// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module HttpX

import NetX
import StringX

fn (req &Request) http_do(port int, method, host_name, path string) ?Response {
	bufsize := 512
	rbuffer := [512]byte
	mut sb := StringX.new_builder(100)
	s := req.build_request_headers(method, host_name, path)
	
	client := NetX.dial( host_name, port) or { return error(err) }
	client.send( s.str, s.len )
	for {
		readbytes := client.crecv( rbuffer, bufsize )
		if readbytes  < 0 { return error('http_do error reading response. readbytes: $readbytes') }
		if readbytes == 0 { break }
		sb.write( tos(rbuffer, readbytes) )
	}
	client.close()
	return parse_response(sb.str())
}