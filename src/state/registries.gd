class_name Registries
## Lo que comparten FlagRegistry e ItemDatabase.


static func duplicates(ids: Array) -> Array[StringName]:
	var seen := {}
	var repeated: Array[StringName] = []
	for id: StringName in ids:
		if seen.has(id) and not repeated.has(id):
			repeated.append(id)
		seen[id] = true
	return repeated
