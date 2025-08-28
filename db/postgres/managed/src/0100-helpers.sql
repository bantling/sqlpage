-- Helper functions that could be used in table definitions, views, or code

---------------------------------------------------------------------------------------------------
-- TEST(TEXT, BOOLEAN): test that a condition succeeded for cases where no exception is raised
--   P_MSG : string exception message if the test failed (cannot be null or empty)
--   P_TEST: true if test succeeded, null or false if it failed
-- 
-- Returns true if the condition is true, else it raises an exception with the given error message
-- It is a function so it can be used in select, making it easy and useful for unit tests
CREATE OR REPLACE FUNCTION managed_code.TEST(P_MSG TEXT, P_TEST BOOLEAN) RETURNS BOOLEAN AS
$$
BEGIN
  CASE
    WHEN LENGTH(COALESCE(P_MSG, '')) = 0 THEN
      RAISE EXCEPTION 'P_MSG cannot be null or empty';

    WHEN P_TEST IS DISTINCT FROM TRUE THEN
      RAISE EXCEPTION '%', P_MSG;

    ELSE
      RETURN TRUE;
  END CASE;
END;
$$ LANGUAGE PLPGSQL IMMUTABLE;

-- TEST(TEXT, TEXT): test a function for a case that raises an exception
--   P_ERR   : expected exception text (cannot be null or empty)
--   P_QUERY : string query to execute (cannot be null or empty)
-- 
-- Returns true if executing P_QUERY raises an exception with message P_ERR
-- It is a function so it can be used in select, making it easy and useful for unit tests
-- If the query does not fail, or fails with a different exception message, then
-- an exception is raised with P_ERR and P_QUERY in the text
CREATE OR REPLACE FUNCTION managed_code.TEST(P_ERR TEXT, P_QUERY TEXT) RETURNS BOOLEAN AS
$$
DECLARE
  V_ERR  TEXT;
  V_DIED BOOLEAN;
BEGIN
  -- P_ERR cannot be NULL or EMPTY
  IF LENGTH(COALESCE(P_ERR, '')) = 0 THEN
    RAISE EXCEPTION 'P_ERR cannot be null or empty';
  END IF;
  
  -- P_QUERY cannot be NULL or EMPTY
  IF LENGTH(COALESCE(P_QUERY, '')) = 0 THEN
    RAISE EXCEPTION 'P_QUERY cannot be null or empty';
  END IF;

  BEGIN
    -- Execute the call
    V_DIED := TRUE;
    EXECUTE P_QUERY;
    V_DIED := FALSE;
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS V_ERR = MESSAGE_TEXT;
  END;
  
  CASE
    -- Did an exception occur?
    WHEN NOT V_DIED
    THEN RAISE EXCEPTION 'Expected exception ''%'' did not occur', P_ERR;
  
    -- If an exception is expected, does it have the right text?
    WHEN NOT V_ERR = P_ERR
    THEN RAISE EXCEPTION 'The expected exception message ''%'' does not match the actual message ''%'' for ''%''', P_ERR, V_ERR, P_QUERY;
    
    ELSE NULL;
  END CASE;
  
  -- Success
  RETURN TRUE;
END;
$$ LANGUAGE PLPGSQL;

-- Test TEST(P_MSG, P_TEST)
DO $$
DECLARE
  V_DIED BOOLEAN;
  V_MSG  TEXT;
BEGIN
  BEGIN
    V_DIED := TRUE;
    SELECT managed_code.TEST(NULL, NULL::BOOLEAN); -- Cast NULL to boolean to force postgres into using boolean overload
    V_DIED := FALSE;
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS V_MSG = MESSAGE_TEXT;
      IF NOT V_MSG = 'P_MSG cannot be null or empty' THEN
        RAISE EXCEPTION 'managed_code.TEST must die with P_MSG cannot be null or empty';
      END IF;  
  END;
  IF NOT V_DIED THEN
    RAISE EXCEPTION 'managed_code.TEST must die when P_MSG is NULL';
  END IF;
  
  BEGIN
    V_DIED := TRUE;
    SELECT managed_code.TEST('', NULL::BOOLEAN);
    V_DIED := FALSE;
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS V_MSG = MESSAGE_TEXT;
      IF NOT V_MSG = 'P_MSG cannot be null or empty' THEN
        RAISE EXCEPTION 'managed_code.TEST must die with P_MSG cannot be null or empty';
      END IF;  
  END;
  IF NOT V_DIED THEN
    RAISE EXCEPTION 'managed_code.TEST must die when P_MSG is empty';
  END IF;
  
  BEGIN
    V_DIED := TRUE;
    SELECT managed_code.TEST('TEST', NULL::BOOLEAN);
    V_DIED := FALSE;
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS V_MSG = MESSAGE_TEXT;
      IF NOT V_MSG = 'TEST' THEN
        RAISE EXCEPTION 'managed_code.TEST must die with P_MSG when P_TEST is null';
      END IF;  
  END;
  IF NOT V_DIED THEN
    RAISE EXCEPTION 'managed_code.TEST must die when P_TEST is null';
  END IF;
  
  BEGIN
    V_DIED := TRUE;
    SELECT managed_code.TEST('TEST', FALSE);
    V_DIED := FALSE;
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS V_MSG = MESSAGE_TEXT;
      IF NOT V_MSG = 'TEST' THEN
        RAISE EXCEPTION 'managed_code.TEST must die with P_MSG when P_TEST is false';
      END IF;  
  END;
  IF NOT V_DIED THEN
    RAISE EXCEPTION 'managed_code.TEST must die when P_TEST is false';
  END IF;
  
  BEGIN
    IF NOT managed_code.TEST('TEST', TRUE) THEN
      RAISE EXCEPTION 'managed_code.TEST must succeed when P_TEST is true';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE EXCEPTION 'managed_code.TEST must not die when P_TEST is true';
  END;
END;
$$ LANGUAGE PLPGSQL;

-- Test TEST(P_ERR, P_QUERY)
DO $$
DECLARE
  V_DIED BOOLEAN;
  V_ERR  TEXT;
  V_MSG TEXT;
  V_RES  TEXT;
BEGIN
  -- P_ERR cannot be null
  BEGIN
    V_DIED := TRUE;
    SELECT managed_code.TEST(NULL, NULL::TEXT); -- Cast NULL to text to force postgres into using text overload
    V_DIED := FALSE;
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS V_MSG = MESSAGE_TEXT;
      IF NOT V_MSG = 'P_ERR cannot be null or empty' THEN
        RAISE EXCEPTION 'managed_code.TEST must die with P_MSG cannot be null or empty';
      END IF;
  END;
  IF NOT V_DIED THEN
    RAISE EXCEPTION 'managed_code.TEST must die when P_MSG is NULL';
  END IF;
  
  -- P_ERR cannot be empty
  BEGIN
    V_DIED := TRUE;
    SELECT managed_code.TEST('', NULL::TEXT);
    V_DIED := FALSE;
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS V_MSG = MESSAGE_TEXT;
      IF NOT V_MSG = 'P_ERR cannot be null or empty' THEN
        RAISE EXCEPTION 'managed_code.TEST must die with P_MSG cannot be null or empty';
      END IF;
  END;
  IF NOT V_DIED THEN
    RAISE EXCEPTION 'managed_code.TEST must die when P_MSG is empty';
  END IF;
  
  -- P_QUERY cannot be null
  BEGIN
    V_DIED := TRUE;
    SELECT managed_code.TEST('ERR', NULL::TEXT);
    V_DIED := FALSE;
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS V_MSG = MESSAGE_TEXT;
      IF NOT V_MSG = 'P_QUERY cannot be null or empty' THEN
        RAISE EXCEPTION 'managed_code.TEST must die with P_QUERY cannot be null or empty';
      END IF;
  END;
  IF NOT V_DIED THEN
    RAISE EXCEPTION 'managed_code.TEST must die when P_QUERY is NULL';
  END IF;
  
  -- P_QUERY cannot be empty
  BEGIN
    V_DIED := TRUE;
    SELECT managed_code.TEST('ERR', '');
    V_DIED := FALSE;
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS V_MSG = MESSAGE_TEXT;
      IF NOT V_MSG = 'P_QUERY cannot be null or empty' THEN
        RAISE EXCEPTION 'managed_code.TEST must die with P_QUERY cannot be null or empty';
      END IF;
  END;
  IF NOT V_DIED THEN
    RAISE EXCEPTION 'managed_code.TEST must die when P_QUERY is empty';
  END IF;
  
  -- Test error calling COALESCE(), where the error message provided IS correct
  BEGIN
    SELECT managed_code.TEST('syntax error at or near ")"', 'SELECT COALESCE()') INTO V_RES;
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS V_MSG = MESSAGE_TEXT;
      RAISE EXCEPTION 'managed_code.TEST COALESCE() died when we provided correct error message: %', V_MSG;
  END;
  
  -- Test error calling COALESCE(), where the error message provided IS NOT correct
  BEGIN
    V_DIED := TRUE;
    SELECT managed_code.TEST('wrong error message', 'SELECT COALESCE()') INTO V_RES;
    V_DIED := FALSE;
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS V_MSG = MESSAGE_TEXT;
      IF NOT V_MSG = 'The expected exception message ''wrong error message'' does not match the actual message ''syntax error at or near ")"'' for ''SELECT COALESCE()''' THEN
        RAISE EXCEPTION 'managed_code.TEST COALESCE() with wrong error message did not return expected error message: %', V_MSG;
      END IF;
  END;
  IF NOT V_DIED THEN
    RAISE EXCEPTION 'managed_code.TEST must die when COALESCE() fails and we provided wrong error message';
  END IF;
END;
$$ LANGUAGE PLPGSQL;
---------------------------------------------------------------------------------------------------




---------------------------------------------------------------------------------------------------
-- IIF: A polymorphic function some other vendors have that Postgres lacks
--   P_EXPR     : A boolean expression
--   P_TRUE_VAL : value to return if P_EXPR is true
--   P_FALSE_VAL: value to return if P_EXPR is false or null
--
-- Returns:
--   NULL                            if P_EXPR IS NULL
--   P_TRUE_VAL  (which may be null) if P_EXPR is true
--   P_FALSE_VAL (which may be null) if P_EXPR is false
--
CREATE OR REPLACE FUNCTION managed_code.IIF(P_EXPR BOOLEAN, P_TRUE_VAL ANYELEMENT, P_FALSE_VAL ANYELEMENT) RETURNS ANYELEMENT AS
$$
  SELECT CASE
           WHEN P_EXPR IS NULL THEN NULL
           WHEN P_EXPR         THEN P_TRUE_VAL
           ELSE                     P_FALSE_VAL
         END;
$$ LANGUAGE SQL IMMUTABLE LEAKPROOF PARALLEL SAFE;

-- Test IIF
SELECT *
  FROM (
    SELECT managed_code.TEST(format('managed_code.IIF(%s, %s, %s) must return %s', expr, tval, fval, res), managed_code.IIF(expr, tval, fval) IS NOT DISTINCT FROM res)
      FROM (VALUES
              (NULL , 'a' , 'b' , NULL)

             ,(TRUE , NULL, NULL, NULL)
             ,(FALSE, NULL, NULL, NULL)

             ,(TRUE , NULL, 'b' , NULL)
             ,(FALSE, NULL, 'b' , 'b' )
             
             ,(TRUE , 'a', NULL , 'a' )
             ,(FALSE, 'a', NULL , NULL)
             
             ,(TRUE , 'a', 'b'  , 'a' )
             ,(FALSE, 'a', 'b'  , 'b' )
           ) AS t (expr, tval, fval, res)
  ) t;
---------------------------------------------------------------------------------------------------




---------------------------------------------------------------------------------------------------
-- NEMPTY_WS: a version of CONCAT_WS that treats empty strings like nulls, and coalesces consecutive empty/nulls
-- P_SEP    : The separator string
-- P_STRS   : The strings to place a separator between
--
-- Returns each non-null non-empty string in P_STRS, separated by P_SEP
-- Unlike CONCAT_WS, the nulls and empty strings are removed first, eliminating consecutive separators 
CREATE OR REPLACE FUNCTION managed_code.NEMPTY_WS(P_SEP TEXT, P_STRS VARIADIC TEXT[]) RETURNS TEXT AS
$$
  SELECT STRING_AGG(strs, P_SEP)
    FROM (SELECT UNNEST(P_STRS) strs) t
   WHERE LENGTH(COALESCE(strs, '')) > 0
$$ LANGUAGE SQL IMMUTABLE LEAKPROOF PARALLEL SAFE;

-- Test NEMPTY_WS
SELECT managed_code.TEST(msg, managed_code.NEMPTY_WS('-', VARIADIC args) IS NOT DISTINCT FROM res) nempty_ws
  FROM (VALUES
          ('NEMPTY_WS must return NULL 1' , ARRAY[                                             ]::TEXT[], NULL     )
         ,('NEMPTY_WS must return NULL 2' , ARRAY[NULL                                         ]::TEXT[], NULL     )
         ,('NEMPTY_WS must return NULL 3' , ARRAY[NULL, NULL                                   ]::TEXT[], NULL     )
         ,('NEMPTY_WS must return a'      , ARRAY['a'                                          ]        , 'a'      )
         ,('NEMPTY_WS must return a'      , ARRAY[NULL, 'a'                                    ]        , 'a'      )
         ,('NEMPTY_WS must return a'      , ARRAY['a' , NULL                                   ]        , 'a'      )
         ,('NEMPTY_WS must return a'      , ARRAY[NULL, 'a' , NULL                             ]        , 'a'      )
         ,('NEMPTY_WS must return a'      , ARRAY[''  , 'a'                                    ]        , 'a'      )     
         ,('NEMPTY_WS must return a'      , ARRAY['a' , ''                                     ]        , 'a'      )
         ,('NEMPTY_WS must return a'      , ARRAY[''  , 'a' , ''                               ]        , 'a'      )
         ,('NEMPTY_WS must return a'      , ARRAY[NULL, 'a' , ''                               ]        , 'a'      )
         ,('NEMPTY_WS must return a'      , ARRAY[''  , 'a' , NULL                             ]        , 'a'      )
         ,('NEMPTY_WS must return a-b'    , ARRAY[NULL, 'a' , ''  , 'b'                        ]        , 'a-b'    )
         ,('NEMPTY_WS must return a-b-c'  , ARRAY[NULL, NULL, 'a' , '' , '', 'b', '', NULL, 'c']        , 'a-b-c'  )
         ,('NEMPTY_WS must return a-b-c-d', ARRAY['a' , 'b' , 'c' , 'd'                        ]        , 'a-b-c-d')
       ) AS t (msg, args, res);
---------------------------------------------------------------------------------------------------




---------------------------------------------------------------------------------------------------
-- RANDOM_INT: produce a random integer in a specified closed range
-- P_MIN     : The minimum value
-- P_MAX     : The maximum value
-- P_CRYPTO  : Use the PG_CRYPTO gen_random_bytes if true, else RANDOM() if false
-- Generate random numbers. If P_CRYPTO is true (default is false) a fairly even distribution is generated.
-- The ordinary random() function is quite skewed, and will favour some values over others, but is much faster.
-- It does not matter if P_MAX and/or P_MIN are negative, or if P_MAX < P_MIN.
-- The result will be always in the closed range starting at LEAST(P_MIN, P_MAX) and counting towards positive infinity.
-- for ABS(P_MAX)-ABS(P_MIN)+1 values.
-- EG:
--  1. P_MIN, P_MAX =    5,  100: values will be the range [   5, 100]
--  2. P_MIN, P_MAX =  100,    5: values will be the range [   5, 100]
--  3. P_MIN, P_MAX =   -5,  100: values will be the range [  -5, 100]
--  4. P_MIN, P_MAX =  100,   -5: values will be the range [  -5, 100]
--  5. P_MIN, P_MAX = -100,    5: values will be the range [-100,   5]
--  6. P_MIN, P_MAX =    5, -100: values will be the range [-100,   5]
--  7. P_MIN, P_MAX = -100,   -5: values will be the range [-100,  -5]
--  8. P_MIN, P_MAX =   -5, -100: values will be the range [-100,  -5]
CREATE OR REPLACE FUNCTION managed_code.RANDOM_INT(P_MIN INT = 1, P_MAX INT = 2_147_483_647, P_CRYPTO BOOLEAN = FALSE) RETURNS INT AS
$$
  -- There is a corner case where the 32-bit generated value may be the smallest negative value,
  -- which is the only negative number that has no corresponding positive number.
  -- In that case, ABS would fail with an error. By casting the 32-bit value to BIGINT, no error ever occurs.
  SELECT (CASE WHEN P_CRYPTO
               THEN ABS(('x' || ENCODE(GEN_RANDOM_BYTES(4), 'hex'))::BIT(32)::BIGINT) % (ABS(P_MAX - P_MIN) + 1)
               ELSE ROUND(RANDOM() * ABS(P_MAX - P_MIN))
          END) + LEAST(P_MIN, P_MAX)
$$ LANGUAGE SQL LEAKPROOF PARALLEL SAFE;

-- Test RANDOM_INT()
SELECT managed_code.TEST(
         'RANDOM_INT() returns an int'
        ,managed_code.RANDOM_INT() IS NOT NULL
       );

SELECT managed_code.TEST(
         'RANDOM_INT() returns an int'
        ,managed_code.RANDOM_INT(P_CRYPTO => TRUE) IS NOT NULL
       );

-- Test RANDOM_INT(50)
SELECT managed_code.TEST(
         'RANDOM_INT(50) returns an int >= 50'
        ,managed_code.RANDOM_INT(50) >= 50
       )
  FROM generate_series(1, 10);

SELECT managed_code.TEST(
         'RANDOM_INT(50) returns an int >= 50'
        ,managed_code.RANDOM_INT(P_MIN => 50, P_CRYPTO => TRUE) >= 50
       )
  FROM generate_series(1, 10);

-- 1. Test RANDOM_INT(5, 20)
SELECT managed_code.TEST(
         'RANDOM_INT(5, 20) must return range of [5, 20]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(5, 20)) = '{5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

SELECT managed_code.TEST(
         'RANDOM_INT(5, 20) must return range of [5, 20]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(5, 20, TRUE)) = '{5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

-- 2. Test RANDOM_INT(20, 5)
SELECT managed_code.TEST(
         'RANDOM_INT(20, 5) must return range of [5, 20]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(20, 5)) = '{5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

SELECT managed_code.TEST(
         'RANDOM_INT(20, 5) must return range of [5, 20]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(20, 5, TRUE)) = '{5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

-- 3. Test RANDOM_INT(-5, 20)
SELECT managed_code.TEST(
         'RANDOM_INT(-5, 20) must return range of [-5, 20]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(-5, 20)) = '{-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

SELECT managed_code.TEST(
         'RANDOM_INT(-5, 20) must return range of [-5, 20]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(-5, 20, TRUE)) = '{-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

-- 4. Test RANDOM_INT(20, -5)
SELECT managed_code.TEST(
         'RANDOM_INT(20, -5) must return range of [-5, 20]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(20, -5)) = '{-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

SELECT managed_code.TEST(
         'RANDOM_INT(20, -5) must return range of [-5, 20]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(20, -5, TRUE)) = '{-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

-- 5. Test RANDOM_INT(-20, 5)
SELECT managed_code.TEST(
         'RANDOM_INT(-20, 5) must return range of [-20, 5]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(-20, 5)) = '{-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0,1,2,3,4,5}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

SELECT managed_code.TEST(
         'RANDOM_INT(-20, 5) must return range of [-20, 5]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(-20, 5, TRUE)) = '{-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0,1,2,3,4,5}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

-- 6. Test RANDOM_INT(5, -20)
SELECT managed_code.TEST(
         'RANDOM_INT(5, -20) must return range of [-20, 5]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(5, -20)) = '{-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0,1,2,3,4,5}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

SELECT managed_code.TEST(
         'RANDOM_INT(5, -20) must return range of [-20, 5]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(5, -20, TRUE)) = '{-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0,1,2,3,4,5}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

-- 7. Test RANDOM_INT(-20, -5)
SELECT managed_code.TEST(
         'RANDOM_INT(-20, -5) must return range of [-20, -5]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(-20, -5)) = '{-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

SELECT managed_code.TEST(
         'RANDOM_INT(-20, -5) must return range of [-20, -5]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(-20, -5, TRUE)) = '{-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

-- 8. Test RANDOM_INT(-5, -20)
SELECT managed_code.TEST(
         'RANDOM_INT(-5, -20) must return range of [-20, -5]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(-5, -20)) = '{-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;

SELECT managed_code.TEST(
         'RANDOM_INT(-5, -20) must return range of [-20, -5]'
        ,ARRAY_AGG(DISTINCT managed_code.RANDOM_INT(-5, -20, TRUE)) = '{-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5}'
       )
  FROM generate_series(1, 1_000)
 ORDER BY 1;
---------------------------------------------------------------------------------------------------




---------------------------------------------------------------------------------------------------
-- RANDOM_CHAR: produce a random char in a specified string
-- P_STR      : The string to produce a char from
-- P_CRYPTO   : Use the PG_CRYPTO gen_random_bytes if true, else RANDOM() if false
-- Generate a random char from a string. See RANDOM_INT for dicussion of randomness.
-- EG:
-- P_STR = 'afty': result will be 'a', 'f', 't', or 'y'
CREATE OR REPLACE FUNCTION managed_code.RANDOM_CHAR(P_STR TEXT, P_CRYPTO BOOLEAN = FALSE) RETURNS TEXT AS
$$
  SELECT SUBSTRING(P_STR FROM managed_code.RANDOM_INT(1, LENGTH(P_STR), P_CRYPTO) FOR 1);
$$ LANGUAGE SQL LEAKPROOF PARALLEL SAFE;

-- Test RANDOM_CHAR('afty')
SELECT DISTINCT managed_code.TEST('managed_code.RANDOM_CHAR(''afty'') must return a, f, t, or y', managed_code.RANDOM_CHAR('afty') IN ('a', 'f', 't', 'y'))
  FROM GENERATE_SERIES(1, 100);

-- Test RANDOM_CHAR('afty') using crypto
SELECT DISTINCT managed_code.TEST('managed_code.RANDOM_CHAR(''afty'') must return a, f, t, or y', managed_code.RANDOM_CHAR('afty', TRUE) IN ('a', 'f', 't', 'y'))
  FROM GENERATE_SERIES(1, 100);

-- Test RANDOM_CHAR('a')
SELECT DISTINCT managed_code.TEST('managed_code.RANDOM_CHAR(''a'') must return a', managed_code.RANDOM_CHAR('a') ='a');

-- Test RANDOM_CHAR('')
SELECT DISTINCT managed_code.TEST('managed_code.RANDOM_CHAR('''') must return ''''', managed_code.RANDOM_CHAR('') = '');

-- Test RANDOM_CHAR(NULL)
SELECT DISTINCT managed_code.TEST('managed_code.RANDOM_CHAR(NULL) must return NULL', managed_code.RANDOM_CHAR(NULL) IS NULL);
---------------------------------------------------------------------------------------------------




---------------------------------------------------------------------------------------------------
-- RANDOM_SUBSET: produce a random subset of a provided JSON array
-- P_ARR   : The JSON array to get a subset of
-- P_MIN   : The minimum number of elements of the subset
-- P_MAX   : The maximum number of elements of the subset
-- P_CRYPTO: Use the PG_CRYPTO gen_random_bytes if true, else RANDOM() if false
-- Generate a random char from a string. See RANDOM_INT for dicussion of randomness.
CREATE OR REPLACE FUNCTION managed_code.RANDOM_SUBSET(P_ARR JSON, P_MIN INT = 1, P_MAX INT = -1, P_CRYPTO BOOLEAN = FALSE) RETURNS JSON AS
$$
  WITH ARR_LEN AS (
    SELECT json_array_length(P_ARR) AS P_LEN
  )
  , ADJUST_MIN AS (
    SELECT *
          ,CASE WHEN P_MIN < 1 THEN 1 WHEN P_MIN > P_LEN THEN P_LEN ELSE P_MIN END AS ADJ_MIN
      FROM ARR_LEN
  )
  , ADJUST_MAX AS (
    SELECT *
          ,CASE WHEN P_MAX < 0 THEN P_LEN WHEN P_MAX < ADJ_MIN THEN ADJ_MIN WHEN P_MAX > P_LEN THEN P_LEN ELSE P_MAX END AS ADJ_MAX
      FROM ADJUST_MIN
  )
  SELECT JSON_AGG(e) subset
    FROM ADJUST_MAX
        ,(
           SELECT e
                 ,ROW_NUMBER() OVER(ORDER BY RANDOM()) r
             FROM json_array_elements(P_ARR) e
         )
   WHERE r BETWEEN ADJ_MIN AND managed_code.RANDOM_INT(ADJ_MIN, ADJ_MAX, P_CRYPTO);
$$ LANGUAGE SQL LEAKPROOF PARALLEL SAFE;

-- Test RANDOM_SUBSET('a', 'f', 't', 'y')
SELECT managed_Code.TEST(
         'RANDOM_SUBSET must return a subset of a,f,t,y'
        ,(SELECT COUNT(*)
            FROM (SELECT JSON_ARRAY_ELEMENTS('["a","f","t","y"]'::JSON) #>> '{}'
                  EXCEPT
                  SELECT JSON_ARRAY_ELEMENTS(managed_code.RANDOM_SUBSET('["a","f","t","y"]'::JSON)) #>> '{}'
                  FROM generate_series(1, 100)
            )
         ) = 0
       );




---------------------------------------------------------------------------------------------------
-- TO_8601 converts a TIMESTAMP into an ISO 8601 string of the form
-- YYYY-MM-DDTHH:MM:SS.sssZ
-- 123456789012345678901234
-- This is a 24 char string
--
-- The conversion uses rounding, not truncation: 253786 microseconds gets rounded up to 254 milliseconds
-- The conversion always provides 3 digits for milliseconds (eg, 210 milliseconds shows as .210, not .21)
--
-- Returns NULL when P_TS is NULL
CREATE OR REPLACE FUNCTION managed_code.TO_8601(P_TS TIMESTAMP) RETURNS VARCHAR(24) AS
$$
  SELECT TO_CHAR(P_TS::TIMESTAMP(3), 'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"')
$$ LANGUAGE SQL IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;


-- Test TO_8601
SELECT managed_code.TEST(msg, managed_code.TO_8601(ARG) IS NOT DISTINCT FROM res)
  FROM (VALUES
          ('TO_9701(NULL) must return NULL'                        , NULL::TIMESTAMP                             , NULL::TEXT)
         ,('TO_8601(NOW - 1 DAY) must return NOW - 1 DAY'          , NOW() AT TIME ZONE 'UTC' - INTERVAL '1 DAY', TO_CHAR((NOW() AT TIME ZONE 'UTC' - INTERVAL '1 DAY')::TIMESTAMP(3), 'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"'))
         ,('TO_8601(2025-08-16T02:30:45.234567Z) rounds to .235 ms', '2025-08-16T02:30:45.234567Z'::TIMESTAMP   , '2025-08-16T02:30:45.235Z')
         ,('TO_8601(2025-08-16T02:30:45.9Z) HAS 900MS'             , '2025-08-16T02:30:45.9Z'::TIMESTAMP        , '2025-08-16T02:30:45.900Z')
       ) AS t(msg, arg, res);
----------------------------------------------------------------------------------------------------




---------------------------------------------------------------------------------------------------
-- FROM_8601 converts an ISO 8601 string of the following form into a TIMESTAMP
-- YYYY-MM-DDTHH:MM:SS.sssZ
-- 123456789012345678901234
-- This is a 24 char string
CREATE OR REPLACE FUNCTION managed_code.FROM_8601(P_TS VARCHAR(24)) RETURNS TIMESTAMP AS
$$
  SELECT TO_TIMESTAMP(P_TS, 'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"')
$$ LANGUAGE SQL IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

-- Test FROM_8601
SELECT managed_code.TEST(msg, managed_code.FROM_8601(arg) IS NOT DISTINCT FROM res)
  FROM (VALUES
          ('FROM_8601(NULL) must return NULL'                      , NULL::VARCHAR                                                    , NULL::TIMESTAMP)
         ,('FROM_8601(NOW - 1 DAY) must return NOW - 1 DAY'        , managed_code.TO_8601(NOW() AT TIME ZONE 'UTC' - INTERVAL '1 DAY'), NOW()::TIMESTAMP(3) - INTERVAL '1 DAY')
         ,('TO_8601(2025-08-16T02:30:45.234567Z) rounds to .235 ms', '2025-08-16T02:30:45.234567Z'                                    , managed_code.FROM_8601('2025-08-16T02:30:45.235Z'))
         ,('TO_8601(2025-08-16T02:30:45.9Z) has 900MS'             , '2025-08-16T02:30:45.9Z'                                         , managed_code.FROM_8601('2025-08-16T02:30:45.900Z'))
       ) AS t(msg, arg, res);
----------------------------------------------------------------------------------------------------




---------------------------------------------------------------------------------------------------
-- RELID_TO_ID converts a BIGINT to a base 62 string with a maximum of 11 chars
-- Maximum signed BIGINT value is 9_223_372_036_854_775_807 -> AzL8n0Y58m7
--                                                             12345678901
-- Raises an exception if P_RELID is < 1, since valid relids start at 1
-- Returns NULL if relid is NULL
CREATE OR REPLACE FUNCTION managed_code.RELID_TO_ID(P_RELID BIGINT) RETURNS VARCHAR(11) AS
$$
DECLARE
  V_RELID BIGINT := P_RELID;
  V_DIGIT CHAR;
  V_ID VARCHAR(11) = '';
  V_RMDR INT;
BEGIN
  IF V_RELID < 1 THEN
    RAISE EXCEPTION 'P_RELID cannot be < 1';
  END IF;

  WHILE V_RELID > 0 LOOP
    V_RMDR = V_RELID % 62;
    CASE
      WHEN V_RMDR < 10      THEN V_DIGIT = CHR(ASCII('0') + V_RMDR          );
      WHEN V_RMDR < 10 + 26 THEN V_DIGIT = CHR(ASCII('A') + V_RMDR - 10     );
      ELSE                       V_DIGIT = CHR(ASCII('a') + V_RMDR - 10 - 26);
    END CASE;
    
    -- Add digits to the front of the string, modulus gives us the digits from least to most significant
    -- Eg for the relid 123, we get the digits 3,2,1
    V_ID    = V_DIGIT || V_ID;
    V_RELID = V_RELID /  62;
  END LOOP;
  
  RETURN V_ID;
END;
$$ LANGUAGE PLPGSQL IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

--- Test RELID_TO_ID
SELECT DISTINCT * FROM (
  SELECT managed_code.TEST('P_RELID cannot be < 1', q)
    FROM (VALUES
            ('SELECT managed_code.RELID_TO_ID(0)'   )
           ,('SELECT managed_code.RELID_TO_ID(-1)'  )
         ) AS t(q)
   UNION ALL
  SELECT managed_code.TEST(format('RELID_TO_ID(%s) must return %s', r, i), managed_code.RELID_TO_ID(r) IS NOT DISTINCT FROM i)
    FROM (VALUES
           (NULL                     , NULL         ),
           (1                        , '1'          ),
           (9                        , '9'          ),
           (10                       , 'A'          ),
           (10 + 25                  , 'Z'          ), -- 35
           (10 + 26                  , 'a'          ), -- 36
           (10 + 26 + 25             , 'z'          ), -- 61
           (10 + 26 + 26             , '10'         ), -- 62
           (10_000_000_000           , 'Aukyoa'     ), -- = 10 * 62^5      + (36 + 20) * 62^4     + (36 + 10) * 62^3   + (36 + 24) * 62^2 + (36 + 14) * 62 + 36
                                                       -- = 10 * 916132832 + 56        * 14776336 + 46        * 238328 + 60        * 3844 + 50        * 62 + 36
           (9_223_372_036_854_775_807, 'AzL8n0Y58m7')  -- = 10 * 62^10              + (10 + 26 + 25) * 62^9              + (10 + 11) * 62^8            + 8 * 62^7          + (10 + 26 + 13) * 62^6        + 0 * 62^5      + (10 + 24) * 62^4     + 5 * 62^3   + 8 * 62^2 + (10 + 26 + 12) * 62 + 7
                                                       -- = 10 * 839299365868340224 + 61             * 13537086546263552 + 21 *        218340105584896 + 8 * 3521614606208 + 49             * 56800235584 + 0 * 916132832 + 34        * 14776336 + 5 * 238328 + 8 * 3844 + 48             * 62 + 7    
        ) AS t(r, i)
) t;
---------------------------------------------------------------------------------------------------




---------------------------------------------------------------------------------------------------
-- ID_TO_RELID converts a base 62 string with a maximum of 11 chars to a BIGINT
-- Maximum ID is AzL8n0Y58m7 -> signed BIGINT value is 9_223_372_036_854_775_807 
--               12345678901
-- Raises an exception if P_ID <= 0, since valid ids start at 1
-- A NULL is returns NULL
-- Uses C collation for ASCII case-sensitive sorting regardless of database collation
CREATE OR REPLACE FUNCTION managed_code.ID_TO_RELID(P_ID VARCHAR(11)) RETURNS BIGINT AS
$$
DECLARE
  --                                               12345678901
  C_LPAD_ID  CONSTANT CHAR(11) := LPAD(P_ID, 11, '00000000000') COLLATE "C";
  C_LPAD_MIN CONSTANT CHAR(11) :=                '00000000001'  COLLATE "C";
  C_LPAD_MAX CONSTANT CHAR(11) :=                'AzL8n0Y58m7'  COLLATE "C";
  
  C_0        CONSTANT INT := ASCII('0');
  C_9        CONSTANT INT := ASCII('9');
  C_CAP_A    CONSTANT INT := ASCII('A');
  C_CAP_Z    CONSTANT INT := ASCII('Z');
  C_LIT_A    CONSTANT INT := ASCII('a');
  C_LIT_Z    CONSTANT INT := ASCII('z');
  
  C_COUNT_DIGITS           CONSTANT INT := 10;
  C_COUNT_DIGITS_AND_LOWER CONSTANT INT := C_COUNT_DIGITS + 26; 
  
  V_ID          VARCHAR(11) := P_ID;
  V_DIGIT       CHAR;
  V_ASCII_DIGIT INT;
  V_RELID       BIGINT := 0;
BEGIN
  -- P_ID cannot be empty string
  IF LENGTH(V_ID) = 0 THEN
    RAISE EXCEPTION 'P_ID cannot be empty';
  END IF;
  
  -- P_ID must be >= '1' and <= 'AzL8n0Y58m7'
  IF (C_LPAD_ID < C_LPAD_MIN) OR (C_LPAD_ID > C_LPAD_MAX) THEN
    RAISE EXCEPTION 'P_ID must be in the range [1 .. AzL8n0Y58m7]';
  END IF;

  FOREACH V_DIGIT IN ARRAY REGEXP_SPLIT_TO_ARRAY(V_ID, '')
  LOOP
    -- Get the ASCII numeric value to guarantee an ASCII comparison 
    V_ASCII_DIGIT = ASCII(V_DIGIT);
    V_RELID = V_RELID * 62;
    
    CASE
      WHEN V_ASCII_DIGIT BETWEEN C_0     AND C_9     THEN V_RELID = V_RELID +                            (V_ASCII_DIGIT - C_0);
      WHEN V_ASCII_DIGIT BETWEEN C_CAP_A AND C_CAP_Z THEN V_RELID = V_RELID + C_COUNT_DIGITS +           (V_ASCII_DIGIT - C_CAP_A);
      WHEN V_ASCII_DIGIT BETWEEN C_LIT_A AND C_LIT_Z THEN V_RELID = V_RELID + C_COUNT_DIGITS_AND_LOWER + (V_ASCII_DIGIT - C_LIT_A);
      ELSE RAISE EXCEPTION 'P_ID digit ''%'' (ASCII 0x%) is invalid: only characters in the ranges of 0..9, A..Z, and a..z are valid', V_DIGIT, UPPER(TO_HEX(V_ASCII_DIGIT));
    END CASE;
  END LOOP;
  
  RETURN V_RELID;
END;
$$ LANGUAGE PLPGSQL IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

--- Test ID_TO_RELID
SELECT DISTINCT * FROM (
  SELECT managed_code.TEST(msg, q)
    FROM (VALUES
            ('P_ID cannot be empty', 'SELECT managed_code.ID_TO_RELID('''')')

           ,('P_ID must be in the range [1 .. AzL8n0Y58m7]', 'SELECT managed_code.ID_TO_RELID(''0'')'          )
           ,('P_ID must be in the range [1 .. AzL8n0Y58m7]', 'SELECT managed_code.ID_TO_RELID(''AzL8n0Y58m8'')')

           ,('P_ID digit ''-'' (ASCII 0x2D) is invalid: only characters in the ranges of 0..9, A..Z, and a..z are valid', 'SELECT managed_code.ID_TO_RELID(''-1'')'  )
           ,('P_ID digit '':'' (ASCII 0x3A) is invalid: only characters in the ranges of 0..9, A..Z, and a..z are valid', 'SELECT managed_code.ID_TO_RELID(''1:'')'  )
           ,('P_ID digit ''['' (ASCII 0x5B) is invalid: only characters in the ranges of 0..9, A..Z, and a..z are valid', 'SELECT managed_code.ID_TO_RELID(''11['')' )
           ,('P_ID digit ''{'' (ASCII 0x7B) is invalid: only characters in the ranges of 0..9, A..Z, and a..z are valid', 'SELECT managed_code.ID_TO_RELID(''111{'')')
         ) AS t(msg, q)
   UNION ALL
  SELECT managed_code.TEST(format('ID_TO_RELID must return %s', r), managed_code.ID_TO_RELID(i) IS NOT DISTINCT FROM r)
    FROM (VALUES
            (NULL         , NULL                     )
           ,('1'          , 1                        )
           ,('9'          , 9                        )
           ,('A'          , 10                       )
           ,('Z'          , 10 + 25                  )
           ,('a'          , 10 + 26                  )
           ,('z'          , 10 + 26 + 25             )
           ,('10'         , 10 + 26 + 26             )
           ,('Aukyoa'     , 10_000_000_000           )
           ,('AzL8n0Y58m7', 9_223_372_036_854_775_807)    
        ) AS t(i, r)
) t;




---------------------------------------------------------------------------------------------------
-- RAISE_MSG raises an error with the given msg if P_PASS is false
-- Otherwise, it returns P_VAL
-- Allow SQL queries to conditionally throw errors
-- If P_MSG is null or empty, then an error is raised regardless of P_PASS
-- If P_PASS is null, then an error is raised
CREATE OR REPLACE FUNCTION managed_code.RAISE_MSG(P_MSG TEXT, P_PASS BOOLEAN, P_VAL ANYELEMENT) RETURNS ANYELEMENT AS
$$
BEGIN
  IF LENGTH(COALESCE(P_MSG, '')) = 0 THEN
    RAISE EXCEPTION 'P_MSG CANNOT BE NULL OR EMPTY';
  END IF;

  IF P_PASS IS NULL THEN
    RAISE EXCEPTION 'P_PASS CANNOT BE NULL';
  END IF;

  IF P_PASS THEN
    RETURN P_VAL;
  ELSE
    RAISE EXCEPTION '%', P_MSG;
  END IF;
END;
$$ LANGUAGE PLPGSQL IMMUTABLE;

-- Test P_MSG IS null or empty
SELECT managed_code.TEST('P_MSG CANNOT BE NULL OR EMPTY', $$SELECT managed_code.RAISE_MSG(NULL, FALSE, ''::TEXT)$$);
SELECT managed_code.TEST('P_MSG CANNOT BE NULL OR EMPTY', $$SELECT managed_code.RAISE_MSG(''  , FALSE, ''::TEXT)$$);

-- Test P_PASS IS null
SELECT managed_code.TEST('P_PASS CANNOT BE NULL', $$SELECT managed_code.RAISE_MSG('the msg', NULL, ''::TEXT)$$);

-- Test RAISE_MSG where P_PASS is false (error raised)
SELECT managed_code.TEST('the msg', $$SELECT managed_code.RAISE_MSG('the msg', FALSE, ''::TEXT)$$);

-- Test RAISE_MSG where P_PASS is true (value returned)
SELECT managed_code.TEST('val', managed_code.RAISE_MSG('the msg', TRUE, 'val'::TEXT) = 'val');




---------------------------------------------------------------------------------------------------
-- RAISE_MSG_IF_EMPTY is an easier test for empty strings
-- Returns P_VAL if it is non-nnull and non-empty, else raises P_MSG
CREATE OR REPLACE FUNCTION managed_code.RAISE_MSG_IF_EMPTY(P_MSG TEXT, P_VAL TEXT) RETURNS TEXT AS
$$
BEGIN
  RETURN managed_code.RAISE_MSG(P_MSG, LENGTH(COALESCE(P_VAL, '')) > 0, P_VAL);
END;
$$ LANGUAGE PLPGSQL IMMUTABLE;
---------------------------------------------------------------------------------------------------




---------------------------------------------------------------------------------------------------
-- GET_JSONB_OBJ_ARR assumes that the parameter is a JSONB object or array of objects
--
-- If the parameter is not an object or array, no elements are returned
-- If the an array is passed, only object elements are returned, any other typeof elements are filtered out
-- This allows for simple implementation that does not raisse any errors.
--
CREATE OR REPLACE FUNCTION managed_code.GET_JSONB_OBJ_ARR(P_VAL JSONB) RETURNS SETOF JSONB AS
$$
--  WITH PARAMS AS (
--    SELECT '[1]'::JSONB AS P_VAL
--  ),
  WITH
  GET_TYP AS (
     SELECT JSONB_TYPEOF(P_VAL) AS jsonb_typ
--       FROM PARAMS
  )
--  SELECT * FROM GET_TYP;
 ,OBJ_ARR AS (
    SELECT managed_code.IIF(jsonb_typ = 'object', P_VAL, NULL) jsonb_obj
          ,managed_code.IIF(jsonb_typ = 'array' , P_VAL, NULL) jsonb_arr
      FROM GET_TYP
  )
  SELECT jsonb_obj AS elem
    FROM OBJ_ARR
   WHERE jsonb_obj IS NOT NULL
   UNION ALL
  SELECT jsonb_elem
    FROM (
            SELECT JSONB_ARRAY_ELEMENTS(jsonb_arr) AS jsonb_elem
              FROM OBJ_ARR
         )
   WHERE JSONB_TYPEOF(jsonb_elem) = 'object'
$$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;

-- Test GET_JSONB_OBJ_ARR(object) returns one row with the object
SELECT managed_code.TEST(
  'Returns one row for object'
 ,managed_code.GET_JSONB_OBJ_ARR('{"a":"b","c":"d"}') = '{"a":"b","c":"d"}'
);

-- Test GET_JSONB_OBJ_ARR(array of one object) returns one row
SELECT managed_code.TEST(
  'Returns one row for array of one object'
 ,managed_code.GET_JSONB_OBJ_ARR('[{"a":"b","c":"d"}]') = '{"a":"b","c":"d"}'
);

-- Test GET_JSONB_OBJ_ARR(array of two objects) returns two rows
SELECT managed_code.TEST(
  'Returns two rows for array of two objects'
 ,(SELECT COUNT(*) FROM managed_code.GET_JSONB_OBJ_ARR('[{"a":"b"},{"c":"d"}]')) = 2
);

-- Test GET_JSONB_OBJ_ARR(array of two objects aand 1 number) returns two rows
SELECT managed_code.TEST(
  'Returns two rows for array of two objects'
 ,(SELECT COUNT(*) FROM managed_code.GET_JSONB_OBJ_ARR('[{"a":"b"},1,{"c":"d"}]')) = 2
);

-- Test GET_JSONB_OBJ_ARR(NULL) returns no rows
SELECT managed_code.TEST(
  'Returns empty set for NULL'
 ,(SELECT COUNT(*) FROM managed_code.GET_JSONB_OBJ_ARR(NULL)) = 0
);

-- Test GET_JSONB_OBJ_ARR(number) returns no rows
SELECT managed_code.TEST(
  'Returns empty set for a number'
 ,(SELECT COUNT(*) FROM managed_code.GET_JSONB_OBJ_ARR('1')) = 0
);

-- Test GET_JSONB_OBJ_ARR([number]) returns no rows
SELECT managed_code.TEST(
  'Returns empty set for an array of one number'
 ,(SELECT COUNT(*) FROM managed_code.GET_JSONB_OBJ_ARR('[1]')) = 0
);




---------------------------------------------------------------------------------------------------
-- VALIDATE_JSONB_SCHEMA validates that a single JSONB object matches a schema
-- P_OBJ   : The object that has to match the schema
-- P_SCHEMA: The schema to test against
-- P_REQD  : An optional text array of required key names
--
-- The schema is a flat schema (each key describes a top level object key of P_OBJ), described
-- as follows:
--   - The key name is the name of a key in P_OBJ
--   - The key value is one of the following strings:
--     - array, object, string, number, boolean, date, timestamp

HANDLE P_OBJ OR P_SCHEMA ARE EMPTY
HANDLE DATE AND TIMESTAMP

--
-- The optional P_REQD array indicates which keys must be non-null, any other key can be absent
-- or null
--
-- Instead of raising errors, a JSONB objects is returned, where each key name is the name of a parameter or object key
-- that has an error associated with it.
-- If the input object has no errors, then the resulting object will be empty.
--
-- If the parameters are invalid the following errors can be returned: (max one error per parameter)
-- {"P_OBJ": "must be an object"}
-- {"P_OBJ": "must have at least one key"}
-- {"P_SCHEMA": "must be an object"}
-- {"P_SCHEMA": "must have at least one key"}
--
-- When there are errors in the parameters, only those errors are returned
--
-- If there are no parameter errors, and the object does not match the schema, the following errors can be returned:
-- {"keyName": "Expected X, got Y"} (eg, {"firstName": "Expected string, got boolean"})
-- {"keyName": "Required"}          (eg, {"firstName": "Required"}, indicating a missing key that is required)
-- {"keyName": "Unexpected"}        (eg, {"muddleName": "Unexpected"}, indicating misspelled muddleName is not part of the schema)
---------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION managed_code.VALIDATE_JSONB_SCHEMA(P_OBJ JSONB, P_SCHEMA JSONB, P_REQD TEXT[] = NULL) RETURNS JSONB AS
$$
  -- Hard-coded data for debugging
--  WITH PARAMS AS (
--    SELECT '{"firstName": "Avery", "middleName": "Sienna", "lastName": "Jones"}'::JSONB AS P_OBJ
--          ,'{"firstName": "string", "middleName": "string", "lastName": "string"}'::JSONB AS P_SCHEMA
--          ,ARRAY['firstName', 'lastName']::TEXT[]                                       AS P_REQD
--  ),
--  SELECT * FROM PARAMS;

  -- Check if the P_OBJ and P_SCHEMA parameters are JSONB objects
  -- If not, convert them to empty objects to make further CTEs easier
  WITH
  PARAMS_WITH_TYPES AS (
    SELECT managed_code.IIF(P_OBJ_TYPE    = 'object', P_OBJ   , '{}') AS P_OBJ
          ,managed_code.IIF(P_SCHEMA_TYPE = 'object', P_SCHEMA, '{}') AS P_SCHEMA
          ,P_OBJ_TYPE
          ,P_SCHEMA_TYPE
      FROM (
              SELECT
--                    *,
                     JSONB_TYPEOF(P_OBJ)    AS P_OBJ_TYPE
                    ,JSONB_TYPEOF(P_SCHEMA) AS P_SCHEMA_TYPE
--                FROM PARAMS
           ) t
  )
--  SELECT * FROM PARAMS_WITH_TYPES;

  -- Validate that P_OBJ and P_SCHEMA parameters are JSONB objects,
  -- producing errors if they are not
 ,VALIDATE_PARAMS AS (
    SELECT '{}'::JSONB
           || managed_code.IIF(P_OBJ_TYPE    = 'object', '{}'::JSONB, '{"P_OBJ"   : "must be an object"}')
           || managed_code.IIF(P_SCHEMA_TYPE = 'object', '{}'::JSONB, '{"P_SCHEMA": "must be an object"}')
           AS PARAM_ERRORS
      FROM PARAMS_WITH_TYPES
  )
--  SELECT * FROM VALIDATE_PARAMS;

  -- Zero or more key/value pairs of object
 ,OBJ_KEY_VALUES AS (
    SELECT KEY   AS OBJ_KEY                      -- TEXT
          ,VALUE AS OBJ_VALUE                    -- JSONB
          ,JSONB_TYPEOF(VALUE) AS OBJ_VALUE_TYPE -- TEXT
      FROM JSONB_EACH(
             (SELECT P_OBJ FROM PARAMS_WITH_TYPES)
           )
  )
--  SELECT * FROM OBJ_KEY_VALUES;

  -- Zero or more key/value pairs of schema
  -- Filter out schema types that do not make sense (eg expecting null)
 ,SCHEMA_KEY_VALUES AS (
    SELECT KEY   AS SCHEMA_KEY        -- TEXT
          ,VALUE AS SCHEMA_VALUE_TYPE -- TEXT
      FROM JSONB_EACH_TEXT(
             (SELECT P_SCHEMA FROM PARAMS_WITH_TYPES)
           )
     WHERE VALUE IN ('array', 'object', 'string', 'number', 'boolean')
  )
--  SELECT * FROM SCHEMA_KEY_VALUES;

  -- Keys defined in schema as one type that are defined in object as another type
  -- EG, schema expects key X to be a string, but object key X is a number
 ,VALIDATE_OBJECT_TO_SCHEMA AS (
    SELECT COALESCE(JSONB_OBJECT_AGG(OBJ_KEY, ERROR), '{}'::JSONB) AS SCHEMA_ERRORS
      FROM (
        SELECT *
          FROM (
            SELECT OBJ_KEY
                  ,CASE
                     -- Schema and object have same key with different types
                   WHEN skv.SCHEMA_VALUE_TYPE IS NOT NULL
                    AND okv.OBJ_VALUE_TYPE    IS NOT NULL
                    AND okv.OBJ_VALUE_TYPE    != 'null'
                    AND skv.SCHEMA_VALUE_TYPE != okv.OBJ_VALUE_TYPE
                   THEN format(
                          'Expected %s, not %s'
                          ,SCHEMA_VALUE_TYPE
                          ,OBJ_VALUE_TYPE
                        )

                     -- Object has key that schema does not
                   WHEN okv.OBJ_KEY    IS NOT NULL
                    AND skv.SCHEMA_KEY IS     NULL
                   THEN 'Unexpected'
                    END AS ERROR
              FROM OBJ_KEY_VALUES okv
              FULL
              JOIN SCHEMA_KEY_VALUES skv
                ON skv.SCHEMA_KEY = okv.OBJ_KEY
          )
         WHERE OBJ_KEY != ''
               AND ERROR IS NOT NULL
       )
  )
--  SELECT * FROM VALIDATE_OBJECT_TO_SCHEMA;


 ,SCHEMA_REQUIRED AS (
    SELECT UNNEST AS REQD_KEY
      FROM UNNEST(
             P_REQD
--             (SELECT P_REQD FROM PARAMS)
           )
  )
--  SELECT * FROM SCHEMA_REQUIRED;

 ,VALIDATE_REQUIRED AS (
    -- All required keys that do not occur in a given object keys
    SELECT COALESCE(
             JSONB_OBJECT_AGG(
               REQD_KEY
              ,'Required'
             )
            ,'{}'::JSONB
           ) AS MISSING_ERRORS
      FROM SCHEMA_REQUIRED sr
      LEFT JOIN OBJ_KEY_VALUES  okv
        ON okv.OBJ_KEY = sr.REQD_KEY
     WHERE (okv.OBJ_KEY IS NULL)
        OR (okv.OBJ_VALUE_TYPE = 'null')
  )
--   SELECT * FROM VALIDATE_REQUIRED;

  -- Return the preferred errors, as follows:
  -- If there are errors for parameters (P_OBJ and P_SCHEMA), return only those errors, as they indicate an invalid call
  -- Otherwise, return combined errors for:
  --   - Object has keys with incorrect type of values
  --   - Object is missing required keys

  SELECT managed_code.IIF(
           PARAM_ERRORS != '{}'::JSONB
          ,PARAM_ERRORS
          ,SCHEMA_ERRORS || MISSING_ERRORS
         ) AS RESULT
    FROM VALIDATE_PARAMS
        ,VALIDATE_OBJECT_TO_SCHEMA
        ,VALIDATE_REQUIRED;
$$ LANGUAGE SQL IMMUTABLE LEAKPROOF PARALLEL SAFE;
