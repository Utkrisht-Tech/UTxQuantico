import MathX

fn testXgcd() {
	assert MathX.gcd(6, 9) == 3
	assert MathX.gcd(6, -9) == 3
	assert MathX.gcd(-6, -9) == 3
	assert MathX.gcd(0, 0) == 0
}

fn testXlcm() {
	assert MathX.lcm(2, 3) == 6
	assert MathX.lcm(-2, 3) == 6
	assert MathX.lcm(-2, -3) == 6
	assert MathX.lcm(0, 0) == 0
}

fn testXdigits() {
	digits_in_10th_base := MathX.digits(125, 10)
	assert digits_in_10th_base[0] == 5
	assert digits_in_10th_base[1] == 2
	assert digits_in_10th_base[2] == 1

	digits_in_16th_base := MathX.digits(15, 16)
	assert digits_in_16th_base[0] == 15

	negative_digits := MathX.digits(-4, 2)
	assert negative_digits[2] == -1
}

/* 
fn testXfactorial() {
	assert MathX.factorial(12) == 479001600
	assert MathX.factorial(5) == 120
	assert MathX.factorial(0) == 1
}
*/ 

fn testXerf() {
	assert MathX.erf(0) == 0
	assert (MathX.erf(1.5) + MathX.erf(-1.5)).eq(0)
	assert MathX.erfc(0) == 1
	assert (MathX.erf(2.5) + MathX.erfc(2.5)).eq(1)
	assert (MathX.erfc(3.6) + MathX.erfc(-3.6)).eq(2)
}

fn testXgamma() {
	assert MathX.gamma(1) == 1
	assert MathX.gamma(5) == 24
	assert MathX.log_gamma(4.5) == MathX.ln(math.gamma(4.5))
}