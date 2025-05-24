-- ====================
-- ==== base table ====
-- ====================
CREATE TABLE IF NOT EXISTS managed_tables.base(
   relid       BIGINT
  ,version     INTEGER
  ,description TEXT
  ,terms       TSVECTOR
  ,extra       JSONB
  ,created     TIMESTAMP(3)
  ,modified    TIMESTAMP(3)
);

-- Primary key
SELECT 'ALTER TABLE managed_tables.base ADD CONSTRAINT base_pk PRIMARY KEY(relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'base'
      AND CONSTRAINT_NAME = 'base_pk'
 )
\gexec

-- Index on base descriptor field for full text searches
CREATE INDEX IF NOT EXISTS base_ix_terms    ON managed_tables.base USING GIN(terms);

-- Index on extra field for json key value comparisons
CREATE INDEX IF NOT EXISTS base_ix_extra    ON managed_tables.base USING GIN(extra JSONB_PATH_OPS);

-- Index on created field for created date comparisons
CREATE INDEX IF NOT EXISTS base_ix_created  ON managed_tables.base (created);

-- Index on modified field for modified date comparisons
CREATE INDEX IF NOT EXISTS base_ix_modified ON managed_tables.base (modified);

-- Row trigger function to ensure that:
-- - relid is generated and never modified
-- - version increments sequentially starting at 1
-- - created is inserted as current timestamp, and never updated
-- - modified is always current timestamp
--
-- NOTES:
-- - current timestamp is not an immutable function, so cannot be used for a generated column
-- - this trigger must be separately applied to each child table
-- - it is not applied to the base table, as that would not accomplish anything
CREATE OR REPLACE FUNCTION base_tg_fn() RETURNS trigger AS
$$
DECLARE
  V_CT TIMESTAMP := NOW() AT TIME ZONE 'UTC';
BEGIN
  CASE TG_OP
    WHEN 'INSERT' THEN
      -- Always use next relid in sequence
      SELECT COALESCE(MAX(relid), 0) + 1 INTO NEW.relid FROM managed_tables.base;

      -- Always atart at version 1
      NEW.version = 1;
      
      -- Always start with same created and modified dates = now
      NEW.created  = V_CT;
      NEW.modified = V_CT;
  
    WHEN 'UPDATE' THEN
      -- The new and old relids have to match
      IF NEW.relid != OLD.relid THEN
        RAISE EXCEPTION 'The relid cannot be changed from % to %', OLD.relid, NEW.relid;
      END IF;

      -- The new and old versions have to match, otherwise some change has occurred since it was loaded
      IF NEW.version != OLD.version THEN
        RAISE EXCEPTION 'The version of id % has changed since the record was loaded', managed_code.RELID_TO_ID(NEW.relid);
      END IF;
      
      -- Always advance version by 1
      NEW.version = OLD.version + 1;

      -- Cannot change created date
      NEW.created = OLD.created;
      
      -- Always set modified date to current time
      NEW.modified = V_CT;
    ELSE NULL;
  END CASE;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Test base trigger (only if base table is empty)
DO $$
DECLARE
    V_RELID       BIGINT;
    V_VERSION     INT;
    V_DESCRIPTION TEXT;
    V_TERMS       TSVECTOR;
    V_EXTRA       JSONB;
    V_CREATED     TIMESTAMP(3);
    V_CREATED2    TIMESTAMP(3);
    V_MODIFIED    TIMESTAMP(3);
    V_MODIFIED2   TIMESTAMP(3);
    V_STUFF       TEXT;
    V_ERR         TEXT;
BEGIN
    -- Only run test on an empty database
    IF (SELECT COUNT(*) FROM managed_tables.base) = 0 THEN
        SET log_min_messages = NOTICE;
        RAISE NOTICE 'Testing base table';

        -- We never actually insert into base table, only derived tables
        CREATE TABLE testbase(stuff TEXT) INHERITS (managed_tables.base);
        CREATE OR REPLACE TRIGGER testbase_tg
        BEFORE INSERT OR UPDATE ON testbase
        FOR EACH ROW
        EXECUTE FUNCTION base_tg_fn();

        INSERT INTO testbase(
            relid
           ,version
           ,description
           ,terms
           ,extra
           ,created
           ,modified
           ,stuff
       ) VALUES(
            2
           ,3
           ,'desc'
           ,TO_TSVECTOR('english', 'dude looks like a lady')
           ,'{"dude": "looks like a lady"}'
           ,'2025-01-02T03:04:05.678Z'
           ,'2025-01-02T03:04:05.678Z'
           ,'whatever'
       )
       RETURNING relid  , version  , description  , terms  , extra  , created  , modified  , stuff
            INTO V_RELID, V_VERSION, V_DESCRIPTION, V_TERMS, V_EXTRA, V_CREATED, V_MODIFIED, V_STUFF;

        PERFORM managed_code.TEST('relid must be 1, not 2', V_RELID = 1);
        PERFORM managed_code.TEST('version must be 1, not ' || V_VERSION, V_VERSION = 1);
        PERFORM managed_code.TEST('description must be desc, not ' || V_DESCRIPTION, V_DESCRIPTION = 'desc');
        PERFORM managed_code.TEST('terms must be dude looks like a lady, not ' || V_TERMS::TEXT, V_TERMS = TO_TSVECTOR('english', 'dude looks like a lady'));
        PERFORM managed_code.TEST('extra must be {"dude": "looks like a lady"}, not (%)' || V_EXTRA::TEXT, V_EXTRA = '{"dude": "looks like a lady"}'::JSONB);
        PERFORM managed_code.TEST('created must be generated, not ' || V_CREATED, V_CREATED != '2025-01-02T03:04:05.678Z');
        PERFORM managed_code.TEST('modified must be same as created, not ' || V_MODIFIED, V_MODIFIED = V_CREATED);
        PERFORM managed_code.TEST('stuff must be whatever, not ' || V_STUFF, V_STUFF = 'whatever');

        -- Get results of an update
        UPDATE testbase
           SET created = NOW() AT TIME ZONE 'UTC' - INTERVAL '1 week'
              ,modified = NOW() AT TIME ZONE 'UTC' - INTERVAL '1 week'
              ,stuff = 'dude'
         WHERE relid = V_RELID
           AND version = V_VERSION
        RETURNING relid,   version,   created,    modified,    stuff
          INTO    V_RELID, V_VERSION, V_CREATED2, V_MODIFIED2, V_STUFF;

        PERFORM managed_code.TEST('relid must be 1, not ' || V_RELID, V_RELID = 1);
        PERFORM managed_code.TEST('version must be 2, not ' || V_VERSION, V_VERSION = 2);
        PERFORM managed_code.TEST(format('created cannot change from %s to %s', V_CREATED, V_CREATED2), V_CREATED2 = V_CREATED);
        PERFORM managed_code.TEST(format('modified must be newer than created, not %s -> %s', V_MODIFIED, V_MODIFIED2), V_MODIFIED2 >= V_MODIFIED);
        PERFORM managed_code.TEST('stuff must be dude, not ' || V_STUFF, V_STUFF = 'dude');

        -- Updating relid is an error
        PERFORM managed_code.TEST('The relid cannot be changed from 1 to 2', 'UPDATE testbase SET relid = 2 WHERE relid = 1');
        PERFORM managed_code.TEST('The version of id 1 has changed since the record was loaded', 'UPDATE testbase SET version = 10 WHERE relid = 1');

        DROP TABLE testbase CASCADE;
    END IF;
END;
$$ LANGUAGE plpgsql;
