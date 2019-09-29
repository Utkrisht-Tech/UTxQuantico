// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module LogX

import os
import time
import TermX

const (
    FATAL = 1
    ERROR = 2 
    WARNING = 3
    INFO  = 4
    DEBUG = 5
)

interface Logger {
    fatal(s string)
    error(s string)
    warning(s string)
    info(s string)
    debug(s string)
}

struct Log{
mut:
    level int
    output string
}


public fn (lo mut Log) set_level(level int){
    lo.level = level
}

public fn (lo mut Log) set_output(output string) {
    lo.output = output
}

fn (lo Log) log_file(s string, e string) {
    filename := lo.output
    f := os.open_append(lo.output) or {
        panic('Error reading file $filename')
    }
    timestamp := time.now().format_ss()
    f.writeln('$timestamp [$e] $s')
}

public fn (lo Log) fatal(s string){
    panic(s)
}

public fn (lo Log) error(s string){
    if lo.level >= ERROR{
        switch lo.output {
        case 'terminal':
            f := TermX.red('E')
            t := time.now()
            println('[$f ${t.format_ss()}] $s')

        default:
            lo.log_file(s, 'E')
        }
    }
}

public fn (lo Log) warning(s string){
    if lo.level >= WARNING{
        switch lo.output {
        case 'terminal':
            f := TermX.yellow('W')
            t := time.now()
            println('[$f ${t.format_ss()}] $s')

        default:
            lo.log_file(s, 'W')
        }
    }  
}

public fn (lo Log) info(s string){
    if lo.level >= INFO{
        switch lo.output {
        case 'terminal':
            f := TermX.white('I')
            t := time.now()
            println('[$f ${t.format_ss()}] $s')

        default:
            lo.log_file(s, 'I')
        }
    }
}

public fn (lo Log) debug(s string){
    if lo.level >= DEBUG{
        switch lo.output {
        case 'terminal':
            f := TermX.blue('D')
            t := time.now()
            println('[$f ${t.format_ss()}] $s')

        default:
            lo.log_file(s, 'D')
        }
    }
}