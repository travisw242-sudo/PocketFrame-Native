extends RefCounted
## Original synthesized latch/spring sounds, not copied console recordings.
static var cached: Dictionary = {}
static func sound(ejecting: bool) -> AudioStreamWAV:
	if cached.has(ejecting): return cached[ejecting]
	var data := PackedByteArray()
	var rate := 44100
	data.resize(int(rate*.12)*2)
	var noise := 15319
	for i in range(data.size()/2):
		var t := float(i)/rate
		noise=(noise*1103515245+12345)&0x7fffffff
		var n := float(noise)/1073741824.-1.
		var value := 0.0
		for start in [0.,.019 if ejecting else .011]:
			var age: float=t-start
			if age>=0:
				value+=(n*.55+sin(age*TAU*(1900 if ejecting else 2600))*.45)*exp(-age*(220 if ejecting else 300))*.8
		if ejecting: value+=sin(t*TAU*730)*exp(-t*110)*.08
		data.encode_s16(i*2,int(clampf(value,-1,1)*20000))
	var stream := AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=rate
	stream.data=data
	cached[ejecting]=stream
	return stream
