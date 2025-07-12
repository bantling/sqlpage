-- Country regions view, where regions is an array of all regions for the country, that is an empty array if there are no regions
CREATE OR REPLACE VIEW managed_views.country_regions AS
SELECT JSONB_BUILD_OBJECT(
          'id'                ,managed_code.RELID_TO_ID(c.relid)
         ,'version'           ,c.version
         ,'created'           ,c.created
         ,'modified'          ,c.modified
         ,'name'              ,c.name
         ,'code2'             ,c.code_2
         ,'code3'             ,c.code_3
         ,'hasRegions'        ,c.has_regions
         ,'hasMailingCode'    ,c.has_mailing_code
         ,'mailingCodeMatch'  ,c.mailing_code_match
         ,'mailingCodeFormat' ,c.mailing_code_format
         ,'regions'           ,(SELECT COALESCE(JSONB_AGG(
                                         JSONB_BUILD_OBJECT(
                                            'id'       , managed_code.RELID_TO_ID(r.relid)
                                           ,'version'  , r.version
                                           ,'created'  , r.created
                                           ,'modified' , r.modified
                                           ,'name'     , r.name
                                           ,'code'     , r.code
                                         )
                                         ORDER
                                            BY r.name
                                       ), '[]'::JSONB)
                                  FROM managed_tables.region r
                                 WHERE r.country_relid = c.relid
                               )
       ) country_regions
  FROM managed_tables.country c
 ORDER
    BY c.name;
