-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--     04/01/10   sth0458   DN12554 - 212 Legacy Enhancements - SCE057 - 
--                          Add UOM field to SWMS
--                          Expanded the length of prod size to accomodate 
--                          for prod size unit.
--                          Changed queries to fetch prod_size_unit 
--                          along with prod_size
--
------------------------------------------------------------------------------
CREATE OR REPLACE FORCE VIEW "SWMS"."V_PN2RA" ("PLOGI_LOC", "LOGI_LOC", "PIK_AISLE", "PIK_SLOT", "PIK_LEVEL", "PIK_PATH", "PUT_AISLE", "PUT_SLOT", "PUT_LEVEL", "PUT_PATH", "PROD_ID", "CUST_PREF_VENDOR", "BRAND", "PACK", "PROD_SIZE","PROD_SIZE_UNIT", "EXP_DATE", "REC_DATE", "DESCRIP", "MFG_SKU", "QOH", "SPC", "STATUS") AS 
  SELECT       i.plogi_loc  plogi_loc,
          i.logi_loc  logi_loc,
          l.pik_aisle  pik_aisle,
          l.pik_slot  pik_slot,
          l.pik_level  pik_level,
          l.pik_path  pik_path,
          l.put_aisle  put_aisle,
          l.put_slot  put_slot,
          l.put_level  put_level,
          l.put_path  put_path,
          i.prod_id  prod_id,
          i.cust_pref_vendor  cust_pref_vendor,
          p.brand brand,
          p.pack pack,
          p.prod_size  prod_size,
  /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - Begin */
  /* Retrieve prod size unit*/
          p.prod_size_unit prod_size_unit,
  /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - End */
          i.exp_date exp_date,
          i.rec_date rec_date,
          p.descrip descrip,
          p.mfg_sku mfg_sku,
          i.qoh  qoh,
          nvl(p.spc,1) spc,
          i.status  status
FROM inv i, pm p, loc l
WHERE          i.plogi_loc = i.logi_loc
AND    i.plogi_loc = l.logi_loc
AND    p.prod_id = i.prod_id
AND    p.cust_pref_vendor = i.cust_pref_vendor
AND    i.status  = 'AVL'
AND    l.perm = 'Y'
AND    i.qoh < 0
;

