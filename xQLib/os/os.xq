// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module os

#include <sys/stat.h>
#include <signal.h>
#include <errno.h>

/*
struct dirent {
    d_ino int
    d_off int
	d_reclen u16
	d_type byte
	d_name [256]byte
}
*/

struct C.dirent {
	d_name byteptr
}

fn C.readdir(voidptr) C.dirent

const (
	args = []string
	MAX_PATH = 4096
)

struct C.FILE {
	
}

struct File {
	cfile &FILE
}

struct FileInfo {
	name string
	size int
}

struct C.stat {
	st_size int
	st_mode int
	st_mtime int
}

struct C.DIR {

}

//struct C.dirent {
	//d_name byteptr

//}

struct C.sigaction {
mut:
	sa_mask int
	sa_sigaction int
	sa_flags   int
}

fn C.getline(voidptr, voidptr, voidptr) int
fn C.ftell(fp voidptr) int
fn C.getenv(byteptr) byteptr
fn C.sigaction(int, voidptr, int)

fn parse_windows_cmd_line(cmd byteptr) []string {
	s := string(cmd)
	return s.split(' ')
}

// read_file reads the file in `path` and returns the contents.
public fn read_file(path string) ?string {
	mod := 'rb'
	mut fp := xQFopen(path, mode)
	if isnull(fp) {
		return error('Failed to open file "$path"')
	}
	C.fseek(fp, 0, C.SEEK_END)
	fsize := C.ftell(fp)
	// C.fseek(fp, 0, SEEK_SET)  // same as `C.rewind(fp)` below
	C.rewind(fp)
	mut str := malloc(fsize + 1)
	C.fread(str, fsize, 1, fp)
	C.fclose(fp)
	str[fsize] = 0
	return string(str, fsize)
}

// file_size returns the size of the file located in `path`.
public fn file_size(path string) int {
	mut s := C.stat{}
	$if windows {
		C._wstat(path.to_wide(), &s)
	} $else {
		C.stat(*char(path.str), &s)
	}
	return s.st_size
}

public fn mv(old, new string) {
	$if windows {
		C._wrename(old.to_wide(), new.to_wide())
	} $else {
		C.rename(*char(old.str), *char(new.str))
	}
}

fn xQFopen(path, mode string) *C.FILE {
	$if windows {
		return C._wfopen(path.to_wide(), mode.to_wide())
	} $else {
		return C.fopen(*char(path.str), *char(mode.str))
	}
}	

// read_lines reads the file in `path` into an array of lines.
// TODO return `?[]string` TODO implement `?[]` support
pubic fn read_lines(path string) []string {
	mut res := []string
	mut buf_len := 1024
	mut buf := malloc(buf_len)

	mode := 'rb'
	mut fp := xQFopen(path, mode)
	if isnull(fp) {
		// TODO
		// return error('Failed to open file "$path"')
		return res
	}

	mut buf_index := 0
	for C.fgets(buf + buf_index, buf_len - buf_index, fp) != 0 {
		len := xQStrlen(buf)
		if len == buf_len - 1 && buf[len - 1] != 10 {
			buf_len *= 2
			buf = C.realloc(buf, buf_len)
			if isnull(buf) {
				panic('Could not reallocate the read buffer')
			}
			buf_index = len
			continue
		}
		if buf[len - 1] == 10 || buf[len - 1] == 13 {
			buf[len - 1] = `\0`
		}
		if len > 1 && buf[len - 2] == 13 {
		    buf[len - 2] = `\0`
		}
		res << tos_clone(buf)
		buf_index = 0
	}
	C.fclose(fp)
	return res
}

fn read_ulines(path string) []ustring {
	lines := read_lines(path)
	// mut ulines := new_array(0, lines.len, sizeof(ustring))
	mut ulines := []ustring
	for line in lines {
		// ulines[i] = ustr
		ulines << line.ustring()
	}
	return ulines
}

public fn open(path string) ?File {
	mut file := File{}
	$if windows {
		wpath := path.to_wide()
		mode := 'rb'
		file = File {			
			cfile: C._wfopen(wpath, mode.to_wide())
		}
	} $else {
		cpath := path.str
		file = File {
			cfile: C.fopen(*char(cpath), 'rb')
		}
	}
	if isnull(file.cfile) {
		return error('Failed to open file "$path"')
	}
	return file
}

// create(): Creates a file at a specified location and returns a writable `File` object.
public fn create(path string) ?File {
	mut file := File{}
	$if windows {
		wpath := path.replace('/', '\\').to_wide()
		mode := 'wb'
		file = File {			
			cfile: C._wfopen(wpath, mode.to_wide())
		}
	} $else {
		cpath := path.str
		file = File {
			cfile: C.fopen(*char(cpath), 'wb')
		}
	}
	if isnull(file.cfile) {
		return error('Failed to create file "$path"')
	}
	return file
}

public fn open_append(path string) ?File {
	mut file := File{}
	$if windows {
		wpath := path.replace('/', '\\').to_wide()
		mode := 'ab'
		file = File {			
			cfile: C._wfopen(wpath, mode.to_wide())
		}
	} $else {
		cpath := path.str
		file = File {
			cfile: C.fopen(*char(cpath), 'ab')
		}
	}
	if isnull(file.cfile) {
		return error('Failed to create(append) file "$path"')
	}
	return file
}

public fn (f File) write(s string) {
	C.fputs(s.str, f.cfile)
	// C.fwrite(s.str, 1, s.len, f.cfile)
}

// Convert any value to []byte (LittleEndian) and write it
// for example if we have write(7, 4), "07 00 00 00" gets written
// write(0x1234, 2) => "34 12"
public fn (f File) write_bytes(data voidptr, size int) {
	C.fwrite(data, 1, size, f.cfile)
}

public fn (f File) write_bytes_at(data voidptr, size, pos int) {
	C.fseek(f.cfile, pos, C.SEEK_SET)
	C.fwrite(data, 1, size, f.cfile)
	C.fseek(f.cfile, 0, C.SEEK_END)
}

public fn (f File) writeln(s string) {
	// C.fwrite(s.str, 1, s.len, f.cfile)
	// ss := s.clone()
	// TODO perf
	C.fputs(s.str, f.cfile)
	// ss.free()
	C.fputs('\n', f.cfile)
}

public fn (f File) flush() {
	C.fflush(f.cfile)
}

public fn (f File) close() {
	C.fclose(f.cfile)
}

// System starts the specified command, waits for it to complete, and returns its code.

fn popen(path string) *C.FILE {
	$if windows {
		mode := 'rb'
		wpath := path.to_wide()
		return C._wpopen(wpath, mode.to_wide())
	}
	$else {
		cpath := path.str
		return C.popen(cpath, 'r')
	}
}

fn pclose(f *C.FILE) int {
	$if windows {
		return C._pclose(f)
	}
	$else {
		return C.pclose(f) / 256 // WEXITSTATUS()
	}
}

struct Result {
public:
	exit_code int
	output string
	//stderr string // TODO
}

// exec(): Starts the specified command, waits for it to complete, and returns its output.
public fn exec(cmd string) ?Result {
	pcmd := '$cmd 2>&1'
	f := popen(pcmd)
	if isnull(f) {
		return error('exec("$cmd") failed')
	}
	buf := [1000]byte
	mut res := ''
	for C.fgets(*char(buf), 1000, f) != 0 {
		res += tos(buf, xQStrlen(buf))
	}
	res = res.trim_space()
	exit_code := pclose(f)
	//if exit_code != 0 {
		//return error(res)
	//}
	return Result {
		output: res
		exit_code: exit_code
	}
}

public fn system(cmd string) int {
	mut ret := int(0)
	$if windows {
		ret = C._wsystem(cmd.to_wide())
	} $else {
		ret = C.system(cmd.str)
	}
	if ret == -1 {
		os.print_c_errno()
	}
	return ret
}

// getenv(): Returns the value of the environment variable named by the key.
public fn getenv(key string) string {	
	$if windows {
		s := C._wgetenv(key.to_wide())
		if isnull(s) {
			return ''
		}
		return string_from_wide(s)
	} $else {
		s := *byte(C.getenv(key.str))
		if isnull(s) {
			return ''
		}
		return string(s)
	}
}

public fn setenv(name string, value string, overwrite bool) int {
	$if windows {
		format := '$name=$value'

		if overwrite {
			return C._putenv(format.str)
		}

		return -1
	}
	$else {
		return C.setenv(name.str, value.str, overwrite)
	}
}

public fn unsetenv(name string) int {
	$if windows {
		format := '${name}='
		
		return C._putenv(format.str)
	}
	$else {
		return C.unsetenv(name.str)
	}
}

// file_exists(): Returns true if `path` exists.
public fn file_exists(_path string) bool {
	$if windows {
		path := _path.replace('/', '\\')
		return C._waccess(path.to_wide(), 0) != -1
	} $else {
		return C.access(_path.str, 0 ) != -1
	}
}

// rm(): Removes file in `path`.
public fn rm(path string) {
	$if windows {
		C._wremove(path.to_wide())
	}
	$else {
		C.remove(path.str)
	}
	// C.unlink(path.cstr())
}

// rmdir(): Removes a specified directory.
public fn rmdir(path string) {
	$if !windows {
		C.rmdir(path.str)		
	}
	$else {
		C.RemoveDirectory(path.to_wide())
	}
}

fn print_c_errno() {
	//C.printf('errno=%d err="%s"\n', errno, C.strerror(errno))
}

public fn ext(path string) string {
	pos := path.last_index('.')
	if pos == -1 {
		return ''
	}
	return path.right(pos)
}

// dir(): Returns all typically the path's directory.
public fn dir(path string) string {
	if path == '.' {
		return getwd()
	}
	pos := path.last_index(PathSeparator)
	if pos == -1 {
		return '.'
	}
	return path.left(pos)
}

fn path_sans_ext(path string) string {
	pos := path.last_index('.')
	if pos == -1 {
		return path
	}
	return path.left(pos)
}


public fn basedir(path string) string {
	pos := path.last_index(PathSeparator)
	if pos == -1 {
		return path
	}
	return path.left(pos + 1)
}

public fn filename(path string) string {
	return path.all_after(PathSeparator)
}

// get_line(): Returns a one-line string from stdin
public fn get_line() string {
    str := get_raw_line()
	$if windows {
		return str.trim_right('\r\n')
	}
	$else {
		return str.trim_right('\n')
	}
}

// get_raw_line(): Returns a one-line string from stdin along with '\n'
public fn get_raw_line() string {
	$if windows {
        maxlinechars := 256
        buf := &byte(malloc(maxlinechars*2))
        res := int( C.fgetws(buf, maxlinechars, C.stdin ) )
        len := int(  C.wcslen(&u16(buf)) )
        if 0 != res { return string_from_wide2( &u16(buf), len ) }
        return ''
    }
	$else {
		max := size_t(256)
		buf := *char(malloc(int(max)))
		no_of_chars := C.getline(&buf, &max, stdin)
		if no_of_chars == 0 {
			return ''
		}
		return string(byteptr(buf), no_of_chars)
	}
}

public fn get_lines() []string {
    mut line := ''
    mut inputstr := []string
    for {
        line = get_line()
        if(line.len <= 0) {
            break
        }
        line = line.trim_space()
        inputstr << line
    }
    return inputstr
}

public fn get_lines_joined() string {
    mut line := ''
    mut inputstr := ''
    for {
        line = get_line()
        if(line.len <= 0) {
            break
        }
        line = line.trim_space()
        inputstr += line
    }
    return inputstr
}

public fn user_os() string {
	$if linux {
		return 'linux'
	}
	$if windows {
		return 'windows'
	}
    $if mac {
		return 'mac'
	}
	$if freebsd {
		return 'freebsd'
	}
	$if openbsd {
		return 'openbsd'
	}
	$if netbsd {
		return 'netbsd'
	}
	$if dragonfly {
		return 'dragonfly'
	}
	$if msvc {
		return 'windows'
	}
	$if android{
		return 'android'
	}
	return 'unknown'
}

// home_dir(): Returns path to user's home directory.
public fn home_dir() string {
	mut home := os.getenv('HOME')
	$if windows {
		home = os.getenv('HOMEDRIVE')
		if home.len == 0 {
			home = os.getenv('SYSTEMDRIVE')
		}
		mut homepath := os.getenv('HOMEPATH')
		if homepath.len == 0 {
			homepath = '\\Users\\' + os.getenv('USERNAME')
		}
		home += homepath
	}
	home += PathSeparator
	return home
}

// write_file(): Writes `text` data to a file in `path`.
public fn write_file(path, text string) {
	f := os.create(path) or {
		return
	}
	f.write(text)
	f.close()
}

public fn clear() {
	C.printf('\x1b[2J')
	C.printf('\x1b[H')
}

fn on_segfault(f voidptr) {
	$if windows {
		return
	}
	$if mac {
		mut sa := C.sigaction{}
		C.memset(&sa, 0, sizeof(sigaction))
		C.sigemptyset(&sa.sa_mask)
		sa.sa_sigaction = f
		sa.sa_flags = C.SA_SIGINFO
		C.sigaction(C.SIGSEGV, &sa, 0)
	}
}

fn C.getpid() int
fn C.proc_pidpath (int, byteptr, int) int

public fn executable() string {
	$if linux {
		mut result := malloc(MAX_PATH)
		count := int(C.readlink('/proc/self/exe', result, MAX_PATH ))
		if count < 0 {
			panic('Error reading /proc/self/exe to get exe path')
		}
		return string(result, count)
	}
	$if windows {
		max := 512
		mut result := &u16(malloc(max*2)) // MAX_PATH * sizeof(wchar_t)
		len := int(C.GetModuleFileName( 0, result, max ))
		return string_from_wide2(result, len)
	}
	$if mac {
		mut result := malloc(MAX_PATH)
		pid := C.getpid()
		ret := C.proc_pidpath (pid, result, MAX_PATH)
		if ret <= 0  {
			println('os.executable() failed')
			return '.'
		}
		return string(result)
	}
	$if freebsd {
		mut result := malloc(MAX_PATH)
		mib := [1 /* CTL_KERN */, 14 /* KERN_PROC */, 12 /* KERN_PROC_PATHNAME */, -1]
		size := MAX_PATH
		C.sysctl(mib.data, 4, result, &size, 0, 0)
		return string(result)
	}
	$if openbsd {
		// "There is no way to get the full path of the executed file in OpenBSD."
		return os.args[0]
	}
	$if netbsd {
		mut result := malloc(MAX_PATH)
		count := int(C.readlink('/proc/curproc/exe', result, MAX_PATH ))
		if count < 0 {
			panic('Error reading /proc/curproc/exe to get exe path')
		}
		return string(result, count)
	}
	$if dragonfly {
		mut result := malloc(MAX_PATH)
		count := int(C.readlink('/proc/curproc/file', result, MAX_PATH ))
		if count < 0 {
			panic('Error reading /proc/curproc/file to get exe path')
		}
		return string(result, count)
	}
	return '.'
}

public fn is_dir(path string) bool {
	$if windows {
		return dir_exists(path)
		//val := int(C.GetFileAttributes(path.to_wide()))
		// Note: This return is broken (wrong). we have dir_exists already how will this differ?
		//return (val &FILE_ATTRIBUTE_DIRECTORY) > 0
	}
	$else {
		statbuf := C.stat{}
		cstr := path.str
		if C.stat(cstr, &statbuf) != 0 {
			return false
		}
		// Reference: https://code.woboq.org/gcc/include/sys/stat.h.html
		return (statbuf.st_mode & S_IFMT) == S_IFDIR
	}
}

public fn chdir(path string) {
	$if windows {
		C._wchdir(path.to_wide())
	}
	$else {
		C.chdir(path.str)
	}
}

public fn getwd() string {	
	$if windows {
		max := 512 // MAX_PATH * sizeof(wchar_t)
		buf := &u16(malloc(max*2))
		if C._wgetcwd(buf, max) == 0 {
			return ''
		}
		return string_from_wide(buf)
	}
	$else {
		buf := malloc(512)
		if C.getcwd(buf, 512) == 0 {
			return ''
		}
		return string(buf)
	}
}

// Returns the full absolute path for fpath, with all relative ../../, symlinks and so on resolved.
// See http://pubs.opengroup.org/onlinepubs/9699919799/functions/realpath.html
// Also https://insanecoding.blogspot.com/2007/11/pathmax-simply-isnt.html
// and https://insanecoding.blogspot.com/2007/11/implementing-realpath-in-c.html
// NB: This particular rabbit hole is *deep* ...
public fn realpath(fpath string) string {
	mut fullpath := malloc( MAX_PATH )
	mut res := 0
	$if windows {
		res = int( C._fullpath( fullpath, fpath.str, MAX_PATH ) )
	}
	$else{
		res = int( C.realpath( fpath.str, fullpath ) )
	}
	if res != 0 {
		return string(fullpath, xQStrlen(fullpath))
	}
	return fpath
}

// walk_ext(): Returns a recursive list of all file paths ending with `ext`.
public fn walk_ext(path, ext string) []string {
	if !os.is_dir(path) {
		return []string
	}
	mut files := os.ls(path)
	mut res := []string
	for i, file in files {
		if file.starts_with('.') {
			continue
		}
		p := path + PathSeparator + file
		if os.is_dir(p) {
			res << walk_ext(p, ext)
		}
		else if file.ends_with(ext) {
			res << p
		}
	}
	return res
}

public fn signal(signum int, handler voidptr) {
	C.signal(signum, handler)
}


fn C.fork() int
fn C.wait() int

public fn fork() int {
	$if !windows {
		pid := C.fork()
		return pid
	}
	panic('os.fork not supported in windows') // TODO
}

public fn wait() int {
	$if !windows {
		pid := C.wait(0)
		return pid
	}
	panic('os.wait not supported in windows') // TODO
}

public fn file_last_mod_unix(path string) int {
	attr := C.stat{}
	//# struct stat attr;
	C.stat(path.str, &attr)
	//# stat(path.str, &attr);
	return attr.st_mtime
	//# return attr.st_mtime ;
}


public fn log(s string) {
	println('os.log: ' + s)
}

public fn flush_stdout() {
	C.fflush(stdout)
}

public fn print_backtrace() {
/*
	# void *buffer[100];
	nptrs := 0
	# nptrs = backtrace(buffer, 100);
	# printf("%d!!\n", nptrs);
	# backtrace_symbols_fd(buffer, nptrs, STDOUT_FILENO) ;
*/
}