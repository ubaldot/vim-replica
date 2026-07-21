$VIMPRG = "vim.exe"
$VIMRC = "vimrc_for_tests"
$LOGGER_DEF_FILE = "logger.vim"

# Create a logger definition file to secure g:logger that will be used in the runner
@'
vim9script

g:logger = g:replica_config.log_filepath

'@ | Out-File -Encoding UTF8 "$LOGGER_DEF_FILE"


# Write vimrc
@'
vim9script

set runtimepath+=..

g:replica_config = {}
g:replica_config.debug = true
g:replica_config.log_level = 'Error'

g:TestFiles = [
    'test_replica_python.vim',
    'test_replica_julia.vim',
    # 'test_replica_r.vim'
]

filetype indent plugin on
'@ | Out-File -Encoding UTF8 $VIMRC

# Check file creation
if (-not (Test-Path $VIMRC)) {
    Write-Error "Failed to create $VIMRC"
    exit 1
}

# Display some info (vimrc + logger)
Get-Content $VIMRC
Write-Output "Logger info:"
Get-Content $LOGGER_DEF_FILE
Write-Output "Starting Vim and executing tests... `n"

    # -ArgumentList "--clean", "-u", $VIMRC, "-i", "NONE", "-N", "--not-a-term", "-S", $LOGGER_DEF_FILE, "-S", "runner.vim" `
# Run Vim
$process = Start-Process `
    -FilePath $VIMPRG `
    -ArgumentList "--clean", "-u", $VIMRC, "-i", "NONE", "-N", "-S", $LOGGER_DEF_FILE, "-S", "runner.vim" `
    -Wait -PassThru

if ($process.ExitCode -ne 0) {
    Write-Error "Vim exited with code $($process.ExitCode)"
    Remove-Item $VIMRC
    exit $process.ExitCode
}


# Check results
Write-Host "REPLICA unit test results:`n"
Get-Content results.txt

if (Select-String -Path results.txt -Pattern "FAIL") {
    Write-Error "Some test failed."
    Remove-Item $VIMRC
    exit 1
} else {
    Write-Host "All tests passed."
}

# Cleanup
Remove-Item $VIMRC
Remove-Item $LOGGER_DEF_FILE -Recurse -Force

exit 0
