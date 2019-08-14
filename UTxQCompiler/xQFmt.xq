// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import strings

// format helpers

fn (scanner mut Scanner) fgen(s string) {
	mut st := s
	if scanner.format_line_empty {
		st = strings.repeat(`\t`, scanner.format_indent) + st
	}
	scanner.format_out.write(st)
	scanner.format_line_empty = false
}

fn (scanner mut Scanner) fgenln(s string) {
	mut st := s
	if scanner.format_line_empty {
		st = strings.repeat(`\t`, scanner.format_indent) + st
	}
	scanner.format_out.writeln(st)
	scanner.format_line_empty = true
}

fn (xQP mut Parser) fgen(s string) {
	xQP.scanner.fgen(s)
}

fn (xQP mut Parser) fspace() {
	xQP.fgen(' ')
}

fn (xQP mut Parser) fgenln(s string) {
	xQP.scanner.fgenln(s)
}

fn (xQP mut Parser) peek() Token {
	for {
		xQP.cgen.line = xQP.scanner.line_no_y + 1
		tk := xQP.scanner.peek()
		if tk != .NEWLINE {
			return tk
		}
	}
	return .EOF  // FIX:- UTxQ doesn't know how to reach here
}

fn (xQP mut Parser) format_inc() {
	xQP.scanner.format_indent++
}

fn (xQP mut Parser) format_dec() {
	xQP.scanner.format_indent--
}
