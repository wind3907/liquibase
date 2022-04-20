/****************************************************************************
** File:       R30_6_6_DDL_alter_pallet_supplier_table.sql
*
** Desc: Script creates  column,  to table PALLET_SUPPLIER related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    03/01/19     xzhe5043     added required column to table PALLET_SUPPLIER        
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'REQUIRED'
        AND table_name = 'PALLET_SUPPLIER';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.PALLET_SUPPLIER ADD REQUIRED VARCHAR2(1 CHAR)';
  END IF;
 END;
/