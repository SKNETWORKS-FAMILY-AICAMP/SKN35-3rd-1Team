# 목업 작품 카드

갱신: 2026-10-15 · dev `6f0b40a` 기준. **초기 React 목업 보존 문서**입니다.

`ArtworkCard.tsx`는 초기 목업의 정적 작품 카드입니다. 좋아요는 로컬 훅을 통해 브라우저에 저장됩니다. 이 폴더에 `ArtworkGrid.tsx`, `ArtworkInfo.tsx`, `LikeButton.tsx` 구현은 없습니다.

운영 작품 UI는 Flutter를 사용하며 실제 API ID·출처·이미지·좋아요 요청을 연결합니다. 김홍도·정선 박물관 이미지 대응은 정확한 원본 URL 매핑을 유지합니다.

## 현재 Flutter 구현

- [현재 작품 목록](../../../lib/pages/artworks_page.dart)
- [현재 작품 상세](../../../lib/pages/detail_page.dart)
- [현재 카드·하트·이미지](../../../lib/ui/design.dart)
- [박물관 이미지 매핑](../../../lib/ui/museum_artwork_images.dart)
