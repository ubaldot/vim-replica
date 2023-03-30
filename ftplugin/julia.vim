vim9script

b:ugly_kernel_name = "julia-1.8"
b:ugly_repl_name = 'JULIA'
b:ugly_cell_delimiter = "# %%"
b:ugly_run_command = 'include("' .. g:ugly_tmp_filename .. '")'

match VisualNOS /b:ugly_cell_delimiter/
