extends RefCounted
const IDS: Array[String] = ["balanced","sharp","ultra"]
const LABELS: Array[String] = ["Balanced · 1×","Sharp · 2× (recommended)","Ultra · 3× (experimental)"]
static func factor(value: String) -> int:
	return 3 if value=="ultra" else 2 if value=="sharp" else 1
static func index(value: String) -> int:
	return maxi(0,IDS.find(value))
