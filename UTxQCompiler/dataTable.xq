// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import math
import StringX

struct dataTable {
mut:
	modules                []string // List of all modules registered by the application
	imports                []string // List of all imported libraries
	typesmap               map[string]Type
	consts                 []Var
	fns                    map[string]Fn
	generic_fns            []GenFnTable //map[string]GenFnTable // generic_fns['listen_and_serve'] == ['Blog', 'Forum']
	file_imports           map[string]ParsedImportsTable // List of file Imports scoped to the parsed file
	cflags                 []CFlag //  ['-framework DotNet', '-WebGL']
	fn_count               int // atomic
	is_obfuscated          bool
	obf_ids                map[string]int
}

struct GenFnTable {
	fn_name string
mut:
	types   []string
}

// Holds import information scoped to the parsed file
struct ParsedImportsTable {
mut:
	module_name  string
	file_path    string
	imports      map[string]string // alias => module
	used_imports []string          // alias
}

enum AccessMod {
	private            // Private Immutable
	privateMUT         // Private Mutable
	public             // Public Immutable (read only)
	publicMUT      	   // Public, but Mutable only in current module
	publicDMUT         // Public and Dual Mutable (NOT Safe Always)
}

enum TypeCategory {
	builtin
	struct
	function // 2
	interface
	enum
	union    // 5
	c_struct
	c_typedef
	objc_interface // 8 Objective-C @interface
	array
}

struct Var {
mut:
	typ             string
	name            string
	is_arg          bool
	is_const        bool
	args            []Var // function args
	attr            string //  [json] etc
	is_mutable      bool
	is_alloc        bool
	is_returned		bool
	ptr             bool
	ref             bool
	parent_fn       string // Variables can only be defined in functions
	mod             string // Module where this var is stored
	access_mod      AccessMod
	is_global       bool // Global (translated from C only)
	is_used         bool
	is_changed      bool
	scope_level     int
	is_c            bool // Remove once `typ` is `Type`, not string
	moved           bool
	scanner_pos     ScannerPosX // TODO: Use only scanner_pos, remove line_no_y
	line_no_y       int
}

struct Type {
mut:
	mod            string
	name           string
	cat            TypeCategory
	fields         []Var
	methods        []Fn
	parent         string
	function       Fn // For cat == FN (type myfn fn())
	is_c           bool // 'C.file'
	enum_vals      []string
	gen_types      []string
	// Shadow Types are not defined previously but are known to exist.
	// See Documentation for more details on Shadow Types.
	// This information is needed in the first CheckPoint.
	is_shadow      bool
	gen_str	       bool  // needs `.str()` method generation
}

struct TypeNode {
mut:
	next &TypeNode
	typ Type
}

// For debugging types
fn (t Type) str() string {
	mut st := 'type "$t.name" {'
	if t.fields.len > 0 {
		// st += '\n    $t.fields.len fields:\n'
		for field in t.fields {
			st += '\n    $field.name $field.typ'
		}
		st += '\n'
	}
	if t.methods.len > 0 {
		// st += '\n    $t.methods.len methods:\n'
		for method in t.methods {
			st += '\n    ${method.str()}'
		}
		st += '\n'
	}
	st += '}\n'
	return st
}

const (
	CReserved = [
		'delete',
		'exit',
		'unix',
		//'print',
		//'ok',
		'error',
		'malloc',
		'calloc',
		'free',
		'panic',
    // Complete list of C reserved words, from: https://en.cppreference.com/w/c/keyword
		'auto',
		'char',
		'default',
		'do',
		'double',
		'extern',
		'float',
		'inline',
		'int',
		'long',
		'register',
		'restrict',
		'short',
		'signed',
		'sizeof',
		'static',
		'switch',
		'typedef',
		'union',
		'unsigned',
		'void',
		'volatile',
		'while',
	]

)

// This is used for debugging only
fn (f Fn) str() string {
	t := dataTable{}
	str_args := f.str_args(t)
	return '$f.name($str_args) $f.typ'
}

fn (t &dataTable) debug_fns() string {
	mut st := StringX.new_builder(1000)
	for k, f in t.fns {
		st.writeln(f.name)
	}
	return st.str()
}

// fn (types array_Type) print_to_file(f string)  {
// }
const (
  number_types = ['number', 'int', 'i8', 'i16', 'u16', 'u32', 'byte', 'i64', 'u64', 'f32', 'f64']
  float_types  = ['f32', 'f64']
)

fn is_number_type(typ string) bool {
	return typ in number_types
}

fn is_float_type(typ string) bool {
	return typ in float_types
}

fn is_primitive_type(typ string) bool {
	return is_number_type(typ) || typ == 'string'
}

fn new_table(is_obfuscated bool) &dataTable {
	mut t := &dataTable {
		is_obfuscated: is_obfuscated
	}
	t.register_type('int')
	t.register_type('size_t')
	t.register_type_with_parent('i8', 'int')
	t.register_type_with_parent('byte', 'int')
	t.register_type_with_parent('char', 'int') // for C functions, to avoid warnings
	t.register_type_with_parent('i16', 'int')
	t.register_type_with_parent('u16', 'u32')
	t.register_type_with_parent('u32', 'int')
	t.register_type_with_parent('i64', 'int')
	t.register_type_with_parent('u64', 'u32')
	t.register_type('byteptr')
	t.register_type('intptr')
	t.register_type('f32')
	t.register_type('f64')
	t.register_type('rune')
	t.register_type('bool')
	t.register_type('void')
	t.register_type('voidptr')
	t.register_type('T')
	t.register_type('va_list')
	t.register_const('stdin', 'int', 'main')
	t.register_const('stdout', 'int', 'main')
	t.register_const('stderr', 'int', 'main')
	t.register_const('errno', 'int', 'main')
	t.register_type_with_parent('map_string', 'map')
	t.register_type_with_parent('map_int', 'map')
	return t
}

// If `name` is a reserved C keyword, returns `xQ_name` instead.
fn (t &dataTable) var_cgen_name(name string) string {
	if name in CReserved {
		return 'xQ_$name'
	}
	else {
		return name
	}
}

fn (t mut dataTable) register_module(mod string) {
	if mod in t.modules {
		return
	}
	t.modules << mod
}

fn (xQP mut Parser) register_array(typ string) {
	if typ.contains('*') {
		println('Bad Array $typ')
		return
	}
	if !xQP.table.known_type(typ) {
		xQP.register_type_with_parent(typ, 'array')
		xQP.cgen.typedefs << 'typedef array $typ;'
	}
}

fn (xQP mut Parser) register_map(typ string) {
	if typ.contains('*') {
		println('Bad Map $typ')
		return
	}
	if !xQP.table.known_type(typ) {
		xQP.register_type_with_parent(typ, 'map')
		xQP.cgen.typedefs << 'typedef map $typ;'
	}
}

fn (table &dataTable) known_mod(mod string) bool {
	return mod in table.modules
}

fn (t mut dataTable) register_const(name, typ, mod string) {
	t.consts << Var {
		name: name
		typ: typ
		is_const: true
		mod: mod
	}
}

// Only for translated code
fn (xQP mut Parser) register_global(name, typ string) {
	xQP.table.consts << Var {
		name: name
		typ: typ
		is_const: true
		is_global: true
		mod: xQP.mod
		is_mutable: true
	}
}

fn (t mut dataTable) register_fn(new_fn Fn) {
	t.fns[new_fn.name] = new_fn
}

fn (table &dataTable) known_type(typ_ string) bool {
	mut typ := typ_
	// 'byte*' => look up 'byte', but don't mess up fns
	if typ.ends_with('*') && !typ.contains(' ') {
		typ = typ.left(typ.len - 1)
	}
	t := table.typesmap[typ]
	return t.name.len > 0 && !t.is_shadow
}


fn (t &dataTable) find_fn(name string) ?Fn {
	f := t.fns[name]
	if !isnull(f.name.str) {
		return f
	}
	return none
}

fn (t &dataTable) known_fn(name string) bool {
	_ := t.find_fn(name) or { return false }
	return true
}

fn (t &dataTable) known_const(name string) bool {
	_ := t.find_const(name) or { return false }
	return true
}

fn (t mut dataTable) register_type(typ string) {
	if typ.len == 0 {
		return
	}
	if typ in t.typesmap {
		return
		}
	t.typesmap[typ] = Type{name:typ}
}

fn (xQP mut Parser) register_type_with_parent(strtyp, parent string) {
	typ := Type {
		name: strtyp
		parent: parent
		mod: xQP.mod
	}
	xQP.table.register_type2(typ)
}

fn (t mut dataTable) register_type_with_parent(typ, parent string) {
	if typ.len == 0 {
		return
	}
	t.typesmap[typ] = Type {
		name: typ
		parent: parent
		//mod: mod
	}
}

fn (t mut dataTable) register_type2(typ Type) {
	if typ.name.len == 0 {
		return
	}
	t.typesmap[typ.name] = typ
}

fn (t mut dataTable) rewrite_type(typ Type) {
	if typ.name.len == 0 {
		return
	}
	t.typesmap[typ.name]  = typ
}

fn (table mut dataTable) add_field(type_name, field_name, field_type string, is_mutable bool, attr string, access_mod AccessMod) {
	if type_name == '' {
		print_backtrace()
		cerror('add_field: empty type')
	}
	mut t := table.typesmap[type_name]
	t.fields << Var {
		name: field_name
		typ: field_type
		is_mutable: is_mutable
		attr: attr
		parent_fn: type_name   // Name of the parent type
		access_mod: access_mod
	}
	table.typesmap[type_name] = t
}

fn (t &Type) has_field(name string) bool {
	_ := t.find_field(name) or { return false }
	return true
}

fn (t &Type) has_enum_val(name string) bool {
	return name in t.enum_vals
}

fn (t &Type) find_field(name string) ?Var {
	for field in t.fields {
		if field.name == name {
			return field
		}
	}
	return none
}

fn (table &dataTable) type_has_field(typ &Type, name string) bool {
	_ := table.find_field(typ, name) or { return false }
	return true
}

fn (table &dataTable) find_field(typ &Type, name string) ?Var {
	for field in typ.fields {
		if field.name == name {
			return field
		}
	}
	if typ.parent != '' {
		parent := table.find_type(typ.parent)
		for field in parent.fields {
			if field.name == name {
				return field
			}
		}
	}
	return none
}

fn (xP mut Parser) add_method(type_name string, f Fn) {
	if !xP.first_cp() && f.name != 'str' {
		return
	}
	if type_name == '' {
		print_backtrace()
		cerror('add_method: empty type')
	}
	// TODO table.typesmap[type_name].methods << f
	mut t := xP.table.typesmap[type_name]
	if type_name == 'str' {
		println(t.methods.len)
	}

	t.methods << f
	if type_name == 'str' {
		println(t.methods.len)
	}	
	xP.table.typesmap[type_name] = t
}

fn (t &Type) has_method(name string) bool {
	_ := t.find_method(name) or { return false }
	return true
}

fn (table &dataTable) type_has_method(typ &Type, name string) bool {
	_ := table.find_method(typ, name) or { return false }
	return true
}

fn (table &dataTable) find_method(typ &Type, name string) ?Fn {
	t := table.typesmap[typ.name]
	for method in t.methods {
		if method.name == name {
			return method
		}
	}
	if typ.parent != '' {
		parent := table.find_type(typ.parent)
		for method in parent.methods {
			if method.name == name {
				return method
			}
		}
		return none
	}
	return none
}

fn (t &Type) find_method(name string) ?Fn {
	// println('$t.name find_method($name) methods.len=$t.methods.len')
	for method in t.methods {
		// println('method=$method.name')
		if method.name == name {
			return method
		}
	}
	return none
}

/*
// TODO
fn (t mutt Type) add_gen_type(type_name string) {
	// println('add_gen_type($s)')
	if t.gen_types.contains(type_name) {
		return
	}
	t.gen_types << type_name
}
*/

fn (xP &Parser) find_type(name string) Type {
	typ := xP.table.find_type(name)
	if typ.name == '' {
		return xP.table.find_type(xP.prepend_mod(name))
	}
	return typ
}

fn (t &dataTable) find_type(name_ string) Type {
	mut name := name_
	if name.ends_with('*') && !name.contains(' ') {
		name = name.left(name.len - 1)
	}
	if !(name in t.typesmap) {
		//println('ret Type')
		return Type{}
	}
	return t.typesmap[name]
}

fn (xP mut Parser) _check_types(got_, expected_ string, throw bool) bool {
	mut got := got_
	mut expected := expected_
	//xP.log('check types got="$got" exp="$expected"  ')
	if xP.pref.translated {
		return true
	}
	// Allow ints to be used as floats
	if got == 'int' && expected == 'f32' {
		return true
	}
	if got == 'int' && expected == 'f64' {
		return true
	}
	if got == 'f64' && expected == 'f32' {
		return true
	}
	if got == 'f32' && expected == 'f64' {
		return true
	}
	// Allow ints to be used as longs
	if got=='int' && expected=='i64' {
		return true
	}
	if got == 'void*' && expected.starts_with('fn ') {
		return true
	}
	if got.starts_with('[') && expected == 'byte*' {
		return true
	}
	// Todo void* allows everything right now
	if got=='void*' || expected=='void*'
  {// || got == 'cvoid' || expected == 'cvoid' {

		return true
	}
	// TODO only allow numeric consts to be assigned to bytes, and
	// throw an error if they are bigger than 255
	if got=='int' && expected=='byte' {
		return true
	}
	if got=='byteptr' && expected=='byte*' {
		return true
	}
	if got=='byte*' && expected=='byteptr' {
		return true
	}
	if got=='int' && expected=='byte*' {
		return true
	}
	//if got=='int' && expected=='voidptr*' {
		//return true
	//}
	// byteptr += int
	if got=='int' && expected=='byteptr' {
		return true
	}
	if got == 'Option' && expected.starts_with('Option_') {
		return true
	}
	// lines := new_array
	if got == 'array' && expected.starts_with('array_') {
		return true
	}
	// Expected type "Option_os__File", got "os__File"
	if expected.starts_with('Option_') && expected.ends_with(got) {
		return true
	}
	// NsColor* return 0
	if expected.ends_with('*') && got == 'int' {
		return true
	}
	// if got == 'T' || got.contains('<T>') {
	// return true
	// }
	// if expected == 'T' || expected.contains('<T>') {
	// return true
	// }
	// TODO fn hack
	if got.starts_with('fn ') && (expected.ends_with('fn') || expected.ends_with('Fn')) {
		return true
	}
	// Allow pointer arithmetic
	if expected=='void*' && got=='int' {
		return true
	}
	// Allow `myu64 == 1`
	//if xP.fileis('Xtest') && is_number_type(got) && is_number_type(expected)  {
		//xP.warn('got=$got exp=$expected $xP.is_const_lit')
	//}
	if is_number_type(got) && is_number_type(expected) && xP.is_const_lit {
		return true
	}
	expected = expected.replace('*', '')
	got = got.replace('*', '')
	if got != expected {
		// Interface check
		if expected.ends_with('er') {
			if xP.satisfies_interface(expected, got, throw) {
				return true
			}
		}
		if !throw {
			return false
		}
		else {
			xP.error('expected type `$expected`, but got `$got`')
		}
	}
	return true
}

// throw by default
fn (xP mut Parser) check_types(got, expected string) bool {
	if xP.first_cp() { return true }
	return xP._check_types(got, expected, true)
}

fn (xP mut Parser) check_types_no_throw(got, expected string) bool {
	return xP._check_types(got, expected, false)
}

fn (xP mut Parser) satisfies_interface(interface_name, _typ string, throw bool) bool {
	int_typ := xP.table.find_type(interface_name)
	typ := xP.table.find_type(_typ)
	for method in int_typ.methods {
		if !typ.has_method(method.name) {
			// if throw {
			xP.error('Type "$_typ" doesn\'t satisfy interface "$interface_name" (method "$method.name" is not implemented)')
			// }
			return false
		}
	}
	return true
}

fn (table &dataTable) is_interface(name string) bool {
	if !(name in table.typesmap) {
		return false
	}
	t := table.typesmap[name]
	return t.cat == .interface
}


// Do we have fn main()?
fn (t &dataTable) main_exists() bool {
	for k, f in t.fns {
		if f.name == 'main' {
			return true
		}
	}
	return false
}

fn (t &dataTable) has_at_least_one_test_fn() bool {
	for _, f in t.fns {
		if f.name.starts_with('testX') {
			return true
		}	
	}
	return false
}

fn (t &dataTable) find_const(name string) ?Var {
	for c in t.consts {
		if c.name == name {
			return c
		}
	}
	return none
}

// ('s', 'string') => 'string s'
// ('nums', '[20]byte') => 'byte nums[20]'
// ('myfn', 'fn(int) string') => 'string (*myfn)(int)'
fn (table &dataTable) cgen_name_type_pair(name, typ string) string {
	// Special case for [10]int
	if typ.len > 0 && typ[0] == `[` {
		tmp := typ.all_after(']')
		size := typ.all_before(']')
		return '$tmp $name  $size ]'
	}
	// fn()
	else if typ.starts_with('fn (') {
		T := table.find_type(typ)
		if T.name == '' {
			println('this should never happen')
			exit(1)
		}
		str_args := T.function.str_args(table)
		return '$T.function.typ (*$name)( $str_args /*FFF*/ )'
	}
	// TODO tm hack, do this for all C struct args
	else if typ == 'tm' {
		return 'struct /*TM*/ tm $name'
	}
	return '$typ $name'
}

fn is_valid_int_const(val, typ string) bool {
	x := val.int()
	switch typ {
	case 'byte': return 0 <= x && x <= math.MaxU8
	case 'u16': return 0 <= x && x <= math.MaxU16
	//case 'u32': return 0 <= x && x <= math.MaxU32
	//case 'u64': return 0 <= x && x <= math.MaxU64
	//////////////
	case 'i8': return math.MinI8 <= x && x <= math.MaxI8
	case 'i16': return math.MinI16 <= x && x <= math.MaxI16
	case 'int': return math.MinI32 <= x && x <= math.MaxI32
	//case 'i64':
		//x64 := val.i64()
		//return i64(-(1<<63)) <= x64 && x64 <= i64((1<<63)-1)
	}
	return true
}

fn (t mut dataTable) register_generic_fn(fn_name string) {
	t.generic_fns << GenFnTable{fn_name, []string}
}

fn (t &dataTable) fn_gen_types(fn_name string) []string {
	for _, f in t.generic_fns {
		if f.fn_name == fn_name {
			return f.types
		}
	}
  cerror('function $fn_name not found')
	return []string
}

// `foo<Bar>()`
// fn_name == 'foo'
// typ == 'Bar'
fn (t mut dataTable) register_generic_fn_type(fn_name, typ string) {
	for i, f in t.generic_fns {
		if f.fn_name == fn_name {
			t.generic_fns[i].types << typ
			return
		}
	}
}

fn (xP mut Parser) typ_to_format(typ string, level int) string {
	t := xP.table.find_type(typ)
	if t.cat == .enum {
		return '%d'
	}
	switch typ {
	case 'string': return '%.*s'
	//case 'bool': return '%.*s'
	case 'ustring': return '%.*s'
	case 'byte', 'bool', 'int', 'char', 'byte', 'i16', 'i8': return '%d'
	case 'u16', 'u32': return '%u'
	case 'f64', 'f32': return '%f'
	case 'i64': return '%lld'
	case 'u64': return '%llu'
	case 'byte*', 'byteptr': return '%s'
		// case 'array_string': return '%s'
		// case 'array_int': return '%s'
	case 'void': xP.error('cannot interpolate this value')
	default:
		if typ.ends_with('*') {
			return '%p'
		}
	}
	if t.parent != '' && level == 0 {
		return xP.typ_to_format(t.parent, level+1)
	}
	return ''
}

fn is_compile_time_const(s_ string) bool {
	s := s_.trim_space()
	if s == '' {
		return false
	}
	if s.contains('\'') {
		return true
	}
	for c in s {
		if ! ((c >= `0` && c <= `9`) || c == `.`) {
			return false
		}
	}
	return true
}

// Once we have a module format we can read from module file instead
// this is not optimal
fn (table &dataTable) qualify_module(mod string, file_path string) string {
	for m in table.imports {
		if m.contains('.') && m.contains(mod) {
			m_parts := m.split('.')
			m_path := m_parts.join('/')
			if mod == m_parts[m_parts.len-1] && file_path.contains(m_path) {
				return m
			}
		}
	}
	return mod
}

fn (table &dataTable) get_file_import_table(file_path string) ParsedImportsTable {
	// if file_path.clone() in table.file_imports {
	// 	return table.file_imports[file_path.clone()]
	// }
	// Just get imports. memory error when recycling import table
	mut pit := new_parsed_imports_table(file_path)
	if file_path in table.file_imports {
		pit.imports = table.file_imports[file_path].imports
	}
	return pit
}

fn new_parsed_imports_table(file_path string) ParsedImportsTable {
	return ParsedImportsTable{
		file_path: file_path
		imports:   map[string]string
	}
}

fn (pit &ParsedImportsTable) known_import(mod string) bool {
	return mod in pit.imports || pit.is_aliased(mod)
}

fn (pit mut ParsedImportsTable) register_import(mod string) {
	pit.register_alias(mod, mod)
}

fn (pit mut ParsedImportsTable) register_alias(alias string, mod string) {
	// NOTE: Come back here
	// if alias in pit.imports && pit.imports[alias] == mod {}
	if alias in pit.imports && pit.imports[alias] != mod {
		cerror('Cannot import $mod as $alias: import name $alias already in use in "${pit.file_path}".')
	}
	if mod.contains('.internal.') {
		mod_parts := mod.split('.')
		mut internal_mod_parts := []string
		for part in mod_parts {
			if part == 'internal' { break }
			internal_mod_parts << part
		}
		internal_parent := internal_mod_parts.join('.')
		if !pit.module_name.starts_with(internal_parent) {
			cerror('module $mod can only be imported internally by libraries.')
		}
	}
	pit.imports[alias] = mod
}

fn (pit &ParsedImportsTable) known_alias(alias string) bool {
	return alias in pit.imports
}

fn (pit &ParsedImportsTable) is_aliased(mod string) bool {
	for k, val in pit.imports {
		if val == mod {
			return true
		}
	}
	return false
}

fn (pit &ParsedImportsTable) resolve_alias(alias string) string {
	return pit.imports[alias]
}

fn (pit mut ParsedImportsTable) register_used_import(alias string) {
	if !(alias in pit.used_imports) {
		pit.used_imports << alias
	}
}

fn (pit &ParsedImportsTable) is_used_import(alias string) bool {
	return alias in pit.used_imports
}

fn (t &Type) contains_field_type(typ string) bool {
				if !t.name[0].is_capital() {
					return false
				}
				for field in t.fields {
					if field.typ == typ {
						return true
					}
				}
				return false
}

// Check for a function / variable / module typo in `name`
fn (table &dataTable) identify_typo(name string, current_fn &Fn, pit &ParsedImportsTable) string {
	// Dont check if name is too short
	if name.len < 2 { return '' }
	min_match := 0.50 // for dice coefficient between 0.0 - 1.0
	name_orig := name.replace('__', '.').replace('_dot_', '.')
	mut output := ''
	// Check functions
	mut n := table.find_misspelled_fn(name, pit, min_match)
	if n != '' {
		output += '\n  * function: `$n`'
	}
	// Check function local variables
	n = current_fn.find_misspelled_local_var(name_orig, min_match)
	if n != '' {
		output += '\n  * variable: `$n`'
	}
	// Check imported modules
	n = table.find_misspelled_imported_mod(name_orig, pit, min_match)
	if n != '' {
		output += '\n  * module: `$n`'
	}
	return output
}

// Find function with closest name to `name`
fn (table &dataTable) find_misspelled_fn(name string, pit &ParsedImportsTable, min_match f32) string {
	mut closest := f32(0)
	mut closest_fn := ''
	n1 := if name.starts_with('main__') { name.right(6) } else { name }
	for _, f in table.fns {
		if n1.len - f.name.len > 2 || f.name.len - n1.len > 2 { continue }
		if !(f.mod in ['', 'main', 'builtin']) {
			mut mod_imported := false
			for _, m in pit.imports {
				if f.mod == m {
					mod_imported = true
					break
				}
			}
			if !mod_imported { continue }
		}
		r := StringX.dice_coefficient(n1, f.name)
		if r > closest {
			closest = r
			closest_fn = f.name
		}
	}
	return if closest >= min_match { closest_fn } else { '' }
}

// Find imported module with closest name to `name`
fn (table &dataTable) find_misspelled_imported_mod(name string, pit &ParsedImportsTable, min_match f32) string {
	mut closest := f32(0)
	mut closest_mod := ''
	n1 := if name.starts_with('main.') { name.right(5) } else { name }
	for alias, mod in pit.imports {
		if (n1.len - alias.len > 2 || alias.len - n1.len > 2) { continue }
		mod_alias := if alias == mod { alias } else { '$alias ($mod)' }
		r := StringX.dice_coefficient(n1, alias)
		if r > closest {
			closest = r
			closest_mod = '$mod_alias'
		}
	}
	return if closest >= min_match { closest_mod } else { '' }
}