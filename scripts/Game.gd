extends Node2D

## Orquestador de la escena principal.
## No contiene lógica de juego — sólo conecta señales del Board
## con los nodos de UI declarados en la escena.

# ── Referencias a nodos de la escena ─────────────────────
@onready var board       : Board  = $Board

@onready var lbl_par     : Label  = $UI/SidePanel/Margin/VBox/LblPar
@onready var lbl_moves   : Label  = $UI/SidePanel/Margin/VBox/LblMoves
@onready var lbl_status  : Label  = $UI/SidePanel/Margin/VBox/LblStatus
@onready var btn_new     : Button = $UI/SidePanel/Margin/VBox/BtnNew
@onready var lbl_counter : Label  = $UI/LblCounter


# ══════════════════════════════════════════════════════════
func _ready() -> void:
	# Conectar señales del Board a este script
	board.game_started.connect(_on_game_started)
	board.move_made.connect(_on_move_made)
	board.game_ended.connect(_on_game_ended)

	# Conectar botón
	btn_new.pressed.connect(board.start_new_game)

	# Arrancar la primera partida
	board.start_new_game()


# ── Manejadores de señales ────────────────────────────────

func _on_game_started(par: int) -> void:
	lbl_par.text    = "Par:       %d mov." % par
	lbl_moves.text  = "Restantes: %d mov." % par
	lbl_counter.text = "Movimientos: 0 / %d" % par
	lbl_status.text  = ""
	lbl_status.add_theme_color_override("font_color", Color.WHITE)


func _on_move_made(par: int, remaining: int) -> void:
	lbl_moves.text   = "Restantes: %d mov." % remaining
	lbl_counter.text = "Movimientos: %d / %d" % [par - remaining, par]


func _on_game_ended(won: bool) -> void:
	lbl_counter.text = ""
	if won:
		lbl_status.text = "¡VICTORIA! 🏆"
		lbl_status.add_theme_color_override("font_color", Color("55ee88"))
	else:
		lbl_status.text = "¡Sin movimientos!\n     💀"
		lbl_status.add_theme_color_override("font_color", Color("ff4444"))
