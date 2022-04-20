--  Modification History 
--  04/01/10   sth0458 DN12554 - 212 Legacy Enhancements - SCE057 - 
--						Add UOM field to SWMS
--            		    Expanded the length of prod size to accomodate 
--						for prod size unit.
-- 				  		Changed queries to fetch prod_size_unit along with prod_size
CREATE OR REPLACE FORCE VIEW "SWMS"."V_RP2RA" ("PALLET_ID", "QTY", "PROD_ID", "CUBE", "CUST_PREF_VENDOR", "UOM", "PACK", "PROD_SIZE", "PROD_SIZE_UNIT", "BRAND", "DESCRIP", "TI", "PALLET_TYPE", "HI", "SPC", "AREA", "ZONE_ID", "ERM_ID", "ERM_TYPE", "STATUS", "EXP_ARRIV_DATE", "SCHED_DATE", "SOURCE_ID", "AWM", "PICK_FREQ") AS 
  SELECT p.pallet_id pallet_id,
          p.qty qty,
          p.prod_id prod_id,
          ((p.qty / m.spc) * m.case_cube) cube,
          p.cust_pref_vendor cust_pref_vendor,
            p.uom uom,
          m.pack pack,
		  m.prod_size prod_size,
-- 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - Begin
-- Retrieve prod size unit
          m.prod_size_unit prod_size_unit,
-- 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - End 			
          m.brand brand,
          m.descrip descrip,
          m.ti ti,
          m.pallet_type pallet_type,
          m.hi hi,
          m.spc spc,
          m.area,
          m.zone_id,
          e.erm_id erm_id,
          e.erm_type erm_type,
          e.status status,
          e.exp_arriv_date exp_arriv_date,
          e.sched_date sched_date,
          e.source_id source_id,
          a1.qty awm,
          a2.qty pick_freq
  FROM awm a2, awm a1, erm e, pm m, putawaylst p
 WHERE a2.awm_type(+) = 'F'
   AND a2.freq(+) = 'M'
   AND a2.uom(+) = 2
   AND a2.prod_id(+) = p.prod_id
   AND a2.cust_pref_vendor(+) = p.cust_pref_vendor
   AND a1.awm_type(+) = 'W'
   AND a1.uom(+) = 2
   AND a1.freq(+) = 'M'
   AND a1.prod_id(+) = p.prod_id
   AND a1.cust_pref_vendor(+) = p.cust_pref_vendor
   AND e.erm_id = p.rec_id
   AND m.prod_id = p.prod_id
   AND m.cust_pref_vendor = p.cust_pref_vendor
   AND SUBSTR(p.dest_loc, 1, 1) = '*'
;
