#!/bin/bash

# скрипт дропает БД для отладки миграций
# создаёт её заново
# наполняет структурой и данными из dev-БД

set -o nounset

# APP_INSTANCE="${APP_INSTANCE:-dev2}"
APP_INSTANCE="${APP_INSTANCE:-local}"

if [[ $APP_INSTANCE == "dev2" ]] ; then

  # предустановка для стенда dev2.sonik.space
  PGADMIN="${PGADMIN:-user_dev_v2}"
  DEV_DB="${DEV_DB:-soniks_dev_v2}"

else

  PGADMIN="${PGADMIN:-admin}"
  DEV_DB="${DEV_DB:-soniks}"

fi

# внимание, это целевая (пересоздаваемая) дебаг-тест-база для отладки миграций
TARGET_DATABASE="${TARGET_DATABASE:-soniks_test}"


TARGET_CONTAINER="${TARGET_CONTAINER:-soniks-postgres}"

PG_COPY_DATA="no"


parseopts () {
  while getopts "hd" optname
      do
        case "$optname" in
          "d")
            echo "Включить копирование данных из dev-БД"
            PG_COPY_DATA="yes"
            ;;
          "h")
            echo "Скрипт для дропа и пересоздания тестовой БД"
            echo "Параметры:"
            echo "    -d - включить копирование данных из dev-БД"
            echo "    -h - помощь"
            echo ""
            echo "Пример: ./scripts/_init_test_db.sh -d"
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
echo "Попытка завершить все подключения к ${TARGET_DATABASE}..."
# Завершить все активные сессии к дебаг-базе (кроме текущей)
sql_query=$(cat <<EOF
  SELECT pg_terminate_backend(pid)
  FROM pg_stat_activity
  WHERE datname = '${TARGET_DATABASE}' AND pid <> pg_backend_pid();
EOF
)

if docker exec "${TARGET_CONTAINER}" psql -U "${PGADMIN}"  -d ${DEV_DB} -c "${sql_query}"; then
    echo "Подключения завершены."
else
    echo "Ошибка при завершении подключений. Проверьте права и подключение."
    exit 1
fi


##############################################################
# step1: drop db (test)
##############################################################
echo "Дропаем базу ${TARGET_DATABASE}"
# подключаемся к dev-БД, чтобы дропнуть соседнюю
if ! docker exec "${TARGET_CONTAINER}" psql -U "${PGADMIN}" -d ${DEV_DB} -c "drop database if exists ${TARGET_DATABASE};";
then
    echo "Ошибка при дропе базы."
    exit 1
else
    echo "База ${TARGET_DATABASE} успешно удалена."
fi

set -o errexit

##############################################################
# step2: create empty db (test)
##############################################################
echo "Пересоздаём пустую базу ${TARGET_DATABASE}..."
sql_query=$(cat <<EOF
  create database ${TARGET_DATABASE} with owner ${PGADMIN};
EOF
)
if docker exec "${TARGET_CONTAINER}" psql -U "${PGADMIN}" -d ${DEV_DB} -c "${sql_query}"; then
    echo "База ${TARGET_DATABASE} успешно пересоздана."
else
    echo "Ошибка при создании базы."
    exit 1
fi

##############################################################
# step3: забираем актуальный дамп из dev-БД
##############################################################
# FUTURE: покуда добавил --if-exists, и --clean,
#        можно теперь обойтись без шагов 1 и 2 (пересоздание БД)
if [[ $PG_COPY_DATA == "yes" ]]; then
    echo "Копируем структуру и данные из dev-БД"
    docker exec -u root -it "${TARGET_CONTAINER}" sh -c "pg_dump -U ${PGADMIN} -d ${DEV_DB} --clean --if-exists > /tmp/_last_db_backup.sql"
else
    echo "Копируем структуру из dev-БД"
    docker exec -u root -it "${TARGET_CONTAINER}" sh -c "pg_dump -U ${PGADMIN} -d ${DEV_DB} --clean --if-exists --schema-only > /tmp/_last_db_backup.sql"
fi

##############################################################
# step4: накатываем бэкап на тестовую БД
##############################################################
docker exec -u root -it "${TARGET_CONTAINER}" sh -c "psql -U ${PGADMIN} -d ${TARGET_DATABASE} < /tmp/_last_db_backup.sql"

if [[ $PG_COPY_DATA != "yes" ]]; then
    # данные таблиц не копировались, только структура,
    # но содержимое служебной таблицы alembic_version должно быть заполнено
    # чтобы alembic мог корректно сравнить версии
    echo "Копируем данные alembic_version из dev-БД"

    docker exec -u root -it "${TARGET_CONTAINER}" sh -c "pg_dump -U ${PGADMIN} -d ${DEV_DB} \
      --table=alembic_version \
      --data-only \
      --inserts \
    | psql -U ${PGADMIN} -d ${TARGET_DATABASE}"
fi

echo "DONE!"
