extends Node3D
## Lightweight telegraph stubs for boss attacks (Skillz). Circle = slam AoE; line = charge / lantern beam;
## ring = donut (Bellwether aftershock); cone = sector (Choir Dirge Blast). Boss rework 2026-10-22: every shape now
## RAMPS UP (alpha 0.3 -> 1.0) to the moment of impact and circles/rings/cones show a fill that grows to the full
## shape on impact, so "when does it hit" reads without a number. A last 0.12 s flash, then it frees itself.
## Instantiate via preload("res://scripts/enemies/boss_telegraph.gd").new() then setup_circle / setup_line / setup_ring / setup_cone.
## Textured ground meshes (Desi assets/vfx/bosses/); falls back to flat colour if art missing.
## See /workspace/desi-models/boss_vfx/HANDOFF.md. No class_name (avoids self-referential .new()).

enum Kind { CIRCLE, LINE, RING, CONE }
const FLASH := 0.12
const VFX_PATH := "res://assets/vfx/bosses/boss_vfx.gd"

var kind: Kind = Kind.CIRCLE
var radius: float = 3.5
var length: float = 10.0
var width: float = 0.6
var color: Color = Color(1.0, 0.25, 0.15, 0.45)
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _t: float = 0.0
var _dur: float = 1.0
var inner: float = 0.0 ## ring inner radius
var half_angle: float = 28.0 ## cone half angle (deg)
var _fill: MeshInstance3D
var _fill_mat: StandardMaterial3D


func setup_circle(at: Vector3, rad: float, duration: float, col: Color = Color(1.0, 0.35, 0.1, 0.5)) -> void:
	kind = Kind.CIRCLE
	radius = rad
	color = col
	_dur = maxf(duration, 0.05)
	global_position = Vector3(at.x, at.y + 0.05, at.z)
	_rebuild()


func setup_line(from: Vector3, dir: Vector3, len: float, duration: float, col: Color = Color(1.0, 0.15, 0.1, 0.55), wid: float = 0.55) -> void:
	kind = Kind.LINE
	length = len
	width = wid
	color = col
	_dur = maxf(duration, 0.05)
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	global_position = Vector3(from.x, from.y + 0.05, from.z) + flat * (len * 0.5)
	rotation.y = atan2(-flat.x, -flat.z)
	_rebuild()


func setup_ring(at: Vector3, r_in: float, r_out: float, duration: float, col: Color = Color(1.0, 0.35, 0.1, 0.5)) -> void:
	kind = Kind.RING
	inner = r_in
	radius = r_out
	color = col
	_dur = maxf(duration, 0.05)
	global_position = Vector3(at.x, at.y + 0.05, at.z)
	_rebuild()


func setup_cone(from: Vector3, dir: Vector3, len: float, half_deg: float, duration: float, col: Color = Color(0.45, 0.6, 1.0, 0.5)) -> void:
	kind = Kind.CONE
	length = len
	half_angle = half_deg
	color = col
	_dur = maxf(duration, 0.05)
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	global_position = Vector3(from.x, from.y + 0.05, from.z)
	rotation.y = atan2(-flat.x, -flat.z)
	_rebuild()


static func spawn_ring(parent: Node3D, at: Vector3, r_in: float, r_out: float, duration: float, col: Color = Color(1.0, 0.35, 0.1, 0.5)) -> Node3D:
	var t: Node3D = (load("res://scripts/enemies/boss_telegraph.gd") as GDScript).new()
	parent.add_child(t)
	t.call("setup_ring", at, r_in, r_out, duration, col)
	return t


static func spawn_cone(parent: Node3D, from: Vector3, dir: Vector3, len: float, half_deg: float, duration: float, col: Color = Color(0.45, 0.6, 1.0, 0.5)) -> Node3D:
	var t: Node3D = (load("res://scripts/enemies/boss_telegraph.gd") as GDScript).new()
	parent.add_child(t)
	t.call("setup_cone", from, dir, len, half_deg, duration, col)
	return t


## Convenience: create + add_child + setup_circle.
static func spawn_circle(parent: Node3D, at: Vector3, rad: float, duration: float, col: Color = Color(1.0, 0.35, 0.1, 0.5)) -> Node3D:
	var scr: GDScript = load("res://scripts/enemies/boss_telegraph.gd") as GDScript
	var t: Node3D = scr.new()
	parent.add_child(t)
	t.call("setup_circle", at, rad, duration, col)
	return t


static func spawn_line(parent: Node3D, from: Vector3, dir: Vector3, len: float, duration: float, col: Color = Color(1.0, 0.15, 0.1, 0.55), wid: float = 0.55) -> Node3D:
	var scr: GDScript = load("res://scripts/enemies/boss_telegraph.gd") as GDScript
	var t: Node3D = scr.new()
	parent.add_child(t)
	t.call("setup_line", from, dir, len, duration, col, wid)
	return t


func _make_mat(c: Color) -> StandardMaterial3D:
	var path := "res://assets/vfx/bosses/tg_circle.png"
	match kind:
		Kind.RING:
			path = "res://assets/vfx/bosses/tg_ring.png"
		Kind.CONE:
			path = "res://assets/vfx/bosses/tg_cone.png"
		Kind.LINE:
			path = "res://assets/vfx/bosses/tg_line.png"
		_:
			path = "res://assets/vfx/bosses/tg_circle.png"
	if ResourceLoader.exists(VFX_PATH):
		return (load(VFX_PATH) as GDScript).make_mat(c, path)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


## Flat annulus / sector in the XZ plane (local -Z = forward for cones). UVs map the unit disc for Desi masks.
static func _flat_mesh(r_in: float, r_out: float, a0: float, a1: float, segs: int) -> ArrayMesh:
	if ResourceLoader.exists(VFX_PATH):
		return (load(VFX_PATH) as GDScript).flat_mesh(r_in, r_out, a0, a1, segs)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var span := maxf(r_out, 0.001) * 2.0
	for i in segs:
		var t0 := lerpf(a0, a1, float(i) / segs)
		var t1 := lerpf(a0, a1, float(i + 1) / segs)
		var d0 := Vector3(sin(t0), 0.0, -cos(t0))
		var d1 := Vector3(sin(t1), 0.0, -cos(t1))
		var p00 := d0 * r_in
		var p01 := d1 * r_in
		var p10 := d0 * r_out
		var p11 := d1 * r_out
		for v in [p00, p10, p11]:
			st.set_uv(Vector2(v.x / span + 0.5, v.z / span + 0.5))
			st.add_vertex(v)
		if r_in > 0.001:
			for v in [p00, p11, p01]:
				st.set_uv(Vector2(v.x / span + 0.5, v.z / span + 0.5))
				st.add_vertex(v)
	return st.commit()


func _rebuild() -> void:
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mat = _make_mat(color)
		_mesh.material_override = _mat
		add_child(_mesh)
		_fill = MeshInstance3D.new()
		_fill_mat = _make_mat(color)
		_fill.material_override = _fill_mat
		_fill.position.y = 0.01
		add_child(_fill)
	_mat.albedo_color = color
	_fill_mat.albedo_color = color
	match kind:
		Kind.CIRCLE:
			_mesh.mesh = _flat_mesh(0.0, radius, 0.0, TAU, 32)
			_fill.mesh = _flat_mesh(0.0, radius, 0.0, TAU, 32)
		Kind.RING:
			_mesh.mesh = _flat_mesh(inner, radius, 0.0, TAU, 40)
			_fill.mesh = _flat_mesh(inner, radius, 0.0, TAU, 40)
		Kind.CONE:
			var h := deg_to_rad(half_angle)
			_mesh.mesh = _flat_mesh(0.0, length, -h, h, 16)
			_fill.mesh = _flat_mesh(0.0, length, -h, h, 16)
		_:
			# Soft lane from Desi tg_line (quad in XZ) so the mask UVs read; falls back to a box.
			var lane := _flat_mesh(0.0, 1.0, 0.0, TAU, 4)  # placeholder
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_normal(Vector3.UP)
			var hw := width * 0.5
			var hl := length * 0.5
			var corners := [
				Vector3(-hw, 0, -hl), Vector3(hw, 0, -hl), Vector3(hw, 0, hl),
				Vector3(-hw, 0, -hl), Vector3(hw, 0, hl), Vector3(-hw, 0, hl),
			]
			var uvs := [
				Vector2(0, 0), Vector2(1, 0), Vector2(1, 1),
				Vector2(0, 0), Vector2(1, 1), Vector2(0, 1),
			]
			for i in corners.size():
				st.set_uv(uvs[i])
				st.add_vertex(corners[i])
			lane = st.commit()
			_mesh.mesh = lane
			_fill.mesh = lane
	_apply_progress(0.0)


## Fill grows from the centre/origin to the full shape at impact (line: from the boss end).
func _apply_progress(p: float) -> void:
	p = clampf(p, 0.0, 1.0)
	var c := color
	c.a = color.a * (0.3 + 0.7 * p)
	if _t > _dur:
		c.a = color.a * 1.4
	_mat.albedo_color = c
	var f := color
	f.a = minf(color.a * 1.35, 0.9)
	_fill_mat.albedo_color = f
	match kind:
		Kind.CIRCLE:
			_fill.scale = Vector3(maxf(p, 0.001), 1.0, maxf(p, 0.001))
		Kind.RING:
			_fill.visible = p > 0.5 and _t <= _dur + FLASH # ring: alpha ramp, then the solid flash (no growing fill)
		Kind.CONE:
			_fill.scale = Vector3(maxf(p, 0.001), 1.0, maxf(p, 0.001))
		_:
			_fill.scale = Vector3(1.0, 1.0, maxf(p, 0.001))
			_fill.position = Vector3(0.0, 0.01, length * 0.5 * (1.0 - p))


func _ready() -> void:
	if _mesh == null:
		_rebuild()


func _process(delta: float) -> void:
	_t += delta
	_apply_progress(_t / _dur)
	if _t >= _dur + FLASH:
		queue_free()
