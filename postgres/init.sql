-- Create database for Keycloak
CREATE DATABASE keycloak;

-- Create user
CREATE USER keycloak WITH PASSWORD 'keycloak123';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;

-- Connect to keycloak database and grant schema privileges
\c keycloak
GRANT ALL ON SCHEMA public TO keycloak;
