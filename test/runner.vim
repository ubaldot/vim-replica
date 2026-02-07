vim9script

# Uncomment for manual tests.
# The global variable g:TestFiles is a list containing all the tests filenames.
# if !exists('g:TestFiles')
# 	g:TestFiles = ['test_replica_python.vim', 'test_replica_julia.vim']
# endif

const test_results_filepath = $'{expand('<sfile>:h')}/results.txt'
delete(test_results_filepath)

def RunTests(test_file: string)
  set nomore
  set debug=beep

	writefile([$'o {test_file}'], test_results_filepath, 'a')

	# Load test functions in memory
	execute $"source {test_file}"
	var read_test_file = readfile(test_file)

	# Get test functions names
	var all_functions = copy(read_test_file)
		->filter('v:val =~ "^def g:"')
		->map("v:val->substitute('^def g:', '', '')")
		->sort()

	# Check is user defined some function name erroneously
	var wrong_test_functions = copy(all_functions)->filter('v:val !~ "^Test_"')
  if !empty(wrong_test_functions)
		writefile([$'WARNING: The following tests are skipped: {wrong_test_functions}'], test_results_filepath, 'a')
		writefile([''], test_results_filepath, 'a')
	endif

	# Pick the good functions
	var test_functions = copy(all_functions)->filter('v:val =~ "^Test_"')
  if empty(test_functions)
    # No tests are found
		writefile([$'No tests are found in {test_file}'], test_results_filepath, 'a')
    return
  endif

	# Execute the test functions
  for test in test_functions
		messages clear
    v:errors = []
		v:errmsg = ''

		exe $'call {test}'

		if !empty(v:errors) || !empty(v:errmsg)
      writefile([$'{test}: FAIL'], test_results_filepath, 'a')
		endif

    if !empty(v:errors)
			writefile(['', 'Assertions errors:', '--------------------'], test_results_filepath, 'a')
      writefile(v:errors, test_results_filepath, 'a')
		endif

		if !empty(v:errmsg)
			writefile(['', 'Other errors log:', '--------------------'], test_results_filepath, 'a')
			writefile(execute('messages')->split("\n"), test_results_filepath, 'a')
		endif

		if empty(v:errors) && empty(v:errmsg)
      writefile([$'{test}: SUCCESS'], test_results_filepath, 'a')
		endif
  endfor
enddef

# To test in stand-alone, remove the try block from the following
for test_file in g:TestFiles
		RunTests(test_file)
    writefile([''], test_results_filepath, 'a')
endfor

qall!

# vim: shiftwidth=2 softtabstop=2 noexpandtab
