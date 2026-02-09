@echo off

REM Script to run the unit-tests for the REPLICA Vim plugin on MS-Windows

SETLOCAL
REM Define the paths and files
SET "VIMPRG=vim.exe"
SET "VIMRC=vimrc_for_tests"
SET VIM_CMD=%VIMPRG% --clean -u "%VIMRC%" -i NONE -N --not-a-term -S "runner.vim"

REM Create or overwrite the vimrc file with the initial setting
(
  echo vim9script
  echo/
  echo set runtimepath+=..
  echo filetype indent plugin on
  echo/
  echo/ g:replica_debug = true
  echo/ g:replica_log_level = 'Error'
  echo/
  echo g:TestFiles = [
  echo 		'test_replica_python.vim',
  echo 		'test_replica_julia.vim',
  echo   ]
) > "%VIMRC%"

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

REM Run Vim with the specified configuration
%VIM_CMD%

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
echo REPLICA unit test results:
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
