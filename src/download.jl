#import 
import .Request: default_requester_p

const KiB = 1000
const KB  = 1024
const MiB = 1000^2
const MB  = 1024^2

const progress_bar_update_time = 1

function downloadfile(url, file_path, file_size; threads = 1, chunck_size = 64KB, req = default_requester_p[])
    #=threads == 1 &&=# return _single_thread_download(url, file_path, file_size; req)
    return _multi_threads_download(url, file_path, file_size; threads, chunck_size, req)
end

function _single_thread_download(url, file_path, file_size; req)
    # rewrited from `HTTP.download`
    HTTP.open(req, :GET, url) do stream
        response = HTTP.startread(stream)
        eof(stream) && return
        HTTP.header(response, "content-encoding") == "gzip" && (stream = HTTP.GzipDecompressorStream(stream))

        open(file_path; write = true) do file
            getted_size = 0
            prev_time = time()

            while ~eof(stream)
                getted_size += write(file, readavailable(stream))

                if time() - prev_time > progress_bar_update_time
                    # TODO: progress bar
                end
            end
        end
    end
end

function _multi_threads_download(url, file_path, file_size; threads, chunck_size, req)
    # TODO:
end