# Konfigurace `site.sexp`

Jeden datový slovník, bez komentářů a bez spouštění kódu. Neznámé položky jsou chyba. Vynechané položky převezmou vestavěné hodnoty. Úplný použitelný soubor je v `examples/site.sexp`.

| Položka | Výchozí hodnota / význam |
|---|---|
| `language` | `"cs"`, jazyk HTML a RSS |
| `timezone` | `"Europe/Prague"`, data bez posunu a kalendářní den pro přesuny |
| `author` | `"Fotograf"`, patička a autor Atomu |
| `blog.url` | `"https://blog.example.cz"`, HTTP(S) origin bez cesty |
| `blog.title` | `"Zápisník"` |
| `blog.output` | `"dist/blog"` |
| `blog.identity` | `"urn:lispic:my-blog"`, stabilní unikátní URI, po publikování neměnit |
| `blog.per-page` | `12`, počet článků na indexu, v archivu a labelu |
| `gallery.url` | `"https://foto.example.cz"` |
| `gallery.title` | `"Fotografie"` |
| `gallery.output` | `"dist/gallery"` |
| `gallery.per-page` | `60`, počet fotografií v celkovém přehledu; alba se nestránkují |
| `sources.posts` | `"content/posts"`, rekurzivní hledání `*.sexp` |
| `sources.pages` | `"content/pages"` |
| `sources.albums` | `"content/albums"` |
| `sources.catalog` | `"content/photos.sexp"`, více kořenových `photo` |
| `sources.originals` | `"originals"`, základ cest katalogových fotografií |
| `sources.cache` | `".cache/lispic"` |
| `labels` | `{}`, např. `{:poznamky "Poznámky"}`; pořadí registru určuje postranní seznam, počty nezahrnují koncepty |
| `images.sizes` | `[480 960 1600 2400]`, délky delší strany |
| `images.jpeg-quality` | `88`, 1–100 |
| `images.webp-quality` | `85`, 1–100 |
| `images.webp` | `true`, JPEG se generuje vždy |
| `layout.gap` | `0`, mezera v px |
| `layout.target-height` | `260`, cílová výška běžného řádku v px |
| `layout.tall-ratio` | `2.5`, minimální výška/šířka vysokého snímku |
| `layout.lookahead` | `6`, počet dalších pozic při povoleném širším hledání |
| `layout.tall-min-width` | `700`, minimální šířka kontejneru pro dvojřádky |
| `layout.reorder` | `false`, širší hledání v celkovém přehledu; alba mají vlastní explicitní `:reorder` s výchozím `false` |
| `layout.local-lookahead` | `3`, počet dalších kandidátů v běžné místní skupině, i bez širšího hledání |
| `layout.group-limit` | `12`, maximum fotografií zkoušeného dvojřádku |
| `layout.min-height-factor` | `0.5`, nejnižší výška pravého řádku vůči cíli |
| `layout.max-height-factor` | `1.8`, nejvyšší výška pravého řádku vůči cíli |
| `layout.max-score` | `1.1`, maximum součtu logaritmických odchylek výšek (plus 0,03 za přesunutou pozici) |
| `feeds.count` | `20`, maximum položek každého blogového feedu |
| `randomization.enabled` | `true` |
| `randomization.seed` | `"lispic-1"`, společný seed |
| `randomization.margin` | `3`, maximum levého i pravého okraje v %, minimum 0 |
| `randomization.mobile-margin` | `1`, maximum na viewportu do 700 px |
| `randomization.font-min` | `98`, minimum velikosti písma v % společného základu |
| `randomization.font-max` | `102`, maximum velikosti písma |
| `randomization.line-height` | `1.7`, stálý násobek velikosti písma |
| `appearance.background` | `"#141618"`, barva #RGB nebo #RRGGBB |
| `appearance.foreground` | `"#e4e1db"` |
| `appearance.accent` | `"#d2b98a"` |
| `appearance.text-width` | `"44rem"`, maximální šířka textu; jednotky rem, em, px, ch |
| `appearance.navigation` | `[]`, další odkazy, např. `[{:title "Kontakt" :href "mailto:ja@example.cz"}]` |

Příklad lokálního přepsání: `(post {... :randomization false} ...)` a `(album {... :reorder true} ...)`. Zdrojová ID, slugy, data, popisky a členství v albech jsou výhradně v souborech obsahu.

Při změně domén se změní absolutní odkazy, nikoliv feedové identifikátory, pokud zachováte `blog.identity`. Originy musí být různé pro skutečně oddělené weby. Lokální náhled vždy používá dva různé porty.
