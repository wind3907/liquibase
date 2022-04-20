------------------------------------------------------------------------------
--
-- View:
--    V_NDM_REPLEN_INFO
--
-- Description:
--    This view is used in creating non-demand replenishments.
--
--    The different types of non-demand replenishments this view is used
--    to create are:
--       'L' - Created from RF using "Replen By Location" option
--       'H' - Created from Screen using "Replen by Historical" option
--       'R' - Created from screen with options other than "Replen by Historical"
--       'O' - Created from cron when a store-order is received that requires a replenishment
--
--    This type is significant because there is different processing when
--    creating replenishments by min/max qty for HS or CF home slot.
--    The rules for min/max qty for HS and CF home slots are:
--       - For historical orders and store orders, types H and O, create
--         a replenishment if the qty in the home slot is < order quantity
--         and the qty in the home slot is < max qty.
--       - For the other types, L and R, create a replenishment when
--         the qty in the home slot is <= min qty.
-- 
--
-- Used By (list may not be complete):
--    -  create_ndm.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/05/12 prpbcb   Project: CRQ41507-Non_demand_repl_dropped_newer_pallet
--                      Activity: CRQ41507-Non_demand_repl_dropped_newer_pallet
--                      Fixed decode stmt.  Changed this decode stmt
-- DECODE (INSTR (p.fifo_trk || p.exp_date_trk || p.mfg_date_trk, 'Y'), 0, 'N', 'Y')
--                      to
-- DECODE(INSTR(DECODE(p.fifo_trk, 'A', 'Y', 'S', 'Y', 'N') || p.exp_date_trk || p.mfg_date_trk, 'Y'), 0, 'N', 'Y')
--                      The fifo flag is F or S or N.
--
--    12/05/12 prpbcb00 Project:  TFS Work ID 1
--                    R12.5 Developers Regression Testing Defects and Fixes
--
--                      For HS and CF create replenishments for historical
--                      and planned orders(store orders) if:
--                            - QOH in the home slot(s) < max qty
--                              and
--                            - QOH in the home slot(s) < order qty
--                      
--    03/18/13 prpbcb00 TFS Project:
-- R12.5.1--WIB#109--CRQ45202:Non-demand replenishments by min/max qty ignoring min qty
--
--                      Bug fix.
--                      Added call to pl_replenishments.get_replen_type() and
--                      expanded the CASE statement.
--
--                      The change I made on 12/05/2012 for historical orders
--                      and planned orders replenishments for HS and CF when
--                      replenishing by min/max qty ended up applying to all
--                      HS and CF replenishments when replenishing by min/max
--                      qty.  This happened because this view did not
--                      know if the replenishments being created were for
--                      regular replenishments, historical or from a planned
--                      order.
--
--                      To fix this program create_ndm.pc was changed to
--                      call package procedure
--                      pl_replenishments.set_replen_type() to set the type
--                      of pl_replenishment getting created.  This view
--                      will call package function
--                      pl_replenishments.get_replen_type() to get the
--                      type of replenishment being created.
--                      pl_replenishments.get_replen_type() will return one
--                      of these:
--       'L' - Created from RF using "Replen By Location" option
--       'H' - Created from Screen using "Replen by Historical" option
--       'R' - Created from screen with options other than "Replen by Historical"
--       'O' - Created from cron when a store-order is received that requires a replenishment
--
--                      The CASE statement in this view checks for replen
--                      types H or O.  So if you want test these replen types
--                      by directly selecting from this view first call
--                      pl_replenishments.set_replen_type() with
--                      parameter H or O then select from the view.
--    08/21/14 Infosys  R13.0-Charm#6000000054-
--            Changes done for excluding Cross Dock inventory from 
--            being included for regular Non-demand replenishment
--    04/25/15 avij3336 R30.0 - Charm#6000007358 - Changes to avoid duplicate replenishment
--                      task getting created.
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swms.v_ndm_replen_info
AS
SELECT  rpl.*
  FROM
     ( -- start inline view
      SELECT distinct l.logi_loc,
             p.prod_id rpl_prod_id,
             p.cust_pref_vendor rpl_cpv,
             p.area,
             p.spc,
             p.fifo_trk,
             p.case_pallet,
             p.case_cube,
             p.min_qty,
             p.max_qty,
             p.ti,
             p.hi,
             --
             DECODE(INSTR(DECODE(p.fifo_trk, 'A', 'Y', 'S', 'Y', 'N')
                            || p.exp_date_trk || p.mfg_date_trk, 'Y'),
                    0, 'N',
                   'Y') is_trk,
             --
             l.cube,
             l.uom,
             l.put_path,
             SUBSTR(l.logi_loc, 1, 2) put_aisle,
             l.pallet_type,
             l.slot_type,
             CEIL((i.qoh + i.qty_planned - i.qty_alloc) / spc) curr_inv_qty,
             TO_CHAR(i.exp_date, 'MMDDYYYY') exp_date,
             l.rank,
             --
             --
             (CASE
                 WHEN l.uom = 1 THEN
                    ROUND (l.cube / p.case_cube)
                 WHEN ndm_repl_method = 'C' THEN
                    ROUND((l.Cube - (skid_cube * deep_positions)) / p.case_cube)
                 WHEN ndm_repl_method = 'M' THEN
                    (CASE l.pallet_type
                       WHEN 'HS' THEN
                          (CASE pl_replenishments.get_replen_type
                              WHEN 'H' THEN
                                 DECODE(SIGN(CEIL((i.qoh + i.qty_planned - i.qty_alloc) / spc) - p.max_qty), -1, p.max_qty, 0)
                              WHEN 'O' THEN
                                 DECODE(SIGN(CEIL((i.qoh + i.qty_planned - i.qty_alloc) / spc) - p.max_qty), -1, p.max_qty, 0)
                              ELSE
                                 DECODE(SIGN(CEIL((i.qoh + i.qty_planned - i.qty_alloc) / spc) - p.min_qty),
                                        1, 0,
                                        p.max_qty)
                          END)
                       WHEN 'CF' THEN
                          (CASE pl_replenishments.get_replen_type
                             WHEN 'H' THEN
                                DECODE(SIGN(CEIL((i.qoh + i.qty_planned - i.qty_alloc) / spc) - p.max_qty), -1, p.max_qty, 0)
                             WHEN 'O' THEN
                                DECODE(SIGN(CEIL((i.qoh + i.qty_planned - i.qty_alloc) / spc) - p.max_qty), -1, p.max_qty, 0)
                             ELSE
                                DECODE(SIGN(CEIL((i.qoh + i.qty_planned - i.qty_alloc) / spc) - p.min_qty),
                                       1, 0,
                                       p.max_qty)
                          END)
                       ELSE
                           DECODE(SIGN(CEIL((i.qoh + i.qty_planned - i.qty_alloc) / spc) - p.min_qty),
                                  1, 0,
                                  p.max_qty)
                    END) 
                 ELSE
                    (ti * hi * deep_positions) + p.min_qty
             END) num_rpl_cases,
             --
             --
             ndm_repl_method, skid_cube, split_cube, deep_positions, bck_logi_loc
        FROM loc_reference lr,
             pm p,
             pallet_type pt,
             slot_type st,
             loc l,
             lzone lz,
             zone z,
             inv i
       WHERE l.perm = 'Y'
         AND l.prod_id IS NOT NULL
         AND i.plogi_loc = l.logi_loc
         AND lz.logi_loc = l.logi_loc
         AND z.zone_id = lz.zone_id
         AND pt.pallet_type = l.pallet_type
         AND st.slot_type = l.slot_type
         AND i.status != 'CDK'
         AND i.prod_id = l.prod_id
         AND p.prod_id = i.prod_id
         AND NVL(p.mx_item_assign_flag, 'N') != 'Y'
         AND p.cust_pref_vendor = l.cust_pref_vendor
         AND l.logi_loc = lr.plogi_loc (+)
         AND (
             (l.uom != 1 AND
              EXISTS (SELECT 0
                        FROM inv i1
                       WHERE i1.prod_id = l.prod_id
                         AND i1.logi_loc != i1.plogi_loc
                         AND i1.status = 'AVL'
                         AND i1.inv_uom != 1
                         AND i1.qoh > 0
                         AND i1.qty_alloc = 0))
                OR
                   (l.uom = 1 AND
                    EXISTS (SELECT 0
                              FROM inv i2
                             WHERE i2.prod_id = l.prod_id
                               AND i2.logi_loc = i2.plogi_loc
                               AND i2.status = 'AVL'
                               AND i2.inv_uom = 2
                               AND i2.qoh - i2.qty_alloc > 0
                               AND i2.qty_alloc = 0))
             )
     ) rpl  -- end inline view
 WHERE 1=1
   AND  curr_inv_qty < num_rpl_cases
   AND ((      ndm_repl_method = 'T'
            AND rpl.uom != 1
            AND EXISTS
                      (SELECT 0
                       FROM inv i2
                      WHERE i2.prod_id = rpl_prod_id
                        AND i2.status = 'AVL'
                        AND i2.logi_loc != i2.plogi_loc
                        AND i2.inv_uom != 1
                        AND i2.qoh - i2.qty_alloc > 0
                        AND i2.qoh / rpl.spc <= (num_rpl_cases - curr_inv_qty)))
        OR
            (   ndm_repl_method != 'T'
             OR rpl.uom = 1)
       )
/

CREATE OR REPLACE PUBLIC SYNONYM v_ndm_replen_info
   FOR swms.v_ndm_replen_info
/
GRANT SELECT ON v_ndm_replen_info TO SWMS_USER, SWMS_VIEWER
/

