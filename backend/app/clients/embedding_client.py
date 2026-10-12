"""텍스트를 벡터로 바꾼다. 문서 청크 적재(scripts.build_chunks)와 챗봇 질문 임베딩이 함께 쓴다.

질문과 문서는 반드시 같은 모델로 임베딩해야 거리 값이 의미가 있다.
모델 이름은 설정(EMBEDDING_MODEL)에서, 차원 수는 DB 컬럼 정의에서 읽는다.
"""

from functools import lru_cache

from langchain_openai import OpenAIEmbeddings

from app.core.config import get_settings
from app.models.base import EMBEDDING_DIMENSION


def model_name() -> str:
    """`document_chunks.embedding_model` 에 기록할 이름."""
    return get_settings().embedding_model


@lru_cache
def _client() -> OpenAIEmbeddings:
    settings = get_settings()
    if settings.openai_api_key is None:
        raise RuntimeError(".env 에 OPENAI_API_KEY 가 없습니다.")
    return OpenAIEmbeddings(
        model=settings.embedding_model,
        api_key=settings.openai_api_key,
        chunk_size=settings.embedding_batch_size,  # 한 번의 API 호출에 보내는 건수
        max_retries=5,
    )


def embed_texts(texts: list[str]) -> list[list[float]]:
    """여러 건을 배치로 임베딩한다. 결과 순서는 입력 순서와 같다."""
    if not texts:
        return []
    vectors = _client().embed_documents(texts)
    _check(vectors)
    return vectors


def embed_query(text: str) -> list[float]:
    vector = _client().embed_query(text)
    _check([vector])
    return vector


def _check(vectors: list[list[float]]) -> None:
    """모델과 DB 컬럼의 차원이 다르면 적재 단계에서 알 수 없는 오류가 나므로 여기서 먼저 막는다."""
    bad = {len(v) for v in vectors} - {EMBEDDING_DIMENSION}
    if bad:
        raise ValueError(
            f"임베딩 차원 {sorted(bad)} 이 DB 컬럼 VECTOR({EMBEDDING_DIMENSION}) 과 다릅니다. "
            f"모델({model_name()})을 확인하세요."
        )
