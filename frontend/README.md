# frontend

React 애플리케이션입니다. Vite의 React + TypeScript 템플릿으로 프로젝트를 만들고 화면, 상태 관리, FastAPI 호출 코드를 둡니다.

## 구성

| 폴더 | 역할 |
| --- | --- |
| `public/` | 가공 없이 그대로 제공하는 정적 파일 |
| `src/` | 애플리케이션 소스 |

## 권장 라이브러리

| 용도 | 후보 | 이유 |
| --- | --- | --- |
| 라우팅 | React Router | 페이지 이동, 로그인 필요 화면 보호 |
| 서버 데이터 | TanStack Query | 목록·추천 캐시, 좋아요 후 추천 다시 불러오기 |
| 전역 상태 | Zustand 또는 Context | 로그인 사용자 정보 정도만 보관 |

## 실행 예시

```bash
npm install
npm run dev        # 기본 주소 http://localhost:5173
```

API 서버 주소는 `frontend/.env`의 `VITE_API_BASE_URL`로 지정합니다. Vite는 `frontend/` 폴더 안의 `.env`만 읽으므로 루트 `.env`와 별도로 만듭니다.

```bash
VITE_API_BASE_URL=http://localhost:8000
```

## 규칙

- 데이터베이스에 직접 접근하지 않습니다. 모든 데이터는 FastAPI를 통해 주고받습니다.
- 추천 순위 계산, 좋아요 중복 검사 같은 로직을 프론트에 두지 않습니다. 화면은 받은 결과를 보여 주기만 합니다.
- API 키를 프론트 코드나 `.env`에 넣지 않습니다. `VITE_`로 시작하는 값은 빌드 결과에 그대로 노출됩니다.
