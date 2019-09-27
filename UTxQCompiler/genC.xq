// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import StringX

const (
	dot_ptr = '->'
)

// returns the type of the new variable
fn (xP mut Parser) gen_var_decl(name string, is_static bool) string {
	// Generate expression to tmp because we need its type first
	// `[typ] [name] = bool_expression();`
	pos := xP.cgen.add_shadow()
	mut typ := xP.bool_expression()
	//xP.gen('/*after expr*/')
	// Option check ? or {
	or_else := xP.tk == .key_or_else
	tmp := xP.get_tmp()
	if or_else {
		// Option_User tmp = get_user(1);
		// if (!tmp.ok) { or_statement }
		// User user = *(User*)tmp.data;
		// xP.assigned_var = ''
		xP.cgen.set_shadow(pos, '$typ $tmp = ')
		xP.genln(';')
		typ = typ.replace('Option_', '')
		xP.next()
		xP.check(.LCBR)
		xP.genln('if (!$tmp .ok) {')
		xP.register_var(Var {
			name: 'err'
			typ: 'string'
			is_mutable: false
			is_used: true
		})
		xP.genln('string err = $tmp . error;')
		xP.statements()
		xP.genln('$typ $name = *($typ*) $tmp . data;')
		if !xP.returns && xP.prev_tk2 != .key_continue && xP.prev_tk2 != .key_break {
			xP.error('`or` block must return/exit/continue/break/panic')
		}
		xP.returns = false
		return typ
	}
	gen_name := xP.table.var_cgen_name(name)
	mut nt_gen := xP.table.cgen_name_type_pair(gen_name, typ)
	// `foo := C.Foo{}` => `Foo foo;`
	if !xP.is_empty_c_struct_init && !typ.starts_with('['){
		nt_gen += '='
	}
	if is_static {
		nt_gen = 'static $nt_gen'
	}
	xP.cgen.set_shadow(pos, nt_gen)
	return typ
}

fn (xP mut Parser) gen_fn_decl(f Fn, typ, str_args string) {
	dll_export_linkage := if xP.os == .msvc && xP.attr == 'live' && xP.pref.is_so {
		'__declspec(dllexport) '
	} else if xP.attr == 'inline' {
		'static inline '
	} else {
		''
	}
	fn_name_cgen := xP.table.fn_gen_name(f)
	//str_args := f.str_args(xP.table)
	xP.genln('$dll_export_linkage$typ $fn_name_cgen($str_args) {')
}

// Blank identifer assignment `_ = 101` 
fn (xP mut Parser) gen_blank_identifier_assign() {
	xP.check_name()
	xP.check_space(.ASSIGN)
	pos := xP.cgen.add_shadow()
	mut typ := xP.bool_expression()
	tmp := xP.get_tmp()
	// Handle or
	if xP.tk == .key_or_else {
		xP.cgen.set_shadow(pos, '$typ $tmp = ')
		xP.genln(';')
		typ = typ.replace('Option_', '')
		xP.next()
		xP.check(.LCBR)
		xP.genln('if (!$tmp .ok) {')
		xP.register_var(Var {
			name: 'err'
			typ: 'string'
			is_mutable: false
			is_used: true
		})
		xP.genln('string err = $tmp . error;')
		xP.statements()
		xP.returns = false
	}
	xP.gen(';')
}

fn types_to_c(types []Type, table &dataTable) string {
	mut sb := StringX.new_builder(10)
	for t in types {
		if t.cat != .union && t.cat != .struct && t.cat != .objc_interface {
			continue
		}
		//if is_atomic {
			//sb.write('_Atomic ')
		//}
		if t.cat == .objc_interface {
			sb.writeln('@interface $t.name : $t.parent { @public')
		}
		else {
			kind := if t.cat == .union {'union'} else {'struct'}
			sb.writeln('$kind $t.name {')
		}
		for field in t.fields {
			sb.write('\t')
			sb.writeln(table.cgen_name_type_pair(field.name,
				field.typ) + ';')
		}
		sb.writeln('};\n')
		if t.cat == .objc_interface {
			sb.writeln('@end')
		}
	}
	return sb.str()
}

fn (xP mut Parser) index_get(typ string, fn_sh int, cfg IndexCfg) {
	// Erase var name we generated earlier:	"int a = m, 0"
	// "m, 0" gets killed since we need to start from scratch. It's messy.
	// "m, 0" is an index expression, save it before deleting and insert later in map_get()
	mut index_expr := ''
	if xP.cgen.is_tmp {
		index_expr = xP.cgen.tmp_line.right(fn_sh)
		xP.cgen.resetln(xP.cgen.tmp_line.left(fn_sh))
	} else {
		index_expr = xP.cgen.cur_line.right(fn_sh)
		xP.cgen.resetln(xP.cgen.cur_line.left(fn_sh))
	}
	// Can't pass integer literal, because map_get() requires a void*
	tmp := xP.get_tmp()
	tmp_ok := xP.get_tmp()
	if cfg.is_map {
		xP.gen('$tmp')
		def := type_default(typ)
		xP.cgen.insert_before('$typ $tmp = $def; bool $tmp_ok = map_get($index_expr, & $tmp);')
	}
	else if cfg.is_arr {
		if xP.pref.translated && !xP.builtin_mod {
			xP.gen('$index_expr ]')
		}
		else {
			if cfg.is_ptr {
				xP.gen('( *($typ*) array__get(* $index_expr) )')
			}  else {
				xP.gen('( *($typ*) array__get($index_expr) )')
			}
		}
	}
	else if cfg.is_str && !xP.builtin_mod {
		xP.gen('string_at($index_expr)')
	}
	// Zero the string after map_get() if it's null, numbers are automatically 0
	// This is ugly, but what can I do without generics?
	// TODO what about user types?
	if cfg.is_map && typ == 'string' {
		// xP.cgen.insert_before('if (!${tmp}.str) $tmp = tos("", 0);')
		xP.cgen.insert_before('if (!$tmp_ok) $tmp = tos((byte *)"", 0);')
	}

}

fn (table mut dataTable) fn_gen_name(f &Fn) string {
	mut name := f.name
	if f.is_method {
		name = '${f.receiver_typ}_$f.name'
		name = name.replace(' ', '')
		name = name.replace('*', '')
		name = name.replace('+', 'plus')
		name = name.replace('-', 'minus')
	}
	// Avoid name conflicts (with things like abs(), print() etc).
	// Generate xQ_abs(), xQ_print()
	// TODO duplicate functionality
	if f.mod == 'builtin' && f.name in CReserved {
		return 'xQ_$name'
	}
	// Obfuscate but skip certain names
	// TODO ugly, fix
	if table.is_obfuscated && f.name != 'main' && f.name != 'WinMain' && f.mod != 'builtin' && !f.is_c &&
	f.mod != 'darwin' && f.mod != 'os' && !f.name.contains('window_proc') && f.name != 'gg__vec2' &&
	f.name != 'build_token_str' && f.name != 'build_keys' && f.mod != 'json' &&
	!name.ends_with('_str') && !name.contains('contains') {
		mut idx := table.obf_ids[name]
		// No such function yet, register it
		if idx == 0 {
			table.fn_cnt++
			table.obf_ids[name] = table.fn_cnt
			idx = table.fn_cnt
		}
		old := name
		name = 'f_$idx'
		println('$old ==> $name')
	}
	return name
}

fn (xP mut Parser) gen_method_call(receiver_type, ftyp string, cgen_name string, receiver Var,method_sh int) {
	//mut cgen_name := xP.table.fn_gen_name(f)
	mut method_call := cgen_name + '('
	// if receiver is key_mutable or a ref (&), generate & for the first arg
	if receiver.ref || (receiver.is_mutable && !receiver_type.contains('*')) {
		method_call += '& /* ? */'
	}
	// generate deref (TODO copy paste later in fn_call_args)
	if !receiver.is_mutable && receiver_type.contains('*') {
		method_call += '*'
	}
	mut cast := ''
	// Method returns (void*) => cast it to int, string, user etc
	// number := *(int*)numbers.first()
	if ftyp == 'void*' {
		// array_int => int
		cast = receiver_type.all_after('_')
		cast = '*($cast*) '
	}
	xP.cgen.set_shadow(method_sh, '$cast $method_call')
	//return method_call
}

fn (xP mut Parser) gen_array_at(typ_ string, is_arr0 bool, fn_sh int) {
	mut typ := typ_
	//xP.fgen('[')
	// array_int a; a[0]
	// type is "array_int", need "int"
	// typ = typ.replace('array_', '')
	if is_arr0 {
		typ = typ.right(6)
	}
	// array a; a.first() voidptr
	// type is "array", need "void*"
	if typ == 'array' {
		typ = 'void*'
	}
	// No bounds check in translated from C code
	if xP.pref.translated && !xP.builtin_mod {
		// Cast void* to typ*: add (typ*) to the beginning of the assignment :
		// ((int*)a.data = ...
		xP.cgen.set_shadow(fn_sh, '(($typ*)(')
		xP.gen('.data))[')
	}
	else {
		xP.gen(',')
	}
}	

fn (xP mut Parser) gen_for_header(i, tmp, var_typ, val string) {
	xP.genln('for (int $i = 0; $i < ${tmp}.len; $i++) {')
	xP.genln('$var_typ $val = (($var_typ *) $tmp . data)[$i];')
}

fn (xP mut Parser) gen_for_str_header(i, tmp, var_typ, val string) {
	xP.genln('array_byte bytes_$tmp = string_bytes( $tmp );')
	xP.genln(';\nfor (int $i = 0; $i < $tmp .len; $i ++) {')
	xP.genln('$var_typ $val = (($var_typ *) bytes_$tmp . data)[$i];')
}

fn (xP mut Parser) gen_for_range_header(i, range_end, tmp, var_type, val string) {
	xP.genln(';\nfor (int $i = $tmp; $i < $range_end; $i++) {')
	xP.genln('$var_type $val = $i;')
}

fn (xP mut Parser) gen_for_map_header(i, tmp, var_typ, val, typ string) {
	def := type_default(typ)
	xP.genln('array_string keys_$tmp = map_keys(& $tmp ); ')
	xP.genln('for (int l = 0; l < keys_$tmp .len; l++) {')
	xP.genln('string $i = ((string*)keys_$tmp .data)[l];')
	// TODO don't call map_get() for each key, fetch values while traversing
	// the tree (replace `map_keys()` above with `map_key_vals()`)
	xP.genln('$var_typ $val = $def; map_get($tmp, $i, & $val);')
}

fn (xP mut Parser) gen_array_init(typ string, no_alloc bool, new_arr_sh int, no_of_elems int) {
	mut new_arr := 'new_array_from_c_array'
	if no_alloc {
		new_arr += '_no_alloc'
	}
	if no_of_elems == 0 && xP.pref.ccompiler != 'tcc' {
		xP.gen(' 0 })')
	} else {
		xP.gen(' })')
	}
	// Need to do this in the second CheckPoint, otherwise it goes to the very top of the out.c file
	if !xP.first_cp() {
		// Due to a tcc bug, the length needs to be specified.
		// GCC crashes if it is.
		cast := if xP.pref.ccompiler == 'tcc' { '($typ[$no_of_elems])' } else { '($typ[])' }
		xP.cgen.set_shadow(new_arr_sh,		
			'$new_arr($no_of_elems, $no_of_elems, sizeof($typ), $cast { ')
	}
}	

fn (xP mut Parser) gen_array_set(typ string, is_ptr, is_map bool,fn_sh, assign_pos int, is_cao bool) {
	// `a[0] = 7`
	// curline right now: `a , 0  =  7`
	mut val := xP.cgen.cur_line.right(assign_pos)
	xP.cgen.resetln(xP.cgen.cur_line.left(assign_pos))
	mut cao_tmp := xP.cgen.cur_line
	mut func := ''
	if is_map {
		func = 'map__set(&'
		// CAO on map is a bit more complicated as it loads
		// the value inside a pointer instead of returning it.
	}
	else {
		if is_ptr {
			func = 'array_set('
			if is_cao {
				cao_tmp = '*($xP.expected_type *) array__get(*$cao_tmp)'
			}
		}
		else {
			func = 'array_set(&/*q*/'
			if is_cao {
				cao_tmp = '*($xP.expected_type *) array__get($cao_tmp)'
			}
		}
	}
	xP.cgen.set_shadow(fn_sh, func)
	if is_cao {
		val = cao_tmp + val.all_before('=') +	val.all_after('=')
	}
	xP.gen(', & ($typ []) { $val })')
}


// Returns true in case of an early return
fn (xP mut Parser) gen_struct_init(typ string, t Type) bool {
	// TODO hack. If it's a C type, we may need to add "struct" before declaration:
	// a := &C.A{}  ==>  struct A* a = malloc(sizeof(struct A));
	if xP.is_c_struct_init {
		if t.cat != .c_typedef {
			xP.cgen.insert_before('struct /*c struct init*/')
		}
	}
	// TODO tm struct struct bug
	if typ == 'tm' {
		xP.cgen.lines[xP.cgen.lines.len-1] = ''
	}
	xP.next()
	xP.check(.LCBR)
	ptr := typ.contains('*')
	// `user := User{foo:bar}` => `User user = (User){ .foo = bar}`
	if !ptr {
		if xP.is_c_struct_init {
			// `face := C.FT_Face{}` => `FT_Face face;`
			if xP.tk == .RCBR {
				xP.is_empty_c_struct_init = true
				xP.check(.RCBR)
				return true
			}
			xP.gen('(struct $typ) {')
			xP.is_c_struct_init = false
		}
		else {
			xP.gen('($typ) {')
		}
	}
	else {
		// TODO tmp hack for 0 pointers init
		// &User{!} ==> 0
		if xP.tk == .NOT {
			xP.next()
			xP.gen('0')
			xP.check(.RCBR)
			return true
		}
		xP.gen('($t.name*)memdup(&($t.name)  {')
	}
	return false
}

fn (xP mut Parser) gen_struct_field_init(field string) {
	xP.gen('.$field = ')
}

fn (xP mut Parser) gen_empty_map(typ string) {
	xP.gen('new_map(1, sizeof($typ))')
}

fn (xP mut Parser) cast(typ string) {
	xP.next()
	pos := xP.cgen.add_shadow()
	if xP.tk == .RPAR {
		// skip `)` if it's `(*int)(ptr)`, not `int(a)`
		xP.ptr_cast = true
		xP.next()
	}
	xP.check(.LPAR)
	xP.expected_type = typ
	expr_typ := xP.bool_expression()
	// `face := FT_Face(cobj)` => `FT_Face face = *((FT_Face*)cobj);`
	casting_voidptr_to_value :=  expr_typ == 'void*' && typ != 'int' &&
		typ != 'byteptr' &&		!typ.ends_with('*')
	xP.expected_type = ''
	// `string(buffer)` => `tos2(buffer)`
	// `string(buffer, len)` => `tos(buffer, len)`
	// `string(bytes_array, len)` => `tos(bytes_array.data, len)`
	is_byteptr := expr_typ == 'byte*' || expr_typ == 'byteptr'
	is_bytearr := expr_typ == 'array_byte'
	if typ == 'string' {
		if is_byteptr || is_bytearr {
			if xP.tk == .COMMA {
				xP.check(.COMMA)
				xP.cgen.set_shadow(pos, 'tos((byte *)')
				if is_bytearr {
					xP.gen('.data')
				}
				xP.gen(', ')
				xP.check_types(xP.expression(), 'int')
			}  else {
				if is_bytearr {
					xP.gen('.data')
				}
				xP.cgen.set_shadow(pos, 'tos2((byte *)')
			}
		}
		// `string(234)` => error
		else if expr_typ == 'int' {
			xP.error('cannot cast `$expr_typ` to `$typ`, use `str()` method instead')
		}
		else {
			xP.error('cannot cast `$expr_typ` to `$typ`')
		}
	}
	else if typ == 'byte' && expr_typ == 'string' {
		xP.error('cannot cast `$expr_typ` to `$typ`, use backquotes `` to create a `$typ` or access the value of an index of `$expr_typ` using []')
	}
	else if casting_voidptr_to_value {
		xP.cgen.set_shadow(pos, '*($typ*)(')
	}
	else {
		xP.cgen.set_shadow(pos, '($typ)(')
	}
	xP.check(.RPAR)
	xP.gen(')')
}

fn type_default(typ string) string {
	if typ.starts_with('array_') {
		return 'new_array(0, 1, sizeof( ${typ.right(6)} ))'
	}
	// Always set pointers to 0
	if typ.ends_with('*') {
		return '0'
	}
	// User struct defined in another module.
	if typ.contains('__') {
		return '{0}'
	}
	// Default values for other types are not needed because of mandatory initialization
	switch typ {
	case 'bool': return '0'
	case 'string': return 'tos((byte *)"", 0)'
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
	return '{0}'
}

fn (xP mut Parser) gen_array_push(sh int, typ, expr_type, tmp, elem_type string) {
	// Two arrays of the same type?
	push_array := typ == expr_type
	if push_array {
		xP.cgen.set_shadow(sh, '_PUSH_MANY(&' )
		xP.gen('), $tmp, $typ)')
	} else {
		xP.check_types(expr_type, elem_typ)
		// Pass tmp var info to the _PUSH macro
		// Prepend tmp initialisation and push call
		// Don't dereference if it's already a mutable array argument  (`fn foo(mut []int)`)
		push_call := if typ.contains('*'){'_PUSH('} else { '_PUSH(&'}
		xP.cgen.set_shadow(sh, push_call)
		if elem_typ.ends_with('*') {
			xP.gen('), $tmp, ${elem_typ.left(elem_typ.len - 1)})')
		} else {
			xP.gen('), $tmp, $elem_typ)')
		}
	}
}