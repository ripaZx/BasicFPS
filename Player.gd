extends KinematicBody

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
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	
func _physics_process(delta):
	process_input()
	process_movement(delta)
	
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
	
	# Sprint
	if Input.is_action_pressed("movimento_sprint"):
		is_sprinting = true
	else:
		is_sprinting = false
	
	# Salto
	if is_on_floor():
		if Input.is_action_pressed("movimento_salto"):
			vel.y = JUMP_SPEED
	
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
	
func _input(event):
	
	# Gestione della rotazione del mouse (rotea la camera per le rotazioni verticali e il giocatore per quelle orizzontali)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY))
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
		
		# Restringe la rotazione verticale [-70, 70] per evitare il ribaltamento
		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		rotation_helper.rotation_degrees = camera_rot