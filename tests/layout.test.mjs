import {test} from 'node:test';
import assert from 'node:assert/strict';
import {layout} from '../lispic/static/layout.js';
/** Assert that geometry covers each input once without cropping or overlaps. */
function verify(items,width,options={}) {
 const r=layout(items,width,options);
 assert.equal(r.boxes.length,items.length);
 assert.equal(new Set(r.boxes.map(b=>b.index)).size,items.length);
 for(const b of r.boxes){
  assert.ok(b.width>0 && b.height>0);
  assert.ok(Math.abs(b.width/b.height-items[b.index].ratio)<1e-8);
  assert.ok(b.x>=0 && b.y>=0 && b.x+b.width<=width+1e-7);
  for(const c of r.boxes) if(b!==c){
   assert.ok(b.x+b.width<=c.x+1e-7||c.x+c.width<=b.x+1e-7||b.y+b.height<=c.y+1e-7||c.y+c.height<=b.y+1e-7,'overlap');
  }
 }
 return r;
}
test('normal rows fill width, final row can be short',()=>{
 const r=verify(Array.from({length:11},()=>({ratio:1.5})),1200,{gap:5});
 const rows=Map.groupBy(r.boxes,b=>b.y);
 for(const [y,row] of rows) if(y!==Math.max(...rows.keys())) assert.ok(Math.abs(row.at(-1).x+row.at(-1).width-1200)<1e-7);
});
test('tall member starts double row, with preserved other order',()=>{
 const r=verify([1.5,.28,1.5,1.5,1.5,1].map(ratio=>({ratio})),1200);
 const tall=r.boxes.find(b=>b.index===1);
 assert.equal(tall.x,0);assert.equal(tall.y,0);
 assert.ok(r.boxes.some(b=>b.y>0 && b.y<tall.height));
 assert.deepEqual(r.boxes.filter(b=>b.index!==1).map(b=>b.index),[0,2,3,4,5]);
});
test('cross-day movement forbidden',()=>{
 const items=[1.5,.28,1.5,1.5,1.5].map((ratio,i)=>({ratio,day:i===0?'2026-10-19':'2026-10-18'}));
 const r=verify(items,1200,{reorder:true});
 assert.equal(r.boxes[0].index,0);
});
test('mobile falls back; extreme ratios and resize stay valid',()=>{
 let seed=7;
 const rand=()=>{seed=(seed*1664525+1013904223)>>>0;return seed/2**32;};
 for(let n=1;n<80;n++) {
   const items=Array.from({length:n},()=>({ratio:.08+rand()*12}));
   for(const width of [320,390,700,1280,1920]) verify(items,width,{gap:4,reorder:true});
 }
});
test('deterministic and input remains unchanged',()=>{
 const items=[{ratio:1.5},{ratio:.2},{ratio:2},{ratio:1}]; const before=JSON.stringify(items);
 assert.deepEqual(layout(items,1000),layout(items,1000));assert.equal(JSON.stringify(items),before);
 assert.deepEqual(layout([],1000),{boxes:[],height:0});
});
