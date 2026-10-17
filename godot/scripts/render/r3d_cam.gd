# The 3DENG.C viewing transform (render3d "Prepare viewing vector vars" /
# "Make global rotation matrix") and the per-point perspective used by the
# addobj*() routines.  Engine world space: X = game x, Y = height, Z = -game y
# (left-handed).  Godot space: (X, Y, -Z).
class_name R3DCam extends RefCounted

const SCREENDIST := 15.0
const CUTOFFDIST := 5.0

# buffer (clip) size in engine pixels and the scale used for q
var W: int = 640
var H: int = 400
var q: int = 440            # short q  (focal length, pixels)
var qa: float = 8.8
var persc: float = 29.3
var scrdr: float = 1.0 / SCREENDIST
var cth: float = 1.0
var sth: float = 0.0
var cph: float = 1.0
var sph: float = 0.0
# rot matrix rows (r00..r23), engine
var r00: float; var r01: float; var r02: float; var r03: float
var r10: float; var r11: float; var r12: float; var r13: float
var r20: float; var r21: float; var r22: float; var r23: float
var view := Vector3.ZERO     # camera position, engine coords

# render3d(buffer, viewx,viewy,viewz, targx,targy,targz, vdist)
func setup(viewx: float, viewy: float, viewz: float, targx: float, targy: float, targz: float,
		vdist: float, scale_x: float, scale_y: float, w: int, h: int) -> void:
	W = w
	H = h
	q = int(vdist * ((scale_x + scale_y) / 2.0))
	if q < 1:
		q = 1
	qa = float(q) * 2.0 / 100.0
	persc = float(q) * scrdr
	viewz = -viewz
	targz = -targz
	targx -= viewx
	targy -= viewy
	targz -= viewz
	var hr: float = targx * targx + targz * targz
	if hr < 1:
		hr = 1
		targz = 1
	var r: float = sqrt(hr + targy * targy)
	hr = sqrt(hr)
	cth = targz / hr
	sth = targx / hr
	cph = hr / r
	sph = targy / r
	view = Vector3(viewx, viewy, viewz)
	# tmp (rotation) * translation
	r00 = cth;              r01 = 0.0;  r02 = -sth
	r10 = -sth * sph;       r11 = cph;  r12 = -cth * sph
	r20 = sth * cph;        r21 = sph;  r22 = cth * cph
	r03 = -(r00 * viewx + r01 * viewy + r02 * viewz)
	r13 = -(r10 * viewx + r11 * viewy + r12 * viewz)
	r23 = -(r20 * viewx + r21 * viewy + r22 * viewz)

# depth of an engine point (objdep)
func depth(x: float, y: float, z: float) -> float:
	return x * r20 + y * r21 + z * r22 + r23

# rotate an engine point into view space (rx, ry, rz)
func to_view(p: Vector3) -> Vector3:
	return Vector3(p.x * r00 + p.y * r01 + p.z * r02 + r03,
		p.x * r10 + p.y * r11 + p.z * r12 + r13,
		p.x * r20 + p.y * r21 + p.z * r22 + r23)

# addobjy-style projection incl. the "alternative perspective" for rz<SCREENDIST.
# returns Vector3(rz, screen x, screen y (up))
func project(p: Vector3) -> Vector3:
	var rv := to_view(p)
	var rz := rv.z
	var qrz: float
	if rz < SCREENDIST:
		qrz = 1.5 - rz * scrdr
		qrz *= qrz
		qrz = persc * (qrz + .75)
	else:
		qrz = float(q) / rz
	return Vector3(rz, rv.x * qrz + float(W >> 1), rv.y * qrz + float(H >> 1))

# Godot world position of the engine-screen point (sx, sy up) placed at view depth d
# (projects back exactly onto (sx, sy) through the matching Camera3D).
func unproject_godot(sx: float, sy: float, d: float) -> Vector3:
	var rx := (sx - float(W >> 1)) * d / float(q)
	var ry := (sy - float(H >> 1)) * d / float(q)
	# engine world = R^T * (rx, ry, d) + view
	var ex := r00 * rx + r10 * ry + r20 * d + view.x
	var ey := r01 * rx + r11 * ry + r21 * d + view.y
	var ez := r02 * rx + r12 * ry + r22 * d + view.z
	return Vector3(ex, ey, -ez)

# Configure a Godot camera to show exactly this view (H rows <-> viewport height).
func apply_to(c: Camera3D) -> void:
	var right := Vector3(r00, r01, -r02)
	var up := Vector3(r10, r11, -r12)
	var fwd := Vector3(r20, r21, -r22)
	c.transform = Transform3D(Basis(right, up, -fwd), Vector3(view.x, view.y, -view.z))
	c.keep_aspect = Camera3D.KEEP_HEIGHT
	c.fov = rad_to_deg(2.0 * atan((float(H) / 2.0) / float(q)))
