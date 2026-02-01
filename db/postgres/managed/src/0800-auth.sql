-- Grant app layer access only to run code, they cannot access the tables or views at all.
-- This prevents the app user from doing things like:
-- - turning off triggers
-- - truncating tables
-- - destroying tables, views, functions, procedures
-- This is accomplished by:
-- - Granting usage and execute on all functions and procedures to app layer user
-- - Ensuring all functions and procedures that access tables or views are created with SECURITY DEFINER
--
-- Extra security is providded by setting the search path such that public and pg_temp come last, in that order.
-- pg_temp is the temporary table schema, which normally comes first.
--
-- This prevents bad actors from creating objects in public and/or pg_temp that mask the real object you're trying to
-- access, attempting to inject unwanted behaviours into your code.

GRANT USAGE ON SCHEMA managed_code TO managed_app_exec;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA managed_code TO managed_app_exec;
