-- =====================================================================
-- (선택) 작품 벡터에 HNSW 벡터 인덱스 붙이기 - TiDB 전용 문법
-- MVP 에는 필요 없음. 작품 수가 수만 개 이상으로 늘어 D번 쿼리가 느려졌을 때 실행.
-- =====================================================================
USE 3rd_project;

-- 1) 벡터 인덱스는 TiFlash(컬럼 저장소) 복제본 위에 만들어짐.
--    이미 만들어진 테이블에 인덱스를 추가할 때는 복제본을 먼저 직접 만들어야 함.
--    (CREATE TABLE 안에 VECTOR INDEX 를 함께 적은 경우에는 TiDB 가 자동으로 만들어 줌)
ALTER TABLE artwork_embeddings SET TIFLASH REPLICA 1;

-- 2) 코사인 거리 기준 인덱스.
--    쿼리에서도 반드시 같은 함수(VEC_COSINE_DISTANCE)로 오름차순 정렬해야 인덱스가 쓰임.
CREATE VECTOR INDEX idx_artwork_embeddings_cos
  ON artwork_embeddings ((VEC_COSINE_DISTANCE(embedding))) USING HNSW;

-- 3) 빌드 진행 상황 확인. ROWS_STABLE_NOT_INDEXED 가 0 이 되면 완료.
SELECT * FROM INFORMATION_SCHEMA.TIFLASH_INDEXES;

-- 4) 방금 넣은 데이터는 Delta 계층에 머물러 인덱스에 안 잡힐 수 있음. 강제로 병합.
ALTER TABLE artwork_embeddings COMPACT;

-- 5) 인덱스가 실제로 쓰이는지 확인.
--    실행 계획의 TableFullScan 줄 operator info 에 'annIndex:' 가 보이면 사용 중.
--    안 보이면 바로 이어서 SHOW WARNINGS 를 실행하면 이유가 나옴.
EXPLAIN
SELECT e.artwork_id
FROM artwork_embeddings AS e
ORDER BY VEC_COSINE_DISTANCE(e.embedding, '[0.1, 0.2, 0.3]')   -- 실제로는 1536차원 벡터
LIMIT 4;

SHOW WARNINGS;
