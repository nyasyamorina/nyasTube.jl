module Utils

import Printf, Base64, HTTP, JSON

encodebody(data::Vector{UInt8}) = data
encodebody(io::IO) = io
encodebody(str::AbstractString) = Vector{UInt8}(str)
encodebody(dict::AbstractDict) = Vector{UInt8}(JSON.json(dict))

function is_video_id(video_id::AbstractString)
    is_valid_char(c) = '0' ≤ c ≤ '9' || 'A' ≤ c ≤ 'Z' || 'a' ≤ c ≤ 'z' || c ∈ ('_', '-')
    length(video_id) ≠ 11 && return false
    return all(is_valid_char.(collect(video_id)))
end

function parse_video_id(url::AbstractString)
    m = match(r"(?:v=|\/)([0-9A-Za-z_-]{11}).*", url)
    m ≡ nothing && return nothing
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
    range == 0 && return ""
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

# rewrite from https://github.com/iv-org/protodec/blob/9e02d88a19f7b948877f0650297dad4949188e52/src/protodec/utils.cr

function protodec_write(io, value::Unsigned)    # type => "varint"
    value == 0 && return write(io, 0x00)
    while value ≠ 0
        byte = UInt8(value & 0x7F)
        value >>= 7
        value == 0 || (byte |= 0x80)
        write(io, byte)
    end
end
protodec_write(io, value::Signed) = protodec_write(io, unsigned(value))

function protodec_write(io, str::AbstractString)  # type => "string"
    protodec_write(io, sizeof(str))
    print(io, str)
end

function protodec_write(io, json::Union{AbstractArray, AbstractDict})  # type => "embedded"
    new_io = IOBuffer()
    protodec_from_json(new_io, json)
    buffer = take!(new_io)
    close(new_io)
    protodec_write(io, length(buffer))
    write(io, buffer)
end

function protodec_from_json(io, json)
    @show "start json"
    for (field::Integer, value) ∈ json
        @show field
        type_id = value isa Integer ? 0 #="varint"=# : 2 #="string"||"embedded"=#
        header = (field << 3) | type_id
        protodec_write(io, header)
        protodec_write(io, value)
    end
    @show "end json"
end

function protodec_encode_json(json)::String
    #=```crystal
    json.try { |i| Protodec::Any.cast_json(i) }.try { |i| Protodec::Any.from_json(i) }
        .try { |i| Base64.urlsafe_encode(i) }  .try { |i| URI.encode_www_form(i) }
    ```=#
    io = IOBuffer()
    b64_io = Base64.Base64EncodePipe(io)
    protodec_from_json(b64_io, json)
    close(b64_io)
    s = String(take!(io))
    close(io)
    s = HTTP.escape(s)
    return s
end

end # Utils