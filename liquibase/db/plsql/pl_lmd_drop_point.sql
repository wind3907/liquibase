
PROMPT Create package specification: pl_lmd_drop_point

/*************************************************************************/
-- Package Specification
/*************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_lmd_drop_point
AS

   -- sccs_id=%Z% %W% %G% %I%

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lmd_drop_point
   --
   -- Description:
   --    This package has objects used to determine drop points used in
   --    forklift labor management distance calculations.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/29/03 prpbcb   Oracle 7 rs239a DN none.  Does not exist on oracle 7.
   --                      Oracle 8 rs239b DN 11338
   --                      Initial creation.
   --                      This package has objects for determining drop
   --                      points used in distance calculations.  Some
   --                      functions from lm_distance.pc were converted
   --                      into PL/SQL in this package.
   --
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
   --    04/12/10  prpbcb  DN 12580
   --                      Project:
   --                          CRQ16476-Complete Not Suspend Labor Mgmt Batch
   --
   --                      Change the suspend batch processing when lxli
   --                      forklift is active.  Complete the labor mgmt
   --                      batch(s) if the task(s) is/are completed
   --                      designating a new parent batch if needed.
   --                      Suspend the labor mgmt batch for the tasks not yet
   --                      completed designating a new parent batch if
   --                      needed.  Before everything was suspended.
   --                      This is done because lxli cannot handle a batch
   --                      performed within the time of another batch.
   --
   --                      Modified how the last drop point is found.
   --
   --    06/09/10  prpbcb  DN 12580
   --                      Project:
   --                          CRQ16476-Complete Not Suspend Labor Mgmt Batch
   --                      Bug fixes.
   --                      Procedure get_last_put_drop_point() was not
   --                      determining the last drop point correctly.
   --
   --                      In procedures
   --                         get_last_put_drop_point
   --                         get_last_ndm_drop_point
   --                         get_last_dmd_drop_point
   --                         get_last_hst_drop_point
   --                      changed
   --                         AND (   t.cmt = SUBSTR(b.batch_no, 3)
   --                              OR t.labor_batch_no = b.batch_no)
   --                      to
   --                          t.labor_batch_no = b.batch_no)
   --                      because the trans.labor_batch_no will have the
   --                      labor batch number.
   --                      Added
   --                         t2.labor_batch_no = b2.batch_no
   --                      to the "SELECT MAX" sub query.
   --                      
   --    07/19/10  prpbcb  Activity: SWMS12.0.0_0000_QC11345
   --                      Project:  QC11345
   --                      Copy from rs239b.
   --
   --  08-Oct-2021 pkab6563 - Copied function get_last_drop_point(i_batch_no) 
   --                         from RDC SWMS for Jira card 3700 to allow
   --                         signoff from forklift batches.
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Type Declarations
   ---------------------------------------------------------------------------

   -- Drop point information.  This is information about the last drop a user
   -- made.  The batch number can be a parent or child batch number depending
   -- on what was last dropped.
   TYPE t_drop_point_rec IS RECORD
   (batch_no         arch_batch.batch_no%TYPE,
    parent_status    arch_batch.status%TYPE,   -- The status of the batch
                                      -- or for merged batches the status of
                                      -- the parent batch.
    pallet_id        trans.pallet_id%TYPE,
    prod_id          trans.prod_id%TYPE,
    cpv              trans.cust_pref_vendor%TYPE,
    drop_point       trans.dest_loc%TYPE,
    drop_qty         BINARY_INTEGER,   -- The cases/splits the operator got
                                       -- credit to handstack.  It is the batch
                                       -- kvi_no_case and kvi_no_split as a
                                       -- split qty.
    trans_qty        BINARY_INTEGER);  -- Transacton qty in splits


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
   --    get_last_put_drop_point
   --
   -- Description:
   --    This procedure finds the last completed drop of a putaway batch.
   ---------------------------------------------------------------------------
   PROCEDURE get_last_put_drop_point
                          (i_batch_no        IN  arch_batch.batch_no%TYPE,
                           o_r_drop_point    OUT t_drop_point_rec);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_last_ndm_drop_point
   --
   -- Description:
   --    This procedure finds the last completed drop of a non-demand
   --    replenishment batch.
   ---------------------------------------------------------------------------
   PROCEDURE get_last_ndm_drop_point
                          (i_batch_no        IN  arch_batch.batch_no%TYPE,
                           o_r_drop_point    OUT t_drop_point_rec);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_last_dmd_drop_point
   --
   -- Description:
   --    This procedure finds the last completed drop of a demand
   --    replenishment batch.
   ---------------------------------------------------------------------------
   PROCEDURE get_last_dmd_drop_point
                          (i_batch_no        IN  arch_batch.batch_no%TYPE,
                           o_r_drop_point    OUT t_drop_point_rec);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_last_hst_drop_point
   --
   -- Description:
   --    This procedure finds the last completed drop of a home slot
   --    transfer batch.
   ---------------------------------------------------------------------------
   PROCEDURE get_last_hst_drop_point
                          (i_batch_no        IN  arch_batch.batch_no%TYPE,
                           o_r_drop_point    OUT t_drop_point_rec);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_last_drop_point
   --
   -- Description:
   --    This procedure finds the last completed drop of a forklift batch.
   ---------------------------------------------------------------------------
   PROCEDURE get_last_drop_point 
                          (i_batch_no        IN  arch_batch.batch_no%TYPE,
                           o_r_drop_point    OUT t_drop_point_rec);

   ---------------------------------------------------------------------------
   -- Function:
   --    get_last_drop_point (overloaded)
   --
   -- Description:
   --    This function returns the the point of the last completed drop of a forklift batch.
   --    This will be the parent batch for merged batches.
   ---------------------------------------------------------------------------
   FUNCTION get_last_drop_point(i_batch_no      IN  arch_batch.batch_no%TYPE)
   RETURN VARCHAR2;

END pl_lmd_drop_point;  -- end package specification
/

SHOW ERRORS;

PROMPT Create package body: pl_lmd_drop_point

/**************************************************************************/
-- Package Body
/**************************************************************************/
CREATE OR REPLACE PACKAGE BODY swms.pl_lmd_drop_point
IS

   -- sccs_id=%Z% %W% %G% %I%

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lmd_drop_point
   --
   -- Description:
   --    This package has objects used to determine drop points used in
   --    forklift labor management distance calculations.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/29/03 prpbcb   Oracle 7 rs239a DN none.  Does not exist on oracle 7.
   --                      Oracle 8 rs239b DN 11338
   --                      Initial creation.
   --                      This package has objects for determining drop
   --                      points used in distance calculations.  Some
   --                      functions in lm_distance.pc were converted
   --                      converted into PL/SQL in this package.
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Private Type Declarations
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Private Global Variables
   ---------------------------------------------------------------------------
   gl_pkg_name   VARCHAR2(30) := 'pl_lmd_drop_point';   -- Package name.
                                             --  Used in error messages.

   gl_e_parameter_null  EXCEPTION;     -- A parameter to a procedure/function
                                       -- is null.

   ---------------------------------------------------------------------------
   -- Private Constants
   ---------------------------------------------------------------------------
   ct_application_function VARCHAR2(10) := 'LABOR MGT';  -- For pl_log message

   ---------------------------------------------------------------------------
   -- Private Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_last_put_drop_point
   --
   -- Description:
   --    This procedure finds the last completed drop of a putaway batch.
   --
   -- Parameters:
   --    i_batch_no        - The putaway batch number to find the last
   --                        completed drop point for.  This will be the
   --                        parent batch for merged batches.
   --    o_r_drop_point    - Drop point information.  The batch number of 
   --                        the last drop can be different from i_batch_no
   --                        for merge batches.
   --  
   -- Exceptions raised:
   --    User defined exception   - A called object returned an user
   --                               defined error.
   --    pl_exc.e_data_error      - Parameter null, could not determine batch
   --                               type, unhandled batch type, last drop point
   --                               null.
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Called by:
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/29/03 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE get_last_put_drop_point
                          (i_batch_no             IN  arch_batch.batch_no%TYPE,
                           o_r_drop_point         OUT t_drop_point_rec)
   IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                                  '.get_last_put_drop_point';

      l_batch_type     VARCHAR2(10);  -- The batch type.

      -- This cursor selects the last completed drop for a putaway
      -- batch.  It accounts for open and closed PO's.  If for some
      -- unknown reason confirmed puts have the same transaction date
      -- then the wrong drop point could be selected.
      CURSOR c_putaway_last_drop_point(cp_batch_no arch_batch.batch_no%TYPE) IS
         SELECT b.batch_no,
                bs.status,
                b.kvi_to_loc dest_loc,
                t.pallet_id,
                t.prod_id,
                t.cust_pref_vendor,
                (NVL(b.kvi_no_case, 0) * pm.spc) +
                                             NVL(b.kvi_no_split, 0) drop_qty,
                 t.qty trans_qty
           FROM pm pm,
                trans t,
                batch b,    -- Last drop batch
                batch bs    -- To get the status of the parent batch.
          WHERE (   b.batch_no = cp_batch_no
                 OR b.parent_batch_no = cp_batch_no)
            AND bs.batch_no = cp_batch_no
            AND pm.prod_id = t.prod_id
            AND pm.cust_pref_vendor = t.cust_pref_vendor
            AND t.pallet_id = b.ref_no
            AND t.labor_batch_no = b.batch_no
            AND t.trans_type || '' IN ('PUT', 'TRP')
            AND t.trans_date =
                          (SELECT MAX(t2.trans_date)
                             FROM trans t2, batch b2
                            WHERE (   b2.batch_no        = cp_batch_no
                                   OR b2.parent_batch_no = cp_batch_no)
                              AND t2.pallet_id      = b2.ref_no
                              AND t2.labor_batch_no = b2.batch_no
                              AND t2.trans_type || '' IN ('PUT', 'TRP')
                              AND ( EXISTS
                                       (SELECT 'x'
                                          FROM putawaylst p
                                         WHERE p.pallet_id = b2.ref_no
                                           AND p.putaway_put = 'Y')
                                  OR NOT EXISTS
                                       (SELECT 'x'
                                          FROM putawaylst p
                                         WHERE p.pallet_id = b2.ref_no)))
            AND (  EXISTS
                       (SELECT 'x'
                          FROM putawaylst p
                         WHERE p.pallet_id = b.ref_no
                           AND p.putaway_put = 'Y')
                  OR NOT EXISTS
                       (SELECT 'x'
                          FROM putawaylst p
                         WHERE p.pallet_id = b.ref_no));

      e_found_no_last_drop_point EXCEPTION;  -- Found no last drop point.
      e_last_drop_point_null     EXCEPTION;  -- Last drop point null.
                                             -- This means trans.dest_loc
                                             -- is null.
      e_not_putaway_batch        EXCEPTION;  -- The batch is not a putaway
                                             -- batch.

   BEGIN
      l_message := l_object_name ||
         '(i_batch_no[' || i_batch_no ||
         '],o_batch_no,o_pallet_id,o_r_drop_point)';

      -- Check if parameter is null.
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- The batch has to be a putaway batch.
      l_batch_type := pl_lmc.get_batch_type(i_batch_no);
      IF (   l_batch_type != pl_lmc.ct_forklift_putaway 
          OR l_batch_type IS NULL) THEN
         RAISE e_not_putaway_batch;
      END IF;

      OPEN c_putaway_last_drop_point(i_batch_no);
      FETCH c_putaway_last_drop_point INTO o_r_drop_point.batch_no,
                                           o_r_drop_point.parent_status,
                                           o_r_drop_point.drop_point,
                                           o_r_drop_point.pallet_id,
                                           o_r_drop_point.prod_id,
                                           o_r_drop_point.cpv,
                                           o_r_drop_point.drop_qty,
                                           o_r_drop_point.trans_qty;

      IF (c_putaway_last_drop_point%NOTFOUND) THEN
         -- Did not found a last drop point but should have.
         CLOSE c_putaway_last_drop_point;
         RAISE e_found_no_last_drop_point;
      END IF;

      CLOSE c_putaway_last_drop_point;

      -- The drop point should not be null.
      IF (o_r_drop_point.drop_point IS NULL) THEN
         RAISE e_last_drop_point_null;
      END IF;

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_message || '  A parameter is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN e_not_putaway_batch THEN
         l_message := l_message || 
                            '  The batch is not a putaway batch.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_found_no_last_drop_point THEN
         l_message := l_message ||
             ' TABLE=trans,batch,putawaylst' ||
             ' KEY=' || i_batch_no || '(lm batch#) ACTION=SELECT' ||
             ' MESSAGE="Found no last drop point but should have"';
         pl_log.ins_msg('FATAL', l_object_name, l_message,
                                 SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_last_drop_point_null THEN
         l_message := l_message ||
                    ' TABLE=trans,batch,putawaylst' ||
                    ' KEY=' || i_batch_no || '(lm batch#) ACTION=SELECT' ||
                    ' MESSAGE="Last drop point is null (trans.dest_loc)"';
         pl_log.ins_msg('FATAL', l_object_name, l_message,
                                 SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_message ||
                    ' TABLE=trans,batch,putawaylst' ||
                    ' KEY=' || i_batch_no || '(lm batch#) ACTION=SELECT' ||
                    ' MESSAGE="OTHERS exception looking for last completed' ||
                    ' drop point"';
         pl_log.ins_msg('FATAL', l_object_name, l_message, SQLCODE, SQLERRM);
         -- Cursor cleaup.
         IF (c_putaway_last_drop_point%ISOPEN) THEN
            CLOSE c_putaway_last_drop_point;
         END IF;
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_message || ': ' || SQLERRM);
   END get_last_put_drop_point;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_last_ndm_drop_point
   --
   -- Description:
   --    This procedure finds the last completed drop of a non-demand
   --    replenishment batch.
   --
   --    The logic is very similar to get_last_dmd_drop_point.
   --
   -- Parameters:
   --    i_batch_no        - The non-demand replenishment batch number to find
   --                        the last completed drop point for.  This will be
   --                        the parent batch for merged batches.
   --    o_r_drop_point    - Drop point information.  The batch number of 
   --                        the last drop can be different from i_batch_no
   --                        for merge batches.
   --  
   -- Exceptions raised:
   --    User defined exception   - A called object returned an user
   --                               defined error.
   --    pl_exc.e_data_error      - Parameter null, could not determine batch
   --                               type, unhandled batch type, last drop point
   --                               null.
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Called by:
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/29/03 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE get_last_ndm_drop_point
                          (i_batch_no         IN  arch_batch.batch_no%TYPE,
                           o_r_drop_point     OUT t_drop_point_rec)
   IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                                  '.get_last_ndm_drop_point';

      l_batch_type     VARCHAR2(10);  -- The batch type.
 
      --
      -- This cursor selects the last completed drop for a non-demand
      -- replenishment batch.
      -- If for some unknown reason completed drops have the same
      -- transaction date then the wrong drop point could be selected.
      --
      CURSOR c_ndm_last_drop_point(cp_batch_no arch_batch.batch_no%TYPE) IS
         SELECT b.batch_no,
                bs.status,
                b.kvi_to_loc dest_loc,
                t.pallet_id,
                t.prod_id,
                t.cust_pref_vendor,
                (NVL(b.kvi_no_case, 0) * pm.spc) +
                                             NVL(b.kvi_no_split, 0) drop_qty,
                 t.qty trans_qty
           FROM pm pm,
                trans t,
                batch b,    -- Last drop batch
                batch bs    -- To get the status of the parent batch.
          WHERE (   b.batch_no        = cp_batch_no
                 OR b.parent_batch_no = cp_batch_no)
            AND bs.batch_no         = cp_batch_no
            AND pm.prod_id          = t.prod_id
            AND pm.cust_pref_vendor = t.cust_pref_vendor
            AND t.pallet_id         = b.ref_no
            AND t.labor_batch_no    = b.batch_no
            AND t.trans_type || ''  = 'RPL'
            AND t.trans_date =
                     (SELECT MAX(t2.trans_date)
                        FROM trans t2, batch b2
                       WHERE (   b2.batch_no        = cp_batch_no
                              OR b2.parent_batch_no = cp_batch_no)
                         AND t2.pallet_id        = b2.ref_no
                         AND t2.labor_batch_no   = b2.batch_no
                         AND t2.trans_type || '' = 'RPL'
                         AND (   t2.user_id = b2.user_id
                              OR t2.user_id = 'OPS$' || b2.user_id));

      e_found_no_last_drop_point EXCEPTION;  -- Found no last drop point.
      e_last_drop_point_null     EXCEPTION;  -- Last drop point null.
                                             -- This means trans.dest_loc
                                             -- is null.
      e_not_ndm_batch            EXCEPTION;  -- The batch is not a non-demand
                                             -- replenishment batch.
   BEGIN
      l_message := l_object_name ||
         '(i_batch_no[' || i_batch_no ||
         '],o_batch_no,o_pallet_id,o_last_drop_point)';

      -- Check if parameter is null.
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- The batch has to be a non-demand replenishment batch.
      l_batch_type := pl_lmc.get_batch_type(i_batch_no);
      IF (   l_batch_type != pl_lmc.ct_forklift_nondemand_rpl
          OR l_batch_type IS NULL) THEN
         RAISE e_not_ndm_batch;
      END IF;

      OPEN c_ndm_last_drop_point(i_batch_no);
      FETCH c_ndm_last_drop_point INTO o_r_drop_point.batch_no,
                                       o_r_drop_point.parent_status,
                                       o_r_drop_point.drop_point,
                                       o_r_drop_point.pallet_id,
                                       o_r_drop_point.prod_id,
                                       o_r_drop_point.cpv,
                                       o_r_drop_point.drop_qty,
                                       o_r_drop_point.trans_qty;

      IF (c_ndm_last_drop_point%NOTFOUND) THEN
         -- Did not found a last drop point but should have.
         CLOSE c_ndm_last_drop_point;
         RAISE e_found_no_last_drop_point;
      END IF;

      CLOSE c_ndm_last_drop_point;

      -- The drop point should not be null.
      IF (o_r_drop_point.drop_point IS NULL) THEN
         RAISE e_last_drop_point_null;
      END IF;

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_message || '  A parameter is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN e_not_ndm_batch THEN
         l_message := l_message || 
            '  The batch is not a non-demand replenishment batch.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_found_no_last_drop_point THEN
         l_message := l_message ||
             ' TABLE=trans,batch' ||
             ' KEY=' || i_batch_no || '(lm batch#) ACTION=SELECT' ||
             ' MESSAGE="Found no last drop point but should have"';
         pl_log.ins_msg('FATAL', l_object_name, l_message,
                                 SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_last_drop_point_null THEN
         l_message := l_message ||
                    ' TABLE=trans,batch' ||
                    ' KEY=' || i_batch_no || '(lm batch#) ACTION=SELECT' ||
                    ' MESSAGE="Last drop point is null (trans.dest_loc)"';
         pl_log.ins_msg('FATAL', l_object_name, l_message,
                                 SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_message ||
                    ' TABLE=trans,batch' ||
                    ' KEY=' || i_batch_no || '(lm batch#) ACTION=SELECT' ||
                    ' MESSAGE="OTHERS exception looking for last completed' ||
                    ' drop point"';
         pl_log.ins_msg('FATAL', l_object_name, l_message,
                                 SQLCODE, SQLERRM);
         -- Cursor cleaup.
         IF (c_ndm_last_drop_point%ISOPEN) THEN
            CLOSE c_ndm_last_drop_point;
         END IF;
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_message || ': ' || SQLERRM);

   END get_last_ndm_drop_point;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_last_dmd_drop_point
   --
   -- Description:
   --    This procedure finds the last completed drop of a demand
   --    replenishment batch.
   --
   --    The logic is very similar to get_last_ndm_drop_point.
   --
   -- Parameters:
   --    i_batch_no       - The demand replenishment batch number to find the
   --                       last completed drop point for.  This will be the
   --                       parent batch for merged batches.
   --    o_r_drop_point   - Drop point information.  The batch number of
   --                       the last drop can be different from i_batch_no
   --                       for merge batches.
   --  
   -- Exceptions raised:
   --    User defined exception   - A called object returned an user
   --                               defined error.
   --    pl_exc.e_data_error      - Parameter null, could not determine batch
   --                               type, unhandled batch type, last drop point
   --                               null.
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Called by:
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/29/03 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE get_last_dmd_drop_point
                          (i_batch_no        IN  arch_batch.batch_no%TYPE,
                           o_r_drop_point    OUT t_drop_point_rec)
   IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                                  '.get_last_dmd_drop_point';

      l_batch_type     VARCHAR2(10);  -- The batch type.

      -- This cursor selects the last completed drop for a demand batch
      -- If for some unknown reason confirmed drops have the same
      -- transaction date then the wrong drop point could be selected.
      CURSOR c_dmd_last_drop_point(cp_batch_no arch_batch.batch_no%TYPE) IS
         SELECT b.batch_no,
                bs.status,
                b.kvi_to_loc dest_loc,
                t.pallet_id,
                t.prod_id,
                t.cust_pref_vendor,
                (NVL(b.kvi_no_case, 0) * pm.spc) +
                                             NVL(b.kvi_no_split, 0) drop_qty,
                 t.qty trans_qty
           FROM pm pm,
                trans t,
                batch b,    -- Last drop batch
                batch bs    -- To get the status of the parent batch.
          WHERE (   b.batch_no = cp_batch_no
                 OR b.parent_batch_no = cp_batch_no)
            AND bs.batch_no = cp_batch_no
            AND pm.prod_id          = t.prod_id
            AND pm.cust_pref_vendor = t.cust_pref_vendor
            AND t.pallet_id         = b.ref_no
            AND t.labor_batch_no    = b.batch_no
            AND t.trans_type || ''  = 'DFK'
            AND t.trans_date =
                     (SELECT MAX(t2.trans_date)
                        FROM trans t2, batch b2
                       WHERE (   b2.batch_no        = cp_batch_no
                              OR b2.parent_batch_no = cp_batch_no)
                         AND t2.pallet_id        = b2.ref_no
                         AND t2.labor_batch_no   = b2.batch_no
                         AND t2.trans_type || '' = 'DFK'
                         AND (   t2.user_id = b2.user_id
                              OR t2.user_id = 'OPS$' || b2.user_id));

      e_found_no_last_drop_point EXCEPTION;  -- Found no last drop point.
      e_last_drop_point_null     EXCEPTION;  -- Last drop point null.
                                             -- This means trans.dest_loc
                                             -- is null.
      e_not_dmd_batch            EXCEPTION;  -- The batch is not a non-demand
                                             -- replenishment batch.
   BEGIN
      l_message := l_object_name ||
         '(i_batch_no[' || i_batch_no ||
          '],o_batch_no,o_pallet_id,o_last_drop_point)';

      -- Check if parameter is null.
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- The batch has to be a demand replenishment batch.
      l_batch_type := pl_lmc.get_batch_type(i_batch_no);
      IF (   l_batch_type != pl_lmc.ct_forklift_demand_rpl
          OR l_batch_type IS NULL) THEN
         RAISE e_not_dmd_batch;
      END IF;

      OPEN c_dmd_last_drop_point(i_batch_no);
      FETCH c_dmd_last_drop_point INTO o_r_drop_point.batch_no,
                                       o_r_drop_point.parent_status,
                                       o_r_drop_point.drop_point,
                                       o_r_drop_point.pallet_id,
                                       o_r_drop_point.prod_id,
                                       o_r_drop_point.cpv,
                                       o_r_drop_point.drop_qty,
                                       o_r_drop_point.trans_qty;

      IF (c_dmd_last_drop_point%NOTFOUND) THEN
         -- Did not found a last drop point but should have.
         CLOSE c_dmd_last_drop_point;
         RAISE e_found_no_last_drop_point;
      END IF;

      CLOSE c_dmd_last_drop_point;

      -- The drop point should not be null.
      IF (o_r_drop_point.drop_point IS NULL) THEN
         RAISE e_last_drop_point_null;
      END IF;

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_message || '  A parameter is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN e_not_dmd_batch THEN
         l_message := l_message || 
            '  The batch is not a demand replenishment batch.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_found_no_last_drop_point THEN
         l_message := l_message ||
             ' TABLE=trans,batch' ||
             ' KEY=' || i_batch_no || '(lm batch#) ACTION=SELECT' ||
             ' MESSAGE="Found no last drop point but should have"';
         pl_log.ins_msg('FATAL', l_object_name, l_message,
                                 SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_last_drop_point_null THEN
         l_message := l_message ||
                    ' TABLE=trans,batch' ||
                    ' KEY=' || i_batch_no || '(lm batch#) ACTION=SELECT' ||
                    ' MESSAGE="Last drop point is null (trans.dest_loc)"';
         pl_log.ins_msg('FATAL', l_object_name, l_message,
                                 SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_message ||
                    ' TABLE=trans,batch' ||
                    ' KEY=' || i_batch_no || '(lm batch#) ACTION=SELECT' ||
                    ' MESSAGE="OTHERS exception looking for last completed' ||
                    ' drop point"';
         pl_log.ins_msg('FATAL', l_object_name, l_message,
                                 SQLCODE, SQLERRM);
         -- Cursor cleaup.
         IF (c_dmd_last_drop_point%ISOPEN) THEN
            CLOSE c_dmd_last_drop_point;
         END IF;
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_message || ': ' || SQLERRM);

   END get_last_dmd_drop_point;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_last_hst_drop_point
   --
   -- Description:
   --    This procedure finds the last completed drop of a home slot
   --    transfer batch.
   --
   --    The logic is very similar to that for a DMD and NDM batch.
   --
   -- Parameters:
   --    i_batch_no       - The home slot transfer batch number to find the
   --                       last completed drop point for.  This will be the
   --                       parent batch for merged batches.
   --    o_r_drop_point   - Drop point information.  The batch number of
   --                       the last drop can be different from i_batch_no
   --                       for merge batches.
   --  
   -- Exceptions raised:
   --    User defined exception   - A called object returned an user
   --                               defined error.
   --    pl_exc.e_data_error      - Parameter null, could not determine batch
   --                               type, unhandled batch type, last drop point
   --                               null.
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Called by:
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/29/03 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE get_last_hst_drop_point
                          (i_batch_no        IN  arch_batch.batch_no%TYPE,
                           o_r_drop_point    OUT t_drop_point_rec)
   IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                                  '.get_last_hst_drop_point';

      l_batch_type     VARCHAR2(10);  -- The batch type.

      -- This cursor selects the last completed drop for a home slot
      -- transfer batch.
      CURSOR c_hst_last_drop_point(cp_batch_no arch_batch.batch_no%TYPE) IS
         SELECT b.batch_no,
                bs.status,
                b.kvi_to_loc dest_loc,
                t.pallet_id,
                t.prod_id,
                t.cust_pref_vendor,
                (NVL(b.kvi_no_case, 0) * pm.spc) +
                                             NVL(b.kvi_no_split, 0) drop_qty,
                 t.qty trans_qty
           FROM pm pm,
                trans t,
                batch b,    -- Last drop batch
                batch bs    -- To get the status of the parent batch.
          WHERE (   b.batch_no = cp_batch_no
                 OR b.parent_batch_no = cp_batch_no)
            AND bs.batch_no = cp_batch_no
            AND pm.prod_id          = t.prod_id
            AND pm.cust_pref_vendor = t.cust_pref_vendor
            AND t.pallet_id         = b.ref_no
            AND t.labor_batch_no    = b.batch_no
            AND t.trans_type || ''  = 'HST'
            AND t.trans_date =
                     (SELECT MAX(t2.trans_date)
                        FROM trans t2, batch b2
                       WHERE (   b2.batch_no        = cp_batch_no
                              OR b2.parent_batch_no = cp_batch_no)
                         AND t2.pallet_id        = b2.ref_no
                         AND t2.labor_batch_no   = b2.batch_no
                         AND t2.trans_type || '' = 'HST'
                         AND (   t2.user_id = b2.user_id
                              OR t2.user_id = 'OPS$' || b2.user_id));

      e_found_no_last_drop_point EXCEPTION;  -- Found no last drop point.
      e_last_drop_point_null     EXCEPTION;  -- Last drop point null.
                                             -- This means trans.dest_loc
                                             -- is null.
      e_not_hst_batch            EXCEPTION;  -- The batch is not a non-demand
                                             -- replenishment batch.
   BEGIN
      l_message := l_object_name ||
         '(i_batch_no[' || i_batch_no ||
          '],o_batch_no,o_pallet_id,o_last_drop_point)';

      -- Check if parameter is null.
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- The batch has to be a demand replenishment batch.
      l_batch_type := pl_lmc.get_batch_type(i_batch_no);
      IF (   l_batch_type != pl_lmc.ct_forklift_home_slot_xfer
          OR l_batch_type IS NULL) THEN
         RAISE e_not_hst_batch;
      END IF;

      OPEN c_hst_last_drop_point(i_batch_no);
      FETCH c_hst_last_drop_point INTO o_r_drop_point.batch_no,
                                       o_r_drop_point.parent_status,
                                       o_r_drop_point.drop_point,
                                       o_r_drop_point.pallet_id,
                                       o_r_drop_point.prod_id,
                                       o_r_drop_point.cpv,
                                       o_r_drop_point.drop_qty,
                                       o_r_drop_point.trans_qty;

      IF (c_hst_last_drop_point%NOTFOUND) THEN
         -- Did not found a last drop point but should have.
         CLOSE c_hst_last_drop_point;
         RAISE e_found_no_last_drop_point;
      END IF;

      CLOSE c_hst_last_drop_point;

      -- The drop point should not be null.
      IF (o_r_drop_point.drop_point IS NULL) THEN
         RAISE e_last_drop_point_null;
      END IF;

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_message || '  A parameter is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN e_not_hst_batch THEN
         l_message := l_message || 
            '  The batch is not a home slot transfer batch.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_found_no_last_drop_point THEN
         l_message := l_message ||
             ' TABLE=trans,batch' ||
             ' KEY=' || i_batch_no || '(lm batch#) ACTION=SELECT' ||
             ' MESSAGE="Found no last drop point but should have"';
         pl_log.ins_msg('FATAL', l_object_name, l_message,
                                 SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_last_drop_point_null THEN
         l_message := l_message ||
                    ' TABLE=trans,batch' ||
                    ' KEY=' || i_batch_no || '(lm batch#) ACTION=SELECT' ||
                    ' MESSAGE="Last drop point is null (trans.dest_loc)"';
         pl_log.ins_msg('FATAL', l_object_name, l_message,
                                 SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_message ||
                    ' TABLE=trans,batch' ||
                    ' KEY=' || i_batch_no || '(lm batch#) ACTION=SELECT' ||
                    ' MESSAGE="OTHERS exception looking for last completed' ||
                    ' drop point"';
         pl_log.ins_msg('FATAL', l_object_name, l_message,
                                 SQLCODE, SQLERRM);
         -- Cursor cleaup.
         IF (c_hst_last_drop_point%ISOPEN) THEN
            CLOSE c_hst_last_drop_point;
         END IF;
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_message || ': ' || SQLERRM);

   END get_last_hst_drop_point;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_last_drop_point
   --
   -- Description:
   --    This procedure finds the last completed drop of a forklift batch.
   --    This will be the parent batch for merged batches.
   --
   -- Parameters:
   --    i_batch_no        - The batch number to get the last drop for.
   --    o_r_drop_point    - Drop point information.  The batch number of
   --                        the last drop can be different from i_batch_no
   --                        for merge batches.
   --  
   -- Exceptions raised:
   --    User defined exception   - A called object returned an user
   --                               defined error.
   --    pl_exc.e_data_error      - Parameter null, could not determine batch
   --                               type, unhandled batch type.
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Called by:
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/29/03 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE get_last_drop_point
                        (i_batch_no         IN  arch_batch.batch_no%TYPE,
                         o_r_drop_point     OUT t_drop_point_rec)
   IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.get_last_drop_point';

      l_batch_type     VARCHAR2(10);  -- The type of forklift labor
                                      -- batch.  Example:  FP, FN, etc.

      e_no_batch_type   EXCEPTION;   -- Could not determine what type of batch
                                     -- i_batch_no is.

      e_unhandled_batch_type  EXCEPTION;  -- The type of batch is not
                                          -- handled in this procedure.
   BEGIN
      l_message := l_object_name ||
         '(i_batch_no[' || i_batch_no || '],o_r_drop_point)';

      -- Check for null parameters.
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      l_batch_type := pl_lmc.get_batch_type(i_batch_no);
  
      IF (l_batch_type IS NULL) THEN
         RAISE e_no_batch_type;  -- Do not know the type of batch.
      END IF;

      IF (l_batch_type = pl_lmc.ct_forklift_putaway) THEN
         get_last_put_drop_point(i_batch_no,
                                 o_r_drop_point);
      ELSIF (l_batch_type = pl_lmc.ct_forklift_nondemand_rpl) THEN
         get_last_ndm_drop_point(i_batch_no,
                                 o_r_drop_point);
      ELSIF (l_batch_type = pl_lmc.ct_forklift_demand_rpl) THEN
         get_last_dmd_drop_point(i_batch_no,
                                 o_r_drop_point);
      ELSIF (l_batch_type = pl_lmc.ct_forklift_home_slot_xfer) THEN
         get_last_hst_drop_point(i_batch_no,
                                 o_r_drop_point);
      ELSE
         -- Have an unhandled batch type.
         RAISE e_unhandled_batch_type;
      END IF;

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_message || '  A parameter is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN e_no_batch_type THEN
         l_message := l_message || 
             '  Could not determine what type of batch it is.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN e_unhandled_batch_type THEN
         l_message := l_message || 
            '  Batch type[' || l_batch_type || ']' ||
            ' not handled in this procedure.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_message || ': ' || SQLERRM);
         END IF;

   END get_last_drop_point;


---------------------------------------------------------------------------
-- Function:
--    get_last_drop_point  (overloaded)
--
-- Description:
--    This function returns the the point of the last completed drop of a forklift batch.
--    This will be the parent batch for merged batches.
--
-- Parameters:
--    i_batch_no      - The batch number to get the last drop for.
--                      For merge batches this needs to be the parent batch.
--    o_drop_point    - Drop point
--
-- Return Values:
--    Last drop pont for the batch or NULL if not found.
--    The calling program will need to decide what to do if NULL returned.
--  
-- Exceptions raised:
--    None.  Errors are logged.  NULL will be returned.
--
-- Called by:
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/20/19 prpbcb   Created.
---------------------------------------------------------------------------
FUNCTION get_last_drop_point(i_batch_no  IN  arch_batch.batch_no%TYPE)
RETURN VARCHAR2
IS
   l_message        VARCHAR2(256);    -- Message buffer
   l_object_name    VARCHAR2(61) := 'get_last_drop_point';

   l_r_last_drop_point    t_drop_point_rec;    -- Work area
   l_drop_point           arch_batch.kvi_to_loc%TYPE;

BEGIN
   --
   -- Initialization.
   --
   l_drop_point := NULL;

   BEGIN
      --
      -- A procedure does the work.
      --
      get_last_drop_point(i_batch_no, l_r_last_drop_point);

      l_drop_point := l_r_last_drop_point.drop_point;

   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
   END;

   IF (l_drop_point IS NULL) THEN
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Unable to find the last drop point for labor batch[' || i_batch_no || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
   END IF;

   RETURN l_drop_point;

END get_last_drop_point;


END pl_lmd_drop_point;   -- end package body
/

SHOW ERRORS;

