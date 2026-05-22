extends Node2D
class_name Board

## Nodo que gestiona toda la lógica del puzzle y el dibujado del tablero.
## Se comunica con el resto de la escena únicamente a través de señales.

# ── Señales ──────────────────────────────────────────────
signal game_started(par: int)
signal move_made(par: int, remaining: int)
signal game_ended(won: bool)

# ── Config (ajustable desde el Inspector) ─────────────────
@export var knight_texture : Texture2D  ## Arrastra aquí tu imagen de caballo (PNG/SVG)
@export var cell_size      : int = 62   ## Tamaño visual de cada casilla en píxeles
@export var min_par        : int = 4    ## Dificultad mínima (movimientos requeridos)
@export var max_par        : int = 6    ## Dificultad máxima
@export var min_cells      : int = 48   ## Tamaño mínimo del mapa
@export var max_cells      : int = 68   ## Tamaño máximo del mapa

# ── Constantes internas ───────────────────────────────────
const GRID_MAX   := 17
const PANEL_W    := 200.0   # px reservados para el panel lateral

## Las 8 posibles "L" del caballo de ajedrez
const KM: Array[Vector2i] = [
	Vector2i( 2,  1), Vector2i( 2, -1),
	Vector2i(-2,  1), Vector2i(-2, -1),
	Vector2i( 1,  2), Vector2i( 1, -2),
	Vector2i(-1,  2), Vector2i(-1, -2),
]

# ── Paleta: tema blanco y negro ───────────────────────────
const C_BG_RIGHT := Color("f0f0f0")         # fondo del área del tablero
const C_LIGHT    := Color("ffffff")          # casilla clara
const C_DARK     := Color("1a1a1a")          # casilla oscura
const C_VALID    := Color("2ecc4099")        # celda con salto válido
const C_TARGET   := Color("cc2222dd")        # celda objetivo
const C_KNIGHT   := Color("e0e0e0")          # fallback círculo caballo
const C_BORDER   := Color("505050")          # borde de celda
const C_SHADOW   := Color(0.0, 0.0, 0.0, 0.15)
const C_HOVER    := Color(0.0, 0.0, 0.0, 0.09)
const C_TRAIL    := Color(0.0, 0.0, 0.0, 0.07)

# ── Estado del juego ──────────────────────────────────────
var _board    : Dictionary          # Vector2i → true
var _origin   : Vector2i            # esquina top-left del bounding box
var _offset   : Vector2             # posición en pantalla de la celda (0,0)

var _knight   : Vector2i
var _goal     : Vector2i
var _par      : int
var _remaining: int
var _hints    : Array[Vector2i]     # saltos válidos actualmente visibles
var _trail    : Array[Vector2i]     # historial de posiciones visitadas
var _hovered  : Vector2i = Vector2i(-999, -999)
var _phase    : String = "idle"     # "playing" | "won" | "lost"


# ══════════════════════════════════════════════════════════
#  API PÚBLICA
# ══════════════════════════════════════════════════════════

## Genera un mapa nuevo y reinicia la partida.
## Llamar desde Game.gd al inicio y al pulsar "Nueva partida".
func start_new_game() -> void:
	_phase     = "playing"
	_hints     = []
	_trail     = []
	_hovered   = Vector2i(-999, -999)

	for _attempt in 100:
		_gen_map()
		var all: Array[Vector2i] = []
		all.assign(_board.keys())
		if all.is_empty():
			continue

		_knight = all[randi() % all.size()]
		var dist := _bfs(_knight)

		var candidates: Array[Vector2i] = []
		for c: Vector2i in dist:
			var d: int = dist[c]
			if d >= min_par and d <= max_par:
				candidates.append(c)
		if candidates.is_empty():
			continue

		_goal       = candidates[randi() % candidates.size()]
		_par        = dist[_goal]
		_remaining  = _par
		_trail.append(_knight)
		break

	game_started.emit(_par)
	queue_redraw()


# ══════════════════════════════════════════════════════════
#  GENERACIÓN DEL MAPA
# ══════════════════════════════════════════════════════════

func _gen_map() -> void:
	_board.clear()
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	var seed := Vector2i(GRID_MAX / 2, GRID_MAX / 2)
	_board[seed] = true
	var frontier: Array[Vector2i] = [seed]
	var wanted := randi_range(min_cells, max_cells)
	var iters  := 0

	while _board.size() < wanted and iters < 3000:
		iters += 1
		var base: Vector2i = frontier[randi() % frontier.size()]
		var nd: Vector2i   = base + dirs[randi() % 4]
		if (nd not in _board
				and nd.x > 0 and nd.x < GRID_MAX - 1
				and nd.y > 0 and nd.y < GRID_MAX - 1):
			_board[nd] = true
			frontier.append(nd)

	_recalc_offset()


func _recalc_offset() -> void:
	var ax: Array = _board.keys().map(func(v: Vector2i) -> int: return v.x)
	var ay: Array = _board.keys().map(func(v: Vector2i) -> int: return v.y)
	_origin = Vector2i(int(ax.min()), int(ay.min()))
	var w: int = (int(ax.max()) - int(ax.min()) + 1) * cell_size
	var h: int = (int(ay.max()) - int(ay.min()) + 1) * cell_size
	var vp := get_viewport_rect().size
	_offset = Vector2(
		PANEL_W + (vp.x - PANEL_W - w) * 0.5,
		(vp.y - h) * 0.5
	)


# ══════════════════════════════════════════════════════════
#  BFS – distancia mínima en movimientos de caballo
# ══════════════════════════════════════════════════════════

func _bfs(start: Vector2i) -> Dictionary:
	var dist: Dictionary = {start: 0}
	var q: Array         = [start]
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		for m: Vector2i in KM:
			var nxt := cur + m
			if nxt in _board and nxt not in dist:
				dist[nxt] = dist[cur] + 1
				q.append(nxt)
	return dist


# ══════════════════════════════════════════════════════════
#  INPUT
# ══════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if _phase != "playing":
		return

	# Ignorar clics en el panel lateral de UI
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var mpos: Vector2 = (event as InputEventMouse).position
		if mpos.x <= PANEL_W:
			return

	if event is InputEventMouseMotion:
		var g := _screen_to_grid((event as InputEventMouseMotion).position)
		if g != _hovered:
			_hovered = g
			queue_redraw()

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var g := _screen_to_grid(mb.position)

		if g in _hints:
			_do_move(g)
		elif g == _knight:
			if _hints.is_empty():
				_hints = _get_valid_moves()
			else:
				_hints.clear()
			queue_redraw()
		else:
			if not _hints.is_empty():
				_hints.clear()
				queue_redraw()


func _get_valid_moves() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for m: Vector2i in KM:
		var n := _knight + m
		if n in _board:
			out.append(n)
	return out


func _do_move(to: Vector2i) -> void:
	_knight     = to
	_remaining -= 1
	_hints.clear()
	_trail.append(_knight)

	if _knight == _goal:
		_phase = "won"
		game_ended.emit(true)
	elif _remaining <= 0:
		_phase = "lost"
		game_ended.emit(false)
	else:
		move_made.emit(_par, _remaining)

	queue_redraw()


# ══════════════════════════════════════════════════════════
#  COORDENADAS
# ══════════════════════════════════════════════════════════

func _grid_to_screen(g: Vector2i) -> Vector2:
	return Vector2((g.x - _origin.x) * cell_size,
				   (g.y - _origin.y) * cell_size) + _offset


func _screen_to_grid(s: Vector2) -> Vector2i:
	var local := s - _offset
	return Vector2i(
		int(floor(local.x / float(cell_size))) + _origin.x,
		int(floor(local.y / float(cell_size))) + _origin.y
	)


# ══════════════════════════════════════════════════════════
#  DIBUJADO
# ══════════════════════════════════════════════════════════

func _draw() -> void:
	if _board.is_empty():
		return

	var vp   := get_viewport_rect()
	var font := ThemeDB.fallback_font
	var cs   := float(cell_size)

	# Fondo del área de juego (derecha del panel)
	draw_rect(Rect2(Vector2(PANEL_W, 0), vp.size), C_BG_RIGHT)

	# Rastro de movimientos anteriores
	for i in range(1, _trail.size() - 1):
		var sp := _grid_to_screen(_trail[i])
		draw_rect(Rect2(sp, Vector2(cs, cs)), C_TRAIL)

	# Celdas
	for cell: Vector2i in _board:
		var sp   := _grid_to_screen(cell)
		var rect := Rect2(sp, Vector2(cs, cs))
		var is_w := (cell.x + cell.y) % 2 == 0
		var ctr  := sp + Vector2(cs, cs) * 0.5

		# Sombra
		draw_rect(Rect2(sp + Vector2(3, 3), Vector2(cs, cs)), C_SHADOW)

		# Relleno
		var fill: Color
		if   cell == _goal   : fill = C_TARGET
		elif cell in _hints  : fill = C_VALID
		elif is_w            : fill = C_LIGHT
		else                 : fill = C_DARK
		draw_rect(rect, fill)

		# Hover
		if cell == _hovered and cell != _knight and _phase == "playing":
			draw_rect(rect, C_HOVER)

		# Borde
		draw_rect(rect, C_BORDER, false, 1.2)

		# ── Marcador de objetivo ──
		if cell == _goal:
			var m := cs * 0.17
			draw_line(sp + Vector2(m, m),      sp + Vector2(cs - m, cs - m), Color.WHITE, 3.5)
			draw_line(sp + Vector2(cs - m, m), sp + Vector2(m, cs - m),      Color.WHITE, 3.5)
			draw_string(font, sp + Vector2(3.0, cs - 4.0),
				"GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.85))

		# ── Punto de salto válido ──
		if cell in _hints:
			draw_circle(ctr, cs * 0.16, Color(0, 0, 0, 0.22))
			draw_circle(ctr, cs * 0.10, Color.WHITE)

		# ── Caballo ──
		if cell == _knight:
			if knight_texture != null:
				var pad := cs * 0.07
				draw_texture_rect(
					knight_texture,
					Rect2(sp + Vector2(pad, pad), Vector2(cs - pad * 2.0, cs - pad * 2.0)),
					false
				)
			else:
				draw_circle(ctr, cs * 0.38, C_KNIGHT)
				draw_circle(ctr, cs * 0.38, Color("303030"), false, 2.5)
				var fs := int(cs * 0.54)
				draw_string(font,
					sp + Vector2((cs - fs * 0.48) * 0.22, cs * 0.68),
					"♞", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("111111"))

	# ── Overlay de fin de partida ──
	if _phase in ["won", "lost"]:
		draw_rect(Rect2(Vector2.ZERO, vp.size), Color(0, 0, 0, 0.55))
		var msg  := "¡VICTORIA!  🏆"   if _phase == "won" else "¡Sin movimientos!  💀"
		var col  := Color("55ee88") if _phase == "won" else Color("ff4444")
		var sz   := 44
		var tw   := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_string(font,
			Vector2((vp.size.x - tw) * 0.5, vp.size.y * 0.5),
			msg, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
		var sub := "Pulsa  🔄 Nueva partida  para continuar"
		var sw  := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font,
			Vector2((vp.size.x - sw) * 0.5, vp.size.y * 0.5 + 56.0),
			sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.85))
