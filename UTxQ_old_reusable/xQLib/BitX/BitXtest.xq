// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

import BitX

import rand
import time

fn testXnew_getSize() {
	instance := BitX.new(10)
	assert instance.getSize() == 10
}

fn testX_set_clear_toggle_get_Bit() {
	mut instance := BitX.new(10)
	instance.setBit(4)
	assert instance.getBit(4) == 1
	instance.clearBit(4)
	assert instance.getBit(4) == 0
	instance.toggleBit(4)
	assert instance.getBit(4) == 1
}

fn testX_BW_and_not_or_xor() {
	rand.seed(time.now().uni)
	len := 80
	mut inp1 := BitX.new(len)
	mut inp2 := BitX.new(len)
	mut i := 0
	for i < len {
		if rand.next(2) == 1 {
			inp1.setBit(i)
		}
		if rand.next(2) == 1{
			inp2.setBit(i)
		}
		i++
	}
	output1 := BitX.BW_xor(inp1, inp2)
	BW_and := BitX.BW_and(inp1, inp2)
	BW_or := BitX.BW_or(inp1, inp2)
	BW_not := BitX.BW_not(BW_and)
	output2 := BitX.BW_and(BW_or, BW_not)
	mut result := 1
	for i < len {
		if output1.getBit(i) != output2.getBit(i) {result = 0}
	}
	assert result == 1
}

fn testXclone_compare() {
	rand.seed(time.now().uni)
	len := 80
	mut inp := BitX.new(len)
	for i := 0; i < len; i++ {
		if rand.next(2) == 1 {
			inp.setBit(i)
		}
	}
	output := BitX.clone(inp)
	assert output.getSize() == len
	assert BitX.compare(inp, output) == true
}

fn testXslice_join() {
	rand.seed(time.now().uni)
	len := 80
	mut inp := BitX.new(len)
	for i := 0; i < len; i++ {
		if rand.next(2) == 1 {
			inp.setBit(i)
		}
	}
	mut result := 1
	for point := 1; point < (len - 1); point++ {
		// divide a BitXSpace into two Sub XSpaces
		chunk1 := inp.slice(0, point)
		chunk2 := inp.slice(point, inp.getSize())
		// concatenate them back into one and compare to the original
		output := BitX.join(chunk1, chunk2)
		if !BitX.compare(inp, output) {
			result = 0
		}
	}
	assert result == 1
}

fn testXpopcount() {
	rand.seed(time.now().uni)
	len := 80
	mut count0 := 0
	mut inp := BitX.new(len)
	for i := 0; i < len; i++ {
		if rand.next(2) == 1 {
			inp.setBit(i)
			count0++
		}
	}
	count1 := inp.popcount()
	assert count0 == count1
}

fn testXhamming_dist() {
	rand.seed(time.now().uni)
	len := 80
	mut count := 0
	mut inp1 := BitX.new(len)
	mut inp2 := BitX.new(len)
	for i := 0; i < len; i++ {
		switch rand.next(4) {
			case 0:
			case 1:
				inp1.setBit(i)
				count++
			case 2:
				inp2.setBit(i)
				count++
			case 3:
				inp1.setBit(i)
				inp2.setBit(i)
		}
	}
	assert count == BitX.hamming_dist(inp1, inp2)
}

fn testXstrToBitX() {
	rand.seed(time.now().uni)
	len := 80
	mut inp := ''
	for i := 0; i < len; i++ {
		if rand.next(2) == 1 {
			inp = inp + '1'
		}
		else {
			inp = inp + '0'
		}
	}
	output := BitX.strToBitX(inp)
	mut result := 1
	for i := 0; i < len; i++ {
		if inp[i] != output.getBit(i) + 48 {
			result = 0
		}
	}
	assert result == 1
}

fn testXbitXToStr() {
	rand.seed(time.now().uni)
	len := 80
	mut inp := BitX.new(len)
	for i := 0; i < len; i++ {
		if rand.next(2) == 1 {
			inp.setBit(i)
		}
	}
	mut check := ''
	for i := 0; i < len; i++ {
		if inp.getBit(i) == 1 {
			check = check + '1'
		}
		else {
			check = check + '0'
		}
	}
	output := inp.bitXToStr()
	mut result := 1
	for i := 0; i < len; i++ {
		if check[i] != output[i] {
			result = 0
		}
	}
	assert result == 1
}

fn testXsetAll() {
		rand.seed(time.now().uni)
	len := 80
	mut inp := BitX.new(len)
	inp.setAll()
	mut result := 1
	for i := 0; i < len; i++ {
		if inp.getBit(i) != 1 {
			result = 0
		}
	}
	assert result == 1
}

fn testXclearAll() {
		rand.seed(time.now().uni)
	len := 80
	mut inp := BitX.new(len)
	for i := 0; i < len; i++ {
		if rand.next(2) == 1 {
			inp.setBit(i)
		}
	}
	inp.clearAll()
	mut result := 1
	for i := 0; i < len; i++ {
		if inp.getBit(i) != 0 {
			result = 0
		}
	}
	assert result == 1
}

fn testXreverse() {
	rand.seed(time.now().uni)
	len := 80
	mut inp := BitX.new(len)
	for i := 0; i < len; i++ {
		if rand.next(2) == 1 {
			inp.setBit(i)
		}
	}
	check := BitX.clone(inp)
	output := inp.reverse()
	mut result := 1
	for i := 0; i < len; i++ {
		if output.getBit(i) != check.getBit(len - i - 1) {
			result = 0
		}
	}
	assert result == 1
}

fn testXresize() {
	rand.seed(time.now().uni)
	len := 80
	mut inp := BitX.new(rand.next(len) + 1)
	for i := 0; i < 100; i++ {
		inp.resize(rand.next(len) + 1)
		inp.setBit(inp.getSize() - 1)
	}
	assert inp.getBit(inp.getSize() - 1) == 1
}

fn testXpos() {
	/**
	 * set arr size to 80
	 * test different sizes of subarr, from 1 to 80
	 * test different positions of subarr, from 0 to where it fits
	 * all arr here contain exactly one instanse of subarr,
	 * so search should return non-negative-values
	**/
	rand.seed(time.now().uni)
	len := 80
	mut result := 1
	for i := 1; i < len; i++ {	// subarr size
		for j := 0; j < len - i; j++ {	// subarr position in the arr
			// create the subarr
			mut subarr := BitX.new(i)

			// fill the subarr with random values
			for k := 0; k < i; k++ {
				if rand.next(2) == 1 {
					subarr.setBit(k)
				}
			}

			// make sure the subarr contains at least one set bit, selected randomly
			r := rand.next(i)
			subarr.setBit(r)

			// create the arr, make sure it contains the subarr
			mut arr := BitX.clone(subarr)

			// if there is space between the start of the arr and the sought subarr, fill it with zeroes
			if j > 0 {
				start := BitX.new(j)
				tmp := BitX.join(start, arr)
				arr = tmp
			}

			// if there is space between the sought subarr and the end of arr, fill it with zeroes
			if j + i < len {
				end := BitX.new(len - j - i)
				tmp2 := BitX.join(arr, end)
				arr = tmp2
			}

			// now let's test
			// the result should be equal to j
			if arr.pos(subarr) != j {
				result = 0
			}
		}
	}
	assert result == 1
}

fn testXrotate() {
	mut result := 1
	len := 80
	for i := 1; i < 80 && result == 1; i++ {
		mut chunk1 := BitX.new(i)
		chunk2 := BitX.new(len - i)
		chunk1.setAll()
		inp := BitX.join(chunk1, chunk2)
		output := inp.rotate(i)
		if output.getBit(len - i - 1) != 0 || output.getBit(len - i) != 1 {
			result = 0
		}
	}
	assert result == 1
}