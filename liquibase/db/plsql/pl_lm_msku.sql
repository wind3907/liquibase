
PROMPT Create package specification: pl_lm_msku

/*************************************************************************/
-- Package Specification
/*************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_lm_msku
IS

   -- sccs_id=@(#) src/schema/plsql/pl_lm_msku.sql, swms, swms.9, 10.1.1 9/7/06 1.9

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lm_msku
   --
   -- Description:
   --    MSKU labor mgmt.
   --    This package has objects for MSKU labor mgmt and returns putaway
   --    labor mgmt.  These objects include procedures/functions to:
   --       - merge batches.
   --       - write audit messages.
   --       - create returns putaway labor mgmt batches
   --
   --    Returns putaway is very similar to a RDC MSKU.  Returns are
   --    accumulated on a physical pallet until the pallet reaches a
   --    designated cube limit.  A LP is created for each item returned and
   --    the LP can have more than one case.  The returns processing will tie
   --    the putaway task together by the parent pallet id which is the
   --    T batch number.  One scan is made to initiate the returns putaway.
   --    The returns labor mgmt batches will be created then merged at scan
   --    time.  The difference between a MSKU and a return is that for a return
   --    the putaway labor mgmt batches are not created until the operator
   --    starts the putaway process, a LP can have more than one case and
   --    the parent batch number is the T batch.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/12/03 prpbcb   Oracle 7 rs239a DN none.  Does not exist on
   --                                                oracle 7.
   --                      Oracle 8 rs239b dvlp8 DN  Does not exist here.
   --                      Oracle 8 rs239b dvlp9 DN  11416
   --                      Initial creation.
   --
   --                      The process of merging batches is done in one
   --                      swoop with SQL statements.  The code is just about
   --                      duplicated in the different procedures that do the
   --                      merging for PUTs, NDM and DMD.  Another approach
   --                      would be to go record by record and call a common
   --                      procedure to do the merge.  This is a more modular
   --                      approach at the expense of execution time.  If time
   --                      permits I will investigate using a common procedure.
   --
   --                      In merging the batches the goal/target time of the
   --                      child batches are not added to that of the parent
   --                      because a forklift labor mgmt batch has the
   --                      goal/target time calculated at batch completion.
   --                      Procedure merge_putawat_batches has this code
   --                      commented out.  The other procedures do not have
   --                      the code.  If in the future we use a common
   --                      procedure to do the merging then this may change.
   --                      The function in lm_forklift.pc that does the merging
   --                      for non-msku batches does add the goal/target time
   --                      to the parent batch but this is not really
   --                      necessary.
   --
   --    12/05/03 prpbcb   Oracle 7 rs239a DN none.  Does not exist here.
   --                      Oracle 8 rs239b dvlp8 DN  Does not exist here.
   --                      Oracle 8 rs239b dvlp9 DN  11444
   --                      Add procedure pallet_substitution to update the
   --                      batch ref# for pallet substitution.
   --
   --                      Add procedure reset_letdown_batch to reset a
   --                      MSKU letdown down batch when the operator aborts
   --                      the operation with func1. 
   --                      A letdown batch is defined to be a NDM or DMD.
   --
   --    10/05/04 prpbcb   Oracle 7 rs239a DN  None
   --                      Oracle 8 rs239b swms8 None
   --                      Oracle 8 rs239b swms9 DN _____
   --                      Func1 processing changes in procedure
   --                      reset_letdown_batch().
   --
   --    02/01/05          Oracle 8 rs239b swms9 DN 11879
   --                      Returns putaway changes.
   --                      Modified procedures:
   --                         - merge_batches()
   --                         - merge_putaway_batches()
   --
   --                      When the operator is ready to putaway the returns
   --                      LP's and scans one of the LP's the T batch will
   --                      become the active batch and the putaway batches
   --                      will be child batches of the T batch.
   --
   --    03/10/05          Oracle 8 rs239b swms9 DN 11884
   --                      More returns putaway changes.
   --                      Renamed procedure calculate_data_capture to
   --                      calculate_kvi_values.
   --
   --    03/15/05          Oracle 8 rs239b swms9 DN 11887
   --                      More returns putaway changes and RDC MSKU changes.
   --                      Procedure calculate_kvi_values not always
   --                      calculating kvi_no_data_capture correctly.
   --                      Changed procedure calculate_kvi_values to clear
   --                      many of the KVI fields for the T batch.  The
   --                      returns T batch is used to tie the putaway batches
   --                      together.  It should have not have many of the
   --                      KVI values.
   --
   --    03/18/05          Oracle 8 rs239b swms9 DN 11892
   --                      More changes.
   --                      Change procedure calculate_kvi_values to set the
   --                      kvi_no_pallet and total_pallet to 0 for the child
   --                      batches of a HX batch (func1 in putaway).
   --
   --    03/03/06 prpbcb   Oracle 8 rs239b swms9 DN 12072
   --                      WAI changes.
   --                      Handle rule id 3.
   --                      Modified:
   --                         - update_msku_batch_info()
   --                         - create_msku_putaway_batches()
   --                      End WAI changes.
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
   -- Procedure:
   --    merge_batches
   --
   -- Description:
   --    This procedure merges all associated MSKU batches.  The associated
   --    batches are merged only if they are in future status.  For a MSKU
   --    only one scan is made to initiate the operation.  The MSKU can have
   --    one or more associated labor mgmt batches which need to be merged
   --    when the operation is started.
   --
   --    For example, if a mksu putaway has
   --    5 child LP's with 3 going to home slots and the rest going to
   --    reserve then there will be 3 labor mgmt batches for the putaway to
   --    the home slots (1 for each child LP) and 1 labor mgmt batch for the
   --    putaway to reserve.  The operator initiates the putaway of the MSKU
   --    by scanning any LP on the MSKU which could be a child LP or the
   --    parent LP.  When it is determined the LP is a MSKU this procedure is
   --    called to merge all associated putaway batches for the MSKU.  Before
   --    this procedure is called the operator would have been made active on
   --    one of the batches for the MSKU.  This prococedure takes the remaining
   --    batches for the MSKU and merges them.
   ---------------------------------------------------------------------------
   PROCEDURE merge_batches(i_batch_no  IN arch_batch.batch_no%TYPE);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    calculate_kvi_values
   --
   -- Description:
   --    This procedure calculates the KVI values for a MSKU batch that may
   --    have changed from what was used when the batch was first created.
   --    The values can change if the operator completes some of the drops
   --    for a MSKU batch then aborts with a func1.
   --
   --    The procedure should be called when the batch is being completed.
   ---------------------------------------------------------------------------
   PROCEDURE calculate_kvi_values(i_batch_no  IN arch_batch.batch_no%TYPE);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    pallet_substitution
   --
   -- Description:
   --    This procedure updates the batch ref# to the pallet substituted for
   --    a drop to a home slot.
   --
   --    For a MSKU pallet the system has designated what child LP's to drop
   --    but another child LP can be substituted as long as it meets the
   --    substitution requirements.  When a pallet is substituted the batch
   --    ref # needs to be updated to the substituted pallet.
   ---------------------------------------------------------------------------
   PROCEDURE pallet_substitution
                (i_batch_type             IN  VARCHAR2,
                 i_pallet_id              IN  putawaylst.pallet_id%TYPE,
                 i_substituted_pallet_id  IN  putawaylst.pallet_id%TYPE);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    reset_letdown_batch
   --
   -- Description:
   --    This procedure resets a MSKU letdown batch when the operator presses
   --    func1 to exit the operation.  A letdown batch is defined to be a
   --    non-demand or demand replenishment batch.
   --
   --    The process flow is:
   --       - For each batch where the operation was not completed reset
   --         the batch.  Ignore the FM (return to reserve) batch if it exists.
   --       - If operations were completed:
   --            - If the parent batch was not one of the completed operations:
   --                 - Select the batch number of one of the completed
   --                   operations to use as the new parent batch.  It does not
   --                   matter which completed operation is used.
   --                 - Update the status of the parent batch to 'A'.
   --                 - Update the child batches parent batch # to the new
   --                   parent batch #.
   --            - Delete the FM batch if it exists.
   --            - Recreate the FM batch.
   --       - If no operations were completed:
   --            - Delete the FM batch if it exists.
   --            - Set the o_parent_batch_no to null.
   ---------------------------------------------------------------------------
   PROCEDURE reset_letdown_batch
                      (i_batch_no         IN  arch_batch.batch_no%TYPE,
                       o_parent_batch_no  OUT arch_batch.batch_no%TYPE);

   ---------------------------------------------------------------------------
   -- Function:
   --    f_is_msku_batch
   --
   -- Description:
   --    This function determines if a batch is for a MSKU pallet.
   ---------------------------------------------------------------------------
   FUNCTION f_is_msku_batch(i_batch_no IN arch_batch.batch_no%TYPE)
   RETURN BOOLEAN;


END pl_lm_msku;  -- end package specification
/

SHOW ERRORS;


PROMPT Create package body: pl_lm_msku

/*************************************************************************/
-- Package Body
/*************************************************************************/
CREATE OR REPLACE PACKAGE BODY swms.pl_lm_msku
IS

   -- sccs_id=@(#) src/schema/plsql/pl_lm_msku.sql, swms, swms.9, 10.1.1 9/7/06 1.9

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lm_msku
   --
   -- Description:
   --    MSKU labor mgmt.
   --    This package has objects for MSKU labor mgmt.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/12/03 prpbcb   Oracle 7 rs239a DN none.  Does not exist on
   --                                                oracle 7.
   --                      Oracle 8 rs239b DN  ____
   --                      Initial creation.
   --
   ---------------------------------------------------------------------------

   ----------------------------------------------------------------------------
   -- Private Global Variables
   ----------------------------------------------------------------------------
   gl_pkg_name   VARCHAR2(20) := 'pl_lm_msku';   -- Package name.  Used in
                                                 -- error messages.

   gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                    -- function is null.

   ----------------------------------------------------------------------------
   -- Private Constants
   ----------------------------------------------------------------------------


   ----------------------------------------------------------------------------
   -- Private Modules
   ----------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Procedure:
   --    merge_putaway_batches
   --
   -- Description:
   --    This procedure merges all associated MSKU putaway batches and also
   --    merges the associated returns putaway batches.
   --
   --    Returns putaway is very similar to a RDC MSKU.  Returns are
   --    accumulated on a physical pallet until the pallet reaches a
   --    designated cube limit.  A LP is created for each item returned and
   --    the LP can have more than one case.  The returns processing will tie
   --    the putaway task together by the parent pallet id which is the
   --    T batch number.  The difference for a return is the putaway labor
   --    mgmt batches are not created until the operator starts the putaway
   --    process and a LP can have more than one case.  One scan is made to
   --    initiate the returns putaway.  The returns labor mgmt batches will be
   --    created then merged at scan time.
   --
   --    The associated batches are merged only if they are in future status.
   --    For a MSKU or returns only one scan is made to initiate the putaway
   --    operation.  The MSKU or returns pallet can have one or more associated
   --    labor mgmt batches which need to be merged when the operation is
   --    started.
   --
   --    For example, if a mksu putaway has
   --    5 child LP's with 3 going to home slots and the rest going to
   --    reserve then there will be 3 labor mgmt batches for the putaway to
   --    the home slots (1 for each child LP) and 1 labor mgmt batch for the
   --    putaway to reserve.  The operator initiates the putaway of the MSKU
   --    by scanning any LP on the MSKU which could be a child LP or the
   --    parent LP.  When it is determined the LP is a MSKU this procedure is
   --    called to merge all associated putaway batches for the MSKU.  Before
   --    this procedure is called the operator would have been made  active on
   --    one of the batches for the MSKU.  This prococedure takes the remaining
   --    batches for the MSKU and merges them.
   --
   -- Parameters:
   --    i_batch_no       - A MSKU batch number.  This will be the parent
   --                       batch.  It needs to be the batch the user was
   --                       first assigned to and be the active batch.
   --                       It must be a putaway batch.
   --                       The MSKU can have one or more labor mgmt
   --                       batches associated with it. 
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null, i_batch_no is not
   --                               a putaway batch.
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Called by:
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/13/03 prpbcb   Created.
   --    02/18/05 prpbcb   Changes for returns putaway.
   --                      Allow the i_batch_no to be a T batch.
   --                      When the operator is ready to putaway the returns
   --                      LP's and scans one of the LP's the T batch will
   --                      become the active batch and the putaway batches
   --                      will be child batches of the T batch.
   ---------------------------------------------------------------------------
   PROCEDURE merge_putaway_batches(i_batch_no  IN arch_batch.batch_no%TYPE)
   IS
      l_message      VARCHAR2(512);    -- Message buffer
      l_object_name  VARCHAR2(61) := gl_pkg_name || '.merge_putaway_batches';

      l_batch_type   VARCHAR2(10);  -- The batch type of i_batch_no.
                                    -- It needs to be a putaway batch.
      l_batch_date   arch_batch.batch_date%TYPE;  -- parent batch batch date
      l_goal_time    arch_batch.goal_time%TYPE := 0;  -- parent batch goal time
      l_status       arch_batch.status%TYPE;      -- parent batch status
      l_sysdate      arch_batch.actl_start_time%TYPE;
      l_target_time  arch_batch.target_time%TYPE := 0; -- parent batch target time
      l_user_id      arch_batch.user_id%TYPE;     -- parent batch user id

      -- This cursor selects the putaway labor mgmt batches to merge.
      -- Only future batches are merged.  It is possible some of the batches
      -- are completed because the operator could have completed some then
      -- did a func1.
      /*
      ** 11/05/03 prpbcb Cursor not used at this time.
      **
      CURSOR c_putaway_batches(cp_batch_no arch_batch.batch_no%TYPE) IS
         SELECT DISTINCT p2.pallet_batch_no
           FROM batch b,
                putawaylst p2,
                putawaylst p
          WHERE p2.parent_pallet_id = p.parent_pallet_id
            AND p.pallet_batch_no   = cp_batch_no
            AND b.batch_no          = p2.pallet_batch_no
            AND b.status            = 'F';    -- Only future batches
      */

      e_batch_not_active   EXCEPTION;  -- i_batch_no is not an active batch.
      e_not_putaway_batch  EXCEPTION;  -- The batch is not a putaway batch.

   BEGIN
      -- Check if parameter is null.
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- Get the batch type.
      l_batch_type := pl_lmc.get_batch_type(i_batch_no);

      -- The batch has to be a putaway batch or a returns putaway batch.
      IF (   l_batch_type = pl_lmc.ct_forklift_putaway
          OR l_batch_type = pl_lmc.ct_returns_putaway) THEN
         NULL;
      ELSE
         RAISE e_not_putaway_batch;
      END IF;

      -- Get info about the batch.  This is the parent batch.
      SELECT b.status, b.batch_date, b.user_id, SYSDATE
        INTO l_status, l_batch_date, l_user_id, l_sysdate
        FROM batch b
       WHERE b.batch_no = i_batch_no;
 
      IF (SQL%NOTFOUND) THEN
         -- Did not find the batch.
         RAISE pl_exc.e_no_lm_parent_found;
      END IF;

      IF (l_status != 'A') THEN
         -- The batch is not active.
         RAISE e_batch_not_active;
      END IF;

      -- Get the goal/target time of the batches to merge.  They will be
      -- added to the parent batch goal/target time.
      /* 11/05/03 prpbcb  Leave this out for now because a forklift labor mgmt
                          batch has the goal/target time calculated at
                          batch completion time.
      */
      /*
      SELECT NVL(SUM(NVL(b.target_time, 0)), 0) target_time,
             NVL(SUM(NVL(b.goal_time, 0)), 0)   goal_time
        INTO l_target_time,
             l_goal_time
        FROM batch b
       WHERE b.status = 'F'
         AND b.batch_no IN
                (SELECT p2.pallet_batch_no
                   FROM putawaylst p2,
                        putawaylst p
                  WHERE p2.parent_pallet_id = p.parent_pallet_id
                    AND p.pallet_batch_no   = i_batch_no);
      */

      -- Merge the MSKU batches.
      -- 02/18/05 prpbcb Modified to handle the T batch for returns putaway.
      --                 The T batch will not be in putawaylst.pallet_batch_no
      --                 because the T batch is not tied to any one pallet but
      --                 the T batch is the parent pallet id.
      UPDATE batch b
         SET b.status            = 'M',
             b.actl_start_time   = l_sysdate,
             b.actl_stop_time    = l_sysdate,
             b.parent_batch_no   = i_batch_no,
             b.parent_batch_date = l_batch_date,
             b.goal_time         = 0,
             b.target_time       = 0,
             b.total_count       = 0,
             b.total_pallet      = 0,
             b.total_piece       = 0,
             b.user_id           = l_user_id
       WHERE b.status = 'F'
         AND b.batch_no IN
                (SELECT p2.pallet_batch_no
                   FROM putawaylst p2,
                        putawaylst p
                  WHERE p2.parent_pallet_id = p.parent_pallet_id
                    AND (   p.pallet_batch_no = i_batch_no
                         OR (    l_batch_type = pl_lmc.ct_returns_putaway
                             AND p.parent_pallet_id = i_batch_no)));

      -- It is possible there are no batches to merge.  An example is when the
      -- the MSKU is going directly to reserve.
      IF (SQL%FOUND) THEN
         -- Add the merged batche goal/target times to the parent batch.
         UPDATE batch b
          SET b.goal_time = NVL(b.goal_time,0) + l_goal_time,
              b.target_time = NVL(b.target_time,0) + l_target_time
         WHERE b.batch_no = i_batch_no;

         IF (SQL%NOTFOUND) THEN
            -- Failed to update the parent batch.
            RAISE pl_exc.e_no_lm_parent_found;
         END IF;

         -- Make the batch a parent
         pl_lmf.make_batch_parent(i_batch_no); 
      END IF;

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
                      '  Parameter i_batch_no is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_not_putaway_batch THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || ']' ||
                            '  The batch is not a putaway batch.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_batch_not_active THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || ']' ||
                            '  Batch status[' || l_status || ']' ||
                            '  The batch is not active.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
            l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';
         IF (SQLCODE <= -20000) THEN
             l_message := l_message ||
                         '  Called object raised an user defined exception.';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;


   END merge_putaway_batches;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    merge_nondemand_rpl_batches
   --
   -- Description:
   --    This procedure merges all associated MSKU non-demand replenishment
   --    batches and merges the return to reserve batch if the MSKU is
   --    going back to reserve after the replenishments are completed.
   --
   --    The associated batches are merged only if they are in future status.
   --    For a MSKU only one scan is made to initiate the operation.  The MSKU
   --    can have one or more associated labor mgmt batches which need to be
   --    merged when the operation is started.
   --
   -- Parameters:
   --    i_batch_no       - The MSKU batch number.
   --                       It must be a putaway batch.
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null.
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Called by:
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/13/03 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE merge_nondemand_rpl_batches
                                   (i_batch_no  IN arch_batch.batch_no%TYPE)
   IS
      l_message      VARCHAR2(256);    -- Message buffer
      l_object_name  VARCHAR2(61) := gl_pkg_name ||
                                             '.merge_nondemand_rpl_batches';

      l_batch_type   VARCHAR2(10);  -- The batch type of i_batch_no.
                                    -- It needs to be a putaway batch.
      l_batch_date   arch_batch.batch_date%TYPE;  -- parent batch batch date
      l_status       arch_batch.status%TYPE;      -- parent batch status
      l_sysdate      arch_batch.actl_start_time%TYPE;
      l_user_id      arch_batch.user_id%TYPE;     -- parent batch user id

      -- This cursor selects the non-demand replenishment labor mgmt batches
      -- to merge.
      -- Only future batches are merged.  It is possible some of the batches
      -- are completed because the operator could have completed some then
      -- did a func1.
      /*
      ** 11/05/03 prpbcb No cursor used at this time.
      */

      e_batch_not_active   EXCEPTION;  -- i_batch_no is not an active batch.
      e_not_ndm_batch  EXCEPTION;      -- The batch is not a NDM batch.

   BEGIN
      -- Check if parameter is null.
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- The batch has to be a NDM batch.
      l_batch_type := pl_lmc.get_batch_type(i_batch_no);
      IF (   l_batch_type != pl_lmc.ct_forklift_nondemand_rpl
          OR l_batch_type IS NULL) THEN
         RAISE e_not_ndm_batch;
      END IF;

      -- Get info about the batch.  This is the parent batch.
      SELECT b.status, b.batch_date, b.user_id, SYSDATE
        INTO l_status, l_batch_date, l_user_id, l_sysdate
        FROM batch b
       WHERE b.batch_no = i_batch_no;
 
      IF (SQL%NOTFOUND) THEN
         -- Did not find the batch.
         RAISE pl_exc.e_no_lm_parent_found;
      END IF;

      IF (l_status != 'A') THEN
         -- The batch is not active.
         RAISE e_batch_not_active;
      END IF;

      -- Merge the MSKU batches.
      UPDATE batch b
         SET b.status            = 'M',
             b.actl_start_time   = l_sysdate,
             b.actl_stop_time    = l_sysdate,
             b.parent_batch_no   = i_batch_no,
             b.parent_batch_date = l_batch_date,
             b.goal_time         = 0,
             b.target_time       = 0,
             b.total_count       = 0,
             b.total_pallet      = 0,
             b.total_piece       = 0,
             b.user_id           = l_user_id
       WHERE b.status = 'F'
         AND b.batch_no IN
         (SELECT b1.batch_no
            FROM replenlst r1,  -- For selecting the other MSKU batches.
                 replenlst r2,  -- For the current batch.
                 batch b1,      -- For selecting the other MSKU batches.
                 batch b2       -- For the current batch.
           WHERE r2.task_id = SUBSTR(b2.batch_no, 3)  -- The task for the
                                                      -- current batch
             AND r2.type = 'NDM'             -- Needs to be a NDM
             AND r1.type = r2.type
             AND r1.src_loc = r2.src_loc     -- Match up location to use index
             AND r1.parent_pallet_id = r2.parent_pallet_id
             AND b1.batch_no = l_batch_type || LTRIM(RTRIM(TO_CHAR(r1.task_id)))
             AND b2.batch_no = i_batch_no
             AND b1.batch_no != b2.batch_no); -- Don't select the current batch

      -- It is possible there are no batches to merge.  An example is when 
      -- only one MSKU is being replenished.
      IF (SQL%FOUND) THEN
         -- Make the batch a parent.
         pl_lmf.make_batch_parent(i_batch_no); 
      END IF;

      --  Create/merge the return to reserve batch if necessary.
      pl_lmf.create_return_to_reserve_batch(i_batch_no);

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
                      '  Parameter i_batch_no is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_not_ndm_batch THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || ']' ||
                     '  The batch is not a non-demand replenishment batch.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_batch_not_active THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || ']' ||
                            '  Batch status[' || l_status || ']' ||
                            '  The batch is not active.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
            l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';
         IF (SQLCODE <= -20000) THEN
             l_message := l_message ||
                         '  Called object raised an user defined exception.';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END merge_nondemand_rpl_batches;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    merge_demand_rpl_batches
   --
   -- Description:
   --    This procedure merges all associated MSKU demand replenishment
   --    batches and merges the return to reserve batch if the MSKU is
   --    going back to reserve after the replenishments are completed.
   --
   --    The associated batches are merged only if they are in future status.
   --    For a MSKU only one scan is made to initiate the operation.  The MSKU
   --    can have one or more associated labor mgmt batches which need to be
   --    merged when the operation is started.
   --
   -- Parameters:
   --    i_batch_no       - The MSKU batch number.
   --                       It must be a putaway batch.
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null.
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Called by:
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/13/03 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE merge_demand_rpl_batches
                                   (i_batch_no  IN arch_batch.batch_no%TYPE)
   IS
      l_message      VARCHAR2(256);    -- Message buffer
      l_object_name  VARCHAR2(61) := gl_pkg_name ||
                                             '.merge_demand_rpl_batches';

      l_batch_type   VARCHAR2(10);  -- The batch type of i_batch_no.
                                    -- It needs to be a putaway batch.
      l_batch_date   arch_batch.batch_date%TYPE;  -- parent batch batch date
      l_status       arch_batch.status%TYPE;      -- parent batch status
      l_sysdate      arch_batch.actl_start_time%TYPE;
      l_user_id      arch_batch.user_id%TYPE;     -- parent batch user id

      -- This cursor selects the demand replenishment labor mgmt batches
      -- to merge.
      -- Only future batches are merged.  It is possible some of the batches
      -- are completed because the operator could have completed some then
      -- did a func1.
      /*
      ** 11/05/03 prpbcb No cursor used at this time.
      */

      e_batch_not_active   EXCEPTION;  -- i_batch_no is not an active batch.
      e_not_dmd_batch  EXCEPTION;      -- The batch is not a NDM batch.

   BEGIN
      -- Check if parameter is null.
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- The batch has to be a DMD batch.
      l_batch_type := pl_lmc.get_batch_type(i_batch_no);
      IF (   l_batch_type != pl_lmc.ct_forklift_demand_rpl
          OR l_batch_type IS NULL) THEN
         RAISE e_not_dmd_batch;
      END IF;

      -- Get info about the batch.  This is the parent batch.
      SELECT b.status, b.batch_date, b.user_id, SYSDATE
        INTO l_status, l_batch_date, l_user_id, l_sysdate
        FROM batch b
       WHERE b.batch_no = i_batch_no;
 
      IF (SQL%NOTFOUND) THEN
         -- Did not find the batch.
         RAISE pl_exc.e_no_lm_parent_found;
      END IF;

      IF (l_status != 'A') THEN
         -- The batch is not active.
         RAISE e_batch_not_active;
      END IF;

      -- Merge the MSKU batches.
      UPDATE batch b
         SET b.status            = 'M',
             b.actl_start_time   = l_sysdate,
             b.actl_stop_time    = l_sysdate,
             b.parent_batch_no   = i_batch_no,
             b.parent_batch_date = l_batch_date,
             b.goal_time         = 0,
             b.target_time       = 0,
             b.total_count       = 0,
             b.total_pallet      = 0,
             b.total_piece       = 0,
             b.user_id           = l_user_id
       WHERE b.status = 'F'
         AND b.batch_no IN
       (SELECT b1.batch_no
          FROM floats f1,  -- For selecting the other MSKU batches.
               floats f2,  -- For the current batch.
               float_detail fd1,  -- For using an index
               float_detail fd2,  -- For using an index
               batch b1,      -- For selecting the other MSKU batches.
               batch b2       -- Current batch
         WHERE f2.float_no = SUBSTR(b2.batch_no, 3)  -- the float for the
                                                     -- current batch
           AND f2.pallet_pull = 'R'    
           AND f1.pallet_pull = f2.pallet_pull
           AND f1.parent_pallet_id = f2.parent_pallet_id
           AND b1.batch_no = l_batch_type || LTRIM(RTRIM(TO_CHAR(f1.float_no)))
           AND b2.batch_no = i_batch_no
           AND fd1.float_no = f1.float_no
           AND fd2.float_no = f2.float_no
           AND fd1.src_loc = fd2.src_loc    -- Match up location to use index
           AND b1.batch_no != b2.batch_no); -- Don't select the current batch

      -- It is possible there are no batches to merge.  An example is when the
      -- the MSKU is going directly to reserve.
      IF (SQL%FOUND) THEN
         -- Make the parent batch a parent
         pl_lmf.make_batch_parent(i_batch_no); 
      END IF;

      --  Create/merge the return to reserve batch if necessary.
      pl_lmf.create_return_to_reserve_batch(i_batch_no);

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
                      '  Parameter i_batch_no is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_not_dmd_batch THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || ']' ||
                        '  The batch is not a demand replenishment batch.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_batch_not_active THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || ']' ||
                            '  Batch status[' || l_status || ']' ||
                            '  The batch is not active.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
            l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';
         IF (SQLCODE <= -20000) THEN
             l_message := l_message ||
                         '  Called object raised an user defined exception.';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END merge_demand_rpl_batches;


   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Procedure:
   --    merge_batches
   --
   -- Description:
   --    This procedure merges all associated MSKU batches.  The associated
   --    batches are merged only if they are in future status.  For a MSKU
   --    only one scan is made to initiate the operation.  The MSKU can have
   --    one or more associated labor mgmt batches which need to be merged
   --    when the operation is started.
   --
   --    For example, if a mksu putaway has
   --    5 child LP's with 3 going to home slots and the rest going to
   --    reserve then there will be 3 labor mgmt batches for the putaway to
   --    the home slots (1 for each child LP) and 1 labor mgmt batch for the
   --    putaway to reserve.  The operator initiates the putaway of the MSKU
   --    by scanning any LP on the MSKU which could be a child LP or the
   --    parent LP.  When it is determined the LP is a MSKU this procedure is
   --    called to merge all associated putaway batches for the MSKU.  Before
   --    this procedure is called the operator would have been made active on
   --    one of the batches for the MSKU.  This prococedure takes the remaining
   --    batches for the MSKU and merges them.
   --
   -- Parameters:
   --    i_batch_no       - The batch number the operator is active on.
   --                       For returns putaway this will be the T batch.
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null.
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Called by:
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/13/03 prpbcb   Created.
   --    02/18/05 prpbcb   Chamges for returns putaway.
   --                      When the operator is ready to putaway the returns
   --                      LP's and scans one of the LP's the T batch will
   --                      become the active batch and the putaway batches
   --                      will be child batches of the T batch.
   ---------------------------------------------------------------------------
   PROCEDURE merge_batches(i_batch_no  IN arch_batch.batch_no%TYPE)
   IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.merge_batches';

      l_batch_type     VARCHAR2(10); -- The batch type of i_batch_no

      e_no_batch_type         EXCEPTION;  -- Could not determine what type of
                                          -- batch i_batch_no is.
      e_unhandled_batch_type  EXCEPTION;  -- The type of batch is not
                                          -- handled in this function.
   BEGIN

      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- Find out what type of batch it is.
      l_batch_type := pl_lmc.get_batch_type(i_batch_no);

      IF (l_batch_type IS NULL) THEN
         RAISE e_no_batch_type;  -- Do not know the type of batch.
      END IF;

      -- Merge batches if a MSKU batch.
      IF (pl_lm_msku.f_is_msku_batch(i_batch_no)) THEN
         -- Merge the associated batches.  Each type of batch has its own
         -- procedure to do the merge.
         IF (l_batch_type = pl_lmc.ct_forklift_putaway) THEN
            merge_putaway_batches(i_batch_no);
         ELSIF (l_batch_type = pl_lmc.ct_forklift_nondemand_rpl) THEN
            merge_nondemand_rpl_batches(i_batch_no);
         ELSIF (l_batch_type = pl_lmc.ct_forklift_demand_rpl) THEN
            merge_demand_rpl_batches(i_batch_no);
         ELSIF (l_batch_type = pl_lmc.ct_returns_putaway) THEN
            merge_putaway_batches(i_batch_no);
         ELSE
            -- Only concerned with merging MSKU batches for putaway,
            -- non-demand repls and demand repls.  The other batch types such
            -- as a transfer will only have one labor batch for the MSKU.
            NULL;
         END IF;
      END IF;

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
                      '  Parameter i_batch_no is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN e_no_batch_type THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
             '  Could not determine what type of batch it is.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_unhandled_batch_type THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
             '  Batch type[' || l_batch_type || ']' ||
             ' not handled in this procedure.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])'||
                         '  Called object raised an user defined exception.';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            l_message := l_object_name || '(i_batch_no[' || i_batch_no || ']';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END merge_batches;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    calculate_kvi_values
   --
   -- Description:
   --    This procedure calculates/adjusts the KVI values for a MSKU batch
   --    that may have changed from what was used when the batch was first
   --    created in pl_lmf.create_msku_putaway_batches.
   --    The values can change if the operator completes some of the drops
   --    for a MSKU batch then aborts with a func1.
   --
   --    The procedure should be called when the batch is being completed.
   --
   --    The values calculated/adjusted are are:
   --        - kvi_no_pallet       Set to 1 for the parent batch.  Set to 0
   --                              for the child batches.
   --        - kvi_no_data_capture
   --        - total_pallet        Set to 1 for the parent batch.  Set to 0
   --                              for the child batches.  For returns the
   --                              parent T batch owns the pallet.
   --
   --    The values for kvi_no_data_capture for the batches will be as follows:
   --       If the MSKU is going to a home/floating slot(s) then possibly a
   --       reserve slot:
   --          There will be a batch for each LP going to the home/floating
   --          slot and one batch for the reserve slot(if going to reserve).
   --                
   --          3 For the first batch going to a home/floating slot.  This is
   --            for the scan of the MSKU at the pickup location plus the scan
   --            of the home/floating slot plus the scan of the LP.
   --          2 For the next batch going to the next home/floating slot.
   --            This is for the scan of the home/floating slot plus the scan
   --            of the LP.
   --
   --          1 For subsequent batches to the same home or floating slot.  This
   --            is for the scan of the LP.
   --          1 For the reserve batch if the MSKU is going to reserve.  This
   --             is for the scan of the reserve slot.
   --
   --       If the MSKU is going straight to a reserve slot:
   --          2 This is for the scan of the MSKU at the pickup location plus
   --            the scan of the reserve slot.
   --
   --    Procedure pl_lmf.create_msku_putaway_batches follows the same logic.
   --
   --    Example of what the data capture will be for a MSKU going to two
   --    different home slots, then a floating slot then to reserve.
   --
   --                                               Create Batch   kvi_no_data_
   --      LP       Parent LP  Dest Loc  Home Slot  for LP         capture
   --      -------  ---------  --------  ---------  -------------  -----------
   --      123        555      DA01A1       Yes        Yes            3
   --      124        555      DA01A1       Yes        Yes            1
   --      125        555      DA01A1       Yes        Yes            1
   --      126        555      DA05B1       Yes        Yes            2
   --      127        555      DA05B1       Yes        Yes            1
   --      200        555      DA10A2       Floating   Yes            2
   --      201        555      DA10A2       Floating   Yes            1
   --      128        555      DA12A5       No         No   -+
   --      129        555      DA12A5       No         No    |        1
   --      130        555      DA12A5       No         No    |
   --      131        555      DA12A5       No         No    | One batch created
   --      132        555      DA12A5       No         No    | for the pallets
   --      133        555      DA12A5       No         No    | going to a
   --      135        555      DA12A5       No         No   -+ reserve slot.
   --
   -- Parameters:
   --    i_batch_no   - The MSKU batch number.  For merged batches
   --                   this will be the parent batch number.
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null.
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Called by:
   --    - lm_goaltime.pc
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    11/08/03 prpbcb   Created.
   --    03/15/05 prpbcb   Added selecting the rule_id and processing floating
   --                      slots the same as home slots.
   --                      Changed to clear many of the KVI fields for the
   --                      a T batch.  The T batch is used to tie the returns
   --                      putaway batches together.  It should have not have
   --                      many of the KVI values.   The creation of the T
   --                      batch may have populated the KVI's.
   --    03/03/06 prpbcb   Handle rule id 3 same as floating.
   ---------------------------------------------------------------------------
   PROCEDURE calculate_kvi_values(i_batch_no  IN arch_batch.batch_no%TYPE)
   IS
      l_message      VARCHAR2(512);    -- Message buffer
      l_object_name  VARCHAR2(61) := gl_pkg_name || '.calculate_kvi_values';

      l_batch_type     VARCHAR2(10);  -- The batch type of i_batch_no.
      l_data_capture   arch_batch.kvi_no_data_capture%TYPE;  -- Data capture
      l_prev_dest_loc  arch_batch.kvi_to_loc%TYPE := 'x';    -- The previous
                                                   -- destination location.
      e_no_batch_type         EXCEPTION;  -- Could not determine what type of
                                          -- batch i_batch_no is.


      -- This cursor selects the batches to process.
      CURSOR c_batch(cp_batch_no  arch_batch.batch_no%TYPE) IS
         SELECT b.batch_no, l.perm, b.kvi_to_loc, z.rule_id, b.ROWID
           FROM zone z, lzone lz, loc l, batch b
          WHERE b.msku_batch_flag = 'Y'
            AND l.logi_loc = b.kvi_to_loc
            AND (   b.batch_no = cp_batch_no
                 OR b.parent_batch_no = cp_batch_no)
            AND lz.logi_loc = b.kvi_to_loc
            AND z.zone_id = lz.zone_id
            AND z.zone_type = 'PUT'
          ORDER BY DECODE(l.perm, 'Y', '1',
                          DECODE(LTRIM(RTRIM(TO_CHAR(z.rule_id))),
                                 '1', '1', 
                                 '3', '1', 
                                 '2')),
                b.kvi_to_loc, b.ref_no;

   BEGIN
      -- Check if parameter is null.
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- Calculate the data capture.
      FOR r_batch IN c_batch(i_batch_no) LOOP
         IF (r_batch.perm = 'Y' OR r_batch.rule_id IN (1, 3)) THEN
            IF (r_batch.kvi_to_loc != l_prev_dest_loc) THEN
               IF (c_batch%ROWCOUNT = 1) THEN
                  -- The first batch selected and it is going to a
                  -- home/floating slot.  The data capture is for the scan of
                  -- the MSKU at the pickup location, the scan of the
                  -- home/floating slot and the scan of the LP.
                  l_data_capture := 3;
               ELSE
                  -- Then next batch going to a different home/floating slot.
                  -- The data capture is for the scan of the home/floating slot
                  -- and the scan of the LP.
                  l_data_capture := 2;
               END IF;
            ELSE
               -- Not the first batch to the home/floating slot.
               -- The data capture is for the scan of the LP.
               l_data_capture := 1;
            END IF;
         ELSE
            -- Batch going to reserve.
            IF (c_batch%ROWCOUNT = 1) THEN
               -- The MSKU is going directly to reserve.
               -- The data capture is for the scan at the pickup location and
               -- the scan of the reserve location.
               l_data_capture := 2; 
            ELSE
               -- Home/floating slots were visited first.
               -- The data capture is for the scan of the reserve location.
               l_data_capture := 1; 
            END IF;
         END IF;

         UPDATE batch
            SET kvi_no_data_capture = l_data_capture
          WHERE ROWID = r_batch.ROWID;

          l_prev_dest_loc := r_batch.kvi_to_loc;

      END LOOP;

      -- Find out what type of batch it is.
      l_batch_type := pl_lmc.get_batch_type(i_batch_no);

      IF (l_batch_type IS NULL) THEN
         RAISE e_no_batch_type;  -- Do not know the type of batch.
      END IF;

      IF (l_batch_type = pl_lmc.ct_forklift_putaway OR
          l_batch_type = pl_lmc.ct_forklift_f1_haul) THEN
         -- Regular MSKU putaway batch or haul batch created by func1
         -- in MSKU putaway.
         UPDATE batch
            SET kvi_no_pallet  = 1,
                total_pallet   = 1
          WHERE batch_no = i_batch_no;

         UPDATE batch
            SET kvi_no_pallet = 0,
                total_pallet  = 0
          WHERE parent_batch_no = i_batch_no
            AND parent_batch_no != batch_no;

      ELSIF (l_batch_type = pl_lmc.ct_returns_putaway) THEN
         -- Returns T batch.
         -- Clear many of the KVI fields if a returns T batch and set others.
         -- The T batch is used to tie the putaway batches together.  It should
         -- have not have many of the KVI values.  The T batch will own the
         -- physical pallet which is why kvi_no_pallet and total_pallet are
         -- set to 1.
         UPDATE batch
            SET kvi_cube            = NULL,
                kvi_wt              = NULL,
                kvi_no_piece        = NULL,
                kvi_no_pallet       = 1,
                kvi_no_case         = NULL,
                kvi_no_split        = NULL,
                kvi_no_item         = NULL,
                kvi_no_po           = NULL,
                kvi_no_loc          = NULL,
                kvi_no_data_capture = NULL,
                total_pallet        = 1
          WHERE batch_no = i_batch_no;

         UPDATE batch
            SET kvi_no_pallet = 0,
                total_pallet  = 0
          WHERE parent_batch_no = i_batch_no
            AND parent_batch_no != batch_no;

         /*
         IF (SQL%NOTFOUND) THEN
            -- No row updated.  This is a fatal error.
            l_message := 'TABLE=batch  ACTION=UPDATE' ||
                     ' KEY=' ||  i_batch_no || '(i_batch_no)' ||
                     ' MESSAGE="SQL%NOTFOUND true.  Failed to update' ||
                     ' the batch KVI values.';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                           l_message, pl_exc.ct_putawaylst_update_fail,
                                    NULL);
            RAISE pl_exc.e_lm_batch_upd_fail;
         END IF;
         */
      END IF;

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
                      '  Parameter i_batch_no is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_no_batch_type THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
             '  Could not determine what type of batch it is.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';
         IF (SQLCODE <= -20000) THEN
            l_message := 'User defined exception.';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;
   END calculate_kvi_values;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    pallet_substitution
   --
   -- Description:
   --    This procedure updates the batch ref# to the pallet substituted for
   --    a drop to a home slot when forklift labor mgmt is active.
   --
   --    For a MSKU pallet the system has designated what child LP's to drop
   --    but another child LP can be substituted as long as it meets the
   --    substitution requirements.  When a pallet is substituted the batch
   --    ref # needs to be updated to the substituted pallet.
   --
   --    When substituting a pallet for a putaway the putawaylst.pallet_batch_no
   --    needs to be switched for the two pallets.  This pallet_batch_no is
   --    the labor mgmt putaway batch.
   --
   --    An error will not be a fatal error except if a paremeter is null.
   --    This is a judgement call to not error out.  A swms log message is
   --    written and processing will continue as usual.
   --
   -- Parameters:
   --    i_batch_type             - The type of batch.  Putaway, NDM, etc.
   --                               The calling object should know this.
   --    i_pallet_id              - The original pallet.
   --    i_substituted_pallet_id  - The substituted pallet.
   --    
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null.
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Called by:
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    12/03/03 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE pallet_substitution
                (i_batch_type             IN  VARCHAR2,
                 i_pallet_id              IN  putawaylst.pallet_id%TYPE,
                 i_substituted_pallet_id  IN  putawaylst.pallet_id%TYPE)
   IS
      l_message      VARCHAR2(512);    -- Message buffer
      l_object_name  VARCHAR2(61) := gl_pkg_name || '.pallet_substitution';

      l_hold_pallet_batch_no_1  putawaylst.pallet_batch_no%TYPE;  -- Work area
      l_hold_pallet_batch_no_2  putawaylst.pallet_batch_no%TYPE;  -- Work area

   BEGIN
      -- Check if a parameter is null.
      IF (   i_batch_type IS NULL
          OR i_pallet_id IS NULL
          OR i_substituted_pallet_id IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- Update the batch when forklift labor mgmt is active.
      IF (pl_lmf.f_forklift_active) THEN

         -- For a putaway the putawaylst.pallet_batch_no needs to be
         -- swithced for the two pallets.  For other batch types the batch
         -- number is not stored in the "operation" table such as in the
         -- REPLENLST table for NDM. 
         IF (i_batch_type = pl_lmc.ct_forklift_putaway) THEN
            SELECT pallet_batch_no INTO l_hold_pallet_batch_no_1
               FROM putawaylst
              WHERE pallet_id = i_pallet_id;

            SELECT pallet_batch_no INTO l_hold_pallet_batch_no_2
               FROM putawaylst
              WHERE pallet_id = i_substituted_pallet_id;

            UPDATE putawaylst
               SET pallet_batch_no = l_hold_pallet_batch_no_2
             WHERE pallet_id = i_pallet_id;

            UPDATE putawaylst
               SET pallet_batch_no = l_hold_pallet_batch_no_1
             WHERE pallet_id = i_substituted_pallet_id;
         END IF;

         -- Update the batch ref# to the substituted pallet.  The batch should
         -- be either active or merged.
         UPDATE batch
            SET ref_no = i_substituted_pallet_id
          WHERE batch_no LIKE i_batch_type || '%'
            AND ref_no = i_pallet_id
            AND status IN ('A', 'M');

         IF (SQL%NOTFOUND) THEN
            -- No row updated.  Write a swms log message.
            l_message := 'TABLE=batch  ACTION=UPDATE' ||
               ' i_batch_type[' || i_batch_type || ']' ||
               ' i_pallet_id[' || i_pallet_id || ']' ||
               ' Status A or M' ||
               '  i_substituted_pallet_id[' || i_substituted_pallet_id || ']' ||
               '  MESSAGE="No batch record updated.  This will not stop' ||
               ' processing."';

            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                           pl_exc.ct_lm_batch_upd_fail, NULL);
         END IF;
      END IF;  -- end forklift active

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name ||
             '(i_batch_type[' || i_batch_type || ']' ||
             ',i_pallet_id[' || i_pallet_id || ']' ||
             ',i_substituted_pallet_id[' || i_substituted_pallet_id || '])' ||
                      '  A parameter is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name ||
             '(i_batch_type[' || i_batch_type || ']' ||
             ',i_pallet_id[' || i_pallet_id || ']' ||
             ',i_substituted_pallet_id[' || i_substituted_pallet_id || '])' ||
            ' This will not stop processing';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
         -- Don't make this a fatal error.
         -- RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
         --                      l_object_name || ': ' || SQLERRM);
   END pallet_substitution;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    reset_letdown_batch
   --
   -- Description:
   --    This procedure resets a MSKU letdown batch when the operator presses
   --    func1 to exit the operation.  A letdown batch is defined to be a
   --    non-demand or demand replenishment batch.
   --
   --    The process flow is:
   --       - For each batch where the operation was not completed reset
   --         the batch.  Ignore the FM (return to reserve) batch if it exists.
   --       - If operations were completed:
   --            - If the parent batch was not one of the completed operations:
   --                 - Select the batch number of one of the completed
   --                   operations to use as the new parent batch.  It does not
   --                   matter which completed operation is used.
   --                 - Update the status of the parent batch to 'A'.
   --                 - Update the child batches parent batch # to the new
   --                   parent batch #.
   --            - Delete the FM batch if it exists.
   --            - Recreate the FM batch.
   --       - If no operations were completed:
   --            - Delete the FM batch if it exists.
   --            - Set the o_parent_batch_no to null.
   --
   -- Parameters:
   --    i_batch_no        - The batch number to reset.  It should be the
   --                        operators active batch and needs to be a
   --                        non-demand replenishment or demand replenishment
   --                        batch.  This will be a parent batch number because
   --                        a MKSU letdown batch will always have at least
   --                        two batches associated with it.
   --    o_parent_batch_no - The parent batch # after the MSKU batch is reset.
   --                        It will be i_batch_no if the operation for
   --                        this batch was completed otherwise it will be the
   --                        batch number for one of the completed operations.
   --                        If none of the operations were completed then
   --                        all the batches would have been reset and the
   --                        value will be null.
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null.
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Called by:
   --    lmf_reset_msku_letdown_batch in lm_forklift.pc.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    12/07/03 prpbcb   Created.
   --    02/01/05 prpbcb   Modified to clear out the parent_batch_no if only
   --                      one operation was completed.  Each operation
   --                      corresponds to one labor batch.  If only one
   --                      operation was completed then there is no parent
   --                      batch.
   ---------------------------------------------------------------------------
   PROCEDURE reset_letdown_batch
                      (i_batch_no         IN  arch_batch.batch_no%TYPE,
                       o_parent_batch_no  OUT arch_batch.batch_no%TYPE)
   IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.reset_letdown_batch';

      l_batch_type     VARCHAR2(10);  -- The batch type of i_batch_no.
      l_msku_batch_flag arch_batch.msku_batch_flag%TYPE;  -- User to verify
                                                   -- the batch is for a MSKU.
      l_need_new_parent_bln BOOLEAN;  -- Designates if a new parent batch is
                                      -- needed.
      l_no_of_batches_reset     PLS_INTEGER;  -- Number of batches reset.
      l_no_of_batches_completed PLS_INTEGER;  -- Number of batches completed.
      l_parent_batch_no arch_batch.batch_no%TYPE;  -- Parent batch.  It will
                            -- be i_batch_no if the operation for this batch
                            -- was completed otherwise it will be the batch
                            -- number of one of the completed operations.
      l_status      arch_batch.status%TYPE;  -- User to verify the batch
                                             -- is active.
      l_trans_type  trans.trans_type%TYPE;  -- Trans type to use in checking
                                            -- if the operation is complete.

      -- This cursors selects the letdown batches and if the operation
      -- is completed.  A check of the trans table is made to see if the
      -- operation is complete.  It leaves out the return to reserve batch
      -- if there is one.
      CURSOR c_letdown_batch(cp_batch_no    arch_batch.batch_no%TYPE,
                             cp_trans_type  trans.trans_type%TYPE) IS
         SELECT b.batch_no,
                DECODE(t.trans_id, NULL, 'N', 'Y') task_completed,
                DECODE(b.batch_no, b.parent_batch_no, 'Y', 'N') is_parent
           FROM trans t,
                batch b
          WHERE t.labor_batch_no (+)  = b.batch_no
            AND t.pallet_id (+)       = b.ref_no
            AND t.trans_type (+)      = cp_trans_type
            AND b.batch_no   NOT LIKE pl_lmc.ct_forklift_msku_ret_to_res || '%'
            AND b.parent_batch_no     = cp_batch_no;

      -- This cursor is used to get the new parent batch if the operation for
      -- the current parent batch was not completed.
      CURSOR c_new_parent_batch(cp_batch_no  arch_batch.batch_no%TYPE) IS
         SELECT batch_no
           FROM batch
          WHERE parent_batch_no = cp_batch_no;

      e_no_batch_type         EXCEPTION;  -- Could not determine what type of
                                          -- batch i_batch_no is.
      e_unhandled_batch_type  EXCEPTION;  -- The type of batch is not
                                          -- handled in this function.
   BEGIN

      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- Find out what type of batch it is.
      l_batch_type := pl_lmc.get_batch_type(i_batch_no);

      IF (l_batch_type IS NULL) THEN
         RAISE e_no_batch_type;  -- Do not know the type of batch.
      END IF;

      -- The batch has to be active and be a MSKU batch.
      BEGIN
         SELECT status, NVL(msku_batch_flag, 'N')
           INTO l_status, l_msku_batch_flag
           FROM batch
          WHERE batch_no = i_batch_no;

         IF (l_status != 'A') THEN
            l_message := 'TABLE=batch  ACTION=VERIFICATION' ||
                ' MESSAGE="Batch [' || i_batch_no || '] has status of' ||
                ' [' || l_status || '].  It needs to be the active batch."';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                           l_message, pl_exc.ct_lm_batch_upd_fail, NULL);

            -- Raise the batch upd fail exception.  For the user to find the
            -- culprit the swms_log table will need to be checked. 
            RAISE pl_exc.e_lm_batch_upd_fail;
         END IF;

         IF (l_msku_batch_flag != 'Y') THEN
            l_message := 'TABLE=batch  ACTION=VERIFICATION' ||
                ' MESSAGE="Batch [' || i_batch_no || '] is not a MSKU batch."';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                           l_message, pl_exc.ct_lm_batch_upd_fail, NULL);

            -- Raise the batch upd fail exception.  For the user to find the
            -- culprit the swms_log table will need to be checked. 
            RAISE pl_exc.e_lm_batch_upd_fail;
         END IF;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            -- Batch not found.
            l_message := 'TABLE=batch  ACTION=SELECT' ||
                        ' KEY=' || i_batch_no || '(i_batch_no)' ||
                        ' MESSAGE="Record not found when selecting the' ||
                        ' status, msku_batch_flag."';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                           l_message, pl_exc.ct_no_lm_batch_found, NULL);
            RAISE pl_exc.e_no_lm_batch_found;
      END;

      l_no_of_batches_reset := 0;
      l_no_of_batches_completed := 0;
      l_need_new_parent_bln := FALSE;

      -- Set the transaction type that would be created if the operation for
      -- the batch was completed.
      IF (l_batch_type = pl_lmc.ct_forklift_nondemand_rpl) THEN
          l_trans_type := 'RPL';
      ELSIF (l_batch_type = pl_lmc.ct_forklift_demand_rpl) THEN
          l_trans_type := 'DFK';
      ELSE
         -- Only non-demand and demand replenishments are handled.
         RAISE e_unhandled_batch_type;
      END IF;

      FOR r_letdown_batch IN c_letdown_batch(i_batch_no, l_trans_type) LOOP
         IF (r_letdown_batch.task_completed = 'N') THEN
            IF (r_letdown_batch.is_parent = 'Y') THEN
               l_need_new_parent_bln := TRUE;
            END IF;
       
            pl_lmf.reset_batch(r_letdown_batch.batch_no);

            l_no_of_batches_reset := l_no_of_batches_reset + 1;
         ELSE
            l_no_of_batches_completed := l_no_of_batches_completed + 1;
         END IF;
      END LOOP;

      IF (l_no_of_batches_completed > 0) THEN
         IF (l_need_new_parent_bln) THEN
            -- Need a new parent batch.  The operation for the current parent
            -- batch was not completed thus it was reset.  Right now the child
            -- batches of the completed operations still have the old parent
            -- batch.  Select one of these to user as the new parent batch.
            -- It does not matter which one is used as the new parent batch.
            OPEN c_new_parent_batch(i_batch_no);
            FETCH c_new_parent_batch INTO l_parent_batch_no;
            IF (c_new_parent_batch%NOTFOUND) THEN
               CLOSE c_new_parent_batch;
               l_message := 'TABLE=batch  ACTION=FETCH' ||
                        ' KEY=' || i_batch_no || '(parent batch no)' ||
                        ' MESSAGE="Candidate child batch not found when' ||
                        ' selecting a new parent batch."';
               pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                           l_message, pl_exc.ct_no_lm_batch_found, NULL);
               RAISE pl_exc.e_no_lm_batch_found;
            END IF;
            CLOSE c_new_parent_batch;

            -- The new parent batch needs to be active.
            UPDATE batch
               SET status = 'A'
             WHERE batch_no = l_parent_batch_no;

            IF (SQL%NOTFOUND) THEN
               -- No row updated.
               l_message := 'TABLE=batch  ACTION=UPDATE' ||
                        ' KEY=' || l_parent_batch_no || '(batch #)' ||
                        ' MESSAGE="Record not found when updating the' ||
                        ' status to A."';
              pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                              l_message, pl_exc.ct_lm_batch_upd_fail, NULL);
              RAISE pl_exc.e_lm_batch_upd_fail;
            END IF;

            -- The batches completed need to be updated with the new
            -- parent batch.  At this point they still have i_batch_no as
            -- the parent batch.  If only one operation was completed
            -- then the parent_batch_no needs to be set to null.
            IF (l_no_of_batches_completed = 1) THEN
               UPDATE batch
                  SET parent_batch_no = NULL
                WHERE parent_batch_no = i_batch_no;
            ELSE
               UPDATE batch
                  SET parent_batch_no = l_parent_batch_no
                WHERE parent_batch_no = i_batch_no;
            END IF;

            IF (SQL%NOTFOUND) THEN
               -- No row(s) updated.
               l_message := 'TABLE=batch  ACTION=UPDATE' ||
                        ' KEY=' || l_parent_batch_no || '(parent batch #)' ||
                        ' MESSAGE="Record(s) not found when updating the' ||
                        ' parent batch # from [' || i_batch_no || '] to [' ||
                        l_parent_batch_no || ']."';
              pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                              l_message, pl_exc.ct_lm_batch_upd_fail, NULL);
              RAISE pl_exc.e_lm_batch_upd_fail;
            END IF;

         ELSE
            l_parent_batch_no := i_batch_no;
         END IF;

         -- Delete the current return to reserve batch because it will not
         -- have the correct kvi values then recreate it.  It is possible
         -- there is not one to delete if everything on the MSKU was
         -- being replenished.
         DELETE
           FROM batch
          WHERE parent_batch_no = l_parent_batch_no
            AND batch_no LIKE pl_lmc.ct_forklift_msku_ret_to_res || '%';

         -- Recreate the return to reserve batch.
         pl_lmf.create_return_to_reserve_batch
                            (i_parent_batch_no      => l_parent_batch_no,
                             i_abort_processing_bln => TRUE);

         o_parent_batch_no := l_parent_batch_no;
      ELSE
         -- All the batches were reset.  There is no parent batch.
         o_parent_batch_no := NULL;
      END IF;  -- end IF (l_no_of_batches_completed > 0)

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '],' ||
                      'o_parent_batch_no)' ||
                      '  Parameter i_batch_no is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN e_no_batch_type THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '],' ||
                      'o_parent_batch_no)' ||
                      '  Could not determine what type of batch it is.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_unhandled_batch_type THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '],' ||
                      'o_parent_batch_no)' ||
                      '  Batch type[' || l_batch_type || ']' ||
                      ' not handled in this procedure.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN pl_exc.e_no_lm_batch_found THEN
         -- l_message set earlier.
         RAISE_APPLICATION_ERROR(pl_exc.ct_no_lm_batch_found,
                                 l_object_name || ': ' || l_message);

      WHEN pl_exc.e_lm_batch_upd_fail THEN
         -- l_message set earlier.
         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_batch_upd_fail,
                                 l_object_name || ': ' || l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '],' ||
                      'o_parent_batch_no)';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END reset_letdown_batch; 


   ---------------------------------------------------------------------------
   -- Function:
   --    f_is_msku_batch
   --
   -- Description:
   --    This function determines if a batch is for a MSKU pallet.
   --    
   --    The approach to handle the different batch types is using different
   --    cursors instead of separate functions.
   --
   -- Parameters:
   --    i_batch_no     - The labor batch number to check.
   --
   -- Return Value:
   --    TRUE     - If the batch is for a MSKU pallet.
   --    FALSE    - If the batch is not for a MSKU pallet.
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null.
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Called by:
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    11/03/03 prpbcb   Created.
   --    02/18/05 prpbcb   Changes for returns putaway.
   ---------------------------------------------------------------------------
   FUNCTION f_is_msku_batch(i_batch_no IN arch_batch.batch_no%TYPE)
   RETURN BOOLEAN
   IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_is_msku_batch';

      l_dummy          VARCHAR2(1);      -- Work area
      l_batch_type     VARCHAR2(10);     -- The batch type of i_batch_no
      l_return_value   BOOLEAN;

      -- These cursor are used to check if the batch is for a MSKU pallet.
      CURSOR c_putaway(cp_batch_no  arch_batch.batch_no%TYPE) IS
         SELECT 'x'
           FROM putawaylst p, batch b
          WHERE b.batch_no = cp_batch_no
            AND p.pallet_batch_no = b.batch_no
            AND p.parent_pallet_id IS NOT NULL;

      CURSOR c_ndm(cp_batch_no  arch_batch.batch_no%TYPE) IS
         SELECT 'x'
           FROM replenlst r, batch b
          WHERE b.batch_no = cp_batch_no
            AND r.task_id = TO_NUMBER(SUBSTR(b.batch_no, 3))
            AND r.parent_pallet_id IS NOT NULL
            AND r.type = 'NDM'; 

      CURSOR c_dmd(cp_batch_no  arch_batch.batch_no%TYPE) IS
         SELECT 'x'
           FROM floats f, batch b
          WHERE b.batch_no = i_batch_no
            AND f.float_no = TO_NUMBER(SUBSTR(b.batch_no, 3))
            AND f.parent_pallet_id IS NOT NULL;

      e_no_batch_type         EXCEPTION;  -- Could not determine what type of
                                          -- batch i_batch_no is.
      e_unhandled_batch_type  EXCEPTION;  -- The type of batch is not
                                          -- handled in this function.
   BEGIN
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- Find out what type of batch it is.
      l_batch_type := pl_lmc.get_batch_type(i_batch_no);

      IF (l_batch_type IS NULL) THEN
         RAISE e_no_batch_type;  -- Do not know the type of batch.
      END IF;

      IF (l_batch_type = pl_lmc.ct_forklift_putaway) THEN
         OPEN c_putaway(i_batch_no);
         FETCH c_putaway INTO l_dummy;
         IF (c_putaway%FOUND) THEN
            l_return_value := TRUE;
         ELSE
            l_return_value := FALSE;
         END IF;
         CLOSE c_putaway;
      ELSIF (l_batch_type = pl_lmc.ct_forklift_nondemand_rpl) THEN
         OPEN c_ndm(i_batch_no);
         FETCH c_ndm INTO l_dummy;
         IF (c_ndm%FOUND) THEN
            l_return_value := TRUE;
         ELSE
            l_return_value := FALSE;
         END IF;
         CLOSE c_ndm;
      ELSIF (l_batch_type = pl_lmc.ct_forklift_demand_rpl) THEN
         OPEN c_dmd(i_batch_no);
         FETCH c_dmd INTO l_dummy;
         IF (c_dmd%FOUND) THEN
            l_return_value := TRUE;
         ELSE
            l_return_value := FALSE;
         END IF;
         CLOSE c_dmd;
      ELSIF (l_batch_type = pl_lmc.ct_returns_putaway) THEN
         -- A returns putaway will always be treated as a MSKU.
         l_return_value := TRUE;
      ELSE
            -- Only concerned with MSKU batches for putaway, non-demand repls
            -- and demand repls.
            l_return_value := FALSE;
      END IF;

      RETURN(l_return_value);

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
                      '  Parameter i_batch_no is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_unhandled_batch_type THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
             '  Batch type[' || l_batch_type || ']' ||
             ' not handled in this procedure.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';
         IF (SQLCODE <= -20000) THEN
            l_message := l_message ||
                         '  Called object raised an user defined exception.';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            IF (c_putaway%ISOPEN) THEN CLOSE c_putaway; END IF;
            IF (c_ndm%ISOPEN) THEN CLOSE c_ndm; END IF;
            IF (c_dmd%ISOPEN) THEN CLOSE c_dmd; END IF;
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            IF (c_putaway%ISOPEN) THEN CLOSE c_putaway; END IF;
            IF (c_ndm%ISOPEN) THEN CLOSE c_ndm; END IF;
            IF (c_dmd%ISOPEN) THEN CLOSE c_dmd; END IF;
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;
   
   END f_is_msku_batch;

END pl_lm_msku;   -- end package body
/

SHOW ERRORS;
