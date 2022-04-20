/****************************************************************************
** File: CRQ29055_DDL_add_1st_stop_unitize.sql
**
** Desc: Script add a column:Use_normal_unitize_processing in the swms.SEL_METHOD 
**       to hold vales TRUE or FALSE.
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    03-dec-2017 Elaine Zheng    Use_normal_unitize_processing added to tables 
**                                  swms.SEL_METHOD
**                                   
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE upper(column_name) = 'USE_NORMAL_UNITIZE_PROCESSING'
        AND table_name = 'SEL_METHOD';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SEL_METHOD ADD USE_NORMAL_UNITIZE_PROCESSING varchar2(1)';
  END IF;
END;
/
