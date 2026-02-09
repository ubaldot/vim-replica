vim9script

# Uncomment for manual tests.
# The global variable g:TestFiles is a list containing all the tests filenames.
# if !exists('g:TestFiles')
# 	g:TestFiles = ['test_replica_python.vim', 'test_replica_julia.vim']
# endif

const RED = "\033[31m"
const GREEN = "\033[32m"
const END = "\033[0m"

const base_path = $'{expand('<sfile>:h:h')}'
const test_results_filepath = $'{base_path}/test/results.txt'

delete(test_results_filepath)

const logfile = g:replica_log_filepath
delete(logfile)

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

		try
			silent! exe $'call {test}'
		catch
			# From test assertions
			writefile([$'{test}: {RED}FAIL{END}'], test_results_filepath, 'a')
			writefile(['', 'Assertions errors:', '--------------------'], test_results_filepath, 'a')
			writefile([v:exception], test_results_filepath, 'a')
			# echoerr, throw and errors, always populate :messages. Hence, when an
			# error is thrown, it is always good idea to check :messages

			# From eventual loggers. g:logfile shall be set from the .vimrc used in
			# test
			if exists('logfile') && filereadable(logfile)
				const log = readfile(logfile)
				if !empty(log)
					writefile(['', 'Logged errors:', '--------------------'], test_results_filepath, 'a')
					writefile(log, test_results_filepath, 'a')
				endif
			endif

			# From :messages
			writefile(['', 'Other errors log:', '--------------------'], test_results_filepath, 'a')
			writefile(execute('messages')->split("\n"), test_results_filepath, 'a')
			break
		endtry

		writefile([$'{test}: {GREEN}OK{END}'], test_results_filepath, 'a')
	endfor
enddef

# To test in stand-alone, remove the try block from the following
for test_file in g:TestFiles
	RunTests(test_file)
	writefile([''], test_results_filepath, 'a')
endfor

delete(logfile)
qall!

# vim: shiftwidth=2 softtabstop=2 noexpandtab
