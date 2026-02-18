import socket
import json
import io
import contextlib
import sys, types
from threading import Thread
from IPython import get_ipython
from IPython.core.interactiveshell import InteractiveShell

HOST = "127.0.0.1"
PORT = 8765
_server_running = True  # global flag


# -------------------------------------------------------------------
# Helper to send JSON-RPC messages over a TCP socket
# -------------------------------------------------------------------
def send_message(conn, data: dict):
    """
    Sends a JSON-RPC message over the socket with Content-Length framing.
    """
    payload = json.dumps(data)
    msg = f"Content-Length: {len(payload.encode('utf-8'))}\r\n\r\n{payload}"
    conn.sendall(msg.encode("utf-8"))


# -------------------------------------------------------------------
# Runtime functions
# -------------------------------------------------------------------
def vim_inspect(conn, expr: str):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        try:
            obj = eval(expr, globals())
            np = sys.modules.get("numpy")
            pd = sys.modules.get("pandas")

            if pd and isinstance(obj, pd.DataFrame):
                print(obj.to_string())
            elif pd and isinstance(obj, pd.Series):
                print(obj.to_string())
            elif np and isinstance(obj, np.ndarray):
                arr = np.asarray(obj)
                sep = "\t"
                if arr.ndim == 1:
                    print(sep.join(map(str, arr)))
                elif arr.ndim == 2:
                    for row in arr:
                        print(sep.join(map(str, row)))
                elif arr.ndim == 3:
                    for i, mat in enumerate(arr):
                        if i > 0:
                            print()
                        for row in mat:
                            print(sep.join(map(str, row)))
            else:
                print(repr(obj))
        except Exception as e:
            print(f"[vim_inspect error] {e!r}")

    send_message(conn, {"method": "vim/inspect", "result": buf.getvalue()})


def vim_whos(conn):
    ip: InteractiveShell | None = get_ipython()
    if ip is None:
        send_message(
            conn,
            {
                "method": "vim/whos",
                "result": "[vim_whos error] Not inside IPython",
            },
        )
        return

    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        try:
            ip.run_line_magic("whos", "")
        except Exception as e:
            print(f"[vim_whos error] {e!r}")

    send_message(conn, {"method": "vim/whos", "result": buf.getvalue()})


def vim_variable_names(conn):
    ip: InteractiveShell | None = get_ipython()
    if ip is None:
        send_message(
            conn,
            {
                "method": "vim/variable_names",
                "result": "[vim_get_variables error] Not inside IPython",
            },
        )
        return

    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        np = sys.modules.get("numpy")
        pd = sys.modules.get("pandas")
        try:
            EXCLUDE_TYPES = (types.ModuleType, types.FunctionType)
            EXCLUDE_NAMES = {
                "In",
                "Out",
                "exit",
                "quit",
                "get_ipython",
                "Token",
                "Prompts",
                "InteractiveShell",
            }

            names = [
                n
                for n, v in ip.user_ns.items()
                if not n.startswith("_")
                and n not in EXCLUDE_NAMES
                and not isinstance(v, EXCLUDE_TYPES)
            ]
            print("\n".join(names))
        except Exception as e:
            print(f"[vim_get_variables error] {e!r}")

    send_message(
        conn, {"method": "vim/variable_names", "result": buf.getvalue()}
    )


# -------------------------------------------------------------------
# Message handling
# -------------------------------------------------------------------
def handle_request(conn, message: dict):
    method = message.get("method")
    params = message.get("params", {})

    if method == "runtime/inspect":
        vim_inspect(conn, params.get("expr", ""))
    elif method == "runtime/whos":
        vim_whos(conn)
    elif method == "runtime/variable_names":
        vim_variable_names(conn)
    elif method == "runtime/exec":
        lines = params.get("lines", [])
        code = "\n".join(lines)
        try:
            exec(code, globals())
        except Exception as e:
            print(f"[vim_exec error] {e!r}")
    elif method == "runtime/shutdown":
        send_message(
            conn, {"method": "result", "result": "Shutting down server"}
        )
        _server_running = False
    else:
        send_message(
            conn, {"method": "error", "result": f"Unknown method: {method}"}
        )


# -------------------------------------------------------------------
# TCP server helpers
# -------------------------------------------------------------------
def read_message(conn):
    """
    Read one JSON-RPC message from a socket using Content-Length framing.
    """
    headers = {}
    buffer = b""
    while b"\r\n\r\n" not in buffer:
        part = conn.recv(1)
        if not part:
            return None
        buffer += part

    header_bytes, remainder = buffer.split(b"\r\n\r\n", 1)
    for line in header_bytes.decode().split("\r\n"):
        key, value = line.split(":", 1)
        headers[key.strip()] = value.strip()

    content_length = int(headers.get("Content-Length", 0))
    body = remainder
    while len(body) < content_length:
        body += conn.recv(content_length - len(body))

    return json.loads(body.decode())


# -------------------------------------------------------------------
# Server entry
# -------------------------------------------------------------------


def start_server():
    global _server_running
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, PORT))
        s.listen()
        print(f"IPython runtime TCP server running on {HOST}:{PORT}")

        # Wait for Vim to connect
        conn, addr = s.accept()
        print(f"Vim connected from {addr}\n")

        try:
            while _server_running:
                message = read_message(conn)
                if message is None:
                    break
                handle_request(conn, message)
        finally:
            conn.close()
            print("Connection closed")

    print("Server stopped")


# Run server in background to keep IPython interactive
server_thread = Thread(target=start_server, daemon=True)
server_thread.start()


# elif cmd == "exec_lines":
#     code = "\n".join(msg["lines"])
#     ip = get_ipython()
#     result_obj = ip.run_cell(code)
#     result = "ok" if result_obj.success else "error"
