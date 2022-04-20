------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_ds1sb_missing_locations.sql, swms, swms.9, 10.1.1 9/7/06 1.2
--
-- View:
--    v_ds1sb_missing_locations    
--
-- Description:
--    This view is used in form ds1sb to display locations missing
--    in the discrete selection TMU setup.
--
--    The view does not select the records very quickly but this should not
--    be an issue because the users should be using this only occasionally.
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

PROMPT Create view v_ds1sb_missing_locations

CREATE OR REPLACE VIEW swms.v_ds1sb_missing_locations
AS
SELECT ai.sub_area_code        sub_area_code,      -- Home slots
       l.slot_type             slot_type,
       l.pallet_type           pallet_type,
       NVL(l.floor_height, 0)  floor_height,
       l.pik_level             pik_level,
       ct.case_type            case_type,
       'HOME SLOT'             home_or_floating,
       count(*)                record_count
  FROM case_type_code ct,
       aisle_info ai,
       loc l
 WHERE ai.name = SUBSTR(l.logi_loc,1,2)
   AND l.perm = 'Y'
   AND NOT EXISTS
             (SELECT 'x'
               FROM ds_tmu ds
              WHERE ds.sub_area_code = ai.sub_area_code
                AND ds.slot_type     = l.slot_type
                AND ds.pallet_type   = l.pallet_type
                AND ds.floor_height  = NVL(l.floor_height, 0)
                AND ds.pik_level     = l.pik_level
                AND ds.case_type     = ct.case_type)
 GROUP BY ai.sub_area_code,
          l.slot_type,
          l.pallet_type,
          NVL(l.floor_height, 0),
          l.pik_level,
          ct.case_type
UNION ALL
SELECT ai.sub_area_code        sub_area_code,      -- Floating slots
       l.slot_type             slot_type,
       l.pallet_type           pallet_type,
       NVL(l.floor_height, 0)  floor_height,
       l.pik_level             pik_level,
       ct.case_type            case_type,
       'FLOATING SLOT'         home_or_floating,
       count(*)                record_count
  FROM case_type_code ct,
       zone z,
       lzone lz,
       aisle_info ai,
       loc l
 WHERE ai.name = SUBSTR(l.logi_loc,1,2)
   AND lz.logi_loc = l.logi_loc
   AND z.zone_id = lz.zone_id
   AND z.zone_type = 'PUT'
   AND z.rule_id = 1
   AND NOT EXISTS
             (SELECT 'x'
                FROM ds_tmu ds
               WHERE ds.sub_area_code = ai.sub_area_code
                 AND ds.slot_type     = l.slot_type
                 AND ds.pallet_type   = l.pallet_type
                 AND ds.floor_height  = NVL(l.floor_height, 0)
                 AND ds.pik_level     = l.pik_level
                 AND ds.case_type     = ct.case_type)
 GROUP BY ai.sub_area_code,
          l.slot_type,
          l.pallet_type,
          NVL(l.floor_height, 0),
          l.pik_level,
          ct.case_type
/

