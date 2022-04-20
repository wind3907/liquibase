/****************************************************************************
** File:       SWMS_ENABLE_RT_BACKOUT_DML.sql
**
** Desc: Script to insert Sysconfig data for ENABLE_RT_BACKOUT
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    17-Dec-2019 Vishnupriya K.     flag to ENABLE_RT_BACKOUT 
**    
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
 
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM sys_config
  WHERE APPLICATION_FUNC = 'ORDER PROCESSING'
  and CONFIG_FLAG_NAME = 'ENABLE_RT_BACKOUT';


IF (v_column_exists = 0)  THEN



INSERT
INTO sys_config
  ( SEQ_NO,
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
    'ORDER PROCESSING',
    'ENABLE_RT_BACKOUT',
    'Enable Route Backout',
    'N',
    'Y',
    'N',
    'N',
    'CHAR',
    20,
    NULL,
    'L',
    'Enable to Delete Routes',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL );

INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('ENABLE_RT_BACKOUT',       'Y',   'Enable Rt Backout');
                           
                               
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('ENABLE_RT_BACKOUT', 'N',      'Disable Rt Backout');
							  
                         
End If;
End;	
/						  