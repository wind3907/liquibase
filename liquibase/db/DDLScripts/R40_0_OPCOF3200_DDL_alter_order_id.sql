/****************************************************************************
** File: R40_0_OPCOF3200_DDL_alter_order_id.sql
*
** Desc: Script makes changes to ORDER_ID column in SAP_PO_IN and ORDM_HISTORY for Brakes enhancement
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    09/18/20     sban3548     Altered order_id length to 14 char	
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
  v_column1_exists NUMBER := 0;
BEGIN

   SELECT COUNT(*)
   INTO v_column_exists
   FROM user_tab_cols
   WHERE column_name = 'ORDER_ID'
     AND table_name  = 'ORDM_HISTORY';

   IF (v_column_exists = 1) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE ORDM_HISTORY MODIFY ORDER_ID VARCHAR2(14 CHAR)';
   END IF;
		
   SELECT COUNT(*)
   INTO v_column1_exists
   FROM user_tab_cols
   WHERE column_name = 'ORDER_ID'
     AND table_name  =	'SAP_PO_IN';	

  IF (v_column1_exists = 1)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SAP_PO_IN MODIFY ORDER_ID VARCHAR2(14 CHAR)';
  END IF;

END;
/
