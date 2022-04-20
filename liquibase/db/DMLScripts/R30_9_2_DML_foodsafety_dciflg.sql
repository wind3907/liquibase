/****************************************************************************
** File:       FOOD_SAFETY_DCI_DML.sql
**
** Desc: Script to insert Sysconfig data for FOOD_SAFETY_DCI
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    28-Jul-2020 Vishnupriya K.     setup FOOD_SAFETY_DCI for Opco  
**    
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM sys_config
  WHERE APPLICATION_FUNC = 'DRIVER CHECK-IN'
   and CONFIG_FLAG_NAME = 'FOOD_SAFETY_DCI';


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
    'DRIVER CHECK-IN',
    'FOOD_SAFETY_DCI',
    'FoodSafety DCI Return enabled?',
    'Y',
    'Y',
    'N',
    'N',
    'CHAR',
    20,
    NULL,
    'L',
    'Enable / disable Food Safety menus',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
  );

						  
                         
End If;
End;	
/
