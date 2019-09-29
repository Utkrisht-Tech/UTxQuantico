// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

fn test_utf8_char_len() {
	assert utf8_char_len(`a`) == 1 
	s := 'п' 
	assert utf8_char_len(s[0]) == 2 
}