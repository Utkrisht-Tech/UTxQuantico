// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module rand

public fn seed(s int) {
	C.srand(s)
}

public fn next(max int) int {
	return C.rand() % max
}

fn C.rand() int

/**
 * rand_r: Reentrant pseudo-random number generator
 *
 * @param seed byref reentrant seed, holding current state
 *
 * @return a value between 0 and C.RAND_MAX (inclusive)
 */
public fn rand_r(seed &int) int {
	mut rs := seed
	ns := ( *rs * 1103515245 + 12345 )
	*rs = ns
	return ns & 0x7fffffff
}