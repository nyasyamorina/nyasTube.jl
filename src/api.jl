module APIs

export BearerToken, refresh!, fetch!, fetch_bearer_token
export ClientType, browse, next, player, search
export WEB, WEB_EMBED, WEB_CREATOR, WEB_MUSIC, WEB_MOBILE, ANDROID, ANDROID_EMBED, ANDROID_CREATOR, ANDROID_MUSIC,
        IOS, IOS_EMBED, IOS_CREATOR, IOS_MUSIC, TV_EMBED

import JSON, nyasHttp
import URIs: URI
import ..nyasTube, ..nyasTube.Utils
import ..nyasTube: req_opts
import ..nyasTube.Utils: encodebody

const json_content_header = "content-type" => "application/json; charset=UTF-8"
const default_token_file = joinpath(nyasTube.cache_dir, "token.json")
const max_time = prevfloat(typemax(typeof(time()))) # = 1.7976931348623157e308

# use to fetch or refresh bearer token
const tv_client_id = "861556708454-d6dlm3lh05idd8npek18k6be8ba3oc68.apps.googleusercontent.com"
const tv_client_secret = "SboVhoG9s0rNafixCSGGKXAT"

# some default client values
const deafult_api_key = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
const default_user_agent = "Mozilla/5.0"
const deafult_android_app_version = "18.20.38"
const deafult_android_sdk_version = 31
const deafult_ios_device_model = "iPhone14,3"

# TODO: make token easy to use

"the bearer token to access some restricted videos"
mutable struct BearerToken
    access ::Union{Missing, String}
    expires::Float64
    refresh::Union{Missing, String}
end

const AllowedTokenTypes = Union{Nothing, BearerToken, AbstractString}
const _default_token = Ref{AllowedTokenTypes}(nothing)
function default_bearer_token()::BearerToken
    if ~(_default_token[] isa BearerToken)
        _default_token[] = BearerToken()
    end
    return _default_token[]
end

BearerToken() = BearerToken(missing, max_time, missing)
BearerToken(access::String) = BearerToken(access, max_time, missing)
BearerToken(dict::AbstractDict) = BearerToken(dict["access"], get(dict, "expires", max_time), get(dict, "refresh", missing))
BearerToken(io::IO) = BearerToken(JSON.parse(io))

function JSON.lower(token::BearerToken)
    result = Dict{String, Union{String, Float64}}()
    token.access  ≢ nothing  && push!(result, "access"  => token.access)
    token.expires ≠ max_time && push!(result, "expires" => token.expires)
    token.refresh ≢ nothing  && push!(result, "refresh" => token.refresh)
    return result
end

"refresh the bearer token"
function refresh!(token::BearerToken; force = false)
    force || token.expires < time() || return
    token.refresh ≡ missing && throw(MissingException("`refresh` feild must be provided to refresh token."))
    start = trunc(Int, time()) - 30
    body = Dict(
        "client_id"     => tv_client_id,
        "client_secret" => tv_client_secret,
        "grant_type"    => "refresh_token",
        "refresh_token" => token.refresh
    )
    response = nyasHttp.post(req_opts, "https://oauth2.googleapis.com/token", [json_content_header], encodebody(body))
    response_json = JSON.parse(String(response.body))
    token.access = response_json["access_token"]
    token.expires = response_json["expires_in"] + start
    return token
end

"fetch a bearer token, need to do some something on your browser"
function fetch!(token::BearerToken)
    start = trunc(Int, time()) - 30
    body = Dict(
        "client_id" => tv_client_id,
        "scope"     => "https://www.googleapis.com/auth/youtube"
    )
    response = nyasHttp.post(req_opts, "https://oauth2.googleapis.com/device/code", [json_content_header], encodebody(body))
    response_json = JSON.parse(String(response.body))
    println("open \"$(response_json["verification_url"])\" on browser, and input code \"$(response_json["user_code"])\".")
    println("press enter after completing this step..."); readline()
    body = Dict(
        "client_id"     => tv_client_id,
        "client_secret" => tv_client_secret,
        "device_code"   => response_json["device_code"],
        "grant_type"    => "urn:ietf:params:oauth:grant-type:device_code"
    )
    response = nyasHttp.post(req_opts, "https://oauth2.googleapis.com/token", [json_content_header], encodebody(body))
    response_json = JSON.parse(String(response.body))
    token.access = response_json["access_token"]
    token.expires = response_json["expires_in"] + start
    token.refresh = response_json["refresh_token"]
    return token
end

"fetch a bearer token, need to do some something on your browser"
fetch_bearer_token(new = false) = fetch!(new ? BearerToken() : default_bearer_token())

"use client type to specify some request value `{\"context\": {\"client\": {...}}}`"
mutable struct ClientType
    client_context::Dict{String, Union{String, Int}}
    user_agent::String
end

function (client::ClientType)(endpoint, body; token::AllowedTokenTypes = _default_token[])
    query = Dict{String, Any}("prettyPrint" => false)
    headers = [json_content_header, "user-agent" => client.user_agent]
    if token ≡ nothing
        push!(query, "key" => deafult_api_key)
    else
        token_str = if token isa BearerToken
            token.access ≢ missing ? refresh!(token) : fetch!(token)
            token.access
        else    # token isa AbstractString
            token
        end
        push!(headers, "authorization" => "Bearer $(token_str)")
    end
    response = nyasHttp.post(req_opts, "https://www.youtube.com$endpoint", headers, encodebody(body); query)
    return JSON.parse(String(response.body))
end

# wrap around `client(...)`

function browse(continuation::AbstractString; client = WEB)
    body = Dict{String, Any}(
        "continuation" => continuation,
        "context"      => Dict(
            "client"   => client.client_context
        )
    )
    return client("/youtubei/v1/browse", body; #=token=#)
end
# Julia does not allow function overloading with different numbers of keyword parameters,
# so defind `browse(browse_id, params)` instead of `browse(browse_id; params)`
function browse(browse_id::AbstractString, params::Union{Nothing, AbstractString}; client = WEB)
    body = Dict{String, Any}(
        "browseId"   => browse_id,
        "context"    => Dict(
            "client" => client.client_context
        )
    )
    params ≡ nothing || push!(body, "params" => params)
    return client("/youtubei/v1/browse", body; #=token=#)
end

#=function get_transcript(video_id::AbstractString; client = WEB)
    body = Dict{String, Any}(
        "videoId" => video_id,
        "context"    => Dict(
            "client" => client.client_context
        )
    )
    return client("/youtubei/v1/get_transcript", body; #=token=#)
end=#
function get_transcript(params::AbstractString; client = WEB)
    body = Dict{String, Any}(
        "params" => params,
        "context"    => Dict(
            "client" => client.client_context
        )
    )
    return client("/youtubei/v1/get_transcript", body; #=token=#)
end

function next(continuation::AbstractString; client = WEB)
    body = Dict{String, Any}(
        "continuation" => continuation,
        "context"      => Dict(
            "client"   => client.client_context
        )
    )
    return client("/youtubei/v1/next", body; #=token=#)
end
next(playlist_id, video_id; client = WEB) =
        next(client, Dict("playlistId" => playlist_id, "videoId" => video_id))
function next(body::AbstractDict; client = WEB)
    _body = Dict{String, Any}(body)
    push!(_body, "context" => Dict("client" => client.client_context))
    return client("/youtubei/v1/next", _body; #=token=#)
end

function player(video_id::AbstractString; params::Union{Nothing, AbstractString} = nothing, client = WEB)
    body = Dict{String, Any}(
        "videoId"        => video_id,
        "contentCheckOk" => true,
        "racyCheckOk"    => true,
        "context"        => Dict(
            "client"     => client.client_context
        )
    )
    params ≡ nothing || push!(body, "params" => params)
    return client("/youtubei/v1/player", body; #=token=#)
end

function resolve_url(url::AbstractString; client = WEB)
    body = Dict{String, Any}(
        "url" => url,
        "context"        => Dict(
            "client"     => client.client_context
        )
    )
    return client("/youtubei/v1/navigation/resolve_url", body; #=token=#)
end

function search(search_query::AbstractString; params::Union{Nothing, AbstractString} = nothing, client = WEB)
    body = Dict{String, Any}(
        "query"      => search_query,
        "context"    => Dict(
            "client" => client.client_context
        )
    )
    params ≡ nothing || push!(body, "params" => params)
    return client("/youtubei/v1/search", body; #=token=#)
end

function verify_age(video_id::AbstractString; client = WEB)
    body = Dict{String, Any}(
        "nextEndpoint" => Dict(
            "urlEndpoint" => Dict(
                "url" => "/watch?v=$video_id"
            )
        ),
        "setControvercy": true,
        "context"    => Dict(
            "client" => client.client_context
        )
    )
    return client("/youtubei/v1/search", body; #=token=#)
end

# some deafult clients

const WEB = ClientType(
    Dict(
        "clientName" => "WEB",
        "clientVersion" => "2.20200720.00.02"
    ),
    default_user_agent
)
const WEB_EMBED = ClientType(
    Dict(
        "clientName" => "WEB_EMBEDDED_PLAYER",
        "clientVersion" => "2.20210721.00.00",
        "clientScreen" => "EMBED"
    ),
    default_user_agent
)
const WEB_CREATOR = ClientType(
    Dict(
        "clientName" => "WEB_CREATOR",
        "clientVersion" => "1.20220726.00.00",
    ),
    default_user_agent
)
const WEB_MUSIC = ClientType(
    Dict(
        "clientName" => "WEB_REMIX",
        "clientVersion" => "1.20220727.01.00",
    ),
    default_user_agent
)
const WEB_MOBILE = ClientType(
    Dict(
        "clientName" => "MWEB",
        "clientVersion" => "2.20220801.00.00",
    ),
    default_user_agent
)

const ANDROID = ClientType(
    Dict(
        "clientName" => "ANDROID",
        "clientVersion" => deafult_android_app_version,
        "androidSdkVersion" => deafult_android_sdk_version
    ),
    "com.google.android.youtube/"
)
const ANDROID_EMBED = ClientType(
    Dict(
        "clientName" => "ANDROID_EMBEDDED_PLAYER",
        "clientVersion" => deafult_android_app_version,
        "clientScreen" => "EMBED",
        "androidSdkVersion" => deafult_android_sdk_version
    ),
    "com.google.android.youtube/"
)
const ANDROID_CREATOR = ClientType(
    Dict(
        "clientName" => "ANDROID_CREATOR",
        "clientVersion" => "22.30.100",
        "androidSdkVersion" => deafult_android_sdk_version
    ),
    "com.google.android.apps.youtube.creator/"
)
const ANDROID_MUSIC = ClientType(
    Dict(
        "clientName" => "ANDROID_MUSIC",
        "clientVersion" => "5.16.51",
        "androidSdkVersion" => deafult_android_sdk_version
    ),
    "com.google.android.apps.youtube.music/"
)

const IOS = ClientType(
    Dict(
        "clientName" => "IOS",
        "clientVersion" => "17.33.2",
        "deviceModel" => deafult_ios_device_model
    ),
    "com.google.ios.youtube/"
)
const IOS_EMBED = ClientType(
    Dict(
        "clientName" => "IOS_MESSAGES_EXTENSION",
        "clientVersion" => "17.33.2",
        "deviceModel" => deafult_ios_device_model
    ),
    "com.google.ios.youtube/"
)
const IOS_CREATOR = ClientType(
    Dict(
        "clientName" => "IOS_CREATOR",
        "clientVersion" => "22.33.101",
        "deviceModel" => deafult_ios_device_model,
    ),
    "com.google.ios.ytcreator/"
)
const IOS_MUSIC = ClientType(
    Dict(
        "clientName" => "IOS_MUSIC",
        "clientVersion" => "5.21",
        "deviceModel" => deafult_ios_device_model
    ),
    "com.google.ios.youtubemusic/"
)

const TV_EMBED = ClientType(
    Dict(
        "clientName" => "TVHTML5_SIMPLY_EMBEDDED_PLAYER",
        "clientVersion" => "2.0",
    ),
    default_user_agent
)

end # APIs