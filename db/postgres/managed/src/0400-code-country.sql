---------------------------------------------------------------------------------------------------
-- GET_COUNTRIES(VARCHAR(3)...):
--
-- Returns a JSONB ARRAY of countries and their regions (null or []).
-- Provide a list of 2 or 3 character country codes to return the selected countries.
-- 2 and 3 character codes can be mixed.
-- If no codes are provided, all countries are listed.
CREATE OR REPLACE FUNCTION managed_code.GET_COUNTRIES(P_CODES VARIADIC VARCHAR(3)[] = NULL) RETURNS JSONB AS
$$
  SELECT JSONB_AGG(country_regions) AS countries
    FROM managed_views.country_regions
        ,(SELECT ARRAY_AGG(val) vals
            FROM (SELECT UNNEST(P_CODES) val) t
           WHERE val IS NOT NULL
         ) u
   WHERE COALESCE(ARRAY_LENGTH(vals, 1), 0) = 0
      OR (country_regions -> 'code2' #>> '{}' = ANY(vals))
      OR (country_regions -> 'code3' #>> '{}' = ANY(vals));
$$ LANGUAGE SQL STABLE LEAKPROOF SECURITY DEFINER;
