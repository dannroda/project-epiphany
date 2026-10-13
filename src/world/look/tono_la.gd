@tool
extends CompositorEffect
## Tono final de Link's Awakening (RenderDoc): viñeta radial sobre el HDR, exposición 2 y curva Hejl/Burgess-Dawson.
## Requiere el tonemapper de Godot en Linear con exposición 1.

@export var exposure := 2.0
@export var vignette := 1.0

var rd: RenderingDevice
var shader: RID
var pipeline: RID

const SRC := """
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(push_constant, std430) uniform Params {
	vec2 size;
	float exposure;
	float vignette;
} p;
const float VIG[19] = float[](1.000, 1.000, 0.981, 0.954, 0.911, 0.860, 0.801, 0.740, 0.676, 0.616,
		0.563, 0.509, 0.461, 0.413, 0.371, 0.333, 0.298, 0.265, 0.238);
float vig(vec2 uv) {
	float d = length(uv * 2.0 - 1.0);
	float x = (d - 0.5) / 0.05;
	if (x <= 0.0) return 1.0;
	if (x >= 18.0) return max(VIG[18] - (x - 18.0) * 0.027, 0.0);
	int i = int(x);
	return mix(VIG[i], VIG[i + 1], x - float(i));
}
void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	if (uv.x >= int(p.size.x) || uv.y >= int(p.size.y)) return;
	vec4 c = imageLoad(color_image, uv);
	float v = mix(1.0, vig((vec2(uv) + 0.5) / p.size), p.vignette);
	vec3 x = max(c.rgb * v * p.exposure - 0.004, vec3(0.0));
	vec3 y = x * (6.2 * x + 0.5) / (x * (6.2 * x + 1.7) + 0.06);
	imageStore(color_image, uv, vec4(clamp(pow(y, vec3(2.2)), 0.0, 1.0), c.a));
}
"""


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_init_shader)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and shader.is_valid():
		rd.free_rid(shader)


func _init_shader() -> void:
	if not rd:
		return
	var src := RDShaderSource.new()
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	src.source_compute = SRC
	var spirv := rd.shader_compile_spirv_from_source(src)
	if spirv.compile_error_compute != "":
		push_error(spirv.compile_error_compute)
		return
	shader = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader)


func _render_callback(_type: int, render_data: RenderData) -> void:
	if not rd or not pipeline.is_valid():
		return
	var buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	if not buffers:
		return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return
	var push := PackedFloat32Array([size.x, size.y, exposure, vignette]).to_byte_array()
	for view in buffers.get_view_count():
		var u := RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u.binding = 0
		u.add_id(buffers.get_color_layer(view))
		var set := UniformSetCacheRD.get_cache(shader, 0, [u])
		var list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(list, pipeline)
		rd.compute_list_bind_uniform_set(list, set, 0)
		rd.compute_list_set_push_constant(list, push, push.size())
		rd.compute_list_dispatch(list, (size.x + 7) / 8, (size.y + 7) / 8, 1)
		rd.compute_list_end()
