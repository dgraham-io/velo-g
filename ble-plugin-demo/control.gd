extends Control

@onready var device_list: ItemList = $VBoxContainer/HBoxContainer2/DeviceList
@onready var bluetooth_status: ColorRect = $VBoxContainer/HBoxContainer/BluetoothStatus
@onready var permissions_failed_panel: PopupPanel = $PermissionsFailedPanel
@onready var heart_rate_label: Label = $VBoxContainer/HeartRateLabel
@onready var bike_data_label: Label = $VBoxContainer/BikeDataLabel
@onready var scan_timer: Timer = $ScanTimer

@onready var  android_manager = AndroidManager.new()

var _plugin_name = "AndroidBLEPlugin"
var _ble_plugin
var bluetoothDevices: Dictionary

func _ready() -> void:
	
	# detect platform and load plugin
	if Engine.has_singleton(_plugin_name):
		_ble_plugin = Engine.get_singleton(_plugin_name)
		_ble_plugin.connect("permission_required", _on_permission_required)
		_ble_plugin.connect("device_found", _on_device_found)
		_ble_plugin.connect("service_found", _on_service_found)
		_ble_plugin.connect("scan_failed", _on_scan_failed)
		_ble_plugin.connect("plugin_message", _on_plugin_message)
		_ble_plugin.connect("heart_rate_raw_data", _on_heart_rate_raw_data)
		_ble_plugin.connect("indoor_bike_raw_data", _on_indoor_bike_raw_data)
		
		# initialize bluetooth
		request_permissions()
		
	else:
		printerr("Couldn't find plugin " + _plugin_name)


func _on_permission_required(permission: String):
	print("Permission required: ", permission)
	OS.request_permission(permission)


func _on_device_found(deviceName: String, deviceAddress: String):
	#print("Found device: ", deviceName, ", Address: ", deviceAddress)
	if (!bluetoothDevices.has(deviceAddress)):
		bluetoothDevices[deviceAddress] = deviceName
		device_list.add_item(deviceName)


func _on_service_found(serviceName: String):
	print("Found Service: ", serviceName)


func _on_scan_failed(error_code: int):
	print("Scan failed with error: ", error_code)


func _on_plugin_message(message: String):
	print(message)

func _on_heart_rate_raw_data(raw_data: PackedByteArray):
	var heart_data = parse_heart_rate_data(raw_data)
	#print(heart_data)
	heart_rate_label.text = str(heart_data)

func _on_indoor_bike_raw_data(raw_data: PackedByteArray):
	var bike_data = parse_indoor_bike_data(raw_data)
	#print(bike_data)
	bike_data_label.text = str(bike_data)

func _on_bike_data_updated(speed: float, cadence: float, power: int):
	print(speed, cadence, power)

func request_permissions() -> void:
	
	if android_manager.has_permissions(_ble_plugin):
		bluetooth_status.color = Color.GREEN
	else:
		bluetooth_status.color = Color.RED
		print("unable to initialize bluetooth")
		show_retry_or_quit()


func show_retry_or_quit():
	permissions_failed_panel.show()


func _on_retry_button_pressed() -> void:
	permissions_failed_panel.hide()
	request_permissions()

func _on_quit_button_pressed() -> void:
	get_tree().quit() # Replace with function body.


func _on_scan_button_pressed() -> void:
	_ble_plugin.startScan()


func parse_heart_rate_data(data: PackedByteArray) -> Dictionary:
	if data.size() < 2:  # Minimum: flags + uint8 HR
		print("Invalid data: Too short")
		return {}
	
	# Read flags (uint8)
	var flags: int = data[0]
	var offset: int = 1
	var result: Dictionary = {}
	
	# Heart Rate Format: bit 0 (0 = uint8 bpm, 1 = uint16 bpm)
	var hr_format_uint16: bool = (flags & 1) == 1
	if hr_format_uint16:
		if offset + 2 > data.size():
			print("Invalid data: Missing uint16 heart rate")
			return {}
		var hr_raw: int = data[offset] + (data[offset + 1] << 8)
		result["heart_rate"] = hr_raw  # bpm
		offset += 2
	else:
		if offset + 1 > data.size():
			print("Invalid data: Missing uint8 heart rate")
			return {}
		result["heart_rate"] = data[offset]  # bpm
		offset += 1
	
	# Sensor Contact Status: bits 1-2
	# 00/01: Feature not supported
	# 10: Supported but contact not detected
	# 11: Supported and contact detected
	var sensor_contact_bits: int = (flags >> 1) & 3
	result["sensor_contact_supported"] = sensor_contact_bits >= 2
	result["sensor_contact_detected"] = sensor_contact_bits == 3
	
	# Energy Expended: bit 3 (uint16 kJ if present)
	if flags & (1 << 3):
		if offset + 2 > data.size():
			print("Invalid data: Missing energy expended")
			return {}
		var energy_raw: int = data[offset] + (data[offset + 1] << 8)
		result["energy_expended"] = energy_raw  # kJ
		offset += 2
	
	# RR-Intervals: bit 4 (one or more uint16, in 1/1024 seconds; convert to ms)
	if flags & (1 << 4):
		result["rr_intervals"] = []  # Array of ms values
		while offset + 2 <= data.size():
			var rr_raw: int = data[offset] + (data[offset + 1] << 8)
			result["rr_intervals"].append(rr_raw * (1000.0 / 1024.0))  # Convert to ms
			offset += 2
	
	# Optional: Check if all data was consumed
	if offset != data.size():
		print("Warning: Extra bytes in data")
	
	return result


func parse_indoor_bike_data(data: PackedByteArray) -> Dictionary:
	if data.size() < 2:
		print("Invalid data: Too short")
		return {}
	
	# Read flags (little-endian uint16)
	var flags: int = data[0] + (data[1] << 8)
	var offset: int = 2
	var result: Dictionary = {}
	
	# Instantaneous Speed (uint16, km/h * 100) - present if bit 0 == 0
	if (flags & 1) == 0:
		if offset + 2 > data.size():
			print("Invalid data: Missing instantaneous speed")
			return {}
		var speed_raw: int = data[offset] + (data[offset + 1] << 8)
		result["instantaneous_speed"] = speed_raw * 0.01  # km/h
		offset += 2
	
	# Average Speed (uint16, km/h * 100) - bit 1
	if flags & (1 << 1):
		if offset + 2 > data.size():
			print("Invalid data: Missing average speed")
			return {}
		var avg_speed_raw: int = data[offset] + (data[offset + 1] << 8)
		result["average_speed"] = avg_speed_raw * 0.01  # km/h
		offset += 2
	
	# Instantaneous Cadence (uint16, RPM * 2) - bit 2
	if flags & (1 << 2):
		if offset + 2 > data.size():
			print("Invalid data: Missing instantaneous cadence")
			return {}
		var cadence_raw: int = data[offset] + (data[offset + 1] << 8)
		result["instantaneous_cadence"] = cadence_raw * 0.5  # RPM
		offset += 2
	
	# Average Cadence (uint16, RPM * 2) - bit 3
	if flags & (1 << 3):
		if offset + 2 > data.size():
			print("Invalid data: Missing average cadence")
			return {}
		var avg_cadence_raw: int = data[offset] + (data[offset + 1] << 8)
		result["average_cadence"] = avg_cadence_raw * 0.5  # RPM
		offset += 2
	
	# Total Distance (uint24, meters) - bit 4
	if flags & (1 << 4):
		if offset + 3 > data.size():
			print("Invalid data: Missing total distance")
			return {}
		var total_distance: int = data[offset] + (data[offset + 1] << 8) + (data[offset + 2] << 16)
		result["total_distance"] = total_distance  # meters
		offset += 3
	
	# Resistance Level (sint16, unitless) - bit 5
	if flags & (1 << 5):
		if offset + 2 > data.size():
			print("Invalid data: Missing resistance level")
			return {}
		var resistance_raw: int = data[offset] + (data[offset + 1] << 8)
		if resistance_raw >= 0x8000:
			resistance_raw -= 0x10000  # Sign extend
		result["resistance_level"] = resistance_raw
		offset += 2
	
	# Instantaneous Power (sint16, watts) - bit 6
	if flags & (1 << 6):
		if offset + 2 > data.size():
			print("Invalid data: Missing instantaneous power")
			return {}
		var power_raw: int = data[offset] + (data[offset + 1] << 8)
		if power_raw >= 0x8000:
			power_raw -= 0x10000  # Sign extend
		result["instantaneous_power"] = power_raw  # watts
		offset += 2
	
	# Average Power (sint16, watts) - bit 7
	if flags & (1 << 7):
		if offset + 2 > data.size():
			print("Invalid data: Missing average power")
			return {}
		var avg_power_raw: int = data[offset] + (data[offset + 1] << 8)
		if avg_power_raw >= 0x8000:
			avg_power_raw -= 0x10000  # Sign extend
		result["average_power"] = avg_power_raw  # watts
		offset += 2
	
	# Expended Energy (multiple fields) - bit 8
	if flags & (1 << 8):
		if offset + 5 > data.size():
			print("Invalid data: Missing expended energy fields")
			return {}
		var total_energy: int = data[offset] + (data[offset + 1] << 8)
		result["total_energy"] = total_energy  # kcal
		offset += 2
		var energy_per_hour: int = data[offset] + (data[offset + 1] << 8)
		result["energy_per_hour"] = energy_per_hour  # kcal/h
		offset += 2
		var energy_per_minute: int = data[offset]
		result["energy_per_minute"] = energy_per_minute  # kcal/min
		offset += 1
	
	# Heart Rate (uint8, BPM) - bit 9
	if flags & (1 << 9):
		if offset + 1 > data.size():
			print("Invalid data: Missing heart rate")
			return {}
		result["heart_rate"] = data[offset]
		offset += 1
	
	# Metabolic Equivalent (uint8, MET * 10) - bit 10
	if flags & (1 << 10):
		if offset + 1 > data.size():
			print("Invalid data: Missing MET")
			return {}
		result["metabolic_equivalent"] = data[offset] * 0.1
		offset += 1
	
	# Elapsed Time (uint16, seconds) - bit 11
	if flags & (1 << 11):
		if offset + 2 > data.size():
			print("Invalid data: Missing elapsed time")
			return {}
		var elapsed_time: int = data[offset] + (data[offset + 1] << 8)
		result["elapsed_time"] = elapsed_time  # seconds
		offset += 2
	
	# Remaining Time (uint16, seconds) - bit 12
	if flags & (1 << 12):
		if offset + 2 > data.size():
			print("Invalid data: Missing remaining time")
			return {}
		var remaining_time: int = data[offset] + (data[offset + 1] << 8)
		result["remaining_time"] = remaining_time  # seconds
		offset += 2
	
	# Optional: Check if all data was consumed
	if offset != data.size():
		print("Warning: Extra bytes in data")
	
	return result


func _on_scan_timer_timeout() -> void:
	_ble_plugin.stopScan()# Replace with function body.
