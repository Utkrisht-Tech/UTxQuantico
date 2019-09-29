// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module MathX

// NOTE:
// All functions are sorted alphabetically.

const (
	e   = 2.71828182845904523536028747135266249775724709369995957496696763
	pi  = 3.14159265358979323846264338327950288419716939937510582097494459
	phi = 1.61803398874989484820458683436563811772030917980576286213544862
	tau = 6.28318530717958647692528676655900576839433879875021164194988918

	sqrt2    = 1.41421356237309504880168872420969807856967187537694807317667974
	sqrt_e   = 1.64872127070012814684865078781416357165377610071014801157507931
	sqrt_pi  = 1.77245385090551602729816748334114518279754945612238712821380779
	sqrt_phi = 1.27201964951406896425242246173749149171560804184009624861664038
    sqrt_tau = 2.50662827463100050241576528481104525300698674060993831662992357

	ln2    = 0.693147180559945309417232121458176568075500134360255254120680009
	log2e  = 1.442695040888963407359924681001892137426645954152985934135449406
	ln10   = 2.30258509299404568401799145468436420760110148862877297603332790
	log10e = 0.434294481903251827651128918916605082294397005803666566114453783
)

const (
        MaxI8   = 127
        MinI8   = -128
        MaxI16  = 32767
        MinI16  = -32768
        MaxI32  = 2147483647
        MinI32  = -2147483648
//        MaxI64  = ((1<<63) - 1)
//        MinI64  = (-(1 << 63) )
        MaxU8  = 255
        MaxU16 = 65535
        MaxU32 = 4294967295
        MaxU64 = 18446744073709551615
)

// Returns the absolute value.
public fn abs(a f64) f64 {
	if a < 0 {
		return -a
	}
	return a
}

fn C.acos(a f64) f64

// acos: Calculates inverse cosine (arccosine).
public fn acos(a f64) f64 {
	return C.acos(a)
}

// asin: Calculates inverse sine (arcsine).
public fn asin(a f64) f64 {
	return C.asin(a)
}

// atan: Calculates inverse tangent (arctangent).
public fn atan(a f64) f64 {
	return C.atan(a)
}

// atan2: Calculates inverse tangent with two arguments, returns the angle between the X axis and the point.
public fn atan2(a, b f64) f64 {
	return C.atan2(a, b)
}

// cbrt: Calculates cubic root.
public fn cbrt(a f64) f64 {
	return C.cbrt(a)
}

// ceil: Ceturns the nearest integer greater or equal to the provided value.
public fn ceil(a f64) int {
	return C.ceil(a)
}

// cos: Calculates cosine.
public fn cos(a f64) f64 {
	return C.cos(a)
}

// cosh: Calculates hyperbolic cosine.
public fn cosh(a f64) f64 {
	return C.cosh(a)
}

// degrees: convert from radians to degrees.
public fn degrees(radians f64) f64 {
	return radians * (180.0 / pi)
}

// exp: Calculates exponent of the number (math.pow(math.e, a)).
public fn exp(a f64) f64 {
	return C.exp(a)
}

// digits: Returns an array of the digits of n in the given base.
public fn digits(_n, base int) []int {
	mut n := _n
	mut sign := 1
	if n < 0 {
		sign = -1
		n = -n
	}
	mut res := []int
	for n != 0 {
		res << (n % base) * sign
		n /= base
	}
	return res
}

// erf: Computes the error function value
public fn erf(a f64) f64 {
	return C.erf(a)
}

// erfc: Computes the complementary error function value
public fn erfc(a f64) f64 {
	return C.erfc(a)
}

// exp2: Returns the base-2 exponential function of a (math.pow(2, a)).
public fn exp2(a f64) f64 {
	return C.exp2(a)
}

// factorial: Calculates the factorial of the provided value.
// TODO bring back once multiple value functions are implemented
/*
fn recursive_product( n int, current_number_ptr &int) int{
    mut m := n / 2
    if (m == 0){
        return *current_number_ptr += 2
    }
    if (n == 2){
        return (*current_number_ptr += 2) * (*current_number_ptr += 2)
    }
    return recursive_product((n - m), *current_number_ptr) * recursive_product(m, *current_number_ptr)
}

public fn factorial(n int) i64 {
    if n < 0 {
        panic('factorial: Cannot find factorial of negative number')
    }
    if n < 2 {
        return i64(1)
    }
    mut r := 1
    mut p := 1
    mut current_number := 1
    mut h := 0
    mut shift := 0
    mut high := 1
    mut len := high
    mut log2n := int(floor(log2(n)))
    for ;h != n; {
        shift += h
        h = n >> log2n
        log2n -= 1
        len = high
        high = (h - 1) | 1
        len = (high - len)/2
        if (len > 0){
            p *= recursive_product(len, &current_number)
            r *= p
        }
    }
    return i64((r << shift))
}
*/

// floor: Returns the nearest integer lower or equal of the provided value.
public fn floor(a f64) f64 {
	return C.floor(a)
}

// fmod: Returns the floating-point remainder of number / denom (rounded towards zero):
public fn fmod(a, b f64) f64 {
	return C.fmod(a, b)
}

// gamma: Computes the gamma function value
public fn gamma(a f64) f64 {
	return C.tgamma(a)
}

// gcd: Calculates greatest common (positive) divisor (or zero if a and b are both zero).
public fn gcd(a_, b_ i64) i64 {
	mut a := a_
	mut b := b_
	if a < 0 {
		a = -a
	}
	if b < 0 {
		b = -b
	}
	for b != 0 {
		a %= b
		if a == 0 {
			return b
		}
		b %= a
	}
	return a
}

// Returns hypotenuse of a right triangle.
public fn hypot(a, b f64) f64 {
	return C.hypot(a, b)
}

// lcm: Calculates least common (non-negative) multiple.
public fn lcm(a, b i64) i64 {
	if a == 0 {
		return a
	}
	res := a * (b / gcd(b, a))
	if res < 0 {
		return -res
	}
	return res
}

// ln: Calculates natural (base-e) logarithm of the provided value.
public fn ln(a f64) f64 {
	return C.log(a)
}

// log2: Calculates base-2 logarithm of the provided value.
public fn log2(a f64) f64 {
	return C.log2(a)
}

// log10: Calculates the common (base-10) logarithm of the provided value.
public fn log10(a f64) f64 {
	return C.log10(a)
}

// log_gamma: Computes the log-gamma function value
public fn log_gamma(a f64) f64 {
	return C.lgamma(a)
}

// log: Calculates base-N logarithm of the provided value.
public fn log(a, b f64) f64 {
	return C.log(a) / C.log(b)
}

// max: Returns the maximum value of the two provided.
public fn max(a, b f64) f64 {
	if a > b {
		return a
	}
	return b
}

// min: Returns the minimum value of the two provided.
public fn min(a, b f64) f64 {
	if a < b {
		return a
	}
	return b
}

// pow: Returns base raised to the provided power.
public fn pow(a, b f64) f64 {
	return C.pow(a, b)
}

// radians: Convert from degrees to radians
public fn radians(degrees f64) f64 {
	return degrees * (pi / 180.0)
}

// round: Returns the integer nearest to the provided value.
public fn round(f f64) f64 {
	return C.round(f)
}

// sin: Calculates sine.
public fn sin(a f64) f64 {
	return C.sin(a)
}

// sinh: Calculates hyperbolic sine.
public fn sinh(a f64) f64 {
	return C.sinh(a)
}

// sqrt: Calculates square-root of the provided value.
public fn sqrt(a f64) f64 {
	return C.sqrt(a)
}
// tan: Calculates tangent.
public fn tan(a f64) f64 {
	return C.tan(a)
}

// tanh: Calculates hyperbolic tangent.
public fn tanh(a f64) f64 {
	return C.tanh(a)
}

// trunc: Returns the nearest integral value that is not larger in magnitude than x.
public fn trunc(x f64) f64 {
	return C.trunc(a)
}