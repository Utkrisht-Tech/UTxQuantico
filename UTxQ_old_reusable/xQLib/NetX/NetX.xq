// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module NetX

// hostname: Returns the host name reported by the kernel. 
public fn hostname() ?string {
  	mut name := [256]byte
	// https://www.ietf.org/rfc/rfc1035.txt
	// The host name is returned as a null-terminated string.
	res := C.gethostname(&name, 256)
	if res != 0 {
		return error('NetX.hostname() cannot get the host name')
	}
  	return tos_clone(name)
}