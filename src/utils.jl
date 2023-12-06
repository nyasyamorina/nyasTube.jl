import Printf

"""
    header([header..., [headers...]])

the argument `headers` in `HTTP.request` accepts wide range of types,
this function will unify them into `Dict{String, String}`
"""
function header(h...)
    result = Dict{String, String}()
    update = pair -> (result[string(pair.first)] = string(pair.second))
    for hh ∈ h
        hh ≡ nothing && continue
        hh isa Pair && (update(hh); continue)
        foreach(update, hh)
    end
    return result
end

function is_video_id(video_id::AbstractString)
    is_valid_char(c) = '0' ≤ c ≤ '9' || 'A' ≤ c ≤ 'Z' || 'a' ≤ c ≤ 'z' || c ∈ ('_', '-')
    length(video_id) ≠ 11 && return false
    return all(is_valid_char.(collect(video_id)))
end

function parse_video_id(url::AbstractString; not_found_error = false)
    m = match(r"(?:v=|\/)([0-9A-Za-z_-]{11}).*", url)
    if m ≡ nothing
        not_found_error && throw(ArgumentError("could not found a video id in \"$url\""))
        return nothing
    end
    return m[1]
end

function safefilename(str::AbstractString, max_length::Union{Nothing, Integer} = nothing; replaceby = "-")
    # https://en.wikipedia.org/wiki/Filename
    invalid = Char[
        (c for c ∈ 0x00:0x1F)..., 0x7F,
        '/', '\\', '?', '%', '*', ':', '|', '\"', '<', '>'#=, '.', ',', ';', '=', ' '=#
    ]
    @assert ~any(collect(replaceby) .∈ invalid) "the replacing string cannot have invalid characters"
    str = replace(str, (char => replaceby for char ∈ invalid)...)
    return max_length ≡ nothing ? str : str[1:max_length]
end

"""
    newpath(path [; ext])

Return a path that does not currently point to anything.

If `path` is a file path with extension, then `has_ext` need to be `true` to
ensure the file extension is not changed.
"""
function newpath(path::AbstractString, has_ext::Bool = false)
    (base_path, ext) = has_ext ? splitext(path) : (path, "")
    ispath(path) || return path
    counting = 1
    while true
        new_path = base_path * " ($counting)" * ext
        ispath(new_path) || return new_path
        counting += 1
    end
end

"convert duration time (in second) to format `HH:MM:SS.MS`"
function prettytime(duration::Real; ms::Bool = false)
    # maybe there is already implemented in Julia?
    s, MS = divrem(duration, 1) |> (xy -> round.(Int, xy .* (1, 1000)))
    ~ms && MS ≥ 500 && (s += 1)
    m, S  = divrem(s, 60)
    H, M  = divrem(m, 60)
    result = H == 0 ? "" : Printf.@sprintf "%02d:" H
    result *= Printf.@sprintf "%02d:%02d" M S
    ms && (result *= Printf.@sprintf ".%03d" MS)
    return result
end

# https://en.wikipedia.org/wiki/Unit_prefix
const unit_prefix = ("K", "M", "G", "T", "P", "E", "Z", "Y", "R", "Q")

function unitprefix(range::UInt)
    range == 0 && return " "
    range ≤ length(unit_prefix) && return @inbounds unit_prefix[range]
    return "×10^$(3range)"
end

"convert value to format `xxxK` or `xxxM`"
function prettyunit(value::AbstractFloat; decimal::UInt = UInt(2))
    prefix_range = zero(UInt)
    while value > 1000
        value /= 1000
        prefix_range += 1
    end
    format = Printf.Format("%.$(decimal)f")
    number = Printf.format(format, value)
    return number * unitprefix(prefix_range)
end
prettyunit(value::Real; decimal::Integer = 2) = prettyunit(Float64(value); decimal = UInt(decimal))

struct SomethingOrZero{T} <: Function end
(::SomethingOrZero{T})(args::Union{Nothing, T}...) where {T} = something(args..., zero(T))

clearline(io::IO) = (print(io, "\r\e[K"); io)
moveup(io::IO) = (print(io, "\e[A"); io)