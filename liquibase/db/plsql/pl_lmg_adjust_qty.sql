
PROMPT Create package specification: pl_lmg_adjust_qty

/*************************************************************************/
-- Package Specification
/*************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_lmg_adjust_qty
AS

   -- sccs_id=@(#) src/schema/plsql/pl_lmg_adjust_qty.sql, swms, swms.9, 10.1.1 9/7/06 1.5

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lmg_adjust_qty
   --
   -- Description:
   --    This package has objects used to determine any adjustment that needs
   --    to be made to the drop and pickup quantity for a slot for forklift
   --    labor management.  These adjustments can affect the quantity
   --    handstacked for a drop or pickup from a slot that calls for
   --    handstacking.
   --
   --    07/30/03 prpbcb
   --    An example of when the quantity handstacked to a slot needs to be
   --    adjusted is for a putaway of 30 cases to a carton flow home slot
   --    which is followed by a demand HST of 10 cases to reserve.  Drops to
   --    a carton flow slot are always handstacked.  The operator needs to
   --    get credit to handstack 20 cases to the carton flow home slot for
   --    the putaway batch and get credit to handstack 0 cases from the
   --    carton flow home slot for the demand HST.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/29/03 prpbcb   Oracle 7 rs239a DN none.  Does not exist on oracle 7.
   --                      Oracle 8 rs239b DN 11338
   --                      Initial creation.
   --    04/21/04 prpbcb   Oracle 7 rs239a DN None
   --                      Oracle 8 rs239b swms8 DN None
   --                      Oracle 8 rs239b swms9 DN 11580
   --                      RDC change.
   --                      Change queries to join to trans.labor_batch_no
   --                      or trans.cmt.  When we know the trans.labor_batch_no
   --                      is always populated the join on trans.cmt can be
   --                      removed.  labor_batch_no is a new column in the
   --                      trans table.
   --
   --    08/08/05 prpbcb   Oracle 8 rs239b swms9 DN 11974
   --                      Project: CRT-Carton Flow replenishments
   --
   --                      Added handling of the FE batch.  This is a return
   --                      to reserve of a partially completed demand
   --                      replenishment.  From the labor mgmt point of view
   --                      a FE batch is identical to a FH (home slot
   --                      transfer) batch.  Changed line 311
   --                      from
   --                         WHERE SUBSTR(b2.batch_no, 1, 2) = 'FH'
   --                      to
   --                         WHERE SUBSTR(b2.batch_no, 1, 2) IN ('FH', 'FE')
   --
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Type Declarations
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Variables
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Public Constants
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_hst_handstack_qty
   --
   -- Description:
   --    This function calculates the quantity that the operator will get
   --    credit to handstack from the home slot for a home slot transfer or
   --    a demand replenishment home slot transfer.
   --    The quantity will be in splits.  This is done by checking if the
   --    user last operation was a drop to the same slot and the same
   --    pallet id as the home slot.  This last operation will be under a
   --    completed or suspended batch.
   --
   --    This calculation takes place when the HST batch is being completed.
   --
   --    The rule is if the operators previous operation before the home slot
   --    transfer was a drop to the same slot with the same pallet id then the
   --    operator will not be given time to handstack the home slot transfer
   --    quantity because it was just left on the pallet during the drop.
   --    This will mainly happen for carton flow and handstack slots.
   --
   --    An audit record is created if forklift audit is active.
   --
   --    Example:
   --       The operator performs a demand replenishment (DMD) of 30 cases to
   --       carton flow slot DA01A1 for pallet 12345.  A drop to a carton flow
   --       slot will always be handstacked--this is the rule.  The operators
   --       next operation is a HST of 10 cases from DA01A1 to DA03B5 for
   --       pallet 12345 for the same item.  The operator will get credit to
   --       handstack 20 cases to the slot for the DMD.  The operator will
   --       not get any credit for handstacking for the HST because he would
   --       have left the 10 cases on the pallet during the DMD.
   ---------------------------------------------------------------------------
   FUNCTION f_get_hst_handstack_qty(i_hst_batch_no IN arch_batch.batch_no%TYPE,
                                    i_hst_qty      IN  BINARY_INTEGER)
   RETURN BINARY_INTEGER;

END pl_lmg_adjust_qty;  -- end package specification
/

SHOW ERRORS;

PROMPT Create package body: pl_lmg_adjust_qty

/**************************************************************************/
-- Package Body
/**************************************************************************/
CREATE OR REPLACE PACKAGE BODY swms.pl_lmg_adjust_qty
IS

   -- sccs_id=@(#) src/schema/plsql/pl_lmg_adjust_qty.sql, swms, swms.9, 10.1.1 9/7/06 1.5

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lmg_adjust_qty
   --
   -- Description:
   --    This package has objects used to determine and adjust the drop
   --    quantity for forklift labor management.
   --
   --    The drop quantity can also affect the pickup quantity for a home
   --    slot transfer made immediately after a drop.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/29/03 prpbcb   Oracle 7 rs239a DN none.  Does not exist on oracle 7.
   --                      Oracle 8 rs239b DN 11338
   --                      Initial creation.
   --                      This package has objects for determining and
   --                      adjusting the drop quantity and possibly adjusting
   --                      the pickup quantity for home slot transfers.
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Private Type Declarations
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Private Global Variables
   ---------------------------------------------------------------------------
   gl_pkg_name   VARCHAR2(30) := 'pl_lmg_adjust_qty';   -- Package name.
                                             --  Used in error messages.

   gl_e_parameter_null  EXCEPTION;     -- A parameter to a procedure/function
                                       -- is null.

   ---------------------------------------------------------------------------
   -- Private Constants
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Private Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Procedure:
   --    f_get_hst_handstack_qty
   --
   -- Description:
   --    This function calculates the quantity that the operator will get
   --    credit to handstack from the home slot for a home slot transfer or
   --    a demand replenishment home slot transfer.
   --    The quantity will be in splits.  This is done by checking if the
   --    user last operation was a drop to the same slot and the same
   --    pallet id as the home slot.  This last operation will be under a
   --    completed or suspended batch.
   --
   --    This calculation takes place when the HST batch is being completed.
   --
   --    The rule is if the operators previous operation before the home slot
   --    transfer was a drop to the same slot with the same pallet id then the
   --    operator will not be given time to handstack the home slot transfer
   --    quantity because it was just left on the pallet during the drop.
   --    This will mainly happen for carton flow and handstack slots.
   --
   --    An audit record is created if forklift audit is active.
   --
   --    Example:
   --       The operator performs a demand replenishment (DMD) of 30 cases to
   --       carton flow slot DA01A1 for pallet 12345.  A drop to a carton flow
   --       slot will always be handstacked--this is the rule.  The operators
   --       next operation is a HST of 10 cases from DA01A1 to DA03B5 for
   --       pallet 12345 for the same item.  The operator will get credit to
   --       handstack 20 cases to the slot for the DMD.  The operator will
   --       not get any credit for handstacking for the HST because he would
   --       have left the 10 cases on the pallet during the DMD.
   --
   -- Parameters:
   --    i_hst_batch_no   - HST batch being processed.  It should be in the
   --                       process of being completed.
   --    i_hst_qty        - Initial HST quantity in splits (it would have come
   --                       from TRANS.QTY).
   --
   -- Return Value:
   --    The quantity in splits to give credit to handstack from the
   --    home slot.
   --  
   -- Exceptions raised:
   --    User defined exception   - A called object returned an user
   --                               defined error.
   --    pl_exc.e_data_error      - Parameter null.
   --                               Batch not a HST.
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Called by:
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/29/03 prpbcb   Created.
   --    08/09/05 prpbcb   Added handling of a demand replenishment home
   --                      slot transfer.
   ---------------------------------------------------------------------------
   FUNCTION f_get_hst_handstack_qty(i_hst_batch_no IN arch_batch.batch_no%TYPE,
                                    i_hst_qty      IN  BINARY_INTEGER)
   RETURN BINARY_INTEGER IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                            '.f_get_hst_handstack_qty';

      l_batch_type     VARCHAR2(10);  -- The batch type.

      l_r_last_drop_point   pl_lmd_drop_point.t_drop_point_rec;  -- Drop point
                                                                 -- info.

      l_record_found_bln  BOOLEAN;  -- Holding place for cursor found
                                    -- value.

      l_handstack_qty  BINARY_INTEGER;

      -- This cursor selects a users last completed or suspended drop batch
      -- (drop batch meaning a pallet was dropped to the home slot) that is
      -- before the home slot transfer batch if this drop batch is the users
      -- last batch.
      -- It also selects information about the HST batch.
      -- Some of the HST batch information is needed for the audit record.
      -- Note that if there are batches with the same start time, which
      -- should not happen, then there is a potential for problems.
      CURSOR c_batch_info(cp_hst_batch_no arch_batch.batch_no%TYPE) IS
         SELECT b.batch_no          last_drop_batch_no,
                bhst.batch_no       hst_batch_no,
                bhst.ref_no         hst_pallet_id,
                bhst.kvi_from_loc   hst_from_loc,
                t.prod_id           hst_prod_id,
                t.cust_pref_vendor  hst_cpv
           FROM trans t,    -- To get info about the HST batch.
                batch b,    -- To get the last drop batch for the user.
                batch bhst  -- To match up with the same user.
          WHERE b.status      IN ('C', 'W')
            AND b.user_id     = bhst.user_id
            AND bhst.batch_no = cp_hst_batch_no
             -- 08/05/03 prpbcb We need to create a new column in the
             -- TRANS table to hold the labor mgmt batch number and not use
             -- the cmt column !!!
            AND (   t.cmt   = SUBSTR(cp_hst_batch_no, 3)
                 OR t.labor_batch_no = cp_hst_batch_no)
            AND t.pallet_id   = bhst.ref_no || ''
            AND SUBSTR(b.batch_no, 1, 2) IN ('FP', 'FR', 'FN')  -- Drop batch
            -- Checking the batch type with the function is too slow(for some
            -- reason) and it is still hardcoding.
            -- AND pl_lmc.get_batch_type(b.batch_no) IN
            --                          (pl_lmc.ct_forklift_putaway,
            --                           pl_lmc.ct_forklift_nondemand_rpl,
            --                           pl_lmc.ct_forklift_demand_rpl)
            AND b.actl_start_time =
                   (SELECT MAX(b2.actl_start_time)  -- Start time of users
                      FROM batch b2                 -- last C or W batch.
                     WHERE b2.user_id         = b.user_id
                       AND b2.status          IN ('C', 'W')
                       AND b2.actl_start_time < bhst.actl_start_time
                       -- Do not look at a FH batch completed within another
                       -- batch or is completed and the user has a suspended
                       -- batch.
                       -- This is to handle this type of situation:
                       --    PUT (merged)
                       --    DHST                 (DHST is a demand HST)
                       --    PUT (merged)
                       --    DHST  When this FH batch is completed it needs
                       --          to find the PUT batch in order to calculate
                       --          the handstack qty.  If this subquery is not
                       --          here then the 1st DHST (which will be
                       --          completed) will be the users last batch thus
                       --          no record will be selected.
                       -- and this situation which will have a suspended batch
                       -- when the second DHST is completed.
                       --    PUT (merged)
                       --    DHST
                       --    PUT (merged)
                       --    DHST
                       --    PUT (merged)
                       --    DHST
                       AND NOT EXISTS
                        (SELECT 'x'
                           FROM batch b3
                          WHERE SUBSTR(b2.batch_no, 1, 2) IN ('FH', 'FE')
                            AND b3.user_id = b2.user_id
                            AND
                            (
                               (    b3.status = 'C'
                                AND b2.actl_start_time > b3.actl_start_time
                                AND b2.actl_stop_time < b3.actl_stop_time)
                              OR
                                (    b3.status = 'W'
                                 AND b2.actl_start_time > b3.actl_start_time)
                            )
                            ));

      l_r_batch_info c_batch_info%ROWTYPE;

      e_not_hst_batch        EXCEPTION;  -- The batch is not a HST batch.

      ------------------------------------------------------------------------
      -- Local Procedure:
      --    write_hst_message
      --
      -- Description:
      --    This procedure writes a swms log message and audit record for
      --    the HST when the HST handstack qty is adjusted because of a
      --    previous drop to the same slot with the same pallet id and
      --    same item.
      --
      -- Parameters:
      --    i_hst_qty           - The HST quantity in splits.
      --    i_handstack_qty     - The HST quantity that time will be given to
      --                          handstack.
      --    i_r_batch_info      - Info about the HST batch and the operators
      --                          last completed or suspended batch drop batch.
      --    i_r_last_drop_point - Info about the operators last completed
      --                          or suspended drop batch.  The quantities
      --                          in the record are in splits.
      --
      -- Exceptions raised:
      --    None.  An error will be written to swms log.
      --
      -- Called by:
      --    f_get_hst_handstack_qty
      -- 
      -- Modification History:
      --    Date     Designer Comments
      --    -------- -------- ------------------------------------------------
      --    07/29/03 prpbcb   Created.
      ------------------------------------------------------------------------
      PROCEDURE write_hst_message
               (i_hst_qty              IN BINARY_INTEGER,
                i_handstack_qty        IN BINARY_INTEGER,
                i_r_batch_info         IN c_batch_info%ROWTYPE,
                i_r_last_drop_point    IN pl_lmd_drop_point.t_drop_point_rec)
      IS
         l_message        VARCHAR2(1500);    -- Message buffer
         l_object_name    VARCHAR2(61) := gl_pkg_name || '.write_hst_message';

         l_cases          BINARY_INTEGER;
         l_spc            pm.spc%TYPE;   -- SPC for the item to case up the
                                         -- qty.  We want to show cases and
                                         -- splits in the message.
         l_splits         BINARY_INTEGER;

         CURSOR c_spc(cp_prod_id  pm.prod_id%TYPE,
                      cp_cpv      pm.cust_pref_vendor%TYPE) IS
            SELECT NVL(pm.spc, 1)
              FROM pm
            WHERE pm.prod_id         = cp_prod_id
             AND pm.cust_pref_vendor = cp_cpv;
      BEGIN

         -- Get the SPC for the item so the quantities can be reported in
         -- cases and splits in the message.
         OPEN c_spc(i_r_batch_info.hst_prod_id, i_r_batch_info.hst_cpv);
         FETCH c_spc INTO l_spc;
         IF (c_spc%NOTFOUND) THEN
            l_spc := 1;
            l_message := l_object_name || ': ' || 
               'prod id[' || i_r_batch_info.hst_prod_id || ']' ||
               ' crod id[' || i_r_batch_info.hst_cpv || ']  Failed to select' ||
               ' the SPC.  Will use 1.';
            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
         END IF;
         CLOSE c_spc;

         -- Build the message.  It is long.
         l_message := 'HST batch ' || i_r_batch_info.hst_batch_no || ' is a' ||
            ' transfer of ' ||
            TO_CHAR(TRUNC(i_hst_qty / l_spc)) || ' case(s)' ||
            ' and ' || TO_CHAR(MOD(i_hst_qty, l_spc)) || ' split(s).' ||
            '  The previous operation for the user' ||
            ' was a drop on batch ' || i_r_last_drop_point.batch_no || ' of ' ||
            TO_CHAR(TRUNC(i_r_last_drop_point.trans_qty / l_spc)) ||
            ' case(s) and ' ||
            TO_CHAR(MOD(i_r_last_drop_point.trans_qty, l_spc)) ||
            ' split(s) to the same slot ' || i_r_batch_info.hst_from_loc ||
            ' and same LP ' || i_r_batch_info.hst_pallet_id ||
            ' and same item ' || i_r_batch_info.hst_prod_id || ' as the HST.' ||
            '  The user was given time to handstack ' ||
            TO_CHAR(TRUNC(i_r_last_drop_point.drop_qty / l_spc)) ||
            ' case(s) and ' ||
            TO_CHAR(MOD(i_r_last_drop_point.drop_qty, l_spc)) ||
            ' splits(s) on batch ' || i_r_last_drop_point.batch_no || '.' ||
            '  This indicates not all the quantity was' ||
            ' physically put in the home slot on the drop by the' ||
            ' user.' ||
            '  For the HST the user will get time to' ||
            ' handstack what was entered for the HST minus what was' ||
            ' left on the pallet after the drop.' ||
            '  This will be ' ||
            TO_CHAR(TRUNC(l_handstack_qty / l_spc)) || ' case(s) and ' ||
            TO_CHAR(MOD(l_handstack_qty, l_spc)) || ' splits(s).';

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                        NULL, NULL);

         -- Write audit record if auditing.
         IF (pl_lma.g_audit_bln) THEN
            pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_1);
         END IF;

      EXCEPTION
         WHEN OTHERS THEN
            -- A failure to write an audit record is not considered a
            -- fatal error.  Processing will continue.
            l_message := l_object_name || ': ' || 
               'i_hst_qty[' || TO_CHAR(i_hst_qty) ||
               ' i_r_batch_info.hst_batch_no[' ||
                                 i_r_batch_info.hst_batch_no || ']' ||
               ' i_r_last_drop_point.batch_no[' ||
                                 i_r_last_drop_point.batch_no || ']';
            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);

      END write_hst_message;   -- end local procedure

   BEGIN

      l_message_param := l_object_name ||
                        '(i_hst_batch_no[' || i_hst_batch_no || ']' ||
                        ',i_hst_qty[' || TO_CHAR(i_hst_qty) || ']splits)';

      -- Check if parameter is null.
      IF (i_hst_batch_no IS NULL OR i_hst_qty IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- The batch has to be a HST batch.
      l_batch_type := pl_lmc.get_batch_type(i_hst_batch_no);
      IF (    (l_batch_type != pl_lmc.ct_forklift_home_slot_xfer
          AND  l_batch_type != pl_lmc.ct_forklift_dmd_rpl_hs_xfer)
          OR l_batch_type IS NULL) THEN
         RAISE e_not_hst_batch;
      END IF;

      -- Initially the HST qty will all be handstacked.  It will be changed
      -- if necessary.
      l_handstack_qty := i_hst_qty; 

      OPEN c_batch_info(i_hst_batch_no);
      FETCH c_batch_info INTO l_r_batch_info;
      l_record_found_bln := c_batch_info%FOUND;
      CLOSE c_batch_info;

      IF (l_record_found_bln) THEN
         -- Found a drop batch.
       
         -- Debug stuff.
         l_message := l_message_param || 
            ' last drop['    || l_r_batch_info.last_drop_batch_no || ']' ||
            ' hst pallet['   || l_r_batch_info.hst_pallet_id      || ']' ||
            ' hst from loc[' || l_r_batch_info.hst_from_loc       || ']';
         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                         NULL, NULL);

         -- Get info about the last drop made on the drop batch.
         pl_lmd_drop_point.get_last_drop_point
                                     (l_r_batch_info.last_drop_batch_no,
                                      l_r_last_drop_point);

         -- If the last drop point matches that of the HST then calculate
         -- the quantity to handstack.  The quantity will be in splits.
         IF (    l_r_last_drop_point.pallet_id  = l_r_batch_info.hst_pallet_id
             AND l_r_last_drop_point.prod_id    = l_r_batch_info.hst_prod_id
             AND l_r_last_drop_point.cpv        = l_r_batch_info.hst_cpv
             AND l_r_last_drop_point.drop_point =
                                            l_r_batch_info.hst_from_loc) THEN
            -- The drop was for the same location, pallet and item as the HST.
            -- Calculate the HST quantity to handstacked.
            -- Ideally the resulting value should be 0.

            -- The last drop point can be a suspended batch so the kvi values
            -- and not yet populated (they are populated when the batch is
            -- completed).  l_r_last_drop_point.drop_qty stores these
            -- kvi values.  If the last drop point batch is not completed
            -- set the drop qty to the transaction qty minus the home slot
            -- qty.  This is to prevent the handstack qty from being negative.
            IF (l_r_last_drop_point.parent_status != 'C') THEN
               l_r_last_drop_point.drop_qty :=
                               l_r_last_drop_point.trans_qty - i_hst_qty;
            END IF;

            l_handstack_qty := i_hst_qty -
               (l_r_last_drop_point.trans_qty - l_r_last_drop_point.drop_qty);

            -- Check the qty and write an appropriate log message.
            IF (l_handstack_qty >= 0) THEN
               write_hst_message(i_hst_qty,
                                 l_handstack_qty,
                                 l_r_batch_info,
                                 l_r_last_drop_point);
            ELSE
               -- Got an abnormal condition.  The hst qty is less than 0.
               --  Write a log message and set the hst qty to 0.
               l_message := l_message_param || '  Last completed drop batch[' ||
           l_r_last_drop_point.batch_no || ']  drop qty[' ||
           TO_CHAR(l_r_last_drop_point.drop_qty) || ']splits  trans qty[' ||
           TO_CHAR(l_r_last_drop_point.trans_qty) || ']splits' ||
           ' i_hst_qty - (last drop trans qty - last drop qty)  results in' ||
           ' a negative handstack qty.  Setting the handstack qty to 0';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                              NULL, NULL);

               -- Write audit record if auditing.
               IF (pl_lma.g_audit_bln) THEN
                  pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                   pl_lma.ct_detail_level_1);
               END IF;

               l_handstack_qty := 0;
            END IF;
       
         END IF;
      ELSE
         -- Last batch for user not a drop.
         -- The operator will get credit to handstack the quantity on the
         -- HST pallet.
         l_message := l_message_param || ' last batch not a drop';
         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                         NULL, NULL);
      END IF;

      RETURN(l_handstack_qty);

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_message_param || '  A parameter is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN e_not_hst_batch THEN
         l_message := l_message_param || 
            '  The batch is not a home slot transfer batch.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_message || ': ' || SQLERRM);
         END IF;

   END f_get_hst_handstack_qty;

END pl_lmg_adjust_qty;   -- end package body
/

SHOW ERRORS;

