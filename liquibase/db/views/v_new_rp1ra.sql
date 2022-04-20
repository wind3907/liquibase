REM @(#) src/schema/views/v_new_rp1ra.sql, swms, swms.9, 10.1.1 9/7/06 1.4
REM File : @(#) src/schema/views/v_new_rp1ra.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_new_rp1ra.sql, swms, swms.9, 10.1.1
REM             -- Maintenance Log --
REM     19-APR-2004  D# 11555 acphxs: Selecting RDC Address Info for SNs.
REM
CREATE OR REPLACE VIEW SWMS.V_NEW_RP1RA (ERM_ID,BUYER,
    ERM_TYPE,EXP_ARRIV_DATE,SCHED_DATE,STATUS,SOURCE_ID,
    SHIP_ADDR1,LOAD_NO,CARR_ID,CASES,AREA,SORT) AS 
    SELECT e.erm_id, p.buyer, e.erm_type,                                           
               e.exp_arriv_date, e.sched_date,                                      
               e.status, decode(e.erm_type,'SN',r.rdc_nbr,e.source_id) source_id,
               decode(e.erm_type,'SN',r.name,e.ship_addr1) ship_addr1, e.load_no, 
               e.carr_id, SUM(d.qty / p.spc) cases,                                 
               NVL(a.area_code, 'X') area, NVL(a.sort, 1000) sort                   
          FROM swms_areas a, swms_sub_areas sa, loc l, erd d1,                      
               pm p, erd d, erm e, sn_header s, rdc_address r 
         WHERE a.area_code(+) = sa.area_code                                        
           AND sa.sub_area_code(+) = SUBSTR(l.logi_loc, 1, 1)                       
           AND l.prod_id = d1.prod_id                                               
           AND d1.erm_line_id in (SELECT MIN(erm_line_id) FROM erd d2               
                                   WHERE d2.erm_id = d.erm_id)                      
           AND d1.erm_id = e.erm_id                                                 
           AND p.prod_id = d.prod_id                                                
           AND d.erm_id = e.erm_id                                                  
           AND e.erm_id = s.sn_no(+)
           AND s.rdc_nbr = r.rdc_nbr(+)
      GROUP BY a.sort, a.area_code, e.erm_id, p.buyer, e.erm_type,                  
               e.exp_arriv_date, e.sched_date,                                      
               e.status,decode(e.erm_type,'SN',r.rdc_nbr,e.source_id), 
               decode(e.erm_type,'SN',r.name,e.ship_addr1), e.load_no,
               e.carr_id, d1.erm_line_id 
    UNION                                                                           
        SELECT e.erm_id, p.buyer, e.erm_type,                                       
               e.exp_arriv_date, e.sched_date,                                      
               e.status, decode(e.erm_type,'SN',r.rdc_nbr,e.source_id) source_id,
               decode(e.erm_type,'SN',r.name,e.ship_addr1) ship_addr1, e.load_no,
               e.carr_id, SUM(d.qty / p.spc) cases,                                 
               NVL(a.area_code, 'X') area, NVL(a.sort, 1000) sort                   
          FROM swms_areas a, swms_sub_areas sa, inv i, erd d1,                      
               pm p, erd d, erm e, sn_header s, rdc_address r 
         WHERE a.area_code(+) = sa.area_code                                        
           AND sa.sub_area_code(+) = SUBSTR(i.plogi_loc, 1, 1)                      
           AND (i.exp_date, i.qoh, i.logi_loc) IN (select MIN(i2.exp_date),         
                                                          MIN(i2.qoh),              
                                                          MIN(i2.logi_loc)          
                                                     from inv i2                    
                                                    where i2.prod_id = d1.prod_id)  
           AND i.prod_id = d1.prod_id                                               
           AND NOT EXISTS (SELECT 'x' FROM loc l                                    
                            WHERE l.prod_id = d1.prod_id)                           
           AND d1.erm_line_id in (SELECT MIN(erm_line_id) FROM erd d2               
                                   WHERE d2.erm_id = d.erm_id)                      
           AND d1.erm_id = e.erm_id                                                 
           AND p.prod_id = d.prod_id                                                
           AND d.erm_id = e.erm_id                                                  
           AND e.erm_id = s.sn_no(+)    
           AND s.rdc_nbr = r.rdc_nbr(+) 
      GROUP BY a.sort, a.area_code, e.erm_id, p.buyer, e.erm_type,                  
               e.exp_arriv_date, e.sched_date,                                      
               e.status,decode(e.erm_type,'SN',r.rdc_nbr,e.source_id), 
               decode(e.erm_type,'SN',r.name,e.ship_addr1), e.load_no,
               e.carr_id,
               d1.erm_line_id, i.exp_date, i.qoh, i.logi_loc                        
    UNION                                                                           
        SELECT e.erm_id, p.buyer, e.erm_type,                                       
               e.exp_arriv_date, e.sched_date,                                      
               e.status, decode(e.erm_type,'SN',r.rdc_nbr,e.source_id) source_id,
               decode(e.erm_type,'SN',r.name,e.ship_addr1) ship_addr1, e.load_no,
               e.carr_id, SUM(d.qty / p.spc) cases,                                 
               'X' area, 1000 sort                                                  
          FROM pm p, erd d, erm e, sn_header s, rdc_address r 
         WHERE p.prod_id = d.prod_id                                                
           AND NOT EXISTS (SELECT 'x' FROM inv i                                    
                            WHERE i.prod_id = d.prod_id)                            
           AND d.erm_line_id IN (SELECT MIN(erm_line_id) FROM erd d2                
                                  WHERE d2.erm_id = d.erm_id)                       
           AND d.erm_id = e.erm_id                                                  
           AND e.erm_id = s.sn_no(+)    
           AND s.rdc_nbr = r.rdc_nbr(+) 
      GROUP BY e.erm_id, p.buyer, e.erm_type,                                       
               e.exp_arriv_date, e.sched_date,                                      
               e.status, decode(e.erm_type,'SN',r.rdc_nbr,e.source_id),
                decode(e.erm_type,'SN',r.name,e.ship_addr1), e.load_no,
               e.carr_id;                                   
 
