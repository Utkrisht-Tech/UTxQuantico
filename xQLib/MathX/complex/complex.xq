// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module complex

import MathX 

struct Complex {
	re f64
	im f64
}

public fn complex(re f64, im f64) Complex {
	return Complex{re, im}
}

// To String method
public fn (c Complex) str() string { 
	mut out := '$c.re'
	out += if c.im >= 0 {
		'+$c.im'
	}
	else {
		'$c.im'
	}
	out += 'i'
	return out
}

// Complex Modulus value
// mod() and abs() return the same
public fn (c Complex) abs() f64 {
	return C.hypot(c.re, c.im)
}
public fn (c Complex) mod() f64 {
	return c.abs()
}


// Complex Angle
public fn (c Complex) angle() f64 { 
	return MathX.atan2(c.im, c.re)
}

// Complex Addition c1 + c2
public fn (c1 Complex) + (c2 Complex) Complex {
	return Complex{c1.re + c2.re, c1.im + c2.im}
}

// Complex Substraction c1 - c2
public fn (c1 Complex) - (c2 Complex) Complex {
	return Complex{c1.re - c2.re, c1.im - c2.im}
}

// Complex Multiplication c1 * c2
// Currently Not Supported
// public fn (c1 Complex) * (c2 Complex) Complex {
// 	return Complex{
// 		(c1.re * c2.re) + ((c1.im * c2.im) * -1), 
// 		(c1.re * c2.im) + (c1.im * c2.re)
// 	}
// }

// Complex Division c1 / c2
// Currently Not Supported
// public fn (c1 Complex) / (c2 Complex) Complex {
// 	denom := (c2.re * c2.re) + (c2.im * c2.im)
// 	return Complex { 
// 		((c1.re * c2.re) + ((c1.im * -c2.im) * -1))/denom, 
// 		((c1.re * -c2.im) + (c1.im * c2.re))/denom
// 	}
// }

// Complex Addition c1.add(c2)
public fn (c1 Complex) add(c2 Complex) Complex {
	return c1 + c2
}

// Complex Subtraction c1.subtract(c2)
public fn (c1 Complex) subtract(c2 Complex) Complex {
	return c1 - c2
}

// Complex Multiplication c1.multiply(c2)
public fn (c1 Complex) multiply(c2 Complex) Complex {
	return Complex{
		(c1.re * c2.re) + ((c1.im * c2.im) * -1), 
		(c1.re * c2.im) + (c1.im * c2.re)
	}
}

// Complex Division c1.divide(c2)
public fn (c1 Complex) divide(c2 Complex) Complex {
	denom := (c2.re * c2.re) + (c2.im * c2.im)
	return Complex { 
		((c1.re * c2.re) + ((c1.im * -c2.im) * -1)) / denom, 
		((c1.re * -c2.im) + (c1.im * c2.re)) / denom
	}
}

// Complex Conjugate
public fn (c Complex) conjugate() Complex{
	return Complex{c.re, -c.im}
}

// Complex Additive Inverse
public fn (c Complex) addinv() Complex {
	return Complex{-c.re, -c.im}
}

// Complex Multiplicative Inverse
public fn (c Complex) mulinv() Complex {
	return Complex {
		c.re / (c.re * c.re + c.im * c.im),
		-c.im / (c.re * c.re + c.im * c.im)
	}
}
 
// Complex Power
public fn (c Complex) pow(n f64) Complex {
	r := MathX.pow(c.abs(), n)
	angle := c.angle()
	return Complex {
		r * MathX.cos(n * angle),
		r * MathX.sin(n * angle)
	}
}

// Complex nth root 
public fn (c Complex) root(n f64) Complex {
	return c.pow(1.0 / n)
}

// Complex Exponential
// Using Euler's Identity 
public fn (c Complex) exp() Complex {
	a := MathX.exp(c.re)
	return Complex {
		a * MathX.cos(c.im), 
		a * MathX.sin(c.im)
	}
}

// Complex Natural Logarithm
public fn (c Complex) ln() Complex {
	return Complex {
		MathX.ln(c.abs()),
		c.angle()
	}
}

// Complex Log Base Complex
public fn (c Complex) log(base Complex) Complex {
	return base.ln().divide(c.ln())
}

// Complex Argument
public fn (c Complex) arg() f64 {
	return MathX.atan2(c.im,c.re)
}

// Complex raised to Complex Power
public fn (c Complex) cpow(p Complex) Complex {
	a := c.arg()
	b := MathX.pow(c.re,2) + MathX.pow(c.im,2)
	d := p.re * a + (1.0/2) * p.im * MathX.log(b)
	t1 := MathX.pow(b,p.re/2) * MathX.exp(-p.im*a)
	return Complex{
		t1 * MathX.cos(d), 
		t1 * MathX.sin(d)
	}
}

// Complex Sin
public fn (c Complex) sin() Complex {
	return Complex{
		MathX.sin(c.re) * MathX.cosh(c.im),
		MathX.cos(c.re) * MathX.sinh(c.im)
	}
}

// Complex Cosine
public fn (c Complex) cos() Complex {
	return Complex{
		MathX.cos(c.re) * MathX.cosh(c.im),
		-(MathX.sin(c.re) * MathX.sinh(c.im))
	}
}

// Complex Tangent
public fn (c Complex) tan() Complex {
	return c.sin().divide(c.cos())
}

// Complex Cotangent
public fn (c Complex) cot() Complex {
	return c.cos().divide(c.sin())
}

// Complex Secant
public fn (c Complex) sec() Complex {
	return complex(1,0).divide(c.cos())
}

// Complex Cosecant
public fn (c Complex) csc() Complex {
	return complex(1,0).divide(c.sin())
}

// Complex Arc Sin (Sin Inverse)
public fn (c Complex) asin() Complex {
	return complex(0,-1).multiply(
			complex(0,1)
			.multiply(c)
			.add(
				complex(1,0)
				.subtract(c.pow(2))
				.root(2)
			)
			.ln()
	)
}

// Complex Arc Cosine (Cos Inverse)
public fn (c Complex) acos() Complex {
	return complex(0,-1).multiply(
		c.add(
			complex(0,1)
			.multiply(
				complex(1,0)
				.subtract(c.pow(2))
				.root(2)
			)
		)
		.ln()
	)
}

// Complex Arc Tangent (Tan Inverse)
public fn (c Complex) atan() Complex {
	i := complex(0,1)
	return complex(0,1.0/2).multiply(
		i.add(c)
		.divide(
			i.subtract(c)
		)
		.ln()
	)
}

// Complex Arc Cotangent (Cot Inverse)
// Based on 
public fn (c Complex) acot() Complex {
	return complex(1,0).divide(c).atan()
}

// Complex Arc Secant (Sec Inverse)
public fn (c Complex) asec() Complex {
	return complex(1,0).divide(c).acos()
}

// Complex Arc Cosecant (Cosec Inverse)
public fn (c Complex) acsc() Complex {
	return complex(1,0).divide(c).asin()
}

// Complex Hyperbolic Sin
public fn (c Complex) sinh() Complex {
	return Complex{
		MathX.cos(c.im) * MathX.sinh(c.re),
		MathX.sin(c.im) * MathX.cosh(c.re)
	}
}

// Complex Hyperbolic Cosine
public fn (c Complex) cosh() Complex {
	return Complex{
		MathX.cos(c.im) * MathX.cosh(c.re),
		MathX.sin(c.im) * MathX.sinh(c.re)
	}
}

// Complex Hyperbolic Tangent
public fn (c Complex) tanh() Complex {
	return c.sinh().divide(c.cosh())
}

// Complex Hyperbolic Cotangent
public fn (c Complex) coth() Complex {
	return c.cosh().divide(c.sinh())
}

// Complex Hyperbolic Secant
public fn (c Complex) sech() Complex {
	return complex(1,0).divide(c.cosh())
}

// Complex Hyperbolic Cosecant
public fn (c Complex) csch() Complex {
	return complex(1,0).divide(c.sinh())
}

// Complex Hyperbolic Arc Sin / Sin Inverse
public fn (c Complex) asinh() Complex {
	return c.add(
		c.pow(2)
		.add(complex(1,0))
		.root(2)
	).ln()
}

// Complex Hyperbolic Arc Consine / Consine Inverse
public fn (c Complex) acosh() Complex {
	if(c.re > 1) {
		return c.add(
			c.pow(2)
			.subtract(complex(1,0))
			.root(2)
		).ln()
	}
	else {
		one := complex(1,0)
		return c.add(
			c.add(one)
			.root(2)
			.multiply(
				c.subtract(one)
				.root(2)
			)
		).ln()
	}
}

// Complex Hyperbolic Arc Tangent / Tangent Inverse
public fn (c Complex) atanh() Complex {
	one := complex(1,0)
	if(c.re < 1) {
		return complex(1.0/2,0).multiply(
			one
			.add(c)
			.divide(
				one
				.subtract(c)
			)
			.ln()
		)
	}
	else {
		return complex(1.0/2,0).multiply(
			one
			.add(c)
			.ln()
			.subtract(
				one
				.subtract(c)
				.ln()
			)
		)
	}
}

// Complex Hyperbolic Arc Cotangent / Cotangent Inverse
public fn (c Complex) acoth() Complex {
	one := complex(1,0)
	if(c.re < 0 || c.re > 1) {
		return complex(1.0/2,0).multiply(
			c
			.add(one)
			.divide(
				c.subtract(one)
			)
			.ln()
		)
	}
	else {
		div := one.divide(c)
		return complex(1.0/2,0).multiply(
			one
			.add(div)
			.ln()
			.subtract(
				one
				.subtract(div)
				.ln()
			)
		)
	}
}

// Complex Hyperbolic Arc Secant / Secant Inverse
// For certain scenarios, Result mismatch in crossverification with Wolfram Alpha - analysis pending
// public fn (c Complex) asech() Complex {
// 	one := complex(1,0)
	// if(c.re < -1.0) {
	// 	return one.subtract(
	// 		one.subtract(
	// 			c.pow(2) 
	// 		)
	// 		.root(2)
	// 	)
	// 	.divide(c)
	// 	.ln()
	// }
	// else {
		// return one.add(
		// 	one.subtract(
		// 		c.pow(2) 
		// 	)
		// 	.root(2)
		// )
		// .divide(c)
		// .ln()
	// }
// }

// Complex Hyperbolic Arc Cosecant / Cosecant Inverse
public fn (c Complex) acsch() Complex {
	one := complex(1,0)
	if(c.re < 0) {
		return one.subtract(
			one.add(
				c.pow(2) 
			)
			.root(2)
		)
		.divide(c)
		.ln()
	} else {
		return one.add(
			one.add(
				c.pow(2) 
			)
			.root(2)
		)
		.divide(c)
		.ln()
	}
}

// Complex Equals
public fn (c1 Complex) equals(c2 Complex) bool {
	return (c1.re == c2.re) && (c1.im == c2.im)
}
