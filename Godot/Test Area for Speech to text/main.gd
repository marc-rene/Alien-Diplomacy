extends Node3D

var xr_interface: XRInterface
@onready var environment: Environment = $"WorldEnvironment".environment


func enable_passthrough() -> bool:
	if xr_interface == null:
		return false
	if xr_interface.is_passthrough_supported():
		return xr_interface.start_passthrough()
	var modes = xr_interface.get_supported_environment_blend_modes()
	if xr_interface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
		xr_interface.set_environment_blend_mode(xr_interface.XR_ENV_BLEND_MODE_ALPHA_BLEND)
		return true
	return false


func _ready() -> void:
	xr_interface = XRServer.primary_interface
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialised successfully")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		enable_passthrough()
	else:
		print("OpenXR not initialised — xr_interface exists: ", xr_interface != null)
		if xr_interface:
			print("  is_initialized: ", xr_interface.is_initialized())
			print("  capabilities: ", xr_interface.get_capabilities())
		print("Check headset connection / OpenXR runtime")
