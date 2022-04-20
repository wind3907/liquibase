--	Modification History
--	--------------------------------
--  v_mntswp_select View used in MNTSWP form details block toshow SWAP record details
--  15-APR-2021  New View
CREATE OR REPLACE VIEW V_MNTSWP_SELECT
AS
  SELECT repl.task_id,
    repl.batch_no,
    repl.seq_no,
    repl.status,
    repl.prod_id,
    repl.cust_pref_vendor,
    repl.src_loc,
    repl.dest_loc,
    repl.pallet_id,
    Pt.Pallet_Type,
    repl.uom,
    DECODE (repl.uom, 1, repl.qty, repl.qty / p.spc) qty,
    Repl.User_Id,
    p.descrip,
    LTRIM (RTRIM (p.pack)
    || '/'
    || p.prod_size
    || ' '
    || p.prod_size_unit) pack_size,
    ai.name aisle,
    ssa.area_code,
    repl.inv_dest_loc,
    repl.type,
    repl.labor_batch_no,
    repl.gen_uid,
    repl.gen_date,
    l.uom dest_uom,
    repl.upd_user,
    repl.upd_date
  FROM 
    replenlst repl,
    pm p,
    loc l,
    pallet_type pt,
    slot_type st,
    swms_sub_areas ssa,
    aisle_info ai
  WHERE repl.type       = 'SWP'
  AND p.prod_id         = repl.prod_id
  AND l.logi_loc       = NVL (repl.inv_dest_loc, repl.dest_loc)
  AND pt.pallet_type    = l.pallet_type
  AND st.slot_type      = l.slot_type
  AND Ai.Pick_Aisle     = L.Pik_Aisle
  AND Ssa.Sub_Area_Code = Ai.Sub_Area_Code; 
  
CREATE OR REPLACE PUBLIC SYNONYM V_MNTSWP_SELECT FOR swms.V_MNTSWP_SELECT;

GRANT SELECT ON V_MNTSWP_SELECT TO SWMS_VIEWER;
GRANT ALL ON V_MNTSWP_SELECT TO SWMS_USER;