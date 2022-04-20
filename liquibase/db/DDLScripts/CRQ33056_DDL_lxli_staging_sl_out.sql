/*********************************************************************
 06/21/17 - pkab6563 - Add new columns multi_home_seq
                       and pik_path to lxli_staging_sl_out 
                       table.

 12/01/17 - pkab6563 - Changed to first check to ensure that the 
                       columns do not exists.
**********************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'MULTI_HOME_SEQ'
        AND table_name = 'LXLI_STAGING_SL_OUT';

  IF (v_column_exists = 0) THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.LXLI_STAGING_SL_OUT ADD MULTI_HOME_SEQ NUMBER(5)';
  END IF;
END;
/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'PIK_PATH'
        AND table_name = 'LXLI_STAGING_SL_OUT';

  IF (v_column_exists = 0) THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.LXLI_STAGING_SL_OUT ADD PIK_PATH NUMBER(9)';
  END IF;
END;
/
