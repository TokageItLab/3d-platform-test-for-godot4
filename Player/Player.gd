extends CharacterBody3D

# Adjusting init timing
var _once = true


# PlayerData
const VIEW_POINT: Vector3 = Vector3(0, 1, 0);


# Adjust Input
# Note: The input value of the pad may not reach the upper limit
const INPUT_AMP: float = 1.5


# Define for Camera
const CAMERA_MOUSE_ROTATION_SPEED: float = 0.001
const CAMERA_CONTROLLER_ROTATION_SPEED: float = 3.0
const CAMERA_X_ROT_MIN: float = -89.0
const CAMERA_X_ROT_MAX: float = 89.0
var _camera: InterpolatedCamera3D
var _camera_point: Node3D
var _camera_gaze: SpringArm3D
var _camera_base: Node3D
var _camera_base2: Node3D
var _camera_light: OmniLight3D


# Define for Movement
const GRAVITY: float = 30.0 # 重力加速度
const DIRECTION_INTERPOLATE_SPEED: float = 1.0
const MOTION_INTERPOLATE_SPEED: float = 20.0 # 移動速度
const ROTATION_INTERPOLATE_SPEED: float = 20.0 # 転回速度
const JUMP_SPEED: float = 12.0 # ジャンプ初速度
const FLOOR_WAIT = 3.0
enum PLAYER_POSITION_STATE {
	FLOOR,
	AIR
}
@onready var _animation_tree: AnimationTree = $AnimationTree


# States
var _state_orientation: Transform3D = Transform3D.IDENTITY
var _state_root_motion: Transform3D = Transform3D.IDENTITY
var _state_motion: Vector2 = Vector2.ZERO
var _state_gravity: float = 0.0
var _state_jump_velocity: Vector3 = Vector3.ZERO
var _state_jump_additional_velocity: Vector3 = Vector3.ZERO
var _state_jump_speed: float = 0.0

var _state_camera_x_rot: float = 0.0

var _state_is_running: bool = false
var _state_was_running_before_jumping: bool = false
var _state_is_jumping: bool = false


# Funcs for Camera
func _ready_camera():
	_camera_base = Node3D.new()
	_camera_base.set_name("CameraBase")
	_camera_base2 = Node3D.new()
	_camera_base2.set_name("CameraBase2")
	_camera_gaze = SpringArm3D.new()
	_camera_gaze.set_name("CameraGaze")
	_camera_point = Node3D.new()
	_camera_point.set_name("CameraPoint")
	_camera = InterpolatedCamera3D.new()
	_camera.set_name("Camera")
	_camera_light = OmniLight3D.new()
	_camera_light.set_name("CameraLight")

	self.get_parent().add_child(_camera_base)
	_camera_base.add_child(_camera_base2)
	_camera_base2.add_child(_camera_gaze)
	_camera_gaze.add_child(_camera_point)
	self.get_parent().add_child(_camera)
	_camera.add_child(_camera_light)
	_camera.target = _camera_point.get_path()
	
	var shape = SphereShape3D.new()
	shape.set_radius(0.1)
	_camera_gaze.set_shape(shape)
	_camera_gaze.add_excluded_object(self.get_rid())
	_camera_light.omni_range = 10
	_camera.fov = 60
	_camera.near = 0.01
	_camera.current = true
	
	self.init_camera()


func init_camera() -> void:    
	_camera_base.rotation.y = self.rotation.y
	_camera_base2.transform.origin = Vector3(0, VIEW_POINT.y, 0)
	_camera_gaze.set_length(4)
	_camera_gaze.rotation.y = PI
	_camera_point.rotation.y = 0
	_camera.translate_speed = 1
	_state_camera_x_rot = PI * 0.125
	return


func _input_camera(delta: float) -> void:
	var camera_move: Vector2 = Vector2(
		Input.get_action_strength("view_right") - Input.get_action_strength("view_left"),
		Input.get_action_strength("view_up") - Input.get_action_strength("view_down")
	)
	camera_move *= INPUT_AMP
	camera_move = camera_move.normalized() * clamp(camera_move.length(), 0, 1)
	var camera_speed_this_frame = delta * CAMERA_CONTROLLER_ROTATION_SPEED
	self._rotate_camera(camera_move * camera_speed_this_frame)
	return

func _rotate_camera(move) -> void:
	_camera_base.rotate_y(-move.x)
	_camera_base.orthonormalize()
	_state_camera_x_rot += move.y
	_state_camera_x_rot = clamp(_state_camera_x_rot, deg2rad(CAMERA_X_ROT_MIN), deg2rad(CAMERA_X_ROT_MAX))
	_camera_base2.rotation.x = _state_camera_x_rot
	return


func _follow_camera() -> void:
	_camera_base.global_transform.origin = self.global_transform.origin
	return


# Funcs for Movement
func _input_motion(delta: float, motion: Vector2) -> Vector2:
	var motion_target: Vector2 = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_front")
	)
	motion_target *= INPUT_AMP
	motion_target = motion_target.normalized() * clamp(motion_target.length(), 0, 1)
	return motion.lerp(motion_target, MOTION_INTERPOLATE_SPEED * delta)


func _apply_orientation(delta: float, orientation: Transform3D) -> void:
	var h_velocity = orientation.origin / delta
	self.linear_velocity.x = h_velocity.x
	self.linear_velocity.z = h_velocity.z

	# Apply GRAVITY
	if self.is_on_floor():
		_state_gravity = 0
		var length = Vector3(self.linear_velocity.x, 0, self.linear_velocity.z).length()
		self.linear_velocity = self.linear_velocity.normalized() * length
	else:
		_state_gravity = -GRAVITY * delta
		self.linear_velocity.y = self.linear_velocity.y + _state_gravity
	

	# Movement when jumping
	var final_jump_velocity = _state_jump_velocity
	if !self.is_on_floor():
		if _state_jump_velocity.x * _state_jump_additional_velocity.x > 0 && abs(_state_jump_additional_velocity.x) > abs(_state_jump_velocity.x):
			final_jump_velocity.x = _state_jump_additional_velocity.x
		else:
			final_jump_velocity.x = _state_jump_velocity.x + _state_jump_additional_velocity.x
		if _state_jump_velocity.z * _state_jump_additional_velocity.z > 0 && abs(_state_jump_additional_velocity.z) > abs(_state_jump_velocity.z):
			final_jump_velocity.z = _state_jump_additional_velocity.z
		else:
			final_jump_velocity.z = _state_jump_velocity.z + _state_jump_additional_velocity.z

	# Calc snap value
	if self.is_on_floor() && !_state_is_jumping:    
		self.snap = -self.get_floor_normal() - self.get_floor_velocity() * delta
	else:
		self.snap = Vector3.ZERO

	# Apply velocity
	var tmp_velocity = self.linear_velocity;
	self.linear_velocity = self.linear_velocity + final_jump_velocity
	self.move_and_slide()
	
	# Don't go up slopes in the not floor
	if !self.is_on_floor() && get_slide_count() > 0 && _state_jump_velocity.y <= 0:
		self.linear_velocity.y = tmp_velocity.y

	# Reset jump velocity
	_state_jump_velocity.y = 0

	return


func _tps_movement(delta: float) -> void:
	self._input_camera(delta)
	var camera_basis = _camera_base.global_transform.basis
	var camera_z = camera_basis.z
	var camera_x = camera_basis.x
	camera_z.y = 0
	camera_z = camera_z.normalized()
	camera_x.y = 0
	camera_x = camera_x.normalized()
	_state_motion = self._input_motion(delta, _state_motion)

	var target: Vector3 = camera_x * _state_motion.x + camera_z * _state_motion.y
	if target.length() > 0.001:
		var q_from: Quaternion = _state_orientation.basis.get_rotation_quaternion()
		var q_to: Quaternion = Transform3D().looking_at(target, Vector3.UP).basis.get_rotation_quaternion()
		# Interpolate current rotation with desired one.
		_state_orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))
	
	# Land behavior
	if self.is_on_floor():
		if _state_motion.length() < 0.1:
			_animation_tree["parameters/StateLand/current"] = 0
		else:
			if !_state_is_running:
				_animation_tree["parameters/StateLand/current"] = 1
			else:
				_animation_tree["parameters/StateLand/current"] = 2

		_state_root_motion = _animation_tree.get_root_motion_transform()
		_state_root_motion.origin.y = 0
		_state_orientation *= _state_root_motion

	# Air behavior
	if !self.is_on_floor():
		# Air movement
		if !_state_was_running_before_jumping:
			_state_jump_additional_velocity = -target * 1.5 # walk root motion speed
		else:
			_state_jump_additional_velocity = -target * max(_state_jump_speed, 1.5)

		# Play fall animation
		_animation_tree["parameters/StateGeneral/current"] = 1
		_animation_tree["parameters/StateJump/current"] = 1
	if _state_is_jumping && self.linear_velocity.y >= 0:
		# Play jump animation
		_animation_tree["parameters/StateGeneral/current"] = 1
		_animation_tree["parameters/StateJump/current"] = 0

	# Apply movement
	self._apply_orientation(delta, _state_orientation)
	_state_orientation.origin = Vector3.ZERO # Clear accumulated root motion displacement (was applied to speed).
	_state_orientation = _state_orientation.orthonormalized() # Orthonormalize orientation.
	self.global_transform.basis = _state_orientation.basis

	# Reset jump velocity
	if self.is_on_floor():
		_animation_tree["parameters/StateGeneral/current"] = 0
		_state_is_jumping = false
		_state_jump_velocity = Vector3.ZERO
		_state_jump_additional_velocity = Vector3.ZERO

	return


# Called when the node enters the scene tree for the first time.
# func _ready():
#	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _process(delta):
	# After ready
	if _once:
		_once = false
		self._ready_camera()

	# Input run
	if Input.is_action_pressed("action_run"):
		_state_is_running = true
	else:
		_state_is_running = false
		_state_was_running_before_jumping = false

	# Input jump
	if Input.is_action_just_pressed("action_jump"):
		if self.is_on_floor():
			_state_jump_velocity = Vector3(0, JUMP_SPEED, 0)
			var floor_velocity = self.get_floor_velocity()
			# Subtract velocity by moving playform
			_state_jump_velocity += Vector3(floor_velocity.x * (1.0 - delta), 0, floor_velocity.z * (1.0 - delta))
			# Reset
			self.linear_velocity.y = 0
			# Set state is jump
			_state_is_jumping = true
			# Does jump has running-up
			if _state_is_running && !is_equal_approx(_state_motion.length(), 0):
				_state_was_running_before_jumping = true
				# Prevent increasing velocity when jumping on a slope
				var current_velocity_normal = self.linear_velocity.normalized()
				var slide_velocity: Vector3 = Vector3(current_velocity_normal.x, 0, current_velocity_normal.y)
				slide_velocity = slide_velocity.normalized() * 4.0 # run root motion speed
				if self.is_on_floor():
					slide_velocity = slide_velocity.slide(self.get_floor_normal())
				slide_velocity = Vector3(slide_velocity.x, 0, slide_velocity.z)
				_state_jump_speed = slide_velocity.length()
			else:
				_state_was_running_before_jumping = false
				_state_jump_speed = 0.0
	self._tps_movement(delta)
	self._follow_camera()
	return
