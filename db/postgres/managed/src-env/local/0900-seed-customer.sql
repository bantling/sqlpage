-- Seed addresses in a simple way that is not super accurate, but good enough and easy to understand
SET log_min_messages = NOTICE;

DO $$
DECLARE
  -- Get the number of customers to generate
  C_NUM_CUSTOMERS INT := ${PG_MANAGED_NUM_SEED_CUSTOMERS};

  -- C_NUM_CUSTOMERS loop counter
  V_COUNT_CUSTOMERS INT;

  -- True for personal addresses, false for business addresses
  V_IS_PERSONAL BOOL;

  -- The business address type relids (null for personal addresses)
  V_BUSINESS_ADDRESS_TYPE_RELIDS BIGINT[];

  -- V_BUSINESS_ADDRESS_TYPE_RELIDS loop counter
  V_LOOP_BUSINESS_ADDRESS_TYPE_RELIDS_IX INT;

  -- The address values
  V_DESCRIPTION TEXT;
  V_COUNTRY_RELID BIGINT;
  V_COUNTRY_NAME TEXT;
  V_COUNTRY_CODE2 CHAR(2);
  V_COUNTRY_HAS_REGIONS BOOL;
  V_REGION_RELID BIGINT;
  V_REGION_NAME TEXT;
  V_REGION_CODE CHAR(2);
  V_ADDRESS_LINE_1 TEXT;
  V_ADDRESS_LINE_2 TEXT;
  V_ADDRESS_LINE_3 TEXT;
  V_ADDRESS TEXT;
  V_CITY TEXT;
  V_MAILING_CODE TEXT;
BEGIN
  RAISE NOTICE 'C_NUM_CUSTOMERS = %', C_NUM_CUSTOMERS;

  FOR V_COUNT_CUSTOMERS IN 1 .. C_NUM_CUSTOMERS LOOP
    -- Choose personal addresses 85% of the time, businesses 15%
    V_IS_PERSONAL := managed_code.RANDOM_INT(1, 100) <= 85;

    -- Business addresses need a random subset of address type relids
    -- If V_IS_PERSONAL is false, 0 rows are selected, causing ARRAY_AGG(relid) to be NULL
    SELECT ARRAY_AGG(relid)
      INTO V_BUSINESS_ADDRESS_TYPE_RELIDS
      FROM (
        SELECT relid
          FROM managed_tables.address_type
         ORDER
            BY managed_code.RANDOM_INT()
         LIMIT managed_code.RANDOM_INT(1, (SELECT COUNT(*)::INT FROM managed_tables.address_type))
      ) t
     WHERE NOT V_IS_PERSONAL;

    -- Loop 1 time for a person, for each selected address type for a business
    -- Array indexes are 1-based
    FOR V_LOOP_BUSINESS_ADDRESS_TYPE_RELIDS_IX IN 1 .. COALESCE(ARRAY_LENGTH(V_BUSINESS_ADDRESS_TYPE_RELIDS, 1), 1) LOOP
        -- Choose a random country
        SELECT relid
              ,name
              ,code_2
              ,has_regions
          INTO V_COUNTRY_RELID
              ,V_COUNTRY_NAME
              ,V_COUNTRY_CODE2
              ,V_COUNTRY_HAS_REGIONS
          FROM managed_tables.country
         ORDER
            BY managed_code.RANDOM_INT()
         LIMIT 1;

        -- Choose a random region if the country has regions
        V_REGION_RELID := NULL;
        V_REGION_NAME  := NULL;
        V_REGION_CODE  := NULL;
        IF V_COUNTRY_HAS_REGIONS THEN
          SELECT relid
                ,name
                ,code
            INTO V_REGION_RELID
                ,V_REGION_NAME
                ,V_REGION_CODE
            FROM managed_tables.region
           WHERE country_relid = V_COUNTRY_RELID
           ORDER
              BY managed_code.RANDOM_INT()
           LIMIT 1;
        END IF;

        -- Generate random civic number and street, city, and mailing code
        SELECT managed_code.RANDOM_INT(1, Range) || ' ' || St -- Civic number, space, street name
              ,City
              ,CASE Country -- Mailing code
                 -- Canada postal code first letter has multiple values for some provinces
                 -- Choose one letter at random
                 WHEN 'CA' THEN SUBSTRING(Prefix FROM managed_code.RANDOM_INT(1, LENGTH(Prefix)) FOR 1) -- letter
                    || managed_code.RANDOM_INT(1, 9)                    -- digit
                    || CHR(ASCII('A') + managed_code.RANDOM_INT(0, 25)) -- letter
                    || ' '
                    || managed_code.RANDOM_INT(1, 9)                    -- digit
                    || CHR(ASCII('A') + managed_code.RANDOM_INT(0, 25)) -- letter
                    || managed_code.RANDOM_INT(1, 9)                    -- digit

                 -- Christmas Island has one postal code
                 WHEN 'CX' THEN Prefix

                 -- US zip code starts with a 3 digit prefix where first two digits can both be zero
                 -- Most states have multiple choices
                 -- Choose one prefix at random
                 WHEN 'US' THEN Prefix::JSON -> managed_code.RANDOM_INT(0, JSON_ARRAY_LENGTH(Prefix::JSON) - 1) #>> '{}' -- First 3 digits
                    || managed_code.RANDOM_INT(0, 9)                    -- Fourth digit
                    || managed_code.RANDOM_INT(0, 9)                    -- Fifth  digit
                    || CASE WHEN managed_code.RANDOM_INT(1, 100) <= 10  -- 10% chance of plus four
                            THEN '-'
                              || managed_code.RANDOM_INT(0, 9) -- First plus four digit
                              || managed_code.RANDOM_INT(0, 9) -- Second digit
                              || managed_code.RANDOM_INT(0, 9) -- Third digit
                              || managed_code.RANDOM_INT(0, 9) -- Fourth digit
                            ELSE ''                                     -- 90% chance of no plus four
                       END

                 -- Remaining countries have no postal code
                 ELSE NULL
               END CASE
          INTO V_ADDRESS_LINE_1
              ,V_CITY
              ,V_MAILING_CODE
          FROM (VALUES
                 -- Aruba
                 -- Country, Region, Range, St, City, No mailing code
                  ('AW', NULL, 999, 'Caya Frans Figaroa', 'Noord'      , NULL)
                 ,('AW', NULL, 99 , 'Spinozastraat'     , 'Oranjestad' , NULL)
                 ,('AW', NULL, 999, 'Bloemond'          , 'Paradera'   , NULL)
                 ,('AW', NULL, 999, 'Sero Colorado'     , 'San Nicolas', NULL)
                 ,('AW', NULL, 99 , 'San Fuego'         , 'Santa Cruz' , NULL)

                 -- Canada
                 -- Country, Region, Range, St, City, Postal code first letter
                 -- Alberta
                 ,('CA', 'AB', 99999, '17th Ave SW'        , 'Calgary'      , 'T'    )
                 ,('CA', 'AB', 9999 , 'Whyte Ave'          , 'Edmonton'     , 'T'    )
                 -- British Columbia
                 ,('CA', 'BC', 9999 , 'Government St'      , 'Victoria'     , 'V'    )
                 ,('CA', 'BC', 99999, 'Robson St'          , 'Vancouver'    , 'V'    )
                 -- Manitoba
                 ,('CA', 'MB', 99999, 'Regent Ave W'       , 'Winnipeg'     , 'R'    )
                 ,('CA', 'MB', 999  , 'Rosser Ave'         , 'Brandon'      , 'R'    )
                 -- New Brunswick
                 ,('CA', 'NB', 9999 , 'Dundonald St'       , 'Fredericton'  , 'E'    )
                 ,('CA', 'NB', 999  , 'King St'            , 'Moncton'      , 'E'    )
                 -- Newfoundland amd Labrador
                 ,('CA', 'NL', 999  , 'George St'          , 'St John''s'   , 'A'    )
                 ,('CA', 'NL', 999  , 'Everest St'         , 'Paradise'     , 'A'    )
                 -- Northwest Territories
                 ,('CA', 'NT', 99   , 'Ragged Ass Rd'      , 'Yellowknife'  , 'X'    )
                 ,('CA', 'NT', 99   , 'Poplar Rd'          , 'Hay River'    , 'X'    )
                 -- Nova Scotia
                 ,('CA', 'NS', 999  , 'Spring Garden Rd'   , 'Halifax'      , 'B'    )
                 ,('CA', 'NS', 999  , 'Dorchester St'      , 'Sydney'       , 'B'    )
                 -- Nunavut
                 ,('CA', 'NU', 99   , 'Mivvik St'          , 'Iqaluit'      , 'X'    )
                 ,('CA', 'NU', 99   , 'TikTaq Ave'         , 'Rankin Inlet' , 'X'    )
                 -- Ontario
                 ,('CA', 'ON', 99999, 'Wellington St'      , 'Ottawa'       , 'KLMNP')
                 ,('CA', 'ON', 99999, 'Yonge St'           , 'Toronto'      , 'KLMNP')
                 -- Prince Edward Island
                 ,('CA', 'PE', 999  , 'Richmond St'        , 'Charlottetown', 'C'    )
                 ,('CA', 'PE', 999  , 'Water St'           , 'Summerside'   , 'C'    )
                 -- Quebec
                 ,('CA', 'QC', 99999, 'Petit-Champlain St' , 'Quebec City'  , 'GHJ'  )
                 ,('CA', 'QC', 99999, 'Sainte-Catherine St', 'Montreal'     , 'GHJ'  )
                 -- Saksatoon
                 ,('CA', 'SK', 999  , 'Broadway Ave'       , 'Saskatoon'    , 'S'    )
                 ,('CA', 'SK', 999  , 'Winnipeg St'        , 'Regina'       , 'S'    )
                 -- Yukon
                 ,('CA', 'YT', 99   , 'Saloon Rd'          , 'Whitehorse'   , 'Y'    )
                 ,('CA', 'YT', 99   , '4th Ave'            , 'Dawson City'  , 'Y'    )

                 -- Christmas Island
                 -- Country, Region, Range, St, City, Single postal code
                 ,('CX', NULL, 99 , 'Lam Lok Loh' , 'Drumsite'        , '6798')
                 ,('CX', NULL, 999, 'Jln Pantai'  , 'Flying Fish Cove', '6798')
                 ,('CX', NULL, 99 , 'San Chye Loh', 'Poon Saan'       , '6798')
                 ,('CX', NULL, 999, 'Sea View Dr' , 'Silver City'     , '6798')

                 -- United States
                 -- Country, Region, Range, St, City, Zip code first 3 digits
                 -- Alabama
                 ,('US', 'AL', 9999  , 'Dexter Ave'         , 'Montgomery'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(350, 369) v EXCEPT SELECT 353 ORDER BY 1)))
                 ,('US', 'AL', 9999  , 'Holmes Ave NW'      , 'Huntsville'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(350, 369) v EXCEPT SELECT 353 ORDER BY 1)))
                 -- Alaska
                 ,('US', 'AK', 999   , 'South Franklin St'  , 'Juneau'          , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(995, 999) v ORDER BY 1)))
                 ,('US', 'AK', 999   , '2nd Ave'            , 'Fairbanks'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(995, 999) v ORDER BY 1)))
                 -- Arizona
                 ,('US', 'AZ', 99999 , 'Van Buren St'       , 'Phoenix'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(850, 865) v EXCEPT SELECT UNNEST(ARRAY[854, 858, 861, 862]) ORDER BY 1)))
                 ,('US', 'AZ', 99999 , '2nd Ave'            , 'Fairbanks'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(850, 865) v EXCEPT SELECT UNNEST(ARRAY[854, 858, 861, 862]) ORDER BY 1)))
                 -- Arkansas
                 ,('US', 'AR', 99999 , 'Commerce St'        , 'Little Rock'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(716, 729) v ORDER BY 1)))
                 ,('US', 'AR', 99999 , 'Dickson St'         , 'Fayetteville'    , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(716, 729) v ORDER BY 1)))
                 -- California
                 ,('US', 'CA', 99999 , 'K St'               , 'Sacramento'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(900, 961) v EXCEPT SELECT UNNEST(ARRAY[909, 929]) ORDER BY 1)))
                 ,('US', 'CA', 99999 , 'San Diego Ave'      , 'San Diego'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(900, 961) v EXCEPT SELECT UNNEST(ARRAY[909, 929]) ORDER BY 1)))
                 -- Colorado
                 ,('US', 'CO', 99999 , 'East Colfax Ave'    , 'Denver'          , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(800, 816) v ORDER BY 1)))
                 ,('US', 'CO', 99999 , 'Wilcox St'          , 'Castle Rock'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(800, 816) v ORDER BY 1)))
                 -- Connecticut
                 ,('US', 'CT', 99999 , 'Pratt St'           , 'Hartford'        , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(60, 69) v ORDER BY 1)))
                 ,('US', 'CT', 99999 , 'Helen St'           , 'Bridgeport'      , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(60, 69) v ORDER BY 1)))
                 -- Delaware
                 ,('US', 'DE', 99999 , 'Division St'        , 'Dover'           , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(197, 199) v ORDER BY 1)))
                 ,('US', 'DE', 99999 , 'Market St'          , 'Wilmington'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(197, 199) v ORDER BY 1)))
                 -- District of C0lumbia
                 ,('US', 'DC', 99999 , 'Pennsylvania Ave'   , 'Washington'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(200, 205) v EXCEPT SELECT 201 UNION ALL SELECT 569 ORDER BY 1)))
                 ,('US', 'DC', 99999 , '7th St'             , 'Shaw'            , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(200, 205) v EXCEPT SELECT 201 UNION ALL SELECT 569 ORDER BY 1)))
                 -- Florida
                 ,('US', 'FL', 99999 , 'Monroe St'          , 'Tallahassee'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(320, 349) v EXCEPT SELECT UNNEST(ARRAY[340, 343, 345, 348]) ORDER BY 1)))
                 ,('US', 'FL', 99999 , 'Laura St'           , 'Jacksonville'    , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(320, 349) v EXCEPT SELECT UNNEST(ARRAY[340, 343, 345, 348]) ORDER BY 1)))
                 -- Georgia
                 ,('US', 'GA', 99999 , 'Peachtree St'       , 'Atlanta'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(300, 319) v UNION ALL SELECT UNNEST(ARRAY[398, 399]) ORDER BY 1)))
                 ,('US', 'GA', 99999 , '11th St'            , 'Columbus'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(300, 319) v UNION ALL SELECT UNNEST(ARRAY[398, 399]) ORDER BY 1)))
                 -- Hawaii
                 ,('US', 'HI', 999   , 'Kalakaua Ave'       , 'Honolulu'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(967, 968) v ORDER BY 1)))
                 ,('US', 'HI', 999   , 'Banyan Dr'          , 'Hilo'            , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(967, 968) v ORDER BY 1)))
                 -- Idaho
                 ,('US', 'ID', 99999 , 'Capitol Blvd'       , 'Boise'           , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(832, 838) v ORDER BY 1)))
                 ,('US', 'ID', 99999 , 'E Pine Ave'         , 'Meridian'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(832, 838) v ORDER BY 1)))
                 -- Illinois
                 ,('US', 'IL', 99999 , 'Route 66'           , 'Springfield'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(600, 629) v EXCEPT SELECT 621 ORDER BY 1)))
                 ,('US', 'IL', 99999 , 'Michigan Ave'       , 'Chicago'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(600, 629) v EXCEPT SELECT 621 ORDER BY 1)))
                 -- Indiana
                 ,('US', 'IN', 99999 , 'Meridian St'        , 'Indianapolis'    , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(460, 479) v ORDER BY 1)))
                 ,('US', 'IN', 99999 , 'Calhoun St'         , 'Fort Wayne'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(460, 479) v ORDER BY 1)))
                 -- Iowa
                 ,('US', 'IA', 99999 , 'Court Ave'          , 'Des Moines'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(500, 528) v EXCEPT SELECT UNNEST(ARRAY[517, 518, 519]) ORDER BY 1)))
                 ,('US', 'IA', 99999 , 'First Ave'          , 'Cedar Rapids'    , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(500, 528) v EXCEPT SELECT UNNEST(ARRAY[517, 518, 519]) ORDER BY 1)))
                 -- Kansas
                 ,('US', 'KS', 99999 , 'SE 10th Ave'        , 'Topeka'          , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(660, 679) v EXCEPT SELECT 663 ORDER BY 1)))
                 ,('US', 'KS', 99999 , 'S Hydraulic Ave'    , 'Wichita'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(660, 679) v EXCEPT SELECT 663 ORDER BY 1)))
                 -- Kentucky
                 ,('US', 'KY', 99999 , 'Holmes St'          , 'Frankfort'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(400, 427) v EXCEPT SELECT 419 ORDER BY 1)))
                 ,('US', 'KY', 99999 , 'S Floyd St'         , 'Louisville'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(400, 427) v EXCEPT SELECT 419 ORDER BY 1)))
                 -- Louisiana
                 ,('US', 'LA', 99999 , 'Third St'           , 'Baton Rouge'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(700, 714) v EXCEPT SELECT UNNEST(ARRAY[702, 709]) ORDER BY 1)))
                 ,('US', 'LA', 99999 , 'Bourbon St'         , 'New Orleans'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(700, 714) v EXCEPT SELECT UNNEST(ARRAY[702, 709]) ORDER BY 1)))
                 -- Maine
                 ,('US', 'ME', 99999 , 'Maine St'           , 'Augusta'         , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(39, 49) v ORDER BY 1)))
                 ,('US', 'ME', 99999 , 'Congress St'        , 'Portland'        , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(39, 49) v ORDER BY 1)))
                 -- Maryland
                 ,('US', 'MD', 99999 , 'Bladen St'          , 'Annapolis'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(206, 219) v EXCEPT SELECT 213 ORDER BY 1)))
                 ,('US', 'MD', 99999 , 'Charles St'         , 'Baltimore'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(206, 219) v EXCEPT SELECT 213 ORDER BY 1)))
                 -- Massachusetts
                 ,('US', 'MA', 99999 , 'Acorn St'           , 'Boston'          , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(10, 27) v UNION ALL SELECT '055' ORDER BY 1)))
                 ,('US', 'MA', 99999 , 'North Water St'     , 'Edgartown'       , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(10, 27) v UNION ALL SELECT '055' ORDER BY 1)))
                 -- Michigan
                 ,('US', 'MI', 99999 , 'W Kalamazoo St'     , 'Lansing'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(480, 499) v ORDER BY 1)))
                 ,('US', 'MI', 99999 , 'Woodward Ave'       , 'Detroit'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(480, 499) v ORDER BY 1)))
                 -- Minnesota
                 ,('US', 'MN', 99999 , 'Summit Ave'         , 'Saint Paul'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(550, 567) v EXCEPT SELECT 552 ORDER BY 1)))
                 ,('US', 'MN', 99999 , 'Nicollet Ave'       , 'Minneapolis'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(550, 567) v EXCEPT SELECT 552 ORDER BY 1)))
                 -- Mississippi
                 ,('US', 'MS', 99999 , 'Farish St'          , 'Jackson'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(386, 397) v ORDER BY 1)))
                 ,('US', 'MS', 99999 , 'Seaway Rd'          , 'Gulfport'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(386, 397) v ORDER BY 1)))
                 -- Missouri
                 ,('US', 'MO', 99999 , 'Capitol Ave'        , 'Jefferson'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(630, 658) v EXCEPT SELECT UNNEST(ARRAY[632, 642, 643]) ORDER BY 1)))
                 ,('US', 'MO', 99999 , 'Independence Ave'   , 'Kansas City'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(630, 658) v EXCEPT SELECT UNNEST(ARRAY[632, 642, 643]) ORDER BY 1)))
                 -- Montana
                 ,('US', 'MT', 99999 , 'E Lyndale Ave'      , 'Helena'          , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(590, 599) v ORDER BY 1)))
                 ,('US', 'MT', 99999 , 'Clark Ave'          , 'Billings'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(590, 599) v ORDER BY 1)))
                 -- Nebraska
                 ,('US', 'NE', 99999 , 'O St'               , 'Lincoln'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(680, 693) v EXCEPT SELECT 682 ORDER BY 1)))
                 ,('US', 'NE', 99999 , 'Farnam St'          , 'Omaha'           , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(680, 693) v EXCEPT SELECT 682 ORDER BY 1)))
                 -- Nevada
                 ,('US', 'NV', 99999 , 'E William St'       , 'Carson City'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(889, 898) v EXCEPT SELECT UNNEST(ARRAY[892, 896]) ORDER BY 1)))
                 ,('US', 'NV', 99999 , 'Las Vegas Blvd'     , 'Las Vegas'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(889, 898) v EXCEPT SELECT UNNEST(ARRAY[892, 896]) ORDER BY 1)))
                 -- New hampshire
                 ,('US', 'NH', 99999 , 'Loudon Rd'          , 'Concord'         , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(30, 38) v ORDER BY 1)))
                 ,('US', 'NH', 99999 , 'Lake Ave'           , 'Manchester'      , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(30, 38) v ORDER BY 1)))
                 -- New Jersey
                 ,('US', 'NJ', 99999 , 'Front St'           , 'Trenton'         , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(70, 89) v ORDER BY 1)))
                 ,('US', 'NJ', 99999 , 'Broad St'           , 'Newark'          , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(70, 89) v ORDER BY 1)))
                 -- New Mexico
                 ,('US', 'NM', 99999 , 'Canyon Rd'          , 'Santa Fe'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(870, 884) v EXCEPT SELECT UNNEST(ARRAY[872, 876]) ORDER BY 1)))
                 ,('US', 'NM', 99999 , 'Central Ave'        , 'Albequerque'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(870, 884) v EXCEPT SELECT UNNEST(ARRAY[872, 876]) ORDER BY 1)))
                 -- New York
                 ,('US', 'NY', 99999 , 'Lark St'            , 'Albany'          , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '005' v UNION ALL SELECT v::TEXT FROM GENERATE_SERIES(100, 149) v ORDER BY 1)))
                 ,('US', 'NY', 99999 , 'Broadway'           , 'New York'        , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '005' v UNION ALL SELECT v::TEXT FROM GENERATE_SERIES(100, 149) v ORDER BY 1)))
                 -- North Carolina
                 ,('US', 'NC', 99999 , 'Fayetteville St'    , 'Raleigh'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(270,289) v ORDER BY 1)))
                 ,('US', 'NC', 99999 , 'Tryon Street'       , 'Charlotte'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(270,289) v ORDER BY 1)))
                 -- North Dakota
                 ,('US', 'ND', 99999 , '4th St'             , 'Bismarck'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(580, 588) v ORDER BY 1)))
                 ,('US', 'ND', 99999 , '13th Ave S'         , 'Fargo'           , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(580, 588) v ORDER BY 1)))
                 -- Ohio
                 ,('US', 'OH', 99999 , 'Broad St'           , 'Columbus'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(430, 459) v ORDER BY 1)))
                 ,('US', 'OH', 99999 , 'Vine St'            , 'Cincinnnati'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(430, 459) v ORDER BY 1)))
                 -- Oklahoma
                 ,('US', 'OK', 99999 , 'Reno Ave'           , 'Oklahoma City'   , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(730, 749) v EXCEPT SELECT UNNEST(ARRAY[732, 733, 742]) ORDER BY 1)))
                 ,('US', 'OK', 99999 , 'S Zenith ave'       , 'Tulsa'           , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(730, 749) v EXCEPT SELECT UNNEST(ARRAY[732, 733, 742]) ORDER BY 1)))
                 -- Oregon
                 ,('US', 'OR', 99999 , 'Chestnut St'        , 'Salem'           , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(970, 979) v ORDER BY 1)))
                 ,('US', 'OR', 99999 , 'Wall St'            , 'Bend'            , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(970, 979) v ORDER BY 1)))
                 -- Pennsylvania
                 ,('US', 'PA', 99999 , 'State St'           , 'Harrisburg'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(150, 196) v ORDER BY 1)))
                 ,('US', 'PA', 99999 , 'South St'           , 'Philadelphia'    , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(150, 196) v ORDER BY 1)))
                 -- Rhode Island
                 ,('US', 'RI', 999   , 'Hope St'            , 'Providence'      , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(28, 29) v ORDER BY 1)))
                 ,('US', 'RI', 999   , 'Phenix Ave'         , 'Cranston'        , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(28, 29) v ORDER BY 1)))
                 -- South Carolina
                 ,('US', 'SC', 99999 , 'Gervais St'         , 'Columbia'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(290, 299) v ORDER BY 1)))
                 ,('US', 'SC', 99999 , 'King St'            , 'Charleston'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(290, 299) v ORDER BY 1)))
                 -- South Dakota
                 ,('US', 'SD', 99999 , 'N Taylor Ave'       , 'Pierre'          , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(570, 577) v ORDER BY 1)))
                 ,('US', 'SD', 99999 , 'Ladyslipper Cir'    , 'Sioux Falls'     , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(570, 577) v ORDER BY 1)))
                 -- Tennessee
                 ,('US', 'TN', 99999 , 'Edgehill Ave'       , 'Nashville'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(370, 385) v ORDER BY 1)))
                 ,('US', 'TN', 99999 , 'Spottswood Ave'     , 'Memphis'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(370, 385) v ORDER BY 1)))
                 -- Texas
                 ,('US', 'TX', 99999 , 'Sixth St'           , 'Austin'          , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT 733 v UNION ALL SELECT GENERATE_SERIES(750, 799) EXCEPT SELECT 771 UNION ALL SELECT 885 ORDER BY 1)))
                 ,('US', 'TX', 99999 , 'Westheimeer Rd'     , 'Houston'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT 733 v UNION ALL SELECT GENERATE_SERIES(750, 799) EXCEPT SELECT 771 UNION ALL SELECT 885 ORDER BY 1)))
                 -- Utah
                 ,('US', 'UT', 99999 , 'Poplar Grove Vlvd S', 'Salt Lake City'  , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(840, 847) v ORDER BY 1)))
                 ,('US', 'UT', 99999 , 'Nancy Dr'           , 'West Valley City', (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(840, 847) v ORDER BY 1)))
                 -- Vermont
                 ,('US', 'VT', 99999 , 'Towne Hill Rd'      , 'Montpelier'      , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(50, 59) v EXCEPT SELECT '055' ORDER BY 1)))
                 ,('US', 'VT', 99999 , 'N Willard St'       , 'Burlington'      , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '0' || GENERATE_SERIES(50, 59) v EXCEPT SELECT '055' ORDER BY 1)))
                 -- Virginia
                 ,('US', 'VA', 99999 , 'Monument Ave'       , 'Richmond'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT 201 v UNION ALL SELECT GENERATE_SERIES(220, 246) ORDER BY 1)))
                 ,('US', 'VA', 99999 , 'Atlantic Ave'       , 'Virginia Beach'  , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT 201 v UNION ALL SELECT GENERATE_SERIES(220, 246) ORDER BY 1)))
                 -- Washington
                 ,('US', 'WA', 99999 , 'Union Ave SE'       , 'Olympia'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(980, 994) v EXCEPT SELECT 987 ORDER BY 1)))
                 ,('US', 'WA', 99999 , 'Pike St'            , 'Seattle'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(980, 994) v EXCEPT SELECT 987 ORDER BY 1)))
                 -- West Virginia
                 ,('US', 'WV', 99999 , 'Quarrier St'        , 'Charleston'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(247, 268) v ORDER BY 1)))
                 ,('US', 'WV', 99999 , 'Buffington Ave'     , 'Huntington'      , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(247, 268) v ORDER BY 1)))
                 -- Wisconsin
                 ,('US', 'WI', 99999 , 'N Bassett St'       , 'Madison'         , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(530, 549) v EXCEPT SELECT UNNEST(ARRAY[533, 536]) ORDER BY 1)))
                 ,('US', 'WI', 99999 , 'Brady St'           , 'Milwaukee'       , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(530, 549) v EXCEPT SELECT UNNEST(ARRAY[533, 536]) ORDER BY 1)))
                 -- Wyoming
                 ,('US', 'WY', 99999 , 'Evans Ave'          , 'Cheyenne'        , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(820, 831) v ORDER BY 1)))
                 ,('US', 'WY', 99999 , 'W Collins Dr'       , 'Casper'          , (SELECT JSON_AGG(v::TEXT)::TEXT FROM (SELECT GENERATE_SERIES(820, 831) v ORDER BY 1)))
                 -- American Samoa
                 ,('US', 'AS', 999   , 'Route 011'          , 'American Samoa, Eastern District, Vaifanua County, Faalefu'     , '["967"]')
                 ,('US', 'AS', 999   , 'Mason Gelns'        , 'American Samoa, Western District, Leasina County, Aasu, A''asu' , '["967"]')
                 -- Guam
                 ,('US', 'GU', 999   , 'Marine Corps Dr'    , 'Hagåtña'         , '["969"]')
                 ,('US', 'GU', 999   , 'Buena Vista Ave'    , 'Dededo'          , '["969"]')
                 -- Northern Mariana Islands
                 ,('US', 'MP', 99    , 'Tapochao Rd'        , 'Saipan'          , '["969"]')
                 ,('US', 'MP', 99    , 'Ayuyu Dr'           , 'Marpi'           , '["969"]')
                 -- Puerto Rico
                 ,('US', 'PU', 999   , 'C Aragón'           , 'San Juan'        , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '00' || GENERATE_SERIES(6, 9) v EXCEPT SELECT '008' ORDER BY 1)))
                 ,('US', 'PU', 999   , 'Ave Hostos'         , 'Bayamón'         , (SELECT JSON_AGG(v)::TEXT FROM (SELECT '00' || GENERATE_SERIES(6, 9) v EXCEPT SELECT '008' ORDER BY 1)))
                 -- Virgin Islands
                 ,('US', 'VI', 99    , 'Harbour Ridge Rd'   , 'Charlotte Amalie', '["008"]')
                 ,('US', 'VI', 99    , 'Alfred Andrews St'  , 'St Croix'        , '["008"]')
               ) as d(
                   Country, Region, Range, St, City, Prefix
               )
         WHERE Country = V_COUNTRY_CODE2
           AND V_REGION_CODE IS NOT DISTINCT FROM Region -- Some countries have NULL region
         ORDER
            BY managed_code.RANDOM_INT()
         LIMIT 1; -- Each country/region has at least 2 street/city combos to choose from

        -- Set address line 2 and 3 randomly
        V_ADDRESS_LINE_2 := NULL;
        V_ADDRESS_LINE_3 := NULL;

        IF V_IS_PERSONAL THEN
            -- Personal addresses can have apartment / suite numbers
            -- Generate them 25% of the time
            SELECT (ARRAY['Apt', 'Suite'])[managed_code.RANDOM_INT(1, 2)] || ' ' || managed_code.RANDOM_INT(1, 9999)
              INTO V_ADDRESS_LINE_2
             WHERE managed_code.RANDOM_INT(1, 100) <= 25;
        ELSE
            -- Business addresses can have a suite / unit numbers, as well as door / stop numbers
            -- Generate a line 2 30% of the time
            SELECT (ARRAY['Suite', 'Unit'])[managed_code.RANDOM_INT(1, 2)] || ' ' || managed_code.RANDOM_INT(1, 9999)
              INTO V_ADDRESS_LINE_2
             WHERE managed_code.RANDOM_INT(1, 100) <= 30;

            -- Generate a line 3 10% of the time a line 2 was chosen (10% of 30% = 3% of the time)
            SELECT (ARRAY['Door' , 'Stop'])[managed_code.RANDOM_INT(1, 2)] || ' ' || managed_code.RANDOM_INT(1, 9)
              INTO V_ADDRESS_LINE_3
             WHERE V_ADDRESS_LINE_2 IS NOT NULL
               AND managed_code.RANDOM_INT(1, 100) <= 10;
        END IF;

        -- The description and terms are based on the full address
        V_DESCRIPTION := V_ADDRESS_LINE_1
                         || COALESCE(' ' || V_ADDRESS_LINE_2, '')
                         || COALESCE(' ' || V_ADDRESS_LINE_3, '')
                         || ' ' || V_CITY
                         || COALESCE(' ' || V_REGION_NAME, '')
                         || ' ' || V_COUNTRY_NAME
                         || COALESCE(' ' || V_MAILING_CODE, '');

        RAISE NOTICE 'V_BUSINESS_ADDRESS_TYPE_RELIDS = %', V_BUSINESS_ADDRESS_TYPE_RELIDS;
        RAISE NOTICE 'V_COUNTRY_RELID                = %', V_COUNTRY_RELID;
        RAISE NOTICE 'V_COUNTRY_CODE2                = %', V_COUNTRY_CODE2;
        RAISE NOTICE 'V_REGION_RELID                 = %', V_REGION_RELID;
        RAISE NOTICE 'V_REGION_CODE                  = %', V_REGION_CODE;
        RAISE NOTICE 'V_ADDRESS_LINE_1               = %', V_ADDRESS_LINE_1;
        RAISE NOTICE 'V_ADDRESS_LINE_2               = %', V_ADDRESS_LINE_2;
        RAISE NOTICE 'V_ADDRESS_LINE_3               = %', V_ADDRESS_LINE_3;
        RAISE NOTICE 'V_CITY                         = %', V_CITY;
        RAISE NOTICE 'V_MAILING_CODE                 = %', V_MAILING_CODE;
        RAISE NOTICE 'V_DESCRIPTION                  = %', V_DESCRIPTION;

        -- Insert address, which may be personal or business
        INSERT INTO managed_tables.address(
          description
         ,address_type_relid
         ,country_relid
         ,region_relid
         ,city
         ,address
         ,address_2
         ,address_3
         ,mailing_code
        ) VALUES (
          V_DESCRIPTION
         ,V_BUSINESS_ADDRESS_TYPE_RELIDS[V_LOOP_BUSINESS_ADDRESS_TYPE_RELIDS_IX]
         ,V_COUNTRY_RELID
         ,V_REGION_RELID
         ,V_CITY
         ,V_ADDRESS_LINE_1
         ,V_ADDRESS_LINE_2
         ,V_ADDRESS_LINE_3
         ,V_MAILING_CODE
        );
    END LOOP; -- V_LOOP_BUSINESS_ADDRESS_TYPE_RELIDS_IX
  END LOOP;   -- V_COUNT_CUSTOMERS
END;
$$ LANGUAGE plpgsql;
