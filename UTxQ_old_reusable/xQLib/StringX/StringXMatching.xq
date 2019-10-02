// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module StringX

#-js

// Levenshtein Distance Algorithm:
// To calculate the distance between two strings (lower is closer)
public fn levenshtein_distance(a, b string) int {
	mut f := [int(0)].repeat(b.len+1)
	for ca in a {
		mut j := 1
		mut fj1 := f[0]
		f[0]++
		for cb in b {
			mut mn := if f[j]+1 <= f[j-1]+1 { f[j]+1 } else { f[j-1]+1 }
			if cb != ca {
				mn = if mn <= fj1+1 { mn } else { fj1+1 }
			} else {
				mn = if mn <= fj1 { mn } else { fj1 }
			}
			fj1 = f[j]
			f[j] = mn
			j++
		}
	}
	return f[f.len-1]
}

// Levenshtein Distance Algorithm: 
// To calculate similarity of two strings as percentage (higher is closer)
public fn levenshtein_distance_percentage(a, b string) f32 {
	d := levenshteinDistance(a, b)
	l := if a.len >= b.len { a.len } else { b.len }
	return (1.00 - f32(d)/f32(l)) * 100.00
}

// Sørensen–Dice coefficient:
// Find similarity between two strings returns coefficient between
// 0.0 (not similar) and 1.0 (exact match).
public fn dice_coefficient(s1, s2 string) f32 {
	if s1.len == 0 || s2.len == 0 { return 0.0 }
	if s1 == s2 { return 1.0 }
	if s1.len < 2 || s2.len < 2 { return 0.0 }
	a := if s1.len > s2.len { s1 } else { s2 }
	b := if a == s1 { s2 } else { s1 }
	mut first_bigrams := map[string]int
	for i := 0; i < a.len-1; i++ {
		bigram := a.substr(i, i+2)
		first_bigrams[bigram] = if bigram in first_bigrams { first_bigrams[bigram]+1 } else { 1 }
	}
	mut intersection_size := 0
	for i := 0; i < b.len-1; i++ {
		bigram := b.substr(i, i+2)
		count := if bigram in first_bigrams { first_bigrams[bigram] } else { 0 }
		if count > 0 {
			first_bigrams[bigram] = count - 1
			intersection_size++
		}
	}
	return (2.0 * intersection_size) / (f32(a.len) + f32(b.len) - 2)
}