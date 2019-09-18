// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module builtin

import StringX

struct array {
public:
	data         voidptr
	len          int
	cap          int
	element_size int
}

/*
// Private function, used by UTxQ (`nums := []int`)
fn new_array(mylen, cap, elm_size int) array {
	arr := array {
		len: mylen
		cap: cap
		element_size: elm_size
	}
	return arr
}


// TODO
public fn _make(len, cap, elm_size int) array {
	return new_array(len, cap, elm_size)
}


*/
fn array_repeat(val voidptr, no_of_repeats, elm_size int) array {
	return val
}

public fn (a array) repeat2(no_of_repeats int) array {
	#return Array(a[0]).fill(no_of_repeats)
	return a
}

public fn (a mut array) sort_with_compare(compare voidptr) {
}

public fn (a mut array) insert(i int, val voidptr) {
}

public fn (a mut array) prepend(val voidptr) {
	a.insert(0, val)
}

public fn (a mut array) delete_elm(idx int) {
}

/*
public fn (a array) first() voidptr {
	if a.len == 0 {
		panic('array.first: empty array')
	}
	return a.data + 0
}

public fn (a array) last() voidptr {
	if a.len == 0 {
		panic('array.last: empty array')
	}
	return a.data + (a.len - 1) * a.element_size
}
*/

public fn (st array) left(n int) array {
	if n >= st.len {
		return st
	}
	return st.slice(0, n)
}

public fn (st array) right(n int) array {
	if n >= st.len {
		return st
	}
	return st.slice(n, st.len)
}

public fn (st array) slice(start, _end int) array {
	return st
}

public fn (a array) reverse() array {
	return a
}

public fn (a array) clone() array {
	return a
}

public fn (a array) free() {
}

// "[ 'a', 'b', 'c' ]"
public fn (a []string) str() string {
	mut sb := StringX.new_builder(a.len * 3)
	sb.write('[')
	for i := 0; i < a.len; i++ {
		val := a[i]
		sb.write('"')
		sb.write(val)
		sb.write('"')
		if i < a.len - 1 {
			sb.write(', ')
		}
	}
	sb.write(']')
	return sb.str()
}

public fn (b []byte) hex() string {
	return 'sdf'
}

public fn (arr mut array) _push_many(val voidptr, size int) {
}

public fn free(voidptr) {

}