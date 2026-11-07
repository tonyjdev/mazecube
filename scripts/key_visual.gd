class_name KeyVisual
extends RefCounted
## Modelo 3D de una llave construido con primitivas: anillo, vástago y dientes.
## La llave queda de pie en el plano XY, con el anillo arriba y centrada en el
## origen, de modo que al girarla sobre Y se ve dar vueltas sobre sí misma.


static func create(color: Color) -> Node3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.5
	mat.roughness = 0.35

	var root := Node3D.new()
	root.name = "Key"

	var ring := TorusMesh.new()
	ring.inner_radius = 0.06
	ring.outer_radius = 0.13
	ring.rings = 24
	ring.ring_segments = 8
	_add_part(root, ring, mat, Vector3(0, 0.12, 0), Vector3(PI * 0.5, 0, 0))

	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.05, 0.3, 0.05)
	_add_part(root, shaft, mat, Vector3(0, -0.12, 0))

	var tooth := BoxMesh.new()
	tooth.size = Vector3(0.08, 0.04, 0.05)
	_add_part(root, tooth, mat, Vector3(0.06, -0.24, 0))
	_add_part(root, tooth, mat, Vector3(0.05, -0.15, 0))
	return root


static func _add_part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	part.position = pos
	part.rotation = rot
	parent.add_child(part)
