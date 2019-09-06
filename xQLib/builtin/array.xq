// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module builtin

import strings

struct array {
public:
	// Using a void pointer allows to implement arrays without generics and without generating
	// extra code for every type.
	data         voidptr
	len          int
	cap          int
	element_size int
}

// Private function, used by UTxQ (`nums := []int`)
fn new_array(inpLen, cap, elem_size int) array {
	arr := array {
		len: inpLen
		cap: cap
		element_size: elem_size
		data: calloc(cap * elem_size)
	}
	return arr
}


// TODO
public fn _make(inpLen, cap, elem_size int) array {
	return new_array(inpLen, cap, elem_size)
}

// Private function, used by UTxQ (`nums := [1, 2, 3]`)
fn new_array_from_c_array(inpLen, cap, elem_size int, c_array voidptr) array {
	arr := array {
		len: inpLen
		cap: cap
		element_size: elem_size
		data: malloc(cap * elem_size)
	}
	// TODO Write all memory functions in UTxQ (like memcpy)
	C.memcpy(arr.data, c_array, inpLen * elem_size)
	return arr
}

// Private function, used by UTxQ (`nums := [1, 2, 3] !`)
fn new_array_from_c_array_no_alloc(inpLen, cap, elem_size int, c_array voidptr) array {
	arr := array {
		len: inpLen
		cap: cap
		element_size: elem_size
		data: c_array
	}
	return arr
}

// Private function, used by UTxQ  (`[0; 100]`)
fn array_repeat(val voidptr, no_of_repeats, elem_size int) array {
	arr := array {
		len: no_of_repeats
		cap: no_of_repeats
		element_size: elem_size
		data: malloc(no_of_repeats * elem_size)
	}
	for i := 0; i < no_of_repeats; i++ {
		C.memcpy(arr.data + i * elem_size, val, elem_size)
	}
	return arr
}

public fn (a mut array) sort_with_compare(compare voidptr) {
	C.qsort(a.data, a.len, a.element_size, compare)
}

public fn (a mut array) insert(i int, val voidptr) {
	if i >= a.len {
		panic('array.insert: index larger than length')
	}
	a._push(val)
	size := a.element_size
	C.memmove(a.data + (i + 1) * size, a.data + i * size, (a.len - i) * size)
	a.set(i, val)
}

public fn (a mut array) prepend(val voidptr) {
	a.insert(0, val)
}

public fn (a mut array) delete(idx int) {
	size := a.element_size
	C.memmove(a.data + idx * size, a.data + (idx + 1) * size, (a.len - idx) * size)
	a.len--
	a.cap--
}

fn (a array) _get(i int) voidptr {
	if i < 0 || i >= a.len {
		panic('array index out of range: $i/$a.len')
	}
	return a.data + i * a.element_size
}

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

public fn (s array) left(n int) array {
	if n >= s.len {
		return s
	}
	return s.slice(0, n)
}

public fn (s array) right(n int) array {
	if n >= s.len {
		return s
	}
	return s.slice(n, s.len)
}

public fn (s array) slice(start, _end int) array {
	mut end := _end
	if start > end {
		panic('invalid slice index: $start > $end')
	}
	if end > s.len {
		panic('runtime error: slice bounds out of range ($end >= $s.len)')
	}
	if start < 0 {
		panic('runtime error: slice bounds out of range ($start < 0)')
	}
	l := end - start
	res := array {
		element_size: s.element_size
		data: s.data + start * s.element_size
		len: l
		cap: l
		//is_slice: true
	}
	return res
}

fn (a mut array) set(idx int, val voidptr) {
	if idx < 0 || idx >= a.len {
		panic('array index out of range: $idx / $a.len')
	}
	C.memcpy(a.data + a.element_size * idx, val, a.element_size)
}

fn (arr mut array) _push(val voidptr) {
	if arr.len >= arr.cap - 1 {
		cap := (arr.len + 1) * 2
		// println('_push: realloc, new cap=$cap')
		if arr.cap == 0 {
			arr.data = malloc(cap * arr.element_size)
		}
		else {
			arr.data = C.realloc(arr.data, cap * arr.element_size)
		}
		arr.cap = cap
	}
	C.memcpy(arr.data + arr.element_size * arr.len, val, arr.element_size)
	arr.len++
}

// `val` is array.data
// TODO make private, right now it's used by strings.Builder
public fn (arr mut array) _push_many(val voidptr, size int) {
	if arr.len >= arr.cap - size {
		cap := (arr.len + size) * 2
		// println('_push: realloc, new cap=$cap')
		if arr.cap == 0 {
			arr.data = malloc(cap * arr.element_size)
		}
		else {
			arr.data = C.realloc(arr.data, cap * arr.element_size)
		}
		arr.cap = cap
	}
	C.memcpy(arr.data + arr.element_size * arr.len, val, arr.element_size * size)
	arr.len += size
}

public fn (a array) reverse() array {
	arr := array {
		len: a.len
		cap: a.cap
		element_size: a.element_size
		data: malloc(a.cap * a.element_size)
	}
	for i := 0; i < a.len; i++ {
		C.memcpy(arr.data + i * arr.element_size, &a[a.len-1-i], arr.element_size)
	}
	return arr
}

public fn (a array) clone() array {
	arr := array {
		len: a.len
		cap: a.cap
		element_size: a.element_size
		data: malloc(a.cap * a.element_size)
	}
	C.memcpy(arr.data, a.data, a.cap * a.element_size)
	return arr
}

//public fn (a []int) free() {
public fn (a array) free() {
	//if a.is_slice {
		//return
	//}
	C.free(a.data)
}

// "[ 'a', 'b', 'c' ]"
public fn (a []string) str() string {
	mut sb := strings.new_builder(a.len * 3)
	sb.write('[')
	for i := 0; i < a.len; i++ {
		val := a[i]
		sb.write('"$val"')
		if i < a.len - 1 {
			sb.write(', ')
		}
	}
	sb.write(']')
	return sb.str()
}

public fn (b []byte) hex() string {
	mut hex := malloc(b.len*2+1)
	mut ptr := &hex[0]
	for i := 0; i < b.len ; i++ {
		ptr += C.sprintf(ptr, '%02x', b[i])
	}
	return string(hex)
}

// TODO: implement for all types
public fn copy(dst, src []byte) int {
	if dst.len > 0 && src.len > 0 {
		min := if dst.len < src.len { dst.len } else { src.len }
		C.memcpy(dst.data, src.left(min).data, dst.element_size*min)
		return min
	}
	return 0
}

fn compare_ints(a, b &int) int {
	if a < b {
		return -1
	}
	if a > b {
		return 1
	}
	return 0
}

public fn (a mut []int) sort() {
	a.sort_with_compare(compare_ints)
}