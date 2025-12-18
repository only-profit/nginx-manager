# Миграция с nginx-certbot на Nginx Proxy Manager

Пошаговая инструкция по переходу с `staticfloat/nginx-certbot` на Nginx Proxy Manager.

## Преимущества перехода

| nginx-certbot | Nginx Proxy Manager |
|--------------|---------------------|
| Конфигурация через файлы | Веб-интерфейс |
| Ручное управление сертификатами | Автоматическое обновление |
| Требует знание nginx | Интуитивно понятный UI |
| Сложнее масштабировать | Легко добавлять новые хосты |

## Подготовка

### 1. Документирование текущей конфигурации

Перед миграцией сохраните информацию о текущих настройках:

```bash
# Сохранить конфигурации nginx
docker exec nginx-certbot cat /etc/nginx/nginx.conf > backup-nginx.conf
docker cp nginx-certbot:/etc/nginx/conf.d ./backup-conf.d

# Список активных сертификатов
docker exec nginx-certbot certbot certificates > backup-certificates.txt

# Или просто список доменов
docker exec nginx-certbot ls /etc/letsencrypt/live/
```

### 2. Резервное копирование сертификатов (опционально)

Если хотите перенести существующие сертификаты:

```bash
# Копирование сертификатов из контейнера
docker cp nginx-certbot:/etc/letsencrypt ./backup-letsencrypt

# Или через docker volumes
sudo cp -r /var/lib/docker/volumes/project_letsencrypt/_data ./backup-letsencrypt
```

> **Примечание:** NPM автоматически запросит новые сертификаты. Перенос старых обычно не требуется, если downtime в несколько минут приемлем.

### 3. Составить список проксируемых сервисов

Создайте таблицу для каждого домена:

| Домен | Upstream (IP:Port) | SSL | Примечания |
|-------|-------------------|-----|------------|
| profitpay.example.com | profitpay-api:5000 | Let's Encrypt | ASP.NET Core |
| quotefeed.example.com | quotefeed-api:5000 | Let's Encrypt | + WebSocket |
| grafana.example.com | grafana:3000 | Let's Encrypt | Ограничить доступ |

---

## Процесс миграции

### Шаг 1: Установка Server Proxy Manager

На том же или новом сервере:

```bash
git clone https://github.com/your-repo/server-proxy-manager.git
cd server-proxy-manager

# Пока НЕ запускаем, сначала остановим старый nginx
```

### Шаг 2: Подготовка сервисов

Добавьте `proxy-network` в docker-compose файлы ваших проектов:

```yaml
# В каждом docker-compose.yml
services:
  your-app:
    # ... существующие настройки ...
    networks:
      - proxy-network  # ДОБАВИТЬ
      - internal       # если есть БД

networks:
  proxy-network:      # ДОБАВИТЬ
    external: true
  internal:
    driver: bridge
```

**Пока не перезапускайте сервисы!**

### Шаг 3: Остановка старого nginx-certbot

```bash
cd /path/to/profitpay  # или другой проект со старым nginx

# Остановить nginx-certbot
docker compose stop nginx-certbot
# или
docker stop nginx-certbot

# Проверить, что порты освободились
sudo ss -tlnp | grep ':80\|:443'
```

### Шаг 4: Создание сети и запуск NPM

```bash
cd /path/to/server-proxy-manager

# Создать сеть
docker network create proxy-network

# Запустить NPM
./setup.sh
# или
docker compose up -d
```

### Шаг 5: Подключение сервисов к сети

```bash
# Подключить уже работающие контейнеры к сети
docker network connect proxy-network profitpay-api
docker network connect proxy-network quotefeed-api
docker network connect proxy-network grafana

# Проверить подключение
docker network inspect proxy-network
```

Или перезапустите сервисы с обновлённым docker-compose:

```bash
cd /path/to/profitpay
docker compose up -d
```

### Шаг 6: Настройка хостов в NPM

1. Откройте `http://YOUR_SERVER_IP:81`
2. Войдите: `admin@example.com` / `changeme`
3. **Смените пароль!**

Для каждого домена:

1. **Hosts** → **Proxy Hosts** → **Add Proxy Host**
2. Вкладка **Details**:
   - **Domain Names:** ваш домен
   - **Scheme:** http
   - **Forward Hostname/IP:** имя контейнера (например, `profitpay-api`)
   - **Forward Port:** порт приложения (например, `5000`)
   - ✅ **Block Common Exploits**
   - ✅ **Websockets Support** (если нужно)

3. Вкладка **SSL**:
   - **SSL Certificate:** Request a new SSL Certificate
   - ✅ **Force SSL**
   - ✅ **HTTP/2 Support**
   - Email для Let's Encrypt
   - ✅ Agree to Terms

4. **Save**

### Шаг 7: Проверка

```bash
# Проверить HTTP → HTTPS редирект
curl -I http://profitpay.example.com

# Проверить SSL
curl -I https://profitpay.example.com

# Проверить сертификат
openssl s_client -connect profitpay.example.com:443 -servername profitpay.example.com < /dev/null | openssl x509 -noout -dates
```

### Шаг 8: Очистка

После успешной проверки:

```bash
# Удалить старый контейнер nginx-certbot
docker rm nginx-certbot

# Удалить старые volumes (опционально, если уверены)
docker volume rm project_nginx_config project_letsencrypt

# Удалить nginx-certbot из docker-compose.yml старого проекта
```

---

## Типичные проблемы

### 502 Bad Gateway

**Причина:** Контейнер не в сети `proxy-network` или неправильное имя хоста.

```bash
# Проверить, что контейнер в сети
docker network inspect proxy-network | grep -A5 profitpay-api

# Подключить если нет
docker network connect proxy-network profitpay-api

# Проверить имя контейнера
docker ps --format '{{.Names}}'
```

### SSL сертификат не выдаётся

**Причина:** DNS не настроен или порт 80 недоступен.

```bash
# Проверить DNS
dig +short profitpay.example.com

# Проверить доступность порта 80
curl -I http://profitpay.example.com/.well-known/acme-challenge/test
```

### Downtime при миграции

Для минимизации downtime:

1. Настройте NPM заранее на другом порту
2. Остановите старый nginx
3. Измените порт NPM на 80/443
4. Перезапустите NPM

---

## Откат

Если что-то пошло не так:

```bash
# Остановить NPM
cd /path/to/server-proxy-manager
docker compose down

# Запустить старый nginx-certbot
cd /path/to/profitpay
docker compose up -d nginx-certbot
```

---

## Пример полной миграции ProfitPay

### До (с nginx-certbot)

```yaml
# /opt/profitpay/docker-compose.yml
services:
  profitpay-api:
    image: profitpay-api:latest
    container_name: profitpay-api
    ports:
      - "5000:5000"  # Убрать после миграции!

  nginx-certbot:
    image: staticfloat/nginx-certbot:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - letsencrypt:/etc/letsencrypt

volumes:
  letsencrypt:
```

### После (с NPM)

```yaml
# /opt/profitpay/docker-compose.yml
services:
  profitpay-api:
    image: profitpay-api:latest
    container_name: profitpay-api
    # Порты НЕ пробрасываем - доступ только через NPM
    networks:
      - proxy-network
      - internal

  profitpay-db:
    image: mcr.microsoft.com/mssql/server:2022-latest
    container_name: profitpay-db
    networks:
      - internal

networks:
  proxy-network:
    external: true
  internal:
    driver: bridge
```

И отдельно Server Proxy Manager в `/opt/server-proxy-manager/`.

