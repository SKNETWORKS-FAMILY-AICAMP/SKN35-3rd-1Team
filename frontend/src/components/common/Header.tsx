import { ArrowUpRight, BookOpen, Search, X } from 'lucide-react';
import { useState } from 'react';
import type { Route } from '../../types/catalog';

export function Brand() { return <><span className="brand-mark" aria-hidden="true"><i /></span><span className="brand-word">Docentalk<span>AI ART DOCENT</span></span></>; }
interface Props { route: Route; navigate: (route: Route) => void; onSearch: (query: string) => void; viewedCount: number }
export default function Header({ route, navigate, onSearch, viewedCount }: Props) {
  const [searchOpen, setSearchOpen] = useState(false);
  const [query, setQuery] = useState('');
  const active = route.page === 'artwork' ? 'gallery' : route.page === 'artist' ? 'artists' : route.page;
  return <header className="site-header"><div className="header-inner">
    <button className="brand" onClick={() => navigate({ page: 'gallery' })} aria-label="Docentalk 홈"><Brand /></button>
    <nav aria-label="주 메뉴">{[{ page: 'gallery', label: '발견하기' }, { page: 'artists', label: '작가 이야기' }, { page: 'library', label: '내 서재' }].map(item => <button key={item.page} className={active === item.page ? 'active' : ''} onClick={() => navigate({ page: item.page as 'gallery' | 'artists' | 'library' })}>{item.label}{item.page === 'library' && viewedCount > 0 && <span className="nav-count">{viewedCount}</span>}</button>)}</nav>
    <div className="header-tools"><span className="header-tagline">일상에 한 점.</span><button className="icon-button search-toggle" onClick={() => setSearchOpen(v => !v)} aria-label={searchOpen ? '검색 닫기' : '작품 검색'}>{searchOpen ? <X size={21} /> : <Search size={20} />}</button><button className="profile-button" onClick={() => navigate({ page: 'library' })} aria-label="나의 감상 기록"><BookOpen size={17} /></button></div>
  </div>{searchOpen && <form className="global-search" onSubmit={e => { e.preventDefault(); onSearch(query); setSearchOpen(false); }}><Search size={20}/><input autoFocus value={query} onChange={e => setQuery(e.target.value)} placeholder="작품명이나 작가 이름을 입력하세요" aria-label="전체 작품 검색어"/><button className="text-link" type="submit">찾아보기<ArrowUpRight size={17}/></button></form>}</header>;
}
