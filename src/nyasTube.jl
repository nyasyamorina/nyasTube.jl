module nyasTube

using nyasHttp

const req_opts = nyasHttp.RequestOptions([
    "accept-language" => "en-US,en",
    "accept-encoding" => "gzip, deflate"
])

const cache_dir = joinpath(dirname(@__DIR__), ".cache")
const default_download_dir = joinpath(cache_dir, "download")

include("sort.jl")
include("filter.jl")
include("utils.jl")
include("itag.jl")
include("api.jl")
include("download.jl")
#include("channel.jl")
include("video.jl")
include("stream.jl")

# TODO: more robust error possibility checking

function __init__()
    mkpath(cache_dir)
    mkpath(default_download_dir)
end

# but, well, `TODO` for me just means `to do nothing now`

end # nyasTube