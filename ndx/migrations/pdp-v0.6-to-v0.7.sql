-- Migrate the Farajaland PDP tables from OpenNDX v0.6.x to v0.7.0.
--
-- This follows step 1.2 of the upstream guide
-- (https://github.com/openndx/openndx-core/blob/main/docs/MIGRATION-v0.6-to-v0.7.md),
-- adapted to the constraint and index names created by ndx/opendif_schema.sql.
-- The upstream script expects policy_metadata_pkey, which this database does
-- not have.
--
-- Every field keeps its decision: v0.6 fields all needed an allow-list entry,
-- and restricted fields without isOwner also needed the owner's consent. Each
-- allow-list entry becomes an active grant with the same expiry.
--
-- Run it once, with the PDP stopped. It runs in one transaction and stops at
-- the first statement if the database has already been migrated:
--
--   docker compose exec -T postgres sh -c \
--     'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1' \
--     < migrations/pdp-v0.6-to-v0.7.sql

BEGIN;

-- 1. Rename the table and its keys to the v0.7.0 names. The unique constraint
--    becomes idx_field_policies_schema_field, which upstream's schema.sql
--    creates as a unique index. The non-unique index duplicated it.
ALTER TABLE policy_metadata RENAME TO field_policies;
ALTER TABLE field_policies RENAME CONSTRAINT policy_metadata_pk TO field_policies_pkey;
ALTER TABLE field_policies
    RENAME CONSTRAINT policy_metadata_schema_field_unique TO idx_field_policies_schema_field;
DROP INDEX idx_policy_metadata_schema_field;

-- The PDP no longer shares a database with the legacy Portal Backend tables.
ALTER TABLE field_policies DROP CONSTRAINT IF EXISTS policy_metadata_provider_schemas_schema_id_fk;
ALTER TABLE field_policies DROP CONSTRAINT IF EXISTS policy_metadata_owner_requirements;

-- 2. Replace access_control_type and is_owner with the two flags
ALTER TABLE field_policies
    ADD COLUMN requires_allowlist BOOLEAN,
    ADD COLUMN requires_consent BOOLEAN;
UPDATE field_policies SET
    requires_allowlist = true,
    requires_consent = (access_control_type = 'restricted' AND NOT is_owner);
ALTER TABLE field_policies
    ALTER COLUMN requires_allowlist SET NOT NULL,
    ALTER COLUMN requires_consent SET NOT NULL;

-- 3. Create the access grants table, as in the v0.7.0 cmd/pdp/schema.sql
CREATE TABLE access_grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schema_id VARCHAR(255) NOT NULL,
    field_name TEXT NOT NULL,
    application_id TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'active'
        CONSTRAINT access_grants_status_check CHECK (status IN ('active', 'revoked')),
    consent_bypass BOOLEAN NOT NULL DEFAULT false,
    legal_basis TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT access_grants_field_fkey FOREIGN KEY (schema_id, field_name)
        REFERENCES field_policies(schema_id, field_name) ON DELETE CASCADE,
    CONSTRAINT access_grants_bypass_check CHECK (NOT consent_bypass OR legal_basis IS NOT NULL)
);
CREATE UNIQUE INDEX idx_access_grants_active
    ON access_grants(schema_id, field_name, application_id, consent_bypass)
    WHERE status = 'active';
CREATE INDEX idx_access_grants_application
    ON access_grants(application_id, schema_id);

-- 4. Copy every allow-list entry into an active grant
INSERT INTO access_grants (schema_id, field_name, application_id, expires_at, created_at, updated_at)
SELECT fp.schema_id,
       fp.field_name,
       entry.key,
       (entry.value->>'expires_at')::timestamptz,
       COALESCE((entry.value->>'updated_at')::timestamptz, CURRENT_TIMESTAMP),
       COALESCE((entry.value->>'updated_at')::timestamptz, CURRENT_TIMESTAMP)
FROM field_policies fp, jsonb_each(fp.allow_list) AS entry(key, value);

-- 5. Drop the v0.6 columns and type
ALTER TABLE field_policies
    DROP COLUMN allow_list,
    DROP COLUMN access_control_type,
    DROP COLUMN is_owner;
DROP TYPE access_control_type_enum;

COMMIT;
