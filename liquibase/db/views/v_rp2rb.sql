--       Modification History
--	-------------------------------
--     04/01/10   sth0458  DN12554 - 212 Enh - SCE057 - 
--                         Add UOM field to SWMS.Expanded the length
--                         of prod size to accomodate for prod size 
--                         unit.Changed queries to fetch 
--                         prod_size_unit along with prod_size
--     01/24/11   prjxl000 CR20506.Added putaway_put = 'N' check for the 2nd
--	     	       	   and 3rd union select statements. This fixes the
--			   problem that if the PO/SN/VSN is in CLO/VCH status
--			   and its pallet(s) have been putaway, they shouldn't
--			   show up on the report.
--    05/06/12   vkat2696 CRQ36264 -swms12.5 fixes . Included the trans table in order the fetch  
--                         the corrected quantity from the proforma correction screen.
--                         This fixes the problem of quantity not getting updated properly  in the report.  
CREATE OR REPLACE VIEW "SWMS"."V_RP2RB" ("DEST_LOC","PALLET_ID",
    "QTY","PROD_ID","CUST_PREF_VENDOR","CATEGORY","PACK",
	/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
	/* Included prod_size_unit */
    "PROD_SIZE","PROD_SIZE_UNIT","BRAND","DESCRIP","TI","PALLET_TYPE","HI","SPC",
	/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End*/
    "ERM_ID","ERM_TYPE","STATUS","EXP_ARRIV_DATE","SCHED_DATE",
    "SOURCE_ID","SORT","LOGI_LOC") AS 
SELECT    p.dest_loc dest_loc,      -- Check OPN PO's. 
          p.pallet_id pallet_id, 
          p.qty qty,
          p.prod_id prod_id, 
          p.cust_pref_vendor cust_pref_vendor, 
          m.category category, 
          m.pack pack, 
          m.prod_size prod_size, 
		  /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		  /*  Declare prod size unit */
		  m.prod_size_unit prod_size_unit,
		  /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
          m.brand brand, 
          m.descrip descrip, 
          m.ti ti, 
          m.pallet_type pallet_type, 
          m.hi hi, 
          m.spc spc, 
          e.erm_id erm_id, 
          e.erm_type erm_type, 
          e.status status, 
          e.exp_arriv_date, 
          e.sched_date, 
          e.source_id, 
          a.sort sort,
          l.logi_loc logi_loc 
   FROM  swms.swms_sub_areas sa, swms.swms_areas a, swms.aisle_info ai, 
         swms.loc l, swms.erm e, swms.pm m, swms.putawaylst p
   WHERE sa.area_code          = a.area_code 
     AND sa.sub_area_code      = ai.sub_area_code 
     AND ai.name = nvl(substr(p.inv_dest_loc,1,2),substr(p.dest_loc,1,2)) 
     AND p.prod_id             = m.prod_id 
     AND p.cust_pref_vendor    = m.cust_pref_vendor 
     AND p.rec_id              = e.erm_id 
     AND l.perm(+)             = 'Y' 
     AND l.rank(+)             = 1 
     AND l.prod_id(+)          = p.prod_id 
     AND l.cust_pref_vendor(+) = p.cust_pref_vendor 
     AND l.uom(+)             <> 1
     AND e.status = 'OPN' 
     AND p.putaway_put = 'N'
UNION 
SELECT 	  p.dest_loc dest_loc,      			-- Check CLO, VCH PO's.  If a putawaylst 
          p.pallet_id pallet_id,    			-- record exists for a CLO or VCH PO
		  /*05/06/12   vkat2696 CRQ36264 -swms12.5 fixes- to fetch the corrected quantity*/
		  /*Added the qty columns of trans table to get the updated quantity*/	
		  t.qty + NVL(t.qty_expected,0) qty,    -- then this indicates the pallet not 
		  p.prod_id prod_id,        			-- confirmed because confirmed putaways 
		  p.cust_pref_vendor cust_pref_vendor,  -- are deleted when 
		  m.category category,				    -- the PO is closed. 
		  m.pack pack,
          m.prod_size prod_size,
		  /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		  /* Declare prod_size_unit*/ 
		  m.prod_size_unit prod_size_unit,
          /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */ 
		  m.brand brand,
          m.descrip descrip,
          m.ti ti,
          m.pallet_type pallet_type,
          m.hi hi,
          m.spc spc,
          e.erm_id erm_id,
          e.erm_type erm_type,
          e.status status,
          e.exp_arriv_date,
          e.sched_date,
          e.source_id,
          a.sort sort,
          l.logi_loc logi_loc
   FROM  swms.swms_sub_areas sa, swms.swms_areas a, swms.aisle_info ai, swms.loc l,
         swms.erm e, swms.pm m, swms.putawaylst p, swms.trans t
   WHERE sa.area_code = a.area_code
     AND sa.sub_area_code = ai.sub_area_code
     AND ai.name = nvl(SUBSTR(p.inv_dest_loc, 1, 2),SUBSTR(p.dest_loc, 1, 2))
     AND p.prod_id = m.prod_id
     AND p.cust_pref_vendor = m.cust_pref_vendor
     AND p.rec_id = e.erm_id
     AND l.perm(+) = 'Y'
     AND l.rank(+) = 1
     AND l.prod_id(+) = p.prod_id
     AND l.cust_pref_vendor(+) = p.cust_pref_vendor
     AND l.uom(+) <> 1
     AND e.status IN('CLO',   'VCH')
     AND p.putaway_put = 'N'
           /*05/06/12   vkat2696 CRQ36264 -swms12.5 fixes- to fetch the corrected quantity - Start */
     AND p.rec_id = t.rec_id 
     AND(t.qty + NVL(t.qty_expected,0)) > 0       --  Check for records having positive quantity
     AND t.trans_id IN(SELECT MAX(trans_id) FROM trans WHERE p.rec_id = rec_id AND p.prod_id = prod_id AND p.pallet_id = pallet_id)
		  /*05/06/12   vkat2696 CRQ36264 -swms12.5 fixes- to fetch the corrected quantity - End */
UNION 
SELECT    p.dest_loc dest_loc,     -- Check for * dest loc putawaylst records. 
          p.pallet_id pallet_id, 
	      p.qty qty,
          p.prod_id prod_id, 
          p.cust_pref_vendor cust_pref_vendor, 
          m.category category, 
          m.pack pack, 
          m.prod_size prod_size,
		  /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */	
	      /* Declare prod size unit */
		  m.prod_size_unit prod_size_unit,
	      /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
          m.brand brand, 
          m.descrip descrip, 
          m.ti ti, 
          m.pallet_type pallet_type, 
          m.hi hi, 
          m.spc spc, 
          e.erm_id erm_id, 
          e.erm_type erm_type, 
          e.status status, 
          e.exp_arriv_date, 
          e.sched_date, 
          e.source_id, 
          1    sort, 
          null logi_loc 
   FROM  swms.erm e, swms.pm m, swms.putawaylst p 
   WHERE p.dest_loc = '*' 
     AND p.prod_id             = m.prod_id 
     AND p.cust_pref_vendor    = m.cust_pref_vendor 
     AND p.rec_id              = e.erm_id 
     AND (e.status = 'OPN'  
          OR e.status = 'CLO' OR  e.status = 'VCH')
     AND p.putaway_put = 'N';
	      

