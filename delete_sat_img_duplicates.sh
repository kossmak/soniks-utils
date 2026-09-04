#!/bin/bash


set -euo pipefail

## вывести в консоль список файлов, имена которых содержатся в файле
## Paths
#SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#FNAMES_FILE="${SCRIPT_DIR}/_used_sat_imgs.txt"
#
#
#SOURCE_DIR="/home/kp.makarov@geoscan.lan/proj/nginx_data/soniks_v1_media/satellites"
#
## Check if input file exists
#if [[ ! -f "${FNAMES_FILE}" ]]; then
#    echo "Error: ${FNAMES_FILE} not found"
#    exit 1
#fi
#
## Process each line in the filenames file
#while IFS= read -r line || [[ -n "${line}" ]]; do
#    # Skip empty lines and comments
#    [[ -z "${line}" || "${line}" =~ ^# ]] && continue
#
#    # Extract the filename (part after 'satellites/')
#    filename="${line#satellites/}"
#
#    # Source file path
#    src_file="${SOURCE_DIR}/${filename}"
#
#     if [[ ! -f "${FNAMES_FILE}" ]]; then
##    if [[ -f "${src_file}" ]]; then
#        echo "missed ${src_file} vs. ${line}"
#    fi
#
#done < "${FNAMES_FILE}"
#
#echo "Done. Processed $(wc -l < "${FNAMES_FILE}") lines from ${FNAMES_FILE}"


## Список "используемых" файлов (FNAMES_FILE) формируется отдельно, вручную,
## SQL-запросом к satellites.image_path (legacy-пути, НЕ ссылки на media/S3) —
## см. обсуждение в диалоге. Секция psql-экспорта здесь больше не нужна (108)
## и удалена как противоречащая текущему workflow (список — готовый входной файл).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FNAMES_FILE="${SCRIPT_DIR}/_used_sat_imgs.txt"

#DIR="./satellites"
#LIST_FILE="_used_sat_imgs.txt"
DIR="${SCRIPT_DIR}/satellites"
LIST_FILE="${FNAMES_FILE}"
DELETED_LOG="${SCRIPT_DIR}/_deleted_sat_imgs_$(date +%Y%m%d_%H%M%S).log"
DRY_RUN=false

if [[ -n "${DEBUG:-}" ]]; then
    # Отладка только по явному запросу через переменную окружения
    set -o xtrace;
    trap 'echo "# $BASH_COMMAND";read' DEBUG
fi

# (110) Явная проверка аргументов до обращения к $1 — иначе крах под set -u
if [ "$#" -eq 0 ]; then
    echo "Использование: $0 --dry-run|--apply" >&2
    echo "  --dry-run  — только показать, что будет удалено, ничего не трогает" >&2
    echo "  --apply    — реально удалить бесхозные файлы" >&2
    exit 1
fi

if [ "$1" = "--dry-run" ] || [ "$1" = "-n" ]; then
    DRY_RUN=true
    echo "*** РЕЖИМ ПРОВЕРКИ (файлы не будут удалены) ***"
elif [ "$1" = "--apply" ]; then
    DRY_RUN=false
else
    echo "Неизвестный аргумент: $1 (ожидается --dry-run или --apply)" >&2
    exit 1
fi

if [ ! -d "$DIR" ]; then
    echo "Ошибка: Директория $DIR не существует"
    exit 1
fi

if [ ! -f "$LIST_FILE" ]; then
    echo "Ошибка: Файл $LIST_FILE не найден"
    exit 1
fi

# Создаём список имён для сохранения (только уникальные имена)
KEEP_LIST=$(mktemp)
trap 'rm -f "$KEEP_LIST"' EXIT

echo "Извлекаю имена файлов из списка..."
while IFS= read -r line; do
    # Удаляем возможные пробелы в начале/конце строки
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -n "$line" ]; then
        # Извлекаем имя файла (после последнего /)
        filename=$(basename "$line")
        # Добавляем в список для сохранения
        echo "$filename" >> "$KEEP_LIST"
        echo "  Добавлен: $filename"
    fi
done < "$LIST_FILE"

# Сортируем и оставляем только уникальные имена
sort -u -o "$KEEP_LIST" "$KEEP_LIST"

TOTAL_KEEP=$(wc -l < "$KEEP_LIST")

# (111) Guard: пустой список "используемых" — не даём удалить всю директорию
if [ "$TOTAL_KEEP" -eq 0 ]; then
    echo "Ошибка: список используемых файлов пуст ($LIST_FILE) — прерываю," \
         "иначе будет удалена вся директория $DIR" >&2
    exit 1
fi

echo "Всего уникальных файлов для сохранения: $TOTAL_KEEP"
echo "---"

# Отображаем список сохранения для проверки
echo "Список файлов, которые НЕ будут удалены:"
cat "$KEEP_LIST" | head -20
if [ "$TOTAL_KEEP" -gt 20 ]; then
    echo "... и ещё $(($TOTAL_KEEP - 20)) файлов"
fi
echo "---"

DELETED=0
KEPT=0
FILES_IN_DIR=0

echo "Проверяю файлы в директории $DIR:"
for file in "$DIR"/*; do
    if [ -f "$file" ]; then
        FILES_IN_DIR=$((FILES_IN_DIR + 1))
        filename=$(basename "$file")

        if grep -Fxq "$filename" "$KEEP_LIST"; then
            echo "✓ $filename (сохраняем)"
            KEPT=$((KEPT + 1))
        else
            echo "✗ $filename (удаляем)"
            if [ "$DRY_RUN" = false ]; then
                rm -f "$file"
                # (112) Лог фактически удалённых файлов
                echo "$filename" >> "$DELETED_LOG"
            fi
            DELETED=$((DELETED + 1))
        fi
    fi
done

echo "---"
echo "Всего файлов в директории: $FILES_IN_DIR"
echo "Сохранено: $KEPT"
echo "Удалено: $DELETED"

if [ "$DRY_RUN" = true ]; then
    echo "*** РЕЖИМ ПРОВЕРКИ: ничего не удалено ***"
else
    echo "Лог удалённых файлов: $DELETED_LOG"
fi
