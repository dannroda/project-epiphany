extends SceneTree
## Bakea el detalle de las caras de arriba de epiphany_outdoor a assets/epiphany/outdoor_detail_a.png y _b.png, que usa la
## variante Mobile del shader. Volver a correrlo si cambia el detalle de epiphany_outdoor.gdshader. Necesita GPU:
## godot --path . --display-driver x11 --screen 1 --script res://tools/bake_outdoor_detail.gd

const OUT := "res://assets/epiphany/outdoor_detail_%s.png"


func _initialize() -> void:
	var bake: SubViewport = load("res://tools/bake_outdoor_detail.tscn").instantiate()
	root.add_child(bake)
	var material: ShaderMaterial = bake.get_node(^"Detail").material
	for layer in 2:
		material.set_shader_parameter(&"layer", layer)
		for i in 4:
			await process_frame
		var path := OUT % ["a", "b"][layer]
		var err := bake.get_texture().get_image().save_png(path)
		print("bake_outdoor_detail: ", path, " ", error_string(err))
	quit()
