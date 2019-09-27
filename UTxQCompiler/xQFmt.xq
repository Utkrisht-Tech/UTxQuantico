// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import StringX

// Format helpers

fn (scanner mut Scanner) fgen(s string) {
	mut st := s
	if scanner.format_line_empty {
		st = StringX.repeat(`\t`, scanner.format_indent) + st
	}
	scanner.format_out.write(st)
	scanner.format_line_empty = false
}

fn (scanner mut Scanner) fgenln(s string) {
	mut st := s
	if scanner.format_line_empty {
		st = StringX.repeat(`\t`, scanner.format_indent) + st
	}
	scanner.format_out.writeln(st)
	scanner.format_line_empty = true
}

fn (xP mut Parser) fgen(s string) {
	xP.scanner.fgen(s)
}

fn (xP mut Parser) fspace() {
	xP.fgen(' ')
}

fn (xP mut Parser) fgenln(s string) {
	xP.scanner.fgenln(s)
}

/*
fn (xP mut Parser) peek() Token {
	for {
		xP.cgen.line = xP.scanner.line_no_y + 1
		tk := xP.scanner.peek()
		if tk != .NEWLINE {
			return tk
		}
	}
	return .EOF  // FIX:- UTxQ doesn't know how to reach here
}
*/

fn (xP mut Parser) format_inc() {
	xP.scanner.format_indent++
}

fn (xP mut Parser) format_dec() {
	xP.scanner.format_indent--
}