/****************************************************************************
** Date:       24-May-2018
** File:       Jira466_enable_finish_goods_Syspar_dml.sql
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
  WHERE APPLICATION_FUNC = 'GENERAL'
   and CONFIG_FLAG_NAME =   'ENABLE_FINISH_GOODS'
  and  CONFIG_FLAG_DESC = 'Finish Goods Enabled Opco';
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
    'GENERAL',
    'ENABLE_FINISH_GOODS',
    'Finish Goods Enabled Opco',
    'N',
    'Y',
    'N',
    'Y',
    'CHAR',
    1,
    NULL,
    'N',
    'Finish Goods Enabled Opco Y/N',
    NULL,
    'NONE',
    NULL,
    NULL,
    NULL
  );
  COMMIT;
  
  End If;
End;							  
/