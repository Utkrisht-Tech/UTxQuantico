// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module SyncX

// Mutex HANDLE
type MHANDLE voidptr

struct Mutex {
mut:
	mx           MHANDLE    // Mutex handle
	state        MutexState // Mutex state
	cycle_wait   i64        // Waiting cycles (implemented only with atomic)
	cycle_woken  i64        // Woken cycles
	reader_sem   u32        // Reader semarphone
	writer_sem   u32        // Writer semarphones
}

enum MutexState {
	broken
	waiting
	released
	abandoned
	destroyed
}

const (
	INFINITE = 0xffffffff
)

// Reference: https://docs.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitforsingleobject#return-value
const (
	WAIT_ABANDONED     = 0x00000080
	WAIT_IO_COMPLETION = 0x000000C0
	WAIT_OBJECT_0      = 0x00000000
	WAIT_TIMEOUT       = 0x00000102
	WAIT_FAILED        = 0xFFFFFFFF
)

public fn (m mut Mutex) lock() {
	// if mutex handle not initalized
	if isnull(m.mx) {
		m.mx = C.CreateMutex(0, false, 0)
		if isnull(m.mx) {
			m.state = .broken // Handle broken and mutex state are broken
			return
		}
	}
	state := C.WaitForSingleObject(m.mx, INFINITE) // Infinite wait
	m.state = match state {
		WAIT_ABANDONED => { MutexState.abandoned }
		WAIT_OBJECT_0  => { MutexState.waiting }
		else           => { MutexState.broken }
	}
}

public fn (m mut Mutex) unlock() {
	if m.state == .waiting {
		if C.ReleaseMutex(m.mx) != 0 {
			m.state = .broken
			return
		}
	}
	m.state = .released
}

public fn (m mut Mutex) destroy() {
	if m.state == .waiting {
		m.unlock() // Unlock mutex before destroying
	}
	C.CloseHandle(m.mx)  // Destroy mutex
	m.state = .destroyed // Setting up reference to invalid state
}