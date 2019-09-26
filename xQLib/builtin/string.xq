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

struct ustring {
public:
	s     string
	runes []int
	len   int
}

// For C strings only
fn C.strlen(s byteptr) int

public fn xQStrlen(s byteptr) int {
	return C.strlen(*char(s))
}

fn todo() { }

// Converts a C string to a UTxQ string.
// String data is reused, not copied.
public fn tos(s byteptr, len int) string {
	// This should never happen.
	if isnull(s) {
		panic('tos(): null string')
	}
	return string {
		str: s
		len: len
	}
}

public fn tos_clone(s byteptr) string {
	if isnull(s) {
		panic('tos: null string')
	}
	return tos2(s).clone()
}

// Same as `tos`, calculates the length. Called by `string(bytes)` casts.
// Used only internally.
fn tos2(s byteptr) string {
	if isnull(s) {
		panic('tos2: null string')
	}
	len := xQStrlen(s)
	res := tos(s, len)
	return res
}

public fn (a string) clone() string {
	mut b := string {
		len: a.len
		str: malloc(a.len + 1)
	}
	for i := 0; i < a.len; i++ {
		b[i] = a[i]
	}
	b[a.len] = `\0`
	return b
}

/*
public fn (s string) cstr() byteptr {
	clone := s.clone()
	return clone.str
}
*/

public fn (s string) replace(rep, with string) string {
	if s.len == 0 || rep.len == 0 {
		return s
	}
	// TODO PERF Allocating ints is expensive. Should be a stack array
	// Get locations of all reps within this string
	mut idxs := []int
	mut rem := s
	mut rstart := 0
	for {
		mut i := rem.index(rep)
		if i < 0 {break}
		idxs << rstart + i
		i += rep.len
		rstart += i
		rem = rem.substr(i, rem.len)
	}
	// Dont change the string if there's nothing to replace
	if idxs.len == 0 {
		return s
	}
	// Now we know the number of replacements we need to do and we can calculate the len of the new string
	new_len := s.len + idxs.len * (with.len - rep.len)
	mut b := malloc(new_len + 1)// add a newline just in case
	// Fill the new string
	mut idx_pos := 0
	mut cur_idx := idxs[idx_pos]
	mut b_i := 0
	for i := 0; i < s.len; i++ {
		// Reached the location of rep, replace it with "with"
		if i == cur_idx {
			for j := 0; j < with.len; j++ {
				b[b_i] = with[j]
				b_i++
			}
			// Skip the length of rep, since we just replaced it with "with"
			i += rep.len - 1
			// Go to the next index
			idx_pos++
			if idx_pos < idxs.len {
				cur_idx = idxs[idx_pos]
			}
		}
		// Rep doesnt start here, just copy
		else {
			b[b_i] = s[i]
			b_i++
		}
	}
	b[new_len] = `\0`
	return tos(b, new_len)
}

public fn (s string) int() int {
	return C.atoi(*char(s.str))
}


public fn (s string) i64() i64 {
	return C.atoll(*char(s.str))
}

public fn (s string) f32() f32 {
	return C.atof(*char(s.str))
}

public fn (s string) f64() f64 {
	return C.atof(*char(s.str))
}

public fn (s string) u32() u32 {
	return C.strtoul(*char(s.str), 0, 0)
}

public fn (s string) u64() u64 {
	return C.strtoull(*char(s.str), 0, 0)
	//return C.atoll(*char(s.str)) // temporary fix for tcc on windows.
}

// ==
fn (s string) equal(a string) bool {
	if isnull(s.str) { // This should never happen
		panic('string.equal(): Null string')
	}
	if s.len != a.len {
		return false
	}
	for i := 0; i < s.len; i++ {
		if s[i] != a[i] {
			return false
		}
	}
	return true
}

// !=
fn (s string) notequal(a string) bool {
	return !s.equal(a)
}

// s < a
fn (s string) lessthan(a string) bool {
	for i := 0; i < s.len; i++ {
		if i >= a.len || s[i] > a[i] {
			return false
		}
		else if s[i] < a[i] {
			return true
		}
	}
	if s.len < a.len {
		return true
	}
	return false
}

// s <= a
fn (s string) lessthanequal(a string) bool {
	return s.lessthan(a) || s.equal(a)
}

// s > a
fn (s string) greaterthan(a string) bool {
	return !s.lessthanequal(a)
}

// s >= a
fn (s string) greaterthanequal(a string) bool {
	return !s.lessthan(a)
}

// TODO `fn (s string) + (a string)` ? To be consistent with operator overloading syntax.
fn (s string) add(a string) string {
	new_len := a.len + s.len
	mut res := string {
		len: new_len
		str: malloc(new_len + 1)
	}
	for j := 0; j < s.len; j++ {
		res[j] = s[j]
	}
	for j := 0; j < a.len; j++ {
		res[s.len + j] = a[j]
	}
	res[new_len] = `\0`// UTxQ strings are not null terminated, but just in case
	return res
}

public fn (s string) split(delimiter string) []string {
	// println('string split delimiter="$delimiter" s="$s"')
	mut res := []string
	if delimiter.len == 0 {
		res << s
		return res
	}
	if delimiter.len == 1 {
		return s.split_single(delimiter[0])
	}
	mut i := 0
	mut start := 0// - 1
	for i < s.len {
		// printiln(i)
		mut a := s[i] == delimiter[0]
		mut j := 1
		for j < delimiter.len && a {
			a = a && s[i + j] == delimiter[j]
			j++
		}
		last := i == s.len - 1
		if a || last {
			if last {
				i++
			}
			mut val := s.substr(start, i)
			// println('got it "$val" start=$start i=$i delimiter="$delimiter"')
			if val.len > 0 {
				// todo perf
				// val now is '___VAL'. remove '___' from the start
				if val.starts_with(delimiter) {
					// println('!!')
					val = val.right(delimiter.len)
				}
				res << val.trim_space()
			}
			start = i
		}
		i++
	}
	return res
}

public fn (s string) split_single(delimiter byte) []string {
	mut res := []string
	if int(delimiter) == 0 {
		res << s
		return res
	}
	mut i := 0
	mut start := 0
	for i < s.len {
		is_delimiter := s[i] == delimiter
		last := i == s.len - 1
		if is_delimiter || last {
			if !is_delimiter && i == s.len - 1 {
				i++
			}
			val := s.substr(start, i)
			if val.len > 0 {
				res << val
			}
			start = i + 1
		}
		i++
	}
	return res
}

public fn (s string) split_into_lines() []string {
	mut res := []string
	if s.len == 0 {
		return res
	}
	mut start := 0
	for i := 0; i < s.len; i++ {
		last := i == s.len - 1
		if int(s[i]) == 10 || last {
			if last {
				i++
			}
			line := s.substr(start, i)
			res << line
			start = i + 1
		}
	}
	return res
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

// substr
public fn (s string) substr(start, end int) string {
	if start > end || start > s.len || end > s.len || start < 0 || end < 0 {
		panic('substr($start, $end) out of bounds (len=$s.len)')
	}
	len := end - start

	mut res := string {
		len: len
		str: malloc(len + 1)
	}
	for i := 0; i < len; i++ {
		res.str[i] = s.str[start + i]
	}
	res.str[len] = `\0`

/*
	res := string {
		str: s.str + start
		len: len
	}
*/
	return res
}

public fn (s string) index(st string) int {
	if st.len > s.len {
		return -1
	}
	mut i := 0
	for i < s.len {
		mut j := 0
		for j < st.len && s[i + j] == st[j] {
			j++
		}
		if j == st.len {
			return i
		}
		i++
	}
	return -1
}

// KMP search
public fn (s string) index_kmp(p string) int {
    if p.len > s.len {
        return -1
    }
    mut prefix := [0].repeat(p.len)
    mut j := 0
    for i := 1; i < p.len; i++ {
        for p[j] != p[i] && j > 0 {
            j = prefix[j - 1]
        }
        if p[j] == p[i] {
            j++
        }
        prefix[i] = j
    }
    j = 0
    for i := 0; i < s.len; i++ {
        for p[j] != s[i] && j > 0 {
            j = prefix[j - 1]
        }
        if p[j] == s[i] {
            j++
        }
    	if j == p.len {
            return i - p.len + 1
        }
    }
        return -1
}

public fn (s string) index_any(chars string) int {
	for c in chars {
		index := s.index(c.str())
		if index != -1 {
			return index
		}
	}
	return -1
}

public fn (s string) last_index(p string) int {
	if p.len > s.len {
		return -1
	}
	mut i := s.len - p.len
	for i >= 0 {
		mut j := 0
		for j < p.len && s[i + j] == p[j] {
			j++
		}
		if j == p.len {
			return i
		}
		i--
	}
	return -1
}

public fn (s string) index_after(p string, start int) int {
	if p.len > s.len {
		return -1
	}
	mut st := start
	if start < 0 {
		st = 0
	}
	if start >= s.len {
		return -1
	}
	mut i := st
	for i < s.len {
		mut j := 0
		mut ii := i
		for j < p.len && s[ii] == p[j] {
			j++
			ii++
		}
		if j == p.len {
			return i
		}
		i++
	}
	return -1
}

// Counts occurrences of substr in s
public fn (s string) count(suBStr string) int {
	if s.len == 0 || suBStr.len == 0 {
		return 0
	}
	if suBStr.len > s.len {
		return 0
	}
	mut n := 0
	mut i := 0
	for {
		i = s.index_after(substr, i)
		if i == -1 {
			return n
		}
		i += substr.len
		n++
	}
	return 0 // TODO can never get here - UTxQ doesn't know that
}

public fn (s string) contains(p string) bool {
	res := s.index(p) > 0 - 1
	return res
}

public fn (s string) starts_with(p string) bool {
	res := s.index(p) == 0
	return res
}

public fn (s string) ends_with(p string) bool {
	if p.len > s.len {
		return false
	}
	res := s.last_index(p) == s.len - p.len
	return res
}

// TODO only works with ASCII
public fn (s string) to_lower() string {
	mut b := malloc(s.len + 1)
	for i := 0; i < s.len; i++ {
		b[i] = C.tolower(s.str[i])
	}
	return tos(b, s.len)
}

public fn (s string) to_upper() string {
	mut b := malloc(s.len + 1)
	for i := 0; i < s.len; i++ {
		b[i] = C.toupper(s.str[i])
	}
	return tos(b, s.len)
}

public fn (s string) capitalize() string {
	sl := s.to_lower()
    cap := sl[0].str().to_upper() + sl.right(1)
	return cap
}

public fn (s string) title() string {
	 words := s.split(' ')
	 mut ttl := []string

	for word in words {
		ttl << word.capitalize()
	}
	title := ttl.join(' ')

	return title	
}

// 'hey [man] how you doin'
// find_between('[', ']') == 'man'
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
fn (ar []string) contains(val string) bool {
	for s in ar {
		if s == val {
			return true
		}
	}
	return false
}

// TODO generic
fn (ar []int) contains(val int) bool {
	for i, s in ar {
		if s == val {
			return true
		}
	}
	return false
}

/*
public fn (a []string) to_c() voidptr {
	mut res := malloc(sizeof(byteptr) * a.len)
	for i := 0; i < a.len; i++ {
		val := a[i]
		res[i] = val.str
	}
	return res
}
*/

fn is_space(c byte) bool {
	return c in [` `,`\n`,`\t`,`\v`,`\f`,`\r`]
}

public fn (c byte) is_space() bool {
	return is_space(c)
}

public fn (s string) trim_space() string {
	return s.trim(' \n\t\v\f\r')
}

public fn (s string) trim(cutset string) string {
	if s.len < 1 || cutset.len < 1 {
		return s
	}
	cs_arr := cutset.bytes()
	mut pos_left := 0
	mut pos_right := s.len - 1
	mut cs_match := true
	for pos_left <= s.len && pos_right >= -1 && cs_match {
		cs_match = false
		if s[pos_left] in cs_arr {
			pos_left++
			cs_match = true
		}
		if s[pos_right] in cs_arr {
			pos_right--
			cs_match = true
		}
		if pos_left > pos_right {
			return ''
		}
	}
	return s.substr(pos_left, pos_right+1)
}

public fn (s string) trim_left(cutset string) string {
	if s.len < 1 || cutset.len < 1 {
		return s
	}
	cs_arr := cutset.bytes()
	mut pos := 0
	for pos <= s.len && s[pos] in cs_arr {
		pos++
	}
	return s.right(pos)
}

public fn (s string) trim_right(cutset string) string {
	if s.len < 1 || cutset.len < 1 {
		return s
	}
	cs_arr := cutset.bytes()
	mut pos := s.len - 1
	for pos >= -1 && s[pos] in cs_arr {
		pos--
	}
	return s.left(pos+1)
}

// fn print_cur_thread() {
// //C.printf("tid = %08x \n", pthread_self());
// }
fn compare_str(a, b &string) int {
	if a.lessthan(b) {
		return -1
	}
	if a.greaterthan(b) {
		return 1
	}
	return 0
}

fn compare_str_by_len(a, b &string) int {
	if a.len < b.len {
		return -1
	}
	if a.len > b.len {
		return 1
	}
	return 0
}

fn compare_lower_str(a, b &string) int {
	aa := a.to_lower()
	bb := b.to_lower()
	return compare_str(aa, bb)
}

public fn (s mut []string) sort() {
	s.sort_with_compare(compare_str)
}

public fn (s mut []string) sort_ignore_case() {
	s.sort_with_compare(compare_lower_str)
}

public fn (s mut []string) sort_by_len() {
	s.sort_with_compare(compare_str_by_len)
}

public fn (s string) ustring() ustring {
	mut res := ustring {
		s: s
		// runes will have at least s.len elements, save reallocations
		// TODO use VLA for small strings?
		runes: new_array(0, s.len, sizeof(int))
	}
	for i := 0; i < s.len; i++ {
		char_len := utf8_char_len(s.str[i])
		res.runes << i
		i += char_len - 1
		res.len++
	}
	return res
}

// Hack to create ustring without allocations.
// It's called from functions like draw_text() where we know that the string is going to be freed
// right away. Uses global buffer for storing runes []int array.
global g_ustring_runes []int
public fn (s string) ustring_tmp() ustring {
	if g_ustring_runes.len == 0 {
		g_ustring_runes = new_array(0, 128, sizeof(int))
	}
	mut res := ustring {
		s: s
	}
	res.runes = g_ustring_runes
	res.runes.len = s.len
	mut j := 0
	for i := 0; i < s.len; i++ {
		char_len := utf8_char_len(s.str[i])
		res.runes[j] = i
		j++
		i += char_len - 1
		res.len++
	}
	return res
}

fn (u ustring) equal(a ustring) bool {
	if u.len != a.len || u.s != a.s {
		return false
	}
	return true
}

fn (u ustring) notequal(a ustring) bool {
	return !u.equal(a)
}

fn (u ustring) lessthan(a ustring) bool {
	return u.s < a.s
}

fn (u ustring) lessthanequal(a ustring) bool {
	return u.lessthan(a) || u.equal(a)
}

fn (u ustring) greaterthan(a ustring) bool {
	return !u.lessthanequal(a)
}

fn (u ustring) greaterthanequal(a ustring) bool {
	return !u.lessthan(a)
}

fn (u ustring) add(a ustring) ustring {
	mut res := ustring {
		s: u.s + a.s
		runes: new_array(0, u.s.len + a.s.len, sizeof(int))
	}
	mut j := 0
	for i := 0; i < u.s.len; i++ {
		char_len := utf8_char_len(u.s.str[i])
		res.runes << j
		i += char_len - 1
		j += char_len
		res.len++
	}
	for i := 0; i < a.s.len; i++ {
		char_len := utf8_char_len(a.s.str[i])
		res.runes << j
		i += char_len - 1
		j += char_len
		res.len++
	}
	return res
}

public fn (u ustring) index_after(p ustring, start int) int {
	if p.len > u.len {
		return -1
	}
	mut strt := start
	if start < 0 {
		strt = 0
	}
	if start > u.len {
		return -1
	}
	mut i := strt
	for i < u.len {
		mut j := 0
		mut ii := i
		for j < p.len && u.at(ii) == p.at(j) {
			j++
			ii++
		}
		if j == p.len {
			return i
		}
		i++
	}
	return -1
}

// Counts occurrences of substr in s
public fn (u ustring) count(substr ustring) int {
	if u.len == 0 || substr.len == 0 {
		return 0
	}
	if substr.len > u.len {
		return 0
	}
	mut n := 0
	mut i := 0
	for {
		i = u.index_after(substr, i)
		if i == -1 {
			return n
		}
		i += substr.len
		n++
	}
	return 0 // TODO can never get here - UTxQ doesn't know that
}

public fn (u ustring) substr(start, end int) string {
	if start > end || start > u.len || end > u.len || start < 0 || end < 0 {
		panic('substr($start, $end) out of bounds (len=$u.len)')
	}
	end := if _end >= u.len {
		u.s.len
	}
	else {
		u.runes[end]
	}
	return u.s.substr(u.runes[start], end)
}

public fn (u ustring) left(pos int) string {
	if pos >= u.len {
		return u.s
	}
	return u.substr(0, pos)
}

public fn (u ustring) right(pos int) string {
	if pos >= u.len {
		return ''
	}
	return u.substr(pos, u.len)
}

fn (s string) at(idx int) byte {
	if idx < 0 || idx >= s.len {
		panic('String index out of range: $idx / $s.len')
	}
	return s.str[idx]
}

public fn (u ustring) at(idx int) string {
	if idx < 0 || idx >= u.len {
		panic('string index out of range: $idx / $u.runes.len')
	}
	return u.substr(idx, idx + 1)
}

fn (u ustring) free() {
	u.runes.free()
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
	free(s.str)
}

/*
fn (arr []string) free() {
	for s in arr {
		s.free()
	}
	C.free(arr.data)
}
*/

// all_before('21:20:10101.255', '.') == '21:20:10101'
public fn (s string) all_before(delimiter string) string {
	pos := s.index(delimiter)
	if pos == -1 {
		return s
	}
	return s.left(pos)
}

public fn (s string) all_before_last(delimiter string) string {
	pos := s.last_index(delimiter)
	if pos == -1 {
		return s
	}
	return s.left(pos)
}

// all_after('21:20:10101.255', '.') == '255'
public fn (s string) all_after(delimiter string) string {
	pos := s.last_index(delimiter)
	if pos == -1 {
		return s
	}
	return s.right(pos + delimiter.len)
}

// fn (s []string) substr(a, b int) string {
// return join_strings(s.slice_fast(a, b))
// }

public fn (a []string) join(_str string) string {
	if a.len == 0 {
		return ''
	}
	mut len := 0
	for i, val in a {
		len += val.len + _str.len
	}
	len -= _str.len
	// Allocate enough memory
	mut res := ''
	res.len = len
	res.str = malloc(res.len + 1)
	mut idx := 0
	// Go through every string and copy its every char one by one
	for i, val in a {
		for j := 0; j < val.len; j++ {
			c := val[j]
			res.str[idx] = val.str[j]
			idx++
		}
		// Add _str if it's not last
		if i != a.len - 1 {
			for k := 0; k < _str.len; k++ {
				res.str[idx] = _str.str[k]
				idx++
			}
		}
	}
	res.str[res.len] = `\0`
	return res
}

public fn (s []string) join_lines() string {
	return s.join('\n')
}

public fn (s string) reverse() string {
	mut res := string {
		len: s.len
		str: malloc(s.len)
	}

	for i := s.len - 1; i >= 0; i-- {
				res[s.len-i-1] = s[i]
	}

	return res
}

// 'hi'.limit(10) => 'hi'
// 'hello'.limit(2) => 'he'
public fn (s string) limit(maxi int) string {
	u := s.ustring()
	if u.len <= maxi {
		return s
	}
	return u.substr(0, maxi)
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
	mut buf := [byte(0)].repeat(s.len)
	C.memcpy(buf.data, s.str, s.len)
	return buf
}