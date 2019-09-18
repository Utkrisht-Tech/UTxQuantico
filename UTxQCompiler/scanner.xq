// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import os
import StringX

struct Scanner {
mut:
	file_path               string
	text                    string
	pos_x                   int         // x - coordinate of Scanner
	line_no_y               int         // y - coordinate of Scanner
	is_in_string            bool
	dollar_start            bool // for hacky string interpolation TODO simplify
	dollar_end              bool
	is_debug                bool
	line_comment            string
	mline_comment           string
	is_started              bool
	// xQFormatter
	format_out              StringX.Builder
	format_indent           int
	format_line_empty       bool
	prev_tk                 Token
	fn_name 				string // needed for @FN
	should_print_line_on_error bool
}

fn new_scanner(file_path string) &Scanner {
  // Check if file exists
  if !os.file_exists(file_path) {
		cerror('"$file_path" doesn\'t exist')
	}

  // Check if file is readable
	mut raw_text := os.read_file(file_path) or {
		cerror('scanner: failed to open "$file_path"')
		return 0
	}

	// Byte Order Mark Check , See wikipedia for more info
	if raw_text.len >= 3 {
		c_text := raw_text.str

		if c_text[0] == 0xEF && c_text[1] == 0xBB && c_text[2] == 0xBF {
			// skip three BOM bytes
			offset_ln := 3    // length to offset from begin
			raw_text = tos(c_text[offset_ln], xQStrlen(c_text) - offset_ln)
		}
	}

	text := raw_text

	scanner := &Scanner {
		file_path: file_path
		text: text
		format_out: StringX.new_builder(1000)
		should_print_line_on_error: true
	}

	return scanner
}

// TODO remove once multiple return values are implemented
struct ScanRes {
	tk Token
	st string
}

fn scan_res(tk Token, st string) ScanRes {
	return ScanRes{tk, st}
}

fn (sc mut Scanner) identify_name() string {
	start_pos := sc.pos_x
	for {
		sc.pos_x++
		if sc.pos_x >= sc.text.len {
			break
		}
		ch := sc.text[sc.pos_x]
		if !is_name_char(ch) && !ch.is_digit() {
			break
		}
	}
	name := sc.text.substr(start_pos, sc.pos_x)
	sc.pos_x--
	return name
}

fn (sc mut Scanner) identify_hex_number() string {
	start_pos := sc.pos_x
	sc.pos_x += 2 // skip '0x'

	for {
		if sc.pos_x >= sc.text.len {
			break
		}
		ch := sc.text[sc.pos_x]
    if ch.is_digit() {
			if !ch.is_hex_digit() {
				sc.error('malformed hexadecimal constant')
			}
		} else {
			break
		}
		sc.pos_x++
	}
	number := sc.text.substr(start_pos, sc.pos_x)
	sc.pos_x--
	return number
}

fn (sc mut Scanner) identify_oct_number() string {
	start_pos := sc.pos_x
	for {
		if sc.pos_x >= sc.text.len {
			break
		}
		ch := sc.text[sc.pos_x]
		if ch.is_digit() {
			if !ch.is_oct_digit() {
				sc.error('malformed octal constant')
			}
		} else {
			break
		}
		sc.pos_x++
	}
	number := sc.text.substr(start_pos, sc.pos_x)
	sc.pos_x--
	return number
}

fn (sc mut Scanner) identify_dec_number() string {
	start_pos := sc.pos_x

	// scan integer part
	for sc.pos_x < sc.text.len && sc.text[sc.pos_x].is_digit() {
		sc.pos_x++
	}

	// e.g. for 1..9
	// we just return '1' and don't scan '..9'
	if sc.expect('..', sc.pos_x) {
		number := sc.text.substr(start_pos, sc.pos_x)
		sc.pos_x--
		return number
	}

	// scan fractional part
	if sc.pos_x < sc.text.len && sc.text[sc.pos_x] == `.` {
		sc.pos_x++
		for sc.pos_x < sc.text.len && sc.text[sc.pos_x].is_digit() {
			sc.pos_x++
		}
		if !sc.inside_string && sc.pos_x < sc.text.len && sc.text[sc.pos_x] == `f` {
						sc.error('no `f` is needed for floats')
					}
	}

	// scan exponential part
	mut has_exponential_part := false
	if sc.expect('e+', sc.pos_x) || sc.expect('e-', sc.pos_x) {
		exp_start_pos := sc.pos_x += 2
		for sc.pos_x < sc.text.len && sc.text[sc.pos_x].is_digit() {
			sc.pos_x++
		}
		if exp_start_pos == sc.pos_x {
			sc.error('exponent has no digits')
		}
		has_exponential_part = true
	}
  // TODO :- Create an all in one function to scan different no. in one go.
	// error check: 1.23.4, 123.e+3.4
	if sc.pos_x < sc.text.len && sc.text[sc.pos_x] == `.` {
		if has_exponential_part {
			sc.error('exponential part should be integer')
		}
		else {
			sc.error('too many decimal points in number')
		}
	}

	number := sc.text.substr(start_pos, sc.pos_x)
	sc.pos_x--
	return number
}

fn (sc mut Scanner) identify_number() string {
	if sc.expect('0x', sc.pos_x) {
		return sc.identify_hex_number()
	}

	if sc.expect('0.', sc.pos_x) || sc.expect('0e', sc.pos_x) {
		return sc.identify_dec_number()
	}

	if sc.text[sc.pos_x] == `0` {
		return sc.identify_oct_number()
	}

	return sc.identify_dec_number()
}

fn (sc Scanner) line_end() bool {
	mut i := sc.pos_x-1
	for i >= 0 && !sc.text[i].is_white() {
		i--
	}
	for i >= 0 && sc.text[i].is_white() {
		if is_NULL(sc.text[i]) {
			return true
		}
		i--
	}
	return false
}

fn (sc mut Scanner) skip_whitespace() {
	for sc.pos_x < sc.text.len && sc.text[sc.pos_x].is_white() {
		// Count \r\n as one line
		if is_NEWLINE(sc.text[sc.pos_x]) && !sc.expect('\r\n', sc.pos_x-1) {
			sc.line_no_y++
		}
		sc.pos_x++
	}
}

fn (sc mut Scanner) scan() ScanRes {
	if sc.line_comment != '' {
		//sc.fgenln('// LOL "$sc.line_comment"')
		//sc.line_comment = ''
	}
	if sc.is_started {
		sc.pos_x++
	}
	sc.is_started = true
	if sc.pos_x >= sc.text.len {
		return scan_res(.EOF, '')
	}
	// skip whitespace
	if !sc.is_in_string {
		sc.skip_whitespace()
	}
	// End of $var, start next string
	if sc.dollar_end {
		if sc.text[sc.pos_x] == `\'` {
			sc.dollar_end = false
			return scan_res(.STRING, '')
		}
		sc.dollar_end = false
		return scan_res(.STRING, sc.identify_string())
	}
	sc.skip_whitespace()
	// end of file
	if sc.pos_x >= sc.text.len {
		return scan_res(.EOF, '')
	}
	// handle each char
	ch := sc.text[sc.pos_x]
	mut nextch := `\0`
	if sc.pos_x + 1 < sc.text.len {
		nextch = sc.text[sc.pos_x + 1]
	}
	// name or keyword
	if is_name_char(ch) {
		name := sc.identify_name()
		// tmp hack to detect . in ${}
		// Check if not .eof to prevent panic
		next_char := if sc.pos_x + 1 < sc.text.len { sc.text[sc.pos_x + 1] } else { `\0` }
		if is_key(name) {
			return scan_res(key_to_token(name), '')
		}
		// 'asdf $b' => "b" is the last name in the string, dont start parsing string
		// at the next ', skip it
		if sc.is_in_string {
			if next_char == `\'` {
				sc.dollar_end = true
				sc.dollar_start = false
				sc.inside_string = false
			}
		}
		if sc.dollar_start && next_char != `.` {
			sc.dollar_end = true
			sc.dollar_start = false
		}
		if sc.pos_x == 0 && next_char == ` ` {
			sc.pos_x++
			//If a single letter name at the start of the file, increment
			//Otherwise the scanner would be stuck at sc.pos = 0
		}
		return scan_res(.NAME, name)
	}
	// `123`, `.123`
	else if ch.is_digit() || (ch == `.` && nextch.is_digit()) {
		num := sc.identify_number()
		return scan_res(.NUMBER, num)
	}

	// all other tokens
	switch ch {
  case `.`:
  	if nextch == `.` {
  		sc.pos_x++
  		return scan_res(.DOTDOT, '')
  	}
  	return scan_res(.DOT, '')
  case `,`:
		return scan_res(.COMMA, '')
  case `;`:
		return scan_res(.SEMICOLON, '')
  case `:`:
		if nextch == `=` {
			sc.pos_x++
			return scan_res(.DECL_ASSIGN, '')
		}
		else {
			return scan_res(.COLON, '')
		}
  case `{`:
    // Skip { in ${ in strings
    if sc.is_in_string {
      return sc.scan()
    }
    return scan_res(.LCBR, '')
  case `}`:
    // sc = `hello $name !`
    // sc = `hello ${name} !`
    if sc.is_in_string {
      sc.pos_x++
      // TODO To Be Removed
      if sc.text[sc.pos_x] == `\'` {
        sc.is_in_string = false
        return scan_res(.STRING, '')
      }
      return scan_res(.STRING, sc.identify_string())
    }
    else {
      return scan_res(.RCBR, '')
    }
  case `(`:
  	return scan_res(.LPAR, '')
  case `)`:
  	return scan_res(.RPAR, '')
  case `[`:
  	return scan_res(.LSBR, '')
  case `]`:
  	return scan_res(.RSBR, '')
	case `+`:
		if nextch == `+` {
			sc.pos_x++
			return scan_res(.INC, '')
		}
		else if nextch == `=` {
			sc.pos_x++
			return scan_res(.PLUS_ASSIGN, '')
		}
		return scan_res(.PLUS, '')
	case `-`:
		if nextch == `-` {
			sc.pos_x++
			return scan_res(.DEC, '')
		}
		else if nextch == `=` {
			sc.pos_x++
			return scan_res(.MINUS_ASSIGN, '')
		}
		return scan_res(.MINUS, '')
	case `*`:
		if nextch == `*` {
			sc.pos_x++
			return scan_res(.STSTAR, '')
		}
    else if nextch == `=` {
			sc.pos_x++
			return scan_res(.STAR_ASSIGN, '')
		}
		return scan_res(.STAR, '')
  case `%`:
    if nextch == `=` {
      sc.pos_x++
      return scan_res(.PER_ASSIGN, '')
    }
    return scan_res(.PERCENTAGE, '')
	case `^`:
		if nextch == `=` {
			sc.pos_x++
			return scan_res(.XOR_ASSIGN, '')
		}
		return scan_res(.XOR, '')
  case `|`:
    if nextch == `|` {
      sc.pos_x++
      return scan_res(.L_OR, '')
    }
    if nextch == `=` {
      sc.pos_x++
      return scan_res(.OR_ASSIGN, '')
    }
    return scan_res(.PIPE, '')
  case `!`:
    if nextch == `=` {
      sc.pos_x++
      return scan_res(.NOTEQUAL, '')
    }
    else {
      return scan_res(.NOT, '')
    }
  case `~`:
    return scan_res(.BIT_NOT, '')
  case `?`:
  		return scan_res(.QUESTION, '')
  case `&`:
  	if nextch == `=` {
  		sc.pos_x++
  		return scan_res(.AND_ASSIGN, '')
  	}
  	if nextch == `&` {
  		sc.pos_x++
  		return scan_res(.AND, '')
  	}
  	return scan_res(.AMPER, '')
  case `#`:
  	start_pos := sc.pos_x + 1
  	for sc.pos_x < sc.text.len && sc.text[sc.pos_x] != `\n` {
  		sc.pos_x++
  	}
  	sc.line_no_y++
  	if nextch == `!` {
  		// Shebang line (#!) is used as a comment identifier
  		sc.line_comment = sc.text.substr(start_pos + 1, sc.pos_x).trim_space()
  		sc.fgenln('// Shebang line "$sc.line_comment"')
  		return sc.scan()
  	}
  	hash := sc.text.substr(start_pos, sc.pos_x)
  	return scan_res(.HASH, hash.trim_space())
  case `$`:
    return scan_res(.DOLLAR, '')
  case `@`:
    if nextch == `=` {
      sc.pos_x++
      return scan_res(.AT_ASSIGN, '')
    } else {
      sc.pos_x++
      name := sc.identify_name()
	  // @FN => will be substituted with the name of the current UTxQ function
	  // @FILE => will be substituted with the path of the UTxQ source file
	  // @LINE_NO_Y => will be substituted with the UTxQ line number where it appears (as a string)
	  // @COLUMN_X => will be substituted with the column where it appears (as a string).
	  // @VERHASH  => will be substituted with the shortened commit hash of the UTxQCompiler (as a string).
	  // This allows things like this:
	  // println( 'file: ' + @FILE + ' | line: ' + @LINE_NO_Y + ' | column: ' + @COLUMN_X + ' | fn: ' + @FN)
	  // ... useful while debugging/tracing
	  if name == 'FN' { return scan_res(.str, sc.fn_name) }
	  if name == 'FILE' { return scan_res(.str, os.realpath(sc.file_path).replace('\\', '\\\\')) } // escape \
	  if name == 'LINE_NO_Y' { return scan_res(.str, (sc.line_no_y+1).str()) }
	  if name == 'COLUMN_X' { return scan_res(.str, (sc.current_column()).str()) }
	  if name == 'VERHASH' { return scan_res(.str, verHash()) }
      if !is_key(name) {
         return scan_res(.AT, '')
      // sc.error('@ must be used before keywords (e.g. `@type string`)')
      }
      return scan_res(.NAME, name)
    }
	case `\'`:
		return scan_res(.STRING, sc.identify_string())
		// TODO allow double quotes
		// case `""`:
		// return scan_res(.STRING, sc.ident_string())
	case `\``: // ` // apostrophe balance comment. do not remove
		return scan_res(.CHAR, sc.identify_char())
	case `\r`:
		if nextch == `\n` {
			sc.pos_x++
			return scan_res(.NEWLINE, '')
		}
	case `\n`:
		return scan_res(.NEWLINE, '')
  case `=`:
    if nextch == `=` {
      sc.pos_x++
      return scan_res(.EQEQUAL, '')
    }
    else if nextch == `>` {
      sc.pos_x++
      return scan_res(.ARROW, '')
    }
    else {
      return scan_res(.ASSIGN, '')
    }
	case `>`:
		if nextch == `=` {
			sc.pos_x++
			return scan_res(.GREATEREQUAL, '')
		}
		else if nextch == `>` {
			if sc.pos_x + 2 < sc.text.len && sc.text[sc.pos_x + 2] == `=` {
				sc.pos_x += 2
				return scan_res(.RIGHT_SHIFT_ASSIGN, '')
			}
			sc.pos_x++
			return scan_res(.RIGHT_SHIFT, '')
		}
		else {
			return scan_res(.GREATER, '')
		}
	case 0xE2:
		//case `≠`:
		if nextch == 0x89 && sc.text[sc.pos_x + 2] == 0xA0 {
			sc.pos_x += 2
			return scan_res(.NOTEQUAL, '')
		}
		// ⩽
		else if nextch == 0x89 && sc.text[sc.pos_x + 2] == 0xBD {
			sc.pos_x += 2
			return scan_res(.LESSEQUAL, '')
		}
		// ⩾
		else if nextch == 0xA9 && sc.text[sc.pos_x + 2] == 0xBE {
			sc.pos_x += 2
			return scan_res(.GREATEREQUAL, '')
		}
	case `<`:
		if nextch == `=` {
			sc.pos_x++
			return scan_res(.LESSEQUAL, '')
		}
		else if nextch == `<` {
			if sc.pos_x + 2 < sc.text.len && sc.text[sc.pos_x + 2] == `=` {
				sc.pos_x += 2
				return scan_res(.LEFT_SHIFT_ASSIGN, '')
			}
      if sc.pos_x + 2 < sc.text.len && sc.text[sc.pos_x + 2] == `>` {
				sc.pos_x += 2
				return scan_res(.NOTEQUAL, '')
			}
			sc.pos_x++
			return scan_res(.LEFT_SHIFT, '')
		}
		else {
			return scan_res(.LESSER, '')
		}
	case `/`:
		if nextc == `=` {
			sc.pos_x++
			return scan_res(.SLASH_ASSIGN, '')
		}

    // Single Line Comments
		if nextch == `/` {
			start_pos := sc.pos_x + 1
			for sc.pos_x < sc.text.len && sc.text[sc.pos_x] != `\n`{
				sc.pos_x++
			}
			sc.line_no_y++
			sc.line_comment = sc.text.substr(start_pos + 1, sc.pos_x)
			sc.line_comment = sc.line_comment.trim_space()
			sc.fgenln('// ${sc.prev_tk.str()} "$sc.line_comment"')

      // Skip the comment (return the next token)
			return sc.scan()
		}
		// Multiline comments
		if nextch == `*` {
			start_pos := sc.pos_x
			mut nest_count := 1
			// Skip comment
			for nest_count > 0 {
				sc.pos_x++
				if sc.pos_x >= sc.text.len {
					sc.line_no_y--
					sc.error('comment not terminated')
				}
				if sc.text[sc.pos_x] == `\n` {
					sc.line_no_y++
					continue
				}
				if sc.expect('/*', sc.pos_x) {
					nest_count++
					continue
				}
				if sc.expect('*/', sc.pos_x) {
					nest_count--
				}
			}
			sc.pos_x++
			end_pos := sc.pos_x + 1
			sc.mline_comment := sc.text.substr(start_pos, end_pos)
			sc.fgenln(sc.mline_comment)
			// Skip if not in format mode
			return sc.scan()
		}
		return scan_res(.SLASH, '')
	}

	$if windows {
		if ch == `\0` {
			return scan_res(.EOF, '')
		}
	}
	mut message := 'invalid character `${ch.str()}`'
	if ch == `"` {
		message += ', use \' to denote strings'
	}
	sc.error(message)
	return scan_res(.EOF, '')
}

fn (sc &Scanner) find_current_line_start_position() int {
	if sc.pos_x >= sc.text.len { return sc.pos_x }
	mut linestart := sc.pos_x
	for {
		if linestart <= 0  {
			linestart = 1
			break
		}
		if sc.text[linestart] == 10 || sc.text[linestart] == 13 {
			linestart++
			break
		}
		linestart--
	}
	return linestart
}

fn (sc &Scanner) find_current_line_end_position() int {
	if sc.pos_x >= sc.text.len { return sc.pos_x }
	mut lineend := sc.pos_x
	for {
		if lineend >= sc.text.len {
			lineend = sc.text.len
			break
		}
		if sc.text[lineend] == 10 || sc.text[lineend] == 13 {
			break
		}
		lineend++
	}
	return lineend
}

fn (sc &Scanner) current_column() int {
	return sc.pos_x - sc.find_current_line_start_position()
}

fn (sc &Scanner) error(message string) {
	linestart := sc.find_current_line_start_position()
	lineend := sc.find_current_line_end_position()
	column := sc.pos_x - linestart
	if sc.should_print_line_on_error && lineend > linestart {
		line := sc.text.substr( linestart, lineend )
		// The pointerline should have the same spaces/tabs as the offending
		// line, so that it prints the ^ character exactly on the *same spot*
		// where it is needed. That is the reason we can not just
		// use StringX.repeat(` `, column) to form it.
		pointerline := line.clone()
		mut pl := pointerline.str
		for i,c in line {
			pl[i] = ` `
			if i == column { pl[i] = `^` }
			else if c.is_space() { pl[i] = c  }
		}
		println(line)
		println(pointerline)
	}
	fullpath := os.realpath( sc.file_path )
	// The filepath:line:col: format is the default C compiler
	// error output format. It allows editors and IDE's like
	// emacs to quickly find the errors in the output
	// and jump to their source with a keyboard shortcut.
	// Using only the filename leads to inability of IDE/editors
	// to find the source file, when it is in another folder.
	println('${fullpath}:${sc.line_no_y + 1}:${column+1}: $message')
	exit(1)
}

fn (sc Scanner) count_symbol_before(p int, sym byte) int {
  mut count := 0
  for i:=p; i>=0; i-- {
    if sc.text[i] != sym {
      break
    }
    count++
  }
  return count
}

// println('array out of bounds $idx len=$a.len')
// This is really bad. It needs a major clean up
fn (sc mut Scanner) identify_string() string {
	// println("\nidentifyString() at char=", string(sc.text[sc.pos_x]),
	// "chard=", sc.text[sc.pos_x], " pos=", sc.pos_x, "txt=", sc.text[sc.pos_x:sc.pos_x+7])
	mut start_pos := sc.pos_x
	sc.is_in_string = false
	dslash := `\\`
	for {
		sc.pos_x++
		if sc.pos_x >= sc.text.len {
			break
		}
		ch := sc.text[sc.pos_x]
		prevch := sc.text[sc.pos_x - 1]
		// end of string
		if ch == `\'` && (prevch != dslash || (prevch == dslash && sc.text[sc.pos_x - 2] == dslash)) {
			// handle '123\\'  slash at the end
			break
		}
		if ch == `\n` {
			sc.line_no_y++
		}
		// Don't allow \0
		if ch == `0` && sc.pos_x > 2 && sc.text[sc.pos_x - 1] == `\\` {
			sc.error('0 character in a string literal')
		}
		// Don't allow \x00
		if ch == `0` && sc.pos_x > 5 && sc.expect('\\x0', sc.pos_x - 3) {
			sc.error('0 character in a string literal')
		}
		// ${var}
		if ch == `{` && prevch == `$` && sc.count_symbol_before(sc.pos_x-2, `\\`) % 2 == 0 {
			sc.is_in_string = true

			sc.pos_x -= 2     // Make sc.pos_x point to $ at the next step
			break
		}
		// $var
		if (ch.is_letter() || ch == `_`) && prevch == `$` && sc.count_symbol_before(sc.pos_x-2, `\\`) % 2 == 0 {
			sc.is_in_string = true
			sc.dollar_start = true
			sc.pos_x -= 2
			break
		}
	}
	mut literal := ''
	if sc.text[start_pos] == `\'` {
		start_pos++
	}
	mut end_pos := sc.pos_x
	if sc.is_in_string {
		end_pos++
	}
	if start_pos > sc.pos_x{}
	else {
		literal = sc.text.substr(start_pos, end_pos)
	}
	return literal
}

fn (sc mut Scanner) identify_char() string {
	start_pos := sc.pos_x
	dslash := `\\`
	mut len := 0
	for {
		sc.pos_x++
		if sc.pos_x >= sc.text.len {
			break
		}
		if sc.text[sc.pos_x] != dslash {
			len++
		}
		double_slash := sc.expect('\\\\', sc.pos_x - 2)
		if sc.text[sc.pos_x] == `\`` && (sc.text[sc.pos_x - 1] != dslash || double_slash) {
		// ` // apostrophe balance comment. do not remove
			if double_slash {
				len++
			}
			break
		}
	}
	len--
	ch := sc.text.substr(start_pos + 1, sc.pos_x)
	if len != 1 {
		u := ch.ustring()
		if u.len != 1 {
			sc.error('Invalid character literal (more than one character: $len)')
		}
	}
	if ch == '\\`' {
		return '`'
	}
	// Escape a `'` character
	return if ch == '\'' { '\\' + ch } else { ch }
}

fn (sc mut Scanner) peek() Token {
	// save scanner state
	pos := sc.pos_x
	line := sc.line_no_y
	is_in_string := sc.is_in_string
	dollar_start := sc.dollar_start
	dollar_end := sc.dollar_end

	res := sc.scan()
	tk := res.tk

	// restore scanner state
	sc.pos_x = pos
	sc.line_no_y = line
	sc.is_in_string = is_in_string
	sc.dollar_start = dollar_start
	sc.dollar_end = dollar_end
	return tk
}

fn (sc &Scanner) expect(want string, start_pos int) bool {
	end_pos := start_pos + want.len
	if start_pos < 0 || start_pos >= sc.text.len {
		return false
	}
	if end_pos < 0 || end_pos > sc.text.len {
		return false
	}
	for pos in start_pos..end_pos {
		if sc.text[pos] != want[pos-start_pos] {
			return false
		}
	}
	return true
}

fn (sc mut Scanner) debug_tk() {
	sc.pos_x = 0
	sc.is_debug = true

	fname := sc.file_path.all_after('/')
	println('\n===DEBUG TOKENS $fname===')

	for {
		res := sc.scan()
		tk := res.tk
		literal := res.literal
		print(tok.str())
		if literal != '' {
			println(' `$literal`')
		}
		else {
			println('')
		}
		if tk == .EOF {
			println('============ END OF DEBUG TOKENS ==================')
			break
		}
	}
}

fn is_name_char(ch byte) bool {
	return ch.is_letter() || ch == `_`
}

fn is_NEWLINE(ch byte) bool {
	return ch == `\r` || ch == `\n`
}

fn (sc &Scanner) get_opening_bracket() int {
	mut pos := sc.pos_x
	mut parentheses := 0
	mut is_in_string := false

	for pos > 0 && sc.text[pos] != `\n` {
		if sc.text[pos] == `)` && !is_in_string {
			parentheses++
		}
		if sc.text[pos] == `(` && !is_in_string {
			parentheses--
		}
		if sc.text[pos] == `\'` && sc.text[pos - 1] != `\\` && sc.text[pos - 1] != `\`` {
			// ` // apostrophe balance comment. do not remove
			is_in_string = !is_in_string
		}
		if parentheses == 0 {
			break
		}
		pos--
	}
	return pos
}

// Foo { bar: 3, baz: 'hi' } => '{ bar: 3, baz: "hi" }'
fn (sc mut Scanner) create_type_string(T Type, name string) {
	line := sc.line_no_y
	is_in_string := sc.is_in_string
	mut newtext := '\'{ '
	start_pos := sc.get_opening_bracket() + 1
	end_pos := sc.pos_x
	for i, field in T.fields {
		if i != 0 {
			newtext += ', '
		}
		newtext += '$field.name: ' + '$${name}.${field.name}'
	}
	newtext += ' }\''
	sc.text = sc.text.substr(0, start_pos) + newtext + sc.text.substr(end_pos, sc.text.len)
	sc.pos_x = start_pos - 2
	sc.line_no_y = line
	sc.is_in_string = is_in_string
}

fn contains_capital(s string) bool {
	// for ch in s {
	for i := 0; i < s.len; i++ {
		ch := s[i]
		if ch >= `A` && ch <= `Z` {
			return true
		}
	}
	return false
}

// HTTPRequest  bad
// HttpRequest  good
fn good_type_name(s string) bool {
	if s.len < 4 {
		return true
	}
	for i in 2 .. s.len {
		if s[i].is_capital() && s[i-1].is_capital() && s[i-2].is_capital() {
			return false
		}
	}
	return true
}
