-- =====================================================================
-- 미술관 도슨트 RAG 서비스 - MVP 스키마 (TiDB / MySQL 호환)
-- 대상: TiDB Cloud Starter 또는 TiDB Self-Managed v8.5 이상
--
-- 실행 전 확인할 것
--   1) VECTOR(1536) 의 1536 은 임베딩 모델 차원 수임. 모델에 맞게 두 군데 모두 수정.
--        text-embedding-3-small = 1536 / bge-m3, multilingual-e5-large = 1024
--      벡터 컬럼은 나중에 다른 타입으로 MODIFY 할 수 없으므로 처음에 정하는 편이 안전함.
--   2) 모든 PK/FK 는 부호 있는 BIGINT 로 통일함.
--      TiDB 는 FK 양쪽 컬럼의 타입·크기가 정확히 같아야 FK 를 만들어 줌.
--   3) 콜레이션을 utf8mb4_general_ci 로 명시함.
--      TiDB 기본값은 utf8mb4_bin(대소문자 구분)이라, 명시하지 않으면
--      'Monet' 과 'monet' 이 다른 값으로 취급되어 검색·이메일 중복 검사 결과가 MySQL 과 달라짐.
--   4) 생성 순서 = 부모 테이블 먼저. 아래 순서 그대로 실행하면 됨.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS 3rd_project
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_general_ci;
USE 3rd_project;

-- ---------------------------------------------------------------------
-- 1. users : 서비스 회원
--    로그인은 Firebase Auth 가 프론트에서 처리하므로 비밀번호를 저장하지 않음.
--    서버는 Authorization 헤더의 Firebase ID 토큰을 검증해 uid 를 얻고,
--    처음 보는 uid 면 이 테이블에 한 번만 행을 만듦. 다른 테이블은 모두 users.id 로 연결.
--    클라이언트가 보낸 uid 값을 그대로 믿으면 안 됨 (남의 기록을 조작할 수 있음).
-- ---------------------------------------------------------------------
CREATE TABLE users (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  -- Firebase Auth 사용자 id (검증된 ID 토큰에서만 가져옴)
  firebase_uid  VARCHAR(128) NOT NULL,
  -- 이메일은 앱에서 소문자로 정규화해서 저장하는 것을 권장 (콜레이션에 기대지 않기 위함)
  email         VARCHAR(255) NOT NULL,
  nickname      VARCHAR(50)  NOT NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_firebase_uid (firebase_uid),
  -- 같은 이메일로 두 번 가입하는 것을 DB 차원에서 차단
  UNIQUE KEY uq_users_email (email)
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 2. art_movements : 사조 (인상주의, 입체주의 ...)
--    문자열 컬럼 대신 테이블로 둔 이유: '인상주의'/'인상파' 같은 표기 흔들림을 막고
--    사조 목록 화면에 설명을 붙이기 위함. 행 수는 수십 개 수준.
-- ---------------------------------------------------------------------
CREATE TABLE art_movements (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  -- URL 과 데이터 적재 스크립트에서 쓰는 고정 식별자 (예: impressionism)
  slug        VARCHAR(100) NOT NULL,
  name        VARCHAR(100) NOT NULL,
  name_en     VARCHAR(100) NULL,
  description TEXT         NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_art_movements_slug (slug)
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 3. artists : 작가
-- ---------------------------------------------------------------------
CREATE TABLE artists (
  id           BIGINT        NOT NULL AUTO_INCREMENT,
  -- slug 가 있으면 적재 스크립트를 다시 돌려도 같은 작가를 찾아 갱신(upsert)할 수 있음.
  -- AUTO_INCREMENT id 는 TiDB 에서 연속 값이 아니므로 적재 기준 키로 쓰기 어려움.
  slug         VARCHAR(120)  NOT NULL,
  name         VARCHAR(200)  NOT NULL,
  name_en      VARCHAR(200)  NULL,
  -- 대표 사조 1개만 둠. 작가-사조 N:M 테이블은 이 규모에서 과함.
  movement_id  BIGINT        NULL,
  birth_year   SMALLINT      NULL,
  death_year   SMALLINT      NULL,
  nationality  VARCHAR(100)  NULL,
  -- 목록 카드에 쓰는 짧은 소개. 긴 생애 원문은 documents 에 저장.
  summary      TEXT          NULL,
  portrait_url VARCHAR(1024) NULL,
  created_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_artists_slug (slug),
  KEY idx_artists_movement (movement_id),
  KEY idx_artists_name (name),
  -- 사조가 삭제돼도 작가는 남아야 하므로 SET NULL
  CONSTRAINT fk_artists_movement FOREIGN KEY (movement_id)
    REFERENCES art_movements (id) ON DELETE SET NULL
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 4. artworks : 작품 (목록·상세 화면의 중심 테이블)
--    벡터를 여기에 두지 않은 이유는 5번 artwork_embeddings 주석 참고.
-- ---------------------------------------------------------------------
CREATE TABLE artworks (
  id               BIGINT        NOT NULL AUTO_INCREMENT,
  slug             VARCHAR(160)  NOT NULL,
  artist_id        BIGINT        NOT NULL,
  -- 작품 단위 사조. 한 작가가 시기별로 사조가 달라질 수 있어 작품에 직접 둠.
  movement_id      BIGINT        NULL,
  title            VARCHAR(255)  NOT NULL,
  title_en         VARCHAR(255)  NULL,
  -- 'c. 1889', '1503-1519' 처럼 원문 표기는 문자열로, 정렬용 숫자는 따로 보관
  year_label       VARCHAR(50)   NULL,
  year_start       SMALLINT      NULL,
  medium           VARCHAR(255)  NULL,
  dimensions       VARCHAR(100)  NULL,
  collection       VARCHAR(255)  NULL,
  description      TEXT          NULL,
  image_url        VARCHAR(1024) NULL,
  -- 이미지 원본 페이지와 라이선스. 발표 화면에 출처를 함께 표기하기 위함.
  image_source_url VARCHAR(1024) NULL,
  image_license    VARCHAR(100)  NULL,
  -- 좋아요가 없는 신규 사용자에게 보여줄 큐레이션 작품 표시 (콜드 스타트 대응)
  is_featured      TINYINT(1)    NOT NULL DEFAULT 0,
  created_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_artworks_slug (slug),
  -- 작가별 목록: WHERE artist_id = ? ORDER BY year_start
  KEY idx_artworks_artist_year (artist_id, year_start),
  -- 사조별 목록: WHERE movement_id = ? ORDER BY year_start
  KEY idx_artworks_movement_year (movement_id, year_start),
  -- 작품이 남아 있는 작가는 지우지 못하게 막음 (실수로 카탈로그가 통째로 사라지는 것 방지)
  CONSTRAINT fk_artworks_artist FOREIGN KEY (artist_id)
    REFERENCES artists (id) ON DELETE RESTRICT,
  CONSTRAINT fk_artworks_movement FOREIGN KEY (movement_id)
    REFERENCES art_movements (id) ON DELETE SET NULL
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 5. artwork_embeddings : 작품 대표 벡터 (추천 전용, 작품당 1행)
--    artworks 와 1:1 인데도 분리한 이유
--      a) 목록 조회 때 벡터(1536차원이면 약 6KB)가 딸려 나오지 않게 하기 위함.
--         TiDB 문서도 벡터 컬럼을 SELECT 결과에서 빼라고 권장함.
--      b) 임베딩 모델을 바꿀 때 artworks 는 건드리지 않고 이 테이블만 다시 채우면 됨.
--      c) 나중에 벡터 인덱스를 붙이면 TiFlash 복제본이 이 작은 테이블에만 생김.
-- ---------------------------------------------------------------------
CREATE TABLE artwork_embeddings (
  artwork_id      BIGINT       NOT NULL,
  -- 고정 차원으로 선언해야 나중에 벡터 인덱스를 만들 수 있음
  embedding       VECTOR(1536) NOT NULL,
  -- 어떤 모델로 만든 벡터인지 기록. 모델이 섞이면 거리 값이 의미가 없어짐.
  embedding_model VARCHAR(64)  NOT NULL,
  updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (artwork_id),
  CONSTRAINT fk_artwork_embeddings_artwork FOREIGN KEY (artwork_id)
    REFERENCES artworks (id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 6. documents : RAG 원문 문서 (작가 생애 / 작품 해설 / 작가 비교)
--    세 종류를 한 테이블에 두고 doc_type 으로 구분함.
--    컬럼 구성이 거의 같고, 청킹·임베딩·출처 표시 로직이 완전히 같기 때문.
-- ---------------------------------------------------------------------
CREATE TABLE documents (
  id          BIGINT        NOT NULL AUTO_INCREMENT,
  -- data/processed 의 문서 키 ('<작가 slug>/<원본 파일>'). 재적재 때 지우고 다시 넣는 대신 이 키로 갱신
  doc_key     VARCHAR(191)  NOT NULL,
  -- 'artist_bio' | 'artwork_commentary' | 'artist_comparison'
  -- ENUM 대신 VARCHAR 로 둔 이유: 종류가 늘 때 ALTER 없이 앱의 Enum 만 고치면 됨.
  doc_type    VARCHAR(30)   NOT NULL,
  -- 작품 해설일 때만 값이 들어감. 생애·비교 문서는 NULL.
  -- 작가와의 관계는 document_artists 에서 관리 (비교 문서는 작가가 2명 이상이라 컬럼 1개로 표현 불가)
  artwork_id  BIGINT        NULL,
  title       VARCHAR(255)  NOT NULL,
  -- 원문 전체. 한글은 글자당 3바이트라 TEXT(64KB)로는 긴 생애 문서가 잘릴 수 있어 MEDIUMTEXT.
  content     MEDIUMTEXT    NOT NULL,
  -- 답변 아래에 표시할 출처 정보
  source_url  VARCHAR(1024) NULL,
  source_name VARCHAR(255)  NULL,
  license     VARCHAR(100)  NULL,
  -- 검색 메타데이터: 언어('ko'|'en'), 생애 문서의 성격(생애 전체, 주변 인물, 연표 ...)
  lang        VARCHAR(8)    NOT NULL DEFAULT 'ko',
  topic       VARCHAR(30)   NULL,
  -- 사람 검토 전 문서. 검색에서 뺄지, 답변에 표시할지는 질의 시점에 정함
  needs_review TINYINT(1)   NOT NULL DEFAULT 0,
  created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_documents_doc_key (doc_key),
  -- 작품 상세 화면에서 '이 작품의 해설 문서' 를 찾는 인덱스 (FK 검사에도 사용됨)
  KEY idx_documents_artwork (artwork_id),
  -- 작품이 삭제되면 그 작품 해설 문서도 의미가 없으므로 함께 삭제
  CONSTRAINT fk_documents_artwork FOREIGN KEY (artwork_id)
    REFERENCES artworks (id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 7. document_artists : 문서-작가 연결 (N:M)
--    생애 문서 = 1행, 비교 문서 = 비교 대상 작가 수만큼(2행 이상).
--    작품 해설 문서는 documents.artwork_id 로 충분하므로 여기에 넣지 않음.
-- ---------------------------------------------------------------------
CREATE TABLE document_artists (
  document_id BIGINT NOT NULL,
  artist_id   BIGINT NOT NULL,
  PRIMARY KEY (document_id, artist_id),
  -- '이 작가와 관련된 문서 전부' 를 찾는 방향. RAG 검색 범위를 정할 때 사용.
  KEY idx_document_artists_artist (artist_id, document_id),
  CONSTRAINT fk_document_artists_document FOREIGN KEY (document_id)
    REFERENCES documents (id) ON DELETE CASCADE,
  CONSTRAINT fk_document_artists_artist FOREIGN KEY (artist_id)
    REFERENCES artists (id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 7-1. document_artworks : 문서가 언급하는 작품 (N:M)
--    연표 사건처럼 해설이 아닌 문서가 여러 작품과 이어질 때 사용 (processed 의 related_artwork_slugs).
--    작품 해설 문서의 '해설 대상 작품' 은 그대로 documents.artwork_id 하나로 둔다.
--    '이 작품을 그릴 때 작가는 어땠나' 처럼 작품에서 생애 이야기를 찾을 때 artwork_id 쪽 인덱스를 씀.
--    Alembic 마이그레이션 20261011_0002 에서 추가.
-- ---------------------------------------------------------------------
CREATE TABLE document_artworks (
  document_id BIGINT NOT NULL,
  artwork_id  BIGINT NOT NULL,
  PRIMARY KEY (document_id, artwork_id),
  KEY idx_document_artworks_artwork (artwork_id, document_id),
  CONSTRAINT fk_document_artworks_document FOREIGN KEY (document_id)
    REFERENCES documents (id) ON DELETE CASCADE,
  CONSTRAINT fk_document_artworks_artwork FOREIGN KEY (artwork_id)
    REFERENCES artworks (id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 8. document_chunks : 문서를 자른 조각 + 조각 벡터 (RAG 검색 전용)
--    청크 본문과 벡터를 같은 행에 둔 이유: 항상 1:1 이고 함께 만들어지고 함께 지워짐.
--    벡터 인덱스를 일부러 만들지 않음:
--      챗봇은 '선택한 작품' 범위 안에서만 검색하므로 WHERE document_id IN (...) 가 항상 붙음.
--      TiDB 는 WHERE 사전 필터가 있으면 벡터 인덱스를 쓰지 않으므로 만들어도 사용되지 않음.
--      범위 안 청크는 많아야 수백 개라 인덱스 없이 정확 검색으로 충분함.
-- ---------------------------------------------------------------------
CREATE TABLE document_chunks (
  id              BIGINT       NOT NULL AUTO_INCREMENT,
  document_id     BIGINT       NOT NULL,
  -- 문서 안에서의 순서(0부터). 앞뒤 청크를 이어 붙여 문맥을 넓힐 때 사용.
  chunk_index     INT          NOT NULL,
  content         TEXT         NOT NULL,
  embedding       VECTOR(1536) NOT NULL,
  embedding_model VARCHAR(64)  NOT NULL,
  created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  -- 같은 문서를 다시 청킹해도 같은 순번이 중복으로 들어가지 않게 함.
  -- 동시에 WHERE document_id IN (...) 범위 검색용 인덱스 역할도 함.
  UNIQUE KEY uq_document_chunks_doc_idx (document_id, chunk_index),
  -- 문서를 지우면 청크도 함께 삭제 → 재적재는 '문서 삭제 후 다시 삽입' 으로 끝남
  CONSTRAINT fk_document_chunks_document FOREIGN KEY (document_id)
    REFERENCES documents (id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 9. artwork_likes : 사용자-작품 좋아요 (N:M)
--    중복 좋아요 방지 = 복합 PK (user_id, artwork_id).
--    별도 id 컬럼 + UNIQUE 조합보다 단순하고, 같은 사용자의 좋아요가 물리적으로 모여 저장됨.
--    좋아요 취소는 행 삭제. is_deleted 같은 소프트 삭제 플래그는 두지 않음.
-- ---------------------------------------------------------------------
CREATE TABLE artwork_likes (
  user_id    BIGINT   NOT NULL,
  artwork_id BIGINT   NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, artwork_id),
  -- 추천 시드: '이 사용자의 최근 좋아요 N개'
  KEY idx_artwork_likes_user_created (user_id, created_at),
  -- 작품별 좋아요 수 집계(인기 작품) + FK 검사용
  KEY idx_artwork_likes_artwork (artwork_id),
  CONSTRAINT fk_artwork_likes_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_artwork_likes_artwork FOREIGN KEY (artwork_id)
    REFERENCES artworks (id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 10. artist_follows : 사용자-작가 팔로우 (N:M). 구조는 좋아요와 동일.
-- ---------------------------------------------------------------------
CREATE TABLE artist_follows (
  user_id    BIGINT   NOT NULL,
  artist_id  BIGINT   NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, artist_id),
  KEY idx_artist_follows_artist (artist_id),
  CONSTRAINT fk_artist_follows_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_artist_follows_artist FOREIGN KEY (artist_id)
    REFERENCES artists (id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 11. artwork_views : 열람 기록 (사용자 x 작품 x 날짜 당 1행)
--    조회할 때마다 행을 쌓는 로그 방식 대신 '하루 1행 + 횟수 증가' 로 설계함.
--      - 새로고침을 여러 번 해도 행이 늘지 않음
--      - 캘린더 쿼리에 DISTINCT 가 필요 없음
--      - PK 가 (user_id, viewed_on, ...) 순서라 월별 조회가 PK 범위 스캔 한 번으로 끝남
--    viewed_on 은 DB 의 CURDATE() 가 아니라 앱에서 한국 시간(Asia/Seoul) 기준 날짜를 계산해 넣을 것.
--    DB 세션이 UTC 이면 자정~오전 9시 열람이 전날로 기록되기 때문.
-- ---------------------------------------------------------------------
CREATE TABLE artwork_views (
  user_id         BIGINT   NOT NULL,
  artwork_id      BIGINT   NOT NULL,
  viewed_on       DATE     NOT NULL,
  view_count      INT      NOT NULL DEFAULT 1,
  first_viewed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_viewed_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, viewed_on, artwork_id),
  KEY idx_artwork_views_artwork (artwork_id),
  CONSTRAINT fk_artwork_views_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_artwork_views_artwork FOREIGN KEY (artwork_id)
    REFERENCES artworks (id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 12. chat_sessions : 도슨트 대화 (로그인 사용자 x 작품 당 1개)
--    작품을 다시 열면 같은 대화를 이어 가므로 (user_id, artwork_id) 에 UNIQUE.
--    updated_at 은 마지막 메시지 시각. 메시지를 추가할 때 앱에서 함께 갱신함.
--    비로그인 사용자의 대화는 저장하지 않음 (요청의 history 로만 맥락 유지).
-- ---------------------------------------------------------------------
CREATE TABLE chat_sessions (
  id         BIGINT   NOT NULL AUTO_INCREMENT,
  user_id    BIGINT   NOT NULL,
  artwork_id BIGINT   NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_chat_sessions_user_artwork (user_id, artwork_id),
  -- '내 대화 목록' 최신순 조회용
  KEY idx_chat_sessions_user_updated (user_id, updated_at),
  KEY idx_chat_sessions_artwork (artwork_id),
  CONSTRAINT fk_chat_sessions_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_chat_sessions_artwork FOREIGN KEY (artwork_id)
    REFERENCES artworks (id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 13. chat_messages : 대화의 질문과 답변
--    sources 는 API 응답의 출처 목록을 그대로 저장한 JSON (질문이면 NULL).
--    document_chunks 에 FK 로 묶지 않음: 다시 청킹하면 청크 id 가 바뀌어 지난 대화의 출처가 깨지기 때문.
-- ---------------------------------------------------------------------
CREATE TABLE chat_messages (
  id         BIGINT      NOT NULL AUTO_INCREMENT,
  session_id BIGINT      NOT NULL,
  -- 'user' | 'assistant'
  role       VARCHAR(20) NOT NULL,
  content    TEXT        NOT NULL,
  -- 범위 밖이라 거절한 답변이면 1
  refused    TINYINT(1)  NOT NULL DEFAULT 0,
  sources    JSON        NULL,
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_chat_messages_session (session_id, id),
  CONSTRAINT fk_chat_messages_session FOREIGN KEY (session_id)
    REFERENCES chat_sessions (id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;
