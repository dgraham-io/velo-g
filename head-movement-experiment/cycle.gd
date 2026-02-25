extends RigidBody3D


@onready var rays: Array[RayCast3D] = [$FrontRayCast, $RearRayCast]
@onready var player_origin: XROrigin3D = $PlayerOrigin

@export var hover_height: float = 1.0  # Target height above ground
@export var spring_stiffness: float = 5000.0  # Hover force strength
@export var damping: float = 500.0  # Reduces bounce
@export var thrust_power: float = 2000.0  # Forward acceleration
@export var steer_torque: float = 1000.0  # Turning strength
@export var lean_torque: float = 500.0  # Leaning into turns (bike-like)
@export var max_speed: float = 50.0  # Limit forward velocity
@export var thrust := 10000.0
@export var torque := 50.0


var hmd_tilt: float

func _process(delta: float) -> void:
	var hmd_raw = XRServer.get_hmd_transform().basis.orthonormalized().get_euler().z
	hmd_tilt = clampf(hmd_raw, -0.25, 0.25)
	rotation.z = hmd_tilt
	player_origin.global_position = global_position + Vector3(0.0, 3.0, 6.0)

func _physics_process(delta: float) -> void:
	#apply_central_force(-basis.z * delta * 1000)
	apply_central_force(Vector3(0,0,-thrust))
	
	apply_torque(Vector3(0.0, hmd_tilt * 1000, 0.0))
	#handle_hover()
	#handle_input(delta)


func handle_hover() -> void:
	var up: Vector3 = -global_transform.basis.y.normalized()
	for ray in rays:
		if ray.is_colliding():
			var hit_pos: Vector3 = ray.get_collision_point()
			var ray_pos: Vector3 = ray.global_transform.origin
			var dist: float = (ray_pos - hit_pos).length()
			var compression: float = hover_height - dist + ray.target_position.length() / 2.0
			if compression > 0:
				# calculate velocity at ray point for damping
				var vel_at_point: Vector3 = linear_velocity + angular_velocity.cross(ray_pos - global_transform.origin)
				var damper: float = -vel_at_point.dot(up) * damping
				var force_mag: float = compression * spring_stiffness + damper
				var force: Vector3 = up * force_mag
				# apply force at relative position for torque / leaning
				apply_force(force, ray_pos - global_transform.origin)

func handle_input(delta: float) -> void:
	var forward: Vector3 = -global_transform.basis.z
	var current_speed: float = linear_velocity.dot(forward)
	
	#Thrust
	if abs(current_speed) < max_speed:
		# get this from the HRM in future
		apply_central_force(forward * 1 * thrust_power) 
	
	# steering
	apply_torque(Vector3(0, hmd_tilt * steer_torque * (current_speed / max_speed + 0.1), 0))
	
	# Leaning
	var lean_amount: float = hmd_tilt * (current_speed / max_speed) * lean_torque
	apply_torque(Vector3(0,0, lean_amount))
	
