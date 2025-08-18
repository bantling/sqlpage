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
-- UPSERT_CUSTOMER_PERSONS
-- Transactional procedure to upsert one or more customer_person and optional address.
-- The P_CUST_ADDRS param may be a single JSONB object, or an array of JSONB objects.
-- For each customer, if the customer or address object fails to upsert, then nothing is upserted for that customer.
-- Each customer and address succeeds or fails independently.
--
-- P_CUST_ADDRS: A JSONB object for customer
--   Object has an optional key "address" containing an address object
--
-- P_RES :       A JSONB array of objects providing the results
--   Object has the following keys:
--     - customerId    (if customer has no errors)
--     - customerError (if customer has an error )
--     - addressId     (if customer has an address with no errors)
--     - addressError  (if customer has an address with an error )
--
-- If P_CUST_ADDRS is null or an empty array, then P_RES is an empty array.
-- If P_CUST_ADDRS is a single object, then P_RES is an array of one object.
--CREATE OR REPLACE PROCEDURE UPSERT_CUSTOMER_PERSONS(
--  P_CUST_ADDRS     JSONB
-- ,P_RES        OUT JSONB
--) AS
--$$
--DECLARE
--  V_CUST_ADDR     JSONB;
--
--  V_ADDR          JSONB;
--  V_ADDR_RELID    BIGINT;
--  V_COUNTRY_RELID BIGINT;
--  V_REGION_RELID  BIGINT;
--  V_ADDR_DESC     TEXT;
--
--  V_PERSON_RELID  BIGINT;
--
--  V_ERR_TEXT      TEXT;
--  V_UPSERT_RES    JSONB;
--BEGIN
--  -- Initialize the result to an empty array
--  P_RES := '[]';
--
--  FOR V_CUST_ADDR IN SELECT * FROM managed_code.GET_JSONB_OBJ_ARR('P_CUST_ADDRS', P_CUST_ADDRS) LOOP
--    -- Subtransaction for address and customer
--    -- Initialize result object
--    V_UPSERT_RES := '{}';
--
--    -- Get person relid, if it exists
--    V_PERSON_RELID := managed_code.ID_TO_RELID(V_CUST_ADDR #>> '{id}');
--
--    -- Grab optional address
--    V_ADDR := V_CUST_ADDR #> '{address}';
--
--    -- Get address relid, if it exists
--    V_ADDR_RELID := managed_code.ID_TO_RELID(V_ADDR #>> '{id}');
--
--    -- Get country relid
--    SELECT relid INTO V_COUNTRY_RELID
--      FROM managed_tables.country
--     WHERE V_ADDR #>> '{country}' IN (code_2, code_3);
--
--    -- Get region relid
--    SELECT relid INTO V_REGION_RELID
--      FROM managed_tables.region
--     WHERE country_relid = V_COUNTRY_RELID
--       AND V_ADDR #>> '{region}' = code;
--
--    BEGIN
--      -- Check if the customer has an address
--      IF V_ADDR IS NOT NULL THEN
--        INSERT INTO managed_tables.address(
--          relid
--         ,description
--         ,terms
--         ,extra
--         ,country_relid
--         ,region_relid
--         ,city
--         ,address
--         ,mailing_code
--        ) VALUES (
--          V_ADDR_RELID
--         ,V_ADDR #>> '{description}'
--         ,TO_TSVECTOR('english', V_ADDR #>> '{terms}')
--         ,V_ADDR #>  '{extra}'
--         ,V_COUNTRY_RELID
--         ,V_REGION_RELID
--         ,V_ADDR #>> '{city}'
--         ,V_ADDR #>> '{address}'
--         ,V_ADDR #>> '{mailingCode}'
--        )
--        ON CONFLICT (relid) DO
--        UPDATE SET
--          description   = V_ADDR #>> '{description}'
--         ,terms         = TO_TSVECTOR('english', V_ADDR #>> '{terms}')
--         ,extra         = V_ADDR #>  '{extra}'
--         ,country_relid = V_COUNTRY_RELID
--         ,region_relid  = V_REGION_RELID
--         ,city          = V_ADDR #>> '{city}'
--         ,address       = V_ADDR #>> '{address}'
--         ,mailing_code  = V_ADDR #>> '{mailingCode}';
--
--        IF V_ADDR_RELID IS NULL THEN
--          V_ADDR_RELID := LASTVAL();
--        END IF;
--
--        V_UPSERT_RES := V_UPSERT_RES || JSONB_BUILD_OBJECT('addressId', managed_code.RELID_TO_ID(V_ADDR_RELID));
--      END IF;
--
--      -- Person
--      INSERT INTO managed_tables.customer_person(
--        relid
--       ,description
--       ,terms
--       ,extra
--       ,address_relid
--       ,first_name
--       ,middle_name
--       ,last_name
--      ) VALUES (
--        V_PERSON_RELID
--       ,V_CUST_ADDR #>> '{description}'
--       ,TO_TSVECTOR('english', V_CUST_ADDR #>> '{terms}')
--       ,V_CUST_ADDR #>  '{extra}'
--       ,V_ADDR_RELID
--       ,V_CUST_ADDR #>> '{firstName}'
--       ,V_CUST_ADDR #>> '{middleName}'
--       ,V_CUST_ADDR #>> '{lastName}'
--      )
--      ON CONFLICT (relid) DO
--      UPDATE SET
--        description   = V_CUST_ADDR #>> '{description}'
--       ,terms         = TO_TSVECTOR('english', V_CUST_ADDR #>> '{terms}')
--       ,extra         = V_CUST_ADDR #>  '{extra}'
--       ,address_relid = V_ADDR_RELID
--       ,first_name    = V_CUST_ADDR #>> '{firstName}'
--       ,middle_name   = V_CUST_ADDR #>> '{middleName}'
--       ,last_name     = V_CUST_ADDR #>> '{lastName}';
--
--      IF V_PERSON_RELID IS NULL THEN
--        V_PERSON_RELID := LASTVAL();
--      END IF;
--
--      V_UPSERT_RES := V_UPSERT_RES || JSONB_BUILD_OBJECT('id', managed_code.RELID_TO_ID(V_ADDR_RELID));
--      RAISE DEBUG 'UPSERT_CUSTOMER_PERSON_PROC: COMMITTING PERSON: %', V_ADDR_RELID;
--      COMMIT;
--      RAISE DEBUG 'UPSERT_CUSTOMER_PERSON_PROC: COMMITTED  PERSON: %', V_ADDR_RELID;
--    EXCEPTION
--      WHEN OTHERS THEN
--        GET STACKED DIAGNOSTICS V_ERR_TEXT = MESSAGE_TEXT;
--        RAISE DEBUG 'UPSERT_CUSTOMER_PERSON_PROC: ROLLING BACK PERSON: %, %', V_PERSON_RELID, V_ERR_TEXT;
--        ROLLBACK;
--        RAISE DEBUG 'UPSERT_CUSTOMER_PERSON_PROC: ROLLED  BACK PERSON: %'   , V_PERSON_RELID;
--        V_UPSERT_RES := V_UPSERT_RES || JSONB_BUILD_OBJECT('error', V_ERR_TEXT);
--    END;
--
--    -- All subtransactions succeeded
--    P_RES := JSONB_INSERT(P_RES, '{-1}', V_UPSERT_RES);
--  END LOOP;
--END;
--$$ LANGUAGE plpgsql SECURITY DEFINER;

--CREATE OR REPLACE FUNCTION UPSERT_CUSTOMER_PERSONS(P_CUST_ADDRS JSONB) RETURNS JSONB AS
--$$
--BEGIN
  WITH
  DATA AS (
    SELECT JSONB_BUILD_ARRAY(
             JSONB_BUILD_OBJECT(
                 'description', 'Avery Sienna Jones'
                ,'firstName'  , 'Avery'
                ,'middleName' , 'Sienna'
                ,'lastName'   , 'Jones'
                ,'address'    , JSONB_BUILD_OBJECT(
                                  'country', 'CA'
                                 ,'region' , 'AB'
                                 ,'city'   , 'Calgary'
                                 ,'address', '123 Sesame St'
                                )
             )
            ,JSONB_BUILD_OBJECT(
                 'description', 'Bob John James'
                ,'firstName'  , 'Bob'
                ,'middleName' , 'John'
                ,'lastName'   , 'James'
             )
           ) AS P_CUST_ADDRS
  ),
--  SELECT * FROM DATA;
--  WITH
  CUST_ADDR_REC AS (
    SELECT managed_code.ID_TO_RELID(CUST_ADDR #>> '{id}')     AS ID
          ,CUST_ADDR #>> '{version}'                          AS VERSION
          ,CUST_ADDR #>> '{description}'                      AS DESCRIPTION
          ,TO_TSVECTOR('english', CUST_ADDR #>> '{terms}')    AS TERMS
          ,CUST_ADDR #>  '{extra}'                            AS EXTRA
          ,managed_code.FROM_8601(CUST_ADDR #>> '{created}')  AS CREATED
          ,managed_code.FROM_8601(CUST_ADDR #>> '{modified}') AS MODIFIED
          ,CUST_ADDR #>> '{firstName}'                        AS FIRST_NAME
          ,CUST_ADDR #>> '{middleName}'                       AS MIDDLE_NAME
          ,CUST_ADDR #>> '{lastName}'                         AS LAST_NAME
          ,CUST_ADDR #>  '{address}'                          AS ADDRESS
          ,ROW_NUMBER() OVER() - 1                              AS ROW_IDX
      FROM (
        SELECT JSONB_ARRAY_ELEMENTS(P_CUST_ADDRS) AS CUST_ADDR
          FROM DATA
      ) t
  )
--  SELECT * FROM CUST_ADDR_REC;
 ,VALIDATE_CUSTOMER AS (
    -- First name is non-null non-empty
    -- need a separate raise function for dying if null or empty string
    SELECT managed_code.IIF(LENGTH(COALESCE(first_name, '')) = 0, managed_code.RAISE_MSG(format('%s: customer firstName is required', ROW_IDX))::TEXT, first_name)
      FROM CUST_ADDR_REC
  )
 SELECT * FROM VALIDATE_CUSTOMER;
--
--  -- Must have a country
-- ,COUNTRY_RELIDS AS (
--    SELECT *
--          ,c.relid AS country_relid
--          ,c.has_regions
--          ,c.has_mailing_code
--      FROM CUST_ADDRS
--          ,managed_tables.country c
--     WHERE D_CUST_ADDR #>> '{country}' IN (c.code_2, c.code_3)
-- )
--  -- May have a region
-- ,REGION_RELIDS AS (
--    SELECT *
--          ,r.relid AS region_relid
--      FROM COUNTRY_RELIDS c
--      LEFT
--      JOIN managed_tables.region r
--        ON r.country_relid = c.country_relid
--       AND D_CUST_ADDR #>> '{region}' = r.code
-- )
-- ,ADDR AS (
--    SELECT ADDR #>> '{description}'                   AS description
--          ,TO_TSVECTOR('english', ADDR #>> '{terms}') AS terms
--          ,ADDR #>  '{extra'}                         AS extra
--          ,ADDR #>> '{extra'}                         AS extra
--      FROM D_CUST_ADDR #> '{address}' ADDR
-- )
-- SELECT NULL;
--END;
--$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
DO $$
DECLARE
  P_RES JSONB;
BEGIN
  CALL UPSERT_CUSTOMER_PERSONS(
    JSONB_BUILD_ARRAY(
      JSONB_BUILD_OBJECT (
        'description', 'Avery Sienna Jones'
       ,'firstName' , 'Avery'
       ,'middleName', 'Sienna'
       ,'lastName'  , 'Jones'
       ,'address', JSONB_BUILD_OBJECT(
           'description' , '123 Sesame St, Calgary, AB, Canada T1T 1T1'
          ,'country'     , 'CA'
          ,'region'      , 'AB'
          ,'city'        , 'Calgary'
          ,'address'     , '123 Sesame St'
          ,'mailingCode', 'T1T 1T1'
        )
      ),
      JSONB_BUILD_OBJECT (
        'description', 'James Jack Marley'
       ,'firstName' , 'James'
       ,'middleName', 'Jack'
       ,'lastName'  , 'Marley'
      )
    )
   ,P_RES
  );

  RAISE DEBUG 'P_RES = %', P_RES;
END;
$$ LANGUAGE plpgsql;

select * from managed_tables.address;
select * from managed_tables.customer_person;
*/
