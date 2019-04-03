extends Spatial

var audio_node = null
var should_loop = false
var globals = null

func _ready():
	audio_node = $Audio_Stream_Player
	audio_node.connect("finished", self, "sound_finished")
	audio_node.stop()
	
	globals = get_node("/root/Globals")
	
func play_sound(audio_stream, position = null):
	if audio_stream == null:
		print("Non è stato passato un flusso audio; impossibile riprodurre suono")
		globals.created_audio.remove(globals.created_auidio.find(self))
		queue_free()
		return
		
	audio_node.stream = audio_stream
	audio_node.play(0.0)
	
func sound_finished():
	if should_loop:
		audio_node.play(0.0)
	else:
		globals.created_audio.remove(globals.created_audio.find(self))
		audio_node.stop()
		queue_free()