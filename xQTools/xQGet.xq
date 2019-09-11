// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import (
	HttpX 
	os 
	JsonX
) 

const (
	//url = 'http://localhost:8089' 
	url = 'https://xQpm.UTxQ.io/'
) 

struct Mod {
	id int 
	name string 
	url string
	no_of_downloads int 
}

fn main() {
	if os.args.len <= 1 {
		println('usage: xQGet module [module] [module] [...]')
		return
	} 

	home := os.home_dir()
	home_xQModules := '${home}.xQModules'
	if !os.dir_exists( home_xQModules ) {
		println('Creating $home_xQModules/ ...')
		os.mkdir(home_xQModules)
	}
	os.chdir(home_xQModules)

	mut errors := 0
	names := os.args.slice(1, os.args.len)
	for name in names {
		modurl := url + '/jsmod/$name'
		r := HttpX.get(modurl) or { panic(err) }
		
		if r.status_code == 404 {
			println('Skipping module "$name":- $url reported "$name" does not exist.')
			errors++
			continue
        	}
		
        	if r.status_code != 200 {
			println('Skipping module "$name":- $url responded with $r.status_code http status code. Please try again later.')
			errors++
			continue
		}
		
		s := r.text
		mod := JsonX.decode(Mod, s) or {
			errors++
			println('Skipping module "$name":- Its information is not in json format.')
			continue
		}
		
		if( '' == mod.url || '' == mod.name ){
			errors++
			// 404 error, which means module is missing
			println('Skipping module "$name":- It is missing name or url information.')
			continue
		}

		final_module_path := '$home_xQModules/' + mod.name.replace('.', '/')

		println('Installing module "$name" from $mod.url to $final_module_path ...')
		_ := os.exec('git clone --depth=1 $mod.url $final_module_path') or {
			errors++
			println('Could not install module "$name" to "$final_module_path" .')
			println('Error details: $err')
			continue
		}
	}
	if errors > 0 {
		exit(1)
	}
}