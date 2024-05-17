export Itags
export isdash, hasaudio, hasvideo, audiocodec, videocodec, filesize, approxfilesize

import HTTP
import ..nyasTube: req_opts

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
    missing2nothing(x) = x ≡ missing ? nothing : x

    s = Stream(video, "", 0, "", "", [], 0, 0, nothing, nothing, missing)
    s.url = ensurenode(dict, "url")
    s.itag = ensurenode(dict, "itag")
    (s.type, s.format, s.codecs) = split_mimeType(ensurenode(dict, "mimeType"))
    s.bitrate = ensurenode(dict, "bitrate")
    # the video is not fully encoded if this value is not set by YouTube
    duration = getnode(dict, "approxDurationMs")
    s.duration = duration ≡ missing ? 0 : parse(Int, duration)
    s.height = missing2nothing(getnode(dict, "height"))
    s.height = missing2nothing(getnode(dict, "height"))
    s.filesize = tryparsenode(Int, dict, "contentLength")
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
filesize(s::Stream) =
        s.filesize ≢ missing ? s.filesize : (s.filesize = parse(Int, HTTP.header(nyasHttp.head(req_opts, s.url), "content-length")))
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

function Base.download(s::Stream, file_path::AbstractString; force = false, kw...)
    force || (file_path = Utils.newpath(file_path, true))
    mkpath(dirname(file_path))
    return downloadfile(s.url, file_path, filesize(s); kw...)
end
Base.download(s::Stream; force = false, kw...) =
        download(s, joinpath(default_download_dir, filename(s)); force, kw...)