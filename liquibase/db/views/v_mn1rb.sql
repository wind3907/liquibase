REM %Z% %W% %G% %I%
REM File : %Z% %W%
REM Usage: sqlplus USR/PWD @%W%
REM
REM      MODIFICATION HISTORY
REM
REM    01/20/06 D#12033 Remove awm table because the "AWM" and "Pick FREQ"
REM             fields are removed from report. New field "UOM" is added
REM             on the report to represent INV.inv_uom.
REM    04/01/10 sth0458 DN12554 - 212 Enh - SCE057 - 
REM                     Add UOM field to SWMS.Expanded the
REM                     length of prod size to accomodate 
REM                     for prod size unit.Changed queries to fetch
REM                     prod_size_unit along with prod_size

CREATE OR REPLACE VIEW "SWMS"."V_MN1RB" ("PLOGI_LOC","LOGI_LOC",
	/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
	/* Select prod size unit */
    "PROD_ID","CUST_PREF_VENDOR","QOH","PACK","PROD_SIZE","PROD_SIZE_UNIT","BRAND",
	/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
    "DESCRIP","MFG_SKU","TI","PALLET_TYPE","HI","SPC",
    "SORT","UOM","AREA_CODE","SUB_AREA_CODE","STATUS",
    "LOT_ID","PARENT_PALLET_ID","VENDOR_ID","RDC_VENDOR_ID",
    "ITEM","CPV","INV_ORDER_ID","SHIP_DATE",rec_id,inv_cust_id,qty_produced,sigma_qty_produced) AS 
    select i.plogi_loc plogi_loc, 
              i.logi_loc  logi_loc, 
              i.prod_id  prod_id, 
              i.cust_pref_vendor cust_pref_vendor, 
              i.qoh  qoh, 
              p.pack  pack, 
              p.prod_size  prod_size, 
			  /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
			  /* Select prod size unit */
			  p.prod_size_unit  prod_size_unit,
			  /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
              p.brand  brand, 
              p.descrip  descrip, 
              p.mfg_sku  mfg_sku, 
              p.ti  ti, 
              p.pallet_type  pallet_type, 
              p.hi  hi, 
              p.spc  spc, 
              a.sort sort, 
	      i.inv_uom,
              a.area_code area_code, 
              sa.sub_area_code sub_area_code, 
              i.status status, 
              i.lot_id lot_id, 
              i.parent_pallet_id parent_pallet_id, 
              p.vendor_id vendor_id, 
              p.rdc_vendor_id  rdc_vendor_id, 
              i.prod_id item, 
              i.cust_pref_vendor cpv,
	      i.inv_order_id,
	      i.ship_date,
	      i.rec_id,
	      i.inv_cust_id,
	      i.qty_produced,
	      i.sigma_qty_produced
        from  swms_areas a, swms_sub_areas sa, aisle_info ai, 
              pm p, inv i 
       where  p.prod_id = i.prod_id 
         and  p.cust_pref_vendor = i.cust_pref_vendor 
         and  ai.name(+) = substr(i.plogi_loc,1,2) 
         and  sa.sub_area_code(+) = ai.sub_area_code 
         and  a.area_code(+) = sa.area_code; 

