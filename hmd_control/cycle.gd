extends RigidBody3D

@onready var player_origin: XROrigin3D = $PlayerOrigin
@onready var rays := get_tree().get_nodes_in_group("RayCasts")


@export var spring_strength := 100.0
@export var spring_damping := 2.0
@export var rest_dist := 0.5


var hmd_tilt: float


func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("quit"):
		get_tree().quit()
		
	for ray in rays:
		_do_single_wheel_suspension(ray)
	
	var hmd_z = XRServer.get_hmd_transform().basis.orthonormalized().get_euler().z
	hmd_tilt = clamp(hmd_z, -0.25, 0.25)
	
	rotation.z = hmd_tilt
	#test_label.text = str(hmd_tilt)
	
	#apply_central_force(basis.z * delta * -5000)
	apply_torque(Vector3(0.0, hmd_tilt * 100, 0.0))


func get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)


func _do_single_wheel_suspension(suspension_ray: RayCast3D) -> void:
	if suspension_ray.is_colliding():
		var contact := suspension_ray.get_collision_point()
		var spring_up_dir := suspension_ray.global_transform.basis.y
		var spring_len := suspension_ray.global_position.direction_to(contact).y
		var offset := rest_dist - spring_len

		var spring_force := spring_strength * offset

		# damping forcce = damping * relative velocity
		var world_vel := get_point_velocity(contact)
		var relative_vel := spring_up_dir.dot(world_vel)
		var spring_damp_force := spring_damping * relative_vel

		var force_vector := (spring_force - spring_damp_force) * spring_up_dir
		
		var force_pos_offset := contact - global_position
		apply_force(force_vector, force_pos_offset)
