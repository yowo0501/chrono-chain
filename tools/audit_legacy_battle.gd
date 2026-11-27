extends SceneTree
const ROOT = "res://assets/character_overhaul/2026-11-24/legacy_retarget/"
func _initialize():
	var manifest = []
	var sources = {"chuheun-source.png":[4,2],"yeonwoo-source.png":[4,2],"chuheun-motion-source.png":[4,4],"yeonwoo-motion-source.png":[4,4],"chuheun-expressive-source.png":[4,4],"yeonwoo-expressive-source.png":[4,4],"chuheun-idle-calm-source.png":[3,2],"yeonwoo-windup-fixed-source.png":[1,1]}
	for file in DirAccess.get_files_at(ROOT+"reference/battle"):
		var path = ROOT+"reference/battle/"+file
		var item = {"path":"reference/battle/"+file,"sha256":FileAccess.get_sha256(path),"bytes":FileAccess.get_file_as_bytes(path).size()}
		if file.ends_with(".png"):
			var im = Image.load_from_file(ProjectSettings.globalize_path(path))
			item["size"] = [im.get_width(),im.get_height()]
			if sources.has(file):
				item["role"] = "original pre-character-sheet design reference"
				var grid = sources[file]
				item["grid"] = grid
				item["frames"] = []
				# Source measurement only: nominal cells are retained and edge contact is reported.
				for f in grid[0]*grid[1]:
					var w = im.get_width()/grid[0]
					var h = im.get_height()/grid[1]
					var minx=w
					var miny=h
					var maxx=0
					var maxy=0
					var area=0
					for y in h:
						for x in w:
							if im.get_pixel(f%grid[0]*w+x,f/grid[0]*h+y).a>=0.6:
								minx=mini(minx,x);miny=mini(miny,y);maxx=maxi(maxx,x);maxy=maxi(maxy,y);area+=1
					item.frames.append({"frame":f,"bounds":[minx,miny,maxx-minx+1,maxy-miny+1],"opaque_area":area,"aspect":float(maxy-miny+1)/maxi(1,maxx-minx+1),"touches_nominal_cell_edge":minx==0 or miny==0 or maxx==w-1 or maxy==h-1})
			else: item["role"] = "historical supporting asset or later costume refresh; inspect before treating as original design"
		manifest.append(item)
	FileAccess.open(ROOT+"metadata/recovered_manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"  "))
	print("RECOVERED: %d archived battle assets with hashes and original frame measurements"%manifest.size())
	quit()
