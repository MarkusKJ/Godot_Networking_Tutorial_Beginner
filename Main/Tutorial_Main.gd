"""
LEARNING GODOT +v4 NETWORKING
#------------------------------------------------------------------#

SERVER/HOST manages the game state and coordinates CLIENT connections.
CLIENTS connect to the SERVER/HOST and receive updates from it
CLIENTS receive updates from the SERVER/HOST and DON'T DIRECTLY COMMUNICATE WITH EACH OTHER.
EACH PLAYER instance has a MULTIPLAYER AUTHORITY set to its PEER ID.


#------------------------------------------------------------------#
RPC stands for "REMOTE PROCEDURE CALL".
It's a way for the game to communicate with OTHER PLAYERS OR THE SERVER over the network.

1) RPC functions are CALLED on the sending end: When you call an RPC function,
 you're sending a message to the SERVER OR OTHER PLAYERS.

2) RPC functions are EXECUTED ON THE RECEIVING END:
	 The server or other players receive the message and execute the corresponding function.

3) RPC functions can be CALLED ON SPECIFIC PEERS by RPC_ID: 
#------------------------------------------------------------------#	
"""
#--------------------------------------------------------------------------------------------------#
extends Node3D

"""These variables are used to reference UI elements in the scene tree."""
@onready var net_info: VBoxContainer = $NetUI/NetInfo
@onready var menu: VBoxContainer = $NetUI/Menu
@onready var display: Label = $NetUI/NetInfo/Display
@onready var lid: Label = $NetUI/NetInfo/ID
@onready var host: Button = $NetUI/Menu/Host
@onready var join: Button = $NetUI/Menu/Join

#Magic. Do not touch.
"""Just kidding, it's just a variable to hold the multiplayer peer object"""
var multiplayer_peer = ENetMultiplayerPeer.new()

"""These constants define the port and address used for multiplayer connections"""
const PORT = 6969
const ADDRESS = "localhost"

"""This array keeps track of connected peer IDs"""
var connected_peer_ids = []


"""This function is called when the node is ready"""
func _ready() -> void:
	"""Connect the host and join buttons to their respective functions"""
	host.connect("pressed", Callable(self, "start_server"))
	join.connect("pressed",Callable(self, "start_client"))
	
	"""Connect to signals emitted by the multiplayer peer"""
	multiplayer.peer_connected.connect(func(id): print("Peer connected: ", id))
	multiplayer.peer_disconnected.connect(func(id): print("Peer disconnected: ", id))
	
	#debug message
	print("Player ready. Authority: ", get_multiplayer_authority(), " My ID: ", multiplayer.get_unique_id())


"""This function is called when the host button is pressed"""	
func start_server():
	display.text = 'SERVER'
	menu.visible = false
	
	"""Create a server using the multiplayer peer"""
	multiplayer_peer.create_server(PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	
	#debug message
	lid.text = str(multiplayer.get_unique_id())
	
	"""Add the server player to the scene"""
	add_player(multiplayer.get_unique_id())
	
	"""Connect to signals emitted by the multiplayer peer"""
	#this will allow the server to spawn a player for the client
	multiplayer.peer_connected.connect(
		func(new_peer_id):
			add_player(new_peer_id)
			"""Send a signal to the new player to add existing players"""
			rpc_id(new_peer_id, "add_existing_players", connected_peer_ids)
	)
	multiplayer.peer_disconnected.connect(
		func(peer_id):
			print("Peer disconnected: ", peer_id)
			"""Remove the disconnected player from the scene"""
			remove_player(peer_id)
			"""Send a signal to all players to remove the disconnected player"""
			rpc("remove_disconnected_player", peer_id)
	)
#------------------------------------------------------------------------------#
"""This function is called when the join button is pressed"""
func start_client():
	display.text = "CLIENT"
	menu.visible = false
	
	"""Create a client using the multiplayer peer"""
	multiplayer_peer.create_client(ADDRESS, PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	
	#debug message
	lid.text = str(multiplayer.get_unique_id())

"""This function adds a player to the scene"""
func add_player(peer_id):
	
	"""Check if the peer ID is not already in the connected peer IDs array"""
	if peer_id not in connected_peer_ids:
		"""Add the peer ID to the connected peer IDs array"""
		connected_peer_ids.append(peer_id)
		
		"""Instantiate a new player scene"""
		var player = preload('res://Scenes/player.tscn').instantiate()
		
		"""Set the multiplayer authority of the player to the peer ID"""
		player.set_multiplayer_authority(peer_id)
		
		"""Set the name of the player to the peer ID"""
		player.name = str(peer_id)
		
		"""Add the player to the scene"""
		add_child(player)
		
		"""Set the position of the player to a random location"""
		player.position.x = randf() * 10 - 5
		player.position.z = randf() * 10 - 5
		
		#debug message
		print("Player ", peer_id, " added")
		
		"""If the multiplayer server is running sync players"""
		if multiplayer.is_server():
			
			"""RPC SYNC_NEW_PLAYER"""
			rpc("sync_new_player", peer_id, player.position)


"""This function removes a player from the scene"""
func remove_player(peer_id):
	
	"""Check if the peer ID is in the connected peer IDs array"""
	if peer_id in connected_peer_ids:
		
		"""Remove the peer ID from the connected peer IDs array"""
		connected_peer_ids.erase(peer_id)
		
		"""Get the player node with the peer ID"""
		var player = get_node_or_null(str(peer_id))
		
		"""If the player node exists, queue it for deletion"""
		if player:
			player.call_deferred("queue_free")
		
		#debug message
		print("Player ", peer_id, " removed")
	else:
		#debug message
		print("Attempted to remove non-existent player: ", peer_id)

#------------------------------------------------------------------------------#

"""This function is called when a player connects to the server"""
@rpc('call_local')
func add_existing_players(peer_ids):
	
	"""Iterate over the peer IDs"""
	for peer_id in peer_ids:
		
		"""If the player hasn't been added yet, add player"""
		if peer_id != multiplayer.get_unique_id():
			add_player(peer_id)

"""This function is called when a player disconnects from the server"""
@rpc('call_local')
func remove_disconnected_player(peer_id):
	"""Remove the player from the scene"""
	remove_player(peer_id)
	
"""This function is called when a new player is added to the scene"""
@rpc
func sync_new_player(peer_id, initial_position):
	"""!is_server(): Returns true if this MultiplayerAPI's multiplayer_peer is invalid"""
	if not multiplayer.is_server():
		#if not then find the player with the peer_id
		var player = get_node_or_null(str(peer_id))
		
		"""If the player node does not exist, create a new one"""
		if not player:
			player = preload('res://Scenes/player.tscn').instantiate()
			player.set_multiplayer_authority(peer_id)
			player.name = str(peer_id)
			add_child(player)
			
		"""Set the position of the player to the initial position"""	
		player.position = initial_position
		
		#debug message
		print("Player ", peer_id, " synced")

#------------------------------------------------------------------------------#
