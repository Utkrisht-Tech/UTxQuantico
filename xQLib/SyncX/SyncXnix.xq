// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module SyncX

#include <pthread.h>
struct Mutex {
	mutex C.pthread_mutex_t
}

public fn (m mut Mutex) lock() {
	C.pthread_mutex_lock(&m.mutex)
}

public fn (m mut Mutex) unlock() {
	C.pthread_mutex_unlock(&m.mutex)
}