import json, urllib.request, base64, time
from pathlib import Path
import websocket
P=Path(__file__).parent
pages=json.load(urllib.request.urlopen('http://localhost:9337/json'))
w=websocket.create_connection(next(p for p in pages if p['type']=='page')['webSocketDebuggerUrl'],origin='http://localhost:9337',timeout=20)
n=0
errors=[]
def call(method,params=None):
 global n
 n+=1; w.send(json.dumps({'id':n,'method':method,'params':params or {}}))
 while True:
  v=json.loads(w.recv())
  if v.get('method')=='Runtime.exceptionThrown': errors.append(v)
  if v.get('id')==n:
   if 'error' in v: raise RuntimeError(v)
   return v.get('result',{})
def js(s): return call('Runtime.evaluate',{'expression':s,'returnByValue':True,'awaitPromise':True}).get('result',{}).get('value')
call('Page.enable');call('Runtime.enable')
results=[]
for name in ['dusk','toybox','emergency']:
 for width in [1440,390]:
  call('Emulation.setDeviceMetricsOverride',{'width':width,'height':1000,'deviceScaleFactor':1,'mobile':False})
  call('Page.navigate',{'url':(P/f'{name}.html').as_uri()})
  for _ in range(40):
   if js("document.readyState === 'complete' && !!document.getElementById('boost')"): break
   time.sleep(.1)
  state=js("({overflow:document.documentElement.scrollWidth>innerWidth,images:[...document.images].every(i=>i.complete&&i.naturalWidth>0),links:[...document.querySelectorAll('nav a')].length})")
  assert not state['overflow'] and state['images'] and state['links']==3,(name,width,state)
  js("document.getElementById('boost').click()")
  assert js("document.getElementById('status').textContent.includes('ACTIVE')")
  js("document.getElementById('boost').click()")
  assert js("document.getElementById('speed').textContent==='00'")
  js("document.getElementById('copy').click()")
  time.sleep(.1)
  assert js("/copied|selected/.test(document.getElementById('feedback').textContent)")
  js("window.exportBlob=null;window.exportName=null;URL.createObjectURL=b=>{window.exportBlob=b;return 'blob:probe'};HTMLAnchorElement.prototype.click=function(){window.exportName=this.download};document.getElementById('export').click()")
  export=js("window.exportBlob.text()")
  assert 'extends RefCounted' in export and 'const ACCENT = Color(' in export
  if width==1440: (P/f'{name}_palette.gd').write_text(export)
  js("document.getElementById('feedback').textContent='Preview only. Game-wide implementation awaits your direction choice.'")
  shot=call('Page.captureScreenshot',{'format':'png','captureBeyondViewport':False})
  (P/'captures'/f'{name}-{width}.png').write_bytes(base64.b64decode(shot['data']))
  results.append({'direction':name,'width':width,'checks':'layout, assets, navigation links, boost/reset, copy fallback, real export Blob'})
assert not errors,errors
(P/'verification.json').write_text(json.dumps({'checks':results,'runtime_errors':errors},indent=2))
print(json.dumps({'views_passed':len(results),'runtime_errors':len(errors)}))
call('Browser.close')
