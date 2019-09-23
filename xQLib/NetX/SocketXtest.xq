// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

import NetX

fn testXsocket() {
	mut server := NetX.listen(0) or {
		println(err)
		return
	}    
	server_port := server.get_port()
	mut client := NetX.dial('127.0.0.1', server_port) or {
		println(err)
		return
	}
	mut socket := server.accept() or {
		println(err)
		return
	}

	message := 'Hello World'
	socket.send(message.str, message.len)	

	bytes := client.recv(1024)
	received := tos(bytes, message.len)

	assert message == received

	server.close()
	client.close()
	socket.close()
}