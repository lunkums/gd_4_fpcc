extends CharacterBody3D
class_name PlayerController
# Handles responses to player input by applying movement and triggering interactions with the game world.

const MAX_SPEED: float = 10
const MOVE_ACCEL: float = 4.5
const MOVE_DEACCEL: float = 16.0  # TODO: Rename or give description here
const MAX_SLOPE_ANGLE: float = deg_to_rad(40.0)
const MAX_CAMERA_X_DEGREE: float = 70.0
const FLOOR_SNAP_LENGTH: float = 0.2
const MIN_FLOOR_Y_VELOCITY: float = -0.5

var mouse_look_sensitivity: float = 0.1
var joy_look_sensitivity: float = 2.0
var force_capture_mouse_motion: bool = false
var _turn_amount: float = 0.0  # TODO: This is re-initialized every tick - delete if possible
var _camera_turned_this_update: bool = false  # TODO: can we eliminate this state?

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var _camera: Camera3D = $RotationHelper/Camera3D
@onready var _camera_viewbob: CameraViewbob = $RotationHelper/Camera3D
@onready var _rotation_helper: Node3D = $RotationHelper
@onready var _input_direction: InputDirection = $InputDirection

func _unhandled_input(event: InputEvent) -> void:
	if can_capture_mouse_motion() and event is InputEventMouseMotion:
		_turn_camera(-(event as InputEventMouseMotion).relative * self.mouse_look_sensitivity)

func _physics_process(delta: float) -> void:
	var input_move_vector := self._input_direction.get_move_direction()
	var camera_rotation := -self._input_direction.get_look_direction() * joy_look_sensitivity

	if camera_rotation != Vector2.ZERO:
		_turn_camera(camera_rotation)

	var previous_velocity := self.velocity
	_process_velocity(
		delta, self.velocity,
		PlayerController._get_walk_direction(self._camera.get_global_transform(), input_move_vector)
	)

	# Don't shoot up ramps
	if self.velocity.y > 0 and self.velocity.y > previous_velocity.y:
		self.velocity.y = max(0, previous_velocity.y)

	var is_walking := input_move_vector.length_squared() > 0

	self._camera_viewbob.update_transform(delta, is_walking, self._turn_amount, input_move_vector.x)

	# TODO: what's happening here?
	if !_camera_turned_this_update:
		_turn_amount = 0
	_camera_turned_this_update = false

func get_rotation_helper_x_rotation() -> float:
	return self._rotation_helper.rotation_degrees.x

func get_input_direction() -> InputDirection:
	return self._input_direction

func can_capture_mouse_motion() -> bool:
	return true if self.force_capture_mouse_motion else Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED

# Calculates and applies velocity to physics body based on input, returning the new velocity.
# TODO: "calculates AND applies" - the calculating can be made fully static, move the applying elsewhere
func _process_velocity(delta: float, new_velocity: Vector3, input_direction: Vector3) -> void:
	input_direction.y = 0
	velocity.y -= delta * self.gravity
	var h_vel := Vector3(new_velocity.x, 0, new_velocity.z)

	input_direction = input_direction.normalized()
	var accel := MOVE_ACCEL if input_direction.dot(h_vel) > 0.0 else MOVE_DEACCEL

	var target = input_direction * MAX_SPEED
	h_vel = h_vel.lerp(target, accel * delta)

	# Reduce sliding up/down ramps when walking
	# https://github.com/godotengine/godot/issues/34117
	if !input_direction.dot(h_vel) > 0:
		if h_vel.x < 1 && h_vel.x > -1:
			h_vel.x = 0
		if h_vel.z < 1 && h_vel.z > -1:
			h_vel.z = 0

	if is_on_floor() and velocity.y < MIN_FLOOR_Y_VELOCITY:
		velocity.y = MIN_FLOOR_Y_VELOCITY

	velocity.x = h_vel.x
	velocity.z = h_vel.z

	move_and_slide()

# Basis vectors are already normalized.
static func _get_walk_direction(camera_transform: Transform3D, input_direction: Vector2) -> Vector3:
	return (-camera_transform.basis.z * -input_direction.y) + (camera_transform.basis.x * input_direction.x)

# Turns the player's Y rotation by `amount.y`, and the camera's X rotation by `amount.x`.
# X rotation is clamped by `MAX_CAMERA_X_DEGREE`.
func _turn_camera(amount: Vector2):
	self._rotation_helper.rotation_degrees.x = clamp(
		self._rotation_helper.rotation_degrees.x + amount.y, -MAX_CAMERA_X_DEGREE, MAX_CAMERA_X_DEGREE
	)
	var y_turn := deg_to_rad(amount.x)
	self.rotate_y(y_turn)
	self._turn_amount = -y_turn
	self._camera_turned_this_update = true
