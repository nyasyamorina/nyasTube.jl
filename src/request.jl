export Requester, default_requester_p, encodebody

import JSON, HTTP
import ..nyasTube.Utils: header

const json_content_header = header("content-type" => "application/json; charset=UTF-8")

# see more: https://juliaweb.github.io/HTTP.jl/stable/client/#Keyword-Arguments

"overwrite the method `HTTP.request` with some default arguments, see also [`HTTP.request`](@ref)"
mutable struct Requester
    headers::Dict{String, String}
    keywords::Dict{Symbol, Any}

    function Requester(; headers = HTTP.Header[], kw...)
        keywords = Dict{Symbol, Any}(kw)
        haskey(kw, :retry) || push!(keywords, :retry => false)
        return new(header(headers), keywords)
    end
end

function Base.getproperty(r::Requester, sym::Symbol)
    sym ∈ fieldnames(Requester) && return getfield(r, sym)
    haskey(r.keywords, sym) && return r.keywords[sym]
    return missing
end

function Base.setproperty!(r::Requester, sym::Symbol, v)
    sym ∈ fieldnames(Requester) && return setfield!(r, sym, v)
    r.keywords[sym] = v
end

HTTP.open(iofunction::Function, req::Requester, methods, url; headers = HTTP.Header[], kw...) = 
        req(methods, url; headers, iofunction, kw...)
function (req::Requester)(method, url; headers = HTTP.Header[], body = HTTP.nobody, kw...)
    total_headers = header(req.headers, headers)
    return HTTP.request(method, url, total_headers, encodebody(body); req.keywords..., kw...)
end

# just for testing...
nyasrequest(args...; kw...) = (@show (args, kw); HTTP.request(args...; kw...))
nyasopen(args...; kw...) = (@show (args, kw); HTTP.open(args..., kw...))

"the reference of default requester for global usage"
const default_requester_p = Ref(Requester(; headers = ["accept-language" => "en-US,en", "accept-encoding" => "gzip, deflate"]))

encodebody(data::Vector{UInt8}) = data
encodebody(io::IO) = io
encodebody(str::AbstractString) = Vector{UInt8}(str)
encodebody(dict::AbstractDict) = Vector{UInt8}(JSON.json(dict))