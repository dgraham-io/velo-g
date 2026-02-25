extends RigidBody3D

func _physics_process(delta: float) -> void:
	apply_central_force(basis.z * delta * -1000)
