shader_type spatial;
render_mode cull_disabled;
uniform sampler2D plaster : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D plaster_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool ceiling = false;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.)).xyz);}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){
 vec2 uv=abs(world_normal.x)>.5?world_position.zy:world_position.xy;
 if(ceiling){uv=world_position.xz;}
 vec3 concrete=texture(plaster,uv*.64).rgb;
 float broad=noise(uv*1.4)*.65+noise(uv*5.8)*.24+noise(uv*27.)*.11;
 vec2 f=fract(uv*vec2(4.,3.5))-.5;
 float stem=abs(f.x-.10*sin(f.y*12.));
 float leaf=abs(abs(f.x)-.11-.10*sin(f.y*15.));
 float pattern=(1.-smoothstep(.006,.017,stem))+(1.-smoothstep(.006,.024,leaf))*smoothstep(.04,.18,abs(f.y));
 vec3 paper=vec3(.43,.395,.32)*(.85+concrete.r*.25)-pattern*vec3(.027,.027,.021);
 float peel=smoothstep(.67,.715,broad+noise(uv*.65)*.12);
 vec3 plaster_base=concrete*vec3(.70,.72,.68);
 vec3 base=mix(paper,plaster_base,peel);
 float waterline=1.-smoothstep(.12,.75+noise(vec2(uv.x*3.,0.))*.2,world_position.y);
 float damp=waterline*(.22+noise(vec2(uv.x*16.,uv.y*.7))*.30);
 base=mix(base,base*vec3(.42,.46,.40),damp);
 float seam=1.-smoothstep(.0008,.0035,abs(fract(uv.x/.53)-.5));
 base*=1.-seam*.14;
 float crack=pow(1.-abs(sin(uv.x*5.+noise(vec2(uv.y*4.,0))*3.)),120.);
 base*=1.-crack*.19*peel;
 if(ceiling){base=concrete*vec3(.64,.64,.59);base*=1.-smoothstep(.63,.79,broad)*.56;}
 ALBEDO=base;
 NORMAL_MAP=texture(plaster_normal,uv*.64).rgb;
 NORMAL_MAP_DEPTH=ceiling?.55:mix(.13,.62,peel);
 ROUGHNESS=.94;SPECULAR=.20;
}
