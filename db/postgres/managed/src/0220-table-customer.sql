-- ========================
-- == address type table ==
-- ========================
CREATE TABLE IF NOT EXISTS managed_tables.address_type(
   name  TEXT    NOT NULL
  ,ord   INTEGER NOT NULL
) INHERITS(managed_tables.base);

-- Base trigger
CREATE OR REPLACE TRIGGER address_type_tg
BEFORE INSERT OR UPDATE ON managed_tables.address_type
FOR EACH ROW
EXECUTE FUNCTION base_tg_fn();

SELECT 'ALTER TABLE managed_tables.address_type ADD CONSTRAINT address_type_pk PRIMARY KEY(relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'address_type'
      AND CONSTRAINT_NAME = 'address_type_pk'
 )
\gexec

SELECT 'ALTER TABLE managed_tables.address_type ADD CONSTRAINT address_type_uk_name UNIQUE(name)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'address_type'
      AND CONSTRAINT_NAME = 'address_type_uk_name'
 )
\gexec

-- ===================
-- == address table ==
-- ===================
CREATE TABLE IF NOT EXISTS managed_tables.address(
   address_type_relid BIGINT
  ,country_relid      BIGINT NOT NULL
  ,region_relid       BIGINT
  ,city               TEXT   NOT NULL
  ,address            TEXT   NOT NULL
  ,address_2          TEXT
  ,address_3          TEXT
  ,mailing_code       TEXT
) INHERITS(managed_tables.base);

-- Base trigger
CREATE OR REPLACE TRIGGER address_tg
BEFORE INSERT OR UPDATE ON managed_tables.address
FOR EACH ROW
EXECUTE FUNCTION base_tg_fn();

SELECT 'ALTER TABLE managed_tables.address ADD CONSTRAINT address_pk PRIMARY KEY(relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'address'
      AND CONSTRAINT_NAME = 'address_pk'
 )
\gexec

SELECT 'ALTER TABLE managed_tables.address ADD CONSTRAINT address_type_fk FOREIGN KEY(address_type_relid) REFERENCES managed_tables.address_type(relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'address'
      AND CONSTRAINT_NAME = 'address_type_fk'
 )
\gexec

SELECT 'ALTER TABLE managed_tables.address ADD CONSTRAINT address_country_fk FOREIGN KEY(country_relid) REFERENCES managed_tables.country(relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'address'
      AND CONSTRAINT_NAME = 'address_country_fk'
 )
\gexec

SELECT 'ALTER TABLE managed_tables.address ADD CONSTRAINT address_region_fk FOREIGN KEY(region_relid) REFERENCES managed_tables.region(relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'address'
      AND CONSTRAINT_NAME = 'address_region_fk'
 )
\gexec

-- =====================
-- customer person table
-- =====================
CREATE TABLE IF NOT EXISTS managed_tables.customer_person(
   address_relid BIGINT
  ,first_name    TEXT   NOT NULL
  ,middle_name   TEXT
  ,last_name     TEXT   NOT NULL
) INHERITS(managed_tables.base);

-- Base trigger
CREATE OR REPLACE TRIGGER customer_person_tg
BEFORE INSERT OR UPDATE ON managed_tables.customer_person
FOR EACH ROW
EXECUTE FUNCTION base_tg_fn();

SELECT 'ALTER TABLE managed_tables.customer_person ADD CONSTRAINT customer_person_pk PRIMARY KEY(relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'customer_person'
      AND CONSTRAINT_NAME = 'customer_person_pk'
 )
\gexec

SELECT 'ALTER TABLE managed_tables.customer_person ADD CONSTRAINT customer_person_addresss_fk FOREIGN KEY(address_relid) REFERENCES managed_tables.address(relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'customer_person'
      AND CONSTRAINT_NAME = 'customer_person_address_fk'
 )
\gexec

-- Trigger function to ensure that customer_person_address rows do NOT have an address type
CREATE OR REPLACE FUNCTION customer_person_address_tg_fn() RETURNS trigger AS
$$
BEGIN
  IF (SELECT address_type_relid IS NOT NULL FROM managed_tables.address WHERE relid = NEW.address_relid) THEN
    -- The related address has an address type
    RAISE EXCEPTION 'A customer person address cannot have an address type';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Person address trigger
CREATE OR REPLACE TRIGGER customer_person_address_tg
BEFORE INSERT OR UPDATE ON managed_tables.customer_person
FOR EACH ROW
EXECUTE FUNCTION customer_person_address_tg_fn();

-- ==========================
-- == business customer table
-- ==========================
CREATE TABLE IF NOT EXISTS managed_tables.customer_business(
   name  TEXT   NOT NULL
) INHERITS(managed_tables.base);

-- Base trigger
CREATE OR REPLACE TRIGGER customer_business_tg
BEFORE INSERT OR UPDATE ON managed_tables.customer_business
FOR EACH ROW
EXECUTE FUNCTION base_tg_fn();

SELECT 'ALTER TABLE managed_tables.customer_business ADD CONSTRAINT customer_business_pk PRIMARY KEY(relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'customer_business'
      AND CONSTRAINT_NAME = 'customer_business_pk'
 )
\gexec

-- =================================
-- == business address join table ==
-- =================================
CREATE TABLE IF NOT EXISTS managed_tables.customer_business_address_jt(
   business_relid     BIGINT
  ,address_relid      BIGINT
);

SELECT 'ALTER TABLE managed_tables.customer_business_address_jt ADD CONSTRAINT customer_business_address_jt_pk PRIMARY KEY(business_relid, address_relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'customer_business_address'
      AND CONSTRAINT_NAME = 'customer_business_address_jt_pk'
 )
\gexec

SELECT 'ALTER TABLE managed_tables.customer_business_address_jt ADD CONSTRAINT customer_business_address_jt_bfk FOREIGN KEY(business_relid) REFERENCES managed_tables.customer_business(relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'customer_business_address'
      AND CONSTRAINT_NAME = 'customer_business_address_jt_bfk'
 )
\gexec

SELECT 'ALTER TABLE managed_tables.customer_business_address_jt ADD CONSTRAINT customer_business_address_jt_afk FOREIGN KEY(address_relid) REFERENCES managed_tables.address(relid)'
 WHERE NOT EXISTS (
   SELECT NULL
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = 'managed_tables'
      AND TABLE_NAME      = 'customer_business_address'
      AND CONSTRAINT_NAME = 'customer_business_address_jt_afk'
 )
\gexec

-- Trigger function to ensure that:
-- 1. An address joined to a business has an address type
-- 2. There does not already exist another address joined to the same business with the same address type
CREATE OR REPLACE FUNCTION customer_business_address_jt_tg_fn() RETURNS trigger AS
$$
DECLARE
    V_ADDRESS_TYPE_RELID BIGINT;
    V_ADDRESS_TYPE_NAME TEXT;
BEGIN
  -- Get address type relid and name
  SELECT a.address_type_relid
        ,mtat.name
    INTO V_ADDRESS_TYPE_RELID
        ,V_ADDRESS_TYPE_NAME
    FROM managed_tables.address a
    JOIN managed_tables.address_type mtat
      ON mtat.relid = a.address_type_relid
   WHERE relid = NEW.address_relid;

  -- The related address must have a type
  IF V_ADDRESS_TYPE_RELID IS NULL THEN
    RAISE EXCEPTION 'A customer business address must have an address type: business relid = %, address relid = %', NEW.business_relid, NEW.address_relid;
  END IF;

  -- Check if there already exists a mapping of this business to another address of the same type
  IF EXISTS (
    SELECT 1
      FROM managed_tables.customer_business_address_jt cbaj
      JOIN managed_tables.address mtad
        ON mtad.relid = cbaj.address_relid
       AND mtad.address_type_relid = V_ADDRESS_TYPE_RELID
     WHERE cbaj.business_relid = NEW.business_relid
  ) THEN
    RAISE EXCEPTION 'A customer business cannot have two addresses of the same type: business relid = %, address type = %', NEW.business_relid, V_ADDRESS_TYPE_NAME;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Business address trigger
CREATE OR REPLACE TRIGGER customer_business_address_jt_tg
BEFORE INSERT OR UPDATE ON managed_tables.customer_business_address_jt
FOR EACH ROW
EXECUTE FUNCTION customer_business_address_jt_tg_fn();
