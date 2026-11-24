extends RefCounted
## Stable metal links on one authored path, never a sinusoidal rope.
static func axis8(delta: Vector2) -> Vector2:
	if delta.length_squared() < 0.001:
		return Vector2.RIGHT
	var step := roundi(delta.angle()/(PI/4.0))
	return Vector2(cos(step*PI/4.0),sin(step*PI/4.0)).snapped(Vector2(0.000001,0.000001)).normalized()
static func draw_links(canvas: CanvasItem, points: PackedVector2Array, scale: float = 1.0, tint: Color = Color.WHITE) -> void:
	if points.size() < 2:
		return
	var next := 0.0
	var traveled := 0.0
	var index := 0
	for i in range(1,points.size()):
		var span := points[i]-points[i-1]
		var length := span.length()
		if length < 0.001:
			continue
		var forward := span/length
		var side := forward.orthogonal()
		while next <= traveled+length:
			var center := points[i-1]+forward*(next-traveled)
			if index%2 == 0:
				var ring := PackedVector2Array()
				for n in 9:
					var angle := n*TAU/8
					ring.append((center+forward*cos(angle)*2.0*scale+side*sin(angle)*0.95*scale).round())
				canvas.draw_polyline(ring,Color("172642")*tint,maxf(1.0,2.0*scale))
				canvas.draw_polyline(ring,Color("88b1d8")*tint,maxf(1.0,0.75*scale))
			else:
				canvas.draw_line((center-forward*1.8*scale).round(),(center+forward*1.8*scale).round(),Color("bfdaf0")*tint,maxf(1.0,scale))
			next += 3.0*scale
			index += 1
		traveled += length

