@echo off

REM Script to run the unit-tests for the REPLICA Vim plugin on MS-Windows

SETLOCAL
REM Define the paths and files
SET "VIMPRG=vim.exe"
SET "VIMRC=vimrc_for_tests"
SET "VIM_CMD=%VIMPRG% --clean -u %VIMRC% -N --not-a-term"

REM Create or overwrite the vimrc file with the initial setting
echo set runtimepath+=.. > "%VIMRC%"
echo filetype plugin on >> "%VIMRC%"

REM Check if the vimrc file was created successfully
if NOT EXIST "%VIMRC%" (
    echo "ERROR: Failed to create %VIMRC%"
    exit /b 1
)

REM Display the contents of VIMRC (for debugging purposes)
echo/
echo ----- dummy_vimrc content -------
type "%VIMRC%"
echo/

REM Run Vim with the specified configuration and additional commands
SET "TEST_FILES=['test_replica_python.vim', 'test_replica_julia.vim']"
%VIM_CMD% -c "vim9cmd g:TestFiles =  %TEST_FILES%" -S "runner.vim"

REM Check the exit code of Vim command
if %ERRORLEVEL% EQU 0 (
    echo Vim command executed successfully.
) else (
    echo/
    echo ERROR: Vim command failed with exit code %ERRORLEVEL%.
    del %VIMRC%
    exit /b 1
)

REM Check test results
echo REPLICA unit test results
powershell -NoProfile -Command "Get-Content -Encoding UTF8 results.txt"

REM Check for FAIL in results.txt
findstr /I "FAIL" results.txt > nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ERROR: Some test failed.
    del %VIMRC%
    exit /b 1
) else (
    echo All tests passed.
)
echo/

REM Exit script with success
del %VIMRC%
exit /b 0
