module VimReplica
using Sockets, JSON, DataFrames

# -------------------------------
# Server configuration
# -------------------------------
const _HOST = ip"127.0.0.1"
const _PORT = 6969
const _server_running = Ref(true)
const _initial_vars = Set(Core.eval(Main, :(names(Main, all=true))))

# -------------------------------
# Helper to send JSON-RPC messages to Vim
# -------------------------------
function send_response(conn::TCPSocket, data::Dict)
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

      # TODO: may be unsafe
      Core.eval(Main, Meta.parse(variable))
      # eval(Main, Meta.parse(variable))
    catch e
      send_response(conn, Dict(
                          "jsonrpc"=>"2.0",
                          "id"=>id,
                          "error"=>Dict("code"=>-32603,"message"=>"Evaluation failed: $e")
                         ))
      return
    end

    # Convert object to a Vim-compatible type
    result = if obj isa AbstractArray
      obj isa AbstractMatrix ? [join(row, "\t") for row in eachrow(obj)] : collect(obj)
      # split(repr(obj), "\t")
    elseif obj isa DataFrame
      split(repr(obj), "\n")
    else
      # Scalar or other
      [repr(obj)]
    end

    result_str = [string(x) for x in result]
    send_response(conn, Dict("jsonrpc"=>"2.0","id"=>id,"result"=>result_str))

  catch e
    send_response(conn, Dict(
                        "jsonrpc"=>"2.0",
                        "id"=>id,
                        "error"=>Dict("code"=>-32603,"message"=>"Evaluation failed: $e")
                       ))
  end
end

function vim_whos(conn::TCPSocket, id::Int, params::Dict)
  # TODO: you may filter based on _initial_vars
    v = Core.eval(Main, :(varinfo(Main; all=true)))
    entries = split(repr(v), "\n")
    send_response(conn, Dict("jsonrpc"=>"2.0", "id"=>id, "result"=>entries))
end

function vim_variable_names(conn::TCPSocket, id::Int, params::Dict)
  names_list = [string(n) for n in Core.eval(Main, :(names(Main, all=true))) if n ∉ _initial_vars]
  send_response(conn, Dict("jsonrpc"=>"2.0","id"=>id,"result"=>sort(names_list)))
end


function vim_send_cell(conn::TCPSocket, id::Int, params::Dict{String,Any})
  lines = get(params, "lines", [])
  code = isa(lines, Vector) ? join(lines, "\n") : string(lines)

  try
    # Evaluate entire code in Main's global scope
    # TODO: may be unsafe
    include_string(Main, code)

    send_response(conn, Dict(
                        "jsonrpc" => "2.0",
                        "id"      => id,
                        "result"  => "$(get(params, "type", "cell")): executed successfully"
                       ))
  catch e
    send_response(conn, Dict(
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
            # println("Received method: ", method)
            handler = get(METHODS, method, nothing)
            if handler === nothing
                send_response(conn, Dict(
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
