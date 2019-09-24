// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

// import time

struct User {
	name string
}

struct A {
	m map[string]int
	users map[string]User
}

fn (a mut A) set(key string, val int) {
	a.m[key] = val
}

fn testXmap() {
	mut m := map[string]int
	assert m.size == 0
	m['hi'] = 1
	m['hello'] = 2
	assert m['hi'] == 1
	assert m['hello'] == 2
	assert m.size == 2
	assert 'hi' in m
	mut sum := 0
	mut key_sum := ''
	// Test `for in`
	for key, val in m {
		sum += val
		key_sum += key
	}
	assert sum == 1 + 2
	assert key_sum == 'hihello'
	// Test `.keys()`
	keys := m.keys()
	assert keys.len == 2
	assert keys[0] == 'hi'
	assert keys[1] == 'hello'
	m.delete('hi')
	assert m.size == 1

	assert m['hi'] == 0
	assert m.keys().len == 1
	assert m.keys()[0] == 'hello'
	////
	mut users := map[string]User
	users['1'] = User{'Peter'}
	peter := users['1']
	assert peter.name == 'Peter'
	mut a := A{
		m: map[string]int
		users: map[string]User
	}
	a.users['Bob'] = User{'Bob'}
	q := a.users['Bob']
	assert q.name == 'Bob'
	a.m['one'] = 1
	a.set('two', 2)
	assert a.m['one'] == 1
	assert a.m['two'] == 2
}

fn testXmap_init() {
	m := { 'one': 1, 'two': 2 }
	assert m['one'] == 1
	assert m['two'] == 2
	assert m['three'] == 0
}

fn testXstring_map() {
	//m := map[string]Fn
}

fn testXlarge_map() {
	//ticks := time.ticks()
	mut nums := map[string]int
	N := 10000
	for i := 0; i < N; i++ {
	        key := i.str()
	        nums[key] = i
	}
	assert nums['1'] == 1
	assert nums['9999'] == 9999
	assert nums['10000'] == 0
	//println(time.ticks() - ticks)
}

fn testXvarious_map_value() {
	mut m1 := map[string]int
	m1['test'] = 1
	assert m1['test'] == 1
	
	mut m2 := map[string]string
	m2['test'] = 'test'
	assert m2['test'] == 'test'
	
	mut m3 := map[string]i8
	m3['test'] = i8(0)
	assert m3['test'] == i8(0)
	
	mut m4 := map[string]i16
	m4['test'] = i16(0)
	assert m4['test'] == i16(0)
	
	mut m5 := map[string]u16
	m5['test'] = u16(0)
	assert m5['test'] == u16(0)
	
	mut m6 := map[string]u32
	m6['test'] = u32(0)
	assert m6['test'] == u32(0)
	
	mut m7 := map[string]bool
	m7['test'] = true
	assert m7['test'] == true
	
	mut m8 := map[string]byte
	m8['test'] = byte(0)
	assert m8['test'] == byte(0)
	
	mut m9 := map[string]f32
	m9['test'] = f32(0.0)
	assert m9['test'] == f32(0.0)
	
	mut m10 := map[string]f64
	m10['test'] = f64(0.0)
	assert m10['test'] == f64(0.0)

	mut m11 := map[string]rune
	m11['test'] = rune(0)
	assert m11['test'] == rune(0)

	//mut m12 := map[string]voidptr
	//m12['test'] = voidptr(0)
	//assert m12['test'] == voidptr(0)

	//mut m13 := map[string]byteptr
	//m13['test'] = byteptr(0)
	//assert m13['test'] == byteptr(0)

	mut m14 := map[string]i64
	m14['test'] = i64(0)
	assert m14['test'] == i64(0)

	mut m15 := map[string]u64
	m15['test'] = u64(0)
	assert m15['test'] == u64(0)
}


fn testXstring_arr() {
	mut m := map[string][]string
	m['a'] = ['one', 'two']
	assert m['a'].len == 2
	assert m['a'][0] == 'one'
	assert m['a'][1] == 'two'
}

/*
fn testXref() {
	m := { 'one': 1 }
	// TODO "cannot take the address of m['one']"
	mut one := &m['one']
	one++
	println(*one)
	
}
*/