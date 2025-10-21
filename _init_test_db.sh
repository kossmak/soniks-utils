#!/bin/bash

# скрипт дропает БД для отладки миграций
# создаёт её заново
# наполняет структурой и данными из dev-БД

set -o nounset

PGUSER=admin
PGPASSWORD=admin
PGHOST=localhost

# внимание, это дебаг-тест-база для отладки миграций
PGDATABASE=soniks_test

DEV_DB=soniks


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

echo "Дропаем базу ${PGDATABASE}"
psql -h ${PGHOST} -U ${PGUSER} -d ${DEV_DB} -c "drop database if exists ${PGDATABASE};"
if [ $? -eq 0 ]; then
    echo "База ${PGDATABASE} успешно удалена."
else
    echo "Ошибка при дропе базы."
    exit 1
fi

set -o errexit

echo "Пересоздаём пустую базу ${PGDATABASE}..."
psql -h ${PGHOST} -U ${PGUSER} -d ${DEV_DB} -c "create database ${PGDATABASE} with owner ${PGUSER};"
if [ $? -eq 0 ]; then
    echo "База ${PGDATABASE} успешно пересоздана."
else
    echo "Ошибка при создании базы."
    exit 1
fi

pg_dump -U ${PGUSER} -h ${PGHOST} -d ${DEV_DB} > _last_db_backup.sql

psql -h ${PGHOST} -U ${PGUSER} -d ${PGDATABASE} < _last_db_backup.sql

echo "DONE!"
