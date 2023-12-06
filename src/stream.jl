export Itags
export isdash, hasaudio, hasvideo, audiocodec, videocodec, filesize, approxfilesize

import HTTP
import ..nyasTube.Request.default_requester_p

mutable struct Stream
    video::Union{Missing, Video}
    url::String
    itag::Int
    type::String    # "video" or "audio"
    format::String
    codecs::Vector{String}  # always has one or two elements
    bitrate::Int
    duration::Rational      # just an approx value
    height::Union{Nothing, Int}
    width::Union{Nothing, Int}
    filesize::Union{Missing, Int}
end

function Stream(dict::Dict{String, Any}; video = missing)
    s = Stream(video, "", 0, "", "", [], 0, 0, nothing, nothing, missing)
    s.url = dict["url"]
    s.itag = dict["itag"]
    (s.type, s.format, s.codecs) = split_mimeType(dict["mimeType"])
    @assert 1 ≤ length(s.codecs) ≤ 2 "got an invalid mimeType: \"$(dict["mimeType"])\""
    s.bitrate = dict["bitrate"]
    s.duration = parse(Int, dict["approxDurationMs"]) // 1000
    haskey(dict, "height") && (s.height = dict["height"])
    haskey(dict, "width")  && (s.width  = dict["width"])
    haskey(dict, "contentLength") && (s.filesize = parse(Int, dict["contentLength"]))
    return s
end

function Base.show(io::IO, s::Stream)
    print(io, Stream, '(')
    print(io, "itag: ", s.itag)
    print(io, ", duration: ", Utils.prettytime(s.duration; ms = true))
    print(io, ", type: ", s.type, '/', s.format, '\"')
    print(io, ", bitrate: ", s.bitrate, "B/s")
    all((s.height, s.width) .≢ nothing) && print(io, ", resolution: ", s.width, 'x', s.height)
    s.filesize ≡ missing || print(io, ", size: ", s.filesize, "B")
    print(io, ')')
end

itag(s::Stream) = s.itag
isdash(s::Stream) = Itags.isdash(itag(s))

hasaudio(s::Stream) = length(s.codecs) == 2 || s.type == "audio"
hasvideo(s::Stream) = length(s.codecs) == 2 || s.type == "video"
audiocodec(s::Stream) = length(s.codecs) == 2 ? s.codecs[2] : s.type == "audio" ? s.codecs[] : nothing
videocodec(s::Stream) = length(s.codecs) == 2 ? s.codecs[1] : s.type == "video" ? s.codecs[] : nothing
filename(s::Stream) = (s.video ≡ missing ? "stream" : Utils.safefilename(title(s.video))) * s.format
filesize(s::Stream; req = default_requester_p[]) =
        s.filesize ≢ missing ? s.filesize : (s.filesize = parse(Int, HTTP.header(req(:HEAD, s.url), "content-length")))
"filesize ≈ bitrate * duration / 8"
approxfilesize(s::Stream) = round(Int, s.bitrate * s.duration / 8)

const is_mp4    = Filter(s -> s.format == ".mp4")
const is_webm   = Filter(s -> s.format == ".webm")
const has_audio = Filter(hasaudio)
const has_video = Filter(hasvideo)
const is_dash   = Filter(Itags.isdash ∘ itag)
const file_size = Sorter(filesize)
const video_quality = Sorter(Utils.SomethingOrZero{Int}() ∘ Itags.resolution ∘ itag)
const audio_quality = Sorter(Utils.SomethingOrZero{Int}() ∘ Itags.bitrate    ∘ itag)

function split_mimeType(mimeType::AbstractString)
    type_format = @view mimeType[1:findfirst(';', mimeType)-1]
    (type, format) = split(type_format, '/')
    indices = findall('\"', mimeType)
    codecs = split((@view mimeType[indices[1]+1:indices[2]-1]), ',')
    return (strip(type), "." * strip(format), map(strip, codecs))
end

function Base.download(s::Stream, file_path::AbstractString; force = false, req = default_requester_p[], kw...)
    force || (file_path = Utils.newpath(file_path, true))
    mkpath(dirname(file_path))
    return downloadfile(s.url, file_path, filesize(s; req); req, kw...)
end
Base.download(s::Stream; force = false, req = default_requester_p[], kw...) =
        download(s, joinpath(default_download_dir, filename(s)); force, req, kw...)