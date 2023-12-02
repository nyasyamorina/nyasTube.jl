module Itags

const progressive_video = Dict{Int, NTuple{2, Union{Nothing, String}}}(
    5   => ( "240p",  "64kbps"),
    6   => ( "270p",  "64kbps"),
    13  => ( "144p",   nothing),
    17  => ( "144p",  "24kbps"),
    18  => ( "360p",  "96kbps"),
    22  => ( "720p", "192kbps"),
    34  => ( "360p", "128kbps"),
    35  => ( "480p", "128kbps"),
    36  => ( "240p",   nothing),
    37  => ("1080p", "192kbps"),
    38  => ("3072p", "192kbps"),
    43  => ( "360p", "128kbps"),
    44  => ( "480p", "128kbps"),
    45  => ( "720p", "192kbps"),
    46  => ("1080p", "192kbps"),
    59  => ( "480p", "128kbps"),
    78  => ( "480p", "128kbps"),
    82  => ( "360p", "128kbps"),
    83  => ( "480p", "128kbps"),
    84  => ( "720p", "192kbps"),
    85  => ("1080p", "192kbps"),
    91  => ( "144p",  "48kbps"),
    92  => ( "240p",  "48kbps"),
    93  => ( "360p", "128kbps"),
    94  => ( "480p", "128kbps"),
    95  => ( "720p", "256kbps"),
    96  => ("1080p", "256kbps"),
    100 => ( "360p", "128kbps"),
    101 => ( "480p", "192kbps"),
    102 => ( "720p", "192kbps"),
    132 => ( "240p",  "48kbps"),
    151 => ( "720p",  "24kbps"),
    300 => ( "720p", "128kbps"),
    301 => ("1080p", "128kbps"),
)
const dash_video = Dict{Int, NTuple{2, Union{Nothing, String}}}(
    133 => ( "240p", nothing),  # MP4
    134 => ( "360p", nothing),  # MP4
    135 => ( "480p", nothing),  # MP4
    136 => ( "720p", nothing),  # MP4
    137 => ("1080p", nothing),  # MP4
    138 => ("2160p", nothing),  # MP4
    160 => ( "144p", nothing),  # MP4
    167 => ( "360p", nothing),  # WEBM
    168 => ( "480p", nothing),  # WEBM
    169 => ( "720p", nothing),  # WEBM
    170 => ("1080p", nothing),  # WEBM
    212 => ( "480p", nothing),  # MP4
    218 => ( "480p", nothing),  # WEBM
    219 => ( "480p", nothing),  # WEBM
    242 => ( "240p", nothing),  # WEBM
    243 => ( "360p", nothing),  # WEBM
    244 => ( "480p", nothing),  # WEBM
    245 => ( "480p", nothing),  # WEBM
    246 => ( "480p", nothing),  # WEBM
    247 => ( "720p", nothing),  # WEBM
    248 => ("1080p", nothing),  # WEBM
    264 => ("1440p", nothing),  # MP4
    266 => ("2160p", nothing),  # MP4
    271 => ("1440p", nothing),  # WEBM
    272 => ("4320p", nothing),  # WEBM
    278 => ( "144p", nothing),  # WEBM
    298 => ( "720p", nothing),  # MP4
    299 => ("1080p", nothing),  # MP4
    302 => ( "720p", nothing),  # WEBM
    303 => ("1080p", nothing),  # WEBM
    308 => ("1440p", nothing),  # WEBM
    313 => ("2160p", nothing),  # WEBM
    315 => ("2160p", nothing),  # WEBM
    330 => ( "144p", nothing),  # WEBM
    331 => ( "240p", nothing),  # WEBM
    332 => ( "360p", nothing),  # WEBM
    333 => ( "480p", nothing),  # WEBM
    334 => ( "720p", nothing),  # WEBM
    335 => ("1080p", nothing),  # WEBM
    336 => ("1440p", nothing),  # WEBM
    337 => ("2160p", nothing),  # WEBM
    394 => ( "144p", nothing),  # MP4
    395 => ( "240p", nothing),  # MP4
    396 => ( "360p", nothing),  # MP4
    397 => ( "480p", nothing),  # MP4
    398 => ( "720p", nothing),  # MP4
    399 => ("1080p", nothing),  # MP4
    400 => ("1440p", nothing),  # MP4
    401 => ("2160p", nothing),  # MP4
    402 => ("4320p", nothing),  # MP4
    571 => ("4320p", nothing),  # MP4
    694 => ( "144p", nothing),  # MP4
    695 => ( "240p", nothing),  # MP4
    696 => ( "360p", nothing),  # MP4
    697 => ( "480p", nothing),  # MP4
    698 => ( "720p", nothing),  # MP4
    699 => ("1080p", nothing),  # MP4
    700 => ("1440p", nothing),  # MP4
    701 => ("2160p", nothing),  # MP4
    702 => ("4320p", nothing),  # MP4
)
const dash_audio = Dict{Int, NTuple{2, Union{Nothing, String}}}(
    139 => (nothing,  "48kbps"),  # MP4
    140 => (nothing, "128kbps"),  # MP4
    141 => (nothing, "256kbps"),  # MP4
    171 => (nothing, "128kbps"),  # WEBM
    172 => (nothing, "256kbps"),  # WEBM
    249 => (nothing,  "50kbps"),  # WEBM
    250 => (nothing,  "70kbps"),  # WEBM
    251 => (nothing, "160kbps"),  # WEBM
    256 => (nothing, "192kbps"),  # MP4
    258 => (nothing, "384kbps"),  # MP4
    325 => (nothing,   nothing),  # MP4
    328 => (nothing,   nothing),  # MP4
)

quality(itag) = get(progressive_video, itag, get(dash_video, itag, get(dash_audio, itag, (nothing, nothing))))[1]
samplerate(itag) = get(progressive_video, itag, get(dash_video, itag, get(dash_audio, itag, (nothing, nothing))))[2]
isHDR(itag::Integer) = 330 ≤ itag ≤ 337
is3D(itag::Integer) = 82 ≤ itag ≤ 85 || 100 ≤ itag ≤ 102
islive(itag::Integer) = 91 ≤ itag ≤ 96 || itag ∈ (132, 151)
    
end # Itags

# TODO: filtering and sorting function types that support arbitrarily combination

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

hasaudio(s::Stream) = length(s.codecs) == 2 || s.type == "audio"
hasvideo(s::Stream) = length(s.codecs) == 2 || s.type == "video"
audio_codec(s::Stream) = length(s.codecs) == 2 ? s.codecs[2] : s.type == "audio" ? s.codecs[] : nothing
video_codec(s::Stream) = length(s.codecs) == 2 ? s.codecs[1] : s.type == "video" ? s.codecs[] : nothing
filename(s::Stream) = (s.video ≡ missing ? "stream" : Utils.safefilename(title(s.video))) * ".$(s.format)"

"filesize ≈ bitrate * duration / 8"
approxfilesize(s::Stream) = round(Int, s.bitrate * s.duration / 8)

function split_mimeType(mimeType::AbstractString)
    type_format = @view mimeType[1:findfirst(';', mimeType)-1]
    (type, format) = split(type_format, '/')
    start = findfirst('\"', mimeType)
    stop = findnext('\"', mimeType, start + 1)
    codecs = split(mimeType[start+1:stop-1], ',')
    return (strip(type), strip(format), map(strip, codecs))
end

# TODO: use multi-taking to download stream