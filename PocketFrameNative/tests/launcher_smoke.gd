extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var launcher = load("res://launcher.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	assert(not launcher.vr_button.disabled and not launcher.desktop_button.disabled, "Cartridge-only launcher must not require a selected game")
	assert(not launcher._session_arguments().has("-Game"), "Normal launch must start empty")
	assert(launcher.quality_choice.item_count == 3, "Native, 2x and 3x quality presets are offered")
	assert(launcher.room_choice.item_count == 2, "Available rooms must populate the dropdown")
	assert(launcher.fit_controls.size() == 10, "Console volume, stylus and controller-fit settings must be available")
	assert(launcher.stylus_side_choice.item_count == 2 and launcher.stylus_return_check != null, "Stylus comfort settings must be available")
	launcher._launch(true)
	for i in range(160):
		await create_timer(0.25).timeout
		if not launcher.launching:
			break
	assert(not launcher.launching, "Launch operation timed out")
	assert(launcher.status.text == "Desktop session launched.", "Launch helper did not succeed: " + launcher.status.text)
	launcher._launch(true)
	for i in range(80):
		await create_timer(0.25).timeout
		if not launcher.launching:
			break
	assert(launcher.status.text.begins_with("Could not launch"), "A duplicate game session should be blocked")
	print("PASS: launcher controls, desktop launch, and duplicate-session protection")
	quit()
