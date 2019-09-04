// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import strings

fn (xP mut Parser) get_type2() Type {
	mut star := false
	mut nr_stars := 0
	mut typ := ''
	mut cat := TypeCategory.struct
	// fn type
	if xP.tk == .key_function {
		mut f := Fn{name: '_', mod: xP.mod}
		xP.next()
		line_no_y := xP.scanner.line_no_y
		xP.fn_args(mut f)
		// Same line, it's a return type
		if xP.scanner.line_no_y == line_no_y {
			if xP.tk == .NAME {
				f.typ = xP.get_type()
			}
			else {
				f.typ = 'void'
			}
			// println('fn return typ=$f.typ')
		}
		else {
			f.typ = 'void'
		}
		// Register anonymous fn type
		fn_typ := Type {
			name: f.typ_str()// 'fn (int, int) string'
			mod: xP.mod
			function: f
			cat: TypeCategory.function
		}
		xP.table.register_type2(fn_typ)
		return fn_typ
	}
	// arrays ([]int)
	mut is_arr := false
	mut is_arr2 := false// [][]int TODO remove this and allow unlimited levels of arrays
	is_question := xP.tk == .QUESTION
	if is_question {
		xP.check(.QUESTION)
	}
	if xP.tk == .LSBR {
		xP.check(.LSBR)
		// [10]int
		if xP.tk == .NUMBER {
			typ = '[$xP.lit]'
			xP.next()
		}
		else {
			is_arr = true
		}
		xP.check(.RSBR)
		// [10][3]int
		if xP.tk == .LSBR {
			xP.next()
			if xP.tk == .NUMBER {
				typ += '[$xP.lit]'
				xP.check(.NUMBER)
			}
			else {
				is_arr2 = true
			}
			xP.check(.RSBR)
		}
		cat = .array
	}
	// map[string]int
	if !xP.builtin_mod && xP.tk == .NAME && xP.lit == 'map' {
		xP.next()
		xP.check(.LSBR)
		key_type := xP.check_name()
		if key_type != 'string' {
			xP.error('maps only support string keys for now')
		}
		xP.check(.RSBR)
		val_type := xP.get_type()// xP.check_name()
		typ = 'map_$val_type'
		xP.register_map(typ)
		return Type{name: typ}
	}
	//
	for xP.tk == .STAR {
		if xP.first_cp() {
			xP.warn('use `&Foo` instead of `*Foo`')
		}
		star = true
		nr_stars++
		xP.check(.STAR)
	}
	if xP.tk == .AMPER {
		star = true
		nr_stars++
		xP.check(.AMPER)
	}
	typ += xP.lit
	if !xP.is_struct_init {
		// Otherwise we get `foo := FooFoo{` because `Foo` was already
		// generated in name_expr()
		xP.fgen(xP.lit)
	}
	// C.Struct import
	if xP.lit == 'C' && xP.peek() == .DOT {
		xP.next()
		xP.check(.DOT)
		typ = xP.lit
	}
	else {
		// Module specified? (e.g. gx.Image)
		if xP.peek() == .DOT {
			// try resolve full submodule
			if !xP.builtin_mod && xP.import_table.known_alias(typ) {
				mod := xP.import_table.resolve_alias(typ)
				if mod.contains('.') {
					typ = mod.replace('.', '_dot_')
				}
			}
			xP.next()
			xP.check(.DOT)
			typ += '__$xP.lit'
		}
		mut t := xP.table.find_type(typ)
		// "typ" not found? try "mod__typ"
		if t.name == '' && !xP.builtin_mod {
			// && !xP.first_cp() {
			if !typ.contains('array_') && xP.mod != 'main' && !typ.contains('__') &&
				!typ.starts_with('[') {
				typ = xP.prepend_mod(typ)
			}
			t = xP.table.find_type(typ)
			if t.name == '' && !xP.pref.translated && !xP.first_cp() && !typ.starts_with('[') {
				println('get_type() bad type')
				// println('all registered types:')
				// for q in xP.table.types {
				// println(q.name)
				// }
				xP.error('unknown type `$typ`')
			}
		}
	}
	if typ == 'void' {
		xP.error('unknown type `$typ`')
	}
	if star {
		typ += strings.repeat(`*`, nr_stars)
	}
	// Register an []array type
	if is_arr2 {
		typ = 'array_array_$typ'
		xP.register_array(typ)
	}
	else if is_arr {
		typ = 'array_$typ'
		// xP.log('ARR TYPE="$typ" run=$xP.cp')
		// We come across "[]User" etc ?
		xP.register_array(typ)
	}
	xP.next()
	if xP.tk == .QUESTION || is_question {
		typ = 'Option_$typ'
		xP.table.register_type_with_parent(typ, 'Option')
		if xP.tk == .QUESTION {
			xP.next()
		}
	}
	if typ.last_index('__') > typ.index('__') {
		xP.error('2 __ in gettype(): typ="$typ"')
	}
	return Type{name: typ, cat: cat}
}
