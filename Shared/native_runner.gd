extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var scenarios_path = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenarios="): scenarios_path=arg.substr(12)
	var scenarios: Array=JSON.parse_string(FileAccess.get_file_as_string(scenarios_path))
	await load(get_script().resource_path.get_base_dir()+"/conformance.gd").run(game,scenarios)
	# Reuse the game's normal cleanup and allow its deferred frees to complete.
	await game._close_test()
