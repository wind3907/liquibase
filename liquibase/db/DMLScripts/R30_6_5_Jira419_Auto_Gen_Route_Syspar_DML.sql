/****************************************************************************
** Date:       24-May-2018
** File:       Jira419_Gen_Autp_Route_Syspar_dml.sql
**
** Script to insert SYSPAR values for Auto route Generation.
**
** Create below SYSPAR entries to check if the SWMS the Opco is 'Auto Route Generation' enabled.
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    24-May-2018 Vishnupriya K.     Check the Syspar value in the 
                                     Auto Route Generation Process
**
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM sys_config
  WHERE APPLICATION_FUNC = 'ORDER_PROCESSING'
   and CONFIG_FLAG_NAME =   'AUTO_GEN_ROUTE_PRCSS';
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
    'ORDER_PROCESSING',
    'AUTO_GEN_ROUTE_PRCSS',
    'Auto Route Generation Running',
    'N',
    'Y',
    'N',
    'Y',
    'CHAR',
    1,
    NULL,
    'N',
    'Auto Route Generation Running Y/N',
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