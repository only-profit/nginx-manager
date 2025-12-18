# Как добавить новый сервис к Nginx Proxy Manager

## Обзор

Этот документ описывает пошаговый процесс добавления нового сервиса (Docker-контейнера или внешнего сервера) к Nginx Proxy Manager.

---

## Вариант 1: Docker-контейнер

### Шаг 1: Подключение к сети

Добавьте в ваш `docker-compose.yml`:

```yaml
services:
  your-service:
    image: your-image:latest
    container_name: your-service-name  # Важно! Используйте это имя в NPM
    restart: unless-stopped
    # Не нужно пробрасывать порты наружу!
    # ports:
    #   - "3000:3000"  # НЕ НУЖНО
    environment:
      - YOUR_ENV_VAR=value
    networks:
      - proxy-network
      - internal  # для связи с БД и другими внутренними сервисами

  your-database:
    image: postgres:15
    container_name: your-db
    networks:
      - internal  # БД не нужно подключать к proxy-network

networks:
  proxy-network:
    external: true
  internal:
    driver: bridge
```

### Шаг 2: Запуск сервиса

```bash
docker compose up -d
```

### Шаг 3: Проверка подключения к сети

```bash
# Убедитесь, что контейнер в сети
docker network inspect proxy-network | grep your-service-name
```

### Шаг 4: Настройка в Nginx Proxy Manager

1. Откройте Admin Panel → **Hosts** → **Proxy Hosts**
2. Нажмите **Add Proxy Host**
3. Вкладка **Details**:
   - **Domain Names:** `your-domain.com`
   - **Scheme:** `http` (обычно)
   - **Forward Hostname/IP:** `your-service-name` (имя контейнера!)
   - **Forward Port:** внутренний порт приложения (например, `3000`, `8080`, `5000`)
   - ✅ **Block Common Exploits**
   - ✅ **Websockets Support** (если нужно)
4. Вкладка **SSL**:
   - **SSL Certificate:** Request a new SSL Certificate
   - ✅ **Force SSL**
   - ✅ **HTTP/2 Support**
   - Введите email
   - ✅ **I Agree to the Terms of Service**
5. Нажмите **Save**

---

## Вариант 2: Внешний сервер

Для сервисов, работающих не в Docker или на другом сервере.

### Шаг 1: Настройка в Nginx Proxy Manager

1. Откройте Admin Panel → **Hosts** → **Proxy Hosts**
2. Нажмите **Add Proxy Host**
3. Вкладка **Details**:
   - **Domain Names:** `your-domain.com`
   - **Scheme:** `http` или `https`
   - **Forward Hostname/IP:** IP-адрес сервера (например, `192.168.1.100`)
   - **Forward Port:** порт приложения
4. Настройте SSL аналогично варианту 1

---

## Примеры конфигураций

### ASP.NET Core приложение

```yaml
services:
  my-dotnet-app:
    image: my-registry/my-dotnet-app:latest
    container_name: my-dotnet-app
    restart: unless-stopped
    environment:
      - ASPNETCORE_URLS=http://+:5000
      - ASPNETCORE_ENVIRONMENT=Production
      - ConnectionStrings__DefaultConnection=Server=my-db;Database=myapp;...
    networks:
      - proxy-network
      - internal

  my-db:
    image: mcr.microsoft.com/mssql/server:2022-latest
    container_name: my-db
    environment:
      - ACCEPT_EULA=Y
      - MSSQL_SA_PASSWORD=YourStrong!Password
    volumes:
      - mssql-data:/var/opt/mssql
    networks:
      - internal

volumes:
  mssql-data:

networks:
  proxy-network:
    external: true
  internal:
    driver: bridge
```

**В NPM:**
- Forward Hostname: `my-dotnet-app`
- Forward Port: `5000`

### Node.js / Express

```yaml
services:
  node-api:
    image: node:20-alpine
    container_name: node-api
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ./:/app
    command: npm start
    environment:
      - NODE_ENV=production
      - PORT=3000
    networks:
      - proxy-network

networks:
  proxy-network:
    external: true
```

**В NPM:**
- Forward Hostname: `node-api`
- Forward Port: `3000`

### React / Vue / Angular (SPA)

```yaml
services:
  frontend:
    image: nginx:alpine
    container_name: my-frontend
    restart: unless-stopped
    volumes:
      - ./dist:/usr/share/nginx/html:ro
    networks:
      - proxy-network

networks:
  proxy-network:
    external: true
```

**В NPM:**
- Forward Hostname: `my-frontend`
- Forward Port: `80`

### Grafana

```yaml
services:
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SERVER_ROOT_URL=https://grafana.yourdomain.com
      - GF_SECURITY_ADMIN_PASSWORD=your-password
    volumes:
      - grafana-data:/var/lib/grafana
    networks:
      - proxy-network

volumes:
  grafana-data:

networks:
  proxy-network:
    external: true
```

**В NPM:**
- Forward Hostname: `grafana`
- Forward Port: `3000`

### Prometheus

```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--web.external-url=https://prometheus.yourdomain.com'
    networks:
      - proxy-network

volumes:
  prometheus-data:

networks:
  proxy-network:
    external: true
```

**В NPM:**
- Forward Hostname: `prometheus`
- Forward Port: `9090`
- Рекомендуется добавить Access List для ограничения доступа!

### PostgreSQL с pgAdmin

```yaml
services:
  postgres:
    image: postgres:15
    container_name: postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=admin
      - POSTGRES_PASSWORD=your-password
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - internal  # Не подключаем к proxy-network!

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin
    restart: unless-stopped
    environment:
      - PGADMIN_DEFAULT_EMAIL=admin@example.com
      - PGADMIN_DEFAULT_PASSWORD=admin
    networks:
      - proxy-network
      - internal

volumes:
  postgres-data:

networks:
  proxy-network:
    external: true
  internal:
    driver: bridge
```

**В NPM для pgAdmin:**
- Forward Hostname: `pgadmin`
- Forward Port: `80`
- Рекомендуется добавить Access List!

---

## Дополнительные настройки

### Custom Nginx Configuration

Для специфичных настроек (большие файлы, таймауты и т.д.):

1. В настройках Proxy Host → вкладка **Advanced**
2. Добавьте custom configuration:

```nginx
# Увеличить максимальный размер загружаемых файлов
client_max_body_size 100M;

# Увеличить таймауты для долгих запросов
proxy_read_timeout 300;
proxy_connect_timeout 300;
proxy_send_timeout 300;

# Дополнительные заголовки
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-Proto $scheme;
```

### Access Lists

Для ограничения доступа по IP:

1. **Access Lists** → **Add Access List**
2. Введите имя (например, "Admin Only")
3. Вкладка **Access** — добавьте разрешённые IP
4. Вкладка **Authorization** — опционально добавьте basic auth
5. Примените к нужным Proxy Hosts

---

## Troubleshooting

### Контейнер не видит NPM

```bash
# Проверить, что контейнер в сети
docker network inspect proxy-network

# Если нет — подключить
docker network connect proxy-network container_name
```

### 502 Bad Gateway

1. Контейнер работает? `docker ps`
2. Контейнер в сети? `docker network inspect proxy-network`
3. Правильное имя контейнера в настройках NPM?
4. Правильный порт?
5. Приложение слушает на 0.0.0.0, а не только на localhost?

### SSL не работает

1. Домен направлен на сервер? `dig +short domain.com`
2. Порт 80 открыт? `curl -I http://domain.com`
3. Не превышены ли rate limits Let's Encrypt?

