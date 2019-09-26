// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module StringX

public fn repeat(ch byte, n int) string {
	if n <= 0 {
		return ''
	}
	mut arr := [ch].repeat(n + 1)
	arr[n] = `\0`
	return string(arr, n)
}