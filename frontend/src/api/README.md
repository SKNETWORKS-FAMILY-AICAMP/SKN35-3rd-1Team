# 목업 API 폴더

갱신: 2026-10-15 · dev `6f0b40a` 기준. **초기 React 목업 보존 문서**입니다.

이 폴더에는 현재 실행되는 TypeScript API 클라이언트가 없습니다. 이전 `client.ts`, `auth.ts`, `chat.ts` 등 목록은 계획안이었으며 구현 파일 목록이 아닙니다.

운영 Flutter는 `ArtlogApi`에서 공통 주소·Firebase Bearer 토큰·401 한 번 갱신·SSE·오류를 처리합니다. 로그인은 Firebase SDK이며 기존 서버 로그인 API를 운영 인증으로 호출하지 않습니다.

## 현재 Flutter 구현

- [현재 API 어댑터](../../lib/api/artlog_api.dart)
- [엔드포인트 계약](../../docs/endpoints.md)
