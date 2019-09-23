// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import (
	os
	StringX
)

const (
	MaxLocalVars = 50
)

struct Fn {
	// addr int
mut:
	name          string
	mod           string
	local_vars    []Var
	var_idx       int
	args          []Var
	is_interface  bool
	// called_fns    []string
	// idx        int
	scope_level   int
	typ           string // return type
	is_c          bool
	receiver_typ  string
	is_public     bool
	is_method     bool
	returns_error bool
	is_decl       bool // type myfn fn(int, int)
	defer_text    []string
	//gen_types 	[]string
}

fn (f &Fn) find_var(name string) ?Var {
	for i in 0 .. f.var_idx {
		if f.local_vars[i].name == name {
			return f.local_vars[i]
		}
	}
	return none
}

fn (xP &Parser) find_var_check_new_var(name string) ?Var {
	for i in 0 .. xP.cur_fn.var_idx {
		if xP.cur_fn.local_vars[i].name == name {
			return xP.cur_fn.local_vars[i]
		}
	}
	// A hack to allow `newvar := Foo{ field: newvar }`
	// Declare the variable so that it can be used in the initialization
	if name == 'main__' + xP.var_decl_name {
		return Var{
			name : xP.var_decl_name
			typ : 'voidptr'
			is_mut : true
		}
	}
	return none
}

fn (f &Fn) find_var2(name string) Var {
	for i in 0 .. f.var_idx {
		if f.local_vars[i].name == name {
			return f.local_vars[i]
		}
	}
	return Var{}
}


fn (xP mut Parser) open_scope() {
	xP.cur_fn.defer_text << ''
	xP.cur_fn.scope_level++
}

fn (xP mut Parser) mark_var_used(var Var) {
	for i, kv in xP.cur_fn.local_vars {
		if kv.name == var.name {
			xP.cur_fn.local_vars[i].is_used = true
		}
	}
}

fn (xP mut Parser) mark_var_returned(var Var) {
	for i, vAr in xP.cur_fn.local_vars {
		if vAr.name == var.name {
			xP.cur_fn.local_vars[i].is_returned = true
		}
	}
}

fn (xP mut Parser) mark_var_changed(var Var) {
	for i, kv in xP.cur_fn.local_vars {
		if kv.name == var.name {
			xP.cur_fn.local_vars[i].is_changed = true
		}
	}
}

fn (f mut Fn) known_var(name string) bool {
	_ := f.find_var(name) or {
		return false
	}	
	return true
}

fn (f mut Fn) register_var(var Var) {
	new_var := {var | scope_level: f.scope_level}
	// Expand the array
	if f.var_idx >= f.local_vars.len {
		f.local_vars << new_var
	}
	else {
		f.local_vars[f.var_idx] = new_var
	}
	f.var_idx++
}

fn (f mut Fn) clear_vars() {
	f.var_idx = 0
	f.local_vars = []Var
}

// xQLib header file
fn (xP mut Parser) is_sig() bool {
	return (xP.pref.build_mode == .default_mode || xP.pref.build_mode == .build_module) &&
	(xP.file_path.contains(ModPath))
}

fn new_fn(mod string, is_public bool) Fn {
	return Fn {
		mod: mod
		local_vars: [Var{}].repeat(MaxLocalVars)
		is_public: is_public
	}


// Function signatures are added to the top of the .c file in the first run.
fn (xP mut Parser) fn_decl() {
	xP.fgen('fn ')
	//defer { xP.fgenln('\n') }
	is_public := xP.tk == .key_public
	is_live := xP.attr == 'live' && !xP.pref.is_so  && xP.pref.is_live
	if p.attr == 'live' &&  xP.first_cp() && !xP.pref.is_live && !xP.pref.is_so {
		println('INFO: run `xQ -live program.xq` if you want to use [live] functions')
	}
	if is_public {
		xP.next()
	}
	xP.returns = false
	//xP.gen('/* returns $xP.returns */')
	xP.next()
	mut f := new_fn(xP.mod, is_public)
	// Method receiver
	mut receiver_typ := ''
	if xP.tk == .LPAR {
		f.is_method = true
		xP.check(.LPAR)
		receiver_name := xP.check_name()
		is_mutable := xP.tk == .key_mutable
		is_amper := xP.tk == .AMPER
		if is_mutable || is_amper {
			xP.check_space(xP.tk)
		}
		receiver_typ = xP.get_type()
		T := xP.table.find_type(receiver_typ)
		if T.cat == .interface {
			xP.error('invalid receiver type `$receiver_typ` (`$receiver_typ` is an interface)')
		}
		// Don't allow modifying types from a different module
		if !xP.first_cp() && !xP.builtin_mod && T.mod != xP.mod {
			println('T.mod=$T.mod')
			println('xP.mod=$xP.mod')
			xP.error('cannot define new methods on non-local type `$receiver_typ`')
		}
		// `(f *Foo)` instead of `(f mut Foo)` is a common mistake
		//if !xP.builtin_mod && receiver_typ.contains('*') {
		if receiver_typ.contains('*') {
			t := receiver_typ.replace('*', '')
			xP.error('use `($receiver_name mut $t)` instead of `($receiver_name *$t)`')
		}
		f.receiver_typ = receiver_typ
		if is_mutable || is_amper {
			receiver_typ += '*'
		}
		xP.check(.RPAR)
		xP.fspace()
		receiver := Var {
			name: receiver_name
			is_arg: true
			typ: receiver_typ
			is_mutable: is_mutable
			ref: is_amper
			ptr: is_mutable
			line_no_y: xP.scanner.line_no_y
			scanner_pos_x: xP.scanner.get_scanner_pos()
		}
		f.args << receiver
		f.register_var(receiver)
	}
	if xP.tk == .PLUS || xP.tk == .MINUS || xP.tk == .STAR {
		f.name = xP.tk.str()
		xP.next()
	}
	else {
		f.name = xP.check_name()
	}
	// C function header def? (fn C.NSMakeRect(int,int,int,int))
	is_c := f.name == 'C' && xP.tk == .DOT
	// Just fn signature? only builtin.xq + default build mode
	// is_sig := xP.builtin_mod && xP.pref.build_mode == default_mode
	// is_sig := xP.pref.build_mode == default_mode && (xP.builtin_mod || xP.file.contains(LANG_TMP))
	is_sig := xP.is_sig()
	// println('\n\nfn_decl() name=$f.name receiver_typ=$receiver_typ')
	if is_c {
		xP.check(.DOT)
		f.name = xP.check_name()
		f.is_c = true
	}
	else if !xP.pref.translated && !xP.file_path.contains('view.xq') {
		if contains_capital(f.name) {
			xP.error('function names cannot contain uppercase letters, use snake_case instead')
		}
		if f.name.contains('__') {
			xP.error('function names cannot contain double underscores, use single underscores instead')
		}
	}
	// simple_name := f.name
	// println('!SIMP.le=$simple_name')
	// user.register() => User_register()
	has_receiver := receiver_typ.len > 0
	if receiver_typ != '' {
		// f.name = '${receiver_typ}_${f.name}'
	}
	// full mod function name
	// os.exit ==> os__exit()
	if !is_c && !xP.builtin_mod && xP.mod != 'main' && receiver_typ.len == 0 {
		f.name = xP.prepend_mod(f.name)
	}
	if xP.first_cp() && receiver_typ.len == 0 {
		for {
		existing_fn := xP.table.find_fn(f.name) or { break }
		// This existing function could be defined as C declaration before (no body), then we don't need to throw an error
		if !existing_fn.is_decl {
			xP.error('redefinition of `$f.name`')
		}
		break
		}
	}
	// Generic?
	mut is_generic := false
	if xP.tk == .LESSER {
		is_generic = true
		xP.next()
		gen_type := xP.check_name()
		if gen_type != 'T' {
			xP.error('only `T` is allowed as a generic type for now')
		}
		xP.check(.GREATER)
		if xP.first_cp() {
			xP.table.register_generic_fn(f.name)
		}  else {
			//gen_types := xP.table.fn_gen_types(f.name)
			//println(gen_types)
		}
	}
	// Args (...)
	xP.fn_args(mut f)
	// Returns an error?
	if xP.tk == .NOT {
		xP.next()
		f.returns_error = true
	}
	// Returns a type?
	mut typ := 'void'
	if xP.tk == .NAME || xP.tk == .STAR || xP.tk == .AMPER || xP.tk == .LSBR ||
	xP.tk == .QUESTION {
		xP.fgen(' ')
		// TODO In
		// if xP.tok in [ .NAME, .STAR, .AMPER, .LSBR ] {
		typ = xP.get_type()
	}
	// Translated C code can have empty functions (just definitions)
	is_fn_header := !is_c && !is_sig && (xP.pref.translated || xP.pref.is_test) &&	xP.tk != .LCBR
	if is_fn_header {
		f.is_decl = true
	}
	// { required only in normal function declarations
	if !is_c && !is_sig && !is_fn_header {
		xP.fgen(' ')
		xP.check(.LCBR)
	}
	// Register ?option type
	if typ.starts_with('Option_') {
		xP.cgen.typedefs << 'typedef Option $typ;'
	}
	// Register function
	f.typ = typ
	mut str_args := f.str_args(xP.table)
	// Special case for main() args
	if f.name == 'main' && !has_receiver {
		if str_args != '' || typ != 'void' {
			xP.error('fn main must have no arguments and no return values')
		}
		typ = 'int'
		str_args = 'int argc, char** argv'
	}
	dll_export_linkage := if xP.os == .msvc && xP.attr == 'live' && xP.pref.is_so {
		'__declspec(dllexport) '
	} else if xP.attr == 'inline' {
		'static inline '
	} else {
		''
	}
	if !xP.is_WebX {
		xP.set_current_fn( f )
	}
	// Generate `User_register()` instead of `register()`
	// Internally it's still stored as "register" in type User
	mut fn_name_cgen := xP.table.fn_gen_name(f)
	// Start generation of the function body
	skip_main_in_test := f.name == 'main' && xP.pref.is_test
	if !is_c && !is_live && !is_sig && !is_fn_header && !skip_main_in_test {
		if xP.pref.is_obfuscated {
			xP.genln('; // $f.name')
		}
		// Generate this function's body for all generic types
		if is_generic {
			gen_types := xP.table.fn_gen_types(f.name)
			// Remember current scanner position, go back here for each type
			// TODO remove this once tokens are cached in `new_parser()`
			cur_pos := xP.scanner.pos_x
			cur_tk := xP.tk
			cur_lit := xP.lit
			for gen_type in gen_types {
				xP.genln('$dll_export_linkage$typ ${fn_name_cgen}_$gen_type($str_args) {')
				xP.genln('// T start $xP.cp ${xP.strtk()}')
				xP.cur_gen_type = gen_type // TODO support more than T
				xP.statements()
				xP.scanner.pos_x = cur_pos
				xP.tk  = cur_tk
				xP.lit = cur_lit
			}
		}
		else {
			xP.gen_fn_decl(f, typ, str_args)
		}
	}
	if is_fn_header {
		xP.genln('$typ $fn_name_cgen($str_args);')
		xP.fgenln('')
	}
	if is_c {
		xP.fgenln('\n')
	}
	// Register the method
	if receiver_typ != '' {
		mut receiver_t := xP.table.find_type(receiver_typ)
		// No such type yet? It could be defined later. Create a new type.
		// struct declaration later will modify it instead of creating a new one.
		if xP.first_cp() && receiver_t.name == '' {
			//println('fn decl ! registering shadow $receiver_typ')
			receiver_t = Type {
				name: receiver_typ.replace('*', '')
				mod: xP.mod
				is_shadow: true
			}
			xP.table.register_type2(receiver_t)
		}
		xP.add_method(receiver_t.name, f)
	}
	else {
		// println('register_fn typ=$typ isg=$is_generic')
		xP.table.register_fn(f)
	}
	if is_sig || xP.first_cp() || is_live || is_fn_header || skip_main_in_test {
		// First CheckPoint:- Skip the body for now
		// Look for generic calls.
		if !is_sig && !is_fn_header {
			mut opened_scopes := 0
			mut closed_scopes := 0
			mut temp_scanner_pos := 0
			for {
				if xP.tk == .LCBR {
					opened_scopes++
				}
				if xP.tk == .RCBR {
					closed_scopes++
				}
				// find `foo<Bar>()` in function bodies and register generic types
				// TODO remove this once tokens are cached
				if xP.tk == .GREATER && xP.prev_tk == .NAME  && xP.prev_tk2 == .LESSER &&
					xP.scanner.text[xP.scanner.pos_x-1] != `T` {
					temp_scanner_pos = xP.scanner.pos_x
					xP.scanner.pos_x -= 3
					for xP.scanner.pos_x > 0 && (is_name_char(xP.scanner.text[xP.scanner.pos_x]) ||
						xP.scanner.text[xP.scanner.pos_x] == `.`  ||
						xP.scanner.text[xP.scanner.pos_x] == `<` ) {
						xP.scanner.pos_x--
					}
					xP.scanner.pos_x--
					xP.next()
					// Run the function in the first CheckPoint to register the generic type
					xP.name_expr()
					xP.scanner.pos_x = temp_scanner_pos
				}
				if xP.tk.is_decl() {
					break
				}
				// fn body ended, and a new fn attribute declaration like [live] is starting?
				if closed_scopes > opened_scopes && xP.prev_tk == .RCBR {
					if xP.tk == .LSBR {
						break
					}
				}
				xP.next()
			}
		}
		// Hot code reloading:- Load all fns from .so
		if is_live && xP.first_cp() && xP.mod == 'main' {
			//println('ADDING SO FN $fn_name_cgen')
			xP.cgen.so_fns << fn_name_cgen
			fn_name_cgen = '(* $fn_name_cgen )'
		}
		// Function definition that goes to the top of the C file.
		mut fn_decl := '$dll_export_linkage$typ $fn_name_cgen($str_args)'
		if xP.pref.is_obfuscated {
			fn_decl += '; // $f.name'
		}
		// Add function definition to the top
		if !is_c && f.name != 'main' && xP.first_cp() {
			// TODO hack to make Volt compile without -embed_xQLib
			if f.name == 'darwin__nsstring' && xP.pref.build_mode == .default_mode {
				return
			}
			xP.cgen.fns << fn_decl + ';'
		}
		return
	}
	if xP.attr == 'live' && xP.pref.is_so {
		//xP.genln('// live_function body start')
		xP.genln('pthread_mutex_lock(&live_fn_mutex);')
	}
	if f.name == 'main' || f.name == 'WinMain' {
		xP.genln('init_consts();')
		if 'os' in xP.table.imports {
			if f.name == 'main' {
				xP.genln('os__args = os__init_os_args(argc, (byteptr*)argv);')
			}
			else if f.name == 'WinMain' {
				xP.genln('os__args = os__parse_windows_cmd_line(xPCmdLine);')
			}
		}
		// We are in live code reload mode, call the .so loader in background
		if xP.pref.is_live {
			file_base := os.filename(xP.file_path).replace('.xq', '')
			if xP.os != .windows && xP.os != .msvc {
				so_name := file_base + '.so'
				xP.genln('
load_so("$so_name");
pthread_t _thread_so;
pthread_create(&_thread_so , NULL, &reload_so, NULL); ')
			} else {
				so_name := file_base + if xP.os == .msvc {'.dll'} else {'.so'}
				xP.genln('
live_fn_mutex = CreateMutexA(0, 0, 0);
load_so("$so_name");
unsigned long _thread_so;
_thread_so = CreateThread(0, 0, (LPTHREAD_START_ROUTINE)&reload_so, 0, 0, 0);
				')
			}
		}
		if xP.pref.is_test && !xP.scanner.file_path.contains('/volt') {
			xP.error('tests cannot have function `main`')
		}
	}
	// println('is_c=$is_c name=$f.name')
	if is_c || is_sig || is_fn_header {
		// println('IS SIG .key_returnING tk=${xP.strtk()}')
		return
	}
	// Profiling mode:- Start counting at the beginning of the function (save current time).
	if xP.pref.is_prof && f.name != 'main' && f.name != 'time__ticks' {
		xP.genln('double _PROF_START = time__ticks();//$f.name')
		cgen_name := xP.table.fn_gen_name(f)
		if f.defer_text.len > f.scope_level {
			f.defer_text[f.scope_level] = '  ${cgen_name}_time += time__ticks() - _PROF_START;'
		}
	}
	if is_generic {
		// Don't need to generate body for the actual generic definition
		xP.cgen.nogen = true
	}
	xP.statements_no_rcbr()
	xP.cgen.nogen = false
	// Print counting result after all statements in main
	if xP.pref.is_prof && f.name == 'main' {
		xP.genln(xP.print_prof_counters())
	}
	// Counting or not, always need to add defer before the end
	if !xP.is_WebX {
		if f.defer_text.len > f.scope_level {
			xP.genln(f.defer_text[f.scope_level])
		}
	}
	if typ != 'void' && !xP.returns && f.name != 'main' && f.name != 'WinMain' {
		xP.error('$f.name must return "$typ"')
	}
	if xP.attr == 'live' && xP.pref.is_so {
		//xP.genln('// live_function body end')
		xP.genln('pthread_mutex_unlock(&live_fn_mutex);')
	}
	// {} closed correctly:- scope_level should be 0
	if xP.mod == 'main' {
		// println(xP.cur_fn.scope_level)
	}
	if xP.cur_fn.scope_level > 2 {
		// xP.error('unclosed {')
	}
	// Make sure all vars in this function are used (only in main for now)
	if xP.mod != 'main' {
		if !is_generic {
			xP.genln('}')
		}
		return
	}
	xP.check_unused_variables()
	xP.set_current_fn( EmptyFn )
	xP.returns = false
	if !is_generic {
		xP.genln('}')
	}
}

fn (xP mut Parser) check_unused_variables() {
	for var in xP.cur_fn.local_vars {
		if var.name == '' {
			break
		}
		if !var.is_used && !xP.pref.is_repl && !var.is_arg && !xP.pref.translated && var.name != '_' {
			xP.production_error('`$var.name` declared and not used', var.scanner_pos_x )
		}
		if !var.is_changed && var.is_mutable && !xP.pref.is_repl && !xP.pref.translated && var.name != '_' {
			xP.error_with_position( '`$var.name` is declared as mutable, but it was never changed', var.scanner_pos_x )
		}
	}
}

// user.register() => "User_register(user)"
// method_sh - where to insert "user_register("
// receiver_var - "user" (needed for pthreads)
// receiver_type - "User"
fn (xP mut Parser) async_fn_call(f Fn, method_sh int, receiver_var, receiver_type string) {
	// println('\nfn_call $f.name is_method=$f.is_method receiver_type=$f.receiver_type')
	// xP.print_tk()
	mut thread_name := ''
	// Normal function => just its name, method => TYPE_FN.name
	mut fn_name := f.name
	if f.is_method {
		fn_name = receiver_type.replace('*', '') + '_' + f.name
		//fn_name = '${receiver_type}_${f.name}'
	}
	// Generate tmp struct with args
	arg_struct_name := 'thread_arg_$fn_name'
	tmp_struct := xP.get_tmp()
	xP.genln('$arg_struct_name * $tmp_struct = malloc(sizeof($arg_struct_name));')
	mut arg_struct := 'typedef struct  $arg_struct_name   { '
	xP.next()
	xP.check(.LPAR)
	// str_args contains the args for the wrapper function:
	// wrapper(arg_struct * arg) { fn("arg->a, arg->b"); }
	mut str_args := ''
	mut did_gen_something := false
	for i, arg in f.args {
		arg_struct += '$arg.typ $arg.name ;'// Add another field (arg) to the tmp struct definition
		str_args += 'arg $dot_ptr $arg.name'
		if i == 0 && f.is_method {
			xP.genln('$tmp_struct  $dot_ptr $arg.name =  $receiver_var ;')
			if i < f.args.len - 1 {
				str_args += ','
			}
			did_gen_something = true
			continue
		}
		// Set the struct values (args)
		xP.genln('$tmp_struct $dot_ptr $arg.name =  ')
		xP.expression()
		xP.genln(';')
		if i < f.args.len - 1 {
			xP.check(.COMMA)
			str_args += ','
		}
		did_gen_something = true
	}

	if !did_gen_something {
		// Msvc doesn't like empty struct
		arg_struct += 'EMPTY_STRUCT_DECLARATION;'
	}

	arg_struct += '} $arg_struct_name ;'
	// Also register the wrapper, so we can use the original function without modifying it
	fn_name = xP.table.fn_gen_name(f)
	wrapper_name := '${fn_name}_thread_wrapper'
	wrapper_text := 'void* $wrapper_name($arg_struct_name * arg) {$fn_name( /*f*/$str_args );  }'
	xP.cgen.register_thread_fn(wrapper_name, wrapper_text, arg_struct)
	// Create thread object
	tmp_nr := xP.get_tmp_counter()
	thread_name = '_thread$tmp_nr'
	if xP.os != .windows && xP.os != .msvc {
		xP.genln('pthread_t $thread_name;')
	}
	tmp2 := xP.get_tmp()
	mut xParg := 'NULL'
	if f.args.len > 0 {
		xParg = ' $tmp_struct'
	}
	// Call the wrapper
	if xP.os == .windows || xP.os == .msvc {
		xP.genln(' CreateThread(0,0, $wrapper_name, $xParg, 0,0);')
	}
	else {
		xP.genln('int $tmp2 = pthread_create(& $thread_name, NULL, $wrapper_name, $xParg);')
	}
	xP.check(.RPAR)
}

// xP.tk == fn_name
fn (xP mut Parser) fn_call(f Fn, method_sh int, receiver_var, receiver_type string) {
	if !f.is_public &&  !f.is_c && !xP.pref.is_test && !f.is_interface && f.mod != xP.mod  {
		if f.name == 'contains' {
			println('use `value in data` instead of `data.contains(value)`')
		}
		xP.error('function `$f.name` is private')
	}
	xP.calling_c = f.is_c
	if f.is_c && !xP.builtin_mod {
		if f.name == 'free' {
			xP.error('use `free()` instead of `C.free()`')
		} else if f.name == 'malloc' {
			xP.error('use `malloc()` instead of `C.malloc()`')
		}
	}
	mut cgen_name := xP.table.fn_gen_name(f)
	xP.next()
	mut gen_type := ''
	if xP.tk == .LESSER {
		xP.check(.LESSER)
		gen_type = xP.check_name()
		// run<T> => run_App
		if gen_type == 'T' && xP.cur_gen_type != '' {
			gen_type = xP.cur_gen_type
		}
		// `foo<Bar>()`
		// If we are in the first CheckPoint, we need to add `Bar` type to the generic function `foo`,
		// so that generic `foo`s body can be generated for each type in the second CheckPoint.
		if xP.first_cp() {
			println('registering $gen_type in $f.name fname=$f.name')
			xP.table.register_generic_fn_type(f.name, gen_type)
			// Function bodies are skipped in the first CheckPoint, we only need to register the generic type here.
			return
		}
		cgen_name += '_' + gen_type
		xP.check(.GREATER)
	}
	// if xP.pref.is_prof {
	// xP.cur_fn.called_fns << cgen_name
	// }
	// Normal function call
	if !f.is_method {
		xP.gen(cgen_name)
		xP.gen('(')
		// xP.fgen(f.name)
	}
	// If we have a method shadow,
	// we need to preappend "method(receiver, ...)"
	else {
		receiver := f.args.first()
		//println('r=$receiver.typ RT=$receiver_type')
		if receiver.is_mutable && !xP.expr_var.is_mutable {
			//println('$method_call  recv=$receiver.name recv_mutable=$receiver.is_mutable')
			xP.error('`$xP.expr_var.name` is immutable, declare it with `mut`')
		}
		if !xP.expr_var.is_changed {
			xP.mark_var_changed(xP.expr_var)
		}
		xP.gen_method_call(receiver_type, f.typ, cgen_name, receiver, method_sh)
	}
	// foo<Bar>()
	xP.fn_call_args(mut f)
	xP.gen(')')
	xP.calling_c = false
	// println('end of fn call typ=$f.typ')
}

// for declaration
// return an updated Fn object with args[] field set
fn (xP mut Parser) fn_args(f mut Fn) {
	xP.check(.LPAR)
	defer { xP.check(.RPAR) }
	if f.is_interface {
		int_arg := Var {
			typ: f.receiver_typ
		}
		f.args << int_arg
	}
	// `(int, string, int)`
	// Just register fn arg types
	types_only := xP.tk == .STAR || xP.tk == .AMPER || (xP.peek() == .COMMA && xP.table.known_type(xP.lit)) || xP.peek() == .RPAR// (int, string)
	if types_only {
		for xP.tk != .RPAR {
			typ := xP.get_type()
			var := Var {
				typ: typ
				is_arg: true
				// is_mutable: is_mutable
				line_no_y: xP.scanner.line_no_y
				scanner_pos_x: xP.scanner.get_scanner_pos()
			}
			// f.register_var(var)
			f.args << var
			if xP.tk == .COMMA {
				xP.next()
			}
		}
	}
	// `(a int, b, c string)` syntax
	for xP.tk != .RPAR {
		mut names := [
		xP.check_name()
		]
		// `a,b,c int` syntax
		for xP.tk == .COMMA {
			xP.check(.COMMA)
			xP.fspace()
			names << xP.check_name()
		}
		xP.fspace()
		is_mutable := xP.tk == .key_mutable
		if is_mutable {
			xP.next()
		}
		mut typ := xP.get_type()
		if is_mutable && is_primitive_type(typ) {
			xP.error('mutable arguments are only allowed for arrays, maps, and structs.' +
			'\nreturn values instead: `foo(n mut int)` => `foo(n int) int`')
		}
		for name in names {
			if !xP.first_cp() && !xP.table.known_type(typ) {
				xP.error('fn_args: unknown type $typ')
			}
			if is_mutable {
				typ += '*'
			}
			var := Var {
				name: name
				typ: typ
				is_arg: true
				is_mutable: is_mutable
				ptr: is_mutable
				line_no_y: xP.scanner.line_no_y
				scanner_pos_x: xP.scanner.get_scanner_pos()        
			}
			f.register_var(var)
			f.args << var
		}
		if xP.tk == .COMMA {
			xP.next()
		}
		if xP.tk == .DOTDOT {
			f.args << Var {
				name: '..'
			}
			xP.next()
		}
	}
}

// foo *(1, 2, 3, mut bar)*
fn (xP mut Parser) fn_call_args(f mut Fn) &Fn {
	// println('fn_call_args() name=$f.name args.len=$f.args.len')
	// C func. # of args is not known
	xP.check(.LPAR)
	if f.is_c {
		for xP.tk != .RPAR {
			//C.func(var1, var2.method())
			//If the parameter calls a function or method that is not C,
			//the value of xP.calling_c is changed
			xP.calling_c = true
			sh := xP.cgen.add_shadow()
			typ := xP.bool_expression()
			// Cast UTxQ byteptr to C char* (byte is unsigned in UTxQ, that led to C warnings)
			if typ == 'byte*' {
				xP.cgen.set_shadow(sh, '(char*)')
			}	
			if xP.tk == .COMMA {
				xP.gen(', ')
				xP.check(.COMMA)
			}
		}
		xP.check(.RPAR)
		return f
	}
	// add debug information to panic when -debug arg is passed
	if xP.xQ.pref.is_debug && f.name == 'panic' && !xP.is_js {
		mod_name := xP.mod.replace('_dot_', '.')
		fn_name := xP.cur_fn.name.replace('${xP.mod}__', '')
		file_path := xP.file_path.replace('\\', '\\\\') // escape \
		xP.cgen.resetln(xP.cgen.cur_line.replace(
			'xQ_panic (',
			'_panic_debug ($xP.scanner.line_no_y, tos2((byte *)"$file_path"), tos2((byte *)"$mod_name"), tos2((byte *)"$fn_name"), '
		))
	}
	// Receiver - first arg
	for i, arg in f.args {
		// println('$i) arg=$arg.name')
		// Skip receiver, because it was already generated in the expression
		if i == 0 && f.is_method {
			if f.args.len > 1 && !p.is_js {
				xP.gen(',')
			}
			continue
		}
		// Reached the final vararg? Quit
		if i == f.args.len - 1 && arg.name == '..' {
			break
		}
		sh := xP.cgen.add_shadow()
		// `)` here means that not enough args were provided
		if xP.tk == .RPAR {
			str_args := f.str_args(xP.table)// TODO this is C args
			xP.error('not enough arguments in call to `$f.name ($str_args)`')
		}
		// If `arg` is mutable, the caller needs to provide `mut`:
		// `mut numbers := [1,2,3]; reverse(mut numbers);`
		if arg.is_mutable {
			if xP.tk != .key_mutable && xP.tk == .NAME {
				mut dots_example :=  'mut $xP.lit'
				if i > 0 {
					dots_example = '.., ' + dots_example
				}
				if i < f.args.len - 1 {
					dots_example = dots_example + ',..'
				}
				xP.error('`$arg.name` is a mutable argument, you need to provide `mut`: `$f.name($dots_example)`')
			}
			if xP.peek() != .NAME {
				xP.error('`$arg.name` is a mutable argument, you need to provide a variable to modify: `$f.name(... mut a...)`')
			}
			xP.check(.key_mutable)
			var_name := xP.lit
			var := xP.cur_fn.find_var(var_name) or {
				xP.error('`$arg.name` is a mutable argument, you need to provide a variable to modify: `$f.name(... mut a...)`')
				exit(1)
			}
			if !var.is_changed {
				xP.mark_var_changed(var)
			}
		}
		xP.expected_type = arg.typ
		typ := xP.bool_expression()
		// Optimize `println`: replace it with `printf` to avoid extra allocations and
		// function calls.
		// `println(777)` => `printf("%d\n", 777)`
		// (If we don't check for void, then UTxQ will compile `println(func())`)
		if i == 0 && (f.name == 'println' || f.name == 'print') && typ == 'ustring' {
			if typ == 'ustring' {
				xP.gen('.s')
			}
			typ = 'string'
		}
		if i == 0 && (f.name == 'println' || f.name == 'print')  && typ != 'string' && typ != 'ustring' && typ != 'void' {
			T := xP.table.find_type(typ)
			$if !windows {
			$if !js {
				fmt := xP.typ_to_format(typ, 0)
				if fmt != '' {
					xP.cgen.resetln(xP.cgen.cur_line.replace(f.name + ' (', '/*opt*/printf ("' + fmt + '\\n", '))
					continue
				}
			}
			}
			if typ.ends_with('*') {
				xP.cgen.set_shadow(sh, 'ptr_str(')
				xP.gen(')')
				continue
			}
			// Make sure this type has a `str()` method
			$if !js {
			if !T.has_method('str') {
				// Arrays have automatic `str()` methods
				if T.name.starts_with('array_') {
					xP.gen_array_str(T)
					xP.cgen.set_shadow(sh, '${typ}_str(')
					xP.gen(')')
					continue
				}
				error_msg := ('`$typ` needs to have method `str() string` to be printable')
				if T.fields.len > 0 {
					mut index := xP.cgen.cur_line.len - 1
					for index > 0 && xP.cgen.cur_line[index - 1] != `(` { index-- }
					name := xP.cgen.cur_line.right(index + 1)
					if name == '}' {
						xP.error(error_msg)
					}
					xP.cgen.resetln(xP.cgen.cur_line.left(index))
					xP.scanner.create_type_string(T, name)
					xP.cgen.cur_line.replace(typ, '')
					xP.next()
					return xP.fn_call_args(mut f)
				}
				xP.error(error_msg)
			}
			xP.cgen.set_shadow(sh, '${typ}_str(')
			xP.gen(')')
			}
			continue
		}
		got := typ
		expected := arg.typ
		// println('fn arg got="$got" exp="$expected"')
		if !xP.check_types_no_throw(got, expected) {
			mut err := 'Fn "$f.name" wrong arg #${i+1}. '
			err += 'Expected "$arg.typ" ($arg.name)  but got "$typ"'
			xP.error(err)
		}
		is_interface := xP.table.is_interface(arg.typ)
		// Add `&` or `*` before an argument?
		if !is_interface {
			// Dereference
			if got.contains('*') && !expected.contains('*') {
				xP.cgen.set_shadow(sh, '*')
			}
			// Reference
			// TODO ptr hacks. fix please.
			if !got.contains('*') && expected.contains('*') && got != 'voidptr' {
				// Special case for mutable arrays. We can't `&` function results,
				// have to use `(array[]){ expr }` hack.
				if expected.starts_with('array_') && expected.ends_with('*') {
					xP.cgen.set_shadow(sh, '& /*111*/ (array[]){')
					xP.gen('}[0] ')
				}
				// println('\ne:"$expected" got:"$got"')
				else if ! (expected == 'void*' && got == 'int') &&
				! (expected == 'byte*' && got.contains(']byte')) &&
				! (expected == 'byte*' && got == 'string') &&
				//! (expected == 'void*' && got == 'array_int') {
				! (expected == 'byte*' && got == 'byteptr') {
					xP.cgen.set_shadow(sh, '& /*112 EXP:"$expected" GOT:"$got" */')
				}
			}
		}
		// interface?
		if is_interface {
			if !got.contains('*') {
				xP.cgen.set_shadow(sh, '&')
			}
			// Pass all interface methods
			interface_type := xP.table.find_type(arg.typ)
			for method in interface_type.methods {
				xP.gen(', ${typ}_${method.name} ')
			}
		}
		// Check for commas
		if i < f.args.len - 1 {
			// Handle 0 args passed to varargs
			is_vararg := i == f.args.len - 2 && f.args[i + 1].name == '..'
			if xP.tk != .COMMA && !is_vararg {
				xP.error('wrong number of arguments for $i,$arg.name fn `$f.name`: expected $f.args.len, but got less')
			}
			if xP.tk == .COMMA {
				xP.fgen(', ')
			}
			if !is_vararg {
				xP.next()
				xP.gen(',')
			}
		}
	}
	// varargs
	if f.args.len > 0 {
		last_arg := f.args.last()
		if last_arg.name == '..' {
			for xP.tk != .RPAR {
				if xP.tk == .COMMA {
					xP.gen(',')
					xP.check(.comma)
				}
				xP.bool_expression()
			}
		}
	}
	if xP.tk == .COMMA {
		xP.error('wrong number of arguments for fn `$f.name`: expected $f.args.len, but got more')
	}
	xP.check(.RPAR)
	// xP.gen(')')
	return f // TODO is return f right?
}

// "fn (int, string) int"
fn (f Fn) typ_str() string {
	mut sb := StringX.new_builder(50)
	sb.write('fn (')
	for i, arg in f.args {
		sb.write(arg.typ)
		if i < f.args.len - 1 {
			sb.write(',')
		}
	}
	sb.write(')')
	if f.typ != 'void' {
		sb.write(' $f.typ')
	}
	return sb.str()
}

// f.args => "int a, string b"
fn (f &Fn) str_args(table &dataTable) string {
	mut s := ''
	for i, arg in f.args {
		// Interfaces are a special case. We need to pass the object + pointers
		// to all methods:
		// fn handle(r Runner) { =>
		// void handle(void *r, void (*Runner_run)(void*)) {
		if table.is_interface(arg.typ) {
			// First the object (same name as the interface argument)
			s += ' void* $arg.name'
			// Now  all methods
			interface_type := table.find_type(arg.typ)
			for method in interface_type.methods {
				s += ', $method.typ (*${arg.typ}_${method.name})(void*'
				if method.args.len > 1 {
					for a in method.args.right(1) {
						s += ', $a.typ'
					}
				}
				s += ')'
			}
		}
		else if arg.name == '..' {
			s += '...'
		}
		else {
			// s += '$arg.typ $arg.name'
			s += table.cgen_name_type_pair(arg.name, arg.typ)// '$arg.typ $arg.name'
		}
		if i < f.args.len - 1 {
			s += ', '
		}
	}
	return s
}

// Find local function variable with closest name to `name`
fn (f &Fn) find_misspelled_local_var(name string, min_match f32) string {
	mut closest := f32(0)
	mut closest_var := ''
	for var in f.local_vars {
		if var.scope_level > f.scope_level {
			continue
		}
		n := name.all_after('.')
		if var.name == '' || (n.len - var.name.len > 2 || var.name.len - n.len > 2) { continue }
		r := StringX.dice_coefficient(var.name, n)
		if r > closest {
			closest = r
			closest_var = var.name
		}
	}
	return if closest >= min_match { closest_var } else { '' }
}
