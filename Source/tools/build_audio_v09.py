from pathlib import Path
import numpy as np,json,subprocess
from scipy.signal import butter,sosfilt
R=Path(__file__).resolve().parents[1];O=R/'assets/audio/environment';SR=24000;rng=np.random.default_rng(909)
def filt(a,cut,kind='lowpass'):return sosfilt(butter(3,cut,fs=SR,btype=kind,output='sos'),a)
def norm(a,db):return a*10**(db/20)/max(1e-8,np.sqrt(np.mean(a*a)))
def fade(a):
 a=a.copy();n=min(240,len(a)//2);a[:n]*=np.linspace(0,1,n);a[-n:]*=np.linspace(1,0,n);return a
report={}
def save(name,a,loop=False):
 subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(SR),'-ac','1','-i','pipe:0','-c:a','libvorbis','-q:a','5',str(O/(name+'.ogg'))],input=a.astype(np.float32).tobytes(),check=True)
 report[name]={'seconds':len(a)/SR,'rms_db':float(20*np.log10(np.sqrt(np.mean(a*a))+1e-10)),'loop':loop}
b=subprocess.check_output(['ffmpeg','-v','error','-i',str(R.parent/'ArtSource/audio-v09/water_drip.mp3'),'-ar',str(SR),'-ac','1','-f','f32le','-']);save('water_drop',fade(norm(filt(np.frombuffer(b,np.float32),[100,1350],'bandpass'),-25)))
t=np.arange(8*SR)/SR;a=.012*np.sin(2*np.pi*96*t)+.006*np.sin(2*np.pi*144*t)
for i in range(8*24):
 n=int(i*SR/24);u=np.arange(int(.026*SR))/SR;tick=filt(rng.normal(size=len(u)),[480,3200],'bandpass')*np.exp(-u*180)*(.017+.006*rng.random());a[n:n+len(tick)]+=tick
save('film_transport',norm(a,-26),True)
a=np.zeros(int(.33*SR))
for start,amount in [(0,1),(.075,.6),(.14,.34)]:
 u=np.arange(int(.1*SR))/SR;tick=filt(rng.normal(size=len(u)),[300,3500],'bandpass')*np.exp(-u*75);n=int(start*SR);a[n:n+len(u)]+=tick*amount
save('slide_click',fade(norm(a,-23)));(O/'manifest_v09.json').write_text(json.dumps(report,indent=2));print('AUDIO_V09_READY')
