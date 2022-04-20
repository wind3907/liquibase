--	Modification History
--	--------------------------------
--     04/01/10   sth0458     DN12554 - 212 Enh - SCE057 - 
--                            Add UOM field to SWMS.Expanded the length
--                            of prod size to accomodate for prod size
--                            unit.Changed queries to fetch
--                            prod_size_unit along with prod_size
--     09/03/14  vred5319     Added Mx_eligible and Mx_item_assign_flag
--                            fields for Symbotic/Matrix Project
-- 	   06/18/18  sban3548	  Jira# 495- Added ORDER_ID field for FoodPro	
--     08/03/13  vkal9662   Jira 540 -Added new columns from inv (qty_planned, qty_alloc, rec_id)

CREATE OR REPLACE VIEW "SWMS"."V_MN1SA" ("PROD_ID",
    "CUST_PREF_VENDOR","PLOGI_LOC","LOGI_LOC","QOH","QALC","QPLN","STATUS",
	/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
	/*  Select prod size unit  */
    "PARENT_PALLET_ID","LOT_ID","PACK","PROD_SIZE","PROD_SIZE_UNIT","BRAND",
	/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
    "DESCRIP","SPC","TI","HI","PALLET_TYPE","MFG_SKU",
    "RDC_VENDOR_ID","ITEM","CPV", "UOM", "MX_ELIGIBLE", "MX_ITEM_ASSIGN_FLAG", "INV_ORDER_ID", "REC_ID", "SHIP_DATE") AS 
    select i.prod_id, i.cust_pref_vendor, i.plogi_loc, 
       i.logi_loc, i.qoh,qty_alloc,i.qty_planned, i.status, i.parent_pallet_id,
		/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		/*  Select prod size unit  */	   
       i.lot_id, p.pack, p.prod_size,p.prod_size_unit, p.brand, p.descrip, 
	   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
       p.spc, p.ti, p.hi, p.pallet_type, p.mfg_sku, 
       p.rdc_vendor_id, i.prod_id item, i.cust_pref_vendor cpv, 
       i.inv_uom uom, p.mx_eligible, p.mx_item_assign_flag, 
	   /*06/15/18 - Jira#495- Added order_id for Foodpro enhancements - Begin */
	   i.inv_order_id,
	   /*06/15/18 - Jira#495- Addeded for Foodpro enhancements - End */
	   i.rec_id, /*08/03/18 - Jira#540- add for Foodpro enhancements*/
        i.ship_date 
  from pm p, inv i 
 where p.prod_id = i.prod_id 
   and p.cust_pref_vendor = i.cust_pref_vendor;
