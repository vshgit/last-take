shader_type canvas_item;
uniform float openness : hint_range(0.0,1.0) = 0.0;
void fragment() {
 float aperture = openness * .88;
 float curve = pow(abs(UV.x-.5)*2.0,2.0)*.16*(1.0-openness);
 float edge = aperture-curve;
 float mask = smoothstep(edge-.018,edge+.012,abs(UV.y-.5));
 if(openness < .015) mask=1.0;
 COLOR=vec4(.006,.003,.002,mask);
}
