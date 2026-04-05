from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/haeda"
    SECRET_KEY: str = "dev-secret-key"
    API_V1_PREFIX: str = "/api/v1"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7   # 7 days
    REFRESH_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 30  # 30 days

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
