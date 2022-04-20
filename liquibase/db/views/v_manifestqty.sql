CREATE OR REPLACE FORCE VIEW "SWMS"."V_MANIFESTQTY" ("MANIFEST_NO", "STOP_NO", 
"INVOICE_NO", "REC_TYPE", "DRY_QTY", "COOL_QTY", "FRZ_QTY") AS 
  SELECT
	md.manifest_no manifest_no,
	md.stop_no stop_no,
        md.invoice_no,
        md.rec_type,
	sum(decode(p.area,'D',md.shipped_qty,0)) dry_qty,
	sum(decode(p.area,'C',md.shipped_qty,0)) cool_qty,
	sum(decode(p.area,'F',md.shipped_qty,0)) frz_qty
FROM manifest_dtls md, pm p
WHERE
md.prod_id = p.prod_id
group by md.manifest_no,md.stop_no,md.invoice_no,md.rec_type;