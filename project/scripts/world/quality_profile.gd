@tool
class_name QualityProfile
extends RefCounted
## Picks the graphics tier. Phones (Android) always use LOW; on PC pass `-- --low-quality` to
## preview what phones get. Later phases will add a settings menu that overrides this.


static func is_low() -> bool:
	if Engine.is_editor_hint():
		return false
	return OS.has_feature("mobile") or "--low-quality" in OS.get_cmdline_user_args()
