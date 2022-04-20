/****************************************************************************
** File:       DDL_SYSPAR_rp1re.sql
**
** Desc: Script creates a column in the Sys_config_values values table 
**       to hold any additional information related to the config value
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    8-Jun-2017 Vishnupriya K.    used for Dynamic setup for Order by  
**
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'PARAM_VALUES'
        AND table_name = 'SYS_CONFIG_VALID_VALUES';

  IF (v_column_exists = 0)  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SYS_CONFIG_VALID_VALUES ADD PARAM_VALUES VARCHAR2(500 CHAR) NULL';
  END IF;
END;
/