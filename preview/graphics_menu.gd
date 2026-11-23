extends CanvasLayer

const NAMES := ["Performance", "Balanced", "High"]
const CONFIG := "user://graphics.cfg"
var quality := 2
var restore_capture := false
var saved := ConfigFile.new()
@onready var slider: HSlider = %Quality
@onready var city = get_parent()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	quality = 2 if RenderingServer.get_current_rendering_method()=="forward_plus" else 0
	if saved.load(CONFIG)==OK:
		quality = clampi(int(saved.get_value("video","quality",quality)),0,2)
	slider.value_changed.connect(func(value:float): set_quality(roundi(value)))
	%Resume.pressed.connect(toggle)
	# Winter builds its lighting during the parent scene's ready signal.
	apply_initial_quality.call_deferred()

func apply_initial_quality() -> void:
	set_quality(quality,false)

func set_quality(level: int, persist := true) -> void:
	quality = clampi(level,0,2)
	slider.set_value_no_signal(quality)
	%Preset.text = NAMES[quality]
	city._resize()
	get_viewport().mesh_lod_threshold = [5.,2.5,1.][quality]
	city.block.crowd_range = [32.,74.,145.][quality]
	city.block.refresh_crowd()
	if city.has_node("Winter"):
		city.get_node("Winter").apply_quality(quality)
	if persist:
		saved.set_value("video","quality",quality)
		saved.save(CONFIG)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		toggle()

func _process(_dt: float) -> void:
	if city.web and bool(city.web.midtownSettingsRequested):
		city.web.midtownSettingsRequested = false
		if not visible: toggle()

func toggle() -> void:
	var opening := not visible
	if opening:
		restore_capture = city.mouse_captured()
		city._release()
	if city.web:
		city.web.midtownSetSettingsOpen(opening)
	visible = opening
	get_tree().paused = opening
	if opening:
		slider.grab_focus()
	else:
		city._reset_clock()
		if restore_capture and not city.web:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree() -> void:
	if visible: get_tree().paused = false
