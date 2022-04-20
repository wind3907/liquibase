
--	--------------------------------
--     04/01/10   sth0458     DN12554 - 212 Enh - SCE057 - 
--                            Add UOM field to SWMS.Expanded the length
--                            of prod size to accomodate for prod size 
--                            unit.Changed queries to fetch 
--                            prod_size_unit along with prod_size

CREATE OR REPLACE VIEW swms.v_rp3ra AS
SELECT d.prod_id,                                                               
       d.cust_pref_vendor,                                                      
       m.pack,                                                                  
       m.prod_size,  
		/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		m.prod_size_unit,
		/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
       m.brand,                                                                 
       m.descrip,                                                               
       d.erm_id,                                                                
       e.status,                                                                
       e.erm_type,                                                              
       e.sched_date,                                                            
       e.exp_arriv_date,                                                        
       e.vend_name,                                                             
       d.qty,                                                                   
       d.qty * m.split_cube cube,                                               
       d.uom,                                                                   
       m.ti,                                                                    
       m.pallet_type,                                                           
       m.hi,                                                                    
       m.spc,                                                                   
       m.stock_type,                                                            
       decode(m.area,'C','COOLER AREA','D','DRY AREA','F','FREEZER AREA', AREA) AREA,
       m.stage,
       m.split_trk, 
       m.case_cube, 
       m.g_weight, 
       m.case_length, m.case_width, m.case_height
 FROM  erm e, pm m, erd d                                                       
WHERE  d.prod_id  = m.prod_id                                                   
  AND  d.cust_pref_vendor = m.cust_pref_vendor                                  
  AND  nvl(m.mx_item_assign_flag,'N') != 'Y' /* 08-25-2015 Sunil changes to handle Symbotic */
  AND  not exists (select zone_id                                               
                     from zone                                                  
                    where zone_id = m.zone_id                                   
                      and zone_type = 'PUT'                                     
                      and rule_id in(1,3))                                      
  AND  not exists (select prod_id                                               
                     from inv                                                   
                    where prod_id = d.prod_id                                   
                      and cust_pref_vendor = d.cust_pref_vendor                 
                      and logi_loc = plogi_loc)                                 
  AND   d.erm_id = e.erm_id                                                     
  AND   e.status in ('NEW','SCH');

