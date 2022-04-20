/****************************************************************************
** File:       DML_create_sts_routein_syspar.sql
**
** Desc: Script to insert Sysconfig data for sts-swms server
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    10-JAN-2019 MCHA1213     setup sts/swms oracle web service syspar 
**    
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM sys_config
  WHERE APPLICATION_FUNC = 'DRIVER-CHECK-IN'
   and CONFIG_FLAG_NAME = 'STS_SWMS_ON'
  and  CONFIG_FLAG_DESC ='STS SWMS Oracle WS Interface';

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
    'DRIVER-CHECK-IN',
    'STS_SWMS_ON',
    'STS SWMS Oracle WS Interface',
    'N',
    'Y',
    'N',
    'N',
    'CHAR',
    20,
    NULL,
    'L',
    'Switch STS-SWMS Oracle WS Interface On',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
  );

						  
                         
End If;
End;	
/						  