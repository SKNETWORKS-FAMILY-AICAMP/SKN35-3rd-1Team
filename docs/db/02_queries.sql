-- =====================================================================
-- 미술관 도슨트 RAG 서비스 - 기능별 쿼리 예시 (TiDB)
--
-- @변수 는 mysql 클라이언트에서 바로 실행해 보기 위한 자리표시자임.
-- FastAPI 에서는 SQLAlchemy 바인드 파라미터로 바꿔 쓰면 됨.
-- 벡터 값은 '[0.12, -0.03, ...]' 형태의 문자열로 넘김 (tidb-vector 가 자동 변환).
-- VEC_COSINE_DISTANCE 는 '거리'(작을수록 비슷함)이므로 항상 오름차순 정렬.
-- =====================================================================
USE 3rd_project;

SET @user_id            = 1;
SET @artwork_id         = 1;          -- 지금 보고 있는 작품
SET @today_kst          = '2026-10-09';   -- 앱에서 Asia/Seoul 기준으로 계산한 날짜
SET @month_start        = '2026-10-01';
SET @next_month_start   = '2026-11-01';

-- ---------------------------------------------------------------------
-- A. 좋아요 / 팔로우 (기능 4, 7, 8번 제약)
-- ---------------------------------------------------------------------
-- 좋아요 누르기: PK 가 (user_id, artwork_id) 라서 두 번 눌러도 1행만 남음.
-- INSERT IGNORE 를 쓰면 중복일 때 에러 대신 조용히 무시 → API 를 멱등하게 만들 수 있음.
INSERT IGNORE INTO artwork_likes (user_id, artwork_id) VALUES (@user_id, @artwork_id);

-- 좋아요 취소: 행 삭제
DELETE FROM artwork_likes WHERE user_id = @user_id AND artwork_id = @artwork_id;

-- 내가 좋아요한 작품 (최신순). idx_artwork_likes_user_created 사용.
SELECT a.id, a.title, a.image_url, ar.name AS artist_name, l.created_at AS liked_at
FROM artwork_likes AS l
JOIN artworks AS a  ON a.id  = l.artwork_id
JOIN artists  AS ar ON ar.id = a.artist_id
WHERE l.user_id = @user_id
ORDER BY l.created_at DESC
LIMIT 20;

-- 작가 팔로우 (좋아요와 같은 패턴)
INSERT IGNORE INTO artist_follows (user_id, artist_id)
SELECT @user_id, a.artist_id FROM artworks AS a WHERE a.id = @artwork_id;

-- ---------------------------------------------------------------------
-- B. 열람 기록 + 내 서재 캘린더 (기능 8, 9)
-- ---------------------------------------------------------------------
-- 작품 상세를 열 때마다 실행. 같은 날 같은 작품이면 횟수만 증가.
INSERT INTO artwork_views (user_id, artwork_id, viewed_on, view_count, first_viewed_at, last_viewed_at)
VALUES (@user_id, @artwork_id, @today_kst, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP())
ON DUPLICATE KEY UPDATE
  view_count     = view_count + 1,
  last_viewed_at = UTC_TIMESTAMP();

-- 캘린더 월 화면: 날짜별로 '몇 작품을 봤는지' 만 가져옴.
-- PK 가 (user_id, viewed_on, artwork_id) 라서 PK 범위 스캔으로 처리됨.
SELECT v.viewed_on,
       COUNT(*)          AS artwork_count,
       SUM(v.view_count) AS total_views
FROM artwork_views AS v
WHERE v.user_id   = @user_id
  AND v.viewed_on >= @month_start
  AND v.viewed_on <  @next_month_start
GROUP BY v.viewed_on
ORDER BY v.viewed_on;

-- 캘린더에서 하루를 눌렀을 때: 그날 본 작품 목록
SELECT a.id, a.title, a.image_url, v.view_count, v.last_viewed_at
FROM artwork_views AS v
JOIN artworks AS a ON a.id = v.artwork_id
WHERE v.user_id = @user_id AND v.viewed_on = @today_kst
ORDER BY v.last_viewed_at DESC;

-- ---------------------------------------------------------------------
-- C. RAG 검색 + 출처 (기능 3, 10)
--    1) 선택한 작품과 관련된 문서만 범위로 잡고
--    2) 그 안에서 질문 벡터와 가까운 청크 5개를 뽑음.
--    범위가 좁아서 인덱스 없이 정확 검색으로 충분함.
-- ---------------------------------------------------------------------
-- 앱에서는 질문을 임베딩한 결과를 넘김. 여기서는 실행 테스트용으로 기존 청크 벡터를 빌려 씀.
SET @question_vec = (SELECT VEC_AS_TEXT(embedding) FROM document_chunks ORDER BY id LIMIT 1);

SELECT c.id          AS chunk_id,
       c.chunk_index,
       c.content,
       d.id          AS document_id,
       d.doc_type,
       d.title       AS document_title,
       d.source_name,
       d.source_url,                       -- 답변 아래 출처 링크로 사용
       VEC_COSINE_DISTANCE(c.embedding, @question_vec) AS distance
FROM document_chunks AS c
JOIN documents AS d ON d.id = c.document_id
WHERE c.document_id IN (
        -- (1) 이 작품의 해설 문서
        SELECT d1.id
        FROM documents AS d1
        WHERE d1.artwork_id = @artwork_id
        UNION
        -- (2) 이 작품 작가의 생애 문서 + 그 작가가 포함된 비교 문서
        SELECT da.document_id
        FROM document_artists AS da
        JOIN artworks AS aw ON aw.artist_id = da.artist_id
        WHERE aw.id = @artwork_id
      )
ORDER BY distance
LIMIT 5;
-- 주의: SELECT 목록에 c.embedding 을 넣지 말 것. 벡터가 통째로 네트워크를 타고 넘어옴.

-- (3) 이 작품을 언급한 연표 사건 (document_artworks, 마이그레이션 20261011_0002)
--     위 범위 (2)에 이미 들어 있지만, 거리 순위와 상관없이 항상 컨텍스트에 넣는다.
--     '야경 그릴 때 렘브란트는 어땠어?' 같은 질문에서 생애 이야기를 놓치지 않기 위함.
SELECT d.id AS document_id, d.doc_key, d.title, d.content, d.source_name, d.source_url
FROM document_artworks AS dw
JOIN documents AS d ON d.id = dw.document_id
WHERE dw.artwork_id = @artwork_id
ORDER BY d.doc_key;

-- ---------------------------------------------------------------------
-- D. '이 작품과 비슷한 작품 3개' (기능 5, 작품 상세 화면용 / 비로그인도 가능)
--    안쪽 쿼리를 "ORDER BY 거리 LIMIT k" 만 있는 순수 KNN 형태로 유지함.
--    나중에 벡터 인덱스를 붙였을 때 인덱스가 쓰이는 조건이 바로 이 형태임.
--    자기 자신 1개가 섞여 나오므로 4개를 뽑고 바깥에서 제외.
-- ---------------------------------------------------------------------
SET @seed_vec = (SELECT VEC_AS_TEXT(embedding) FROM artwork_embeddings WHERE artwork_id = @artwork_id);

SELECT a.id, a.title, a.image_url, ar.name AS artist_name, knn.distance
FROM (
        SELECT e.artwork_id,
               VEC_COSINE_DISTANCE(e.embedding, @seed_vec) AS distance
        FROM artwork_embeddings AS e
        ORDER BY distance
        LIMIT 4
     ) AS knn
JOIN artworks AS a  ON a.id  = knn.artwork_id
JOIN artists  AS ar ON ar.id = a.artist_id
WHERE knn.artwork_id <> @artwork_id
ORDER BY knn.distance
LIMIT 3;

-- ---------------------------------------------------------------------
-- E. 좋아요 기반 개인화 추천 후보 30개 (기능 5, 6 공통 입력)
--    평균 벡터를 만들지 않고, 최근 좋아요 10개 각각과의 거리 중 '가장 가까운 값'을 점수로 씀.
--      - 취향이 여러 갈래(인상주의 + 추상)여도 각 갈래의 이웃이 살아남음
--      - TiDB 문서의 벡터용 집계 함수 목록(COUNT/MAX/MIN)에 AVG 가 없어서, 평균은 앱으로 벡터를 꺼내 와 계산해야 함
--    계산량 = 좋아요 10개 x 전체 작품 수. 작품 수천 개 규모에서는 부담 없는 크기.
--    3개가 아니라 30개를 뽑는 이유: 작가 다양성 필터와 작가 추천에 재료가 필요함.
-- ---------------------------------------------------------------------
SELECT cand.artwork_id,
       a.artist_id,
       a.title,
       MIN(VEC_COSINE_DISTANCE(cand.embedding, seed.embedding)) AS best_distance
FROM (
        -- 최근 좋아요 10개만 시드로 사용 (오래된 취향이 결과를 지배하지 않게 함)
        SELECT l.artwork_id
        FROM artwork_likes AS l
        WHERE l.user_id = @user_id
        ORDER BY l.created_at DESC
        LIMIT 10
     ) AS recent
JOIN artwork_embeddings AS seed ON seed.artwork_id = recent.artwork_id
JOIN artwork_embeddings AS cand ON cand.artwork_id <> seed.artwork_id
JOIN artworks AS a ON a.id = cand.artwork_id
WHERE cand.artwork_id <> @artwork_id                       -- 지금 보고 있는 작품 제외
  AND cand.artwork_id NOT IN (                             -- 이미 좋아요한 작품 제외
        SELECT l2.artwork_id FROM artwork_likes AS l2 WHERE l2.user_id = @user_id
      )
GROUP BY cand.artwork_id, a.artist_id, a.title
ORDER BY best_distance
LIMIT 30;
-- 앱에서 마무리: 위 30개를 순서대로 훑으며 작가당 1개씩만 골라 상위 3개를 반환.

-- ---------------------------------------------------------------------
-- F. 추천 작가 3명 (기능 6)
--    E 의 후보 30개를 작가별로 묶어 점수를 합산함.
--    이미 팔로우한 작가는 제외. (좋아요한 작품의 작가까지 뺄지는 기획에서 결정)
-- ---------------------------------------------------------------------
SELECT ar.id   AS artist_id,
       ar.name AS artist_name,
       COUNT(*)                    AS matched_artworks,
       SUM(1 - pool.best_distance) AS score      -- 1 - 거리 = 유사도. 여러 작품이 걸릴수록 점수 상승
FROM (
        SELECT cand.artwork_id,
               MIN(VEC_COSINE_DISTANCE(cand.embedding, seed.embedding)) AS best_distance
        FROM (
                SELECT l.artwork_id
                FROM artwork_likes AS l
                WHERE l.user_id = @user_id
                ORDER BY l.created_at DESC
                LIMIT 10
             ) AS recent
        JOIN artwork_embeddings AS seed ON seed.artwork_id = recent.artwork_id
        JOIN artwork_embeddings AS cand ON cand.artwork_id <> seed.artwork_id
        WHERE cand.artwork_id NOT IN (
                SELECT l2.artwork_id FROM artwork_likes AS l2 WHERE l2.user_id = @user_id
              )
        GROUP BY cand.artwork_id
        ORDER BY best_distance
        LIMIT 30
     ) AS pool
JOIN artworks AS a  ON a.id  = pool.artwork_id
JOIN artists  AS ar ON ar.id = a.artist_id
WHERE ar.id NOT IN (
        SELECT f.artist_id FROM artist_follows AS f WHERE f.user_id = @user_id
      )
GROUP BY ar.id, ar.name
ORDER BY score DESC
LIMIT 3;

-- ---------------------------------------------------------------------
-- G. 좋아요가 없는 신규 사용자용 대체 추천 (콜드 스타트)
--    큐레이션(is_featured) 우선, 그다음 전체 좋아요 수 순.
--    사용자가 몇 명뿐인 발표 환경에서는 '인기순'만으로는 전부 0이라 순서가 무의미하므로
--    is_featured 를 1순위로 둠.
-- ---------------------------------------------------------------------
SELECT a.id, a.title, a.image_url, a.is_featured, COUNT(l.user_id) AS like_count
FROM artworks AS a
LEFT JOIN artwork_likes AS l ON l.artwork_id = a.id
GROUP BY a.id, a.title, a.image_url, a.is_featured
ORDER BY a.is_featured DESC, like_count DESC, a.id
LIMIT 3;
