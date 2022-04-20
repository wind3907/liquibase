/****************************************************************************
** File:       R30_6_5_DDL_alter_sp_pallet_table.sql
*
** Desc: Script creates  column,  to table SP_PALLET related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    03/01/19     xzhe5043     added required column to table SP_PALLET        
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('VENDOR_ID','LOAD_NO','VENDOR_NAME','REC_DATE')
        AND table_name = 'SP_PALLET';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SP_PALLET ADD ( VENDOR_ID VARCHAR2(10),VENDOR_NAME VARCHAR2(30),  LOAD_NO varchar2(12), REC_DATE DATE)';
	  
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SP_PALLET ADD CONSTRAINT PK_suplier PRIMARY KEY (erm_id, supplier)';
	
  END IF;

 END;
/