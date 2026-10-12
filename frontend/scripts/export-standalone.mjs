import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.resolve(root, '../output/ui/artlog-mockup.html');
let html = await readFile(path.join(root, 'dist/index.html'), 'utf8');
const scriptPath = html.match(/<script\b[^>]*src="([^"]+)"[^>]*><\/script>/)?.[1];
const stylesheetPath = html.match(/<link\b[^>]*rel="stylesheet"[^>]*href="(\/assets\/[^" ]+)"[^>]*>/)?.[1];
if (!scriptPath || !stylesheetPath) throw new Error('Run npm run build before exporting.');
let js = await readFile(path.join(root, 'dist', scriptPath), 'utf8');
let css = await readFile(path.join(root, 'dist', stylesheetPath), 'utf8');
const fonts = await readFile(path.join(root, 'public/fonts/offline-fonts.css'), 'utf8');
const credits = JSON.parse(await readFile(path.join(root, 'src/data/artworks.json'), 'utf8'));
for (const art of credits) {
  const bytes = await readFile(path.join(root, 'public', art.file));
  const data = `data:image/jpeg;base64,${bytes.toString('base64')}`;
  const original = JSON.stringify(art.file);
  if (!js.includes(original)) throw new Error(`Artwork asset missing from the build: ${art.id}`);
  js = js.replaceAll(original, JSON.stringify(data));
}
const favicon = await readFile(path.join(root, 'public/favicon.svg'));
html = html.replace('/favicon.svg', `data:image/svg+xml;base64,${favicon.toString('base64')}`);
html = html.replace(/<link\b[^>]*href="https:\/\/fonts\.[^"]+"[^>]*>/g, '');
css = css.replace(/@import\s*(?:url\(\s*)?(?:"[^"]*"|'[^']*'|[^;]+)\s*\)?\s*;/g, '');
html = html.replace(/<script\b[^>]*src="[^"]+"[^>]*><\/script>/, () => `<script type="module">${js.replace(/<\/script/gi, '<\\/script')}</script>`);
html = html.replace(/<link\b[^>]*rel="stylesheet"[^>]*href="\/assets\/[^" ]+"[^>]*>/, () => `<style>${fonts}\n${css}</style>`);
const fontLicenses = await readFile(path.join(root, 'public/fonts/licenses.json'), 'utf8');
html = html.replace('</head>', () => `<script type="application/json" id="artlog-font-licenses">${fontLicenses.replace(/<\/script/gi, '<\\/script')}</script>\n</head>`);
html = html.replace('<!doctype html>', '<!doctype html>\n<!-- ARTLOG standalone UI mockup. Artwork images, application code, styles and subset webfonts are embedded. Open this file directly in a browser; no installation or server is needed. Artwork attribution is available in each artwork detail and the bundled catalog. Fonts use the SIL Open Font License. -->');
if (/<(?:script|link)\b[^>]*(?:src|href)="\/(?:assets|favicon)/.test(html)) throw new Error('An external build asset remains.');
await mkdir(path.dirname(output), { recursive: true });
await writeFile(output, html);
console.log(JSON.stringify({ output, bytes: Buffer.byteLength(html), embeddedArtworks: credits.length }));
