------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_ds_floats.sql, swms, swms.9, 10.1.1 9/7/06 1.2
--
-- Views:
--    v_ds_floats_intermediate
--    v_ds_floats
--
-- Description:
--    These views are used to select the records to process for discrete
--    selection.  An intermediate view and a main view are used so that an
--    outer join can be made on the DS_TMU table.  This enables a check that
--    a matching record exists in the DS_TMU table.
--
--    Included in view V_DS_FLOATS are the pickup objects designated to be
--    picked up while selecting.  Ideally the pickup point for these
--    should be a slot.
--
-- Used by:
--    Package pl_lm_ds.sql
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/26/05 prpbcb   Oracle 8 rs239b swms9 DN 11490
--                      Created for discrete selection.
--    04/26/05 prpbcb   Removed references to syspars:
--                         - DS_DRY_MAX_WALKING_DISTANCE
--                         - DS_CLR_MAX_WALKING_DISTANCE
--                         - DS_FRZ_MAX_WALKING_DISTANCE
--                      After meeting with Distribution Services it was
--                      determined these syspars are not needed.
------------------------------------------------------------------------------


/*************************************************************************
** Create intermediate view that does not include the DS_TMU table.
**
** The maximum walking distances are defined by area and are designated
** by syspars.  These syspars are selected in this view.  If in the future the
** walking distances are defined differently because doing it by area is
** too general then hopefully only this view needs changing.
*************************************************************************/
PROMPT Create view v_ds_floats_intermediate

CREATE OR REPLACE VIEW swms.v_ds_floats_intermediate
AS
SELECT f.batch_no               batch_no,
       f.equip_id               equip_id,
       fd.prod_id               prod_id,
       fd.cust_pref_vendor      cust_pref_vendor,
       pm.case_type             case_type,
       fd.uom                   uom,
       fd.qty_alloc             qty_alloc,
       --  fd.merge_alloc_flag,
       DECODE(fd.uom, 2, NVL(fd.qty_alloc, 0) /
                                        DECODE(pm.spc,NULL,1,0,1,pm.spc),
                      0) no_cases,
       DECODE(fd.uom, 1, NVL(fd.qty_alloc, 0),
                      0) no_splits,
       l.pik_path               pik_path,
       l.pik_aisle              pik_aisle,
       l.pik_slot               pik_slot,
       l.pik_level              pik_level,
       SUBSTR(l.logi_loc,1,2)   aisle,
       SUBSTR(l.logi_loc,3,2)   bay,
       fd.src_loc               pick_loc,
       ca.from_cross            from_cross,
       ca.to_cross              to_cross,
       NVL(ai.direction, -1)    direction,
       ai.physical_aisle_order  physical_aisle_order,
       bd.bay_dist              bay_dist,  -- The distance to the bay from the
                                           -- beginning of the aisle.
       sm.sel_type              sel_type,
       sm.method_id             method_id,
       sm.group_no              group_no,
       sm.sel_lift_job_code     job_code,
       r.f_door                 f_door,
       r.c_door                 c_door,
       r.d_door                 d_door,
       f.float_no               float_no,   -- Used to get the destination
                                            -- door number.
       DECODE(sm.sel_type, 'UNI', 'Y', 'N') unitized_pull_flag,
       se.opt_pull              opt_pull,
       NVL(l.floor_height, 0)   floor_height,
       l.pallet_type            pallet_type,
       l.slot_type              slot_type,
       ai.sub_area_code         sub_area_code,
       pm.spc                   spc,
       ssa.area_code            area_code
  FROM swms_sub_areas ssa,  -- To get the area.
       sel_equip se,        -- To get opt_pull flag.
       cross_aisle ca,      -- Selection cross aisle designator.
       aisle_info ai,
       sel_method sm,       -- To get the selection job code.
       route r,             -- To get the selection job code and door numbers.
       bay_distance bd,
       pm,
       loc l,
       float_detail fd,
       floats f
 WHERE 
       se.equip_id   (+)   = f.equip_id
   AND bd.aisle      (+)   = SUBSTR(l.logi_loc,1,2)
   AND bd.bay        (+)   = SUBSTR(l.logi_loc,3,2)
   AND ca.pick_aisle (+)   = l.pik_aisle
   AND r.route_no          = f.route_no
   AND sm.method_id        = r.method_id
   AND sm.group_no         = f.group_no
   AND fd.float_no         = f.float_no
   AND l.logi_loc          = fd.src_loc
   AND ssa.sub_area_code   = ai.sub_area_code
   AND ai.name             = SUBSTR(l.logi_loc, 1, 2)
   AND pm.prod_id          = fd.prod_id
   AND pm.cust_pref_vendor = fd.cust_pref_vendor
/


/************************************************************************
** Create the view used to select the records to process for discrete
** selection.
**
** It includes the DS_TMU table with an outer join.  This enables a check
** that a matching record exists in the DS_TMU table.  This statement is
** used to flag if a DS_TMU record exists:
**     "DECODE(ds.case_type, NULL, 'N', 'Y')" 
** Any other not null column from table DS_TMU could have been used.
** I just happened to pick the case_type.
**
** If no matching record is found in table DS_TMU then the tmu value
** for cases and splits are taken from syspars DS_DEFAULT_CASE_TMU
** and DS_DEFAULT_SPLIT_TMU.  If these syspars do not exist then 200 is
** used as the tmu value.
**
** Also included are the pickup objects designated to be picked up
** while selecting.
************************************************************************/
PROMPT Create view v_ds_floats

CREATE OR REPLACE VIEW swms.v_ds_floats
AS
SELECT 'ITEM'                  pick_type,
       v.batch_no              batch_no,
       v.equip_id              equip_id,
       v.prod_id               prod_id,
       v.cust_pref_vendor      cust_pref_vendor,
       v.case_type             case_type,
       v.uom                   uom,
       v.qty_alloc             qty_alloc,
       v.no_cases              no_cases,
       v.no_splits             no_splits,
       NVL(ds.tmu_no_case,
           TO_NUMBER(NVL(dct.config_flag_val, '200')))   tmu_no_case,
       NVL(ds.tmu_no_split,
           TO_NUMBER(NVL(dst.config_flag_val, '200')))   tmu_no_split,
       DECODE(v.uom, 2, NVL(ds.tmu_no_case, TO_NUMBER(NVL(dct.config_flag_val, '200'))) * (NVL(v.qty_alloc, 0) /
                             DECODE(v.spc,NULL, 1, 0, 1, v.spc)),
                     0)  item_total_case_tmu,
       DECODE(v.uom, 1, NVL(ds.tmu_no_split, TO_NUMBER(NVL(dst.config_flag_val, '200'))) * v.qty_alloc,
                     0)  item_total_split_tmu,
       v.pik_path              pik_path,
       v.pik_aisle             pik_aisle,
       v.pik_slot              pik_slot,
       v.pik_level             pik_level,
       v.aisle                 aisle,
       v.bay                   bay,
       v.pick_loc              pick_loc,
       v.from_cross            from_cross,
       v.to_cross              to_cross,
       v.direction             direction,
       v.physical_aisle_order  physical_aisle_order,
       v.bay_dist              bay_dist,
       v.sel_type              sel_type,
       v.method_id             method_id,
       v.group_no              group_no,
       v.job_code              job_code,
       v.f_door                f_door,
       v.c_door                c_door,
       v.d_door                d_door,
       v.float_no              float_no,
       v.unitized_pull_flag    unitized_pull_flag,
       v.opt_pull              opt_pull,
       DECODE(ds.case_type, NULL, 'N', 'Y')  ds_tmu_record_exists,
       v.spc                   spc,
       v.sub_area_code         sub_area_code,
       v.area_code             area_code,
       NULL                    pickup_object,
       0                       pickup_object_tmu
  FROM v_ds_floats_intermediate v,
       ds_tmu ds,
       (SELECT config_flag_val
          FROM sys_config
         WHERE config_flag_name = 'DS_DEFAULT_CASE_TMU') dct,
       (SELECT config_flag_val
          FROM sys_config
         WHERE config_flag_name = 'DS_DEFAULT_SPLIT_TMU') dst
 WHERE 
       ds.sub_area_code (+)   = v.sub_area_code
   AND ds.slot_type     (+)   = v.slot_type
   AND ds.pallet_type   (+)   = v.pallet_type
   AND ds.floor_height  (+)   = v.floor_height
   AND ds.pik_level     (+)   = v.pik_level
   AND ds.case_type     (+)   = v.case_type
UNION ALL       --  Must have the UNION ALL because we want all records.
SELECT DISTINCT 'PICKUP_OBJECT'  pick_type,     -- If the PUP is a slot then
       f.batch_no                batch_no,      -- the direction, cross aisle,
       f.equip_id                equip_id,      -- aisle, bay, etc will
       NULL                      prod_id,       -- have a value.
       NULL                      cust_pref_vendor,
       NULL                      case_type,
       0                         uom,
       0                         qty_alloc,
       0                         no_cases,
       0                         no_splits,
       0                         tmu_no_case,
       0                         tmu_no_split,
       0                         item_total_case_tmu,
       0                         item_total_split_tmu,
       l.pik_path                pik_path,
       l.pik_aisle               pik_aisle,
       l.pik_slot                pik_slot,
       l.pik_level               pik_level,
       SUBSTR(l.logi_loc,1,2)    aisle,
       SUBSTR(l.logi_loc,3,2)    bay,
       pup.pickup_point          pick_loc,    -- Pickup point
       ca.from_cross             from_cross,
       ca.to_cross               to_cross,
       NVL(ai.direction, -1)     direction,
       ai.physical_aisle_order   physical_aisle_order,
       bd.bay_dist               bay_dist,  -- The distance to the bay from the
                                            -- beginning of the aisle.
       sm.sel_type               sel_type,
       sm.method_id              method_id,
       f.group_no                group_no,
       pup.job_code              job_code,
       0                         f_door,
       0                         c_door,
       0                         d_door,
       0                         float_no,
       NULL                      unitized_pull_flag,
       NULL                      opt_pull,
       NULL                      ds_tmu_record_exists,
       0                         spc,
       NULL                      sub_area_code,
       NULL                      area_code,
       pup.pickup_object         pickup_object,
       puo.tmu                   pickup_object_tmu  -- This is the TMU assigned
                                                    -- to the object.
  FROM swms_sub_areas ssa,  -- To get the area of the PUP
       cross_aisle ca,      -- Selection cross aisle designator if PUP is a slot
       aisle_info ai,       -- To get the direction if PUp is a slot.
       bay_distance bd,     -- To get the bay distance if PUP is a slot
       loc l,      -- To get the pick path of the pickup point if it is a loc.
       ds_pickup_object puo,            -- To get the TMU for the pickup object
       ds_selection_pickup_object pup,  -- Job code pickup points
       sel_method sm,                   -- To get the selection job code
       route r,                         -- To get the selection job code
       floats f
 WHERE bd.aisle          (+)  = SUBSTR(l.logi_loc,1,2)
   AND bd.bay            (+)  = SUBSTR(l.logi_loc,3,2)
   AND ca.pick_aisle     (+)  = l.pik_aisle
   AND ssa.sub_area_code (+)  = ai.sub_area_code
   AND ai.name           (+)  = SUBSTR(l.logi_loc,1,2)
   AND l.logi_loc        (+)  = pup.pickup_point
   AND r.route_no             = f.route_no
   AND sm.method_id           = r.method_id
   AND sm.group_no            = f.group_no
   AND pup.job_code           = sm.sel_lift_job_code
   AND pup.pickup_while_selecting_flag = 'Y'
   AND puo.pickup_object      = pup.pickup_object
/

