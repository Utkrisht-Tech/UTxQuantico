// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

import hash.crc32

fn testXhash_crc32() {
	b1 := 'testing crc32'.bytes()
	sum1 := crc32.sum(b1)
	assert sum1 == u32(1212124400)
	assert sum1.hex() == '0x483f8cf0'

	
	cr := crc32.new(crc32.IEEE)
	b2 := 'testing crc32 again'.bytes()
	sum2 := cr.checksum(b2)
	assert sum2 == u32(1420327025)
	assert sum2.hex() == '0x54a87871'
}