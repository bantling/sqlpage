-- Revoke public access to create objects on public schema
REVOKE CREATE ON SCHEMA public FROM public;

-- Create tables schema
CREATE SCHEMA IF NOT EXISTS managed_tables;

-- Create views schema
CREATE SCHEMA IF NOT EXISTS managed_views;

-- managed_app_exec can execute all functions and procedures, and can login with a password for external access
SELECT $$
CREATE ROLE managed_app_exec PASSWORD '${PG_MANAGED_EXEC_PASS}' LOGIN
$$
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
-- If any objects exist outside this schema that depend on objects in this schema, they will also be dropped.
-- See https://www.postgresql.org/docs/current/sql-dropschema.html.
DROP SCHEMA IF EXISTS managed_code CASCADE;
CREATE SCHEMA IF NOT EXISTS managed_code;
