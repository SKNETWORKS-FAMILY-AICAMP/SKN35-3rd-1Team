"""Application settings loaded from the repository root ``.env`` file."""

from functools import lru_cache
from pathlib import Path

from dotenv import dotenv_values
from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL, make_url

PROJECT_ROOT = Path(__file__).resolve().parents[3]
LEGACY_ENV = dotenv_values(PROJECT_ROOT / ".env")


class Settings(BaseSettings):
    """Runtime settings for TiDB.

    ``TIDB_*`` names are preferred, while the existing generic names in the
    team ``.env`` remain supported for backwards compatibility.
    """

    model_config = SettingsConfigDict(
        env_file=PROJECT_ROOT / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
        validate_default=True,
    )

    tidb_database_url: str | None = Field(
        default=None,
        validation_alias="TIDB_DATABASE_URL",
    )
    tidb_host: str | None = Field(
        default=LEGACY_ENV.get("HOST"),
        validation_alias="TIDB_HOST",
    )
    tidb_port: int = Field(
        default=int(LEGACY_ENV.get("PORT") or 4000),
        validation_alias="TIDB_PORT",
    )
    tidb_username: str | None = Field(
        default=LEGACY_ENV.get("USERNAME"),
        validation_alias="TIDB_USERNAME",
    )
    tidb_password: SecretStr | None = Field(
        default=LEGACY_ENV.get("PASSWORD"),
        validation_alias="TIDB_PASSWORD",
    )
    tidb_database: str | None = Field(
        default=LEGACY_ENV.get("DATABASE"),
        validation_alias="TIDB_DATABASE",
    )
    tidb_ssl_verify_cert: bool = True
    tidb_ssl_verify_identity: bool = True

    # Comma-separated web origins allowed to call the API (e.g. the Vercel domain).
    # Local Flutter dev servers on localhost/127.0.0.1 are always allowed.
    cors_origins: str = ""
    # "dev": every request acts as one fixed development user (no login yet).
    # "firebase": verify the Firebase ID token and resolve its UID in TiDB.
    auth_mode: str = "dev"
    dev_user_uid: str = "dev-user"
    firebase_project_id: str = "skn35-3rd-1team"
    # Railway can inject the JSON directly. Otherwise the Admin SDK uses ADC
    # (for example GOOGLE_APPLICATION_CREDENTIALS pointing to a mounted file).
    firebase_service_account_json: SecretStr | None = None
    google_application_credentials: str | None = None
    app_timezone: str = "Asia/Seoul"

    # 임베딩: 차원 수는 DB 컬럼(app.models.base.EMBEDDING_DIMENSION)이 기준이다.
    # 모델을 바꾸면 차원도 맞춰 Alembic 으로 컬럼을 바꾸고 청크·Chroma 를 전부 다시 만들어야 한다.
    openai_api_key: SecretStr | None = Field(default=None, validation_alias="OPENAI_API_KEY")
    embedding_model: str = Field(default="text-embedding-3-small", validation_alias="EMBEDDING_MODEL")
    embedding_batch_size: int = Field(default=100, validation_alias="EMBEDDING_BATCH_SIZE")

    # Chroma: 검색용 사본 (원본은 TiDB). CHROMA_HOST 가 있으면 서버(HttpClient), 없으면 CHROMA_PATH 폴더(PersistentClient).
    # Railway 공개 도메인은 CHROMA_PORT=443, CHROMA_SSL=true. 같은 프로젝트 내부망은 <서비스>.railway.internal:8000.
    # Chroma Cloud: 세 값이 모두 있으면 CloudClient 로 붙고 CHROMA_HOST·CHROMA_PATH 는 무시한다.
    chroma_api_key: SecretStr | None = Field(default=None, validation_alias="CHROMA_API_KEY")
    chroma_tenant: str | None = Field(default=None, validation_alias="CHROMA_TENANT")
    chroma_database: str | None = Field(default=None, validation_alias="CHROMA_DATABASE")
    chroma_host: str | None = Field(default=None, validation_alias="CHROMA_HOST")
    chroma_port: int = Field(default=8000, validation_alias="CHROMA_PORT")
    chroma_ssl: bool = Field(default=False, validation_alias="CHROMA_SSL")
    chroma_path: str | None = Field(default=None, validation_alias="CHROMA_PATH")
    # 개발용·발표용 컬렉션 이름을 나눈다 (예: chunks_dev / chunks)
    chroma_chunks_collection: str = Field(default="chunks", validation_alias="CHROMA_CHUNKS_COLLECTION")
    chroma_artworks_collection: str = Field(default="artworks", validation_alias="CHROMA_ARTWORKS_COLLECTION")

    @property
    def cors_origin_list(self) -> list[str]:
        return [
            origin.strip() for origin in self.cors_origins.split(",") if origin.strip()
        ]

    @property
    def sqlalchemy_url(self) -> URL:
        """Return a safely encoded SQLAlchemy URL without exposing secrets."""

        if self.tidb_database_url:
            return make_url(self.tidb_database_url)

        values = {
            "host": self.tidb_host,
            "username": self.tidb_username,
            "password": self.tidb_password,
            "database": self.tidb_database,
        }
        missing = [name for name, value in values.items() if value is None]
        if missing:
            raise ValueError(
                "Missing TiDB settings: "
                + ", ".join(f"TIDB_{name.upper()}" for name in missing)
            )

        return URL.create(
            drivername="mysql+pymysql",
            username=self.tidb_username,
            password=self.tidb_password.get_secret_value()
            if self.tidb_password
            else None,
            host=self.tidb_host,
            port=self.tidb_port,
            database=self.tidb_database,
        )

    @property
    def tidb_connect_args(self) -> dict[str, bool]:
        """PyMySQL TLS verification options required by TiDB Cloud."""

        return {
            "ssl_verify_cert": self.tidb_ssl_verify_cert,
            "ssl_verify_identity": self.tidb_ssl_verify_identity,
        }


@lru_cache
def get_settings() -> Settings:
    return Settings()
