import os
from pathlib import Path

#########################
#                       #
#   Required settings   #
#                       #
#########################

# This is a list of valid fully-qualified domain names (FQDNs) for the NetBox server. NetBox will not permit write
# access to the server via any other hostnames. The first FQDN in the list will be treated as the preferred name.
ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', '*').split()

# PostgreSQL database configuration
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'netbox'),
        'USER': os.environ.get('DB_USER', 'netbox'),
        'PASSWORD': os.environ.get('DB_PASSWORD', 'netbox'),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
        'CONN_MAX_AGE': 300,
    }
}

# Redis database settings
REDIS = {
    'tasks': {
        'HOST': os.environ.get('REDIS_HOST', 'localhost'),
        'PORT': int(os.environ.get('REDIS_PORT', 6379)),
        'USERNAME': os.environ.get('REDIS_USERNAME', ''),
        'PASSWORD': os.environ.get('REDIS_PASSWORD', ''),
        'DATABASE': int(os.environ.get('REDIS_DATABASE', 0)),
        'SSL': os.environ.get('REDIS_SSL', 'False').lower() == 'true',
    },
    'caching': {
        'HOST': os.environ.get('REDIS_HOST', 'localhost'),
        'PORT': int(os.environ.get('REDIS_PORT', 6379)),
        'USERNAME': os.environ.get('REDIS_USERNAME', ''),
        'PASSWORD': os.environ.get('REDIS_PASSWORD', ''),
        'DATABASE': int(os.environ.get('REDIS_CACHE_DATABASE', 1)),
        'SSL': os.environ.get('REDIS_SSL', 'False').lower() == 'true',
    }
}

# This key is used for secure generation of random numbers and strings. It must never be exposed outside of this file.
# For optimal security, SECRET_KEY should be at least 50 characters in length and contain a mix of letters, numbers, and
# symbols. NetBox will not run without this defined.
SECRET_KEY = os.environ.get('SECRET_KEY', '')

#########################
#                       #
#   Optional settings   #
#                       #
#########################

# Specify one or more name and email address tuples representing NetBox administrators
ADMINS = [
    # ('Admin User', 'admin@example.com'),
]

# Permit the retrieval of API tokens after their creation
ALLOW_TOKEN_RETRIEVAL = False

# Base URL path if accessing NetBox within a directory
BASE_PATH = os.environ.get('BASE_PATH', '')

# API Cross-Origin Resource Sharing (CORS) settings
CORS_ORIGIN_ALLOW_ALL = False
CORS_ORIGIN_WHITELIST = [
    # 'https://hostname.example.com',
]
CORS_ORIGIN_REGEX_WHITELIST = [
    # r'^(https?://)?(\w+\.)?example\.com$',
]

# Set to True to enable server debugging. WARNING: Debugging introduces a substantial performance penalty and may reveal
# sensitive information about your installation. Only enable debugging while performing testing.
DEBUG = os.environ.get('DEBUG', 'False').lower() == 'true'

# Email settings
EMAIL = {
    'SERVER': os.environ.get('EMAIL_SERVER', 'localhost'),
    'PORT': int(os.environ.get('EMAIL_PORT', 25)),
    'USERNAME': os.environ.get('EMAIL_USERNAME', ''),
    'PASSWORD': os.environ.get('EMAIL_PASSWORD', ''),
    'USE_SSL': os.environ.get('EMAIL_USE_SSL', 'False').lower() == 'true',
    'USE_TLS': os.environ.get('EMAIL_USE_TLS', 'False').lower() == 'true',
    'TIMEOUT': int(os.environ.get('EMAIL_TIMEOUT', 10)),
    'FROM_EMAIL': os.environ.get('EMAIL_FROM', ''),
}

# Exempt certain models from the enforcement of view permissions
EXEMPT_VIEW_PERMISSIONS = [
    # 'dcim.site',
    # 'dcim.region',
    # 'ipam.prefix',
]

# IP addresses recognized as internal to the system
INTERNAL_IPS = ('127.0.0.1', '::1')

# Enable custom logging
LOGGING = {}

# Login settings
LOGIN_PERSISTENCE = False
LOGIN_REQUIRED = True
LOGIN_TIMEOUT = None

# The file path where uploaded media such as image attachments are stored
MEDIA_ROOT = '/opt/netbox/netbox/media'

# Expose Prometheus monitoring metrics at the HTTP endpoint '/metrics'
METRICS_ENABLED = os.environ.get('METRICS_ENABLED', 'False').lower() == 'true'

# Enable installed plugins. Add the name of each plugin to the list.
PLUGINS = []

# Plugins configuration settings
PLUGINS_CONFIG = {
    # 'my_plugin': {
    #     'foo': 'bar',
    #     'buzz': 'bazz'
    # }
}

# Remote authentication support
REMOTE_AUTH_ENABLED = False
REMOTE_AUTH_BACKEND = 'netbox.authentication.RemoteUserBackend'
REMOTE_AUTH_HEADER = 'HTTP_REMOTE_USER'
REMOTE_AUTH_AUTO_CREATE_USER = True
REMOTE_AUTH_DEFAULT_GROUPS = []
REMOTE_AUTH_DEFAULT_PERMISSIONS = {}

# Release check
RELEASE_CHECK_URL = None

# The file path where custom reports will be stored
REPORTS_ROOT = '/opt/netbox/netbox/reports'

# Maximum execution time for background tasks, in seconds
RQ_DEFAULT_TIMEOUT = 300

# The file path where custom scripts will be stored
SCRIPTS_ROOT = '/opt/netbox/netbox/scripts'

# Time zone
TIME_ZONE = os.environ.get('TIME_ZONE', 'UTC')

# Session settings
SESSION_COOKIE_NAME = 'sessionid'
SESSION_FILE_PATH = None
