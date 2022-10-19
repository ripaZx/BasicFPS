extends Node

var mouse_sensitivity = 0.98
var joypad_sensitivity = 2

var audio_clips = {
	"Pistol_shot": preload("res://assets/Audio/pistol_shot.wav"),
	"Rifle_shot": preload("res://assets/Audio/rifle_shot.wav"),
	"Gun_cock": preload("res://assets/Audio/gun_cock.wav")
}

const SIMPLE_AUDIO_PLAYER_SCENE = preload("res://Scenes/Simple_Audio_Player.tscn")
var created_audio = []

var respawn_points = null

const MAIN_MENU_PATH = "res://Scenes/Main_Menu.tscn"
const POPUP_SCENE = preload("res://Scenes/Pause_Popup.tscn")
var popup = null

var canvas_layer = null

const DEBUG_DISPLAY_SCENE = preload("res://Scenes/Debug_Display.tscn")
var debug_display = null

func _ready():
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	randomize()
	
func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if popup == null:
			popup = POPUP_SCENE.instance()
			
			popup.get_node("Button_quit").connect("pressed", self, "popup_quit")
			popup.connect("popup_hide", self, "popup_closed")
			popup.get_node("Button_resume").connect("pressed", self, "popup_closed")
			
			canvas_layer.add_child(popup)
			popup.popup_centered()
			
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
			get_tree().paused = true
			
func load_new_scene(new_scene_path):
	get_tree().change_scene(new_scene_path)
	respawn_points = null
	
	for sound in created_audio:
		if (sound != null):
			sound.queue_free()
	created_audio.clear()
	
func set_debug_display(display_on):
	if !display_on and debug_display != null:
		debug_display.queue_free()
		debug_display = null
	elif debug_display == null:
		debug_display = DEBUG_DISPLAY_SCENE.instance()
		canvas_layer.add_child(debug_display)
	
func popup_closed():
	get_tree().paused = false
	
	if popup != null:
		popup.queue_free()
		popup = null
	
func popup_quit():
	get_tree().paused = false
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if popup != null:
		popup.queue_free()
		popup = null
	
	load_new_scene(MAIN_MENU_PATH)
	
func get_respawn_position():
	if respawn_points == null:
		return Vector3(0, 0, 0)
	else:
		var respawn_point = rand_range(0, respawn_points.size() -1)
		return respawn_points[respawn_point].global_transform.origin
	
func play_sound(sound_name, loop_sound = false, sound_position = null):
	if audio_clips.has(sound_name):
		var new_audio = SIMPLE_AUDIO_PLAYER_SCENE.instance()
		new_audio.should_loop = loop_sound
		
		add_child(new_audio)
		created_audio.append(new_audio)
		
		new_audio.play_sound(audio_clips[sound_name], sound_position)
	else:
		print("ERRORE: non è possibile riprodurre audio non incluso in audio_clips!")
