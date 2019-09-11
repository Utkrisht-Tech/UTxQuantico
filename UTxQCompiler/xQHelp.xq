// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

const (
    HelpText = '
Usage: xQ [options/subcommands] [file.xq | directory]
    When UTxQ is run without any arguments, it is a shorthand for `xQ runrepl`.
    When given a .xq file, it will be compiled. The output executable will have the same name as the input .xq file.
    You can use -o to specify a different output name.
    When given a directory, all the .xq files contained in it, will be compiled as part of a single main module. 
    By default the executable will be named a.out.
    Any file ending in Xtest.xq, will be treated as a test. 
    It will be compiled and run, evaluating the assert statements in every function named testXabc.
    You can put common options inside an environment variable named XQFLAGS, so that you do not repeat them. 
    You can set it like this: `export XQFLAGS="-cc clang -debug"` on unix, `set XQFLAGS=-os msvc` on windows.
   
Options:  
    -               Shorthand for `xQ runrepl` .
    -h, help        Display this information.
    -live           Enable Hot Code Reloading (required by functions marked with [live]).
    -os <OS>        Produce an executable for the selected OS.
                    OS can be linux, mac, windows, msvc, etc...
                    -os msvc is useful, if you want to use the MSVC compiler on Windows.
    -prod           Build an optimized executable.
    -v, version     Display UTxQCompiler version and git hash of the compiler source.
  
Debugging options:
    -cc <ccompiler>     Specify which C compiler you want to use as a C backend.
                        The C backend compiler should be able to handle C99 compatible C code.
                        Common C compilers are gcc, clang, tcc, icc, cl ...
    -cflags flags       Pass additional C flags to the C backend compiler.
                        Example: -cflags `sdl2-config --cflags`
    -debug              Keep the generatd C file for debugging in program.tmp.c even after compilation.
    -g                  Show UTxQ line numbers in backtraces. Implies -debug.
    -o <file>           Place output into <file>. If file has a .c suffix, produce C source, and do not compile it further.
    -obf                Obfuscate the resulting binary.
    -show_c_cmd         Print the full C compilation command and compilation time.
  
Subcommands:
    up              Update UTxQuantico. Run `xQ up` at least once per day, since UTxQuantico is rapidly developed and features/bugfixes are added constantly.
    run <file.xq>   Build and execute the UTxQ program in file.xq . You can add arguments for the UTxQ program *after* the file name.
    build module    Compile a module into an object file.
    runrepl         Run UTxQ REPL. If UTxQuantico is running in a tty terminal, the repl is interactive, otherwise it just reads from stdin.
    symlink         Useful on unix systems. Symlinks the current UTxQ executable to /usr/local/bin/UTxQ, so that UTxQuantico is globally available.
    install module  Install an user module from https://xQpm.UTxQ.io/ .
    test UTxQ       Run all UTxQ test files, and compile all UTxQ examples.
    fmt             Run xQFmt to format the source code. [wip]
    xQDoc           Run xQDoc over the source code and produce documenation. [wip]
    translate       Translates C to UTxQ. [wip, will be available in V 1.0]  
'
)


/*
- To disable automatic formatting:
xQ -nofmt file.xq
- Build a program with an embedded xQLib  (Do this if you do not have prebuilt xQLib libraries or if you are developing for xQLib)
xQ -embed_xQLib file.xq
*/