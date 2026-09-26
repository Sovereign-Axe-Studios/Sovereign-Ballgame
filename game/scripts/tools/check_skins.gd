extends Node
## Headless smoke check for skins:
##   godot --headless --path . scenes/tools/check_skins.tscn
## Draws every ball look (spin/t at 0 and 1.5) and runs every animated
## background for ~2 s, firing board-cleared and new-ball halfway. A broken
## skin shows up as a SCRIPT ERROR above its line.

func _ready() -> void:
	var canvas := Control.new()
	canvas.size = Vector2(200, 200)
	add_child(canvas)
	for look: BallLook in Skins.ball_skins:
		for t in [0.0, 1.5]:
			canvas.draw.connect(func() -> void: look.draw(canvas, Vector2(100, 100), 40.0, t * 3.0, t), CONNECT_ONE_SHOT)
			canvas.queue_redraw()
			await get_tree().process_frame
		print("  ok    ball        %s%s" % [look.skin_name, "  [locked]" if look.locked_by != &"" else ""])
	for skin in Skins.background_skins:
		if skin.scene == null:
			continue
		var bg := skin.scene.new() as AnimatedBackground
		add_child(bg)
		for i in range(120):
			if i == 60:
				bg.on_board_cleared(Vector2(540, 800))
				bg.on_new_ball(Vector2(300, 1500))
			await get_tree().process_frame
		bg.queue_free()
		print("  ok    background  %s" % skin.skin_name)
	print("%d ball looks, %d backgrounds" % [Skins.ball_skins.size(), Skins.background_skins.size()])
	get_tree().quit()
