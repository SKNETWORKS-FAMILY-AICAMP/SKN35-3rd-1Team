export type ArtistId = 'van-gogh' | 'monet' | 'klimt' | 'cezanne' | 'gauguin' | 'rembrandt' | 'caravaggio' | 'schiele' | 'kim-hongdo' | 'jeong-seon';

export interface Artwork {
  id: string;
  file: string;
  artist: string;
  artistKo: string;
  title: string;
  titleKo: string;
  year: string;
  movement: string;
  movementKo: string;
  sourceUrl: string;
  imageUrl: string;
  license: string;
  museumUrl?: string | null;
  artistId: ArtistId;
  note: string;
  color: string;
}

export interface Artist {
  id: ArtistId;
  name: string;
  english: string;
  years: string;
  movement: string;
  line: string;
}

export interface ViewRecord { artworkId: string; date: string }
export type Route = { page: 'gallery' | 'artists' | 'library' } | { page: 'artwork'; id: string } | { page: 'artist'; id: string };
