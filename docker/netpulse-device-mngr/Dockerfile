FROM python:3.11-slim as base

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libpq-dev \
    libxml2-dev \
    libxslt1-dev \
    libffi-dev \
    libssl-dev \
    zlib1g-dev \
    libjpeg62-turbo-dev \
    postgresql-client \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create netbox user and directories
RUN useradd -m -d /opt/netbox -s /bin/bash netbox && \
    mkdir -p /opt/netbox/netbox/static /opt/netbox/netbox/media /opt/netbox/netbox/reports /opt/netbox/netbox/scripts

WORKDIR /opt/netbox

# Copy NetBox source code from the submodule
COPY core/netpulse-device-manager/netpulse-device-mngr /opt/netbox/

# Install Python dependencies
RUN pip install --upgrade pip && \
    pip install -r requirements.txt && \
    pip install gunicorn whitenoise

# Change ownership
RUN chown -R netbox:netbox /opt/netbox

# Switch to netbox user
USER netbox

# Collect static files (will be done at runtime via entrypoint)
# EXPOSE port
EXPOSE 8000

# Create entrypoint script
COPY --chown=netbox:netbox docker/netpulse-device-mngr/entrypoint.sh /opt/netbox/entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/opt/netbox/entrypoint.sh"]
CMD ["python", "/opt/netbox/netbox/manage.py", "runserver", "0.0.0.0:8000"]
