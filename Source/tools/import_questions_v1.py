from pathlib import Path
from lxml import etree
from PIL import Image
from concurrent.futures import ThreadPoolExecutor
import io,json,re,zipfile,urllib.request,sys
R=Path(__file__).resolve().parents[1];doc=Path(sys.argv[1])
d=json.loads((R/'content.json').read_text());old={q['id']:q for q in d['questions']}
ns={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main','r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
rows=[];level=0;kind='';q=None
with zipfile.ZipFile(doc) as z:
 rels={e.get('Id'):e.get('Target') for e in etree.fromstring(z.read('word/_rels/document.xml.rels'))}
 for p in etree.fromstring(z.read('word/document.xml')).xpath('//w:body/w:p',namespaces=ns):
  t=''.join(p.xpath('.//w:t/text()',namespaces=ns)).strip()
  if t.startswith('Блок '):level=int(t[5]);q=None;continue
  if re.match(r'^[1-4] (Текстовые|Вопросы)',t):kind={'1':'cards','2':'gesture','3':'frame','4':'audio'}[t[0]];q=None;continue
  m=re.match(r'^(\d{3})\. (.+)',t)
  if m:q={'document_number':int(m[1]),'level':level,'type':kind,'text':m[2],'options':[],'notes':[],'links':[],'embeds':[]};rows.append(q)
  elif q:
   if t.startswith('ID:'):q['id']=t[4:].split('  •')[0].strip();q['category']=t.split('Тема в игре:')[-1].strip()
   elif re.match(r'^[АБВ]\)',t):q['options'].append(t[3:].strip())
   elif t.startswith('Правильный ответ:'):q['answer']=t.split(':',1)[1].strip()
   elif t.startswith('Планируемый игровой файл:') or t.startswith('Изображение: assets/'):q['image_path']=t.split(':',1)[1].strip().split(' (')[0]
   elif t.startswith('Аудиофайл для вычитки:'):q['audio_file']=t.split(':',1)[1].strip().split(' (')[0]
   elif t:q['notes'].append(t)
  if q:
   for h in p.xpath('.//w:hyperlink',namespaces=ns):q['links'].append({'label':t,'url':rels[h.get('{'+ns['r']+'}id')]})
   for rid in p.xpath('.//@r:embed',namespaces=ns):
    member='word/'+rels[rid];dest=R/'assets/projection/document'/Path(member).name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(z.read(member));q['embeds'].append('res://'+str(dest.relative_to(R)))
assert len(rows)==216
norm=lambda s:re.sub(r'[«»„“”".\s—–-]','',s).casefold()
for i,q in enumerate(rows):
 q.setdefault('id',f'document_{q["document_number"]:03}');q.setdefault('category','история кино');q['asset_index']=i;p=old.get(q['id'],{})
 if q['type']=='gesture':q['options']=['Нет','Да']
 answer=q.pop('answer');m=re.match(r'^([АБВ])\)',answer)
 if m:q['correct']='АБВ'.index(m[1])
 else:
  matches=[i for i,x in enumerate(q['options']) if norm(x)==norm(answer)];assert len(matches)==1,(q,answer);q['correct']=matches[0]
 assert len(q['options'])==(2 if q['type']=='gesture' else 3)
 q['topic']=p.get('topic',q['id']);q['source']=q['links'][0]['url'] if q['links'] else p.get('source',doc.name)
 q['fact']='Правильный ответ: '+q['options'][q['correct']]
 q['voice_id']=p['voice_id'] if p.get('text')==q['text'] else 'v1_'+q['id']
 if q['type']=='frame':
  if q['embeds']:q['image']=q['embeds'][0];q['media_status']='supplied_document'
  elif q.get('image_path') and (R/q['image_path']).exists():q['image']='res://'+q['image_path'];q['media_status']='existing_game'
  else:q['image']='res://assets/projection/document/'+q['id']+'.jpg';q['media_status']='pending_download'
 if q['type']=='audio':q['audio']='res://assets/audio/questions/'+q['audio_file'];q['media_status']='supplied_demo'
assert len({q['id'] for q in rows})==216
with zipfile.ZipFile(sys.argv[2]) as z:
 (R/'assets/audio/questions').mkdir(exist_ok=True)
 for q in rows:
  if q['type']=='audio':(R/'assets/audio/questions'/q['audio_file']).write_bytes(z.read(q['audio_file']))
fallback={
'easy_image_01':'https://m.media-amazon.com/images/M/MV5BMjk5Y2E2YmUtMTQ0MS00YmU4LWJlM2UtMTdiMGZhMmExY2ZmXkEyXkFqcGc%40._V1_.jpg',
'hard_image_k13':'https://kinorotterdam.nl/content/uploads/2023/04/A-Clockwork-Orange-06.webp',
'hard_image_k14':'https://cdn2.bigcommerce.com/server4900/364bb/products/241064/images/192526/e6039ce7-a767-5600-aaa4-c9d07a846d95__42973.1659946541.1280.1280.jpg?c=2',
'hard_image_k19':'https://cdni.fancaps.net/file/fancaps-movieimages/549923.jpg'}
def fetch(q):
 if q.get('media_status')!='pending_download':return
 try:
  url=fallback.get(q['id']) or next(x['url'] for x in q['links'] if x['label'].startswith(('Изображение:','Кадр:')))
  with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=40) as r:im=Image.open(io.BytesIO(r.read())).convert('RGB')
  im.thumbnail((1536,1024));im.save(R/q['image'][6:],quality=92)
  q['resolved_image_url']=url;q['media_status']='replacement_same_film' if q['id'] in fallback else 'downloaded_document_link'
  print(q['id'],'OK',flush=True)
 except Exception as e:q['media_status']='missing_image';q['media_error']=str(e);print(q['id'],'FAILED',e,flush=True)
with ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(fetch,rows))
d['questions']=rows;d['version']='1.0'
d['intro'][2]={'id':'intro_rules_v1','text':'Восемнадцать секунд. Ошибёшься — новый дубль. Три ошибки — конец. Дойдёшь до финала — отпущу.','action':'timer'}
for line in d['lines']:
 if line['id']=='retake':line['text']='Нет. Будет дубль.'
 if line['id']=='wrong':line.update(id='wrong_v1',text='Третья ошибка. Сеанс окончен.');line.pop('parts',None)
d['session_rules']={'levels':3,'questions_per_level':7,'lives':3,'wrong_answer':'advance','timeout':'lose_life_and_advance','mixes':[{'cards':2,'gesture':2,'frame':3},{'cards':2,'gesture':2,'frame':3},{'cards':2,'gesture':1,'frame':2,'audio':2}]}
(R/'content.json').write_text(json.dumps(d,ensure_ascii=False,indent=2))
print('MISSING',[(q['id'],q.get('media_error')) for q in rows if q.get('media_status')=='missing_image'])
