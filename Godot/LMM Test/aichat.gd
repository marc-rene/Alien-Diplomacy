extends Control

@onready var aiText: RichTextLabel = $PanelContainer/VBoxContainer/RichTextLabel
@onready var textEdit: TextEdit = $PanelContainer/VBoxContainer/TextEdit

var aiChat: Node = null


func _ready() -> void:
	if ClassDB.class_exists("NobodyWhoModel") and ClassDB.class_exists("NobodyWhoChat"):
		var model_node: Node = ClassDB.instantiate("NobodyWhoModel")
		model_node.name = "NobodyWhoModel"
		model_node.set("model_path", "gemma-2-2b-it-Q4_K_M.gguf")
		add_child(model_node)

		aiChat = ClassDB.instantiate("NobodyWhoChat")
		aiChat.name = "NobodyWhoChat"
		aiChat.set("system_prompt", "You are a space pirate")
		add_child(aiChat)
		# Set model_node path after both are in the tree
		aiChat.set("model_node", NodePath("../NobodyWhoModel"))

		aiChat.connect("response_updated", _on_nobody_who_chat_response_updated)
		aiChat.connect("response_finished", _on_nobody_who_chat_response_finished)
		print("NobodyWho chat ready")
	else:
		print("NobodyWho not available — chat window showing placeholder")
		aiText.text = "[AI chat not available on this platform]"
		textEdit.editable = false


func ask() -> void:
	if aiChat == null:
		return
	textEdit.editable = false
	aiChat.ask(textEdit.text)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_text_newline"):
		ask()


func _on_nobody_who_chat_response_updated(new_token: String) -> void:
	aiText.text += new_token


func _on_nobody_who_chat_response_finished(_response: String) -> void:
	textEdit.editable = true
	textEdit.text = ""
	print("Ai said: " + _response)
