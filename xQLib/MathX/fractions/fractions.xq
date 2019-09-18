// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module fractions

import MathX

// Fraction Struct
struct Fraction {
	n i64
	d i64
}

// Creates a Fraction, adds a boundary condition
public fn fraction(n i64, d i64) Fraction{
	if d != 0 {
		return Fraction{n, d}
	} 
	else {
		panic('Denominator cannot be zero')
	}
}

// To String method
public fn (f Fraction) str() string { 
	return '$f.n/$f.d' 
}

// Fraction add using operator overloading
public fn (f1 Fraction) + (f2 Fraction) Fraction {
	if f1.d == f2.d {
		return Fraction{f1.n + f2.n, f1.d}
	}
	else {
		return Fraction{(f1.n * f2.d) + (f2.n * f1.d), f1.d * f2.d}
	}
}

// Fraction subtract using operator overloading
public fn (f1 Fraction) - (f2 Fraction) Fraction {
	if f1.d == f2.d {
		return Fraction{f1.n - f2.n, f1.d}
	}
	else {
		return Fraction{(f1.n * f2.d) - (f2.n * f1.d), f1.d * f2.d}
	}
}

// Fraction multiply using operator overloading
// public fn (f1 Fraction) * (f2 Fraction) Fraction {
// 	return Fraction{f1.n * f2.n,f1.d * f2.d}
// }

// Fraction divide using operator overloading
// public fn (f1 Fraction) / (f2 Fraction) Fraction {
// 	return Fraction{f1.n * f2.d,f1.d * f2.n}
// }

// Fraction add method
public fn (f1 Fraction) add(f2 Fraction) Fraction {
	return f1 + f2
}

// Fraction subtract method
public fn (f1 Fraction) subtract(f2 Fraction) Fraction {
	return f1 - f2
}

// Fraction multiply method
public fn (f1 Fraction) multiply(f2 Fraction) Fraction {
	return Fraction{f1.n * f2.n, f1.d * f2.d}
}

// Fraction divide method
public fn (f1 Fraction) divide(f2 Fraction) Fraction {
	return Fraction{f1.n * f2.d, f1.d * f2.n}
}

// Fraction reciprocal method
public fn (f1 Fraction) reciprocal() Fraction {
	return Fraction{f1.d, f1.n}
}

// Fraction method which gives greatest common divisor of numerator and denominator
public fn (f1 Fraction) gcd() i64 {
	return MathX.gcd(f1.n, f1.d)
}

// Fraction method which reduces the fraction
public fn (f1 Fraction) reduce() Fraction {
	cf := f1.gcd()
	return Fraction{f1.n / cf, f1.d / cf}
}

// Converts Fraction to decimal
public fn (f1 Fraction) f64() f64 {
	return f64(f1.n) / f64(f1.d)
}

// Compares two Fractions
public fn (f1 Fraction) equals(f2 Fraction) bool {
	r1 := f1.reduce()
	r2 := f2.reduce()
	return (r1.n == r2.n) && (r1.d == r2.d)
}