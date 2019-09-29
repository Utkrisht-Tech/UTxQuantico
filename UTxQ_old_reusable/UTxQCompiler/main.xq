// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import (
	os
	StringX
	BenchmarkX
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
	build_module
}

const (
	supported_platforms = ['linux' , 'windows', 'mac', 'freebsd', 'openbsd', 'netbsd', 'dragonfly', 'msvc', 'android', 'js', 'solaris']
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
	js
	android
	solaris
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
	os				OS // the OS to build for
	out_name_c		string // name of the temporary C file
	files			[]string // all UTxQ files that need to be parsed and compiled
	dir				string // directory (or file) being compiled (TODO rename to path?)
	table			&dataTable // table with types, vars, functions etc
	cgen			&CGen // C code generator
	pref			&Preferences // all the preferences and settings extracted to a struct for reusability
	lang_dir		string // "~/code/xQ"
	out_name		string // "program.exe"
	xQRoot			string
	mod				string  // module being built with -lib
	parsers			[]Parser
	xQGen_buf		StringX.Builder
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
	building_xQ	   bool
	autofree       bool
	compress	   bool
}

fn main() {
	// There's no `flags` module yet, so args have to be parsed manually
	args := env_xQFlags_and_os_args()
	// Print the version and exit.
	if '-v' in args || '--version' in args || 'version' in args {
		version_hash := verHash()
		println('UTxQuantico $Version $version_hash')
		return
	}
	if '-h' in args || '--help' in args || 'help' in args {
		println(HelpText)
		return
	}
	if 'translate' in args {
		println('Translating C to UTxQ will be available in v1.0')
		return
	}
	if 'update' in args {
		update_UTxQ()
		return
	}
	if 'get' in args {
		println('use `xQ install` to install modules from xQpm.UTxQ.io ')
		return
	}
	if 'symlink' in args {
		create_symlink()
		return
	}
	if 'install' in args {
		install_UTxQ(args)
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
		xQFmt(args)
		return
	}


	// Construct the UTxQ object from command line arguments
	mut xQ := new_xQ(args)
	if args.join(' ').contains(' test UTxQ') {
		xQ.test_UTxQ()
		return
	}
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

	// TODO remove
	if xQ.pref.autofree {
		println('Started freeing UTxQ struct')
		xQ.table.typesmap.free()
		xQ.table.obf_ids.free()
		xQ.cgen.lines.free()
		free(xQ.cgen)
		for _, f in xQ.table.fns {
			//f.local_vars.free()
			f.args.free()
			//f.defer_text.free()
		}	
		xQ.table.fns.free()
		free(xQ.table)
		//for p in parsers {

		//}
		println('done!')
	}
}

fn (xQ mut UTxQ) add_parser(parser Parser) {
       for xP in xQ.parsers {
               if xP.if == parser.id {
                       return
               }
       }
       xQ.parsers << parser
}

fn (xQ mut UTxQ) compile() {
	// Prevent people on linux from being able to build with msvc
	if os.user_os() != 'windows' && xQ.os == .msvc {
		xQError('Cannot build with msvc on ${os.user_os()}')
	}

	mut cgen := xQ.cgen
	cgen.genln('// Generated by UTxQ')
	if xQ.pref.is_verbose {
		println('all .xq files before:')
		println(xQ.files)
	}
	xQ.add_xQ_files_to_compile()
	if xQ.pref.is_verbose || xQ.pref.is_debug  {
		println('all .xq files:')
		println(xQ.files)
	}
	if xQ.pref.is_debug {
		println('\nParsers:')
		for p in xQ.parsers {
			println(p.file_name)
		}	
		println('\nFiles:')
		for f in xQ.files {
			println(f)
		}	
	}
	// First CheckPoint (declarations)
	for file in xQ.files {
		for i, p in xQ.parsers {
			if p.file_path == file {
				xQ.parsers[i].parse(.decl)
				break
			}
		}
	}
	// Main CheckPoint
	cgen.cp = CheckPoint.main
	if xQ.pref.is_debug {
		$if js {
			cgen.genln('const XQDEBUG = 1;\n')
		}	$else {
			cgen.genln('#define XQDEBUG (1)')
		}
	}
	if xQ.os == .js {
		cgen.genln('#define _XQJS (1) ')
	}

	if xQ.pref.building_xQ {
		cgen.genln('#ifndef UTXQ_COMMIT_HASH')
		cgen.genln('#define UTXQ_COMMIT_HASH "' + verHash() + '"')
		cgen.genln('#endif')
	}


	$if js {
		cgen.genln(js_headers)
	} $else {
		cgen.genln(CommonCHeaders)
	}

	xQ.generate_hotcode_reloading_declarations()

	imports_json := 'json' in xQ.table.imports
	// TODO remove global UI hack
	if xQ.os == .mac && ((xQ.pref.build_mode == .embed_xQLib && 'ui' in
		xQ.table.imports) || (xQ.pref.build_mode == .build_module &&
		xQ.dir.contains('/ui'))) {
		cgen.genln('id defaultFont = 0; // main.xq')
	}
	// We need the cjson header for all the json decoding that will be done in default mode
	if xQ.pref.build_mode == .default_mode {
		if imports_json {
			cgen.genln('#include "cJSON.h"')
		}
	}
	if xQ.pref.build_mode == .embed_xQLib || xQ.pref.build_mode == .default_mode {
	//if xP.pref.build_mode in [.embed_xQLib, .default_mode] {
		// If we declare these for all modes, then when running `xQ a.xq` we'll get
		// `/usr/bin/ld: multiple definition of 'total_m'`
		// TODO
		//cgen.genln('i64 total_m = 0; // For counting total RAM allocated')
		//if xQ.pref.is_test {
			cgen.genln('int g_test_ok = 1; ')
		//}
		if imports_json {
			cgen.genln('
#define js_get(object, key) cJSON_GetObjectItemCaseSensitive((object), (key))
')
		}
	}
	if '-debug_alloc' in os.args {
		cgen.genln('#define DEBUG_ALLOC 1')
	}
	//cgen.genln('/*================================== FNS =================================*/')
	cgen.genln('this line will be replaced with definitions')
	defs_pos := cgen.lines.len - 1
	for file in xQ.files {
		for i, p in xQ.parsers {
			if p.file_path == file {
				xQ.parsers[i].parse(.main)
				break
			}
		}
		//if xP.pref.autofree {		xP.scanner.text.free()		free(xP.scanner)	}
		// xP.g.gen_x64()
		// Format all files (don't format automatically generated xQLib headers)
		if !xQ.pref.noxQFmt && !file.contains('/xQLib/') {
			// new xQFmt is not ready yet
		}
	}
	// Parse generated UTxQ code (str() methods etc)
	mut xQGen_parser := xQ.new_parser_string_id(xQ.xQGen_buf.str(), 'xQGen')
	// Free the String Builder which held the generated methods
	xQ.xQGen_buf.free()
	xQGen_parser.parse(.main)
	xQ.log('Done parsing.')
	// Write everything
	mut d := StringX.new_builder(10000)// Avoid unnecessary allocations
	$if !js {
		d.writeln(cgen.includes.join_lines())
		d.writeln(cgen.typedefs.join_lines())
		d.writeln(xQ.type_definitions())
		d.writeln('\nstring _STR(const char*, ...);\n')
		d.writeln('\nstring _STR_TMP(const char*, ...);\n')
		d.writeln(cgen.fns.join_lines()) // fn definitions
	} $else {
		d.writeln(xQ.type_definitions())
	}
	d.writeln(cgen.consts.join_lines())
	d.writeln(cgen.thread_args.join_lines())
	if xQ.pref.is_prof {
		d.writeln('; // Prof counters:')
		d.writeln(xQ.prof_counters())
	}
	cgen.lines[defs_pos] = d.str()
	xQ.generate_main()
	xQ.generate_code_for_hot_reloading()
	if xQ.pref.is_verbose {
		xQ.log('flags=')
		for flag in xQ.get_os_cflags() {
			println(' * ' + flag.format())
		}
	}
	$if js {
		cgen.genln('main();')
	}	
	cgen.save()
	xQ.XCompiler()
}

fn (xQ mut UTxQ) generate_main() {
	mut cgen := xQ.cgen
	$if js { return }

	// if xQ.build_mode in [.default, .embed_xQLib] {
	if xQ.pref.build_mode == .default_mode || xQ.pref.build_mode == .embed_xQLib {
		mut consts_init_body := cgen.consts_init.join_lines()
		// xQLib can't have `init_consts()`
		cgen.genln('void init_consts() {
#ifdef _WIN32
DWORD consoleMode;
BOOL isConsole = GetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), &consoleMode);
int mode = isConsole ? _O_U16TEXT : _O_U8TEXT;
_setmode(_fileno(stdin), mode);
_setmode(_fileno(stdout), _O_U8TEXT);
SetConsoleMode(GetStdHandle(STD_OUTPUT_HANDLE), ENABLE_PROCESSED_OUTPUT | 0x0004);
// ENABLE_VIRTUAL_TERMINAL_PROCESSING
setbuf(stdout,0);
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
	if xQ.pref.build_mode != .build_module {
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
		else if xQ.pref.is_test {
			if xQ.table.main_exists() {
				xQError('Test files cannot have function `main`')
			}	
			// Make sure there's at least on test function
			if !xQ.table.has_at_least_one_test_fn() {
				xQError('Test files need to have at least one test function')
			}	
			// Generate `main` which calls every single test function
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
	mut cmd := '"' + final_target_out_name(xQ.out_name).replace('.exe','') + '"'
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
		xQError('$dir doesn\'t exist')
	} else if !os.dir_exists(dir) {
		xQError('$dir isn\'t a directory')
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
		if file.ends_with('_js.xq') {
			continue
		}
		if file.ends_with('_nix.xq') && (xQ.os == .windows || xQ.os == .msvc) {
			continue
		}
		if file.ends_with('_js.xq') && xQ.os != .js {
			continue
		}
		if file.ends_with('_c.xq') && xQ.os == .js {
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
		mut xP := xQ.new_parser_file(file)
		xP.parse(.imports)
		//if xP.pref.autofree {		xP.scanner.text.free()		free(xP.scanner)	}
	}
	// Parse user imports
	for file in user_files {
		mut xP := xQ.new_parser_file(file)
		xP.parse(.imports)
		//if xP.pref.autofree {		xP.scanner.text.free()		free(xP.scanner)	}
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
				xQError('cannot import module $mod (no .xq files in "$import_path")')
			}
			// Add all imports referenced by these libs
			for file in xQFiles {
				mut xP := xQ.new_parser_file(file, CheckPoint.imports)
				xP.parse()
				if xP.pref.autofree {		xP.scanner.text.free()		free(xP.scanner)	}
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
			xQError('cannot import module $mod (no .xq files in "$import_path")')
		}
		// Add all imports referenced by these libs
		for file in xQFiles {
			mut xP := xQ.new_parser_file(file)
			xP.parse(.imports)
			//if xP.pref.autofree {		xP.scanner.text.free()		free(xP.scanner)	}
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
		xQError('Import cycle detected')
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
		if xQ.pref.build_mode == .default_mode || xQ.pref.build_mode == .build_module {
			module_path = '$ModPath/xQLib/$mod_p'
		}
*/
		if mod == 'builtin' { continue } // builtin files were already added
		xQFiles := xQ.xQ_files_from_dir(mod_path)
		for file in xQFiles {
			if !(file in xQ.files) {
				xQ.files << file
			}
		}
	}
	// Add remaining user files
	mut i := 0
	mut j := 0
	mut len := -1
	for _, pit in xQ.table.file_imports {
		// Don't add a duplicate; builtin files are always there
		if pit.file_path in xQ.files || pit.module_name == 'builtin' {
			i++
			continue
		}
		if len == -1 {
			len = i
		}
		j++
		// TODO remove this once imports work with .build_module
		if xQ.pref.build_mode == .build_module && j >= len/2 {
			break
		}
		//println(pit)
		//println('pit $pit.file_path')
		xQ.files << pit.file_path
		i++
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
		//return mod.replace('.', os.PathSeparator)
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
	mut xQGen_buf := StringX.new_builder(1000)
	xQGen_buf.writeln('module main\nimport StringX')

	joined_args := args.join(' ')
	target_os := get_arg(joined_args, 'os', '')
	mut out_name := get_arg(joined_args, 'o', 'a.out')

	mut dir := args.last()
	if 'run' in args {
		dir = get_all_after(joined_args, 'run', '')
	}
	if dir.ends_with(os.PathSeparator) {
		dir = dir.all_before_last(os.PathSeparator)
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
		build_mode = .build_module
		// xQ build module ~/UTxQ/os => os.o
		//mod = os.dir(dir)
		mod = if dir.contains(os.PathSeparator) {
			dir.all_after(os.PathSeparator)
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
	else if !('-embed_xQLib' in args) {
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
		base := os.getwd().all_after(os.PathSeparator)
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
		$if solaris {
			_os = .solaris
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
		case 'js': _os = .js
		case 'solaris': _os = .solaris
		}
	}
	//println('OS=$_os')
	builtin := 'builtin.xq'
	builtins := [
	'array.xq',
	'string.xq',
	'builtin.xq',
	'int.xq',
	'utf8.xq',
	'map.xq',
	'option.xq',
	]
	//println(builtins)
	// Location of all xQLib files
	xQRoot := os.dir(os.executable())
	//println('XQROOT=$xQRoot')
	// UTxQ.exe's parent directory should contain xQLib
	if !os.dir_exists(xQRoot) || !os.dir_exists(xQRoot + '/xQLib/builtin') {
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
			__ := 1
			$if js {
				f = '$xQRoot/xQLib/builtin/js/$builtin'
			}
			// In default mode we use precompiled xQLib.o, point to .xqh files with signatures
			if build_mode == .default_mode || build_mode == .build_module {
				//f = '$TmpPath/xQLib/builtin/${builtin}h'
			}
			files << f
		}

	cflags := get_cmdline_cflags(args)

	rdir := os.realpath( dir )
	rdir_name := os.filename( rdir )

	is_obfuscated := '-obf' in args
	is_repl := '-repl' in args
	pref := &Preferences {
		is_test: is_test
		is_script: is_script
		is_so: '-shared' in args
		is_prod: '-prod' in args
		is_verbose: '-verbose' in args || '--verbose' in args
		is_debuggable: '-g' in args
		is_debug: '-debug' in args || '-g' in args
		is_obfuscated: is_obfuscated
		is_prof: '-prof' in args
		is_live: '-live' in args
		sanitize: '-sanitize' in args
		noxQFmt: '-noxQFmt' in args
		show_c_cmd: '-show_c_cmd' in args
		translated: 'translated' in args
		is_run: 'run' in args
		autofree: '-autofree' in args
		compress: '-compress' in args
		is_repl: is_repl
		build_mode: build_mode
		cflags: cflags
		ccompiler: find_c_compiler()
		building_xQ: !is_repl && (rdir_name == 'UTxQCompiler'  || dir.contains('xQLib'))
	}
	if pref.is_verbose || pref.is_debug {
		println('C compiler=$pref.ccompiler')
	}
	if pref.is_so {
		out_name_c = out_name.all_after(os.PathSeparator) + '_shared_lib.c'
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
		xQGen_buf: xQGen_buf
	}
}

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

fn update_UTxQ() {
	println('Updating UTxQuantico...')
	xQRoot := os.dir(os.executable())
	s := os.exec('git -C "$xQRoot" pull --rebase origin master') or {
		xQError(err)
		return
	}
	println(s.output)
	$if windows {
		xQ_backup_file := '$xQRoot/UTxQ_old.exe'
		if os.file_exists( xQ_backup_file ) {
			os.rm( xQ_backup_file )
		}
		os.mv('$xQRoot/UTxQ.exe', xQ_backup_file)
		s2 := os.exec('"$xQRoot/make.bat"') or {
			xQError(err)
			return
		}
		println(s2.output)
	} $else {
		s2 := os.exec('make -C "$xQRoot"') or {
			xQError(err)
			return
		}
		println(s2.output)
	}
}

fn xQFmt(args[]string) {
	file := args.last()
	if !os.file_exists(file) {
		println('"$file" does not exist')
		exit(1)
	}
	if !file.ends_with('.xq') {
		println('xQFmt can only be used on .xq files')
		exit(1)
	}
	println('xQFmt is temporarily disabled')
}

fn install_UTxQ(args[]string) {
	if args.len < 3 {
		println('usage: xQ install [module] [module] [...]')
		return
	}
	names := args.slice(2, args.len)
	xQExec := os.executable()
	xQRoot := os.dir(xQExec)
	xQGet := '$xQRoot/xQTools/xQGet'
	if true {
		//println('Building xQGet...')
		os.chdir(xQRoot + '/xQTools')
		xQGetcompilation := os.exec('$xQExec -o $xQGet xQGet.xq') or {
			xQError(err)
			return
		}
		if xQGetcompilation.exit_code != 0 {
			xQError( xQGetcompilation.output )
			return
		}
	}
	xQGetresult := os.exec('$xQGet ' + names.join(' ')) or {
		xQError(err)
		return
	}
	if xQGetresult.exit_code != 0 {
		xQError( xQGetresult.output )
		return
	}
}

fn (xQ &UTxQ) test_UTxQ() {
	if !os.dir_exists('xQLib') {
		println('run "xQ test UTxQ" next to the xQLib/ directory')
		exit(1)
	}
	args := env_xQFlags_and_os_args()
	vexe := args[0]
	// Pass args from the invocation to the test
	// e.g. `xQ -g -os msvc test xQ` => `$xQExe -g -os msvc $file`
	mut joined_args := args.right(1).join(' ')
	joined_args = joined_args.left(joined_args.last_index('test'))
	//	println('$joined_args')
	mut failed := false
	test_files := os.walk_ext('.', '_test.xq')

	println('Testing...')
	mut tmark := BenchmarkX.new_BenchmarkX()
	for dot_relative_file in test_files {	
		relative_file := dot_relative_file.replace('./', '')
		file := os.realpath( relative_file )
		tmpcfilepath := file.replace('_test.xq', '_test.tmp.c')

		mut cmd := '"$xQExe" $joined_args -debug "$file"'
		if os.user_os() == 'windows' { cmd = '"$cmd"' }
		
		tmark.step()
		r := os.exec(cmd) or {
			tmark.fail()
			failed = true
			println(tmark.step_message('$relative_file FAIL'))
			continue
		}
		if r.exit_code != 0 {
			failed = true
			tmark.fail()
			println(tmark.step_message('$relative_file FAIL \n`$file`\n (\n$r.output\n)'))
		} else {
			tmark.ok()
			println(tmark.step_message('$relative_file OK'))
		}
		os.rm( tmpcfilepath )
	}
	tmark.stop()
	println( tmark.total_message('running UTxQ tests'))

	println('\nBuilding examples...')
	examples := os.walk_ext('examples', '.xq')
	mut bmark := BenchmarkX.new_BenchmarkX()
	for relative_file in examples {
		file := os.realpath( relative_file )
		tmpcfilepath := file.replace('.xq', '.tmp.c')
		mut cmd := '"$xQExe" $joined_args -debug "$file"'
		if os.user_os() == 'windows' { cmd = '"$cmd"' }
		bmark.step()
		r := os.exec(cmd) or {
			failed = true
			bmark.fail()
			println(bmark.step_message('$relative_file FAIL'))
			continue
		}
		if r.exit_code != 0 {
			failed = true
			bmark.fail()
			println(bmark.step_message('$relative_file FAIL \n`$file`\n (\n$r.output\n)'))
		} else {
			bmark.ok()
			println(bmark.step_message('$relative_file OK'))
		}
		os.rm(tmpcfilepath)
	}
	bmark.stop()
	println( bmark.total_message('Building Examples'))

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

public fn xQError(s string) {
	println('UTxQ error: $s')
	os.flush_stdout()
	exit(1)
}

fn verHash() string {
	mut buf := [50]byte
	buf[0] = 0
	C.snprintf(*char(buf), 50, '%s', C.UTXQ_COMMIT_HASH )
	return tos_clone(buf)
}