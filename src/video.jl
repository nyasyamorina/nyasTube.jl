mutable struct Video
    id::String
    player::Union{Missing, Dict{String, Any}}   # response json from youtube player api
end

Video(url::String) = Video(Utils.is_video_id(url) ? url : Utils.parse_video_id(url; not_found_error = true), missing)

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