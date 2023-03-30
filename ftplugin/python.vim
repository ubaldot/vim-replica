vim9script

# My python custom stuff
b:ugly_kernel_name = "python3"
b:ugly_repl_name = 'IPYTHON'
b:ugly_cell_delimiter = "# %%"
# b:ugly_cell_delimiter = g:ugly_cell_delimiter[&filetype]
b:ugly_run_command = "run -i " .. g:ugly_tmp_filename

match VisualNOS /b:ugly_cell_delimiter/
