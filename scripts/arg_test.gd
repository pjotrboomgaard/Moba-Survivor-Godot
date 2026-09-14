extends Node
## Quick diagnostic: print OS.get_cmdline_args() and quit.
## Run: godot --path . -- --test-args

func _ready() -> void:
	print("[ArgTest] cmdline_args=", str(OS.get_cmdline_args()))
	print("[ArgTest] args_after_dashdash=", str(OS.get_cmdline_user_args()))
	get_tree().quit(0)
