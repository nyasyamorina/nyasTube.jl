module nyasTube

# TODO: learn how to make a proper julia package

const cache_dir = joinpath(dirname(@__DIR__), ".cache")

include("error.jl")
include("utils.jl")
include("request.jl")
include("api.jl")
include("video.jl")
include("stream.jl")

# TODO: more robust error possibility checking

function __init__()
    #mkpath(cache_dir)
end

# but, well, `TODO` for me just means `to do nothing now`
 
end # nyasTube