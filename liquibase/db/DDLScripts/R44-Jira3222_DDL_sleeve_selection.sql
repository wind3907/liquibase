/****************************************************************************
**
** Description:
**    Project: R44-Jira3222_Sleeve_selection
**       
**    Added columms to tables.
**
**    SEL_EQUIP
**       is_sleeve_selection       VARCHAR2(1 CHAR)
**    FLOAT_DETAIL
**       sleeve_id                 VARCHAR2(11 CHAR)
**    FLOAT_DETAIL_BCKUP
**       sleeve_id                 VARCHAR2(11 CHAR)
**    FLOATS   
**       is_sleeve_selection       VARCHAR2(1 CHAR)
**    SOS_BATCH
**       is_sleeve_selection       VARCHAR2(1 CHAR)
**    SOS_BATCH_HIST
**       is_sleeve_selection       VARCHAR2(1 CHAR)
**    T_CURR_BATCH
**       sleeve_id                 VARCHAR2(11 CHAR)
**    T_CURR_BATCH_SHORT
**       sleeve_id                 VARCHAR2(11 CHAR)
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    10/08/20 bben0556 Brian Bent
**                      Project: R44-Jira3222_Sleeve_selection
**                      S4R
**                      Created.
**
**    12/04/20 bben0556 Brian Bent
**                      Since the sel_method.single_stop_flag needs to be
**                      'Y' for sleeve selection it makes more sense to
**                      put the sleeve selection flag column in the SEL_METHOD
**                      table and not the SEL_EQUIP table.  This also simplifies
**                      validation.  The rule at this time is if sleeve selection
**                      is turned on for a selection method group then the
**                      single stop flag needs to be Y.  This will be validated
**                      in the form as well as with a DB trigger on the
**                      SEL_METHOD table.
**                      README - Did not do this.  Left the sleeve selection flag
**                               in the SEL_EQUIP table.
**
**    01/05/21 bben0556 Brian Bent
**                      Change sleeve_id length from 15 to 11 as STS has a
**                      maximum of 11 characters for a barcode.
**
**    01/06/21 bben0556 Brian Bent
**                      Program sos_batchcmp.pc not compiling after column IS_SLEEVE_SELECTION
**                      added to table SOS_BATCH.  Found sos_batchcmp.pc is doing this:
**                         EXEC SQL INSERT INTO sos_batch_hist
**                            SELECT * FROM sos_batch
**                             WHERE  batch_no = REPLACE(:BatchNo,'S');
**                      Column IS_SLEEVE_SELECTION was not added to table SOS_BATCH_HIST
**                      at this time since sleeve selection is at the proof of
**                      concept phrase.  So the SELECT * changed to list each column.
**                      Note we should not be doing  insert into ... select * from ...
**                      There is no guarantee the destination table will be created exactly
**                      matching the columns or the order of columns in the source table.
**
**    01/14/21 bben0556 Brian Bent
**                      When ahead and added column IS_SLEEVE_SELECTION to SOS_BATCH_HIST
**                      because script "pl_swms_purge_orders.sql" was failing because 
**                      it is doing "insert into sos_bath_hist select * from sos_batch".
** 
****************************************************************************/


--------------------------------------------------------------------------
-- Add columns to FLOAT_DETAIL
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
   execute_stmt('ALTER TABLE swms.sel_equip           ADD (is_sleeve_selection       VARCHAR2(1  CHAR))'  );
   execute_stmt('ALTER TABLE swms.float_detail        ADD (sleeve_id                 VARCHAR2(11 CHAR))'  );
   execute_stmt('ALTER TABLE swms.float_detail_bckup  ADD (sleeve_id                 VARCHAR2(11 CHAR))'  );
   execute_stmt('ALTER TABLE swms.floats              ADD (is_sleeve_selection       VARCHAR2(1  CHAR))'  );
   execute_stmt('ALTER TABLE swms.sos_batch           ADD (is_sleeve_selection       VARCHAR2(1  CHAR))'  );
   execute_stmt('ALTER TABLE swms.sos_batch_hist      ADD (is_sleeve_selection       VARCHAR2(1  CHAR))'  );
   execute_stmt('ALTER TABLE swms.t_curr_batch        ADD (sleeve_id                 VARCHAR2(11 CHAR))'  );
   execute_stmt('ALTER TABLE swms.t_curr_batch_short  ADD (sleeve_id                 VARCHAR2(11 CHAR))'  );
END;
/


