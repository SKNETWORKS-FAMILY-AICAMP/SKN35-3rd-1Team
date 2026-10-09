# frontend/src

React 애플리케이션의 소스 코드입니다.

## 폴더별 역할

| 폴더 | 역할 | 의존해도 되는 곳 |
| --- | --- | --- |
| `pages/` | URL과 연결되는 화면. 컴포넌트를 조립함 | `components`, `hooks`, `stores` |
| `components/` | 재사용 UI 조각 | `hooks`, `types` |
| `hooks/` | 조회·변경 로직과 캐시 관리 | `api`, `types` |
| `api/` | FastAPI 호출 함수 | `types` |
| `stores/` | 로그인 상태 등 전역 상태 | `types` |
| `routes/` | 라우터 정의, 접근 규칙 | `pages`, `stores` |
| `types/` | API 응답 타입 | (없음) |
| `assets/` | 로고, 아이콘, 스타일 | (없음) |

## 데이터가 흐르는 방향

```text
pages → components → hooks → api → FastAPI
```

컴포넌트가 `api/`의 함수를 직접 부르지 않고 훅을 거치게 하면, 로딩·오류·캐시 처리가 한 곳에 모입니다.

## 이 폴더 바로 아래에 둘 파일

- `main.tsx`: 앱 시작점
- `App.tsx`: 라우터와 공통 레이아웃 연결
