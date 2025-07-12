---------------------------------------------------------------------------------------------------
-- GET_CUSTOMER_PERSONS(TEXT...):
--
-- Returns a JSONB ARRAY of customers and their optional address
-- Provide a list of ids, and/or first names, and/or last names to return the selected people.
-- If no names are provided, all people are listed.
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
