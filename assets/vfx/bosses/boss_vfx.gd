extends RefCounted
## Desi boss telegraph / zone / stage / Frenzy visuals (playtest #15).
## White RGBA masks under res://assets/vfx/bosses/; tint with bosses[id].colors at spawn.
## Timing contract (Skillz boss_telegraph): alpha 0.3→1.0 over `a` s, 0.12 s flash at impact.
## Unit radius = 1.0 (XZ); scale the node by the real radius. Path-loaded (no class_name).
## Skillz wires this via patches/boss_telegraph_hookup (see desi-models/boss_vfx/HANDOFF.md).

const DIR := "res://assets/vfx/bosses/"
const TEX_CIRCLE := DIR + "tg_circle.png"
const TEX_RIM := DIR + "tg_circle_rim.png"
const TEX_RING := DIR + "tg_ring.png"
const TEX_CONE := DIR + "tg_cone.png"
const TEX_LINE := DIR + "tg_line.png"
const TEX_ZONE := DIR + "zone_fill.png"
const TEX_BURST := DIR + "zone_burst.png"
const TEX_STAGE := DIR + "stage_ring.png"
const TEX_FRENZY := DIR + "frenzy_glow.png"
const TEX_BLINK := DIR + "blink_mark.png"
const FLASH := 0.12

static var _cache: Dictionary = {}


static func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func make_mat(col: Color, tex_path: String = TEX_CIRCLE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	var t := _tex(tex_path)
	if t != null:
		m.albedo_texture = t
	return m


## Flat annulus / sector in XZ. UV maps the unit disc (u,v in 0..1 over the AABB of the outer radius).
static func flat_mesh(r_in: float, r_out: float, a0: float, a1: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var span := maxf(r_out, 0.001) * 2.0
	for i in segs:
		var t0 := lerpf(a0, a1, float(i) / segs)
		var t1 := lerpf(a0, a1, float(i + 1) / segs)
		var d0 := Vector3(sin(t0), 0.0, -cos(t0))
		var d1 := Vector3(sin(t1), 0.0, -cos(t1))
		var verts: Array = [d0 * r_in, d0 * r_out, d1 * r_out]
		if r_in > 0.001:
			verts = [d0 * r_in, d0 * r_out, d1 * r_out, d0 * r_in, d1 * r_out, d1 * r_in]
		for v in verts:
			var uv := Vector2(v.x / span + 0.5, v.z / span + 0.5)
			st.set_uv(uv)
			st.add_vertex(v)
	return st.commit()


static func tex_for_kind(kind: String) -> String:
	match kind:
		"ring":
			return TEX_RING
		"cone":
			return TEX_CONE
		"line":
			return TEX_LINE
		"zone":
			return TEX_ZONE
		"burst":
			return TEX_BURST
		"rim":
			return TEX_RIM
		_:
			return TEX_CIRCLE


## Billboard / ground disc MeshInstance sized for unit radius 1, parent scales.
static func make_disc(tex_path: String, col: Color, segs: int = 40) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = flat_mesh(0.0, 1.0, 0.0, TAU, segs)
	mi.material_override = make_mat(col, tex_path)
	return mi


static func make_ring_mesh(r_in_frac: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = flat_mesh(clampf(r_in_frac, 0.0, 0.95), 1.0, 0.0, TAU, 48)
	mi.material_override = make_mat(col, TEX_RING)
	return mi


## Stage-change flash + expanding ring at `at`. Frees itself.
static func spawn_stage_flash(parent: Node3D, at: Vector3, col: Color = Color(1.0, 0.85, 0.4, 0.8), max_r: float = 6.0, dur: float = 0.55) -> Node3D:
	if parent == null:
		return null
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(at.x, at.y + 0.06, at.z)
	var ring := make_disc(TEX_STAGE, col, 48)
	root.add_child(ring)
	var glow := make_disc(TEX_CIRCLE, Color(col.r, col.g, col.b, col.a * 0.55), 32)
	glow.scale = Vector3(0.4, 1, 0.4)
	root.add_child(glow)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(max_r, 1, max_r), dur).from(Vector3(0.3, 1, 0.3))
	tw.tween_property(ring, "modulate", Color(1, 1, 1, 0), dur)
	tw.tween_property(glow, "scale", Vector3(max_r * 0.6, 1, max_r * 0.6), dur * 0.7)
	tw.tween_property(glow, "modulate", Color(1, 1, 1, 0), dur)
	tw.chain().tween_callback(root.queue_free)
	return root


## Persistent Frenzy aura parented to `boss` (chest-ish height). Caller frees / hides when Frenzy ends.
static func spawn_frenzy_aura(boss: Node3D, col: Color = Color(1.0, 0.35, 0.1, 0.7)) -> Node3D:
	if boss == null:
		return null
	var root := Node3D.new()
	root.name = "FrenzyAura"
	boss.add_child(root)
	root.position = Vector3(0, 1.4, 0)
	var body := Sprite3D.new()
	body.texture = _tex(TEX_FRENZY)
	body.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.modulate = col
	body.pixel_size = 0.012
	body.transparent = true
	body.shaded = false
	body.double_sided = true
	root.add_child(body)
	var eye := Sprite3D.new()
	eye.texture = _tex(TEX_FRENZY)
	eye.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	eye.modulate = Color(1.0, 0.55, 0.15, 0.9)
	eye.pixel_size = 0.005
	eye.position = Vector3(0, 0.55, 0.15)
	eye.transparent = true
	eye.shaded = false
	root.add_child(eye)
	# gentle pulse
	var tw := root.create_tween().set_loops()
	tw.tween_property(body, "modulate:a", col.a * 0.45, 0.45)
	tw.tween_property(body, "modulate:a", col.a, 0.45)
	return root


## Lantern blink landing mark (purple). Frees after `dur`.
static func spawn_blink_mark(parent: Node3D, at: Vector3, col: Color = Color(0.8, 0.4, 1.0, 0.7), dur: float = 0.7) -> Node3D:
	if parent == null:
		return null
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(at.x, at.y + 0.05, at.z)
	var mark := make_disc(TEX_BLINK, col, 24)
	mark.scale = Vector3(1.2, 1, 1.2)
	root.add_child(mark)
	var tw := root.create_tween()
	tw.tween_property(mark, "scale", Vector3(1.6, 1, 1.6), dur)
	tw.parallel().tween_property(mark, "modulate", Color(1, 1, 1, 0), dur)
	tw.tween_callback(root.queue_free)
	return root


## Burst ring at zone expiry / bomb blast. `radius` world metres.
static func spawn_burst(parent: Node3D, at: Vector3, radius: float, col: Color, dur: float = 0.35) -> Node3D:
	if parent == null:
		return null
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(at.x, at.y + 0.07, at.z)
	var ring := make_disc(TEX_BURST, col, 40)
	ring.scale = Vector3(radius * 0.55, 1, radius * 0.55)
	root.add_child(ring)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(radius * 1.35, 1, radius * 1.35), dur)
	tw.tween_property(ring, "modulate", Color(1, 1, 1, 0), dur)
	tw.chain().tween_callback(root.queue_free)
	return root
