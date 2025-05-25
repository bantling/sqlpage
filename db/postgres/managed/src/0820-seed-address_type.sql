-- Seed address types
--
-- If an address type changes name, two steps are required:
-- 1. Write an update query before the hard-coded data
-- 2. Update the hard-coded data with the new name
--

-- Hard-coded address type data
WITH ADDR_TYPE_DATA AS (
  SELECT s.*
        ,ROW_NUMBER() OVER() AS ord
    FROM (VALUES
            ('Physical')
           ,('Mailing')
           ,('Billing')
         ) AS s(name)
)
INSERT INTO managed_tables.address_type(
  description
 ,terms
 ,name
 ,ord
)
SELECT atd.name                         AS description
      ,TO_TSVECTOR('english', atd.name) AS terms
      ,atd.*
  FROM ADDR_TYPE_DATA atd
    ON CONFLICT(name) DO
UPDATE
   SET ord  = excluded.ord
 WHERE address_type.ord  != excluded.ord;
