# 목업 타입

갱신: 2026-10-15 · dev `6f0b40a` 기준. **초기 React 목업 보존 문서**입니다.

현재 TypeScript 타입 파일은 `catalog.ts`입니다. `auth.ts`, `chat.ts`, `library.ts`, `recommendation.ts`는 이전 계획안이며 실제 API 계약 구현 파일이 아닙니다.

운영 Flutter는 Dart 모델을 사용합니다. API 필드·nullable 값·출처·페이지 응답은 해당 모델에서 매핑하고 변경 시 서버 schema와 함께 확인합니다.

## 현재 Flutter 구현

- [작품·작가·도슨트 모델](../../lib/models.dart)
- [감상 모델](../../lib/diary.dart)
- [컬렉션·취향 모델](../../lib/mypage.dart)
- [공개 프로필·팔로우 모델](../../lib/social.dart)
