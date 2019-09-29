// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module JsonX

#flag -I @XQROOT/thirdParty/cJSON
#flag @XQROOT/thirdParty/cJSON/cJSON.o
#include "cJSON.h"

struct C.cJSON {
	valueint    int
	valuedouble f32
	valuestring byteptr
}

// Functions for decoding from Json

fn jsonXdecode_int(root &C.cJSON) int {
	if isnull(root) {
		return 0
	}
	return root.valueint
}

fn jsonXdecode_i8(root &C.cJSON) i8 {
	if isnull(root) {
		return i8(0)
	}
	return i8(root.valueint)
}

fn jsonXdecode_i16(root &C.cJSON) i16 {
	if isnull(root) {
		return i16(0)
	}
	return i16(root.valueint)
}

fn jsonXdecode_i64(root &C.cJSON) i64 {
	if isnull(root) {
		return i64(0)
	}
	return i64(root.valuedouble) //i64 is double in C
}

fn jsonXdecode_byte(root &C.cJSON) byte {
	if isnull(root) {
		return byte(0)
	}
	return byte(root.valueint)
}

fn jsonXdecode_u16(root &C.cJSON) u16 {
	if isnull(root) {
		return u16(0)
	}
	return u16(root.valueint)
}

fn jsonXdecode_u32(root &C.cJSON) u32 {
	if isnull(root) {
		return u32(0)
	}
	return u32(root.valueint)
}

fn jsonXdecode_u64(root &C.cJSON) u64 {
	if isnull(root) {
		return u64(0)
	}
	return u64(root.valueint)
}

fn jsonXdecode_f32(root &C.cJSON) f32 {
	if isnull(root) {
		return f32(0)
	}
	return f32(root.valuedouble)
}

fn jsonXdecode_f64(root &C.cJSON) f64 {
	if isnull(root) {
		return f64(0)
	}
	return f64(root.valuedouble)
}

fn jsonXdecode_string(root &C.cJSON) string {
	if isnull(root) {
		return ''
	}
	if isnull(root.valuestring) {
		return ''
	}
	// println('jsonXdecode string valuestring="$root.valuestring"')
	// return tos(root.valuestring, _strlen(root.valuestring))
	return tos_clone(root.valuestring)// , _strlen(root.valuestring))
}

fn jsonXdecode_bool(root &C.cJSON) bool {
	if isnull(root) {
		return false
	}
	return C.cJSON_IsTrue(root)
}

// Functions for encoding to Json

fn jsonXencode_int(val int) &C.cJSON {
	return C.cJSON_CreateNumber(val)
}

fn jsonXencode_i8(val i8) &C.cJSON {
	return C.cJSON_CreateNumber(val)
}

fn jsonXencode_i16(val i16) &C.cJSON {
	return C.cJSON_CreateNumber(val)
}

fn jsonXencode_i64(val i64) &C.cJSON {
	return C.cJSON_CreateNumber(val)
}

fn jsonXencode_byte(val byte) &C.cJSON {
	return C.cJSON_CreateNumber(val)
}

fn jsonXencode_u16(val u16) &C.cJSON {
	return C.cJSON_CreateNumber(val)
}

fn jsonXencode_u32(val u32) &C.cJSON {
	return C.cJSON_CreateNumber(val)
}

fn jsonXencode_u64(val u64) &C.cJSON {
	return C.cJSON_CreateNumber(val)
}

fn jsonXencode_f32(val f32) &C.cJSON {
	return C.cJSON_CreateNumber(val)
}

fn jsonXencode_f64(val f64) &C.cJSON {
	return C.cJSON_CreateNumber(val)
}

fn jsonXencode_bool(val bool) &C.cJSON {
	return C.cJSON_CreateBool(val)
}

fn jsonXencode_string(val string) &C.cJSON {
	clone := val.clone()
	return C.cJSON_CreateString(clone.str)
	// return C.cJSON_CreateString2(val.str, val.len)
}

// Parse & Print Functions

// user := decode_User(jsonXparse(js_string_var))
fn jsonXparse(s string) &C.cJSON {
	return C.cJSON_Parse(s.str)
}

// json_string := jsonXprint(encode_User(user))
fn jsonXprint(json &C.cJSON) string {
	s := C.cJSON_PrintUnformatted(json)
	return tos(s, C.strlen(s))
}

// cJSON wrappers
// fn json_array_for_each(val, root &C.cJSON) {
// #cJSON_ArrayForEach (val ,root)
// }