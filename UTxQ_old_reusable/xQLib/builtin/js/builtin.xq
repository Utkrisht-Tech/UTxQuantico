// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module builtin

public fn exit(code int) {
	println('js.exit()')
}

// isnull returns true if an object is null (only for C objects).
public fn isnull(v voidptr) bool {
	return v == 0
}

public fn panic(st string) {
	println('UTxQ panic: ' + st)
	exit(1)
}

public fn println(st string) {
	#console.log(st)
}

public fn eprintln(st string) {
	#console.log(st)
}

public fn print(st string) {
	#console.log(st)
}