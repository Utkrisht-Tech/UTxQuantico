// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module builtin

#include <float.h>
#include <math.h>

public fn (d f64) str() string {
	buf := malloc(sizeof(double) * 5 + 1)// TODO
	C.sprintf(*char(buf), '%f', d)
	return tos(buf, xQStrlen(buf))
}

public fn (d f32) str() string {
	buf := malloc(sizeof(double) * 5 + 1)// TODO
	C.sprintf(*char(buf), '%f', d)
	return tos(buf, xQStrlen(buf))
}

public fn ptr_str(ptr voidptr) string {
	buf := malloc(sizeof(double) * 5 + 1)// TODO
	C.sprintf(*char(buf), '%p', ptr)
	return tos(buf, xQStrlen(buf))
}

// compare floats using C epsilon
public fn (a f64) eq(b f64) bool {
	//return C.fabs(a - b) <= C.DBL_EPSILON	
	return (a - b) <= C.DBL_EPSILON	
}

// fn (nn i32) str() string {
// return i
// }
public fn (nn int) str() string {
	mut n := nn
	if n == 0 {
		return '0'
	}
	max := 16
	mut buf := calloc(max)
	mut len := 0
	mut is_neg := false
	if n < 0 {
		n = -n
		is_neg = true
	}
	// Fill the string from the end
	for n > 0 {
		d := n % 10
		buf[max - len - 1] = d + int(`0`)
		len++
		n = n / 10
	}
	// Prepend - if it's negative
	if is_neg {
		buf[max - len - 1] = `-`
		len++
	}
	return tos(buf + max - len, len)
}

public fn (nn u32) str() string {
	 mut n := nn
	if n == u32(0) {
		return '0'
	}
	max := 16
	mut buf := malloc(max)
	mut len := 0
	// Fill the string from the end
	for n > u32(0) {
		d := n % u32(10)
		buf[max - len - 1] = d + u32(`0`)
		len++
		n = n / u32(10)
	}
	return tos(buf + max - len, len)
}

/*
public fn (nn byte) str() string {
	 mut n := nn
	if n == byte(0) {
		return '0'
	}
	max := 5
	mut buf := malloc(max)
	mut len := 0
	// Fill the string from the end
	for n > byte(0) {
		d := n % byte(10)
		buf[max - len - 1] = d + byte(`0`)
		len++
		n = n / byte(10)
	}
	return tos(buf + max - len, len)
}
*/

public fn (nn i64) str() string {
	mut n := nn
	if n == i64(0) {
		return '0'
	}
	max := 32
	mut buf := malloc(max)
	mut len := 0
	mut is_neg := false
	if n < i64(0) {
		n = -n
		is_neg = true
	}
	// Fill the string from the end
	for n > i64(0) {
		d := int(n % i64(10))
		buf[max - len - 1] = d + int(`0`)
		len++
		n = n / i64(10)
	}
	// Prepend - if it's negative
	if is_neg {
		buf[max - len - 1] = `-`
		len++
	}
	return tos(buf + max - len, len)
}

public fn (nn u64) str() string {
	 mut n := nn
	if n == u64(0) {
		return '0'
	}
	max := 32
	mut buf := malloc(max)
	mut len := 0
	// Fill the string from the end
	for n > u64(0) {
		d := n % u64(10)
		buf[max - len - 1] = d + u64(`0`)
		len++
		n = n / u64(10)
	}
	return tos(buf + max - len, len)
}

public fn (bo bool) str() string {
	if bo {
		return 'true'
	}
	return 'false'
}

public fn (n int) hex() string {
	len := if n >= 0 {
		n.str().len + 3
	} else {
		11
	}
	hex := malloc(len) // 0x + \n
	count := int(C.sprintf(*char(hex), '0x%x', n))
	return tos(hex, count)
}

public fn (n i64) hex() string {
	len := if n >= i64(0) {
		n.str().len + 3
	} else {
		19
	}
	hex := malloc(len)
	count := int(C.sprintf(*char(hex), '0x%llx', n))
	return tos(hex, count)
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
	first_byte := int(c) >> 8 * 3 & 0xff
	len := utf8_char_len(first_byte)
	mut str := string {
		len: len
		str: malloc(len + 1)
	}
	for i := 0; i < len; i++ {
		str.str[i] = int(c) >> 8 * (3 - i) & 0xff
	}
	str[len] = `\0`
	return str
}

public fn (c byte) str() string {
	mut str := string {
		len: 1
		str: malloc(2)
	}
	str.str[0] = c
	str.str[1] = `\0`
	return str
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