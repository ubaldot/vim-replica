@echo off

REM Script to run the unit-tests for the replica Vim plugin on MS-Windows

SETLOCAL
SET VIMPRG=vim.exe
SET VIMRC=vimrc_for_tests
SET VIM_CMD="%VIMPRG% -u %VIMRC% -U NONE -i NONE --noplugin -N --not-a-term -es"

echo Running Vim command...
echo %VIM_CMD%
%VIM_CMD% -c "vim9cmd g:TestName='test_replica.vim'" -S runner.vim > vim_output.log 2>&1

REM Wait for 60 seconds for Vim to finish, then force close if still running
TIMEOUT /T 60 /NOBREAK
TASKLIST /FI "IMAGENAME eq vim.exe" 2>NUL | FIND /I /N "vim.exe" >NUL
IF "%ERRORLEVEL%"=="0" (
    echo Vim is still running. Terminating...
    TASKKILL /F /IM vim.exe
)

echo VIM-REPLICA unit test results
type results.txt

findstr /I FAIL results.txt > nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ERROR: Some test failed.
    exit /b 1
) else (
    echo SUCCESS: All the tests passed.
    exit /b 0
)
