"""Chroma 접속 방식 선택 테스트. 실제로 접속하지 않고 어떤 클라이언트를 어떤 값으로 만드는지만 본다."""

from types import SimpleNamespace

import pytest
from pydantic import SecretStr

from app.clients import chroma_client


def settings(**kw):
    values = {
        "chroma_api_key": None, "chroma_tenant": None, "chroma_database": None,
        "chroma_host": None, "chroma_port": 8000, "chroma_ssl": False, "chroma_path": None,
    }
    return SimpleNamespace(**(values | kw))


@pytest.fixture
def made(monkeypatch):
    """chromadb 클라이언트 생성자를 가짜로 바꿔, 어떤 것이 어떤 인자로 불렸는지 기록한다."""
    calls = []
    for name in ("CloudClient", "HttpClient", "PersistentClient"):
        monkeypatch.setattr(chroma_client.chromadb, name, lambda *a, _n=name, **k: calls.append((_n, k)) or _n)
    chroma_client.client.cache_clear()
    yield calls
    chroma_client.client.cache_clear()


def use(monkeypatch, **kw):
    monkeypatch.setattr(chroma_client, "get_settings", lambda: settings(**kw))
    return chroma_client.client()


def test_cloud_wins_when_all_three_values_exist(monkeypatch, made):
    got = use(monkeypatch, chroma_api_key=SecretStr("ck-secret"), chroma_tenant="t1", chroma_database="artlog",
              chroma_host="ignored.example")
    assert got == "CloudClient"
    assert made == [("CloudClient", {"tenant": "t1", "database": "artlog", "api_key": "ck-secret"})]


def test_partial_cloud_settings_fail_loudly(monkeypatch, made):
    with pytest.raises(RuntimeError, match="세 값이 모두"):
        use(monkeypatch, chroma_api_key=SecretStr("ck-secret"), chroma_tenant="t1")


def test_blank_cloud_values_fall_back_to_server(monkeypatch, made):
    """.env 에 `CHROMA_API_KEY=` 처럼 비워 둔 줄이 있어도 Cloud 로 판단하지 않는다."""
    got = use(monkeypatch, chroma_api_key=SecretStr(""), chroma_tenant="", chroma_database="",
              chroma_host="chroma.railway.internal")
    assert got == "HttpClient"
    assert made == [("HttpClient", {"host": "chroma.railway.internal", "port": 8000, "ssl": False})]


def test_local_folder_when_no_server(monkeypatch, made):
    assert use(monkeypatch, chroma_path="data/chroma") == "PersistentClient"
    assert made[0][1]["path"].endswith("data/chroma")


def test_nothing_configured_explains_options(monkeypatch, made):
    with pytest.raises(RuntimeError, match="CHROMA_API_KEY"):
        use(monkeypatch)


def test_describe_never_prints_the_key(monkeypatch):
    monkeypatch.setattr(chroma_client, "get_settings", lambda: settings(
        chroma_api_key=SecretStr("ck-secret"), chroma_tenant="t1", chroma_database="artlog"))
    text = chroma_client.describe()
    assert "t1/artlog" in text and "ck-secret" not in text
