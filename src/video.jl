export player, playable, title, description, duration, aspectratio, author, streams

import FFMPEG

mutable struct Video
    id::String
    player::Union{Missing, Dict{String, Any}}   # response json from youtube player api
end

Video(url::String) = Video(Utils.is_video_id(url) ? url : Utils.parse_video_id(url; not_found_error = true), missing)

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

player(v::Video; req = Request.default_requester_p[]) = v.player ≢ missing ? v.player : (v.player = APIs.player(APIs.ANDROID_EMBED, v.id; req))

playable(v::Video) = player(v)["playabilityStatus"]["status"] == "OK"
title(v::Video) = player(v)["videoDetails"]["title"]
description(v::Video) = player(v)["videoDetails"]["shortDescription"]
duration(v::Video) = parse(Int, player(v)["videoDetails"]["lengthSeconds"])
aspectratio(v::Video) = player(v)["streamingData"]["aspectRatio"]
author(v::Video) = player(v)["videoDetails"]["author"]      # maybe create a type named `Author` or `Channel`?
streams(v::Video) = map(dict -> Stream(dict; video = v), stream_dicts(v))

function stream_dicts(v::Video; req = Request.default_requester_p[])
    streamingData = player(v; req)["streamingData"]
    dicts = Vector{Dict{String, Any}}(undef, 0)
    haskey(streamingData, "formats") && append!(dicts, streamingData["formats"])
    haskey(streamingData, "adaptiveFormats") && append!(dicts, streamingData["adaptiveFormats"])
    return dicts
end

function Base.download(v::Video, file_path::AbstractString; force = false, req = default_requester_p[], kw...)
    force || (file_path = Utils.newpath(file_path, true))
    dir = dirname(file_path)
    mkpath(dir)

    ss = filter!(is_dash, streams(v))
    videos = filter(has_video, ss)
    sort!(videos; by = video_quality)
    mp4 = filter(is_mp4, videos)[end]
    webm = filter(is_webm, videos)[end]
    video = isless(video_quality(mp4), video_quality(webm)) ? webm : mp4
    video_path = download(video, tempname(dir; cleanup = false); force = true, req, kw...)
    audios = filter(has_audio, ss)
    audio = sort!(audios; by = audio_quality)[end]
    audio_path = download(audio, tempname(dir; cleanup = false); force = true, req, kw...)

    @info "combining video and audio to \"$file_path\""
    # TODO: figure out what parameters can keep the input quality and produce not too large file
    FFMPEG.exe(`-v 16 -i $video_path -i $audio_path -qscale 0 $file_path`)
    rm(video_path); rm(audio_path)
    return file_path
end
Base.download(v::Video; force = false, req = default_requester_p[], kw...) =
        download(v, joinpath(default_download_dir, Utils.safefilename(title(v) * ".mp4")); force, req, kw...)