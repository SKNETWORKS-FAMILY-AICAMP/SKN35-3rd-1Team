# 목업 공통 헤더

갱신: 2026-10-15 · dev `6f0b40a` 기준. **초기 React 목업 보존 문서**입니다.

`Header.tsx`는 초기 React 목업의 공통 메뉴입니다. 이 폴더를 현재 Flutter 공통 컴포넌트 위치로 사용하지 않습니다.

현재 헤더·모바일 메뉴·이젤 로고·설정 패널은 `shell.dart`, 버튼·입력·대화상자는 테마와 surfaces에서 관리합니다. 본문 공통 너비는 1280px이며 현재 폰트는 Chiron Sung HK입니다. 설정 패널의 로그아웃은 하단에 있습니다.

## 현재 Flutter 구현

- [현재 헤더·설정](../../../lib/ui/shell.dart)
- [공통 테마](../../../lib/ui/app_theme.dart)
- [버튼·표면 스타일](../../../lib/ui/surfaces.dart)
