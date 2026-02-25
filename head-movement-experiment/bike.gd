extends RigidBody3D

@onready var player_origin: XROrigin3D = $PlayerOrigin

@onready var rays = get_tree().get_nodes_in_group("Raycasts")
@onready var body: MeshInstance3D = $body

@export var speed = 15000
var turn_speed = 5000
var reverse_speed = 10000
@export var hover_force = 5000
@export var turn_point: Vector3 = Vector3(0.0, 0.0, 1.0)
@export var turn_force: float = 5.0
var hmd_tilt: float = 0.0


func _process(delta: float) -> void:
	
	var hmd_raw = XRServer.get_hmd_transform().basis.orthonormalized().get_euler().z
	hmd_tilt = clampf(hmd_raw, -0.25, 0.25)
	#rotation.z = hmd_tilt
	player_origin.global_position = global_position + Vector3(0.0, 3.0, 6.0)
	
	apply_central_force(-global_transform.basis.z * speed * delta)
	apply_torque(Vector3(0, hmd_tilt * 100, 0))
	
	if Input.is_action_pressed("quit"):
		get_tree().quit()
			
	if Input.is_action_pressed("thrust"):
		apply_central_force(Vector3(0,0,-100))
		
	if Input.is_action_pressed("left"):
		apply_torque(Vector3(0, -10, 0))
		
	if Input.is_action_pressed("right"):
		apply_torque(Vector3(0,10, 0))

func _physics_process(delta: float) -> void:
	for ray in rays:
		if ray.is_colliding():
			var collision_point = ray.get_collision_point()
			
			# calculate distance between ray position and raycast hit
			var dist = collision_point.distance_to(ray.global_transform.origin)
			
			apply_force(Vector3.UP * (1/dist) * hover_force * delta, ray.global_transform.origin - global_transform.origin)
			
	if Input.is_action_pressed("quit"):
		get_tree().quit()
		
	if Input.is_action_pressed("thrust"):
		apply_central_force(-global_transform.basis.z * speed * delta)
		
		
	if Input.is_action_pressed("left"):
		#apply_torque(global_transform.basis.y * turn_speed * delta)
		apply_torque(Vector3(0.0, turn_force, 0.0))
		
	if Input.is_action_pressed("right"):
		#apply_torque(-global_transform.basis.y * turn_speed * delta)
		apply_torque(Vector3(0.0, -turn_force, 0.0))
