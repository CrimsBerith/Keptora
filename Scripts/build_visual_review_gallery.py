#!/usr/bin/env python3
"""Build an offline per-file review gallery; no image manipulation."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / 'Docs/Product/VISUAL_REGENERATION_MANIFEST.json').read_text())
data = json.dumps(manifest['assets'], ensure_ascii=False).replace('<', '\\u003c')
page = '''<!doctype html>
<html lang="tr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Keptora · 67 görsel incelemesi</title>
<style>
*{box-sizing:border-box}[hidden]{display:none!important}body{margin:0;background:#f5f3ff;color:#191338;font:16px/1.5 system-ui,sans-serif}
main{max-width:1280px;margin:auto;padding:24px}h1{font-size:28px;margin:0}p{margin:8px 0}
.notice{background:#fff2d7;border-radius:12px;padding:14px;margin:16px 0;color:#513708}
nav{display:flex;flex-wrap:wrap;gap:10px;margin:18px 0;align-items:center}
button,select,input{font:inherit;min-height:44px;border:1px solid #d4cceb;border-radius:10px;padding:8px 14px;background:white;color:#251b52}
button{cursor:pointer}button:disabled{opacity:.4;cursor:default}button:focus-visible,select:focus-visible,input:focus-visible,a:focus-visible{outline:3px solid #5747ed;outline-offset:3px}
select{max-width:100%}#jump{flex:1;min-width:220px}#viewer{background:white;min-height:280px;padding:24px;border:1px solid #ddd7ee;border-radius:18px;display:flex;align-items:center;justify-content:center}
#viewer.dark{background:#211c35}#picture{max-width:100%;max-height:72vh;object-fit:contain;display:block}#picture.magnified{image-rendering:pixelated}
#negative{max-width:650px;padding:32px;background:#fff2d7;color:#513708;border-radius:12px}
#filename{overflow-wrap:anywhere;font-size:18px}#badge{display:inline-block;background:#e8e2ff;color:#352277;padding:4px 10px;border-radius:8px;font-weight:600}
#sha{overflow-wrap:anywhere;font:12px/1.5 ui-monospace,monospace}a{color:#4433b4}footer{margin-top:16px}
@media(max-width:600px){main{padding:14px}h1{font-size:23px}#viewer{padding:10px}#jump{width:100%;flex-basis:100%}}
</style>
<main><h1>Keptora · 67 görsel incelemesi</h1><p>2026-10-03 · Her dosyanın ayrı inceleme kaydı. Ok tuşlarıyla gezebilirsin.</p>
<p class="notice">12 ekran, <strong>tasarım önizlemesidir</strong>. Gerçek native uygulama çekimi veya App Store onayı değildir. Bozuk JPEG yalnızca negatif test olarak kabul edildi.</p>
<nav aria-label="Görsel gezinme"><button id="prev">← Önceki</button><button id="next">Sonraki →</button>
<label>Tür <select id="kind"><option value="">Tümü</option><option value="icon">İkon / logo</option><option value="illustration">İllüstrasyon</option><option value="corpus">Test fotoğrafı</option><option value="screen">Ekran önizlemesi</option></select></label>
<select id="jump" aria-label="Dosya seç"></select><button id="background">Zemin değiştir</button><button id="zoom" aria-pressed="false">Küçük ikonu büyüt</button></nav>
<p id="position" aria-live="polite"></p><h2 id="filename"></h2><p id="badge"></p><p id="notes"></p>
<div id="viewer"><img id="picture" alt=""><div id="negative" hidden>Bu JPEG kasıtlı kesilmiştir. Görüntülenmesi beklenmez; decoder hata davranışı doğrulandı. Görsel güzellik onayı verilmez.</div></div>
<footer><a id="original" target="_blank" rel="noopener">Dosyayı aç</a> · <a href="VISUAL_REGENERATION_REVIEW.md">İnceleme raporu</a> · <a href="VISUAL_REGENERATION_MANIFEST.json">Tam kabul kaydı</a><p id="dimensions"></p><p id="sha"></p></footer></main>
<script id="assets" type="application/json">DATA</script>
<script>
const all=JSON.parse(document.getElementById('assets').textContent);
const $=id=>document.getElementById(id);
let filtered=all, index=0, magnified=false;
const labels={accepted_asset:'Görsel kabul',accepted_design_preview_only:'Yalnızca tasarım önizlemesi kabulü',accepted_negative_fixture:'Negatif test kabulü'};
function options(){ $('jump').replaceChildren(...filtered.map((a,i)=>{const o=document.createElement('option');o.value=i;o.textContent=(all.indexOf(a)+1)+'. '+a.path;return o})); }
function render(){const a=filtered[index],negative=a.visual_review.status==='accepted_negative_fixture';
 $('position').textContent=(index+1)+' / '+filtered.length+' · Genel sıra '+(all.indexOf(a)+1)+' / 67';
 $('filename').textContent=a.path;$('badge').textContent=labels[a.visual_review.status];$('notes').textContent=a.visual_review.notes;
 $('prev').disabled=index===0;$('next').disabled=index===filtered.length-1;$('jump').value=index;
 $('picture').hidden=negative;$('negative').hidden=!negative;
 if(negative){$('picture').removeAttribute('src')}else{$('picture').src='../../'+encodeURI(a.path);$('picture').alt=a.visual_review.notes}
 $('original').href='../../'+encodeURI(a.path);
 $('dimensions').textContent=a.pixels?a.pixels.join(' × ')+' px · '+a.bytes.toLocaleString('tr-TR')+' bayt':'64 bayt · kasıtlı geçersiz JPEG';
 $('sha').textContent='İncelenen SHA-256: '+a.visual_review.reviewed_sha256;
 const small=a.pixels&&a.pixels[0]<=128;$('zoom').disabled=!small;
 $('picture').classList.toggle('magnified',magnified&&small);
 $('picture').style.width=magnified&&small?Math.min(512,a.pixels[0]*8)+'px':'';
 $('picture').style.height='';
}
function move(delta){index=Math.max(0,Math.min(filtered.length-1,index+delta));render()}
$('prev').onclick=()=>move(-1);$('next').onclick=()=>move(1);$('jump').onchange=e=>{index=Number(e.target.value);render()};
$('kind').onchange=e=>{filtered=all.filter(a=>!e.target.value||a.kind===e.target.value);index=0;options();render()};
$('background').onclick=()=>$('viewer').classList.toggle('dark');
$('zoom').onclick=()=>{magnified=!magnified;$('zoom').setAttribute('aria-pressed',String(magnified));render()};
document.addEventListener('keydown',e=>{if(['SELECT','INPUT','TEXTAREA'].includes(e.target.tagName))return;if(e.key==='ArrowRight'){e.preventDefault();move(1)}if(e.key==='ArrowLeft'){e.preventDefault();move(-1)}});
options();render();
</script></html>
'''
(ROOT / 'Docs/Product/VISUAL_GALLERY.html').write_text(page.replace('DATA', data), encoding='utf-8')
print('Built offline gallery for 67 individually reviewed paths.')
