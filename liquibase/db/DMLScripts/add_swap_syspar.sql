/****************************************************************************
 ** File:      add_swap_syspar.sql
 **
 ** Desc: Script to insert Sysconfig data for the SWAP funcitonality.
 **
 **
 ** Modification History:
 **    Date        Designer   Comments
 **    --------    --------   ----------------------------------------------------
 **    APR-5-2021  mche6435   Initial version
 **
 ****************************************************************************/

DECLARE
  v_column_exists               NUMBER := 0;
  l_swap_window_start_default   varchar2(5) := '07:00';
  l_swap_window_end_default     varchar2(5) := '17:00';
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM sys_config
  WHERE APPLICATION_FUNC = 'INVENTORY CONTROL'
  AND CONFIG_FLAG_NAME IN ('SWAP_WINDOW_START', 'SWAP_WINDOW_END');

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
        'INVENTORY CONTROL',
        'SWAP_WINDOW_START',
        'Military time to enable SWAP',
        l_swap_window_start_default,
        'Y',
        'N',
        'N',
        'CHAR',
        5,
        NULL,
        'N',
        'Select local military time to enable SWAP functionality daily. e.g. 07:00',
        NULL,
        NULL,
        NULL,
        NULL,
        NULL
      );

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
        'INVENTORY CONTROL',
        'SWAP_WINDOW_END',
        'Military time to disable SWAP',
        /* 'Local time in military format to disable the SWAP functionality', */
        l_swap_window_end_default,
        'Y',
        'N',
        'N',
        'CHAR',
        5,
        NULL,
        'N',
        'Select local military time to disable SWAP functionality daily. e.g. 17:00',
        NULL,
        NULL,
        NULL,
        NULL,
        NULL
      );
  END IF;

  COMMIT;
END;
/
