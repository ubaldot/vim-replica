import io
import contextlib
import base64
import sys, types

# import time
from IPython import get_ipython
from IPython.core.interactiveshell import InteractiveShell
from IPython.terminal.prompts import Prompts, Token

_VIM_SENTINEL_START = "__VIM_PAYLOAD__"
_VIM_SENTINEL_END = "__END__"


def __vim_change_prompt(prompt: str) -> None:
    ip: InteractiveShell | None = get_ipython()
    if ip is None:
        raise RuntimeError("Not running inside IPython")

    class CustomPrompt(Prompts):
        def in_prompt_tokens(self, cli=None):
            return [(Token.Prompt, prompt)]

    ip.prompts = CustomPrompt(ip)  # type: ignore


def __vim_inspect(expr: str):
    """
    Evaluate `expr` in the current REPL and send its textual
    representation to Vim via stdout using a sentinel + base64 frame.

    OBS! The payload shall finish with \n
    """
    buf = io.StringIO()

    with contextlib.redirect_stdout(buf):
        try:
            obj = eval(expr, globals())

            # Optional deps
            np = sys.modules.get("numpy")
            pd = sys.modules.get("pandas")

            if pd is not None and isinstance(obj, pd.DataFrame):
                print(obj.to_string())
            elif pd is not None and isinstance(obj, pd.Series):
                print(obj.to_string())
            elif np is not None and isinstance(obj, np.ndarray):
                # Only display 1D, 2D or 3D ndarray
                arr = np.asarray(obj)
                sep = "\t"

                if arr.ndim == 1:
                    print(sep.join(map(str, arr)))

                if arr.ndim == 2:
                    for row in arr:
                        print(sep.join(map(str, row)))

                elif arr.ndim == 3:
                    for i, mat in enumerate(arr):
                        if i > 0:
                            print()  # separate slices
                        for row in mat:
                            print(sep.join(map(str, row)))

            else:
                print(repr(obj))

        except Exception as e:
            print(f"[vim_inspect error] {e!r}")

    payload = base64.b64encode(buf.getvalue().encode("utf-8")).decode("ascii")
    # Note that the payload is always on one-line.
    # If you start dealing with extremely long payloads, consider splitting
    # payload in smaller chunks (see commented lines below)
    print(f"{_VIM_SENTINEL_START}{payload}{_VIM_SENTINEL_END}")

    # For testing multi-line payloads
    # print(_VIM_SENTINEL_START + payload[:200])
    # time.sleep(0.1)
    # print(payload[200:400])
    # time.sleep(0.1)
    # print(payload[400:] + _VIM_SENTINEL_END)


def __vim_whos():
    """
    Run `%whos` in the current IPython session and send its textual
    output to Vim via stdout using a sentinel + base64 frame.

    OBS! The payload shall finish with \n
    """

    ip: InteractiveShell | None = get_ipython()
    if ip is None:
        print("[vim_whos error] Not running inside IPython")
        return

    buf = io.StringIO()

    with contextlib.redirect_stdout(buf):
        try:
            ip.run_line_magic("whos", "")
        except Exception as e:
            print(f"[vim_whos error] {e!r}")

    payload = base64.b64encode(buf.getvalue().encode("utf-8")).decode("ascii")
    print(f"{_VIM_SENTINEL_START}{payload}{_VIM_SENTINEL_END}")


def __vim_variable_names():
    """
    Return user-defined variable names from the current IPython session,
    excluding modules, functions, and common internals.
    Output is sent to Vim via stdout using a sentinel + base64 frame.

    OBS! The payload shall finish with \n
    """

    ip: InteractiveShell | None = get_ipython()
    if ip is None:
        print("[vim_get_variables error] Not running inside IPython")
        return

    buf = io.StringIO()

    with contextlib.redirect_stdout(buf):
        # Optional deps
        np = sys.modules.get("numpy")
        pd = sys.modules.get("pandas")
        try:
            EXCLUDE_TYPES = (
                types.ModuleType,  # modules
                types.FunctionType,  # functions
            )

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

    payload = base64.b64encode(buf.getvalue().encode("utf-8")).decode("ascii")
    print(f"{_VIM_SENTINEL_START}{payload}{_VIM_SENTINEL_END}")
