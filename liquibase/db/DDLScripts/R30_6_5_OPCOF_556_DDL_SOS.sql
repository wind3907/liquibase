/*******************************************************************
**
**  Script to add new colum AUTO_ENTER_KEY to SOS_USR_CONFIG.
**  P. Kabran - 07-Aug-2018
**
********************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'AUTO_ENTER_KEY'
        AND table_name = 'SOS_USR_CONFIG';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SOS_USR_CONFIG ADD AUTO_ENTER_KEY VARCHAR2(1 CHAR) NULL';
  END IF;
END;
/
