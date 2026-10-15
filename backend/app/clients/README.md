# clients

외부 임베딩과 Chroma 접속을 공통으로 처리합니다.

- `embedding_client.py`: OpenAI 텍스트 임베딩 배치 호출·질문 임베딩·결과 차원 검사.
- `chroma_client.py`: Chroma 클라이언트와 검색 컬렉션 생성·조회, 임베딩 모델·거리 함수 검사.

Chroma 접속 우선순위는 Cloud 설정(`CHROMA_API_KEY`·`CHROMA_TENANT`·`CHROMA_DATABASE` 모두 지정) → 서버(`CHROMA_HOST`) → 로컬(`CHROMA_PATH`)입니다. 컬렉션 이름은 `CHROMA_CHUNKS_COLLECTION`·`CHROMA_ARTWORKS_COLLECTION`로 구분합니다.

임베딩 모델은 `core/config.py`의 `EMBEDDING_MODEL`(기본 `text-embedding-3-small`), 차원은 `models/base.py`의 `EMBEDDING_DIMENSION`(1536)을 기준으로 합니다. 질문과 문서는 같은 모델을 사용해야 합니다.

현재 별도 `llm_client.py`는 없습니다. 답변·범위 판정·컬렉션 AI는 `docent/service.py`, `docent/stream.py`, `docent/scope.py`, `services/collection_assistant.py`, `services/theme_collections.py`에서 `ChatOpenAI`를 사용합니다. 공통 모델 설정은 `ASSISTANT_MODEL`입니다.
