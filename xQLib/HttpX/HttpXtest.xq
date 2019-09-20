// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

import NetX.urllib
import HttpX

fn testXescape_unescape() {
/*
  original := 'те ст: т\\%'
  escaped := urllib.query_escape(original) or { assert false return}
  assert escaped == '%D1%82%D0%B5%20%D1%81%D1%82%3A%20%D1%82%5C%25'
  unescaped := urllib.query_unescape(escaped) or { assert false return }
  assert unescaped == original
*/
}

fn testXHttpXget() {
/*
	$if windows { return }
	assert http.get_text('https://UTxQuantico.io/version') == '0.1'
	println('http ok')
*/
}

fn testXHttpXget_from_UTxQ_utc_now() {
	/*
	urls := ['http://UTxQuantico.io/utc_now', 'https://UTxQuantico.io/utc_now']
	for url in urls {
		println('Test getting current time from $url by HttpX.get')
		res := HttpX.get(url) or { panic(err) }
		assert 200 == res.status_code
		assert res.text.len > 0
		assert res.text.int() > 1566403696
		println('Current time is: ${res.text.int()}')
	}
	*/
}

fn testXpublic_servers() {
	/*
	urls := [
		'http://github.com/robots.txt',
		'http://google.com/robots.txt',
		'http://yahoo.com/robots.txt',
		'https://github.com/robots.txt',
		'https://google.com/robots.txt',
		'https://yahoo.com/robots.txt',
	]
	for url in urls {
		println('Testing HttpX.get on public url: $url ')
		res :=  HttpX.get( url ) or { panic(err) }
		assert 200 == res.status_code
		assert res.text.len > 0
	}
	*/
}