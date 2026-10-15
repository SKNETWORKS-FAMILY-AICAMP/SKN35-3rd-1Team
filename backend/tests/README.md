# tests

현재 자동 테스트는 도슨트·질문 분류·컬렉션 제안과 평가 계산을 검증합니다. `backend/`에서 실행합니다.

```bash
uv run pytest
```

| 파일 | 검증 대상 |
| --- | --- |
| `test_classifier.py` | 작가 별칭·범위 밖 질문·비교 근거·추천 분기 |
| `test_prompts.py` | 스타일별 프롬프트, 정확도·출처 규칙과 구조화 답변 |
| `test_docent_grounding.py` | 검색 맥락·스타일·출처·편집 근거·잘못된 문서 ID 거절 |
| `test_docent_preferences.py` | JSON 답변의 스타일·근거·범위·정정 처리 |
| `test_docent_scope.py` | 현재 질문과 필요한 이전 맥락에 따른 범위 판정 |
| `test_docent_stream.py` | SSE 증분·최종 답변·출처 검증·범위 거절 |
| `test_docent_recommendation_copy.py` | 추천 안내 문구와 비로그인 대체 추천 |
| `test_collection_suggestions.py` | 실질 질문 3회 이후 첫 성공 답변에만 제안, 거절·정정 제외 |
| `test_eval_round3.py` | 검색 평가 지표 계산 |

`questions/`는 RAG·프롬프트 정확도·청크 정답·3차 보충 평가 질문셋입니다. `fixtures/chat-responses.json`과 `contracts/activity-cases.json`은 가짜 응답·활동 계약 참고 자료입니다.

외부 모델·검색 호출은 자동 테스트에서 대체합니다. 실제 모델·TiDB·Chroma를 사용하는 품질 평가는 `scripts.eval_docent`·`scripts.eval_retrieval`·`scripts.eval_round3`로 분리하고 실행 옵션은 각 명령의 `--help`를 확인합니다. DB를 사용하는 평가는 별도 환경에서 진행합니다.

현재 `test_api.py`·`conftest.py`·추천/서재 서비스 전용 테스트는 저장소에 없습니다. API 계약은 라우트·Pydantic 스키마와 [API 명세](../../docs/api.md)를 대조하고, 서버의 `/openapi.json`·`/docs`에서 확인합니다.
