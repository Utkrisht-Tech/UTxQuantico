// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

import NetX

fn start_socket_udp_server() {
	bufsize := 1024
	bytes := [1024]byte
	s := NetX.socket_udp() or { panic(err) }
	_ = s.bind( 9876 ) or { panic(err) }
	println('Waiting for udp packets:')
	for {
		res := s.crecv(bytes, bufsize)
		if res < 0 { break }
		print('Received $res bytes: ' + tos(bytes, res))
	}
}

fn test_udp_server() {
	// start_socket_udp_server()
}