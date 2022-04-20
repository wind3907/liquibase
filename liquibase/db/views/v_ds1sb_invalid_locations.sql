------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_ds1sb_invalid_locations.sql, swms, swms.9, 10.1.1 9/7/06 1.2
--
-- View:
--    v_ds1sb_invalid_locations    
--
-- Description:
--    This view is used in form ds1sb to display locations in the
--    discrete selection TMU setup, table DS_TMU, that are not valid.
--    Records in the TMU setup can become invalid if a location configuration
--    changes.  A record is considered invalid if the combination of the
--    sub area code, slot tpe, pallet type and pik level does not exist in
--    the LOC table.
--
--    There is a procedure in pl_lm_ds used to delete the invalid locations
--    so if the logic changes in this view then the procedure may need to
--    be changed too.
--
--    Background Info:
--    A case TMU and split TMU are entered for each combination of:
--      (sub area code, slot type, pallet_type, floor_height, case type)
--    for home slots and floating slots.
--
-- Used by:
--    Form ds1sb.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/02/05 prpbcb   Oracle 8 rs239b swms9 DN 11490
--                      Created for discrete selection.
------------------------------------------------------------------------------

PROMPT Create view v_ds1sb_invalid_locations

CREATE OR REPLACE VIEW swms.v_ds1sb_invalid_locations
AS
SELECT ds.sub_area_code,
       ds.slot_type,
       ds.pallet_type,
       ds.floor_height,
       ds.pik_level,
       ds.case_type,
       ds.tmu_no_case,
       ds.tmu_no_split,
       ds.add_date,
       ds.add_user,
       ds.upd_date,
       ds.upd_user
  FROM ds_tmu ds
 WHERE NOT EXISTS
             (SELECT 1
                FROM aisle_info ai,
                     loc l
               WHERE ai.name                = SUBSTR(l.logi_loc,1,2)
                 AND ai.sub_area_code       = ds.sub_area_code
                 AND l.slot_type            = ds.slot_type
                 AND l.pallet_type          = ds.pallet_type
                 AND NVL(l.floor_height, 0) = ds.floor_height
                 AND l.pik_level            = ds.pik_level)
/

