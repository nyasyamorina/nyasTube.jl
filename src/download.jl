import .Utils: header
import .Request: default_requester_p

const KiB = 1000
const KB  = 1024
const MiB = 1000^2
const MB  = 1024^2

const progress_bar_update_time = 1
const spinners = ('◐','◓','◑','◒')
const bar_front_heads = ('▏','▎','▍','▌','▋','▊','▉')

# actually [`ProgressMeter.jl`](https://github.com/timholy/ProgressMeter.jl)
# is not so good for network measurement.

mutable struct ProgessBar
    total::UInt
    bar_length::UInt
    speed_delay::Float64     # see [`update!`](@ref)
    start::UInt64
    io::IO

    showed::Bool
    spinner_index::UInt
    n::UInt
    time::UInt64
    speed::Float64

    function ProgessBar(total, bar_length = 40, speed_delay = 5, io = stderr; show = true, n = 0, current = time_ns())
        p = new(total, bar_length, speed_delay, current, io, false, 1, n, current, 0)
        show && updatescreen(p)
        return p
    end
end

# see also https://www.bilibili.com/read/cv28323254/
function update!(p::ProgessBar, n, current = time_ns(); show = true)
    p.spinner_index = mod(p.spinner_index, length(spinners)) + 1
    Δn = n - p.n
    ΔT = (current - p.time) * 1e-9
    (p.n, p.time) = (n, current)
    beta = exp(-ΔT / p.speed_delay)
    p.speed = p.speed * beta + (Δn / ΔT) * (1 - beta)
    show && updatescreen(p)
    return p
end

function finish!(p::ProgessBar, current = time_ns(); show = true)
    p.spinner_index = 0
    p.n = p.total
    p.time = current
    if show 
        updatescreen(p)
        println(p.io)
    end
    return p
end

function updatescreen(p::ProgessBar)
    p.showed && Utils.clearline(p.io)
    # show the spinner or check mark
    spinner = p.spinner_index == 0 ? '✓' : spinners[p.spinner_index]
    print(p.io, ' ', spinner, ' ')
    # show the bar
    if p.bar_length ≠ 0
        print(p.io, '|')
        bar_len = p.bar_length * (p.n / p.total)
        solid_len = trunc(Int, bar_len)
        print(p.io, repeat('█', solid_len))
        if solid_len ≠ p.bar_length
            front_index = trunc(Int, length(bar_front_heads) * (bar_len - solid_len)) + 1
            print(p.io, bar_front_heads[front_index])
            print(p.io, repeat(' ', p.bar_length - solid_len - 1))
        end
        print(p.io, "| ")
    end
    if p.spinner_index == 0
        # show total size
        print(p.io, "total: ", Utils.prettyunit(p.total), "B ")
        # show total time
        print(p.io, "in ", Utils.prettytime((p.time - p.start) * 1e-9))
    else
        # show speed
        print(p.io, "speed: ", Utils.prettyunit(p.speed), "B/s ")
        # show time remaining
        eta = (p.total - p.n) / p.speed
        eta_str = eta > 24 * 3600 ? "∞" : Utils.prettytime(eta)
        print(p.io, "ETA: ", eta_str)
    end
    
    p.showed = true
    return p
end

function downloadfile(url, file_path, file_size; threads = 1, chunck_size = 64KB, req = default_requester_p[])
    threads == 1 && return _single_thread_download(url, file_path, file_size; req)
    return _multi_threads_download(url, file_path, file_size; threads, chunck_size, req)
end

function _single_thread_download(url, file_path, file_size; req)
    # rewrited from `HTTP.download`
    HTTP.open(req, :GET, url) do stream
        response = HTTP.startread(stream)
        eof(stream) && return

        open(file_path; write = true) do file
            @info "downloading a file of size $file_size bytes to \"$file_path\"..."
            getted_size = 0
            prev_time = time()

            p = ProgessBar(file_size)
            while ~eof(stream)
                getted_size += write(file, readavailable(stream))

                if time() - prev_time > progress_bar_update_time
                    update!(p, getted_size)
                    prev_time = time()
                end
            end
            finish!(p)
        end
    end
    return file_path
end

function _multi_threads_download(url, file_path, file_size; threads, chunck_size, req)
    avg_size = file_size ÷ threads
    extra_size = file_size - avg_size * threads
    getted_sizes = zeros(UInt, threads)

    @info "downloading a file of size $file_size bytes to \"$file_path\" using $threads threads..."
    download_tasks = map(1:threads) do index
        @task begin
            start = avg_size * (index - 1) + min(extra_size, index - 1)
            stop = start + avg_size + Int(index ≤ extra_size) - 1

            @debug "strart download task $index from bytes $start to $stop..."
            headers = header("range" => "bytes=$start-$stop")
            HTTP.open(req, :GET, url; headers) do stream
                response = HTTP.startread(stream)

                # TODO: download directly into one file instead of
                # downloading into multiple files and then merge them
                open(joinpath(cache_dir, "$index.dat"); write = true) do dat
                    while ~eof(stream)
                        getted_sizes[index] += write(dat, readavailable(stream))
                    end
                end
            end
            @debug "download task $index done"
        end
    end

    p = ProgessBar(file_size)
    schedule.(download_tasks)
    while ~all(istaskdone.(download_tasks))
        sleep(1)
        update!(p, sum(getted_sizes))
    end
    finish!(p)

    open(file_path; write = true) do file
        for index ∈ 1:threads
            dat_file = joinpath(cache_dir, "$index.dat")
            open(dat_file) do dat
                write(file, read(dat))  # heavy memory use
            end
            rm(dat_file)
        end
    end
    return file_path
end