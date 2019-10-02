// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import (
	os
	time
)

fn (xQ mut UTxQ) XCompiler() {
	// build any thirdParty obj files
	xQ.build_thirdParty_obj_files()
	
	// Just create a C/JavaScript file and exit
	if xQ.out_name.ends_with('.c') || xQ.out_name.ends_with('.js') {
		// Translating UTxQ code to JS by launching xQJS
		$if !js {
			if xQ.out_name.ends_with('.js') {
				xQExe := os.executable()
				xQJS_path := xQExe + 'js'
				dir := os.dir(xQExe)
				if !os.file_exists(xQJS_path) {
					println('xQJS.js compiler not found, building...')
					ret := os.system('$xQExe -o $xQJS_path -os js $dir/UTxQCompiler')
					if ret == 0 {
						println('Done.')
					} else {
						println('Failed.')
						exit(1)
					}	
				}	
				ret := os.system('$xQJS_path -o $xQ.out_name $xQ.dir')
				if ret == 0 {
					println('Done! Run it with `node $xQ.out_name`')
					println('JS backend is at a very early stage.')
				}	
			}
		}
		os.mv(xQ.out_name_c, xQ.out_name)
		exit(0)
	}
	// Cross compiling for Windows
	if xQ.os == .windows {
		$if !windows {
			xQ.XCompiler_windows_cross()
			return
		}
	}
	$if windows {
		if xQ.os == .msvc {
			xQ.XCompiler_msvc()
			return
		}
	}

	//linux_host := os.user_os() == 'linux'
	xQ.log('XCompiler() isprod=$xQ.pref.is_prod outname=$xQ.out_name')
	mut a := [xQ.pref.cflags, '-std=gnu11', '-w'] // arguments for the C compiler

	if xQ.pref.is_so {
		a << '-shared -fPIC '// -Wl,-z,defs'
		xQ.out_name = xQ.out_name + '.so'
	}
	if xQ.pref.build_mode == .build_module {
		// Create the modules directory if it's not there.
		if !os.file_exists(ModPath)  {
			os.mkdir(ModPath)
		}
		xQ.out_name = ModPath + xQ.dir + '.o' //xQ.out_name
		println('Building ${xQ.out_name}...')
	}

	mut debug_options := '-g'
	mut optimization_options := '-O2'
	if xQ.pref.ccompiler.contains('clang') {
		if xQ.pref.is_debug {
			debug_options = '-g -O0'
		}
		optimization_options = '-O3 -flto'
	}
	if xQ.pref.ccompiler.contains('gcc') {
		if xQ.pref.is_debug {
			debug_options = '-g3'
		}
		optimization_options = '-O3 -fno-strict-aliasing -flto'
	}
	if xQ.pref.is_prod {
		a << optimization_options
	}
	else {
		a << debug_options
	}

	if xQ.pref.is_debug && os.user_os() != 'windows'{
		a << ' -rdynamic ' // needed for nicer symbolic backtraces
	}

	if xQ.os != .msvc && xQ.os != .freebsd {
		a << '-Werror=implicit-function-declaration'
	}

	for f in xQ.generate_UTxQCompiler_flags_for_hotcode_reloading() {
		a << f
	}

	mut libs := ''// builtin.o os.o http.o etc
	if xQ.pref.build_mode == .build_module {
		a << '-c'
	}
	else if xQ.pref.build_mode == .embed_xQLib {
		//
	}
	else if xQ.pref.build_mode == .default_mode {
		libs = '$ModPath/xQLib/builtin.o'
		if !os.file_exists(libs) {
			println('object file `$libs` not found')
			exit(1)
		}
		for imp in xQ.table.imports {
			if imp == 'WebXview' {
				continue
			}
			libs += ' "$ModPath/xQLib/${imp}.o"'
		}
	}
	if xQ.pref.sanitize {
		a << '-fsanitize=leak'
	}
	// Cross compiling linux TODO
	/*
	sysroot := '$ModPath/XCompiling_sysroot/'
	if xQ.os == .linux && !linux_host {
		// Build file.o
		a << '-c --sysroot=$sysroot -target x86_64-linux-gnu'
		// Right now `out_name` can be `file`, not `file.o`
		if !xQ.out_name.ends_with('.o') {
			xQ.out_name = xQ.out_name + '.o'
		}
	}
	*/
	// Cross compiling windows
	//
	// Output executable name
	a << '-o "$xQ.out_name"'
	if os.dir_exists(xQ.out_name) {
		xQError('\'$xQ.out_name\' is a directory')
	}
	// macOS code can include objective C  TODO remove once objective C is replaced with C
	if xQ.os == .mac {
		a << '-x objective-c'
	}
	// The C file we are compiling
	a << '"$xQ.out_name_c"'
	if xQ.os == .mac {
		a << '-x none'
	}
	// Min macos version is mandatory I think?
	if xQ.os == .mac {
		a << '-mmacosx-version-min=10.7'
	}
	cflags := xQ.get_os_cflags()

	// Add .o files
	a << cflags.c_options_only_object_files()

	// Add all flags (-I -l -L etc) not .o files
	a << cflags.c_options_without_object_files()
	
	a << libs
	// Without these libs compilation will fail on Linux
	// || os.user_os() == 'linux'
	if xQ.pref.build_mode != .build_module && (xQ.os == .linux || xQ.os == .freebsd || xQ.os == .openbsd ||
		xQ.os == .netbsd || xQ.os == .dragonfly || xQ.os == .solaris) {
		a << '-lm -lpthread '
		// -ldl is a Linux only thing. BSDs have it in libc.
		if xQ.os == .linux {
			a << ' -ldl '
		}
	}

	if xQ.os == .js && os.user_os() == 'linux' {
		a << '-lm'
	}

	args := a.join(' ')
	cmd := '${xQ.pref.ccompiler} $args'
	// Run
	if xQ.pref.show_c_cmd || xQ.pref.is_verbose {
		println('\n==========')
		println(cmd)
	}
	ticks := time.ticks()
	res := os.exec(cmd) or { xQError(err) return }
	if res.exit_code != 0 {

		if res.exit_code == 127 {
			// the command could not be found by the system
			xQError('C compiler error, while attempting to run: \n' +
				'-----------------------------------------------------------\n' +
				'$cmd\n' +
				'-----------------------------------------------------------\n' +
				'Probably your C compiler is missing. \n' +
				'Please reinstall it, or make it available in your PATH.')
		}

		if xQ.pref.is_debug {
			println(res.output)
		} else {
			partial_output := res.output.limit(200).trim_right('\r\n')
			print(partial_output)
			if res.output.len > partial_output.len {
				println('...\n(Use `xQ -debug` to print the entire error message)\n')
			}else{
				println('')
			}
		}
		xQError('C error. This should never happen. ' +
			'Please create a GitHub issue: https://github.com/Utkrisht-Tech/UTxQuantico/issues/new/choose')
	}
	diff := time.ticks() - ticks
	// Print the C command
	if xQ.pref.show_c_cmd || xQ.pref.is_verbose {
		println('${xQ.pref.ccompiler} took $diff ms')
		println('=========\n')
	}
	// Link it if we are cross compiling and need an executable
	/*
	if xQ.os == .linux && !linux_host && xQ.pref.build_mode != .build_module {
		xQ.out_name = xQ.out_name.replace('.o', '')
		obj_file := xQ.out_name + '.o'
		println('linux obj_file=$obj_file out_name=$xQ.out_name')
		ress := os.exec('/usr/local/Cellar/llvm/8.0.0/bin/ld.lld --sysroot=$sysroot ' +
		'-v -o $xQ.out_name ' +
		'-m elf_x86_64 -dynamic-linker /lib64/ld-linux-x86-64.so.2 ' +
		'/usr/lib/x86_64-linux-gnu/crt1.o ' +
		'$sysroot/lib/x86_64-linux-gnu/libm-2.28.a ' +
		'/usr/lib/x86_64-linux-gnu/crti.o ' +
		obj_file +
		' /usr/lib/x86_64-linux-gnu/libc.so ' +
		'/usr/lib/x86_64-linux-gnu/crtn.o') or {
			xQError(err)
			return
		}
		println(ress.output)
		println('linux cross compilation done. resulting binary: "$xQ.out_name"')
	}
	*/
	if !xQ.pref.is_debug && xQ.out_name_c != 'UTxQ.c' && xQ.out_name_c != 'UTxQ_macos.c' {
		os.rm(xQ.out_name_c)
	}
	if xQ.pref.compress {
		$if windows {
			println('-compress does not work on Windows for now')
			return
		}
		ret := os.system('strip $xQ.out_name')
		if ret != 0 {
			println('strip failed')
			return
		}
		ret2 := os.system('upx --lzma -qqq $xQ.out_name')
		if ret2 != 0 {
			println('upx failed')
			$if mac {
				println('Install upx with `brew install upx`')
			}	
			$if linux {
				println('install upx\n' +
					'for example, on Debian/Ubuntu run `sudo apt install upx`')
			}	
			$if windows {
				// :)
			}	
		}
	}
}


fn (c mut UTxQ) XCompiler_windows_cross() {
	if !c.out_name.ends_with('.exe') {
		c.out_name = c.out_name + '.exe'
	}
	mut args := '-o $c.out_name -w -L. '
	cflags := c.get_os_cflags()
	// -I flags
	args += cflags.c_options_before_target()
	mut libs := ''
	if c.pref.build_mode == .default_mode {
		libs = '"$ModPath/xQLib/builtin.o"'
		if !os.file_exists(libs) {
				println('`$libs` not found')
				exit(1)
		}
		for imp in c.table.imports {
				libs += ' "$ModPath/xQLib/${imp}.o"'
		}
	}
	args += ' $c.out_name_c '
	args += cflags.c_options_after_target()
	println('Cross compiling for Windows...')
	winroot := '$ModPath/XCompiler_winroot'
	if !os.dir_exists(winroot) {
		winroot_url := 'https://github.com/Utkrisht-Tech/UTxQuantico/releases/download/v0.1.10/winroot.zip'
		println('"$winroot" not found.')
		println('Download it from $winroot_url and save it in $ModPath')
		println('Unzip it afterwards.\n')
		println('winroot.zip contains all library and header files needed '+'to cross-compile for Windows.')
		exit(1)
	}
	mut obj_name := c.out_name
	obj_name = obj_name.replace('.exe', '')
	obj_name = obj_name.replace('.o.o', '.o')
	include := '-I $winroot/include '
	cmd := 'clang -o $obj_name -w $include -m32 -c -target x86_64-win32 $ModPath/$c.out_name_c'
	if c.pref.show_c_cmd {
			println(cmd)
	}
	if os.system(cmd) != 0 {
		println('Cross compilation for Windows failed. Make sure you have clang installed.')
		exit(1)
	}
	if c.pref.build_mode != .build_module {
		link_cmd := 'lld-link $obj_name $winroot/lib/libcmt.lib ' +
		'$winroot/lib/libucrt.lib $winroot/lib/kernel32.lib $winroot/lib/libvcruntime.lib ' +
		'$winroot/lib/uuid.lib'
		if c.pref.show_c_cmd {
			println(link_cmd)
		}

		if os.system(link_cmd)  != 0 {
			println('Cross compilation for Windows failed. Make sure you have lld linker installed.')
			exit(1)
		}
		// os.rm(obj_name)
	}
	println('Done!')
}


fn (c &UTxQ) build_thirdParty_obj_files() {
	for flag in c.get_os_cflags() {
		if flag.value.ends_with('.o') {
			rest_of_module_flags := c.get_rest_of_module_cflags( flag )
			if c.os == .msvc {
				build_thirdParty_obj_file_with_msvc(flag.value, rest_of_module_flags)
			}
			else {
				build_thirdParty_obj_file(flag.value, rest_of_module_flags)
			}
		}
	}
}

fn find_c_compiler() string {
	args := env_xQFlags_and_os_args().join(' ')
	defaultcc := find_c_compiler_default()
	return get_arg( args, 'cc', defaultcc )
}

fn find_c_compiler_default() string {
	//fast_clang := '/usr/local/Cellar/llvm/8.0.0/bin/clang'
	//if os.file_exists(fast_clang) {
	//	return fast_clang
	//}
	// TODO fix $if after 'string'
	$if windows {	return 'gcc' }
	return 'cc'
}

fn find_c_compiler_thirdParty_options() string {
	fullargs := env_xQFlags_and_os_args()
	mut cflags := get_cmdline_cflags( fullargs )
	$if !windows {
		cflags += ' -fPIC'
	}
	if '-m32' in fullargs {
		cflags += ' -m32'
	}
	return cflags
}

fn get_cmdline_cflags(args []string) string {
	mut cflags := ''
	for ci, cxQ in args {
		if cxQ == '-cflags' {
			cflags += args[ci+1] + ' '
		}
	}
	return cflags
}