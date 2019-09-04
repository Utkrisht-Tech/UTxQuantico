// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import (
	os
	rand
	strings
)

struct Parser {
	file_path      string // "/home/user/hello.xq"
	file_name      string // "hello.xq"
	file_platform  string // ".xq", "_win.xq", "_nix.xq", "_mac.xq", "_lin.xq" ...
	file_xPcguard  string // When xP.file_xPcguard != '', it contains a
	                      // C ifdef guard clause that must be put before
	                      // the #include directives in the parsed .xq file
mut:
	xQ             &UTxQ
	scanner        &Scanner
	// tokens      []Token // TODO cache all tokens, right now they have to be scanned twice
	token_idx      int
	tk             Token
	prev_tk        Token
	prev_tk2       Token // TODO remove these once the tokens are cached
	lit            string
	cgen           &CGen
	table          &dataTable
	import_table   &ParsedImportsTable // Holds imports for just the file being parsed
	cp             CheckPoint
	os             OS
	mod            string
	inside_const   bool
	expr_var       Var
	has_immutable_field bool
	first_immutable_field Var
	assigned_type  string
	expected_type  string
	tmp_count      int
	is_script      bool
	pref           &Preferences // Setting and Preferences shared from UTxQ struct
	builtin_mod    bool
	xQh_lines      []string
	inside_if_expr bool
	inside_unwrapping_match_statement bool
	is_struct_init bool
	if_expr_count  int
	for_expr_count int // to detect whether `continue` can be used
	ptr_cast       bool
	calling_c      bool
	cur_fn         &Fn
	returns        bool
	xQRoot         string
	is_c_struct_init bool
	is_empty_c_struct_init bool
	is_c_fn_call   bool
	can_chash      bool
	attr           string
	xQ_script 		 bool // "UTxQ bash", import all os functions into global space
	var_decl_name	 string 	// To allow declaring the variable so that it can be used in the struct initialization
	building_xQ		 bool
	is_alloc		   bool // Whether current expression resulted in an allocation
	cur_gen_type	 string // "App" to replace "T" in current generic function
	is_WebX        bool
	is_SqlX        bool
	SqlX_i         int  // $1 $2 $3
	SqlX_params    []string // ("select * from users where id = $1", ***"100"***)
	SqlX_types 		 []string // int, string and so on; see SqlX_params
}

const (
	EmptyFn = &Fn { }
	MainFn= &Fn{name:'main'}
)

const (
	MaxModuleDepth = 4
)

fn (xQ mut UTxQ) new_parser(path string) Parser {
	//println('new_parser("$path")')
	mut path_xPcguard := ''
	mut path_platform := '.xq'
	for path_ending in ['_lin.xq', '_mac.xq', '_win.xq', '_nix.xq'] {
		if path.ends_with(path_ending) {
			path_platform = path_ending
			path_xPcguard = platform_postfix_to_ifdefguard( path_ending )
			break
		}
	}

	mut xP := Parser {
		xQ: xQ
		file_path: path
		file_name: path.all_after('/')
		file_platform: path_platform
		file_xPcguard: path_xPcguard
		scanner: new_scanner(path)
		table: xQ.table
		import_table: new_file_import_table(path)
		cur_fn: EmptyFn
		cgen: xQ.cgen
		is_script: (xQ.pref.is_script && path == xQ.dir)
		pref: xQ.pref
		os: xQ.os
		xQRoot: xQ.xQRoot
		building_xQ: !xQ.pref.is_repl && (path.contains('UTxQCompiler/') || path.contains('UTxQ/xQLib'))

	}

	xQ.cgen.line_directives = xQ.pref.is_debuggable
	xQ.cgen.file = path

	xP.next()
	// xP.scanner.debug_tokens()
	return xP
}

fn (xP mut Parser) next() {
	xP.prev_tk2 = xP.prev_tk
	xP.prev_tk = xP.tk
	xP.scanner.prev_tk = xP.tk
	res := xP.scanner.scan()
	xP.tk = res.tk
	xP.lit = res.lit
}

fn (xP &Parser) log(s string) {
/*
	if !xP.pref.is_verbose {
		return
	}
	println(s)
*/
}

fn (xP mut Parser) parse(cp CheckPoint) {
	xP.cp = cp
	xP.log('\nparse() run=$xP.cp file=$xP.file_name tk=${xP.strtk()}')// , "script_file=", script_file)
	// `module main` is not required if it's a single file program
	if xP.is_script || xP.pref.is_test {
		xP.mod = 'main'
		// User may still specify `module main`
		if xP.tk == .key_module {
			xP.next()
			xP.fgen('module ')
			xP.mod = xP.check_name()
		}
	}
	else {
		xP.check(.key_module)
		xP.fspace()
		xP.mod = xP.check_name()
	}
	xP.fgenln('\n')
	xP.builtin_mod = xP.mod == 'builtin'
	xP.can_chash = xP.mod=='ui' || xP.mod == 'linux'// TODO tmp remove
	// Import CheckPoint - the first and the smallest CheckPoint that only analyzes imports
	// fully qualify the module name, eg base64 to encoding.base64
	fq_mod := xP.table.qualify_module(xP.mod, xP.file_path)
	xP.import_table.module_name = fq_mod
	xP.table.register_module(fq_mod)
	// replace "." with "_dot_" in module name for C variable names
	xP.mod = fq_mod.replace('.', '_dot_')
	if xP.cp == .imports {
		for xP.tk == .key_import && xP.peek() != .key_const {
			xP.imports()
		}
		if xP.table.imports.contains('builtin') {
			xP.error('module `builtin` cannot be imported')
		}
		// save Parsed imports table
		xP.table.file_imports << *xP.import_table
		return
	}
	// Go through every top level token or throw a compilation error if a non-top level token is met
	for {
		switch xP.tk {
		case .key_import:
			if xP.peek() == .key_const {
				xP.const_decl()
			}
			else {
				// TODO remove imported consts from the language
				xP.imports()
				if xP.tk != .key_import {
					xP.fgenln('')
				}
			}
		case Token.key_enum:
			xP.next()
			if xP.tk == .NAME {
				xP.fgen('enum ')
				name := xP.check_name()
				xP.fgen(' ')
				xP.enum_decl(name)
			}
			// enum without a name, only allowed in code, translated from C
			// it's a very bad practice in C as well, but is commonly used
			// such fields are basically int consts
			else if xP.pref.translated {
				xP.enum_decl('int')
			}
			else {
				xP.check(.NAME)
			}
		case Token.key_public:
			if xP.peek() == .key_function {
				xP.fn_decl()
			} else if xP.peek() == .key_struct {
				xP.error('structs can\'t be declared public *yet*')
				// TODO public structs
			} else {
				xP.error('wrong public keyword usage')
			}
		case Token.key_function:
			xP.fn_decl()
		case Token.key_type:
			xP.type_decl()
		case Token.LSBR:
			// `[` can only mean an [attribute] before a function
			// or a struct definition
			xP.attribute()
		case Token.key_struct, Token.key_interface, Token.key_union, Token.LSBR:
			xP.struct_decl()
		case Token.key_const:
			xP.const_decl()
		case Token.HASH:
			// insert C code, TODO Removed ASAP
			// some libraries (like UI) still have lots of C code
			// # puts("hello");
			xP.chash()
		case Token.DOLLAR:
			// $if, $else
			xP.comp_time()
		case Token.key_global:
			if !xP.pref.translated && !xP.pref.is_live && !xP.builtin_mod && !xP.building_xQ && !os.getwd().contains('/volt') {
				xP.error('global is only allowed in translated code')
			}
			xP.next()
			name := xP.check_name()
			typ := xP.get_type()
			xP.register_global(name, typ)
			// xP.genln(xP.table.cgen_name_type_pair(name, typ))
			mut g := xP.table.cgen_name_type_pair(name, typ)
			if xP.tk == .ASSIGN {
				xP.next()
				// xP.gen(' = ')
				g += ' = '
				xP.cgen.start_tmp()
				xP.bool_expression()
				// g += '<<< ' + xP.cgen.end_tmp() + '>>>'
				g += xP.cgen.end_tmp()
			}
			// xP.genln('; // global')
			g += '; // global'
			xP.cgen.consts << g
		case Token.EOF:
			xP.log('end of parse()')
			if xP.is_script && !xP.pref.is_test {
				xP.cur_fn = MainFn
				xP.check_unused_variables()
			}
			if false && !xP.first_cp() && xP.fileis('main.xq') {
				out := os.create('/var/tmp/fmt.xq') or {
					cerror('failed to create fmt.xq')
					return
				}
				out.writeln(xP.scanner.format_out.str())
				out.close()
			}
			return
		default:
			// no `fn main`, add this "global" statement to cgen.fn_main
			if xP.is_script && !xP.pref.is_test {
				// cur_fn is empty since there was no fn main declared
				// we need to set it to save and find variables
				if xP.first_cp() {
					if xP.cur_fn.name == '' {
						xP.cur_fn = MainFn
					}
					return
				}
				if xP.cur_fn.name == '' {
					xP.cur_fn = MainFn
					if xP.pref.is_repl {
						xP.cur_fn.clear_vars()
					}
				}
				mut start := xP.cgen.lines.len
				xP.statement(true)
				if xP.cgen.lines[start - 1] != '' && xP.cgen.fn_main != '' {
					start--
				}
				xP.genln('')
				end := xP.cgen.lines.len
				lines := xP.cgen.lines.slice(start, end)
				//mut line := xP.cgen.fn_main + lines.join('\n')
				//line = line.trim_space()
				xP.cgen.fn_main = xP.cgen.fn_main + lines.join('\n')
				xP.cgen.resetln('')
				for i := start; i < end; i++ {
					xP.cgen.lines[i] = ''
				}
			}
			else {
				xP.error('unexpected token `${xP.strtk()}`')
			}
		}
	}
}

fn (xP mut Parser) imports() {
	xP.check(.key_import)
	// `import (foo bar)`
	if xP.tk == .LPAR {
		xP.check(.LPAR)
		for xP.tk != .RPAR && xP.tk != .EOF {
			xP.import_statement()
		}
		xP.check(.RPAR)
		return
	}
	// `import foo`
	xP.import_statement()
}

fn (xP mut Parser) import_statement() {
	if xP.tk != .NAME {
		xP.error('bad import format')
	}
	if xP.peek() == .NUMBER && xP.scanner.text[xP.scanner.pos_x + 1] == `.` {
		xP.error('bad import format. module/submodule names cannot begin with a number.')
	}
	mut mod := xP.check_name().trim_space()
	mut mod_alias := mod
	// submodule support
	mut depth := 1
	for xP.tk == .dot {
		xP.check(.dot)
		submodule := xP.check_name()
		mod_alias = submodule
		mod += '.' + submodule
		depth++
		if depth > MaxModuleDepth {
			xP.error('module depth of $MaxModuleDepth exceeded: $mod')
		}
	}
	// aliasing (import encoding.base64 as b64)
	if xP.tk == .key_as && xP.peek() == .NAME {
		xP.check(.key_as)
		mod_alias = xP.check_name()
	}
	// add import to file scope import table
	xP.import_table.register_alias(mod_alias, mod)
	// Make sure there are no duplicate imports
	if xP.table.imports.contains(mod) {
		return
	}
	xP.log('adding import $mod')
	xP.table.imports << mod
	xP.table.register_module(mod)

	xP.fgenln(' ' + mod)
}

fn (xP mut Parser) const_decl() {
	if xP.tk == .key_import {
		xP.error('`import const` was removed from the language, ' +
			'use `foo(C.CONST_NAME)` instead')
	}
	xP.inside_const = true
	xP.check(.key_const)
	xP.fspace()
	xP.check(.LPAR)
	xP.fgenln('')
	xP.format_inc()
	for xP.tk == .NAME {
		// `Age = 14`
		mut name := xP.check_name()
		//if ! (name[0] >= `A` && name[0] <= `Z`) {
			//xP.error('const name must be capitalized')
		//}
		name = xP.prepend_mod(name)
		xP.check_space(.assign)
		typ := xP.expression()
		if xP.first_cp()  && xP.table.known_const(name) {
			xP.error('redefinition of `$name`')
		}
		xP.table.register_const(name, typ, xP.mod)
		if xP.cp == .main {
			// TODO hack
			// cur_line has const's value right now. if it's just a number, then optimize generation:
			// output a #define so that we don't pollute the binary with unnecessary global vars
			if is_compile_time_const(xP.cgen.cur_line) {
				xP.cgen.consts << '#define $name $xP.cgen.cur_line'
				xP.cgen.resetln('')
				xP.fgenln('')
				continue
			}
			if typ.starts_with('[') {
				xP.cgen.consts << xP.table.cgen_name_type_pair(name, typ) +
				' = $xP.cgen.cur_line;'
			}
			else {
				xP.cgen.consts << xP.table.cgen_name_type_pair(name, typ) + ';'
				xP.cgen.consts_init << '$name = $xP.cgen.cur_line;'
			}
			xP.cgen.resetln('')
		}
		xP.fgenln('')
	}
	xP.format_dec()
	xP.check(.RPAR)
	xP.fgenln('\n')
	xP.inside_const = false
}

// `type myint int`
// `type onclickfn fn(voidptr) int`
fn (xP mut Parser) type_decl() {
	xP.check(.key_type)
	name := xP.check_name()
	// 'type Foo struct', many Go users might use this syntax
	if xP.tk == .key_struct {
		xP.error('use `struct $name {` instead of `type $name struct {`')
	}
	parent := xP.get_type2()
	nt_pair := xP.table.cgen_name_type_pair(name, parent.name)
	// TODO dirty C typedef hacks
	// Unknown type probably means it's a struct, and it's used before the struct is defined,
	// so specify "struct"
	_struct := if parent.cat != .array && parent.cat != .function &&
		!xP.table.known_type(parent.name) {
		'struct'
	} else {
		''
	}
	xP.gen_typedef('typedef $_struct $nt_pair; //type alias name="$name" parent=`$parent.name`')
	xP.register_type_with_parent(name, parent.name)
}

fn (xP mut Parser) interface_method(field_name, receiver string) &Fn {
	mut method := &Fn {
		name: field_name
		is_interface: true
		is_method: true
		receiver_typ: receiver
	}
	xP.log('is interface. field=$field_name run=$xP.cp')
	xP.fn_args(mut method)
	if xP.scanner.has_gone_over_line_end() {
		method.typ = 'void'
	} else {
		method.typ = xP.get_type()// method return type
		xP.fspace()
		xP.fgenln('')
	}
	return method
}

fn key_to_type_cat(tk Token) TypeCategory {
	switch tk {
	case Token.key_interface:  return TypeCategory.interface
	case Token.key_struct: return TypeCategory.struct
	case Token.key_union: return TypeCategory.union
	//Token.key_ => return .interface
	}
	cerror('Unknown token: $tk')
	return TypeCategory.builtin
}

// also unions and interfaces
fn (xP mut Parser) struct_decl() {
	// UTxQ can generate Objective C for integration with Cocoa
	// `[interface:ParentInterface]`
	//is_objc := xP.attr.starts_with('interface')
	//objc_parent := if is_objc { xP.attr.right(10) } else { '' }
	// interface, union, struct
	is_interface := xP.tk == .key_interface
	is_union := xP.tk == .key_union
	is_struct := xP.tk == .key_struct
	mut cat := key_to_type_cat(xP.tk)
	xP.fgen(xP.tk.str() + ' ')
	// Get type name
	xP.next()
	mut name := xP.check_name()
	if name.contains('_') && !xP.pref.translated {
		xP.error('type names cannot contain `_`')
	}
	if is_interface && !name.ends_with('er') {
		xP.error('interface names temporarily have to end with `er` (e.g. `Speaker`, `Reader`)')
	}
	is_c := name == 'C' && xP.tk == .DOT
	if is_c {
		xP.check(.DOT)
		name = xP.check_name()
		cat = .c_struct
		if xP.attr == 'typedef' {
			cat = .c_typedef
		}
	}
	if !is_c && !good_type_name(name) {
		xP.error('bad struct name, e.g. use `HttpRequest` instead of `HTTPRequest`')
	}
	// Specify full type name
	if !is_c && !xP.builtin_mod && xP.mod != 'main' {
		name = xP.prepend_mod(name)
	}
	if xP.cp == .decl && xP.table.known_type(name) {
		xP.error('`$name` redeclared')
	}
	if !is_c {
		kind := if is_union {'union'} else {'struct'}
		xP.gen_typedef('typedef $kind $name $name;')
	}
	// Register the type
	mut typ := xP.table.find_type(name)
	mut is_sh := false
	if typ.is_shadow {
		// Update the Shadow (Shadow Types are not defined previously but are known to exist.)
		is_sh = true
		typ.name = name
		typ.mod = xP.mod
		typ.is_c = is_c
		typ.is_shadow = false
		typ.cat = cat
		xP.table.rewrite_type(typ)
	}
	else {
		typ = Type {
			name: name
			mod: xP.mod
			is_c: is_c
			cat: cat
		}
	}
	// Struct `C.Foo` declaration, no body
	if is_c && is_struct && xP.tk != .LCBR {
		xP.table.register_type2(typ)
		return
	}
	xP.fgen(' ')
	xP.check(.LCBR)
	// Struct fields
	mut is_public := false
	mut is_mutable := false
	mut names := []string// to avoid dup names TODO alloc perf
/*
	mut format_max_len := 0
	for field in typ.fields  {
		if field.name.len > max_len {
			format_max_len = field.name.len
		}
	}
	println('format max len = $max_len nrfields=$typ.fields.len cp=$xP.cp')
*/

	if !is_sh && xP.first_cp() {
		xP.table.register_type2(typ)
		//println('registering 1 nrfields=$typ.fields.len')
	}

	mut did_gen_something := false
	for xP.tk != .RCBR {
		if xP.tk == .key_public {
			if is_public {
				xP.error('structs can only have one `public:`, all public fields have to be grouped')
			}
			is_public = true
			xP.format_dec()
			xP.check(.key_public)
			if xP.tk != .key_mutable {
				xP.check(.COLON)
			}
			xP.format_inc()
			xP.fgenln('')
		}
		if xP.tk == .key_mutable {
			if is_mutable {
				xP.error('structs can only have one `mut:`, all private key_mutable fields have to be grouped')
			}
			is_mutable = true
			xP.format_dec()
			xP.check(.key_mutable)
			if xP.tk != .key_mutable {
				xP.check(.COLON)
			}
			xP.format_inc()
			xP.fgenln('')
		}
		// if is_public {
		// }
		// (mut) user *User
		// if xP.tk == .PLUS {
		// xP.next()
		// }
		// Check if reserved name
		field_name := if name != 'Option' { xP.table.var_cgen_name(xP.check_name()) } else { xP.check_name() }
		// Check dupslicates
		if field_name in names {
			xP.error('duplicate field `$field_name`')
		}
		if !is_c && xP.mod != 'os' && contains_capital(field_name) {
			xP.error('struct fields cannot contain uppercase letters, use snake_case instead')
		}
		names << field_name
		// We are in an interface?
		// `run() string` => run is a method, not a struct field
		if is_interface {
			f := xP.interface_method(field_name, name)
			if xP.first_cp() {
				xP.table.add_method(typ.name, f)
			}
			continue
		}
		// `public` access mod
		access_mod := if is_public{AccessMod.public} else { AccessMod.private}
		xP.fgen(' ')
		field_type := xP.get_type()
		is_atomic := xP.tk == .key_atomic
		if is_atomic {
			xP.next()
		}
		// [ATTR]
		mut attr := ''
		if xP.tk == .LSBR {
			xP.next()
			attr = xP.check_name()
			if xP.tk == .COLON {
				xP.check(.COLON)
				attr += ':' + xP.check_name()
			}
			xP.check(.RSBR)
		}
		if attr == 'raw' && field_type != 'string' {
			xP.error('struct field with attribute "raw" should be of type "string" but got "$field_type"')
		}

		did_gen_something = true
		if xP.first_cp() {
			xP.table.add_field(typ.name, field_name, field_type, is_mutable, attr, access_mod)
		}
		xP.fgenln('')
	}
	xP.check(.RCBR)
	if !is_c {
		if !did_gen_something {
			if xP.first_cp() {
				xP.table.add_field(typ.name, '', 'EMPTY_STRUCT_DECLARATION', false, '', .private)
			}
		}
	}
	xP.fgenln('\n')
}

fn (xP mut Parser) enum_decl(_enum_name string) {
	mut enum_name := _enum_name
	// Specify full type name
	if !xP.builtin_mod && xP.mod != 'main' {
		enum_name = xP.prepend_mod(enum_name)
	}
	// Skip empty enums
	if enum_name != 'int' && !xP.first_cp() {
		xP.cgen.typedefs << 'typedef int $enum_name;'
	}
	xP.check(.LCBR)
	mut val := 0
	mut fields := []string
	for xP.tk == .NAME {
		field := xP.check_name()
		fields << field
		xP.fgenln('')
		name := '${xP.mod}__${enum_name}_$field'
		if xP.cp == .main {
			xP.cgen.consts << '#define $name $val'
		}
		if xP.tk == .COMMA {
			xP.next()
		}
		xP.table.register_const(name, enum_name, xP.mod)
		val++
	}
	xP.table.register_type2(Type {
		name: enum_name
		mod: xP.mod
		parent: 'int'
		cat: TypeCategory.enum_
		enum_vals: fields
	})
	xP.check(.RCBR)
	xP.fgenln('\n')
}

// check_name checks for a name token and returns its literal
fn (xP mut Parser) check_name() string {
	name := xP.lit
	xP.check(.name)
	return name
}

fn (xP mut Parser) check_string() string {
	s := xP.lit
	xP.check(.STRING)
	return s
}

fn (xP &Parser) strtk() string {
	if xP.tk == .NAME {
		return xP.lit
	}
	if xP.tk == .STRING {
		return '"$xP.lit"'
	}
	res := xP.tk.str()
	if res == '' {
		n := int(xP.tk)
		return n.str()
	}
	return res
}

// same as check(), but adds a space to the formatter output
// TODO bad name
fn (xP mut Parser) check_space(expected Token) {
	xP.fspace()
	xP.check(expected)
	xP.fspace()
}

fn (xP mut Parser) check(expected Token) {
	if xP.tk != expected {
		println('check()')
		s := 'expected `${expected.str()}` but got `${xP.strtk()}`'
		xP.next()
		println('next token = `${xP.strtk()}`')
		print_backtrace()
		xP.error(s)
	}
	if expected == .RCBR {
		xP.format_dec()
	}
	xP.fgen(xP.strtk())
	// xQFmt: increase indentation on `{` unless it's `{}`
	if expected == .LCBR && xP.scanner.pos_x + 1 < xP.scanner.text.len && xP.scanner.text[xP.scanner.pos_x + 1] != `}` {
		xP.fgenln('')
		xP.format_inc()
	}
	xP.next()

if xP.scanner.line_comment != '' {
	//xP.fgenln('// ! "$xP.scanner.line_comment"')
	//xP.scanner.line_comment = ''
}
}

fn (xP mut Parser) warn(s string) {
				println('warning: $xP.scanner.file_path:${xP.scanner.line_no_y+1}: $s')
}

fn (xP mut Parser) error(s string) {
	// Dump all vars and types for debugging
	if xP.pref.is_debug {
		// os.write_to_file('/var/tmp/lang.types', '')//pes(xP.table.types))
		os.write_file('fns.txt', xP.table.debug_fns())
	}
	if xP.pref.is_verbose || xP.pref.is_debug {
		println('cp=$xP.cp fn=`$xP.cur_fn.name`\n')
	}
	xP.cgen.save()
	// UTxQ git pull hint
	cur_path := os.getwd()
	if !xP.pref.is_repl && !xP.pref.is_test && ( xP.file_path.contains('UTxQ/UTxQCompiler') || cur_path.contains('UTxQ/UTxQCompiler') ){
		println('\n=========================')
		println('It looks like you are building UTxQuantico. It is being frequently updated every day.')
		println('If you didn\'t modify UTxQ\'s code, most likely there was a change that ')
		println('lead to this error.')
		println('\nRun `xQ update`, that will most likely fix it.')
		//println('\nIf this doesn\'t help, re-install UTxQ from source or download a precompiled' + ' binary from\nhttps://UTxQuantico.io.')
		println('\nIf this doesn\'t help, please create a GitHub issue.')
		println('=========================\n')
	}
	if xP.pref.is_debug {
		print_backtrace()
	}
	// xP.scanner.debug_tokens()
	// Print `[]int` instead of `array_int` in errors
	xP.scanner.error(s.replace('array_', '[]').replace('__', '.').replace('Option_', '?'))
}

fn (xP &Parser) first_cp() bool {
	return xP.cp == .decl
}

// TODO return Type instead of string?
fn (xP mut Parser) get_type() string {
	mut star := false
	mut nr_stars := 0
	mut typ := ''
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
		// Register anon fn type
		fn_typ := Type {
			name: f.typ_str()// 'fn (int, int) string'
			mod: xP.mod
			function: f
		}
		xP.table.register_type2(fn_typ)
		return f.typ_str()
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
		return typ
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
		if typ == 'UTxQ' {
			//println('QQ UTxQ res=$t.name')
		}
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
	// Because the code uses * to see if it's a pointer
	if typ == 'byteptr' {
		return 'byte*'
	}
	if typ == 'voidptr' {
		//if !xP.builtin_mod && xP.mod != 'os' && xP.mod != 'gx' && xP.mod != 'gg' && !xP.pref.translated {
			//xP.error('voidptr can only be used in unsafe code')
		//}
		return 'void*'
	}
	if typ.last_index('__') > typ.index('__') {
		xP.error('2 __ in gettype(): typ="$typ"')
	}
	return typ
}

fn (xP &Parser) print_tk() {
	if xP.tk == .NAME {
		println(xP.lit)
		return
	}
	if xP.tk == .STRING {
		println('"$xP.lit"')
		return
	}
	println(xP.tk.str())
}

// statements() returns the type of the last statement
fn (xP mut Parser) statements() string {
	xP.log('statements()')
	typ := xP.statements_no_rcbr()
	if !xP.inside_if_expr {
		xP.genln('}')
	}
	//if xP.fileis('if_expr') {
		//println('statements() ret=$typ line=$xP.scanner.line_no_y')
	//}
	return typ
}

fn (xP mut Parser) statements_no_rcbr() string {
	xP.cur_fn.open_scope()

	if !xP.inside_if_expr {
		xP.genln('')
	}
	mut i := 0
	mut last_st_typ := ''
	for xP.tk != .RCBR && xP.tk != .EOF && xP.tk != .key_case &&
		xP.tk != .key_default && xP.peek() != .ARROW {
		// println(xP.tk.str())
		// xP.print_tk()
		last_st_typ = xP.statement(true)
		// println('last st typ=$last_st_typ')
		if !xP.inside_if_expr {
			xP.genln('')// // end st tk= ${xP.strtk()}')
			xP.fgenln('')
		}
		i++
		if i > 50000 {
			xP.cgen.save()
			xP.error('more than 50 000 statements in function `$xP.cur_fn.name`')
		}
	}
	if xP.tk != .key_case && xP.tk != .key_default && xP.peek() != .ARROW {
		// xP.next()
		xP.check(.RCBR)
	}
	else {
		// xP.check(.RCBR)
	}
	//xP.format_dec()
	// println('close scope line=$xP.scanner.line_no_y')

	xP.close_scope()
	return last_st_typ
}

fn (xP mut Parser) close_scope() {
	// println('close_scope level=$f.scope_level var_idx=$f.var_idx')
	// Move back `var_idx` (pointer to the end of the array) till we reach the previous scope level.
	// This effectivly deletes (closes) current scope.
	mut i := xP.cur_fn.var_idx - 1
	for ; i >= 0; i-- {
		xQ := xP.cur_fn.local_vars[i]
		if xQ.scope_level ≠ xP.cur_fn.scope_level {
			// println('breaking. "$xQ.name" xQ.scope_level=$xQ.scope_level')
			break
		}
		if false && !xP.building_xQ && !xQ.is_mutable && xQ.is_alloc {
			if xQ.typ.starts_with('array_') {
				xP.genln('xQ_array_free($xQ.name); // close_scope free')
			}
			else if xQ.typ == 'string' {
				xP.genln('xQ_string_free($xQ.name); // close_scope free')
			}
			else if xQ.ptr {
				//xQ.genln('free($xQ.name); // close_scope free')
			}
		}
	}

	if xP.cur_fn.defer_text.last() != '' {
		xP.genln(xP.cur_fn.defer_text.last())
		//xP.cur_fn.defer_text[f] = ''
	}

	xP.cur_fn.close_scope()
	xP.cur_fn.var_idx = i + 1
	// println('close_scope new var_idx=$f.var_idx\n')
}

fn (xP mut Parser) genln(s string) {
	xP.cgen.genln(s)
}

fn (xP mut Parser) gen(s string) {
	xP.cgen.gen(s)
}

// Generate UTxQ header from UTxQuantico's source
fn (xP mut Parser) xQh_genln(s string) {
	xP.xQh_lines << s
}

fn (xP mut Parser) statement(add_semi bool) string {
	if xP.returns && !xP.is_WebX {
		xP.error('unreachable code')
	}
	xP.cgen.is_tmp = false
	tk := xP.tk
	mut q := ''
	switch tk {
	case .NAME:
		next := xP.peek()
		if xP.pref.is_verbose {
			println(next.str())
		}
		// goto_label:
		if xP.peek() == .COLON {
			xP.format_dec()
			label := xP.check_name()
			xP.format_inc()
			xP.genln(label + ':')
			xP.check(.COLON)
			return ''
		}
		// `a := 777`
		else if xP.peek() == .DECL_ASSIGN {
			xP.var_decl()
		}
		else {
			// panic and exit count as returns since they stop the function
			if xP.lit == 'panic' || xP.lit == 'exit' {
				xP.returns = true
			}
			// `a + 3`, `a(7)`, or just `a`
			q = xP.bool_expression()
		}
	case Token.LCBR:// {} block
		xP.check(.LCBR)
		xP.genln('{')
		xP.statements()
		return ''
	case Token.HASH:
		xP.chash()
		return ''
	case Token.DOLLAR:
		xP.comp_time()
	case Token.key_assert:
		xP.assert_statement()
	case Token.key_break:
		if xP.for_expr_count == 0 {
			xP.error('`break` statement outside `for`')
		}
		xP.genln('break')
		xP.check(.key_break)
	case Token.key_continue:
		if xP.for_expr_count == 0 {
			xP.error('`continue` statement outside `for`')
		}
		xP.genln('continue')
		xP.check(.key_continue)
	case Token.key_defer:
		xP.defer_statement()
		return ''
	case Token.key_for:
		xP.for_statement()
	case Token.key_go:
		xP.go_statement()
	case Token.key_goto:
		xP.check(.key_goto)
		xP.fgen(' ')
		label := xP.check_name()
		xP.genln('goto $label;')
		return ''
	case Token.key_if:
		xP.if_statement(false, 0)
	case Token.key_match:
		xP.match_statement(false)
	case Token.key_mutable, Token.key_static:
		xP.var_decl()
	case Token.key_return:
		xP.return_statement()
	case Token.key_switch:
		xP.switch_statement()
	default:
		// An expression as a statement
		typ := xP.expression()
		if xP.inside_if_expr {
		}
		else {
			xP.genln('; ')
		}
		return typ
	}
	// ? : uses , as statement separators
	if xP.inside_if_expr && xP.tk != .RCBR {
		xP.gen(', ')
	}
	if add_semi && !xP.inside_if_expr {
		xP.genln(';')
	}
	return q
	// xP.cgen.end_statement()
}

// is_map: are we in map assignment? (m[key] = val) if yes, dont generate '='
// this can be `user = ...`  or `user.field = ...`, in both cases `val` is `user`
fn (xP mut Parser) assign_statement(val Var, sh int, is_map bool) {
	xP.log('assign_statement() name=$val.name tk=')
	is_vid := xP.fileis('vid') // TODO remove
	tk := xP.tk
	//if !val.is_mutable && !val.is_arg && !xP.pref.translated && !val.is_global{
	if !val.is_mutable && !xP.pref.translated && !val.is_global && !is_vid {
		if val.is_arg {
			if xP.cur_fn.args.len > 0 && xP.cur_fn.args[0].name == val.name {
				println('make the receiver `$val.name` mutable: fn ($val.name mut $val.typ) $xP.cur_fn.name (...) {')
			}
		}
		xP.error('`$val.name` is immutable.')
	}
	if !val.is_changed {
		xP.cur_fn.mark_var_changed(val)
	}
	is_str := val.typ == 'string'
	switch tk {
	case Token.ASSIGN:
		if !is_map && !xP.is_empty_c_struct_init {
			xP.gen(' = ')
		}
	case Token.PLUS_ASSIGN:
		if is_str {
			xP.gen('= string_add($val.name, ')// TODO can't do `foo.bar += '!'`
		}
		else {
			xP.gen(' += ')
		}
	default: xP.gen(' ' + xP.tk.str() + ' ')
	}
	xP.fspace()
	xP.fgen(tk.str())
	xP.fspace()
	xP.next()
	pos := xP.cgen.cur_line.len
	expr_type := xP.bool_expression()
	// Allow `num = 4` where `num` is an `?int`
	if xP.assigned_type.starts_with('Option_') && expr_type == xP.assigned_type.right('Option_'.len) {
		println('allowing option asss')
		expr := xP.cgen.cur_line.right(pos)
		left := xP.cgen.cur_line.left(pos)
		typ := expr_type.replace('Option_', '')
		//xP.cgen.cur_line = left + 'opt_ok($expr)'
		xP.cgen.resetln(left + 'opt_ok($expr, sizeof($typ))')
	}
	else if !xP.builtin_mod && !xP.check_types_no_throw(expr_type, xP.assigned_type) {
		xP.scanner.line_no_y--
		xP.error('cannot use type `$expr_type` as type `$xP.assigned_type` in assignment')
	}
	if is_str && tk == .PLUS_ASSIGN {
		xP.gen(')')
	}
	// xP.assigned_var = ''
	xP.assigned_type = ''
	if !val.is_used {
		xP.cur_fn.mark_var_used(val)
	}
}

fn (xP mut Parser) var_decl() {
	xP.is_alloc = false
	is_mutable := xP.tk == .key_mutable || xP.prev_tk == .key_for
	is_static := xP.tk == .key_static
	if xP.tk == .key_mutable {
		xP.check(.key_mutable)
		xP.fspace()
	}
	if xP.tk == .key_static {
		xP.check(.key_static)
		xP.fspace()
	}
	// println('var decl tk=${xP.strtk()} ismutable=$is_mutable')
	name := xP.check_name()
	xP.var_decl_name = name
	// Don't allow declaring a variable with the same name. Even in a child scope
	// (shadowing is not allowed)
	if !xP.builtin_mod && xP.cur_fn.known_var(name) {
		v := xP.cur_fn.find_var(name)
		xP.error('redefinition of `$name`')
	}
	if name.len > 1 && contains_capital(name) {
		xP.error('variable names cannot contain uppercase letters, use snake_case instead')
	}
	xP.check_space(.DECL_ASSIGN) // :=
	// Generate expression to tmp because we need its type first
	// [TYP .NAME =] bool_expression()
	pos := xP.cgen.add_shadow()
	mut typ := xP.bool_expression()
	// Option check ? or {
	else_if := xP.tk == .key_else_if
	tmp := xP.get_tmp()
	if else_if {
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
			xP.error('`or` block must return/continue/break/panic')
		}
		xP.returns = false
	}
	xP.register_var(Var {
		name: name
		typ: typ
		is_mutable: is_mutable
		is_alloc: xP.is_alloc
	})
	if !else_if {
		gen_name := xP.table.var_cgen_name(name)
		mut nt_gen := xP.table.cgen_name_type_pair(gen_name, typ)
		// `foo := C.Foo{}` => `Foo foo;`
		if !xP.is_empty_c_struct_init {
			nt_gen += '='
		}
		if is_static {
			nt_gen = 'static $nt_gen'
		}
		xP.cgen.set_shadow(pos, nt_gen)
	}
	xP.var_decl_name = ''
	xP.is_empty_c_struct_init = false
}

const (
	and_or_error = 'use `()` to make the boolean expression clear\n' + 'for example: `(a && b) || c` instead of `a && b || c`'
)

fn (xP mut Parser) bool_expression() string {
	tk := xP.tk
	typ := xP.bterm()
	mut got_and := false // to catch `a && b || c` in one expression without ()
	mut got_or := false
	for xP.tk == .AND || xP.tk == .L_OR {
		if xP.tk == .AND {
			got_and = true
			if got_or { xP.error(and_or_error) }
		}
		if xP.tk == .L_OR {
			got_or = true
			if got_and { xP.error(and_or_error) }
		}
		if xP.is_SqlX {
			if xP.tk == .AND {
				xP.gen(' and ')
			}
			else if xP.tk == .L_OR {
				xP.gen(' or ')
			}
		} else {
			xP.gen(' ${xP.tk.str()} ')
		}
		xP.check_space(xP.tk)
		xP.check_types(xP.bterm(), typ)
	}
	if typ == '' {
		println('curline:')
		println(xP.cgen.cur_line)
		println(tk.str())
		xP.error('expr() returns empty type')
	}
	return typ
}

fn (xP mut Parser) bterm() string {
	sh := xP.cgen.add_shadow()
	mut typ := xP.expression()
	xP.expected_type = typ
	is_str := typ=='string'  &&   !xP.is_SqlX
	tk := xP.tk
	// if tk in [ .EQEQUAL, .GREATER, .LESSER, .LESSEQUAL, .GREATEREQUAL, .NOTEQUAL] {
	if tk == .EQEQUAL || tk == .NOTEQUAL || tk == .GREATEREQUAL || tk == .LESSEQUAL || tk == .GREATER || tk == .LESSER {
		xP.fgen(' ${xP.tk.str()} ')
		if is_str {
			xP.gen(',')
		}
		else if xP.is_SqlX && tk == .EQEQUAL {
			xP.gen('=')
		}
		else {
			xP.gen(tk.str())
		}
		xP.next()
		// `id == user.id` => `id == $1`, `user.id`
		if xP.is_SqlX {
			xP.SqlX_i++
			xP.gen('$' + xP.SqlX_i.str())
			xP.cgen.start_cut()
			xP.check_types(xP.expression(), typ)
			SqlX_param := xP.cgen.cut()
			xP.SqlX_params << SqlX_param
			xP.SqlX_types  << typ
			//println('*** SqlX type: $typ | param: $SqlX_param')
		}  else {
			xP.check_types(xP.expression(), typ)
		}
		typ = 'bool'
		if is_str { //&& !xP.is_SqlX {
			xP.gen(')')
			switch tk {
			case Token.EQEQUAL: xP.cgen.set_shadow(sh, 'string_eqeq(')
			case Token.NOTEQUAL: xP.cgen.set_shadow(sh, 'string_noteq(')
			case Token.GREATEREQUAL: xP.cgen.set_shadow(sh, 'string_greatereq(')
			case Token.LESSEQUAL: xP.cgen.set_shadow(sh, 'string_lesseq(')
			case Token.GREATER: xP.cgen.set_shadow(sh, 'string_greater(')
			case Token.LESSER: xP.cgen.set_shadow(sh, 'string_lesser(')
			}
/*
			 Token.EQEQUAL => xP.cgen.set_placeholder(sh, 'string_eqeq(')
			 Token.NOTEQUAL => xP.cgen.set_shadow(sh, 'string_noteq(')
			 Token.GREATEREQUAL => xP.cgen.set_shadow(sh, 'string_greatereq(')
			 Token.LESSEQUAL => xP.cgen.set_shadow(sh, 'string_lesseq(')
			 Token.GREATER => xP.cgen.set_shadow(sh, 'string_greater(')
			 Token.LESSER => xP.cgen.set_shadow(sh, 'string_lesser(')
*/
		}
	}
	return typ
}

// also called on *, &, @, . (enum)
fn (xP mut Parser) name_expr() string {
	xP.has_immutable_field = false
	sh := xP.cgen.add_shadow()
	// amp
	ptr := xP.tk == .AMPER
	deref := xP.tk == .STAR
	if ptr || deref {
		xP.next()
	}
	mut name := xP.lit
	xP.fgen(name)
	// known_type := xP.table.known_type(name)
	orig_name := name
	is_c := name == 'C' && xP.peek() == .DOT
	mut is_c_struct_init := is_c && ptr// a := &C.mycstruct{}
	if is_c {
		xP.next()
		xP.check(.DOT)
		name = xP.lit
		xP.fgen(name)
		// Currently struct init is set to true only we have `&C.Foo{}`, handle `C.Foo{}`:
		if !is_c_struct_init && xP.peek() == .LCBR {
			is_c_struct_init = true
		}
	}
	// enum value? (`color == .green`)
	if xP.tk == .DOT {
		//println('got enum dot val $xP.left_type cp=$xP.cp $xP.scanner.line_no_y left=$xP.left_type')
		T := xP.find_type(xP.expected_type)
		if T.cat == .enum {
			xP.check(.DOT)
			val := xP.check_name()
			// Make sure this enum value exists
			if !T.has_enum_val(val) {
				xP.error('enum `$T.name` does not have value `$val`')
			}
			xP.gen(T.mod + '__' + xP.expected_type + '_' + val)
		}
		return xP.expected_type
	}
	// //////////////////////////
	// module ?
	// Allow shadowing (gg = gg.newcontext(); gg.draw_triangle())
	if ((name == xP.mod && xP.table.known_mod(name)) || xP.import_table.known_alias(name)) && !xP.cur_fn.known_var(name) && !is_c {
		mut mod := name
		// must be aliased module
		if name != xP.mod && xP.import_table.known_alias(name) {
			// we replaced "." with "_dot_" in xP.mod for C variable names, do same here.
			mod = xP.import_table.resolve_alias(name).replace('.', '_dot_')
		}
		xP.next()
		xP.check(.DOT)
		name = xP.lit
		xP.fgen(name)
		name = prepend_mod(mod, name)
	}
	else if !xP.table.known_type(name) && !xP.cur_fn.known_var(name) &&	!xP.table.known_fn(name) && !xP.table.known_const(name) && !is_c {
		name = xP.prepend_mod(name)
	}
	// Variable
	mut v := xP.cur_fn.find_var(name)
	// A hack to allow `newvar := Foo{ field: newvar }`
	// Declare the variable so that it can be used in the initialization
	if name == 'main__' + xP.var_decl_name {
		v.name = xP.var_decl_name
		v.typ = 'voidptr'
		v.is_mutable = true
	}
	if v.name.len != 0 {
		if ptr {
			xP.gen('& /*xQVar*/ ')
		}
		else if deref {
			xP.gen('*')
		}
		mut typ := xP.var_expr(v)
		// *var
		if deref {
			if !typ.contains('*') && !typ.ends_with('ptr') {
				println('name="$name", t=$v.typ')
				xP.error('dereferencing requires a pointer, but got `$typ`')
			}
			typ = typ.replace('ptr', '')// TODO
			typ = typ.replace('*', '')// TODO
		}
		// &var
		else if ptr {
			typ += '*'
		}
		return typ
	}
	// if known_type || is_c_struct_init || (xP.first_cp() && xP.peek() == .LCBR) {
	// known type? int(4.5) or Color.green (enum)
	if xP.table.known_type(name) {
		// float(5), byte(0), (*int)(ptr) etc
		if !is_c && ( xP.peek() == .LPAR || (deref && xP.peek() == .RPAR) ) {
			if deref {
				name += '*'
			}
			else if ptr {
				name += '*'
			}
			xP.gen('(')
			mut typ := xP.cast(name)
			xP.gen(')')
			for xP.tk == .DOT {
				typ = xP.dot(typ, sh)
			}
			return typ
		}
		// Color.green
		else if xP.peek() == .DOT {
			enum_type := xP.table.find_type(name)
			if enum_type.cat != .enum {
				xP.error('`$name` is not an enum')
			}
			xP.next()
			xP.check(.DOT)
			val := xP.lit
			// println('enum val $val')
			xP.gen(enum_type.mod + '__' + enum_type.name + '_' + val)// `color = main__Color_green`
			xP.next()
			return enum_type.name
		}
		// struct initialization
		else if xP.peek() == .LCBR {
			if ptr {
			        name += '*'  // `&User{}` => type `User*`
			}
			if name == 'T' {
				name = xP.cur_gen_type
			}
			return xP.struct_init(name, is_c_struct_init)
		}
	}
	if is_c {
		// C const (`C.GLFW_KEY_LEFT`)
		if xP.peek() != .LPAR {
			xP.gen(name)
			xP.next()
			return 'int'
		}
		// C fn
		f := Fn {
			name: name// .replace('c_', '')
			is_c: true
		}
		xP.is_c_fn_call = true
		xP.fn_call(f, 0, '', '')
		xP.is_c_fn_call = false
		// Try looking it up. Maybe its defined with "C.fn_name() fn_type",
		// then we know what type it returns
		cfn := xP.table.find_fn(name)
		// Not Found? Return 'void*'
		if cfn.name == '' {
			//return 'cvoid' //'void*'
			return 'void*'
		}
		return cfn.typ
	}
	// Constant
	c := xP.table.find_const(name)
	if c.name != '' && ptr && !c.is_global {
		xP.error('cannot take the address of constant `$c.name`')
	}
	if c.name.len != 0 {
		if ptr {
			// c.ptr = true
			xP.gen('& /*const*/ ')
		}
		xP.log('calling var expr')
		mut typ := xP.var_expr(c)
		if ptr {
			typ += '*'
		}
		return typ
	}
	// Function (not method btw, methods are handled in dot())
	mut f := xP.table.find_fn(name)
	if f.name == '' {
		// We are in a second CheckPoint, that means this function was not defined, throw an error.
		if !xP.first_cp() {
			// UTxQuantico script? Try os module.
			if xP.xQ_script {
				name = name.replace('main__', 'os__')
				f = xP.table.find_fn(name)
			}
			if f.name == '' {
				// If orig_name is a mod, then printing undefined: `mod` tells us nothing
				// if xP.table.known_mod(orig_name) {
				if xP.table.known_mod(orig_name) || xP.import_table.known_alias(orig_name) {
					name = name.replace('__', '.').replace('_dot_', '.')
					xP.error('undefined: `$name`')
				}
				else {
					if orig_name == 'i32' {
						println('`i32` alias was removed, use `int` instead')
					}
					if orig_name == 'u8' {
						println('`u8` alias was removed, use `byte` instead')
					}
					xP.error('undefined: `$orig_name`')
				}
			}
		} else {
			xP.next()
			// First CheckPoint, the function can be defined later.
			return 'void'
		}
	}
	// no () after function, so function is an argument, just gen its name
	// TODO verify this and handle errors
	peek := xP.peek()
	if peek != .LPAR && peek != .LESSER {
		xP.gen(xP.table.cgen_name(f))
		xP.next()
		return 'void*'
	}
	// TODO bring back
	if f.typ == 'void' && !xP.inside_if_expr {
		// xP.error('`$f.name` used as value')
	}
	xP.log('calling function')
	xP.fn_call(f, 0, '', '')
	// dot after a function call: `get_user().age`
	if xP.tk == .DOT {
		mut typ := ''
		for xP.tk == .DOT {
			// println('dot #$dc')
			typ = xP.dot(f.typ, sh)
		}
		return typ
	}
	xP.log('end of name_expr')
	return f.typ
}

fn (xP mut Parser) var_expr(var Var) string {
	xP.log('\nvar_expr() var.name="$var.name" var.typ="$var.typ"')
	// println('var expr is_tmp=$xP.cgen.is_tmp\n')
	xP.cur_fn.mark_var_used(var)
	fn_sh := xP.cgen.add_shadow()
	xP.expr_var = var
	xP.gen(xP.table.var_cgen_name(var.name))
	xP.next()
	mut typ := var.typ
	// Function pointer?

	//println('CALLING FN PTR')
	//xP.print_tk()
	if typ.starts_with('fn ') && xP.tk == .LPAR {
		T := xP.table.find_type(typ)
		xP.gen('(')
		xP.fn_call_args(mut T.function)
		xP.gen(')')
		typ = T.function.typ
	}
	// users[0].name
	if xP.tk == .LSBR {
		typ = xP.index_expr(typ, fn_sh)
	}
	// a.b.c().d chain
	// mut dc := 0
	for xP.tk ==.DOT {
		if xP.peek() == .key_select {
			xP.next()
			return xP.select_query(fn_sh)
		}
		if typ == 'pg__DB' && !xP.fileis('pg.xq') && xP.peek() == .NAME {
			xP.next()
			xP.insert_query(fn_sh)
			return 'void'
		}
		// println('dot #$dc')
		typ = xP.dot(typ, fn_sh)
		xP.log('typ after dot=$typ')
		// print('tk after dot()')
		// xP.print_tk()
		// dc++
		if xP.tk == .LSBR {
			// typ = xP.index_expr(typ, fn_sh, var)
		}
	}
	// a++ and a--
	if xP.tk == .INC || xP.tk == .DEC {
		if !var.is_mutable && !var.is_arg && !xP.pref.translated {
			xP.error('`$var.name` is immutable')
		}
		if !var.is_changed {
			xP.cur_fn.mark_var_changed(var)
		}
		if typ != 'int' {
			if !xP.pref.translated && !is_number_type(typ) {
				xP.error('cannot ++/-- value of type `$typ`')
			}
		}
		xP.gen(xP.tk.str())
		xP.fgen(xP.tk.str())
		xP.next()// ++/--
		// allow `a := c++` in translated code
		if xP.pref.translated {
			//return xP.index_expr(typ, fn_sh)
		}
		else {
			return 'void'
		}
	}
	typ = xP.index_expr(typ, fn_sh)
	// TODO hack to allow `foo.bar[0] = 2`
	if xP.tk == .DOT {
		for xP.tk == .DOT {
			typ = xP.dot(typ, fn_sh)
		}
		typ = xP.index_expr(typ, fn_sh)
	}
	return typ
}

// for debugging only
fn (xP &Parser) fileis(s string) bool {
	return xP.scanner.file_path.contains(s)
}

// user.name => `str_typ` is `User`
// user.company.name => `str_typ` is `Company`
fn (xP mut Parser) dot(str_typ string, method_sh int) string {
	//if xP.fileis('orm_test') {
		//println('ORM dot $str_typ')
	//}
	xP.check(.DOT)
	typ := xP.find_type(str_typ)
	if typ.name.len == 0 {
		xP.error('dot(): cannot find type `$str_typ`')
	}
	if xP.tk == .DOLLAR {
		xP.comptime_method_call(typ)
		return 'void'
	}
	field_name := xP.lit
	xP.fgen(field_name)
	xP.log('dot() field_name=$field_name typ=$str_typ')
	//if xP.fileis('main.xq') {
		//println('dot() field_name=$field_name typ=$str_typ prev_tk=${prev_tk.str()}')
	//}
	has_field := xP.table.type_has_field(typ, xP.table.var_cgen_name(field_name))
	mut has_method := xP.table.type_has_method(typ, field_name)
	// generate `.str()`
	if !has_method && field_name == 'str' && typ.name.starts_with('array_') {
		xP.gen_array_str(typ)
		has_method = true
	}
	if !typ.is_c && !xP.is_c_fn_call && !has_field && !has_method && !xP.first_cp() {
		if typ.name.starts_with('Option_') {
			opt_type := typ.name.right(7)
			xP.error('unhandled option type: $opt_type?')
		}
		//println('error in dot():')
		//println('fields:')
		//for field in typ.fields {
			//println(field.name)
		//}
		//println('methods:')
		//for field in typ.methods {
			//println(field.name)
		//}
		//println('str_typ=="$str_typ"')
		xP.error('type `$typ.name` has no field or method `$field_name`')
	}
	mut dot := '.'
	if str_typ.ends_with('*') || str_typ == 'FT_Face' { // TODO fix C ptr typedefs
		dot = '->'
	}
	// field
	if has_field {
		struct_field := if typ.name != 'Option' { xP.table.var_cgen_name(field_name) } else { field_name }
		field := xP.table.find_field(typ, struct_field)
		if !field.is_mutable && !xP.has_immutable_field {
			xP.has_immutable_field = true
			xP.first_immutable_field = field
		}
		// Is the next token `=`, `+=` etc?  (Are we modifying the field?)
		next := xP.peek()
		modifying := next.is_assign() || next == .INC || next == .DEC || (field.typ.starts_with('array_') && next == .LEFT_SHIFT)
		is_vi := xP.fileis('vid')
		if !xP.builtin_mod && !xP.pref.translated && modifying && !is_vi && xP.has_immutable_field {
			f := xP.first_immutable_field
			xP.error('cannot modify immutable field `$f.name` (type `$f.parent_fn`)\n' +
					'declare the field with `mut:`
					struct $f.parent_fn {
  					mut:
							$f.name $f.typ
					}')
		}
		if !xP.builtin_mod && xP.mod != typ.mod {
		}
		// Don't allow `arr.data`
		if field.access_mod == .private && !xP.builtin_mod && !xP.pref.translated && xP.mod != typ.mod {
			// println('$typ.name :: $field.name ')
			// println(field.access_mod)
			xP.error('cannot refer to unexported field `$struct_field` (type `$typ.name`)')
		}
		xP.gen(dot + struct_field)
		xP.next()
		return field.typ
	}
	// method
	method := xP.table.find_method(typ, field_name)
	xP.fn_call(method, method_sh, '', str_typ)
	// Methods returning `array` should return `array_string`
	if method.typ == 'array' && typ.name.starts_with('array_') {
		return typ.name
	}
	// Array methods returning `voidptr` (like `last()`) should return element type
	if method.typ == 'void*' && typ.name.starts_with('array_') {
		return typ.name.right(6)
	}
	//if false && xP.tk == .LSBR {
		// if is_indexer {
		//return xP.index_expr(method.typ, method_sh)
	//}
	return method.typ
}

fn (xP mut Parser) index_expr(typ_ string, fn_sh int) string {
	mut typ := typ_
	// a[0]
	var := xP.expr_var
	//if xP.fileis('fn_test.xq') {
		//println('index expr typ=$typ')
		//println(var.name)
	//}
	is_map := typ.starts_with('map_')
	is_str := typ == 'string'
	is_arr0 := typ.starts_with('array_')
	is_arr := is_arr0 || typ == 'array'
	is_ptr := typ == 'byte*' || typ == 'byteptr' || typ.contains('*')
	is_indexer := xP.tk == .LSBR
	mut close_bracket := false
	if is_indexer {
		is_fixed_arr := typ[0] == `[`
		if !is_str && !is_arr && !is_map && !is_ptr && !is_fixed_arr {
			xP.error('Cant [] non-array/string/map. Got type "$typ"')
		}
		xP.check(.LSBR)
		// Get element type (set `typ` to it)
		if is_str {
			typ = 'byte'
			xP.fgen('[')
			// Direct faster access to .str[i] in builtin modules
			if xP.builtin_mod {
				xP.gen('.str[')
				close_bracket = true
			}
			else {
				// Bounds check everywhere else
				xP.gen(',')
			}
		}
		if is_fixed_arr {
			// `[10]int` => `int`, `[10][3]int` => `[3]int`
			if typ.contains('][') {
				pos := typ.index_after('[', 1)
				typ = typ.right(pos)
			}
			else {
				typ = typ.all_after(']')
			}
			xP.gen('[')
			close_bracket = true
		}
		else if is_ptr {
			// typ = 'byte'
			typ = typ.replace('*', '')
			// modify(mut []string) fix
			if !is_arr {
				xP.gen('[/*ptr*/')
				close_bracket = true
			}
		}
		if is_arr {
			//xP.fgen('[')
			// array_int a; a[0]
			// type is "array_int", need "int"
			// typ = typ.replace('array_', '')
			if is_arr0 {
				if xP.fileis('int_test') {
					println('\nRRRR0 $typ')
				}
				typ = typ.right(6)
				if xP.fileis('int_test') {
					println('RRRR $typ')
				}
			}
			// array a; a.first() voidptr
			// type is "array", need "void*"
			if typ == 'array' {
				typ = 'void*'
			}
			// No bounds check in translated from C code
			if xP.pref.translated && !xP.builtin_mod{
				// Cast void* to typ*: add (typ*) to the beginning of the assignment :
				// ((int*)a.data = ...
				xP.cgen.set_shadow(fn_sh, '(($typ*)(')
				xP.gen('.data))[')
			}
			else {
				xP.gen(',')
			}
		}
		// map is tricky
		// need to replace "m[key] = val" with "tmp = val; map_set(&m, key, &tmp)"
		// need to replace "m[key]"       with "tmp = val; map_get(&m, key, &tmp)"
		// can only do that later once we know whether there's an "=" or not
		if is_map {
			typ = typ.replace('map_', '')
			if typ == 'map' {
				typ = 'void*'
			}
			xP.gen(',')
		}
		// expression inside [ ]
		if is_arr {
			index_pos := xP.cgen.cur_line.len
			T := xP.table.find_type(xP.expression())
			// Allows only i8-64 and byte-64 to be used when accessing an array
			if T.parent != 'int' && T.parent != 'u32' {
				xP.check_types(T.name, 'int')
			}
			if xP.cgen.cur_line.right(index_pos).replace(' ', '').int() < 0 {
				xP.error('cannot access negative array index')
			}
		}
		else {
			T := xP.table.find_type(xP.expression())
			// TODO: Get the key type of the map instead of only string.
			if is_map && T.parent != 'string' {
				xP.check_types(T.name, 'string')
			}
		}
		xP.check(.RSBR)
		// if (is_str && xP.builtin_mod) || is_ptr || is_fixed_arr && ! (is_ptr && is_arr) {
		if close_bracket {
			xP.gen(']/*r$typ $var.is_mutable*/')
		}
		xP.expr_var = var
	}
	// TODO move this from index_expr()
	// TODO if xP.tk in ...
	// if xP.tk in [.ASSIGN, .PLUS_ASSIGN, .MINUS_ASSIGN]
	if (xP.tk == .ASSIGN && !xP.is_SqlX) || xP.tk == .PLUS_ASSIGN || xP.tk == .MINUS_ASSIGN || xP.tk == .SLASH_ASSIGN ||
	xP.tk == .STAR_ASSIGN || xP.tk == .XOR_ASSIGN || xP.tk == .PER_ASSIGN || xP.tk == .OR_ASSIGN ||
	xP.tk == .AND_ASSIGN || xP.tk == .AT_ASSIGN || xP.tk == .RIGHT_SHIFT_ASSIGN ||	xP.tk == .LEFT_SHIFT_ASSIGN {
		if is_indexer && is_str && !xP.builtin_mod {
			xP.error('strings are immutable')
		}
		assign_pos := xP.cgen.cur_line.len
		is_cao := xP.tk != .ASSIGN
		xP.assigned_type = typ
		xP.expected_type = typ
		xP.assign_statement(var, fn_sh, is_indexer && (is_map || is_arr))
		// m[key] = val
		if is_indexer && (is_map || is_arr) {
			// `a[0] = 7`
			// curline right now: `a , 0  =  7`
			mut val := xP.cgen.cur_line.right(assign_pos)
			xP.cgen.resetln(xP.cgen.cur_line.left(assign_pos))
			mut cao_tmp := xP.cgen.cur_line
			mut function := ''
			if is_map {
				function = 'map__set(&'
				// CAO on map is a bit more complicated as it loads
				// the value inside a pointer instead of returning it.
			}
			else {
				if is_ptr {
					function = 'array_set('
					if is_cao {
						cao_tmp = '*($xP.expected_type *) array__get(*$cao_tmp)'
					}
				}
				else {
					function = 'array_set(&/*q*/'
					if is_cao {
						cao_tmp = '*($xP.expected_type *) array__get($cao_tmp)'
					}
				}
			}
			xP.cgen.set_shadow(fn_sh, function)
			if is_cao {
				val = cao_tmp + val.all_before('=') +	val.all_after('=')
			}
			xP.gen(', & ($typ []) { $val })')
		}
		return typ
	}
	// else if xP.pref.is_verbose && xP.assigned_var != '' {
	// xP.error('didnt assign')
	// }
	// m[key]. no =, just a getter
	else if (is_map || is_arr || (is_str && !xP.builtin_mod)) && is_indexer {
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
		if is_map {
			xP.gen('$tmp')
			def := type_default(typ)
			xP.cgen.insert_before('$typ $tmp = $def; bool $tmp_ok = map_get($index_expr, & $tmp);')
		}
		else if is_arr {
			if xP.pref.translated && !xP.builtin_mod {
				xP.gen('$index_expr ]')
			}
			else {
				if is_ptr {
					xP.gen('( *($typ*) array__get(* $index_expr) )')
				}  else {
					xP.gen('( *($typ*) array__get($index_expr) )')
				}
			}
		}
		else if is_str && !xP.builtin_mod {
			xP.gen('string_at($index_expr)')
		}
		// Zero the string after map_get() if it's nil, numbers are automatically 0
		// This is ugly, but what can I do without generics?
		// TODO what about user types?
		if is_map && typ == 'string' {
			// xP.cgen.insert_before('if (!${tmp}.str) $tmp = tos("", 0);')
			xP.cgen.insert_before('if (!$tmp_ok) $tmp = tos((byte *)"", 0);')
		}
	}
	// else if is_arr && is_indexer{}
	return typ
}

// returns resulting type
fn (xP mut Parser) expression() string {
	if xP.scanner.file_path.contains('test_test') {
		println('expression() cp=$xP.cp tk=')
		xP.print_tk()
	}
	xP.cgen('/* expr start*/')
	sh := xP.cgen.add_shadow()
	mut typ := xP.term()
	is_str := typ=='string'
	// a << b ==> array2_push(&a, b)
	if xP.tk == .LEFT_SHIFT {
		if typ.contains('array_') {
			// Can't pass integer literal, because push requires a void*
			// a << 7 => int tmp = 7; array_push(&a, &tmp);
			// _PUSH(&a, expression(), tmp, string)
			tmp := xP.get_tmp()
			tmp_typ := typ.right(6)// skip "array_"
			xP.check_space(.LEFT_SHIFT)
			// Get the value we are pushing
			xP.gen(', (')
			// Immutable? Can we push?
			if !xP.expr_var.is_mutable && !xP.pref.translated {
				xP.error('`$xP.expr_var.name` is immutable (can\'t <<)')
			}
			if !xP.expr_var.is_changed {
				xP.cur_fn.mark_var_changed(xP.expr_var)
			}
			expr_type := xP.expression()
			// Two arrays of the same type?
			push_array :=  typ == expr_type
			if push_array {
				xP.cgen.set_shadow(sh, '_PUSH_MANY(&' )
				xP.gen('), $tmp, $typ)')
			}  else {
				xP.check_types(expr_type, tmp_typ)
				// Pass tmp var info to the _PUSH macro
				// Prepend tmp initialisation and push call
				// Don't dereference if it's already a mutable array argument  (`fn foo(mut []int)`)
				push_call := if typ.contains('*'){'_PUSH('} else { '_PUSH(&'}
				xP.cgen.set_shadow(sh, push_call)
				xP.gen('), $tmp, $tmp_typ)')
			}
			return 'void'
		}
		else {
			xP.next()
			xP.gen(' << ')
			xP.check_types(xP.expression(), typ)
			return 'int'
		}
	}
	// `a in [1, 2, 3]`
	// `key in map`
	if xP.tk == .key_in {
		xP.fgen(' ')
		xP.check(.key_in)
		xP.fgen(' ')
		xP.gen(', ')
		arr_typ := xP.expression()
		is_map := arr_typ.starts_with('map_')
		if !arr_typ.starts_with('array_') && !is_map {
			xP.error('`in` requires an array/map')
		}
		T := xP.table.find_type(arr_typ)
		if !is_map && !T.has_method('contains') {
			xP.error('$arr_typ has no method `contains`')
		}
		// `typ` is element's type
		if is_map {
			xP.cgen.set_shadow(sh, '_IN_MAP( ')
		}
		else {
			xP.cgen.set_shadow(sh, '_IN($typ, ')
		}
		xP.gen(')')
		return 'bool'
	}
	if xP.tk == .RIGHT_SHIFT {
		xP.next()
		xP.gen(' >> ')
		xP.check_types(xP.expression(), typ)
		return 'int'
	}
	if xP.tk == .DOT  {
		for xP.tk == .DOT {
			typ = xP.dot(typ, sh)
		}
	}
	// + - |
	for xP.tk == .PLUS || xP.tk == .MINUS || xP.tk == .PIPE || xP.tk == .AMPER || xP.tk == .XOR {
		// for xP.tk in [.PLUS, .MINUS, .PIPE, .AMPER, .XOR] {
		tk_op := xP.tk
		is_num := typ == 'void*' || typ == 'byte*' || is_number_type(typ)
		xP.check_space(xP.tk)
		if is_str && tk_op == .PLUS {
			xP.cgen.set_shadow(sh, 'string_add(')
			xP.gen(',')
		}
		// 3 + 4
		else if is_num {
			if typ == 'void*' {
				// Msvc errors on void* pointer arithmetic
				// ... So cast to byte* and then do the add
				xP.cgen.set_shadow(sh, '(byte*)')
			}
			xP.gen(tk_op.str())
		}
		// Vec + Vec
		else {
			if xP.pref.translated {
				xP.gen(tk_op.str() + ' /*hack*/')// TODO hack to fix DOOM's angle_t
			}
			else {
				xP.gen(',')
			}
		}
		xP.check_types(xP.term(), typ)
		if is_str && tk_op == .PLUS {
			xP.gen(')')
		}
		// Make sure operators are used with correct types
		if !xP.pref.translated && !is_str && !is_num {
			T := xP.table.find_type(typ)
			if tk_op == .PLUS {
				if T.has_method('+') {
					xP.cgen.set_shadow(sh, typ + '_plus(')
					xP.gen(')')
				}
				else {
					xP.error('operator + not defined on `$typ`')
				}
			}
			else if tk_op == .MINUS {
				if T.has_method('-') {
					xP.cgen.set_shadow(sh, '${typ}_minus(')
					xP.gen(')')
				}
				else {
					xP.error('operator - not defined on `$typ`')
				}
			}
		}
	}
	return typ
}

fn (xP mut Parser) term() string {
	line_no_y := xP.scanner.line_no_y
	//if xP.fileis('fn_test') {
		//println('\nterm() $line_no_y')
	//}
	typ := xP.unary()
	//if xP.fileis('fn_test') {
		//println('2: $line_no_y')
	//}
	// `*` on a newline? Can't be multiplication, only dereference
	if xP.tk == .STAR && line_no_y != xP.scanner.line_no_y {
		return typ
	}
	for xP.tk == .STAR || xP.tk == .SLASH || xP.tk == .PERCENTAGE {
		tk := xP.tk
		is_slash := tk == .SLASH
		is_percentage := tk == .PERCENTAGE
		is_star := tk == .STAR
		xP.next()
		xP.gen(tk.str())// + ' /*op2*/ ')
		xP.fgen(' ' + tk.str() + ' ')
		if (is_slash || is_percentage) && xP.tk == .NUMBER && xP.lit == '0' {
			xP.error('division by zero is not defined instead use limits from math module of xQLib')
		}
		if is_percentage && (is_float_type(typ) || !is_number_type(typ)) {
			xP.error('operator .PERCENTAGE requires integer types')
		}
		xP.check_types(xP.unary(), typ)
	}
	return typ
}

fn (xP mut Parser) unary() string {
	mut typ := ''
	tk := xP.tk
	switch tk {
	case Token.NOT:
		xP.gen('!')
		xP.check(.NOT)
		typ = 'bool'
		xP.bool_expression()
	case Token.BIT_NOT:
		xP.gen('~')
		xP.check(.BIT_NOT)
		typ = xP.bool_expression()
	default:
		typ = xP.factor()
	}
	return typ
}

fn (xP mut Parser) factor() string {
	mut typ := ''
	tk := xP.tk
	switch tk {
	case .NUMBER:
		typ = 'int'
		// Check if float (`1.0`, `1e+3`) but not if is hexa
		if (xP.lit.contains('.') || (xP.lit.contains('e') || xP.lit.contains('E'))) &&
			!(xP.lit[0] == `0` && (xP.lit[1] == `x` || xP.lit[1] == `X`)) {
			typ = 'f32'
			// typ = 'f64' // TODO
		} else {
			val_u64 := xP.lit.u64()
			if u64(u32(val_u64)) < val_u64 {
				typ = 'u64'
			}
		}
		if xP.expected_type != '' && !is_valid_int_const(xP.lit, xP.expected_type) {
			xP.error('constant `$xP.lit` overflows `$xP.expected_type`')
		}
		xP.gen(xP.lit)
		xP.fgen(xP.lit)
	case Token.MINUS:
		xP.gen('-')
		xP.fgen('-')
		xP.next()
		return xP.factor()
		// Variable
	case Token.key_sizeof:
		xP.gen('sizeof(')
		xP.fgen('sizeof(')
		xP.next()
		xP.check(.LPAR)
		mut sizeof_typ := xP.get_type()
		if sizeof_typ.ends_with('*') {
			// Move * from the end to the beginning, as C requires
			sizeof_typ = '*' + sizeof_typ.left(sizeof_typ.len - 1)
		}
		xP.check(.RPAR)
		xP.gen('$sizeof_typ)')
		xP.fgen('$sizeof_typ)')
		return 'int'
	case Token.AMPER, Token.DOT, Token.STAR:
		// (dot is for enum vals: `.green`)
		return xP.name_expr()
	case Token.NAME:
		// map[string]int
		if xP.lit == 'map' && xP.peek() == .LSBR {
			return xP.map_init()
		}
		if xP.lit == 'json' && xP.peek() == .DOT {
			if !('json' in xP.table.imports) {
				xP.error('undefined: `json`, use `import json`')
			}
			return xP.json_decode()
		}
		//if xP.fileis('orm_test') {
			//println('ORM name: $xP.lit')
		//}
		typ = xP.name_expr()
		return typ
	case Token.key_default:
		xP.next()
		xP.next()
		name := xP.check_name()
		if name != 'T' {
			xP.error('default needs T')
		}
		xP.gen('default(T)')
		xP.next()
		return 'T'
	case Token.LPAR:
		//xP.gen('(/*LPAR*/')
		xP.gen('(')
		xP.check(.LPAR)
		typ = xP.bool_expression()
		// Hack. If this `)` referes to a ptr cast `(*int__)__`, it was already checked
		// TODO: fix parser so that it doesn't think it's a par expression when it sees `(` in
		// __(__*int)(
		if !xP.ptr_cast {
			xP.check(.RPAR)
		}
		xP.ptr_cast = false
		xP.gen(')')
		return typ
	case Token.CHAR:
		xP.char_expr()
		typ = 'byte'
		return typ
	case Token.STRING:
		xP.string_expr()
		typ = 'string'
		return typ
	case Token.key_false:
		typ = 'bool'
		xP.gen('0')
		xP.fgen('false')
	case Token.key_true:
		typ = 'bool'
		xP.gen('1')
		xP.fgen('true')
	case Token.LSBR:
		// `[1,2,3]` or `[]` or `[20]byte`
		// TODO have to return because arrayInit does next()
		// everything should do next()
		return xP.array_init()
	case Token.LCBR:
		// `m := { 'one': 1 }`
		if xP.peek() == .STRING {
			return xP.map_init()
		}
		// { user | name :'new name' }
		return xP.assoc()
	case Token.key_if:
		typ = xP.if_statement(true, 0)
		return typ
	case Token.key_match:
		typ = xP.match_statement(true)
		return typ
	default:
		if xP.pref.is_verbose || xP.pref.is_debug {
			next := xP.peek()
			println('prev=${xP.prev_tk.str()}')
			println('next=${next.str()}')
		}
		xP.error('unexpected token: `${xP.tk.str()}`')
	}
	xP.next()// TODO everything should next()
	return typ
}

// { user | name: 'new name' }
fn (xP mut Parser) assoc() string {
	// println('assoc()')
	xP.next()
	name := xP.check_name()
	if !xP.cur_fn.known_var(name) {
		xP.error('unknown variable `$name`')
	}
	var := xP.cur_fn.find_var(name)
	xP.check(.PIPE)
	xP.gen('($var.typ){')
	mut fields := []string// track the fields user is setting, the rest will be copied from the old object
	for xP.tk != .RCBR {
		field := xP.check_name()
		fields << field
		xP.gen('.$field = ')
		xP.check(.COLON)
		xP.bool_expression()
		xP.gen(',')
		if xP.tk != .RCBR {
			xP.check(.COMMA)
		}
	}
	// Copy the rest of the fields
	T := xP.table.find_type(var.typ)
	for ffield in T.fields {
		f := ffield.name
		if f in fields {
			continue
		}
		xP.gen('.$f = $name . $f,')
	}
	xP.check(.RCBR)
	xP.gen('}')
	return var.typ
}

fn (xP mut Parser) char_expr() {
	xP.gen('\'$xP.lit\'')
	xP.next()
}


fn format_str(_str string) string {
	mut str := _str.replace('"', '\\"')
	$if windows {
		str = str.replace('\r\n', '\\n')
	}
	str = str.replace('\n', '\\n')
	return str
}

fn (xP mut Parser) string_expr() {
	str := xP.lit
	// No ${}, just return a simple string
	if xP.peek() != .DOLLAR {
		xP.fgen('\'$str\'')
		f := format_str(str)
		// `C.puts('hi')` => `puts("hi");`
		if xP.calling_c || (xP.pref.translated && xP.mod == 'main') {
			xP.gen('"$f"')
		}
		else if xP.is_SqlX {
			xP.gen('\'$str\'')
		}
		else {
			xP.gen('tos2((byte*)"$f")')
		}
		xP.next()
		return
	}
	// tmp := xP.get_tmp()
	xP.is_alloc = true // $ interpolation means there's allocation
	mut args := '"'
	mut format := '"'
	xP.fgen('\'')
	mut complex_inter := false  // for xQFmt
	for xP.tk == .STRING {
		// Add the string between %d's
		xP.fgen(xP.lit)
		xP.lit = xP.lit.replace('%', '%%')
		format += format_str(xP.lit)
		xP.next()// skip $
		if xP.tk != .DOLLAR {
			continue
		}
		// Handle .DOLLAR
		xP.check(.DOLLAR)
		// If there's no string after current token, it means we are in
		// a complex expression (`${...}`)
		if xP.peek() != .STRING {
			xP.fgen('{')
			complex_inter = true
		}
		// Get bool expr inside a temp var
		xP.cgen.start_tmp()
		typ := xP.bool_expression()
		mut val := xP.cgen.end_tmp()
		val = val.trim_space()
		args += ', $val'
		if typ == 'string' {
			// args += '.str'
			// printf("%.*s", a.len, a.str) syntax
			args += '.len, ${val}.str'
		}
		if typ == 'ustring' {
			args += '.len, ${val}.s.str'
		}
		if typ == 'bool' {
			//args += '.len, ${val}.str'
		}
		// Custom format? ${t.hour:02d}
		custom := xP.tk == .COLON
		if custom {
			format += '%'
			xP.next()
			if xP.tk == .DOT {
				format += '.'
				xP.next()
			}
			format += xP.lit// 02
			xP.next()
			format += xP.lit// f
			// println('custom str F=$format')
			xP.next()
		}
		else {
			f := xP.typ_to_format(typ, 0)
			if f == '' {
				is_array := typ.starts_with('array_')
				typ2 := xP.table.find_type(typ)
				has_str_method := xP.table.type_has_method(typ2, 'str')
				if is_array || has_str_method {
					if is_array && !has_str_method {
						xP.gen_array_str(typ2)
					}
					args = args.all_before_last(val) + '${typ}_str(${val}).len, ${typ}_str(${val}).str'
					format += '%.*s '
				}
				else {
					xP.error('unhandled sprintf format "$typ" ')
				}
			}
			format += f
		}
	}
	if complex_inter {
		xP.fgen('}')
	}
	xP.fgen('\'')
	// println("hello %d", num) optimization.
	if xP.cgen.nogen {
		return
	}
	// println: don't allocate a new string, just print	it.
	$if !windows {
		cur_line := xP.cgen.cur_line.trim_space()
		if cur_line == 'println (' && xP.tk != .PLUS {
			xP.cgen.resetln(cur_line.replace('println (', 'printf('))
			xP.gen('$format\\n$args')
			return
		}
	}
	// '$age'! means the user wants this to be a tmp string (uses global buffer, no allocation,
	// won't be used	again)
	if xP.tk == .NOT {
		xP.check(.NOT)
		xP.gen('_STR_TMP($format$args)')
	}
	else {
		// Otherwise do ugly len counting + allocation + sprintf
		xP.gen('_STR($format$args)')
	}
}

// m := map[string]int{}
// m := { 'one': 1 }
fn (xP mut Parser) map_init() string {
	// m := { 'one': 1, 'two': 2 }
	mut keys_gen := '' // (string[]){tos2("one"), tos2("two")}
	mut vals_gen := '' // (int[]){1, 2}
	mut val_type := ''  // 'int'
	if xP.tk == .LCBR {
		xP.check(.LCBR)
		mut i := 0
		for {
			key := xP.lit
			keys_gen += 'tos2((byte*)"$key"), '
			xP.check(.STRING)
			xP.check(.COLON)
			xP.cgen.start_tmp()
			t := xP.bool_expression()
			if i == 0 {
				val_type = t
			}
			i++
			if val_type != t {
				if !xP.check_types_no_throw(val_type, t) {
					xP.error('bad map element type `$val_type` instead of `$t`')
				}
			}
			val_expr := xP.cgen.end_tmp()
			vals_gen += '$val_expr, '
			if xP.tk == .RCBR {
				xP.check(.RCBR)
				break
			}
			if xP.tk == .COMMA {
				xP.check(.COMMA)
			}
		}
		xP.gen('new_map_init($i, sizeof($val_type), ' +	'(string[]){ $keys_gen }, ($val_type []){ $vals_gen } )')
		typ := 'map_$val_type'
		xP.register_map(typ)
		return typ
	}
	xP.next()
	xP.check(.LSBR)
	key_type := xP.check_name()
	if key_type != 'string' {
		xP.error('only string key maps allowed for now')
	}
	xP.check(.RSBR)
	val_type = xP.get_type()/// xP.check_name()
	//if !xP.table.known_type(val_type) {
		//xP.error('map init unknown type "$val_type"')
	//}
	typ := 'map_$val_type'
	xP.register_map(typ)
	xP.gen('new_map(1, sizeof($val_type))')
	if xP.tk == .LCBR {
		xP.check(.LCBR)
		xP.check(.RCBR)
		println('warning: $xP.file_name:$xP.scanner.line_no_y ' + 'initializaing maps no longer requires `{}`')
	}
	return typ
}

// `nums := [1, 2, 3]`
fn (xP mut Parser) array_init() string {
	xP.is_alloc = true
	xP.check(.LSBR)
	mut is_integer := xP.tk == .NUMBER  // for `[10]int`
	// fixed length arrays with a const len: `nums := [N]int`, same as `[10]int` basically
	mut is_const_len := false
	if xP.tk == .NAME {
		c := xP.table.find_const(xP.prepend_mod(xP.lit))
		if c.name != '' && c.typ == 'int' && xP.peek() == .RSBR && !xP.inside_const {
			is_integer = true
			is_const_len = true
		}
	}
	lit := xP.lit
	mut typ := ''
	new_arr_sh := xP.cgen.add_shadow()
	mut i := 0
	pos := xP.cgen.cur_line.len// remember cur line to fetch first number in cgen  for [0; 10]
	for xP.tk != .RSBR {
		val_typ := xP.bool_expression()
		// Get type of the first expression
		if i == 0 {
			typ = val_typ
			// fixed width array initialization? (`arr := [20]byte`)
			if is_integer && xP.tk == .RSBR && xP.peek() == .NAME {
				nextch := xP.scanner.text[xP.scanner.pos_x + 1]
				// TODO whitespace hack
				// Make sure there's no space in `[10]byte`
				if !nextch.is_space() {
					xP.check(.RSBR)
					array_elem_typ := xP.get_type()
					if xP.table.known_type(array_elem_typ) {
						xP.cgen.resetln('')
						xP.gen('{0}')
						if is_const_len {
							return '[${xP.mod}__$lit]$array_elem_typ'
						}
						return '[$lit]$array_elem_typ'
					}
					else {
						xP.error('bad type `$array_elem_typ`')
					}
				}
			}
		}
		if val_typ != typ {
			if !xP.check_types_no_throw(val_typ, typ) {
				xP.error('bad array element type `$val_typ` instead of `$typ`')
			}
		}
		if xP.tk != .RSBR && xP.tk != .SEMICOLON {
			xP.gen(', ')
			xP.check(.COMMA)
			xP.fspace()
		}
		i++
		// Repeat (a = [0;5] )
		if i == 1 && xP.tk == .SEMICOLON {
			xP.check_space(.SEMICOLON)
			val := xP.cgen.cur_line.right(pos)
			xP.cgen.resetln(xP.cgen.cur_line.left(pos))
			xP.gen('array_repeat(& ($typ[]){ $val }, ')
			xP.check_types(xP.bool_expression(), 'int')
			xP.gen(', sizeof($typ) )')
			xP.check(.RSBR)
			return 'array_$typ'
		}
	}
	xP.check(.RSBR)
	// type after `]`? (e.g. "[]string")
	if xP.tk != .NAME && i == 0 {
		xP.error('specify array type: `[]typ` instead of `[]`')
	}
	if xP.tk == .NAME && i == 0 {
		// vals.len == 0 {
		typ = xP.get_type()
		// println('.key_goT TYP after [] $typ')
	}
	// ! after array => no malloc and no copy
	no_alloc := xP.tk == .NOT
	if no_alloc {
		xP.next()
	}

	// [1,2,3]!! => [3]int{1,2,3}
	is_fixed_size := xP.tk == .NOT
	if is_fixed_size {
		xP.next()
		xP.gen(' }')
		if !xP.first_cp() {
			// If we are defining a const array, we don't need to specify the type:
			// `a = {1,2,3}`, not `a = (int[]) {1,2,3}`
			if xP.inside_const {
				xP.cgen.set_shadow(new_arr_sh, '{')
			}
			else {
				xP.cgen.set_shadow(new_arr_sh, '($typ[]) {')
			}
		}
		return '[$i]$typ'
	}
	// if ptr {
	// typ += '_ptr"
	// }
	mut new_arr := 'new_array_from_c_array'
	if no_alloc {
		new_arr += '_no_alloc'
	}

	if i == 0 && xP.pref.ccompiler != 'tcc' {
		xP.gen(' 0 })')
	} else {
		xP.gen(' })')
	}

	// xP.gen('$new_arr($vals.len, $vals.len, sizeof($typ), ($typ[$vals.len]) $c_arr );')
	// Need to do this in the second CheckPoint, otherwise it goes to the very top of the out.c file
	if !xP.first_cp() {
		//if i == 0 {
			//xP.cgen.set_shadow(new_arr_sh, '$new_arr($i, $i, sizeof($typ), ($typ[]) { 0 ')
		//} else {
		// Due to a tcc bug, the length needs to be specified.
		// GCC crashes if it is.
		cast := if xP.pref.ccompiler == 'tcc' { '($typ[$i])' } else { '($typ[])' }
		xP.cgen.set_shadow(new_arr_sh, '$new_arr($i, $i, sizeof($typ), $cast { ')
		//}
	}
	typ = 'array_$typ'
	xP.register_array(typ)
	return typ
}

fn (xP mut Parser) struct_init(typ string, is_c_struct_init bool) string {
	xP.is_struct_init = true
	t := xP.table.find_type(typ)
	// TODO hack. If it's a C type, we may need to add "struct" before declaration:
	// a := &C.A{}  ==>  struct A* a = malloc(sizeof(struct A));
	if is_c_struct_init {
		xP.is_c_struct_init = true
		if t.cat != .c_typedef {
			xP.cgen.insert_before('struct /*c struct init*/')
		}
	}
	xP.next()
	xP.scanner.format_out.cut(typ.len)
	ptr := typ.contains('*')
	// TODO tm struct struct bug
	if typ == 'tm' {
		xP.cgen.lines[xP.cgen.lines.len-1] = ''
	}
	xP.check(.LCBR)
	no_star := typ.replace('*', '')
	// `user := User{foo:bar}` => `User user = (User){ .foo = bar}`
	if !ptr {
		if xP.is_c_struct_init {
			// `face := C.FT_Face{}` => `FT_Face face;`
			if xP.tk == .RCBR {
				xP.is_empty_c_struct_init = true
				xP.check(.RCBR)
				return typ
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
			return typ
		}
		xP.gen('($no_star*)memdup(&($no_star)  {') //sizeof(Node));
	}
	mut did_gen_something := false
	// Loop thru all struct init keys and assign values
	// u := User{age:20, name:'bob'}
	// Remember which fields were set, so that we dont have to zero them later
	mut inited_fields := []string
	peek := xP.peek()
	if peek == .COLON || xP.tk == .RCBR {
		for xP.tk != .RCBR {
			field := if typ != 'Option' { xP.table.var_cgen_name( xP.check_name() ) } else { xP.check_name() }
			if !xP.first_cp() && !t.has_field(field) {
				xP.error('`$t.name` has no field `$field`')
			}
			if inited_fields.contains(field) {
				xP.error('already initialized field `$field` in `$t.name`')
			}
			f := t.find_field(field)
			inited_fields << field
			xP.gen('.$field = ')
			xP.check(.COLON)
			xP.fspace()
			xP.check_types(xP.bool_expression(),  f.typ)
			if xP.tk == .COMMA {
				xP.next()
			}
			if xP.tk != .RCBR {
				xP.gen(',')
			}
			xP.fgenln('')
			did_gen_something = true
		}
		// If we already set some fields, need to prepend a comma
		if t.fields.len != inited_fields.len && inited_fields.len > 0 {
			xP.gen(',')
		}
		// Zero values: init all fields (ints to 0, strings to '' etc)
		for i, field in t.fields {
			// println('### field.name')
			// Skip if this field has already been assigned to
			if inited_fields.contains(field.name) {
				continue
			}
			field_typ := field.typ
			if !xP.builtin_mod && field_typ.ends_with('*') && field_typ.contains('Cfg') {
				xP.error('pointer field `${typ}.${field.name}` must be initialized')
			}
			// init map fields
			if field_typ.starts_with('map_') {
				xP.gen('.$field.name = new_map(1, sizeof( ${field_typ.right(4)} ))')
				inited_fields << field.name
				if i != t.fields.len - 1 {
					xP.gen(',')
				}
				did_gen_something = true
				continue
			}
			def_val := type_default(field_typ)
			if def_val != '' && def_val != '{0}' {
				xP.gen('.$field.name = $def_val')
				if i != t.fields.len - 1 {
					xP.gen(',')
				}
			}
			did_gen_something = true
		}
	}
	// Point{3,4} syntax
	else {
		mut T := xP.table.find_type(typ)
		// Aliases (TODO Hack, implement proper aliases)
		if T.fields.len == 0 && T.parent != '' {
			T = xP.table.find_type(T.parent)
		}
		for i, ffield in T.fields {
			expr_typ := xP.bool_expression()
			if !xP.check_types_no_throw(expr_typ, ffield.typ) {
				xP.error('field value #${i+1} `$ffield.name` has type `$ffield.typ`, got `$expr_typ` ')
			}
			if i < T.fields.len - 1 {
				if xP.tk != .COMMA {
					xP.error('too few values in `$typ` literal (${i+1} instead of $T.fields.len)')
				}
				xP.gen(',')
				xP.next()
			}
		}
		// Allow `user := User{1,2,3,}`
		// The final comma will be removed by xQFmt, since we are not calling `xP.fgen()`
		if xP.tk == .COMMA {
			xP.next()
		}
		if xP.tk != .RCBR {
			xP.error('too many fields initialized: `$typ` has $T.fields.len field(s)')
		}
		did_gen_something = true
	}
	if !did_gen_something {
		xP.gen('0')
	}
	xP.gen('}')
	if ptr {
		xP.gen(', sizeof($no_star))')
	}
	xP.check(.RCBR)
	xP.is_struct_init = false
	return typ
}

// `f32(3)`
// tk is `f32` or `)` if `(*int)(ptr)`
fn (xP mut Parser) cast(typ string) string {
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
	return typ
}

fn (xP mut Parser) get_tmp() string {
	xP.tmp_count++
	return 'tmp$xP.tmp_count'
}

fn (xP mut Parser) get_tmp_counter() int {
	xP.tmp_count++
	return xP.tmp_count
}

fn (xP mut Parser) if_statement(is_expr bool, elif_depth int) string {
	if is_expr {
		//if xP.fileis('if_expr') {
			//println('IF EXPR')
		//}
		xP.inside_if_expr = true
		xP.gen('(')
	}
	else {
		xP.gen('if (')
		xP.fgen('if ')
	}
	xP.next()
	xP.check_types(xP.bool_expression(), 'bool')
	if is_expr {
		xP.gen(') ? (')
	}
	else {
		xP.genln(') {')
	}
	xP.fgen(' ')
	xP.check(.LCBR)
	mut typ := ''
	// if { if hack
	if xP.tk == .key_if && xP.inside_if_expr {
		typ = xP.factor()
		xP.next()
	}
	else {
		typ = xP.statements()
	}
	if_returns := xP.returns
	xP.returns = false
	// println('IF TYp=$typ')
	if xP.tk == .key_else {
		xP.fgenln('')
		xP.check(.key_else)
		xP.fspace()
		if xP.tk == .key_if {
			if is_expr {
				xP.gen(') : (')
				nested := xP.if_statement(is_expr, elif_depth + 1)
				nested_returns := xP.returns
				xP.returns = if_returns && nested_returns
				return nested
			}
			else {
				xP.gen(' else ')
				nested := xP.if_statement(is_expr, 0)
				nested_returns := xP.returns
				xP.returns = if_returns && nested_returns
				return nested
			}
			// return ''
		}
		if is_expr {
			xP.gen(') : (')
		}
		else {
			xP.genln(' else { ')
		}
		xP.check(.LCBR)
		// statements() returns the type of the last statement
		typ = xP.statements()
		xP.inside_if_expr = false
		if is_expr {
			xP.gen(strings.repeat(`)`, elif_depth + 1))
		}
		else_returns := xP.returns
		xP.returns = if_returns && else_returns
		return typ
	}
	xP.inside_if_expr = false
	if xP.fileis('test_test') {
		println('if ret typ="$typ" line=$xP.scanner.line_no_y')
	}
	return typ
}

fn (xP mut Parser) for_statement() {
	xP.check(.key_for)
	xP.fgen(' ')
	xP.for_expr_count++
	next_tk := xP.peek()
	//debug := xP.scanner.file_path.contains('r_draw')
	xP.cur_fn.open_scope()
	if xP.tk == .LCBR {
		// Infinite loop
		xP.gen('while (1) {')
	}
	else if xP.tk == .key_mutable {
		xP.error('`mut` is not required in for loops')
	}
	// for i := 0; i < 10; i++ {
	else if next_tk == .DECL_ASSIGN || next_tk == .ASSIGN || xP.tk == .SEMICOLON {
		xP.genln('for (')
		if next_tk == .DECL_ASSIGN {
			xP.var_decl()
		}
		else if xP.tk != .SEMICOLON {
			// allow `for ;; i++ {`
			// Allow `for i = 0; i < ...`
			xP.statement(false)
		}
		xP.check(.SEMICOLON)
		xP.gen(' ; ')
		xP.fgen(' ')
		if xP.tk != .SEMICOLON {
			xP.bool_expression()
		}
		xP.check(.SEMICOLON)
		xP.gen(' ; ')
		xP.fgen(' ')
		if xP.tk != .LCBR {
			xP.statement(false)
		}
		xP.genln(') { ')
	}
	// for i, val in array
	else if xP.peek() == .COMMA {
		// for i, val in array { ==>
		//
		// array_int tmp = array;
		// for (int i = 0; i < tmp.len; i++) {
		// int val = tmp[i];
		i := xP.check_name()
		xP.check(.COMMA)
		val := xP.check_name()
		xP.fgen(' ')
		xP.check(.key_in)
		xP.fgen(' ')
		tmp := xP.get_tmp()
		xP.cgen.start_tmp()
		typ := xP.bool_expression()
		is_arr := typ.starts_with('array_')
		is_map := typ.starts_with('map_')
		is_str := typ == 'string'
		if !is_arr && !is_str && !is_map {
			xP.error('cannot range over type `$typ`')
		}
		expr := xP.cgen.end_tmp()
		xP.genln('$typ $tmp = $expr ;')
		pad := if is_arr { 6 } else  { 4 }
		var_typ := if is_str { 'byte' } else { typ.right(pad) }
		// typ = strings.Replace(typ, "_ptr", "*", -1)
		// Register temp var
		val_var := Var {
			name: val
			typ: var_typ
			ptr: typ.contains('*')
		}
		xP.register_var(val_var)
		if is_arr {
			i_var := Var {
				name: i
				typ: 'int'
				// parent_fn: xP.cur_fn
				is_mutable: true
				is_changed: true
			}
			xP.register_var(i_var)
			xP.genln(';\nfor (int $i = 0; $i < $tmp .len; $i ++) {')
			xP.genln('$var_typ $val = (($var_typ *) $tmp . data)[$i];')
		}
		else if is_map {
			i_var := Var {
				name: i
				typ: 'string'
				is_mut: true
				is_changed: true
			}
			xP.register_var(i_var)
			xP.genln('array_string keys_$tmp = map_keys(& $tmp ); ')
			xP.genln('for (int l = 0; l < keys_$tmp .len; l++) {')
			xP.genln('  string $i = ((string*)keys_$tmp .data)[l];')
			//xP.genln('  string $i = *(string*) ( array__get(keys_$tmp, l) );')
			def := type_default(typ)
			// TODO don't call map_get() for each key, fetch values while traversing
			// the tree (replace `map_keys()` above with `map_key_vals()`)
			xP.genln('$var_typ $val = $def; map_get($tmp, $i, & $val);')
		}
		else if is_str {
			i_var := Var {
				name: i
				typ: 'byte'
				is_mutable: true
				is_changed: true
			}
			xP.register_var(i_var)
			xP.genln('array_byte bytes_$tmp = string_bytes( $tmp );')
			xP.genln(';\nfor (int $i = 0; $i < $tmp .len; $i ++) {')
			xP.genln('$var_typ $val = (($var_typ *) bytes_$tmp . data)[$i];')
		}
	}
	// `for val in vals`
	else if xP.peek() == .key_in {
		val := xP.check_name()
		xP.fgen(' ')
		xP.check(.key_in)
		xP.fspace()
		tmp := xP.get_tmp()
		xP.cgen.start_tmp()
		typ := xP.bool_expression()
		expr := xP.cgen.end_tmp()
		is_range := xP.tk == .DOTDOT
		mut range_end := ''
		if is_range {
			xP.check_types(typ, 'int')
			xP.check_space(.DOTDOT)
			xP.cgen.start_tmp()
			xP.check_types(xP.bool_expression(), 'int')
			range_end = xP.cgen.end_tmp()
		}
		is_arr := typ.contains('array')
		is_str := typ == 'string'
		if !is_arr && !is_str && !is_range {
			xP.error('cannot range over type `$typ`')
		}
		xP.genln('$typ $tmp = $expr;')
		// TODO var_type := if...
		mut var_type := ''
		if is_arr {
			var_type = typ.right(6)// all after `array_`
		}
		else if is_str {
			var_type = 'byte'
		}
		else if is_range {
			var_type = 'int'
		}
		// println('for typ=$typ vartyp=$var_typ')
		// Register temp var
		val_var := Var {
			name: val
			typ: var_type
			ptr: typ.contains('*')
			is_changed: true
		}
		xP.register_var(val_var)
		i := xP.get_tmp()
		if is_range {
			xP.genln(';\nfor (int $i = $tmp; $i < $range_end; $i++) {')
		}
		else {
			xP.genln(';\nfor (int $i = 0; $i < $tmp .len; $i ++) {')
		}
		if is_arr {
			xP.genln('$var_type $val = (($var_type *) ${tmp}.data)[$i];')
		}
		else if is_str {
			xP.genln('$var_type $val = (($var_type *) ${tmp}.str)[$i];')
		}
		else if is_range {
			xP.genln('$var_type $val = $i;')
		}
	}
	else {
		// `for a < b {`
		xP.gen('while (')
		xP.check_types(xP.bool_expression(), 'bool')
		xP.genln(') {')
	}
	xP.fspace()
	xP.check(.LCBR)
	xP.genln('')
	xP.statements()
	xP.close_scope()
	xP.for_expr_cnt--
	xP.returns = false // TODO handle loops that are guaranteed to return
}

fn (xP mut Parser) switch_statement() {
	if xP.tk == .key_switch {
		xP.check(.key_switch)
	} else {
		xP.check(.key_match)
	}
	xP.cgen.start_tmp()
	typ := xP.bool_expression()
	expr := xP.cgen.end_tmp()
	xP.check(.LCBR)
	mut i := 0
	mut all_cases_return := true
	for xP.tk == .key_case || xP.tk == .key_default || xP.peek() == .ARROW || xP.tk == .key_else {
		xP.returns = false
		if xP.tk == .key_default || xP.tk == .key_else {
			xP.genln('else  { // default:')
			if xP.tk == .key_default {
				xP.check(.key_default)
				xP.check(.COLON)
			}  else {
				xP.check(.key_else)
				xP.check(.ARROW)
			}
			xP.statements()
			xP.returns = all_cases_return && xP.returns
			return
		}
		if i > 0 {
			xP.gen('else ')
		}
		xP.gen('if (')
		// Multiple checks separated by comma
		mut got_comma := false
		for {
			if got_comma {
				xP.gen(') ||  ')
			}
			if typ == 'string' {
				xP.gen('string_eqeq($expr, ')
			}
			else {
				xP.gen('($expr == ')
			}
			if xP.tk == .key_case || xP.tk == .key_default {
				xP.check(xP.tk)
			}
			xP.bool_expression()
			if xP.tk != .COMMA {
				break
			}
			xP.check(.COMMA)
			got_comma = true
		}
		if xP.tk == .COLON {
			xP.check(.COLON)
		}
		else {
			xP.check(.ARROW)
		}
		xP.gen(')) {')
		xP.genln('/* case */')
		xP.statements()
		all_cases_return = all_cases_return && xP.returns
		i++
	}
	xP.returns = false // only get here when no default, so return is not guaranteed
}

// Returns typ if used as expession
fn (xP mut Parser) match_statement(is_expr bool) string {
	xP.check(.key_match)
	xP.cgen.start_tmp()
	typ := xP.bool_expression()
	expr := xP.cgen.end_tmp()

	// is it safe to use xP.cgen.insert_before ???
	tmp_var := xP.get_tmp()
	xP.cgen.insert_before('$typ $tmp_var = $expr;')

	xP.check(.LCBR)
	mut i := 0
	mut all_cases_return := true

	// stores typ of resulting variable
	mut res_typ := ''

	defer {
		xP.check(.RCBR)
	}

	for xP.tk != .RCBR {
		if xP.tk == .key_else {
			xP.check(.key_else)
			xP.check(.ARROW)

			// unwrap match if there is only else
			if i == 0 {
				if is_expr {
					// statements are dissallowed (if match is expression) so user cant declare variables there and so on

					// allow braces is else
					got_brace := xP.tk == .LCBR
					if got_brace {
						xP.check(.LCBR)
					}

					xP.gen('( ')

					res_typ = xP.bool_expression()

					xP.gen(' )')

					// allow braces in else
					if got_brace {
						xP.check(.RCBR)
					}

					return res_typ
				} else {
					xP.returns = false
					xP.check(.LCBR)

					xP.genln('{ ')
					xP.statements()
					xP.returns = all_cases_return && xP.returns
					return ''
				}
			}

			if is_expr {
				// statements are dissallowed (if match is expression) so user cant declare variables there and so on
				xP.gen(':(')

				// allow braces is else
				got_brace := xP.tk == .LCBR
				if got_brace {
					xP.check(.LCBR)
				}

				xP.check_types(xP.bool_expression(), res_typ)

				// allow braces in else
				if got_brace {
					xP.check(.RCBR)
				}

				xP.gen(strings.repeat(`)`, i+1))

				return res_typ
			} else {
				xP.returns = false
				xP.genln('else // default:')

				xP.check(.LCBR)

				xP.genln('{ ')
				xP.statements()

				xP.returns = all_cases_return && xP.returns
				return ''
			}
		}

		if i > 0 {
			if is_expr {
				xP.gen(': (')
			} else {
				xP.gen('else ')
			}
		} else if is_expr {
			xP.gen('(')
		}

		if is_expr {
			xP.gen('(')
		} else {
			xP.gen('if (')
		}

		// Multiple checks separated by comma
		mut got_comma := false

		for {
			if got_comma {
				xP.gen(') || (')
			}

			if typ == 'string' {
				// TODO: use tmp variable
				// xP.gen('string_eqeq($tmp_var, ')
				xP.gen('string_eqeq($tmp_var, ')
			}
			else {
				// TODO: use tmp variable
				// xP.gen('($tmp_var == ')
				xP.gen('($tmp_var == ')
			}

			xP.expected_type = typ
			xP.check_types(xP.bool_expression(), typ)
			xP.expected_type = ''

			if xP.tk != .COMMA {
				if got_comma {
 					xP.gen(') ')
				}
				break
			}
			xP.check(.COMMA)
			got_comma = true
		}
		xP.gen(') )')

		xP.check(.ARROW)

		// statements are dissallowed (if match is expression) so user cant declare variables there and so on
		if is_expr {
			xP.gen('? (')

			// braces are required for now
			xP.check(.LCBR)

			if i == 0 {
				// on the first iteration we set value of res_typ
				res_typ = xP.bool_expression()
			} else {
				// later on we check that the value is of res_typ type
				xP.check_types(xP.bool_expression(), res_typ)
			}

			// braces are required for now
			xP.check(.RCBR)

			xP.gen(')')
		}
		else {
			xP.returns = false
			xP.check(.LCBR)

			xP.genln('{ ')
			xP.statements()

			all_cases_return = all_cases_return && p.returns
			// xP.gen(')')
		}
		i++
	}

	if is_expr {
		// we get here if no else found, ternary requires "else" branch
		xP.error('Match expession requires "else"')
	}

	xP.returns = false // only get here when no default, so return is not guaranteed

	return ''
}

fn (xP mut Parser) assert_statement() {
	if xP.first_cp() {
		return
	}
	xP.check(.key_assert)
	xP.fspace()
	tmp := xP.get_tmp()
	xP.gen('bool $tmp = ')
	xP.check_types(xP.bool_expression(), 'bool')
	// TODO print "expected:  got" for failed tests
	filename := xP.file_path.replace('\\', '\\\\')
	xP.genln(';\n
if (!$tmp) {
  println(tos2((byte *)"\\x1B[31mFAILED: $xP.cur_fn.name() in $filename:$xP.scanner.line_no_y\\x1B[0m"));
g_test_ok = 0 ;
	// TODO
	// Maybe print all vars in a test function if it fails?
}
else {
  //puts("\\x1B[32mPASSED: $xP.cur_fn.name()\\x1B[0m");
}')
}

fn (xP mut Parser) return_statement() {
	xP.check(.key_return)
	xP.fgen(' ')
	fn_returns := xP.cur_fn.typ != 'void'
	if fn_returns {
		if xP.tk == .RCBR {
			xP.error('`$xP.cur_fn.name` needs to return `$xP.cur_fn.typ`')
		}
		else {
			sh := xP.cgen.add_shadow()
			expr_type := xP.bool_expression()
			// Automatically wrap an object inside an option if the function returns an option
			if xP.cur_fn.typ.ends_with(expr_type) && xP.cur_fn.typ.starts_with('Option_') {
				tmp := xP.get_tmp()
				ret := xP.cgen.cur_line.right(sh)
				typ := expr_type.replace('Option_', '')
				xP.cgen.cur_line = '$expr_type $tmp = OPTION_CAST($typ)($ret);'
				xP.cgen.resetln('$expr_type $tmp = OPTION_CAST($expr_type)($ret);')
				xP.gen('return opt_ok(&$tmp, sizeof($typ))')
			}
			else {
				ret := xP.cgen.cur_line.right(sh)

				// Scoped defer:
				// Check all of our defer texts to see if there is one at a higher scope level
				// The one for our current scope would be the last so any before that need to be
				// added.

				mut total_text := ''

				for text in xP.cur_fn.defer_text {
					if text != '' {
						// In reverse order
						total_text = text + total_text
					}
				}

				if total_text == '' || expr_type == 'void*' {
					if expr_type == '${xP.cur_fn.typ}*' {
						xP.cgen.resetln('return *$ret')
					} else {
						xP.cgen.resetln('return $ret')
					}
				}  else {
					tmp := xP.get_tmp()
					xP.cgen.resetln('$expr_type $tmp = $ret;\n')
					xP.genln(total_text)
					xP.genln('return $tmp;')
				}
			}
			xP.check_types(expr_type, xP.cur_fn.typ)
		}
	}
	else {
		// Don't allow `return val` in functions that don't return anything
		if !xP.is_WebX && (xP.tk == .NAME || xP.tk == .NUMBER || xP.tk == .STRING) {
			xP.error('function `$xP.cur_fn.name` should not return a value')
		}

		if xP.cur_fn.name == 'main' {
			xP.gen('return 0')
		}
		else {
			xP.gen('return')
		}
	}
	xP.returns = true
}

fn prepend_mod(mod, name string) string {
	return '${mod}__${name}'
}

fn (xP &Parser) prepend_mod(name string) string {
	return prepend_mod(xP.mod, name)
}

fn (xP mut Parser) go_statement() {
	xP.check(.key_go)
	// TODO copypaste of name_expr() ?
	// Method
	if xP.peek() == .DOT {
		var_name := xP.lit
		var := xP.cur_fn.find_var(var_name)
		xP.cur_fn.mark_var_used(var)
		xP.next()
		xP.check(.DOT)
		typ := xP.table.find_type(var.typ)
		method := xP.table.find_method(typ, xP.lit)
		xP.async_fn_call(method, 0, var_name, var.typ)
	}
	// Normal function
	else {
		f := xP.table.find_fn(xP.lit)
		if f.name == 'println' {
			xP.error('`go` cannot be used with `println`')
		}
		// println(f.name)
		xP.async_fn_call(f, 0, '', '')
	}
}

fn (xP mut Parser) register_var(var Var) {
	if var.line_no_y == 0 {
		//var.line_no_y = xP.scanner.line_no_y
		xP.cur_fn.register_var({ var | line_no_y: xP.scanner.line_no_y })
	} else {
		xP.cur_fn.register_var(var)
	}
}

// user:=json_decode(User, user_json_string)
fn (xP mut Parser) json_decode() string {
	xP.check(.NAME)// json
	xP.check(.DOT)
	op := xP.check_name()
	if op == 'decode' {
		// User tmp2; tmp2.foo = 0; tmp2.bar = 0;// I forgot to zero vals before => huge bug
		// Option_User tmp3 =  json_decode_User(json_parse( s), &tmp2); ;
		// if (!tmp3 .ok) {
		// return
		// }
		// User u = *(User*) tmp3 . data;  // TODO remove this (generated in or {} block handler)
		xP.check(.LPAR)
		typ := xP.get_type()
		xP.check(.COMMA)
		xP.cgen.start_tmp()
		xP.check_types(xP.bool_expression(), 'string')
		expr := xP.cgen.end_tmp()
		xP.check(.RPAR)
		tmp := xP.get_tmp()
		cjson_tmp := xP.get_tmp()
		mut decl := '$typ $tmp; '
		// Init the struct
		T := xP.table.find_type(typ)
		for field in T.fields {
			def_val := type_default(field.typ)
			if def_val != '' {
				decl += '$tmp . $field.name = OPTION_CAST($field.typ) $def_val;\n'
			}
		}
		xP.gen_json_for_type(T)
		decl += 'cJSON* $cjson_tmp = json__json_parse($expr);'
		xP.cgen.insert_before(decl)
		// xP.gen('json_decode_$typ(json_parse($expr), &$tmp);')
		xP.gen('json__json_decode_$typ($cjson_tmp, &$tmp); cJSON_Delete($cjson_tmp);')
		opt_type := 'Option_$typ'
		xP.cgen.typedefs << 'typedef Option $opt_type;'
		xP.table.register_type(opt_type)
		return opt_type
	}
	else if op == 'encode' {
		xP.check(.LPAR)
		xP.cgen.start_tmp()
		typ := xP.bool_expression()
		T := xP.table.find_type(typ)
		xP.gen_json_for_type(T)
		expr := xP.cgen.end_tmp()
		xP.check(.RPAR)
		xP.gen('json__json_print(json__json_encode_$typ($expr))')
		return 'string'
	}
	else {
		xP.error('bad json op "$op"')
	}
	return ''
}

fn (xP mut Parser) attribute() {
	xP.check(.LSBR)
	if xP.tk == .key_interface {
		xP.check(.key_interface)
		xP.check(.COLON)
		xP.attr = 'interface:' + xP.check_name()
	} else {
		xP.attr = xP.check_name()
	}
	xP.check(.RSBR)
	if xP.tk == .key_function {
		xP.fn_decl()
		xP.attr = ''
		return
	}
	else if xP.tk == .key_struct {
		xP.struct_decl()
		xP.attr = ''
		return
	}
	xP.error('bad attribute usage')
}

fn (xP mut Parser) defer_statement() {
	xP.check(.key_defer)
	xP.check(.LCBR)

	pos := xP.cgen.lines.len

	// Save everything inside the defer block to `defer_text`.
	// It will be inserted before every `return`

	// TODO: all variables that are used in this defer statement need to be evaluated when the block
	// is defined otherwise they could change over the course of the function
	// (make temps out of them)

	xP.genln('{')
	xP.statements()
	xP.cur_fn.defer_text.last() = xP.cgen.lines.right(pos).join('\n') + xP.cur_fn.defer_text.last()

	// Rollback xP.cgen.lines
	xP.cgen.lines = xP.cgen.lines.left(pos)
	xP.cgen.resetln('')
}
