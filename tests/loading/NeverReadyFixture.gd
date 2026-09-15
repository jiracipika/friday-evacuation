# NeverReadyFixture.gd — target scene whose is_loading_complete() NEVER
# becomes true, used to drive the loader into its readiness-timeout error
# state AFTER the scene swap already happened.
extends Node


func is_loading_complete() -> bool:
	return false
