REM @(#) src/schema/views/v_ml1rc.sql, swms, swms.9, 10.1.1 9/7/06 1.3
REM File : @(#) src/schema/views/v_ml1rc.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_ml1rc.sql, swms, swms.9, 10.1.1
REM
REM      MODIFICATION HISTORY
REM  08/05/02  acpakp modified to add location status as AVL to the condition.
REM  11/18/02  prppxx modified to add slot_height and width_positions.DN11118.
REM
REM

create or replace view swms.v_ml1rc as 
select l.logi_loc logi_loc,
              l.slot_type slot_type, 
              l.uom uom,
              l.pallet_type pallet_type,
              l.perm perm,
              l.aisle_side aisle_side,
              l.prod_id prod_id,
              l.cust_pref_vendor cust_pref_vendor,
              l.slot_height slot_height,
              l.width_positions width_positions,
              a.sort sort,
              l.status,
              l.cube,
              sa.sub_area_code sub_area_code,                                   
              a.area_code area_code
       from   swms_sub_areas sa, swms_areas a, aisle_info ai, loc l, inv i
       where  sa.area_code = a.area_code(+)
         and  sa.sub_area_code(+) = ai.sub_area_code
         and  ai.name = substr(l.logi_loc, 1, 2)
         and  l.logi_loc = i.plogi_loc(+)
         and  i.plogi_loc IS NULL
         and  l.status = 'AVL'
/

