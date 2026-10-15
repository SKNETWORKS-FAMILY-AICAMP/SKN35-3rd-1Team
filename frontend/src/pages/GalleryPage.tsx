import { ArrowRight, ArrowUpRight, ChevronDown, Flower2, Search, Sparkles, X } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { artists, artworks, artImage } from '../data/catalog';
import ArtworkCard from '../components/artwork/ArtworkCard';
import type { Collection } from '../hooks/useCollection';
import type { Route } from '../types/catalog';

interface Props { collection: Collection; navigate: (route: Route) => void; search: string; searchRevision: number }
export default function GalleryPage({ collection, navigate, search, searchRevision }: Props) {
  const [mode, setMode] = useState('movement');
  const [filter, setFilter] = useState('전체');
  const [query, setQuery] = useState(search);
  const [sort, setSort] = useState('curated');
  const [visibleCount, setVisibleCount] = useState(8);
  useEffect(() => { setQuery(search); if (search) document.getElementById('collection')?.scrollIntoView({ behavior: 'smooth' }); }, [search, searchRevision]);
  const hero = artworks[0];
  const filters = mode === 'artist' ? ['전체', ...artists.map(a => a.name)] : ['전체', '인상주의', '후기인상주의', '빈 분리파', '표현주의', '바로크', '조선 회화'];
  const filtered = useMemo(() => {
    const list = artworks.filter(a => (filter === '전체' || (mode === 'artist' ? a.artistKo === filter : a.movementKo === filter)) && `${a.titleKo} ${a.title} ${a.artistKo} ${a.artist}`.toLowerCase().includes(query.toLowerCase()));
    if (sort === 'year') return list.sort((a, b) => Number(a.year.match(/\d{4}/)?.[0] ?? 9999) - Number(b.year.match(/\d{4}/)?.[0] ?? 9999));
    if (sort === 'name') return list.sort((a, b) => a.titleKo.localeCompare(b.titleKo, 'ko'));
    return list.sort((a, b) => Number(collection.follows.includes(b.artistId)) - Number(collection.follows.includes(a.artistId)));
  }, [filter, mode, query, sort, collection.follows]);
  const reset = () => { setFilter('전체'); setQuery(''); };
  return <>
    <section className="hero page-width">
      <div className="hero-copy"><div className="eyebrow"><span className="mini-star">✳</span> A LITTLE ART, EVERY DAY</div><h1>그림을 보는 시간,<br/>나를 발견하는 순간<span>.</span></h1><p>한 점의 그림에서 시작되는 새로운 이야기.<br/>나만의 속도로, 나만의 미술관을 만나보세요.</p><button className="primary-button" onClick={() => document.getElementById('collection')?.scrollIntoView({ behavior: 'smooth' })}>오늘의 그림 발견하기<ArrowUpRight size={19}/></button><div className="hero-foot"><span className="overlap-dots">{artworks.slice(0,3).map(a => <img key={a.id} src={artImage(a)} alt=""/>)}</span><p><strong>10명의 거장</strong>과 함께하는<br/>작지만 깊은 미술 여행</p></div></div>
      <div className="hero-art"><button className="hero-art-button" onClick={() => navigate({ page: 'artwork', id: hero.id })} aria-label={`오늘의 작품 ${hero.titleKo} 감상하기`}><img src={artImage(hero)} alt={`${hero.artistKo}의 ${hero.titleKo}`} fetchPriority="high"/><div className="hero-image-shade"/><span className="hero-edition">CURATOR’S PICK<span>ART NOTE 01</span></span><div className="hero-caption"><div><span>오늘, 이 그림</span><h2>{hero.titleKo}</h2><p>{hero.artistKo} · {hero.year}</p></div><span className="circle-arrow"><ArrowUpRight size={25}/></span></div></button><div className="image-label"><span>A moment to pause, a world to discover.</span><span>EST. 2026</span></div></div>
    </section>
    <section className="collection-section page-width" id="collection"><div className="section-heading"><div><div className="eyebrow">THE COLLECTION</div><h2>어떤 그림에 마음이 머무나요?</h2><p>마음이 가는 작품을 고르고, 그 안의 이야기를 들어보세요.</p></div><span className="collection-total">{artworks.length}<span> ARTWORKS</span></span></div>
      <div className="filter-toolbar"><div className="view-tabs" role="tablist" aria-label="작품 분류"><button role="tab" aria-selected={mode==='movement'} className={mode==='movement'?'active':''} onClick={() => {setMode('movement');setFilter('전체');}}>사조별로 보기</button><button role="tab" aria-selected={mode==='artist'} className={mode==='artist'?'active':''} onClick={() => {setMode('artist');setFilter('전체');}}>작가별로 보기</button></div><label className="collection-search"><Search size={17}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="어떤 작품을 찾으세요?" aria-label="작품 또는 작가 검색"/>{query && <button onClick={()=>setQuery('')} aria-label="검색어 지우기"><X size={15}/></button>}</label></div>
      <div className="filter-chips" aria-label={mode === 'artist' ? '작가 선택' : '사조 선택'}>{filters.map(f=><button key={f} className={filter===f?'selected':''} onClick={()=>{setFilter(f);setVisibleCount(8);}} aria-pressed={filter===f}>{f}</button>)}</div>
      <div className="results-toolbar"><span>총 <strong>{filtered.length}</strong>점의 작품{collection.follows.length > 0 && <span className="following-note"> · 팔로우한 작가 먼저</span>}</span><label className="sort-control"><select aria-label="작품 정렬" value={sort} onChange={e=>setSort(e.target.value)}><option value="curated">큐레이터 추천순</option><option value="year">제작 연도순</option><option value="name">작품 이름순</option></select><ChevronDown size={14}/></label></div>
      {filtered.length ? <div className="artwork-grid">{filtered.slice(0,visibleCount).map(a=><ArtworkCard key={a.id} art={a} liked={collection.likes.includes(a.id)} onLike={()=>collection.toggleLike(a.id)} onOpen={()=>navigate({page:'artwork',id:a.id})}/>)}</div> : <div className="empty-state"><Flower2 size={34}/><h3>아직 만나지 못한 그림이네요.</h3><p>다른 작품명이나 작가 이름으로 찾아보세요.</p><button className="secondary-button" onClick={reset}>모든 작품 보기<ArrowRight size={17}/></button></div>}
      {filtered.length > visibleCount && <div className="load-more"><button className="secondary-button" onClick={()=>setVisibleCount(v=>v+8)}>그림 더 만나보기<span>{filtered.length-visibleCount}</span><ArrowRight size={17}/></button></div>}
    </section>
    <section className="docent-banner page-width"><div className="banner-art"><img src={artImage(artworks.find(a=>a.artistId==='monet') ?? hero)} alt="모네의 수련"/></div><div className="banner-copy"><div className="eyebrow"><Sparkles size={15}/> YOUR PERSONAL DOCENT</div><h2>그림 앞에서 생긴 물음표,<br/>이야기가 되는 순간.</h2><p>작품을 고르고 도슨트에게 물어보세요.<br/>답변의 출처까지, 함께 살펴볼 수 있어요.</p><button className="light-button" onClick={()=>navigate({page:'artwork',id:hero.id})}>도슨트와 대화해 보기<ArrowUpRight size={18}/></button></div><span className="banner-decoration" aria-hidden="true">✳</span></section>
    <section className="artist-preview page-width"><div className="section-heading"><div><div className="eyebrow">BEHIND THE CANVAS</div><h2>그림 너머, 작가의 이야기</h2></div><button className="text-link" onClick={()=>navigate({page:'artists'})}>작가 모두 보기<ArrowUpRight size={17}/></button></div><div className="artist-preview-grid">{artists.slice(0,4).map(a=>{const art=artworks.find(w=>w.artistId===a.id)!;return <button className="artist-preview-card" key={a.id} onClick={()=>navigate({page:'artist',id:a.id})}><img src={artImage(art)} alt={`${a.name} 작품 일부`}/><div><span>{a.movement}</span><h3>{a.name}</h3><p>{a.english}</p></div><ArrowUpRight size={19}/></button>;})}</div></section>
  </>;
}
