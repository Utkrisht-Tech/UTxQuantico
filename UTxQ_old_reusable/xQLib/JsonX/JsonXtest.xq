// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

import JsonX

struct User {
	age       	int
	nums      	[]int
	last_name 	string 	[json:lastName]
	is_registered	bool 	[json:IsRegistered]
}

fn testXparse_user() {
	s := '{"age": 10, "nums": [1,2,3], "lastName": "Johnson", "IsRegistered": true}'
	u := JsonX.decode(User, s) or {
		exit(1)
	}
	assert u.age == 10
	assert u.last_name == 'Johnson'
	assert u.is_registered == true
	assert u.nums.len == 3
	assert u.nums[0] == 1
	assert u.nums[1] == 2
	assert u.nums[2] == 3
}

fn testXencode_user(){
	usr := User{ age: 10, nums: [1,2,3], last_name: 'Johnson', is_registered: true}
	expected := '{"age":10,"nums":[1,2,3],"lastName":"Johnson","IsRegistered":true}'
	out := JsonX.encode(usr)
	assert out == expected
}

struct Color {
    space string
    point string [raw]
}

fn testXraw_json_field() {
    color := JsonX.decode(Color, '{"space": "YCbCr", "point": {"Y": 123}}') or {
        println('text')
        return
    }
    assert color.point == '{"Y":123}'
    assert color.space == 'YCbCr'
}