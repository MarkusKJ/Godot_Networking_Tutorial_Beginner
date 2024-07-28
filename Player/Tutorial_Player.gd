
"""This script is attached to the player in the game"""
extends CharacterBody3D

"""These variables reference the camera and player name label in the scene tree"""
@onready var playercam: Camera3D = $Camera3D
@onready var player_name: Label = $PlayerName

"""These variables control the player's movement speed, jump velocity, and mouse sensitivity"""
@export var speed: float = 10.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.05

"""This variable stores the gravity value from the project settings"""
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

"""This function is called when the player is ready"""
func _ready() -> void:
	player_name.text = name
	
	"""If this player is not the authority (i.e., not the local player), disable physics process and input"""
	if not is_multiplayer_authority():
		# Disable physics process and input for non-authority players
		set_physics_process(false)
		set_process_input(false)
		# Optionally, you might want to disable the camera for non-authority players
		playercam.current = false

"""This function is called every physics frame (i.e., every time the physics engine updates)"""
func _physics_process(delta: float) -> void:
	"""If this player is not the authority, skip this function"""
	if not is_multiplayer_authority():
		return
	# Apply gravity to the player's velocity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jumping
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity


	"""Get the input direction from the player's movement keys"""
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	"""Move the player based on the input direction"""
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		"""If no input direction is given, slow down the player's movement"""
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	
	# Send position update to other clients
	rpc("remote_set_position", global_position)


@rpc("unreliable")

"""This function is marked as a REMOTE PROCEDURE CALL (RPC) with "UNRELIABLE" networking.
# "UNRELIABLE" means the network DOESN'T GUARANTEE DELIVERY OR ORDER OF THESE CALLS,
# which is often USED FOR FREQUENT UPDATES WHERE OCCASIONAL PACKET LOSS IS ACCEPTABLE."""

func remote_set_position(authority_position: Vector3) -> void:
	
	"""Check if this instance is not the multiplayer authority"""
	if not is_multiplayer_authority():
		"""
		it's not the authority, INTERPOLATE(lerp) the position
			This creates a smoother movement by BLENDING THE CURRENT POSITION
				WITH THE RECEIVED POSITION
		"""
		global_position = global_position.lerp(authority_position, 0.5)

"""This function handles input events"""
func _input(event: InputEvent) -> void:
	"""Check if the event is a mouse motion event"""
	if event is InputEventMouseMotion:
		
		"""Camera movement(FPS)"""
		#Rotate the player around the Y-axis
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		# Rotate the camera around the X-axis (up-down rotation)
		playercam.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		# Restrict the up-down look angle between -90 and 90 degrees
		playercam.rotation.x = clamp(playercam.rotation.x, deg_to_rad(-90), deg_to_rad(90))
