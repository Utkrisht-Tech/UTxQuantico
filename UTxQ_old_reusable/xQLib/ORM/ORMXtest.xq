// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

//import DataBaseX.PgSQL
 
struct Modules {
	id int 
	user_id int 
	name string 
	url string
	//no_of_downloads int 
}

fn testXorm() {
/* 
	db := PgSQL.connect('xQpm', 'UTx10101')
	//no_of_modules := db.select count from modules  
	//no_of_modules := db.select count from Modules where id == 1
	no_of_modules := db.select count from Modules where	name == 'UTX' && id == 1
	println(no_of_modules)
 
 	mod := db.select from Modules where id = 1 limit 1
	println(mod)

	mods := db.select from Modules limit 10
	for mod in mods {
	println(mod)
	}
*/

/*
	mod := db.retrieve<Module>(1)

	mod := db.update Module set name = name + '!' where id > 10


	no_of_modules := db.select count from Modules
		where id > 1 && name == ''
	println(no_of_modules)

	no_of_modules := db.select count from modules
	no_of_modules := db.select from modules
	no_of_modules := db[:modules].select
*/ 
/* 
	mod := select from db.modules where id = 1 limit 1
	println(mod.name)
	top_mods := select from db.modules where no_of_downloads > 1000 order by no_of_downloads desc limit 10
	top_mods := db.select from modules where no_of_downloads > 1000 order by no_of_downloads desc limit 10
	top_mods := db.select<Module>(m => m.no_of_downloads > 1000).order_by(m => m.no_of_downloads).desc().limit(10)
	names := select name from db.modules // []string

	n := db.q_int('select count(*) from modules')
	println(n)
*/
}