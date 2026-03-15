# Server Proxy Manager

🚀 **Универсальное решение для управления несколькими сайтами на одном сервере через единую точку входа.**

Основан на [Nginx Proxy Manager](https://nginxproxymanager.com/) — удобный веб-интерфейс для управления reverse proxy с автоматическим SSL через Let's Encrypt.

## Возможности

- ✅ Управление множеством сайтов через веб-интерфейс
- ✅ Автоматические SSL-сертификаты Let's Encrypt
- ✅ Поддержка WebSocket
- ✅ Access Lists для ограничения доступа
- ✅ Редиректы и кастомные конфигурации nginx
- ✅ Интеграция с любыми Docker-контейнерами
- ✅ Поддержка wildcard сертификатов

---

## 🚀 Быстрый старт

```bash
# 1. Клонировать репозиторий
git clone https://github.com/only-profit/nginx-manager.git
cd nginx-manager

# 2. Сделать скрипт исполняемым
chmod +x setup.sh

# 3. Запустить установку
./setup.sh
```

После запуска:
- **Admin Panel:** `http://YOUR_SERVER_IP:81`
- **Email:** `admin@example.com`
- **Password:** `changeme`

> ⚠️ **ВАЖНО:** Смените пароль сразу после первого входа!

---

## 📖 Содержание

- [Как добавить новый сайт](#как-добавить-новый-сайт)
- [Подключение Docker-контейнера](#подключение-docker-контейнера)
- [Настройка SSL](#настройка-ssl)
- [Миграция с существующего nginx](#миграция-с-существующего-nginx)
- [Безопасность](#безопасность)
- [Полезные команды](#полезные-команды)
- [Troubleshooting](#troubleshooting)

---

## Как добавить новый сайт

### Вариант 1: Проксирование на внешний сервер/IP

1. Откройте Admin Panel (`http://server-ip:81`)
2. Перейдите в **Hosts** → **Proxy Hosts**
3. Нажмите **Add Proxy Host**
4. Заполните:
   - **Domain Names:** `example.com` (ваш домен)
   - **Scheme:** `http` или `https`
   - **Forward Hostname/IP:** IP адрес целевого сервера
   - **Forward Port:** порт приложения (например, 3000)
5. Нажмите **Save**

### Вариант 2: Проксирование на Docker-контейнер

1. Подключите контейнер к сети `proxy-network` (см. ниже)
2. В **Forward Hostname/IP** укажите **имя контейнера**
3. В **Forward Port** укажите внутренний порт контейнера

> 💡 При проксировании на Docker-контейнер используйте имя контейнера вместо IP!

---

## Подключение Docker-контейнера

Чтобы контейнер был доступен через Nginx Proxy Manager, его нужно подключить к общей сети `proxy-network`.

### Для нового проекта

Добавьте в `docker-compose.yml`:

```yaml
services:
  myapp:
    image: myapp:latest
    container_name: myapp
    networks:
      - proxy-network
      - internal  # опционально, для изоляции

networks:
  proxy-network:
    external: true
  internal:
    driver: bridge
```

### Для существующего контейнера

```bash
# Подключить работающий контейнер к сети
docker network connect proxy-network container_name

# Проверить подключение
docker network inspect proxy-network
```

### Пример с ASP.NET Core приложением

```yaml
services:
  myapp-api:
    image: your-registry/myapp-api:latest
    container_name: myapp-api
    environment:
      - ASPNETCORE_URLS=http://+:5000
    networks:
      - proxy-network
      - internal

  myapp-db:
    image: mcr.microsoft.com/mssql/server:2022-latest
    container_name: myapp-db
    networks:
      - internal  # БД не нужна в proxy-network

networks:
  proxy-network:
    external: true
  internal:
    driver: bridge
```

В Nginx Proxy Manager:
- **Domain:** `myapp.example.com`
- **Forward Hostname:** `myapp-api`
- **Forward Port:** `5000`

---

## Настройка SSL

### Автоматический SSL через Let's Encrypt

1. Убедитесь, что домен направлен на ваш сервер (A-запись в DNS)
2. В настройках Proxy Host перейдите на вкладку **SSL**
3. Выберите **Request a new SSL Certificate**
4. Включите:
   - ✅ Force SSL
   - ✅ HTTP/2 Support
   - ✅ HSTS Enabled (опционально)
5. Введите email для уведомлений Let's Encrypt
6. Примите Terms of Service
7. Нажмите **Save**

### Wildcard сертификаты

Для wildcard (`*.yourdomain.com`) нужен DNS Challenge:

1. Перейдите в **SSL Certificates** → **Add SSL Certificate**
2. Выберите **Let's Encrypt**
3. Введите `*.yourdomain.com`
4. Включите **Use a DNS Challenge**
5. Выберите вашего DNS провайдера и введите API ключ
6. Нажмите **Save**

### Использование существующих сертификатов

1. Перейдите в **SSL Certificates** → **Add SSL Certificate**
2. Выберите **Custom**
3. Загрузите файлы сертификата и ключа
4. Нажмите **Save**

---

## Миграция с существующего nginx

### С nginx-certbot (staticfloat/nginx-certbot)

#### Шаг 1: Резервное копирование сертификатов (опционально)

```bash
# Скопировать сертификаты из старого контейнера
docker cp nginx-certbot:/etc/letsencrypt ./backup-letsencrypt

# Или найти их в volumes
ls /var/lib/docker/volumes/*letsencrypt*
```

#### Шаг 2: Документирование текущих настроек

Сохраните список всех доменов и их конфигурацию:

```bash
# Просмотреть конфиги nginx
docker exec nginx-certbot cat /etc/nginx/conf.d/default.conf

# Список сертификатов
docker exec nginx-certbot ls /etc/letsencrypt/live/
```

#### Шаг 3: Остановка старого nginx

```bash
# Остановить старый контейнер
cd /path/to/old/project
docker compose down

# Или если это systemd сервис
sudo systemctl stop nginx
```

#### Шаг 4: Запуск Nginx Proxy Manager

```bash
cd /path/to/server-proxy-manager
./setup.sh
```

#### Шаг 5: Настройка сайтов

1. Откройте Admin Panel
2. Для каждого сайта создайте Proxy Host
3. Включите SSL — Let's Encrypt выпустит новые сертификаты автоматически

#### Шаг 6: Обновление docker-compose других проектов

Добавьте в каждый проект подключение к `proxy-network`:

```yaml
networks:
  proxy-network:
    external: true
```

И подключите нужные сервисы:

```yaml
services:
  myservice:
    networks:
      - proxy-network
```

### С Caddy

Caddy можно заменить аналогично:

1. Остановите Caddy
2. Запустите Nginx Proxy Manager
3. Создайте Proxy Hosts для каждого сайта из Caddyfile
4. SSL будет настроен автоматически

---

## Безопасность

### Защита Admin Panel

По умолчанию порт 81 (Admin UI) привязан к `127.0.0.1` и недоступен извне. Для доступа используйте SSH туннель:

```bash
# Linux/macOS
ssh -L 8181:localhost:81 user@your-server

# PowerShell (Windows)
ssh -L 8181:localhost:81 user@your-server
```

Затем откройте `http://localhost:8181` в браузере.

> 💡 Если нужен публичный доступ к админке, измените в `.env`:
> `ADMIN_PORT=81` (без привязки к 127.0.0.1) и защитите порт через firewall или Access List.

#### Дополнительно: Access List в самом NPM

1. Создайте Access List в Admin Panel
2. Добавьте разрешённые IP адреса
3. Примените к Proxy Host для админки

### Смена пароля по умолчанию

1. Войдите с `admin@example.com` / `changeme`
2. Нажмите на иконку пользователя → **Edit Details**
3. Смените email и пароль

### Регулярное обновление

```bash
cd /path/to/server-proxy-manager
docker compose pull
docker compose up -d
```

---

## Полезные команды

```bash
# Просмотр логов
docker logs -f nginx-proxy-manager

# Просмотр логов доступа к конкретному хосту
docker exec nginx-proxy-manager cat /data/logs/proxy-host-1_access.log

# Перезапуск
docker compose restart

# Остановка
docker compose down

# Обновление до последней версии
docker compose pull
docker compose up -d

# Проверка статуса
docker compose ps

# Подключение к контейнеру
docker exec -it nginx-proxy-manager /bin/bash

# Просмотр сети
docker network inspect proxy-network

# Список всех контейнеров в сети
docker network inspect proxy-network --format '{{range .Containers}}{{.Name}} {{end}}'
```

---

## Troubleshooting

### Порты 80/443 заняты

```bash
# Найти процесс на порту
sudo lsof -i :80
sudo lsof -i :443

# Или
sudo ss -tlnp | grep ':80\|:443'

# Остановить nginx
sudo systemctl stop nginx
sudo systemctl disable nginx

# Или остановить другой контейнер
docker stop container_name
```

### 502 Bad Gateway

1. Проверьте, что целевой контейнер работает:
   ```bash
   docker ps | grep container_name
   ```

2. Проверьте, что контейнер в сети `proxy-network`:
   ```bash
   docker network inspect proxy-network
   ```

3. Проверьте правильность имени хоста и порта в настройках Proxy Host

4. Проверьте логи целевого контейнера:
   ```bash
   docker logs container_name
   ```

### Let's Encrypt не выдаёт сертификат

1. Проверьте, что домен направлен на сервер:
   ```bash
   dig +short yourdomain.com
   ```

2. Проверьте, что порт 80 доступен извне:
   ```bash
   curl -I http://yourdomain.com
   ```

3. Проверьте логи:
   ```bash
   docker logs nginx-proxy-manager | grep -i acme
   ```

4. Убедитесь, что не превышены rate limits Let's Encrypt

### Контейнер не видит другой контейнер

1. Убедитесь, что оба в `proxy-network`:
   ```bash
   docker network inspect proxy-network
   ```

2. Проверьте имя контейнера (используйте `container_name`, а не service name):
   ```bash
   docker ps --format '{{.Names}}'
   ```

3. Проверьте доступность изнутри контейнера:
   ```bash
   docker exec nginx-proxy-manager ping container_name
   ```

### Сброс пароля администратора

Если забыли пароль:

```bash
# Подключиться к SQLite базе
docker exec -it nginx-proxy-manager sqlite3 /data/database.sqlite

# Сбросить пароль на changeme
UPDATE user SET email='admin@example.com' WHERE id=1;
-- Выйти: .quit

# Перезапустить контейнер
docker compose restart
```

### Проблемы с правами на volumes

```bash
# Проверить права
ls -la data/ letsencrypt/

# Исправить если нужно
sudo chown -R $USER:$USER data/ letsencrypt/
```

---

## Структура проекта

```
server-proxy-manager/
├── docker-compose.yml      # Основная конфигурация
├── .env.example            # Шаблон переменных окружения
├── .env                    # Ваши настройки (создаётся автоматически)
├── setup.sh                # Скрипт установки
├── README.md               # Эта документация
├── data/                   # Данные NPM (создаётся автоматически)
├── letsencrypt/            # SSL сертификаты (создаётся автоматически)
└── examples/
    ├── add-service.md      # Детальная инструкция добавления сервиса
    ├── migration-from-nginx-certbot.md  # Миграция с nginx-certbot
    ├── sample-service/
    │   └── docker-compose.yml  # Пример для подключаемого сервиса
    └── monitoring/
        ├── docker-compose.yml     # Стек мониторинга (Grafana + Prometheus)
        └── prometheus/
            └── prometheus.yml     # Конфигурация Prometheus
```

---

## Полезные ссылки

- [Nginx Proxy Manager Documentation](https://nginxproxymanager.com/guide/)
- [Docker Documentation](https://docs.docker.com/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Docker Networking](https://docs.docker.com/network/)

---

## Лицензия

MIT License

