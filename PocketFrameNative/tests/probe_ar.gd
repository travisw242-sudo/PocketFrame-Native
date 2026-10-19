extends SceneTree
func _initialize() -> void: _probe.call_deferred()
func _probe() -> void:
	var interface := XRServer.find_interface("OpenXR")
	var initialized: bool=interface!=null and interface.is_initialized()
	var modes: Array=interface.get_supported_environment_blend_modes() if initialized else []
	var report := {"initialized":initialized,"blend_modes":modes,"alpha_supported":XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes}
	var file := FileAccess.open("res://test-logs/ar-capabilities.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("PF_AR_CAPABILITIES ",report)
	quit()
