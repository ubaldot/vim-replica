import io
import contextlib
import base64

_VIM_SENTINEL_START = "__VIM_PAYLOAD__"
_VIM_SENTINEL_END = "__END__"


def vim_inspect(expr):
    """
    Evaluate `expr` in the current REPL and send its textual
    representation to Vim via stdout using a sentinel + base64 frame.
    """
    buf = io.StringIO()

    with contextlib.redirect_stdout(buf):
        try:
            obj = eval(expr, globals())

            # Optional deps
            try:
                import pandas as pd
            except ImportError:
                pd = None

            try:
                import numpy as np
            except ImportError:
                np = None

            if pd is not None and isinstance(obj, pd.DataFrame):
                print(obj.to_string())
            elif pd is not None and isinstance(obj, pd.Series):
                print(obj.to_string())
            elif np is not None and isinstance(obj, np.ndarray):
                # print(repr(obj))
                for row in obj:
                    print("\t".join(map(str, row)))
            else:
                print(repr(obj))

        except Exception as e:
            print(f"[vim_inspect error] {e!r}")

    payload = base64.b64encode(buf.getvalue().encode("utf-8")).decode("ascii")
    print(f"{_VIM_SENTINEL_START}{payload}{_VIM_SENTINEL_END}")
