/****************************************************************************
** File: R30_6_9_DDL_alter_sts_routein_rj_obj.sql
*
** Desc: Script makes changes to sts_routein_rj_obj related to POD enhancement
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    01/31/20     mch1213     added new columns to sts_routein_rj_obj
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
  v_column1_exists NUMBER := 0;
BEGIN
		
  select COUNT(*)
  into v_column_exists
  from sys.dba_type_attrs
  where owner = 'SWMS'
  and type_name = 'STS_ROUTEIN_RJ_OBJ'
  and attr_name = 'BARCODE';		

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'alter TYPE STS_ROUTEIN_RJ_OBJ ADD ATTRIBUTE BARCODE VARCHAR2(11) CASCADE'; 
	COMMIT;
  END IF;

  
  select COUNT(*)
  into v_column1_exists
  from sys.dba_type_attrs
  where owner = 'SWMS'
  and type_name = 'STS_ROUTEIN_RJ_OBJ'
  and attr_name = 'MULTI_PICK_IND';		

  IF (v_column1_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'alter TYPE STS_ROUTEIN_RJ_OBJ ADD ATTRIBUTE MULTI_PICK_IND VARCHAR2(6) CASCADE'; 
	COMMIT;
  END IF;
  
  


END;
/
