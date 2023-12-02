# nyasTube.jl

A simple youtube video downloading module.

* Yeah, this module is rewrited from [PyTube](https://github.com/pytube/pytube), just go to see that, not walking around here.

---

### 1. How to use it

First, you need to include this module (not import, I don't know how to make a proper package in Julia).

```julia
include("src/nyasTube.jl")
```

Then you can use it to download a youtube video (at least that's how it works ideally).

```julia
# init a Video object
video = nyasTube.Video("https://www.youtube.com/watch?v=Lworfif9Ck4")
# get all available streams
streams = nyasTube.streams(video)
# download the best quality video stream with audio
filter!(nyasTube.HasAudio, streams)
sort!(streams; lt = nyasTube.VideoQuality, rev = true)
nyasTube.download(streams[1]; threads = 64)
```

Or maybe you just a low-level API enthusiast

```julia
body = Dict(
    "videoId" => "Lworfif9Ck4",
    "playlistId" => "PLvoJm-S4aIszxXQGYbZNJEZFRP1SSbw0X"
)
response = nyasTube.APIs.next(nyasTube.APIs.WEB, body)
```

### 2. Future plans

```julia
nothing
```