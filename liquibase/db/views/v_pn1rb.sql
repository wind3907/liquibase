rem *************************************************************************
rem Date   :  23-JUL-2003
rem File   :  v_pn1rb.sql
rem Defect#:  D# 12502 Mini-load reserve project 
rem           This view is created for generating Mini-load reserve NDM
rem           replenishment list report.
rem            
rem Date       User    Comments
rem 08/28/09   prppxx  D#12502 Initial version.
REM  04/01/10   sth0458 DN12554 - 212 Legacy Enhancements - SCE057 - 
REM                     Add UOM field to SWMS
REM                     Expanded the length of prod size to accomodate 
REM                     for prod size unit.
REM                     Changed queries to fetch prod_size_unit 
REM                     along with prod_size
rem
rem *************************************************************************

CREATE OR REPLACE VIEW swms.v_pn1rb 
  (dest_loc,
   pallet_id,
   src_loc,
   prod_id,
   task_id,
   batch_no,
   status,
   gen_uid,
   pik_path,
   exp_date,
   pik_aisle,
   pack,
   prod_size,
   /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - Begin */
   /* select prodsize unit */
   prod_size_unit,
   /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - End*/
   cust_pref_vendor,
   descrip,
   zone_id,
   split_cube,
   case_cube,
   max_case_carriers,
   qoh,
   qty,
   cube,
   slot_type,
   uom,
   spc,
   skid_cube,
   type,
   priority)
AS
SELECT r.dest_loc   dest_loc,
       r.pallet_id  pallet_id,
       r.src_loc    src_loc,
       r.prod_id    prod_id,
       r.task_id    task_id,
       r.batch_no   batch_no,
       r.status     status,
       r.gen_uid    gen_uid,
       l.pik_path   pik_path,
       i.exp_date   exp_date,
       l.pik_aisle  pik_aisle,
       p.pack       pack,
       p.prod_size  prod_size,
   /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - Begin */
   /* select prod size unit*/
       p.prod_size_unit  prod_size_unit,
   /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - End*/
       p.cust_pref_vendor cust_pref_vendor,
       p.descrip    descrip,
       p.zone_id    zone_id,
       p.split_cube split_cube,
       p.case_cube  case_cube,
       p.max_miniload_case_carriers  max_case_carriers,
       i.qoh        qoh,
       r.qty        qty,
       l.cube       cube,
       l.slot_type  slot_type,
       nvl(l.uom,0) uom,
       nvl(p.spc,1) spc,
       pa.skid_cube skid_cube,
       r.type,
       r.priority
FROM   replenlst r, pm p, inv i, loc l, pallet_type pa
WHERE  r.dest_loc = l.logi_loc
 AND   i.logi_loc(+) = r.pallet_id
 AND   r.prod_id = p.prod_id
 AND   r.cust_pref_vendor = p.cust_pref_vendor
 AND   r.status != 'PRE'
 AND   l.pallet_type = pa.pallet_type
/
