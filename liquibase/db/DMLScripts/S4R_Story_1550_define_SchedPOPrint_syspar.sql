SET ECHO OFF
REM
REM Purpose: This script will ensure that the SCHEDULE_PRINT_PO_WORKSHEET
REM          SysPar is defined on the current SWMS instance and initializes
REM          it to [Y]es. If the SysPar has already been defined, no change
REM          will occur.
REM
SET LINESIZE 132
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
  K_Script_Name       CONSTANT  VARCHAR2(100) := 'S4R_DML_define_SchedPOPrint_syspar.sql';
  K_ADD_SysPar_Name   CONSTANT  sys_config.config_flag_name%TYPE  := 'PRINT_SCHEDULED_PO_WORKSHEETS';
  K_ADD_SysPar_ValN   CONSTANT  sys_config.config_flag_name%TYPE  := 'N';
  K_ADD_SysPar_ValY   CONSTANT  sys_config.config_flag_name%TYPE  := 'Y';

  n_count                     PLS_INTEGER;
  n_changes                   PLS_INTEGER := 0;
  b_sched_print               BOOLEAN;
  l_live_receiving            sys_config.config_flag_val%TYPE;
  This_Message                VARCHAR2(2000);
  r_parm                      sys_config%ROWTYPE;
  r_val                       sys_config_valid_values%ROWTYPE;
BEGIN
  SELECT COUNT(*)
    INTO n_count
    FROM sys_config sp
   WHERE sp.config_flag_name = UPPER( K_ADD_SysPar_Name );

  IF ( n_count = 0 ) THEN
    SELECT NVL( MAX( seq_no ), 0 ) + 1
      INTO r_parm.seq_no
      FROM sys_config;
    r_parm.application_func := UPPER( 'RECEIVING' );
    r_parm.config_flag_name := UPPER( K_ADD_SysPar_Name );
    r_parm.config_flag_desc := 'Print scheduled PO worksheets';
    r_parm.config_flag_val  := 'Y';
    r_parm.value_required   := 'Y';
    r_parm.value_updateable := 'Y';
    r_parm.value_is_boolean := 'Y';
    r_parm.data_type        := 'CHAR';
    r_parm.data_precision   := 1;       -- Length for string
    r_parm.data_scale       := NULL;    -- Undefined for string
    r_parm.sys_config_list  := 'L';
    r_parm.sys_config_help  := 'If OpCo has Live Receiving enabled and doesn''t need to print PO worksheets during the scheduled opening of POs, then the print operation can be disabled by setting to N. Default is Y.';
    r_parm.lov_query        := NULL;
    r_parm.validation_type  := NULL;
    r_parm.range_low        := NULL;
    r_parm.range_high       := NULL;
    r_parm.disabled_flag    := NULL;

    INSERT INTO sys_config VALUES r_parm;
    n_changes := n_changes + 1;
    DBMS_Output.Put_Line( K_Script_Name || ': parameter ' || K_ADD_SysPar_Name || ' has been added as a system parameter.' );
  ELSE
    DBMS_Output.Put_Line( K_Script_Name || ': parameter ' || K_ADD_SysPar_Name || ' already exists as a system parameter.' );
  END IF;

  SELECT COUNT(*)
    INTO n_count
    FROM sys_config_valid_values spv
   WHERE spv.config_flag_name = UPPER( K_ADD_SysPar_Name )
     AND spv.config_flag_val  = UPPER( K_ADD_SysPar_ValN ) ;

  IF ( n_count = 0 ) THEN
    r_val.config_flag_name  := UPPER( K_ADD_SysPar_Name );
    r_val.config_flag_val   := UPPER( K_ADD_SysPar_ValN );
    r_val.description       := 'Disable printing of PO worksheets during scheduled opening of POs. Live Receiving must be enabled in order to choose this option.';

    INSERT INTO sys_config_valid_values VALUES r_val;
    n_changes := n_changes + 1;
    DBMS_Output.Put_Line( K_Script_Name || ': parameter value ' || K_ADD_SysPar_ValN || ' has been added for system parameter ' || K_ADD_SysPar_Name || '.' );
  ELSE
    DBMS_Output.Put_Line( K_Script_Name || ': parameter value ' || K_ADD_SysPar_ValN || ' already exists for system parameter ' || K_ADD_SysPar_Name || '.' );
  END IF;

  SELECT COUNT(*)
    INTO n_count
    FROM sys_config_valid_values spv
   WHERE spv.config_flag_name = UPPER( K_ADD_SysPar_Name )
     AND spv.config_flag_val  = UPPER( K_ADD_SysPar_ValY ) ;

  IF ( n_count = 0 ) THEN
    r_val.config_flag_name  := UPPER( K_ADD_SysPar_Name );
    r_val.config_flag_val   := UPPER( K_ADD_SysPar_ValY );
    r_val.description       := 'Enable printing of PO worksheets during scheduled opening of POs.';

    INSERT INTO sys_config_valid_values VALUES r_val;
    n_changes := n_changes + 1;
    DBMS_Output.Put_Line( K_Script_Name || ': parameter value ' || K_ADD_SysPar_ValY || ' has been added for system parameter ' || K_ADD_SysPar_Name || '.' );
  ELSE
    DBMS_Output.Put_Line( K_Script_Name || ': parameter value ' || K_ADD_SysPar_ValY || ' already exists for system parameter ' || K_ADD_SysPar_Name || '.' );
  END IF;

  IF ( n_changes > 0 ) THEN
    COMMIT;
    DBMS_Output.Put_Line( K_Script_Name || ': saving one or more changes.' );
  END IF;
END;
/
