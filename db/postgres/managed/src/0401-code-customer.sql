---------------------------------------------------------------------------------------------------
-- GET_CUSTOMER_PERSONS(P_IDS, P_FIRST_NAMES, P_LAST_NAMES, P_ORDER_ID, P_ORDER_FIRST, P_ORDER_LAST, P_PAGE_SIZE, P_PAGE_NUM):
--
-- Returns a JSONB ARRAY of personal customers and their optional address.
-- Provide a list of ids, and/or first names, and/or last names to return the selected people.
-- If no ids or names are provided, all people are listed.
-- P_ORDER_BY is an array containing the following values
--   id
--   first name
--   last name
-- The order of the above strings in the P_ORDER_BY array is significant:
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
  WITH --
  ADJ_PARAMS AS (
    SELECT COALESCE(ARRAY_LENGTH(P_IDS        , 1), 0   ) FILT_IDS_LEN
          ,COALESCE(ARRAY_LENGTH(P_FIRST_NAMES, 1), 0   ) FILT_FNS_LEN
          ,COALESCE(ARRAY_LENGTH(P_LAST_NAMES , 1), 0   ) FILT_LNS_LEN
          ,COALESCE(P_ORDER                       , NULL) ORD_BY
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
             ORDER BY CASE ORD_BY[1]
                        WHEN 'id'         THEN f.relid::TEXT
                        WHEN 'first_name' THEN f.first_name
                        WHEN 'last_name'  THEN f.last_name
                        ELSE NULL
                       END
            ,         CASE ORD_BY[2]
                        WHEN 'id'         THEN f.relid::TEXT
                        WHEN 'first_name' THEN f.first_name
                        WHEN 'last_name'  THEN f.last_name
                        ELSE NULL
                       END
            ,         CASE ORD_BY[3]
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
     SELECT JSONB_STRIP_NULLS(JSONB_BUILD_OBJECT(
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
      WHERE ((PAGE_SIZE = 0) OR (PAGE_NUM = 0)) OR (ROW_NUM BETWEEN PAGE_SIZE * (PAGE_NUM - 1) AND (PAGE_SIZE * PAGE_NUM) - 1)
      ORDER
         BY ROW_NUM
  )
--  SELECT * FROM CPA_JSON; --
  SELECT JSONB_AGG(customer_person_address)
    FROM CPA_JSON;
$$ LANGUAGE SQL STABLE LEAKPROOF SECURITY DEFINER;




---------------------------------------------------------------------------------------------------
-- GET_CUSTOMER_BUSINESSES(P_IDS, P_NAMES, P_ORDER_ID, P_ORDER_NAME, P_PAGE_SIZE, P_PAGE_NUM):
--
-- Returns a JSONB ARRAY of business customers and their address(es).
-- Provide a list of ids, and/or names to return the selected businesses.
-- If no ids or names are provided, all businesses are listed.
-- P_ORDER_BY is an array containing the following values
--   id
--   name
-- The order of the above strings in the P_ORDER_BY array is significant:
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
          ,COALESCE(P_ORDER                 , NULL) ORD_BY
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
             ORDER BY CASE ORD_BY[1]
                        WHEN 'id'   THEN f.relid::TEXT
                        WHEN 'name' THEN f.name
                        ELSE NULL
                       END
            ,         CASE ORD_BY[2]
                        WHEN 'id'   THEN f.relid::TEXT
                        WHEN 'name' THEN f.name
                        ELSE NULL
                       END
           ) - 1 AS ROW_NUM
      FROM FILTERED f
  )
--  SELECT * FROM ORDERED; --
  ,CBA_JSON AS (
     SELECT JSONB_STRIP_NULLS(JSONB_BUILD_OBJECT(
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
      WHERE ((PAGE_SIZE = 0) OR (PAGE_NUM = 0)) OR (ROW_NUM BETWEEN PAGE_SIZE * (PAGE_NUM - 1) AND (PAGE_SIZE * PAGE_NUM) - 1)
      ORDER
         BY ROW_NUM
  )
--  SELECT * FROM CBA_JSON; --
  SELECT JSONB_AGG(customer_business_addresses)
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
