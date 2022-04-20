SET ECHO OFF
REM
REM Purpose: This script will ensure that the Corporate-controlled IS_RDC
REM          SysPar is defined on the current SWMS instance and initializes
REM          it based on the company number. If the SysPar has already been
REM          defined, no change will occur.
REM
SET LINESIZE 132
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
  K_Script_Name       CONSTANT  VARCHAR2(100) := $$PLSQL_UNIT;
  K_ADD_SysPar_Name   CONSTANT  sys_config.config_flag_name%TYPE  := 'IS_RDC';
  K_ADD_SysPar_ValN   CONSTANT  sys_config.config_flag_name%TYPE  := 'N';
  K_ADD_SysPar_ValY   CONSTANT  sys_config.config_flag_name%TYPE  := 'Y';

/* Existing RDC company numbers */
  K_VA_NorthEast_RDC  CONSTANT  sys_config.config_flag_val%TYPE   := '177';
  K_FL_SouthEast_RDC  CONSTANT  sys_config.config_flag_val%TYPE   := '184';

  n_count                     PLS_INTEGER;
  n_changes                   PLS_INTEGER := 0;
  l_company_name              maintenance.attribute_value%TYPE;
  l_company_number            maintenance.attribute_value%TYPE;
  b_is_rdc                    BOOLEAN;
  This_Message                VARCHAR2(2000);
  r_parm                      sys_config%ROWTYPE;
  r_val                       sys_config_valid_values%ROWTYPE;
BEGIN
  BEGIN
    SELECT SUBSTR( m.attribute_value, 1, INSTR( m.attribute_value, ':' )-1 ) company_number
         , SUBSTR( m.attribute_value, INSTR( m.attribute_value, ':' )+1, 99 ) company_name
      INTO l_company_number, l_company_name
      FROM maintenance m
     WHERE m.component = 'COMPANY';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
    l_company_name   := 'Corporate' ;
    l_company_number := '000' ;
  END;

  b_is_rdc := ( l_company_number IN ( K_VA_NorthEast_RDC
                                    , K_FL_SouthEast_RDC
                                    ) );
  This_Message := K_Script_Name || ': '
               || l_company_name || '/' || l_company_number || ' is'
               || CASE b_is_rdc WHEN FALSE THEN ' not' END
               || ' an RDC.';
  DBMS_Output.Put_Line( This_Message );

  SELECT COUNT(*)
    INTO n_count
    FROM sys_config sp
   WHERE sp.config_flag_name = UPPER( K_ADD_SysPar_Name );

  IF ( n_count = 0 ) THEN
    SELECT NVL( MAX( seq_no ), 0 ) + 1
      INTO r_parm.seq_no
      FROM sys_config;
    r_parm.application_func := UPPER( 'General' );
    r_parm.config_flag_name := UPPER( K_ADD_SysPar_Name );
    r_parm.config_flag_desc := 'Are we an RDC?';
    IF ( b_is_rdc ) THEN
      r_parm.config_flag_val  := 'Y';
    ELSE
      r_parm.config_flag_val  := 'N';
    END IF;
    r_parm.value_required   := 'Y';
    r_parm.value_updateable := 'N';
    r_parm.value_is_boolean := 'Y';
    r_parm.data_type        := 'CHAR';
    r_parm.data_precision   := 1;       -- Length for string
    r_parm.data_scale       := NULL;    -- Undefined for string
    r_parm.sys_config_list  := 'L';
    r_parm.sys_config_help  := 'Does the warehouse operate like a ReDistibution Center (RDC)?';
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
    r_val.description       := 'Disable RDC functionality. Assumption: OpCo functionality.';

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
    r_val.description       := 'Enable RDC functionality.';

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
