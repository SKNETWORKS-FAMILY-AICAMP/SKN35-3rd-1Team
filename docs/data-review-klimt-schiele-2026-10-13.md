# 클림트·실레 AI 사전 검수 기록 (2026-10-13)

## 범위와 승인 상태

| 단계 | 문서 | 확인 내용 | 결과 |
| --- | ---: | --- | --- |
| 대표작 각 5점 + 생애 각 1건 | 12 | 소장 기관의 개별 해설과 인물·구도·매체·연대·해석 경계를 대조 | 2026-10-13 팀 최종 승인 |
| 나머지 작품 | 50 | 기관 수장품 설명 첫 부분과 작품별 해설의 핵심 진술, 연대·치수, 500자 기준 및 반복 문단 대조 | 2026-10-13 팀 최종 승인 |
| 작가별 기법·풍경·맥락 | 6 | 기관 출처와 전처리 길이 대조 | 2026-10-13 팀 최종 승인 |

대표작은 실레 `the-family-schiele`, `death-and-the-maiden-schiele`, `portrait-of-wally`, `self-portrait-with-chinese-lantern-plant`, `the-hermits-schiele`; 클림트 `portrait-of-fritza-riedler`, `judith-i`, `beethoven-frieze`, `the-kiss`, `death-and-life`이다. 각 문서의 출처 URL, 전처리 본문 SHA-256, 길이, 이미지 상태는 [`review_audit_klimt_schiele.json`](../data/mappings/review_audit_klimt_schiele.json)에 68행으로 기록했다. 사용자 ju가 68건 최종 승인을 확인했고 `reviews.json`에 승인자·날짜·본문 해시를 기록했다. 문서 승인과 개별 이미지의 표시 가능 여부는 별개다.

실레와 클림트 작품 60점의 출처는 모두 벨베데레 또는 레오폴트 미술관이다. 58점은 수집 시 저장한 기관 페이지 내용과 URL을 다시 대조했고, 나머지 벨베데레 2점(`가족`, `죽음과 소녀`)은 기관의 현재 페이지에서 확인했다. 모든 작품 설명은 전처리 결과에서 500자 이상이며, 각 작품에 별도의 `감상 포인트` 절이 있다. 대표작 해설에서 근거가 확인되지 않은 《가족》의 “미완성” 단정을 지우고 전처리 본문을 다시 만들었다.

## 이미지·이용 조건

현재 60점 중 `image_url` 43건(실레 21건, 클림트 22건), `NULL` 17건이다. 표시 후보 43건은 개별 Wikimedia Commons 파일 페이지의 작품 동일성과 Public Domain 표기를 확인했다. 두 작가 카드에도 공개 도메인 초상 URL을 추가했다. 이 표기는 관할권별 재이용 검토를 대체하지 않는다. 기관 사이트의 텍스트와 이미지도 각각 [벨베데레 법적 고지](https://www.belvedere.at/en/legal-notice), [레오폴트 법적 고지](https://onlinecollection.leopoldmuseum.org/en/legal-notice/)를 따른다.

- 《작은 도시 III》에 연결돼 있던 [Commons 파일](https://commons.wikimedia.org/wiki/File:Egon_Schiele_015.jpg)은 실제로 《작은 도시 II》였으므로 `image_url`과 `image_source_url`을 비웠다.
- 《죽음과 소녀》, 《프리차 리들러의 초상》, 《요한나 슈타우데의 초상》, 《베토벤 프리즈》, 《물뱀 I》에는 별도의 Public Domain 대체 파일을 확인해 교체했다. 《가족》과 《두 아이와 어머니 II》는 확인된 파일이 각각 [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/)이고 현재 UI에 저작자·라이선스 링크·변경 여부 표시가 없으므로 `image_url`을 계속 비워 둔다.

정확한 작품과 Public Domain 재현물을 함께 확인하지 못한 17점은 전처리된 `artworks.jsonl`에서도 `image_url: null`이다. 기관 수장품 사진을 `source_url`에서 직접 가져와 표시하는 방식은 사용하지 않는다.

## 승인 전후 검색 제외 검증

`documents.needs_review=true`이면 범위 조회, 고정 청크, 검색 출처, 청크 생성, Chroma 동기화 후보에서 제외한다. 이전에 생성된 미승인 청크는 `load_documents`에서 삭제하고, 이전 Chroma 사본은 `sync_chroma`에서 제거한다. 승인 상태를 바꾸면 같은 범위 조회와 청크 생성 대상에 들어간다. 회귀 테스트 `backend/tests/test_review_gate.py`는 승인 전 → 승인 후 → 승인 취소의 세 상태를 SQLite 가상 DB로 확인한다. 실제 검색 서비스의 DB·Chroma에는 아직 반영하지 않았다.

검증 결과: 백엔드 테스트 221개 통과, Ruff `F` 검사 통과, `git diff --check` 통과. 전체 Ruff 규칙에는 이번 변경 이전 파일에도 있던 import 순서와 긴 줄 위반이 남아 있어 통과로 기록하지 않는다.

## 산출물과 다음 게이트

- 전처리 버전: `data/processed/_SUCCESS.json`의 파일별 SHA-256. 현재 6 사조, 10 작가, 279 작품, 429 문서, `needs_review=true` 0건이다.
- 검수 장부 버전: `2026-10-13-final-approved-1`. 장부의 `documents.jsonl`·`artworks.jsonl` SHA-256이 `_SUCCESS.json`과 일치해야 한다. `reviews.json`의 68개 해시도 각 전처리 본문과 일치해야 한다.
- 팀 승인·전처리는 완료했다. 작품·문서 DB 적재 → 청크·작품 임베딩 → Chroma 동기화는 접속 설정이 갖춰지면 실행한다.
- 마지막 검증은 승인된 문서만 검색되는지 실제 `/chat`과 Chroma에서 확인하고, `_SUCCESS.json`·`reviews.json`·DB 문서·청크 건수·Chroma ID 집합을 같은 시점에 대조한다. 현재 이 단계는 실행 전이다. 로컬에 TiDB, OpenAI, Chroma 접속 설정이 없어 실제 건수를 기록할 수 없다.

운영 동기화 완료 판정은 실제 DB와 Chroma에서만 내린다. 승인·전처리와 로컬 제외 테스트를 운영 데이터 동기화 완료로 표시하지 않는다.
