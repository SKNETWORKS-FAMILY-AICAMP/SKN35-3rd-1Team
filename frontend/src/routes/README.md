# 목업 경로 계획 폴더

갱신: 2026-10-15 · dev `6f0b40a` 기준. **초기 React 목업 보존 문서**입니다.

이 폴더에는 `router.tsx`·`ProtectedRoute.tsx` 구현이 없습니다. React 목업은 `src/App.tsx`에서 hashchange와 로컬 상태로 화면을 전환합니다.

운영 앱은 Flutter GoRouter의 해시 라우팅을 사용합니다. 로그인 필요 화면은 안내·로그인 대화상자를 제공하며 `/login` 페이지로 이동하는 구조가 아닙니다. 최종 권한 검사는 서버 토큰·소유권 검사입니다.

## 현재 Flutter 구현

- [현재 GoRouter](../../lib/main.dart)
- [계정 안내](../../lib/ui/collection_workspace.dart)
- [서버 인증 경계](../../docs/endpoints.md)
