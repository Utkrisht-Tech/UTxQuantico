// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import os
import term

struct Repl {
mut:
	indent         int
	in_fn          bool
	lines          []string
	temp_lines     []string
	functions_name []string
	functions      []string
}

fn (R mut Repl) checks(line string) bool {
	mut in_string := false
	was_indent := R.indent > 0

	for i := 0; i < line.len; i++ {
		if line[i] == `\'` && (i == 0 || line[i - 1] != `\\`) {
			in_string = !in_string
		}
		if line[i] == `{` && !in_string {
			R.indent++
		}
		if line[i] == `}` && !in_string {
			R.indent--
			if R.indent == 0 {
				R.in_fn = false
			}
		}
		if i + 2 < line.len && R.indent == 0 && line[i + 1] == `f` && line[i + 2] == `n` {
			R.in_fn = true
		}
	}
	return R.in_fn || (was_indent && R.indent <= 0) || R.indent > 0
}

fn (R &Repl) function_call(line string) bool {
	for function in R.functions_name {
		if line.starts_with(function) {
			return true
		}
	}
	return false
}

fn repl_help() {
version_hash := verHash()
println('UTxQuantico $Version $version_hash
  help                   Displays this information.
  Ctrl-C, Ctrl-D, exit   Exits the REPL.
  clear                  Clears the screen.
')
}

fn run_repl() []string {
	version_hash := verHash()
	println('UTxQuantico $Version $version_hash')
	println('Use Ctrl-C or `exit` to exit')
	file := '.xQRepl.xq'
	temp_file := '.xQRepl_temp.xq'
	defer {
		os.rm(file)
		os.rm(temp_file)
		os.rm(file.left(file.len - 2))
		os.rm(temp_file.left(temp_file.len - 2))
	}
	mut R := Repl{}
	xQexe := os.args[0]
	for {
		if R.indent == 0 {
			print('>>> ')
		}
		else {
			print('... ')
		}
		mut line := os.get_raw_line()
		if line.trim_space() == '' && line.ends_with('\n') {
			continue
		}
		line = line.trim_space()
		if line.len == -1 || line == '' || line == 'exit' {
			break
		}
		if line == '\n' {
			continue
		}
		if line == 'clear' {
			term.erase_display('2')
			continue
		}
		if line == 'help' {
			repl_help()
			continue
		}
		if line.starts_with('fn') {
			R.in_fn = true
			R.functions_name << line.all_after('fn').all_before('(').trim_space()
		}
		was_fn := R.in_fn
		if R.checks(line) {
			if R.in_fn || was_fn {
				R.functions << line
			}
			else {
				R.temp_lines << line
			}
			if R.indent > 0 {
				continue
			}
			line = ''
		}
		// Save the source only if the user is printing something,
		// but don't add this print call to the `lines` array,
		// so that it doesn't get called during the next print.
		if line.starts_with('print') {
			source_code := R.functions.join('\n') + R.lines.join('\n') + '\n' + line
			os.write_file(file, source_code)
			s := os.exec('$vexe run $file -repl') or {
				cerror(err)
				return []string
			}
			vals := s.output.split('\n')
			for i:=0; i < vals.len; i++ {
				println(vals[i])
			}
		}
		else {
			mut temp_line := line
			mut temp_flag := false
			func_call := r.function_call(line)
			if !(line.contains(' ') || line.contains(':') || line.contains('=') || line.contains(',') || line == '') && !func_call {
				temp_line = 'println($line)'
				temp_flag = true
			}
			temp_source_code := r.functions.join('\n') + r.lines.join('\n') + r.temp_lines.join('\n') + '\n' + temp_line
			os.write_file(temp_file, temp_source_code)
			q := os.exec('$xQexe run $temp_file -repl') or {
				cerror(err)
				return []string
			}
			if !fn_call && !q.exit_code {
				for R.temp_lines.len > 0 {
					if !R.temp_lines[0].starts_with('print') {
						R.lines << R.temp_lines[0]
					}
					R.temp_lines.delete(0)
				}
				R.lines << line
			}
			else {
				for R.temp_lines.len > 0 {
					R.temp_lines.delete(0)
				}
			}
			vals := q.output.split('\n')
			for i:=0; i<vals.len; i++ {
				println(vals[i])
			}
		}
	}
	return R.lines
}
