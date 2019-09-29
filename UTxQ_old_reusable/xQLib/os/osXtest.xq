// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

import os

fn testXsetenv() {
    os.setenv('foo', 'bar', true)
    assert os.getenv('foo') == 'bar'
    
    // `setenv` should not set if `overwrite` is false
    os.setenv('foo', 'bar2', false)
    assert os.getenv('foo') == 'bar'
    
    // `setenv` should overwrite if `overwrite` is true
    os.setenv('foo', 'bar2', true)
    assert os.getenv('foo') == 'bar2'
}

fn testXunsetenv() {
    os.setenv('foo', 'bar', true)
    os.unsetenv('foo')
    assert os.getenv('foo') == ''
}

fn testXwrite_and_read_string_to_file() {
    filename := './test1.txt'
    hello := 'hello world!'
    os.write_file(filename, hello)
    assert hello.len == os.file_size(filename)
    
    read_hello := os.read_file(filename) or { panic('Error reading file $filename') }
    assert hello == read_hello
    
    os.rm(filename)
}

fn testXcreate_and_delete_folder() {
    folder := './test1'
    os.mkdir(folder)
    
    folder_contents := os.ls(folder)
    assert folder_contents.len == 0
    
    os.rmdir(folder)
    
    folder_exists := os.dir_exists(folder)
    
    assert folder_exists == false
}

fn testXdir() {
	$if windows {
		assert os.dir('C:\\a\\b\\c') == 'C:\\a\\b' 
	} $else { 
		assert os.dir('/var/tmp/foo') == '/var/tmp' 
	} 
} 

//fn testXfork() {
    //pid := os.fork()
    //if pid == 0 {
        //println('Child')
    //}
    //else {
        //println('Parent')
    //}
//}

//fn testXwait() {
    //pid := os.fork()
    //if pid == 0 {
        //println('Child')
        //exit(0)
    //}
    //else {
        //cpid := os.wait()
        //println('Parent')
        //println(cpid)
    //}
//}