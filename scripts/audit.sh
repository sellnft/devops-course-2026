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

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1