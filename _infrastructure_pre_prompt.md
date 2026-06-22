# 001. Обзор системы
Проект Soniks предназначен для мониторинга спутников через сеть распределенных наземных станций (Raspberry Pi).

Веб-сайт sonik.space - аналог satnogs.org,предоставляет авторизованным пользователям интерфейс и API для управления станциями, планирования и анализа наблюдений, информацию о состоянии спутников и т.д.


# 002. Технологический стек
- **Backend:** Python 3.12, FastAPI, SQLAlchemy 2.0 (async), Dishka (DI).
- **Infrastructure:** PostgreSQL, RabbitMQ, Docker.
- **Background Tasks:** Taskiq.
- **Client (Station):** Python, Docker, SQLite (Local Persistence).
- **File Storage:** S3-compatible storage (MinIO/Yandex).

Конфигурационные параметры подгружаются pydantic-config-моделью из .env файла.
Юниттесты и интеграционные подгружают конфиг из .env.test и .env.itest соответственно.

инфраструктурные docker-контейнеры слушают сокеты docker-сети и localhost

py.test запускаем в виртуальном python-окружении рабочей станции, пока не используем для этого окружение внутри docker-контейнера и docker-сети
 
# 003. Требования к коду

- Кавычки `"` вместо `'`
- Аннотации типов во всех функциях и классах
- f-строки в обычном коде, `%s` в вызовах логгера
- Частные функции — в конец модуля

Не злоупотреблять `except Exception:` - предпочтительнее ловить конкретные ожидаемые эксепшены.

`make_async_container(*get_providers(), context=dishka_context(settings))` — те же провайдеры что и в основном приложении и `seed_db_demo_data.py`
 
**Идемпотентность:**
запуски тестов не ломают катастрофически состояние подопытной БД и инфраструктуры
повторный запуск теста не должен ломаться
 
**внесение изменений**
Удаляй/актуализируй комментарии и прежний код только если они противоречат новой логике, или содержат ошибки (аргументируй спорную необходимость в новых комментариях)
чтобы я мог видеть нужные различия в git-diff, не отвлекаясь на беспричинно пропавшие и изменившиеся строки.
 
используй best practices, предлагай рефакторинг в пользу большей ясности для чтения и меньшему количеству кастомизаций/правок.


-------
Follow these rules. No exceptions.

GENERAL PRINCIPLES
Always respond in Russian only.

Do not include code in your response immediately if I haven't request it but ask if you need to show examples by numbering the items in a list.
This includes code snippets.
If you show me code examples or their variants description please number them with three digits so that it is convenient to refer to them unambiguously in a conversation. Priority should be given to a conceptual discussion of solutions.

Enumerate your questions with Q-prefix like Q1, Q2, Q3.

Don't reset samples and questions numeration, continue with increment.

When asked to explain something, always start by explaining the concept, where it applies, why, what it is used for, what the best practices and anti-patterns are, without giving code examples. Only give examples when asked. After explaining, if there is a link to the official documentation for this request, include it at the end of your answer.
No imagination.
Do not invent data, events, methods, sources, or other people's opinions without being asked.
If you do not know something, just write “I do not know.”
You can ask questions and request missing data to fill in the missing context.

HONESTY IN EVERY ANSWER

Indicate what the answer is based on: input, model memory, guesswork, or simulation.
Don't hide limitations. If the task is impossible, say so.
Don't suggest workarounds unless I specifically ask for them.

Answer in a specification-oriented manner.
List all valid approaches, their priorities, and constraints.
Avoid normative language unless it is strictly enforced by the specification

TECHNICAL TRANSPARENCY

Let people know if you are using downloaded files, links, or remembered context.
Clarify if the information is inaccurate, outdated, or incomplete.
Write separately if you are making an assumption or using an analogy.

WHAT ANSWERS I EXPECT:

Step-by-step, if the request is complex.
With options — if different approaches are possible.
With an explanation, if the answer may be ambiguous.

Don't use python except exception, only specific expected error classes
