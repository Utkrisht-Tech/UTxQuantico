// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module PgSQL

import os
import time

#flag -lpq
#flag linux -I/usr/include/postgresql
#flag darwin -I/opt/local/include/postgresql11
#include <libpq-fe.h>

struct DB {
mut:
	conn &C.PGconn
}

struct Row {
public mut:
	vals []string
}

struct C.PGResult { }

struct Config {
public:
  host string
  user string
  password string
  dbname string
}

fn C.PQconnectdb(a byteptr) &C.PGconn
fn C.PQerrorMessage(voidptr) byteptr 
fn C.PQgetvalue(voidptr, int, int) byteptr
fn C.PQstatus(voidptr) int 

public fn connect(config PgSQL.Config) DB {
	conninfo := 'host=$config.host user=$config.user dbname=$config.dbname'
	conn:=C.PQconnectdb(conninfo.str)
	status := C.PQstatus(conn)
	if status != C.CONNECTION_OK { 
		error_msg := C.PQerrorMessage(conn) 
		eprintln('Connection to a PostGreSQL database failed: ' + string(error_msg)) 
		exit(1) 
	}
	return DB {conn: conn} 
}

fn res_to_rows(res voidptr) []PgSQL.Row {
	no_of_rows := C.PQntuples(res) 
	no_of_cols := C.PQnfields(res) 
	mut rows := []PgSQL.Row
	for i := 0; i < no_of_rows; i++ {
		mut row := Row{}
		for j := 0; j < no_of_cols; j++ {
			val := C.PQgetvalue(res, i, j) 
			row.vals << string(val)
		}
		rows << row
	}
	return rows
}

public fn (db DB) q_int(query string) int {
	rows := db.exec(query)
	if rows.len == 0 {
		println('q_int "$query" not found')
		return 0
	}
	row := rows[0]
	if row.vals.len == 0 {
		return 0
	}
	val := row.vals[0]
	return val.int() 
}

public fn (db DB) q_string(query string) string {
	rows := db.exec(query)
	if rows.len == 0 {
		println('q_string "$query" not found')
		return ''
	}
	row := rows[0]
	if row.vals.len == 0 {
		return ''
	}
	val := row.vals[0]
	return val
}

public fn (db DB) q_strings(query string) []PgSQL.Row {
	return db.exec(query)
}

public fn (db DB) exec(query string) []PgSQL.Row {
	res := C.PQexec(db.conn, query.str)
	e := string(C.PQerrorMessage(db.conn))
	if e != '' {
		println('PostGreSQL exec error:')
		println(e)
		return res_to_rows(res)
	}
	return res_to_rows(res)
}

fn rows_first_or_empty(rows []PgSQL.Row) PgSQL.Row? {
	if rows.len == 0 {
		return error('no row')
	} 
	return rows[0]
}
            
public fn (db DB) exec_one(query string) PgSQL.Row? {
	res := C.PQexec(db.conn, query.str)
	e := string(C.PQerrorMessage(db.conn))
	if e != '' {
		return error('PostGreSQL exec error: "$e"')
	}
	row := rows_first_or_empty( res_to_rows(res) )
	return row
}

// 
public fn (db DB) exec_param2(query string, param, param2 string) []PgSQL.Row {
	mut param_vals := [2]byteptr
	param_vals[0] = param.str
	param_vals[1] = param2.str
	res := C.PQexecParams(db.conn, query.str, 2, 0, param_vals, 0, 0, 0)
	e := string(C.PQerrorMessage(db.conn))
	if e != '' {
		println('PostGreSQL exec2 error:')
		println(e)
		return res_to_rows(res)
	}
	return res_to_rows(res)
}

public fn (db DB) exec_param(query string, param string) []PgSQL.Row {
	mut param_vals := [1]byteptr
	param_vals[0] = param.str
	res := C.PQexecParams(db.conn, query.str, 1, 0, param_vals, 0, 0, 0)
	return res_to_rows(res)
}