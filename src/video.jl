export @video_str, player, playable, title, description, duration, uploaddate, aspectratio, author, channelid, streams

import FFMPEG
parsedatetime(str) = ZonedDateTime(str, "yyyy-mm-ddTHH:MM:SSzzzz")

mutable struct Video
    id::String
    client::APIs.ClientType
    player::Union{Missing, Dict{String, Any}}   # response json from youtube player api
end

function Video(url::String, c = APIs.ANDROID_EMBED; client = c)
    Utils.is_video_id(url) && return Video(url, client, missing)
    video_id = Utils.parse_video_id(url)
    video_id ≡ nothing && throw(ArgumentError("could not found a video id in \"$url\""))
    return Video(video_id, client, missing)
end
macro video_str(url::String); Video(url); end

function Base.show(io::IO, v::Video)
    print(io, Video, '(')
    print(io, "id: ", v.id)
    if v.player ≢ missing
        print(io, ", ")
        print(io, "title: \"", title(v), "\", ")
        print(io, "author: \"", author(v), "\", ")
        print(io, "duration: ", Utils.prettytime(duration(v)))
    end
    print(io, ')')
end

# TODO: error handling for unplayable video, ie, live streaming, age restricted or so on

function player(v::Video, c = v.client; client = c)
    v.player ≢ missing && client == v.client && return v.player
    v.player = APIs.player(v.id; client)
    return v.player
end

playable(v::Video) = getnode(player(v), "playabilityStatus\\status") == "OK"
title(v::Video) = getnode(player(v), "videoDetails\\title")
description(v::Video) = getnode(player(v), "videoDetails\\shortDescription")
uploaddate(v::Video) = skipmissing(parsedatetime, getnode(player(v), "microformat\\playerMicroformatRenderer\\uploadDate"))
duration(v::Video) = tryparsenode(Int, player(v), "videoDetails\\lengthSeconds")
aspectratio(v::Video) = getnode(player(v), "streamingData\\aspectRatio")
author(v::Video) = getnode(player(v), "videoDetails\\author")
channelid(v::Video) = getnode(player(v), "videoDetails\\channelId")
#channel(v::Video) = Channel(channelid(v), missing)
streams(v::Video) = map(dict -> Stream(dict; video = v), stream_dicts(v))

function stream_dicts(v::Video)
    streamingData = ensurenode(player(v), "streamingData")
    dicts = Vector{Dict{String, Any}}(undef, 0)
    haskey(streamingData, "formats") && append!(dicts, streamingData["formats"])
    haskey(streamingData, "adaptiveFormats") && append!(dicts, streamingData["adaptiveFormats"])
    return dicts
end

function Base.download(v::Video, file_path::AbstractString; force = false, kw...)
    force || (file_path = Utils.newpath(file_path, true))
    dir = dirname(file_path)
    mkpath(dir)

    ss = filter!(is_dash, streams(v))
    videos = filter(has_video, ss)
    sort!(videos; by = video_quality)
    mp4 = filter(is_mp4, videos)[end]
    webm = filter(is_webm, videos)[end]
    video = isless(video_quality(mp4), video_quality(webm)) ? webm : mp4
    video_path = download(video, tempname(dir; cleanup = false); force = true, kw...)
    audios = filter(has_audio, ss)
    audio = sort!(audios; by = audio_quality)[end]
    audio_path = download(audio, tempname(dir; cleanup = false); force = true, kw...)

    @info "combining video and audio to \"$file_path\""
    # TODO: figure out what parameters can keep the input quality and produce not too large file
    FFMPEG.exe(`-v 16 -i $video_path -i $audio_path -qscale 0 $file_path`)
    rm(video_path); rm(audio_path)
    return file_path
end
Base.download(v::Video; force = false, kw...) =
        download(v, joinpath(default_download_dir, Utils.safefilename(title(v) * ".mp4")); force, kw...)