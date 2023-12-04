module nyasTube

# TODO: learn how to make a proper julia package

const cache_dir = joinpath(dirname(@__DIR__), ".cache")
const default_download_dir = joinpath(cache_dir, "download")

include("error.jl")
include("sort.jl")
include("filter.jl")
module Itags;   include("itag.jl");    end
module Utils;   include("utils.jl");   end
module Request; include("request.jl"); end
module APIs;    include("api.jl");     end
include("download.jl")
include("video.jl")
include("stream.jl")

# TODO: more robust error possibility checking

function __init__()
    mkpath(cache_dir)
    mkpath(default_download_dir)
end

# but, well, `TODO` for me just means `to do nothing now`
 
end # nyasTube