-- Join customer_person and their optional address
CREATE OR REPLACE VIEW managed_views.customer_person_address AS
SELECT JSONB_BUILD_OBJECT(
          'id'          ,managed_code.RELID_TO_ID(cp.relid)
         ,'version'     ,cp.version
         ,'created'     ,cp.created
         ,'changed'     ,cp.modified
         ,'first_name'  ,cp.first_name
         ,'middle_name' ,cp.middle_name
         ,'last_name'   ,cp.last_name
         ,'address'    ,(SELECT JSONB_STRIP_NULLS(
                                  JSONB_BUILD_OBJECT(
                                     'id'           ,managed_code.RELID_TO_ID(a.relid)
                                    ,'version'      ,a.version
                                    ,'created'      ,a.created
                                    ,'changed'      ,a.modified
                                    ,'city'         ,a.city
                                    ,'address'      ,a.address
                                    ,'country'      ,c.code_2
                                    ,'region'       ,r.code
                                    ,'mailing_code' ,a.mailing_code
                                  )
                                ) address
                            FROM managed_tables.address a
                            JOIN managed_tables.country c
                              ON c.relid = a.country_relid
                            LEFT
                            JOIN managed_tables.region r
                              ON r.relid = a.region_relid
                           WHERE a.relid = cp.address_relid
                        )
       ) customer_person_address
  FROM managed_tables.customer_person cp
 ORDER
    BY  cp.last_name
       ,cp.first_name
       ,cp.middle_name;

-- Join customer_business and their address(es)
CREATE OR REPLACE VIEW managed_views.customer_business_address AS
SELECT JSONB_BUILD_OBJECT(
          'id'         ,managed_code.RELID_TO_ID(cb.relid)
         ,'version'    ,cb.version
         ,'created'    ,cb.created
         ,'changed'    ,cb.modified
         ,'name'       ,cb.name
         ,'addresses'  ,(SELECT JSONB_AGG(
                                  JSONB_STRIP_NULLS(
                                    JSONB_BUILD_OBJECT(
                                       'id'          ,managed_code.RELID_TO_ID(a.relid)
                                      ,'type'        ,t.name
                                      ,'version'     ,a.version
                                      ,'created'     ,a.created
                                      ,'changed'     ,a.modified
                                      ,'city'        ,a.city
                                      ,'address_1'   ,a.address
                                      ,'address_2'   ,a.address_2
                                      ,'address_3'   ,a.address_3
                                      ,'country'     ,c.code_2
                                      ,'region'      ,r.code
                                      ,'mailing_code',a.mailing_code
                                    )
                                  )
                                  ORDER
                                     BY t.ord
                                ) address
                           FROM managed_tables.address a
                           JOIN managed_tables.country c
                             ON c.relid = a.country_relid
                           LEFT
                           JOIN managed_tables.region r
                             ON r.relid = a.region_relid  
                           JOIN managed_tables.address_type t
                             ON t.relid = a.address_type_relid
                           JOIN managed_tables.customer_business_address_jt cba
                             ON cba.business_relid = c.relid
                            AND cba.address_relid  = a.relid
                        )
       ) customer_business_address
  FROM managed_tables.customer_business cb
 ORDER
    BY cb.name;
