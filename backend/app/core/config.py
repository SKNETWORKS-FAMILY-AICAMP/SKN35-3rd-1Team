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
