---------------------------------------------------------------------------------------------------
-- GET_CUSTOMER_PERSONS(P_IDS, P_FIRST_NAMES, P_LAST_NAMES, P_ORDER, P_PAGE_SIZE, P_PAGE_NUM):
--
-- Returns a JSONB ARRAY of personal customers and their optional address.
-- Provide a list of ids, and/or first names, and/or last names to return the selected people.
-- If no ids or names are provided, all people are listed.
-- P_ORDER is an array containing the following values
--   id
--   first name
--   last name
-- The order of the above strings in the P_ORDER array is significant:
-- eg, '{first_name, last_name}' sorts by firstname first, then last name
-- If no ordering is provided, results have no guaranteed order
-- A page size and number can be used for pagination, where the page number is 1-based.
---------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION managed_code.GET_CUSTOMER_PERSONS(
   P_IDS         TEXT[] = NULL
  ,P_FIRST_NAMES TEXT[] = NULL
  ,P_LAST_NAMES  TEXT[] = NULL
  ,P_ORDER       TEXT[] = NULL
  ,P_PAGE_SIZE   INT    = NULL
  ,P_PAGE_NUM    INT    = NULL
) RETURNS JSONB AS
$$
--  WITH PARAMS AS (                    --
--    SELECT NULL::TEXT[] P_IDS         --
--          ,NULL::TEXT[] P_FIRST_NAMES --
--          ,NULL::TEXT[] P_LAST_NAMES  --
--          ,NULL::TEXT[] P_ORDER       --
--          ,10::INT P_PAGE_SIZE        --
--          ,1::INT P_PAGE_NUM          --
--  ),                                  --
  WITH VALIDATE AS (
    SELECT managed_code.TEST(
             'P_PAGE_SIZE and P_PAGE_NUM must be both NULL or both non-NULL and > zero'
            ,(
                   ((P_PAGE_SIZE IS NULL) = (P_PAGE_NUM IS NULL))
               AND ((P_PAGE_SIZE IS NULL) OR ((P_PAGE_SIZE > 0) AND (P_PAGE_NUM > 0)))
             )
           ) AS VALID
  )
 ,ADJ_PARAMS AS (
    SELECT COALESCE(ARRAY_LENGTH(P_IDS        , 1), 0   ) FILT_IDS_LEN
          ,COALESCE(ARRAY_LENGTH(P_FIRST_NAMES, 1), 0   ) FILT_FNS_LEN
          ,COALESCE(ARRAY_LENGTH(P_LAST_NAMES , 1), 0   ) FILT_LNS_LEN
          ,P_ORDER                                        ORD_BY
          ,COALESCE(P_PAGE_SIZE                   , 0   ) PAGE_SIZE
          ,COALESCE(P_PAGE_NUM                    , 0   ) PAGE_NUM
--          ,*      --
--      FROM PARAMS --
  )
--  SELECT * FROM ADJ_PARAMS; --
 ,FILTERED AS (
    SELECT *
          ,managed_code.RELID_TO_ID(cp.relid) id
          ,TO_JSON(cp) cp_json
      FROM ADJ_PARAMS p
          ,managed_tables.customer_person cp
     WHERE (
                 ((FILT_IDS_LEN = 0) OR (managed_code.RELID_TO_ID(cp.relid) = ANY(P_IDS        )))
             AND ((FILT_FNS_LEN = 0) OR (cp.first_name                      = ANY(P_FIRST_NAMES)))
             AND ((FILT_LNS_LEN = 0) OR (cp.last_name                       = ANY(P_LAST_NAMES )))
           )
  )
--  SELECT * FROM FILTERED; --
 ,ORDERED AS (
    SELECT *
          ,ROW_NUMBER() OVER(
             ORDER
                BY CASE ORD_BY[1]
                     WHEN 'id'         THEN f.relid::TEXT
                     WHEN 'first_name' THEN f.first_name
                     WHEN 'last_name'  THEN f.last_name
                     ELSE NULL
                     END
            ,       CASE ORD_BY[2]
                      WHEN 'id'         THEN f.relid::TEXT
                      WHEN 'first_name' THEN f.first_name
                      WHEN 'last_name'  THEN f.last_name
                      ELSE NULL
                     END
            ,       CASE ORD_BY[3]
                      WHEN 'id'         THEN f.relid::TEXT
                      WHEN 'first_name' THEN f.first_name
                      WHEN 'last_name'  THEN f.last_name
                      ELSE NULL
                     END
           ) - 1 AS ROW_NUM
      FROM FILTERED f
  )
--  SELECT * FROM ORDERED; --
  ,CPA_JSON AS (
     SELECT *
           ,JSONB_STRIP_NULLS(JSONB_BUILD_OBJECT(
              'id'          ,managed_code.RELID_TO_ID(o.relid)
             ,'version'     ,o.version
             ,'created'     ,o.created
             ,'changed'     ,o.modified
             ,'first_name'  ,o.first_name
             ,'middle_name' ,o.middle_name
             ,'last_name'   ,o.last_name
             ,'address'    ,(SELECT JSONB_BUILD_OBJECT(
                                      'id'           ,managed_code.RELID_TO_ID(a.relid)
                                     ,'version'      ,a.version
                                     ,'created'      ,a.created
                                     ,'changed'      ,a.modified
                                     ,'city'         ,a.city
                                     ,'address'      ,a.address
                                     ,'country'      ,c.code_2
                                     ,'region'       ,r.code
                                     ,'mailing_code' ,a.mailing_code
                                    ) address
                               FROM managed_tables.address a
                               JOIN managed_tables.country c
                                 ON c.relid = a.country_relid
                               LEFT
                               JOIN managed_tables.region r
                                 ON r.relid = a.region_relid
                              WHERE a.relid = o.address_relid
                            )
            )) customer_person_address
       FROM ORDERED o
      WHERE (PAGE_SIZE = 0)
         OR (PAGE_NUM = 0)
         OR (ROW_NUM BETWEEN PAGE_SIZE * (PAGE_NUM - 1) AND (PAGE_SIZE * PAGE_NUM) - 1)
  )
--  SELECT * FROM CPA_JSON; --
  SELECT JSONB_AGG(customer_person_address ORDER BY ROW_NUM)
    FROM CPA_JSON;
$$ LANGUAGE SQL STABLE LEAKPROOF SECURITY DEFINER;




---------------------------------------------------------------------------------------------------
-- GET_CUSTOMER_BUSINESSES(P_IDS, P_NAMES, P_ORDER, P_PAGE_SIZE, P_PAGE_NUM):
--
-- Returns a JSONB ARRAY of business customers and their address(es).
-- Provide a list of ids, and/or names to return the selected businesses.
-- If no ids or names are provided, all businesses are listed.
-- P_ORDER is an array containing the following values
--   id
--   name
-- The order of the above strings in the P_ORDER array is significant:
-- eg, '{name, id}' sorts by name first, then id
-- If no ordering is provided, results have no guaranteed order
-- A page size and number can be used for pagination, where the page number is 1-based.
---------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION managed_code.GET_CUSTOMER_BUSINESSES(
   P_IDS       TEXT[] = NULL
  ,P_NAMES     TEXT[] = NULL
  ,P_ORDER     TEXT[] = NULL
  ,P_PAGE_SIZE INT    = NULL
  ,P_PAGE_NUM  INT    = NULL
) RETURNS JSONB AS
$$
--  WITH PARAMS AS (              --
--    SELECT NULL::TEXT[] P_IDS   --
--          ,NULL::TEXT[] P_NAMES --
--          ,NULL::TEXT[] P_ORDER --
--          ,10::INT P_PAGE_SIZE  --
--          ,1::INT P_PAGE_NUM    --
--  ),                                  --
  WITH --
  ADJ_PARAMS AS (
    SELECT COALESCE(ARRAY_LENGTH(P_IDS  , 1), 0   ) FILT_IDS_LEN
          ,COALESCE(ARRAY_LENGTH(P_NAMES, 1), 0   ) FILT_NMS_LEN
          ,P_ORDER                                  ORD_BY
          ,COALESCE(P_PAGE_SIZE             , 0   ) PAGE_SIZE
          ,COALESCE(P_PAGE_NUM              , 0   ) PAGE_NUM
--          ,*      --
--      FROM PARAMS --
  )
--  SELECT * FROM ADJ_PARAMS; --
 ,FILTERED AS (
    SELECT *
          ,managed_code.RELID_TO_ID(cb.relid) id
      FROM ADJ_PARAMS p
          ,managed_tables.customer_business cb
     WHERE (
                 ((FILT_IDS_LEN = 0) OR (managed_code.RELID_TO_ID(cb.relid) = ANY(P_IDS  )))
             AND ((FILT_NMS_LEN = 0) OR (cb.name                            = ANY(P_NAMES)))
           )
  )
--  SELECT * FROM FILTERED; --
 ,ORDERED AS (
    SELECT *
          ,ROW_NUMBER() OVER(
             ORDER
                BY CASE ORD_BY[1]
                     WHEN 'id'   THEN f.relid::TEXT
                     WHEN 'name' THEN f.name
                     ELSE NULL
                    END
                  ,CASE ORD_BY[2]
                     WHEN 'id'   THEN f.relid::TEXT
                     WHEN 'name' THEN f.name
                     ELSE NULL
                    END
           ) - 1 AS ROW_NUM
      FROM FILTERED f
  )
--  SELECT * FROM ORDERED; --
  ,CBA_JSON AS (
     SELECT *
           ,JSONB_STRIP_NULLS(JSONB_BUILD_OBJECT(
              'id'        ,managed_code.RELID_TO_ID(o.relid)
             ,'version'   ,o.version
             ,'created'   ,o.created
             ,'changed'   ,o.modified
             ,'name'      ,o.name
             ,'addresses' ,(  WITH ADDRESSES AS (
                                     SELECT JSONB_BUILD_OBJECT(
                                              'id'           ,managed_code.RELID_TO_ID(a.relid)
                                             ,'version'      ,a.version
                                             ,'created'      ,a.created
                                             ,'changed'      ,a.modified
                                             ,'city'         ,a.city
                                             ,'address'      ,a.address
                                             ,'country'      ,c.code_2
                                             ,'region'       ,r.code
                                             ,'mailing_code' ,a.mailing_code
                                            ) address_json
                                           ,c.name AS country_name
                                       FROM managed_tables.address a
                                       JOIN managed_tables.customer_business_address_jt cbaj
                                         ON cbaj.address_relid = a.relid
                                        AND cbaj.business_relid = o.relid
                                       JOIN managed_tables.country c
                                         ON c.relid = a.country_relid
                                       LEFT
                                       JOIN managed_tables.region r
                                        ON r.relid = a.region_relid
                                   )
                             SELECT JSONB_AGG(address_json ORDER BY country_name)
                               FROM ADDRESSES
                           )
            )) customer_business_addresses
       FROM ORDERED o
      WHERE (PAGE_SIZE = 0)
         OR (PAGE_NUM  = 0)
         OR (ROW_NUM BETWEEN PAGE_SIZE * (PAGE_NUM - 1) AND (PAGE_SIZE * PAGE_NUM) - 1)
  )
--  SELECT * FROM CBA_JSON; --
  SELECT JSONB_AGG(customer_business_addresses ORDER BY ROW_NUM)
    FROM CBA_JSON;
$$ LANGUAGE SQL STABLE LEAKPROOF SECURITY DEFINER;




---------------------------------------------------------------------------------------------------
-- SET_CUSTOMER_PERSONS(JSONB):
--
-- Upserts one or more persons from a JSONB OBJECT or ARRAY of personal customers and their optional
-- addresses, returning a JSONB ARRAY of
-- {
--    "id"           : "<customer id>"
--   ,"addressId"    : "<address id>"
--   ,"error"        : "<error message>" (only if customer failed)
--   ,"addressError" : "<error message>" (only if address  failed)
-- }
--
-- If a customer address fails to upsert, the customer is not upserted either
--
-- id and addressId are each returned in two cases:
--  - The upsert was successful
--  - It was provided
--
-- The caller can line up each result with the original data provided via the array index
---------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION managed_code.SET_CUSTOMER_PERSONS(P_CUSTOMER_PERSONS JSONB) RETURNS JSONB AS
$$
DECLARE
  -- customer_person fields
  V_PERSON        JSONB;
  V_PERSON_ID     VARCHAR(11);
  V_PERSON_RELID  BIGINT;

  -- address fields
  V_ADDRESS       JSONB;
  V_ADDRESS_ID    VARCHAR(11);
  V_ADDRESS_RELID BIGINT;
  V_COUNTRY_RELID BIGINT;
  V_REGION_RELID  BIGINT;

  -- Error
  V_ERR_TEXT      TEXT;
  V_RES           JSONB;
  V_RESULTS       JSONB := '[]';
BEGIN
  <<MAIN_LOOP>>
  FOR V_PERSON IN SELECT managed_code.GET_JSONB_OBJ_ARR(P_CUSTOMER_PERSONS) LOOP
    -- Get person relid, if provided
    V_PERSON_ID    := VPERSON #>> '{id}';
    V_PERSON_RELID := managed_code.ID_TO_RELID(V_PERSON_ID);

    -- Address transaction
    BEGIN
      -- Since a person can only have one address, the customer_person has an address_relid column
      -- Insert address first
      -- If no id is provided, we insert, else we update
      V_ADDRESS       := V_PERSON  #>  '{address}';
      V_ADDRESS_ID    := V_ADDRESS #>> '{id}';
      V_ADDRESS_RELID := manaaged_code.ID_TO_RELID(V_ADDRESS_ID);

      -- Get country and region ids, we refer to them multiple times
      SELECT relid INTO V_COUNTRY_RELID
        FROM managed_tables.country
       WHERE V_ADDRESS #>> '{country}' IN (code_2, code_3);

      SELECT relid INTO V_REGION_RELID
        FROM managed_tables.region
       WHERE country_relid            = V_COUNTRY_RELID
         AND V_ADDRESS #>> '{region}' = code;

      -- Start with empty error object
      V_ERROR := '{}';

      -- If we know the address id, add it to the error object
      IF V_ADDRESS_ID IS NOT NULL THEN
        V_ERROR := VERROR || format('{"address_Id": "%"}', V_ADDRESS_ID);
      END IF;

      -- Upsert address, grabbing the relid in case it is an insert
      -- Catch any exception for this upsert so we can add the error
      INSERT INTO managed_tables.address(
        relid
       ,description
       ,terms
       ,extra
       ,country_relid
       ,region_relid
       ,city
       ,address
       ,mailing_code
      ) VALUES (
        V_ADDRESS_RELID
       ,V_ADDRESS #>> '{description}'
       ,V_ADDRESS #>> '{terms}'
       ,V_ADDRESS #>> '{extra}'
       ,V_COUNTRY_RELID
       ,V_REGION_RELID
       ,V_ADDRESS #>> '{city}'
       ,V_ADDRESS #>> '{address}'
       ,V_ADDRESS #>> '{mailing_code}'
      )
      ON CONFLICT(relid)
      DO UPDATE SET description   = V_ADDRESS #>> '{description}'
                   ,terms         = V_ADDRESS #>> '{terms}'
                   ,extra         = V_ADDRESS #>> '{extra}'
                   ,country_relid = V_COUNTRY_RELID
                   ,region_relid  = V_REGION_RELID
                   ,city          = V_ADDRESS #>> '{city}'
                   ,address       = V_ADDRESS #>> '{address}'
                   ,mailing_code  = V_ADDRESS #>> '{mailing_code}'
      RETURNING relid INTO V_ADDRESS_RELID;

      -- Add id to error
      V_ADDRESS_ID := managed_code.RELID_TO_ID(V_ADDRESS_RELID);
      V_ERROR := V_ERROR || format('{"addressId": "%"}', V_ADDRESS_ID);
    EXCEPTION
      WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS V_ERR = MESSAGE_TEXT;
        V_ERRORS := V_ERRORS || format('{"addressError": "%"}', V_ERR);

        -- No point in trying to upsert the person if the address failed
        CONTINUE MAIN_LOOP;
    END;

    -- Person Customer transaction
    BEGIN
      -- Get person relid
      V_PERSON_ID    := VPERSON #>> '{id}';
      V_PERSON_RELID := managed_code.ID_TO_RELID(V_PERSON_ID);

      -- Next, upsert the person
      INSERT INTO managed_tables.customer_person(
        relid
       ,description
       ,terms
       ,extra
       ,address_relid
       ,first_name
       ,middle_name
       ,last_name
      ) VALUES (
        V_PERSON_RELID
       ,V_PERSON #>> '{description}'
       ,V_PERSON #>> '{terms}'
       ,V_PERSON #>> '{extra}'
       ,V_ADDRESS_RELID
       ,V_PERSON #>> '{first_name}'
       ,V_PERSON #>> '{middle_name}'
       ,V_PERSON #>> '{last_name}'
      )
      ON CONFLICT(relid)
      DO UPDATE SET description   = V_PERSON #>> '{description}'
                   ,terms         = V_PERSON #>> '{terms}'
                   ,extra         = V_PERSON #>> '{extra}'
                   ,address_relid = V_ADDRESS_RELID
                   ,first_name    = V_PERSON #>> '{first_name}'
                   ,middle_name   = V_PERSON #>> '{middle_name}'
                   ,last_name     = V_PERSON #>> '{last_name}'
      RETURNING relid INTO V_PERSON_RELID;

      -- Add id to error
      V_PERSON_ID := managed_code.RELID_TO_ID(V_PERSON_RELID);
      V_ERROR := V_ERROR || format('{"id": "%"}', V_PERSON_ID);
    EXCEPTION
      WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS V_ERR = MESSAGE_TEXT;
        V_ERRORS := V_ERRORS || format('{"error": "%"}', V_ERR);
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
