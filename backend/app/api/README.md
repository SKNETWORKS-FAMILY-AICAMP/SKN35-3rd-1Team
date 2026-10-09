# api

기능별 라우터를 하나로 묶어 `main.py`에 넘깁니다.

## 들어갈 파일

- `router.py`: `routes/`의 라우터를 모아 공통 접두어(`/api`)로 등록

## 규칙

- 라우터 함수는 세 가지만 합니다: 입력 검증(Pydantic), 서비스 호출, 응답 스키마로 반환.
- 로그인한 사용자와 DB 세션은 `core/deps.py`의 의존성으로 받습니다.
- 오류는 서비스가 던진 예외를 `core/exceptions.py`의 처리기가 HTTP 응답으로 바꿉니다. 라우터마다 try/except를 쓰지 않습니다.
