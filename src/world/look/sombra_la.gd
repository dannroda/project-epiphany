@tool
extends CompositorEffect
## AO de pantalla de Link's Awakening (RenderDoc): multiplica toda la escena HDR, no solo el ambiente.

@export var strength := 1.0
## Radio máximo de muestreo, en texeles del AO del juego (480 × 270).
@export var max_radius := 30.0
## Hasta qué distancia (m) un punto ocluye: más chico, menos halo de lo alto sobre el piso de abajo.
@export var reach := 5.0
@export var debug_view := false   # output the AO instead of the scene

var rd: RenderingDevice
var sh_ao: RID
var sh_blur: RID
var sh_mul: RID
var sh_box: RID
var p_box: RID
var p_ao: RID
var p_blur: RID
var p_mul: RID
var sampler_nearest: RID
var sampler_linear: RID
var tex := {}          # name -> RID
var tex_size := Vector2i.ZERO

const AO_SRC := """
#version 450
layout(local_size_x = 8, local_size_y = 8) in;
layout(set = 0, binding = 0) uniform sampler2D depth_tex;
layout(r16f, set = 0, binding = 1) uniform writeonly image2D ao_out;
layout(push_constant, std430) uniform P {
	mat4 inv_proj;
	vec2 size;        // AO buffer size
	float cot_half;   // cot(fov / 2)
	float reach;
	vec2 game_texel;  // 1 / (480, 270): the game's AO buffer, which its radius is measured in
	float max_radius;
	float pad2;
} p;
const vec2 KERNEL[4] = vec2[](vec2(0.0810819, 0.0192399), vec2(-0.207505, -0.139434),
		vec2(0.149406, -0.563876), vec2(0.0471044, 0.748519));
vec3 vpos(vec2 uv) {
	vec4 v = p.inv_proj * vec4(uv * 2.0 - 1.0, textureLod(depth_tex, uv, 0.0).r, 1.0);
	return v.xyz / v.w;
}
void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= int(p.size.x) || px.y >= int(p.size.y)) return;
	vec2 t = 1.0 / p.size;
	vec2 uv = (vec2(px) + 0.5) * t;
	vec3 l = vpos(uv - vec2(t.x, 0.0)), r = vpos(uv + vec2(t.x, 0.0));
	vec3 u = vpos(uv - vec2(0.0, t.y)), d = vpos(uv + vec2(0.0, t.y));
	vec3 c = (l + r) * 0.5;
	vec3 n = normalize(cross(r - l, d - u));
	if (dot(n, -c) < 0.0) n = -n;
	float rad = clamp(p.cot_half * 200.0 / max(-c.z, 1e-3), 1.0, p.max_radius);
	// 16 rotations, 4x4 interleaved (the game picks them from a table by pixel position).
	int idx = (px.x & 3) * 4 + ((px.y & 3) ^ ((px.x >> 2) & 3));
	float a = float((idx * 7) & 15) * 0.3926991;
	float cs = cos(a), sn = sin(a);
	vec2 g = p.game_texel;
	vec2 o = vec2(rad * (g.x * cs - g.y * sn), rad * (g.x * sn + g.y * cs));
	float sum = 0.0;
	for (int i = 0; i < 4; i++) {
		vec3 v = vpos(uv + KERNEL[i] * o) - c;
		float dist = length(v);
		if (dist < p.reach && dist > 1e-4) sum += clamp(dot(n, v / dist) - 0.25, 0.0, 1.0);
	}
	imageStore(ao_out, px, vec4(1.0 - 0.5 * clamp(sum * 0.25 * 5.0, 0.0, 1.0)));
}
"""

const BLUR_SRC := """
#version 450
layout(local_size_x = 8, local_size_y = 8) in;
layout(set = 0, binding = 0) uniform sampler2D src;
layout(r16f, set = 0, binding = 1) uniform writeonly image2D dst;
layout(push_constant, std430) uniform P {
	vec2 size;     // dst size
	vec2 step1;    // uv offset of the inner taps
	vec2 step2;    // uv offset of the outer taps
	vec2 pad;
} p;
void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= int(p.size.x) || px.y >= int(p.size.y)) return;
	vec2 uv = (vec2(px) + 0.5) / p.size;
	float s = 0.227 * textureLod(src, uv, 0.0).r
			+ 0.3162 * (textureLod(src, uv - p.step1, 0.0).r + textureLod(src, uv + p.step1, 0.0).r)
			+ 0.07027 * (textureLod(src, uv - p.step2, 0.0).r + textureLod(src, uv + p.step2, 0.0).r);
	imageStore(dst, px, vec4(s));
}
"""

## Promedio 4x4 del AO crudo: cancela justo las 16 rotaciones intercaladas (si no, queda un damero en los degradés).
const BOX_SRC := """
#version 450
layout(local_size_x = 8, local_size_y = 8) in;
layout(set = 0, binding = 0) uniform sampler2D src;
layout(r16f, set = 0, binding = 1) uniform writeonly image2D dst;
layout(push_constant, std430) uniform P {
	vec2 size;
	vec2 pad;
} p;
void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= int(p.size.x) || px.y >= int(p.size.y)) return;
	ivec2 hi = ivec2(p.size) - 1;
	float s = 0.0;
	for (int j = -2; j < 2; j++)
		for (int i = -2; i < 2; i++)
			s += texelFetch(src, clamp(px + ivec2(i, j), ivec2(0), hi), 0).r;
	imageStore(dst, px, vec4(s / 16.0));
}
"""

const MUL_SRC := """
#version 450
layout(local_size_x = 8, local_size_y = 8) in;
layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D ao1;
layout(set = 0, binding = 2) uniform sampler2D ao2;
layout(push_constant, std430) uniform P {
	vec2 size;
	float strength;
	float debug_view;
} p;
void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= int(p.size.x) || px.y >= int(p.size.y)) return;
	vec2 uv = (vec2(px) + 0.5) / p.size;
	float ao = textureLod(ao1, uv, 0.0).r * textureLod(ao2, uv, 0.0).r;
	vec4 c = imageLoad(color_image, px);
	vec3 rgb = p.debug_view > 0.5 ? vec3(ao) * 0.5 : c.rgb * mix(1.0, ao, p.strength);   // 0.5: exposure 2 brings it back to ~1
	imageStore(color_image, px, vec4(rgb, c.a));
}
"""


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_init_shaders)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rd:
		for r in tex.values() + [sh_ao, sh_blur, sh_mul, sh_box, sampler_nearest, sampler_linear]:
			if r.is_valid(): rd.free_rid(r)


func _compile(src: String) -> RID:
	var s := RDShaderSource.new()
	s.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	s.source_compute = src
	var spirv := rd.shader_compile_spirv_from_source(s)
	if spirv.compile_error_compute != "":
		push_error(spirv.compile_error_compute)
		return RID()
	return rd.shader_create_from_spirv(spirv)


func _init_shaders() -> void:
	if not rd:
		return
	sh_ao = _compile(AO_SRC); sh_blur = _compile(BLUR_SRC); sh_mul = _compile(MUL_SRC); sh_box = _compile(BOX_SRC)
	if not (sh_ao.is_valid() and sh_blur.is_valid() and sh_mul.is_valid() and sh_box.is_valid()):
		return
	p_ao = rd.compute_pipeline_create(sh_ao)
	p_blur = rd.compute_pipeline_create(sh_blur)
	p_mul = rd.compute_pipeline_create(sh_mul)
	p_box = rd.compute_pipeline_create(sh_box)
	var ss := RDSamplerState.new()
	sampler_nearest = rd.sampler_create(ss)
	ss.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	ss.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_linear = rd.sampler_create(ss)


func _free_textures() -> void:
	for k in tex:
		if tex[k].is_valid(): rd.free_rid(tex[k])
	tex.clear()


func _make_tex(size: Vector2i) -> RID:
	var f := RDTextureFormat.new()
	f.width = size.x; f.height = size.y
	f.format = RenderingDevice.DATA_FORMAT_R16_SFLOAT
	f.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	return rd.texture_create(f, RDTextureView.new())


func _ensure_textures(size: Vector2i) -> void:
	if size == tex_size and not tex.is_empty():
		return
	_free_textures()
	tex_size = size
	var q := Vector2i(maxi(size.x / 4, 1), maxi(size.y / 4, 1))
	var e := Vector2i(maxi(size.x / 8, 1), maxi(size.y / 8, 1))
	tex = {"raw": _make_tex(q), "box": _make_tex(q), "qa": _make_tex(q), "q": _make_tex(q), "ea": _make_tex(e), "e": _make_tex(e)}


func _sampler_uniform(binding: int, sampler: RID, t: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(sampler); u.add_id(t)
	return u


func _image_uniform(binding: int, t: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(t)
	return u


func _dispatch(pipeline: RID, shader: RID, uniforms: Array, push: PackedByteArray, size: Vector2i) -> void:
	var set := UniformSetCacheRD.get_cache(shader, 0, uniforms)
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list, pipeline)
	rd.compute_list_bind_uniform_set(list, set, 0)
	rd.compute_list_set_push_constant(list, push, push.size())
	rd.compute_list_dispatch(list, (size.x + 7) / 8, (size.y + 7) / 8, 1)
	rd.compute_list_end()


func _blur(src: RID, dst: RID, dst_size: Vector2i, step1: Vector2, step2: Vector2) -> void:
	var push := PackedFloat32Array([dst_size.x, dst_size.y, step1.x, step1.y, step2.x, step2.y, 0, 0]).to_byte_array()
	_dispatch(p_blur, sh_blur, [_sampler_uniform(0, sampler_linear, src), _image_uniform(1, dst)], push, dst_size)


func _render_callback(_type: int, render_data: RenderData) -> void:
	if not rd or not p_mul.is_valid():
		return
	var buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	var scene: RenderSceneData = render_data.get_render_scene_data()
	if not buffers or not scene:
		return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return
	_ensure_textures(size)
	var q := Vector2i(maxi(size.x / 4, 1), maxi(size.y / 4, 1))
	var e := Vector2i(maxi(size.x / 8, 1), maxi(size.y / 8, 1))
	# Blur offsets in the game's 480x270 AO texels (1.477 / 3.446 across, 1.385 / 3.231 down), the same for both passes.
	var h1 := Vector2(1.477 / 480.0, 0.0); var h2 := Vector2(3.446 / 480.0, 0.0)
	var v1 := Vector2(0.0, 1.385 / 270.0); var v2 := Vector2(0.0, 3.231 / 270.0)
	for view in buffers.get_view_count():
		var proj: Projection = scene.get_view_projection(view)
		var inv := proj.inverse()
		var m := PackedFloat32Array()
		for c in 4:
			for r in 4:
				m.append(inv[c][r])
		m.append_array([q.x, q.y, absf(proj[1][1]), reach, 1.0 / 480.0, 1.0 / 270.0, max_radius, 0.0])   # cot(fov/2); Godot's RD projection may carry a Y flip
		_dispatch(p_ao, sh_ao, [_sampler_uniform(0, sampler_nearest, buffers.get_depth_layer(view)), _image_uniform(1, tex["raw"])],
				m.to_byte_array(), q)
		_dispatch(p_box, sh_box, [_sampler_uniform(0, sampler_nearest, tex["raw"]), _image_uniform(1, tex["box"])],
				PackedFloat32Array([q.x, q.y, 0.0, 0.0]).to_byte_array(), q)
		_blur(tex["box"], tex["qa"], q, h1, h2)
		_blur(tex["qa"], tex["q"], q, v1, v2)
		_blur(tex["q"], tex["ea"], e, h1, h2)
		_blur(tex["ea"], tex["e"], e, v1, v2)
		var push := PackedFloat32Array([size.x, size.y, strength, 1.0 if debug_view else 0.0]).to_byte_array()
		_dispatch(p_mul, sh_mul, [_image_uniform(0, buffers.get_color_layer(view)),
				_sampler_uniform(1, sampler_linear, tex["q"]), _sampler_uniform(2, sampler_linear, tex["e"])], push, size)
