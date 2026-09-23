-- Creates the audit_db database for the audit service (LSFLK/argus).
--
-- Unlike the old opendif-core audit-service, argus manages its own
-- audit_logs table schema via GORM AutoMigrate on every startup
-- (internal/pipeline/sinks/postgres.go's NewPostgresSink) - it has a very
-- different shape (hash-chaining columns, JSONB message/metadata, etc.),
-- so there is nothing to pre-create here beyond the database itself.

SELECT 'CREATE DATABASE audit_db'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'audit_db')\gexec
