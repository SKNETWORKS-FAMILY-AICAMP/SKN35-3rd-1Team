# 목업 전역 상태 계획 폴더

갱신: 2026-10-15 · dev `6f0b40a` 기준. **초기 React 목업 보존 문서**입니다.

이 폴더에는 `authStore.ts` 구현이 없습니다. React 목업은 컴포넌트 상태와 `useCollection`의 localStorage를 사용합니다.

운영 Flutter는 `ArtlogState`에서 공유 상태·요청 캐시·계정 변경을 관리합니다. Firebase SDK가 세션을 보관하고 API 요청 때 ID 토큰을 가져옵니다. 비밀번호나 ID 토큰을 앱의 SharedPreferences에 별도로 저장하지 않습니다. 미리보기 개인 기록은 브라우저 저장과 구분합니다.

## 현재 Flutter 구현

- [현재 공유 상태](../../lib/state.dart)
- [현재 인증](../../lib/auth/firebase_session.dart)
- [작품별 대화 상태](../../lib/docent_conversation.dart)
