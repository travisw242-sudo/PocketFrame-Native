extends RefCounted
## Only real compositor alpha passthrough; never imitate it with a blank room.
var active := false
var saved := {}

static func supported(modes: Array) -> bool:
	# Require a safe route back to opaque VR as well as alpha passthrough.
	return XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes and XRInterface.XR_ENV_BLEND_MODE_OPAQUE in modes

static func reason(interface: Variant, xr_running: bool) -> String:
	if not xr_running or interface==null or not interface.is_initialized():
		return "AR needs an active headset session."
	if not supported(interface.get_supported_environment_blend_modes()):
		return "AR unavailable: this runtime does not expose alpha passthrough. Arcturus currently supports on-headset apps, not PC-streamed VR."
	return "Compositor passthrough available. Use seated; virtual props do not detect real furniture."

func enable(interface: Variant, viewport: Viewport, environment: Environment) -> bool:
	if active: return true
	if interface==null or not interface.is_initialized() or not supported(interface.get_supported_environment_blend_modes()): return false
	saved={"blend":interface.environment_blend_mode,"transparent":viewport.transparent_bg,"background":environment.background_mode,"color":environment.background_color}
	interface.environment_blend_mode=XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	if interface.environment_blend_mode!=XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND:
		interface.environment_blend_mode=saved.blend
		saved.clear()
		return false
	viewport.transparent_bg=true
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(0,0,0,0)
	active=true
	return true

func disable(interface: Variant, viewport: Viewport, environment: Environment) -> void:
	if not active: return
	if interface!=null and interface.is_initialized(): interface.environment_blend_mode=saved.blend
	viewport.transparent_bg=saved.transparent
	environment.background_mode=saved.background
	environment.background_color=saved.color
	saved.clear()
	active=false
