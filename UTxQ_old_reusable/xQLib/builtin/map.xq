// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module builtin

import StringX

struct map {
	element_size int
	root      &mapnode
public:
	size int
}

struct mapnode {
	left &mapnode
	right &mapnode
	is_empty bool
	key string
	val voidptr
}

fn new_map(cap, elem_size int) map {
	res := map {
		element_size: elem_size
		root: 0
	}
	return res
}

// `m := { 'one': 1, 'two': 2 }`
fn new_map_init(cap, elem_size int, keys &string, vals voidptr) map {
	mut res := map {
		element_size: elem_size
		root: 0
	}
	for i in 0 .. cap {
		res._set(keys[i], vals + i * elem_size)
	}
	return res
}

fn new_node(key string, val voidptr, element_size int) &mapnode {
	new_e := &mapnode {
		key: key
		val: malloc(element_size)
		left: 0
		right: 0
	}
	C.memcpy(new_e.val, val, element_size)
	return new_e
}

fn (m mut map) insert(n mut mapnode, key string, val voidptr) {
	if n.key == key {
		C.memcpy(n.val, val, m.element_size)
		return
	}
	if n.key > key {
		if isnull(n.left) {
			n.left = new_node(key, val, m.element_size)
			m.size++
		}  else {
			m.insert(mut n.left, key, val)
		}
		return
	}
	if isnull(n.right) {
		n.right = new_node(key, val, m.element_size)
		m.size++
	}  else {
		m.insert(mut n.right, key, val)
	}
}

fn (n & mapnode) find(key string, out voidptr, element_size int) bool{
	if n.key == key {
		C.memcpy(out, n.val, element_size)
		return true
	}
	else if n.key > key {
		if isnull(n.left) {
			return false
		}  else {
			return n.left.find(key, out, element_size)
		}
	}
	else {
		if isnull(n.right) {
			return false
		}  else {
			return n.right.find(key, out, element_size)
		}
	}
}

// same as `find`, but doesn't return a value. Used by `exists`
fn (n & mapnode) find2(key string, element_size int) bool{
	if n.key == key {
		return true
	}
	else if n.key > key {
		if isnull(n.left) {
			return false
		}  else {
			return n.left.find2(key, element_size)
		}
	}
	else {
		if isnull(n.right) {
			return false
		}  else {
			return n.right.find2(key, element_size)
		}
	}
}

fn (m mut map) _set(key string, val voidptr) {
	if isnull(m.root) {
		m.root = new_node(key, val, m.element_size)
		m.size++
		return
	}
	m.insert(mut m.root, key, val)
}

/*
fn (m map) bs(query string, start, end int, out voidptr) {
	// println('bs "$query" $start -> $end')
	mid := start + ((end - start) / 2)
	if end - start == 0 {
		last := m.entries[end]
		C.memcpy(out, last.val, m.element_size)
		return
	}
	if end - start == 1 {
		first := m.entries[start]
		C.memcpy(out, first.val, m.element_size)
		return
	}
	if mid >= m.entries.len {
		return
	}
	mid_msg := m.entries[mid]
	// println('mid.key=$mid_msg.key')
	if query < mid_msg.key {
		m.bs(query, start, mid, out)
		return
	}
	m.bs(query, mid, end, out)
}
*/

fn preorder_keys(node &mapnode, keys mut []string, key_i int) int {
	mut i := key_i
	if !node.is_empty {
		keys[i] = node.key
		i++
	}
	if !isnull(node.left) {
		i = preorder_keys(node.left, mut keys, i)
	}
	if !isnull(node.right) {
		i = preorder_keys(node.right, mut keys, i)
	}
	return i
}

public fn (m &map) keys() []string {
	mut keys := [''].repeat(m.size)
	if isnull(m.root) {
		return keys
	}
	preorder_keys(m.root, mut keys, 0)
	return keys
}

fn (m map) get(key string, out voidptr) bool {
	if isnull(m.root) {
		return false
	}
	return m.root.find(key, out, m.element_size)
}

public fn (n mut mapnode) delete(key string, element_size int) {
	if n.key == key {
		C.memset(n.val, 0, element_size)
		n.is_empty = true
		return
	}
	else if n.key > key {
		if isnull(n.left) {
			return
		}  else {
			n.left.delete(key, element_size)
		}
	}
	else {
		if isnull(n.right) {
			return
		}  else {
			n.right.delete(key, element_size)
		}
	}
}

public fn (m mut map) delete(key string) {
	m.root.delete(key, m.element_size)
	m.size--
}

public fn (m map) exists(key string) {
	panic('map.exists(key) was removed from the language. Use `key in map` instead.')
}

fn (m map) _exists(key string) bool {
	return !isnull(m.root) && m.root.find2(key, m.element_size)
}

public fn (m map) print() {
	println('<<<<<<<<')
	//for i := 0; i < m.entries.len; i++ {
		// entry := m.entries[i]
		// println('$entry.key => $entry.val')
	//}
	/*
	for i := 0; i < m.cap * m.element_size; i++ {
		b := m.table[i]
		print('$i: ')
		C.printf('%02x', b)
		println('')
	}
*/
	println('>>>>>>>>>>')
}

fn (n mut mapnode) free() {
	if n.val != 0 {
		free(n.val)
	}	
	if n.left != 0 {
		n.left.free()
	}	
	if n.right != 0 {
		n.right.free()
	}	
	free(n)
}

public fn (m mut map) free() {
	if m.root == 0 {
		return
	}	
	m.root.free()
	// C.free(m.table)
	// C.free(m.keys_table)
}

public fn (m map_string) str() string {
	if m.size == 0 {
		return '{}'
	}
	mut sb := StringX.new_builder(50)
	sb.writeln('{')
	for key, val  in m {
		sb.writeln('  "$key" => "$val"')
	}
	sb.writeln('}')
	return sb.str()
}