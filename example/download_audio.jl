# just a simple script to download audio to my own OneDrive

using Pkg

const nyasTube_path = dirname(@__DIR__)
Pkg.activate(nyasTube_path)
using HTTP, nyasHttp, nyasTube, JSON

const proxy = get(ENV, "nyasProxy", "")
isempty(proxy) || setoptions!(nyasTube.req_opts; proxy)

const cache_path = joinpath(nyasTube.cache_dir, "channelid_name.json")
channelid_name = if isfile(cache_path)
    JSON.parsefile(cache_path; dicttype = Dict{String, String})
else
    Dict{String, String}()
end

const top_level = haskey(ENV, "OneDrive") ? joinpath(ENV["OneDrive"], "a/A5MR/ori") : pwd()

# use [aria2](https://github.com/aria2/aria2) to download files to avoid Julia getting stuck due to OpenSSL.jl problem.
# see also @ nyasTube.jl/src/download.jl:134 & https://discourse.julialang.org/t/openssl-jl-eof-blocks-with-keep-alive-connections/109053
const aria2_exe = get(ENV, "ARIA2_EXE_PATH", "")
const has_aria2 = ~isempty(aria2_exe) && isfile(aria2_exe)

if has_aria2
    @info "download file using aria2 @ \"$aria2_exe\""
    function downloadfunc(url, file_path, file_size; threads = 16)
        (dir, name) = splitdir(file_path)
        proxy_opt = isempty(proxy) ? "" : "--all-proxy=$proxy"
        cmd = `$aria2_exe -d$dir -o$name --file-allocation=prealloc -k1M -s$threads -x$threads $proxy_opt --summary-interval=0 $url`
        run(cmd)
        return file_path
    end
else
    @info "download file using builtin method in `nyasTube.jl`"
    const downloadfunc = nyasTube.downloadfile
end


function printerror()
    println()
    for (exc, bt) ∈ current_exceptions()
        showerror(stdout, exc, bt)
        println()
    end
end

function retryornot()
    println("\n <- press [enter] to continue, press [R] end [enter] to retry")
    char = first(uppercase(readline()))
    return char == 'R'
end

function getaudiostream(video)
    ss = nyasTube.streams(video)
    filter!(nyasTube.is_dash & nyasTube.has_audio, ss)
    s = last(sort!(ss; by = nyasTube.audio_quality))
    nyasTube.itag(s) == 251 || @warn """the itag of the highest audio quality is 251, only got $(nyasTube.itag(s)),
                                        you can wait a few hours and check again."""
    return s
end

function getdownloadinfo(url)
    while true
        println("\ngetting video information...")

        try
            v = nyasTube.Video(url; client = nyasTube.APIs.WEB)
            s = getaudiostream(v)

            println("================================")
            println("title: ", title(v))
            println("upload: ", uploaddate(v))
            println("author: ", author(v))
            println("channel id: ", channelid(v))
            if s.filesize ≢ missing
                println("file size: ", s.filesize ÷ 10^4 / 10^2, "MB")
            end

            file_name = nyasTube.filename(s)
            println("\n <- enter file tile [default: $file_name]")
            _file_name = readline()
            isempty(_file_name) || (file_name = nyasTube.Utils.safefilename(_file_name))
            splitext(file_name)[2] == s.format || (file_name *= s.format)

            cid = channelid(v)
            sub_dir = get(channelid_name, cid, "")
            println("\n <- enter sub-dir save to [default: $(isempty(sub_dir) ? "<top-level>" : sub_dir)]")
            _sub_dir = readline()
            if ~isempty(_sub_dir)
                sub_dir = nyasTube.Utils.safefilename(_sub_dir)
                channelid_name[cid] = sub_dir
                open(cache_path; write = true) do file
                    JSON.print(file, channelid_name, 4)
                end
            end

            threads = 16
            println()
            while true
                println(" <- enter # of downloading threads [default: $threads]")
                sss = readline()
                isempty(sss) && break
                _threads = tryparse(Int, sss)
                _threads ≢ nothing && (threads = _threads; break)
                println("\"$sss\" is not a valid integer")
            end

            return (s.url, file_name, sub_dir, threads)

        catch err
            err isa InterruptException || printerror()
            retryornot() || return
        end
    end
end

function trydownload(video_url, stream_url, file_name, sub_dir, threads)
    retrying = false

    while true
        try
            if retrying
                v = nyasTube.Video(video_url; client = nyasTube.APIs.WEB)
                s = getaudiostream(v)
                stream_url = s.url
                retrying = false
            end

            # test whether the url can be accessed normally
            headers = nyasHttp.head(nyasTube.req_opts, stream_url)
            file_size = parse(Int, HTTP.header(headers, "content-length"))

            file_path = joinpath(top_level, sub_dir, file_name)
            return downloadfunc(stream_url, file_path, file_size; threads)

        catch err
            err isa InterruptException || printerror()
            retryornot() || return
            retrying = true
        end
    end
end


function one_audio()
    println("\n <- enter url, exit if no url")
    url = readline()
    isempty(url) && exit()

    info = getdownloadinfo(url)
    info ≡ nothing && return
    trydownload(url, info...)
end

while true
    one_audio()
    print("\033c")
end