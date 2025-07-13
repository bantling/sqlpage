---------------------------------------------------------------------------------------------------
-- GET_CUSTOMER_PERSONS(P_RELIDS, P_FIRST_NAME, P_LAST_NAMES):
--
-- Returns a JSONB ARRAY of personal customers and their optional address
-- Provide a list of ids, and/or first names, and/or last names to return the selected people.
-- If no ids or names are provided, all people are listed.
---------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION managed_code.GET_CUSTOMER_PERSONS(P_RELIDS TEXT[] = NULL, P_FIRST_NAMES TEXT[] = NULL, P_LAST_NAMES TEXT[] = NULL) RETURNS JSONB AS
$$
  SELECT JSONB_AGG(customer_person_address) AS customers
    FROM managed_views.customer_person_address
   WHERE (
               ((COALESCE(ARRAY_LENGTH(P_RELIDS     , 1), 0) = 0) OR (customer_person_address #>> '{id}'         = ANY(P_RELIDS)))
           AND ((COALESCE(ARRAY_LENGTH(P_FIRST_NAMES, 1), 0) = 0) OR (customer_person_address #>> '{first_name}' = ANY(P_FIRST_NAMES)))
           AND ((COALESCE(ARRAY_LENGTH(P_LAST_NAMES , 1), 0) = 0) OR (customer_person_address #>> '{last_name}'  = ANY(P_LAST_NAMES)))
         );
$$ LANGUAGE SQL STABLE LEAKPROOF SECURITY DEFINER;




---------------------------------------------------------------------------------------------------
-- GET_CUSTOMER_BUSINESSES(P_RELIDS, P_NAMES):
--
-- Returns a JSONB ARRAY of business customers and their address(es)
-- Provide a list of ids, and/or names to return the selected businesses.
-- If no ids or names are provided, all businesses are listed.
---------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION managed_code.GET_CUSTOMER_BUSINESSES(P_RELIDS TEXT[] = NULL, P_NAMES TEXT[] = NULL) RETURNS JSONB AS
$$
  SELECT JSONB_AGG(customer_business_address) AS customers
    FROM managed_views.customer_business_address
   WHERE (
               ((COALESCE(ARRAY_LENGTH(P_RELIDS, 1), 0) = 0) OR (customer_business_address #>> '{id}'   = ANY(P_RELIDS)))
           AND ((COALESCE(ARRAY_LENGTH(P_NAMES , 1), 0) = 0) OR (customer_business_address #>> '{name}' = ANY(P_NAMES)))
         );
$$ LANGUAGE SQL STABLE LEAKPROOF SECURITY DEFINER;




---------------------------------------------------------------------------------------------------
-- SET_CUSTOMER_PERSONS(JSONB):
--
-- Upserts one or more persons from a JSONB OBJECT or ARRAY of personal customers and their optional
-- addresses, returning a JSONB ARRAY of
-- {
--    "id"           : "<customer id>"
--   ,"addressId"    : "<address id>"
--   ,"customerError": "<error message>"
--   ,"addressError" : "<error message>"
-- }
-- where the id and addressId are returned whether a person was created or updated
---------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION managed_code.SET_CUSTOMER_PERSONS(P_CUSTOMER_PERSONS JSONB) RETURNS JSONB AS
$$
  WITH VALIDATE AS (
    SELECT managed_code.IS_JSONB_OBJ_ARR('P_CUSTOMER_PERSONS',  P_CUSTOMER_PERSONS)
  )
  SELECT NULL::JSONB;
$$ LANGUAGE sql;
