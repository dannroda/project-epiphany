@tool
extends CompositorEffect
## Sombras de nubes sobre toda la escena HDR (personajes, agua y props incluidos), antes del TonoLA. Cada píxel vuelve a
## su posición en el mundo, sube por el sol hasta las nubes y se oscurece con su sombra, pero solo si está iluminado:
## lo que ya está en sombra (árboles, AO, pies) no se oscurece de nuevo.

@export_range(0.0, 1.0) var strength := 0.4
## Color de la sombra (se mezcla según la fuerza): frío, como la luz cálida del juego.
@export var tint := Color(0.82, 0.88, 1.0)
## Tamaño de una nube en metros y su deriva en m/s (x, z).
@export var size := 9.0
@export var drift := Vector2(0.5, 0.2)
## Borde de la nube: entre estos valores del ruido pasa de sol a sombra.
@export var edge := Vector2(0.4, 0.62)
## Luminancia (HDR) desde la que algo cuenta como al sol, y hasta la que la sombra pesa entera.
@export var lit := Vector2(0.04, 0.2)
## Cuánto se corre la sombra por metro de altura (la dirección del sol en XZ).
@export var slant := Vector2(0.3, 0.45)
@export var debug_view := false
## Para capturas: un tiempo fijo en lugar del reloj (negativo = el reloj).
var time_override := -1.0

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var sampler: RID

const SRC := """
#version 450
layout(local_size_x = 8, local_size_y = 8) in;
layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D depth_tex;
layout(push_constant, std430) uniform P {
	mat4 to_world;
	vec4 tint_strength;
	vec4 size_time_drift;
	vec4 edge_lit;
	vec4 slant_debug;
} p;
float hash(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(color_image);
	if (px.x >= size.x || px.y >= size.y) return;
	vec2 uv = (vec2(px) + 0.5) / vec2(size);
	float depth = textureLod(depth_tex, uv, 0.0).r;
	vec4 c = imageLoad(color_image, px);
	if (depth <= 0.0) return;
	vec4 v = p.to_world * vec4(uv * 2.0 - 1.0, depth, 1.0);
	vec3 world = v.xyz / v.w;
	vec2 q = (world.xz + world.y * p.slant_debug.xy - p.size_time_drift.zw * p.size_time_drift.y) / p.size_time_drift.x;
	float n = noise(q) * 0.65 + noise(q * 2.3 + 17.0) * 0.35;
	float cloud = smoothstep(p.edge_lit.x, p.edge_lit.y, n);
	float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	float k = cloud * smoothstep(p.edge_lit.z, p.edge_lit.w, luma);
	vec3 rgb = c.rgb * mix(vec3(1.0), p.tint_strength.rgb, k);
	if (p.slant_debug.z > 0.5) rgb = vec3(1.0 - k) * 0.5;
	imageStore(color_image, px, vec4(rgb, c.a));
}
"""


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_init_shader)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rd:
		for r in [shader, sampler]:
			if r.is_valid():
				rd.free_rid(r)


func _init_shader() -> void:
	if not rd:
		return
	var source := RDShaderSource.new()
	source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	source.source_compute = SRC
	var spirv := rd.shader_compile_spirv_from_source(source)
	if spirv.compile_error_compute != "":
		push_error(spirv.compile_error_compute)
		return
	shader = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader)
	sampler = rd.sampler_create(RDSamplerState.new())


func _render_callback(_type: int, render_data: RenderData) -> void:
	if not rd or not pipeline.is_valid() or strength <= 0.0:
		return
	var buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	var scene: RenderSceneData = render_data.get_render_scene_data()
	if not buffers or not scene:
		return
	var screen := buffers.get_internal_size()
	if screen.x == 0 or screen.y == 0:
		return
	var time := Time.get_ticks_msec() / 1000.0 if time_override < 0.0 else time_override
	var cam := scene.get_cam_transform()
	for view in buffers.get_view_count():
		var to_world := Projection(cam) * scene.get_view_projection(view).inverse()
		var push := PackedFloat32Array()
		for c in 4:
			for r in 4:
				push.append(to_world[c][r])
		var shadow := Vector3(tint.r, tint.g, tint.b) * (1.0 - strength) / maxf(tint.get_luminance(), 0.01)
		push.append_array([shadow.x, shadow.y, shadow.z, strength, size, time, drift.x, drift.y, edge.x, edge.y, lit.x, lit.y,
				slant.x, slant.y, 1.0 if debug_view else 0.0, 0.0])
		var color := RDUniform.new()
		color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		color.binding = 0
		color.add_id(buffers.get_color_layer(view))
		var depth := RDUniform.new()
		depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		depth.binding = 1
		depth.add_id(sampler)
		depth.add_id(buffers.get_depth_layer(view))
		var set := UniformSetCacheRD.get_cache(shader, 0, [color, depth])
		var list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(list, pipeline)
		rd.compute_list_bind_uniform_set(list, set, 0)
		var bytes := push.to_byte_array()
		rd.compute_list_set_push_constant(list, bytes, bytes.size())
		rd.compute_list_dispatch(list, (screen.x + 7) / 8, (screen.y + 7) / 8, 1)
		rd.compute_list_end()
