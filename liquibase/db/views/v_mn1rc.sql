REM %Z% %W% %G% %I%
REM File : %Z% %W%
REM Usage: sqlplus USR/PWD @%W%
REM
REM      MODIFICATION HISTORY
REM  04/01/10   sth0458 DN12554 - 212 Enh - SCE057 - 
REM                     Add UOM field to SWMS.Expanded the
REM                     length of prod size to accomodate 
REM                     for prod size unit.Changed queries to fetch 
REM                     prod_size_unit along with prod_size

CREATE OR REPLACE VIEW swms.v_mn1rc AS
 SELECT  i.plogi_loc  plogi_loc,
         i.logi_loc  logi_loc,
         i.prod_id  prod_id,
         i.cust_pref_vendor  cust_pref_vendor,
         i.qoh  qoh,
         i.status status,
         i.qty_alloc qty_alloc,
         i.qty_planned qty_planned,
         ((((i.qoh / p.spc) * p.case_cube) / l.cube) * 100.0)  capacity,
	 i.inv_uom inv_uom,
         p.pack  pack,
         p.prod_size  prod_size,
		 /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		 p.prod_size_unit  prod_size_unit,
		 /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
         p.brand  brand,
         p.descrip  descrip,
         p.mfg_sku  mfg_sku,
         p.vendor_id  vendor_id,
         p.ti  ti,
         p.pallet_type  pallet_type,
         p.hi  hi,
         p.spc  spc,
         a.sort sort,
         sa.sub_area_code sub_area_code,
         a.area_code area_code,
         a.description area_description,
	 i.inv_order_id,
	 i.ship_date,
	 i.rec_id,
	 i.parent_pallet_id,
	 i.inv_cust_id,
	 i.qty_produced,
	 i.sigma_qty_produced
    FROM  swms_sub_areas sa, swms_areas a, aisle_info ai, 
          pm p, loc l, inv i
    WHERE  sa.area_code = a.area_code(+)
      and sa.sub_area_code(+) = ai.sub_area_code
      and ai.name(+) = substr(l.logi_loc,1,2)
      and  i.prod_id = p.prod_id
      and  i.cust_pref_vendor = p.cust_pref_vendor
      and  l.logi_loc = i.plogi_loc;

