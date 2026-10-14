import { useEffect, useState } from 'react';
import { ArrowUpRight, X } from 'lucide-react';
import Header, { Brand } from './components/common/Header';
import GalleryPage from './pages/GalleryPage';
import ArtworkDetailPage from './pages/ArtworkDetailPage';
import ArtistsPage from './pages/ArtistsPage';
import LibraryPage from './pages/LibraryPage';
import { artworks } from './data/catalog';
import { useCollection } from './hooks/useCollection';
import type { Route } from './types/catalog';

function readRoute(): Route {
  const [page,id]=window.location.hash.replace(/^#\/?/,'').split('/');
  if(page==='artwork' && artworks.some(a=>a.id===id)) return {page:'artwork',id};
  if(page==='artist' && id) return {page:'artist',id};
  if(page==='library'||page==='artists')return {page};
  return {page:'gallery'};
}

export default function App() {
  const [route,setRoute]=useState<Route>(readRoute);
  const [search,setSearch]=useState('');
  const [searchRevision,setSearchRevision]=useState(0);
  const [about,setAbout]=useState(false);
  const collection=useCollection();
  useEffect(()=>{const listener=()=>{setRoute(readRoute());window.scrollTo({top:0,behavior:'instant'});};window.addEventListener('hashchange',listener);return()=>window.removeEventListener('hashchange',listener);},[]);
  const routeId='id' in route?route.id:'';
  useEffect(()=>{if(route.page==='artwork')collection.recordView(route.id);},[route.page,routeId]);
  useEffect(()=>{const title=route.page==='artwork'?artworks.find(a=>a.id===routeId)?.titleKo:route.page==='library'?'내 서재':route.page==='artists'?'작가 이야기':'일상에 한 점, 나만의 미술관';document.title=`${title} — Docentalk`;},[route.page,routeId]);
  useEffect(()=>{if(!about)return;const listener=(e:KeyboardEvent)=>{if(e.key==='Escape')setAbout(false);};document.addEventListener('keydown',listener);return()=>document.removeEventListener('keydown',listener);},[about]);
  const navigate=(next:Route)=>{const hash='id' in next?`${next.page}/${next.id}`:next.page;if(window.location.hash===`#${hash}`){setRoute(next);window.scrollTo({top:0,behavior:'instant'});}else{window.location.hash=hash;}};
  return <><a className="skip-link" href="#main-content" onClick={e=>{e.preventDefault();document.getElementById('main-content')?.focus();document.getElementById('main-content')?.scrollIntoView();}}>본문으로 바로가기</a><Header route={route} navigate={navigate} viewedCount={new Set(collection.views.map(v=>v.artworkId)).size} onSearch={query=>{setSearch(query);setSearchRevision(v=>v+1);navigate({page:'gallery'});}}/><div id="main-content" className="main-content" tabIndex={-1}>{route.page==='gallery'&&<GalleryPage collection={collection} navigate={navigate} search={search} searchRevision={searchRevision}/>} {route.page==='artwork'&&<ArtworkDetailPage key={route.id} art={artworks.find(a=>a.id===route.id)!} collection={collection} navigate={navigate}/>} {(route.page==='artists'||route.page==='artist')&&<ArtistsPage collection={collection} navigate={navigate} artistId={route.page==='artist'?route.id:undefined}/>} {route.page==='library'&&<LibraryPage collection={collection} navigate={navigate}/>}</div><footer className="site-footer page-width"><div className="footer-top"><button className="brand" onClick={()=>navigate({page:'gallery'})}><Brand/></button><p>한 점의 그림이, 당신의 하루에 머물기를.</p><button className="text-link" onClick={()=>setAbout(true)}>Docentalk에 대하여<ArrowUpRight size={15}/></button></div><div className="footer-bottom"><span>© 2026 DOCENTALK. A LITTLE ART, EVERY DAY.</span><span>INTERACTIVE UI PROTOTYPE</span></div></footer>{about&&<div className="about-backdrop" onClick={()=>setAbout(false)}><section className="about-modal" role="dialog" aria-modal="true" aria-label="Docentalk 소개" onClick={e=>e.stopPropagation()}><button autoFocus className="about-close icon-button" onClick={()=>setAbout(false)} aria-label="소개 닫기"><X size={21}/></button><div className="eyebrow">ABOUT DOCENTALK</div><h2>나만의 속도로 만나는 미술.</h2><p>Docentalk는 열 명의 작가와 열두 점의 작품을 탐색하고, 도슨트와 이야기하며 감상의 순간을 모으는 미술관 UI 목업입니다.</p><p>좋아요, 팔로우, 감상 기록은 현재 브라우저에 저장됩니다. 도슨트는 준비된 예시 답변을 제공하며 실제 AI 서비스는 연결되어 있지 않습니다.</p><div className="about-divider"/><div className="eyebrow">DESIGN REFERENCES</div><p>절제된 갤러리, 작품 중심 편집, 확인 가능한 출처에서 영감을 받았습니다.</p>{[{name:'Timelens · Rylic Studio',url:'https://dribbble.com/shots/26018383-Timelens-Art-Gallery-Museum-Website'},{name:'Art Gallery · Maria Sy',url:'https://www.behance.net/gallery/153037463/Art-Gallery-Website-Maiskaia-Alla-UXUI-design'},{name:'Artsy · Collection discovery',url:'https://www.artsy.net/collect'},{name:'Perplexity · Source citations',url:'https://www.perplexity.ai/help-center/en/articles/10352895-how-does-perplexity-work'}].map(r=><a className="reference-link" key={r.name} href={r.url} target="_blank" rel="noreferrer">{r.name}<ArrowUpRight size={16}/></a>)}</section></div>}</>;
}
