const (
	a = 3
	u = u64(1)
)

fn testXconst() {
	b := (true && true) || false
	assert b == true
	assert a == 3
	assert u == u64(1)
}

fn testXstr_methods() {
	assert i8(1).str() == '1'
	assert i8(-1).str() == '-1'
	assert i16(1).str() == '1'
	assert i16(-1).str() == '-1'
	assert int(1).str() == '1'
	assert int(-1).str() == '-1'
	assert i64(1).str() == '1'
	assert i64(-1).str() == '-1'

	// assert byte(1).str() == '1'
	// assert byte(-1).str() == '255'
	assert u16(1).str() == '1'
	assert u16(-1).str() == '65535'
	assert u32(1).str() == '1'
	assert u32(-1).str() == '4294967295'
	assert u64(1).str() == '1'
	assert u64(-1).str() == '18446744073709551615'
}

/*
fn testXcmp() {
	assert 1 != 2
	assert 1 <= 2
	assert 1 >= 0
}
*/