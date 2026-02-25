extends RigidBody3D


@onready var center_rays = get_tree().get_nodes_in_group("CenterRays")
@onready var body: MeshInstance3D = $body

@export var speed = 15000
var turn_speed = 5000
var reverse_speed = 10000
@export var hover_force = 5000
@export var turn_point: Vector3 = Vector3(0.0, 0.0, 1.0)
@export var turn_force: float = 5.0
@export var max_lean: float = deg_to_rad(20.0)

func _process(delta: float) -> void:
	if Input.is_action_pressed("quit"):
		get_tree().quit()
		
	if Input.is_action_pressed("thrust"):
		apply_central_force(Vector3(0,0,-100))
		
	if Input.is_action_pressed("left"):
		apply_torque(Vector3(0,-10, 0))
		
	if Input.is_action_pressed("right"):
		apply_torque(Vector3(0,10, 0))

func _physics_process(delta: float) -> void:
	#for ray in center_rays:
		#if ray.is_colliding():
			#var collision_point = ray.get_collision_point()
			#
			## calculate distance between ray position and raycast hit
			#var dist = collision_point.distance_to(ray.global_transform.origin)
			#
			#apply_force(Vector3.UP * (1/dist) * hover_force * delta, ray.global_transform.origin - global_transform.origin)
			#
	if Input.is_action_pressed("quit"):
		get_tree().quit()
		
	if Input.is_action_pressed("thrust"):
		apply_central_force(-global_transform.basis.z * speed * delta)
		
	if Input.is_action_pressed("left"):
		var local_torque_axis: Vector3 = Vector3.FORWARD  # Or RIGHT/FORWARD for other axes
		var global_torque_axis: Vector3 = global_transform.basis * local_torque_axis
		print("global torque axis", global_torque_axis )
		
		if abs(global_rotation.z) < max_lean:
			var torque_vector: Vector3 = global_torque_axis * turn_force
			apply_torque(-torque_vector)
			print(rotation)
		apply_torque(Vector3(0.0, turn_force, 0.0))
		
	if Input.is_action_pressed("right"):
		var local_torque_axis: Vector3 = Vector3.FORWARD  # Or RIGHT/FORWARD for other axes
		var global_torque_axis: Vector3 = global_transform.basis * local_torque_axis
		print("global torque axis", global_torque_axis )
		
		if abs(global_rotation.z) < max_lean:
			var torque_vector: Vector3 = global_torque_axis * turn_force
			apply_torque(torque_vector)
			print(rotation)
		apply_torque(Vector3(0.0, -turn_force, 0.0))
		
	if Input.is_action_pressed("tilt_left"):
		var local_torque_axis: Vector3 = Vector3.FORWARD  # Or RIGHT/FORWARD for other axes
		var global_torque_axis: Vector3 = global_transform.basis * local_torque_axis
		print("global torque axis", global_torque_axis )
		
		if abs(global_rotation.z) < max_lean:
			var torque_vector: Vector3 = global_torque_axis * turn_force
			apply_torque(-torque_vector)
			print(rotation)
