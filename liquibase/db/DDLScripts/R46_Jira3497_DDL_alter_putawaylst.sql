/****************************************************************************
**
** Description:
**    Project: R46_Jira3497_DDL_alter_putawaylst.sql
**       
**    Added columns to tables.
**
**    USR
**       workday_id                VARCHAR2(30 CHAR)
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    07/20/21 bgil6182 Jim Gilliam
**                      Project: R46_Jira3497
**                      Created script to add DOOR_NO to PUTAWAYLST table.
**
****************************************************************************/

--------------------------------------------------------------------------
-- Add column to PUTAWAYLST
--------------------------------------------------------------------------

DECLARE
   PROCEDURE execute_stmt(i_stmt IN VARCHAR2)
   IS
      e_column_already_exists         EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_column_already_exists, -1430);  -- ORA-01430: column being added already exists in table
   BEGIN
      EXECUTE IMMEDIATE(i_stmt);
   EXCEPTION
      WHEN e_column_already_exists THEN NULL;
      WHEN OTHERS THEN RAISE;
   END execute_stmt;

BEGIN
   execute_stmt( 'ALTER TABLE swms.putawaylst ADD ( door_no VARCHAR2( 4 CHAR ) )' );
END;
/
