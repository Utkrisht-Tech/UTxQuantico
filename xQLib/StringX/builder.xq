// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module StringX 

struct Builder {
mut: 
	buf []byte
public:
	len int
}

public fn new_builder(initial_size int) Builder {
	return Builder {
		buf: _make(0, initial_size, sizeof(byte))
	}
}

public fn (bu mut Builder) write(s string) {
	bu.buf._push_many(s.str, s.len)
	//bu.buf << []byte(s)  // TODO 
	bu.len += s.len
}

public fn (bu mut Builder) writeln(s string) {
	bu.buf._push_many(s.str, s.len)
	//bu.buf << []byte(s)  // TODO 
	bu.buf << `\n`
	bu.len += s.len + 1
}

public fn (bu Builder) str() string {
	return string(bu.buf, bu.len)
}

public fn (bu mut Builder) cut(n int) {
	bu.len -= n
}

public fn (bu mut Builder) free() {
	free(bu.buf.data)
}