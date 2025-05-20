-- app_objects owns all database objects except functions and procedures
SELECT 'CREATE ROLE managed_objects'
 WHERE NOT EXISTS (
       SELECT 1
         FROM pg_roles
        WHERE rolname = 'managed_objects'
 )
\gexec

-- Create tables schema
CREATE SCHEMA IF NOT EXISTS managed_tables AUTHORIZATION managed_objects;

-- Create views schema
CREATE SCHEMA IF NOT EXISTS managed_views AUTHORIZATION managed_objects;
