// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module os

#include <dirent.h>
#include <unistd.h>

const (
	PathSeparator = '/'
)


// get_error_msg(): Return error code representation in string.
public fn get_error_msg(code int) string {
	_ptr_text := C.strerror(code) // voidptr?
	if _ptr_text == 0 {
		return ''
	}
	return tos(_ptr_text, C.strlen(_ptr_text))
}

public fn ls(path string) []string {
	mut res := []string
	dir := C.opendir(path.str)
	if isnull(dir) {
		println('ls(): Couldnt open dir "$path"')
		print_c_errno()
		return res
	}
	mut ent := &C.dirent{!}
	for {
		ent = C.readdir(dir)
		if isnull(ent) {
			break
		}
		name := tos_clone(ent.d_name)
		if name != '.' && name != '..' && name != '' {
			res << name
		}
	}
	C.closedir(dir)
	return res
}

public fn dir_exists(path string) bool {
	dir := C.opendir(path.str)
	res := !isnull(dir)
	if res {
		C.closedir(dir)
	}
	return res
}

// mkdir(): Creates a new directory with the specified path.
public fn mkdir(path string) {
	C.mkdir(path.str, 511)// S_IRWXU | S_IRWXG | S_IRWXO
}