// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

// FlagX for command-line flag parsing :-
//
// - flags like '--flag' or '--stuff=things' or '--things stuff' 
// - handles bool, int, float and string args
// - handles unknown arguments as error 
// - capable to print usage
// 
// Usage example:
//
//  ```UTxQ
//  module main
//  
//  import os
//  import FlagX
//  
//  fn main() {
//  	mut fp := FlagX.new_FlagX_parser(os.args)
//  	fp.application('FlagX_example_tool')
//  	fp.version('v0.0.0')
//  	fp.description('Designed to show working of FlagX lib')
//  
//  	fp.skip_executable()
//  
//  	an_int := fp.int('an_int', 666, 'some int to define 666 is default')
//  	a_bool := fp.bool('a_bool', false, 'some \'real\' flag')
//  	a_float := fp.float('a_float', 1.0, 'also floats')
//  	a_string := fp.string('a_string', 'no text', 'finally, some text')
//  
//  	additional_args := fp.finalize() or {
//  		eprintln(err)
//  		println(fp.usage())
//  		return
//  	}
//  
//  	println('
//  		  an_int: $an_int
//  		  a_bool: $a_bool
//  		 a_float: $a_float
//  		a_string: \'$a_string\'
//  	')
//  	println(additional_args.join_lines())
//  }
//  ```

module FlagX

// data object storing information about a defined flag
struct FlagX {
public:
    name              string // name as it appears on command line
    abbr              byte   // shortcut
    usage             string // help message
    val_description   string // Description that appears in usage
}

struct FlagXParser {
public mut: 
    args                    []string     // the arguments to be parsed
    flags                   []FlagX      // registered flags
    application_name        string
    application_version     string
    application_description string
    min_free_args int
    max_free_args int
}

// Create a new flag set for parsing command-line arguments
// TODO use INT_MAX.
public fn new_FlagX_parser(args []string) &FlagXParser {
    return &FlagXParser{args:args, max_free_args: 4048}
}

// Set application name to be used in 'usage' output
public fn (fs mut FlagXParser) application(s string) {
    fs.application_name = s
}

// Set the application version to be used in 'usage' output
public fn (fs mut FlagXParser) version(s string) {
    fs.application_version = s
}

// Set the application description to be used in 'usage' output
public fn (fs mut FlagXParser) description(s string) {
    fs.application_description = s
}

// Mosty the first argv is not needed for flag parsing
public fn (fs mut FlagXParser) skip_executable() {
    fs.args.delete(0)
}

// Internal helper to register a flag
fn (fs mut FlagXParser) add_flag(n string, a byte, u, vd string) {
    fs.flags << FlagX{
        name: n,
        abbr: a,
        usage: u,
        val_description: vd
    }
}

// Internal: General parsing for a single argument 
//  - search args for existence
//    if true
//      extract the defined value as string
//    else 
//      return an (dummy) error -> argument is not defined
//
//  - the name, usage are registered
//  - found arguments and corresponding values are removed from args list
fn (fs mut FlagXParser) parse_value(n string, ab byte) ?string {
    c := '--$n'
    for i, a in fs.args {
        if a == c || (a.len == 2 && a[1] == ab) {
            if fs.args.len > i+1 && fs.args[i+1].left(2) != '--' {
                val := fs.args[i+1]
                fs.args.delete(i+1)
                fs.args.delete(i)
                return val
            } else {
                panic('Argument Missing for \'$n\'')
            }
        } else if a.len > c.len && c == a.left(c.len) && a.substr(c.len, c.len+1) == '=' {
            val := a.right(c.len+1)
            fs.args.delete(i)
            return val
        }
    }
    return error('Parameter \'$n\' not found')
}

// Special parsing for bool values 
// Also See: parse_value
// 
// Special: it is allowed to define bool flags without value
// -> '--flag' is parsed as true
// -> '--flag' is equal to '--flag=true'
fn (fs mut FlagXParser) parse_bool_value(n string, ab byte) ?string {
    c := '--$n'
    for i, a in fs.args {
        if a == c || (a.len == 2 && a[1] == ab) {
            if fs.args.len > i+1 && (fs.args[i+1] in ['true', 'false'])  {
                val := fs.args[i+1]
                fs.args.delete(i+1)
                fs.args.delete(i)
                return val
            } else {
                val := 'true'
                fs.args.delete(i)
                return val
            }
        } else if a.len > c.len && c == a.left(c.len) && a.substr(c.len, c.len+1) == '=' {
            val := a.right(c.len+1)
            fs.args.delete(i)
            return val
        }
    }
    return error('Parameter \'$n\' not found')
}

// Defining and parsing a bool flag 
//  if defined 
//      the value is returned (true/false)
//  else 
//      the default value is returned
// Abbreviation-Version
//TODO error handling for invalid string to bool conversion
public fn (fs mut FlagXParser) bool_(n string, a byte, v bool, u string) bool {
    fs.add_flag(n, a, u, '')
    parsed := fs.parse_bool_value(n, a) or {
        return v
    }
    return parsed == 'true'
}

// Defining and parsing a bool flag 
//  if defined 
//      the value is returned (true/false)
//  else 
//      the default value is returned
//TODO error handling for invalid string to bool conversion
public fn (fs mut FlagXParser) bool(n string, v bool, u string) bool {
    return fs.bool_(n, `\0`, v, u)
}

// Defining and parsing an int flag 
//  if defined 
//      the value is returned (int)
//  else 
//      the default value is returned
// Abbreviation-Version
//TODO error handling for invalid string to int conversion
public fn (fs mut FlagXParser) int_(n string, a byte, i int, u string) int {
    fs.add_flag(n, a, u, '<int>')
    parsed := fs.parse_value(n, a) or {
        return i
    }
    return parsed.int()
}

// Defining and parsing an int flag 
//  if defined 
//      the value is returned (int)
//  else 
//      the default value is returned
//TODO error handling for invalid string to int conversion
public fn (fs mut FlagXParser) int(n string, i int, u string) int {
    return fs.int_(n, `\0`, i, u)
}

// Defining and parsing a float flag 
//  if defined 
//      the value is returned (float)
//  else 
//      the default value is returned
// Abbreviation-Version
//TODO error handling for invalid string to float conversion
public fn (fs mut FlagXParser) float_(n string, a byte, f f32, u string) f32 {
    fs.add_flag(n, a, u, '<float>')
    parsed := fs.parse_value(n, a) or {
        return f
    }
    return parsed.f32()
}

// Defining and parsing a float flag 
//  if defined 
//      the value is returned (float)
//  else 
//      the default value is returned
//TODO error handling for invalid string to float conversion
public fn (fs mut FlagXParser) float(n string, f f32, u string) f32 {
    return fs.float_(n, `\0`, f, u)
}

// Defining and parsing a string flag 
//  if defined 
//      the value is returned (string)
//  else 
//      the default value is returned
// Abbreviation-Version
public fn (fs mut FlagXParser) string_(n string, a byte, v, u string) string {
    fs.add_flag(n, a, u, '<arg>')
    parsed := fs.parse_value(n, a) or {
        return v
    }
    return parsed
}

// Defining and parsing a string flag 
//  if defined 
//      the value is returned (string)
//  else 
//      the default value is returned
public fn (fs mut FlagXParser) string(n, v, u string) string {
    return fs.string_(n, `\0`, v, u)
}

// This will cause an error in finalize() if free args are out of range
// (min, ..., max)
public fn (fs mut FlagXParser) limit_free_args(min, max int) {
    if min > max {
        panic('FlagX.limit_free_args expect min < max, got $min >= $max')
    }
    fs.min_free_args = min
    fs.max_free_args = max
}

const (
    // used for formating usage message
    SPACE = '                            '
)

// Collect all given information and 
public fn (fs FlagXParser) usage() string {
    mut use := '\n'
    use += 'usage ${fs.application_name} [options] [ARGS]\n'
    use += '\n'
    
    if fs.flags.len > 0 {
        use += 'options:\n'
        for f in fs.flags {
            flag_description := '  --$f.name $f.val_description'
            space := if flag_description.len > SPACE.len-2 {
                '\n$SPACE'
            } else {
                SPACE.right(flag_description.len)
            }
            abbr_description := if f.abbr == `\0` { '' } else { '  -${tos(f.abbr, 1)}\n' }
            use += '$abbr_description$flag_description$space$f.usage\n'
        }
    }
    
    use += '\n'
    use += '$fs.application_name $fs.application_version\n'
    if fs.application_description != '' {
        use += '\n'
        use += 'description:\n'
        use += '$fs.application_description'
    }
    return use
}

// Finalize argument parsing -> call after all arguments are defined
//
// all remaining arguments are returned in the same order they are defined on
// command line
//
// if additional flag are found (things starting with '--') an error is returned 
// error handling is up to the application developer
public fn (fs FlagXParser) finalize() ?[]string {
    for a in fs.args {
        if a.left(2) == '--' {
            return error('Unknown argument \'${a.right(2)}\'')
        }
    }
    if fs.args.len < fs.min_free_args {
        return error('Expect at least ${fs.min_free_args} arguments')
    }
    if fs.args.len >= fs.max_free_args {
        if fs.max_free_args > 0 {
            return error('Expect at most ${fs.max_free_args} arguments')
        } else {
            return error('Expect no arguments')
        }
    }
    return fs.args
}