extends RefCounted
## Full-scale room. Props are curated conversions of the user's licensed packs.
const G = preload("res://scripts/geometry.gd")
const SURFACE = preload("res://scripts/room_surface.gdshader")
const ASSETS := "res://assets/rooms/motel/"

static func textured(color: String, kind: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=SURFACE
	mat.set_shader_parameter("tint",Color(color))
	mat.set_shader_parameter("surface_kind",kind)
	return mat

static func box(root: Node3D, title: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size=size
	return G.instance(root,mesh,mat,pos,title)

static func bounds(node: Node3D, frame: Transform3D = Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	var first := true
	if node is MeshInstance3D:
		result=frame*node.transform*node.get_aabb()
		first=false
	for child in node.get_children():
		if not child is Node3D: continue
		var part := bounds(child,frame*node.transform)
		if part.size.length_squared()==0: continue
		result=part if first else result.merge(part)
		first=false
	return result

static func prop(root: Node3D, asset: String, title: String, pos: Vector3, width: float, angle: float = 0) -> Node3D:
	var path := ASSETS+asset+".scn"
	if not ResourceLoader.exists(path): return null
	var node: Node3D=load(path).instantiate()
	var dimensions := bounds(node)
	var size := width/maxf(dimensions.size.x,.001)
	var mount := Node3D.new()
	mount.name=title
	root.add_child(mount)
	mount.position=pos
	mount.rotation.y=deg_to_rad(angle)
	mount.scale=Vector3.ONE*size
	mount.add_child(node)
	node.position-=Vector3(dimensions.get_center().x,dimensions.position.y,dimensions.get_center().z)
	mount.set_meta("source_asset",asset)
	mount.set_meta("height",dimensions.size.y*size)
	mount.set_meta("depth",dimensions.size.z*size)
	return mount

static func cable(root: Node3D, points: Array[Vector3], mat: Material) -> void:
	for i in range(points.size()-1):
		var a := points[i]
		var b := points[i+1]
		var segment := G.cylinder(root,.003,a.distance_to(b),mat,(a+b)*.5,"PowerCable")
		segment.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))

static func build_fan_power(root: Node3D, fan: Node3D, cream: Material, dark: Material) -> void:
	var outlet := Node3D.new()
	outlet.name="FanOutlet"; outlet.position=Vector3(-2.097,.28,.9)
	outlet.rotation.y=PI/2
	root.add_child(outlet)
	box(outlet,"Faceplate",Vector3(.08,.12,.01),Vector3.ZERO,cream)
	for y in [-.027,.027]:
		for x in [-.014,.014]: box(outlet,"Socket",Vector3(.005,.015,.006),Vector3(x,y,.006),dark)
	box(outlet,"Plug",Vector3(.035,.027,.032),Vector3(0,-.027,.023),dark)
	var frame: Transform3D=fan.transform*(fan.get_child(0) as Node3D).transform
	cable(root,[frame*Vector3(0,1.13,-.08),frame*Vector3(0,.8,-.04),frame*Vector3(0,.10,-.04),frame*Vector3(.12,.015,-.12),Vector3(-1.93,.024,.9),Vector3(-2.00,.024,.9),Vector3(-2.05,.09,.9),Vector3(-2.059,.253,.9)],dark)

static func build_tv(root: Node3D, pos: Vector3) -> void:
	# Detailed late-2000s LCD: a recessed glass panel, stepped bezel, pedestal,
	# separate speaker grille, rear vents and physical controls, not the motel prop.
	var tv := Node3D.new()
	tv.name="BedroomTV"; tv.position=pos; tv.rotation.y=-PI/2
	root.add_child(tv)
	var shell := G.material(Color("11151b"),.25,.28)
	var trim := G.material(Color("4b5056"),.65,.3)
	var rubber := G.material(Color("090b10"),0,.8)
	var body := G.rounded(tv,Vector3(.72,.075,.47),.024,.008,shell,Vector3(0,.30,0),"BeveledHousing")
	body.rotation.x=PI/2
	box(tv,"RecessedTrim",Vector3(.661,.375,.008),Vector3(0,.321,.040),trim)
	box(tv,"InnerBezel",Vector3(.649,.363,.006),Vector3(0,.321,.046),rubber)
	var glass := G.material(Color("14232d"),.38,.19)
	box(tv,"ScreenGlass",Vector3(.625,.34,.003),Vector3(0,.321,.050),glass)
	# A subtle standby reflection rather than a bright distracting fake image.
	box(tv,"LowerSpeaker",Vector3(.57,.024,.005),Vector3(0,.115,.041),rubber)
	for i in range(45): box(tv,"SpeakerPerforation",Vector3(.0015,.016,.001),Vector3(-.275+i*.0125,.115,.044),trim)
	G.cylinder(tv,.018,.10,trim,Vector3(0,.07,-.006),"StandNeck")
	G.rounded(tv,Vector3(.31,.018,.18),.045,.005,shell,Vector3(0,.009,.016),"WeightedFoot")
	for i in range(5):
		G.cylinder(tv,.004,.003,trim,Vector3(.276-i*.016,.085,.039),"TVButton").rotation.x=PI/2
	var led := G.material(Color("87b3a2"),0,.3)
	led.emission_enabled=true; led.emission=Color("183b2d")
	box(tv,"StandbyLED",Vector3(.004,.002,.002),Vector3(.314,.085,.041),led)
	for i in range(16): box(tv,"RearVent",Vector3(.012,.065,.003),Vector3(-.21+i*.027,.36,-.039),rubber)
	cable(tv,[Vector3(.16,.18,-.042),Vector3(.16,.03,-.11),Vector3(.16,-.12,-.15)],rubber)

static func domestic_details(root: Node3D, cream: Material, dark: Material) -> void:
	# A desk alarm clock with seven-segment digits, not a floating text label.
	var clock := Node3D.new()
	clock.name="DeskAlarmClock"; clock.position=Vector3(.82,.8,-2.32)
	root.add_child(clock)
	G.rounded(clock,Vector3(.19,.07,.07),.012,.004,dark,Vector3(0,.035,0),"ClockHousing")
	box(clock,"TintedClockFace",Vector3(.168,.044,.003),Vector3(0,.036,.037),G.material(Color("150f12")))
	var glow := G.material(Color("b84d30"))
	glow.emission_enabled=true; glow.emission=Color("7d271a")
	var digits := [[1,2],[0,1,3,4,6],[0,1,2,3,4,5]] # 1:20, seven-segment display
	for d in range(3):
		var x := -.059+d*.054
		for segment in digits[d]:
			var positions := [Vector2(0,.016),Vector2(.013,.008),Vector2(.013,-.008),Vector2(0,-.016),Vector2(-.013,-.008),Vector2(-.013,.008),Vector2(0,0)]
			var p: Vector2=positions[segment]
			box(clock,"LEDSegment",Vector3(.019 if segment in [0,3,6] else .003,.003 if segment in [0,3,6] else .011,.001),Vector3(x+p.x,.036+p.y,.039),glow)
	for y in [-.007,.007]: box(clock,"Colon",Vector3(.003,.003,.001),Vector3(-.031,.036+y,.039),glow)
	box(clock,"SnoozeButton",Vector3(.065,.003,.023),Vector3(0,.071,0),cream)
	# A small display rocket grounded on the bookcase top.
	var rocket := Node3D.new()
	rocket.name="ShelfModelRocket"
	var shelf := root.get_node("CollectionShelf")
	rocket.position=Vector3(1.85,.02+float(shelf.get_meta("height")),-.55)
	root.add_child(rocket)
	G.cylinder(rocket,.028,.012,dark,Vector3(0,.006,0),"DisplayBase")
	G.cylinder(rocket,.012,.12,cream,Vector3(0,.078,0),"RocketBody")
	var cone := CylinderMesh.new(); cone.top_radius=0; cone.bottom_radius=.012; cone.height=.032
	G.instance(rocket,cone,G.material(Color("a94c3c")),Vector3(0,.154,0),"NoseCone")
	for angle in [0,TAU/3,TAU*2/3]:
		var fin := box(rocket,"RocketFin",Vector3(.028,.03,.003),Vector3(sin(angle)*.01,.027,cos(angle)*.01),dark)
		fin.rotation.y=angle

static func closed_book(parent: Node3D, title: String, size: Vector3, pos: Vector3, color: String) -> Node3D:
	var book := Node3D.new()
	book.name="ShelfBook"; book.position=pos
	parent.add_child(book)
	var cover := G.material(Color(color),0,.85)
	var paper := G.material(Color("d9cfb6"),0,1)
	box(book,"PageBlock",size-Vector3(.005,.008,.008),Vector3(0,0,-.001),paper)
	for x in [-1,1]: box(book,"HardCover",Vector3(.002,size.y,size.z),Vector3(x*(size.x*.5-.001),0,0),cover)
	box(book,"BoundSpine",Vector3(size.x,size.y,.006),Vector3(0,0,size.z*.5-.003),cover)
	var foil := G.material(Color("bba36f"),.1,.7)
	for y in [-.35,.35]: box(book,"SpineBand",Vector3(size.x-.005,.002,.001),Vector3(0,size.y*y,size.z*.5+.0005),foil)
	# Fine page edges and an inset spine title distinguish real books from blocks.
	for i in range(6): box(book,"PageEdge",Vector3(.0005,size.y-.012,.001),Vector3(-size.x*.35+i*size.x*.14,0,-size.z*.5+.003),G.material(Color("b8ac91"),0,1))
	var label := Label3D.new()
	label.name="SpineTitle"; label.text=title; label.font_size=28
	label.pixel_size=.00018; label.outline_size=0
	label.modulate=Color("d5c7a1"); label.position=Vector3(0,0,size.z*.5+.0015)
	label.rotation.z=PI/2
	book.add_child(label)
	return book

static func shelf_books(root: Node3D) -> void:
	var collection := Node3D.new()
	collection.name="ShelfBooks"; collection.position=Vector3(1.85,0,-.55); collection.rotation.y=-PI/2
	root.add_child(collection)
	# Converted bookcase top surfaces measured from the mesh: .143/.435/.702/.968.
	var colors := ["394853","655245","586150","4d3e42","354f5b"]
	var titles := ["STAR MAPS","FIELD NOTES","ADVENTURES","SKETCHBOOK","OCEANS"]
	for i in range(5):
		var height := .19+(i%3)*.012
		closed_book(collection,titles[i],Vector3(.028,height,.155),Vector3(-.20+i*.030,.435+height*.5,.015),colors[i])
	for i in range(3):
		var book := closed_book(collection,"COLLECTED STORIES",Vector3(.030,.20,.15),Vector3(.13,.702+.015+i*.031,.012),colors[i+1])
		book.rotation.z=PI/2
	for i in range(2):
		closed_book(collection,titles[i+2],Vector3(.036,.21,.16),Vector3(.10+i*.038,.143+.105,.012),colors[i+2])

static func build(root: Node3D) -> void:
	var wall := textured("657a89",1)
	var cream := G.material(Color("ded9c9"),0,.8)
	var wood := textured("795439",0)
	var dark := G.material(Color("202832"),.2,.5)
	var cloth := textured("31567b",2)
	box(root,"BedroomFloor",Vector3(4.3,.06,4.5),Vector3(0,-.03,-.3),G.material(Color("211b18")))
	# Shared plank mesh: narrow real gaps, staggered joints and grain shading.
	var plank := BoxMesh.new()
	plank.size=Vector3(.142,.016,.74)
	var boards := MultiMesh.new()
	boards.transform_format=MultiMesh.TRANSFORM_3D
	boards.mesh=plank
	boards.instance_count=29*6
	for x in range(29):
		for z in range(6):
			boards.set_instance_transform(x*6+z,Transform3D(Basis.IDENTITY,Vector3((x-14)*.148,.004,-2.12+z*.75)))
	var floor := MultiMeshInstance3D.new()
	floor.name="WoodFloorboards"
	floor.multimesh=boards
	floor.material_override=wood
	root.add_child(floor)
	box(root,"BackWall",Vector3(4.3,2.55,.08),Vector3(0,1.275,-2.55),wall)
	box(root,"LeftWall",Vector3(.08,2.55,4.5),Vector3(-2.15,1.275,-.3),wall)
	box(root,"RightWall",Vector3(.08,2.55,4.5),Vector3(2.15,1.275,-.3),wall)
	box(root,"FrontWall",Vector3(4.3,2.55,.08),Vector3(0,1.275,1.95),wall)
	box(root,"Ceiling",Vector3(4.3,.04,4.5),Vector3(0,2.56,-.3),cream)
	for z in [-2.49,1.89]:
		box(root,"Skirting",Vector3(4.22,.105,.025),Vector3(0,.065,z),cream)
		box(root,"CrownMoulding",Vector3(4.22,.055,.04),Vector3(0,2.49,z),cream)
	for x in [-2.09,2.09]:
		box(root,"Skirting",Vector3(.025,.105,4.4),Vector3(x,.065,-.3),cream)
		box(root,"CrownMoulding",Vector3(.04,.055,4.4),Vector3(x,2.49,-.3),cream)
	# Window inset over desk, framed glass and individual blind slats.
	var glass := G.material(Color("b6d5df"),.1,.35)
	glass.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	box(root,"WindowDaylight",Vector3(1.28,1.14,.018),Vector3(.68,1.72,-2.494),glass)
	for x in [-.01,1.37]: box(root,"WindowTrim",Vector3(.065,1.3,.065),Vector3(x,1.72,-2.46),cream)
	for y in [1.1,2.34]: box(root,"WindowTrim",Vector3(1.44,.065,.065),Vector3(.68,y,-2.46),cream)
	box(root,"WindowSill",Vector3(1.53,.05,.19),Vector3(.68,1.09,-2.4),cream)
	for i in range(13):
		var slat := box(root,"BlindSlat",Vector3(1.3,.029,.045),Vector3(.68,2.29-i*.037,-2.43),cream)
		slat.rotation.x=.35
	for x in [.15,1.22]: box(root,"BlindCord",Vector3(.003,1.13,.003),Vector3(x,1.72,-2.4),dark)
	# Hero furniture. Lower edges are grounded from actual imported bounds.
	prop(root,"SM_Bed","Bed",Vector3(-1.35,.02,-1.16),1.35)
	var desk := Node3D.new()
	desk.name="Desk"
	root.add_child(desk)
	box(root,"Desktop",Vector3(1.6,.045,.85),Vector3(.68,.775,-2.02),wood)
	box(root,"DeskBack",Vector3(1.22,.36,.025),Vector3(.72,.56,-2.29),wood)
	for x in [-.04,1.4]:
		for z in [-2.37,-1.67]: box(root,"DeskSupport",Vector3(.04,.75,.04),Vector3(x,.4,z),wood)
	prop(root,"SM_Chair","DeskChair",Vector3(.02,.02,-1.15),.47,145)
	var nightstand := prop(root,"SM_Nightstand","Nightstand",Vector3(-.4,.02,-2.06),.42)
	var bedside_top := .02+float(nightstand.get_meta("height",.5)) if nightstand else .52
	prop(root,"SM_TableLamp","BedsideLamp",Vector3(-.4,bedside_top,-2.06),.23)
	prop(root,"SM_Nightstand_Drawer","NightstandDrawer",Vector3(-.4,.02,-2.06),.42)
	var shelf := prop(root,"Vintage_Bookcase","CollectionShelf",Vector3(1.85,.02,-.55),.65,-90)
	if shelf:
		for mesh in shelf.find_children("*","MeshInstance3D",true,false): mesh.material_override=wood
	var tv_top := .57
	var tv_cabinet := Node3D.new()
	tv_cabinet.name="TVCabinet"
	root.add_child(tv_cabinet)
	tv_cabinet.position=Vector3(1.65,0,.95)
	tv_cabinet.rotation.y=deg_to_rad(-90)
	box(tv_cabinet,"CabinetBody",Vector3(.79,maxf(.1,tv_top-.04),.4),Vector3(0,tv_top*.5,0),wood)
	for x in [-.19,.19]:
		box(tv_cabinet,"CabinetDoor",Vector3(.37,maxf(.08,tv_top-.12),.022),Vector3(x,tv_top*.5,.214),wood)
		box(tv_cabinet,"BrushedHandle",Vector3(.08,.012,.018),Vector3(x,tv_top*.58,.233),dark)
	build_tv(root,Vector3(1.65,tv_top,.95))
	prop(root,"SM_Plant","WindowPlant",Vector3(1.15,1.12,-2.39),.14)
	prop(root,"SM_Cup","DeskCup",Vector3(1.31,.8,-2.22),.085)
	# Keep the monitor housing in front of the projecting window sill.
	prop(root,"Vintage_Computer","FamilyHandMeDownComputer",Vector3(.30,.8,-2.025),.43)
	# Source bounds include the cable: a .17 m total width made the earcups tiny.
	prop(root,"Vintage_Headphones","Headphones",Vector3(1.18,.8,-2.025),.34,-15)
	prop(root,"Vintage_Cassette","Cassette",Vector3(1.56,tv_top+.002,.75),.1,-35)
	prop(root,"Vintage_OrangeLamp","DeskLamp",Vector3(-.01,.8,-2.16),.18)
	prop(root,"SM_Book01","SchoolBook",Vector3(1.18,.8,-2.29),.18,12)
	prop(root,"SM_Book02","BedsideBook",Vector3(-.4,bedside_top,-1.94),.19,-15)
	var fan := prop(root,"SM_PedestalFan_Connected","Fan",Vector3(-1.78,.02,.65),.35,90)
	if fan: build_fan_power(root,fan,cream,dark)
	prop(root,"SM_CeilingFan","CeilingFan",Vector3(.1,2.18,-.5),1.0)
	# Soft rug, layered edge binding, not shiny plastic.
	box(root,"RugBinding",Vector3(1.95,.012,1.75),Vector3(0,.019,-.36),G.material(Color("b7aa8c"),0,1))
	box(root,"WovenRug",Vector3(1.9,.014,1.7),Vector3(0,.026,-.36),textured("48566c",2))
	# Door and domestic details behind the user, no forced room-scale movement.
	box(root,"DoorFrame",Vector3(.93,2.13,.06),Vector3(.9,1.08,1.88),cream)
	box(root,"DoorPanel",Vector3(.82,2.04,.045),Vector3(.9,1.05,1.84),wood)
	for y in [.62,1.52]: box(root,"DoorInset",Vector3(.62,.69,.012),Vector3(.9,y,1.81),wood)
	var nickel := G.material(Color("aaa69a"),.82,.3)
	G.cylinder(root,.034,.009,nickel,Vector3(.58,1,1.809),"HandleRose").rotation.x=PI/2
	G.cylinder(root,.011,.032,nickel,Vector3(.58,1,1.788),"HandleSpindle").rotation.x=PI/2
	var knob := SphereMesh.new()
	knob.radius=.027; knob.height=.046
	G.instance(root,knob,nickel,Vector3(.58,1,1.762),"DoorHandle")
	for y in [.977,1.023]:
		G.cylinder(root,.0025,.001,dark,Vector3(.58,y,1.803),"RoseScrew").rotation.x=PI/2
	for x in [-.6,1.5]:
		box(root,"OutletPlate",Vector3(.075,.12,.012),Vector3(x,.3,-2.493),cream)
		for dx in [-.014,.014]: box(root,"OutletSocket",Vector3(.006,.018,.006),Vector3(x+dx,.3,-2.483),dark)
	# Original graphic poster designs using layered geometric printing.
	for i in range(2):
		var poster := Node3D.new()
		poster.name="OriginalPoster"
		root.add_child(poster)
		poster.position=Vector3(-1.45+i*.69,1.78,-2.487)
		box(poster,"Paper",Vector3(.55,.71,.006),Vector3.ZERO,G.material(Color("e6d7b7")))
		var print_mat := G.material(Color.WHITE,0,.95)
		var image := Image.new()
		var svg_path := "res://assets/rooms/"+("orbit-poster.svg" if i==0 else "summer-poster.svg")
		image.load_svg_from_string(FileAccess.get_file_as_string(svg_path))
		image.generate_mipmaps()
		print_mat.albedo_texture=ImageTexture.create_from_image(image)
		var print_mesh := QuadMesh.new()
		print_mesh.size=Vector2(.54,.70)
		G.instance(poster,print_mesh,print_mat,Vector3(0,0,.004),"OriginalPrint")
	# The actual desk is the dock: no additional floating table or shelf placeholders.
	var dock := Marker3D.new()
	dock.name="DeskDock"; dock.position=Vector3(.8,.813,-1.76)
	root.add_child(dock)
	var spawn := Marker3D.new()
	spawn.name="PlayerSpawn"; spawn.position=Vector3(.8,0,-1.22)
	root.add_child(spawn)
	# Small domestic details, all outside the playable desktop area.
	box(root,"MousePad",Vector3(.19,.004,.22),Vector3(.68,.802,-2.14),cloth)
	var mouse := SphereMesh.new(); mouse.radius=.028; mouse.height=.033
	G.instance(root,mouse,dark,Vector3(.68,.818,-2.14),"ComputerMouse").scale.z=1.5
	box(root,"MouseSeam",Vector3(.001,.002,.026),Vector3(.68,.835,-2.15),cream)
	box(root,"LightSwitch",Vector3(.07,.115,.012),Vector3(.23,1.13,1.898),cream)
	box(root,"SwitchRocker",Vector3(.024,.044,.01),Vector3(.23,1.13,1.887),dark)
	domestic_details(root,cream,dark)
	shelf_books(root)
	# Warm bedside lamp and broad window fill: bounded local lights, no shadows.
	for spec in [[Vector3(-.4,1.0,-2.0),Color("ffd5a0"),.65,2.4],[Vector3(.7,1.8,-2.12),Color("c8deef"),.85,3.3]]:
		var light := OmniLight3D.new()
		light.position=spec[0]
		light.light_color=spec[1]
		light.light_energy=spec[2]
		light.omni_range=spec[3]
		light.shadow_enabled=false
		root.add_child(light)
	var window_light := SpotLight3D.new()
	window_light.name="WindowKeyLight"
	window_light.position=Vector3(.68,1.95,-2.32)
	window_light.basis=Basis.looking_at(Vector3(-.25,-.6,1).normalized(),Vector3.UP)
	window_light.light_color=Color("dae6ef")
	window_light.light_energy=2.2
	window_light.spot_range=4.8
	window_light.spot_angle=65
	window_light.shadow_enabled=true
	root.add_child(window_light)
