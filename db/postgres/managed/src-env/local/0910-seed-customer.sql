SET log_min_messages = NOTICE;

-- Seed addresses in a simple way that is not super accurate, but good enough and easy to understand
DO $$
DECLARE
  C_NUM_ROWS INT := ${PG_MANAGED_NUM_SEED_CUSTOMERS};

  -- Loop counter
  V_COUNT INT;

  -- True if generating a personal address, false for business address
  V_IS_PERSONAL BOOL;

  -- The business address type relid (null for personal address)
  V_BUSINESS_ADDRESS_TYPE_RELID BIGINT;

  -- The country and region values
  V_COUNTRY_RELID BIGINT;
  V_COUNTRY_CODE2 CHAR(2);
  V_COUNTRY_HAS_REGIONS BOOL;
  V_REGION_CODE CHAR(2);

  -- The region relid (null for countries with no regions)
  V_REGION_RELID BIGINT;
BEGIN
  RAISE NOTICE 'C_NUM_ROWS = %', C_NUM_ROWS;

  FOR V_COUNT IN 1 .. C_NUM_ROWS LOOP
    -- Choose personal addresses 60% of the time, businesses 40%
    V_IS_PERSONAL := random() <= 0.60;

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
          ,has_regions
      INTO V_COUNTRY_RELID
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

    RAISE NOTICE 'V_BUSINESS_ADDRESS_TYPE_RELID = %', V_BUSINESS_ADDRESS_TYPE_RELID;
    RAISE NOTICE 'V_COUNTRY_RELID = %'              , V_COUNTRY_RELID;
    RAISE NOTICE 'V_COUNTRY_HAS_REGIONS = %'        , V_COUNTRY_HAS_REGIONS;
    RAISE NOTICE 'V_REGION_RELID = %'               , V_REGION_RELID;
    RAISE NOTICE 'V_REGION_CODE = %'                , V_REGION_CODE;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
