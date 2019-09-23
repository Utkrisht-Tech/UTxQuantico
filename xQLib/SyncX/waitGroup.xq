// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module SyncX

struct WaitGroup {
mut:
	mu Mutex
	active int
}

public fn (wg mut WaitGroup) add(delta int) {
	wg.mu.lock()
	wg.active += delta
	wg.mu.unlock()
	if wg.active < 0 {
		panic('Negative number of jobs in waitgroup')
	}
}

public fn (wg mut WaitGroup) done() {
	wg.add(-1)
}

public fn (wg mut WaitGroup) wait() {
	for wg.active > 0 {
		// waiting
	}
}