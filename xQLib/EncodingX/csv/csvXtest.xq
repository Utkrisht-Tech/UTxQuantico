// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

import EncodingX.csv

fn testXencoding_csv_reader() {
	data := 'name,email,phone,other\nutx,utx@utkrisht-tech.com,0400000000,test\nutx10101,utx10101@utkrisht-tech.com,0433000000,"test quoted field"\n#UTX,UTX@nomail.com,94444444,"commented row"\nUTX10101,UTX10101@mUtkrisht-Tech.com,98888888,"Utkrisht-Tech:UTx10101"\n'
	mut csv_reader := csv.new_reader(data)

	mut row_count := 0
	for {
		row := csv_reader.read() or {
			break
		}
		row_count++
		if row_count== 1 {
			assert row[0] == 'name'
		}
		if row_count == 2 {
			assert row[0] == 'utx'
		}
		if row_count == 3 {
			assert row[0] == 'utx10101'
			// quoted field
			assert row[3] == 'test quoted field'
		}
		if row_count == 4 {
			assert row[0] == 'UTX10101'
		}
	}

	assert row_count == 4
}

fn testXencoding_csv_writer() {
	mut csv_writer := csv.new_writer()

	csv_writer.write(['name', 'email', 'phone', 'other'])
	csv_writer.write(['utx', 'utx@utkrisht-tech.com', '0400000000', 'test'])
	csv_writer.write(['utx10101', 'utx10101@utkrisht-tech.com', '0433000000', 'needs, quoting'])

	assert csv_writer.str() == 'name,email,phone,other\nutx,utx@utkrisht-tech.com,0400000000,test\nutx10101,utx10101@utkrisht-tech.com,0433000000,"needs, quoting"\n'
}