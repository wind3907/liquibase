-- 	Modification History
--	-------------------------------
--     04/01/10   sth0458 	DN12554 - 212 Legacy Enhancements - SCE057 - 
--					Add UOM field to SWMS
--            		           	Expanded the length of prod size to accomodate 
--					for prod size unit.
-- 				  	Changed queries to fetch prod_size_unit along with prod_size
CREATE OR REPLACE FORCE VIEW "SWMS"."V_RP1RC" ("ERM_TYPE", "EXP_ARRIV_DATE", "SCHED_DATE", "REC_DATE", "SOURCE_ID", "CARR_ID", "STATUS", "ERM_ID", "PROD_ID", "CUST_PREF_VENDOR", "QTY", "PALLET_ID", "LOGI_LOC", "PACK", "PROD_SIZE", "PROD_SIZE_UNIT","BRAND", "DESCRIP", "MFG_SKU", "SPC") AS 
  SELECT e.erm_type erm_type,
              e.exp_arriv_date exp_arriv_date,
              e.sched_date sched_date,
              e.rec_date rec_date,
              e.source_id source_id,
              e.carr_id carr_id,
              e.status status,
              p.rec_id erm_id,
              p.prod_id prod_id,
              p.cust_pref_vendor cust_pref_vendor,
              p.qty qty,
              p.pallet_id pallet_id,
              p.dest_loc logi_loc,
              m.pack pack,
              m.prod_size prod_size,
-- 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - Begin
--			   Declare prod size unit
			  m.prod_size_unit prod_size_unit,
-- 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - End                       
              m.brand brand,
              m.descrip descrip,
              m.mfg_sku mfg_sku,
              m.spc spc
        FROM  pm m, erm e, putawaylst p
        WHERE p.rec_id = e.erm_id
        AND   p.prod_id = m.prod_id
        AND   p.cust_pref_vendor = m.cust_pref_vendor
        AND   p.inv_status = 'HLD'
;

