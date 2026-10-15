import credits from './artworks.json';
import type { Artist, ArtistId, Artwork } from '../types/catalog';

export const artists: Artist[] = [
  { id: 'van-gogh', name: '빈센트 반 고흐', english: 'Vincent van Gogh', years: '1853–1890', movement: '후기인상주의', line: '붓끝에 담긴, 가장 뜨거운 마음.' },
  { id: 'monet', name: '클로드 모네', english: 'Claude Monet', years: '1840–1926', movement: '인상주의', line: '빛이 머무는 순간을 그리다.' },
  { id: 'klimt', name: '구스타프 클림트', english: 'Gustav Klimt', years: '1862–1918', movement: '빈 분리파', line: '황금빛으로 기억하는 아름다움.' },
  { id: 'cezanne', name: '폴 세잔', english: 'Paul Cézanne', years: '1839–1906', movement: '후기인상주의', line: '익숙한 풍경에서 발견한 새로운 질서.' },
  { id: 'gauguin', name: '폴 고갱', english: 'Paul Gauguin', years: '1848–1903', movement: '후기인상주의', line: '선명한 색채 너머, 또 다른 세계.' },
  { id: 'rembrandt', name: '렘브란트', english: 'Rembrandt van Rijn', years: '1606–1669', movement: '바로크', line: '어둠 속에서 만나는 사람의 온기.' },
  { id: 'caravaggio', name: '카라바조', english: 'Caravaggio', years: '1571–1610', movement: '바로크', line: '빛과 그림자가 만들어낸 한 장면.' },
  { id: 'schiele', name: '에곤 실레', english: 'Egon Schiele', years: '1890–1918', movement: '표현주의', line: '솔직한 선으로 마주하는 내면.' },
  { id: 'kim-hongdo', name: '김홍도', english: 'Kim Hong-do', years: '1745–1806 이후', movement: '조선 회화', line: '우리의 일상을 담은 다정한 시선.' },
  { id: 'jeong-seon', name: '정선', english: 'Jeong Seon', years: '1676–1759', movement: '조선 회화', line: '우리 산천에서 찾은 깊고 넓은 풍경.' },
];

const notes: Record<string, string> = {
  'van-gogh-wheatfield': '바람을 따라 일렁이는 밀밭, 하늘로 솟아오르는 나무. 오늘은 고흐의 풍경 속을 천천히 걸어보세요.',
  'van-gogh-garden': '초록빛 정원을 따라 시선이 머뭅니다. 서로 다른 방향의 붓질을 천천히 찾아보세요.',
  'van-gogh-bedroom': '의자와 침대, 창문과 벽. 익숙한 방이 색과 선을 만나 특별한 풍경이 됩니다.',
  'monet-waterlilies': '수면에 비친 하늘과 꽃 사이, 위아래의 경계가 사라집니다. 그림 속 빛을 따라가 보세요.',
  'klimt-kiss': '황금빛 무늬 속에 머무는 두 사람. 작은 패턴과 부드러운 얼굴의 대비를 발견해 보세요.',
  'cezanne-apples': '탁자 위에 놓인 사과가 하나의 풍경이 됩니다. 둥근 형태와 색의 균형을 살펴보세요.',
  'gauguin-day-of-god': '선명한 색면들이 한 장면을 이루고 있습니다. 색이 전하는 분위기를 먼저 느껴보세요.',
  'rembrandt-gold-chain': '어두운 배경에서 천천히 드러나는 얼굴. 빛이 닿은 곳과 그림자가 머문 곳을 따라가 보세요.',
  'caravaggio-emmaus': '탁자를 둘러싼 인물들의 손짓과 시선. 그림 속 이야기가 시작되는 순간을 찾아보세요.',
  'schiele-wally': '간결한 선과 강렬한 눈빛이 마주합니다. 인물의 표정과 색의 대비를 살펴보세요.',
  'kim-hongdo-ssireum': '구경꾼들의 표정까지 생생한 한판. 원을 이루는 사람들 사이로 시선을 움직여 보세요.',
  'jeong-seon-inwang': '짙은 먹빛 바위와 옅은 안개가 만납니다. 비 갠 산의 고요함을 천천히 느껴보세요.',
};

const artistFor = (id: string): ArtistId => artists.find(a => id.startsWith(a.id))?.id ?? 'van-gogh';
const order = ['van-gogh-wheatfield', 'monet-waterlilies', 'klimt-kiss', 'kim-hongdo-ssireum', 'gauguin-day-of-god', 'cezanne-apples', 'rembrandt-gold-chain', 'jeong-seon-inwang', 'van-gogh-bedroom', 'caravaggio-emmaus', 'schiele-wally', 'van-gogh-garden'];
export const artworks: Artwork[] = (credits as Omit<Artwork, 'artistId' | 'note' | 'color'>[])
  .map(a => ({ ...a, year: String(a.year), artistId: artistFor(a.id), movementKo: artists.find(artist => artist.id === artistFor(a.id))!.movement, note: notes[a.id] ?? '한 점의 그림 속에서 나만의 이야기를 발견해 보세요.', color: '#e8e6dc' }))
  .sort((a, b) => order.indexOf(a.id) - order.indexOf(b.id));

export const artImage = (art: Artwork) => art.file.startsWith('data:') ? art.file : `/artworks/${art.file.split('/').pop()}`;
export const localDate = (date = new Date()) => new Intl.DateTimeFormat('sv-SE', { timeZone: 'Asia/Seoul' }).format(date);
