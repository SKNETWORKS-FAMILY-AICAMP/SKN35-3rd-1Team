-- =====================================================================
-- 나중에 필요해지면 추가할 테이블 (MVP 에는 넣지 않음)
-- 01_schema_mvp.sql 을 먼저 실행한 뒤에 실행.
-- (채팅 기록 테이블은 2026-10-12에 01_schema_mvp.sql 로 옮김)
-- =====================================================================
USE 3rd_project;

-- ---------------------------------------------------------------------
-- 1. 작품 간 유사도 사전 계산 (추천이 느려졌을 때 쓰는 캐시)
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
