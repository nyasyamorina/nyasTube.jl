module Request

export Requester, default_requester_p, encodebody

import JSON, HTTP
import ..nyasTube.Utils: header

"overwrite the method `HTTP.request` with some default arguments, see also [`HTTP.request`](@ref)"
mutable struct Requester
    headers::Dict{String, String}
    keywords::Dict{Symbol, Any}

    function Requester(; headers = nothing, keywords...)
        kw = Dict{Symbol, Any}(keywords)
        haskey(kw, :retry) || push!(kw, :retry => false)
        return new(header(headers), kw)
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

function (req::Requester)(method, url; headers = nothing, body = HTTP.nobody, keywords...)
    total_headers = header(req.headers, headers)
    # fall back to the default behavior of `HTTP.request` if there is no header
    final_headers = isempty(total_headers) ? nothing : total_headers
    return HTTP.request(method, url, final_headers, encodebody(body); req.keywords..., keywords...)
end

# just for testing...
nyasrequest(args...; keywords...) = (@show (args, keywords); HTTP.request(args...; keywords...))

"the reference of default requester for global usage"
const default_requester_p = Ref(Requester(; headers = ["accept-language" => "en-US,en", "accept-encoding" => "gzip, deflate"]))

encodebody(data::Vector{UInt8}) = data
encodebody(io::IO) = io
encodebody(str::AbstractString) = Vector{UInt8}(str)
encodebody(dict::AbstractDict) = Vector{UInt8}(JSON.json(dict))

end # Request