-- Drop the triggers on the affected tables first, and re-enable them later
-- This cuts the insertion time to about 62%
ALTER TABLE managed_tables.customer_person   DISABLE TRIGGER ALL;
ALTER TABLE managed_tables.customer_business DISABLE TRIGGER ALL;

-- Generate customers the fast way, using CTEs
-- Basic CTE strategy is as follows:
-- 1. Start with CTEs that select * from previous CTE to build up more and more data to choose from into a single row
-- 2. GEN_IS_PERSONAL CTE uses generate_series to generate PG_MANAGED_NUM_SEED_CUSTOMERS rows of data
--    The data indicates if a customer is personal or not (business)
-- 3. Remaining person CTEs choose individual randomn names for each personal customer
-- 4. I_CUSTOMER_PERSON CTE inserts random names into customer_person
-- 5. Some business CTEs draw from  GEN_IS_PERSONAL to generate random names for business customers
-- 6. I_CUSTOMER_BUSINESS CTE inserts random names into customer_business
-- 7. Final select just selects constant 1, so that as CTEs evolve, final select does not need to be altered
WITH PARAMS AS (
  SELECT 1000 AS NUM_CUSTOMERS
        ,CURRENT_TIMESTAMP AS INS_TIMESTAMP
   --WHERE (SELECT COUNT(*) FROM managed_tables.address)           = 0
   --  AND (SELECT COUNT(*) FROM managed_tables.customer_person)   = 0
   --  AND (SELECT COUNT(*) FROM managed_tables.customer_business) = 0
)
-- SELECT * FROM PARAMS;
, ADDRESS_DATA AS (
    -- ADDRESS_DATA is a 2D ARRAY that contains a row for each country,
    -- which in turn contains a row for each city/region:
    -- [[{"Country": "AW", ...}, {"Country": "AW"}, ...], [{"Country": "CA", ...}, {"Country": "CA", ...}], ...]
    SELECT JSON_AGG(d) AS d
      FROM (
            SELECT JSON_AGG(TO_JSON(d) ORDER BY Country, Region, City) d
              FROM (VALUES
                     -- Aruba
                     -- Country, Region, Range, St, City, No mailing code
                       ('AW', NULL, 999, 'Caya Frans Figaroa', 'Noord'      , 'null'::JSON)
                      ,('AW', NULL, 99 , 'Spinozastraat'     , 'Oranjestad' , 'null'::JSON)
                      ,('AW', NULL, 999, 'Bloemond'          , 'Paradera'   , 'null'::JSON)
                      ,('AW', NULL, 999, 'Sero Colorado'     , 'San Nicolas', 'null'::JSON)
                      ,('AW', NULL, 99 , 'San Fuego'         , 'Santa Cruz' , 'null'::JSON)

                     -- Canada
                     -- Country, Region, Range, St, City, Postal code first letter
                     -- Alberta
                     ,('CA', 'AB', 99999, '17th Ave SW'        , 'Calgary'      , TO_JSON('T'::TEXT))
                     ,('CA', 'AB', 9999 , 'Whyte Ave'          , 'Edmonton'     , TO_JSON('T'::TEXT))

                     -- British Columbia
                     ,('CA', 'BC', 9999 , 'Government St'      , 'Victoria'     , TO_JSON('V'::TEXT))
                     ,('CA', 'BC', 99999, 'Robson St'          , 'Vancouver'    , TO_JSON('V'::TEXT))
                     -- Manitoba
                     ,('CA', 'MB', 99999, 'Regent Ave W'       , 'Winnipeg'     , TO_JSON('R'::TEXT))
                     ,('CA', 'MB', 999  , 'Rosser Ave'         , 'Brandon'      , TO_JSON('R'::TEXT))
                     -- New Brunswick
                     ,('CA', 'NB', 9999 , 'Dundonald St'       , 'Fredericton'  , TO_JSON('E'::TEXT))
                     ,('CA', 'NB', 999  , 'King St'            , 'Moncton'      , TO_JSON('E'::TEXT))
                     -- Newfoundland amd Labrador
                     ,('CA', 'NL', 999  , 'George St'          , 'St John''s'   , TO_JSON('A'::TEXT))
                     ,('CA', 'NL', 999  , 'Everest St'         , 'Paradise'     , TO_JSON('A'::TEXT))
                     -- Northwest Territories
                     ,('CA', 'NT', 99   , 'Ragged Ass Rd'      , 'Yellowknife'  , TO_JSON('X'::TEXT))
                     ,('CA', 'NT', 99   , 'Poplar Rd'          , 'Hay River'    , TO_JSON('X'::TEXT))
                     -- Nova Scotia
                     ,('CA', 'NS', 999  , 'Spring Garden Rd'   , 'Halifax'      , TO_JSON('B'::TEXT))
                     ,('CA', 'NS', 999  , 'Dorchester St'      , 'Sydney'       , TO_JSON('B'::TEXT))
                     -- Nunavut
                     ,('CA', 'NU', 99   , 'Mivvik St'          , 'Iqaluit'      , TO_JSON('X'::TEXT))
                     ,('CA', 'NU', 99   , 'TikTaq Ave'         , 'Rankin Inlet' , TO_JSON('X'::TEXT))
                     -- Ontario
                     ,('CA', 'ON', 99999, 'Wellington St'      , 'Ottawa'       , TO_JSON('KLMNP'::TEXT))
                     ,('CA', 'ON', 99999, 'Yonge St'           , 'Toronto'      , TO_JSON('KLMNP'::TEXT))
                     -- Prince Edward Island
                     ,('CA', 'PE', 999  , 'Richmond St'        , 'Charlottetown', TO_JSON('C'::TEXT))
                     ,('CA', 'PE', 999  , 'Water St'           , 'Summerside'   , TO_JSON('C'::TEXT))
                     -- Quebec
                     ,('CA', 'QC', 99999, 'Petit-Champlain St' , 'Quebec City'  , TO_JSON('GHJ'::TEXT))
                     ,('CA', 'QC', 99999, 'Sainte-Catherine St', 'Montreal'     , TO_JSON('GHJ'::TEXT))
                     -- Saksatoon
                     ,('CA', 'SK', 999  , 'Broadway Ave'       , 'Saskatoon'    , TO_JSON('S'::TEXT))
                     ,('CA', 'SK', 999  , 'Winnipeg St'        , 'Regina'       , TO_JSON('S'::TEXT))
                     -- Yukon
                     ,('CA', 'YT', 99   , 'Saloon Rd'          , 'Whitehorse'   , TO_JSON('Y'::TEXT))
                     ,('CA', 'YT', 99   , '4th Ave'            , 'Dawson City'  , TO_JSON('Y'::TEXT))

                     -- Christmas Island
                     -- Country, Region, Range, St, City, Single postal code
                     ,('CX', NULL, 99 , 'Lam Lok Loh' , 'Drumsite'        , TO_JSON('6798'::TEXT))
                     ,('CX', NULL, 999, 'Jln Pantai'  , 'Flying Fish Cove', TO_JSON('6798'::TEXT))
                     ,('CX', NULL, 99 , 'San Chye Loh', 'Poon Saan'       , TO_JSON('6798'::TEXT))
                     ,('CX', NULL, 999, 'Sea View Dr' , 'Silver City'     , TO_JSON('6798'::TEXT))

                     -- United States
                     -- Country, Region, Range, St, City, Zip code first 3 digits
                     -- Alabama
                     ,('US', 'AL', 9999  , 'Dexter Ave'         , 'Montgomery'      , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(350, 369) v EXCEPT SELECT 353 ORDER BY 1)))
                     ,('US', 'AL', 9999  , 'Holmes Ave NW'      , 'Huntsville'      , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(350, 369) v EXCEPT SELECT 353 ORDER BY 1)))
                     -- Alaska
                     ,('US', 'AK', 999   , 'South Franklin St'  , 'Juneau'          , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(995, 999) v ORDER BY 1)))
                     ,('US', 'AK', 999   , '2nd Ave'            , 'Fairbanks'       , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(995, 999) v ORDER BY 1)))
                     -- Arizona
                     ,('US', 'AZ', 99999 , 'Van Buren St'       , 'Phoenix'         , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(850, 865) v EXCEPT SELECT UNNEST(ARRAY[854, 858, 861, 862]) ORDER BY 1)))
                     ,('US', 'AZ', 99999 , '2nd Ave'            , 'Fairbanks'       , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(850, 865) v EXCEPT SELECT UNNEST(ARRAY[854, 858, 861, 862]) ORDER BY 1)))
                     -- Arkansas
                     ,('US', 'AR', 99999 , 'Commerce St'        , 'Little Rock'     , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(716, 729) v ORDER BY 1)))
                     ,('US', 'AR', 99999 , 'Dickson St'         , 'Fayetteville'    , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(716, 729) v ORDER BY 1)))
                     -- California
                     ,('US', 'CA', 99999 , 'K St'               , 'Sacramento'      , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(900, 961) v EXCEPT SELECT UNNEST(ARRAY[909, 929]) ORDER BY 1)))
                     ,('US', 'CA', 99999 , 'San Diego Ave'      , 'San Diego'       , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(900, 961) v EXCEPT SELECT UNNEST(ARRAY[909, 929]) ORDER BY 1)))
                     -- Colorado
                     ,('US', 'CO', 99999 , 'East Colfax Ave'    , 'Denver'          , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(800, 816) v ORDER BY 1)))
                     ,('US', 'CO', 99999 , 'Wilcox St'          , 'Castle Rock'     , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(800, 816) v ORDER BY 1)))
                     -- Connecticut
                     ,('US', 'CT', 99999 , 'Pratt St'           , 'Hartford'        , (SELECT JSON_AGG(v) FROM (SELECT '0' || GENERATE_SERIES(60, 69) v ORDER BY 1)))
                     ,('US', 'CT', 99999 , 'Helen St'           , 'Bridgeport'      , (SELECT JSON_AGG(v) FROM (SELECT '0' || GENERATE_SERIES(60, 69) v ORDER BY 1)))
                     -- Delaware
                     ,('US', 'DE', 99999 , 'Division St'        , 'Dover'           , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(197, 199) v ORDER BY 1)))
                     ,('US', 'DE', 99999 , 'Market St'          , 'Wilmington'      , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(197, 199) v ORDER BY 1)))
                     -- District of C0lumbia
                     ,('US', 'DC', 99999 , 'Pennsylvania Ave'   , 'Washington'      , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(200, 205) v EXCEPT SELECT 201 UNION ALL SELECT 569 ORDER BY 1)))
                     ,('US', 'DC', 99999 , '7th St'             , 'Shaw'            , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(200, 205) v EXCEPT SELECT 201 UNION ALL SELECT 569 ORDER BY 1)))
                     -- Florida
                     ,('US', 'FL', 99999 , 'Monroe St'          , 'Tallahassee'     , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(320, 349) v EXCEPT SELECT UNNEST(ARRAY[340, 343, 345, 348]) ORDER BY 1)))
                     ,('US', 'FL', 99999 , 'Laura St'           , 'Jacksonville'    , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(320, 349) v EXCEPT SELECT UNNEST(ARRAY[340, 343, 345, 348]) ORDER BY 1)))
                     -- Georgia
                     ,('US', 'GA', 99999 , 'Peachtree St'       , 'Atlanta'         , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(300, 319) v UNION ALL SELECT UNNEST(ARRAY[398, 399]) ORDER BY 1)))
                     ,('US', 'GA', 99999 , '11th St'            , 'Columbus'        , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(300, 319) v UNION ALL SELECT UNNEST(ARRAY[398, 399]) ORDER BY 1)))
                     -- Hawaii
                     ,('US', 'HI', 999   , 'Kalakaua Ave'       , 'Honolulu'        , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(967, 968) v ORDER BY 1)))
                     ,('US', 'HI', 999   , 'Banyan Dr'          , 'Hilo'            , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(967, 968) v ORDER BY 1)))
                     -- Idaho
                     ,('US', 'ID', 99999 , 'Capitol Blvd'       , 'Boise'           , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(832, 838) v ORDER BY 1)))
                     ,('US', 'ID', 99999 , 'E Pine Ave'         , 'Meridian'        , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(832, 838) v ORDER BY 1)))
                     -- Illinois
                     ,('US', 'IL', 99999 , 'Route 66'           , 'Springfield'     , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(600, 629) v EXCEPT SELECT 621 ORDER BY 1)))
                     ,('US', 'IL', 99999 , 'Michigan Ave'       , 'Chicago'         , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(600, 629) v EXCEPT SELECT 621 ORDER BY 1)))
                     -- Indiana
                     ,('US', 'IN', 99999 , 'Meridian St'        , 'Indianapolis'    , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(460, 479) v ORDER BY 1)))
                     ,('US', 'IN', 99999 , 'Calhoun St'         , 'Fort Wayne'      , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(460, 479) v ORDER BY 1)))
                     -- Iowa
                     ,('US', 'IA', 99999 , 'Court Ave'          , 'Des Moines'      , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(500, 528) v EXCEPT SELECT UNNEST(ARRAY[517, 518, 519]) ORDER BY 1)))
                     ,('US', 'IA', 99999 , 'First Ave'          , 'Cedar Rapids'    , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(500, 528) v EXCEPT SELECT UNNEST(ARRAY[517, 518, 519]) ORDER BY 1)))
                     -- Kansas
                     ,('US', 'KS', 99999 , 'SE 10th Ave'        , 'Topeka'          , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(660, 679) v EXCEPT SELECT 663 ORDER BY 1)))
                     ,('US', 'KS', 99999 , 'S Hydraulic Ave'    , 'Wichita'         , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(660, 679) v EXCEPT SELECT 663 ORDER BY 1)))
                     -- Kentucky
                     ,('US', 'KY', 99999 , 'Holmes St'          , 'Frankfort'       , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(400, 427) v EXCEPT SELECT 419 ORDER BY 1)))
                     ,('US', 'KY', 99999 , 'S Floyd St'         , 'Louisville'      , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(400, 427) v EXCEPT SELECT 419 ORDER BY 1)))
                     -- Louisiana
                     ,('US', 'LA', 99999 , 'Third St'           , 'Baton Rouge'     , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(700, 714) v EXCEPT SELECT UNNEST(ARRAY[702, 709]) ORDER BY 1)))
                     ,('US', 'LA', 99999 , 'Bourbon St'         , 'New Orleans'     , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(700, 714) v EXCEPT SELECT UNNEST(ARRAY[702, 709]) ORDER BY 1)))
                     -- Maine
                     ,('US', 'ME', 99999 , 'Maine St'           , 'Augusta'         , (SELECT JSON_AGG(v) FROM (SELECT '0' || GENERATE_SERIES(39, 49) v ORDER BY 1)))
                     ,('US', 'ME', 99999 , 'Congress St'        , 'Portland'        , (SELECT JSON_AGG(v) FROM (SELECT '0' || GENERATE_SERIES(39, 49) v ORDER BY 1)))
                     -- Maryland
                     ,('US', 'MD', 99999 , 'Bladen St'          , 'Annapolis'       , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(206, 219) v EXCEPT SELECT 213 ORDER BY 1)))
                     ,('US', 'MD', 99999 , 'Charles St'         , 'Baltimore'       , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(206, 219) v EXCEPT SELECT 213 ORDER BY 1)))
                     -- Massachusetts
                     ,('US', 'MA', 99999 , 'Acorn St'           , 'Boston'          , (SELECT JSON_AGG(v) FROM (SELECT '0' || GENERATE_SERIES(10, 27) v UNION ALL SELECT '055' ORDER BY 1)))
                     ,('US', 'MA', 99999 , 'North Water St'     , 'Edgartown'       , (SELECT JSON_AGG(v) FROM (SELECT '0' || GENERATE_SERIES(10, 27) v UNION ALL SELECT '055' ORDER BY 1)))
                     -- Michigan
                     ,('US', 'MI', 99999 , 'W Kalamazoo St'     , 'Lansing'         , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(480, 499) v ORDER BY 1)))
                     ,('US', 'MI', 99999 , 'Woodward Ave'       , 'Detroit'         , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(480, 499) v ORDER BY 1)))
                     -- Minnesota
                     ,('US', 'MN', 99999 , 'Summit Ave'         , 'Saint Paul'      , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(550, 567) v EXCEPT SELECT 552 ORDER BY 1)))
                     ,('US', 'MN', 99999 , 'Nicollet Ave'       , 'Minneapolis'     , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(550, 567) v EXCEPT SELECT 552 ORDER BY 1)))
                     -- Mississippi
                     ,('US', 'MS', 99999 , 'Farish St'          , 'Jackson'         , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(386, 397) v ORDER BY 1)))
                     ,('US', 'MS', 99999 , 'Seaway Rd'          , 'Gulfport'        , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(386, 397) v ORDER BY 1)))
                     -- Missouri
                     ,('US', 'MO', 99999 , 'Capitol Ave'        , 'Jefferson'       , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(630, 658) v EXCEPT SELECT UNNEST(ARRAY[632, 642, 643]) ORDER BY 1)))
                     ,('US', 'MO', 99999 , 'Independence Ave'   , 'Kansas City'     , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(630, 658) v EXCEPT SELECT UNNEST(ARRAY[632, 642, 643]) ORDER BY 1)))
                     -- Montana
                     ,('US', 'MT', 99999 , 'E Lyndale Ave'      , 'Helena'          , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(590, 599) v ORDER BY 1)))
                     ,('US', 'MT', 99999 , 'Clark Ave'          , 'Billings'        , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(590, 599) v ORDER BY 1)))
                     -- Nebraska
                     ,('US', 'NE', 99999 , 'O St'               , 'Lincoln'         , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(680, 693) v EXCEPT SELECT 682 ORDER BY 1)))
                     ,('US', 'NE', 99999 , 'Farnam St'          , 'Omaha'           , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(680, 693) v EXCEPT SELECT 682 ORDER BY 1)))
                     -- Nevada
                     ,('US', 'NV', 99999 , 'E William St'       , 'Carson City'     , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(889, 898) v EXCEPT SELECT UNNEST(ARRAY[892, 896]) ORDER BY 1)))
                     ,('US', 'NV', 99999 , 'Las Vegas Blvd'     , 'Las Vegas'       , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(889, 898) v EXCEPT SELECT UNNEST(ARRAY[892, 896]) ORDER BY 1)))
                     -- New hampshire
                     ,('US', 'NH', 99999 , 'Loudon Rd'          , 'Concord'         , (SELECT JSON_AGG(v) FROM (SELECT '0' || GENERATE_SERIES(30, 38) v ORDER BY 1)))
                     ,('US', 'NH', 99999 , 'Lake Ave'           , 'Manchester'      , (SELECT JSON_AGG(v) FROM (SELECT '0' || GENERATE_SERIES(30, 38) v ORDER BY 1)))
                     -- New Jersey
                     ,('US', 'NJ', 99999 , 'Front St'           , 'Trenton'         , (SELECT JSON_AGG(v) FROM (SELECT '0' || GENERATE_SERIES(70, 89) v ORDER BY 1)))
                     ,('US', 'NJ', 99999 , 'Broad St'           , 'Newark'          , (SELECT JSON_AGG(v) FROM (SELECT '0' || GENERATE_SERIES(70, 89) v ORDER BY 1)))
                     -- New Mexico
                     ,('US', 'NM', 99999 , 'Canyon Rd'          , 'Santa Fe'        , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(870, 884) v EXCEPT SELECT UNNEST(ARRAY[872, 876]) ORDER BY 1)))
                     ,('US', 'NM', 99999 , 'Central Ave'        , 'Albequerque'     , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(870, 884) v EXCEPT SELECT UNNEST(ARRAY[872, 876]) ORDER BY 1)))
                     -- New York
                     ,('US', 'NY', 99999 , 'Lark St'            , 'Albany'          , (SELECT JSON_AGG(v) FROM (SELECT '005' v UNION ALL SELECT v::TEXT FROM GENERATE_SERIES(100, 149) v ORDER BY 1)))
                     ,('US', 'NY', 99999 , 'Broadway'           , 'New York'        , (SELECT JSON_AGG(v) FROM (SELECT '005' v UNION ALL SELECT v::TEXT FROM GENERATE_SERIES(100, 149) v ORDER BY 1)))
                     -- North Carolina
                     ,('US', 'NC', 99999 , 'Fayetteville St'    , 'Raleigh'         , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(270,289) v ORDER BY 1)))
                     ,('US', 'NC', 99999 , 'Tryon Street'       , 'Charlotte'       , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(270,289) v ORDER BY 1)))
                     -- North Dakota
                     ,('US', 'ND', 99999 , '4th St'             , 'Bismarck'        , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(580, 588) v ORDER BY 1)))
                     ,('US', 'ND', 99999 , '13th Ave S'         , 'Fargo'           , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(580, 588) v ORDER BY 1)))
                     -- Ohio
                     ,('US', 'OH', 99999 , 'Broad St'           , 'Columbus'        , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(430, 459) v ORDER BY 1)))
                     ,('US', 'OH', 99999 , 'Vine St'            , 'Cincinnnati'     , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(430, 459) v ORDER BY 1)))
                     -- Oklahoma
                     ,('US', 'OK', 99999 , 'Reno Ave'           , 'Oklahoma City'   , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(730, 749) v EXCEPT SELECT UNNEST(ARRAY[732, 733, 742]) ORDER BY 1)))
                     ,('US', 'OK', 99999 , 'S Zenith ave'       , 'Tulsa'           , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(730, 749) v EXCEPT SELECT UNNEST(ARRAY[732, 733, 742]) ORDER BY 1)))
                     -- Oregon
                     ,('US', 'OR', 99999 , 'Chestnut St'        , 'Salem'           , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(970, 979) v ORDER BY 1)))
                     ,('US', 'OR', 99999 , 'Wall St'            , 'Bend'            , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(970, 979) v ORDER BY 1)))
                     -- Pennsylvania
                     ,('US', 'PA', 99999 , 'State St'           , 'Harrisburg'      , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(150, 196) v ORDER BY 1)))
                     ,('US', 'PA', 99999 , 'South St'           , 'Philadelphia'    , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(150, 196) v ORDER BY 1)))
                     -- Rhode Island
                     ,('US', 'RI', 999   , 'Hope St'            , 'Providence'      , (SELECT JSON_AGG(v) FROM (SELECT '0' || GENERATE_SERIES(28, 29) v ORDER BY 1)))
                     ,('US', 'RI', 999   , 'Phenix Ave'         , 'Cranston'        , (SELECT JSON_AGG(v) FROM (SELECT '0' || GENERATE_SERIES(28, 29) v ORDER BY 1)))
                     -- South Carolina
                     ,('US', 'SC', 99999 , 'Gervais St'         , 'Columbia'        , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(290, 299) v ORDER BY 1)))
                     ,('US', 'SC', 99999 , 'King St'            , 'Charleston'      , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(290, 299) v ORDER BY 1)))
                     -- South Dakota
                     ,('US', 'SD', 99999 , 'N Taylor Ave'       , 'Pierre'          , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(570, 577) v ORDER BY 1)))
                     ,('US', 'SD', 99999 , 'Ladyslipper Cir'    , 'Sioux Falls'     , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(570, 577) v ORDER BY 1)))
                     -- Tennessee
                     ,('US', 'TN', 99999 , 'Edgehill Ave'       , 'Nashville'       , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(370, 385) v ORDER BY 1)))
                     ,('US', 'TN', 99999 , 'Spottswood Ave'     , 'Memphis'         , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(370, 385) v ORDER BY 1)))
                     -- Texas
                     ,('US', 'TX', 99999 , 'Sixth St'           , 'Austin'          , (SELECT JSON_AGG(v::TEXT) FROM (SELECT 733 v UNION ALL SELECT GENERATE_SERIES(750, 799) EXCEPT SELECT 771 UNION ALL SELECT 885 ORDER BY 1)))
                     ,('US', 'TX', 99999 , 'Westheimeer Rd'     , 'Houston'         , (SELECT JSON_AGG(v::TEXT) FROM (SELECT 733 v UNION ALL SELECT GENERATE_SERIES(750, 799) EXCEPT SELECT 771 UNION ALL SELECT 885 ORDER BY 1)))
                     -- Utah
                     ,('US', 'UT', 99999 , 'Poplar Grove Vlvd S', 'Salt Lake City'  , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(840, 847) v ORDER BY 1)))
                     ,('US', 'UT', 99999 , 'Nancy Dr'           , 'West Valley City', (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(840, 847) v ORDER BY 1)))
                     -- Vermont
                     ,('US', 'VT', 99999 , 'Towne Hill Rd'      , 'Montpelier'      , (SELECT JSON_AGG(v) FROM (SELECT '0' || GENERATE_SERIES(50, 59) v EXCEPT SELECT '055' ORDER BY 1)))
                     ,('US', 'VT', 99999 , 'N Willard St'       , 'Burlington'      , (SELECT JSON_AGG(v) FROM (SELECT '0' || GENERATE_SERIES(50, 59) v EXCEPT SELECT '055' ORDER BY 1)))
                     -- Virginia
                     ,('US', 'VA', 99999 , 'Monument Ave'       , 'Richmond'        , (SELECT JSON_AGG(v::TEXT) FROM (SELECT 201 v UNION ALL SELECT GENERATE_SERIES(220, 246) ORDER BY 1)))
                     ,('US', 'VA', 99999 , 'Atlantic Ave'       , 'Virginia Beach'  , (SELECT JSON_AGG(v::TEXT) FROM (SELECT 201 v UNION ALL SELECT GENERATE_SERIES(220, 246) ORDER BY 1)))
                     -- Washington
                     ,('US', 'WA', 99999 , 'Union Ave SE'       , 'Olympia'         , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(980, 994) v EXCEPT SELECT 987 ORDER BY 1)))
                     ,('US', 'WA', 99999 , 'Pike St'            , 'Seattle'         , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(980, 994) v EXCEPT SELECT 987 ORDER BY 1)))
                     -- West Virginia
                     ,('US', 'WV', 99999 , 'Quarrier St'        , 'Charleston'      , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(247, 268) v ORDER BY 1)))
                     ,('US', 'WV', 99999 , 'Buffington Ave'     , 'Huntington'      , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(247, 268) v ORDER BY 1)))
                     -- Wisconsin
                     ,('US', 'WI', 99999 , 'N Bassett St'       , 'Madison'         , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(530, 549) v EXCEPT SELECT UNNEST(ARRAY[533, 536]) ORDER BY 1)))
                     ,('US', 'WI', 99999 , 'Brady St'           , 'Milwaukee'       , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(530, 549) v EXCEPT SELECT UNNEST(ARRAY[533, 536]) ORDER BY 1)))
                     -- Wyoming
                     ,('US', 'WY', 99999 , 'Evans Ave'          , 'Cheyenne'        , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(820, 831) v ORDER BY 1)))
                     ,('US', 'WY', 99999 , 'W Collins Dr'       , 'Casper'          , (SELECT JSON_AGG(v::TEXT) FROM (SELECT GENERATE_SERIES(820, 831) v ORDER BY 1)))
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
                     ,('US', 'PU', 999   , 'C Aragón'           , 'San Juan'        , (SELECT JSON_AGG(v) FROM (SELECT '00' || GENERATE_SERIES(6, 9) v EXCEPT SELECT '008' ORDER BY 1)))
                     ,('US', 'PU', 999   , 'Ave Hostos'         , 'Bayamón'         , (SELECT JSON_AGG(v) FROM (SELECT '00' || GENERATE_SERIES(6, 9) v EXCEPT SELECT '008' ORDER BY 1)))
                     -- Virgin Islands
                     ,('US', 'VI', 99    , 'Harbour Ridge Rd'   , 'Charlotte Amalie', '["008"]')
                     ,('US', 'VI', 99    , 'Alfred Andrews St'  , 'St Croix'        , '["008"]')
                      ) as d(
                        Country, Region, Range, St, City, Prefix
                      )
             GROUP BY Country
            ) d
)
-- SELECT * FROM ADDRESS_DATA;
, ADD_PERSON_NAMES AS (
    SELECT *
          ,ARRAY[[
               'Anna'
              ,'Britney'
              ,'Christie'
              ,'Denise'
              ,'Elen'
              ,'Fatima'
              ,'Gale'
              ,'Haley'
              ,'Isabel'
              ,'Jenny'
              ,'Kristen'
              ,'Lisa'
              ,'Mona'
              ,'Nancy'
              ,'Oprah'
              ,'Patsy'
              ,'Queenie'
              ,'Roberta'
              ,'Selena'
              ,'Tina'
              ,'Ursula'
              ,'Victoria'
              ,'Wendy'
              ,'Xena'
              ,'Yolanda'
              ,'Zoey'
             ],[
               'Alfred'
              ,'Bob'
              ,'Caleb'
              ,'Denny'
              ,'Edward'
              ,'Fred'
              ,'Glen'
              ,'Howard'
              ,'Indiana'
              ,'James'
              ,'Karl'
              ,'Leonard'
              ,'Michael'
              ,'Norman'
              ,'Oliver'
              ,'Patrick'
              ,'Quentin'
              ,'Ramsey'
              ,'Silas'
              ,'Tim'
              ,'Umar'
              ,'Victor'
              ,'William'
              ,'Xavier'
              ,'Yakov'
              ,'Zachary'
             ]] AS FIRST_MIDDLE_NAMES
          , ARRAY[
               'Adair'
              ,'Adams'
              ,'Adley'
              ,'Anderson'
              ,'Ashley'
              ,'Bardot'
              ,'Beckett'
              ,'Carter'
              ,'Cassidy'
              ,'Collymore'
              ,'Crassus'
              ,'Cromwell'
              ,'Curran'
              ,'Daughtler'
              ,'Dawson'
              ,'Ellis'
              ,'Elsher'
              ,'Finnegan'
              ,'Ford'
              ,'Gasper'
              ,'Gatlin'
              ,'Gonzales'
              ,'Gray'
              ,'Hansley'
              ,'Hayes'
              ,'Hendrix'
              ,'Hope'
              ,'Huxley'
              ,'Jenkins'
              ,'Keller'
              ,'Langley'
              ,'Ledger'
              ,'Levine'
              ,'Lennon'
              ,'Lopez'
              ,'Madison'
              ,'Marley'
              ,'McKenna'
              ,'Monroe'
              ,'Pierce'
              ,'Poverly'
              ,'Raven'
              ,'Solace'
              ,'St. James'
              ,'Stoll'
              ,'Thatcher'
              ,'Verlice'
              ,'West'
              ,'Wilson'
              ,'Zimmerman'
             ] AS LAST_NAMES
      FROM PARAMS
)
-- SELECT * FROM ADD_PERSON_NAMES;
, ADD_BUSINESS_NAMES AS (
    SELECT *
          ,ARRAY[
               '9 Yards Media'
              ,'Aceable, Inc.'
              ,'Aims Community College'
              ,'Bent Out of Shape Jewelry'
              ,'Compass Mortgage'
              ,'Everything But Anchovies'
              ,'Exela Movers'
              ,'Ibotta, Inc.'
              ,'Intrepid Travel'
              ,'Kaboom Fireworks'
              ,'Light As a Feather'
              ,'Like You Mean It Productions'
              ,'Marathon Physical Therapy'
              ,'More Than Words'
              ,'Percepta Security'
              ,'Semicolon Bookstore'
              ,'Soft As a Grape'
              ,'To Each Their Own, LLC'
              ,'Top It Off'
              ,'Twisters Gymnastics Academy'
              ,'Wanderu'
              ,'What You Will Yoga'
              ,'When Pigs Fly'
             ] AS BUSINESS_NAMES
      FROM ADD_PERSON_NAMES
)
-- SELECT * FROM ADD_BUSINESS_NAMES;
, GEN_IS_PERSONAL AS (
    SELECT *
          ,managed_code.RANDOM_INT(1, 100) <= 85 AS IS_PERSONAL
          ,generate_series(1, NUM_CUSTOMERS)     AS ROW_NUM
      FROM ADD_BUSINESS_NAMES
  )
-- SELECT * FROM GEN_IS_PERSONAL;
, GEN_ROW_LINK AS (
    SELECT *
          ,ROW_NUMBER() OVER (PARTITION BY IS_PERSONAL ORDER BY ROW_NUM) AS ROW_LINK
      FROM GEN_IS_PERSONAL
  )
-- SELECT * FROM GEN_ROW_LINK;
, GEN_PERSONAL_HAS_ADDRESS AS (
    SELECT *
          ,managed_code.RANDOM_INT(1, 100) <= 90 AS PERSONAL_HAS_ADDRESS
      FROM GEN_ROW_LINK
     WHERE IS_PERSONAL
  )
-- SELECT * FROM GEN_PERSONAL_HAS_ADDRESS;
, GEN_PERSONAL_NAME_IDX AS (
    SELECT *
          ,managed_code.RANDOM_INT(1, 2) AS GENDER_IDX
          ,managed_code.RANDOM_INT(1, ARRAY_LENGTH(FIRST_MIDDLE_NAMES, 2)) AS FIRST_NAME_IDX
          ,managed_code.RANDOM_INT(0, ARRAY_LENGTH(FIRST_MIDDLE_NAMES, 2)) AS MIDDLE_NAME_IDX
      FROM GEN_PERSONAL_HAS_ADDRESS
  )
-- SELECT * FROM GEN_PERSONAL_NAME_IDX;
, GEN_ADJ_MIDDLE_NAME_IDX AS (
    SELECT *
          ,managed_code.IIF(
             FIRST_NAME_IDX = MIDDLE_NAME_IDX
            ,managed_code.IIF(MIDDLE_NAME_IDX = 1, 2, MIDDLE_NAME_IDX - 1)
            ,MIDDLE_NAME_IDX
           ) AS ADJ_MIDDLE_NAME_IDX
      FROM GEN_PERSONAL_NAME_IDX
  )
-- SELECT * FROM GEN_ADJ_MIDDLE_NAME_IDX;
, GEN_FIRST_MIDDLE_LAST_NAMES AS (
    SELECT *
          ,FIRST_MIDDLE_NAMES[GENDER_IDX][FIRST_NAME_IDX]                      AS FIRST_NAME
          ,FIRST_MIDDLE_NAMES[GENDER_IDX][ADJ_MIDDLE_NAME_IDX]                 AS MIDDLE_NAME
          ,LAST_NAMES[managed_code.RANDOM_INT(1, ARRAY_LENGTH(LAST_NAMES, 1))] AS LAST_NAME
      FROM GEN_ADJ_MIDDLE_NAME_IDX
  )
-- SELECT * FROM GEN_FIRST_MIDDLE_LAST_NAMES;
, GEN_PERSON_DESC AS (
    SELECT *
          ,FIRST_NAME || COALESCE(' ' || MIDDLE_NAME, '') || ' ' || LAST_NAME AS DESCRIPTION
      FROM GEN_FIRST_MIDDLE_LAST_NAMES
  )
-- SELECT * FROM GEN_PERSON_DESC;
, I_CUSTOMER_PERSON AS (
    INSERT INTO managed_tables.customer_person(
           relid
          ,version
          ,description
          ,terms
          ,created
          ,modified
          ,first_name
          ,middle_name
          ,last_name
         )
    SELECT NEXTVAL('managed_tables.base_seq')
          ,1
          ,DESCRIPTION
          ,TO_TSVECTOR('english', DESCRIPTION)
          ,INS_TIMESTAMP
          ,INS_TIMESTAMP
          ,FIRST_NAME
          ,MIDDLE_NAME
          ,LAST_NAME
      FROM GEN_PERSON_DESC
    RETURNING relid
  )
-- SELECT * FROM I_CUSTOMER_PERSON;
, GEN_BUSINESS_NAME AS (
    SELECT *
          ,BUSINESS_NAMES[managed_code.RANDOM_INT(1, ARRAY_LENGTH(BUSINESS_NAMES, 1))] AS BUSINESS_NAME
      FROM GEN_ROW_LINK
     WHERE NOT IS_PERSONAL
  )
-- SELECT * FROM GEN_BUSINESS_NAME;
, I_CUSTOMER_BUSINESS AS (
    INSERT INTO managed_tables.customer_business(
           relid
          ,version
          ,description
          ,terms
          ,created
          ,modified
          ,name
         )
    SELECT NEXTVAL('managed_tables.base_seq')
          ,1
          ,BUSINESS_NAME
          ,TO_TSVECTOR('english', BUSINESS_NAME)
          ,INS_TIMESTAMP
          ,INS_TIMESTAMP
          ,BUSINESS_NAME
      FROM GEN_BUSINESS_NAME
    RETURNING relid
  )
-- SELECT * FROM I_CUSTOMER_BUSINESS;
, GEN_PERSONAL_COUNTRY_IDX AS (
    SELECT *
          ,managed_code.RANDOM_INT(
             0
            ,JSON_ARRAY_LENGTH((SELECT d FROM ADDRESS_DATA)) - 1
           ) country_idx
      FROM GEN_PERSONAL_HAS_ADDRESS gpha
     WHERE IS_PERSONAL
     ORDER BY ROW_LINK
)
-- SELECT * FROM GEN_PERSONAL_COUNTRY_IDX;
, GEN_PERSONAL_REGION_IDX AS (
    SELECT *
          ,managed_code.RANDOM_INT(
             0
            ,JSON_ARRAY_LENGTH((SELECT d FROM ADDRESS_DATA) -> country_idx) - 1
           ) region_idx
      FROM GEN_PERSONAL_COUNTRY_IDX
)
-- SELECT * FROM GEN_PERSONAL_REGION_IDX;
, GEN_PERSONAL_COUNTRY_REGION AS (
    SELECT *
          ,(SELECT d FROM ADDRESS_DATA) -> country_idx -> region_idx AS country_region
      FROM GEN_PERSONAL_REGION_IDX
)
-- SELECT * FROM GEN_PERSONAL_COUNTRY_REGION;
, GEN_PERSONAL_CIVIC_ST_CITY AS (
    SELECT *
          ,country_region ->> 'country' AS Country
          ,country_region ->> 'region'  AS Region
          ,managed_code.RANDOM_INT(1, (country_region ->> 'range')::INT) AS Civic
          ,country_region ->> 'st' AS Street
          ,country_region ->> 'city' AS City
          ,country_region -> 'prefix' AS Prefix -- Keep Prefix value as JSON
      FROM GEN_PERSONAL_COUNTRY_REGION
)
-- SELECT * FROM GEN_PERSONAL_CIVIC_ST_CITY
, GEN_PERSONAL_ADDRESS AS (
    SELECT Country
          ,Region
          ,Street
          ,Civic
          ,Prefix
          ,NULL AS address_type_relid
          ,managed_code.RANDOM_INT(1, 100) >= 6 has_address
          ,c.relid AS country_relid
          ,r.relid AS region_relid
          ,gpcsc.City AS city
          ,CASE Country
           WHEN 'AW' THEN
                Street || ' ' || Civic ||
                CASE
                WHEN managed_code.RANDOM_INT(1, 100) <= 15 THEN
                     ' ' ||
                     (ARRAY['Apt', 'Suite'])[managed_code.RANDOM_INT(1, 2)] ||
                     ' ' ||
                     managed_code.RANDOM_INT(1, 9999)
                ELSE ''
                END
           ELSE CASE
                WHEN managed_code.RANDOM_INT(1, 100) <= 15 THEN
                     (ARRAY['Apt', 'Suite'])[managed_code.RANDOM_INT(1, 2)] ||
                     ' ' ||
                     managed_code.RANDOM_INT(1, 9999) ||
                     ' '
                ELSE ''
                END ||
                gpcsc.Civic  || ' ' || gpcsc.Street
            END AS address
          ,NULL AS address_2
          ,NULL AS address_3
          ,CASE Country
           WHEN 'CA' THEN
                managed_code.RANDOM_CHAR(Prefix #>> '{}') ||
                CHR(ASCII('0') + managed_code.RANDOM_INT(0, 9)) ||
                CHR(ASCII('A') + managed_code.RANDOM_INT(0, 25)) ||
                ' ' ||
                CHR(ASCII('A') + managed_code.RANDOM_INT(0, 25)) ||
                CHR(ASCII('0') + managed_code.RANDOM_INT(0, 9)) ||
                CHR(ASCII('A') + managed_code.RANDOM_INT(0, 25))
           WHEN 'US' THEN
                Prefix ->> managed_code.RANDOM_INT(0, JSON_ARRAY_LENGTH(Prefix) - 1) ||
                CHR(ASCII('0') + managed_code.RANDOM_INT(0, 9)) ||
                CHR(ASCII('0') + managed_code.RANDOM_INT(0, 9)) ||
                CASE
                WHEN managed_code.RANDOM_INT(1, 100) <= 10 THEN
                     '-' ||
                     CHR(ASCII('0') + managed_code.RANDOM_INT(0, 9)) ||
                     CHR(ASCII('0') + managed_code.RANDOM_INT(0, 9)) ||
                     CHR(ASCII('0') + managed_code.RANDOM_INT(0, 9)) ||
                     CHR(ASCII('0') + managed_code.RANDOM_INT(0, 9))
                ELSE ''
                END
           ELSE Prefix #>> '{}' -- Aruba = NULL, Christmas Island = 6798
           END AS mailing_code
      FROM GEN_PERSONAL_CIVIC_ST_CITY gpcsc
      JOIN managed_tables.country c
        ON c.code_2 = gpcsc.Country
      LEFT JOIN managed_tables.region r
        ON r.code = gpcsc.Region
)
SELECT * FROM GEN_PERSONAL_ADDRESS;
, ADD_PERSONAL_ADDRESS_DESC AS (
    SELECT *
          , CASE Country
            WHEN ''

      FROM GEN_PERSONAL_ADDRESS
)
, I_CUSTOMER_PERSON_ADDRESS AS (
  INSERT INTO managed_tables.address(
         relid
        ,version
        ,description
        ,terms
        ,created
        ,modified
        ,country_relid
        ,region_relid
        ,city
        ,address
        ,mailing_code
       )
  SELECT NEXTVAL('managed_tables.base_seq')
        ,1
        ,
SELECT 1;

ALTER TABLE managed_tables.customer_person   ENABLE TRIGGER ALL;
ALTER TABLE managed_tables.customer_business ENABLE TRIGGER ALL;
