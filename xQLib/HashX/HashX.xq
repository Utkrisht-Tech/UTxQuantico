// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module HashX

interface HashX {
	// Sum appends the current hash to b and returns the resulting array.
	// It does not change the underlying hash state.
	sum(b []byte) []byte
	size() int
	block_size() int
}

interface HashX32 {
	sum32() u32
}

interface HashX64 {
	sum64() u64
}