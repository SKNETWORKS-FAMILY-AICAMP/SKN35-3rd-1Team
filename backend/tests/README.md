# tests

자동 테스트와 RAG 테스트 질문셋을 둡니다.

## 들어갈 파일

- `conftest.py`: 공통 준비 (가짜 repository, 테스트용 앱)
- `test_recommendation_service.py`: 추천 규칙
- `test_library_service.py`: 열람 날짜 계산, 캘린더 집계
- `test_chat_scope.py`: 범위 밖 질문 거절, 출처 포함 여부
- `test_api_*.py`: 엔드포인트 요청·응답 형식
- `questions/`: 테스트 질문셋 (사실 확인형, 비교형, 범위 밖)
- `questions/prompt-accuracy.json`: 근거·판본·출처·복제·멀티턴 정확도 집중 9문항
- `fixtures/chat-responses.json`: 실제 LLM 없이 응답 형식을 확인하는 가짜 결과
- `contracts/activity-cases.json`: 좋아요·팔로우·열람 기록 구현 시 옮겨 쓸 계약 사례
- `test_evaluation_fixtures.py`: 위 평가 자료의 개수와 필수 필드 검사

## 무엇으로 테스트하는가

| 대상 | 방법 | 이유 |
| --- | --- | --- |
| 서비스 규칙 (추천 분기, 작가당 1개, 날짜 계산) | 가짜 repository | DB 없이 빠르게 돌릴 수 있음 |
| API 형식 | FastAPI 테스트 클라이언트 + 가짜 서비스 | 프론트와의 약속 확인 |
| repository의 벡터 쿼리 | TiDB의 테스트용 데이터베이스 | `VECTOR`와 거리 함수는 TiDB에서만 동작함. SQLite로 대신할 수 없음 |
| 답변 품질 | 질문셋을 돌려 결과를 사람이 확인 | 자동 판정이 어려움 |

## 꼭 확인할 추천 테스트 항목

- 이미 좋아요한 작품과 현재 작품이 결과에 없는가
- 한 작가의 작품이 3개 중 2개 이상 나오지 않는가
- 좋아요가 없는 사용자에게도 3개가 반환되는가
- 팔로우한 작가가 추천 작가에 없는가

## 규칙

- 운영 데이터베이스에서 테스트하지 않습니다. TiDB가 필요한 테스트는 별도 데이터베이스 이름을 씁니다.
- 테스트에서 실제 LLM·임베딩 API를 호출하지 않습니다. 호출이 필요한 품질 평가는 질문셋 실행으로 분리합니다.
- 범위 밖 질문의 거절 비율은 발표의 환각 방지 근거 수치가 됩니다. 실행 결과를 `docs/`에 남깁니다.
