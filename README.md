# Lispic

Osobní generátor dvou statických fotografických webů. Jádro je napsané v **Hy 1.3.1**, obrázky zpracovává Pillow. Tmavý blog má úzký textový sloupec, galerie široké řádky bez ořezu. Výsledné adresáře potřebují pouze statický HTTP hosting.

## Rychlý začátek

Vyžaduje Python 3.11 nebo novější s `venv` a systémovými daty časových pásem. Ověřeno na Pythonu 3.13.16, Hy 1.3.1 a Pillow 12.3.0.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -e .
.venv/bin/lispic check --config examples/site.sexp
.venv/bin/lispic build --config examples/site.sexp
.venv/bin/lispic serve --config examples/site.sexp
```

Otevřete **http://localhost:8000** (blog) a **http://localhost:8001** (galerie). Aktivace prostředí není nutná. Při instalaci přes `pipx install .` lze příkaz `lispic` používat odkudkoli; cestu k `site.sexp` určíte `--config`. Samostatně instalované `hy` nemusí mít závislosti projektu, proto pro vývoj použijte `.venv/bin/hy`.

- `check`: načte i koncepty, ověří syntaxi, metadata, odkazy a čitelnost obrázků. Nevytváří cache ani web.
- `build`: vytvoří oba weby, v ukázce `examples/dist/blog` a `examples/dist/gallery`.
- `serve`: sestaví oddělený místní výstup `examples/.preview/{blog,gallery}`, nahradí obě základní URL localhostem a spustí dva servery vázané na loopback. Produkční `dist` nemění. Ukončení Ctrl+C. Po úpravě obsahu ho spusťte znovu.
- Porty lze změnit pomocí `--port 8100 --gallery-port 8101`.

`serve` přepisuje také explicitní odkazy v obsahu a navigaci, které začínají nakonfigurovanou produkční URL. Ostatní externí odkazy zůstávají externí. Na náhled používejte HTTP, nikoliv `file://`.

## Obsah

Všechny cesty v konfiguraci jsou relativní k jejímu souboru. Ukázkový web obsahuje dva články, koncept, stránku O mně, sedm katalogových fotografií, dvě alba a samostatný obrázek článku. Obrázky jsou označené technické ilustrace různých rozměrů, nikoliv fotografie. Jsou součástí checkoutu; znovu je vytvoří `.venv/bin/hy examples/make_images.hy`.

### Článek

V adresáři `sources.posts` založte např. `2026-10-18-podzim.sexp`:

```lisp
(post {:id "podzim-2026" :title "Podzim za městem" :slug "podzim-za-mestem"
       :published "2026-10-18T18:30:00+02:00" :labels ["krajina"]}
  (p Vyrazil jsem ráno, ještě před deštěm.)
  (p Tentokrát mě zajímaly (em okraje) věcí.)
  (photo {:ref "pole-01"} Popisek pro tento článek.)
  (gallery {:photos ["pole-01" "pole-02"]}))
```

ID a slug jsou malá ASCII písmena, číslice, spojovníky nebo podtržítka (bez úvodní či koncové interpunkce). `:id` je stabilní, `:slug` určuje `/clanky/{slug}/`. `:title` se zobrazí jako hlavní nadpis. Přejmenování zdrojového souboru URL nemění.

`:published` je ISO datum/čas. Bez něj je nutné datum `YYYY-MM-DD` na začátku názvu; použije se místní půlnoc. Datum bez posunu používá nastavené časové pásmo. Nejnovější články jsou první, shody rozhoduje vzestupná cesta zdrojového souboru. `:updated` ovlivňuje Atom, nikoli řazení. **Budoucí data se publikují.** `:draft true` článek vyřadí z výstupu. Odkaz z veřejného obsahu na koncept je chyba. `check` kontroluje i samotné koncepty.

Volitelné `:summary` je ruční textový perex, `:randomization false` vypne odchylky odstavců. `:labels` odkazuje na registry v konfiguraci. `page` má `:id`, `:title`, `:slug`, tělo jako článek a URL `/stranky/{slug}/`; nevstupuje do chronologie ani feedů. Stránky se automaticky přidají do navigace.

### Zápis textu

- `(název {atributy} obsah)`; slovník je volitelný, ale musí být na začátku.
- Atributy jsou čistá data: `:klíč`, řetězce s JSON escapováním, čísla, `true`, `false`, seznamy, vnořené slovníky, keyword hodnoty jako `:gallery`. Žádný `eval` ani Hy reader se na obsah nepoužívá.
- V těle je text výchozí; uvozovky a středníky jsou obyčejné znaky. `\(`, `\)` a `\\` označují doslovné závorky a lomítko. Jiný escape v těle je chyba.
- Mezery a nové řádky se znormalizují. `(p Tohle je (em důležité).)` vytvoří přesně `<p>Tohle je <em>důležité</em>.</p>`.
- `pre` zachová whitespace včetně vnořeného `code`. Jeden oddělovač za názvem nebo atributy je syntaktický; další whitespace už tvoří obsah. Závorky kódu je nutné escapovat.
- Podporované prvky: `p`, `h1`–`h6`, `em`, `strong`, `a`, `ul`, `ol`, `li`, `blockquote`, `pre`, `code`, `br`, `photo`, `gallery`.
- `(a {:post "podzim-2026"} Související článek)` vyhledá článek podle ID. `(a {:href "https://example.org" :title "Volitelné"} Externí odkaz)` je běžný odkaz. Nepovolují se skriptová URL.
- Text i HTML atributy se escapují; surové HTML není podporováno.
- Parser ukládá pozice uzlů, chyby obsahu uvádějí soubor, řádek a sloupec. U metadat jde o pozici začátku prvku.

### Fotografie

Originál vložte do `sources.originals` a přidejte záznam do `sources.catalog`:

```lisp
(photo {:id "pole-01" :src "pole-01.jpg" :alt "Pole pod zataženou oblohou"
        :caption "Pole po sklizni" :gallery true
        :added "2026-10-18T18:00:00+02:00" :taken "2026-10-12"})
```

`:added` musí být u veřejné fotografie vyplněno a nemění se automaticky. Přehled řadí podle tohoto data sestupně, shody podle ID vzestupně. `:taken` je nezávislé volitelné datum pořízení. Detail `/foto/{id}/` nezávisí na albu.

**`:gallery false` neznamená soukromí:** fotografii lze publikovat v článku přes `:ref`. Nedostane galerijní detail a nesmí do alba. Varianty se publikují s blogem, pouze pokud ji veřejný obsah používá. U `:gallery true` jsou varianty na galerijní subdoméně; blog je načítá odtamtud.

Vložení přes `(photo {:ref "pole-01" :alt "Volitelné přepsání"} Lokální popisek.)` přebírá katalogový alt a popisek, není-li přepsán. Veřejná fotografie má vedle lightboxu samostatný odkaz na detail. Galerie v článku používá `(gallery {:photos ["pole-01" "pole-02"]})`.

Fotografie jen pro jeden článek může být také `(photo {:src "images/poznamky.jpg" :alt "Popis"} Popisek.)`; cesta se vyhodnocuje vůči článku. Cesty nesmí opustit odpovídající zdrojový adresář, včetně symlinků. Originály se nekopírují do výstupu.

### Alba

Do `sources.albums` vložte:

```lisp
(album {:id "podzim" :title "Podzim" :slug "podzim"
        :photos ["pole-03" "pole-01" "pole-02"] :reorder false}
  (p Ručně vybraný soubor fotografií.))
```

Pořadí je dané seznamem, fotografie lze sdílet mezi alby. Všechny musí mít `:gallery true`. Vysoký člen právě skládaného dvojřádku se může zobrazit jako první vlevo; zbytek má zachované vzájemné pořadí. `:reorder true` dovoluje širší místní hledání. Lightbox i DOM vždy zachovávají původní pořadí seznamu.

## Obrázky a cache

Pillow nejprve aplikuje EXIF orientaci, potom převádí vložený ICC profil do sRGB. Neplatný/nepodporovaný profil je chyba s názvem souboru. Bez profilu se předpokládá sRGB; neprofilované CMYK se převede standardním převodem Pillow do RGB (pro přesné barvy raději exportujte do sRGB). Průhlednost se skládá na bílý podklad. Veřejné varianty neobsahují EXIF, GPS ani původní ICC metadata; data jsou už v sRGB.

Delší strana výchozích variant: 480, 960, 1600, 2400 px; bez zvětšování, shodné skutečné velikosti se neduplikují. JPEG 88 a WebP 85. HTML má `picture`, `srcset`, `sizes`, rozměry a lazy loading. Galerie upraví `sizes` podle skutečné šířky dlaždice. Pro velké zobrazení se používá největší vytvořená varianta.

Klíč cache obsahuje SHA-256 originálu, parametry převodu, verzi pipeline a Pillow. Editace textu obrázky znovu nepřevádí. Cache je možné smazat, není součástí nasazení. Stará cache se automaticky neprořezává. RAW ani animace nejsou cílovým formátem první verze; používejte hotové JPEG/PNG/WebP/TIFF exporty.

## Rozložení a odstavce

`static/layout.js` je čistá funkce bez DOM. Počítá justified řádky a dvojřádky s jedním vysokým panoramatem. Poměry stran zachovává, úplné řádky vyplňují šířku, poslední může zůstat kratší. Řešení dvojřádku zohledňuje mezeru, poměry stran a cílovou výšku; při nevhodném výsledku se použije běžný řádek. Mobil pod prahem `tall-min-width` používá běžné řádky. `ResizeObserver` přepočítává geometrii bez čekání na snímky.

Bez povoleného širšího hledání se vysoký snímek hledá mezi prvními čtyřmi členy místní skupiny; při povolení do `lookahead + 1`. Zkouší se skupiny do 12 snímků a oba pravé řádky se drží přibližně mezi 0,5–1,8 cílové výšky. Tyto heuristické meze lze upravit pomocí `local-lookahead`, `group-limit`, `min-height-factor`, `max-height-factor` a `max-score`. V celkovém přehledu se snímek nesmí přesunout před fotografii z jiného dne (den v nastaveném časovém pásmu). Přeskupení nepřekračuje hranici stránkování.

Randomizace se vypočítá pomocí SHA-256 ze seedu webu, ID článku, normalizované struktury odstavce (nebo jeho `:id`) a názvu parametru. Přidání jiného odstavce nemá vliv. Identické odstavce bez ID mají stejné odchylky; explicitní ID dovolují jejich odlišení. Změna textu změní odchylky, při explicitním ID nikoli. Font vychází z `rem`, takže se při vnoření nenásobí. Mobil má samostatné menší okraje. Feedy, popisky a navigace efekt nemají.

## Feedy a archivy

Blog publikuje `/atom.xml`, `/rss.xml`, `/archiv/`, stránky `/labels/{id}/` a stránkované seznamy. Galerie vlastní feed nemá. Každá položka obsahuje perex, první fotografii (i první člen vložené galerie) a pokračovací odkaz. Bez ručního perexu se vybírají přímé běžné odstavce článku, ne citace, kód, nadpisy nebo popisky. Cíl je 500 znaků, hranice odstavce/věty mezi 300–650; jinak hranice slova a výpustka. Základní české zkratky a čísla omezují chybné dělení vět; nejde o plný jazykový analyzátor.

UUIDv5 položky vychází z `blog.identity` a ID článku. Změna titulku, slugu, CSS nebo seedu ID ani datum aktualizace nemění. Neměňte `blog.identity` po prvním zveřejnění. RSS používá datum vydání; Atom vydání a aktualizaci. Prázdný feed používá jako své datum epochu 1970-01-01, nikoli čas sestavení.

## Konfigurace a publikování

Kompletní příklad: `examples/site.sexp`. Všechny položky a výchozí hodnoty popisuje [docs/configuration.md](docs/configuration.md). Povolené lokální volby jsou `post.randomization` a `album.reorder`. Jinak platí konfigurace webu a vestavěné výchozí hodnoty. Metadata patří do obsahu, ne konfigurace.

Pro vlastní web zkopírujte ukázkovou strukturu a upravte URL, autora, názvy, obsah a stabilní identitu blogu. Po `build` nahrajte **obsah** `dist/blog` do kořene blogové subdomény a **obsah** `dist/gallery` do kořene fotografické subdomény. Hosting musí obsluhovat adresáře přes `index.html`, poskytovat správný MIME typ pro `.js`, CSS, obrázky a XML. Žádný Python ani databáze nejsou potřeba. Nasazení nástroj neprovádí.

Sestavení nejprve připraví oba stromy v dočasných sousedních adresářích. Teprve po úspěšném renderování nahradí staré výstupy, takže nezůstávají osiřelé články ani varianty. Přepisuje pouze prázdné adresáře nebo adresáře označené `.lispic-output`; cíle nesmí překrývat zdroje, cache ani jeden druhý. Dvojí přejmenování není transakce při výpadku disku; nespouštějte současně dvě sestavení stejného webu.

Výsledky provedených kontrol: [docs/verification.md](docs/verification.md).

## Vývoj a testy

```sh
.venv/bin/python -m pip install -e ".[test]"
.venv/bin/python -m pytest -q
# Čistá geometrie, pouze Node.js >=22, bez npm závislostí:
node --test tests/layout.test.mjs
# Volitelné testy skutečného prohlížeče:
npm install
npx playwright install chromium
# V druhém terminálu nechte běžet serve z rychlého začátku:
node tests/browser.mjs
```

Testy zahrnují parser, český text a interpunkci, nebezpečné odkazy, metadata, řazení, koncepty, orientaci a ICC, odstranění GPS, cache, odstavce, perexy, identitu a XML feedů, existenci místních odkazů, opakovatelnost a odstranění starých stránek. Geometrické testy kontrolují překryvy, poměry stran, vyplnění řádků, panoramata a zákaz přesunů mezi dny. Browser testy ověřují desktop 1440 px, mobil 390 px, lightbox, přechody mezi weby, feedy a základní navigaci bez JavaScriptu.

Jádro: `parser.hy`, `model.hy`, `config.hy`, `validation.hy`, `images.hy`, `typography.hy`, `excerpts.hy`, `render.hy`, `feeds.hy`, `build.hy`, `cli.hy`. Jediný Python bootstrap je `__init__.py`; testy jsou v Pythonu a JavaScriptu.

PhotoSwipe **5.4.4** je přibalen lokálně, pod licencí **MIT**. Viz `lispic/static/PHOTOSWIPE-LICENSE.txt` a [docs/third-party.md](docs/third-party.md). Za běhu web nepoužívá CDN ani externí písma.

První verze nemá sledování změn, administraci, automatické přesměrování starých slugů, RAW pipeline ani vyhledávání. Identifikátory se automaticky nedoplňují a data `:added` musí autor uložit ručně. Chybová hlášení se zastaví u první chyby.
