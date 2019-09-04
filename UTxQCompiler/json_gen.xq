// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

// TODO replace with comptime code generation.
// TODO remove cJSON dependency.
// OLD: User decode_User(string json) {
// now it's
// User decode_User(cJSON* root) {
// User res;
// res.name = decode_string(json_get(root, "name"));
// res.profile = decode_Profile(json_get(root, "profile"));
// return res;
// }
// Codegen json_decode/encode functions
fn (xP mut Parser) gen_json_for_type(typ Type) {
	mut decoder := ''
	mut encoder := ''
	t := typ.name
	if t == 'int' || t == 'string' || t == 'bool' {
		return
	}
	if xP.first_cp() {
		return
	}
	// println('gen_json_for_type( $typ.name )')
	// Register decoder fn
	mut decoder_fn := Fn {
		mod: xP.mod
		typ: 'Option_$typ.name'
		name: json_decoder_name(t)
	}
	// Already registered? Skip.
	if xP.table.known_fn(decoder_fn.name) {
		return
	}
	// decode_TYPE functions receive an actual cJSON* object to decode
	// cJSON_Parse(str) call is added by the compiler
	arg := Var {
		typ: 'cJSON*'
	}
	decoder_fn.args << arg
	xP.table.register_fn(decoder_fn)
	// Register encoder fn
	mut encoder_fn := Fn {
		mod: xP.mod
		typ: 'cJSON*'
		name: json_encoder_name(t)
	}
	// encode_TYPE functions receive an object to encode
	encoder_arg := Var {
		typ: t
	}
	encoder_fn.args << encoder_arg
	xP.table.register_fn(encoder_fn)
	// Code gen decoder
	decoder += '
//$t $decoder_fn.name(cJSON* root) {
Option $decoder_fn.name(cJSON* root, $t* res) {
//  $t res;
  if (!root) {
    const char *error_ptr = cJSON_GetErrorPtr();
    if (error_ptr != NULL)	{
      fprintf(stderr, "Error in decode() for $t error_ptr=: %%s\\n", error_ptr);
//      printf("\\nbad js=%%s\\n", json.str);
      return v_error(tos2(error_ptr));
    }
  }
'
	// Code gen encoder
	encoder += '
cJSON* $encoder_fn.name($t val) {
cJSON *o = cJSON_CreateObject();
string res = tos2("");
'
	// Handle arrays
	if t.starts_with('array_') {
		decoder += xP.decode_array(t)
		encoder += xP.encode_array(t)
	}
	// Range through fields
	for field in typ.fields {
		if field.attr == 'skip' {
			continue
		}
		name := if field.attr.starts_with('json:') {
			field.attr.right(5)
		} else {
			field.name
		}
		field_type := xP.table.find_type(field.typ)
		_typ := field.typ.replace('*', '')
		encoder_name := json_encoder_name(_typ)
		if field.attr == 'raw' {
			decoder += ' res->$field.name = tos2(cJSON_PrintUnformatted(' +
				'json_get(root, "$name")));\n'

		} else {
			// Now generate decoders for all field types in this struct
			// need to do it here so that these functions are generated first
			xP.gen_json_for_type(field_type)

			decoder_name := json_decoder_name(_typ)

			if is_json_prim(_typ) {
				decoder += ' res->$field.name = $decoder_name(json_get(' +
					'root, "$name"))'
			}
			else {
				decoder += ' $decoder_name(json_get(root, "$name"), & (res->$field.name))'
			}
			decoder += ';\n'
		}
		encoder += '  cJSON_AddItemToObject(o,  "$name",$encoder_name(val.$field.name)); \n'
	}
	// cJSON_delete
	//xP.cgen.fns << '$decoder return opt_ok(res); \n}'
	xP.cgen.fns << '$decoder return opt_ok(res, sizeof(*res)); \n}'
	xP.cgen.fns << '/*encoder start*/ $encoder return o;}'
}

fn is_json_prim(typ string) bool {
	return typ == 'int' || typ == 'string' ||
	typ == 'bool' || typ == 'f32' || typ == 'f64' ||
	typ == 'i8' || typ == 'i16' || typ == 'i64' ||
	typ == 'u16' || typ == 'u32' || typ == 'u64'
}

fn (xP mut Parser) decode_array(array_type string) string {
	typ := array_type.replace('array_', '')
	t := xP.table.find_type(typ)
	fn_name := json_decoder_name(typ)
	// If we have `[]Profile`, have to register a Profile en(de)coder first
	xP.gen_json_for_type(t)
	mut s := ''
	if is_json_prim(typ) {
		s = '$typ val= $fn_name(jsonval); '
	}
	else {
		s = '  $typ val; $fn_name(jsonval, &val); '
	}
	return '
*res = new_array(0, 0, sizeof($typ));
const cJSON *jsonval = NULL;
cJSON_ArrayForEach(jsonval, root)
{
$s
  array__push(res, &val);
}
'
}

fn json_encoder_name(typ string) string {
	name := 'json__jsonencode_$typ'
	return name
}

fn json_decoder_name(typ string) string {
	name := 'json__jsondecode_$typ'
	return name
}

fn (xP &Parser) encode_array(array_type string) string {
	typ := array_type.replace('array_', '')
	fn_name := json_encoder_name(typ)
	return '
o = cJSON_CreateArray();
for (int i = 0; i < val.len; i++){
  cJSON_AddItemToArray(o, $fn_name(  (($typ*)val.data)[i]  ));
}
'
}
