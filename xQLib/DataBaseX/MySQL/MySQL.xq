// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module MySQL

#flag -lmysqlclient
#include <mysql.h>

struct DB {
	conn *C.MYSQL
}

struct Result {
	result *C.MYSQL_RES
}

struct Row {
public mut:
	vals []string
}

// C - Functions

struct C.MYSQL { }
struct C.MYSQL_RES { }

fn C.mysql_init(mysql *C.MYSQL) *C.MYSQL
fn C.mysql_real_connect(mysql *C.MYSQL, host byteptr, user byteptr, passwd byteptr, db byteptr, port u32, unix_socket byteptr, clientflag u64) *C.MYSQL
fn C.mysql_query(mysql *C.MYSQL, q byteptr) int
fn C.mysql_error(mysql *C.MYSQL) byteptr
fn C.mysql_num_fields(res *C.MYSQL_RES) int
fn C.mysql_store_result(mysql *C.MYSQL) *C.MYSQL_RES
fn C.mysql_fetch_row(res *C.MYSQL_RES) &byteptr
fn C.mysql_free_result(res *C.MYSQL_RES)
fn C.mysql_close(sock *C.MYSQL)

// UTxQ - Functions

public fn connect(server, user, passwd, dbname string) DB {
	conn := C.mysql_init(0)
	if isnull(conn) {
		eprintln('mysql_init failed')
		exit(1)
	}
	conn2 := C.mysql_real_connect(conn, server.str, user.str, passwd.str, dbname.str, 0, 0, 0)
	if isnull(conn2) {
		eprintln('mysql_real_connect failed')
		exit(1)
	}
	return DB {conn: conn2}
}

public fn (db DB) query(q string) Result {
	ret := C.mysql_query(db.conn, q.str)
	if ret != 0 {
		C.fprintf(stderr, '%s\n', mysql_error(db.conn))
		exit(1)
	}
	res := C.mysql_store_result(db.conn)
	return Result {result: res}
}

public fn (db DB) close() {
	C.mysql_close(db.conn)
}

public fn (r Result) fetch_row() &byteptr {
	return C.mysql_fetch_row(r.result)
}

public fn (r Result) num_fields() int {
	return C.mysql_num_fields(r.result)
}

public fn (r Result) rows() []Row {
	mut rows := []Row
	no_of_cols := r.num_fields()
	for rr := r.fetch_row(); rr; rr = r.fetch_row() {
		mut row := Row{}
		for i := 0; i < no_of_cols; i++ {
			if rr[i] == 0 {
				row.vals << ''
			} else {
				row.vals << string(rr[i])
			}
		}
		rows << row
	}
	return rows
}

public fn (r Result) free() {
	C.mysql_free_result(r.result)
}