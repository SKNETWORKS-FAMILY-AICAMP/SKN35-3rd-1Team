import { ArrowUpRight, Heart } from 'lucide-react';
import type { Artwork } from '../../types/catalog';
import { artImage } from '../../data/catalog';

interface Props { art: Artwork; liked: boolean; onLike: () => void; onOpen: () => void; compact?: boolean }
export default function ArtworkCard({ art, liked, onLike, onOpen, compact }: Props) {
  return <article className={`art-card ${compact ? 'compact' : ''}`}>
    <div className="art-card-frame">
      <button className="art-card-open" onClick={onOpen} aria-label={`${art.titleKo} 작품 보기`}>
        <img src={artImage(art)} alt={`${art.artistKo}, ${art.titleKo}`} loading="lazy" />
        <span className="art-card-overlay"><span>작품 만나기</span><ArrowUpRight size={19} /></span>
      </button>
      <button className={`like-button ${liked ? 'liked' : ''}`} onClick={onLike} aria-label={`${art.titleKo} 좋아요 ${liked ? '취소' : '하기'}`} aria-pressed={liked}><Heart size={17} fill={liked ? 'currentColor' : 'none'} /></button>
      <span className="movement-tag">{art.movementKo}</span>
    </div>
    <div className="art-card-info"><button onClick={onOpen} className="art-title">{art.titleKo}</button><span>{art.year}</span></div>
    <p className="art-card-artist">{art.artistKo}<span>{art.artist}</span></p>
  </article>;
}
