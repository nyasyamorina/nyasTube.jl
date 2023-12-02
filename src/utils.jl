module Utils

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

const json_content_header = header("content-type" => "application/json; charset=UTF-8")

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
    str = replace(str, char => replaceby for char ∈ invalid)
    return max_length ≡ nothing ? str : str[1:max_length]
end
    
end # Utils