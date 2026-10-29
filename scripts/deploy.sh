
#!/usr/bin/env bash
# Автоматическая доставка сайта на Ubuntu Server

set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"

ROOT="$(git rev-parse --show-toplevel)"
LOCAL_DIR="${ROOT}/site/"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"

# Проверяем аргументы
DRY_RUN=false

if [[ $# -gt 1 ]]; then
    echo "Ошибка: слишком много аргументов" >&2
    exit 1
fi

if [[ $# -eq 1 ]]; then
    if [[ "$1" == "--dry-run" ]]; then
        DRY_RUN=true
    else
        echo "Ошибка: неизвестный аргумент $1" >&2
        exit 1
    fi
fi

# Проверяем наличие главной страницы
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: отсутствует site/index.html" >&2
    exit 1
fi

# Проверяем незакоммиченные изменения
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незакоммиченные изменения" >&2
    exit 1
fi

echo "Деплой коммита: $COMMIT"

RSYNC_ARGS=(-avz --delete --chmod=D755,F644)

if [[ "$DRY_RUN" == true ]]; then
    RSYNC_ARGS+=(--dry-run)
    echo "Пробный запуск — файлы не изменяются"
fi

# Передаём файлы через SSH
rsync "${RSYNC_ARGS[@]}" \
    -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
    "$LOCAL_DIR" "${REMOTE}:${REMOTE_DIR}/"

if [[ "$DRY_RUN" == true ]]; then
    echo "Пробный запуск завершён"
    exit 0
fi

# Проверяем HTTPS
if [[ ! -f "$CA_CERT" ]]; then
    echo "Ошибка: сертификат $CA_CERT не найден" >&2
    exit 1
fi

curl --fail --silent --show-error \
    --cacert "$CA_CERT" \
    -o /dev/null "$SITE_URL"

echo "Деплой выполнен успешно: $COMMIT"
exit 0
