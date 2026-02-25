extends RigidBody3D

@onready var rays: Array[RayCast3D] = [$FrontRay, $RearRay]  # Add more if using four

@export var hover_height: float = 1.0  # Target hover height
@export var spring_stiffness: float = 50.0  # Hover force strength (tune high for less sag)
@export var damping: float = 5.0  # Bounce reduction
@export var thrust_power: float = 1000.0  # Forward acceleration
@export var max_speed: float = 30.0  # Speed limit
@export var max_lean_angle: float = deg_to_rad(45.0)  # Max roll in radians
@export var roll_stiffness: float = 20.0  # How quickly it leans (increased for better response)
@export var roll_damping: float = 2.0  # Roll oscillation control
@export var yaw_factor: float = 1.0  # Turn rate from lean (increased for stronger turns)
@export var countersteer_factor: float = 200.0  # Brief opposite yaw to initiate lean (new)
@export var low_speed_threshold: float = 5.0  # Below this, use direct steering
@export var low_speed_steer: float = 50.0  # Direct yaw strength at low speed (reduced)


var spring_preload: float = 0.0
var prev_input_x: float = 0.0  # Track for countersteer detection

func _ready() -> void:
	# Preload for exact height (balances gravity)
	var gravity_mag: float = PhysicsServer3D.body_get_direct_state(get_rid()).total_gravity.length()
	spring_preload = (mass * gravity_mag) / (spring_stiffness * rays.size())

func _physics_process(delta: float) -> void:
	handle_hover()
	handle_input(delta)

func handle_hover() -> void:
	var up: Vector3 = Vector3.UP  # World up for vertical forces (better for turning)
	for ray in rays:
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
				var force_mag: float = compression * spring_stiffness + damper
				var force: Vector3 = up * force_mag
				apply_force(force, rel_pos)  # Offset for natural torque/leaning

func handle_input(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
	var forward: Vector3 = -global_transform.basis.z  # Z-forward
	var current_speed: float = linear_velocity.dot(forward)
	var speed_factor: float = clamp(abs(current_speed) / max_speed, 0.0, 1.0)

	# Thrust
	if abs(current_speed) < max_speed:
		apply_central_force(forward * input_dir.y * thrust_power)

	# Detect input change for countersteer (brief opposite yaw to initiate lean)
	var input_change: float = input_dir.x - prev_input_x
	if abs(input_change) > 0.1 and abs(current_speed) > low_speed_threshold:
		var countersteer_yaw: float = input_change * countersteer_factor * speed_factor
		apply_torque(Vector3(0, countersteer_yaw, 0))  # Opposite direction to input
	prev_input_x = input_dir.x

	# Motorcycle turning: Lean drives yaw; input drives desired lean
	var desired_lean: float = -input_dir.x * max_lean_angle * speed_factor
	var roll_error: float = desired_lean - rotation.z
	var roll_torque: float = roll_error * roll_stiffness - angular_velocity.z * roll_damping
	apply_torque(Vector3(0, 0, roll_torque))

	# Yaw from lean (simulates motorcycle curve)
	var yaw_torque: float = -rotation.z * current_speed * yaw_factor  # Sign: left lean -> left turn
	apply_torque(Vector3(0, yaw_torque, 0))

	# Low-speed direct steering (handlebar turn without lean)
	if abs(current_speed) < low_speed_threshold:
		var low_yaw: float = -input_dir.x * low_speed_steer * (current_speed / low_speed_threshold)
		apply_torque(Vector3(0, clamp(low_yaw, -low_speed_steer, low_speed_steer), 0))  # Clamp to prevent excess
