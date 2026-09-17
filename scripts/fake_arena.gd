extends Node2D

## Minimal fake arena node for the isolated minigame test.
## Provides half_extents() which MinigameArea._apply_layout() calls.

func half_extents() -> Vector2:
	return Vector2(2360.0, 1560.0) * 0.5
