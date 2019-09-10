// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module csv

// Once interfaces are further along the idea would be to have something similar to
// go's io.reader & bufio.reader rather than reading the whole file into string, this
// would then satisfy that interface. Ii is designed in a way to be easily adapted.

const (
	err_comment_is_delimiter = error('EncodingX.csv: comment cannot be the same as delimiter')
	err_invalid_delimiter    = error('EncodingX.csv: invalid delimiter')
	err_eof                  = error('EncodingX.csv: end of file')
	err_invalid_line_end     = error('EncodingX.csv: could not find any valid line endings.')
)


struct Reader  {
	// not used yet
	// has_header        bool
	// headings          []string
	data              string
public:
mut:
	delimiter         byte
	comment           byte
	is_mac_pre_osx_line_end bool
	row_pos_y         int
}

public fn new_reader(data string) &Reader {
	return &Reader{
		delimiter: `,`,
		comment: `#`,
		data: data
	}
}

// read() reads one row from the csv file
public fn (xR mut Reader) read() ?[]string {
	l := xR.read_record() or {
		return error(err)
	}
	return l
}

// Once we have multi dimensional array
// public fn (xR mut Reader) read_all() ?[][]string {
// 	mut records := []string
// 	for {
// 		record := xR.read_record() or {
// 			if error(err).error == err_eof.error {
// 				return records
// 			} else {
// 				return error(err)
// 			}
// 		}
// 		records << record
// 	}
// 	return records
// }

fn (xR mut Reader) read_line() ?string {
	// last record
	if xR.row_pos_y == xR.data.len {
		return err_eof
	}
	line_end := if xR.is_mac_pre_osx_line_end { '\r' } else { '\n' }
	mut i := xR.data.index_after(line_end, xR.row_pos_y)
	if i == -1 {
		if xR.row_pos_y == 0 {
			// check for pre osx mac line endings
			i = xR.data.index_after('\r', xR.row_pos_y)
			if i != -1 {
				xR.is_mac_pre_osx_line_end = true
			} else {
				// no valid line endings found
				return err_invalid_line_end
			}
		}
	}
	mut line := xR.data.substr(xR.row_pos_y, i)
	xR.row_pos = i+1
	// normalize windows line endings (remove extra \r)
	if !xR.is_mac_pre_osx_line_end && (line.len >= 1 && line[line.len-1] == `\r`) {
		line = line.left(line.len-1)
	}
	return line
}

fn (xR mut Reader) read_record() ?[]string {
	if xR.delimiter == xR.comment {
		return err_comment_is_delimiter
	}
	if !valid_delimiter(xR.delimiter) {
		return err_invalid_delimiter
	}
	mut line := ''
	for {
		l := xR.read_line() or {
			return error(err)
		}
		line = l
		// skip commented lines
		if line[0] == xR.comment {
			continue
		}
		break
	}
	mut fields := []string
	mut i := -1
	for {
		// not quoted
		if line[0] != `"` {
			i = line.index(xR.delimiter.str())
			if i == -1 {
				// last
				break
			}
			fields << line.left(i)
			line = line.right(i+1)
			continue
		}
		// quoted
		else {
			line = line.right(1)
			i = line.index('"')
			if i != -1 {
				if i+1 == line.len {
					// last record
					fields << line.left(i)
					break
				}
				next := line[i+1]
				if next == xR.delimiter {
					fields << line.left(i)
					line = line.right(i)
					continue
				}
			}
			line = line.right(1)
		}
		if i <= -1 && fields.len == 0 {
			return err_invalid_delimiter
		}
	}
	
	return fields
}

fn valid_delimiter(b byte) bool {
	return b != 0 &&
		   b != `"` &&
		   b != `\r` &&
		   b != `\n`
}