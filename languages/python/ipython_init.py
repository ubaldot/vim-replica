import socket
import json
import io
import contextlib
import sys, types
from typing import Callable, Any
from threading import Thread
from IPython import get_ipython
from IPython.core.interactiveshell import InteractiveShell

HOST = "127.0.0.1"
PORT = 8765
_server_running = True


# -------------------------------------------------------------------
# Helper to send JSON-RPC messages over a TCP socket
# -------------------------------------------------------------------
def send_response(conn: socket.socket, data: dict):
    """
    REPL->VIM
    Sends a JSON-RPC message over the socket with Content-Length framing.
    """
    payload = json.dumps(data)
    msg = f"Content-Length: {len(payload.encode('utf-8'))}\r\n\r\n{payload}"
    conn.sendall(msg.encode("utf-8"))


# -------------------------------------------------------------------
# Runtime functions
# -------------------------------------------------------------------
def vim_inspect(conn: socket.socket, msg_id: int, params=None):
    buf = io.StringIO()

    variable = params.get("variable", "")

    try:
        with contextlib.redirect_stdout(buf):
            ip: InteractiveShell | None = get_ipython()

            if ip is None:
                vim_error_response(conn, msg_id, -32603, "Not inside IPython")
                return

            obj = ip.user_ns.get(variable)

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

        # SUCCESS RESPONSE
        send_response(
            conn,
            {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": buf.getvalue(),
            },
        )

    except Exception:
        vim_error_response(conn, msg_id, -32603, "Evaluation failed")


def vim_whos(conn: socket.socket, msg_id: int, params=None):
    ip: InteractiveShell | None = get_ipython()

    if ip is None:
        vim_error_response(conn, msg_id, -32603, "Not inside IPython")
        return

    buf = io.StringIO()

    try:
        with contextlib.redirect_stdout(buf):
            ip.run_line_magic("whos", "")

        # success
        send_response(
            conn,
            {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": buf.getvalue(),
            },
        )

    except Exception:
        vim_error_response(conn, msg_id, -32603, "'whos' execution failed")


def vim_variable_names(conn: socket.socket, msg_id: int, params=None):
    ip: InteractiveShell | None = get_ipython()

    if ip is None:
        vim_error_response(conn, msg_id, -32603, "Not inside IPython")
        return
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

        result = "\n".join(names)

        #  success
        send_response(
            conn,
            {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": result,
            },
        )

    except Exception as e:
        vim_error_response(conn, msg_id, -32603, "Variable listing failed")


def vim_send_cell(conn: socket.socket, msg_id: int, params=None):
    """
    This is used for sending lines, cells and files.

    Upstream, everything is converted to a list of strings that can be
    interpreted as list of strings.
    """
    ip: InteractiveShell | None = get_ipython()

    if ip is None:
        vim_error_response(conn, msg_id, -32603, "Not inside IPython")
        return
    else:
        code = params.get("lines", "")
        if isinstance(code, list):
            code = "\n".join(code)

        result_obj = ip.run_cell(code)

        if msg_id is not None and result_obj.success:
            send_response(
                conn,
                {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": f"{params.get('type')}: success",
                },
            )
        elif msg_id is not None and not result_obj.success:
            vim_error_response(
                conn, msg_id, -32601, f"{params.get('type')} failed"
            )


def vim_server_shutdown(conn: socket.socket, msg_id: int, params=None):
    global _server_running
    _server_running = False

    if msg_id is not None:
        send_response(
            conn,
            {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": "Shutting down server",
            },
        )


def vim_error_response(conn: socket.socket, msg_id: int, code, message):
    if msg_id is not None:
        send_response(
            conn,
            {
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {
                    "code": code,
                    "message": message,
                },
            },
        )


# -------------------------------------------------------------------
# Message handling
# -------------------------------------------------------------------
HandlerType = Callable[[socket.socket, int, dict[Any, Any] | None], None]
METHODS: dict[str, HandlerType] = {
    "runtime/vim_inspect": vim_inspect,
    "runtime/vim_whos": vim_whos,
    "runtime/vim_variable_names": vim_variable_names,
    "runtime/vim_send_cell": vim_send_cell,
    "runtime/vim_shutdown": vim_server_shutdown,
}


def handle_request(conn: socket.socket, message: Any):
    global _server_running

    try:
        message.get("jsonrpc") == "2.0"
        msg_id = message.get("id")
        method = message.get("method")
        params = message.get("params", {})

        # --- Dispatch ---
        handler = METHODS.get(method)  # type: ignore

        if handler is not None:
            # Call the handler
            handler(conn, msg_id, params)
        else:
            vim_error_response(
                conn, msg_id, -32601, f"Method not found: {method}"
            )
            return

    except Exception as e:
        vim_error_response(
            conn, msg_id, -32603, f"Internal server error: {repr(e)}"
        )


# -------------------------------------------------------------------
# TCP server helpers
# -------------------------------------------------------------------
def read_message(conn: socket.socket):
    """
    VIM->REPL
    Read one JSON-RPC message from a socket using Content-Length framing.
    """
    headers = {}
    buffer = b""
    while b"\r\n\r\n" not in buffer:
        part = conn.recv(4096)
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
