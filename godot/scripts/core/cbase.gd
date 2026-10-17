# C runtime helpers used by the ported match engine.
# Root of the class chain:  CBase <- GlobConsts <- Glob <- (game modules).
class_name CBase extends RefCounted

const TRUE := 1
const FALSE := 0
const NULL_PTR = null

# ---- integer width emulation (Watcom: char is UNSIGNED, short is 16 bit) ----
static func u8(v: int) -> int:
	return v & 0xFF

static func s8(v: int) -> int:
	v &= 0xFF
	return v - 256 if v > 127 else v

static func u16(v: int) -> int:
	return v & 0xFFFF

static func s16(v: int) -> int:
	v &= 0xFFFF
	return v - 65536 if v > 32767 else v

static func s32(v: int) -> int:
	v &= 0xFFFFFFFF
	return v - 4294967296 if v > 2147483647 else v

# C truthiness -> int (for expressions like  x = (a>b);  or  x = a && b; )
static func bi(b) -> int:
	return 1 if b else 0

# C abs() is the INTEGER abs: abs(float) truncates toward zero first
# (verified in the original object code: CHP / fistp then call abs).
static func iabs(v) -> int:
	return absi(int(v))

# fabs() on floats.
static func fabs(v: float) -> float:
	return absf(v)

# C float->int conversion (truncation toward zero).
static func ftoi(v: float) -> int:
	return int(v)

# ---- Watcom C library rand()/srand() (Open Watcom clib: LCG, 15 bit result) ----
static var _rand_next: int = 1

static func c_srand(seed_v: int) -> void:
	_rand_next = seed_v & 0xFFFFFFFF

static func c_rand() -> int:
	_rand_next = (_rand_next * 1103515245 + 12345) & 0xFFFFFFFF
	return (_rand_next >> 16) & 0x7FFF

# modf(): returns the fractional part (C stores the integer part via pointer;
# the game only ever uses the fractional part).
static func c_modf(v: float) -> float:
	return v - float(int(v))

# MIN/MAX macros
static func cmin(a, b):
	return a if a < b else b

static func cmax(a, b):
	return a if a > b else b

# ---- function-like macros of the missing game header ----
# AFEQS(a,b): approximate equality of ABS(a) with b
static func AFEQS(a, b) -> bool:
	return (absf(a) < b + 0.001) and (absf(a) > b - 0.001)

# LIMIT(v,lo,hi)
static func LIMIT(v, lo, hi):
	return lo if v < lo else (hi if v > hi else v)

# ---- array allocation helpers (used by the generated glob.gd) ----
static func _arr(n: int, v) -> Array:
	var a := []
	a.resize(n)
	a.fill(v)
	return a

static func _sarr(n: int, cls) -> Array:
	var a := []
	for i in n:
		a.append(cls.new())
	return a

# Nested arrays; dims listed outermost first (C order).
static func _narr(d: Array, v) -> Array:
	if d.size() == 1:
		return _arr(d[0], v)
	var a := []
	for i in d[0]:
		a.append(_narr(d.slice(1), v))
	return a

static func _snarr(d: Array, cls) -> Array:
	if d.size() == 1:
		return _sarr(d[0], cls)
	var a := []
	for i in d[0]:
		a.append(_snarr(d.slice(1), cls))
	return a

# #define ABS(a) (( (a) >= 0 ) ? (a):-(a))   -- type preserving (float stays float)
static func ABS(a):
	return a if a >= 0 else -a
