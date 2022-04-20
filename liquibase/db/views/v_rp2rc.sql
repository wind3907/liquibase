-- 	Modification History
--	-------------------------------
--     04/01/10   sth0458 	DN12554 - 212 Legacy Enhancements - SCE057 - 
--					Add UOM field to SWMS
--            		           	Expanded the length of prod size to accomodate 
--					for prod size unit.
--				  	Changed queries to fetch prod_size_unit along with prod_size
CREATE OR REPLACE FORCE VIEW "SWMS"."V_RP2RC" ("CATEGORY", "PROD_ID", "CUST_PREF_VENDOR", "PACK", "PROD_SIZE", "PROD_SIZE_UNIT","BRAND", "DESCRIP", "SPC", "OBLIGATION_NO", "ERM_ID", "STATUS", "ERM_TYPE", "ROUTE_NO", "STOP_NO", "DEST_LOC", "PALLET_ID", "QTY", "UOM") AS 
  SELECT p.CATEGORY category,
       t.PROD_ID prod_id,
       t.CUST_PREF_VENDOR cust_pref_vendor,
       p.PACK pack,
       p.PROD_SIZE prod_size,
       /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - Begin */
	   /* Declare prod size unit*/
	   p.prod_size_unit prod_size_unit,
	   /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - End */
       p.BRAND brand,
       p.DESCRIP descrip,
       p.SPC spc,
       r.OBLIGATION_NO obligation_no,
       e.ERM_ID erm_id,
       e.STATUS status,
       e.ERM_TYPE erm_type,
       r.ROUTE_NO route_no,
       r.STOP_NO stop_no,
       t.DEST_LOC dest_loc,
       t.PALLET_ID pallet_id,
       t.QTY qty,
       t.UOM uom
FROM   PM p, RETURNS r, PUTAWAYLST t, ERM e
WHERE  t.REC_ID   = e.ERM_ID
AND  r.ERM_LINE_ID = t.ERM_LINE_ID
AND  e.ERM_ID   = 'S' || r.MANIFEST_NO
AND  p.PROD_ID  = t.PROD_ID
AND  p.CUST_PREF_VENDOR = t.CUST_PREF_VENDOR
AND  e.ERM_TYPE = 'CM'
AND  (   (e.STATUS = 'OPN' AND t.PUTAWAY_PUT = 'N')
OR (e.STATUS = 'CLO') )
;

