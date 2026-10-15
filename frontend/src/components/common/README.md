# common components

여러 기능에서 함께 쓰는 기본 컴포넌트를 둡니다.

예: `Button`, `Spinner`, `ErrorMessage`, `EmptyState`, `Header`, `Modal`, `Tabs`.

## 규칙

- 특정 기능(작품, 채팅, 추천)에 대한 지식이 없어야 합니다. 작품 타입을 import하게 되면 그 컴포넌트는 여기에 둘 것이 아닙니다.
- 갤러리의 작가별·사조별 탭은 `Tabs`를 사용합니다.
