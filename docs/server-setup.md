# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины
- Объём оперативной памяти: 2048 МБ (2 ГБ)
- Количество ядер процессора: 2
- Объём диска: 25 ГБ (динамически расширяемый)
- Средство виртуализации: VirtualBox 7.x
- Операционная система: Ubuntu Server 24.04 LTS

## 2. Сетевые интерфейсы
- **Адаптер 1 (NAT):** IP-адрес `10.0.2.15` (интерфейс `enp0s3`). Назначение: доступ в Интернет для обновления пакетов.
- **Адаптер 2 (Host-only):** IP-адрес `192.168.56.101` (интерфейс `enp0s8`). Назначение: прямой доступ с хостовой системы (Windows) для SSH и веб-сервера.

## 3. Правило проброса портов
- Порт хостовой системы (Windows): `2222`
- Порт гостевой системы (Ubuntu): `2222`
- Протокол: TCP

## 4. Учётные записи
- **student / marco:** (изначальные учетные записи). Входят в группу `sudo`. Вход по паролю.
- **devops:** создан для управления. Входит в группу `sudo`. Вход по SSH-ключу (парольная аутентификация отключена).

## 5. Служба SSH
- Порт: `2222`
- Изменённые директивы (в файле `/etc/ssh/sshd_config.d/99-hardening.conf`):
  - `Port 2222`
  - `PermitRootLogin no`
  - `PasswordAuthentication no`
  - `PubkeyAuthentication yes`
  - `AllowUsers devops`
  - `MaxAuthTries 3`
  - `LoginGraceTime 30`
  - `ClientAliveInterval 300`
  - `ClientAliveCountMax 2`
  - `X11Forwarding no`
- Расположение основного файла: `/etc/ssh/sshd_config` (не изменялся).
- Расположение дополняющего файла: `/etc/ssh/sshd_config.d/99-hardening.conf`.

## 6. Правила межсетевого экрана (UFW)
- Политики по умолчанию: `deny (incoming)`, `allow (outgoing)`.
- Перечень правил:
  - `2222/tcp` (LIMIT) — SSH с защитой от брутфорса
  - `80/tcp` (ALLOW) — HTTP
  - `443/tcp` (ALLOW) — HTTPS
- Статус: `active`.

## 7. Снимки состояния
- **01-clean-install** — сразу после установки ОС и обновления (до изменений конфигураций).
- **02-keys-configured** — после настройки ключевой аутентификации и создания пользователя devops.
- **03-ssh-hardened** — после усиления защиты SSH (изменение порта, отключение паролей).
- **04-nginx-https** — после настройки Nginx и перевода ресурса на HTTPS.

## 8. Веб-сервер
- Установленный пакет: `nginx`
- Путь к конфигурации ресурса: `/etc/nginx/sites-available/devops-site`
- Каталог ресурса: `/var/www/devops-site` (владелец `devops:devops`, права `755` для каталогов, `644` для файлов)
- Путь к сертификату: `/etc/ssl/certs/devops.crt` (права `644`, владелец `root`)
- Путь к ключу: `/etc/ssl/private/devops.key` (права `600`, владелец `root`)
- Команда формирования сертификата: `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"`
- Срок действия: 365 дней