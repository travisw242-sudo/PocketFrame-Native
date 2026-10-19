extends RefCounted
## Read-only, bounded NCSD/NCCH -> ExeFS icon reader. Never loads a ROM into RAM.
## Format references: 3dbrew NCSD, NCCH and SMDH. No decryption/key handling.
const FORMATS := ["cci", "3ds", "cxi", "3dsx", "app"]

static func _read(file: FileAccess, offset: int, count: int) -> PackedByteArray:
	if offset < 0 or count < 0 or offset+count > file.get_length(): return PackedByteArray()
	file.seek(offset)
	return file.get_buffer(count)

static func _text(data: PackedByteArray, start: int, count: int) -> String:
	var result := ""
	for i in range(count):
		var code := data.decode_u16(start+i*2)
		if code==0: break
		if code in [9,10,13]: result+=" ";continue
		if code>=32 and not (code>=0xD800 and code<=0xDFFF): result+=String.chr(code)
	return result.strip_edges()

static func read_game(path: String) -> Dictionary:
	var label := path.get_file().get_basename().replace("_"," ")
	var result := {"display_name":label,"icon":null,"product_code":"","art_source":"title label"}
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null: return result
	var header := _read(file,0,512)
	if header.size()!=512: return result
	var base := 0
	if header.slice(0x100,0x104).get_string_from_ascii()=="NCSD":
		base=int(header.decode_u32(0x120))*512
		header=_read(file,base,512)
	if header.size()!=512 or header.slice(0x100,0x104).get_string_from_ascii()!="NCCH": return result
	result.product_code=header.slice(0x150,0x160).get_string_from_ascii().strip_edges()
	# Encrypted metadata is not guessed or searched across a multi-GB file.
	if (header[0x18F]&4)==0 or header[0x18E]>8: return result
	var unit := 512 << header[0x18E]
	var exefs := base+int(header.decode_u32(0x1A0))*unit
	var exe_size := int(header.decode_u32(0x1A4))*unit
	var table := _read(file,exefs,512)
	if table.size()!=512 or exe_size<512: return result
	for i in range(8):
		var section := table.slice(i*16,i*16+4).get_string_from_ascii()
		if section!="icon": continue
		var offset := int(table.decode_u32(i*16+8))
		var size := int(table.decode_u32(i*16+12))
		if size<0x36C0 or offset+512+0x36C0>exe_size: return result
		var smdh := _read(file,exefs+512+offset,0x36C0)
		if smdh.size()!=0x36C0 or smdh.slice(0,4).get_string_from_ascii()!="SMDH": return result
		var title := _text(smdh,8+0x200,0x40) # English; fallback Japanese then filename.
		var long_title := _text(smdh,8+0x200+0x80,0x80)
		if not long_title.is_empty(): title=long_title
		if title.is_empty(): title=_text(smdh,8,0x40)
		if not title.is_empty(): result.display_name=title.replace("\n"," ")
		var image := Image.create(48,48,false,Image.FORMAT_RGB8)
		for y in range(48):
			for x in range(48):
				var morton := 0
				for bit in range(3):
					morton |= ((x>>bit)&1)<<(bit*2)
					morton |= ((y>>bit)&1)<<(bit*2+1)
				var index := ((y/8)*6+x/8)*64+morton
				var pixel := smdh.decode_u16(0x24C0+index*2)
				image.set_pixel(x,y,Color(float((pixel>>11)&31)/31.,float((pixel>>5)&63)/63.,float(pixel&31)/31.))
		result.icon=ImageTexture.create_from_image(image)
		result.art_source="embedded game icon"
		break
	return result
