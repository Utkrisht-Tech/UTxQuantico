// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module builtin

public fn exit(code int) {
	C.exit(code)
}

// isnull returns true if an object is null (only for C objects).
public fn isnull(v voidptr) bool {
	return v == 0
}

fn on_panic(f fn (int) int) {
	// TODO
}

fn C.backtrace(voidptr, int) int

public fn print_backtrace_skipping_top_frames(skipframes int) {
	$if mac {
		buffer := [100]byteptr
		nr_ptrs := C.backtrace(*voidptr(buffer), 100)
		C.backtrace_symbols_fd(*voidptr(&buffer[skipframes]), nr_ptrs-skipframes, 1)
		return
	}
	$if linux {
		$if !android {
			// backtrace is not available on Android.
			if C.backtrace_symbols_fd != 0 {
				buffer := [100]byteptr
				nr_ptrs := C.backtrace(*voidptr(buffer), 100)
				C.backtrace_symbols_fd(&buffer[skipframes], nr_ptrs-skipframes, 1)
				return
			}else{
				C.printf('backtrace_symbols_fd is missing, so printing backtraces is not available.\n')
				C.printf('Some libc implementations like musl simply do not provide it.\n')
			}
		}
	}
	println('print_backtrace_skipping_top_frames is not implemented on this platform for now...\n')
}
public fn print_backtrace(){
	// at the time of backtrace_symbols_fd call, the C stack would look something like this:
	// 1 frame for print_backtrace_skipping_top_frames
	// 1 frame for print_backtrace itself
	// ... print the rest of the backtrace frames ...
	// => top 2 frames should be skipped, since they will not be informative to the developer
	print_backtrace_skipping_top_frames(2)
}

// replaces panic when -debug arg is passed
fn _panic_debug(line_no_y int, file,  mod, fn_name, s string) {
	println('================ UTxQuantico panic ================')
	println('   module: $mod')
	println(' function: ${fn_name}()')
	println('     file: $file')
	println('     line: ' + line_no_y.str())
	println('  message: $s')
	println('=========================================')
	print_backtrace_skipping_top_frames(1)
	C.exit(1)
}

public fn panic(s string) {
	println('UTxQ panic: $s')
	print_backtrace()
	C.exit(1)
}

public fn println(s string) {
	// Should never happen
	if isnull(s.str) {
		panic('println(NULL)')
	}
	$if windows {
		C._putws(s.to_wide())
	} $else {
		C.printf('%.*s\n', s.len, s.str)
	}
}

public fn eprintln(s string) {
	if isnull(s.str) {
		panic('eprintln(NULL)')
	}
	$if mac {
		C.fprintf(stderr, '%.*s\n', s.len, s.str)
	}
	// TODO issues with stderr and XCompiling for Linux
	$else {
		println(s)
	}
}

public fn print(s string) {
	$if windows {
		C.wprintf(s.to_wide())
	} $else {
		C.printf('%.*s', s.len, s.str)
	}
}

__global total_m i64 = 0
//__global no_of_mallocs int = 0
public fn malloc(n int) byteptr {
	if n < 0 {
		panic('malloc(<0)')
	}
	//no_of_mallocs++
/*
TODO
#ifdef UTXQPLAY
	if n > 10000 {
		panic('allocating more than 10 KB is not allowed in the Quantum Playground')
	}
#endif
#ifdef DEBUG_ALLOC
	total_m += n
	println('\n\n\nmalloc($n) total=$total_m')
	print_backtrace()
#endif
*/
	ptr := C.malloc(n)
	if isnull(ptr) {
		panic('malloc($n) failed')
	}
	return ptr
}

public fn calloc(n int) byteptr {
	if n < 0 {
		panic('calloc(<0)')
	}
	return C.calloc(n, 1)
}

public fn free(ptr voidptr) {
	C.free(ptr)
}

fn memdup(src voidptr, sz int) voidptr {
	mem := malloc(sz)
	return C.memcpy(mem, src, sz)
}

fn xQ_ptr_free(ptr voidptr) {
	C.free(ptr)
}