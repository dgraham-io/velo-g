extends RigidBody3D

@onready var player_origin: XROrigin3D = $PlayerOrigin
@onready var test_label: Label3D = $PlayerOrigin/XRCamera3D/TestLabel

var hmd_tilt: float

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("quit"):
		get_tree().quit()
	
	var hmd_z = XRServer.get_hmd_transform().basis.orthonormalized().get_euler().z
	hmd_tilt = clamp(hmd_z, -0.25, 0.25)
	
	rotation.z = hmd_tilt
	test_label.text = str(hmd_tilt)
	
	apply_central_force(basis.z * delta * -5000)
	apply_torque(Vector3(0.0, hmd_tilt * 100, 0.0))

func _process(delta: float) -> void:
	player_origin.position = position + Vector3(0.0, 5.0, 20.0)
