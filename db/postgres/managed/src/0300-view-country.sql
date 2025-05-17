-- Country regions view, where regions is an array of all regions for the country, that is empty if there are no regions
CREATE OR REPLACE VIEW managed_views.country_regions AS
SELECT jsonb_build_object(
          'id'                ,managed_code.RELID_TO_ID(c.relid)
         ,'version'           ,cb.version
         ,'created'           ,cb.created
         ,'modified'          ,cb.modified
         ,'name'              ,c.name
         ,'code2'             ,c.code_2
         ,'code3'             ,c.code_3
         ,'hasRegions'        ,c.has_regions
         ,'hasMailingCode'    ,c.has_mailing_code
         ,'mailingCodeMatch'  ,c.mailing_code_match
         ,'mailingCodeFormat' ,c.mailing_code_format
         ,'regions'           ,(SELECT jsonb_agg(
                                         jsonb_build_object(
                                            'id'       , managed_code.RELID_TO_ID(r.relid)
                                           ,'version'  ,cb.version
                                           ,'created'  ,cb.created
                                           ,'modified' ,cb.modified
                                           ,'name'     , r.name
                                           ,'code'     , r.code
                                         )
                                         ORDER
                                            BY r.name
                                       ) region
                                  FROM managed_tables.region r
                                  JOIN managed_tables.base rb
                                    ON rb.relid = r.relid
                                 WHERE r.country_relid = c.relid
                               )
       ) country_regions
  FROM managed_tables.country c
  JOIN managed_tables.base cb
    ON cb.relid = c.relid
 ORDER
    BY c.name;
