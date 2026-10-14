# Docentalk · AI 미술관 도슨트

Flutter Web 프론트엔드, FastAPI 백엔드, TiDB 데이터베이스로 작품 감상과 AI 도슨트 대화를 제공하는 팀 프로젝트입니다.

프론트엔드의 서비스 이름은 **Docentalk**입니다. `frontend/`에서 `flutter pub get`, `flutter run -d chrome`으로 미리보기를 실행합니다. 작품 탐색, 도슨트, 감상 피드와 공개/비공개 다이어리, 서재 캘린더, 마이페이지·컬렉션을 제공합니다. 실제 API 연결과 배포 방법은 [프론트 README](frontend/README.md)를 참고하세요. 초기 React 목업은 참고용으로 보존했습니다.

각 폴더의 `README.md`에는 그 폴더의 역할, 넣을 파일 예시, 지켜야 할 규칙이 적혀 있습니다. 파일명은 전부 예시이므로 팀에서 바꿔도 됩니다.

## 폴더 구조

```text
museum-rag-react-fastapi-tidb/
├── backend/                 FastAPI 서버
│   ├── alembic/             DB 마이그레이션
│   ├── app/
│   │   ├── api/routes/      엔드포인트 (요청 검증, 응답 반환)
│   │   ├── services/        서비스 로직 (좋아요, 내 서재, 추천, 챗봇 흐름)
│   │   ├── repositories/    TiDB 조회·저장, 벡터 거리 SQL
│   │   ├── models/          SQLAlchemy 모델 (서비스 테이블 20개)
│   │   ├── schemas/         Pydantic 요청·응답 스키마
│   │   ├── rag/             청킹, 검색, 프롬프트, 답변 생성, 출처
│   │   ├── clients/         임베딩·LLM API 호출
│   │   ├── core/            설정, 인증, 예외, 공통 의존성
│   │   └── db/              엔진, 세션
│   ├── scripts/             데이터 적재, 임베딩 생성 (필요할 때만 실행)
│   └── tests/
├── frontend/                Flutter Web (lib/), 초기 React 목업(src/) 보존
│   └── src/
│       ├── pages/           URL 과 연결되는 화면
│       ├── components/      artwork, artist, chat, recommendation, library, common
│       ├── api/             FastAPI 호출 함수
│       ├── hooks/           조회·변경 로직
│       ├── stores/          로그인 상태 등 전역 상태
│       ├── routes/          라우터, 로그인 필요 화면 보호
│       └── types/           API 응답 타입
├── data/                    raw(원본), processed(정제), images
├── docs/                    아키텍처, API 명세, DB 설계(docs/db), 테스트, 발표
└── infra/                   로컬 실행, Docker, 배포 설정
```

## 요청이 지나가는 길

```text
Flutter 화면 → frontend/lib/api → FastAPI routes → services → repositories → TiDB
                                                     └→ rag → repositories → TiDB
                                                          └→ clients → 임베딩·LLM API
```

의존 방향은 왼쪽에서 오른쪽 한쪽으로만 흐릅니다. `repositories`가 `services`를 import하거나 `rag`가 `api`를 import하는 일은 없어야 합니다.

## 기능별로 손대는 곳

| 기능 | 백엔드 | 프론트엔드 |
| --- | --- | --- |
| 1. 작가별·사조별 작품 목록 | `routes/artworks.py`, `catalog_service`, `catalog_repository` | `pages/GalleryPage`, `components/artwork` |
| 2. 작품 상세·이미지 | `routes/artworks.py`, `catalog_service` | `pages/ArtworkDetailPage` |
| 3. 작품 도슨트 챗봇 | `routes/chat.py`, `chat_service`, `rag/` | `components/chat` |
| 4. 작품 좋아요 | `routes/likes.py`, `like_service`, `activity_repository` | `components/artwork/LikeButton` |
| 5. 비슷한 작품·맞춤 작품 추천 | `routes/recommendations.py`, `recommendation_service`, `recommendation_repository` | `components/recommendation` |
| 6. 작가 추천 | 5번과 같은 파일 | `components/recommendation` |
| 7. 작가 팔로우 | `routes/follows.py`, `follow_service`, `activity_repository` | `components/artist/FollowButton` |
| 8. 열람 기록 | `routes/library.py`, `library_service`, `activity_repository` | 작품 상세 진입 시 호출 |
| 9. 내 서재 캘린더 | `routes/library.py`, `library_service` | `pages/LibraryPage`, `components/library` |
| 10. 답변 근거·출처 표시 | `rag/citations.py`, `schemas/chat.py` | `components/chat/SourceList` |

## 팀이 먼저 고정할 약속 3가지

이 세 가지가 정해지면 데이터, 검색, 생성, 화면 담당이 서로 기다리지 않고 동시에 작업할 수 있습니다.

1. **문서 스키마**: 수집한 문서를 어떤 필드로 저장하는가 → `data/README.md`
2. **검색 결과 형식**: 검색기가 답변 생성 쪽에 무엇을 넘기는가 → `backend/app/rag/README.md`
3. **API 요청·응답 형식**: 프론트와 백이 무엇을 주고받는가 → `backend/app/api/routes/README.md` 초안, 확정본은 `docs/`

## 처음 실행하는 순서

1. 저장소 루트에서 `uv sync`로 파이썬 의존성을 설치합니다. `pyproject.toml`과 `uv.lock`은 루트에 있습니다.
2. 루트의 `.env.example`을 루트에 `.env`로 복사해 값을 채웁니다. Flutter 프론트는 `--dart-define` 또는 Git 제외 설정 파일로 빌드 값을 전달합니다 (`frontend/README.md` 참고).
3. 임베딩 모델을 정하고 `EMBEDDING_DIM`과 스키마의 `VECTOR(1536)`을 같은 값으로 맞춥니다.
4. TiDB에 Alembic 마이그레이션 전체 이력을 적용합니다 (`alembic upgrade head`). `docs/db/01_schema_mvp.sql`은 0006 시점의 참고 스냅샷이며 현재 head는 `20261014_0008`입니다.
5. `backend/scripts/`의 적재 스크립트를 정해진 순서로 실행합니다.
6. 백엔드 서버와 프론트 개발 서버를 띄웁니다.

## 공통 규칙

- 비밀번호, TiDB 접속 정보, API 키는 `.env`에만 두고 커밋하지 않습니다.
- SQL, 특히 벡터 거리 계산은 `repositories/`에만 둡니다.
- 임베딩 모델 이름과 차원 수는 `backend/app/clients/` 한 곳에서만 정의합니다.
- 라우터에는 로직을 쓰지 않고 서비스를 호출합니다.
- 폴더 역할이 바뀌면 그 폴더의 `README.md`도 함께 고칩니다.
