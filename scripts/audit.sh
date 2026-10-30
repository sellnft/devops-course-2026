#!/usr/bin/env bash
set -uo pipefail

PASS=0; FAIL=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo " [OK]  $desc"; ((PASS++))
  else
    echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"; ((FAIL++))
  fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"
check "Порт SSH не 22" "yes" "$([ "$(sudo sshd -T | awk '/^port/{print $2}')" != "22" ] && echo yes || echo no)"
check "MaxAuthTries = 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"
check "UFW incoming deny" "deny" "$(sudo ufw status verbose | grep Default | awk '{print $2}')"

echo "[3] Учётные записи"
awk -F: ' $3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"
# а) Конфигурация Nginx корректна
if sudo nginx -t 2>/dev/null; then
  echo " [OK] Конфигурация nginx корректна"; ((PASS++))
else
  echo " [FAIL] Конфигурация nginx корректна"; ((FAIL++))
fi

# б) Сертификат истекает не ранее чем через 30 дней
if sudo openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt; then
  echo " [OK] Сертификат действителен более 30 дней"; ((PASS++))
else
  echo " [FAIL] Сертификат истекает менее чем через 30 дней"; ((FAIL++))
fi

# в) В каталоге ресурса нет файлов, доступных для записи всем
if [ -z "$(sudo find /var/www/devops-site -perm -o+w)" ]; then
  echo " [OK] Нет файлов, доступных для записи всем"; ((PASS++))
else
  echo " [FAIL] Найдены файлы, доступные для записи всем"; ((FAIL++))
fi

# г) Права ключа равны 600
if [ "$(sudo stat -c '%a' /etc/ssl/private/devops.key)" == "600" ]; then
  echo " [OK] Права ключа 600"; ((PASS++))
else
  echo " [FAIL] Права ключа не 600"; ((FAIL++))
fi

echo "[5] Контейнеризация"
# а) Служба docker активна
if [[ "$(systemctl is-active docker)" == "active" ]]; then
  echo " [OK] Служба Docker активна"; ((PASS++))
else
  echo " [FAIL] Служба Docker не активна"; ((FAIL++))
fi

# б) Контейнер СУБД в состоянии healthy
if [[ "$(sudo docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null)" == "healthy" ]]; then
  echo " [OK] Контейнер СУБД healthy"; ((PASS++))
else
  echo " [FAIL] Контейнер СУБД не healthy"; ((FAIL++))
fi

# в) Порты 5000 и 5432 не прослушиваются на внешних адресах
if ! sudo ss -tln | grep -E '0\.0\.0\.0:(5000|5432)|\[::\]:(5000|5432)' > /dev/null; then
  echo " [OK] Порты 5000 и 5432 не прослушиваются извне"; ((PASS++))
else
  echo " [FAIL] Порты 5000 или 5432 доступны извне"; ((FAIL++))
fi

# г) Права файла .env равны 600
if [[ "$(sudo stat -c '%a' /home/devops/app/.env 2>/dev/null)" == "600" ]]; then
  echo " [OK] Права файла .env (600)"; ((PASS++))
else
  echo " [FAIL] Права файла .env не 600"; ((FAIL++))
fi

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1