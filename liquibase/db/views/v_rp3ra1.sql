------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_rp3ra1
--
-- Description:
--    This view is used in the rp3ra.sql No_Home_LOCATION report.  This view
--    will contain all items for POs in SCH, NEW status which do not have
--    a home location.The report will filter out all could records, by 
--    checking for invalid/missing case dimensions.
--
-- Used by:
--    Report rp3ra.sql
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/01/02 pxppp    rs239b DN 10994  Created.  
--                      RCD non-dependent changes.
--    08/27/02 acpppp   Defect # 11357:Syspar check added so that 
--                      no home location report will show records 
--                      with error code as "MD" only if
--                      PUTAWAY_DIMENSION syspar has been set to "I"
--    04/01/10 sth0458  DN12554 - 212 Enh - SCE057 - 
--                      Add UOM field to SWMS
--                      Expanded the length of prod size to accomodate 
--                      for prod size unit.
--                      Changed queries to fetch prod_size_unit along with 
--                      prod_size
------------------------------------------------------------------------------

PROMPT Create view v_rp3ra1

--This view will pick up all the product details of new/sch POs
CREATE OR REPLACE VIEW swms.v_rp3ra1(
   prod_id,
   cust_pref_vendor,
   pack,
   prod_size,
   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
   /* Declare prod size unit */ 
   prod_size_unit,
   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
   brand,
   descrip,
   erm_id,
   status,
   erm_type,
   sched_date,
   exp_arriv_date,
   vend_name,
   qty,
   cube,
   uom,
   ti,
   pallet_type,
   hi,
   spc,
   stock_type,
   area, stage,
   case_height, case_width, case_length, 
   split_trk,
   g_weight, case_cube )
AS
SELECT d.prod_id,
       d.cust_pref_vendor,
       m.pack,
       m.prod_size,
        /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
        /* Declare prod size unit */ 
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
       m.case_height,
       m.case_width,
       m.case_length,
       m.split_trk, 
       m.g_weight, 
       m.case_cube
 FROM  erm e, pm m, erd d
WHERE  d.prod_id  = m.prod_id
  AND  d.cust_pref_vendor = m.cust_pref_vendor
  AND  nvl(m.mx_item_assign_flag,'N') != 'Y' /* 08-25-2015 Sunil changes to handle Symbotic */
  AND   d.erm_id = e.erm_id
  AND   e.status in ('NEW','SCH')
  AND   'I' = (select config_flag_val from sys_config      
              where config_flag_name='PUTAWAY_DIMENSION')
/

