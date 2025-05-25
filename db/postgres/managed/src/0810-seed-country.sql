-- Seed data for country and region managed_tables
-- See https://www.iban.com/country-codes for 2 and 3 char country codes
-- See https://en.wikipedia.org/wiki/ISO_3166-2 for countries and region codes
--
-- If a country changes name, two steps are required:
-- 1. Write an update query before the hard-coded data
-- 2. Update the hard-coded data with the new data

-- Hard-coded country data
WITH COUNTRY_DATA AS (
  SELECT s.*
        ,ROW_NUMBER() OVER() AS ord
    FROM (VALUES
           ('Aruba'           , 'AW'  , 'ABW' , false      , false           , NULL                                             , NULL               )
          ,('Canada'          , 'CA'  , 'CAN' , true       ,  true           , '^([A-Za-z][0-9][A-Za-z]) ?([0-9][A-Za-z][0-9])$','\1 \2'             )
          ,('Christmas Island', 'CX'  , 'CXR' , false      ,  true           , '^6798$'                                         ,'6798'              )
          ,('United States'   , 'US'  , 'USA' , true       ,  true           , '^([0-9]{5}(-[0-9]{4})?)$'                       ,'\1'                )
         ) AS s(
            name              , code_2, code_3, has_regions, has_mailing_code, mailing_code_match                               , mailing_code_format
         )
)
INSERT INTO managed_tables.country(
   description
  ,terms
  ,name
  ,code_2
  ,code_3
  ,has_regions
  ,has_mailing_code
  ,mailing_code_match
  ,mailing_code_format
  ,ord
)
SELECT c.name                                                               AS description
      ,TO_TSVECTOR('english', c.name || ' ' || c.code_2 || ' ' || c.code_3) AS terms
      ,c.*
  FROM COUNTRY_DATA c
    ON CONFLICT(name) DO
UPDATE
   SET description                 = excluded.name
      ,terms                       = TO_TSVECTOR('english', excluded.name || ' ' || excluded.code_2 || ' ' || excluded.code_3)
      ,code_2                      = excluded.code_2
      ,code_3                      = excluded.code_3
      ,has_regions                 = excluded.has_regions
      ,has_mailing_code            = excluded.has_mailing_code
      ,mailing_code_match          = excluded.mailing_code_match
      ,ord                         = excluded.ord
 WHERE country.code_2             != excluded.code_2
    OR country.code_3             != excluded.code_3
    OR country.has_regions        != excluded.has_regions
    OR country.has_mailing_code   != excluded.has_mailing_code
    OR country.mailing_code_match != excluded.mailing_code_match
    OR country.ord                != excluded.ord;

--
-- If a region changes name, two steps are required:
-- 1. Write an update query before the hard-coded data
-- 2. Update the hard-coded data with the new details
--
-- Hard-coded region data
WITH CA_REGION_DATA AS (
  SELECT (SELECT relid FROM managed_tables.country WHERE code_2 = 'CA') AS country_relid
        ,s.*
    FROM (VALUES
           ('Alberta'                  , 'AB')
          ,('British Columbia'         , 'BC')
          ,('Manitoba'                 , 'MB')
          ,('New Brunswick'            , 'NB')
          ,('Newfoundland and Labrador', 'NL')
          ,('Northwest Territories'    , 'NT')
          ,('Nova Scotia'              , 'NS')
          ,('Nunavut'                  , 'NU')
          ,('Ontario'                  , 'ON')
          ,('Prince Edward Island'     , 'PE')
          ,('Quebec'                   , 'QC')
          ,('Saskatchewan'             , 'SK')
          ,('Yukon'                    , 'YT')
        ) AS s(
            name                       , code
        )
)
, US_REGION_DATA AS (
  SELECT (SELECT relid FROM managed_tables.country WHERE code_2 = 'US') country_relid
        ,s.*
    FROM (VALUES
           ('Alabama'                  , 'AL')
          ,('Alaska'                   , 'AK')
          ,('Arizona'                  , 'AZ')
          ,('Arkansaa'                 , 'AR')
          ,('California'               , 'CA')
          ,('Colorado'                 , 'CO')
          ,('Connecticut'              , 'CT')
          ,('Delaware'                 , 'DE')
          ,('District of Columbia'     , 'DC')
          ,('Florida'                  , 'FL')
          ,('Georgia'                  , 'GA')
          ,('Hawaii'                   , 'HI')
          ,('Idaho'                    , 'ID')
          ,('Illinois'                 , 'IL')
          ,('Indiana'                  , 'IN')
          ,('Iowa'                     , 'IA')
          ,('Kansas'                   , 'KS')
          ,('Kentucky'                 , 'KY')
          ,('Louisiana'                , 'LA')
          ,('Maine'                    , 'ME')
          ,('Maryland'                 , 'MD')
          ,('Massachusetts'            , 'MA')
          ,('Michigan'                 , 'MI')
          ,('Minnesota'                , 'MN')
          ,('Mississippi'              , 'MS')
          ,('Missouri'                 , 'MO')
          ,('Montana'                  , 'MT')
          ,('Nebraska'                 , 'NE')
          ,('Nevada'                   , 'NV')
          ,('New Hampshire'            , 'NH')
          ,('New Jersey'               , 'NJ')
          ,('New Mexico'               , 'NM')
          ,('New York'                 , 'NY')
          ,('North Carolina'           , 'NC')
          ,('North Dakota'             , 'ND')
          ,('Ohio'                     , 'OH')
          ,('Oklahoma'                 , 'OK')
          ,('Oregon'                   , 'OR')
          ,('Pennsylvania'             , 'PA')
          ,('Rhode Island'             , 'RI')
          ,('South Carolina'           , 'SC')
          ,('South Dakota'             , 'SD')
          ,('Tennessee'                , 'TN')
          ,('Texas'                    , 'TX')
          ,('Utah'                     , 'UT')
          ,('Vermont'                  , 'VT')
          ,('Virginia'                 , 'VA')
          ,('Washington'               , 'WA')
          ,('West Virginia'            , 'WV')
          ,('Wisconsin'                , 'WI')
          ,('Wyoming'                  , 'WY')
          ,('American Samoa'           , 'AS')
          ,('Guam'                     , 'GU')
          ,('Northern Mariana Islands' , 'MP')
          ,('Puerto Rico'              , 'PU')
          ,('Virgin Islands'           , 'VI')
         ) AS s(
           name                        , code
         )
)
,REGION_DATA AS (
  SELECT *
        ,ROW_NUMBER() OVER(PARTITION BY s.country_relid) AS ord
    FROM (
    SELECT *
      FROM CA_REGION_DATA
     UNION ALL
    SELECT *
      FROM US_REGION_DATA
  ) s
)
INSERT INTO managed_tables.region(
  description
 ,terms
 ,country_relid
 ,name
 ,code
 ,ord
)
SELECT r.name as description
      ,TO_TSVECTOR('english', r.name || ' ' || r.code) AS terms
      ,r.*
  FROM REGION_DATA r
    ON CONFLICT(name, country_relid) DO
UPDATE
   SET description = excluded.name
      ,terms       = TO_TSVECTOR('english', excluded.name || ' ' || excluded.code)
      ,code        = excluded.code
      ,ord         = excluded.ord
 WHERE region.code != excluded.code
    OR region.ord  != excluded.ord;
