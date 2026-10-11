# scripts

전처리, 데이터 적재와 임베딩 생성처럼 필요할 때만 실행하는 작업을 둡니다. 서버가 시작될 때 자동으로 돌지 않습니다.

## 현재 있는 스크립트

- `preprocess.py`: `data/raw/`와 `data/mappings/`를 읽어 `data/processed/`를 만듭니다.
- `translate.py`: 영어 원문을 한국어로 번역합니다. API 비용이 드므로 실행 전에 데이터 담당자에게 확인합니다.
- `check_db.py`: TiDB 연결과 현재 테이블을 확인합니다.

적재·청킹·임베딩 스크립트는 아직 작성하지 않았습니다. **DB 적재는 모든 수집·전처리가 완료된 다음에 진행합니다.**

## 추후 작성할 파일과 실행 순서

FK 때문에 부모 테이블부터 채워야 합니다. 아래 순서대로 실행합니다.

| 순서 | 파일 | 읽는 것 | 쓰는 테이블 |
| --- | --- | --- | --- |
| 1 | `load_catalog.py` | `data/processed/`의 사조·작가·작품 | `art_movements`, `artists`, `artworks` |
| 2 | `load_documents.py` | `data/processed/`의 문서 | `documents`, `document_artists`, `document_artworks` |
| 3 | `build_chunks.py` | `documents` | `document_chunks` (청킹 + 임베딩) |
| 4 | `build_artwork_embeddings.py` | `artworks` | `artwork_embeddings` |
| 5 | `seed_demo_users.py` | (없음) | `users`, `artwork_likes` 등 발표용 계정 |

원본을 정제하는 전처리 스크립트(`preprocess.py`)는 `data/raw/`와 `data/mappings/`를 읽어 `data/processed/`에 씁니다. 기준은 [`docs/data-collection.md`](../../docs/data-collection.md)에 있습니다. 전처리 결과가 최종 확정되기 전에는 위 적재 스크립트를 실행하지 않습니다.

## 실행 방법

`backend/`에서 모듈로 실행합니다. 그래야 `app`의 모델과 설정을 import할 수 있습니다.

```bash
uv run python -m scripts.preprocess
```

적재 스크립트를 작성한 뒤에는 `uv run python -m scripts.load_catalog`처럼 실행합니다.

## 규칙

- **여러 번 돌려도 안전하게**: 사조·작가·작품은 `slug`를 기준으로 있으면 갱신하고 없으면 추가합니다. 자동 증가 id는 실행할 때마다 달라질 수 있어 기준 키로 쓰지 않습니다.
- **문서 갱신**: 문서는 `doc_key`를 기준으로 갱신합니다. 본문이 바뀐 문서만 기존 청크를 지우고 다시 청킹·임베딩합니다.
- **작품 벡터의 원문**: 제목, 사조, 재료·기법, 주제 설명을 한 덩어리로 만들어 임베딩합니다. 작가 이름을 넣으면 같은 작가 작품끼리 더 가까워지므로 넣을지 팀에서 정합니다.
- **임베딩 모델 기록**: 벡터를 넣을 때 `embedding_model` 컬럼에 모델 이름을 함께 넣습니다.
- **API 비용**: 임베딩은 여러 건을 묶어 호출하고, 이미 같은 모델로 만든 벡터는 건너뜁니다.
- 실행 결과(몇 건 추가, 몇 건 갱신)를 출력합니다.
