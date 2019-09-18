// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module BenchmarkX

import time

/*
Usage:
```
import BenchmarkX
mut bmark := BenchmarkX.new_BenchmarkX()
// by default the benchmark will be verbose, i.e. it will include timing information
// if you want it to be silent, set bmark.verbose = false 
for { 
   bmark.step() // call this when you want to advance the benchmark. 
                // The timing info in bmark.step_message will be measured starting from the last call to bmark.step
   ....

   //bmark.fail() // call this if the step failed
   //bmark.step_message(('failed')

   bmark.ok() // call this when the step succeeded
   println( bmark.step_message('ok')
}
bmark.stop() // call when you want to finalize the benchmark
println( bmark.total_message('remarks about the benchmark') )
```
*/

struct BenchmarkX{
public mut:
	benchX_start_time i64
	benchX_end_time i64
	step_start_time i64
	step_end_time i64
	no_of_total int
	no_of_ok    int
	no_of_fail  int
	verbose bool
}

public fn new_BenchmarkX() BenchmarkX{
	return BenchmarkX{
		benchX_start_time: BenchmarkX.now()
		verbose: true
	}
}

public fn (bx mut BenchmarkX) stop() {
	bx.benchX_end_time = BenchmarkX.now()
}

public fn (bx mut BenchmarkX) step() {
	bx.step_start_time = BenchmarkX.now()
}

public fn (bx mut BenchmarkX) fail() {
	bx.step_end_time = BenchmarkX.now()
	bx.no_of_total++
	bx.no_of_fail++
}

public fn (bx mut BenchmarkX) ok() {
	bx.step_end_time = BenchmarkX.now()
	bx.no_of_total++
	bx.no_of_ok++
}

public fn (bx mut BenchmarkX) step_message(msg string) string {
	return bx.tdiff_in_ms(msg, bx.step_start_time, bx.step_end_time)
}

public fn (bx mut BenchmarkX) total_message(msg string) string {
	mut tmsg := '$msg : ok, fail, total = ${bx.no_of_ok:5d}, ${bx.no_of_fail:5d}, ${bx.no_of_total:5d}'
	if bx.verbose {
		tmsg = '<=== total time spent $tmsg'
	}
	return bx.tdiff_in_ms(tmsg, bx.bench_start_time, bx.bench_end_time)
}

// Internal (Private) functions for BenchmarkX

fn (bx mut BenchmarkX) tdiff_in_ms(s string, sticks i64, eticks i64) string {
	if bx.verbose {
		tdiff := (eticks - sticks)
		return '${tdiff:6d} ms | $s'
	}
	return s
}

fn now() i64 {
	return time.ticks()
}