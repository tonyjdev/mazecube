class_name Benchmark
extends Node
## Banco de pruebas de rendimiento (solo en builds de depuración).
##
## Si existe user://benchmark.txt, el menú lo lanza al arrancar (ver
## maybe_start): el archivo tiene los números de nivel (desde 1) separados
## por espacios. Para cada nivel abre la partida, deja que el cubo ruede y
## mide los fotogramas por segundo en varios escenarios, desactivando cosas
## una a una para ver cuánto cuesta cada una. Los resultados se escriben en
## el log (líneas «BENCH», ver `adb logcat -s godot`) y en
## user://benchmark_result.txt; al acabar cierra el juego.
##
## En el móvil (build de depuración):
##   adb shell "run-as com.tonyjdev.mazecube sh -c 'echo 115 1 > files/benchmark.txt'"
##   adb shell am start -n com.tonyjdev.mazecube/com.godot.game.GodotApp
##   adb shell "run-as com.tonyjdev.mazecube cat files/benchmark_result.txt"

const REQUEST := "user://benchmark.txt"
const RESULT := "user://benchmark_result.txt"
## Espera tras cargar el nivel (aparición del tablero y del cubo) y duración
## de cada medida.
const SETTLE_TIME := 6.0
const SAMPLE_TIME := 5.0

var _levels: Array[int] = []
## Modo «frames»: juega cada nivel FRAMES_TIME segundos y apunta los
## fotogramas lentos (más de SLOW_FRAME_MS) con los disparos y explosiones.
var _frames_mode := false
const FRAMES_TIME := 40.0
const SLOW_FRAME_MS := 25.0
var _lines: PackedStringArray = []


static func maybe_start(tree: SceneTree) -> bool:
	if not OS.is_debug_build() or not FileAccess.file_exists(REQUEST):
		return false
	if tree.root.has_node("Benchmark"):
		return true
	var bench := Benchmark.new()
	bench.name = "Benchmark"
	for word in FileAccess.get_file_as_string(REQUEST).split(" ", false):
		if word.strip_edges() == "frames":
			bench._frames_mode = true
		elif word.strip_edges().is_valid_int():
			bench._levels.append(int(word.strip_edges()))
	tree.root.add_child.call_deferred(bench)
	return true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_log("dispositivo %s, %s, ventana %s, fps máx %d" % [OS.get_model_name(),
		RenderingServer.get_video_adapter_name(), get_viewport().get_visible_rect().size,
		DisplayServer.screen_get_refresh_rate()])
	for level in _levels:
		await _bench_level(level)
	var file := FileAccess.open(RESULT, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(_lines) + "\n")
	_log("FIN")
	get_tree().quit()


func _bench_level(number: int) -> void:
	GameState.play_level(number - 1)
	await _wait(1.0)
	while GameState.is_loading:
		# La pantalla de carga espera a que se pulse Continuar.
		for node in get_tree().root.get_children():
			if node is LoadingScreen and node._continue_button.visible:
				node._continue_button.pressed.emit()
		await get_tree().process_frame
	await _wait(SETTLE_TIME)
	var game := get_tree().current_scene
	var level: Level = game.get_node("Level")
	if _frames_mode:
		await _log_slow_frames(number, level)
		return
	var cube: RollingCube = game.get_node("Cube")
	var sun: DirectionalLight3D = game.get_node("Sun")
	var viewport := get_viewport()
	# El cubo se queda quieto (la cámara lo sigue igual): así no muere ni
	# llega a la meta durante la medida.
	cube.set_process(false)
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	_log("renderizador %s, MSAA %d" % [RenderingServer.get_current_rendering_method(), viewport.msaa_3d])
	_log("nivel %d: %d nodos, pantalla %s, interfaz %s" % [number, game.get_tree().get_node_count(),
		DisplayServer.window_get_size(), viewport.get_visible_rect().size])
	# Combinaciones de ajustes: cada una se aplica, se mide y se deshace.
	var shadow_quality: int = ProjectSettings.get_setting(
		"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile")
	var camera: Node = game.get_node("Camera3D")
	var atlas: int = ProjectSettings.get_setting_with_override(
		"rendering/lights_and_shadows/directional_shadow/size")
	var scale := viewport.scaling_3d_scale
	var setups := [
		["normal", {}],
		["sin MSAA", {"msaa": false}],
		["3D al 100 %", {"scale": 1.0}],
		["3D al 100 % + sombra 4096", {"scale": 1.0, "atlas": 4096}],
		["sin sombras", {"shadows": false}],
		["sin 3D ni UI", {"no3d": true, "ui": false}],
		["normal (otra vez)", {}],
	]
	for setup: Array in setups:
		var o: Dictionary = setup[1]
		viewport.scaling_3d_scale = o.get("scale", scale)
		RenderingServer.directional_shadow_atlas_set_size(o.get("atlas", atlas), true)
		RenderingServer.directional_soft_shadow_filter_set_quality(o.get("quality", shadow_quality))
		sun.directional_shadow_max_distance = o.get("distance", 40.0)
		sun.shadow_enabled = o.get("shadows", GameState.shadows)
		game.get_node("UI").visible = o.get("ui", true)
		level.visible = not o.get("hide", false)
		cube.visible = not o.get("hide", false)
		viewport.disable_3d = o.get("no3d", false)
		viewport.msaa_3d = Viewport.MSAA_4X if o.get("msaa", GameState.antialiasing) else Viewport.MSAA_DISABLED
		get_tree().paused = o.get("pause", false)
		level.set_process(o.get("level", true))
		camera.set_process(o.get("camera", true))
		game.set_process(o.get("game", true))
		await _sample(setup[0])
	cube.set_process(true)


func _log_slow_frames(number: int, level: Level) -> void:
	_log("nivel %d: fotogramas lentos durante %d s" % [number, FRAMES_TIME])
	var start := Time.get_ticks_usec()
	var last := start
	var bombs := 0
	var lasers := 0
	var frames := 0
	var slow := 0
	while last - start < int(FRAMES_TIME * 1000000.0):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var t := (now - start) / 1000000.0
		frames += 1
		if level._bombs.size() > bombs:
			_log("  %5.1f s  dispara bomba" % t)
		elif level._bombs.size() < bombs:
			_log("  %5.1f s  explota bomba" % t)
		if level._lasers.size() > lasers:
			_log("  %5.1f s  dispara láser" % t)
		bombs = level._bombs.size()
		lasers = level._lasers.size()
		var ms := (now - last) / 1000.0
		if ms > SLOW_FRAME_MS:
			slow += 1
			_log("  %5.1f s  fotograma lento: %.0f ms" % [t, ms])
		last = now
	_log("  %d fotogramas, %.1f fps de media, %d lentos" % [frames, frames / FRAMES_TIME, slow])


func _sample(label: String) -> void:
	await _wait(0.5)
	var rid := get_viewport().get_viewport_rid()
	var frames := 0
	var worst := 0.0
	var start := Time.get_ticks_usec()
	var last := start
	var end := start + int(SAMPLE_TIME * 1000000.0)
	var draws := 0.0
	var prims := 0.0
	var cpu := 0.0
	var gpu := 0.0
	while last < end:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid) \
			+ RenderingServer.get_frame_setup_time_cpu()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var ms := (last - start) / 1000.0 / frames
	_log("  %-22s %5.1f fps %5.1f ms/f peor %5.1f | render CPU %4.1f GPU %5.1f ms | draws %4d tris %4dk" % [
		label, 1000.0 / ms, ms, worst, cpu / frames, gpu / frames, draws / frames, prims / frames / 1000.0])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _log(text: String) -> void:
	_lines.append(text)
	print("BENCH ", text)
