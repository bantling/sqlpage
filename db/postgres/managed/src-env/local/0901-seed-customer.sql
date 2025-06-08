-- Generate customers the fast way, using CTEs
WITH PARAMS AS (
  SELECT ${PG_MANAGED_NUM_SEED_CUSTOMERS} AS NUM_CUSTOMERS
   WHERE (SELECT COUNT(*) FROM managed_tables.address)           = 0
     AND (SELECT COUNT(*) FROM managed_tables.customer_person)   = 0
     AND (SELECT COUNT(*) FROM managed_tables.customer_business) = 0
)
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
             ], [
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
             ]]::TEXT[][] AS FIRST_MIDDLE_NAMES
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
              ]::TEXT[] AS LAST_NAMES
      FROM PARAMS
)
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
, GEN_IS_PERSONAL AS (
    SELECT *
          ,managed_code.RANDOM_INT(1, 100) <= 85 AS IS_PERSONAL
          ,generate_series(1, NUM_CUSTOMERS) AS ROW_LINK
      FROM ADD_BUSINESS_NAMES
  )
 ,GEN_PERSONAL_HAS_ADDRESS AS (
    SELECT *
          ,managed_code.RANDOM_INT(1, 100) <= 90 AS PERSONAL_HAS_ADDRESS
      FROM GEN_IS_PERSONAL
     WHERE IS_PERSONAL
  )
 ,GEN_PERSONAL_NAME_IDX AS (
    SELECT *
          ,managed_code.RANDOM_INT(1, 2) AS GENDER_IDX
          ,managed_code.RANDOM_INT(1, ARRAY_LENGTH(FIRST_MIDDLE_NAMES, 2)) AS FIRST_NAME_IDX
          ,managed_code.RANDOM_INT(0, ARRAY_LENGTH(FIRST_MIDDLE_NAMES, 2)) AS MIDDLE_NAME_IDX
      FROM GEN_PERSONAL_HAS_ADDRESS
  )
 ,GEN_ADJUST_MIDDLE_NAME_IDX AS (
    SELECT *
          ,managed_code.IIF(
             FIRST_NAME_IDX = MIDDLE_NAME_IDX
            ,managed_code.IIF(MIDDLE_NAME_IDX = 1, 2, MIDDLE_NAME_IDX - 1)
            ,MIDDLE_NAME_IDX
           ) AS ADJ_MIDDLE_NAME_IDX
      FROM GEN_PERSONAL_NAME_IDX
  )
 ,GEN_FIRST_MIDDLE_LAST_NAMES AS (
    SELECT *
          ,FIRST_MIDDLE_NAMES[GENDER_IDX][FIRST_NAME_IDX] AS FIRST_NAME
          ,managed_code.IIF(
             ADJ_MIDDLE_NAME_IDX > 0
            ,FIRST_MIDDLE_NAMES[GENDER_IDX][ADJ_MIDDLE_NAME_IDX]
            ,NULL
           ) AS MIDDLE_NAME
          ,LAST_NAMES[managed_code.RANDOM_INT(1, ARRAY_LENGTH(LAST_NAMES, 1))] AS LAST_NAME
      FROM GEN_ADJUST_MIDDLE_NAME_IDX
  )
  ,I_CUSTOMER_PERSON AS (
    INSERT INTO managed_tables.customer_person(
           description
          ,address_relid
          ,first_name
          ,middle_name
          ,last_name
         )
    SELECT FIRST_NAME || COALESCE(' ' || MIDDLE_NAME, '') || ' ' || LAST_NAME
          ,NULL
          ,FIRST_NAME
          ,MIDDLE_NAME
          ,LAST_NAME
      FROM GEN_FIRST_MIDDLE_LAST_NAMES
    RETURNING relid
  )
SELECT * FROM I_CUSTOMER_PERSON;
