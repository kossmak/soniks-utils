
import uvicorn

# import src.main
# from src.core.configs import settings
# from main import app


def _main() -> None:
    uvicorn.run(
        # "main:app",  # зависит от рабочего каталога
        "src.main:app",
        # host="0.0.0.0",
        host="127.0.0.1",
        port=8088,
        reload=True,
        log_level="debug",
        reload_dirs=["src"],
        # reload_excludes=["*.pyc", "__pycache__", "templates"],
        reload_excludes=["*.pyc", "__pycache__", "templates", "src/templates"],
    )


if __name__ == "__main__":
    _main()
