
SET SCAN OFF

PROMPT Create package specification: pl_lm_time

/**************************************************************************/
-- Package Specification
/**************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_lm_time
AS

   -- sccs_id=@(#) src/schema/plsql/pl_lm_time.sql, swms, swms.9, 10.1.1 10/5/06 1.4

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lm_time
   --
   -- Description:
   --    Set the batch goal/target time for labor mgmt batches.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    02/04/04 prpbcb   Oracle 8 rs239b swms8 DN None
   --                      Oracle 8 rs239b swms9 DN 11741
   --                      PL/SQL package version of the selection labor mgmt
   --                      functions in PRO*C program lm_down.pc.
   --                      Initially created to use with discrete selection
   --                      but installed before discrete selection to use
   --                      for return labor mgmt.
   --
   --                      Old History:
   --                      09/13/04 prpbcb  Change procedure load_goaltime to
   --                      accept another parameter which designates to only
   --                      calculate the goal/target time.  The current status
   --                      of the batch is ignored.
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
   -- Procedure:
   --    load_goaltime
   --
   -- Description:
   --    This procedure updates the labor mgmt batch goal/target time for a
   --    batch based on the batch kvi values and the job code tmu values.
   --    When parameter i_ignore_status_bln is null or not specified then the
   --    status of the batch must be 'X' which will then be updated to 'F'.
   --    If parameter i_ignore_status_bln is true then the status of the batch
   --    is ignored and not changed.
   --
   --    The bulk of the calculation of the goal/target time is done in
   --    views.
   ---------------------------------------------------------------------------
   PROCEDURE load_goaltime(i_lm_batch_no        IN arch_batch.batch_no%TYPE,
                           i_ignore_status_bln  IN BOOLEAN  DEFAULT FALSE,
                           i_batch_operation    IN VARCHAR2 DEFAULT NULL);

END  pl_lm_time;  -- end package specification
/

SHOW ERRORS;

PROMPT Create package body: pl_lm_time

/**************************************************************************/
-- Package Body
/**************************************************************************/
CREATE OR REPLACE PACKAGE BODY swms.pl_lm_time
IS
   -- sccs_id=@(#) src/schema/plsql/pl_lm_time.sql, swms, swms.9, 10.1.1 10/5/06 1.4

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lm_time
   --
   -- Description:
   --    Set the batch goal/target time.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    02/21/02 prpbcb   rs239a DN 10859  rs239b DN 10860  Created.  
   --                      PL/SQL package version of the selection labor mgmt
   --                      functions in PRO*C program lm_down.pc.
   --                      Initially created to use with discrete selection.
   ---------------------------------------------------------------------------


   ---------------------------------------------------------------------------
   -- Private Global Variables
   ---------------------------------------------------------------------------
   gl_pkg_name   VARCHAR2(20) := 'pl_lm_time';   -- Package name.  Used in
                                                 -- error messages.


   ---------------------------------------------------------------------------
   -- Private Constants
   ---------------------------------------------------------------------------


   ---------------------------------------------------------------------------
   -- Private Modules
   ---------------------------------------------------------------------------

   ------------------------------------------------------------------------
   -- Function:
   --    f_get_non_merge_batch_time
   --
   -- Description:
   --    This function returns the batch time in minutes for a non merge batch.
   --
   -- Parameters:
   --    i_lm_batch_no   - Labor mgmt batch number.
   --
   -- Return value:
   --    - The batch time in minutes.
   --   
   -- Exceptions raised:
   --    pl_exc.e_no_lm_batch_found  - Could not find the batch.
   --    pl_exc.ct_database_error    - Any other error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    02/27/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   FUNCTION f_get_non_merge_batch_time
               (i_lm_batch_no IN arch_batch.batch_no%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(128);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                            '.f_get_non_merge_batch_time';

      -- This cursor gets the batch time for the labor mgmt batch.
      -- The time is calculated in a view.
      CURSOR c_batch_time IS
         SELECT batch_time_in_minutes
           FROM v_non_merge_batch_time
          WHERE batch_no = i_lm_batch_no;

      l_r_batch  c_batch_time%ROWTYPE;

   BEGIN

      l_message_param := l_object_name ||
         '(i_lm_batch_no=[' || i_lm_batch_no || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_batch_time;
      FETCH c_batch_time INTO l_r_batch;

      IF (c_batch_time%NOTFOUND) THEN
         CLOSE c_batch_time;
         RAISE pl_exc.e_no_lm_batch_found;
      END IF; 

      CLOSE c_batch_time;

      RETURN(l_r_batch.batch_time_in_minutes);

   EXCEPTION
      WHEN pl_exc.e_no_lm_batch_found THEN
         l_message := l_object_name || '(i_lm_batch_no[' || i_lm_batch_no ||
                       '])   Could not find batch.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_get_non_merge_batch_time;


   ------------------------------------------------------------------------
   -- Function:
   --    f_get_merge_batch_time
   --
   -- Description:
   --    This function returns the batch time in minutes for a non merge batch.
   --
   -- Parameters:
   --    i_lm_batch_no   - Labor mgmt batch number.
   --
   -- Return value:
   --    - The batch time in minutes.
   --   
   -- Exceptions raised:
   --    pl_exc.e_no_lm_batch_found  - Could not find the batch.
   --    pl_exc.ct_database_error    - Any other error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    02/27/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   FUNCTION f_get_merge_batch_time
               (i_lm_batch_no IN arch_batch.batch_no%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(128);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                         '.f_get_merge_batch_time';

      -- This cursor gets the batch time for the labor mgmt batch.
      -- The time is calculated in a view.
      CURSOR c_batch_time IS
         SELECT batch_time_in_minutes
           FROM v_merge_batch_time
          WHERE parent_batch_no = i_lm_batch_no;

      l_r_batch  c_batch_time%ROWTYPE;

   BEGIN

      l_message_param := l_object_name ||
         '(i_lm_batch_no=[' || i_lm_batch_no || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_batch_time;
      FETCH c_batch_time INTO l_r_batch;

      IF (c_batch_time%NOTFOUND) THEN
         CLOSE c_batch_time;
         RAISE pl_exc.e_no_lm_batch_found;
      END IF; 

      CLOSE c_batch_time;

      RETURN(l_r_batch.batch_time_in_minutes);

   EXCEPTION
      WHEN pl_exc.e_no_lm_batch_found THEN
         l_message := l_object_name || '(i_lm_batch_no=[' || i_lm_batch_no ||
                       '])   Could not find batch.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_get_merge_batch_time;


   ------------------------------------------------------------------------
   -- Function:
   --    f_get_ds_non_merge_batch_time
   --
   -- Description:
   --    This function returns the batch time in minutes for a discrete
   --    selection non merge batch.
   --
   -- Parameters:
   --    i_lm_batch_no   - Labor mgmt batch number.
   --
   -- Return value:
   --    - The batch time in minutes.
   --   
   -- Exceptions raised:
   --    pl_exc.e_no_lm_batch_found  - Could not find the batch.
   --    pl_exc.ct_database_error    - Any other error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    02/27/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   FUNCTION f_get_ds_non_merge_batch_time
               (i_lm_batch_no IN arch_batch.batch_no%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(128);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                           '.f_get_ds_non_merge_batch_time';

      -- This cursor gets the batch time for a discrete selection
      -- non merge batch.  The time is calculated in a view.
      CURSOR c_batch_time IS
         SELECT batch_time_in_minutes
           FROM v_ds_non_merge_batch_time
          WHERE batch_no = i_lm_batch_no;

      l_r_batch  c_batch_time%ROWTYPE;

   BEGIN

      l_message_param := l_object_name ||
         '(i_lm_batch_no=[' || i_lm_batch_no || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_batch_time;
      FETCH c_batch_time INTO l_r_batch;

      IF (c_batch_time%NOTFOUND) THEN
         CLOSE c_batch_time;
         RAISE pl_exc.e_no_lm_batch_found;
      END IF; 

      CLOSE c_batch_time;

      RETURN(l_r_batch.batch_time_in_minutes);

   EXCEPTION
      WHEN pl_exc.e_no_lm_batch_found THEN
         l_message := l_object_name || '(i_lm_batch_no=[' || i_lm_batch_no ||
                       '])   Could not find batch.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_get_ds_non_merge_batch_time;


   ------------------------------------------------------------------------
   -- Function:
   --    f_get_ds_merge_batch_time
   --
   -- Description:
   --    This function returns the batch time in minutes for a discrete
   --    selection merge (parent) batch.
   --
   -- Parameters:
   --    i_lm_batch_no   - Labor mgmt batch number.
   --
   -- Return value:
   --    - The batch time in minutes.
   --   
   -- Exceptions raised:
   --    pl_exc.e_no_lm_batch_found  - Could not find the batch.
   --    pl_exc.ct_database_error    - Any other error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    02/27/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   FUNCTION f_get_ds_merge_batch_time
               (i_lm_batch_no IN arch_batch.batch_no%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(128);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                           '.f_get_ds_merge_batch_time';

      -- This cursor gets the batch time for a discrete selection merged batch.
      -- The time is calculated in a view.
      CURSOR c_batch_time IS
         SELECT batch_time_in_minutes
           FROM v_ds_merge_batch_time
          WHERE parent_batch_no = i_lm_batch_no;

      l_r_batch  c_batch_time%ROWTYPE;

   BEGIN
      l_message_param := l_object_name ||
         '(i_lm_batch_no=[' || i_lm_batch_no || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_batch_time;
      FETCH c_batch_time INTO l_r_batch;

      IF (c_batch_time%NOTFOUND) THEN
         CLOSE c_batch_time;
         RAISE pl_exc.e_no_lm_batch_found;
      END IF; 

      CLOSE c_batch_time;

      RETURN(l_r_batch.batch_time_in_minutes);

   EXCEPTION
      WHEN pl_exc.e_no_lm_batch_found THEN
         l_message := l_object_name || '(i_lm_batch_no=[' || i_lm_batch_no ||
                       '])   Could not find batch.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_get_ds_merge_batch_time;


   ------------------------------------------------------------------------
   -- Function:
   --    f_get_batch_time
   --
   -- Description:
   --    This function returns the batch time for a labor mgmt batch.
   --
   -- Parameters:
   --    i_lm_batch_no   - Labor mgmt batch number.
   --    i_merge_batch   - Designates if the labor mgmt batch is a merge
   --                      (parent) batch or not merged batch.
   --                      Valid values are NONMERGED and MERGED.
   --    i_batch_operation - Type of batch operation.
   --                        Some batch types are:
   --                           - discrete selection
   --                           - regular selection
   --                           - forklift
   --
   -- Return value:
   --    - The batch time in minutes.
   --   
   -- Exceptions raised:
   --    pl_exc.e_data_error
   --    pl_exc.e_database_error  - Oracle error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    02/20/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   FUNCTION f_get_batch_time
               (i_lm_batch_no      IN arch_batch.batch_no%TYPE,
                i_merge_batch      IN VARCHAR2,
                i_batch_operation  IN VARCHAR2 := NULL)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_batch_time';

      l_batch_time         NUMBER;

      e_invalid_parameter  EXCEPTION;   -- Invalid value for i_merge_batch.

   BEGIN
      l_message_param := l_object_name ||
         '(i_lm_batch_no=[' || i_lm_batch_no || ']' ||
         ' i_merge_batch=[' || i_merge_batch || ']' ||
         ' i_batch_operation=[' || i_batch_operation || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      IF (i_merge_batch NOT IN ('NONMERGED','MERGED')) THEN
            RAISE e_invalid_parameter;
      END IF;

      IF (i_batch_operation = pl_lmc.ct_ds) THEN
         -- Dynamic selection batch.
         IF (i_merge_batch = 'NONMERGED') THEN
            l_batch_time := f_get_ds_non_merge_batch_time(i_lm_batch_no);
         ELSE
            l_batch_time := f_get_ds_merge_batch_time(i_lm_batch_no);
         END IF;
      ELSE
         IF (i_merge_batch = 'NONMERGED') THEN
            l_batch_time := f_get_non_merge_batch_time(i_lm_batch_no);
         ELSE
            l_batch_time := f_get_merge_batch_time(i_lm_batch_no);
         END IF;
      END IF;
    
      RETURN(l_batch_time);

   EXCEPTION
      WHEN e_invalid_parameter THEN
         l_message := l_object_name ||
            'i_lm_batch_no=[' || i_lm_batch_no || ']' ||
            ' Invalid value for i_merge_batch=[' || i_merge_batch;
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
            -- RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
            --                         l_object_name || ': ' || SQLERRM);
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_get_batch_time;


   -- end of private modules

   ---------------------------------------------------------------------------
   ---------------------------------------------------------------------------
   ---------------------------------------------------------------------------


   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ------------------------------------------------------------------------
   -- Procedure:
   --    load_goaltime
   --
   -- Description:
   --    This procedure updates the labor mgmt batch goal/target time for a
   --    batch based on the batch kvi values and the job code tmu values.
   --    When parameter i_ignore_status_bln is null or not specified then the
   --    status of the batch must be 'X' which will then be updated to 'F'.
   --    If parameter i_ignore_status_bln is true then the status of the batch
   --    is ignored and not changed.
   --
   --    The bulk of the calculation of the goal/target time is done in
   --    views.
   --
   -- Parameters:
   --    i_lm_batch_no       - Labor mgmt batch number.
   --    i_ignore_status_bln - Desginates if to ignore the status of the batch.
   --    i_batch_operation   - Type of batch.  This is optional except for
   --                          discrete selection.  The values to use are
   --                          constants defined in pl_lmc such as pl_lmc.ct.ds.
   --                          Some batch types are:
   --                            - discrete selection
   --                            - regular selection
   --                            - forklift
   --
   -- Exceptions raised:
   --    pl_exc.ct_data_error      - Unable to update the batch.
   --    pl_exc.ct_database_error  - Any other error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    02/20/02 prpbcb   Created.
   --                      As of this time i_batch_operation is only used for
   --                      discrete selection.  If not a discrete selection
   --                      batch then i_batch_operation can be null or not 
   --                      specified in the parameter list.
   --    09/13/04 prpbcb   Changed procedure to accept another parameter which
   --                      designates to only calculate the goal/target time.
   --                      The current status of the batch is ignored.
   ---------------------------------------------------------------------------
   PROCEDURE load_goaltime(i_lm_batch_no        IN arch_batch.batch_no%TYPE,
                           i_ignore_status_bln  IN BOOLEAN  DEFAULT FALSE,
                           i_batch_operation    IN VARCHAR2 DEFAULT NULL)
   IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(60) := gl_pkg_name || '.load_goaltime';

      l_buf              VARCHAR2(20); -- Work area
      l_goal_time        NUMBER;
      l_print_goal_flag  lbr_func.print_goal_flag%TYPE;
      l_standard         NUMBER;   -- Work area for the batch time.
      l_target_time      NUMBER;
      l_update_status_flag VARCHAR2(1);  -- Work area with the value based on
                                         -- the value of i_ignore_status_bln.
                                         -- It is used in the update statement
                                         -- it controlling if the status is
                                         -- updated bacause i_ignore_status_bln
                                         -- is a boolean which cannot be used.

      e_bad_batch_status   EXCEPTION;  -- Batch status not 'X'

      -- This cursor selects information about the batch.
      CURSOR c_batch_rec(cp_batch_no  arch_batch.batch_no%TYPE) IS
         SELECT batch_no, 
                jbcd_job_code, 
                status,
                ref_no,
                parent_batch_no 
           FROM batch
          WHERE batch_no = cp_batch_no;

      -- This cursor select the print_goal flag for a job code.
      CURSOR c_print_goal_flag(cp_jbcd_job_code job_code.jbcd_job_code%TYPE) IS
         SELECT NVL(lf.print_goal_flag, 'Y') 
           FROM lbr_func lf, job_code jc
          WHERE jc.lfun_lbr_func = lf.lfun_lbr_func
            AND jc.jbcd_job_code = cp_jbcd_job_code;

      -- This cursor selects information about the job code.
      CURSOR c_job_code_rec(cp_jbcd_job_code  job_code.jbcd_job_code%TYPE) IS
         SELECT jbcd_job_code, 
                engr_std_flag
           FROM job_code
          WHERE jbcd_job_code = cp_jbcd_job_code;

      l_r_batch        c_batch_rec%ROWTYPE;
      l_r_job_code     c_job_code_rec%ROWTYPE;

   BEGIN

      IF (i_ignore_status_bln) THEN
         l_buf := 'TRUE';
      ELSE
         l_buf := 'FALSE';
      END IF;

      l_message_param := l_object_name || '(' || i_lm_batch_no ||
                   ' ,i_ignore_status_bln=[' || l_buf ||
                   ' ,i_batch_operation=[' || i_batch_operation || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Select the batch record.
      OPEN c_batch_rec(i_lm_batch_no);
      FETCH c_batch_rec INTO l_r_batch;

      IF (c_batch_rec%NOTFOUND) THEN
         CLOSE c_batch_rec;
         l_message := l_object_name ||
                      ' TABLE=batch  ACTION=SELECT' ||
                      ' i_lm_batch_no=[' || i_lm_batch_no || ']' ||
                      ' MESSAGE="Did not find the batch number."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_no_lm_batch_found, NULL);
         RAISE pl_exc.e_no_lm_batch_found;
      END IF;

      CLOSE c_batch_rec;

      -- The status of the batch has to be 'X'.  Only check when not ignoring
      -- the batch status.
      IF (NOT i_ignore_status_bln AND l_r_batch.status != 'X') THEN
         RAISE e_bad_batch_status;
      END IF;

      -- Get the print goal flag.
      OPEN c_print_goal_flag(l_r_batch.jbcd_job_code);
      FETCH c_print_goal_flag INTO l_print_goal_flag;

      IF (c_print_goal_flag%NOTFOUND) THEN
         l_message := 'TABLE=lbr_func,job_code  ACTION=SELECT' ||
            ' i_lm_batch_no=' || i_lm_batch_no ||
            '  MESSAGE="Failed to select the print_goal_flag.' ||
            '  Will use Y as the value"';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM);
         l_print_goal_flag := 'Y';
      END IF;

      CLOSE c_print_goal_flag;

      -- Select the job code record for the batch.
      OPEN c_job_code_rec(l_r_batch.jbcd_job_code);
      FETCH c_job_code_rec INTO l_r_job_code;

      IF (c_job_code_rec%NOTFOUND) THEN
         CLOSE c_job_code_rec;
         l_message := 'TABLE=job_code  ACTION=SELECT' ||
            '  job_code=' || l_r_batch.jbcd_job_code ||
            '  MESSAGE="Did not find the job code."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, 
                        l_message, pl_exc.ct_lm_jobcode_not_found, NULL);
         RAISE pl_exc.e_lm_jobcode_not_found;
      END IF;

      CLOSE c_job_code_rec;

      -----------------------------------
      -- Calculate the goal/target time.
      -----------------------------------
      l_standard := 0;

      IF (NVL(l_r_batch.ref_no, 'x') != 'MULTI') THEN
          -- Not a pre-merged batch.
          l_standard := f_get_batch_time(l_r_batch.batch_no, 'NONMERGED',
                                         i_batch_operation);
      ELSE
          -- A pre-merged batch.
          -- Need to update the parent_batch_no of the parent batch. 
          UPDATE batch
             SET parent_batch_no = l_r_batch.batch_no
           WHERE batch_no = l_r_batch.batch_no;

          -- Need to have updated 1 record.
          IF (SQL%NOTFOUND) THEN
            l_message := l_object_name ||
               ' TABLE=batch  ACTION=SELECT' ||
               ' i_lm_batch_no=' || l_r_batch.batch_no ||
               '  MESSAGE="Batch not found when attempting to update parent_batch_no column".';

            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           pl_exc.ct_lm_batch_upd_fail, NULL);
            RAISE pl_exc.e_lm_batch_upd_fail;
         END IF;

         l_standard := f_get_batch_time(l_r_batch.batch_no, 'MERGED',
                                         i_batch_operation);

      END IF;

      -- Set either goal time or target time, depending on the engineering
      -- standard flag.  Y = goal time  N = target time 
      IF (l_r_job_code.engr_std_flag = 'Y') THEN
          l_target_time := 0;
          l_goal_time := l_standard;
      ELSE
          l_goal_time := 0;
          l_target_time := l_standard;
      END IF;

      -- Set the value of the update flag depending on the boolean.
      IF (i_ignore_status_bln) THEN
         l_update_status_flag  := 'N';
      ELSE
         l_update_status_flag  := 'Y';
      END IF;

      --  Update the BATCH table.


      IF (l_print_goal_flag = 'Y') THEN
         UPDATE batch
            SET status = DECODE(l_update_status_flag, 'Y', 'F', status),
                goal_time = l_goal_time,
                target_time = l_target_time
          WHERE batch_no = i_lm_batch_no;
      ELSE
         UPDATE batch
            SET status = DECODE(l_update_status_flag, 'Y', 'F', status),
                goal_time = 0,
                target_time = 0
          WHERE batch_no = i_lm_batch_no;
      END IF;

      -- Need to have updated 1 record only.
      IF (SQL%ROWCOUNT != 1) THEN
         IF (SQL%ROWCOUNT > 1) THEN
            l_message := l_object_name ||
               ' TABLE=batch  ACTION=SELECT' ||
               ' i_lm_batch_no=' || i_lm_batch_no ||
               '  MESSAGE="Updated more than one batch record to "F".';
         ELSE
            l_message := l_object_name ||
               ' TABLE=batch  ACTION=SELECT' ||
               ' i_lm_batch_no=' || i_lm_batch_no ||
               '  MESSAGE="Updated 0 batch records to "F".';
         END IF;

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_batch_upd_fail, NULL);
         RAISE pl_exc.e_lm_batch_upd_fail;
      END IF;

      IF (NVL(l_r_batch.ref_no, 'x') != 'MULTI') THEN
         UPDATE batch
            SET (total_count, total_piece, total_pallet) =
                   (SELECT COUNT(*), SUM(NVL(kvi_no_piece, 0)),
                           SUM(NVL(kvi_no_pallet, 0))
                      FROM batch
                     WHERE batch_no = i_lm_batch_no
                        OR parent_batch_no = i_lm_batch_no)
          WHERE batch_no = i_lm_batch_no;
      ELSE
         UPDATE batch
            SET (total_count, total_piece, total_pallet) =
                   (SELECT 1, SUM(NVL(kvi_no_piece, 0)),
                           SUM(NVL(kvi_no_pallet, 0))
                      FROM batch
                     WHERE batch_no = i_lm_batch_no
                        OR parent_batch_no = i_lm_batch_no)
          WHERE batch_no = i_lm_batch_no;
      END IF;
 

      -- Need to have updated 1 record only.
      IF (SQL%ROWCOUNT != 1) THEN
         IF (SQL%ROWCOUNT > 1) THEN
            l_message := l_object_name ||
               ' TABLE=batch  ACTION=SELECT' ||
               ' i_lm_batch_no=' || i_lm_batch_no ||
               '  MESSAGE="Updated total count incorrectly';
         ELSE
            l_message := l_object_name ||
               ' TABLE=batch  ACTION=SELECT' ||
               ' i_lm_batch_no=' || i_lm_batch_no ||
               '  MESSAGE="Not Updated total count';
         END IF;

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_batch_upd_fail, NULL);
         RAISE pl_exc.e_lm_batch_upd_fail;
      END IF;

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name,
                     'Batch: ' || i_lm_batch_no ||
                     '  Goal time: ' || TO_CHAR(l_goal_time, 99999.9999) ||
                     '  Target time: ' || TO_CHAR(l_target_time, 99999.9999),
                     NULL, NULL);

   EXCEPTION
      WHEN pl_exc.e_no_lm_batch_found THEN
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN e_bad_batch_status THEN
         l_message := l_object_name || ': Status of batch ' ||
                      i_lm_batch_no || ' is ' ||
                      l_r_batch.status || ' and not X.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        NULL, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN pl_exc.e_lm_batch_upd_fail THEN
         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_batch_upd_fail, l_message);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
                                    l_object_name || ': ' || SQLERRM);
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;
 
   END load_goaltime;

END pl_lm_time;  -- end package body
/

SHOW ERRORS;


SET SCAN ON

