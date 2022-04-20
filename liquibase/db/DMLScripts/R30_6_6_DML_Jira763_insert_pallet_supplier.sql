/****************************************************************************
** File:       R30_6_5_DDL_insert_pallet_supplier_table.sql
*
** Desc: Script creates  column,  to table PALLET_SUPPLIER related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    03/01/19     xzhe5043     added records to PALLET_SUPPLIER        
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM PALLET_SUPPLIER
  where supplier='BLUE-CHEP';
    
  IF (v_column_exists = 0)
  THEN
   INSERT INTO SWMS.PALLET_SUPPLIER(supplier, required) values ('BLUE-CHEP','N');
  END IF;
  commit;
 END;
/