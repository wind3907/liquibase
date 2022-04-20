REM @(#) src/schema/views/v_ob1rb.sql, swms, swms.9, 10.1.1 9/7/06 1.3
REM File : @(#) src/schema/views/v_ob1rb.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_ob1rb.sql, swms, swms.9, 10.1.1
REM

CREATE OR REPLACE VIEW swms.v_ob1rb
AS
SELECT r.truck_no                     TRUCK_NO,
       r.route_no                     ROUTE_NO,
       r.sch_time                     SCH_TIME,
       r.f_door                       F_DOOR,
       r.c_door                       C_DOOR,
       r.d_door                       D_DOOR,
       f.comp_code                    COMP_CODE,
       f.float_seq                    FLOAT_SEQ,
       f.batch_seq                    BATCH_SEQ,
       SUBSTR(NVL(ssa.sub_area_type, z.descrip),1,30)  PICK_AREA,
       sm.sel_type                    SEL_TYPE,
       fd.stop_no                     STOP_NO,
       fd.zone                        ZONE,
       fd.merge_alloc_flag            MERGE_ALLOC_FLAG,
       fd.uom                         UOM,
       fd.qty_alloc                   QTY_ALLOC,
       fd.float_no                    FLOAT_NO,
       pm.spc                         SPC,
       fd.merge_loc                   MERGE_LOC,
       ROUND (
         NVL (pm.case_cube, 0) /
         NVL (pm.spc, 1) *
         NVL (fd.qty_alloc, 0), 2
       )                              CUBE,
       f.batch_no                     FLOATS_BATCH_NO,
       r.route_batch_no               ROUTE_BATCH_NO,
       r.status                       STATUS,
       r.method_id                    METHOD_ID,
       f.group_no                     GROUP_NO,
       DECODE (fd.uom, 1, 'SP', 'CS') CS_SP,
       DECODE (fd.uom, 1,
           NVL (fd.qty_alloc, 0), 0
       )                              SPLITS,
       ROUND (
         DECODE (fd.uom, 1,
            NVL (pm.case_cube, 0) /
             NVL (pm.spc, 1), 0
         ), 2
       )                              SPLIT_CUBE,
       FLOOR (
         DECODE (fd.uom, 1, 0,
           NVL (fd.qty_alloc, 0) /
           NVL (pm.spc, 1)
         )
       )                              CASES,
       DECODE (fd.uom, 1, 0,
             NVL (pm.case_cube, 0)
       )                              CASE_CUBE,
       se.no_of_zones                 NO_OF_ZONES,
       fd.src_loc                     SRC_LOC,
       fd.seq_no                      SEQ_NO,
       fd.prod_id                     PROD_ID
  FROM	swms_sub_areas ssa,
	zone z,
	lzone l,
	sel_method sm,
	route r,
	pm,
	float_detail fd,
	floats f,
	sel_equip se
 WHERE f.float_no = fd.float_no
 AND   fd.prod_id = pm.prod_id
 AND   fd.cust_pref_vendor = pm.cust_pref_vendor
 AND   f.route_no = r.route_no
 AND   f.pallet_pull != 'R'
 AND   f.merge_loc like '???%'
 AND   sm.method_id = r.method_id
 AND   sm.group_no = f.group_no
 AND   se.equip_id = f.equip_id
 AND   l.logi_loc = fd.src_loc
 AND   z.zone_id  = l.zone_id
 AND   z.zone_type = 'PIK'
 AND	ssa.area_code (+) = z.z_area_code
 AND	ssa.sub_area_code (+) = z.z_sub_area_code
/

