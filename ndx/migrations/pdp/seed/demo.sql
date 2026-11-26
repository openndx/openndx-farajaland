-- Demo data for the Policy Decision Point: the policies for the fields the
-- passport application reads, and the application's access grants to them.
--
-- run.sh loads this after the migrations on every `docker compose up`, with
--   psql -v access_grant_ttl="$DEMO_ACCESS_GRANT_TTL"
-- It only inserts rows that are missing, so it never overwrites a policy or
-- grant changed through the PDP API.

-- Stop before writing anything if DEMO_ACCESS_GRANT_TTL isn't a valid interval.
SELECT :'access_grant_ttl'::interval AS access_grant_ttl \gset

BEGIN;

CREATE TEMP TABLE demo_fields (
    schema_id VARCHAR(255) NOT NULL,
    field_name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    description TEXT
) ON COMMIT DROP;

INSERT INTO demo_fields (schema_id, field_name, display_name, description) VALUES
    ('abc-212', 'getPersonInfo.name', 'Person''s Name', NULL),
    ('abc-212', 'getPersonInfo.sex', 'Person''s Sex', NULL),
    ('abc-212', 'getPersonInfo.birthDate', 'Birth Date', 'Person''s Birth Date'),
    ('abc-212', 'getPersonInfo.birthPlace', 'Birth Place of Person', NULL),
    ('abc-212', 'getPersonInfo.district', 'Birth District of Person', NULL),
    ('abc-212', 'getPersonInfo.brNo', 'Birth Registration Number', NULL),
    ('drp-schema-v1', 'person.fullName', 'Full Name', 'Person''s Full Name'),
    ('drp-schema-v1', 'person.otherNames', 'Person''s Other Names', NULL),
    ('drp-schema-v1', 'person.permanentAddress', 'Residing Address', 'Person''s Residential Address'),
    ('drp-schema-v1', 'person.profession', 'Your Profession', NULL);

-- Each field needs an allow-list grant and the citizen's consent.
INSERT INTO field_policies
    (schema_id, field_name, display_name, description, source, requires_allowlist, requires_consent, owner)
SELECT schema_id, field_name, display_name, description, 'primary', true, true, 'citizen'
FROM demo_fields
ON CONFLICT (schema_id, field_name) DO NOTHING;

-- The passport application's grant to each field, expiring
-- DEMO_ACCESS_GRANT_TTL after it is first seeded. A field that already has a
-- passport-app grant, whether active, expired or revoked, is left alone, so
-- a revoked grant is never brought back.
INSERT INTO access_grants (schema_id, field_name, application_id, expires_at)
SELECT d.schema_id, d.field_name, 'passport-app', now() + :'access_grant_ttl'::interval
FROM demo_fields d
WHERE NOT EXISTS (
    SELECT 1
    FROM access_grants g
    WHERE g.schema_id = d.schema_id
      AND g.field_name = d.field_name
      AND g.application_id = 'passport-app'
      AND NOT g.consent_bypass
);

COMMIT;
