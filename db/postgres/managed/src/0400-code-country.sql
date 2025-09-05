---------------------------------------------------------------------------------------------------
-- GET_COUNTRIES(VARCHAR(3)...):
--
-- Returns a JSONB ARRAY of countries and their regions (null or []).
-- Provide a list of 2 or 3 character country codes to return the selected countries.
-- 2 and 3 character codes can be mixed.
-- If no codes are provided, all countries are listed.
---------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION managed_code.GET_COUNTRIES(P_CODES VARIADIC VARCHAR(3)[] = NULL) RETURNS JSONB AS
$$
    WITH ADJ_PARAMS AS (
      SELECT -- NULL::VARCHAR(3)[] AS P_CODES
             -- ARRAY['CXR','AW']::VARCHAR(3)[] AS P_CODES
             P_CODES
    ),
    COUNTRY_JSON AS (
      SELECT JSONB_BUILD_OBJECT(
                'id'                ,RELID_TO_ID(c.relid)
               ,'version'           ,c.version
               ,'created'           ,c.created
               ,'modified'          ,c.modified
               ,'name'              ,c.name
               ,'code2'             ,c.code_2
               ,'code3'             ,c.code_3
               ,'hasRegions'        ,c.has_regions
               ,'hasMailingCode'    ,c.has_mailing_code
               ,'mailingCodeMatch'  ,c.mailing_code_match
               ,'mailingCodeFormat' ,c.mailing_code_format
               ,'regions'           ,(SELECT COALESCE(
                                               JSONB_AGG(
                                                 JSONB_BUILD_OBJECT(
                                                   'id'       , RELID_TO_ID(r.relid)
                                                  ,'version'  , r.version
                                                  ,'created'  , r.created
                                                  ,'modified' , r.modified
                                                  ,'name'     , r.name
                                                  ,'code'     , r.code
                                                 )
                                                 ORDER BY r.name
                                               ), '[]'::JSONB
                                             )
                                        FROM managed_tables.region r
                                       WHERE r.country_relid = c.relid
                                     )
             ) country_regions
            ,c.name
        FROM ADJ_PARAMS
            ,managed_tables.country c
       WHERE (COALESCE(ARRAY_LENGTH(P_CODES, 1), 0) = 0)
          OR (c.code_2 = ANY(P_CODES))
          OR (c.code_3 = ANY(P_CODES))
    )
--  SELECT * FROM COUNTRY_JSON; --
  SELECT JSONB_AGG(country_regions ORDER BY name) AS countries
    FROM COUNTRY_JSON;
$$ LANGUAGE SQL STABLE LEAKPROOF SECURITY DEFINER;
