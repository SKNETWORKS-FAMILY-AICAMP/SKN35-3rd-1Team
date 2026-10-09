# rag

문서 검색과 답변 생성을 담당합니다. 좋아요 기반 추천은 RAG가 아니므로 여기 두지 않고 `services/`에 둡니다.

## 들어갈 파일

- `chunking.py`: 문서를 청크로 자르는 규칙 (길이, 겹침)
- `retriever.py`: 질문을 임베딩하고 선택한 작품 범위 안에서 가까운 청크를 찾음
- `prompts.py`: 시스템 프롬프트와 거절 규칙
- `chain.py`: 검색 결과와 질문, 이전 대화를 LLM에 넘겨 답변 생성
- `citations.py`: 답변에 쓰인 청크를 출처 목록으로 정리

## 검색 결과 형식 (팀 약속)

`retriever`는 아래 필드를 가진 항목의 리스트를 거리 오름차순으로 돌려줍니다. 답변 생성 담당은 이 형식만 맞으면 가짜 데이터로 먼저 개발할 수 있습니다.

| 필드 | 설명 |
| --- | --- |
| `chunk_id` | 청크 id |
| `content` | 청크 본문 |
| `document_id` | 문서 id |
| `document_title` | 문서 제목 |
| `doc_type` | `artist_bio`, `artwork_commentary`, `artist_comparison` |
| `source_name` | 출처 이름 |
| `source_url` | 출처 링크 |
| `distance` | 코사인 거리 (작을수록 가까움) |

LangChain을 쓴다면 `content`는 `page_content`, 나머지는 `metadata`로 옮기면 됩니다.

## 검색 범위

챗봇은 선택한 작품과 관련된 문서 안에서만 검색합니다.

- 그 작품의 해설 문서 (`documents.artwork_id`)
- 그 작품 작가의 생애 문서와 그 작가가 포함된 비교 문서 (`document_artists`)

범위가 좁아서 벡터 인덱스 없이 정확 검색으로 충분합니다.

## 규칙

- **문서 밖 답변 금지**: 검색 결과가 없거나 거리가 기준보다 멀면 "자료에 없다"고 답하고 `refused`를 참으로 돌려줍니다. 기준값은 테스트 질문셋으로 정합니다.
- **출처는 검색 결과에서만**: LLM이 만들어 낸 링크를 쓰지 않고, 검색된 청크의 `source_url`만 출처로 내보냅니다.
- **SQL은 repository에**: `retriever`는 `document_repository`의 함수를 호출합니다.
- **임베딩은 clients로**: 질문 임베딩은 `clients/embedding_client.py`를 사용합니다. 문서와 같은 모델이어야 합니다.
- **대화 맥락**: 이전 대화는 요청에 담겨 옵니다. 서버에 저장하지 않으므로 몇 턴까지 프롬프트에 넣을지만 정하면 됩니다.
- 프롬프트를 고칠 때는 버전과 바꾼 이유를 `docs/`에 남깁니다.
