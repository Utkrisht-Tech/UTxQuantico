// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module builtin

#include <float.h>
#include <math.h>

public fn (d double) str() string {
	return '0'
}

public fn (d f64) str() string {
	return '0'
}

public fn (d f32) str() string {
	return '0'
}

public fn ptr_str(ptr voidptr) string {
	return '0'
}

// compare floats using C epsilon
public fn (a f64) eq(b f64) bool {
	//return C.fabs(a - b) <= C.DBL_EPSILON	
	return (a - b) <= 0.01
}

// fn (nn i32) str() string {
// return i
// }
public fn (nn int) str() string {
	return '0'
}

public fn (nn u32) str() string {
	return '0'
}

public fn (nn u8) str() string {
	return '0'
}

public fn (nn i64) str() string {
	return '0'
}

public fn (nn u64) str() string {
	return '0'
}

public fn (b bool) str() string {
	if b {
		return 'true'
	}
	return 'false'
}

public fn (n int) hex() string {
	return '0'
}

public fn (n i64) hex() string {
	return '0'
}

public fn (a []byte) contains(val byte) bool {
	for aa in a {
		if aa == val {
			return true
		}
	}
	return false
}

public fn (c rune) str() string {
	return '0'
}

public fn (c byte) str() string {
	return '0'
}

public fn (c byte) is_capital() bool {
	return c >= `A` && c <= `Z`
}

public fn (b []byte) clone() []byte {
	mut res := [byte(0)].repeat(b.len)
	for i := 0; i < b.len; i++ {
		res[i] = b[i]
	}
	return res
}