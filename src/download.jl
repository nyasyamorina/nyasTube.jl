import ..nyasTube: req_opts

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

function downloadfile(url, file_path, file_size; threads = 1)
    threads == 1 && return _single_thread_download(url, file_path, file_size)
    return _multi_threads_download(url, file_path, file_size; threads)
end

function _single_thread_download(url, file_path, file_size)
    # rewrited from `HTTP.download`
    nyasHttp.open(req_opts, :GET, url) do stream
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

function _spawn_download_task(file, url, start_bytes, stop_bytes, downloaded_bytes_ref)
    return Threads.@spawn begin
        headers = ["range" => "bytes=$start_bytes-$stop_bytes"]
        nyasHttp.open(req_opts, :GET, url, headers) do stream
            @debug "start downloading bytes from $start_bytes to $stop_bytes..."
            response = HTTP.startread(stream)

            open(file; append = true) do file
                seek(file, start_bytes)
                # If the connection is accidentally disconnected,
                # the task will fall into the infinite loop in `eof(::SSLStream)` and cannot return.
                # Report to `HTTP.jl` or `OpenSSL.jl` is needed.
                while ~eof(stream)
                    downloaded_bytes_ref[] += write(file, readavailable(stream))
                end
            end

            @debug "downloading bytes from $start_bytes to $stop_bytes is done."
        end
        nothing # https://github.com/JuliaLang/julia/issues/40626
    end
end

mutable struct DownloadTask
    file::String
    url::String
    start_bytes::Int
    stop_bytes::Int
    downloaded_bytes::Vector{Int}
    tasks::Vector{Task}
    last_update_bytes::Int
    last_update_time::Float64

    function DownloadTask(file, url, start_bytes, stop_bytes)
        downloaded_bytes = Int[0]
        task = _spawn_download_task(file, url, start_bytes, stop_bytes, Ref(downloaded_bytes, 1))
        return new(file, url, start_bytes, stop_bytes, downloaded_bytes, [task], 0, time())
    end
end
stoptask(task::DownloadTask) = istaskdone(workingtask(task)) || schedule(workingtask(task), InterruptException(); error = true)
workingtask(task::DownloadTask) = task.tasks[end]
downloaded_bytes(task::DownloadTask) = task.last_update_bytes
Base.istaskdone(task::DownloadTask) = task.start_bytes + task.last_update_bytes == task.stop_bytes + 1

function check_and_restart_task(task::DownloadTask; time_out = 15.0, max_retries = 4)
    istaskdone(task) && return

    if task.downloaded_bytes[end] ≠ task.last_update_bytes
        # Downloading bytes means that the task does not fall into an infinite loop
        task.last_update_bytes = task.downloaded_bytes[end]
        task.last_update_time = time()
    elseif time() - task.last_update_time > time_out
        # Restart downloading task if the task falls into an infinite loop
        stoptask(task)
        @debug "kiiled downloading task that should stop at bytes $(task.stop_bytes)"
        length(task.tasks) - 1 > max_retries && throw(error("download task faild"))
        start_bytes = task.start_bytes + task.last_update_bytes
        push!(task.downloaded_bytes, task.last_update_bytes)
        bytes_ref = Ref(task.downloaded_bytes, length(task.downloaded_bytes))
        new_task = _spawn_download_task(task.file, task.url, start_bytes, task.stop_bytes, bytes_ref)
        push!(task.tasks, new_task)
    end
end

function _multi_threads_download(url, file_path, file_size; threads)
    avg_size = file_size ÷ threads
    extra_size = file_size - avg_size * threads

    open(file -> seek(file, file_size), file_path; write = true)

    @info "downloading a file with $file_size bytes to \"$file_path\" using $threads threads..."
    download_tasks = map(1:threads) do index
        start = avg_size * (index - 1) + min(extra_size, index - 1)
        stop = start + avg_size + Int(index ≤ extra_size) - 1
        DownloadTask(file_path, url, start, stop)
    end

    try
        p = ProgessBar(file_size)
        # note: for unreasonable reason, `all(t -> istaskdone(t.task), download_tasks)`
        # will also block the main thread if there is a task fall into an infinite loop.
        while p.n < file_size
            sleep(progress_bar_update_time)
            check_and_restart_task.(download_tasks)
            update!(p, sum(downloaded_bytes, download_tasks))
        end
        finish!(p)

    finally
        stoptask.(download_tasks)
        @info map(t -> length(t.tasks), download_tasks)
        @info map(t -> istaskdone.(t.tasks), download_tasks)
    end
    return file_path
end