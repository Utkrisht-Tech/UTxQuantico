// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module urllib

struct ValueStruct {
public:
mut:
	data []string
}

// using this instead of just ValueStruct
// because of unknown map initializer bug
type Value ValueStruct

struct Values {
public:
mut:
	data map[string]Value
	size int
}

// new_values returns a new Values struct for creating
// urlencoded query string parameters. it can also be to 
// post form data with application/x-www-form-urlencoded.
// values.encode() will return the encoded data
public fn new_values() Values {
	return Values{
		data: map[string]Value
	}
}

// Currently you will need to use all()[key].data
// once map[string][]string is implemented
// this will be fixed
public fn (val &Value) all() []string {
	return val.data
}

// get gets the first value associated with the given key.
// If there are no values associated with the key, get returns
// a empty string.
public fn (val Values) get(key string) string {
	if val.data.size == 0 {
		return ''
	}
	vs := val.data[key]
	if vs.data.len == 0 {
		return ''
	}
	return vs.data[0]
}

// get_all gets the all the values associated with the given key.
// If there are no values associated with the key, get returns
// a empty []string.
public fn (val Values) get_all(key string) []string {
	if val.data.size == 0 {
		return []string
	}
	vs := val.data[key]
	if vs.data.len == 0 {
		return []string
	}
	return vs.data
}

// set sets the key to value. It replaces any existing
// values.
public fn (val mut Values) set(key, value string) {
	mut a := val.data[key]
	a.data = [value]
	val.data[key] = a
	val.size = val.data.size
}

// add adds the value to key. It appends to any existing
// values associated with key.
public fn (val mut Values) add(key, value string) {
	mut a := val.data[key]
	if a.data.len == 0 {
		a.data = []string
	}
	a.data << value
	val.data[key] = a
	val.size = val.data.size
}

// del deletes the values associated with key.
public fn (val mut Values) del(key string) {
	val.data.delete(key)
	val.size = val.data.size
}