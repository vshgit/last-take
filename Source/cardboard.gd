extends RefCounted

static func build(g, text_texture: Texture2D, variant: int) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width = .30
	var depth = .19
	var nx = 16
	var nz = 10
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for j in range(nz+1):
		for i in range(nx+1):
			var u = float(i)/nx
			var v = float(j)/nz
			var edge = minf(minf(u,1-u),minf(v,1-v))
			var fray = sin(i*12.73+j*7.21+variant)*.0007 if edge < .001 else 0.0
			var curl = pow(maxf(0.0,(u-.76)/.24),2)*pow(maxf(0.0,(.30-v)/.30),2)*.010
			points.append(Vector3((u-.5)*width+fray,.003+curl+sin(u*PI)*sin(v*PI)*.0008,(v-.5)*depth+fray))
	# Smooth the continuous sheet, including the lifted corner. Explicit normals
	# avoid hard facets where SurfaceTool splits vertices along UV boundaries.
	for j in range(nz+1):
		for i in range(nx+1):
			var dx = points[j*(nx+1)+mini(i+1,nx)]-points[j*(nx+1)+maxi(i-1,0)]
			var dz = points[mini(j+1,nz)*(nx+1)+i]-points[maxi(j-1,0)*(nx+1)+i]
			normals.append(dz.cross(dx).normalized())
	for j in range(nz):
		for i in range(nx):
			var a=j*(nx+1)+i
			for k in [a,a+1,a+nx+1,a+1,a+nx+2,a+nx+1]:
				st.set_uv(Vector2(float(k%(nx+1))/nx,float(floori(float(k)/(nx+1)))/nz))
				st.set_normal(normals[k])
				st.add_vertex(points[k])
	st.index()
	st.generate_tangents()
	var mesh = MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat = g._mat(Color("c5c3bd"),.95)
	mat.albedo_texture = text_texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.metallic_specular = .2
	mesh.material_override = mat
	# Real cardboard core and a dark inner edge, not a zero-thickness plane.
	g._box(Vector3(width-.001,.0028,depth-.001),Vector3(0,.001,0),g._mat(Color("8d724a")),mesh,false)
	return mesh
