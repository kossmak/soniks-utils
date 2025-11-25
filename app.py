from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from logging import Logger

from dishka import AsyncContainer, make_async_container
from dishka.integrations.fastapi import setup_dishka
from fastapi import FastAPI
from fastapi.responses import ORJSONResponse
from markupsafe import escape
from prometheus_client import REGISTRY
from prometheus_client.openmetrics.exposition import (
    CONTENT_TYPE_LATEST,
    generate_latest,
)
from sqlalchemy.ext.asyncio import AsyncEngine
from starlette.requests import Request
from starlette.responses import Response
from taskiq_aio_pika import AioPikaBroker

from src.core.configs import LoggingSettings, Settings
from src.core.configs.admin import AdminSettings
from src.core.configs.auth import AuthSettings
from src.core.configs.database import PostgresSettings, SQLEngineSettings
from src.core.configs.file import FileSettings
from src.core.configs.file_storage import MinioSettings
from src.core.containers import get_providers
from src.infrastructure.open_telemetry import configure_otlp
from src.presentation.admin import add_views
from src.presentation.admin.base import CustomAdmin
from src.presentation.api.exceptions.handlers import setup_handlers
from src.presentation.api.middlewares.admin import AdminAuthMiddleware
from src.presentation.api.middlewares.prometheus import PrometheusMiddleware
from src.presentation.api.middlewares.upload_file import LimitUploadSizeMiddleware
from src.presentation.api.v1.routers import api_v1_router


def metrics(request: Request) -> Response:
    return Response(
        generate_latest(REGISTRY),
        headers={"Content-Type": CONTENT_TYPE_LATEST},
    )


def add_admin(
    app: FastAPI,
    engine: AsyncEngine,
    admin_settings: AdminSettings,
) -> None:
    admin = CustomAdmin(
        app=app,
        engine=engine,
        title=admin_settings.TITLE,
        base_url=admin_settings.ADMIN_URL,
        templates_dir=admin_settings.TEMPLATES_DIR,
    )

    def safe_render_field(field, **kwargs):
        """Jinja-фильтр для отладки ошибок рендеринга "трудных" полей."""
        try:
            return field(**kwargs)
        except Exception as err1:
            from loguru import logger

            logger.error(
                f"Failed to render field {field.name}: {str(field.data)}: {err1}"
            )
            if field.name == "countries":
                field.data = []
                field.raw_data = []
            else:
                field.data = None
                field.raw_data = None
            try:
                rendered_field = field(**kwargs)
            except Exception as err2:
                field_type = escape(str(err1))
                return (
                    f'<div class="alert alert-danger">Error rendering field "{field.name}": {field_type}</div>'
                    + f'<div class="alert alert-danger">Error2: {str(err2)}</div>'
                )

            return f'<div class="alert alert-danger">Error rendering field "{field.name}": {str(err1)}</div>{rendered_field}'

    # Добавить в Jinja environment
    admin.templates.env.globals["safe_render"] = safe_render_field

    add_views(admin)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    container: AsyncContainer = app.state.dishka_container

    engine = await container.get(AsyncEngine)
    admin_settings = await container.get(AdminSettings)

    add_admin(app, engine, admin_settings)

    broker = await container.get(AioPikaBroker)
    if not broker.is_worker_process:
        await broker.startup()

    logger = await container.get(Logger)
    logger.info("Приложение успешно запущено")

    yield

    await container.close()

    if not broker.is_worker_process:
        await broker.shutdown()

    logger.info("Приложение успешно завершило работу")


def create_app(settings: Settings) -> FastAPI:
    app = FastAPI(
        debug=settings.app.DEBUG,
        default_response_class=ORJSONResponse,
        lifespan=lifespan,
    )
    app.add_middleware(AdminAuthMiddleware, settings.admin.ADMIN_URL)

    if settings.otlp.HOST:
        configure_otlp(app, settings.app.APP_NAME, settings.otlp)
        app.add_middleware(PrometheusMiddleware, settings.app.APP_NAME)
    else:
        print("unused OTLP!")

    app.add_middleware(
        LimitUploadSizeMiddleware,
        settings.file.MAX_FILE_SIZE,
        settings.file.UPLOAD_FILE_URL,
    )

    app.include_router(api_v1_router)
    app.add_route("/metrics", metrics)

    context = {
        PostgresSettings: settings.postgres,
        SQLEngineSettings: settings.sql_engine,
        AuthSettings: settings.auth,
        AdminSettings: settings.admin,
        FileSettings: settings.file,
        MinioSettings: settings.minio,
        LoggingSettings: settings.logging,
    }

    container = make_async_container(*get_providers(), context=context)
    setup_dishka(container, app)

    setup_handlers(app, container)

    return app
