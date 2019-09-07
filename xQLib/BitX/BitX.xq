// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module BitX

/*
BitX is a module (shared library for UTxQuantico) for manipulating bits(0,1).

BitXSpace structure
------------------
The data structure used by BitX module to store Bit Arrays. This module
provides API (functions and methods) for accessing and modifying Bit Arrays.
*/

struct BitXSpace {
mut:
	size int
	//xspace *u32
	xspace []u32
}

// Internal Helper Functions & Methods  
const (
	SLOT_SIZE = 32
)

fn bitMask_in(bitnumber int) u32 {
	return u32(u32(1) << u32(bitnumber % SLOT_SIZE))
}

fn bitSlot_in(size int) int {
	return size / SLOT_SIZE
}

fn getBit_in(instance BitXSpace, bitnumber int) int {
	return (instance.xspace[bitSlot_in(bitnumber)] >> u32(bitnumber % SLOT_SIZE)) & 1
}

fn setBit_in(instance mut BitXSpace, bitnumber int) {
	instance.xspace[bitSlot_in(bitnumber)] = instance.xspace[bitSlot_in(bitnumber)] | bitMask_in(bitnumber)
}

fn clearBit_in(instance mut BitXSpace, bitnumber int) {
	instance.xspace[bitSlot_in(bitnumber)] = instance.xspace[bitSlot_in(bitnumber)] & ~bitMask_in(bitnumber)
}

fn toggleBit_in(instance mut BitXSpace, bitnumber int) {
	instance.xspace[bitSlot_in(bitnumber)] = instance.xspace[bitSlot_in(bitnumber)] ^ bitMask_in(bitnumber)
}
/*
#define TESTBIT(a, b) ((a)->xspace[BITSLOT(b)] & BITMASK(b))
*/

fn mini(inp1 int, inp2 int) int {
	if inp1 < inp2 {
		return inp1
	}
	else {
		return inp2
	}
}

fn bitNSlots_in(length int) int {
	return (length - 1) / SLOT_SIZE + 1
} 

fn clearTail_in(instance mut BitXSpace) {
	tail := instance.size % SLOT_SIZE
	if tail != 0 {
		// create a bitMask for the tail 
		mask := u32((1 << tail) - 1)
		// clear the extra bits 
		instance.xspace[bitNSlots_in(instance.size) - 1] = instance.xspace[bitNSlots_in(instance.size) - 1] & mask
	}
}

// Public API Functions & Methods 

// strToBitX() converts a string of characters ('0' and '1') to a bit
// array. Any character different from '0' is treated as '1'.

public fn strToBitX(inp string) BitXSpace {
	mut output := new(inp.len)
	for i := 0; i < inp.len; i++ {
		if inp[i] != 48 {
			output.setBit(i)
		}
	}
	return output
}

// bitXToStr() converts a bit array to a string of characters ('0' and '1') and
// return the string

public fn (inp BitXSpace) bitXToStr() string {
	mut output := ''
	for i := 0; i < inp.size; i++ {
		if inp.getBit(i) == 1 {
			output = output + '1'
		}
		else {
			output = output + '0'
		}
	}
	return output
}

//new(size) creates an empty Bit Array capable of storing 'size' bits.

public fn new(size int) BitXSpace {
	output := BitXSpace{
		size: size 
		//xspace: *u32(calloc(bitNSlots_in(size) * SLOT_SIZE / 8))
		xspace: [u32(0); bitNSlots_in(size)]
	}
	return output
}
/*
public fn remove(instance *BitXSpace) {
	free(instance.xspace)
	free(instance)
}
*/

// getBit() returns the value (0 or 1) of bit number 'bit_number' (count from
// 0)

public fn (instance BitXSpace) getBit(bitnumber int) int {
	if bitnumber >= instance.size {return 0}
	return getBit_in(instance, bitnumber)
}

// setBit() set bit number 'bit_number' to 1 (count from 0)

public fn (instance mut BitXSpace) setBit(bitnumber int) {
	if bitnumber >= instance.size {return}
	setBit_in(mut instance, bitnumber)
}

// clearBit() clears (sets to zero) bit number 'bit_number' (count from 0)

public fn (instance mut BitXSpace) clearBit(bitnumber int) {
	if bitnumber >= instance.size {return}
	clearBit_in(mut instance, bitnumber)
}

// setAll() sets all bits in the array to 1

public fn (instance mut BitXSpace) setAll() {
	for i := 0; i < bitNSlots_in(instance.size); i++ {
		instance.xspace[i] = u32(-1)
	}
	clearTail_in(mut instance)
}

// clearAll() clears (sets to zero) all bits in the array

public fn (instance mut BitXSpace) clearAll() {
	for i := 0; i < bitNSlots_in(instance.size); i++ {
		instance.xspace[i] = u32(0)
	}
}

// toggleBit() change the value (from 0 to 1 or from 1 to 0) of bit
// number 'bit_number'

public fn (instance mut BitXSpace) toggleBit(bitnumber int) {
	if bitnumber >= instance.size {return}
	toggleBit_in(mut instance, bitnumber)
}

// BW_and(inp1 BitXSpace, inp2 BitXSpace) perform logical AND operation on every 
// pair of bits from 'inp1' and 'inp2' and return the result as a new array. If 
// inputs differ in size, the tail of the longer one is ignored.

public fn BW_and(inp1 BitXSpace, inp2 BitXSpace) BitXSpace {
	size := mini(inp1.size, inp2.size)
	bitNSlots := bitNSlots_in(size)
	mut output := new(size)
	mut i := 0
	for i < bitNSlots {
		output.xspace[i] = inp1.xspace[i] & inp2.xspace[i]
		i++
	}
	clearTail_in(mut output)
	return output
}

// BW_not(inp BitXSpace) toggle all bits in a bit array and return the result as a new array

public fn BW_not(inp BitXSpace) BitXSpace {
	size := inp.size
	bitNSlots := bitNSlots_in(size)
	mut output := new(size)
	mut i := 0
	for i < bitNSlots {
		output.xspace[i] = ~inp.xspace[i]
		i++
	}
	clearTail_in(mut output)
	return output
}

// BW_or(inp1 BitXSpace, inp2 BitXSpace) perform logical OR operation on every 
// pair of bits from 'inp1' and 'inp2' and return the result as a new array. If 
// inputs differ in size, the tail of the longer one is ignored.

public fn BW_or(inp1 BitXSpace, inp2 BitXSpace) BitXSpace {
	size := mini(inp1.size, inp2.size)
	bitNSlots := bitNSlots_in(size)
	mut output := new(size)
	mut i := 0
	for i < bitNSlots {
		output.xspace[i] = inp1.xspace[i] | inp2.xspace[i]
		i++
	}
	clearTail_in(mut output)
	return output
}

// BW_xor(inp1 BitXSpace, inp2 BitXSpace) perform logical XOR operation on
// every pair of bits from 'input1' and 'input2' and return the result as a new
// array. If inputs differ in size, the tail of the longer one is ignored.

public fn BW_xor(inp1 BitXSpace, inp2 BitXSpace) BitXSpace {
	size := mini(inp1.size, inp2.size)
	bitNSlots := bitNSlots_in(size)
	mut output := new(size)
	mut i := 0
	for i < bitNSlots {
		output.xspace[i] = inp1.xspace[i] ^ inp2.xspace[i]
		i++
	}
	clearTail_in(mut output)
	return output
}

// join() concatenates two Bit Arrays and return the result as a new array.

public fn join(inp1 BitXSpace, inp2 BitXSpace) BitXSpace {
	output_size := inp1.size + inp2.size
	mut output := new(output_size)
	// copy the first input to output as is
	for i := 0; i < bitNSlots_in(inp1.size); i++ {
		output.xspace[i] = inp1.xspace[i]
	}

	// find offset bit and offset slot
	offset_bit := inp1.size % SLOT_SIZE
	offset_slot := inp1.size / SLOT_SIZE

	for i := 0; i < bitNSlots_in(inp2.size); i++ {
		output.xspace[i + offset_slot] =
		    output.xspace[i + offset_slot] |
		    u32(inp2.xspace[i] << u32(offset_bit))
	}

	/*
	 * If offset_bit is not zero, additional operations are needed.
	 * Number of iterations depends on the number of slots in output. Two
	 * options:
	 * (a) number of slots in output is the sum of inputs' slots. In this
	 * case, the number of bits in the last slot of output is less than the
	 * number of bits in second input (i.e. ), OR
	 * (b) number of slots of output is the sum of inputs' slots less one
	 * (i.e. less iterations needed). In this case, the number of bits in
	 * the last slot of output is greater than the number of bits in second
	 * input.
	 * If offset_bit is zero, no additional copies needed.
	 */

	if (output_size - 1) % SLOT_SIZE < (inp2.size - 1) % SLOT_SIZE {
		for i := 0; i < bitNSlots_in(inp2.size); i++ {
			output.xspace[i + offset_slot + 1] =
			    output.xspace[i + offset_slot + 1] |
			    u32(inp2.xspace[i] >> u32(SLOT_SIZE - offset_bit))
		}
	} else if (output_size - 1) % SLOT_SIZE > (inp2.size - 1) % SLOT_SIZE {
		for i := 0; i < bitNSlots_in(inp2.size) - 1; i++ {
			output.xspace[i + offset_slot + 1] =
			    output.xspace[i + offset_slot + 1] |
			    u32(inp2.xspace[i] >> u32(SLOT_SIZE - offset_bit))
		}
	}
	return output
}

// print(instance BitXSpace) send the content of a Bit Array to stdout as a
// string of characters ('0' and '1').

public fn print(instance BitXSpace) {
	mut i := 0
	for i < instance.size {
		if instance.getBit(i) == 1 {
			print('1')
		}
		else {
			print('0')
		}
		i++
	}
}

// getSize() returns the number of bits the array can hold

public fn (instance BitXSpace) getSize() int {
	return instance.size
}

// clone() create a copy of a Bit Array

public fn clone(inp BitXSpace) BitXSpace {
	bitNSlots := bitNSlots_in(inp.size)
	mut output := new(inp.size)
	mut i := 0
	for i < bitNSlots {
		output.xspace[i] = inp.xspace[i]
		i++
	}
	return output
}

// compare() compare two Bit Arrays bit by bit and return 'true' if they are
// identical by length and contents and 'false' otherwise.

public fn compare(inp1 BitXSpace, inp2 BitXSpace) bool {
	if inp1.size != inp2.size {return false}
	for i := 0; i < bitNSlots_in(inp1.size); i++ {
		if inp1.xspace[i] != inp2.xspace[i] {return false}
	}
	return true
}

// popcount() returns the number of set bits (ones) in the array

public fn (instance BitXSpace) popcount() int {
	size := instance.size
	bitNSlots := bitNSlots_in(size)
	tail := size % SLOT_SIZE
	mut count := 0
	for i := 0; i < bitNSlots - 1; i++ {
		for j := 0; j < SLOT_SIZE; j++ {
			if u32(instance.xspace[i] >> u32(j)) & u32(1) == u32(1) {
				count++
			}
		}
	}
	for j := 0; j < tail; j++ {
		if u32(instance.xspace[bitNSlots - 1] >> u32(j)) & u32(1) == u32(1) {
			count++
		}
	}
	return count
}

// hamming_dist () compute the Hamming distance between two Bit Arrays.

public fn hamming_dist(inp1 BitXSpace, inp2 BitXSpace) int {
	input_xored := BW_xor(inp1, inp2)
	return input_xored.popcount()
}

// pos(subarr) checks if the array contains a sub-array 'subarr' and returns its
// position if it does, -1 if it does not, and -2 on error.

// TODO:- Make it much faster using a Pattern Matching Algorithm
public fn (arr BitXSpace) pos(subarr BitXSpace) int {
	arr_size := arr.size
	subarr_size := subarr.size
	diff := arr_size - subarr_size

	// subarr longer than arr; return error code -2
	if diff < 0 {
		return -2
	}
	for i := 0; i <= diff; i++ {
		subarr_candidate := arr.slice(i, subarr_size + i)
		if compare(subarr_candidate, subarr) {
			// subarr matches a sub-array of arr; return starting position of the sub-array
			return i
		}
	}
	// nothing matched; return -1
	return -1
}

// slice() return a sub-array of bits between 'start_bit_number' (included) and 
// 'end_bit_number' (excluded)

public fn (inp BitXSpace) slice(_start int, _end int) BitXSpace {
	// boundary checks
	mut start := _start
	mut end := _end
	if end > inp.size {
		end = inp.size // or panic?
	}
	if start > end {
		start = end // or panic?
	}

	mut output := new(end - start)
	start_offset := start % SLOT_SIZE
	end_offset := (end - 1) % SLOT_SIZE
	start_slot := start / SLOT_SIZE
	end_slot := (end - 1) / SLOT_SIZE
	output_slots := bitNSlots_in(end - start)

	if output_slots > 1 {
		if start_offset != 0 {
			for i := 0; i < output_slots - 1; i++ {
				output.xspace[i] =
				    u32(inp.xspace[start_slot + i] >> u32(start_offset))
				output.xspace[i] = output.xspace[i] |
				    u32(inp.xspace[start_slot + i + 1] <<
				    u32(SLOT_SIZE - start_offset))
			}
		}
		else {
			for i := 0; i < output_slots - 1; i++ {
				output.xspace[i] =
				    u32(inp.xspace[start_slot + i])
			}
		}
	}

	if start_offset > end_offset {
		output.xspace[(end - start - 1) / SLOT_SIZE] =
		    u32(inp.xspace[end_slot - 1] >> u32(start_offset))
		mut mask := u32((1 << (end_offset + 1)) - 1)
		mask = inp.xspace[end_slot] & mask
		mask = u32(mask << u32(SLOT_SIZE - start_offset))
		output.xspace[(end - start - 1) / SLOT_SIZE] =
		    output.xspace[(end - start - 1) / SLOT_SIZE] | mask
	}
	else if start_offset == 0 {
		mut mask := u32(0)
		if end_offset == SLOT_SIZE - 1 {
			mask = u32(-1)
		}
		else {
			mask = u32(u32(1) << u32(end_offset + 1))
			mask = mask - u32(1)
		}
		output.xspace[(end - start - 1) / SLOT_SIZE] =
		    (inp.xspace[end_slot] & mask)
	}
	else {
		mut mask := u32(((1 << (end_offset - start_offset + 1)) - 1)  << start_offset)
		mask = inp.xspace[end_slot] & mask
		mask = u32(mask >> u32(start_offset))
		output.xspace[(end - start - 1) / SLOT_SIZE] =
		    output.xspace[(end - start - 1) / SLOT_SIZE] | mask
	}
	return output
}

// reverse() reverses the order of bits in the array (swap the first with the
// last, the second with the last but one and so on)

public fn (instance mut BitXSpace) reverse() BitXSpace {
	size := instance.size
	bitNSlots := bitNSlots_in(size)
	mut output := new(size)
	for i:= 0; i < (bitNSlots - 1); i++ {
		for j := 0; j < SLOT_SIZE; j++ {
			if u32(instance.xspace[i] >> u32(j)) & u32(1) == u32(1) {
				setBit_in(mut output, size - i * SLOT_SIZE - j - 1)
			}
		}
	}
	bits_in_last_input_slot := (size - 1) % SLOT_SIZE + 1
	for j := 0; j < bits_in_last_input_slot; j++ {
		if u32(instance.xspace[bitNSlots - 1] >> u32(j)) & u32(1) == u32(1) {
			setBit_in(mut output, bits_in_last_input_slot - j - 1)
		}
	}
	return output
}

// resize() changes the size of the bit array to 'new_size'

public fn (instance mut BitXSpace) resize(size int) {
	new_bitNSlots := bitNSlots_in(size)
	old_size := instance.size
	old_bitNSlots := bitNSlots_in(old_size)
	mut xspace := [u32(0); new_bitNSlots]
	for i := 0; i < old_bitNSlots && i < new_bitNSlots; i++ {
		xspace[i] = instance.xspace[i]
	}
	instance.xspace = xspace
	instance.size = size
	if size < old_size && size % SLOT_SIZE != 0 {
		clearTail_in(mut instance)
	}
}

// rotate(offset int) circular-shift the bits by 'offset' positions (move
// 'offset' bit to 0, 'offset+1' bit to 1, and so on)

public fn (instance BitXSpace) rotate(offset int) BitXSpace {
	/**
	 * This function "cuts" the BitXSpace into two and swaps them.
	 * If the offset is positive, the cutting point is counted from the
	 * beginning of the Bit Array, otherwise from the end.
	**/
	size := instance.size
	// removing extra rotations

	mut offset_internal := offset % size
	if (offset_internal == 0) {
		// nothing to shift
		return instance
	}
	if offset_internal < 0 {
		offset_internal = offset_internal + size
	}

	first_chunk := instance.slice(0, offset_internal)
	second_chunk := instance.slice(offset_internal, size)
	output := join(second_chunk, first_chunk)
	return output
}