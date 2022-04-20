------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_ml1rd
--
-- Description:
--    This view is used in the ml1rd.pc reports. 
--
-- Used by:
--    Report ml1rd.pc
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
create or replace view swms.v_ml1rd as
select l.logi_loc logi_loc,
              l.slot_type slot_type,
              l.aisle_side aisle_side,
              l.uom uom,
              l.cube cube,
              l.pallet_type pallet_type,
              l.perm perm,
              l.slot_height slot_height,
              l.width_positions width_positions,
              p.pack pack,
              p.prod_size prod_size,
			  /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
			  /* Declare prod size unit*/
			  p.prod_size_unit prod_size_unit,
			  /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
              p.brand brand,
              p.descrip descrip,
              p.prod_id prod_id,
              p.cust_pref_vendor cust_pref_vendor,
              p.ti ti,
              p.hi hi,
              p.avg_wt avg_wt,
              p.spc spc,
              i.logi_loc pallet_id,
              i.qoh qoh,
              a.sort sort,
              a.area_code area_code,
              sa.sub_area_code sub_area_code,
              lr.bck_logi_loc bck_logi_loc,
              l.status
        from  swms_sub_areas sa, swms_areas a, aisle_info ai,
              pm p, inv i, loc l, loc_reference lr
       where  sa.area_code = a.area_code(+)
         and  sa.sub_area_code(+) = ai.sub_area_code
         and  ai.name(+) = substr(l.logi_loc,1,2)
         and  p.prod_id = i.prod_id
         and  p.cust_pref_vendor = i.cust_pref_vendor
         and  i.plogi_loc = l.logi_loc
         and  l.logi_loc = lr.plogi_loc(+)
/

