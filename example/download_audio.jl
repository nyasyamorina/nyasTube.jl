# just a simple script to download audio to my own OneDrive

using Pkg

const nyasTube_path = dirname(@__DIR__)
Pkg.activate(nyasTube_path)
using nyasHttp, nyasTube, JSON

setoptions!(nyasTube.req_opts; proxy = ENV["nyasProxy"])

const cache_path = joinpath(nyasTube.cache_dir, "channelid_name.json")
channelid_name = if isfile(cache_path)
    JSON.parsefile(cache_path; dicttype = Dict{String, String})
else
    Dict{String, String}()
end

const top_level = joinpath(ENV["OneDrive"], "a/A5MR/ori")

function one_audio()
    println("\n <- enter url")
    url = readline()
    isempty(url) && exit()

    try
        println("\ngetting video information...")
        v = nyasTube.Video(url; client = nyasTube.APIs.WEB)
        cid = nyasTube.channelid(v)
        ss = nyasTube.streams(v)

        filter!(nyasTube.is_dash & nyasTube.has_audio, ss)
        s = sort!(ss; by = nyasTube.audio_quality)[end]
        file_name = nyasTube.filename(s)
        file_size = (nyasTube.filesize(s) ÷ 10^4) / 10^2
        itag = nyasTube.itag(s)

        println("================================")
        println("title: ", title(v))
        println("upload: ", uploaddate(v))
        println("author: ", author(v))
        println("channel id: ", channelid(v))
        println("itag: ", itag, itag == 251 ? "" : "(the itag of the highest audio quality is 251)")
        println("file size: ", file_size, "MB")

        println("\n <- enter file tile [default: $file_name]")
        _file_name = readline()
        isempty(_file_name) || (file_name = nyasTube.Utils.safefilename(_file_name))
        ext = splitext(file_name)[2]
        (isempty(ext) || length(ext) > 4) && (file_name *= s.format)

        sub_dir::String = get(channelid_name, cid, "")
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
            println(" <- enter # of downloading threads [default: 16]")
            sss = readline()
            isempty(sss) && break
            _threads = tryparse(Int, sss)
            _threads ≢ nothing && (threads = _threads; break)
            println("\"$sss\" is not a valid integer")
        end

        println()
        download(s, joinpath(top_level, sub_dir, file_name); threads, force = true)

    catch err
        println()
        for (exc, bt) ∈ current_exceptions()
            showerror(stdout, exc, bt)
            println()
        end
        print("\n press enter to exit...")
        readline()
        exit()
    end
end

while true
    one_audio()
    print("\033c")
end