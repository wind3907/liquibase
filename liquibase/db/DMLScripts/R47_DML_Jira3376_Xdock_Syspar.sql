/****************************************************************************
** Date:       06/03/2021
** File:       R47_DML_Jira3376_xdock_Syspar.sql
**
** Create below SYSPAR entries to check if the SWMS the Opco is 'ENABLE_OPCO_TO_OPCO_XDOCK' enabled.
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    03-Jun-21 PDAS8114       Create Syspar ENABLE_OPCO_TO_OPCO_XDOCK
**
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM sys_config
  WHERE 1=1
  and CONFIG_FLAG_NAME =   'ENABLE_OPCO_TO_OPCO_XDOCK';
   
IF (v_column_exists = 0)  THEN

INSERT
INTO sys_config 
  (
    SEQ_NO,
    APPLICATION_FUNC,
    CONFIG_FLAG_NAME,
    CONFIG_FLAG_DESC,
    CONFIG_FLAG_VAL,
    VALUE_REQUIRED,
    VALUE_UPDATEABLE,
    VALUE_IS_BOOLEAN,
    DATA_TYPE,
    DATA_PRECISION,
    DATA_SCALE,
    SYS_CONFIG_LIST,
    SYS_CONFIG_HELP,
    LOV_QUERY,
    VALIDATION_TYPE,
    RANGE_LOW,
    RANGE_HIGH,
    DISABLED_FLAG
  )
  VALUES
  ( (SELECT MAX(seq_no) + 1 FROM sys_config),
    'GENERAL',
    'ENABLE_OPCO_TO_OPCO_XDOCK',
    'Enable OpCo to OpCo XDock',
    'N',
    'Y',
    'N',
    'N',
	'CHAR',
    0,
    NULL,
    'L',
    'Enable/Disable OpCo to OpCo XDock',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL  );
	
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('ENABLE_OPCO_TO_OPCO_XDOCK', 'Y', 'Enables opco to ocpco xdock' );
  
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('ENABLE_OPCO_TO_OPCO_XDOCK', 'N', 'Disables opco to ocpco xdock' );
                          
  
  
  COMMIT;
  
  End If;
End;							  
/