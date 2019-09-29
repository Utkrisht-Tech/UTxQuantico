// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module builtin

struct string {
//mut:
	//hash_cache int
public:
	str byteptr
	len int
}

// For C strings only
fn C.strlen(s byteptr) int

fn todo() { }


public fn (a string) clone() string {
	return a
}

public fn (s string) replace(rep, with_ string) string {
	return s
}

public fn (s string) int() int {
	return 0
}

public fn (s string) i64() i64 {
	return 0
}

public fn (s string) f32() f32 {
	return 0.0
}

public fn (s string) f64() f64 {
	return 0.0
}

public fn (s string) u32() u32 {
	return u32(0)
}

public fn (s string) u64() u64 {
	return u64(0)
}

public fn (s string) split(delimiter string) []string {
	return s.split(delimiter)
}

public fn (s string) split_single(delimiter byte) []string {
	return s.split(delimiter.str())
}

public fn (s string) split_into_lines() []string {
	return s.split('\n')
}

// 'hello'.left(2) => 'he'
public fn (s string) left(n int) string {
	if n >= s.len {
		return s
	}
	return s.substr(0, n)
}
// 'hello'.right(2) => 'llo'
public fn (s string) right(n int) string {
	if n >= s.len {
		return ''
	}
	return s.substr(n, s.len)
}

public fn (s string) substr(start, end int) string {
	return 'a'
}

public fn (s string) index(p string) int {
	return -1
}

public fn (s string) index_any(chars string) int {
	return -1
}

public fn (s string) last_index(p string) int {
	return -1
}

public fn (s string) index_after(p string, start int) int {
	return -1
}

// counts occurrences of substr in s
public fn (s string) count(substr string) int {
	return 0 // TODO can never get here - UTxQ doesn't know that
}

public fn (s string) contains(p string) bool {
	return false
}

public fn (s string) starts_with(p string) bool {
	return false
}

public fn (s string) ends_with(p string) bool {
	return false
}

// TODO only works with ASCII
public fn (s string) to_lower() string {
	return s
}

public fn (s string) to_upper() string {
	return s
}

public fn (s string) capitalize() string {
	return s
}

public fn (s string) title() string {
	return s
}

// 'Hello [UTxQ] you are welcome'
// find_between('[', ']') == 'UTxQ'
public fn (s string) find_between(start, end string) string {
	start_pos := s.index(start)
	if start_pos == -1 {
		return ''
	}
	// First get everything to the right of 'start'
	val := s.right(start_pos + start.len)
	end_pos := val.index(end)
	if end_pos == -1 {
		return val
	}
	return val.left(end_pos)
}

// TODO generic
public fn (ar []string) contains(val string) bool {
	for s in ar {
		if s == val {
			return true
		}
	}
	return false
}

// TODO generic
public fn (ar []int) contains(val int) bool {
	for i, s in ar {
		if s == val {
			return true
		}
	}
	return false
}


fn is_space(c byte) bool {
	return C.isspace(c)
}

public fn (c byte) is_space() bool {
	return is_space(c)
}

public fn (s string) trim_space() string {
	#return s.str.trim(' ');
	return ''
}

public fn (s string) trim(cutset string) string {
	#return s.str.trim(cutset);
	return ''
}

public fn (s string) trim_left(cutset string) string {
	#return s.str.trimLeft(cutset);
	return ''
}

public fn (s string) trim_right(cutset string) string {
	#return s.str.trimRight(cutset);
	return ''
}

// fn print_cur_thread() {
// //C.printf("tid = %08x \n", pthread_self());
// }
public fn (s mut []string) sort() {

}

public fn (s mut []string) sort_ignore_case() {
}

public fn (s mut []string) sort_by_len() {
}

fn (s string) at(idx int) byte {
	if idx < 0 || idx >= s.len {
		panic('String index out of range')
	}
	return s.str[idx]
}
public fn (c byte) is_digit() bool {
	return c >= `0` && c <= `9`
}

public fn (c byte) is_hex_digit() bool {
	return c.is_digit() || (c >= `a` && c <= `f`) || (c >= `A` && c <= `F`)
}

public fn (c byte) is_oct_digit() bool {
	return c >= `0` && c <= `7`
}

public fn (c byte) is_letter() bool {
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`)
}

public fn (s string) free() {
}

/*
fn (arr []string) free() {
	for s in arr {
		s.free()
	}
	C.free(arr.data)
}
*/

// all_before('23:34:45.234', '.') == '23:34:45'
public fn (s string) all_before(dot string) string {
	pos := s.index(dot)
	if pos == -1 {
		return s
	}
	return s.left(pos)
}

public fn (s string) all_before_last(dot string) string {
	pos := s.last_index(dot)
	if pos == -1 {
		return s
	}
	return s.left(pos)
}

public fn (s string) all_after(dot string) string {
	pos := s.last_index(dot)
	if pos == -1 {
		return s
	}
	return s.right(pos + dot.len)
}

// fn (s []string) substr(a, b int) string {
// return join_strings(s.slice_fast(a, b))
// }
public fn (a []string) join(del string) string {
	return ''
}

public fn (s []string) join_lines() string {
	return s.join('\n')
}

public fn (s string) reverse() string {
	return s
}

public fn (s string) limit(max int) string {
	if s.len <= max {
		return s
	}
	return s.substr(0, max)
}

// TODO is_white_space()
public fn (c byte) is_white() bool {
	i := int(c)
	return i == 10 || i == 32 || i == 9 || i == 13 || c == `\r`
}


public fn (s string) hash() int {
	//mut h := s.hash_cache
	mut h := 0
	if h == 0 && s.len > 0 {
		for c in s {
			h = h * 31 + int(c)
		}
	}
	return h
}

public fn (s string) bytes() []byte {
	if s.len == 0 {
		return []byte
	}
	mut buf := [byte(0)].repeat2(s.len)
	C.memcpy(buf.data, s.str, s.len)
	return buf
}