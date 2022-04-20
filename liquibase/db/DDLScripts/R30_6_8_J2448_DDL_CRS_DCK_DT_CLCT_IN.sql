/****************************************************************************
** 
** Desc: Script creates column,  to table INV related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    -----------    --------     ------------------------------------------
**    Aug 2nd 2019 vkal9662          add CMU columns to table CROSS_DOCK_DATA_COLLECT_IN   
**                       ( Master_order_id,order_seq,carrier_id,lot_id,mfg_date, item_seq, Case_id)
**    9/20/19      mcha1213          add checking for existing of column      
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
BEGIN

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'MASTER_ORDER_ID'
        AND table_name = 'CROSS_DOCK_DATA_COLLECT_IN';

  IF (v_column_exists = 0)
  THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.CROSS_DOCK_DATA_COLLECT_IN ADD (MASTER_ORDER_ID VARCHAR2(25))';
  

  END IF;
  
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'CMU_INDICATOR'
        AND table_name = 'CROSS_DOCK_DATA_COLLECT_IN';

  IF (v_column_exists = 0)
  THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.CROSS_DOCK_DATA_COLLECT_IN ADD (CMU_INDICATOR VARCHAR2(1 CHAR))';
  

  END IF;
  
  
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'CARRIER_ID'
        AND table_name = 'CROSS_DOCK_DATA_COLLECT_IN';

  IF (v_column_exists = 0)
  THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.CROSS_DOCK_DATA_COLLECT_IN ADD (CARRIER_ID VARCHAR2(18 CHAR))';
  

  END IF;
  
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'LOT_ID'
        AND table_name = 'CROSS_DOCK_DATA_COLLECT_IN';

  IF (v_column_exists = 0)
  THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.CROSS_DOCK_DATA_COLLECT_IN ADD (LOT_ID VARCHAR2(30 CHAR))';
  

  END IF;
  
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'CW_TYPE'
        AND table_name = 'CROSS_DOCK_DATA_COLLECT_IN';

  IF (v_column_exists = 0)
  THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.CROSS_DOCK_DATA_COLLECT_IN ADD (CW_TYPE	VARCHAR2(1 CHAR))';
  

  END IF;
  
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'CASE_ID'
        AND table_name = 'CROSS_DOCK_DATA_COLLECT_IN';

  IF (v_column_exists = 0)
  THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.CROSS_DOCK_DATA_COLLECT_IN ADD (CASE_ID NUMBER(13,0))';
  

  END IF;
  
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ORDER_SEQ'
        AND table_name = 'CROSS_DOCK_DATA_COLLECT_IN';

  IF (v_column_exists = 0)
  THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.CROSS_DOCK_DATA_COLLECT_IN ADD (ORDER_SEQ NUMBER(8,0))';
  

  END IF;
  
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ITEM_SEQ'
        AND table_name = 'CROSS_DOCK_DATA_COLLECT_IN';

  IF (v_column_exists = 0)
  THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.CROSS_DOCK_DATA_COLLECT_IN ADD (ITEM_SEQ NUMBER(3,0))';
  

  END IF;
  
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'MFG_DATE'
        AND table_name = 'CROSS_DOCK_DATA_COLLECT_IN';

  IF (v_column_exists = 0)
  THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.CROSS_DOCK_DATA_COLLECT_IN ADD ( MFG_DATE DATE )';
  

  END IF;
  
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'PALLET_ID'
        AND table_name = 'CROSS_DOCK_DATA_COLLECT_IN';

  IF (v_column_exists = 0)
  THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.CROSS_DOCK_DATA_COLLECT_IN ADD (PALLET_ID VARCHAR2(18 CHAR)) ';
  

  END IF;
  
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'SYS_ORDER_ID'
        AND table_name = 'CROSS_DOCK_DATA_COLLECT_IN';

  IF (v_column_exists = 0)
  THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.CROSS_DOCK_DATA_COLLECT_IN ADD (SYS_ORDER_ID	NUMBER(10,0) )';
  

  END IF;
  

  
  END;
/ 



