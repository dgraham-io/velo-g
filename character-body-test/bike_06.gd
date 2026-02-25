extends CharacterBody3D

@onready var player_origin: XROrigin3D = $PlayerOrigin
@onready var xr_camera_3d: XRCamera3D = $PlayerOrigin/XRCamera3D

## This script simulates a simple motorcycle using CharacterBody3D.
## It handles acceleration, leaning based on steering input, and turning based on lean angle.
## The turning uses an arcade-style physics approximation: omega = (g * tan(theta)) / v
## Modified to reduce bounciness on landing by damping vertical velocity.
## Attach this to a CharacterBody3D node with a CollisionShape3D (e.g., capsule or box for the bike).
## Add a child Node3D (e.g., MeshInstance3D) for the visual model and assign it to 'bike_mesh'.

@export var bike_mesh: Node3D  # The visual mesh of the bike, which will lean.

@export var max_speed: float = 50.0
@export var acceleration: float = 5.0
@export var deceleration: float = 5.0
@export var max_lean_angle_deg: float = 45.0
@export var lean_sensitivity: float = 0.2  # How quickly the lean interpolates (0-1)
@export var turn_sharpness: float = 5  # Multiplier to make turns sharper
@export var landing_damping: float = 0.1  # NEW: Damping factor for vertical velocity on landing (0-1)
@export var jump_gravity_multiplier: float = 5.0

var gravity: float = 9.8
var current_speed: float = 0.0
var current_lean: float = 0.0
var max_lean_angle: float = deg_to_rad(45.0)  # Converted to radians
var was_on_floor: bool = false  # NEW: Track previous frame's floor state

var hmd_tilt: float = 0.0

func _ready() -> void:
	max_lean_angle = deg_to_rad(max_lean_angle_deg)


func _process(delta: float) -> void:
	var hmd_raw = XRServer.get_hmd_transform().basis.orthonormalized().get_euler().z
	hmd_tilt = clampf(hmd_raw, -0.3, 0.3)
	#rotation.z = hmd_tilt
	#player_origin.global_position = global_position + Vector3(0.0, 3.0, 6.0)
	# Orient the CameraRig to face the character's forward direction
	var character_forward = -global_transform.basis.z # Character's forward direction
	character_forward.y = 0 # Keep orientation horizontal (ignore vertical tilt)
	character_forward = character_forward.normalized()
	
	# Set CameraRig to look in the character's forward direction, offset behind
	var look_position = global_transform.origin + character_forward * 2.0 # Adjust distance as needed
	xr_camera_3d.look_at(look_position + Vector3(0.0, 3.0, 6.0), Vector3.UP)
	

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("quit"):
		get_tree().quit()
	if Input.is_action_pressed("reload"):
		get_tree().reload_current_scene()
	# Apply gravity if not on the floor
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# NEW: Dampen vertical velocity on landing (when transitioning from airborne to grounded)
		if not was_on_floor:
			velocity.y -= gravity * jump_gravity_multiplier * delta  # NEW: Apply higher gravity during jumps
		# Prevent sinking or bouncing
		# Inside the is_on_floor() block, before velocity.y = 0
		var floor_normal = get_floor_normal()
		if floor_normal != Vector3.UP:  # Only align if the floor isn't flat
			var target_up = floor_normal
			var current_up = transform.basis.y
			var rotation_axis = current_up.cross(target_up).normalized()
			if rotation_axis.length() > 0.01:
				var rotation_angle = current_up.angle_to(target_up)
				transform.basis = transform.basis.rotated(rotation_axis, rotation_angle * delta * 5.0)  # Smoothly align	
		velocity.y = 0

	# Update floor state for next frame
	was_on_floor = is_on_floor()  # NEW: Store current floor state

	# Get input
	#var accel_input: float = Input.get_action_strength("throttle") - Input.get_action_strength("brake")
	var accel_input = 1.0
	#var steer_input: float = Input.get_action_strength("lean_left") - Input.get_action_strength("lean_right")  # Positive for left turn
	var steer_input = hmd_tilt * 5
	print(hmd_tilt)
	# Update speed
	if accel_input != 0:
		current_speed += accel_input * acceleration * delta
	else:
		# Natural deceleration
		if current_speed > 0:
			current_speed -= deceleration * delta
		elif current_speed < 0:
			current_speed += deceleration * delta

	current_speed = clamp(current_speed, -max_speed / 2, max_speed)

	# Calculate desired lean (proportional to steer and speed)
	var desired_lean: float = steer_input * max_lean_angle * (abs(current_speed) / max_speed)

	# Interpolate current lean towards desired
	current_lean = lerp(current_lean, desired_lean, lean_sensitivity)

	# Apply lean to the visual mesh (roll around local Z axis)
	if bike_mesh:
		bike_mesh.rotation.z = current_lean

	# Calculate turning angular velocity (yaw rate)
	var turn_rate: float = 0.0
	if abs(current_speed) > 0.1 and abs(current_lean) > 0.01:
		turn_rate = (gravity * tan(current_lean)) / abs(current_speed)
		turn_rate *= turn_sharpness

	# Apply turning (rotate around Y axis)
	rotate_y(turn_rate * delta)

	# Set horizontal velocity in the forward direction
	var forward_velocity: Vector3 = -transform.basis.z * current_speed
	velocity.x = forward_velocity.x
	velocity.z = forward_velocity.z

	# Move the body
	move_and_slide()
