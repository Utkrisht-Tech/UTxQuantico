// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import (
	WebX.template  // for `$WebX_html()`
	os
	StringX
)

fn (xP mut Parser) comp_time() {
	xP.check(.DOLLAR)
	if xP.tk == .key_if {
		xP.check(.key_if)
		xP.fspace()
		not := xP.tk == .NOT
		if not {
			xP.check(.NOT)
		}
		name := xP.check_name()
		xP.fspace()
		if name in supported_platforms {
			ifdef_name := os_name_to_ifdef(name)
			if not {
				xP.genln('#ifndef $ifdef_name')
			}
			else {
				xP.genln('#ifdef $ifdef_name')
			}
			xP.check(.LCBR)
			xP.statements_no_rcbr()
			if ! (xP.tk == .DOLLAR && xP.peek() == .key_else) {
				xP.genln('#endif')
			}
		}
		else if name == 'debug' {
			xP.genln('#ifdef UTXQDEBUG')
			xP.check(.LCBR)
			xP.statements_no_rcbr()
			xP.genln('#endif')
		}
		else {
			println('Supported Platforms:')
			println(supported_platforms)
			xP.error('Unknown platform `$name`')
		}
		if_returns := xP.returns
		xP.returns = false
		//xP.gen('/* returns $xP.returns */')
		if xP.tk == .DOLLAR && xP.peek() == .key_else {
			xP.next()
			xP.next()
			xP.check(.LCBR)
			xP.genln('#else')
			xP.statements_no_rcbr()
			xP.genln('#endif')
			else_returns := xP.returns
			xP.returns = if_returns && else_returns
			//xP.gen('/* returns $xP.returns */')
		}
	}
	else if xP.tk == .key_for {
		xP.next()
		name := xP.check_name()
		if name != 'field' {
			xP.error('for field only')
		}
		xP.check(.key_in)
		xP.check_name()
		xP.check(.DOT)
		xP.check_name()// fields
		xP.check(.LCBR)
		// for xP.tk != .RCBR && xP.tk != .EOF {
		res_name := xP.check_name()
		println(res_name)
		xP.check(.DOT)
		xP.check(.DOLLAR)
		xP.check(.NAME)
		xP.check(.ASSIGN)
		xP.cgen.start_tmp()
		xP.bool_expression()
		val := xP.cgen.end_tmp()
		println(val)
		xP.check(.RCBR)
		// }
	}
	// $WebX.html()
	// Compile WebX html template to UTxQ code, parse that UTxQ code and embed the resulting UTxQ functions
	// that returns an html string
	else if xP.tk == .NAME && xP.lit == 'WebX' {
		mut path := xP.cur_fn.name + '.html'
		if xP.pref.is_debug {
			println('Compiling template $path')
		}
		if !os.file_exists(path) {
			// Can't find the template file in current directory,
			// try looking next to the WebX program, in case it's run with
			// xQ path/to/WebX_app.xq
			path = os.dir(xP.scanner.file_path) + '/' + path
			if !os.file_exists(path) {
				xP.error('WebX HTML template "$path" not found')
			}
		}
		xP.check(.NAME)  // TODO skip `WebX.html()`
		xP.check(.DOT)
		xP.check(.NAME)
		xP.check(.LPAR)
		xP.check(.RPAR)
		xQ_code := template.compile_template(path)
		if os.file_exists('.WebXTemplate.xq') {
			os.rm('.WebXTemplate.xq')
		}
		os.write_file('.WebXTemplate.xq', xQ_code.clone()) // TODO don't need clone, compiler bug
		xP.genln('')
		// Parse the function and embed resulting C code in current function so that
		// all variables are available.
		pos := xP.cgen.lines.len - 1
		mut xPP := xP.xQ.new_parser_file('.WebXTemplate.xq')
		if !xP.pref.is_debug {
			os.rm('.WebXTemplate.xq')
		}
		xPP.is_WebX = true
		xPP.set_current_fn( xP.cur_fn ) // give access too all variables in current function
		xPP.parse(.main)
		template_fn_body := xP.cgen.lines.slice(pos + 2, xP.cgen.lines.len).join('\n').clone()
		end_pos := template_fn_body.last_index('Builder_str( sb )')  + 19 // TODO
		xP.cgen.lines = xP.cgen.lines.left(pos)
		xP.genln('/////////////////// Template start')
		xP.genln(template_fn_body.left(end_pos))
		xP.genln('/////////////////// Template end')
		// `app.WebX.html(index_view())`
		receiver := xP.cur_fn.args[0]
		dot := if receiver.is_mutable { '->' } else { '.' }
		xP.genln('WebX__Context_html($receiver.name $dot WebX, template_res)')
	}
	else {
		xP.error('bad comptime expression')
	}
}

// #include, #flag, #UTxQ
fn (xP mut Parser) chash() {
	hash := xP.lit.trim_space()
	// println('chash() file=$xP.file  is_sig=${xP.is_sig()} hash="$hash"')
	xP.next()
	is_sig := xP.is_sig()
	if hash.starts_with('flag ') {
		mut flag := hash.right(5)
		// expand `@XQROOT` `@XQMOD` to absolute path
		flag = flag.replace('@XQROOT', xP.xQRoot)
		flag = flag.replace('@XQMOD', ModPath)
		//xP.log('adding flag "$flag"')
		xP.table.parse_cflag(flag, xP.mod)
		return
	}
	if hash.starts_with('include') {
		if xP.first_cp() && !is_sig {
			if xP.file_xPCguard.len != 0 {
				//println('xP: $xP.file_platform $xP.file_xPCguard')
				xP.cgen.includes << '$xP.file_xPCguard\n#$hash\n#endif'
				return
			}
			xP.cgen.includes << '#$hash'
			return
		}
	}
	// TODOx remove after ui_mac.m is removed
	else if hash.contains('embed') {
		pos := hash.index('embed') + 5
		file := hash.right(pos)
		if xP.pref.build_mode != BuildMode.default_mode {
			xP.genln('#include $file')
		}
	}
	else if hash.contains('define') {
		// Move defines on top
		xP.cgen.includes << '#$hash'
	}
	else if hash == 'UTxQ' {
		println('UTxQ script')
		//xP.xQ_script = true
	}
	// Don't parse a non-JS UTxQ file (`#-js` flag)
	else if hash == '-js'  {
		$if js {
			for xP.tk != .EOF {
				xP.next()
			}
		} $else {
			xP.next()
		}
	}
	else {
		$if !js {
			if !xP.can_chash {
				println('hash="$hash"')
				println(hash.starts_with('include'))
				xP.error('bad token `#` (embedding C code is no longer supported)')
			}
		}
		xP.genln(hash)
	}
}

// `user.$method()` (`method` is a string)
fn (xP mut Parser) comptime_method_call(typ Type) {
	xP.cgen.cur_line = ''
	xP.check(.DOLLAR)
	var := xP.check_name()
	for i, method in typ.methods {
		if method.typ != 'void' {
			continue
		}
		receiver := method.args[0]
		amp := if receiver.is_mutable { '&' } else { '' }
		if i > 0 {
			xP.gen(' else ')
		}
		xP.gen('if ( string_eqeq($var, _STR("$method.name")) ) ${typ.name}_$method.name($amp $xP.expr_var.name);')
	}
	xP.check(.LPAR)
	xP.check(.RPAR)
	if xP.tk == .key_or_else {
		xP.check(.key_or_else)
		xP.genln('else {')
		xP.check(.LCBR)
		xP.statements()
	}
}

fn (xP mut Parser) gen_array_str(typ Type) {
	xP.add_method(typ.name, Fn{
		name: 'str'
		typ: 'string'
		args: [Var{typ: typ.name, is_arg:true}]
		is_method: true
		is_public: true
		receiver_typ: typ.name
	})
	elm_type := typ.name.right(6)
	elm_type2 := xP.table.find_type(elm_type)
	if xP.typ_to_format(elm_type, 0) == '' && !xP.table.type_has_method(elm_type2, 'str') {
		xP.error('cant print ${elm_type}[], unhandled print of ${elm_type}')
	}
	xP.xQ.xQGen_buf.writeln('
fn (a $typ.name) str() string {
	mut sb := StringX.new_builder(a.len * 3)
	sb.write("[")
	for i, elem in a {
		sb.write(elem.str())
		if i < a.len - 1 {
			sb.write(", ")
		}
	}
	sb.write("]")
	return sb.str()
}
	')
	xP.cgen.fns << 'string ${typ.name}_str();'
}

// `Foo { bar: 3, baz: 'hi' }` => '{ bar: 3, baz: "hi" }'
fn (xP mut Parser) gen_struct_str(typ Type) {
	xP.add_method(typ.name, Fn{
		name: 'str'
		typ: 'string'
		args: [Var{typ: typ.name, is_arg:true}]
		is_method: true
		is_public: true
		receiver_typ: typ.name
	})

	mut sb := StringX.new_builder(typ.fields.len * 20)
	sb.writeln('fn (a $typ.name) str() string {\nreturn')
	sb.writeln("'{")
	for field in typ.fields {
		sb.writeln('\t$field.name: \$a.${field.name}')
	}
	sb.writeln("\n}'")
	sb.writeln('}')
	xP.xQ.xQGen_buf.writeln(sb.str())
	// Need to manually add the definition to `fns` so that it stays
	// at the top of the file.
	// This function will get parsed by UTxQ after the main CheckPoint.
	xP.cgen.fns << 'string ${typ.name}_str();'
}
