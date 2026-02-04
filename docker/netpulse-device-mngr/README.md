# Netpulse device manager docker

This directory contains a custom Dockerfile and Docker Compose configuration to build and run from the source code.
```
netpulse/core/netpulse-device-manager/netpulse-device-mngr
```

## Directory Structure

```
├── Dockerfile              # Custom NetBox image build file
├── docker-compose.yml      # Orchestration for NetBox, PostgreSQL, and Redis
├── entrypoint.sh          # Container initialization script
├── configuration.py       # NetBox configuration (uses environment variables)
├── .env                   # Environment variables configuration
└── README.md              # This file
```

## Features

- Custom NetBox build from source code
- PostgreSQL 15 database
- Redis for caching and task queuing
- Automated database migrations
- Automatic superuser creation
- Background worker for async tasks
- Housekeeping service for maintenance
- Persistent volumes for data storage

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- At least 2GB of free RAM
- At least 5GB of free disk space

## Quick Start

### 1. Configure Environment Variables

Edit the `.env` file and update the following important settings:

```bash
# Change this to a secure random 50+ character string
SECRET_KEY=your_secure_random_secret_key_here

# Update database password
DB_PASSWORD=your_secure_database_password

# Update superuser credentials
SUPERUSER_NAME=admin
SUPERUSER_EMAIL=admin@example.com
SUPERUSER_PASSWORD=your_secure_admin_password

# Set your timezone
TIME_ZONE=America/New_York
```

**IMPORTANT**: Generate a secure SECRET_KEY using:
```bash
python3 -c 'from secrets import token_urlsafe; print(token_urlsafe(50))'
```

### 2. Build and Start Services

From the `netbox-docker` directory:

```bash
# Build the NetBox image
docker-compose build

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f netbox
```

### 3. Access NetBox

Once the services are running:

- NetBox Web UI: http://localhost:8000
- Default credentials: admin / admin (or as configured in .env)

## Service Components

### Main Services

1. **netbox** - Main NetBox web application
   - Port: 8000
   - Handles web UI and API requests

2. **netbox-worker** - Background task worker
   - Processes async tasks (webhooks, reports, etc.)

3. **netbox-housekeeping** - Maintenance tasks
   - Runs daily cleanup operations

### Supporting Services

4. **postgres** - PostgreSQL database
   - Stores all NetBox data
   - Persistent volume: `postgres-data`

5. **redis** - Redis cache and queue
   - Handles caching and task queuing
   - Persistent volume: `redis-data`

## Customization

### Adding Custom Plugins

1. Edit the `Dockerfile` to install plugin packages:
```dockerfile
RUN pip install netbox-plugin-example
```

2. Update `configuration.py` to enable the plugin:
```python
PLUGINS = ['netbox_plugin_example']

PLUGINS_CONFIG = {
    'netbox_plugin_example': {
        'setting1': 'value1',
    }
}
```

3. Rebuild and restart:
```bash
docker-compose build
docker-compose up -d
```

### Modifying NetBox Source Code

1. Make changes to the source code in `../netbox/`
2. Rebuild the image:
```bash
docker-compose build
```
3. Restart services:
```bash
docker-compose up -d
```

## Common Commands

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f netbox
docker-compose logs -f postgres
```

### Run Management Commands
```bash
# Access NetBox shell
docker-compose exec netbox python /opt/netbox/netbox/manage.py shell

# Create a superuser manually
docker-compose exec netbox python /opt/netbox/netbox/manage.py createsuperuser

# Run migrations
docker-compose exec netbox python /opt/netbox/netbox/manage.py migrate
```

### Restart Services
```bash
# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart netbox
```

### Stop and Remove Services
```bash
# Stop services
docker-compose stop

# Stop and remove containers
docker-compose down

# Stop and remove containers + volumes (WARNING: deletes all data)
docker-compose down -v
```

## Data Persistence

The following volumes are created for persistent data:

- `postgres-data` - Database files
- `redis-data` - Redis persistence
- `netbox-media` - User-uploaded files
- `netbox-reports` - Custom reports
- `netbox-scripts` - Custom scripts

### Backup

To backup your data:

```bash
# Backup database
docker-compose exec postgres pg_dump -U netbox netbox > netbox_backup.sql

# Backup media files
docker run --rm -v netbox-docker_netbox-media:/data -v $(pwd):/backup alpine tar czf /backup/media-backup.tar.gz -C /data .
```

### Restore

To restore from backup:

```bash
# Restore database
docker-compose exec -T postgres psql -U netbox netbox < netbox_backup.sql

# Restore media files
docker run --rm -v netbox-docker_netbox-media:/data -v $(pwd):/backup alpine tar xzf /backup/media-backup.tar.gz -C /data
```

## Troubleshooting

### Container fails to start

Check logs:
```bash
docker-compose logs netbox
```

### Database connection errors

Ensure PostgreSQL is running:
```bash
docker-compose ps postgres
docker-compose logs postgres
```

### Permission errors

The NetBox container runs as the `netbox` user. Ensure volumes have correct permissions.

### Reset everything

```bash
# Stop and remove all containers and volumes
docker-compose down -v

# Remove built images
docker-compose rm

# Start fresh
docker-compose up -d
```

## Production Considerations

For production deployments:

1. **Security**:
   - Change all default passwords
   - Use a strong SECRET_KEY
   - Set `ALLOWED_HOSTS` to specific domains
   - Disable DEBUG mode (already disabled by default)

2. **Performance**:
   - Increase worker count in docker-compose.yml
   - Add a reverse proxy (nginx/traefik) with SSL
   - Configure database connection pooling

3. **Monitoring**:
   - Enable `METRICS_ENABLED=true` for Prometheus metrics
   - Set up log aggregation
   - Configure health checks

4. **Backup**:
   - Implement automated backup solution
   - Test restore procedures regularly

## Environment Variables Reference

### Database
- `DB_NAME` - Database name (default: netbox)
- `DB_USER` - Database user (default: netbox)
- `DB_PASSWORD` - Database password
- `DB_HOST` - Database host (default: postgres)
- `DB_PORT` - Database port (default: 5432)

### Redis
- `REDIS_HOST` - Redis host (default: redis)
- `REDIS_PORT` - Redis port (default: 6379)
- `REDIS_PASSWORD` - Redis password
- `REDIS_DATABASE` - Redis database for tasks (default: 0)
- `REDIS_CACHE_DATABASE` - Redis database for cache (default: 1)

### NetBox
- `SECRET_KEY` - Django secret key (required, 50+ characters)
- `ALLOWED_HOSTS` - Space-separated list of allowed hosts
- `DEBUG` - Enable debug mode (default: false)
- `TIME_ZONE` - Timezone (default: UTC)

### Superuser (optional, for auto-creation)
- `SUPERUSER_NAME` - Admin username
- `SUPERUSER_EMAIL` - Admin email
- `SUPERUSER_PASSWORD` - Admin password

## Support

For NetBox documentation and support:
- Official Docs: https://docs.netbox.dev/
- GitHub: https://github.com/netbox-community/netbox
- Community: https://github.com/netbox-community/netbox/discussions
