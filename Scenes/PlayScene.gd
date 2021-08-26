extends Node3D


@onready var _player: CharacterBody3D = $Player
@onready var _debug_log: Label = $Texts/Debug
var _debug_dict: Dictionary = {
}

const SPEED_ARRAY_SIZE = 30
var _speed_array: Array = []
var _speed_average: float = 0.0
var before_player_pos: Vector3 = Vector3()
# Called when the node enters the scene tree for the first time.
func _ready():
	for i in range(SPEED_ARRAY_SIZE):
		_speed_array.append(0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	
	# Calc speed average
	_speed_array.push_front((before_player_pos - _player.global_transform.origin).length())
	before_player_pos = _player.global_transform.origin
	_speed_array.pop_back()
	_speed_average = 0
	for i in range(SPEED_ARRAY_SIZE):
		_speed_average += _speed_array[i]
	_speed_average / SPEED_ARRAY_SIZE
	_debug_dict["Position"] =  "(%f, %f, %f)" % [_player.global_transform.origin.x, _player.global_transform.origin.y, _player.global_transform.origin.z]
	_debug_dict["Average Speed"] = snapped(_speed_average, 0.001)
	_debug_dict["Character Velocity"] = "(%.2f, %.2f, %.2f)" % [_player.linear_velocity.x, _player.linear_velocity.y, _player.linear_velocity.z]
	var floor_v: Vector3 = _player.get_platform_velocity()
	_debug_dict["Floor Velocity"] = "(%.2f, %.2f, %.2f)" % [floor_v.x, floor_v.y, floor_v.z]
	
	_debug_dict["Is On Floor"] = _player.is_on_floor()
	_debug_dict["Is On Wall"] = _player.is_on_wall()
	
	if _player.last_collision:
		_debug_dict["Collision angle"] = "%.2f°" % rad2deg(_player.last_collision.get_angle())
	
	_debug_log.text = ""
	for i in _debug_dict:
		_debug_log.text += str(i) + ": " + str(_debug_dict[i]) + "\n"
