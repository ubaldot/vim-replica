@echo off

REM Script to run the unit-tests for the TERMDEBUG Vim plugin on MS-Windows

SETLOCAL
SET VIMPRG="vim.exe"
SET VIMRC="vimrc_for_tests"
SET VIM_CMD=%VIMPRG% -u %VIMRC% -U NONE -i NONE --noplugin -N --not-a-term

REM Run Vim command with unit test configuration
%VIM_CMD% -c "vim9cmd g:TestName='test_replica.vim'" -S runner.vim

REM Check the exit code of Vim command
if %ERRORLEVEL% EQU 0 (
    echo Vim command executed successfully.
) else (
    echo ERROR: Vim command failed with exit code %ERRORLEVEL%.
    exit /b 1
)

REM Check test results
echo REPLICA unit test results
type results.txt

REM Check for FAIL in results.txt
findstr /I "FAIL" results.txt > nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ERROR: Some test failed.
    exit /b 1
) else (
    echo All tests passed.
)

REM Exit script with success
exit /b 0
