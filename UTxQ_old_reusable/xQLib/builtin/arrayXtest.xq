// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

const (
	test_arr = [1, 2, 3]
	A = 8
)

fn testXints() {
	mut a := [1, 2, 3, 4, 5]
	assert a.len == 5
	assert a[1] == 2
	assert a[3] == 4
	assert a.last() == 5
	a << 6
	assert a.len == 6
	assert a.first() == 1
	assert a.last() == 6

	st := a.str()
	assert st == '[1, 2, 3, 4, 5, 6]'
	assert a[3] == 4
    assert a.first() == 1
	assert a.last() == 6
}

fn testXdeleting() {
	mut a := [1, 2, 3, 4, 5, 6]
	assert a.len == 6
	assert a.str() == '[1, 2, 3, 4, 5, 6]'

	a.delete(0)
	assert a.str() == '[2, 3, 4, 5, 6]'
	assert a.len == 5

	a.delete(1)
	assert a.str() == '[2, 4, 5, 6]'
	assert a.len == 4
}

fn testXshort() {
	a := [1, 2, 3]
	assert a.len == 3
	assert a.cap == 3
	assert a[0] == 1
	assert a[1] == 2
	assert a[2] == 3
}

fn testXlarge() {
	mut a := [0].repeat(0)
	for i := 0; i < 10000; i++ {
		a << i
	}
	assert a.len == 10000
	assert a[500] == 500
}

struct Chunk {
	val string
}

struct K {
	test_arr []Chunk
}

fn testXempty() {
	mut chunks := []Chunk{}
	a := Chunk{}
	assert chunks.len == 0
	chunks << a
	assert chunks.len == 1
	chunks = []Chunk{}
	assert chunks.len == 0
	chunks << a
	assert chunks.len == 1
}

fn testXpush() {
	mut a := []int
	a << 1
	a << 2
	assert a[1] == 2
	assert a.str() == '[1, 2]'
}

fn testXstrings() {
	a := ['a', 'b', 'c']
	assert a.str() == '["a", "b", "c"]'
}

fn testXrepeat() {
	a := [0].repeat(3)
	assert a.len == 3
	assert a[0] == 0 && a[1] == 0 && a[2] == 0
	b := [10].repeat(3)
	assert b.len == 3
	assert b[0] == 10 && b[1] == 10 && b[2] == 10
	{
		mut aa := [1.1].repeat(3)
		// FIXTHIS: assert aa[0] == 1.1 still not supported, need to implement
		assert aa[0] == f32(1.1)
		assert aa[1] == f32(1.1)
		assert aa[2] == f32(1.1)
	}
	{
		mut aa := [f32(1.1)].repeat(3)
		assert aa[0] == f32(1.1)
		assert aa[1] == f32(1.1)
		assert aa[2] == f32(1.1)
	}
	{
		aa := [f64(1.1)].repeat(3)
		assert aa[0] == f64(1.1)
		assert aa[1] == f64(1.1)
		assert aa[2] == f64(1.1)
	}
}

fn testXright() {
	a := [1, 2, 3, 4]
	b := a.right(1)
	assert b[0] == 2
	assert b[1] == 3
    assert b[2] == 4
}

fn testXleft() {
	a := [1, 2, 3]
	b := a.left(2)
	assert b[0] == 1
	assert b[1] == 2
}

fn testXslice() {
	a := [1, 2, 3, 4]
	b := a.slice(2, 4)
	assert b.len == 2
	assert a.slice(1, 2).len == 1
	assert a.len == 4
}

fn testXpush_many() {
	mut a := [1, 2, 3]
	b := [4, 5, 6]
	a << b
	assert a.len == 6
    assert a.first() == 1
	assert a[0] == 1
	assert a[3] == 4
	assert a[5] == 6
    assert a.last() == 6
}

fn testXreverse() {
  	mut a := [1, 2, 3, 4]
	mut b := ['test', 'array', 'reverse']
	c := a.reverse()
	d := b.reverse()
	for i, _  in c {
		assert c[i] == a[a.len-i-1]
	}
	for i, _ in d {
		assert d[i] == b[b.len-i-1]
	}
}

const (
	N = 5
)

fn testXfixed() {
	/*
	mut nums := [4]int 
	assert nums[0] == 0 
	assert nums[1] == 0 
	assert nums[2] == 0 
	assert nums[3] == 0 
	nums[1] = 10
	assert nums[1] == 7 
	///////
	nums2 := [N]int 
	assert nums2[N - 1] == 0
	*/
} 

fn modify (numbers mut []int) {
        numbers[0] = 777
}

fn testXmut_slice() {
	mut n := [1,2,3]
	modify(mut n.left(2))
	assert n[0] == 777
	modify(mut n.right(2))
	assert n[2] == 777
	println(n)
}

fn testXclone() {
	nums := [1, 2, 3, 4, 10]
	nums2 := nums.clone()
	assert nums2.len == 5
	assert nums2.str() == '[1, 2, 3, 4, 10]'
	assert nums.slice(1, 3).str() == '[2, 3]'
}
 
fn testXdoubling() {
	mut nums := [1, 2, 3, 4, 5]
	for i := 0; i < nums.len; i++ {
		nums[i] *= 2
	}
	assert nums.str() == '[2, 4, 6, 8, 10]'
}

struct Test2 {
	one int
	two int
}

struct Test {
	a string
mut:
	b []Test2
}

fn (t Test2) str() string {
	return '{$t.one $t.two}'
}

fn (t Test) str() string {
	return '{$t.a $t.b}'
}

fn testXstruct_print() {
	mut a := Test {
		a: 'Test',
		b: []Test2
	}
	b := Test2 {
		one: 1,
		two: 2
	}
	a.b << b
	a.b << b
	assert a.str() == '{Test [{1 2}, {1 2}] }'
	assert b.str() == '{1 2}'
	assert a.b.str() == '[{1 2}, {1 2}]'
}