// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import StringX

const (
	dot_ptr = '.'
)

fn (xP mut Parser) gen_var_decl(name string, is_static bool) string {
	xP.gen('var $name /* typ */ = ')
	typ := xP.bool_expression()
	or_else := xP.tk == .key_or_else
	//tmp := xP.get_tmp()
	if or_else {
		//panic('optionals todo')
	}
	return typ
}

fn (xP mut Parser) gen_fn_decl(f Fn, typ, _str_args string) {
	mut str_args := ''
	for i, arg in f.args   {
		str_args += ' /** @type { $arg.typ } **/ ' + arg.name
		if i < f.args.len - 1 {
			str_args += ', '
		}
	}
	name := xP.table.fn_gen_name(f)
	if f.is_method {
		xP.genln('\n${f.receiver_typ}.prototype.${name} = function($str_args) {')
	} else {
		xP.genln('/** @return { $typ } **/\nfunction $name($str_args) {')
	}
}

fn (xP mut Parser) gen_blank_identifier_assign() {
	typ := xP.bool_expression()
	or_else := xP.tk == .key_or_else
	//tmp := xP.get_tmp()
	if or_else {
		//panic('optionals todo')
	}
}

fn types_to_c(types []Type, table &dataTable) string {
	mut sb := StringX.new_builder(10)
	for t in types {
		if t.cat != .union && t.cat != .struct {
			continue
		}
		sb.write('\n/**\n')
		sb.write('* @typedef { object } $t.name' + 'Type\n')
		for field in t.fields {
			sb.writeln('* @property { $field.typ' + '= } $field.name')
		}
		sb.writeln('**/\n')
		sb.writeln('/** @type { function & $t.name' + 'Type } **/')
		sb.writeln('var $t.name = function() {}')
	}
	return sb.str()
}

fn (xP mut Parser) index_get(typ string, fn_sh int, cfg IndexCfg) {
	xP.cgen.cur_line = xP.cgen.cur_line.replace(',', '[') + ']'
}

fn (table &dataTable) fn_gen_name(f &Fn) string {
	mut name := f.name
	if f.is_method {
		name = name.replace(' ', '')
		name = name.replace('*', '')
		name = name.replace('+', 'plus')
		name = name.replace('-', 'minus')
		return name
	}
	// Avoid name conflicts (with things like abs(), print() etc).
	// Generate b_abs(), b_print()
	// TODO duplicate functionality
	if f.mod == 'builtin' && f.name in CReserved {
		return 'xQ_$name'
	}
	return name
}

fn (xP mut Parser) gen_method_call(receiver_type, ftyp string, cgen_name string, receiver Var,method_sh int) {
	//mut cgen_name := xP.table.fn_gen_name(f)
	//mut method_call := cgen_name + '('
	xP.gen('.' + cgen_name.all_after('_') + '(')
	//xP.cgen.set_shadow(method_sh, '$cast kKE $method_call')
	//return method_call
}


fn (xP mut Parser) gen_array_at(typ string, is_arr0 bool, fn_sh int) {
	xP.gen('[')
}	

fn (xP mut Parser) gen_for_header(i, tmp, var_typ, val string) {
	xP.genln('for (var $i = 0; $i < ${tmp}.length; $i++) {')
	xP.genln('var $val = $tmp [$i];')
}

fn (xP mut Parser) gen_for_range_header(i, range_end, tmp, var_type, val string) {
	xP.genln(';\nfor (var $i = $tmp; $i < $range_end; $i++) {')
	xP.genln('var /*$var_type*/ $val = $i;')
}

fn (xP mut Parser) gen_for_str_header(i, tmp, var_typ, val string) {
	xP.genln('for (var $i = 0; $i < $tmp .length; $i ++) {')
	xP.genln('var $val = $tmp[$i];')
}

fn (xP mut Parser) gen_for_map_header(i, tmp, var_typ, val, typ string) {
	xP.genln('for (var $i in $tmp) {')
	xP.genln('var $val = $tmp[$i];')
}

fn (xP mut Parser) gen_array_init(typ string, no_alloc bool, new_arr_sh int, no_of_elems int) {
	xP.cgen.set_shadow(new_arr_sh,	'[')
	xP.gen(']')
}

fn (xP mut Parser) gen_array_set(typ string, is_ptr, is_map bool,fn_sh, assign_pos int, is_cao bool) {
	mut val := xP.cgen.cur_line.right(assign_pos)
	xP.cgen.resetln(xP.cgen.cur_line.left(assign_pos))
	xP.gen('] =')
	cao_tmp := xP.cgen.cur_line
	if is_cao  {
		val = cao_tmp + val.all_before('=') +	val.all_after('=')
	}
	xP.gen(val)
}

// Returns true in case of an early return
fn (xP mut Parser) gen_struct_init(typ string, t Type) bool {
	xP.next()
	xP.check(.LCBR)
	ptr := typ.contains('*')
	if !ptr {
			xP.gen('{')
	}
	else {
		// TODO tmp hack for 0 pointers init
		// &User{!} ==> 0
		if xP.tk == .NOT {
			xP.next()
			xP.gen('}')
			xP.check(.RCBR)
			return true
		}
	}
	return false
}

fn (xP mut Parser) gen_struct_field_init(field string) {
	xP.gen('$field : ')
}

fn (xP mut Parser) gen_empty_map(typ string) {
	xP.gen('{}')
}

fn (xP mut Parser) cast(typ string) string {
	xP.next()
	pos := xP.cgen.add_shadow()
	if xP.tk == .RPAR {
		xP.next()
	}
	xP.check(.LPAR)
	xP.bool_expression()
	if typ == 'string' {
		if xP.tk == .COMMA {
			xP.check(.COMMA)
			xP.cgen.set_shadow(pos, 'tos(')
			//xP.gen('tos(')
			xP.gen(', ')
			xP.expression()
			xP.gen(')')
		}
	}
	xP.check(.RPAR)
	return typ
}

fn type_default(typ string) string {
	if typ.starts_with('array_') {
		return '[]'
	}
	// Always set pointers to 0
	if typ.ends_with('*') {
		return '0'
	}
	// User struct defined in another module.
	if typ.contains('__') {
		return '{}'
	}
	// Default values for other types are not needed because of mandatory initialization
	switch typ {
	case 'bool': return '0'
	case 'string': return '""'
	case 'i8': return '0'
	case 'i16': return '0'
	case 'i64': return '0'
	case 'u16': return '0'
	case 'u32': return '0'
	case 'u64': return '0'
	case 'byte': return '0'
	case 'int': return '0'
	case 'rune': return '0'
	case 'f32': return '0.0'
	case 'f64': return '0.0'
	case 'byteptr': return '0'
	case 'voidptr': return '0'
	}
	return '{}'
}

fn (xP mut Parser) gen_array_push(sh int, typ, expr_type, tmp, tmp_typ string) {
	push_array := typ == expr_type
	if push_array {
		xP.cgen.set_shadow(sh, 'push(&' )
		xP.gen('), $tmp, $typ)')
	}  else {
		xP.check_types(expr_type, tmp_typ)
		xP.gen(')')
		xP.cgen.cur_line = xP.cgen.cur_line.replace(',', '.push')
	}
}