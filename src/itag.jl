module Itags

hasdata(itag) = haskey(dash_video, itag) || haskey(dash_audio, itag) || haskey(legacy, itag)
isdash(itag) = haskey(dash_video, itag) || haskey(dash_audio, itag)
hasvideo(itag) = haskey(dash_video, itag) || haskey(legacy, itag)
hasaudio(itag) = haskey(dash_audio, itag) || haskey(legacy, itag)
resolution(itag) = haskey(dash_video, itag) ? dash_video[itag][1] : haskey(legacy, itag) ? legacy[itag][1] : nothing
bitrate(itag) = haskey(dash_audio, itag) ? dash_audio[itag][1] : haskey(legacy, itag) ? legacy[itag][2] : nothing
videocodec(itag) = haskey(dash_video, itag) ? dash_video[itag][2] : haskey(legacy, itag) ? legacy[itag][3] : nothing
audiocodec(itag) = haskey(dash_audio, itag) ? dash_audio[itag][2] : haskey(legacy, itag) ? legacy[itag][4] : nothing
iswebm(itag) = hasvideo(itag) ? occursin("VP9", videocodec(itag)) : occursin("Opus", audiocodec(itag))
ismp4(itag) = ~iswebm(itag)
format(itag) = iswebm(itag) ? ".webm" : ".mp4"

# https://gist.github.com/AgentOak/34d47c65b1d28829bb17c24c04a0096f

# WARNING: this table is not completed.
# TODO: add table from https://gist.github.com/sidneys/7095afe4da4ae58694d128b1034e01e2

"only video, `itag => (resolusion, codec)`"
const dash_video = Dict(
    133 => ( 240, "H.264"),
    134 => ( 360, "H.264"),
    135 => ( 480, "H.264"),
    136 => ( 720, "H.264"),
    137 => (1080, "H.264"),
    138 => (4320, "H.264"),
    160 => ( 144, "H.264"),
    242 => ( 240, "VP9"),
    243 => ( 360, "VP9"),
    244 => ( 480, "VP9"),
    247 => ( 720, "VP9"),
    248 => (1080, "VP9"),
    264 => (1440, "H.264"),
    266 => (2160, "H.264"),
    271 => (1440, "VP9"),
    272 => (4320, "VP9 HFR"),
    278 => ( 144, "VP9"),
    298 => ( 720, "H.264 HFR"),
    299 => (1080, "H.264 HFR"),
    302 => ( 720, "VP9 HFR"),
    303 => (1080, "VP9 HFR"),
    304 => (1440, "H.264 HFR"),
    305 => (2160, "H.264 HFR"),
    308 => (1440, "VP9 HFR"),
    313 => (2160, "VP9"),
    315 => (2160, "VP9 HFR"),
    330 => ( 144, "VP9.2 HDR HFR"),
    331 => ( 240, "VP9.2 HDR HFR"),
    332 => ( 360, "VP9.2 HDR HFR"),
    333 => ( 480, "VP9.2 HDR HFR"),
    334 => ( 720, "VP9.2 HDR HFR"),
    335 => (1080, "VP9.2 HDR HFR"),
    336 => (1440, "VP9.2 HDR HFR"),
    337 => (2160, "VP9.2 HDR HFR"),
    394 => ( 144, "AV1"),
    395 => ( 240, "AV1"),
    396 => ( 360, "AV1"),
    397 => ( 480, "AV1"),
    398 => ( 720, "AV1 HFR"),
    399 => (1080, "AV1 HFR"),
    400 => (1440, "AV1 HFR"),
    401 => (2160, "AV1 HFR"),
    402 => (4320, "AV1 HFR"),
    571 => (4320, "AV1 HFR"),       # ~50% higher bitrate than 402
    694 => ( 144, "AV1 HFR High"),
    695 => ( 240, "AV1 HFR High"),
    696 => ( 360, "AV1 HFR High"),
    697 => ( 480, "AV1 HFR High"),
    698 => ( 720, "AV1 HFR High"),
    699 => (1080, "AV1 HFR High"),
    700 => (1440, "AV1 HFR High"),
    701 => (2160, "AV1 HFR High"),
)

"only audio, `itag => (bitrate, channels(2=>Stereo, 5=>Surround, 4=>Quadraphonic), codec)`"
const dash_audio = Dict(
    139 => ( 48, 2, "AAC (HE v1)"),
    140 => (128, 2, "AAC (LC)"),
    141 => (256, 2, "AAC (LC)"),
    249 => ( 50, 2, "Opus"),
    250 => ( 70, 2, "Opus"),
    251 => (160, 2, "Opus"),
    256 => (192, 5, "AAC (HE v1)"),
    258 => (384, 5, "AAC (LC)"),
    327 => (256, 5, "AAC (LC)"),
    338 => (480, 4, "Opus"),
)

"both audio and video, `itag => (video resolusion, audio bitrate, video codec, audio codec)`"
const legacy = Dict(
    18  => ( 360,  96, "H.264 (Baseline, L3.0)", "AAC (LC)"),
    22  => ( 720, 192, "H.264 (High, L3.1)",     "AAC (LC)"),
    37  => (1080, 128, "H.264 (High, L4.0)",     "AAC (LC)"),
    59  => ( 480, 128, "H.264 (Main, L3.1)",     "AAC (LC)"),
    # live streams
    91  => ( 144,  48, "H.264 (Baseline, L1.1)", "AAC (HE v1)"),
    92  => ( 240,  48, "H.264 (Main, L2.1)",     "AAC (HE v1)"),
    93  => ( 360, 128, "H.264 (Main, L3.0)",     "AAC (LC)"),
    94  => ( 480, 128, "H.264 (Main, L3.1)",     "AAC (LC)"),
    95  => ( 720, 256, "H.264 (Main, L3.1)",     "AAC (LC)"),
    96  => (1080, 256, "H.264 (Main, L4.0)",     "AAC (LC)"),
    300 => ( 720, 128, "H.264 HFR (Main, L3.2)", "AAC (LC)"),
    300 => (1080, 128, "H.264 HFR (Main, L4.0)", "AAC (LC)"),
)

end # Itags