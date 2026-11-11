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
## Modo «sky»: solo las variantes del fondo y la luz ambiente, con capturas
## (user://shot_<nivel>_<n>.png) para comparar el aspecto.
var _sky_mode := false
## Modo «matte»: brillo especular desactivado en los materiales mates o en
## todos, con capturas.
var _matte_mode := false
## Modo «repeat»: la misma medida varias veces sin tocar nada.
var _repeat_mode := false
## Modo «map»: abre la pausa y guarda capturas del mapa 2D
## (user://map_<nivel>_<n>.png): al abrir, con la leyenda, acercado y
## centrado en el cubo.
var _map_mode := false
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
		elif word.strip_edges() == "sky":
			bench._sky_mode = true
		elif word.strip_edges() == "matte":
			bench._matte_mode = true
		elif word.strip_edges() == "repeat":
			bench._repeat_mode = true
		elif word.strip_edges() == "map":
			bench._map_mode = true
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
	if _map_mode:
		await _map_shots(number, game)
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
	var env: Environment = game.get_node("WorldEnvironment").environment
	var bg := env.background_mode
	var bg_color := env.background_color
	var refl := env.reflected_light_source
	var radiance := env.sky.radiance_size
	var ambient := env.ambient_light_source
	var tonemap := env.tonemap_mode
	var setups := [
		["normal (3D al 75 %)", {"scale": 0.75}],
		["3D al 67 %", {"scale": 0.67}],
		["3D al 60 %", {"scale": 0.6}],
		["BASE: 3D al 100 %", {}],
		["sin MSAA", {"msaa": false}],
		["sin sombras", {"shadows": false}],
		["fondo de color (sin cielo)", {"sky": false}],
		["sin tonemap", {"tonemap": false}],
		["luz por vértice", {"shading": BaseMaterial3D.SHADING_MODE_PER_VERTEX}],
		["sin iluminación", {"shading": BaseMaterial3D.SHADING_MODE_UNSHADED}],
		["sin transparentes", {"no_alpha": true}],
		["solo terreno", {"terrain_only": true}],
		["sin UI", {"ui": false}],
		["cielo+vértice+sin MSAA", {"sky": false, "msaa": false,
			"shading": BaseMaterial3D.SHADING_MODE_PER_VERTEX}],
		["sin 3D ni UI", {"no3d": true, "ui": false}],
		["base 100 % (otra vez)", {}],
	]
	if _sky_mode:
		setups = [
			["actual", {"shot": true}],
			["reflejos de 64", {"radiance": Sky.RADIANCE_SIZE_64}],
			["reflejos de 32", {"radiance": Sky.RADIANCE_SIZE_32, "shot": true}],
			["sin reflejos del cielo", {"refl": false}],
			["actual (otra vez)", {}],
		]
	if _matte_mode:
		setups = [
			["actual", {"shot": true}],
			["mates sin especular", {"specular": "matte", "shot": true}],
			["todos sin especular", {"specular": "all", "shot": true}],
			["actual (otra vez)", {}],
		]
	if _repeat_mode:
		setups = [["actual 1", {}], ["actual 2", {}], ["actual 3", {}], ["actual 4", {}]]
	var shot := 0
	var materials := _materials(game)
	# Sin vsync para ver cuánto margen hay por encima de 60 fps.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for setup: Array in setups:
		var o: Dictionary = setup[1]
		# Base al 100 % para que la GPU no llegue a 60 fps y se vea lo que
		# ahorra cada cambio (Android no deja quitar la vsync).
		viewport.scaling_3d_scale = o.get("scale", 1.0)
		RenderingServer.directional_shadow_atlas_set_size(o.get("atlas", atlas), true)
		RenderingServer.directional_soft_shadow_filter_set_quality(o.get("quality", shadow_quality))
		sun.directional_shadow_max_distance = o.get("distance", 40.0)
		sun.shadow_enabled = o.get("shadows", GameState.shadows)
		game.get_node("UI").visible = o.get("ui", true)
		viewport.disable_3d = o.get("no3d", false)
		viewport.msaa_3d = Viewport.MSAA_4X if o.get("msaa", GameState.antialiasing) else Viewport.MSAA_DISABLED
		var sky: bool = o.get("sky", true)
		env.background_mode = Environment.BG_SKY if o.get("sky_bg", false) \
			else bg if sky else Environment.BG_COLOR
		env.background_color = bg_color
		env.reflected_light_source = refl if o.get("refl", true) else Environment.REFLECTION_SOURCE_BG
		if env.sky.radiance_size != o.get("radiance", radiance):
			env.sky.radiance_size = o.get("radiance", radiance)
			await _wait(1.0)
		env.ambient_light_source = ambient if sky and o.get("amb", true) else Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.5, 0.55, 0.62)
		env.tonemap_mode = tonemap if o.get("tonemap", true) else Environment.TONE_MAPPER_LINEAR
		var hidden: Array = []
		for mat in materials:
			if not is_instance_valid(mat):
				continue
			mat.shading_mode = o.get("shading", materials[mat]["shading"])
			var spec: String = o.get("specular", "")
			var matte: bool = mat.roughness >= 0.8 and mat.metallic == 0.0
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED \
				if spec == "all" or (spec == "matte" and matte) else materials[mat]["specular"]
			if o.get("no_alpha", false) and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				for node in materials[mat]["nodes"]:
					if is_instance_valid(node) and node.visible:
						node.visible = false
						hidden.append(node)
		if o.get("terrain_only", false):
			for node in level.get_children():
				if node is Node3D and node != level._terrain and node.visible:
					node.visible = false
					hidden.append(node)
			if cube.visible:
				cube.visible = false
				hidden.append(cube)
		if o.has("shading") or o.has("specular"):
			# Recompilación de los shaders.
			await _wait(2.0)
		await _sample(setup[0])
		if o.get("shot", false):
			shot += 1
			viewport.get_texture().get_image().save_png("user://shot_%d_%d.png" % [number, shot])
		for node in hidden:
			if is_instance_valid(node):
				node.visible = true
	cube.set_process(true)


## Materiales 3D de la escena -> { "shading": modo original, "nodes": nodos que lo usan }.
func _materials(root: Node) -> Dictionary:
	var result := {}
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var mats: Array = [node.material_override]
		var mesh: Mesh = null
		if node is MeshInstance3D:
			mesh = node.mesh
			for i in node.get_surface_override_material_count():
				mats.append(node.get_surface_override_material(i))
		elif node is MultiMeshInstance3D and node.multimesh:
			mesh = node.multimesh.mesh
		if mesh:
			for i in mesh.get_surface_count():
				mats.append(mesh.surface_get_material(i))
		for mat in mats:
			if mat is BaseMaterial3D:
				if not result.has(mat):
					result[mat] = {"shading": mat.shading_mode, "specular": mat.specular_mode, "nodes": []}
				result[mat]["nodes"].append(node)
	return result


func _map_shots(number: int, game: Node) -> void:
	# El cubo rueda solo un rato para explorar algo más que la salida.
	await _wait(8.0)
	game._set_paused(true)
	await _wait(1.0)
	var map: PauseMap = game._map
	_log("nivel %d: mapa %s, %.1f px por casilla" % [number, map._grid, map._zoom])
	await _map_shot(number, 1)
	map._legend_open = true
	map._legend.visible = true
	await _wait(0.5)
	await _map_shot(number, 2)
	map._legend_open = false
	map._legend.visible = false
	map._zoom_smoothly(PauseMap.ZOOM_STEP * PauseMap.ZOOM_STEP)
	await _wait(0.6)
	_log("  tras acercar: zoom %s, offset %s, canvas %s / %s, visible %s" % [map._zoom, map._offset,
		map._canvas.position, map._canvas.scale, map._canvas.is_visible_in_tree()])
	await _map_shot(number, 3)
	map.center_on_cube()
	await _wait(0.6)
	await _map_shot(number, 4)
	game._set_paused(false)
	await _wait(1.5)
	# Con el mapa entero a la vista (mecánica futura).
	game.level.reveal_whole_map()
	game._set_paused(true)
	await _wait(1.0)
	await _map_shot(number, 5)
	game._set_paused(false)
	await _wait(1.0)


func _map_shot(number: int, index: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://map_%d_%d.png" % [number, index])


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
	var script_ms := 0.0
	var objects := 0.0
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
		script_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var ms := (last - start) / 1000.0 / frames
	_log("  %-22s %5.1f fps %5.1f ms/f peor %5.1f | render CPU %4.1f GPU %5.1f ms | proceso %4.1f ms | objs %4d draws %4d tris %4dk" % [
		label, 1000.0 / ms, ms, worst, cpu / frames, gpu / frames, script_ms / frames,
		objects / frames, draws / frames, prims / frames / 1000.0])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _log(text: String) -> void:
	_lines.append(text)
	print("BENCH ", text)
