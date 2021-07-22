extends Node3D


@onready var _player: CharacterBody3D = $Player
@onready var _debug_log: Label = $Texts/Debug
var _debug_dict: Dictionary = {
}

const SPEED_ARRAY_SIZE = 30
var _speed_array: Array = []
var _speed_average: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in range(SPEED_ARRAY_SIZE):
		_speed_array.append(0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	
	# Calc speed average
	_speed_array.push_front(_player.linear_velocity.length())
	_speed_array.pop_back()
	_speed_average = 0
	for i in range(SPEED_ARRAY_SIZE):
		_speed_average += _speed_array[i]
	_speed_average / SPEED_ARRAY_SIZE
	_debug_dict["Average Speed"] = snapped(_speed_average, 0.001)
	
	_debug_dict["Is On Floor"] = _player.is_on_floor()
	_debug_dict["Is On Wall"] = _player.is_on_wall()
	
	_debug_dict["Character Velocity X"] = snapped(_player.linear_velocity.x, 0.001)
	_debug_dict["Character Velocity Y"] = snapped(_player.linear_velocity.y, 0.001)
	_debug_dict["Character Velocity Z"] = snapped(_player.linear_velocity.z, 0.001)

	var floor_v: Vector3 = _player.get_floor_velocity()
	_debug_dict["Floor Velocity X"] = snapped(floor_v.x, 0.001)
	_debug_dict["Floor Velocity Y"] = snapped(floor_v.y, 0.001)
	_debug_dict["Floor Velocity Z"] = snapped(floor_v.z, 0.001)
	
	_debug_log.text = ""
	for i in _debug_dict:
		_debug_log.text += str(i) + ": " + str(_debug_dict[i]) + "\n"
