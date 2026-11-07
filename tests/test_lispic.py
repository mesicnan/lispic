import copy
import shutil
import subprocess
import sys
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit
import xml.etree.ElementTree as ET
import pytest
import hy
from PIL import Image, ImageCms
from lispic.parser import parse, parse_data
from lispic.model import ContentError, plain
from lispic.config import load_config, DEFAULTS
from lispic.validation import load_content
from lispic.render import render_node
from lispic.typography import paragraph_style
from lispic.excerpts import summary, first_photo
from lispic.images import process_image
from lispic.build import build
from lispic.feeds import stable_id

@pytest.fixture(scope="session")
def example_template(tmp_path_factory):
    """Generate disposable images for the code repository's text-only test fixtures."""
    root = tmp_path_factory.mktemp("example") / "site"
    project = Path(__file__).parents[1]
    shutil.copytree(project / "tests/fixtures/site", root)
    subprocess.run([sys.executable, "-m", "hy", str(project / "tools/make_images.hy"), str(root)], check=True)
    return root


@pytest.fixture
def site(tmp_path, example_template):
    """Give each test an isolated site without reading the author's content repository."""
    shutil.copytree(example_template, tmp_path / "site")
    return load_config(tmp_path / "site/site.sexp")

def render(s):
    "Render one parsed element without catalog or post dependencies."
    return render_node(parse(s)[0], {}, {}, DEFAULTS)

def test_natural_text_and_escaping():
    "Preserve inline punctuation and whitespace while escaping HTML and literal delimiters."
    assert render('(p Tohle je (em důležité).)') == '<p>Tohle je <em>důležité</em>.</p>'
    assert render('(p A(strong B)C; "D" & <E>)') == '<p>A<strong>B</strong>C; &quot;D&quot; &amp; &lt;E&gt;</p>'
    assert render(r'(p \(a\) \\ konec)') == '<p>(a) \\ konec</p>'
    assert render('(p A\n  (em B)   C.)') == '<p>A <em>B</em> C.</p>'
    assert render('(pre a\n  b\n)') == '<pre>a\n  b\n</pre>'
    assert render('(pre (code a\n  b\n))') == '<pre><code>a\n  b\n</code></pre>'

def test_data_and_errors():
    "Accept literal data and attach source coordinates to rejected syntax."
    assert parse_data('{:a [1 -2 3.5 true false :gallery {:x "č"}]}')['a'] == [1,-2,3.5,True,False,':gallery',{'x':'č'}]
    for text in ['(p x', '(p \\x)', '(p {:x 1 :x 2})', '(p {:x (__import__ "os")})']:
        with pytest.raises(ContentError, match=r'fixture:1:\d+:'):
            parse(text, 'fixture')
    assert parse('(p a)\n(p b)', 'x')[1].pos.line == 2

def test_order_drafts_dates(site):
    "Exclude drafts, derive missing dates from filenames, and publish future-dated posts."
    data = build(site, True)
    assert [p['attrs']['id'] for p in data['public-posts']] == ['podzim-2026','ranni-mlha']
    assert data['post-map']['ranni-mlha']['published'].isoformat() == '2026-09-28T00:00:00+02:00'
    source = site['root']/'content/posts/2026-10-18-podzim.sexp'
    source.write_text(source.read_text().replace('2026-10-18T18:30:00+02:00','2099-10-18T18:30:00+02:00'))
    assert build(site,True)['public-posts'][0]['attrs']['id'] == 'podzim-2026'

@pytest.mark.parametrize('old,new,error',[
    (':post "ranni-mlha"', ':post "missing"', 'Neexistující článek'),
    (':post "ranni-mlha"', ':post "koncept"', 'koncept'),
    (':ref "pole-01"', ':ref "missing"', 'Neexistující fotografie'),
    ('"krajina" "panorama"', '"unknown"', 'Neznámý label'),
    (':href "https://example.org"', ':href "javascript:alert(1)"', 'Nepovolená'),
])
def test_validation(site,old,new,error):
    "Reject unresolved content references, draft links, unknown labels, and unsafe URLs."
    for p in (site['root']/'content/posts').glob('*.sexp'):
        p.write_text(p.read_text().replace(old,new))
    with pytest.raises(ContentError,match=error): load_content(site)

def test_private_album_rejected(site):
    "Keep blog-only catalog photos out of public albums."
    p=site['root']/'content/albums/podzim.sexp'
    p.write_text(p.read_text().replace('"pole-03"','"sesit"'))
    with pytest.raises(ContentError,match='neveřejnou'): load_content(site)

def test_randomization_stable():
    "Keep existing paragraph styles stable and honor explicit identities and seed changes."
    a=parse('(p Stejný (em text).)')[0]
    b=parse('(post (p Jiný.) (p Stejný (em text).))')[0].children[-1]
    options=copy.deepcopy(DEFAULTS['randomization'])
    before=paragraph_style(a,'post-id',options)
    assert before == paragraph_style(b,'post-id',options)
    options['seed']='other'
    assert before != paragraph_style(a,'post-id',options)
    assert paragraph_style(parse('(p {:id "x"} A)')[0],'p',options) == paragraph_style(parse('(p {:id "x"} B)')[0],'p',options)

def test_images_orientation_cache_profiles(tmp_path):
    "Apply orientation and ICC conversion, strip GPS, reuse cache entries, and avoid upscaling."
    p=tmp_path/'image.jpg'
    im=Image.new('RGB',(100,300),'red')
    exif=Image.Exif(); exif[274]=6; exif[34853]={1:'N',2:(50.,0.,0.)}
    im.save(p,exif=exif,icc_profile=ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes())
    options=copy.deepcopy(DEFAULTS['images'])
    cache=tmp_path/'cache'
    a=process_image(p, options, cache)
    assert (a['width'],a['height']) == (300,100)
    times={f:f.stat().st_mtime_ns for f in cache.rglob('*') if f.is_file()}
    assert a == process_image(p,options,cache)
    assert times == {f:f.stat().st_mtime_ns for f in times}
    for v in a['variants']:
        with Image.open(cache/a['key']/v['file']) as converted:
            assert converted.width <= 300 and converted.height <= 100
            assert abs(converted.width/converted.height-3) < .02
            assert 34853 not in converted.getexif() and 274 not in converted.getexif()
    options['jpeg-quality']=80
    assert process_image(p,options,cache)['key'] != a['key']

def test_excerpts_and_first_photo(site):
    "Choose manual or automatic excerpts and locate photos in document order."
    data=load_content(site)
    post=data['post-map']['podzim-2026']
    assert 300 <= len(summary(post)) <= 650
    assert 'Lokální popisek' not in summary(post)
    assert first_photo(post['node']).attrs['ref'] == 'pole-01'
    r=data['post-map']['ranni-mlha']
    assert summary(r) == r['attrs']['summary']
    assert first_photo(r['node']).attrs['src'] == 'images/poznamky.jpg'
    long='slovo '*200
    assert summary({'attrs':{},'node':parse(f'(post (p {long}))')[0]}).endswith('…')
    sentence='A'*310+' např. něco pokračuje. '
    result=summary({'attrs':{},'node':parse(f'(post (p {sentence}{long}))')[0]})
    assert not result.endswith('např.')

class Links(HTMLParser):
    """Collect generated anchor and image URLs without a browser dependency."""
    def __init__(self): "Initialize the HTML parser and its collected URL list."; super().__init__(); self.urls=[]
    def handle_starttag(self,tag,attrs):
        "Collect links and image targets for generated-file existence checks."
        for k,v in attrs:
            if k in ('href','src','data-pswp-src'): self.urls.append(v)

def test_build_feeds_links_cleanup_and_reproducibility(site):
    "Verify complete outputs, feed XML, link targets, repeatability, cache reuse, and stale-page removal."
    data=build(site)
    root=site['root']; blog=root/'dist/blog'; gallery=root/'dist/gallery'
    assert not (blog/'clanky/nedokoncena-cesta').exists()
    assert not (gallery/'foto/sesit').exists()
    private=data['photos']['sesit']['image']['key']
    assert (blog/'media'/private).is_dir() and not (gallery/'media'/private).exists()
    for id,rec in data['photos'].items():
        if rec['attrs'].get('gallery'):
            assert (gallery/'foto'/id/'index.html').is_file()
            assert (gallery/'media'/rec['image']['key']).is_dir()
            assert not (blog/'media'/rec['image']['key']).exists()
    for output in [blog,gallery]:
        for page in output.rglob('*.html'):
            parser=Links(); parser.feed(page.read_text())
            for url in parser.urls:
                parsed=urlsplit(url)
                if not parsed.path: continue
                target={'blog.example.cz':blog,'foto.example.cz':gallery}.get(parsed.netloc)
                if not parsed.netloc: target=output
                if target:
                    path=target/parsed.path.lstrip('/')
                    if parsed.path.endswith('/'): path=path/'index.html'
                    assert path.is_file(), (page,url)
    atom=ET.parse(blog/'atom.xml'); rss=ET.parse(blog/'rss.xml')
    ns={'a':'http://www.w3.org/2005/Atom'}
    assert len(atom.findall('a:entry',ns))==2
    assert len(rss.findall('./channel/item'))==2
    assert '<img' in atom.find('a:entry/a:summary',ns).text
    rec=data['public-posts'][0]; before=stable_id(rec,site)
    rec['attrs']['title']='Changed';rec['attrs']['slug']='changed'
    assert stable_id(rec,site)==before
    snapshots={str(p.relative_to(root)):p.read_bytes() for out in [blog,gallery] for p in out.rglob('*') if p.is_file()}
    cache_times={p:p.stat().st_mtime_ns for p in (root/'.cache').rglob('*') if p.is_file()}
    build(site)
    assert snapshots=={str(p.relative_to(root)):p.read_bytes() for out in [blog,gallery] for p in out.rglob('*') if p.is_file()}
    source=root/'content/posts/2026-10-18-podzim.sexp'
    source.write_text(source.read_text().replace('Vyrazil jsem','Odešel jsem'))
    build(site)
    assert cache_times=={p:p.stat().st_mtime_ns for p in cache_times}
    # Remove a page that is not referenced by other content.
    (root/'content/pages/o-mne.sexp').unlink();build(site)
    assert not (blog/'stranky/o-mne').exists()

def test_output_guard(site):
    "Reject an output destination that would overwrite source content."
    site['blog']['output']='content'
    with pytest.raises(ContentError, match='výstupní'): build(site)

def test_tie_order_and_updated(site):
    "Use source paths to break publication-date ties independently of updated dates."
    posts=site['root']/'content/posts'
    for name,id in [('2026-01-01-b.sexp','b'),('2026-01-01-a.sexp','a')]:
        (posts/name).write_text(f'(post {{:id "{id}" :title "{id}" :slug "{id}" :updated "2099-01-01"}} (p Text.))')
    data=load_content(site)
    assert [p['attrs']['id'] for p in data['posts']][-2:] == ['a','b']

def test_empty_catalog_and_pagination(site):
    # Empty catalogs are legal for a text-only blog.
    "Build a text-only blog and paginate indices, archives, and label lists."
    for path in (site['root']/'content/albums').glob('*.sexp'): path.unlink()
    for path in (site['root']/'content/posts').glob('*.sexp'): path.unlink()
    (site['root']/'content/photos.sexp').write_text('')
    site['blog']['per-page']=1
    for i in range(3):
        (site['root']/f'content/posts/2026-01-0{i+1}-x.sexp').write_text(f'(post {{:id "p{i}" :title "Test" :slug "p{i}" :labels ["krajina"]}} (p Test.))')
    build(site)
    blog=site['root']/'dist/blog'
    for route in ['strana/2','strana/3','labels/krajina/strana/2','archiv/strana/3']:
        assert (blog/route/'index.html').is_file()

@pytest.mark.parametrize('fragment', ['(p (h2 Invalid))','(ul Text)','(p (a {:href "/"} (a {:href "/"} X)))'])
def test_invalid_html_structure(site,fragment):
    "Reject source nesting that would produce invalid HTML structures."
    p=site['root']/'content/pages/invalid.sexp'
    p.write_text(f'(page {{:id "invalid" :title "Invalid" :slug "invalid"}} {fragment})')
    with pytest.raises(ContentError):load_content(site)

@pytest.mark.parametrize('key,value', [('per-page',0),('per-page',1.5)])
def test_invalid_configuration(tmp_path,key,value):
    "Reject nonpositive and noninteger pagination settings."
    p=tmp_path/'site.sexp'
    p.write_text('{:blog {:' + key + ' ' + str(value) + '}}')
    with pytest.raises(ContentError):load_config(p)

def test_preview_urls_and_randomization_override(site):
    "Rewrite only matching origins and apply explicit per-post paragraph settings."
    from lispic.render import public_href, body
    site['preview-origins']={'https://blog.example.cz':'http://localhost:8000','https://foto.example.cz':'http://localhost:8001'}
    assert public_href('https://blog.example.cz/clanky/test/',site)=='http://localhost:8000/clanky/test/'
    assert public_href('https://blog.example.cz.evil.test/',site)=='https://blog.example.cz.evil.test/'
    site['randomization']['enabled']=False
    node=parse('(post {:id "x" :randomization true} (p Text.))')[0]
    assert 'varied' in body({'node':node,'attrs':node.attrs},{},site)

def test_no_word_boundary_and_number_tokens():
    "Handle exponent notation and bound excerpts even when text contains no spaces."
    assert parse_data('[1e3 -1.2e-3]') == [1000,-.0012]
    rec={'attrs':{},'node':parse('(post (p '+('x'*800)+'))')[0]}
    assert len(summary(rec)) == 501

def test_album_cannot_bypass_public_catalog(site):
    "Reject direct source-file photos in album bodies."
    p=site['root']/'content/albums/podzim.sexp'
    p.write_text('(album {:id "x" :title "X" :slug "x" :photos ["pole-01"]} (photo {:src "local.jpg" :alt "X"}))')
    with pytest.raises(ContentError,match='pouze veřejné katalogové'):load_content(site)

def test_ignored_photo_attributes_are_rejected(site):
    "Reject catalog-only attributes on embedded photo elements."
    p=site['root']/'content/posts/2026-10-18-podzim.sexp'
    p.write_text(p.read_text().replace(':ref "pole-01"', ':ref "pole-01" :gallery false'))
    with pytest.raises(ContentError,match='Nepovolený atribut'):load_content(site)


def test_output_repositories_survive_builds(site):
    """Keep output repository history and settings across first and repeat builds."""
    outputs = [site['root'] / 'dist' / name for name in ('blog', 'gallery')]
    for output in outputs:
        output.mkdir(parents=True)
        subprocess.run(['git', 'init', '--initial-branch=main', str(output)], check=True, capture_output=True)
        (output / '.gitignore').write_text('local-notes.txt\n')
        (output / '.gitattributes').write_text('*.html text\n')
    build(site)
    heads = {}
    for output in outputs:
        subprocess.run(['git', '-C', str(output), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(output), '-c', 'user.name=Lispic tests', '-c',
                        'user.email=lispic@example.invalid', 'commit', '-m', 'First output'],
                       check=True, capture_output=True)
        heads[output] = subprocess.check_output(['git', '-C', str(output), 'rev-parse', 'HEAD'])
        (output / 'obsolete.html').write_text('stale generated page')
    (site['root'] / 'content/pages/o-mne.sexp').unlink()
    build(site)
    for output in outputs:
        assert subprocess.check_output(['git', '-C', str(output), 'rev-parse', 'HEAD']) == heads[output]
        assert not (output / 'obsolete.html').exists()
        assert (output / '.gitignore').read_text() == 'local-notes.txt\n'
        assert (output / '.gitattributes').read_text() == '*.html text\n'
        subprocess.run(['git', '-C', str(output), 'fsck', '--no-dangling'], check=True, capture_output=True)
    assert not (outputs[0] / 'stranky/o-mne').exists()


def test_build_launcher_preflight_and_skip(site, tmp_path, monkeypatch, capfd):
    """Stop before writing output on check failure, unless the preflight is explicitly skipped."""
    from lispic.launcher import run

    project = tmp_path / 'checkout'
    project.mkdir()
    # Use the real installed CLI with an isolated checkout/content layout.
    (project / '.venv').symlink_to(Path(sys.prefix), target_is_directory=True)
    original = site['root'] / 'originals' / 'unused-broken.jpg'
    original.write_bytes(b'not an image')
    catalog = site['root'] / 'content/photos.sexp'
    catalog.write_text(catalog.read_text() + '\n(photo {:id "unused-broken" :src "unused-broken.jpg" :alt "Unused" :gallery false})\n')
    arguments = ['build.hy', '--config', str(site['root'] / 'site.sexp')]
    monkeypatch.setattr(sys, 'argv', arguments)
    assert run('build', project) == 1
    assert not (site['root'] / 'dist').exists()

    # The unused image is not part of public output. Skipping the full image
    # preflight permits the build, while normal source validation still runs.
    monkeypatch.setattr(sys, 'argv', arguments + ['--skip-check'])
    assert run('build', project) == 0
    assert (site['root'] / 'dist/blog/index.html').is_file()
    assert (site['root'] / 'dist/gallery/index.html').is_file()

    source = site['root'] / 'content/posts/2026-10-18-podzim.sexp'
    source.write_text(source.read_text().replace(':ref "pole-01"', ':ref "missing"'))
    assert run('build', project) == 1
    assert 'Neexistující fotografie' in capfd.readouterr().err


@pytest.mark.parametrize('entry', ['build.hy', 'lispic/build.hy'])
def test_build_entry_paths_show_launcher_help(entry, tmp_path):
    """Both build paths reach the launcher even when executed outside the checkout."""
    project = Path(__file__).parents[1]
    result = subprocess.run([sys.executable, '-m', 'hy', str(project / entry), '--help'],
                            cwd=tmp_path, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert '--skip-check' in result.stdout
    assert '--config' in result.stdout
    assert 'Traceback' not in result.stderr
