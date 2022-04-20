CREATE OR REPLACE TRIGGER trg_cpd_xdock_pm_in
/*
    ===========================================================================================================
    -- Database Trigger
    -- trg_cpd_xdock_pm_in
    --
    -- Description.
    -- This script has trigger on xdock_pm_in that calls interface program to process to pm table
    -- Modification History
    --
    -- Date                User                  Version            Defect  Comment
    -- 05/14/2021          Pdas8114              1.0                Initial Creation
	-- 09/09/2021          Pdas8114              1.1                Added code to reprocess on update
    ============================================================================================================
    */

FOR INSERT OR UPDATE ON xdock_pm_in
COMPOUND TRIGGER
  l_error_msg         VARCHAR2(400);
  l_error_code        VARCHAR2(100);
  
  AFTER STATEMENT IS
BEGIN
IF INSERTING OR UPDATING THEN
 BEGIN
  PL_XDOCK_PM_IN.PROCESS_XDOCK_PM_IN;
 EXCEPTION 
 WHEN OTHERS THEN
      l_error_msg:= SUBSTR(SQLERRM,1,100);
      l_error_code:= SQLCODE;
      UPDATE xdock_pm_in
         SET record_status   = 'F'
           , error_msg       = l_error_msg
           , error_code      = l_error_code
       WHERE sequence_number = :new.sequence_number;
      pl_log.ins_msg( pl_log.ct_warn_msg, 'trg_cpd_xdock_pm_in', l_error_msg, SQLCODE, SQLERRM, 'MAINTENANCE', 'trg_cpd_xdock_pm_in' );
  END;
  END IF; 
END AFTER STATEMENT;
END trg_cpd_xdock_pm_in;
/
