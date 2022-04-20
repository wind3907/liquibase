CREATE OR REPLACE PACKAGE swms.pl_lm_loader
AS

---------------------------------------------------------------------------
-- Package Name:
--    pl_lm_loader
--
-- Description:
--    Package for loader labor batches.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    05/01/19 bben0556 Brian Bent
--                      Project: S4R-Jira-Story_1736_Use_plsql_to_create_loader_labor_batches
--
--                      Package created.
--
--                      Function "create_loading_batches" in file "crt_lbr_mgmt_bats.pc"
--                      modified to call package procedure
--                      "pl_lm_loader.create_loader_batches" to create the loader
--                      labor mgmt batches when creating by float number.
--
--    10/30/19 bben0556 Brian Bent
--                      Project: S4R-Jira-Story_2298_Loader_lm_ref_no_and_send_lxli_send_time_fixes
--
--                      The loader batch batch.ref_no is not always the correct route.  This is
--                      happening when a pallet is moved between routes in the Route Manager screen
--                      as the loader batch batch.ref_no is not updated to the route the
--                      pallet was moved to.  Procedure "Pl_Op_Rdc_Route_Optimization.Move_Pallet"
--                      changed to fix the issue.
--
--                      Make change in procedure "create_loader_batches" that when a RDC
--                      to use the route.route_no for the batch.ref_no instead
--                      of route.truck_no.  The route.truck_no is always the
--                      route.route_no for a RDC but to be more direct
--                      lets just use the route.route_no for batch.ref_no.
--
--                      Add function "is_loader_active".
--                      Add procedure "update_batch_ref_no".
--
---------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Constants
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Cursors
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Type Declarations
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Function:
--    is_loader_active
--
-- Description:
--    This function determines if loader labor mgmt is active.
--    Loader labor is active when syspar LBR_MGMT_FLAG is 'Y' and
--    column create_batch_flag is 'Y' in table LBR_FUNC where
--    lfun_lbr_func = 'LD'.
---------------------------------------------------------------------------
FUNCTION is_loader_active
RETURN BOOLEAN;


---------------------------------------------------------------------------
-- Procedure:
--    create_loader_batches
--
-- Description:
--    This procedure creates the loader labor batches at the pallet level
--    for either a wave, route, float or task.
--
--    This is a PL/SQL version of function "create_loading_batches"
--    in file "crt_lbr_mgmt_bats.pc".  This function modified to call
--    this procedure to create the loader batches when creating by float number.
--
--    The FLOATS table is the driving table.
--
--    Items on the float with 'M' and 'S' merge alloc flags will have the
--    case/split count put in "kvi_no_merge."
--    NOTE: Not sure what 'S' merge flag means as I saw no OpCo with 'S' merges
---------------------------------------------------------------------------
PROCEDURE create_loader_batches
         (i_route_batch_no  IN  route.route_batch_no%TYPE     DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE           DEFAULT NULL,
          i_float_no        IN  floats.float_no%TYPE          DEFAULT NULL);

---------------------------------------------------------------------------
-- Procedure:
--    update_batch_ref_no
--
-- Description:
--    This procedure updates the loader batch ref_no to the new route number.
--    It is called when a pallet is manually moved to another route.
---------------------------------------------------------------------------
PROCEDURE update_batch_ref_no
         (i_float_no        IN  floats.float_no%TYPE,
          i_new_route_no    IN  route.route_no%TYPE);

END pl_lm_loader;
/

show errors



CREATE OR REPLACE PACKAGE BODY swms.pl_lm_loader
AS

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------

gl_pkg_name   VARCHAR2(30) := $$PLSQL_UNIT;   -- Package name.  Used in error messages.


--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function CONSTANT  VARCHAR2(10) := 'LABOR';


---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------

   --
   -- This record is for recording statistics when creating labor batches.
   --  08/13/2021  Brian Bent  Took from RDC pl_lmf.sql
   --
   TYPE t_create_labor_batch_stats_rec IS RECORD
      (num_records_processed         PLS_INTEGER := 0,
       num_batches_created           PLS_INTEGER := 0,
       num_batches_existing          PLS_INTEGER := 0,
       num_not_created_due_to_error  PLS_INTEGER := 0,
       num_with_no_location          PLS_INTEGER := 0,   -- Applies only to receiving putaway batches
       num_live_receiving_location   PLS_INTEGER := 0);  -- Applies only to receiving putaway batches



---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------


-- 08/13/2021 Brian Bent Took "does_batch_exist" from RDC pl_lmc.sql
---------------------------------------------------------------------------
-- Function:
--    does_batch_exist
--
-- Description:
--    This function returns TRUE if a labor batch exists in the BATCH table
--    otherwise FALSE.
--    By default the BATCH_DATE is ignored.  The key on the BATCH table is
--    BATCH_NO and BATCH_DATE.
--
-- Parameters:
--    i_batch_no    - Labor batch number.
--    i_batch_date  - Check if created on this date.  Default value is NULL
--                    which signifies to check if the batch exists regardless
--                    of the batch date.
--                    The key on the BATCH table is BATCH_NO and BATCH_DATE.
--
-- Return Values:
--    TRUE  -  Batch exists.
--    FALSE -  Batch does not exist.
--
-- Exceptions Raised:
--    pl_exc.e_database_error  - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/26/18 bben0556 Brian Bent
--                      Created to use for forklift labor.  For forklift labor
--                      the BATCH.BATCH_NO needs to be unique.
--
---------------------------------------------------------------------------
FUNCTION does_batch_exist
             (i_batch_no    IN  batch.batch_no%TYPE,
              i_batch_date  IN  DATE DEFAULT NULL)
RETURN BOOLEAN
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'does_batch_exist';
   l_dummy         VARCHAR2(1);

BEGIN
   BEGIN
      --
      -- Note: BATCH.BATCH_DATE is stored without the time.
      --
      SELECT DISTINCT 'x' INTO l_dummy
        FROM batch
       WHERE batch.batch_no   = i_batch_no
         AND batch.batch_date = NVL(TRUNC(i_batch_date), batch.batch_date);
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
         RETURN FALSE;
   END;

   RETURN TRUE;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END does_batch_exist;


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Function:
--    is_loader_active  (public)
--
-- Description:
--    This function determines if loader labor mgmt is active.
--    Unloading labor is active when syspar LBR_MGMT_FLAG is 'Y' and
--    column create_batch_flag is 'Y' in table LBR_FUNC where
--    lfun_lbr_func = 'UL'.
--
-- Parameters:
--    none
--
-- Return Values:
--    TRUE  - forklift is active.
--    FALSE - forklift is not active.
--
-- Exceptions raised:
--    -20001  An oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/06/19 bben0556 Brian Bent
--                      Created.
--
---------------------------------------------------------------------------
FUNCTION is_loader_active
RETURN BOOLEAN IS
   l_object_name            VARCHAR2(30) := 'is_loader_active';

   l_create_batch_flag      lbr_func.create_batch_flag%TYPE := NULL;
   l_loader_active   BOOLEAN;        -- Designates if loader labor is active.
   l_sqlerrm                VARCHAR2(500);  -- SQLERRM

   --
   -- This cursor selects the create batch flag for forklift labor mgmt.
   --
   CURSOR c_lbr_func IS
      SELECT create_batch_flag
        FROM lbr_func
       WHERE lfun_lbr_func = 'LD';
BEGIN
   IF (pl_common.f_get_syspar('LBR_MGMT_FLAG', 'N') = 'Y') THEN
      --
      -- Labor mgmt is on.
      -- See if loader labor function is turned on.
      --
      OPEN c_lbr_func;
      FETCH c_lbr_func INTO l_create_batch_flag;

      IF (c_lbr_func%NOTFOUND) THEN
         l_create_batch_flag := 'N';
      END IF;

      CLOSE c_lbr_func;

      IF  (l_create_batch_flag = 'Y') THEN
         l_loader_active := TRUE;
      ELSE
         l_loader_active := FALSE;
      END IF;
   ELSE
      l_loader_active := FALSE;
   END IF;

   RETURN(l_loader_active);

EXCEPTION
   WHEN OTHERS THEN
      l_sqlerrm := SQLERRM;  -- Save mesg in case cursor cleanup fails.

      IF (c_lbr_func%ISOPEN) THEN   -- Cursor cleanup.
         CLOSE c_lbr_func;
      END IF;

      RAISE_APPLICATION_ERROR(-20001, l_object_name||' Error: ' || l_sqlerrm);
END is_loader_active;


---------------------------------------------------------------------------
-- Procedure:
--    create_loader_batches (public)
--
-- Description:
--    This procedure creates the loader labor batches at the pallet level
--    for either a wave, route, float or task.
--
--    This is a PL/SQL version of function "create_loading_batches"
--    in file "crt_lbr_mgmt_bats.pc".  This function modified to call
--    this procedure to create the loader batches when creating by float number.
--
--    The FLOATS table is the driving table.
--
--    Items on the float with 'M' and 'S' merge alloc flags will have the
--    case/split count put in "kvi_no_merge."
--    NOTE: Not sure what 'S' merge flag means as I saw no OpCo with 'S' merges
--
-- Parameters:
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number (wave) to process.
--    i_float_no         - The float to create the batch for.
--    NOTE: One and only one parameters i_route_batch_no, i_route_no
--          and i_float_no can be populated.
--
-- Called by:
--    xxx
--
-- Exceptions raised:
--    pl_exc.ct_data_error     - Bad combination of parameters.
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/05/19 bben0556 Created to replace PRO*C creating loader
--                      by float number.   "crt_lbr_mgmt_bats.pc"
--                      will be changed to call this procedure.
--
--                      "crt_lbr_mgmt_bats.pc" was creating loader batches
--                      for the primary pallet of a merge selection.
--                      This pallet is never loaded onto the truck so
--                      this procdedure will not create a loader batch
--                      for the primary pallet.
--
--    10/30/19 bben0556 Brian Bent
--                      Project: S4R-Jira-Story_xxxx_Loader_labor_mgmt_batch_ref_no_sometimes_incorrect
--
--                      For the RDC--when creating the loader labor mgmt batch put route.route_no in the
--                      batch.ref_no instead of route.truck_no.  The route.truck_no is set to the
--                      route.route_no but to be more direct lets just use the route.route_no
--                      for batch.ref_no (though I don't believe this resolves the issue).
--
---------------------------------------------------------------------------
PROCEDURE create_loader_batches
         (i_route_batch_no  IN  route.route_batch_no%TYPE     DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE           DEFAULT NULL,
          i_float_no        IN  floats.float_no%TYPE          DEFAULT NULL)
IS
   l_object_name   VARCHAR2(30)   := 'create_loader_batches';
   l_message       VARCHAR2(256);

   l_num_pieces            PLS_INTEGER;
   l_total_cube            NUMBER;
   l_total_wt              NUMBER;

   l_tmp  varchar2(200);

   l_r_create_batch_stats  t_create_labor_batch_stats_rec;   -- Keep track of how many batches created,


   e_parameter_bad_combination  EXCEPTION;  -- Bad combination of parameters.
   e_batch_already_exists       EXCEPTION;  -- Batch already exists.


   --
   -- This cursor selects the FLOATS to create loader batches for.
   -- Either the specified wave, route, float or task.
   --
   -- For merge pulls no labor batch is created for the primary float as
   -- it this float is not loaded onto a truck.
   --
   CURSOR c_floats(cp_route_batch_no  route.route_batch_no%TYPE,
                   cp_route_no        route.route_no%TYPE,
                   cp_float_no        floats.float_no%TYPE)
   IS
   SELECT sm.load_job_code                                            load_job_code,
          'L' || LTRIM(TO_CHAR(f.float_no))                           loader_labor_batch_no,
          f.float_no                                                  float_no,
          --
          SUM(DECODE(d.merge_alloc_flag,
                     'M', 0,
                     'S', 0,
                     DECODE(uom, 1, d.qty_alloc, 0)))                 num_splits,
          --
          SUM(DECODE(d.merge_alloc_flag,
                     'M', 0,
                     'S', 0,
                     DECODE(uom, 2, d.qty_alloc / NVL(p.spc, 1),
                            NULL, d.qty_alloc / NVL(p.spc, 1), 0)))   num_cases,
          --
          SUM(DECODE(d.merge_alloc_flag,
                     'M', DECODE(uom, 2, d.qty_alloc / NVL(p.spc,1), 1, d.qty_alloc, 0),
                     'S', DECODE(uom, 2, d.qty_alloc / NVL(p.spc,1), 1, d.qty_alloc, 0),
                     0))                                                                             num_merges,
          --
          COUNT(DISTINCT d.float_no)                                                                 num_floats,
          SUM(DECODE(p.catch_wt_trk, 'Y', DECODE(uom, 1, d.qty_alloc, d.qty_alloc/NVL(spc, 1)),0))   num_data_captures,
          SUM(DECODE(uom, 1, d.qty_alloc * (p.g_weight / NVL(p.spc,1)), 0))                          split_wt,
          SUM(DECODE(uom, 1, d.qty_alloc * p.split_cube, 0))                                         split_cube,
          SUM(DECODE(uom, 2, d.qty_alloc * (p.g_weight/NVL(p.spc, 1)), NULL, d.qty_alloc * (p.g_weight / NVL(p.spc,1)), 0))    case_wt,
          SUM(DECODE(uom, 2, (d.qty_alloc / NVL(p.spc,1)) * p.case_cube, NULL, (d.qty_alloc / NVL(p.spc,1)) * p.case_cube, 0)) case_cube,
          --
          COUNT(DISTINCT d.prod_id || d.cust_pref_vendor)                    num_items,
          --
          -- If a RDC the reference number is the route number.
          -- 10/30/19 Brian Bent Changed to look at the IS_RDC syspar.
          -- DECODE(COUNT(DISTINCT r.truck_no), 1, MIN(r.truck_no), 'MULTIPLE') reference,  -- Should never be MULTIPLE since we create by float
          DECODE(is_rdc_syspar.config_flag_val, 'Y', MIN(r.route_no),
                 DECODE(COUNT(DISTINCT r.truck_no), 1, MIN(r.truck_no), 'MULTIPLE')) reference,  -- Should never be MULTIPLE since we create by float
          --
          COUNT(DISTINCT f.route_no)                                         num_routes, -- Should always be 1
          f.float_seq                                                        float_seq
     FROM job_code j,
          sel_method sm,
          pm p,
          float_detail d,
          floats f,
          route r,
          --
          (SELECT NVL(MAX(config_flag_val), 'N') config_flag_val
             FROM sys_config
            WHERE config_flag_name = 'IS_RDC') is_rdc_syspar
          --
    WHERE j.lfun_lbr_func    = 'LD'
      AND j.jbcd_job_code    = sm.load_job_code
      AND sm.group_no        = f.group_no
      AND sm.method_id       = r.method_id
      AND p.prod_id          = d.prod_id
      AND p.cust_pref_vendor = d.cust_pref_vendor
      AND d.float_no         = f.float_no
      AND f.route_no         = r.route_no
      --
      AND NVL(f.merge_loc, '???') = '???'        -- Only the pallets to load on trucks.  Leave out the merge pallet.
                                                 -- 10-APR-2019 Brian Bent The RDC code is not populating FLOATS.MERGE_LOC.
                                                 -- Maybe be should to keep it consistent with the OpCo ?
      --
      -- For the RDC we create loader batches for VRTs.
      AND (   is_rdc_syspar.config_flag_val = 'N' AND f.pallet_pull not in ('D', 'R')
           OR is_rdc_syspar.config_flag_val = 'Y' AND f.pallet_pull not in ('R'))
      --
      AND (   r.route_batch_no  = cp_route_batch_no
           OR r.route_no        = cp_route_no
           OR f.float_no        = cp_float_no)
      --
    GROUP BY sm.load_job_code, f.float_no, f.float_seq, is_rdc_syspar.config_flag_val
    ORDER BY sm.load_job_code, f.float_no, f.float_seq;
BEGIN
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                     || '  (i_route_batch_no['   || TO_CHAR(i_route_batch_no) || '],'
                     || 'i_route_no['            || i_route_no                || '],'
                     || 'i_float_no['            || TO_CHAR(i_float_no)       || '])'
                     || '  This procedure creates the loader labor batches.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');


   --
   -- Check the parameters.
   -- One and only one of i_route_batch_no, i_route_no and i_float_no can be populated.
   -- The IF conditions returns only one 'x' when only one of the parameters is populated.
   -- ...  This works as long as one of the parameetrs valae is not actually an 'x' which
   -- should never happend
   --
   IF (    (CASE WHEN TO_CHAR(i_route_batch_no)  IS NULL THEN NULL ELSE 'x' END)
        || (CASE WHEN i_route_no                 IS NULL THEN NULL ELSE 'x' END)
        || (CASE WHEN TO_CHAR(i_float_no)        IS NULL THEN NULL ELSE 'x' END) = 'x')
   THEN
      NULL;  -- Parameter check OK.
   ELSE
      RAISE e_parameter_bad_combination;
   END IF;

   --
   -- Initialize the counts.
   --
   l_r_create_batch_stats.num_records_processed        := 0;
   l_r_create_batch_stats.num_batches_created          := 0;
   l_r_create_batch_stats.num_batches_existing         := 0;
   l_r_create_batch_stats.num_not_created_due_to_error := 0;

   FOR r_floats IN c_floats(i_route_batch_no, i_route_no, i_float_no)
   LOOP
      l_r_create_batch_stats.num_records_processed := l_r_create_batch_stats.num_records_processed + 1;

      /*****  Don't log each float processed, creates to many messages, I guess
      pl_log.ins_msg
                (i_msg_type         => pl_log.ct_info_msg,
                 i_procedure_name   => l_object_name,
                 i_msg_text         => 'Processing float[' || TO_CHAR(r_bulk_fork.float_no) || ']'
                                || '  pallet pull[' || r_bulk_fork.pallet_pull || ']',
                 i_msg_no           => NULL,
                 i_sql_err_msg      => NULL,
                 i_application_func => ct_application_function,
                 i_program_name     => gl_pkg_name,
                 i_msg_alert        => 'N');
      *****/

      --
      -- Start new block to trap errors.
      --
      BEGIN
         SAVEPOINT sp_loader;   -- Rollback to here if an error so the error affects only one batch.

         --
         --  Check if the labor batch already exists.
         --
         IF (does_batch_exist(r_floats.loader_labor_batch_no) = TRUE) THEN
            RAISE e_batch_already_exists;
         END IF;


         l_num_pieces := r_floats.num_cases + r_floats.num_splits + r_floats.num_merges;
         l_total_cube := r_floats.case_cube + r_floats.split_cube;
         l_total_wt   := r_floats.case_wt + r_floats.split_wt;

         INSERT INTO batch
                           (batch_no,
                            batch_date,
                            status,
                            jbcd_job_code,
                            user_id,
                            ref_no,
                            kvi_cube,
                            kvi_wt,
                            kvi_no_merge,
                            kvi_no_piece,
                            kvi_no_case,
                            kvi_no_split,
                            kvi_no_pallet,
                            kvi_no_data_capture,
                            kvi_no_item,
                            kvi_doc_time,
                            cmt)
                   SELECT
                          r_floats.loader_labor_batch_no   batch_no,
                          TRUNC(SYSDATE)                   batch_date,
                          'X'                              status,
                          r_floats.load_job_code           jbcd_job_code,
                          NULL                             user_id,
                          r_floats.reference               ref_no,
                          l_total_cube                     kvi_cube,
                          l_total_wt                       kvi_wt,
                          r_floats.num_merges              kvi_no_merge,
                          l_num_pieces                     kvi_no_piece,
                          r_floats.num_cases               kvi_no_case,
                          r_floats.num_splits              kvi_no_split,
                          r_floats.num_floats              kvi_no_pallet,
                          r_floats.num_data_captures       kvi_no_data_capture,
                          r_floats.num_items               kvi_no_item,
                          1                                kvi_doc_time,
                          r_floats.float_seq               cmt
                     FROM DUAL;

         --
         -- Set the goal/target time for the batch.
         --
         pl_lm_time.load_goaltime(r_floats.loader_labor_batch_no);

         l_r_create_batch_stats.num_batches_created := l_r_create_batch_stats.num_batches_created + 1;

      EXCEPTION
         WHEN DUP_VAL_ON_INDEX OR e_batch_already_exists THEN
            --
            -- Batch already exists.  This is OK because this procedure
            -- could have been run again for the same data.
            --
            l_r_create_batch_stats.num_batches_existing := l_r_create_batch_stats.num_batches_existing + 1;
         WHEN OTHERS THEN
            --
            -- There was an error creating the labor batch(s) log a message and rollback to savepoint.
            --
            pl_log.ins_msg
                (i_msg_type         => pl_log.ct_info_msg,
                 i_procedure_name   => l_object_name,
                 i_msg_text         => 'Error creating loader labor batch for float[' || TO_CHAR(r_floats.float_no) || ']'
                                         || '  Skip it.',
                 i_msg_no           => SQLCODE,
                 i_sql_err_msg      => SQLERRM,
                 i_application_func => ct_application_function,
                 i_program_name     => gl_pkg_name,
                 i_msg_alert        => 'N');

            ROLLBACK TO sp_loader;   -- Rollback to here if an error so the error affects only one batch.

            l_r_create_batch_stats.num_not_created_due_to_error := l_r_create_batch_stats.num_not_created_due_to_error + 1;
      END;
   END LOOP;

   --
   -- Log when done.  Note that if there is an exception this message can be bypassed.
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                     || '  (i_route_batch_no['  || TO_CHAR(i_route_batch_no)  || ']'
                     || ',i_route_no['          || i_route_no                 || ']'
                     || ',i_float_no['          || TO_CHAR(i_float_no)        || '])'
                     || '  num_records_processed['        || TO_CHAR(l_r_create_batch_stats.num_records_processed)        || ']'
                     || '  num_batches_created['          || TO_CHAR(l_r_create_batch_stats.num_batches_created)          || ']'
                     || '  num_batches_existing['         || TO_CHAR(l_r_create_batch_stats.num_batches_existing)         || ']'
                     || '  num_not_created_due_to_error[' || TO_CHAR(l_r_create_batch_stats.num_not_created_due_to_error) || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
EXCEPTION
   WHEN e_parameter_bad_combination THEN
      --
      -- One and only one of i_route_batch_no, i_route_no and i_float_no can be populated.
      --
      l_message := '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
                   || 'i_route_no['     || i_route_no                || '],'
                   || 'i_float_no['     || TO_CHAR(i_float_no)       || '])'
                   || '  One and only one of the parameters can have a value.';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                     l_message, pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                         '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
                         || 'i_route_no['     || i_route_no                || '],'
                         || 'i_float_no['     || TO_CHAR(i_float_no)       || '])',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END create_loader_batches;


---------------------------------------------------------------------------
-- Procedure:
--    update_batch_ref_no
--
-- Description:
--    This procedure updates the loader batch ref_no to the new route number.
--    It is called when a pallet is manually moved to another route.
--
-- Parameters:
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number (wave) to process.
--    i_float_no         - The float to create the batch for.
--    NOTE: One and only one parameters i_route_batch_no, i_route_no
--          and i_float_no can be populated.
--
-- Called by:
--    xxx
--
-- Exceptions raised:
--    None.  A message is logged.  We do not want to stop processing
--    if an error occurs.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/31/19 bben0556 Created
---------------------------------------------------------------------------
PROCEDURE update_batch_ref_no
         (i_float_no        IN  floats.float_no%TYPE,
          i_new_route_no    IN  route.route_no%TYPE)
IS
   l_object_name   VARCHAR2(30)   := 'update_batch_ref_no';
   l_message       VARCHAR2(256);
   l_parameters    VARCHAR2(128);   -- Used in log messages

   l_add_date            arch_batch.batch_add_date%TYPE;     -- Used in log messages
   l_batch_no            arch_batch.batch_no%TYPE;           -- Loader labor mgmt batch number
   l_current_ref_no      arch_batch.ref_no%TYPE;             -- Used in log messages
   l_parent_batch_no     arch_batch.parent_batch_no%TYPE;    -- Used in log messages
   l_status              arch_batch.status%TYPE;             -- Used in log messages

   --
   -- This cursor is used to get the current batch ref_no to use in a log message.
   --
   CURSOR c_current_ref_no(cp_batch_no  arch_batch.batch_no%TYPE)
   IS
   SELECT b.ref_no,
          b.parent_batch_no,
          b.status,
          b.add_date
     FROM batch b
    WHERE b.batch_no = cp_batch_no;
BEGIN
   --
   -- This used in log messages.
   --
   l_parameters := '(i_float_no['        || TO_CHAR(i_float_no)  || '],'
                   || 'i_new_route_no['  || i_new_route_no       || '])';

   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                     || l_parameters
                     || '  This procedure updates loader batch ref# to the'
                     || ' new route number when a pallet is moved to a different route.'
                     || '  It is called only when a pallet is manually moved and not by optimization.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Build the batch number.  The format is 'L' || float number.
   --
   l_batch_no :=  'L' || TRIM(TO_CHAR(i_float_no));

   --
   -- Get the current value of ref_no so we can log it.
   --
   OPEN c_current_ref_no(l_batch_no);
   FETCH c_current_ref_no INTO l_current_ref_no,
                               l_parent_batch_no,
                               l_status,
                               l_add_date;

   IF (c_current_ref_no%NOTFOUND) THEN
      --
      -- Did not loader batch.  Log a message but do not stop processing.
      -- We will not consider this a fatal error.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         =>
                      'TABLE=batch  ACTION=SELECT'
                   || '  KEY=[' || l_batch_no || '](l_batch_no)'
                   || '  MESSAGE="Batch not in batch table.  This will not stop processing but'
                   || ' the batch.ref_no will not get updated."',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      CLOSE c_current_ref_no;
   ELSE
      --
      -- Selected the loader batch.
      --
      CLOSE c_current_ref_no;

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Info about the batch:'
                         || '  batch_no['        || l_batch_no        || ']'
                         || '  parent_batch_no[' || l_parent_batch_no || ']'
                         || '  status['          || l_status          || ']'
                         || '  current_ref_no['  || l_current_ref_no  || ']'
                         || '  add_date['        || TO_CHAR(l_add_date, 'DD-MON-YYYY HH24:MI:SS') || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      UPDATE batch
         SET ref_no = i_new_route_no
       WHERE batch_no = l_batch_no;

      IF (SQL%NOTFOUND) THEN
         --
         -- Did not find the loader batch to update.  Log a message but do not stop processing.
         -- We will not consider this a fatal error.
         --
         pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         =>
                      'TABLE=batch  ACTION=UPDATE'
                   || '  KEY=[' || l_batch_no || '](l_batch_no)'
                   || '  MESSAGE="Did not find the batch to update.  This will not stop processing but'
                   || ' the batch.ref_no will not get updated."',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
      ELSE
         --
         -- Loader batch ref_no updated successfully.
         --
         pl_log.ins_msg
             (i_msg_type         => pl_log.ct_info_msg,
              i_procedure_name   => l_object_name,
              i_msg_text         => 'Labor batch updated.'
                         || '  batch_no[' || l_batch_no || ']'
                         || '  ref_no changed from['  || l_current_ref_no  || ']'
                         || '  to['      || i_new_route_no    || ']',
              i_msg_no           => NULL,
              i_sql_err_msg      => NULL,
              i_application_func => ct_application_function,
              i_program_name     => gl_pkg_name,
              i_msg_alert        => 'N');
      END IF;
   END IF;

   --
   -- Log endign the procedure.
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                     || l_parameters,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.  Log a message but do not propagate the error.
      -- We will not consider this a fatal error.
      --
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_warn_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_parameters ||  '  Error updating the batch.'
                   || '  This will not stop processing but'
                   || ' the batch.ref_no will not get updated.',
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

END update_batch_ref_no;



END pl_lm_loader;
/

show errors


CREATE OR REPLACE PUBLIC SYNONYM pl_lm_loader FOR swms.pl_lm_loader;
GRANT EXECUTE ON swms.pl_lm_loader TO SWMS_USER;