-- =======================
-- ==== country table ====
-- =======================
CREATE TABLE IF NOT EXISTS managed_tables.country(
   name                TEXT    NOT NULL
  ,code_2              CHAR(2) NOT NULL
  ,code_3              CHAR(3) NOT NULL
  ,has_regions         BOOLEAN NOT NULL
  ,has_mailing_code    BOOLEAN NOT NULL
  ,mailing_code_match  TEXT
  ,mailing_code_format TEXT
  ,ord                 INTEGER NOT NULL
) INHERITS (managed_tables.base);

-- Base triggers
CREATE OR REPLACE TRIGGER country_tg_ins
BEFORE INSERT ON managed_tables.country
FOR EACH ROW
EXECUTE FUNCTION BASE_TG_FN();

CREATE OR REPLACE TRIGGER country_tg_upd
BEFORE UPDATE ON managed_tables.country
FOR EACH ROW
WHEN (OLD IS DISTINCT FROM NEW)
EXECUTE FUNCTION BASE_TG_FN();

-- Primary key
SELECT 'ALTER TABLE managed_tables.country ADD CONSTRAINT country_pk PRIMARY KEY(relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'country'
      AND CONSTRAINT_NAME = 'country_pk'
 )
\gexec

-- Unique name
SELECT 'ALTER TABLE managed_tables.country ADD CONSTRAINT country_uk_name UNIQUE(name)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'country'
      AND CONSTRAINT_NAME = 'country_uk_name'
 )
\gexec

-- Unique code_2
SELECT 'ALTER TABLE managed_tables.country ADD CONSTRAINT country_uk_code_2 UNIQUE(code_2)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'country'
      AND CONSTRAINT_NAME = 'country_uk_code_2'
 )
\gexec

-- Unique code_3
SELECT 'ALTER TABLE managed_tables.country ADD CONSTRAINT country_uk_code_3 UNIQUE(code_3)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'country'
      AND CONSTRAINT_NAME = 'country_uk_code_3'
 )
\gexec

-- Check constraint
-- - If has_mailing_code is true , then mailing_code_match and mailing_code_format must both be NON-NULL
-- - If has_mailing_code is false, then mailing_code_match and mailing_code_format must both be NULL
SELECT 'ALTER TABLE managed_tables.country ADD CONSTRAINT country_ck_mailing_fields CHECK((has_mailing_code = (mailing_code_match IS NOT NULL)) AND (has_mailing_code = (mailing_code_format IS NOT NULL)))'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'country'
      AND CONSTRAINT_NAME = 'country_ck_mailing_fields'
 )
\gexec

-- ==================
-- == region table ==
-- ==================
CREATE TABLE IF NOT EXISTS managed_tables.region(
   country_relid INTEGER NOT NULL
  ,name          TEXT    NOT NULL
  ,code          CHAR(2) NOT NULL
  ,ord           INTEGER NOT NULL
  ,active        BOOLEAN DEFAULT TRUE
) INHERITS(managed_tables.base);

-- Base trigger
CREATE OR REPLACE TRIGGER region_tg_ins
BEFORE INSERT ON managed_tables.region
FOR EACH ROW
EXECUTE FUNCTION BASE_TG_FN();

CREATE OR REPLACE TRIGGER region_tg_upd
BEFORE UPDATE ON managed_tables.region
FOR EACH ROW
WHEN (OLD IS DISTINCT FROM NEW)
EXECUTE FUNCTION BASE_TG_FN();

-- Primary key
SELECT 'ALTER TABLE managed_tables.region ADD CONSTRAINT region_pk PRIMARY KEY(relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'region'
      AND CONSTRAINT_NAME = 'region_pk'
 )
\gexec

-- Unique (name, country)
SELECT 'ALTER TABLE managed_tables.region ADD CONSTRAINT region_uk_name_country UNIQUE(name, country_relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'region'
      AND CONSTRAINT_NAME = 'region_uk_name_country'
 )
\gexec

-- Unique (code, country)
SELECT 'ALTER TABLE managed_tables.region ADD CONSTRAINT region_uk_code_country UNIQUE(code, country_relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'region'
      AND CONSTRAINT_NAME = 'region_uk_code_country'
 )
\gexec

-- Country exists
SELECT 'ALTER TABLE managed_tables.region ADD CONSTRAINT region_country_fk FOREIGN KEY(country_relid) REFERENCES managed_tables.country(relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'region'
      AND CONSTRAINT_NAME = 'region_country_fk'
 )
\gexec
