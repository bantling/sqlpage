-- Seed addresses in a simple way that is not super accurate, but good enough and easy to understand
SET log_min_messages = NOTICE;

DO $$
DECLARE
  C_NUM_ROWS INT := ${PG_MANAGED_NUM_SEED_CUSTOMERS};

  -- Loop counter
  V_COUNT INT;

  -- True if generating a personal address, false for business address
  V_IS_PERSONAL BOOL;

  -- The business address type relid (null for personal address)
  V_BUSINESS_ADDRESS_TYPE_RELID BIGINT;

  -- The address values
  V_COUNTRY_RELID BIGINT;
  V_COUNTRY_CODE2 CHAR(2);
  V_COUNTRY_HAS_REGIONS BOOL;
  V_REGION_RELID BIGINT;
  V_REGION_CODE CHAR(2);
  V_ADDRESS_1 TEXT;
  V_ADDRESS_2 TEXT;
  V_ADDRESS_3 TEXT;
  V_CITY TEXT;
  V_MAILING_CODE TEXT;
BEGIN
  RAISE NOTICE 'C_NUM_ROWS = %', C_NUM_ROWS;

  FOR V_COUNT IN 1 .. C_NUM_ROWS LOOP
    -- Choose personal addresses 70% of the time, businesses 30%
    V_IS_PERSONAL := random() <= 0.70;

    -- Business addresses need a random address type relid
    V_BUSINESS_ADDRESS_TYPE_RELID := NULL;
    IF NOT V_IS_PERSONAL THEN
       SELECT relid
         INTO V_BUSINESS_ADDRESS_TYPE_RELID
         FROM managed_tables.address_type
        ORDER BY RANDOM()
        LIMIT 1;
    END IF;

    -- Choose a random country id and has_regions flag
    SELECT relid
          ,code_2
          ,has_regions
      INTO V_COUNTRY_RELID
          ,V_COUNTRY_CODE2
          ,V_COUNTRY_HAS_REGIONS
      FROM managed_tables.country
     ORDER BY RANDOM()
     LIMIT 1;

    -- Choose a random region id and code if the country has regions
    V_REGION_RELID := NULL;
    V_REGION_CODE  := NULL;
    IF V_COUNTRY_HAS_REGIONS THEN
      SELECT relid
            ,code
        INTO V_REGION_RELID
            ,V_REGION_CODE
        FROM managed_tables.region
       WHERE country_relid = V_COUNTRY_RELID
       ORDER BY RANDOM()
       LIMIT 1;
    END IF;

    -- TEMP HARD CODING
    SELECT relid INTO V_COUNTRY_RELID FROM managed_tables.country WHERE code_2 = 'AW';
    V_COUNTRY_CODE2 := 'US';
    --V_COUNTRY_HAS_REGIONS := FALSE;
    --V_REGION_RELID := NULL;
    --V_REGION_CODE := NULL;
    SELECT relid INTO V_REGION_RELID FROM managed_tables.region WHERE code = 'NB';
    V_REGION_CODE := 'GA';

    SELECT managed_code.RANDOM_INT(1, Range) || ' ' || St
          ,City
          ,CASE Country
             WHEN 'CA' THEN SUBSTRING(Prefix FROM managed_code.RANDOM_INT(1, LENGTH(Prefix)) FOR 1) -- letter
                || managed_code.RANDOM_INT(1, 9)                    -- digit
                || CHR(ASCII('A') + managed_code.RANDOM_INT(0, 25)) -- letter
                || ' '
                || managed_code.RANDOM_INT(1, 9)                    -- digit
                || CHR(ASCII('A') + managed_code.RANDOM_INT(0, 25)) -- letter
                || managed_code.RANDOM_INT(1, 9)                    -- digit
             WHEN 'CX' THEN Prefix
             WHEN 'US' THEN Prefix::JSON -> managed_code.RANDOM_INT(0, JSON_ARRAY_LENGTH(Prefix::JSON) -1) #>> '{}' -- First 3 digits
                || managed_code.RANDOM_INT(0, 9)::TEXT -- Fourth digit
                || managed_code.RANDOM_INT(0, 9)::TEXT -- Fifth  digit
                || CASE WHEN RANDOM() <= 0.1     -- 10% chance of plus four
                        THEN '-'
                          || managed_code.RANDOM_INT(0, 9)::TEXT
                          || managed_code.RANDOM_INT(0, 9)::TEXT
                          || managed_code.RANDOM_INT(0, 9)::TEXT
                          || managed_code.RANDOM_INT(0, 9)::TEXT
                        ELSE ''                  -- 90% chance of no plus four
                   END
             ELSE NULL
           END CASE
      INTO V_ADDRESS_1
          ,V_CITY
          ,V_MAILING_CODE
      FROM (VALUES
              -- Aruba
              ('AW'   , NULL  , 99    , 'Caya Frans Figaroa' , 'Noord'      , NULL)
             ,('AW'   , NULL  , 99    , 'Spinozastraat'      , 'Oranjestad' , NULL)
             ,('AW'   , NULL  , 99    , 'Bloemond'           , 'Paradera'   , NULL)
             ,('AW'   , NULL  , 99    , 'Sero Colorado'      , 'San Nicolas', NULL)
             ,('AW'   , NULL  , 99    , 'San Fuego'          , 'Santa Cruz' , NULL)

             -- Canada
             -- Alberta
             ,('CA'   , 'AB'  , 99999 , '17th Ave SW'        , 'Calgary'    , 'T')
             ,('CA'   , 'AB'  , 999   , 'Whyte Ave'          , 'Edmonton'   , 'T')
             -- British Columbia
             ,('CA'   , 'BC'  , 9999  , 'Government St'      , 'Victoria'   , 'V')
             ,('CA'   , 'BC'  , 99999 , 'Robson St'          , 'Vancouver'  , 'V')
             -- Manitoba
             ,('CA'   , 'MB'  , 99999 , 'Regent Ave W'       , 'Winnipeg'   , 'R')
             ,('CA'   , 'MB'  , 999   , 'Rosser Ave'         , 'Brandon'    , 'R')
             -- New Brunswick
             ,('CA'   , 'NB'  , 9999  , 'Dundonald St'       , 'Fredericton' , 'E')
             ,('CA'   , 'NB'  , 999   , 'King St'            , 'Moncton'    , 'E')
             -- Newfoundland amd Labrador
             ,('CA'   , 'NL'  , 999   , 'George St'          , 'St John''s' , 'A')
             ,('CA'   , 'NL'  , 999   , 'Everest St'         , 'Paradise'   , 'A')
             -- Northwest Territories
             ,('CA'   , 'NT'  , 99    , 'Ragged Ass Rd'      , 'Yellowknife', 'X')
             ,('CA'   , 'NT'  , 99    , 'Poplar Rd'          , 'Hay River'  , 'X')
             -- Nova Scotia
             ,('CA'   , 'NS'  , 999   , 'Spring Garden Rd'   , 'Halifax'    , 'B')
             ,('CA'   , 'NS'  , 999   , 'Dorchester St'      , 'Sydney'     , 'B')
             -- Nunavut
             ,('CA'   , 'NU'  , 99    , 'Mivvik St'          , 'Iqaluit'    , 'X')
             ,('CA'   , 'NU'  , 99    , 'TikTaq Ave'         , 'Rankin Inlet', 'X')
             -- Ontario
             ,('CA'   , 'ON'  , 99999 , 'Wellington St'      , 'Ottawa'      , 'KLMNP')
             ,('CA'   , 'ON'  , 99999 , 'Yonge St'           , 'Toronto'     , 'KLMNP')
             -- Prince Edward Island
             ,('CA'   , 'PE'  , 999   , 'Richmond St'        , 'Charlottetown', 'C')
             ,('CA'   , 'PE'  , 999   , 'Water St'           , 'Summerside'   , 'C')
             -- Quebec
             ,('CA'   , 'QC'  , 99999 , 'Petit-Champlain St' , 'Quebec City', 'GHJ')
             ,('CA'   , 'QC'  , 99999 , 'Sainte-Catherine St', 'Montreal'   , 'GHJ')
             -- Saksatoon
             ,('CA'   , 'SK'  , 999   , 'Broadway Ave'       , 'Saskatoon'  , 'S')
             ,('CA'   , 'SK'  , 999   , 'Winnipeg St'        , 'Regina'     , 'S')
             -- Yukon
             ,('CA'   , 'YT'  , 99    , 'Saloon Rd'          , 'Whitehorse' , 'Y')
             ,('CA'   , 'YT'  , 99    , '4th Ave'            , 'Dawson City', 'Y')

             -- Christmas Island
             ,('CX'   , NULL  , 99    , 'Lam Lok Loh'        , 'Drumsite'        , '6798')
             ,('CX'   , NULL  , 99    , 'Jln Pantai'         , 'Flying Fish Cove', '6798')
             ,('CX'   , NULL  , 99    , 'San Chye Loh'       , 'Poon Saan'       , '6798')
             ,('CX'   , NULL  , 99    , 'Sea View Dr'        , 'Silver City'     , '6798')

             -- United States
             -- Alabama
             ,('US'   , 'AL'  , 9999  , 'Dexter Ave'         , 'Montgomery'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(350, 369) v EXCEPT SELECT 353 ORDER BY 1)))
             ,('US'   , 'AL'  , 9999  , 'Holmes Ave NW'      , 'Huntsville'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(350, 369) v EXCEPT SELECT 353 ORDER BY 1)))
             -- Alaska
             ,('US'   , 'AK'  , 99    , 'South Franklin St'  , 'Juneau'          , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(995, 999) v ORDER BY 1)))
             ,('US'   , 'AK'  , 99    , '2nd Ave'            , 'Fairbanks'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(995, 999) v ORDER BY 1)))
             -- Arizona
             ,('US'   , 'AZ'  , 99999 , 'Van Buren St'       , 'Phoenix'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(850, 865) v EXCEPT SELECT UNNEST(ARRAY[854, 858, 861, 862]) ORDER BY 1)))
             ,('US'   , 'AZ'  , 99999 , '2nd Ave'            , 'Fairbanks'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(850, 865) v EXCEPT SELECT UNNEST(ARRAY[854, 858, 861, 862]) ORDER BY 1)))
             -- Arkansas
             ,('US'   , 'AR'  , 99999 , 'Commerce St'        , 'Little Rock'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(716, 729) v ORDER BY 1)))
             ,('US'   , 'AR'  , 99999 , 'Dickson St'         , 'Fayetteville'    , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(716, 729) v ORDER BY 1)))
             -- California
             ,('US'   , 'CA'  , 99999 , 'K St'               , 'Sacramento'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(900, 961) v EXCEPT SELECT UNNEST(ARRAY[909, 929]) ORDER BY 1)))
             ,('US'   , 'CA'  , 99999 , 'San Diego Ave'      , 'San Diego'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(900, 961) v EXCEPT SELECT UNNEST(ARRAY[909, 929]) ORDER BY 1)))
             -- Colorado
             ,('US'   , 'CO'  , 99999 , 'East Colfax Ave'    , 'Denver'          , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(800, 816) v ORDER BY 1)))
             ,('US'   , 'CO'  , 99999 , 'Wilcox St'          , 'Castle Rock'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(800, 816) v ORDER BY 1)))
             -- Connecticut
             ,('US'   , 'CT'  , 99999 , 'Pratt St'           , 'Hartford'        , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(60, 69) v ORDER BY 1)))
             ,('US'   , 'CT'  , 99999 , 'Helen St'           , 'Bridgeport'      , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(60, 69) v ORDER BY 1)))
             -- Delaware
             ,('US'   , 'DE'  , 99999 , 'Division St'        , 'Dover'           , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(197, 199) v ORDER BY 1)))
             ,('US'   , 'DE'  , 99999 , 'Market St'          , 'Wilmington'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(197, 199) v ORDER BY 1)))
             -- District of C0lumbia
             ,('US'   , 'DC'  , 99999 , 'Pennsylvania Ave'   , 'Washington'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(200, 205) v EXCEPT SELECT 201 UNION ALL SELECT 569 ORDER BY 1)))
             ,('US'   , 'DC'  , 99999 , '7th St'             , 'Shaw'            , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(200, 205) v EXCEPT SELECT 201 UNION ALL SELECT 569 ORDER BY 1)))
             -- Florida
             ,('US'   , 'FL'  , 99999 , 'Monroe St'          , 'Tallahassee'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(320, 349) v EXCEPT SELECT UNNEST(ARRAY[340, 343, 345, 348]) ORDER BY 1)))
             ,('US'   , 'FL'  , 99999 , 'Laura St'           , 'Jacksonville'    , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(320, 349) v EXCEPT SELECT UNNEST(ARRAY[340, 343, 345, 348]) ORDER BY 1)))
             -- Georgia
             ,('US'   , 'GA'  , 99999 , 'Peachtree St'       , 'Atlanta'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(300, 319) v EXCEPT SELECT UNNEST(ARRAY[398, 399]) ORDER BY 1)))
             ,('US'   , 'GA'  , 99999 , '11th St'            , 'Columbus'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(300, 319) v EXCEPT SELECT UNNEST(ARRAY[398, 399]) ORDER BY 1)))
             -- Hawaii
             ,('US'   , 'HI'  , 999   , 'Kalakaua Ave'       , 'Honolulu'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(967, 968) v ORDER BY 1)))
             ,('US'   , 'HI'  , 999   , 'Banyan Dr'          , 'Hilo'            , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(967, 968) v ORDER BY 1)))
             -- Idaho
             ,('US'   , 'ID'  , 99999 , 'Capitol Blvd'       , 'Boise'           , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(832, 838) v ORDER BY 1)))
             ,('US'   , 'ID'  , 99999 , 'E Pine Ave'         , 'Meridian'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(832, 838) v ORDER BY 1)))
             -- Illinois
             ,('US'   , 'IL'  , 99999 , 'Route 66'           , 'Springfield'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(600, 629) v EXCEPT SELECT 621 ORDER BY 1)))
             ,('US'   , 'IL'  , 99999 , 'Michigan Ave'       , 'Chicago'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(600, 629) v EXCEPT SELECT 621 ORDER BY 1)))
             -- Indiana
             ,('US'   , 'IN'  , 99999 , 'Meridian St'        , 'Indianapolis'    , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(460, 479) v ORDER BY 1)))
             ,('US'   , 'IN'  , 99999 , 'Calhoun St'         , 'Fort Wayne'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(460, 479) v ORDER BY 1)))
             -- Iowa
             ,('US'   , 'IA'  , 99999 , 'Peachtree St'       , 'Atlanta'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(300, 319) v EXCEPT SELECT UNNEST(ARRAY[398, 399]) ORDER BY 1)))
             ,('US'   , 'IA'  , 99999 , '11th St'            , 'Columbus'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(300, 319) v EXCEPT SELECT UNNEST(ARRAY[398, 399]) ORDER BY 1)))
             -- Kansas
             ,('US'   , 'KS'  , 99999 , 'SE 10th Ave'        , 'Topeka'          , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(660, 679) v EXCEPT SELECT 663 ORDER BY 1)))
             ,('US'   , 'KS'  , 99999 , 'S Hydraulic Ave'    , 'Wichita'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(660, 679) v EXCEPT SELECT 663 ORDER BY 1)))
             -- Kentucky
             ,('US'   , 'KY'  , 99999 , 'Holmes St'          , 'Frankfort'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(400, 427) v EXCEPT SELECT 419 ORDER BY 1)))
             ,('US'   , 'KY'  , 99999 , 'S Floyd St'         , 'Louisville'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(400, 427) v EXCEPT SELECT 419 ORDER BY 1)))
           ) as d(
               Country, Region, Range , St                   , City              , Prefix
           )
     WHERE Country = V_COUNTRY_CODE2
       AND V_REGION_CODE IS NOT DISTINCT FROM Region
     ORDER BY RANDOM()
      LIMIT 1;

    RAISE NOTICE 'V_BUSINESS_ADDRESS_TYPE_RELID = %', V_BUSINESS_ADDRESS_TYPE_RELID;
    RAISE NOTICE 'V_COUNTRY_RELID               = %', V_COUNTRY_RELID;
    RAISE NOTICE 'V_COUNTRY_CODE2               = %', V_COUNTRY_CODE2;
    RAISE NOTICE 'V_REGION_RELID                = %', V_REGION_RELID;
    RAISE NOTICE 'V_REGION_CODE                 = %', V_REGION_CODE;
    RAISE NOTICE 'V_ADDRESS_1                   = %', V_ADDRESS_1;
    RAISE NOTICE 'V_CITY                        = %', V_CITY;
    RAISE NOTICE 'V_MAILING_CODE                = %', V_MAILING_CODE;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
