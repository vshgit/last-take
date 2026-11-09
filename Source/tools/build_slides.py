from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,json
R=Path(__file__).resolve().parents[1];O=R/'assets/projection/text';O.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(909);background=np.clip(rng.normal(186,1.8,(1024,1536)),0,255).astype('uint8')
for q in [dict(id='blank',text='',type='cards')]+json.loads((R/'content.json').read_text())['questions']:
 if q['type']=='frame':continue
 im=Image.fromarray(background).convert('RGB');d=ImageDraw.Draw(im)
 for size in range(84,48,-2):
  f=ImageFont.truetype(str(R/'assets/sans.ttf'),size);lines=[];line=''
  for word in q['text'].split():
   test=(line+' '+word).strip()
   if line and d.textlength(test,font=f)>1270:lines.append(line);line=word
   else:line=test
  lines.append(line)
  if len(lines)<=5:break
 for i,line in enumerate(lines):d.text((768,480+(i-(len(lines)-1)/2)*(size+22)),line,font=f,fill=(24,24,21),anchor='mm')
 if q['type']=='gesture':d.text((768,876),'ДА — КИВОК   /   НЕТ — ПОВОРОТ ГОЛОВЫ',font=ImageFont.truetype(str(R/'assets/sans.ttf'),36),fill=(50,50,44),anchor='mm')
 im.save(O/(q['id']+'.jpg'),quality=94)
print('SLIDES_READY')
