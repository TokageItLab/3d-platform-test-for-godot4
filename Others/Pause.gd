extends Node

var paused = false
var step_once = false

func _ready():
	_update_label(false)

func _physics_process(_delta):
	if Input.is_action_just_pressed('pause'):
		paused = !paused
		get_tree().paused = paused
		step_once = false
		if paused:
			_update_label(true)
		else:
			_update_label(false)
	
	if paused:
		if step_once:
			get_tree().paused = true
			step_once = false
		elif Input.is_action_just_pressed('step'):
			get_tree().paused = false
			step_once = true

func _update_label(display:bool):
	owner.find_node("Pause").visible = display
	owner.find_node("PauseCommand").visible = display
