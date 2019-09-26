// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import os

// add a module and its deps (module speficic dag method)
public fn(graph mut DepGraph) from_import_tables(import_tables map[string]ParsedImportsTable) {
	for _, pit in import_tables {
		mut deps := []string
		for _, m in pit.imports {
			deps << m
		}
		graph.add(pit.module_name, deps)
	}
}

// get ordered imports (module speficic dag method)
public fn(graph &DepGraph) imports() []string {
	mut mods := []string
	for node in graph.nodes {
		if node.name == 'main' {
			continue
		}
		mods << node.name
	}
	return mods
}

// 'StringX' => 'XQROOT/xQLib/StringX'
// 'installed_mod' => '~/.xQModules/installed_mod'
// 'local_mod' => '/path/to/current/dir/local_mod'
fn (xQ &UTxQ) find_module_path(mod string) string {
	mod_path := xQ.module_path(mod)
	// First check for local modules in the same directory
	mut import_path := os.getwd() + '/$mod_path'
	// Now search in xQLib/
	if !os.dir_exists(import_path) {
		import_path = '$xQ.lang_dir/xQLib/$mod_path'
	}
	//println('ip=$import_path')
	// Finally try modules installed with xQpm (~/.xQModules)
	if !os.dir_exists(import_path) {
		import_path = '$ModPath/$mod_path'
		if !os.dir_exists(import_path){
			xQError('module "$mod" not found')
		}
	}
	return import_path
}
