# 목업 추천 구성 계획

갱신: 2026-10-15 · dev `6f0b40a` 기준. **초기 React 목업 보존 문서**입니다.

이 폴더에는 별도 React 추천 컴포넌트가 없습니다. 초기 목업 정적 추천과 실제 서버 추천을 구분합니다.

현재 Flutter의 관련·맞춤 작품/작가는 서버 순서와 추천 이유를 표시합니다. 계산은 서버에서 수행하고 프론트는 오류·빈 상태를 별도로 안내합니다. AI 취향 테마는 일반 추천과 다른 개인 컬렉션 기능이며 캐시·생성 조건을 따릅니다.

## 현재 Flutter 구현

- [현재 맞춤 추천](../../../lib/ui/personal_recommendations.dart)
- [관련 작품](../../../lib/pages/detail_page.dart)
- [AI 취향 모음](../../../lib/ui/collection_workspace.dart)
