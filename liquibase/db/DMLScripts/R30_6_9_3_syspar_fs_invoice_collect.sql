/****************************************************************************
** File:       R30_6_9_3_ins_sys_config.sql
**
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    30-SEP-2020 Kiet Nhan
**    
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM sys_config
  WHERE CONFIG_FLAG_NAME = 'FOOD_SAFETY_INVOICE_COLLECT';

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
    'FOOD_SAFETY_INVOICE_COLLECT',
    'Food Safety Invoice Retn Num',
    '3',
    'Y',
    'Y',
    'N',
    'NUMBER',
    3,
    NULL,
    'R',
    'Enter the number of randomly pick items to represent Food Safety temperature collection when there is an invoice returns',
    NULL,
    'RANGE',
    1,
    999,
    NULL
  );

						  
                         
End If;
End;	
/						  
