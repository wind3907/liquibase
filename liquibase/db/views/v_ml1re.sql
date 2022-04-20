------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_ml1re
--
-- Description:
--    This view is used in the ml1re.pc reports. 
--
-- Used by:
--    Report ml1re.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/18/02 prppxx   Modify to add net height and width positions. DN#11118.
--    04/01/10 sth0458  DN12554 - 212 Enh - SCE057 - 
--                      Add UOM field to SWMS.Expanded the length
--                      of prod size to accomodate for prod size 
--                      unit.Changed queries to fetch
--                      prod_size_unit along with prod_size
------------------------------------------------------------------------------
create or replace view swms.v_ml1re as
SELECT l.logi_loc,
       l.slot_type,
       l.uom,
       l.cube,
       l.perm,
       l.aisle_side,
       l.slot_height slot_height,
       l.width_positions width_positions,
       p.pack,
       p.prod_size,
	   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
	   /* Declare prod size unit */
	   p.prod_size_unit,
	   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
       p.brand,
       p.descrip pm_desc,
       p.prod_id,
       p.cust_pref_vendor,
       i.logi_loc pallet_id,
       TRUNC(i.qoh/NVL(p.spc,1)) cases,
       MOD(i.qoh,NVL(p.spc,1)) splits,
       p.ti,
       l.pallet_type,
       p.hi,
       z1.zone_id put_zone,
       z2.zone_id pick_zone,
       a.sort,
       a.description area_desc,
       lr.bck_logi_loc,
       l.status
 FROM  swms_sub_areas sa, swms_areas a, zone z1, zone z2,  lzone lz1,
       lzone lz2, pm p, inv i, loc l, loc_reference lr
 WHERE  sa.area_code = a.area_code(+)
  AND  sa.sub_area_code(+) = substr(l.logi_loc,1,1)
  AND  p.prod_id(+) = i.prod_id
  AND  p.cust_pref_vendor(+) = i.cust_pref_vendor
  AND  i.plogi_loc(+) = l.logi_loc
  AND  z1.zone_type = 'PUT'
  AND  z1.zone_id = lz1.zone_id
  AND  lz1.logi_loc = l.logi_loc
  AND  z2.zone_type = 'PIK'
  AND  z2.zone_id = lz2.zone_id
  AND  lz2.logi_loc = l.logi_loc
  AND  l.logi_loc = lr.plogi_loc(+)
/

