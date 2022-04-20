/****************************************************************************
** Date:       18-May-2017
** File:       swms_sprocketProgram_Syspar_dml.sql
**
** Script to insert SYSPAR valeus for Sprocket.
**
** Create below SYSPAR entries for to check if the SWMS Sprocket package
** PL_EQUIP_OUT needs to be called or not
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    18-May-2017 Vishnupriya K.     Check the Syspar value in the package
**                                   PL_EQUIP_OUT before executing the Sprocket
**                                   message delivery logic
**
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM sys_config
  WHERE APPLICATION_FUNC = 'MAINTENANCE'
   and CONFIG_FLAG_NAME =   'ENBL_SWMS_SPROCKET_INTFC'
  and  CONFIG_FLAG_DESC = 'Enable Swms-Sprocket Process';
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
    (SELECT MAX(seq_no) + 1 FROM sys_config
    )
    ,
    'MAINTENANCE',
    'ENBL_SWMS_SPROCKET_INTFC',
    'Enable Swms-Sprocket Process',
    'N',
    'Y',
    'N',
    'Y',
    'CHAR',
    1,
    NULL,
    'N',
    'Enable the SWMS Sprocket Functionality Y/N',
    NULL,
    'NONE',
    NULL,
    NULL,
    NULL
  );
  COMMIT;
  
  End If;
End;							  
