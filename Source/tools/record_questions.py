"""Record only newly added question IDs with the prototype's existing voice."""
from pathlib import Path
import json,wave,subprocess,tempfile,sys,math
import numpy as np
import onnxruntime
onnxruntime.disable_telemetry_events()
from piper import PiperVoice,SynthesisConfig
ROOT=Path(__file__).resolve().parents[1]
voice=PiperVoice.load(sys.argv[1])
audio=ROOT/'assets/audio';data=json.loads((ROOT/'content.json').read_text());meta=json.loads((audio/'voice_meta.json').read_text())
with tempfile.TemporaryDirectory() as temp:
 temp=Path(temp)
 for q in data['questions']+[dict(voice_id=line['id'],text=line['text']) for line in data['intro']+data['lines']]:
  key=q['voice_id']
  if key in meta:continue
  raw=temp/(key+'.wav');processed=temp/(key+'_p.wav')
  with wave.open(str(raw),'wb') as f:voice.synthesize_wav(q['text'],f,syn_config=SynthesisConfig(length_scale=1.09,noise_scale=.60,noise_w_scale=.70))
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(raw),'-af','asetrate=22050*0.93,aresample=22050,atempo=1.07527,highpass=f=75,lowpass=f=6500,acompressor=threshold=0.2:ratio=2:attack=10:release=100',str(processed)],check=True)
  with wave.open(str(processed),'rb') as f:samples=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').copy()
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(processed),'-af','aecho=0.8:0.7:37:0.10,alimiter=limit=0.95','-c:a','libvorbis','-q:a','4',str(audio/(key+'.ogg'))],check=True)
  envelope=[float(np.sqrt(np.mean(samples[i:i+882].astype(float)**2))) for i in range(0,len(samples),882)];maximum=max(float(np.percentile(envelope,95)),100)
  meta[key]={'duration':len(samples)/22050,'envelope':[round(min(1,x/maximum),3) for x in envelope],'hz':25}
  (audio/'voice_meta.json').write_text(json.dumps(meta))
  print(key,round(meta[key]['duration'],2),flush=True)
 # A quiet periodic hum, without the old broadband noise. Disabled by default.
 t=np.arange(22050*12)/22050;samples=(np.sin(t*math.tau*50)*.006+np.sin(t*math.tau*100)*.0015)
 hum=temp/'room_clean.wav'
 with wave.open(str(hum),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(22050);f.writeframes((samples*32767).astype('<i2').tobytes())
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(hum),'-af','lowpass=f=180','-c:a','libvorbis','-q:a','4',str(audio/'room.ogg')],check=True)
(audio/'voice_meta.json').write_text(json.dumps(meta))
print('AUDIO_READY',len(meta),flush=True)
