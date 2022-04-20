CREATE OR REPLACE VIEW SWMS.V_PN1RA_SELECT AS
SELECT  repl.task_id, repl.batch_no, repl.status, repl.prod_id, repl.cust_pref_vendor, repl.src_loc,
        repl.dest_loc, repl.pallet_id, repl.uom,
        DECODE (repl.uom, 1, repl.qty, repl.qty / p.spc) qty,
        TRUNC (DECODE (repl.uom, 1, (i.qoh + repl.CumQty - repl.qty), (i.qoh + repl.CumQty - repl.qty) / p.spc)) qoh_before,
        TRUNC (DECODE (repl.uom, 1, (i.qoh + repl.CumQty), (i.qoh + repl.CumQty) / p.spc)) qoh_after,
        Repl.User_Id, Repl.Gen_Uid,
        Repl.exp_date,
        Pt.Pallet_Type,
        p.descrip, LTRIM (RTRIM (p.pack) || '/' || p.prod_size || ' ' || p.prod_size_unit) pack_size,
        LEAST (ROUND ((CumRepl * pt.skid_cube + (i.qoh + repl.CumQty) * p.split_cube) / DECODE (l.cube, 0, .01, l.cube) * 100, 2), 100) Pct_Full,
        ai.name aisle, ssa.area_code, repl.inv_dest_loc, repl.type, repl.gen_date, l.uom dest_uom
  From  (
        SELECT  r.task_id, r.type, r.batch_no, r.status, r.prod_id, r.cust_pref_vendor, r.exp_date,
                r.src_loc, r.dest_loc, r.pallet_id, r.uom, r.qty,
                SUM (r.qty) OVER (PARTITION BY r.dest_loc ORDER BY r.dest_loc ROWS UNBOUNDED PRECEDING) CumQty,
                COUNT (r.task_id) OVER (PARTITION BY r.dest_loc ORDER BY r.dest_loc ROWS UNBOUNDED PRECEDING) CumRepl,
                user_id, gen_uid, r.inv_dest_loc, gen_date
          From  Replenlst R
        WHERE  type = 'NDM'
         Order  By R.Dest_Loc, R.Pallet_Id) Repl,
        pm p, inv i, loc l, pallet_type pt, slot_type st,
        swms_sub_areas ssa, aisle_info ai
 WHERE  p.prod_id = repl.prod_id
   AND  i.plogi_loc = NVL (repl.inv_dest_loc, repl.dest_loc)
   AND  i.logi_loc = i.plogi_loc
   AND  l.logi_loc = i.plogi_loc
   AND  pt.pallet_type = l.pallet_type
   AND  st.slot_type = l.slot_type
   And  Ai.Pick_Aisle = L.Pik_Aisle
   And  Ssa.Sub_Area_Code = Ai.Sub_Area_Code;
/
CREATE OR REPLACE PUBLIC SYNONYM V_PN1RA_SELECT FOR SWMS.V_PN1RA_SELECT;


--Grant permissions


GRANT ALL ON SWMS.V_PN1RA_SELECT TO SWMS_USER;
/
