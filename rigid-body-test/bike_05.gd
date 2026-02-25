extends RigidBody3D

 
@onready var ray_front: RayCast3D = $RayFront
@onready var ray_left: RayCast3D = $RayLeft
@onready var ray_right: RayCast3D = $RayRight
@onready var ray_rear: RayCast3D = $RayRear


@export var acceleration: float = 500.0
@export var accel_curve: Curve
@export var max_speed: float = 100.0
@export var deceleration: float = 100.0

@export var tire_turn_speed: float = 5.0
@export var tire_max_turn_degree: float = 5.0

@export var max_lean_degree: float = 10.0
var max_lean: float = 0.0
@export var balance_dist: float = 1.0
@export var balance_strength: float = 2000.0
@export var balance_damping: float = 500.0
#@export var righting_torque_strength: float = 500.0  # Torque to keep upright at low speeds
#@export var righting_speed_threshold: float = 10.0
@export var rest_dist: float = 1.5
@export var spring_strength: float = 2000.0
@export var spring_damping: float = 90.0

func _ready() -> void:
	max_lean = deg_to_rad(max_lean_degree)

func _process(delta: float) -> void:
	if Input.is_action_pressed("quit"):
		get_tree().quit()
	
	if Input.is_action_pressed("reload"):
		get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	# process plyer movement from HMD.
	# left/right lean for turning
	# forward back lean for accelerate / decelerate
	# heart rate for available power
	# wsad keyboard input for testing.
	#basic_steering_rotation(delta)
	
	
	if Input.get_action_strength("lean_forward"):
		# accelerate
		do_single_wheel_acceleration(ray_rear)
	elif Input.get_action_strength("lean_back"):
		do_single_wheel_braking(ray_front)
		
	var turn_input := Input.get_axis("lean_right", "lean_left")
	
	rider_leaning(turn_input, delta)
	basic_steering_rotation(turn_input, delta)
	do_single_wheel_traction(ray_front)
	do_single_wheel_traction(ray_rear)
	process_suspension_ray(ray_front, 0.0)
	process_suspension_ray(ray_rear, 0.0)
	
	#process
	print(turn_input)
	ray_left.position.y = turn_input * 0.5
	ray_right.position.y = -turn_input * 0.5
	process_balance_ray(ray_left, 0.0)
	process_balance_ray(ray_right, 0.0)


func rider_leaning(turn_strength: float, delta: float) -> void:
	if turn_strength:
		center_of_mass = Vector3(turn_strength * -0.1, 0.0, 0.0)
	else:
		center_of_mass = Vector3.ZERO


func basic_steering_rotation(turn_strength: float, delta: float) -> void:
	if turn_strength:
		ray_front.rotation.y = clamp(ray_front.rotation.y + turn_strength * delta,
		 deg_to_rad(-tire_max_turn_degree), deg_to_rad(tire_max_turn_degree))
	else:
		ray_front.rotation.y = move_toward(ray_front.rotation.y, 0, tire_turn_speed * delta)


func do_single_wheel_acceleration(ray: RayCast3D) -> void:
	if ray.is_colliding():
		
		var forward_dir := -ray.global_basis.z
		var vel := forward_dir.dot(linear_velocity)
		
		if vel > max_speed:
			return
		var contact := ray.global_position
		var force_vector := forward_dir * acceleration
		var force_pos := contact - global_position
		
		apply_force(force_vector, force_pos)

func do_single_wheel_braking(ray: RayCast3D) -> void:
	var forward_dir := -ray.global_basis.z
	var vel := forward_dir.dot(linear_velocity)
	var contact := ray.global_position
	
	var force_pos := contact - global_position
	var drag_force_vector = global_basis.z * deceleration * signf(vel)
	apply_force(drag_force_vector, force_pos)
	


func do_single_wheel_traction(ray: RayCast3D) -> void:
	if not ray.is_colliding(): return
	
	var  steer_side_dir := ray.global_basis.x
	var tire_vel := get_point_velocity(ray.global_position)
	var steering_x_vel := steer_side_dir.dot(tire_vel)
	var x_traction := 1.0
	var gravty: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var x_force := -steer_side_dir * steering_x_vel * x_traction * ((mass * gravty) / 4.0)
	
	var force_pos := ray.global_position - global_position
	apply_force(x_force, force_pos)

func get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)

func process_suspension_ray(suspension_ray: RayCast3D, over_extend: float) -> bool:
	var grounded := false
	if suspension_ray.is_colliding():
		grounded = true
		suspension_ray.target_position.y = -(rest_dist + over_extend)
		var contact: Vector3 = suspension_ray.get_collision_point()
		var spring_up_dir: Vector3 = Vector3.UP
		
		# this can be used to position a mesh
		#var ray_pos: Vector3 = suspension_ray.global_transform.origin
		
		var spring_len := suspension_ray.global_position.distance_to(contact)
		var offset := rest_dist - spring_len
		
		var spring_force := spring_strength * offset
		
		# damping force = damping * relative velocity
		var world_vel := get_point_velocity(contact)
		var relative_vel := spring_up_dir.dot(world_vel)
		var spring_damp_force := spring_damping * relative_vel
		
		var force_vector := (spring_force - spring_damp_force) * spring_up_dir
		
		contact = suspension_ray.global_position
		var force_pos_offset := contact - global_position
		apply_force(force_vector, force_pos_offset)
	else:
		grounded = false
	
	return grounded


func process_balance_ray(balance_ray: RayCast3D, over_extend: float) -> bool:
	var grounded := false
	if balance_ray.is_colliding():
		grounded = true
		balance_ray.target_position.y = -(rest_dist + over_extend)
		var contact: Vector3 = balance_ray.get_collision_point()
		var balance_up_dir: Vector3 = Vector3.UP
		
		# this can be used to position a mesh
		#var ray_pos: Vector3 = suspension_ray.global_transform.origin
		
		var balance_len := balance_ray.global_position.distance_to(contact)
		var offset := balance_dist - balance_len
		
		var balance_force := balance_strength * offset
		
		# damping force = damping * relative velocity
		var world_vel := get_point_velocity(contact)
		var relative_vel := balance_up_dir.dot(world_vel)
		var balance_damp_force := balance_damping * relative_vel
		
		var force_vector := (balance_force - balance_damp_force) * balance_up_dir
		
		contact = balance_ray.global_position
		var force_pos_offset := contact - global_position
		apply_force(force_vector, force_pos_offset)
	else:
		grounded = false
	
	return grounded
