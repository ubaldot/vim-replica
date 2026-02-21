using Sockets, JSON, Base.Threads, InteractiveUtils

# -------------------------------
# Server configuration
# -------------------------------
const _HOST = ip"127.0.0.1"
const _PORT = 8765
const _server_running = Ref(true)

# -------------------------------
# Helper to send JSON-RPC messages to Vim
# -------------------------------
function send_lsp_old(conn::TCPSocket, data::Dict)
    payload = JSON.json(data)
    msg = "Content-Length: $(sizeof(payload))\r\n\r\n$payload"
    write(conn, msg)
    flush(conn)
end
function send_lsp(conn::TCPSocket, data::Dict)
    payload = JSON.json(data)
    payload_bytes = codeunits(payload)  # UTF-8 bytes
    header = "Content-Length: $(length(payload_bytes))\r\n\r\n"
    write(conn, header)                  # header is ASCII, fine
    write(conn, payload_bytes)           # write UTF-8 bytes explicitly
    open("debug.log","a") do f
      println(f, "Sending payload: ", payload)
    end
    flush(conn)
end
# -------------------------------
# Handlers
# -------------------------------
function vim_inspect(conn::TCPSocket, id::Int, params::Dict)
    variable = get(params, "variable", "")
    try
        obj = try
            eval(Main, Meta.parse(variable))
        catch e
            send_lsp(conn, Dict(
                "jsonrpc"=>"2.0",
                "id"=>id,
                "error"=>Dict("code"=>-32603,"message"=>"Evaluation failed: $e")
            ))
            return
        end

        # Convert object to a Vim-compatible type
        result = if obj isa AbstractArray
            obj isa AbstractMatrix ? [join(row, "\t") for row in eachrow(obj)] : collect(obj)
        else
            string(obj)
        end

        send_lsp(conn, Dict("jsonrpc"=>"2.0","id"=>id,"result"=>result))

    catch e
        send_lsp(conn, Dict(
            "jsonrpc"=>"2.0",
            "id"=>id,
            "error"=>Dict("code"=>-32603,"message"=>"Evaluation failed: $e")
        ))
    end
end

function vim_whos(conn::TCPSocket, id::Int, params::Dict)
    entries = []
    for n in names(Main, all=true)
        v = getfield(Main, n)
        if !startswith(string(n), "_") && !(v isa Function) && !(v isa Module)
            push!(entries, Dict("name"=>string(n), "value"=>string(v)))
        end
    end
    send_lsp(conn, Dict("jsonrpc"=>"2.0","id"=>id,"result"=>entries))
end

function vim_variable_names(conn::TCPSocket, id::Int, params::Dict)
    names_list = [string(n) for n in names(Main, all=true) if !startswith(string(n), "_")]
    send_lsp(conn, Dict("jsonrpc"=>"2.0","id"=>id,"result"=>sort(names_list)))
end

function vim_send_cell(conn::TCPSocket, id::Int, params::Dict{String,Any})
    lines = get(params, "lines", [])
    code = isa(lines, Vector) ? join(lines, "\n") : string(lines)

    try
        # Evaluate entire code in Main's global scope
        include_string(Main, code)

        send_lsp(conn, Dict(
            "jsonrpc" => "2.0",
            "id"      => id,
            "result"  => "$(get(params, "type", "cell")): executed successfully"
        ))
    catch e
        send_lsp(conn, Dict(
            "jsonrpc" => "2.0",
            "id"      => id,
            "error"   => Dict("code"=>-32603, "message"=>"Execution failed: $e")
        ))
    end
end

# -------------------------------
# Method dispatch table
# -------------------------------
const METHODS = Dict(
    "runtime/vim_inspect"=>vim_inspect,
    "runtime/vim_whos"=>vim_whos,
    "runtime/vim_variable_names"=>vim_variable_names,
    "runtime/vim_send_cell"=>vim_send_cell,
    # "runtime/vim_shutdown"=>vim_shutdown,
)

# -------------------------------
# Read LSP HTTP-style framed message
# -------------------------------
function read_lsp(conn::TCPSocket)
    headers = Dict{String,String}()
    buffer = UInt8[]

    # --- read header until CRLF CRLF ---
    while true
        b_vec = read(conn, 1)
        isempty(b_vec) && return nothing  # connection closed
        push!(buffer, b_vec[1])
        if length(buffer) >= 4 && buffer[end-3:end] == UInt8[13,10,13,10]  # \r\n\r\n
            break
        end
    end

    # decode header safely
    header_str = String(buffer)  # ASCII / UTF-8
    for line in split(header_str, "\r\n")
        isempty(strip(line)) && continue
        occursin(":", line) || continue
        k, v = split(line, ":"; limit=2)
        headers[strip(k)] = strip(v)
    end

    # --- read body ---
    content_length = parse(Int, get(headers, "Content-Length", "0"))
    body_bytes = read(conn, content_length)        # read exactly content_length bytes
    body_str = String(body_bytes)                  # decode UTF-8
    return JSON.parse(body_str)                    # parse JSON
end

# -------------------------------
# Client handler
# -------------------------------
function handle_client(conn::TCPSocket, addr)
    println("Vim connected from $addr")
    try
        while _server_running[]
            msg = read_lsp(conn)
            msg === nothing && break
            id = get(msg, "id", 0)
            method = get(msg, "method", "")
            params_raw = get(msg, "params", Dict())
            params = isa(params_raw, JSON.Object) ? Dict(params_raw) : params_raw

            println("method: ", method)
            println("params: ", params)

            handler = get(METHODS, method, nothing)
            if handler === nothing
                send_lsp(conn, Dict(
                    "jsonrpc" => "2.0",
                    "id"      => id,
                    "error"   => Dict("code"=>-32601, "message"=>"Method not found: $method")
                ))
            else
                handler(conn, id, params)
            end
        end
    catch e
        println("Client error: $e")
    finally
        close(conn)
        println("Connection closed")
    end
end
# -------------------------------
# Server loop
# -------------------------------
function start_server()
    server = listen(_HOST,_PORT)
    println("Julia LSP-style TCP server running on $_HOST:$_PORT")

    while _server_running[]
        try
            conn = accept(server)
            @spawn handle_client(conn,getpeername(conn))
        catch e
            println("Accept error: $e")
        end
    end

    println("Server stopped")
end

# -------------------------------
# Run server in background
# -------------------------------
@spawn start_server()
