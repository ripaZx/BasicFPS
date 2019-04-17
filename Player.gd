extends KinematicBody

var animation_manager

# HP e respawn
const RESPAWN_TIME = 4
var dead_time = 0
var is_dead = false
const MAX_HEALTH = 150
var health = 100

var globals

# Armi
var current_weapon_name = "DISARMATO"
var weapons = {"DISARMATO":null, "COLTELLO":null, "PISTOLA":null, "FUCILE":null}
const WEAPON_NUMBER_TO_NAME = {0:"DISARMATO", 1:"COLTELLO", 2:"PISTOLA", 3:"FUCILE"}
const WEAPON_NAME_TO_NUMBER = {"DISARMATO":0, "COLTELLO":1, "PISTOLA":2, "FUCILE":3}
var changing_weapon = false
var changing_weapon_name = "DISARMATO"
var reloading_weapon = false

# Granate
var grenade_amounts = {"Grenade":2, "Sticky Grenade": 2}
const MAX_GRENADE = 5
var current_grenade = "Grenade"
var grenade_scene = preload("res://Grenade.tscn")
var sticky_grenade_scene = preload("res://Sticky_Grenade.tscn")
const GRENADE_THROW_FORCE = 50

# Acchiappa oggetti
var grabbed_object = null
const OBJECT_THROW_FORCE = 520
const OBJECT_GRAB_DISTANCE = 8
const OBJECT_GRAB_RAY_DISTANCE = 10

var UI_status_label

# Movimento e fisica 
const GRAVITY = -24.8
var vel = Vector3()
const MAX_SPEED = 30
const MAX_SPRINT_SPEED = 45
const JUMP_SPEED = 20
const SPRINT_ACCEL = 18
const ACCEL = 4.5
var is_sprinting = false

var flashlight

var dir = Vector3()
var jump_dir = Vector3()

const DEACCEL = 16
const MAX_SLOPE_ANGLE = 40

var camera
var rotation_helper

# Inputs
var mouse_scroll_value = 0
const MOUSE_SENSITIVITY_SCROLL_WHEEL = 0.08
var JOYPAD_SENSITIVITY = 2
const JOYPAD_DEADZONE = 0.15
var MOUSE_SENSITIVITY = 0.05

# Chiamato quando il nodo entra nella scena per la prima volta
func _ready():
	
	globals = get_node("/root/Globals")
	global_transform.origin = globals.get_respawn_position()
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
	
	if !is_dead:
		process_input()
		process_view_input(delta)
		process_movement(delta)
		
	if grabbed_object == null:
		process_changing_weapons(delta)
		process_reloading(delta)
	
	process_UI(delta)
	process_respawn(delta)
	
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
	
	if Input.get_connected_joypads().size() > 0:
		var joypad_vec = Vector2(0, 0)
		
		if OS.get_name() == "Windows":
			joypad_vec = Vector2(Input.get_joy_axis(0, 0), -Input.get_joy_axis(0, 1))
		elif OS.get_name() == "X11":
			joypad_vec = Vector2(Input.get_joy_axis(0, 1), Input.get_joy_axis(0, 2))
		elif OS.get_name() == "OSX":
			joypad_vec = Vector2(Input.get_joy_axis(0, 1), -Input.get_joy_axis(0, 2))
			
		if joypad_vec.length() < JOYPAD_DEADZONE:
			joypad_vec = Vector2(0, 0)
		else:
			joypad_vec = joypad_vec.normalized() * ((joypad_vec.length() - JOYPAD_DEADZONE) / (1 - JOYPAD_DEADZONE))
		
		input_movement_vector += joypad_vec
		
	input_movement_vector = input_movement_vector.normalized()
	
	dir += -cam_xform.basis.z.normalized() * input_movement_vector.y
	dir += cam_xform.basis.x.normalized() * input_movement_vector.x
	
	# Normalizzo la direzione per avere consistenza nella velocità (in diagonale il giocatore sarebbe più veloce)
	dir.y = 0
	dir = dir.normalized()
	
	if is_on_floor():
		jump_dir = dir
	
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
		if reloading_weapon == false:
			if WEAPON_NUMBER_TO_NAME[weapon_change_number] != current_weapon_name:
				changing_weapon_name = WEAPON_NUMBER_TO_NAME[weapon_change_number]
				changing_weapon = true
				
	mouse_scroll_value = weapon_change_number
	
	# Ricarica
	if reloading_weapon == false:
		if changing_weapon == false:
			if Input.is_action_pressed("ricarica"):
				var current_weapon = weapons[current_weapon_name]
				if current_weapon != null:
					if current_weapon.CAN_RELOAD == true:
						var current_anim_state = animation_manager.current_state
						var is_reloading = false
						for weapon in weapons:
							var weapon_node = weapons[weapon]
							if weapon_node != null:
								if current_anim_state == weapon_node.RELOADING_ANIM_NAME:
									is_reloading = true
						if is_reloading == false:
							reloading_weapon = true
	
	# Prendere e tirare oggetti
	if Input.is_action_just_pressed("fuoco") and current_weapon_name == "DISARMATO":
		if grabbed_object == null:
			var state = get_world().direct_space_state
			
			var center_position = get_viewport().size / 2
			var ray_from = camera.project_ray_origin(center_position)
			var ray_to = ray_from + camera.project_ray_normal(center_position) * OBJECT_GRAB_RAY_DISTANCE
			
			var ray_result = state.intersect_ray(ray_from, ray_to, [self, $Rotation_Helper/Gun_Fire_Points/Knife_Point/Area])
			if !ray_result.empty():
				if ray_result["collider"] is RigidBody:
					grabbed_object = ray_result["collider"]
					grabbed_object.mode = RigidBody.MODE_STATIC
					
					grabbed_object.collision_layer = 0
					grabbed_object.collision_mask = 0
					
		else:
			grabbed_object.mode = RigidBody.MODE_RIGID
			
			grabbed_object.apply_impulse(Vector3(0, 0, 0), -camera.global_transform.basis.z.normalized() * OBJECT_THROW_FORCE)
			
			grabbed_object.collision_layer = 1
			grabbed_object.collision_mask = 1
			
			grabbed_object = null
		
	if grabbed_object != null:
		grabbed_object.global_transform.origin = camera.global_transform.origin + ( -camera.global_transform.basis.z.normalized() * OBJECT_GRAB_DISTANCE)
		
	# Sprint
	if Input.is_action_pressed("movimento_sprint"):
		is_sprinting = true
	else:
		is_sprinting = false
		
	# Melee
	if Input.is_action_just_pressed("melee"):
		var state = get_world().direct_space_state
		
		var center_position = get_viewport().size / 2
		var ray_from = camera.project_ray_origin(center_position)
		var ray_to = ray_from + camera.project_ray_normal(center_position) * OBJECT_GRAB_RAY_DISTANCE
		
		var ray_result = state.intersect_ray(ray_from, ray_to, [self, $Rotation_Helper/Gun_Fire_Points/Knife_Point/Area])
		if !ray_result.empty():
			if ray_result["collider"] is RigidBody:
				ray_result["collider"].apply_impulse(ray_result["normal"], -camera.global_transform.basis.z.normalized() * OBJECT_THROW_FORCE)
			elif ray_result["collider"] is StaticBody || ray_result["collider"] is GridMap:
				if is_on_floor():
					dir += camera.global_transform.basis.z.normalized() * OBJECT_THROW_FORCE / 20
				else:
					jump_dir += camera.global_transform.basis.z.normalized() * OBJECT_THROW_FORCE / 300
			else:
				return
				
	# Salto
	if is_on_floor():
		if Input.is_action_pressed("movimento_salto"):
			vel.y = JUMP_SPEED
	
	# Sparare
	if Input.is_action_pressed("fuoco"):
		if reloading_weapon == false:
			if changing_weapon == false:
				var current_weapon = weapons[current_weapon_name]
				if current_weapon != null:
					if current_weapon.ammo_in_weapon > 0:
						if animation_manager.current_state == current_weapon.IDLE_ANIM_NAME:
							animation_manager.set_animation(current_weapon.FIRE_ANIM_NAME)
	
	# Cambio granate e lancio
	if Input.is_action_just_pressed("cambio_granata"):
		if current_grenade == "Grenade":
			current_grenade = "Sticky Grenade"
		elif current_grenade == "Sticky Grenade":
			current_grenade = "Grenade"
		
	if Input.is_action_just_pressed("lancio_granata"):
		if grenade_amounts[current_grenade] > 0:
			grenade_amounts[current_grenade] -= 1
			
			var grenade_clone
			if current_grenade == "Grenade":
				grenade_clone = grenade_scene.instance()
			elif current_grenade == "Sticky Grenade":
				grenade_clone = sticky_grenade_scene.instance()
				grenade_clone.player_body = self
			
			get_tree().root.add_child(grenade_clone)
			grenade_clone.global_transform = $Rotation_Helper/Grenade_Toss_Pos.global_transform
			grenade_clone.apply_impulse(Vector3(0, 0, 0), grenade_clone.global_transform.basis.z * GRENADE_THROW_FORCE)
			
	# Torcia
	if Input.is_action_pressed("torcia"):
		if flashlight.is_visible_in_tree():
			flashlight.hide()
		else:
			flashlight.show()
	
	# Catturare/liberare il cursore del mouse
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func process_view_input(delta):
	
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	
	var joypad_vec = Vector2()
	if Input.get_connected_joypads().size() > 0:
		
		if OS.get_name() == "Windows":
			joypad_vec = Vector2(Input.get_joy_axis(0, 2), Input.get_joy_axis(0, 3))
		elif OS.get_name() == "X11":
			joypad_vec = Vector2(Input.get_joy_axis(0, 3), Input.get_joy_axis(0, 4))
		elif OS.get_name() == "OSX":
			joypad_vec = Vector2(Input.get_joy_axis(0, 3), Input.get_joy_axis(0, 4))
		
		if joypad_vec.length() < JOYPAD_DEADZONE:
			joypad_vec = Vector2(0, 0)
		else:
			joypad_vec = joypad_vec.normalized() * ((joypad_vec.length() - JOYPAD_DEADZONE) / (1 - JOYPAD_DEADZONE))
		
		rotation_helper.rotate_x(deg2rad(joypad_vec.y * JOYPAD_SENSITIVITY))
		
		rotate_y(deg2rad(joypad_vec.x * JOYPAD_SENSITIVITY * -1))
		
		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		rotation_helper.rotation_degrees = camera_rot
		
# Gli input vengono applicati al KinematicBody
func process_movement(delta):
	
	# Aggiungo la gravità alla velocità verticale del giocatore
	vel.y += delta * GRAVITY
	
	var hvel = vel
	hvel.y = 0
	
	# Specifica quanto lontano andrà il giocatore nella direzione dir
	var target
	if is_on_floor():
		target = dir
	else:
		target = jump_dir
	
	if is_sprinting:
		target *= MAX_SPRINT_SPEED
	else:
		target *= MAX_SPEED
	
	# Se hvel è nella stessa direzione di dir accelera, altrimenti decelera
	var accel
	if target.dot(hvel) > 0:
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
	
func process_reloading(delta):
	if reloading_weapon == true:
		var current_weapon = weapons[current_weapon_name]
		if current_weapon != null:
			current_weapon.reload_weapon()
		reloading_weapon = false
	
func process_UI(delta):
	if current_weapon_name == "DISARMATO" or current_weapon_name == "COLTELLO":
		UI_status_label.text = "VITA: " + str(health)
	else:
		var current_weapon = weapons[current_weapon_name]
		UI_status_label.text = "VITA: " + str(health) + \
		"\nAMMO: " + str(current_weapon.ammo_in_weapon) + "/" + str(current_weapon.spare_ammo) + \
		"\n" + current_grenade + ": " + str(grenade_amounts[current_grenade])
	
func process_respawn(delta):
	if health <= 0 and !is_dead:
		$Body_CollisionShape.disabled = true
		$Feet_CollisionShape.disabled = true
		
		changing_weapon = true
		changing_weapon_name = "DISARMATO"
		
		$HUD/Death_Screen.visible = true
		
		$HUD/Panel.visible = false
		$HUD/Crosshair.visible = false
		
		dead_time = RESPAWN_TIME
		is_dead = true
		
		if grabbed_object != null:
			grabbed_object.mode = RigidBody.MODE_RIGID
			grabbed_object.apply_impulse(Vector3(0, 0, 0), -camera.global_transform.basis.z.normalized() * OBJECT_THROW_FORCE / 2)
			
			grabbed_object.collision_layer = 1
			grabbed_object.collision_mask = 1
			
			grabbed_object = null
			
	if is_dead:
		dead_time -= delta
		
		var dead_time_pretty = str(dead_time).left(3)
		$HUD/Death_Screen/Label.text = "Sei morto\n" + dead_time_pretty + " secondi per il respawn"
		
		if dead_time <= 0:
			global_transform.origin = globals.get_respawn_position()
			
			$Body_CollisionShape.disabled = false
			$Feet_CollisionShape.disabled = false
			
			$HUD/Death_Screen.visible = false
			
			$HUD/Panel.visible = true
			$HUD/Crosshair.visible = true
			
			for weapon in weapons:
				var weapon_node = weapons[weapon]
				if weapon_node != null:
					weapon_node.reset_weapon()
					
			health = 100
			grenade_amounts = {"Grenade":2, "Sticky Grenade":2}
			current_grenade = "Grenade"
			
			is_dead = false
	
func _input(event):
	
	if is_dead:
		return
		
	if event is InputEventMouseButton and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN:
			if event.button_index == BUTTON_WHEEL_UP:
				mouse_scroll_value += MOUSE_SENSITIVITY_SCROLL_WHEEL
			elif event.button_index == BUTTON_WHEEL_DOWN:
				mouse_scroll_value -= MOUSE_SENSITIVITY_SCROLL_WHEEL
				
			mouse_scroll_value = clamp(mouse_scroll_value, 0, WEAPON_NUMBER_TO_NAME.size() -1)
			
			if changing_weapon == false:
				if reloading_weapon == false:
					var round_mouse_scroll_value = int(round(mouse_scroll_value))
					if WEAPON_NUMBER_TO_NAME[round_mouse_scroll_value] != current_weapon_name:
						changing_weapon_name = WEAPON_NUMBER_TO_NAME[round_mouse_scroll_value]
						changing_weapon = true
						mouse_scroll_value = round_mouse_scroll_value
	
	# Gestione della rotazione del mouse (rotea la camera per le rotazioni verticali e il giocatore per quelle orizzontali)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY))
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
		
		# Restringe la rotazione verticale [-70, 70] per evitare il ribaltamento
		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		rotation_helper.rotation_degrees = camera_rot
	
func bullet_hit(damage, bullet_hit_pos):
	health -= damage
	
func add_health(additional_health):
	health += additional_health
	health = clamp(health, 0, MAX_HEALTH)
	
func add_ammo(additional_ammo):
	if (current_weapon_name != "DISARMATO"):
		if (weapons[current_weapon_name].CAN_REFILL == true):
			weapons[current_weapon_name].spare_ammo += weapons[current_weapon_name].AMMO_IN_MAG * additional_ammo
	
func add_grenade(additional_grenade):
	grenade_amounts[current_grenade] += additional_grenade
	grenade_amounts[current_grenade] = clamp(grenade_amounts[current_grenade], 0, MAX_GRENADE)
	
func fire_bullet():
	if changing_weapon == true:
		return
		
	weapons[current_weapon_name].fire_weapon()
	
func create_sound(sound_name, position = null):
	globals.play_sound(sound_name, false, position)