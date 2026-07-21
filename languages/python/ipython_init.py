import socket
import json
import io
import contextlib
import sys, types
from typing import Callable, Any
from threading import Thread
from IPython import get_ipython  # type: ignore
from IPython.core.interactiveshell import InteractiveShell  # type: ignore

_HOST = "127.0.0.1"
_PORT = 6969
_server_running = True


# -------------------------------------------------------------------
# Helper to send JSON-RPC messages over a TCP socket
# -------------------------------------------------------------------
def __send_response(conn: socket.socket, data: dict):
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
def __vim_inspect(conn: socket.socket, msg_id: int, params=None):
    buf = io.StringIO()

    variable = params.get("variable", "")

    try:
        with contextlib.redirect_stdout(buf):
            ip: InteractiveShell | None = get_ipython()

            if ip is None:
                __vim_error_response(
                    conn, msg_id, -32603, "Not inside IPython"
                )
                return

            try:
                # Evaluate the expression safely in the user namespace
                safe_ns = {
                    k: v
                    for k, v in ip.user_ns.items()
                    if not k.startswith("_")
                }
                obj = eval(variable, {"__builtins__": None}, safe_ns)
            except Exception as e:
                __vim_error_response(
                    conn, msg_id, -32603, f"Evaluation failed: {e}"
                )
                return

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

            elif np and isinstance(obj, np.generic):
                print(obj.item())
            else:
                print(repr(obj))

        # SUCCESS RESPONSE
        __send_response(
            conn,
            {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": buf.getvalue().rstrip("\n").split("\n"),
            },
        )

    except Exception:
        __vim_error_response(conn, msg_id, -32603, "Evaluation failed")


def __vim_whos(conn, msg_id, params=None):
    ip: InteractiveShell | None = get_ipython()
    if ip is None:
        __vim_error_response(conn, msg_id, -32603, "Not inside IPython")
        return

    # --- Filter user_ns ---
    filtered_ns = {}
    for name, val in ip.user_ns.items():
        typname = type(val).__name__
        if (
            not name.startswith("_")  # exclude names starting with _
            and not isinstance(
                val, (types.FunctionType, types.ModuleType, type)
            )  # exclude functions, modules, types
            and not typname.startswith("_")  # exclude private/internal types
        ):
            filtered_ns[name] = val

    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        # Temporarily replace user_ns for %whos
        original_ns = ip.user_ns
        try:
            ip.user_ns = filtered_ns
            ip.run_line_magic("whos", "")
        finally:
            ip.user_ns = original_ns

    __send_response(
        conn,
        {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": buf.getvalue().rstrip("\n").split("\n"),
        },
    )


def __vim_variable_names(conn: socket.socket, msg_id: int, params=None):
    ip: InteractiveShell | None = get_ipython()

    if ip is None:
        __vim_error_response(conn, msg_id, -32603, "Not inside IPython")
        return

    EXCLUDED_TYPES = (types.ModuleType, types.FunctionType, type)
    EXCLUDED_VARS = {"Callable"}

    names = [
        name
        for name, val in ip.user_ns.items()
        if not name.startswith("_")
        and name not in ip.user_ns_hidden
        and name not in EXCLUDED_VARS
        and not isinstance(val, EXCLUDED_TYPES)
    ]

    __send_response(
        conn,
        {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": sorted(names),
        },
    )


def __vim_server_shutdown(conn: socket.socket, msg_id: int, params=None):
    global _server_running
    _server_running = False

    if msg_id is not None:
        __send_response(
            conn,
            {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": ["Shutting down server"],
            },
        )


def __vim_error_response(conn: socket.socket, msg_id: int, code, message):
    if msg_id is not None:
        __send_response(
            conn,
            {
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {
                    "code": code,
                    "message": [message],
                },
            },
        )


# -------------------------------------------------------------------
# Message handling
# -------------------------------------------------------------------
_HandlerType = Callable[[socket.socket, int, dict[Any, Any] | None], None]
_METHODS: dict[str, _HandlerType] = {
    "runtime/vim_inspect": __vim_inspect,
    "runtime/vim_whos": __vim_whos,
    "runtime/vim_variable_names": __vim_variable_names,
    "runtime/vim_shutdown": __vim_server_shutdown,
}


def __validate_jsonrpc(message):
    if not isinstance(message, dict):
        return False
    if message.get("jsonrpc") != "2.0":
        return False
    if "method" not in message:
        return False
    return True


def __handle_request(conn: socket.socket, message: Any):
    global _server_running

    try:
        # -----------------------------
        # JSON-RPC basic validation
        # -----------------------------
        if not __validate_jsonrpc(message):
            __vim_error_response(
                conn, message.get("id"), -32600, "Invalid Request"
            )
            return

        # -----------------------------
        # Extract fields
        # -----------------------------
        msg_id = message.get("id")
        method = message.get("method")
        params = message.get("params", {})

        # -----------------------------
        # Dispatch
        # -----------------------------
        handler = _METHODS.get(method)

        if handler is None:
            __vim_error_response(
                conn, msg_id, -32601, f"Method not found: {method}"
            )
            return

        handler(conn, msg_id, params)

    except Exception as e:
        __vim_error_response(
            conn,
            message.get("id"),
            -32603,
            f"Internal server error: {repr(e)}",
        )


# -------------------------------------------------------------------
# TCP server helpers
# -------------------------------------------------------------------
def __read_message(conn: socket.socket):
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
    for line in header_bytes.decode("utf-8", errors="replace").split("\r\n"):
        line = line.strip()
        if not line:
            continue

        key, sep, value = line.partition(":")
        if not sep:
            continue

        headers[key.strip()] = value.strip()

    content_length = int(headers.get("Content-Length", 0))
    body = remainder
    while len(body) < content_length:
        body += conn.recv(content_length - len(body))

    return json.loads(body.decode())


# -------------------------------------------------------------------
# Server entry
# -------------------------------------------------------------------
def __handle_client(conn: socket.socket, addr):
    print(f"Vim connected from {addr}\n")

    try:
        while _server_running:
            message = __read_message(conn)
            if message is None:
                break
            __handle_request(conn, message)

    except Exception as e:
        print(f"Client error: {e}")

    finally:
        conn.close()
        print("Connection closed\n")


def __start_server():
    global _server_running

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((_HOST, _PORT))
        s.listen()

        print(f"IPython runtime TCP server running on {_HOST}:{_PORT}")

        try:
            conn, addr = s.accept()
        except OSError:
            _server_running = False  # socket closed

        __handle_client(conn, addr)

    print("Server stopped")


# Run server in background to keep IPython interactive
_server_thread = Thread(target=__start_server, daemon=True)
_server_thread.start()
