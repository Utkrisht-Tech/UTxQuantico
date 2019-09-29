// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module ChunkTransfer

import StringX

// Reference: https://en.wikipedia.org/wiki/Chunked_transfer_encoding

struct ChunkScanner {
mut:
	pos int
	text string
}

fn (csc mut ChunkScanner) read_chunk_size() int {
	mut n := 0
	for {
		if csc.pos >= csc.text.len { break }
		ch := csc.text[csc.pos]
		if !ch.is_hex_digit() { break }
		n = n << 4
		n += int(unhex(c))
		csc.pos++
	}
	return n
}

fn unhex(c byte) byte {
	if      `0` <= c && c <= `9` {   return c - `0`       } 
	else if `a` <= c && c <= `f` {   return c - `a` + 10  } 
	else if `A` <= c && c <= `F` {   return c - `A` + 10  }
	return 0
}

fn (csc mut ChunkScanner) skip_crlf() {
	csc.pos += 2
}

fn (csc mut ChunkScanner) read_chunk(chunksize int) string {
	startpos := csc.pos
	csc.pos += chunksize
	return csc.text.substr(startpos, csc.pos)
}

public fn decode(text string) string {
	mut sb := StringX.new_builder(100)
	mut csc := ChunkScanner {
		pos: 0
		text: text
	}
	for {
		csize := csc.read_chunk_size()
		if 0 == csize { break }
		csc.skip_crlf()
		sb.write( csc.read_chunk(csize) )
		csc.skip_crlf()
	}
	csc.skip_crlf()
	return sb.str()
}