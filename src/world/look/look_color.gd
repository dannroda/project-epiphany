@tool
extends RefCounted
## El color de la escena como imagen rgba16f para los compute de los efectos LA. En Forward+ es la capa de color misma.
## En Mobile esa capa no tiene STORAGE ni copia (RGB10A2 con el HDR dividido por LUMINANCE), así que begin() la pasa a
## una textura compartida con un compute y end() la devuelve con un triángulo a pantalla completa. Un efecto la deja
## en la textura para el siguiente solo si en el cuadro anterior, en el mismo lugar, le siguió otro sobre la misma capa.

const LUMINANCE := 2.0

const IN_SRC := """
#version 450
layout(local_size_x = 8, local_size_y = 8) in;
layout(set = 0, binding = 0) uniform sampler2D src;
layout(rgba16f, set = 0, binding = 1) uniform writeonly image2D dst;
layout(push_constant, std430) uniform P {
	vec2 size;
	float luminance;
	float pad;
} p;
void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= int(p.size.x) || px.y >= int(p.size.y)) return;
	vec4 c = texelFetch(src, px, 0);
	imageStore(dst, px, vec4(c.rgb * p.luminance, c.a));
}
"""

const OUT_VERTEX := """
#version 450
void main() {
	vec2 v = vec2(float((gl_VertexIndex << 1) & 2), float(gl_VertexIndex & 2));
	gl_Position = vec4(v * 2.0 - 1.0, 0.0, 1.0);
}
"""

const OUT_FRAGMENT := """
#version 450
layout(set = 0, binding = 0) uniform sampler2D src;
layout(push_constant, std430) uniform P {
	vec4 luminance;
} p;
layout(location = 0) out vec4 frag_color;
void main() {
	vec4 c = texelFetch(src, ivec2(gl_FragCoord.xy), 0);
	frag_color = vec4(c.rgb / p.luminance.x, c.a);
}
"""

static var _users := 0
static var _in_shader: RID
static var _in_pipeline: RID
static var _out_shader: RID
static var _out_pipelines := {}
static var _sampler: RID
static var _textures := {}
static var _held: RID
static var _held_texture: RID
static var _frame := -1
static var _order := []
static var _last_order := []

var rd: RenderingDevice


func _init(device: RenderingDevice) -> void:
	rd = device
	_users += 1


func free_rids() -> void:
	_users -= 1
	if _users > 0:
		return
	for r in _textures.values() + [_in_shader, _out_shader, _sampler]:
		if r.is_valid():
			rd.free_rid(r)
	_textures.clear()
	_out_pipelines.clear()
	_in_pipeline = RID()
	_held = RID()


func begin(buffers: RenderSceneBuffersRD, view: int) -> RID:
	var frame := Engine.get_frames_drawn()
	if frame != _frame:
		_frame = frame
		_last_order = _order
		_order = []
		_held = RID()
	var color := buffers.get_color_layer(view)
	_order.append([self, color])
	if rd.texture_get_format(color).usage_bits & RenderingDevice.TEXTURE_USAGE_STORAGE_BIT:
		return color
	if color == _held:
		return _held_texture
	if _held.is_valid():
		_flush()
	if not _in_pipeline.is_valid() and not _compile():
		return RID()
	var size := buffers.get_internal_size()
	if not _textures.has(size):
		var f := RDTextureFormat.new()
		f.width = size.x
		f.height = size.y
		f.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
		f.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		_textures[size] = rd.texture_create(f, RDTextureView.new())
	var texture: RID = _textures[size]
	var dst := RDUniform.new()
	dst.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	dst.binding = 1
	dst.add_id(texture)
	var push := PackedFloat32Array([size.x, size.y, LUMINANCE, 0.0]).to_byte_array()
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list, _in_pipeline)
	rd.compute_list_bind_uniform_set(list, UniformSetCacheRD.get_cache(_in_shader, 0, [_sampler_uniform(color), dst]), 0)
	rd.compute_list_set_push_constant(list, push, push.size())
	rd.compute_list_dispatch(list, (size.x + 7) / 8, (size.y + 7) / 8, 1)
	rd.compute_list_end()
	_held = color
	_held_texture = texture
	return texture


func end() -> void:
	if not _held.is_valid():
		return
	var at := _order.size() - 1
	if at + 1 < _last_order.size() and _last_order[at] == _order[at] and _last_order[at + 1][1] == _held:
		return
	_flush()


func _flush() -> void:
	var framebuffer := FramebufferCacheRD.get_cache_multipass([_held], [], 1)
	var format := rd.framebuffer_get_format(framebuffer)
	if not _out_pipelines.has(format):
		var blend := RDPipelineColorBlendState.new()
		blend.attachments = [RDPipelineColorBlendStateAttachment.new()]
		_out_pipelines[format] = rd.render_pipeline_create(_out_shader, format, RenderingDevice.INVALID_FORMAT_ID,
				RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
				RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(), blend)
	var push := PackedFloat32Array([LUMINANCE, 0.0, 0.0, 0.0]).to_byte_array()
	var list := rd.draw_list_begin(framebuffer)
	rd.draw_list_bind_render_pipeline(list, _out_pipelines[format])
	rd.draw_list_bind_uniform_set(list, UniformSetCacheRD.get_cache(_out_shader, 0, [_sampler_uniform(_held_texture)]), 0)
	rd.draw_list_set_push_constant(list, push, push.size())
	rd.draw_list_draw(list, false, 1, 3)
	rd.draw_list_end()
	_held = RID()


func _sampler_uniform(texture: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = 0
	u.add_id(_sampler)
	u.add_id(texture)
	return u


func _compile() -> bool:
	var source := RDShaderSource.new()
	source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	source.source_compute = IN_SRC
	var spirv := rd.shader_compile_spirv_from_source(source)
	if spirv.compile_error_compute != "":
		push_error(spirv.compile_error_compute)
		return false
	_in_shader = rd.shader_create_from_spirv(spirv)
	_in_pipeline = rd.compute_pipeline_create(_in_shader)
	source = RDShaderSource.new()
	source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	source.source_vertex = OUT_VERTEX
	source.source_fragment = OUT_FRAGMENT
	spirv = rd.shader_compile_spirv_from_source(source)
	if spirv.compile_error_vertex != "" or spirv.compile_error_fragment != "":
		push_error(spirv.compile_error_vertex + spirv.compile_error_fragment)
		return false
	_out_shader = rd.shader_create_from_spirv(spirv)
	_sampler = rd.sampler_create(RDSamplerState.new())
	return true
