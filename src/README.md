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
# download the best quality video stream with the best audio
download(video, "path/to/file.mp4"; threads = 16)
```

And also you can select your favorite stream

```julia
# get the list of streams
streams = nyasTube.streams(video)
# then filer them or sort them
filter!(nyasTube.has_audio & nyasTube.has_video, streams)
sort!(streams; by = -nyasTube.video_quality >> - nyasTube.audio_quality)
# get your stream
stream = streams[1]
# then download it or do something interesting
file_size = nyasTube.filesize(stream)
download(stream, "path/to/dir/$(nyasTube.filename(stream))")
```

Or maybe you just a low-level API enthusiast

```julia
playlist_id = "PLvoJm-S4aIszxXQGYbZNJEZFRP1SSbw0X"
response = nyasTube.APIs.next(nyasTube.APIs.WEB, playlist_id, video.id)
```

### 2. Filtering & Sorting system

The filtering and sorting functions can wrap around by specific types:
`nyasTube.Filter` and `nyasTube.Sorter`

```julia
divisible_by_3 = nyasTube.Filter(x -> mod(x, 3) == 0)
second = nyasTube.Sorter(x -> x[2])
```

Then they can combine with each other

```julia
nyasfilter = divisible_by_3 ⊻ !nyasTube.Filter(<(0))
nyassorter = second << -nyasTube.Sorter(sum)
```

use them as the normal filtering and sorting functions

```julia
list1 = filter(nyasfilter, -7:7)
println(list1)  # [-6, -3, 1, 2, 4, 5, 7]
list2 = [(0,0), (1,3), (-4,4), (2,2), (-5,9), (1,1)]
sort!(list2, by = nyassorter)
println(list2)  # [(2,2), (1,3), (-5,9), (1,1), (0,0), (-4,4)]
```

### ∞. Future plans

```julia
nothing
```