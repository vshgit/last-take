"""Rebuild the v0.8 soundscape from included CC0 previews and original synthesis.
Requires numpy, scipy and ffmpeg. Run from any directory; ArtSource is beside Source.
"""
from pathlib import Path
import subprocess,json
import numpy as np
from scipy.signal import butter,sosfilt
R=Path(__file__).resolve().parents[1];SRC=R.parent/'ArtSource/audio-v08';OUT=R/'assets/audio/environment';OUT.mkdir(parents=True,exist_ok=True)
SR=24000;rng=np.random.default_rng(808)
def decode(name):
    b=subprocess.check_output(['ffmpeg','-v','error','-i',str(SRC/(name+'.mp3')),'-ar',str(SR),'-ac','1','-f','f32le','-'])
    return np.frombuffer(b,np.float32).copy()
def filt(a,cut,kind='lowpass',order=3):return sosfilt(butter(order,cut,fs=SR,btype=kind,output='sos'),a)
def norm(a,db=-19):return a*10**(db/20)/max(1e-8,np.sqrt(np.mean(a*a)))
def fade(a,start=.02,end=.05):
    a=a.copy();n=min(len(a),int(start*SR));m=min(len(a),int(end*SR));a[:n]*=np.linspace(0,1,n);a[-m:]*=np.linspace(1,0,m);return a
report={}
def save(name,a,loop=False):
    peak=float(np.max(np.abs(a)))
    if peak>.89:a=a*.89/peak
    subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(SR),'-ac','1','-i','pipe:0','-c:a','libvorbis','-q:a','5',str(OUT/(name+'.ogg'))],input=a.astype(np.float32).tobytes(),check=True)
    report[name]={'seconds':len(a)/SR,'rms_db':float(20*np.log10(np.sqrt(np.mean(a*a))+1e-10)),'peak_db':float(20*np.log10(max(abs(a))+1e-10)),'loop':loop}
def seamless(a,seconds=2):
    n=int(seconds*SR);w=np.linspace(0,1,n);return np.concatenate((a[n:-n],a[-n:]*(1-w)+a[:n]*w))
breath=filt(decode('breathing'),[100,3400],'bandpass')
save('breathing_wake',fade(norm(breath[int(.35*SR):int(7.35*SR)],-19),.25,1.8))
save('breathing_late',fade(norm(breath[int(8.05*SR):int(15.25*SR)],-19),.2,1.6))
sniff=filt(decode('sniff'),[170,3800],'bandpass')
for i,(a,b) in enumerate([(7.12,7.75),(4.39,4.92)]):save('sniff_%d'%i,fade(norm(sniff[int(a*SR):int(b*SR)],-20),.015,.08))
steps=filt(decode('steps'),[70,1150],'bandpass')
for i,(a,b) in enumerate([(.52,.92),(1.34,1.77),(2.05,2.49)]):save('step_%d'%i,fade(norm(steps[int(a*SR):int(b*SR)],-18),.012,.08))
# Real cars and conversational fragments, low-pass filtered as heard through glass.
city=filt(decode('city'),[70,820],'bandpass');city=np.tanh(city*4)/4
city=norm(seamless(city,3),-23)
# Occasional muffled two-tone car horns embedded in the seamless field recording.
for begin,duration,freq in [(18.5,.32,370),(49.2,.65,330),(87.8,.23,390),(135.6,.43,350),(182.4,.28,400)]:
    t=np.arange(int(duration*SR))/SR;horn=np.sin(2*np.pi*freq*t)+.65*np.sin(2*np.pi*freq*1.25*t)+.15*np.sin(2*np.pi*freq*2*t)
    horn=fade(horn*.023,.04,.12);i=int(begin*SR);city[i:i+len(horn)]+=horn
save('city_behind_glass',city,True)
t=np.arange(12*SR)/SR
hum=.75*np.sin(2*np.pi*100*t)+.28*np.sin(2*np.pi*50*t)+.1*np.sin(2*np.pi*200*t)
save('bulb_hum',norm(hum,-30),True)
# Wing beat plus narrow-band air noise; endpoints crossfaded for click-free looping.
t=np.arange(9*SR)/SR;phase=2*np.pi*np.cumsum(191+12*np.sin(2*np.pi*.7*t)+5*np.sin(2*np.pi*2*t))/SR
buzz=(np.sin(phase)+.33*np.sin(phase*2)+.12*np.sin(phase*3))*(.8+.13*np.sin(2*np.pi*7*t))
buzz+=filt(rng.normal(size=len(t)),[750,2500],'bandpass')*.3
save('fly_buzz',norm(seamless(buzz,.5),-22),True)
# Short hollow water impact with damped resonances, rather than a UI beep.
t=np.arange(int(.72*SR))/SR
drop=np.sin(2*np.pi*(900*t+180*t*t))*np.exp(-t*35)+.55*np.sin(2*np.pi*1430*t)*np.exp(-t*29)
drop+=filt(rng.normal(size=len(t)),2200)*np.exp(-t*65)*.2
for delay,amount in [(.062,.24),(.137,.11),(.231,.055)]:
    n=int(delay*SR);drop[n:]+=drop[:-n]*amount
save('water_drop',fade(norm(drop,-22),.002,.06))
# Original dry double mechanical click: spring catch then hammer latch.
cock=np.zeros(int(.36*SR))
for start,level,freq in [(.012,1,2600),(.155,.7,1950)]:
    t=np.arange(int(.11*SR))/SR;click=(filt(rng.normal(size=len(t)),[700,5300],'bandpass')+.25*np.sin(2*np.pi*freq*t))*np.exp(-t*62)
    n=int(start*SR);cock[n:n+len(t)]+=fade(click*level,.001,.01)
save('hammer_cock',norm(cock,-22))
(OUT/'manifest.json').write_text(json.dumps(report,indent=2))
print('AUDIO_V08_BUILT',len(report),'streams')
