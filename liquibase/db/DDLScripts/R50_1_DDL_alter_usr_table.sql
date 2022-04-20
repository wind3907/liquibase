/****************************************************************************
**
** Desc: this creates a column TERMINATION_DATE (Date) in USR table,
**
** Modification History:
**    Date        Designer           Comments
**    -----------    --------     ------------------------------------------
**    Jan27th 2022  gcha2088          one column added to table usr
**       
****************************************************************************/

DECLARE
v_column_exists NUMBER := 0;
BEGIN
SELECT COUNT(*)
INTO v_column_exists
FROM user_tab_cols
WHERE column_name = 'TERMINATION_DATE'
  AND table_name = 'USR';

IF (v_column_exists = 0)   THEN
      EXECUTE IMMEDIATE 'ALTER TABLE USR ADD TERMINATION_DATE DATE';
END IF;
END;
/