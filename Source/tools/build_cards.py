"""Typeset the actual answer strings on reproducible, worn index-card stock."""
from pathlib import Path
import json, io
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
W, H = 1024, 640
for q in json.loads((ROOT/'content.json').read_text())['questions']:
    if q['type']=='gesture':continue
    assert len(q['options']) == 3, 'Every question must have exactly three answers'
    for i, answer in enumerate(q['options']):
        if (ROOT/f'assets/cards/q{q["asset_index"]:02}_{i}.jpg').exists():continue
        rng = np.random.default_rng(6000 + q['asset_index']*8 + i)
        y,x = np.mgrid[:H,:W]
        edge = np.minimum.reduce([x, W-1-x, y, H-1-y])
        grain = rng.normal(0, 2.2, (H,W))
        blotch = 3*np.sin(x/74+y/132)+2*np.cos(x/137-y/61)
        wear = 17*np.exp(-edge/18)
        stock=np.clip(np.array([191,169,126])[None,None,:]+(grain+blotch-wear)[:,:,None],0,255).astype('uint8')
        im=Image.fromarray(stock)
        d=ImageDraw.Draw(im)
        for _ in range(2200):
            px=int(rng.integers(W));py=int(rng.integers(H))
            col=(int(rng.integers(135,180)),int(rng.integers(119,152)),int(rng.integers(83,113)))
            d.line((px,py,px+int(rng.integers(2,10)),py+1),fill=col,width=1)
        # Printed frame and scuffed edges; the answer remains high contrast.
        ink=(39,35,27); faded=(112,88,60)
        small=ImageFont.truetype(str(ROOT/'assets/sans.ttf'),22)
        num=ImageFont.truetype(str(ROOT/'assets/sans.ttf'),56)
        d.text((54,40),str(i+1).zfill(2),font=num,fill=ink)
        d.text((W-55,63),'КИНОАРХИВ',anchor='rm',font=small,fill=faded)
        d.line((56,119,W-56,119),fill=faded,width=2)
        for size in range(80,27,-2):
            font=ImageFont.truetype(str(ROOT/'assets/serif.ttf'),size)
            lines=[];line=''
            for word in answer.split():
                test=(line+' '+word).strip()
                if line and d.textlength(test,font=font)>W-135:
                    lines.append(line);line=word
                else:line=test
            lines.append(line)
            if len(lines)<=4 and max(d.textlength(line,font=font) for line in lines)<W-120:break
        for row,line in enumerate(lines):
            d.text((W/2,318+(row-(len(lines)-1)/2)*(size+15)),line,anchor='mm',font=font,fill=ink)
        d.line((56,H-107,W-56,H-107),fill=faded,width=1)
        d.text((56,H-77),'ПОСЛЕДНИЙ ДУБЛЬ',font=small,fill=faded)
        d.text((W-56,H-66),f'{q["asset_index"]+1:03} / {i+1}',anchor='rm',font=small,fill=faded)
        for _ in range(110):
            px=int(rng.integers(W));py=int(rng.choice([rng.integers(0,15),H-rng.integers(1,16)]))
            d.line((px,py,px+int(rng.integers(2,19)),py),fill=(220,204,170),width=1)
        buffer=io.BytesIO()
        im.save(buffer,format='JPEG',quality=92)
        (ROOT/f'assets/cards/q{q["asset_index"]:02}_{i}.jpg').write_bytes(buffer.getvalue())
print('Typeset',sum(len(q['options']) for q in json.loads((ROOT/'content.json').read_text())['questions']),'answer cards')
