// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import (
	os
	time
	strings
)

const (
	Version = '0.1'
)

enum BuildMode {
	// `xQ program.xq'
	// Build user code only, and add pre-compiled xQLib (`XCompiler program.o builtin.o os.o...`)
	default_mode
	// `xQ -embed_xQLib program.xq`
	// xQLib + user code in one file (slower compilation, but easier when working on xQLib and cross-compiling)
	embed_xQLib
	// `xQ -lib ~/UTxQuantico/os`
	// build any module (generate os.o + os.xqh)
	build //TODO a better name would be something like `.build_module` I think
}

const (
	SupportedPlatforms = ['linux' , 'windows', 'mac', 'freebsd', 'openbsd', 'netbsd', 'dragonfly', 'msvc']
	ModPath            = os.home_dir() + '/.xQModules/'
)

enum OS {
  linux
	mac
	windows
	freebsd
	openbsd
	netbsd
	dragonfly
	msvc
}

enum CheckPoint {
	// A very short CheckPoint that only looks at imports in the beginning of
	// each file
	imports
	// First CheckPoint, only parses and saves declarations (fn signatures,
	// consts, types).
	// Skips function bodies.
	// We need this because in UTxQ things can be used before they are
	// declared.
	decl
	// Second CheckPoint, parses function bodies and generates C or machine code.
	main
}

struct UTxQ {
mut:
	os         OS // the OS to build for
	out_name_c string // name of the temporary C file
	files      []string // all UTxQ files that need to be parsed and compiled
	dir        string // directory (or file) being compiled (TODO rename to path?)
	table      &dataTable // table with types, vars, functions etc
	cgen       &CGen // C code generator
	pref       &Preferences // all the prefrences and settings extracted to a struct for reusability
	lang_dir   string // "~/code/xQ"
	out_name   string // "program.exe"
	xQRoot      string
	mod        string  // module being built with -lib
	//parsers    []Parser
}

struct Preferences {
mut:
	build_mode     BuildMode
	noxQFmt        bool // disable vfmt
	is_test        bool // `xQ test string_test.xq`
	is_script      bool // single file mode (`xQ program.xq`), main function can be skipped
	is_live        bool // for hot code reloading
	is_so          bool
	is_prof        bool // benchmark every function
	translated     bool // `xQ translate program.xq` are we running UTxQ code translated from C? allow globals, ++ expressions, etc
	is_prod        bool // use "-O2"
	is_verbose     bool // print extra information with `xQ.log()`
	is_obfuscated  bool // `xQ -obf program.xQ`, renames functions to "f_XXX"
	is_repl        bool
	is_run         bool
	show_c_cmd     bool // `xQ -show_c_cmd` prints the C command to build program.xq.c
	sanitize       bool // use Clang's new "-fsanitize" option
	is_debuggable  bool
	is_debug       bool // keep compiled C files
	no_auto_free   bool // `xQ -nofree` disable automatic `free()` insertion for better performance in some applications  (e.g. compilers)
	cflags         string // Additional options which will be passed to the C compiler.
						 // For example, passing -cflags -Os will cause the C compiler to optimize the generated binaries for size.
						 // You could pass several -cflags XXX arguments. They will be merged with each other.
						 // You can also quote several options at the same time: -cflags '-Os -fno-inline-small-functions'.
	ccompiler      string // the name of the used C compiler
}


fn main() {
	// There's no `flags` module yet, so args have to be parsed manually
	args := env_xQFlags_and_os_args()
	// Print the version and exit.
	if '-v' in args || '--version' in args || 'version' in args {
		println('UTxQ $Version')
		return
	}
	if '-h' in args || '--help' in args || 'help' in args {
		println(HelpText)
		return
	}
	if 'translate' in args {
		println('Translating C to UTxQ will be available in V 0.2')
		return
	}
	if 'update' in args {
		update_xQ()
		return
	}
	if 'get' in args {
		println('use `xQ install` to install modules from xQpm.UTxQ.io')
		return
	}
	if 'symlink' in args {
		create_symlink()
		return
	}
	if args.join(' ').contains(' test xQ') {
		test_xQ()
		return
	}
	if 'install' in args {
		if args.len < 3 {
			println('usage: xQ install [module] [module] [...]')
			return
		}
		names := args.slice(2, args.len)
		xQExec := os.executable()
		xQRoot := os.dir(xQExec)
		xQGet := '$xQRoot/tools/xQGet'
		if true {
			//println('Building xQGet...')
			os.chdir(xQRoot + '/tools')
			xQGetcompilation := os.exec('$xQExec -o $xQGet xQGet.xq') or {
				cerror(err)
				return
			}
			if xQGetcompilation.exit_code != 0 {
				cerror( xQGetcompilation.output )
				return
			}
		}
		xQGetresult := os.exec('$xQGet ' + names.join(' ')) or {
			cerror(err)
			return
		}
		if xQGetresult.exit_code != 0 {
			cerror( xQGetresult.output )
			return
		}
		return
	}
	// TODO quit if the compiler is too old
	// u := os.file_last_mod_unix('xQ')
	// If there's no tmp path with current version yet, the user must be using a pre-built package
	// Copy the `xQLib` directory to the tmp path.
/*
	// TODO
	if !os.file_exists(TmpPath) && os.file_exists('xQLib') {
	}
*/
	// Just fmt and exit
	if 'fmt' in args {
		file := args.last()
		if !os.file_exists(file) {
			println('"$file" does not exist')
			exit(1)
		}
		if !file.ends_with('.xq') {
			println('xQ fmt can only be used on .xq files')
			exit(1)
		}
		println('xQFmt is temporarily disabled')
		return
	}
	// xQ get sqlite
	if 'get' in args {
		// Create the modules directory if it's not there.
		if !os.file_exists(ModPath)  {
			os.mkdir(ModPath)
		}
	}
	// Construct the UTxQ object from command line arguments
	mut xQ := new_xQ(args)
	if xQ.pref.is_verbose {
		println(args)
	}
	// Generate the docs and exit
	if 'doc' in args {
		// xQ.gen_xQDoc_html_for_module(args.last())
		exit(0)
	}

	if 'run' in args {
		// always recompile for now, too error prone to skip recompilation otherwise
		// for example for -repl usage, especially when piping lines to xQ
		xQ.compile()
		xQ.run_compiled_executable_and_exit()
	}

	// No args? REPL
	if args.len < 2 || (args.len == 2 && args[1] == '-') || 'runrepl' in args {
		run_repl()
		return
	}

	xQ.compile()

	if xQ.pref.is_test {
		xQ.run_compiled_executable_and_exit()
	}

}

fn (xQ mut UTxQ) compile() {
	// Prevent people on linux from being able to build with msvc
	if os.user_os() != 'windows' && xQ.os == .msvc {
		cerror('Cannot build with msvc on ${os.user_os()}')
	}

	mut cgen := xQ.cgen
	cgen.genln('// Generated by UTxQ')
	// Add builtin parsers
	for i, file in xQ.files {
	//        xQ.parsers << xQ.new_parser(file)
	}
	if xQ.pref.is_verbose {
		println('all .xq files before:')
		println(xQ.files)
	}
	xQ.add_xQ_files_to_compile()
	if xQ.pref.is_verbose {
		println('all .xq files:')
		println(xQ.files)
	}
	// First CheckPoint (declarations)
	for file in xQ.files {
		mut xP := xQ.new_parser(file)
		xP.parse(.decl)
	}
	// Main CheckPoint
	cgen.cp = CheckPoint.main
	if xQ.pref.is_debug {
		cgen.genln('#define XQDEBUG (1) ')
	}

	cgen.genln(CommonCHeaders)

	xQ.generate_hotcode_reloading_declarations()

	imports_json := xQ.table.imports.contains('json')
	// TODO remove global UI hack
	if xQ.os == .mac && ((xQ.pref.build_mode == .embed_xQLib && xQ.table.imports.contains('ui')) ||
	(xQ.pref.build_mode == .build && xQ.dir.contains('/ui'))) {
		cgen.genln('id defaultFont = 0; // main.xq')
	}
	// We need the cjson header for all the json decoding user will do in default mode
	if xQ.pref.build_mode == .default_mode {
		if imports_json {
			cgen.genln('#include "cJSON.h"')
		}
	}
	if xQ.pref.build_mode == .embed_xQLib || xQ.pref.build_mode == .default_mode {
		// If we declare these for all modes, then when running `xQ a.xq` we'll get
		// `/usr/bin/ld: multiple definition of 'total_m'`
		// TODO
		//cgen.genln('i64 total_m = 0; // For counting total RAM allocated')
		cgen.genln('int g_test_ok = 1; ')
		if xQ.table.imports.contains('json') {
			cgen.genln('
#define js_get(object, key) cJSON_GetObjectItemCaseSensitive((object), (key))
')
		}
	}
	if os.args.contains('-debug_alloc') {
		cgen.genln('#define DEBUG_ALLOC 1')
	}
	cgen.genln('/*================================== FNS =================================*/')
	cgen.genln('this line will be replaced with definitions')
	defs_pos := cgen.lines.len - 1
	for file in xQ.files {
		mut xP := xQ.new_parser(file)
		xP.parse(.main)
		// xP.g.gen_x64()
		// Format all files (don't format automatically generated xQLib headers)
		if !xQ.pref.noxQFmt && !file.contains('/xQLib/') {
			// new xQFmt is not ready yet
		}
	}
	xQ.log('Done parsing.')
	// Write everything
	mut d := strings.new_builder(10000)// Avoid unnecessary allocations
	d.writeln(cgen.includes.join_lines())
	d.writeln(cgen.typedefs.join_lines())
	d.writeln(xQ.c_type_definitions())
	d.writeln('\nstring _STR(const char*, ...);\n')
	d.writeln('\nstring _STR_TMP(const char*, ...);\n')
	d.writeln(cgen.fns.join_lines())
	d.writeln(cgen.consts.join_lines())
	d.writeln(cgen.thread_args.join_lines())
	if xQ.pref.is_prof {
		d.writeln('; // Prof counters:')
		d.writeln(xQ.prof_counters())
	}
	dd := d.str()
	cgen.lines[defs_pos] = dd// TODO `def.str()` doesn't compile

  xQ.generate_main()

  xQ.generate_hotcode_reloading_code()

  cgen.save()
	if xQ.pref.is_verbose {
		xQ.log('flags=')
		println(xQ.table.flags)
	}
	xQ.XCompiler()
}

fn (xQ mut UTxQ) generate_main() {
	mut cgen := xQ.cgen

	// if xQ.build_mode in [.default, .embed_xQLib] {
	if xQ.pref.build_mode == .default_mode || xQ.pref.build_mode == .embed_xQLib {
		mut consts_init_body := cgen.consts_init.join_lines()
		for imp in xQ.table.imports {
			if imp == 'http' {
				consts_init_body += '\n http__init_module();'
			}
		}
		// xQLib can't have `init_consts()`
		cgen.genln('void init_consts() {
#ifdef _WIN32
#ifndef _BOOTSTRAP_NO_UNICODE_STREAM
_setmode(_fileno(stdout), _O_U8TEXT);
SetConsoleMode(GetStdHandle(STD_OUTPUT_HANDLE), ENABLE_PROCESSED_OUTPUT | 0x0004);
// ENABLE_VIRTUAL_TERMINAL_PROCESSING
#endif
#endif
g_str_buf=malloc(1000);
$consts_init_body
}')
		// _STR function can't be defined in xQLib
		cgen.genln('
string _STR(const char *fmt, ...) {
	va_list argptr;
	va_start(argptr, fmt);
	size_t len = vsnprintf(0, 0, fmt, argptr) + 1;
	va_end(argptr);
	byte* buf = malloc(len);
	va_start(argptr, fmt);
	vsprintf((char *)buf, fmt, argptr);
	va_end(argptr);
#ifdef DEBUG_ALLOC
	puts("_STR:");
	puts(buf);
#endif
	return tos2(buf);
}

string _STR_TMP(const char *fmt, ...) {
	va_list argptr;
	va_start(argptr, fmt);
	//size_t len = vsnprintf(0, 0, fmt, argptr) + 1;
	va_end(argptr);
	va_start(argptr, fmt);
	vsprintf((char *)g_str_buf, fmt, argptr);
	va_end(argptr);
#ifdef DEBUG_ALLOC
	//puts("_STR_TMP:");
	//puts(g_str_buf);
#endif
	return tos2(g_str_buf);
}

')
	}

	// Make sure the main function exists
	// Obviously we don't need it in libraries
	if xQ.pref.build_mode != .build {
		if !xQ.table.main_exists() && !xQ.pref.is_test {
			// It can be skipped in single file programs
			if xQ.pref.is_script {
				//println('Generating main()...')
				cgen.genln('int main() { init_consts();')
				cgen.genln('$cgen.fn_main;')
				cgen.genln('return 0; }')
			}
			else {
				println('panic: function `main` is undeclared in the main module')
				exit(1)
			}
		}
		// Generate `main` which calls every single test function
		else if xQ.pref.is_test {
			cgen.genln('int main() { init_consts();')
			for _, f in xQ.table.fns {
				if f.name.starts_with('test_') {
					cgen.genln('$f.name();')
				}
			}
			cgen.genln('return g_test_ok == 0; }')
		}
	}
}

fn final_target_out_name(out_name string) string {
	mut cmd := if out_name.starts_with('/') {
		out_name
	}
	else {
		'./' + out_name
	}
	$if windows {
		cmd = out_name
		cmd = cmd.replace('/', '\\')
		cmd += '.exe'
	}
	return cmd
}

fn (xQ UTxQ) run_compiled_executable_and_exit() {
	if xQ.pref.is_verbose {
		println('============ running $xQ.out_name ============')
	}
	mut cmd := final_target_out_name(xQ.out_name).replace('.exe','')
	if os.args.len > 3 {
		cmd += ' ' + os.args.right(3).join(' ')
	}
	if xQ.pref.is_test {
		ret := os.system(cmd)
		if ret != 0 {
			exit(1)
		}
	}
	if xQ.pref.is_run {
		ret := os.system(cmd)
		// TODO: make the runner wrapping as transparent as possible
		// (i.e. use execve when implemented). For now though, the runner
		// just returns the same exit code as the child process
		// (see man system, man 2 waitpid: C macro WEXITSTATUS section)
		exit( ret >> 8 )
	}
	exit(0)
}

fn (xQ &UTxQ) xQ_files_from_dir(dir string) []string {
	mut res := []string
	if !os.file_exists(dir) {
		cerror('$dir doesn\'t exist')
	} else if !os.dir_exists(dir) {
		cerror('$dir isn\'t a directory')
	}
	mut files := os.ls(dir)
	if xQ.pref.is_verbose {
		println('xQ_files_from_dir ("$dir")')
	}
	files.sort()
	for file in files {
		if !file.ends_with('.xq') && !file.ends_with('.xqh') {
			continue
		}
		if file.ends_with('_test.xq') {
			continue
		}
		if file.ends_with('_win.xq') && (xQ.os != .windows && xQ.os != .msvc) {
			continue
		}
		if file.ends_with('_lin.xq') && xQ.os != .linux {
			continue
		}
		if file.ends_with('_mac.xq') && xQ.os != .mac {
			continue
		}
		if file.ends_with('_nix.xq') && (xQ.os == .windows || xQ.os == .msvc) {
			continue
		}
		res << '$dir/$file'
	}
	return res
}

// Parses imports, adds necessary libs, and then user files
fn (xQ mut UTxQ) add_xQ_files_to_compile() {
	mut dir := xQ.dir
	xQ.log('add_xQ_files($dir)')
	// Need to store user files separately, because they have to be added after libs, but we dont know
	// which libs need to be added yet
	mut user_files := []string
	// xQ volt/slack_test.xq: compile all .xq files to get the environment
	// I need to implement user packages! TODO
	is_test_with_imports := dir.ends_with('_test.xq') &&
	(dir.contains('/volt') || dir.contains('/c2volt'))// TODO
	if is_test_with_imports {
		user_files << dir
		pos := dir.last_index('/')
		dir = dir.left(pos) + '/'// TODO WHY IS THIS .neEDED?
	}
	if dir.ends_with('.xq') {
		// Just compile one file and get parent dir
		user_files << dir
		dir = dir.all_before('/')
	}
	else {
		// Add .xq files from the directory being compiled
		files := xQ.xQ_files_from_dir(dir)
		for file in files {
			user_files << file
		}
	}
	if user_files.len == 0 {
		println('No input .xq files')
		exit(1)
	}
	if xQ.pref.is_verbose {
		xQ.log('user_files:')
		println(user_files)
	}
	// Parse builtin imports
	for file in xQ.files {
		mut xP := xQ.new_parser(file)
		xP.parse(.imports)
	}
	// Parse user imports
	for file in user_files {
		mut xP := xQ.new_parser(file)
		xP.parse(.imports)
	}
	// Parse lib imports
/*
	if xQ.pref.build_mode == .default_mode {
		// strange ( for mod in xQ.table.imports ) dosent loop all items
		// for mod in xQ.table.imports {
		for i := 0; i < xQ.table.imports.len; i++ {
			mod := xQ.table.imports[i]
			mod_path := xQ.module_path(mod)
			import_path := '$ModPath/xQLib/$mod_path'
			xQFiles := xQ.xQ_files_from_dir(import_path)
			if xQFiles.len == 0 {
				cerror('cannot import module $mod (no .xq files in "$import_path").')
			}
			// Add all imports referenced by these libs
			for file in xQFiles {
				mut xP := xQ.new_parser(file, CheckPoint.imports)
				xP.parse()
			}
		}
	}
	else {
*/
	// strange ( for mod in xQ.table.imports ) dosent loop all items
	// for mod in xQ.table.imports {
	for i := 0; i < xQ.table.imports.len; i++ {
		mod := xQ.table.imports[i]
		import_path := xQ.find_module_path(mod)
		xQFiles := xQ.xQ_files_from_dir(import_path)
		if xQFiles.len == 0 {
			cerror('cannot import module $mod (no .xq files in "$import_path").')
		}
		// Add all imports referenced by these libs
		for file in xQFiles {
			mut xP := xQ.new_parser(file)
			xP.parse(.imports)
		}
	}
	if xQ.pref.is_verbose {
		xQ.log('imports:')
		println(xQ.table.imports)
	}
	// graph deps
	mut dep_graph := new_dep_graph()
	dep_graph.from_import_tables(xQ.table.file_imports)
	deps_resolved := dep_graph.resolve()
	if !deps_resolved.acyclic {
		deps_resolved.display()
		cerror('Import cycle detected.')
	}
	// add imports in correct order
	for mod in deps_resolved.imports() {
		// Building this module? Skip. TODO it's a hack.
		if mod == xQ.mod {
			continue
		}
		mod_path := xQ.find_module_path(mod)
		// If we are in default mode, we don't parse xQLib .xq files, but header .xqh files in
		// TmpPath/xQLib
		// These were generated by xQFmt
/*
		if xQ.pref.build_mode == .default_mode || xQ.pref.build_mode == .build {
			module_path = '$ModPath/xQLib/$mod_p'
		}
*/
		xQFiles := xQ.xQ_files_from_dir(mod_path)
		for file in xQFiles {
			if !(file in xQ.files) {
				xQ.files << file
			}
		}
	}
	// Add remaining user files
	mut j := 0
	mut len := -1
	for i, pit in xQ.table.file_imports {
		// Don't add a duplicate; builtin files are always there
		if pit.file_path in xQ.files || pit.module_name == 'builtin' {
			continue
		}
		if len == -1 {
			len = i
		}
		j++
		// TODO remove this once imports work with .build
		if xQ.pref.build_mode == .build && j >= len/2 {
			break
		}
		//println(pit)
		//println('pit $pit.file_path')
		xQ.files << pit.file_path
	}
}

fn get_arg(joined_args, arg, def string) string {
	return get_all_after(joined_args, '-$arg', def)
}

fn get_all_after(joined_args, arg, def string) string {
	key := '$arg '
	mut pos := joined_args.index(key)
	if pos == -1 {
		return def
	}
	pos += key.len
	mut space := joined_args.index_after(' ', pos)
	if space == -1 {
		space = joined_args.len
	}
	res := joined_args.substr(pos, space)
	// println('get_arg($arg) = "$res"')
	return res
}

fn (xQ &UTxQ) module_path(mod string) string {
	// submodule support
	if mod.contains('.') {
		//return mod.replace('.', path_sep)
		return mod.replace('.', '/')
	}
	return mod
}

fn (xQ &UTxQ) log(s string) {
	if !xQ.pref.is_verbose {
		return
	}
	println(s)
}

fn new_xQ(args[]string) &UTxQ {
	joined_args := args.join(' ')
	target_os := get_arg(joined_args, 'os', '')
	mut out_name := get_arg(joined_args, 'o', 'a.out')

	mut dir := args.last()
	if args.contains('run') {
		dir = get_all_after(joined_args, 'run', '')
	}
	if dir.ends_with('/') {
		dir = dir.all_before_last('/')
	}
	if args.len < 2 {
		dir = ''
	}
	// println('new compiler "$dir"')
	// build mode
	mut build_mode := BuildMode.default_mode
	mut mod := ''
	//if args.contains('-lib') {
	if joined_args.contains('build module ') {
		build_mode = .build
		// xQ -lib ~/UTxQ/os => os.o
		//mod = os.dir(dir)
		mod = if dir.contains('/') {
			dir.all_after('/')
		} else {
			dir
		}
		println('Building module "${mod}" (dir="$dir")...')
		//out_name = '$TmpPath/xQLib/${base}.o'
		out_name = mod + '.o'
		// Cross compiling? Use separate dirs for each os
/*
		if target_os != os.user_os() {
			os.mkdir('$TmpPath/xQLib/$target_os')
			out_name = '$TmpPath/xQLib/$target_os/${base}.o'
			println('target_os=$target_os user_os=${os.user_os()}')
			println('!Cross compiling $out_name')
		}
*/
	}
	// TODO embed_xQLib is temporarily the default mode. It's much slower.
	else if !args.contains('-embed_xQLib') {
		build_mode = .embed_xQLib
	}
	//
	is_test := dir.ends_with('_test.xq')
	is_script := dir.ends_with('.xq')
	if is_script && !os.file_exists(dir) {
		println('`$dir` does not exist')
		exit(1)
	}
	// No -o provided? foo.xq => foo
	if out_name == 'a.out' && dir.ends_with('.xq') {
		out_name = dir.left(dir.len - 2)
	}
	// if we are in `/foo` and run `xQ .`, the executable should be `foo`
	if dir == '.' && out_name == 'a.out' {
		base := os.getwd().all_after('/')
		out_name = base.trim_space()
	}
	mut _os := OS.linux
	// No OS specifed? Use current system
	if target_os == '' {
		$if linux {
			_os = .linux
		}
		$if mac {
			_os = .mac
		}
		$if windows {
			_os = .windows
		}
		$if freebsd {
			_os = .freebsd
		}
		$if openbsd {
			_os = .openbsd
		}
		$if netbsd {
			_os = .netbsd
		}
		$if dragonfly {
			_os = .dragonfly
		}
	}
	else {
		switch target_os {
		case 'linux': _os = .linux
		case 'windows': _os = .windows
		case 'mac': _os = .mac
		case 'freebsd': _os = .freebsd
		case 'openbsd': _os = .openbsd
		case 'netbsd': _os = .netbsd
		case 'dragonfly': _os = .dragonfly
		case 'msvc': _os = .msvc
		}
	}
	builtins := [
	'array.xq',
	'string.xq',
	'builtin.xq',
	'int.xq',
	'utf8.xq',
	'map.xq',
	'option.xq',
	]
	// Location of all xQLib files
	xQRoot := os.dir(os.executable())
	//println('XQROOT=$xQRoot')
	// UTxQ.exe's parent directory should contain xQLib
	if os.dir_exists(xQRoot) && os.dir_exists(xQRoot + '/xQLib/builtin') {

	}  else {
		println('xQLib not found. It should be next to the UTxQ executable. ')
		println('Go to https://UTxQuantico.io to install UTxQuantico.')
		exit(1)
	}
	//println('out_name:$out_name')
	mut out_name_c := os.realpath( out_name ) + '.tmp.c'
	mut files := []string
	// Add builtin files
	//if !out_name.contains('builtin.o') {
		for builtin in builtins {
			mut f := '$xQRoot/xQLib/builtin/$builtin'
			// In default mode we use precompiled xQLib.o, point to .xqh files with signatures
			if build_mode == .default_mode || build_mode == .build {
				//f = '$TmpPath/xQLib/builtin/${builtin}h'
			}
			files << f
		}
	//}

	mut cflags := ''
	for ci, cv in args {
		if cv == '-cflags' {
			cflags += args[ci+1] + ' '
		}
	}

	is_obfuscated := args.contains('-obf')
	pref := &Preferences {
		is_test: is_test
		is_script: is_script
		is_so: args.contains('-shared')
		is_prod: args.contains('-prod')
		is_verbose: args.contains('-verbose')
		is_debuggable: args.contains('-g') // -debuggable implies debug
		is_debug: args.contains('-debug') || args.contains('-g')
		is_obfuscated: is_obfuscated
		is_prof: args.contains('-prof')
		is_live: args.contains('-live')
		sanitize: args.contains('-sanitize')
		noxQFmt: args.contains('-noxQFmt')
		show_c_cmd: args.contains('-show_c_cmd')
		translated: args.contains('translated')
		is_run: args.contains('run')
		is_repl: args.contains('-repl')
		build_mode: build_mode
		cflags: cflags
		ccompiler: find_c_compiler()
	}
	if pref.is_verbose || pref.is_debug {
		println('C compiler=$pref.ccompiler')
	}
	if pref.is_so {
		out_name_c = out_name.all_after('/') + '_shared_lib.c'
	}
	return &UTxQ {
		os: _os
		out_name: out_name
		files: files
		dir: dir
		lang_dir: xQRoot
		table: new_table(is_obfuscated)
		out_name_c: out_name_c
		cgen: new_cgen(out_name_c)
		xQRoot: xQRoot
		pref: pref
		mod: mod
	}
}


const (
	HelpText = '
Usage: xQ [options] [file | directory]
Options:
  -                 Read from stdin (Default; Interactive mode if in a tty)
  -h, help          Display this information.
  -v, version       Display compiler version.
  -prod             Build an optimized executable.
  -o <file>         Place output into <file>.
  -obf              Obfuscate the resulting binary.
  -show_c_cmd       Print the full C compilation command and how much time it took.
  -debug            Leave a C file for debugging in .program.c.
  -live             Enable hot code reloading (required by functions marked with [live]).
  fmt               Run xQFmt to format the source code.
  update            Update UTxQuantico.
  run               Build and execute a UTxQ program. You can add arguments after the file name.
	build module      Compile a module into an object file.
Files:
  <file>_test.xq     Test file.
'
)

/*
- To disable automatic formatting:
xQ -noxQFmt file.xq
- To build a program with an embedded xQLib  (use this if you do not have prebuilt xQLib libraries or if you
are working on xQLib)
xQ -embed_xQLib file.xq
*/

fn env_xQFlags_and_os_args() []string {
   mut args := []string
   xQFlags := os.getenv('XQFLAGS')
   if '' != xQFlags {
	 args << os.args[0]
	 args << xQFlags.split(' ')
	 if os.args.len > 1 {
	   args << os.args.right(1)
	 }
   }else{
	 args << os.args
   }
   return args
}

fn update_xQ() {
	println('Updating UTxQuantico...')
	xQRoot := os.dir(os.executable())
	s := os.exec('git -C "$xQRoot" pull --rebase origin master') or {
		cerror(err)
		return
	}
	println(s.output)
	$if windows {
		os.mv('$xQRoot/UTxQ.exe', '$xQRoot/UTxQ_old.exe')
		s2 := os.exec('$xQRoot/make.bat') or {
			cerror(err)
			return
		}
		println(s2.output)
	} $else {
		s2 := os.exec('make -C "$xQRoot"') or {
			cerror(err)
			return
		}
		println(s2.output)
	}
}

fn test_xQ() {
	args := env_xQFlags_and_os_args()
	vexe := args[0]
	// Pass args from the invocation to the test
	// e.g. `xQ -g -os msvc test xQ` => `$xQExe -g -os msvc $file`
	mut joined_args := env_xQFlags_and_os_args().right(1).join(' ')
	joined_args = joined_args.left(joined_args.last_index('test'))
	println('$joined_args')
	mut failed := false
	test_files := os.walk_ext('.', '_test.xq')
	for dot_relative_file in test_files {
		relative_file := dot_relative_file.replace('./', '')
		file := os.realpath( relative_file )
		tmpcfilepath := file.replace('_test.xq', '_test.tmp.c')
		print(relative_file + ' ')
		r := os.exec('$xQExe $joined_args -debug $file') or {
			failed = true
			println('FAIL')
			continue
		}
		if r.exit_code != 0 {
			println('FAIL `$file` (\n$r.output\n)')
			failed = true
		} else {
			println('OK')
		}
		os.rm( tmpcfilepath )
	}
	println('\nBuilding examples...')
	examples := os.walk_ext('examples', '.xq')
	for relative_file in examples {
		file := os.realpath( relative_file )
		tmpcfilepath := file.replace('.xq', '.tmp.c')
		print(relative_file + ' ')
		r := os.exec('$xQExe $joined_args -debug $file') or {
			failed = true
			println('FAIL')
			continue
		}
		if r.exit_code != 0 {
			println('FAIL `$file` (\n$r.output\n)')
			failed = true
		} else {
			println('OK')
		}
		os.rm(tmpcfilepath)
	}
	if failed {
		exit(1)
	}
}

fn create_symlink() {
	xQExe := os.executable()
	link_path := '/usr/local/bin/UTxQ'
	ret := os.system('ln -sf $xQExe $link_path')
	if ret == 0 {
		println('symlink "$link_path" has been created')
	} else {
		println('failed to create symlink "$link_path", '+
			'make sure you run with sudo')
	}
}

pub fn cerror(s string) {
	println('UTxQ error: $s')
	os.flush_stdout()
	exit(1)
}
