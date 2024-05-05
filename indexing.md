# nyasTube.jl

### Requester

- nyasTube.Request.default_requester_p[]

---

## Video

- Video(url::String)
- video"..."

- playable(::Video)::Bool
- title(::Video)::String
- description(::Video)::String
- duration(::Video)::Int
- aspectratio(::Video)::String
- author(::Video)::String
- channelid(::Video)::String
- channel(::Video):Channel
- streams(::Video)::Vector{Stream}

- download(::Video, *[path::String]*; *[force::Bool]*, *[threads::Int]*)::String

---

## Stream

- itag(::Stream)::Int
- isdash(::Stream)::Bool
- hasaudio(::Stream)::Bool
- hasvideo(::Stream)::Bool
- audiocodec(::Stream)::Union{Nothing, String}
- videocodec(::Stream)::Union{Nothing, String}
- filename(::Stream)::String
- filesize(::Stream)::Int
- approxfilesize(::Stream)::Int

- is_mp4::Filter
- is_webm::Filter
- has_audio::Filter
- has_video::Filter
- is_dash::Filter
- file_size::Sorter
- video_quality::Sorter
- audio_quality::Sorter

- download(::Stream, *[path::Stream]*; *[force::Bool]*, *[threads::Int]*)::String