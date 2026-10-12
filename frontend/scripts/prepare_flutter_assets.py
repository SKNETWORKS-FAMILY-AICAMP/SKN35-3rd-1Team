"""Reuse the supplied standalone mockup's fonts and existing artwork credits."""
from pathlib import Path
import base64
import json
import re
import shutil
import sys

root = Path(__file__).resolve().parents[1]
mockup = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/Users/lsh/Downloads/artlog-mockup.html')
html = mockup.read_text()
fonts = root / 'assets/fonts'
fonts.mkdir(parents=True, exist_ok=True)
for css in re.findall(r'@font-face\s*\{(.*?)\}', html, re.S):
    if 'font-style: italic' in css:
        continue
    family = re.search(r"font-family:\s*'([^']+)'", css).group(1)
    weight = re.search(r'font-weight:\s*(\d+)', css).group(1)
    payload = re.search(r'base64,([A-Za-z0-9+/=]+)', css).group(1)
    (fonts / f'{family.replace(" ", "")}-{weight}.ttf').write_bytes(base64.b64decode(payload))
shutil.copyfile(root / 'public/fonts/licenses.json', fonts / 'licenses.json')
shutil.copyfile(root / 'public/favicon.svg', root / 'web/favicon.svg')
ts = (root / 'src/data/catalog.ts').read_text()
artists = []
movement_ids = {'인상주의': 'impressionism', '후기인상주의': 'post-impressionism', '빈 분리파': 'vienna-secession', '표현주의': 'expressionism', '바로크': 'baroque', '조선 회화': 'joseon-late-painting'}
for line in ts.splitlines():
    if line.strip().startswith("{ id:"):
        row = dict(re.findall(r"(\w+): '([^']*)'", line))
        row['id'] = row['id'].replace('kim-hongdo', 'kim-hong-do')
        artists.append(dict(id=row['id'], slug=row['id'], name=row['name'], name_en=row['english'], years=row['years'], movement_name=row['movement'], movement_id=movement_ids[row['movement']], summary=row['line']))
notes = dict(re.findall(r"'([\w-]+)': '([^']+)'", ts))
order = re.search(r'const order = \[(.*?)\];', ts).group(1)
order = re.findall(r"'([^']+)'", order)
works = []
for row in json.loads((root / 'src/data/artworks.json').read_text()):
    artist = next(a for a in artists if row['artistKo'] == a['name'])
    works.append(dict(id=row['id'], slug=row['id'], title=row['titleKo'], title_en=row['title'],
        artist_id=artist['id'], artist_name=artist['name'], artist_name_en=artist['name_en'],
        year_label=str(row['year']), movement_id=artist['movement_id'], movement_name=artist['movement_name'],
        image_url='public/artworks/' + Path(row['file']).name, is_asset=True,
        description=notes[row['id']], image_source_url=row['sourceUrl'], image_license=row['license']))
works.sort(key=lambda w: order.index(w['id']))
movements = [dict(id=v, name=k) for k,v in movement_ids.items()]
(root / 'assets/catalog.json').write_text(json.dumps(dict(artists=artists, artworks=works, movements=movements),ensure_ascii=False,indent=2)+'\n')
print(f'Prepared {len(works)} artworks, {len(artists)} artists, and licensed mockup fonts.')
