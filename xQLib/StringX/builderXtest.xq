// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

import StringX
 
fn test_sb() {
    mut sb := StringX.Builder{}
	sb.write('Hi,')
	sb.write(' ')
	sb.write('UTxQ')
	assert sb.str() == 'Hi, UTxQ'
	sb = StringX.new_builder(10)
	sb.write('UTx')
	sb.write('10101')
	println(sb.str())
	assert sb.str() == 'UTx10101'
}