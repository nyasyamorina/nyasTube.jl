struct NodeNotFoundException <: Exception
    path::String
end

Base.showerror(io::IO, err::NodeNotFoundException) = print(io, "Could not find json node: \"$(err.path)\"")


getnode(obj, path::AbstractString) = getnode(obj, splitpath(path))

function getnode(value #= number | string | bool | etc. =#, path::AbstractVector{<:AbstractString})
    isempty(path) && return value
    node_name = popfirst!(path)
    (isempty(node_name) || node_name ∈ ('/', '\\')) && return getnode(value, path)

    return missing
end

function getnode(json::AbstractDict{String}, path::AbstractVector{<:AbstractString})
    isempty(path) && return json
    node_name = popfirst!(path)
    (isempty(node_name) || node_name ∈ ('/', '\\')) && return getnode(json, path)

    haskey(json, node_name) || return missing
    node = json[node_name]
    return getnode(node, path)
end

function getnode(vec::AbstractVector, path::AbstractVector{<:AbstractString})
    isempty(path) && return value
    node_name = popfirst!(path)
    (isempty(node_name) || node_name ∈ ('/', '\\')) && return getnode(vec, path)

    index = tryparse(Int, node_name)
    index ≡ nothing && return missing
    index = mod1(index, length(vec))
    node = vec[index]
    return getnode(node, path)
end

function tryparsenode(::Type{T}, obj, path) where {T <: Real}
    node = getnode(obj, path)
    node ≡ missing && return missing
    return tryparse(T, node)
end

function ensurenode(obj, path)
    path isa AbstractVector && return ensurenode(obj, joinpath(path))
    node = getnode(obj, path)
    node ≡ missing && throw(NodeNotFoundException(path))
    return node
end