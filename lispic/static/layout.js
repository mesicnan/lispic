/** Pure geometry; no DOM dependencies. Input order is never mutated. */
export function layout(items, width, settings = {}) {
  const o = {gap: 0, 'target-height': 260, 'tall-ratio': 2.5,
    lookahead: 6, 'tall-min-width': 700, reorder: false, 'local-lookahead': 3,
    'group-limit': 12, 'min-height-factor': .5, 'max-height-factor': 1.8, 'max-score': 1.1, ...settings};
  if (!(width > 0)) return {boxes: [], height: 0};
  const gap = Math.min(o.gap, width / 20), target = Math.min(o['target-height'], width);
  const pending = items.map((item, index) => ({...item, index}));
  if (pending.some(p => !(p.ratio > 0) || !Number.isFinite(p.ratio))) throw new Error('Invalid aspect ratio');
  const boxes = [];
  let y = 0;
  const addRow = (row, x, top, h) => {
    for (const p of row) { const w = p.ratio * h; boxes.push({index:p.index, x, y:top, width:w, height:h}); x += w + gap; }
  };
  while (pending.length) {
    let best = null;
    if (width >= o['tall-min-width'] && pending.length >= 3) {
      // A local two-row group may put its tall member first. Explicit reorder
      // permits looking farther ahead. No other pair changes relative order.
      const search = Math.min(pending.length, o.reorder ? o.lookahead + 1 : o['local-lookahead'] + 1);
      for (let t = 0; t < search; t++) {
        const tall = pending[t], r = tall.ratio;
        if (1 / r < o['tall-ratio']) continue;
        if (tall.day && pending.slice(0,t).some(p => p.day !== tall.day)) continue;
        for (let count = Math.max(3,t+1); count <= Math.min(pending.length,o['group-limit']); count++) {
          const group = pending.slice(0,count), rest = group.filter(p => p !== tall);
          for (let split = 1; split < rest.length; split++) {
            const a = rest.slice(0,split), b = rest.slice(split);
            const A = a.reduce((s,p)=>s+p.ratio,0), B = b.reduce((s,p)=>s+p.ratio,0);
            const q = 1/A + 1/B;
            const H = ((width-gap-r*gap)*q-gap*((a.length-1)/A+(b.length-1)/B))/(1+r*q);
            const tw = r*(H+gap), rw = width-tw-gap;
            const h1 = (rw-(a.length-1)*gap)/A, h2 = (rw-(b.length-1)*gap)/B;
            if (Math.min(h1,h2) < target*o['min-height-factor'] || Math.max(h1,h2) > target*o['max-height-factor'] || rw < width*.45) continue;
            const score = Math.abs(Math.log(h1/target))+Math.abs(Math.log(h2/target)) + t*.03;
            if (!best || score < best.score) best = {score,count,tall,a,b,tw,h1,h2};
          }
        }
      }
    }
    if (best && best.score < o['max-score']) {
      const {count,tall,a,b,tw,h1,h2} = best;
      boxes.push({index:tall.index,x:0,y,width:tw,height:h1+gap+h2});
      addRow(a,tw+gap,y,h1); addRow(b,tw+gap,y+h1+gap,h2);
      pending.splice(0,count); y += h1+gap+h2+gap;
      continue;
    }
    let count = 1, sum = pending[0].ratio;
    while (count < pending.length && (width-(count-1)*gap)/sum > target) {
      const next = sum+pending[count].ratio;
      const oldError = Math.abs((width-(count-1)*gap)/sum-target);
      const newError = Math.abs((width-count*gap)/next-target);
      if (newError > oldError) break;
      sum = next; count++;
    }
    const fullHeight = (width-(count-1)*gap)/sum;
    const h = count === pending.length ? Math.min(target,fullHeight) : fullHeight;
    addRow(pending.splice(0,count),0,y,h); y += h+gap;
  }
  return {boxes, height: Math.max(0,y-gap)};
}
