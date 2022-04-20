------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_rp1rb
--
-- Description:
--    This view is used in the rp1rb.pc reports. 
--
-- Used by:
--    Report rp1rb.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--     04/01/10   sth0458 	DN12554 - 212 Legacy Enhancements - SCE057 - 
--					Add UOM field to SWMS
--            		           	Expanded the length of prod size to accomodate 
--					for prod size unit.
--				  	Changed queries to fetch prod_size_unit along with prod_size
------------------------------------------------------------------------------ 
 CREATE OR REPLACE FORCE VIEW "SWMS"."V_RP1RB" ("ERM_ID", "ERM_TYPE", "EXP_ARRIV_DATE", "SHIP_DATE", "REC_DATE", "SOURCE_ID", "STATUS", "CMT", "ERM_LINE_ID", "PROD_ID", "CUST_PREF_VENDOR", "QTY", "UOM", "PACK", "PROD_SIZE","PROD_SIZE_UNIT", "BRAND", "DESCRIP", "SPC", "TI", "HI", "PALLET_TYPE", "SCHED_DATE") AS 
  select m.erm_id erm_id,
              m.erm_type erm_type,
              m.exp_arriv_date exp_arriv_date,
              m.ship_date ship_date,
              m.rec_date rec_date,
              m.source_id source_id,
              m.status status,
              m.cmt cmt,
              d.erm_line_id erm_line_id,
              d.prod_id prod_id,
              p.cust_pref_vendor cust_pref_vendor,
              d.qty qty,
              d.uom uom,
              p.pack pack,
              p.prod_size prod_size,
			  /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - Begin */
			  p.prod_size_unit prod_size_unit,
			  /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - End */
              p.brand brand,
              p.descrip descrip,
              p.spc spc,
              p.ti ti,
              p.hi hi,
              p.pallet_type pallet_type,
                    m.sched_date sched_date
        from  pm p, erd d, erm m
        where p.prod_id = d.prod_id
        and   p.cust_pref_vendor = d.cust_pref_vendor
        and   m.erm_id = d.erm_id
        and   m.erm_type = 'CM'
/

