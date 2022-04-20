CREATE OR REPLACE FORCE VIEW "SWMS"."V_MATRIX_OPEN_HOMESLOT" ("LOGI_LOC", "PALLET_TYPE", "CUBE", "UOM", "PERM", "DESCRIPTION")
AS
  SELECT l.logi_loc logi_loc,
    l.pallet_type pallet_type,
    l.cube cube,
    l.uom uom,
    l.perm perm,
    l.descrip description
  FROM aisle_info ai,
    swms_sub_areas sa,
    loc l
  WHERE ai.sub_area_code = sa.sub_area_code
  AND ai.name            = SUBSTR(l.logi_loc,1,2)
  AND l.perm             = 'Y'
  AND l.prod_id         IS NULL
  AND l.status           = 'AVL';