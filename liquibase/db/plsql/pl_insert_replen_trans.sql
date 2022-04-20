CREATE OR REPLACE
PROCEDURE SWMS.PL_INSERT_REPLEN_TRANS
   (r_prod_id               replenlst.prod_id%TYPE,
    r_drop_qty              replenlst.drop_qty%TYPE,
    r_uom                   replenlst.uom%TYPE,
    r_src_loc               replenlst.src_loc%TYPE,
    r_dest_loc              replenlst.dest_loc%TYPE,
    r_pallet_id             replenlst.pallet_id%TYPE,
    r_user_id               replenlst.user_id%TYPE,
    r_order_id              replenlst.order_id%TYPE,
    r_route_no              replenlst.route_no%TYPE,
    r_cust_pref_vendor      replenlst.cust_pref_vendor%TYPE,
    r_batch_no              replenlst.batch_no%TYPE,
    r_float_no              replenlst.float_no%TYPE,
    r_type          	    replenlst.type%TYPE,
    r_status          	    replenlst.status%TYPE,
    r_qty          	    replenlst.qty%TYPE,
    r_task_id               replenlst.task_id%TYPE,
    r_door_no               replenlst.door_no%TYPE,
    r_exp_date              replenlst.exp_date%TYPE,
    r_mfg_date              replenlst.mfg_date%TYPE,
    operation               VARCHAR2,
    r_inv_dest_loc          replenlst.inv_dest_loc%TYPE          DEFAULT NULL,
    r_parent_pallet_id      replenlst.parent_pallet_id%TYPE      DEFAULT NULL,
    r_labor_batch_no        replenlst.labor_batch_no%TYPE        DEFAULT NULL,
    i_replen_creation_type  replenlst.replen_type%TYPE           DEFAULT NULL,
    i_cross_dock_type       replenlst.cross_dock_type%TYPE       DEFAULT NULL)
IS
-----------------------------------------------------------------------------
-- @(#)src/schema/plsql/pl_insert_replen_trans.sql, swms, swms.9, 10.1.1 9/7/06 1.7
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    10/01/15 bben0556 Brian Bent
--                      Symbotic project.  WIB 543
--
--                      Bug fix--user getting "No LM batch" error message
--                      on RF when attempting to perform a DXL or DSP
--                      replenishment.  No transactions created for DXL and DSP.
--
--                      Add DXL and DSP replenishment types.
--
--
--    10/01/15 bben0556 Brian Bent
--                      Project:
-- R30.4--FTP30.3.2--WIB#584--Charm6000009889_ORDCW_records_not created_when_COO_item_bulk_pulled_repalletize_mixed_stops_on_float
--
--                      DSP trans.qty not correct.  Do not multiply by SPC
--                      since r_qty is already a split qty.
--
--                      Change
--                         IF (r_user_id NOT LIKE 'OPS$%') THEN
--                            l_user_id := r_user_id;
--                         ELSE
--                            l_user_id := SUBSTR(r_user_id, 5, 10);
--                         END IF;
--                      to
--                         l_user_id := REPLACE(r_user_id, 'OPS$', NULL);
--
--
--    06/22/16 bben0556 Brian Bent
--                      Project:
--       R30.4.2--WIB#646--Charm6000013323_Symbotic_replenishment_fixes
--
--                      RPL transaction for DXL transaction is incorrect.  It
--                      is getting multiplied by the spc.
--                      replenlst.qty for DXL replenishment is in splits
--                      so added DXL to the decode so that the r_qty is taken
--                      as is when populating l_qty which is used for the trans.qty.
--
--                      Note: For DMD the replenlst.qty is in cases when replenishing
--                            cases.
--
--
--    07/19/16 bben0556 Brian Bent
--                      Project:
--                R30.5--WIB#663--CRQ000000007533_Save_what_created_NDM_in_trans_RPL_record
--
--                      Add parameter i_replen_creation_type
--                      Add variables:
--     l_task_priority              user_downloaded_tasks.priority%TYPE;
--     l_suggested_task_priority    user_downloaded_tasks.priority%TYPE;
--
--                      Add:
--             l_task_priority := pl_replenishments.get_task_priority(r_task_id, USER);
--             l_suggested_task_priority := pl_replenishments.get_suggested_task_priority(USER);
--
--                      Populate TRANS.REPLEN_CREATION_TYPE with i_replen_creation_type
--                      Populate TRANS.REPLEN_TYPE with r_type
--                      Populate TRANS.TASK_PRIORITY
--                      Populate TRANS.SUGGESTED_TASK_PRIORITY
--
--                      TRANS.REPLEN_CREATION_TYPE added to the transaction
--                      tables to store what created the non-demand
--                      replenishment.  The OpCo wants to know this.
--                      The value comes from column REPLENST.REPLEN_TYPE 
--                      which for non-demand replenishments will have one of
--                      these values:
--       'L' - Created from RF using "Replen By Location" option
--       'H' - Created from Screen using "Replen by Historical" option
--       'R' - Created from screen with options other than "Replen by Historical"
--       'O' - Created from cron job when a store-order is received that
--             requires a replenishment
--
--
--                      TRANS.REPLEN_TYPE added to the transaction tables
--                      to store the replenishment type.  It main purpose is
--                      to store the matrix replenishment type.  The value
--                      will come from REPLENLST.TYPE.
--                      Matrix replenishments have diffent types but we use
--                      RPL for the transaction.  The OpCo wants to know the
--                      matrix replenishment type.  The matrix replenishment
--                      types are in table MX_REPLEN_TYPE which are
--                      listed here.
--               TYPE DESCRIP
--               ---  ----------------------------------------
--               DSP  Demand: Matrix to Split Home
--               DXL  Demand: Reserve to Matrix
--               MRL  Manual Release: Matrix to Reserve
--               MXL  Assign Item: Home Location to Matrix
--               NSP  Non-demand: Matrix to Split Home
--               NXL  Non-demand: Reserve to Matrix
--               UNA  Unassign Item: Matrix to Main Warehouse
--
--
--                      TASK_PRIORITY stores the forklift task priority
--                      for the NDM.  I also populated it for DMD's.
--                      The value comes from USER_DOWNLOADED_TASKS.
--
--                      SUGGESTED_TASK_PRIORITY stores the hightest
--                      forklift task priority from the replenishment
--                      list sent to the RF.  The value comes from
--                      USER_DOWNLOADED_TASKS.  Distribution Services
--                      wants to know if the forklift operator is doing
--                      lower priority drops before higher ones.
--
--    09/28/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3611_Site_2_XDK_task_PFK_DFK_transactions_not_created
--
--                      PFK and DFK transactions are not created when completing a XDK task.
--                      Add handling XDK.
--
--                      The replenlst.qty for a XDK will always be the number of pieces
--                      on the pallet---whether at Site 1 it was a normal selection or a bulk pull.
--                      This will also be the trans.qty for the PFK and DFK.  So
--                      when selecting the trans PFK and DFK for a XDK task do not not
--                      divide the trans.qty by the SPC--if the pallet has multiple items
--                      you could not divide by the spc anyway.
--
--    09/30/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3578_Site_2_Merging_after_route_gen_assign_float_seq_based_on_Site_1_comp_code
--
--                      For an XDK put in trans.cmt a note that the trans.qty is the number of pieces
--                      on the pallet---whether at Site 1 it was a normal selection or a bulk pull.
--
--    10/21/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3725_Site_2_Create_PIK_transaction_for_cross_dock_pallet
--
--                      Populate trans.cross_dock_type.
--                      Add parameter:
--                         i_cross_dock_type  replenlst.cross_dock_type%TYPE   DEFAULT NULL
--                      Add cross_dock_type to TRANS insert stmts.
--                      These triggers changed adding cross_dock_type in call to "pl_insert_replen_trans":
--                         - trg_ins_replenlst_row.sql
--                         - trg_upd_replenlst_row.sql
--                         - trg_del_replenlst_row.sql
--
--                      trans.qty not assigned to the PFK and DFK transactions for a Site 2 cross
--                      dock pallet ('X' cross dock type) and the pallet has multiple items.
--
-----------------------------------------------------------------------------
   l_user_id                    replenlst.user_id%TYPE ;
   l_trans_type                 trans.trans_type%TYPE ;
   l_loc                        NUMBER(2);
   l_qty                        trans.qty%TYPE;
   l_drop_qty                   trans.qty%TYPE;
   l_task_priority              user_downloaded_tasks.priority%TYPE;
   l_suggested_task_priority    user_downloaded_tasks.priority%TYPE;

   CURSOR c_loc (l_loc_no VARCHAR2) IS
      SELECT 0
      FROM loc
      WHERE logi_loc = l_loc_no
      AND perm = 'Y';
BEGIN
   BEGIN
      --
      -- Use the replenlst.qty as is for a Site 2 cross dock pallet.  The replenlst.qty is the number of
      -- pieces on the pallet.  Keep in mind the pallet can have multiple items.
      --
      IF (i_cross_dock_type = 'X') THEN 
         l_qty := r_qty;
         l_drop_qty := r_drop_qty;    -- r_drop_qty should always be null for a 'X' cross dock pallet.
      ELSE
         SELECT DECODE(r_type, 'DSP', r_qty,
                               'DXL', r_qty,
                               'XDK', r_qty,             -- Should not hit this condition as a XDK should have the cross_dock_type set to 'X'.
                                NVL(spc, 1) * r_qty),
                       NVL(spc, 1) * r_drop_qty
           INTO l_qty,
                l_drop_qty
           FROM pm
          WHERE prod_id          = r_prod_id
            AND cust_pref_vendor = r_cust_pref_vendor;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN NULL;
   END;

   l_user_id := REPLACE(r_user_id, 'OPS$', NULL);

   DBMS_OUTPUT.PUT_LINE ('USER ID = ' || l_user_id || ', PALLET ID = ' || r_pallet_id);

   IF (operation = 'INSERT') THEN
      BEGIN
         IF (r_type IN ('BLK', 'XDK')) THEN
            l_trans_type := 'PIK';
         ELSIF (r_type IN ('DMD', 'DXL', 'DSP')) THEN
            l_trans_type := 'RPL';
         END IF;

         l_user_id := 'ORDER';
      END;
   ELSIF (operation = 'UPDATE') THEN
      BEGIN
         IF (r_status = 'PIK') THEN
            BEGIN
               OPEN c_loc (r_src_loc);
               FETCH c_loc INTO l_loc;

               IF (c_loc%FOUND) THEN
                  l_trans_type := 'PHM';
               ELSE
                  l_trans_type := 'PFK';
               END IF;

               CLOSE c_loc;

               UPDATE floats
                  SET status = 'PIK'
                WHERE float_no = r_float_no;
            END;
         -- ELSIF (r_status = 'HOM' AND r_drop_qty > 0) THEN
         ELSIF (r_status = 'HOM') THEN
            BEGIN
               l_trans_type := 'DHM';
            END;
         ELSIF (r_status = 'NEW') THEN
            BEGIN
               DELETE trans
                WHERE pallet_id = r_pallet_id
                  AND trans_type IN ('PFK', 'PHM', 'DHM')
                  AND user_id IN (l_user_id, 'OPS$' || l_user_id);

               UPDATE floats
                  SET status = 'NEW'
                WHERE float_no = r_float_no;
            END;
         END IF;
      END;
   ELSIF (operation = 'DELETE') THEN
      BEGIN
         l_trans_type := 'DFK';

      END;
   END IF;

   IF (NOT ((operation = 'UPDATE') AND (r_status = 'NEW'))) THEN
      BEGIN
         IF (r_type IN ('BLK', 'XDK') AND operation = 'INSERT') THEN
            NULL;
         ELSE
            BEGIN
               l_task_priority := pl_replenishments.get_task_priority(r_task_id, USER);
               l_suggested_task_priority := pl_replenishments.get_suggested_task_priority(USER);

               INSERT INTO trans
                                (trans_id,
                                 trans_type,
                                 trans_date,
                                 prod_id,
                                 qty,
                                 uom,
                                 src_loc,
                                 dest_loc,
                                 user_id,
                                 order_id,
                                 route_no,
                                 cust_pref_vendor,
                                 batch_no,
                                 float_no,
                                 pallet_id,
                                 cmt,
                                 bck_dest_loc,
                                 exp_date,
                                 mfg_date,
                                 labor_batch_no,
                                 parent_pallet_id,
                                 replen_task_id,
                                 replen_creation_type,
                                 replen_type,
                                 task_priority,
                                 suggested_task_priority,
                                 cross_dock_type)
                          VALUES
                                (trans_id_seq.NEXTVAL,
                                 l_trans_type,
                                 SYSDATE,
                                 r_prod_id,
                                 DECODE(l_trans_type, 'DHM', l_drop_qty, l_qty),
                                 r_uom,
                                 r_src_loc,
                                 DECODE(l_trans_type, 'DHM',
							DECODE (r_inv_dest_loc, NULL, r_dest_loc, r_inv_dest_loc),
						DECODE (r_type, 'RPL',
							DECODE (r_inv_dest_loc, NULL, r_dest_loc, r_inv_dest_loc),
						NVL (TO_CHAR (r_door_no), r_dest_loc))),
                                 DECODE(l_user_id, 'ORDER', l_user_id, 'OPS$' || l_user_id),
                                 r_order_id,
                                 r_route_no,
                                 r_cust_pref_vendor,
                                 r_batch_no,
                                 r_float_no,
                                 r_pallet_id,
                                 DECODE(r_type, 'XDK', 'THIS IS A "XDK" TASK.  THE TRANSACTION QTY IS THE NUMBER OF PIECES ON THE PALLET.',
                                                r_float_no),
                                 DECODE(r_inv_dest_loc, NULL, NULL, r_dest_loc),
                                 r_exp_date,
                                 r_mfg_date,
                                 NVL(r_labor_batch_no,'FR' || r_float_no),
                                 r_parent_pallet_id, 
                                 r_task_id,
                                 i_replen_creation_type,
                                 r_type,
                                 l_task_priority,
                                 l_suggested_task_priority,
                                 i_cross_dock_type);
            END;
         END IF;
      END;
   END IF;

   IF ((operation = 'INSERT') AND (NVL (r_drop_qty, 0) > 0) AND (r_type = 'BLK')) THEN
      BEGIN
         l_task_priority := pl_replenishments.get_task_priority(r_task_id, USER);
         l_suggested_task_priority := pl_replenishments.get_suggested_task_priority(USER);

         INSERT INTO trans
                          (trans_id,
                           trans_type,
                           trans_date,
                           prod_id,
                           qty,
                           uom,
                           src_loc,
                           dest_loc,
                           user_id,
                           order_id,
                           route_no,
                           cust_pref_vendor,
                           batch_no,
                           float_no,
                           pallet_id,
                           cmt,
                           bck_dest_loc,
                           exp_date,
                           mfg_date,
                           labor_batch_no,
                           replen_task_id,
                           replen_creation_type,
                           replen_type,
                           task_priority,
                           suggested_task_priority,
                           cross_dock_type)
                   VALUES 
                          (trans_id_seq.NEXTVAL,
                           'DRO',
                           SYSDATE,
                           r_prod_id,
                           l_drop_qty,
                           r_uom,
                           r_src_loc,
                           NVL(r_inv_dest_loc, r_dest_loc),
                           DECODE(l_user_id, 'ORDER', l_user_id, 'OPS$' || l_user_id),
                           r_order_id,
                           r_route_no,
                           r_cust_pref_vendor,
                           r_batch_no,
                           r_float_no,
                           r_pallet_id,
                           DECODE(r_type, 'XDK', 'THIS IS A "XDK" TASK.  THE TRANSACTION QTY IS THE NUMBER OF PIECES ON THE PALLET.',
                                          r_float_no),
                           DECODE(r_inv_dest_loc, NULL, NULL, r_dest_loc),
                           r_exp_date,
                           r_mfg_date,
                           'FR' || r_float_no,
                           r_task_id,
                           i_replen_creation_type,
                           r_type,
                           l_task_priority,
                           l_suggested_task_priority,
                           i_cross_dock_type);
      END;
   END IF;
END;
/

