// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module bits

// --- RotateLeft ---

// rotate_left_8: Returns the value of x rotated left by (k mod 8) bits.
//                To rotate x right by k bits, call rotate_left_8(x, -k).
//
//                This function's execution time does not depend on the inputs.
public fn rotate_left_8(x byte, k int) byte {
	n := byte(8)
	s := byte(k) & byte(n - byte(1))
	return byte((x<<s) | (x>>(n-s)))
}

// rotate_left_16: Returns the value of x rotated left by (k mod 16) bits.
//                 To rotate x right by k bits, call rotate_left_16(x, -k).
//
//                 This function's execution time does not depend on the inputs.
public fn rotate_left_16(x u16, k int) u16 {
	n := u16(16)
	s := u16(k) & (n - u16(1))
	return u16((x<<s) | (x>>(n-s)))
}

// rotate_left_32: Returns the value of x rotated left by (k mod 32) bits.
//                 To rotate x right by k bits, call rotate_left_32(x, -k).
//
//                 This function's execution time does not depend on the inputs.
public fn rotate_left_32(x u32, k int) u32 {
	n := u32(32)
	s := u32(k) & (n - u32(1))
	return u32(u32(x<<s) | u32(x>>(n-s)))
}

// rotate_left_64: Returns the value of x rotated left by (k mod 64) bits.
//                 To rotate x right by k bits, call rotate_left_64(x, -k).
//
//                 This function's execution time does not depend on the inputs.
public fn rotate_left_64(x u64, k int) u64 {
	n := u64(64)
	s := u64(k) & (n - u64(1))
	return u64(u64(x<<s) | u64(x>>(n-s)))
}