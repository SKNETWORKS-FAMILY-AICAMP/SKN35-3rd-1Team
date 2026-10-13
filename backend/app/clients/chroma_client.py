"""Chroma 접속과 컬렉션. 적재(scripts.sync_chroma)와 검색(app.rag)이 함께 쓴다.

Chroma 는 TiDB 벡터의 검색용 사본이다. id 는 TiDB 행 id 를 문자열로 바꾼 값이고
(청크: document_chunks.id, 작품: artwork_embeddings.artwork_id), 벡터는 TiDB 에서 옮겨 온다.
Chroma 가 비거나 날아가면 sync_chroma 만 다시 돌리면 OpenAI 호출 없이 복원된다.
"""

from functools import lru_cache
from pathlib import Path

import chromadb
from chromadb.api import ClientAPI
from chromadb.api.models.Collection import Collection

from app.clients.embedding_client import model_name
from app.core.config import PROJECT_ROOT, get_settings

DISTANCE = "cosine"  # Chroma 기본값은 l2. 이미 만든 컬렉션의 거리 함수는 바꿀 수 없다


@lru_cache
def client() -> ClientAPI:
    """접속 우선순위: Chroma Cloud(API 키) > 서버(CHROMA_HOST) > 로컬 폴더(CHROMA_PATH)."""
    settings = get_settings()
    cloud = (settings.chroma_api_key, settings.chroma_tenant, settings.chroma_database)
    if any(cloud):
        if not all(cloud):
            raise RuntimeError("Chroma Cloud 는 CHROMA_API_KEY, CHROMA_TENANT, CHROMA_DATABASE 세 값이 모두 필요합니다.")
        return chromadb.CloudClient(
            tenant=settings.chroma_tenant,
            database=settings.chroma_database,
            api_key=settings.chroma_api_key.get_secret_value(),
        )
    if settings.chroma_host:
        return chromadb.HttpClient(host=settings.chroma_host, port=settings.chroma_port, ssl=settings.chroma_ssl)
    if settings.chroma_path:
        path = Path(settings.chroma_path)
        return chromadb.PersistentClient(path=str(path if path.is_absolute() else PROJECT_ROOT / path))
    raise RuntimeError(
        ".env 에 Chroma 접속 정보가 없습니다. CHROMA_API_KEY·CHROMA_TENANT·CHROMA_DATABASE(Chroma Cloud), "
        "CHROMA_HOST(서버), CHROMA_PATH(로컬 폴더) 중 하나를 넣으세요."
    )


def describe() -> str:
    """어디에 붙었는지 사람이 읽을 수 있게 (비밀값 제외)."""
    s = get_settings()
    if s.chroma_api_key:
        return f"Chroma Cloud {s.chroma_tenant}/{s.chroma_database}"
    return f"Chroma {s.chroma_host}:{s.chroma_port}" if s.chroma_host else f"Chroma 로컬 {s.chroma_path}"


def chunks_collection(chroma: ClientAPI | None = None) -> Collection:
    return _collection(chroma or client(), get_settings().chroma_chunks_collection)


def artworks_collection(chroma: ClientAPI | None = None) -> Collection:
    return _collection(chroma or client(), get_settings().chroma_artworks_collection)


def _collection(chroma: ClientAPI, name: str) -> Collection:
    """없으면 만들고, 있으면 같은 임베딩 모델·거리 함수로 만든 컬렉션인지 확인한다.

    embedding_function=None: 벡터는 항상 우리가 넣으므로 Chroma 기본 임베딩 모델을 쓰지 않는다.
    """
    model = model_name()
    collection = chroma.get_or_create_collection(
        name,
        metadata={"hnsw:space": DISTANCE, "embedding_model": model},
        embedding_function=None,
    )
    meta = collection.metadata or {}
    if meta.get("embedding_model") != model or meta.get("hnsw:space") != DISTANCE:
        raise RuntimeError(
            f"Chroma 컬렉션 '{name}' 은 {meta.get('embedding_model')}/{meta.get('hnsw:space')} 로 만들어졌습니다 "
            f"(지금 설정 {model}/{DISTANCE}). `sync_chroma --reset` 으로 다시 만드세요."
        )
    return collection
