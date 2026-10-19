/** Connect pure gallery geometry and the bundled PhotoSwipe lightbox to the DOM. */
import {layout} from './layout.js';
import PhotoSwipeLightbox from './photoswipe-lightbox.esm.js';
// Use server-provided ratios immediately; image loading is not a layout dependency.
for (const grid of document.querySelectorAll('.photo-grid')) {
  const tiles = [...grid.children];
  const items = tiles.map(tile => ({ratio:Number(tile.dataset.ratio), day:tile.dataset.day}));
  const options = JSON.parse(grid.dataset.layout);
  /** Recompute tile coordinates and responsive-image hints for the current width. */
  const update = () => {
    const result = layout(items,grid.clientWidth,options);
    if (!grid.clientWidth) return;
    grid.classList.add('positioned');
    grid.style.height = `${result.height}px`;
    for (const b of result.boxes) {
      // Position the original node instead of moving it in document order.
      Object.assign(tiles[b.index].style,{left:`${b.x}px`,top:`${b.y}px`,width:`${b.width}px`,height:`${b.height}px`});
      for (const image of tiles[b.index].querySelectorAll('img,source')) image.sizes = `${Math.ceil(b.width)}px`;
    }
  };
  new ResizeObserver(update).observe(grid);
  update();
}
// Scope each lightbox to its own source-ordered collection. Ordinary hrefs remain
// usable when modules fail to load or JavaScript is disabled.
for (const container of document.querySelectorAll('.lightbox')) {
  const lightbox = new PhotoSwipeLightbox({gallery:container,children:'a.zoom',
    pswpModule:()=>import('./photoswipe.esm.js'),
    closeTitle:'Zavřít',zoomTitle:'Zvětšit',arrowPrevTitle:'Předchozí',arrowNextTitle:'Další',
    errorMsg:'Fotografii se nepodařilo načíst.'});
  lightbox.init();
}
