/****************************************************************************

Alter SAP tables, add new column ERROR_MSG
  
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_RT_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_RT_OUT ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_CU_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_CR_OUT ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_CU_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_CU_IN ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_IM_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_IM_IN ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_MF_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_MF_IN ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_ML_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_ML_IN ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_OR_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_OR_IN ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_PM_MISC_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PM_MISC_IN ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_PO_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PO_IN ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_RD_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_RD_IN ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_SN_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_SN_IN ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_CONTAINER_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_CONTAINER_OUT ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_CR_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_CR_OUT ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_EQUIP_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_EQUIP_OUT ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_IA_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_IA_OUT ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_LM_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_LM_OUT ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_OW_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_OW_OUT ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_PW_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PW_OUT ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/


DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_WH_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_WH_OUT ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/