vim9script

# Uncomment for manual tests.
# The global variable g:TestFiles is a list containing all the tests filenames.
 # if !exists('g:TestFiles')
 	# # g:TestFiles = ['test_links.vim', 'test_tables.vim', 'test_regex.vim']
 	# g:TestFiles = ['test_tables.vim']
 # endif

const test_path = expand('<sfile>:h')
delete($'{test_path}/results.txt')

def RunTests(test_file: string)
  set nomore
  set debug=beep

	writefile([$'o {test_file}'], 'results.txt', 'a')

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
	echom "wrong_functions: " .. string(wrong_test_functions)
  if !empty(wrong_test_functions)
		writefile([$'WARNING: The following tests are skipped: {wrong_test_functions}'], 'results.txt', 'a')
		writefile([''], 'results.txt', 'a')
	endif

	# Pick the good functions
	var test_functions = copy(all_functions)->filter('v:val =~ "^Test_"')
	echom "test_functions: " .. string(test_functions)
  if test_functions->empty()
    # No tests are found
		writefile([$'No tests are found in {test_file}'], 'results.txt', 'a')
    return
  endif

	# Execute the test functions
  # writefile(['Executed test:'], 'results.txt', 'a')
  for test in test_functions
    try
      :%bw!
      exe $'call {test}'
    catch
			# In a catch block v:exception is written instead of v:errmsg
			writefile(['FAIL', '--------------------'], 'results.txt', 'a')
			writefile([v:throwpoint], 'results.txt', 'a')
			writefile([v:exception, ''], 'results.txt', 'a')

			break
    endtry

		writefile([$'{test}: pass'], 'results.txt', 'a')

  endfor
enddef

# To test in stand-alone, remove the try block from the following
for test_file in g:TestFiles
	RunTests(test_file)
	writefile([''], 'results.txt', 'a')
endfor

qall!

# vim: shiftwidth=2 softtabstop=2 noexpandtab
