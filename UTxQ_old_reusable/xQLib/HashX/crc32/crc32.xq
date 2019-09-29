// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

// This is a very basic crc32 implementation
// at the moment with no architecture optimizations
module crc32

// polynomials
const (
	IEEE       = 0xedb88320
	Castagnoli = 0x82f63b78
	Koopman    = 0xeb31d82e
)

// The size of a CRC-32 checksum in bytes.
const (
	Size = 4
)

struct Crc32 {
mut:
	table []u32
}

fn(cr mut Crc32) generate_table(poly int) {
	for i := 0; i < 256; i++ {
		mut crc := u32(i)
		for j := 0; j < 8; j++ {
			if crc&u32(1) == u32(1) {
				crc = u32((crc >> u32(1)) ^ poly)
			} else {
				crc >>= u32(1)
			}
		}
		cr.table << crc
	}
}
 
fn(cr &Crc32) sum32(b []byte) u32 {
	mut crc := ~u32(0)
	for i := 0; i < b.len; i++ {
		crc = cr.table[byte(crc)^b[i]] ^ u32(crc >> u32(8))
	}
	return ~crc
}

public fn(cr &Crc32) checksum(b []byte) u32 {
	return cr.sum32(b)
}

// Pass the polinomial to use
public fn new(poly int) &Crc32 {
	mut cr := &Crc32{}
	cr.generate_table(poly)
	return cr
}

// Calculate crc32 using IEEE
public fn sum(b []byte) u32 {
	mut cr := new(IEEE)
	return cr.sum32(b)
}