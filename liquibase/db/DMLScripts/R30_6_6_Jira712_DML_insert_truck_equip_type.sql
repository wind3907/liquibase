/****************************************************************************
** File:       R30_6_6_Jira712_DML_insert_truck_equip_type.sql
*
** Desc: Script creates  column,  to table PALLET_SUPPLIER related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    03/01/19     xzhe5043     added records to LAS_TRUCK_EQUIPMENT_TYPE       
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM LAS_TRUCK_EQUIPMENT_TYPE
  where EQUIPMENT_TYPE='BLUE-CHEP';
    
  IF (v_column_exists = 0)
  THEN
   Insert into LAS_TRUCK_EQUIPMENT_TYPE (TYPE_SEQ,EQUIPMENT_TYPE,SCANNABLE,ADD_DATE,ADD_USER,UPD_DATE,UPD_USER,ACTION_FLAG,MIN_COUNT,MAX_COUNT,BARCODE,ASSET_COUNT) 
   values ( (select nvl(max(type_seq),0)+1 from LAS_TRUCK_EQUIPMENT_TYPE),'BLUE-CHEP','N',to_date(SYSDATE,'DD-MON-RR'),'SWMS',to_date(SYSDATE,'DD-MON-RR'),'SWMS','P',0,999,null,null);
  END IF;
  COMMIT;
 END;
/
 