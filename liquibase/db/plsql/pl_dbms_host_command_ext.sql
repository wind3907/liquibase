create or replace FUNCTION "DBMS_HOST_COMMAND_FUNC_EXT" (
  p_userid  IN  VARCHAR2,
  p_command IN VARCHAR2
  ) RETURN VARCHAR2
AS
$if swms.platform.SWMS_REMOTE_DB $then
  endpoint            VARCHAR2 (20);
  json_in             VARCHAR2 (500);
  outvar              VARCHAR2 (500);
  result              VARCHAR2 (500);
  jo                  JSON_OBJECT_T;
  rc                  NUMBER;
  POST_REQUEST_FAILED EXCEPTION;
BEGIN

--  json_in := '{'
--    || '"command":"/swms/curr/bin/run_os_command ' || p_userid || ' ''source /swms/curr/bin/swms_profile;' || REPLACE(p_command, '"', '\"') || '''"'
--    || '}';

  -- char(39) is single quote
  -- char(34) is doble quotes

  json_in := '{'
    || '"command":"/swms/curr/bin/run_os_command ' || p_userid || ' ''source /swms/curr/bin/swms_profile;' 
    || REPLACE(REPLACE(p_command, Chr(39), Chr(34)), '"', '\"') || '''"'
    || '}';

    pl_text_log.ins_msg('FATAL', 'DBMS_HOST_COMMAND_FUNC', 'P_COMMAND=' || p_command ||']', NULL, NULL);

  endpoint:='execute';
  rc:=PL_CALL_REST.call_rest_post(json_in, endpoint, outvar);

  IF rc != 0 THEN
    RAISE POST_REQUEST_FAILED;
  END IF;

  jo := JSON_OBJECT_T.parse(outvar);
  result:=jo.get_string('result');
  RETURN(REPLACE(result, CHR(10), ''));
EXCEPTION
  WHEN POST_REQUEST_FAILED THEN
    pl_text_log.ins_msg('FATAL', 'DBMS_HOST_COMMAND_FUNC', 'POST Request Failed rc=[' || rc || ']', NULL, NULL);
  WHEN OTHERS THEN
    pl_text_log.ins_msg('FATAL', 'DBMS_HOST_COMMAND_FUNC', 'Failed Parsing Response=[' || outvar || ']', NULL, NULL);
END;
$else
LANGUAGE JAVA
NAME 'Host_call.executeCommand_host (java.lang.String, java.lang.String) return java.lang.String' ;
$end
/
