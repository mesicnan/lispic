# Ověření první verze

Ověřeno 19. 10. 2026 na openSUSE Tumbleweed, Python 3.13.16, Hy 1.3.1, Pillow 12.3.0. Testy geometrie běžely na Node.js 24.19.0, prohlížečové testy na Chromium přes Playwright 1.62.1.

- `python -m pytest -q`: **25 testů prošlo**. Parser a pozice chyb, čeština, whitespace a escaping, atributy, řazení a datum z názvu, publikování budoucích článků, koncepty a odkazy, veřejnost fotografií/alb, EXIF/ICC/GPS, rozměry a cache, stabilní odstavce, perexy a první fotografie, XML feedů a jejich identita, stránkování, prázdný katalog, kontrola výstupních cest a odstranění osiřelé stránky.
- `node --test tests/layout.test.mjs`: **5 testů prošlo**, včetně deterministických sad různých poměrů stran při šířkách 320–1920 px. Kontrolují zachování poměrů, nepřekrývání, vyplnění řádků, vysoké panorama a hranice dne.
- `node tests/browser.mjs`: **prošlo**. Desktop 1440 px a mobil 390 px, blog i galerie, album, obrázky, PhotoSwipe (otevření, další snímek, zavření), skutečná změna šířky kontejneru, přechod mezi oběma lokálními weby, HTTP načtení obou feedů a navigace na detail/větší obrázek při vypnutém JavaScriptu. Bez JS chyb a neúspěšných HTTP odpovědí sledovaných testem.
- Desktopový přehled a mobilní článek byly také vizuálně zkontrolovány ze screenshotů.
- Vytvořen wheel, nainstalován s vlastními závislostmi do nového virtuálního prostředí. `check` a `build` proběhly nad oddělenou kopií ukázkového obsahu. Příkazy spuštěny mimo repozitář; import pochází z instalovaného balíčku.
- `pip check`: bez rozbitých závislostí.

## Konkrétní omezení

- Náhled nemá automatické sledování změn. Po editaci je nutné `serve` restartovat.
- Rozložení je deterministická lokální heuristika, nikoliv globální optimalizace. Extrémní poměry mohou vytvořit výrazně nízké nebo vysoké běžné řádky.
- Bez JavaScriptu fungují odkazy a obrázky; přesný justified/dvojřádkový layout a lightbox vyžadují JavaScript.
- Perex používá omezený seznam českých zkratek a jednoduché hranice vět, ne úplný jazykový model. Ruční `summary` má přednost.
- Nekopírují se originály, nevyvolává se RAW, nečistí se automaticky staré položky obrazové cache.
- Nejsou automatická přesměrování po změně slugu. Stabilní ID zůstávají, ale starou URL musí případně přesměrovat hosting.
- Dva výstupy jsou připraveny před náhradou starých adresářů, ale samotná náhrada není společná transakce při selhání disku. Souběžné buildy stejného webu nejsou podporované.
- Automatizovaná kontrola prohlížeče pokrývá Chromium; Firefox a Safari nebyly samostatně spuštěny.
