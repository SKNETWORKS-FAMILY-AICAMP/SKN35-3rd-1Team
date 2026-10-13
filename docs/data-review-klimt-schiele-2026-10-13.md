# 클림트·실레 AI 사전 검수 기록 (2026-10-13)

## 범위와 승인 상태

| 단계 | 문서 | 확인 내용 | 결과 |
| --- | ---: | --- | --- |
| 대표작 각 5점 + 생애 각 1건 | 12 | 소장 기관의 개별 해설과 인물·구도·매체·연대·해석 경계를 대조 | 2026-10-13 팀 최종 승인 |
| 나머지 작품 | 50 | 기관 수장품 설명 첫 부분과 작품별 해설의 핵심 진술, 연대·치수, 500자 기준 및 반복 문단 대조 | 2026-10-13 팀 최종 승인 |
| 작가별 기법·풍경·맥락 | 6 | 기관 출처와 전처리 길이 대조 | 2026-10-13 팀 최종 승인 |

대표작은 실레 `the-family-schiele`, `death-and-the-maiden-schiele`, `portrait-of-wally`, `self-portrait-with-chinese-lantern-plant`, `the-hermits-schiele`; 클림트 `portrait-of-fritza-riedler`, `judith-i`, `beethoven-frieze`, `the-kiss`, `death-and-life`이다. 각 문서의 출처 URL, 전처리 본문 SHA-256, 길이, 이미지 상태는 [`review_audit_klimt_schiele.json`](../data/mappings/review_audit_klimt_schiele.json)에 68행으로 기록했다. 사용자 ju가 68건 최종 승인을 확인했고 `reviews.json`에 승인자·날짜·본문 해시를 기록했다. 문서 승인과 개별 이미지의 표시 가능 여부는 별개다.

실레와 클림트 작품 원문 60점의 출처는 모두 벨베데레 또는 레오폴트 미술관이다. 이 가운데 이미지 권리를 확보하지 못한 3점은 수집·검수 이력만 보존하고 배포 카탈로그와 전용 문서에서 제외했다. 배포되는 57점의 설명은 모두 500자 이상이며, 각 작품에 별도의 `감상 포인트` 절이 있다.

## 이미지·이용 조건

현재 배포되는 57점은 `image_url`이 모두 있으며 실레 28건, 클림트 29건이다. 54건은 Public Domain, 3건은 CC BY 또는 CC BY-SA이며 사진 저작자와 라이선스를 `image_license`에 함께 기록했다. 앱 상세 화면은 `이미지 이용` 문구와 `원본 작품 정보와 이용 조건` 링크를 표시한다.

- 《작은 도시 III》에 연결돼 있던 [Commons 파일](https://commons.wikimedia.org/wiki/File:Egon_Schiele_015.jpg)은 실제로 《작은 도시 II》였으므로 `image_url`과 `image_source_url`을 비웠다.
- 《죽음과 소녀》, 《프리차 리들러의 초상》, 《요한나 슈타우데의 초상》, 《베토벤 프리즈》, 《물뱀 I》, 《가족》에는 Public Domain 파일을 확인해 연결했다. 《두 아이와 어머니 II》, 《크루마우》, 《도나우강의 슈타인 II》는 각각 사진 저작자와 CC 라이선스를 표시하고 Commons 파일 페이지를 이용 조건 링크로 제공한다.

정확한 작품과 재사용 가능한 재현물을 함께 확인하지 못한 《작은 도시 III》, 《책이 있는 정물: 화가의 책상》, 《붉은 스케치북》 3점은 `excluded_artworks`에 등록했다. 세 작품은 전처리된 `artworks.jsonl`과 `documents.jsonl`, 배포 DB에서 완전히 제외한다.

## 승인 전후 검색 제외 검증

`documents.needs_review=true`이면 범위 조회, 고정 청크, 검색 출처, 청크 생성, Chroma 동기화 후보에서 제외한다. 이전에 생성된 미승인 청크는 `load_documents`에서 삭제하고, 이전 Chroma 사본은 `sync_chroma`에서 제거한다. 승인 상태를 바꾸면 같은 범위 조회와 청크 생성 대상에 들어간다. 회귀 테스트 `backend/tests/test_review_gate.py`는 승인 전 → 승인 후 → 승인 취소의 세 상태를 SQLite 가상 DB로 확인한다. 실제 검색 서비스의 DB·Chroma에는 아직 반영하지 않았다.

검증 결과: 백엔드 테스트 221개 통과, Ruff `F` 검사 통과, `git diff --check` 통과. 전체 Ruff 규칙에는 이번 변경 이전 파일에도 있던 import 순서와 긴 줄 위반이 남아 있어 통과로 기록하지 않는다.

## 산출물과 다음 게이트

- 전처리 버전: `data/processed/_SUCCESS.json`의 파일별 SHA-256. 현재 6 사조, 10 작가, 276 작품, 426 문서, `needs_review=true` 0건이다.
- 검수 장부 버전: `2026-10-13-final-approved-5-catalog-exclusions`. 장부의 `documents.jsonl`·`artworks.jsonl` SHA-256이 `_SUCCESS.json`과 일치해야 한다. `reviews.json`의 68개 해시는 수집·검수 이력으로 보존하며, 제외 3건을 뺀 65건이 배포된다.
- 팀 승인·전처리는 완료했다. 작품·문서 DB 적재 → 청크·작품 임베딩 → Chroma 동기화는 접속 설정이 갖춰지면 실행한다.
- 마지막 검증은 승인된 문서만 검색되는지 실제 `/chat`과 Chroma에서 확인하고, `_SUCCESS.json`·`reviews.json`·DB 문서·청크 건수·Chroma ID 집합을 같은 시점에 대조한다. 현재 이 단계는 실행 전이다. 로컬에 TiDB, OpenAI, Chroma 접속 설정이 없어 실제 건수를 기록할 수 없다.

운영 동기화 완료 판정은 실제 DB와 Chroma에서만 내린다. 승인·전처리와 로컬 제외 테스트를 운영 데이터 동기화 완료로 표시하지 않는다.
