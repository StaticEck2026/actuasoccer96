# Port of SOURCE/MATHS.CPP  (assembled by tools/assemble.py - edit the files in parts/)
class_name Maths extends Glob
#******************************************************************************
#******************************************************************************
#
# Maths routines...
#
#******************************************************************************
#******************************************************************************

# int matherr(struct exception *)
static func matherr() -> int:
	keys[0x01] = 1			# Simulate escape.
	return 0

#******************************************************************************
#******************************************************************************

# void af_randomize()
static func af_randomize() -> void:
	rand_seed = s16(c_rand())

	seed = rand_seed & 127
#	printf("%d\n",seed&15);

#******************************************************************************
#******************************************************************************

# void random_vector(float &a,float &b)   -> returns [a, b]
static func random_vector(a: float, b: float) -> Array:
	var ang: int = s16((rand_seed & 32767) << 1)
	var ab: float = c_modf(float(ang) / PI)
	a = cos(ab)
	b = sin(ab)
	return [a, b]

#******************************************************************************
#******************************************************************************

# Returns a random value of ( 0 -> (Range-1) )

# int rand_range(int range)
static func rand_range(range_v: int) -> int:
	var rs: int = (seed * range_v) / 128
	return rs

#******************************************************************************
#******************************************************************************

# float calc_dist(float x,float y)
static func calc_dist(x: float, y: float) -> float:
	var r: float
	r = sqrt((x * x) + (y * y))
	if r > 0.1:
		return r
	else:
		return 0.1

