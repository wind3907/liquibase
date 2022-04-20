create or replace FUNCTION "DBMS_HOST_COMMAND_FUNC" (
  p_userid  IN  VARCHAR2,
  p_command IN VARCHAR2
  ) RETURN VARCHAR2
AS
    v_plsql_package VARCHAR2(50);
    v_enabled       VARCHAR2(1);
    v_proc_module   VARCHAR2(50);
    v_result          VARCHAR2 (1000);
    v_stmt  VARCHAR2(1000);
    v_request_params VARCHAR2(1000);
    v_command_temp  VARCHAR2(1000);
 BEGIN

    v_command_temp := TRIM(REPLACE(p_command, 'nohup'));
    v_command_temp := NVL(SUBSTR(v_command_temp, 0, INSTR(v_command_temp, '>>') -1), v_command_temp);

    v_proc_module := NVL(SUBSTR(v_command_temp, 0, INSTR(v_command_temp, ' ') -1), v_command_temp);
    
    IF  INSTR(v_command_temp, ' ') > 0 THEN
        v_request_params:= NVL(SUBSTR(v_command_temp, INSTR(v_command_temp, ' '), LENGTH(v_command_temp)), '');
    ELSE 
        v_request_params:='';
    END IF;


    BEGIN
    SELECT PLSQL_PACKAGE, ENABLED 
    INTO v_plsql_package, v_enabled
    FROM PROC_MODULE_CONFIG
    WHERE PROC_MODULE = v_proc_module;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_enabled := 'N';
    END;

    IF v_enabled = 'Y' THEN
        pl_text_log.ins_msg_async('INFO', 'DBMS_HOST_COMMAND_FUNC', 'Calling the PLSQL package[' || v_plsql_package || ']', NULL, NULL);
        v_stmt := 'BEGIN ' || v_plsql_package || '.P_EXECUTE_FRM(:1, :2, :3); END;' ;
        EXECUTE IMMEDIATE v_stmt USING IN p_userid, IN v_request_params, OUT v_result;
    ELSE
        pl_text_log.ins_msg_async('INFO', 'DBMS_HOST_COMMAND_FUNC', 'Calling the external host command [' || p_command || ']', NULL, NULL);
        v_result:= DBMS_HOST_COMMAND_FUNC_EXT(p_userid, p_command);
    END IF;
    
    RETURN v_result;

    
    EXCEPTION
     WHEN OTHERS THEN
      pl_text_log.ins_msg_async('WARN', 'DBMS_HOST_COMMAND_FUNC', 'Command execution failed [' || v_command_temp || ']' || 'parameters [' || v_request_params || ']', NULL, NULL);
END;
/
