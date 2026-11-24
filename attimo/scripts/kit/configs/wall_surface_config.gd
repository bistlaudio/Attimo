class_name WallSurfaceConfig
extends Resource
## Config of the Wall surface block (Phase 05.1, KIT-01, D-06, D-11): one surface enum instead of flags. WALL_RUN pads carry the
## wall-run, WALL_JUMP pads the kick; the motion itself is the player's WallRun / WallJump state with its MovementConfig values, the
## surface only says which one. Presets live in resources/kit/wall_surface/. Sizes have strictly positive minimums (T-05.1-10). A
## loaded preset is never written at runtime: the block duplicates it in _ready (D-12).

enum Surface { WALL_RUN, WALL_JUMP }

## Which move the panel offers: WALL_RUN joins the group wall_run_surface, WALL_JUMP the group wall_jump_surface.
@export var surface: Surface = Surface.WALL_RUN
## Panel height in m from the block origin up; raise it so a kick cannot clear the pad (a wall-jump twin needs
## WallSurface.JUMP_PAD_HEIGHT_MIN).
@export_range(1.0, 20.0, 0.5) var height: float = 4.0
## Panel width in m along the face (centred on the block origin); raise it for a longer wall-run.
@export_range(1.0, 30.0, 0.5) var width: float = 12.0
