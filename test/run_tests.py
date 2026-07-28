#!/usr/bin/env python3
"""
Cross-platform test harness for vim-replica.
Replaces run_tests.sh / run_tests.ps1.

Usage:
    python run_tests.py        # local run (keeps results.txt on failure)
    python run_tests.py ci     # CI mode: non-zero exit + full cleanup on failure
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

# ── Plugin configuration (only this section differs across plugins) ───────────

PLUGIN_NAME = "vim-replica"

VIMRC_PREAMBLE = """\
vim9script

set runtimepath+=..

g:replica_config = {}
g:replica_config.debug = true
g:replica_config.log_level = 'Error'
g:replica_config.display_variables = 'vsplit'

filetype indent plugin on
"""

# Platform-specific test files: ps1 on Windows, sh/zsh on Unix.
TEST_FILES: list[str] = [
    "test_replica_python.vim",
    "test_replica_julia.vim",
    "test_replica_r.vim",
] + (
    ["test_replica_ps1.vim"]
    if sys.platform == "win32"
    else ["test_replica_sh.vim", "test_replica_zsh.vim"]
)

# Extra files written *and cleaned up* by this script {filename: content}.
# logger.vim must be sourced after the vimrc (which defines g:replica_config)
# so that g:logger is set from g:replica_config.log_filepath once the plugin loads.
EXTRA_FILES: dict[str, str] = {
    "logger.vim": """\
vim9script

g:logger = g:replica_config.log_filepath
""",
}

# Vim flags placed between the executable and '-u VIMRC'.
VIM_FLAGS: list[str] = ["--clean", "-i", "NONE", "-N", "--not-a-term"]

# Extra '-S <file>' arguments sourced before runner.vim (relative to test/).
EXTRA_SOURCE: list[str] = ["logger.vim"]

# ── Harness (identical across all plugins – do not edit) ──────────────────────

_RESULTS = "results.txt"
_VIMRC   = "vimrc_for_tests"
_ANSI    = re.compile(r"\x1b\[[0-9;]*m")
_SEP     = "-" * 50


def _find_vim() -> str:
    for var in ("VIMPRG", "VIM_PRG"):
        if v := os.environ.get(var, "").strip():
            return v
    if found := shutil.which("vim.exe") or shutil.which("vim"):
        return found
    sys.exit("ERROR: vim not found in PATH.  Set VIMPRG or VIM_PRG.")


def _write_vimrc() -> None:
    files_list = "[" + ", ".join(f"'{f}'" for f in TEST_FILES) + "]"
    Path(_VIMRC).write_text(
        VIMRC_PREAMBLE.rstrip("\n") + f"\ng:TestFiles = {files_list}\n",
        encoding="utf-8",
    )


def _write_extra() -> None:
    for name, content in EXTRA_FILES.items():
        Path(name).write_text(content, encoding="utf-8")


def _vim_cmd(vim: str) -> list[str]:
    cmd = [vim, *VIM_FLAGS, "-u", _VIMRC]
    for src in EXTRA_SOURCE:
        cmd += ["-S", src]
    return [*cmd, "-S", "runner.vim"]


def _cleanup(*, keep_results: bool = False) -> None:
    for name in (_VIMRC, *EXTRA_FILES):
        Path(name).unlink(missing_ok=True)
    if not keep_results:
        Path(_RESULTS).unlink(missing_ok=True)


def main() -> int:
    ci = "ci" in sys.argv[1:]
    os.chdir(Path(__file__).parent)

    vim = _find_vim()
    _write_vimrc()
    _write_extra()

    print(f"Vim: {vim}")
    print(f"\n{_SEP}\nvimrc ({_VIMRC}):")
    print(Path(_VIMRC).read_text(encoding="utf-8").rstrip())
    print(f"{_SEP}\n")
    print(f"Running {PLUGIN_NAME} tests...\n")

    try:
        rc = subprocess.run(_vim_cmd(vim), timeout=120).returncode
    except subprocess.TimeoutExpired:
        print("ERROR: Vim timed out (possible infinite loop).")
        _cleanup(keep_results=not ci)
        return 1
    if rc != 0:
        print(f"ERROR: Vim exited with code {rc}.")
        _cleanup(keep_results=not ci)
        return rc

    if not Path(_RESULTS).exists():
        print("ERROR: results.txt not found – Vim did not produce output.")
        _cleanup()
        return 1

    text = Path(_RESULTS).read_text(encoding="utf-8", errors="replace")
    stripped = _ANSI.sub("", text)
    passed = "FAIL" not in stripped and all(
        f"o {f}" in stripped for f in TEST_FILES
    )

    print(f"{PLUGIN_NAME} unit test results:\n{_SEP}")
    print(text.rstrip())
    print(_SEP)

    if passed:
        print("SUCCESS: All tests passed.")
        _cleanup()
        return 0

    print("ERROR: Some tests failed.")
    _cleanup(keep_results=not ci)
    return 1


if __name__ == "__main__":
    sys.exit(main())
