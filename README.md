# ♞ Knight Puzzle – Godot 4.6

## Abrir el proyecto
1. Godot 4.6 → **Import** → carpeta `knight_puzzle/`
2. **F5** para jugar

---

## Estructura del proyecto

```
knight_puzzle/
├── project.godot
├── scenes/
│   └── Game.tscn          ← árbol de nodos completo (UI declarada aquí)
└── scripts/
    ├── Board.gd            ← lógica del puzzle + dibujado del tablero
    └── Game.gd             ← orquestador: conecta señales con la UI
```

### Árbol de nodos en Game.tscn
```
Game  (Node2D)  [Game.gd]
├── Board  (Node2D)  [Board.gd]
└── UI  (CanvasLayer)
    ├── SidePanel  (PanelContainer)
    │   └── Margin  (MarginContainer)
    │       └── VBox  (VBoxContainer)
    │           ├── Title       (Label)
    │           ├── Sep1        (HSeparator)
    │           ├── LblPar      (Label)   ← actualizado por señal
    │           ├── LblMoves    (Label)   ← actualizado por señal
    │           ├── LblStatus   (Label)   ← actualizado por señal
    │           ├── Sep2        (HSeparator)
    │           ├── BtnNew      (Button)  ← llama board.start_new_game()
    │           ├── Sep3        (HSeparator)
    │           ├── LblInstructions (Label)
    │           ├── Sep4        (HSeparator)
    │           └── LblLegend   (Label)
    └── LblCounter  (Label)               ← contador sobre el tablero
```

### Flujo de comunicación (señales)
```
Board ──game_started(par)──────► Game._on_game_started()  → actualiza labels
Board ──move_made(par,remaining)► Game._on_move_made()     → actualiza labels
Board ──game_ended(won)────────► Game._on_game_ended()     → muestra resultado

BtnNew.pressed ────────────────► board.start_new_game()
```

---

## Poner tu propia imagen del caballo

1. Importa tu PNG/SVG al proyecto (arrástralo al **FileSystem** de Godot)
2. Selecciona el nodo **Board** en la escena
3. En el **Inspector**, arrastra la imagen al campo **Knight Texture**

Si el campo está vacío, se dibuja el símbolo ♞ como fallback automático.

---

## Ajustar dificultad y tamaño

Selecciona el nodo **Board** → Inspector:

| Propiedad   | Por defecto | Descripción                         |
|-------------|-------------|-------------------------------------|
| Cell Size   | 62          | Tamaño visual de cada casilla (px)  |
| Min Par     | 4           | Movimientos mínimos requeridos      |
| Max Par     | 6           | Movimientos máximos requeridos      |
| Min Cells   | 48          | Tamaño mínimo del mapa              |
| Max Cells   | 68          | Tamaño máximo del mapa              |
