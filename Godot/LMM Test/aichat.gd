extends Control

@onready var aiText = $PanelContainer/VBoxContainer/RichTextLabel
@onready var textEdit = $PanelContainer/VBoxContainer/TextEdit
@onready var aiChat = $NobodyWhoChat

func ask():
	textEdit.editable = false
	aiChat.ask(textEdit.text)
	
func _input(event:InputEvent) -> void:
		if(event.is_action_pressed("ui_text_newline")):
			ask()

func _on_nobody_who_chat_response_updated(new_token: String) -> void:
		aiText.text += new_token

func _on_nobody_who_chat_response_finished(_response:String) -> void:
	textEdit.editable = true
	textEdit.text = ""
