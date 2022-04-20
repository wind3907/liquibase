
/****************************************************************************
**
** Description:
**    Project:
**        
**    Add new columns to RETURNS table for Return Items barcode changes 
** 	  and returns POD CRT changes
**    
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    02/21/20 sban3548 Jira-OPCOF-2790 
**	  03/30/20 sban3548	Removed some RETURNS columns from previous script
**
****************************************************************************/

--------------------------------------------------------------------------
-- Add columns to RETURNS table
--------------------------------------------------------------------------

DECLARE
   PROCEDURE execute_stmt(i_stmt IN VARCHAR2)
   IS
      e_column_already_exists  EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_column_already_exists, -1430);
   BEGIN
      EXECUTE IMMEDIATE(i_stmt);
   EXCEPTION
      WHEN e_column_already_exists THEN NULL;
      WHEN OTHERS THEN RAISE;
   END execute_stmt;

BEGIN
   execute_stmt('ALTER TABLE swms.returns ADD lock_chg VARCHAR(1)');
   execute_stmt('ALTER TABLE swms.returns ADD barcode_ref_no NUMBER(10)');
   execute_stmt('ALTER TABLE swms.returns ADD create_put VARCHAR(1)');
END;
/
