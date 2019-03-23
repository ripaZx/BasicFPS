extends KinematicBody

var animation_manager

var current_weapon_name = "DISARMATO"
var weapons = {"DISARMATO":null, "COLTELLO":null, "PISTOLA":null, "FUCILE":null}
const WEAPON_NUMBER_TO_NAME = {0:"DISARMATO", 1:"COLTELLO", 2:"PISTOLA", 3:"FUCILE"}
const WEAPON_NAME_TO_NUMBER = {"DISARMATO":0, "COLTELLO":1, "PISTOLA":2, "FUCILE":3}
var changing_weapon = false
var changing_weapon_name = "DISARMATO"

var health = 100

var UI_status_label

const GRAVITY = -24.8
var vel = Vector3()
const MAX_SPEED = 25
const MAX_SPRINT_SPEED = 35
const JUMP_SPEED = 20
const SPRINT_ACCEL = 18
const ACCEL = 4.5
var is_sprinting = false

var flashlight

var dir = Vector3()

const DEACCEL = 16
const MAX_SLOPE_ANGLE = 40

var camera
var rotation_helper

var MOUSE_SENSITIVITY = 0.05

# Chiamato quando il nodo entra nella scena per la prima volta
func _ready():
	
	# Prendo i nodi della camera, del rotation_helper e della torcia e li salvo nelle rispettive variabili
	camera = $Rotation_Helper/Camera
	rotation_helper = $Rotation_Helper
	flashlight = $Rotation_Helper/Flashlight
	animation_manager=$Rotation_Helper/Model/Animation_Player
	animation_manager.callback_function = funcref(self, "fire_bullet")
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	weapons["COLTELLO"] = $Rotation_Helper/Gun_Fire_Points/Knife_Point
	weapons["PISTOLA"] = $Rotation_Helper/Gun_Fire_Points/Pistol_Point
	weapons["FUCILE"] = $Rotation_Helper/Gun_Fire_Points/Rifle_Point
	
	var gun_aim_point_pos = $Rotation_Helper/Gun_Aim_Point.global_transform.origin
	
	for weapon in weapons:
		var weapon_node = weapons[weapon]
		if weapon_node != null:
			weapon_node.player_node = self
			weapon_node.look_at(gun_aim_point_pos, Vector3(0, 1, 0))
			weapon_node.rotate_object_local(Vector3(0, 1, 0), deg2rad(180))
			
	current_weapon_name = "DISARMATO"
	changing_weapon_name = "DISARMATO"
	
	UI_status_label = $HUD/Panel/Gun_label
	
func _physics_process(delta):
	process_input()
	process_movement(delta)
	process_changing_weapons(delta)
	
# Vengono processati gli input
func process_input():
	
	# Movimento base
	dir = Vector3()
	var cam_xform = camera.get_global_transform()
	var input_movement_vector = Vector2()
	
	if Input.is_action_pressed("movimento_avanti"):
		input_movement_vector.y += 1
	if Input.is_action_pressed("movimento_indietro"):
		input_movement_vector.y -= 1
	if Input.is_action_pressed("movimento_destra"):
		input_movement_vector.x += 1
	if Input.is_action_pressed("movimento_sinistra"):
		input_movement_vector.x -= 1
	
	input_movement_vector =input_movement_vector.normalized()
	
	dir += -cam_xform.basis.z.normalized() * input_movement_vector.y
	dir += cam_xform.basis.x.normalized() * input_movement_vector.x
	
	#Cambio arma
	var weapon_change_number = WEAPON_NAME_TO_NUMBER[current_weapon_name]
	
	if Input.is_key_pressed(KEY_1):
		weapon_change_number = 0
	if Input.is_key_pressed(KEY_2):
		weapon_change_number = 1
	if Input.is_key_pressed(KEY_3):
		weapon_change_number = 2
	if Input.is_key_pressed(KEY_4):
		weapon_change_number = 3
	
	if Input.is_action_just_pressed("shift_weapon_positive"):
		weapon_change_number += 1
	if Input.is_action_just_pressed("shift_weapon_negative"):
		weapon_change_number -= 1
		
	weapon_change_number = clamp(weapon_change_number, 0, WEAPON_NUMBER_TO_NAME.size() -1)
	
	if changing_weapon == false:
		if WEAPON_NUMBER_TO_NAME[weapon_change_number] != current_weapon_name:
			changing_weapon_name = WEAPON_NUMBER_TO_NAME[weapon_change_number]
			changing_weapon = true
	
	# Sprint
	if Input.is_action_pressed("movimento_sprint"):
		is_sprinting = true
	else:
		is_sprinting = false
	
	# Salto
	if is_on_floor():
		if Input.is_action_pressed("movimento_salto"):
			vel.y = JUMP_SPEED
	
	# Sparare
	if Input.is_action_pressed("fuoco"):
		if changing_weapon == false:
			var current_weapon = weapons[current_weapon_name]
			if current_weapon != null:
				if animation_manager.current_state == current_weapon.IDLE_ANIM_NAME:
					animation_manager.set_animation(current_weapon.FIRE_ANIM_NAME)
	
	# Torcia
	if Input.is_action_pressed("torcia"):
		if flashlight.is_visible_in_tree():
			flashlight.hide()
		else:
			flashlight.show()
	
	# Catturare/liberare il cursore del mouse
	if Input.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
# Gli input vengono applicati al KinematicBody
func process_movement(delta):
	
	# Normalizzo la direzione per avere consistenza nella velocità (in diagonale il giocatore sarebbe più veloce)
	dir.y = 0
	dir = dir.normalized()
	
	# Aggiungo la gravità alla velocità verticale del giocatore
	vel.y += delta * GRAVITY
	
	var hvel = vel
	hvel.y = 0
	
	# Specifica quanto lontano andrà il giocatore nella direzione dir
	var target = dir
	if is_sprinting:
		target *= MAX_SPRINT_SPEED
	else:
		target *= MAX_SPEED
	
	# Se hvel è nella stessa direzione di dir accelera, altrimenti decelera
	var accel
	if dir.dot(hvel) > 0:
		if is_sprinting:
			accel = SPRINT_ACCEL
		else:
			accel = ACCEL
	else:
		accel = DEACCEL
	
	# Calcola la linea da seguire per spostarsi e si sposta
	hvel = hvel.linear_interpolate(target, accel * delta)
	vel.x = hvel.x
	vel.z = hvel.z
	vel = move_and_slide(vel, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))
	
func process_changing_weapons(delta):
	if changing_weapon == true:
		
		var weapon_unequipped = false
		var current_weapon = weapons[current_weapon_name]
		
		if current_weapon == null:
			weapon_unequipped = true
		else:
			if current_weapon.is_weapon_enabled == true:
				weapon_unequipped = current_weapon.unequip_weapon()
			else:
				weapon_unequipped = true
				
		if weapon_unequipped == true:
			
			var weapon_equipped = false
			var weapon_to_equip = weapons[changing_weapon_name]
			
			if weapon_to_equip == null:
				weapon_equipped = true
			else:
				if weapon_to_equip.is_weapon_enabled == false:
					weapon_equipped = weapon_to_equip.equip_weapon()
				else:
					weapon_equipped = true
					
			if weapon_equipped == true:
				changing_weapon = false
				current_weapon_name = changing_weapon_name
				changing_weapon_name = ""
	
func _input(event):
	
	# Gestione della rotazione del mouse (rotea la camera per le rotazioni verticali e il giocatore per quelle orizzontali)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY))
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
		
		# Restringe la rotazione verticale [-70, 70] per evitare il ribaltamento
		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		rotation_helper.rotation_degrees = camera_rot
		
func fire_bullet():
	if changing_weapon == true:
		return
		
	weapons[current_weapon_name].fire_weapon()
