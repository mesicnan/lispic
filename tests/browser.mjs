// Exercise responsive layout, cross-origin previews, PhotoSwipe, and no-JS links.
// Run against `lispic serve --config ../content/site.sexp`.
import assert from 'node:assert/strict';
const {chromium}=await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const browser=await chromium.launch({headless:true});
const errors=[];
for(const width of [1440,390]) {
 const page=await browser.newPage({viewport:{width,height:1000}});
 page.on('pageerror',e=>errors.push(e.message));
 page.on('response',r=>{if(r.status()>=400)errors.push(`${r.status()} ${r.url()}`);});
 for(const url of ['http://localhost:8000/','http://localhost:8000/clanky/podzim-za-mestem/',
  'http://localhost:8001/','http://localhost:8001/alba/podzim-za-mestem/']) {
  await page.goto(url,{waitUntil:'networkidle'});
  assert.equal(await page.locator('h1').count(),1);
  const status=await page.evaluate(()=>({overflow:document.documentElement.scrollWidth>innerWidth+1,
    production:[...document.querySelectorAll('a[href],img[src]')].some(n=>/https:\/\/(blog|foto)\.example\.cz/.test(n.href||n.src)),
    broken:[...document.images].filter(i=>i.complete && !i.naturalWidth).length}));
  assert.deepEqual(status,{overflow:false,production:false,broken:0},url);
  if(await page.locator('.photo-grid').count()) {
   await page.waitForSelector('.photo-grid.positioned');
   const boxes=await page.locator('.photo-grid').first().evaluate(grid=>[...grid.children].map(t=>{
    const r=t.getBoundingClientRect(); return {x:r.x,y:r.y,w:r.width,h:r.height,ratio:Number(t.dataset.ratio)};
   }));
   for(const b of boxes) assert.ok(Math.abs(b.w/b.h-b.ratio)<.02);
   await page.locator('.photo-grid a.zoom').first().click();
   await page.waitForFunction(()=>window.pswp?.opener.isOpen);
   assert.equal(await page.evaluate(()=>window.pswp.currIndex),0);
   await page.keyboard.press('ArrowRight');
   await page.waitForFunction(()=>window.pswp.currIndex===1);
   await page.getByRole('button',{name:'Zavřít',exact:true}).click();
   await page.waitForSelector('.pswp--open',{state:'detached'});
  }
  await page.screenshot({path:`work/${width}-${url.includes('8001')?'gallery':'blog'}-${url.endsWith('8000/')||url.endsWith('8001/')?'index':'detail'}.png`,fullPage:true});
 }
 await page.goto('http://localhost:8001/');
 const beforeResize=await page.locator('.photo-grid').evaluate(e=>e.clientHeight);
 await page.setViewportSize({width:width===1440?600:900,height:1000});
 await page.waitForFunction(before=>document.querySelector('.photo-grid').clientHeight!==before,beforeResize);
 await page.setViewportSize({width,height:1000});
 await page.goto('http://localhost:8000/');
 await page.getByRole('link',{name:'Fotografie',exact:true}).click();
 assert.match(page.url(),/^http:\/\/localhost:8001/);
 await page.getByRole('link',{name:'Zápisník',exact:true}).click();
 assert.match(page.url(),/^http:\/\/localhost:8000/);
 for(const feed of ['atom.xml','rss.xml']){
   const response=await page.request.get(`http://localhost:8000/${feed}`);
   assert.equal(response.status(),200);assert.ok(!(await response.text()).includes('https://foto.example.cz'));
 }
 await page.close();
}
const nojs=await browser.newPage({javaScriptEnabled:false,viewport:{width:390,height:900}});
await nojs.goto('http://localhost:8001/');
await nojs.locator('.photo-grid a').first().click();
assert.match(nojs.url(),/\/foto\//);
await nojs.locator('a.zoom').click();
assert.match(nojs.url(),/\.jpg$/);
await browser.close();
assert.deepEqual(errors,[]);
console.log('PASS: desktop, mobile, lightbox, cross-site navigation, feeds, no-JS fallback');
