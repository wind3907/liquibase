/****************************************************************************
** File:       r45_2_jira3502_swap_enable_dml.sql
**
** Desc: Script to insert Sysconfig for swms SWAP process
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    18-Jun-2021 Vishnupriya K.    Flag for SWMS SWAP Process at Opco level  
**    
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM sys_config
  WHERE  CONFIG_FLAG_NAME = 'SWMS_SWAP_ON';

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
  (
    (SELECT MAX(seq_no) + 1 FROM sys_config),
    'MAINTENANCE',
    'SWMS_SWAP_ON',
    'Enable SWMS SWAP Process',
    'N',
    'Y',
    'N',
    'N',
    'CHAR',
    20,
    NULL,
    'L',
    'Enable SWM SWAP Process On or Off',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
  );

						  
                         
End If;
End;	
/						  