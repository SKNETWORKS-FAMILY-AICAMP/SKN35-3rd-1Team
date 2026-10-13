# rag

문서 검색과 답변 생성을 담당합니다. 좋아요 기반 추천은 RAG가 아니므로 여기 두지 않고 `services/`에 둡니다.

## 들어갈 파일

- `chunking.py`: 문서를 청크로 자르는 규칙 (길이, 겹침)
- `classifier.py`: 검색 전에 질문을 `rag` / `other_artist` / `refuse` / `recommend`로 분류 (규칙 기반 수퍼바이저)
- `retriever.py`: 질문을 임베딩하고 선택한 작품 범위 안에서 가까운 청크를 찾음
- `prompts.py`: 시스템 프롬프트와 거절 규칙
- `chain.py`: 검색 결과와 질문, 이전 대화를 LLM에 넘겨 답변 생성
- `citations.py`: 답변에 쓰인 청크를 출처 목록으로 정리

## 검색 결과 형식 (팀 약속)

`retriever.retrieve(session, artwork_id, question, k=5)`는 LangChain `Document` 리스트를 돌려줍니다 (기획서 v2 약속 2). 답변 생성 담당은 이 형식만 맞으면 가짜 데이터로 먼저 개발할 수 있습니다.

- `page_content`: 청크 본문. 머리말 `문서 제목 > 섹션`이 붙어 있어 프롬프트에 그대로 넣을 수 있습니다.
- 순서: 거리 순위 k개(오름차순) → 거리와 상관없이 항상 넣는 청크(`pinned`). 범위가 비면(없는 작품) 빈 리스트입니다.

| `metadata` 키 | 설명 |
| --- | --- |
| `chunk_id`, `chunk_index` | 청크 id(= Chroma id = `document_chunks.id`)와 문서 안 순서 |
| `document_id`, `doc_key`, `doc_type` | 문서 id, 고유 키, `artist_bio` / `artwork_commentary` / `artist_comparison` |
| `title`, `source_name`, `source_url`, `license` | 출처 표시. `license`는 괄호까지 자르지 않고 보여 줌 (handoff 6절) |
| `distance` | 코사인 거리 (작을수록 가까움) |
| `pinned` | `True`면 거리 순위가 아니라 규칙으로 들어온 청크: 그 작품을 언급한 연표 사건, 범위 안 `답변 시 주의` 보정문 |
| `annotation` | `None` / `"감상 포인트"`(편집 보충문, 규칙 8) / `"답변 시 주의"`(보정문, 원문보다 우선, 규칙 7) |
| `basis_sources` | `annotation`이 있을 때 편집 근거 `[{"source_name", "source_url"}]`. 출처 표시에 함께 보여 줌 |

**거리로 거절하지 않습니다.** handoff 9절 질문으로 재 보니 범위 밖 질문(피카소·클림트)의 최상위 거리(0.68·0.70)가 답할 수 있는 질문의 범위(0.33~0.84) 안에 들어갑니다. 거절은 프롬프트 규칙(근거에 없으면 모른다고 답함)으로 판단하고, 거리 값은 로그·튜닝용으로만 씁니다.

## 검색 범위

챗봇은 선택한 작품과 관련된 문서 안에서만 검색합니다.

- 그 작품의 해설 문서 (`documents.artwork_id`)
- 그 작품 작가의 생애 문서와 그 작가가 포함된 비교 문서 (`document_artists`)

범위에 드는 문서 id를 TiDB에서 구하고, Chroma에서 `where={"document_id": {"$in": ...}}`로 그 안에서만 검색합니다.

## 규칙

- **문서 밖 답변 금지**: 검색 결과가 없거나 거리가 기준보다 멀면 "자료에 없다"고 답하고 `refused`를 참으로 돌려줍니다. 기준값은 테스트 질문셋으로 정합니다.
- **출처는 검색 결과에서만**: LLM이 만들어 낸 링크를 쓰지 않고, 검색된 청크의 `source_url`만 출처로 내보냅니다.
- **SQL은 repository에**: `retriever`는 `repositories/document_repository.py`의 함수를 호출합니다. 벡터 검색은 Chroma(`clients/chroma_client.py`)가 합니다.
- **임베딩은 clients로**: 질문 임베딩은 `clients/embedding_client.py`를 사용합니다. 문서와 같은 모델이어야 합니다.
- **대화 맥락**: 로그인 사용자는 `chat_sessions`·`chat_messages`에 저장하고, 비로그인은 직전 12개 메시지를 요청에 담아 보냅니다 (기획서 v2). 검색은 마지막 질문만으로 합니다.
- 프롬프트를 고칠 때는 버전과 바꾼 이유를 `docs/`에 남깁니다.
