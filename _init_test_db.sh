#!/bin/bash

# скрипт дропает БД для отладки миграций
# создаёт её заново
# наполняет структурой и данными из dev-БД

set -o nounset

PGUSER="admin"
PGHOST="localhost"

# внимание, это дебаг-тест-база для отладки миграций
PGDATABASE=soniks_test

PG_COPY_DATA=0

DEV_DB=soniks

parseopts () {
  while getopts "hd" optname
      do
        case "$optname" in
          "d")
            echo "Включить копирование данных из dev-БД"
            PG_COPY_DATA=1
            ;;
          "h")
            echo "Скрипт для дропа и пересоздания тестовой БД"
            echo "Параметры:"
            echo "    -d - включить копирование данных из dev-БД"
            echo "    -h - помощь"
            echo ""
            echo "Пример: PYTHONPATH=. python3 ./scripts/init_test_db.py -d"
            exit 0
            ;;
          "?")
            echo "Неизвестный параметр: -$OPTARG"
            exit 1
            ;;
          *)
            # Соответствий не найдено
            echo "Unknown error while processing options"
            ;;
        esac
      done
}

parseopts "$@"

##############################################################
# step0: закрыть все активные сессии к пересоздаваемой debug-test-БД
# (кроме текущей, разумеется
#   - используемая для этого сессия закроется сама по завершении процесса отключения остальных)
##############################################################
echo "Попытка завершить все подключения к ${PGDATABASE}..."
# Завершить все активные сессии к дебаг-базе (кроме текущей)
psql -h ${PGHOST} -U ${PGUSER}  -d ${DEV_DB} -c "
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '${PGDATABASE}' AND pid <> pg_backend_pid();
"
if [ $? -eq 0 ]; then
    echo "Подключения завершены."
else
    echo "Ошибка при завершении подключений. Проверьте права и подключение."
    exit 1
fi


##############################################################
# step1: drop db (test)
##############################################################
echo "Дропаем базу ${PGDATABASE}"
if ! psql -h ${PGHOST} -U ${PGUSER} -d ${DEV_DB} -c "drop database if exists ${PGDATABASE};";
then
    echo "Ошибка при дропе базы."
    exit 1
else
    echo "База ${PGDATABASE} успешно удалена."
fi

set -o errexit

##############################################################
# step2: create empty db (test)
##############################################################
echo "Пересоздаём пустую базу ${PGDATABASE}..."
psql -h ${PGHOST} -U ${PGUSER} -d ${DEV_DB} -c "create database ${PGDATABASE} with owner ${PGUSER};"
if [ $? -eq 0 ]; then
    echo "База ${PGDATABASE} успешно пересоздана."
else
    echo "Ошибка при создании базы."
    exit 1
fi

##############################################################
# step3: забираем актуальный дамп из dev-БД
##############################################################
# FIXME: покуда добавил --if-exists, и --clean,
#        можно теперь обойтись без шагов 1 и 2 (пересоздание БД)
if [[ $PG_COPY_DATA -eq 1 ]]; then
    echo "Копируем структуру и данные из dev-БД"
    pg_dump -U ${PGUSER} -h ${PGHOST} -d ${DEV_DB} --clean --if-exists > _last_db_backup.sql
else
    echo "Копируем структуру из dev-БД"
    pg_dump -U ${PGUSER} -h ${PGHOST} -d ${DEV_DB} --clean --if-exists --schema-only > _last_db_backup.sql
fi

##############################################################
# step4: накатываем бэкап на тестовую БД
##############################################################
psql -h ${PGHOST} -U ${PGUSER} -d ${PGDATABASE} < _last_db_backup.sql

echo "DONE!"
