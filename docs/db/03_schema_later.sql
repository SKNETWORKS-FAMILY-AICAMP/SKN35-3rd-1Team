-- =====================================================================
-- 나중에 필요해지면 추가할 테이블 (MVP 에는 넣지 않음)
-- 01_schema_mvp.sql 을 먼저 실행한 뒤에 실행.
-- =====================================================================
USE 3rd_project;

-- ---------------------------------------------------------------------
-- 1. 채팅 기록 저장 (대화 이력을 서버에 남기고 싶을 때)
--    MVP 에서는 대화 이력을 React 상태로 들고 있다가 요청마다 최근 몇 턴을 함께 보내면 됨.
--    출처 표시는 답변 생성 시점에 검색된 청크를 API 응답에 실어 보내면 되므로 저장이 필수는 아님.
-- ---------------------------------------------------------------------
CREATE TABLE chat_sessions (
  id         BIGINT   NOT NULL AUTO_INCREMENT,
  user_id    BIGINT   NOT NULL,
  artwork_id BIGINT   NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  -- '이 사용자가 이 작품에서 나눈 대화' 조회용
  KEY idx_chat_sessions_user_artwork (user_id, artwork_id, created_at),
  KEY idx_chat_sessions_artwork (artwork_id),
  CONSTRAINT fk_chat_sessions_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_chat_sessions_artwork FOREIGN KEY (artwork_id)
    REFERENCES artworks (id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

CREATE TABLE chat_messages (
  id         BIGINT      NOT NULL AUTO_INCREMENT,
  session_id BIGINT      NOT NULL,
  -- 'user' | 'assistant'
  role       VARCHAR(20) NOT NULL,
  content    MEDIUMTEXT  NOT NULL,
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_chat_messages_session (session_id, id),
  CONSTRAINT fk_chat_messages_session FOREIGN KEY (session_id)
    REFERENCES chat_sessions (id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- 답변 1개가 근거로 삼은 청크들. 과거 대화를 다시 열었을 때 출처를 그대로 복원하기 위함.
CREATE TABLE chat_message_citations (
  message_id BIGINT NOT NULL,
  chunk_id   BIGINT NOT NULL,
  -- 검색 순위(1이 가장 가까움)와 그때의 거리 값
  rank_no    INT    NOT NULL,
  distance   DOUBLE NULL,
  PRIMARY KEY (message_id, chunk_id),
  KEY idx_chat_message_citations_chunk (chunk_id),
  CONSTRAINT fk_chat_message_citations_message FOREIGN KEY (message_id)
    REFERENCES chat_messages (id) ON DELETE CASCADE,
  CONSTRAINT fk_chat_message_citations_chunk FOREIGN KEY (chunk_id)
    REFERENCES document_chunks (id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 2. 작품 간 유사도 사전 계산 (추천이 느려졌을 때 쓰는 캐시)
--    작품 카탈로그는 데이터 적재 때만 바뀌므로, 적재 스크립트에서 작품마다
--    가까운 이웃 20개를 미리 계산해 넣어 두면 런타임에는 벡터 연산 없이 JOIN 만으로 추천 가능.
--    사용자별 추천 결과 테이블(user_recommendations)은 권장하지 않음:
--    좋아요를 누를 때마다 무효화해야 해서 관리 비용이 이득보다 큼.
-- ---------------------------------------------------------------------
CREATE TABLE artwork_similarities (
  artwork_id         BIGINT NOT NULL,
  -- 1이 가장 비슷한 작품
  rank_no            INT    NOT NULL,
  similar_artwork_id BIGINT NOT NULL,
  distance           DOUBLE NOT NULL,
  PRIMARY KEY (artwork_id, rank_no),
  KEY idx_artwork_similarities_similar (similar_artwork_id),
  CONSTRAINT fk_artwork_similarities_artwork FOREIGN KEY (artwork_id)
    REFERENCES artworks (id) ON DELETE CASCADE,
  CONSTRAINT fk_artwork_similarities_similar FOREIGN KEY (similar_artwork_id)
    REFERENCES artworks (id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;
