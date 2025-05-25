---------------------------------------------------------------------------------------------------
-- GET_COUNTRIES(VARCHAR(3)...):
--
-- Use the provided list of 2 or 3 character country codes to return the selected countries.
-- 2 and 3 character codes can be mixed.
-- If no codes are provided, all countries are listed
CREATE OR REPLACE FUNCTION managed_code.GET_COUNTRIES(P_CODES VARIADIC VARCHAR(3)[] = NULL) RETURNS JSONB AS
$$
  SELECT JSONB_AGG(country_regions)
    FROM managed_views.country_regions
   WHERE COALESCE(ARRAY_LENGTH(P_CODES, 1), 0) = 0
      OR (country_regions -> 'code2' #>> '{}' = ANY(P_CODES))
      OR (country_regions -> 'code3' #>> '{}' = ANY(P_CODES));
$$ LANGUAGE SQL SECURITY DEFINER;
