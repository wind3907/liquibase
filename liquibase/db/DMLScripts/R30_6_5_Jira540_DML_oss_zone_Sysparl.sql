/****************************************************************************
** Date:       7-Aug-2018
** File:       Jira540_oss_zone_Syspar_dml.sql
**
** Script to insert SYSPAR values for Finish Goods.
**
** Create below SYSPAR entries to check if the SWMS the Opco is 'Finish Goods' enabled.
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    24-May-2018 Vishnupriya K.     Check the Syspar value in the 
                                     Pick Adjustments Forms
**
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM sys_config
  WHERE 1=1
  and CONFIG_FLAG_NAME =   'OSS_ZONE';
   
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
    'OSS_ZONE',
    'Outside Storage Main Zone',
    'OSS1',
    'Y',
    'Y',
    'N',
	'CHAR',
    8,
    NULL,
    'L',
    'Set up Outside Storage Main Zone',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL  );
	
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('OSS_ZONE', 'OSS1', 'Primary OSS Zone' );
  
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('OSS_ZONE', 'OSS2', 'OSS Zone 2' );
                           
                               
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('OSS_ZONE', 'OSS3', 'OSS Zone 3');
							  

  
  
  COMMIT;
  
  End If;
End;							  
/