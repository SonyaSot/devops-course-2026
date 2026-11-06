
#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo " [OK] $desc"
        ((PASS+=1))
    else
        echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL+=1))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"

check "Вход от имени root запрещён" \
    "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"

check "Парольная аутентификация отключена" \
    "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

check "Порт SSH отличается от 22" \
    "yes" "$(sudo sshd -T | awk '/^port/{if ($2 != 22) print "yes"; else print "no"}')"

check "MaxAuthTries равен 3" \
    "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"

check "Межсетевой экран активен" \
    "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"

check "Политика входящих соединений — deny" \
    "deny" "$(sudo ufw status verbose | awk '/^Default:/{print $2}')"

echo "[3] Учётные записи"

awk -F: '$3>=1000 && $3<65534 {printf "              %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"

check "Служба Nginx активна" \
    "active" "$(systemctl is-active nginx)"

if sudo nginx -t >/dev/null 2>&1; then
    nginx_config="ok"
else
    nginx_config="fail"
fi

check "Конфигурация Nginx корректна" \
    "ok" "$nginx_config"

if openssl x509 -in /etc/ssl/certs/devops.crt \
    -noout -checkend 2592000 >/dev/null 2>&1; then
    cert_status="ok"
else
    cert_status="fail"
fi

check "Сертификат действителен ещё минимум 30 дней" \
    "ok" "$cert_status"

unsafe_files=$(find /var/www/devops-site -perm -o+w -print)

check "Нет файлов с правом записи для всех" \
    "" "$unsafe_files"

check "Права закрытого TLS-ключа равны 600" \
    "600" "$(sudo stat -c '%a' /etc/ssl/private/devops.key)"


echo "[5] Контейнеризация"

check "Служба Docker активна" \
    "active" "$(systemctl is-active docker)"

check "PostgreSQL имеет статус healthy" \
    "healthy" "$(docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null)"

unsafe_ports=$(sudo ss -tlnH | awk '
{
    address=$4
    if (address ~ /:(5000|5432)$/ &&
        address !~ /^127\.0\.0\.1:/) {
        print address
    }
}')

check "Порты 5000 и 5432 не опубликованы наружу" \
    "" "$unsafe_ports"

check "Права файла .env равны 600" \
    "600" "$(stat -c '%a' /home/devops/app/.env)"

echo "Пройдено: $PASS, не пройдено: $FAIL"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1

