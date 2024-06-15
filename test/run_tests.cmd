@echo off

REM Script to run the unit-tests for the TERMDEBUG Vim plugin on MS-Windows

SETLOCAL
SET VIMPRG="vim.exe"
SET VIMRC="vimrc_for_tests"
SET VIM_CMD=%VIMPRG% -u %VIMRC% -U NONE -i NONE --noplugin -N --not-a-term

%VIM_CMD% -c "vim9cmd g:TestName='test_replica.vim'" -S runner.vim

echo REPLICA unit test results
type results.txt

findstr /I FAIL results.txt > nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo All tests passed.
) else (
    echo ERROR: Some test failed.
    exit /b 1
)
