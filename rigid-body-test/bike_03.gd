extends RigidBody3D

# Bicycle/Motorcycle handling using RigidBody3D and raycast wheels
# Adapted for narrow track to simulate two-wheeled vehicle with leaning
# Use head tilt (roll) from VR HMD for steering input
# Assume forward is -Z axis, Y up
# Setup: Attach this script to a RigidBody3D node
# Add a CollisionShape3D (e.g., BoxShape3D fitting the motorcycle body, excluding wheels; offset upwards to avoid ground contact)
# Add a MeshInstance3D for the visual model
# In VR setup, ensure XR origin is positioned appropriately (e.g., camera follows or attached to bike)
# Input for throttle/brake assumed from actions "throttle" and "brake" (add in Project Settings > Input Map)
# Position the RigidBody3D above ground so rays hit with some compression (e.g., at y = 0.5 + 0.35 - 0.1 for slight compression)

@export var suspension_rest_dist: float = 0.5  # Suspension length at rest
@export var spring_strength: float = 4000.0    # Spring force constant
@export var spring_damper: float = 200.0       # Damping for suspension
@export var wheel_radius: float = 0.35         # Radius of wheels
@export var wheel_inertia: float = 10.0        # Wheel rotational inertia
@export var wheel_width: float = 0.1           # Half-width for left/right offset (small for bike simulation)
@export var front_wheel_z: float = 1.0         # Z position of front wheels
@export var rear_wheel_z: float = -1.0         # Z position of rear wheels
@export var max_steer_angle: float = 30.0      # Max steering angle in degrees
@export var steer_sensitivity: float = 2.0     # Sensitivity of head tilt to steering
@export var max_engine_torque: float = 500.0   # Max engine torque (adjusted for wheel rotation)
@export var max_brake_torque: float = 1200.0   # Max brake torque
@export var side_friction: float = 2000.0      # Lateral friction stiffness
@export var forward_friction: float = 2000.0   # Longitudinal friction stiffness
@export var righting_torque_strength: float = 500.0  # Torque to keep upright at low speeds
@export var righting_speed_threshold: float = 10.0   # Speed above which righting torque fades

var wheels: Array = []
var steer: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0

func _ready() -> void:
	# Set center of mass low for leaning stability
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.4, 0)
	
	# Define wheels (narrow track for motorcycle approximation)
	wheels = [
		{"pos": Vector3(wheel_width, 0, front_wheel_z), "steered": true, "powered": false, "omega": 0.0},  # Front right
		{"pos": Vector3(-wheel_width, 0, front_wheel_z), "steered": true, "powered": false, "omega": 0.0}, # Front left
		{"pos": Vector3(wheel_width, 0, rear_wheel_z), "steered": false, "powered": true, "omega": 0.0},   # Rear right
		{"pos": Vector3(-wheel_width, 0, rear_wheel_z), "steered": false, "powered": true, "omega": 0.0}   # Rear left
	]

func _process(_delta: float) -> void:
	# Get non-physics inputs (throttle/brake)
	throttle = Input.get_action_strength("throttle")
	brake = Input.get_action_strength("brake")

func _physics_process(delta: float) -> void:
	# Get HMD transform for head tilt (roll for steering, controls lean indirectly via physics)
	#var hmd_transform = XRServer.get_hmd_transform()
	#var hmd_euler = hmd_transform.basis.get_euler()
	#var head_roll = hmd_euler.x  # Roll angle (tilt left/right)
	#
	## Map head roll to steering input (negative to match typical left tilt = left turn)
	#steer = -head_roll * steer_sensitivity
	#steer = clamp(steer, -deg_to_rad(max_steer_angle), deg_to_rad(max_steer_angle))
	
	if Input.is_action_pressed("left"):
		steer = deg_to_rad(-30.0)
	elif Input.is_action_pressed("right"):
		steer = deg_to_rad(30.0)
	else:
		steer = 0.0
		
	# Calculate forward direction and speed
	var body_basis = global_transform.basis
	var forward = -body_basis.z
	var speed = linear_velocity.dot(forward)
	
	# Apply righting torque at low speeds to prevent tipping (fades at higher speeds)
	var current_roll = asin(body_basis.x.dot(Vector3.UP))  # Approximate roll angle
	var righting_factor = clamp(1.0 - abs(speed) / righting_speed_threshold, 0.0, 1.0)
	var righting_torque = -current_roll * righting_torque_strength * righting_factor * forward  # Torque around forward axis
	apply_torque(righting_torque)
	
	# Get direct space state for raycasts
	var space_state = get_world_3d().direct_space_state
	
	# Compute global center of mass once
	var global_com = global_transform.origin + body_basis * center_of_mass
	
	for wheel in wheels:
		# Raycast from suspension attachment point downward
		var attach_pos_local = Vector3(wheel.pos.x, 0, wheel.pos.z)  # Y=0 assuming CoM adjustment
		var attach_global = global_transform * attach_pos_local
		var ray_start = global_transform * (attach_pos_local + Vector3(0, suspension_rest_dist, 0))
		var ray_end = ray_start - Vector3.UP * (suspension_rest_dist + wheel_radius)
		
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.exclude = [get_rid()]
		var hit = space_state.intersect_ray(query)
		
		if hit.is_empty():
			continue
		
		# Calculate suspension compression
		var hit_dist = (ray_start - hit.position).length()
		var compression = (suspension_rest_dist + wheel_radius) - hit_dist
		if compression <= 0:
			continue
		
		var contact_global = hit.position
		var contact_normal = hit.normal
		
		# Velocity at contact point
		var r = contact_global - global_com
		var vel_at_contact = linear_velocity + angular_velocity.cross(r)
		var rel_vel = vel_at_contact - (hit.collider_velocity if "collider_velocity" in hit else Vector3.ZERO)
		
		# Suspension force (spring + damper)
		var spring_force = compression * spring_strength
		var damper_force = rel_vel.dot(contact_normal) * spring_damper
		var suspension_force = (spring_force - damper_force) * contact_normal
		apply_force(suspension_force, attach_global)
		
		# Wheel local directions (with steering for front wheels)
		var wheel_steer = steer if wheel.steered else 0.0
		var wheel_basis = body_basis.rotated(body_basis.y, wheel_steer)
		var wheel_forward = -wheel_basis.z
		var wheel_lateral = wheel_basis.x
		
		# Project relative velocity onto ground plane
		var proj_vel = rel_vel - rel_vel.dot(contact_normal) * contact_normal
		
		# Lateral and longitudinal velocities
		var lat_vel = proj_vel.dot(wheel_lateral)
		var long_vel = proj_vel.dot(wheel_forward)
		
		# Apply engine and brake torques to wheel
		var engine_torque: float = 0.0
		if wheel.powered:
			engine_torque = max_engine_torque * throttle
		var brake_torque: float = 0.0
		if brake > 0:
			brake_torque = -sign(wheel.omega) * max_brake_torque * brake
		var total_torque = engine_torque + brake_torque
		wheel.omega += total_torque / wheel_inertia * delta
		
		# Calculate longitudinal slip
		var slip = long_vel - wheel.omega * wheel_radius
		
		# Friction forces (scaled by normal force approximation)
		var normal_mag = spring_force  # Approximate normal force
		var lat_friction = clamp(-lat_vel * side_friction, -normal_mag, normal_mag)
		var long_friction = clamp(-slip * forward_friction, -normal_mag, normal_mag)
		
		var friction_force = lat_friction * wheel_lateral + long_friction * wheel_forward
		apply_force(friction_force, contact_global)
		print(friction_force)
		
		# Apply friction reaction torque to wheel
		var friction_torque = -long_friction * wheel_radius
		wheel.omega += friction_torque / wheel_inertia * delta
