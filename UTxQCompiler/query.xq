// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import strings

fn SqlX_params2params_gen(SqlX_params []string, SqlX_types []string, qprefix string) string {
	mut params_gen := ''
	for i, mparam in SqlX_params {
		param := mparam.trim_space()
		paramtype := SqlX_types[ i ]
		if param[0].is_digit() {
			params_gen += '${qprefix}params[$i] = int_str($param).str;\n'
		}else if param[0] == `\'` {
			sparam := param.trim('\'')
			params_gen += '${qprefix}params[$i] = "$sparam";\n'
		} else {
			// A variable like q.nr_orders
			if paramtype == 'int' {
				params_gen += '${qprefix}params[$i] = int_str( $param ).str;\n'
			}else if paramtype == 'string' {
				params_gen += '${qprefix}params[$i] = ${param}.str;\n'
			}else{
				cerror('orm: only int and string variable types are supported in queries')
			}
		}
	}
	//println('>>>>>>>> params_gen')
	//println( params_gen )
	return params_gen
}

// `db.select from User where id == 1 && nr_bookings > 0`
fn (xP mut Parser) select_query(fn_sh int) string {
	// NB: qprefix and { xP.SqlX_i, xP.SqlX_params, xP.SqlX_types } SHOULD be reset for each query,
	// because we can have many queries in the _same_ scope.
	qprefix := xP.get_tmp().replace('tmp','SqlX') + '_'
	xP.SqlX_i = 0
	xP.SqlX_params = []string
	xP.SqlX_types = []string

	mut q := 'select '
	xP.check(.key_select)
	n := xP.check_name()
	if n == 'count' {
		q += 'count(*) from '
		xP.check_name()
	}
	table_name := xP.check_name()
	// Register this type's fields as variables so they can be used in where expressions
	typ := xP.table.find_type(table_name)
	if typ.name == '' {
		xP.error('unknown type `$table_name`')
	}
	//fields := typ.fields.filter(typ == 'string' || typ == 'int')
	// get only string and int fields
	mut fields := []Var
	for i, field in typ.fields {
		if field.typ != 'string' && field.typ != 'int' {
			continue
		}
		fields << field
	}
	if fields.len == 0 {
		xP.error('UTxQ orm: select: empty fields in `$table_name`')
	}
	if fields[0].name != 'id' {
		xP.error('UTxQ orm: `id int` must be the first field in `$table_name`')
	}
	// 'select id, name, age from...'
	if n == 'from' {
		for i, field in fields {
			q += field.name
			if i < fields.len - 1 {
				q += ', '
			}
		}
		q += ' from '
	}
	for field in fields {
		//println('registering SqlX field var $field.name')
		if field.typ != 'string' && field.typ != 'int' {
			continue
		}
		xP.cur_fn.register_var({ field | is_used:true })
	}
	q += table_name
	// `where` statement
	if xP.tk == .NAME && xP.lit == 'where' {
		xP.next()
		xP.cgen.start_tmp()
		xP.is_SqlX = true
		xP.bool_expression()
		xP.is_SqlX = false
		q += ' where ' + xP.cgen.end_tmp()
	}
	// limit?
	mut query_one := false
	if xP.tk == .NAME && xP.lit == 'limit' {
		xP.next()
		xP.cgen.start_tmp()
		xP.is_SqlX = true
		xP.bool_expression()
		xP.is_SqlX = false
		limit := xP.cgen.end_tmp()
		q += ' limit ' + limit
		// `limit 1` means we are getting `?User`, not `[]User`
		if limit.trim_space() == '1' {
			query_one = true
		}
	}
	println('SqlX query="$q"')
	xP.cgen.insert_before('// DEBUG_SQLX prefix: $qprefix | fn_sh: $fn_sh | query: "$q" ')

	if n == 'count' {
		xP.cgen.set_shadow(fn_sh, 'pg__DB_q_int(')
		xP.gen(', tos2("$q"))')
	} else {
		// Build an object, assign each field.
		tmp := xP.get_tmp()
		mut obj_gen := strings.new_builder(300)
		for i, field in fields {
			mut cast := ''
			if field.typ == 'int' {
				cast = 'xQ_string_int'
			}
			obj_gen.writeln('${qprefix}$tmp . $field.name = $cast( *(string*)array__get(${qprefix}row.vals, $i) );')
		}
		// One object
		if query_one {
			mut params_gen := SqlX_params2params_gen( xP.SqlX_params, xP.SqlX_types, qprefix )
			xP.cgen.insert_before('

char* ${qprefix}params[$xP.SqlX_i];
$params_gen

Option_${table_name} opt_${qprefix}$tmp;
void* ${qprefix}res = PQexecParams(db.conn, "$q", $xP.SqlX_i, 0, ${qprefix}params, 0, 0, 0)  ;
array_pg__Row ${qprefix}rows = pg__res_to_rows ( ${qprefix}res ) ;
Option_pg__Row opt_${qprefix}row = pg__rows_first_or_empty( ${qprefix}rows );
if (! opt_${qprefix}row . ok ) {
   opt_${qprefix}$tmp = v_error( opt_${qprefix}row . error );
}else{
   $table_name ${qprefix}$tmp;
   pg__Row ${qprefix}row = *(pg__Row*) opt_${qprefix}row . data;
${obj_gen.str()}
   opt_${qprefix}$tmp = opt_ok( & ${qprefix}$tmp, sizeof($table_name) );
}

')
			xP.cgen.resetln('opt_${qprefix}$tmp')
		}
		// Array
		else {
			q += ' order by id'
			params_gen := SqlX_params2params_gen( xP.SqlX_params, xP.SqlX_types, qprefix )
			xP.cgen.insert_before('char* ${qprefix}params[$xP.SqlX_i];
$params_gen

void* ${qprefix}res = PQexecParams(db.conn, "$q", $xP.SqlX_i, 0, ${qprefix}params, 0, 0, 0)  ;
array_pg__Row ${qprefix}rows = pg__res_to_rows(${qprefix}res);

// TODO preallocate
array ${qprefix}arr_$tmp = new_array(0, 0, sizeof($table_name));
for (int i = 0; i < ${qprefix}rows.len; i++) {
    pg__Row ${qprefix}row = *(pg__Row*)array__get(${qprefix}rows, i);
    $table_name ${qprefix}$tmp;
    ${obj_gen.str()}
    _PUSH(&${qprefix}arr_$tmp, ${qprefix}$tmp, ${tmp}2, $table_name);
}
')
			xP.cgen.resetln('${qprefix}arr_$tmp')
}

	}
	if n == 'count' {
		return 'int'
	}	else if query_one {
		opt_type := 'Option_$table_name'
		xP.cgen.typedefs << 'typedef Option $opt_type;'
		xP.table.register_type( opt_type )
		return opt_type
	}  else {
		xP.register_array('array_$table_name')
		return 'array_$table_name'
	}
}

// `db.insert(user)`
fn (xP mut Parser) insert_query(fn_sh int) {
	xP.check_name()
	xP.check(.LPAR)
	var_name := xP.check_name()
	xP.check(.RPAR)
	var := xP.cur_fn.find_var(var_name)
	typ := xP.table.find_type(var.typ)
	mut fields := []Var
	for i, field in typ.fields {
		if field.typ != 'string' && field.typ != 'int' {
			continue
		}
		fields << field
	}
	if fields.len == 0 {
		xP.error('UTxQ orm: insert: empty fields in `$var.typ`')
	}
	if fields[0].name != 'id' {
		xP.error('UTxQ orm: `id int` must be the first field in `$var.typ`')
	}
	table_name := var.typ
	mut sfields := ''  // 'name, city, country'
	mut params := '' // params[0] = 'bob'; params[1] = 'Tom';
	mut vals := ''  // $1, $2, $3...
	mut nr_vals := 0
	for i, field in fields {
		if field.name == 'id' {
			continue
		}
		sfields += field.name
		vals += '$' + i.str()
		nr_vals++
		params += 'params[${i-1}] = '
		if field.typ == 'string' {
			params += '$var_name . $field.name .str;\n'
		}  else if field.typ == 'int' {
			params += 'int_str($var_name . $field.name).str;\n'
		} else {
			xP.error('UTxQ ORM: unsupported type `$field.typ`')
		}
		if i < fields.len - 1 {
			sfields += ', '
			vals += ', '
		}
	}
	xP.cgen.insert_before('char* params[$nr_vals];' + params)
	xP.cgen.set_shadow(fn_sh, 'PQexecParams( ')
	xP.genln('.conn, "insert into $table_name ($sfields) values ($vals)", $nr_vals, 0, params, 0, 0, 0)')
}
