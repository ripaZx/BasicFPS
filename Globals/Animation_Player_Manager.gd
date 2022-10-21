extends AnimationPlayer

# Macchina degli stati; struttura -> Nome dell'animazione: [Stati d'animazione collegati]
var states = {
	"Idle_unarmed":["Knife_equip", "Pistol_equip", "Rifle_equip", "Idle_unarmed"],
	
	"Pistol_equip":["Pistol_idle"],
	"Pistol_fire":["Pistol_idle"],
	"Pistol_idle":["Pistol_fire", "Pistol_reload", "Pistol_unequip", "Pistol_idle"],
	"Pistol_reload":["Pistol_idle"],
	"Pistol_unequip":["Idle_unarmed"],
	
	"Rifle_equip":["Rifle_idle"],
	"Rifle_fire":["Rifle_idle"],
	"Rifle_idle":["Rifle_fire", "Rifle_reload", "Rifle_unequip", "Rifle_idle"],
	"Rifle_reload":["Rifle_idle"],
	"Rifle_unequip":["Idle_unarmed"],
	
	"Knife_equip":["Knife_idle"],
	"Knife_fire":["Knife_idle"],
	"Knife_idle":["Knife_fire", "Knife_unequip", "Knife_idle"],
	"Knife_unequip":["Idle_unarmed"],
}

var animation_speeds = {
	"Idle_unarmed": 1,
	"Pistol_equip":1.4,
	"Pistol_fire":1.8,
	"Pistol_idle":1,
	"Pistol_reload":1,
	"Pistol_unequip":1.4,
	
	"Rifle_equip":2,
	"Rifle_fire":6,
	"Rifle_idle":1,
	"Rifle_reload":1.45,
	"Rifle_unequip":2,
	
	"Knife_equip":1,
	"Knife_fire":1.35,
	"Knife_idle":1,
	"Knife_unequip":1,
}

var current_state = null
var callback_function = null

func _ready():
	set_animation("Idle_unarmed")
	connect("animation_finished", self, "animation_ended")
	
func set_animation(animation_name):
	if animation_name == current_state:
		print ("Animation_Player_Manager.gf -- WARNING: l'animazione è già ", animation_name)
		return true
	
	if has_animation(animation_name):
		if current_state != null:
			var possible_animations = states[current_state]
			if animation_name in possible_animations:
				current_state = animation_name
				play(animation_name, -1, animation_speeds[animation_name])
				return true
			else:
				print ("Animation_Player_Manager.gf -- WARNING: non posso passare a ", animation_name, " da ", current_state)
		else:
			current_state = animation_name
			play(animation_name, -1, animation_speeds[animation_name])
			return true
	return false
	
func animation_ended(anim_name):
	
	# Transizioni DISARMATO
	if current_state == "Idle_unarmed":
		pass
		
	# Transizioni COLTELLO
	elif current_state == "Knife_equip":
		set_animation("Knife_idle")
	elif current_state == "Knife_idle":
		pass
	elif current_state == "Knife_fire":
		set_animation("Knife_idle")
	elif current_state == "Knife_unequip":
		set_animation("Idle_unarmed")
		
	# Transizioni PISTOLA
	elif current_state == "Pistol_equip":
		set_animation("Pistol_idle")
	elif current_state == "Pistol_idle":
		pass
	elif current_state == "Pistol_fire":
		set_animation("Pistol_idle")
	elif current_state == "Pistol_unequip":
		set_animation("Idle_unarmed")
	elif current_state == "Pistol_reload":
		set_animation("Pistol_idle")
	
	# Transizioni FUCILE
	elif current_state == "Rifle_equip":
		set_animation("Rifle_idle")
	elif current_state == "Rifle_idle":
		pass
	elif current_state == "Rifle_fire":
		set_animation("Rifle_idle")
	elif current_state == "Rifle_unequip":
		set_animation("Idle_unarmed")
	elif current_state == "Rifle_reload":
		set_animation("Rifle_idle")
		
func animation_callback():
	if callback_function == null:
		print ("Animation_Player_Manager.gd -- WARNING: Non c'è una funzione callback da far chiamare all'animazione!")
	else:
		callback_function.call_func()
