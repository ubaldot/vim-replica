module VimReplica
using Sockets, JSON, Base.Threads, InteractiveUtils, DataFrames

# -------------------------------
# Server configuration
# -------------------------------
const _HOST = ip"127.0.0.1"
const _PORT = 8765
const _server_running = Ref(true)
const _initial_vars = Set(Core.eval(Main, :(names(Main, all=true))))
# -------------------------------
# Helper to send JSON-RPC messages to Vim
# -------------------------------
function send_lsp(conn::TCPSocket, data::Dict)
  payload = JSON.json(data)
  payload_bytes = codeunits(payload)  # UTF-8 bytes
  header = "Content-Length: $(length(payload_bytes))\r\n\r\n"
  write(conn, header)                  # header is ASCII, fine
  write(conn, payload_bytes)           # write UTF-8 bytes explicitly
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
function vim_whos_vairnfo(conn::TCPSocket, id::Int, params::Dict)
  entries = ["aaa", "bbb"]

  # println(Core.eval(Main, :(varinfo(Main; all=true))))
    # if v in Core.eval(Main, :(varinfo(Main; all=true)))
    #   println("v.content: " , v)
    #   # push!(entries, v.content)
    # end
    send_lsp(conn, Dict("jsonrpc"=>"2.0", "id"=>id, "result"=>entries))
end

function vim_whos(conn::TCPSocket, id::Int, params::Dict)
    entries = String[]

    all_vars = Core.eval(Main, :(names(Main, all=true)))
    try
        # Iterate over all names in Main
        for name in all_vars
            # Skip builtin modules and internal names
            if !(name in _initial_vars)

                # Safely get runtime value
                val_repr = try
                    v = Core.eval(Main, :(getfield(Main, $(QuoteNode(name)))))

                    # Summarize objects cleanly
                    if v isa AbstractArray
                        "$(typeof(v)) of size $(size(v))"
                    elseif typeof(v) <: DataFrames.DataFrame
                        "DataFrame with $(nrow(v)) rows × $(ncol(v)) cols"
                    elseif v isa String
                        # optionally truncate very long strings
                        length(v) > 50 ? "$(v[1:50])…" : v
                    else
                        repr(v)  # scalar or small object
                    end
                catch e
                    "[error getting value]"
                end

                push!(entries, "$name = $val_repr")
            end
        end
    catch e
        push!(entries, "[vim_whos error] $e")
    end

    send_lsp(conn, Dict("jsonrpc"=>"2.0", "id"=>id, "result"=>entries))
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
            msg === nothing && break   # client closed connection
            id = get(msg, "id", 0)
            method = get(msg, "method", "")
            params_raw = get(msg, "params", Dict())
            params = isa(params_raw, JSON.Object) ? Dict(params_raw) : params_raw
            println("Received method: ", method)
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

  try
    conn = accept(server)
    handle_client(conn,getpeername(conn))
  catch e
    println("Accept error: $e")
  end

  println("Server stopped")
end

# -------------------------------
# Run server in background
# -------------------------------
@async start_server()

# End of module
end
