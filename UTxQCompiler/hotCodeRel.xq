// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import os

fn (xQ mut UTxQ) generate_UTxQCompiler_flags_for_hotcode_reloading() []string {
  mut a := []string
	if xQ.pref.is_live || xQ.pref.is_so {
		// See 'man dlopen', and test running a GUI program compiled with -live
		if (xQ.os == .linux || os.user_os() == 'linux'){
			a << '-rdynamic'
		}
		if (xQ.os == .mac || os.user_os() == 'mac'){
			a << '-flat_namespace'
		}
	}
  return a
}

fn (xQ mut UTxQ) generate_declarations_for_hotcode_reloading() {
  mut cgen := xQ.cgen
	if xQ.os != .windows && xQ.os != .msvc {
		if xQ.pref.is_so {
			cgen.genln('pthread_mutex_t live_fn_mutex;')
		}
		if xQ.pref.is_live {
			cgen.genln('pthread_mutex_t live_fn_mutex = PTHREAD_MUTEX_INITIALIZER;')
		}
	} else {
		if xQ.pref.is_so {
			cgen.genln('HANDLE live_fn_mutex;')
		}
		if xQ.pref.is_live {
			cgen.genln('HANDLE live_fn_mutex = 0;')
		}
	}
}

fn (xQ mut UTxQ) generate_code_for_hotcode_reloading() {
  mut cgen := xQ.cgen

	// Hot code reloading
	if xQ.pref.is_live {
		file := xQ.dir
		file_base := xQ.dir.replace('.xq', '')
		so_name := file_base + '.so'
		// Need to build .so file before building the live application
		// The live app needs to load this .so file on initialization.
		mut xQExe := os.args[0]

		if os.user_os() == 'windows' {
			xQExe = xQExe.replace('\\', '\\\\')
		}

		mut msvc := ''
		if xQ.os == .msvc {
			msvc = '-os msvc'
		}

		mut debug := ''

		if xQ.pref.is_debug {
			debug = '-debug'
		}

		os.system('$xQExe $msvc $debug -o $file_base -shared $file')
		cgen.genln('

void lfnmutex_print(char *s){
	if(0){
		fflush(stderr);
		fprintf(stderr,">> live_fn_mutex: %p | %s\\n", &live_fn_mutex, s);
		fflush(stderr);
	}
}
')

		if xQ.os != .windows && xQ.os != .msvc {
			cgen.genln('
#include <dlfcn.h>
void* live_lib=0;
int load_so(byteptr path) {
	char cpath[1024];
	sprintf(cpath,"./%s", path);
	//printf("load_so %s\\n", cpath);
	if (live_lib) dlclose(live_lib);
	live_lib = dlopen(cpath, RTLD_LAZY);
	if (!live_lib) {
		puts("open failed");
		exit(1);
		return 0;
	}
')
			for so_fn in cgen.so_fns {
				cgen.genln('$so_fn = dlsym(live_lib, "$so_fn");  ')
			}
		}
		else {
			cgen.genln('
void* live_lib=0;
int load_so(byteptr path) {
	char cpath[1024];
	sprintf(cpath, "./%s", path);
	if (live_lib) FreeLibrary(live_lib);
	live_lib = LoadLibraryA(cpath);
	if (!live_lib) {
		puts("open failed");
		exit(1);
		return 0;
	}
')

			for so_fn in cgen.so_fns {
				cgen.genln('$so_fn = (void *)GetProcAddress(live_lib, "$so_fn");  ')
			}
		}

		cgen.genln('return 1;
}

int _live_reloads = 0;
void reload_so() {
	char new_so_base[1024];
	char new_so_name[1024];
	char compile_cmd[1024];
	int last = os__file_last_mod_unix(tos2("$file"));
	while (1) {
		// TODO use inotify
		int now = os__file_last_mod_unix(tos2("$file"));
		if (now != last) {
			last = now;
			_live_reloads++;

			//xQ -o elastic_collision -shared elastic_collision.xq
			sprintf(new_so_base, ".tmp.%d.${file_base}", _live_reloads);
			#ifdef _WIN32
			// We have to make this directory becuase windows WILL NOT
			// do it for us
			os__mkdir(string_all_before_last(tos2(new_so_base), tos2("/")));
			#endif
			#ifdef _MSC_VER
			sprintf(new_so_name, "%s.dll", new_so_base);
			#else
			sprintf(new_so_name, "%s.so", new_so_base);
			#endif
			sprintf(compile_cmd, "$xQExe $msvc -o %s -shared $file", new_so_base);
			os__system(tos2(compile_cmd));

			if( !os__file_exists(tos2(new_so_name)) ) {
				fprintf(stderr, "Errors while compiling $file\\n");
				continue;
			}

			lfnmutex_print("reload_so locking...");
			pthread_mutex_lock(&live_fn_mutex);
			lfnmutex_print("reload_so locked");

			live_lib = 0; // hack: force skipping dlclose/1, the code may be still used...
			load_so(new_so_name);
			#ifndef _WIN32
			unlink(new_so_name); // removing the .so file from the filesystem after dlopen-ing it is safe, since it will still be mapped in memory.
			#else
			_unlink(new_so_name);
			#endif
			//if(0 == rename(new_so_name, "${so_name}")){
			//	load_so("${so_name}");
			//}

			lfnmutex_print("reload_so unlocking...");
			pthread_mutex_unlock(&live_fn_mutex);
			lfnmutex_print("reload_so unlocked");

		}
		time__sleep_ms(100);
	}
}
' )
	}

	if xQ.pref.is_so {
		cgen.genln(' int load_so(byteptr path) { return 0; }')
	}
}