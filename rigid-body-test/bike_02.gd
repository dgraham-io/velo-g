extends VehicleBody3D

@onready var ray_fl: RayCast3D = $RayFL
@onready var ray_rl: RayCast3D = $RayRL
@onready var ray_fr: RayCast3D = $RayFR
@onready var ray_rr: RayCast3D = $RayRR


@export var speed: float = 5000.0
@export var max_lean: float = .025
@export var turn_force: float = 10
@export var balance: float = 0.0
@export var spring_preload: float = 1.0
@export var hover_height: float = 1.0
@export var spring_stiffness: float = 50.0
@export var damping: float = 5.02



func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("throttle"):
		apply_central_force(-global_transform.basis.z * speed * delta)
		
	if Input.is_action_pressed("left"):
		balance = 2.0
		process_ray(ray_fl, -balance)
		process_ray(ray_rl, -balance)
		process_ray(ray_fr, balance)
		process_ray(ray_rr, balance)
		apply_torque(Vector3(0.0, 10.0, 0.0))
	elif Input.is_action_pressed("right"):
		balance = 1.0
		process_ray(ray_fl, balance)
		process_ray(ray_rl, balance)
		process_ray(ray_fr, -balance)
		process_ray(ray_rr, -balance)
		apply_torque(Vector3(0.0, -10.0, 0.0))
	else:
		balance = 0.0
		process_ray(ray_fl, balance)
		process_ray(ray_rl, balance)
		process_ray(ray_fr, balance)
		process_ray(ray_rr, balance)
	
	
func process_ray(ray: RayCast3D, balance: float) -> void:
	var up: Vector3 = Vector3.UP
	if ray.is_colliding():
		var hit_pos: Vector3 = ray.get_collision_point()
		var ray_pos: Vector3 = ray.global_transform.origin
		var vertical_dist: float = ray_pos.y - hit_pos.y  # Vertical height
		var compression: float = spring_preload + (hover_height - vertical_dist)
		if compression > 0:
			# Damper based on vertical velocity
			var rel_pos: Vector3 = ray_pos - global_transform.origin
			var vel_at_point: Vector3 = linear_velocity + angular_velocity.cross(rel_pos)
			var damper: float = -vel_at_point.dot(up) * damping
			var force_mag: float = compression * (spring_stiffness + balance) + damper
			var force: Vector3 = up * force_mag
			apply_force(force, rel_pos)  # Offset for natural torque/leaning
		
	
	#var local_torque_axis: Vector3 = Vector3.FORWARD  # Or RIGHT/FORWARD for other axes
	#var global_torque_axis: Vector3 = global_transform.basis * local_torque_axis
	#print("global torque axis", global_torque_axis )
	#
	#if abs(global_rotation.z) < max_lean:
		#var torque_vector: Vector3 = global_torque_axis * turn_force
		#apply_torque(-torque_vector)
		#print(rotation)
	#apply_torque(Vector3(0.0, turn_force, 0.0))
		#
	#if Input.is_action_pressed("right"):
		#var local_torque_axis: Vector3 = Vector3.FORWARD  # Or RIGHT/FORWARD for other axes
		#var global_torque_axis: Vector3 = global_transform.basis * local_torque_axis
		#print("global torque axis", global_torque_axis )
		#
		#if abs(global_rotation.z) < max_lean:
			#var torque_vector: Vector3 = global_torque_axis * turn_force
			#apply_torque(torque_vector)
			#print(rotation)
		#apply_torque(Vector3(0.0, -turn_force, 0.0))
		#
	#if Input.is_action_pressed("tilt_left"):
		#var local_torque_axis: Vector3 = Vector3.FORWARD  # Or RIGHT/FORWARD for other axes
		#var global_torque_axis: Vector3 = global_transform.basis * local_torque_axis
		#print("global torque axis", global_torque_axis )
		#
		#if abs(global_rotation.z) < max_lean:
			#var torque_vector: Vector3 = global_torque_axis * turn_force
			#apply_torque(-torque_vector)
			#print(rotation)
