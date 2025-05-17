-- app_exec owns all functions and procedures, and has a password for external access
/*
DO $$
BEGIN
  RAISE NOTICE 'PG_EXEC_PASS = ${PG_EXEC_PASS}';
END;
$$ LANGUAGE plpgsql;
*/

SELECT 'CREATE ROLE managed_app_exec PASSWORD ''${PG_EXEC_PASS}'''
 WHERE NOT EXISTS (
       SELECT 1
         FROM pg_roles
        WHERE rolname = 'managed_app_exec'
 )
\gexec

-- Drop and recreate code schema, to guarantee that:
-- - It only has latest code
-- - No old overloads exist that are no longer needed
--
-- There MUST NOT exist any objects outside this schema that depend on objects in this schema.
-- Any such objects will also be dropped.
-- See https://www.postgresql.org/docs/current/sql-dropschema.html.
DROP SCHEMA IF EXISTS managed_code CASCADE;
CREATE SCHEMA IF NOT EXISTS managed_code AUTHORIZATION managed_app_exec;
