# docent

작품 도슨트 채팅(`POST /api/artworks/{id}/chat`, SSE 포함)의 답변 흐름을 담당합니다. `rag/`의 분류·검색·프롬프트와 `services/`의 카탈로그·추천·마이페이지·채팅 저장을 엮어 근거 있는 답변을 만듭니다.

| 파일 | 담당 |
| --- | --- |
| `service.py` | JSON 도슨트 답변. 질문 분류·범위 판정·검색·답변 생성·답변 검증, 추천 요청 분기 |
| `stream.py` | SSE 도슨트 답변. `service.py`와 같은 답변 계약을 증분 이벤트로 전달 |
| `grounding.py` | 검색 맥락·스타일·멀티턴 검색어 구성, 출처·편집 근거 검증 |
| `scope.py` | 현재 질문이 선택 작품에 관한 것인지 판정하는 별도 모델 호출 |
| `collection_suggestions.py` | 실질 질문 3회 이후 첫 성공 답변에 컬렉션 담기 제안 (규칙 기반, 저장하지 않음) |

## 규칙

- 의존 방향은 `api/routes/chat.py → docent → services / rag`입니다. `services/`와 `rag/`는 이 폴더를 import하지 않습니다.
- 채팅은 데이터를 변경하지 않습니다. 컬렉션 제안은 제안만 반환하고, 사용자가 확정하면 컬렉션 REST 호출로 저장합니다. 로그인 대화 저장은 `services/chat_service.py`가 합니다.
- 프롬프트 규칙은 [프롬프트 문서](../../../docs/prompts.md), 검색 결과 형식은 [`rag/README.md`](../rag/README.md)를 참고합니다.
