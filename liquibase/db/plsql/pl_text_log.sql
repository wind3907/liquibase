CREATE OR REPLACE  PACKAGE "SWMS"."PL_TEXT_LOG"  AS
   /* This two global below need to define one time in the calling program */
   g_application_func   swms_log.application_func%TYPE   := 'UNDEFINE';
   g_program_name       swms_log.program_name%TYPE       := 'UNDEFINE';
   g_debug_on           BOOLEAN;
   g_machine            v$session.machine%TYPE;
   g_osuser             v$session.osuser%TYPE;
   g_module             v$session.module%TYPE;
   g_process            v$session.process%TYPE;
   
$if swms.platform.SWMS_PLATFORM_LINUX $then
$else
    g_syslog_data		pls_integer := 0;	-- actually a pointer
$end

	-- Constants from <aplog.h>

   /*
   ** Facility Constants
   */
   APLOG_APCOM		constant PLS_INTEGER := 0;	/* Application Communications */
   APLOG_SWMS		constant PLS_INTEGER := 1;	/* Warehouse Management System */
   APLOG_SOCERS		constant PLS_INTEGER := 2;	/* Apcom/SWMS Build Procedures */
   APLOG_DISTRIBUTE	constant PLS_INTEGER := 3;	/* Code Distribution */

   /*
   ** Severity Constants
   */
   APLOG_EMERGENCY	constant PLS_INTEGER := 0;	/* A panic condition, system unusable */
   APLOG_ALERT		constant PLS_INTEGER := 1;	/* Condition must be corrected immediately */
   APLOG_CRITICAL	constant PLS_INTEGER := 2;	/* Critical error, many applications terminated */
   APLOG_ERROR		constant PLS_INTEGER := 3;	/* Error, application terminated */
   APLOG_WARNING		constant PLS_INTEGER := 4;	/* Warning, application may terminate */
   APLOG_NOTICE		constant PLS_INTEGER := 5;	/* Not error, but requires special attention */
   APLOG_INFO		constant PLS_INTEGER := 6;	/* Informational message */
   APLOG_DEBUG		constant PLS_INTEGER := 7;	/* Info to debug a program */
   
   /* Initialize the program to be written to the SWMS log by APCOM */
   PROCEDURE init (
      i_program_name     IN   swms_log.program_name%TYPE
   );
   PROCEDURE ins_msg (
      i_msg_type         IN   swms_log.msg_type%TYPE,
      i_procedure_name   IN   swms_log.procedure_name%TYPE,
      i_msg_text         IN   swms_log.msg_text%TYPE,
      i_msg_no           IN   swms_log.msg_no%TYPE,
      i_sql_err_msg      IN   swms_log.sql_err_msg%TYPE
   );
   /* Added this procedure to call this package from forms as we cannot
      set the global variables in forms. These global variables are passed
      as parameters and is set in this procedure */
   PROCEDURE ins_msg (
      i_msg_type           IN   swms_log.msg_type%TYPE,
      i_procedure_name     IN   swms_log.procedure_name%TYPE,
      i_msg_text           IN   swms_log.msg_text%TYPE,
      i_msg_no             IN   swms_log.msg_no%TYPE,
      i_sql_err_msg        IN   swms_log.sql_err_msg%TYPE,
      i_application_func   IN   swms_log.application_func%TYPE,
      i_program_name       IN   swms_log.program_name%TYPE
   );
   PROCEDURE ins_msg (
      i_msg_type         IN   swms_log.msg_type%TYPE,
      i_procedure_name   IN   swms_log.procedure_name%TYPE,
      i_msg_text         IN   swms_log.msg_text%TYPE,
      i_msg_no           IN   swms_log.msg_no%TYPE,
      i_sql_err_msg      IN   swms_log.sql_err_msg%TYPE,
      i_machine          IN   v$session.machine%TYPE,
      i_osuser           IN   v$session.osuser%TYPE,
      i_process          IN   v$session.process%TYPE,
      i_timestamp        IN   DATE
   );
   PROCEDURE ins_msg_async (
      i_msg_type         IN   swms_log.msg_type%TYPE,
      i_procedure_name   IN   swms_log.procedure_name%TYPE,
      i_msg_text         IN   VARCHAR2,
      i_msg_no           IN   swms_log.msg_no%TYPE,
      i_sql_err_msg      IN   swms_log.sql_err_msg%TYPE
   );
   PROCEDURE ins_msg_async (
      i_msg_type           IN   swms_log.msg_type%TYPE,
      i_procedure_name     IN   swms_log.procedure_name%TYPE,
      i_msg_text           IN   swms_log.msg_text%TYPE,
      i_msg_no             IN   swms_log.msg_no%TYPE,
      i_sql_err_msg        IN   swms_log.sql_err_msg%TYPE,
      i_application_func   IN   swms_log.application_func%TYPE,
      i_program_name       IN   swms_log.program_name%TYPE
   );
   PROCEDURE ins_msg_async_agent(
      context raw,
      reginfo sys.aq$_reg_info,
      descr sys.aq$_descriptor,
      payload raw,
      payloadl number
   );
   FUNCTION f_debug_syspar
      RETURN BOOLEAN;
END pl_text_log;
/

CREATE OR REPLACE  PACKAGE BODY "SWMS"."PL_TEXT_LOG"  AS

FUNCTION f_debug_syspar
   RETURN BOOLEAN
IS
   l_flag_val sys_config.config_flag_val%TYPE;
BEGIN
   /* Initialization section. It will run only one time */
   BEGIN
      SELECT process, module, machine, REPLACE(USER,'OPS$')
        INTO g_process, g_module, g_machine, g_osuser
        FROM v$session WHERE audsid = userenv('SESSIONID');
   EXCEPTION
      WHEN OTHERS THEN
         g_process := NULL;
         g_module := 'unknown';
         g_machine := 'local';
         g_osuser := REPLACE(USER,'OPS$');
   END;

   SELECT config_flag_val
     INTO l_flag_val
     FROM sys_config
    WHERE config_flag_name = 'DEBUG_SWMS_LOG';

   IF l_flag_val = 'Y' THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN FALSE;
   WHEN OTHERS THEN
      ins_msg ('F',
               'pl_text_io_log.f_debug_syspar',
               'WHEN others exception raised in pl_text_io_log package',
               SQLCODE,
               SQLERRM
              );
END f_debug_syspar;

/* *********************************************************************** */
PROCEDURE init (
   i_program_name       IN   swms_log.program_name%TYPE
)
IS
   rc PLS_INTEGER;
BEGIN
   g_program_name := i_program_name;
END;

/* *********************************************************************** */
PROCEDURE ins_msg (
   i_msg_type         IN   swms_log.msg_type%TYPE,
   i_procedure_name   IN   swms_log.procedure_name%TYPE,
   i_msg_text         IN   swms_log.msg_text%TYPE,
   i_msg_no           IN   swms_log.msg_no%TYPE,
   i_sql_err_msg      IN   swms_log.sql_err_msg%TYPE
)
IS
   rc PLS_INTEGER;
BEGIN
   ins_msg (i_msg_type,
            i_procedure_name,
            i_msg_text,
            i_msg_no,
            i_sql_err_msg,
            g_machine,
            g_osuser,
            g_process,
            SYSDATE
           );
END;

/* *********************************************************************** */
PROCEDURE ins_msg (
   i_msg_type           IN   swms_log.msg_type%TYPE,
   i_procedure_name     IN   swms_log.procedure_name%TYPE,
   i_msg_text           IN   swms_log.msg_text%TYPE,
   i_msg_no             IN   swms_log.msg_no%TYPE,
   i_sql_err_msg        IN   swms_log.sql_err_msg%TYPE,
   i_application_func   IN   swms_log.application_func%TYPE,
   i_program_name       IN   swms_log.program_name%TYPE
)
IS
   rc PLS_INTEGER;
BEGIN
   init(i_program_name);
   g_application_func := i_application_func;
   g_program_name := i_program_name;
   ins_msg (i_msg_type,
            i_procedure_name,
            i_msg_text,
            i_msg_no,
            i_sql_err_msg,
            g_machine,
            g_osuser,
            g_process,
            SYSDATE
           );
END;

/* *********************************************************************** */
PROCEDURE ins_msg (
   i_msg_type         IN   swms_log.msg_type%TYPE,
   i_procedure_name   IN   swms_log.procedure_name%TYPE,
   i_msg_text         IN   swms_log.msg_text%TYPE,
   i_msg_no           IN   swms_log.msg_no%TYPE,
   i_sql_err_msg      IN   swms_log.sql_err_msg%TYPE,
   i_machine          IN   v$session.machine%TYPE,
   i_osuser           IN   v$session.osuser%TYPE,
   i_process          IN   v$session.process%TYPE,
   i_timestamp        IN   DATE
)
IS
   l_msg_type PLS_INTEGER;
   rc PLS_INTEGER;

   msg_txt VARCHAR2(1000);
   $if swms.platform.SWMS_PLATFORM_LINUX $then
      req utl_http.req;
      os_type VARCHAR2(10);
      resp  utl_http.resp;
      resp_value VARCHAR2(100);
      http_req_string VARCHAR2(2000);
      l_swms_host_syspar sys_config.config_flag_val%TYPE;
   $end

$if swms.platform.SWMS_PLATFORM_LINUX $then
$else
	syslog_rc		pls_integer;
	LogOption		pls_integer := pl_syslog.LOG_PID + pl_syslog.LOG_NOWAIT;
	Facility		pls_integer := pl_syslog.LOG_LOCAL3;		/* to swms.log */
	pri				pls_integer;
$end

BEGIN
   IF UPPER(SUBSTR(i_msg_type,1,1)) = 'F' THEN
      l_msg_type := pl_text_log.APLOG_ALERT;
		pri := pl_syslog.LOG_ALERT;
   ELSIF UPPER(SUBSTR(i_msg_type,1,1)) = 'W' THEN
      l_msg_type := pl_text_log.APLOG_WARNING;
		pri := pl_syslog.LOG_WARNING;
   ELSIF UPPER(SUBSTR(i_msg_type,1,1)) = 'D' THEN
      l_msg_type := pl_text_log.APLOG_DEBUG;
		pri := pl_syslog.LOG_DEBUG;
   ELSE
      l_msg_type := pl_text_log.APLOG_INFO;
		pri := pl_syslog.LOG_INFO;
   END IF;

   IF (pl_text_log.g_debug_on AND l_msg_type = pl_text_log.APLOG_DEBUG)
      OR l_msg_type <> pl_text_log.APLOG_DEBUG THEN

$if swms.platform.SWMS_PLATFORM_LINUX $then
      msg_txt := TO_CHAR(NVL(i_timestamp, SYSDATE),'Mon  DD HH24:MI:SS') || ' ' ||
                 i_machine || ' ' || i_osuser || ' ' || g_program_name || ' ' ||
                 i_process || ' : [' || i_procedure_name || '] msg_no=[' ||
                 TO_CHAR(i_msg_no) || '] ' || 'msg=[' || i_msg_text ||
                 ']';
 $else
      msg_txt := i_osuser || ' [' || TO_CHAR(i_msg_no) || ']' || i_msg_text;
 $end
                 
      IF i_sql_err_msg IS NOT NULL THEN
         msg_txt := msg_txt || ' : sqlerrm=[' || i_sql_err_msg || ']';
      END IF;

      $if swms.platform.SWMS_PLATFORM_LINUX $then
        $if swms.platform.SWMS_REMOTE_DB $then
           l_swms_host_syspar := pl_common.f_get_syspar('SWMS_HOST', 'localhost');
        $else
           l_swms_host_syspar := 'localhost';
        $end

         http_req_string := 'http://' || l_swms_host_syspar || ':39005/?log=' || msg_txt;
         http_req_string := utl_url.escape(http_req_string);
         req := utl_http.begin_request(http_req_string, 'GET');
         resp := utl_http.get_response(req);
         UTL_HTTP.read_text(resp, resp_value);
         utl_http.end_response(resp);
      $else
			if g_syslog_data = 0	-- first time initialization
			then
				g_syslog_data	:= pl_syslog.new_syslog_data();
				syslog_rc		:= pl_syslog.openlog_r(i_procedure_name,LogOption,Facility,g_syslog_data);
			end if;

			syslog_rc := pl_syslog.syslog_r(pri,g_syslog_data,msg_txt);
      $end

   END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END ins_msg;

/* *********************************************************************** */
PROCEDURE ins_msg_async (
   i_msg_type         IN   swms_log.msg_type%TYPE,
   i_procedure_name   IN   swms_log.procedure_name%TYPE,
   i_msg_text         IN   VARCHAR2,
   i_msg_no           IN   swms_log.msg_no%TYPE,
   i_sql_err_msg      IN   swms_log.sql_err_msg%TYPE
)
IS
$if swms.platform.SWMS_REMOTE_DB $then
   rc PLS_INTEGER;
   l_enqueue_options     dbms_aq.enqueue_options_t;
   l_message_properties  dbms_aq.message_properties_t;
   l_message_handle      RAW(16);
   l_message             swms.log_message_type;
$end
   l_msg_text swms_log.msg_text%TYPE;
   l_process VARCHAR2(200);
BEGIN
   l_msg_text:=substr(i_msg_text, 1,1999);
   l_process:=g_process;
   
   $if not dbms_db_version.ver_le_11 $then
       BEGIN
            l_process:=SUBSTR(utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(2)),1,199);
            if INSTR(l_process,'INS_MSG')>0 then
                l_process:=SUBSTR(utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(3)),1,199);
            end if;
       EXCEPTION
            WHEN OTHERS THEN
                l_process:=g_process;
        END;
   $end
   
   $if swms.platform.SWMS_REMOTE_DB $then
       l_message := swms.log_message_type(i_msg_type,
                     i_procedure_name,
                     l_msg_text,
                     i_msg_no,
                     i_sql_err_msg,
                     g_machine,
                     g_osuser,
                     l_process,
                     SYSDATE);
       l_enqueue_options.visibility := DBMS_AQ.IMMEDIATE;
       dbms_aq.enqueue(queue_name => 'async_log',
             enqueue_options      => l_enqueue_options,
             message_properties   => l_message_properties,
             payload              => l_message,
             msgid                => l_message_handle);
   $else
       ins_msg(
               i_msg_type,
               i_procedure_name,
               l_msg_text,
               i_msg_no,
               i_sql_err_msg,
               g_machine,
               g_osuser,
               g_process,
               SYSDATE
       );
   $end
END;

/* *********************************************************************** */
PROCEDURE ins_msg_async (
   i_msg_type           IN   swms_log.msg_type%TYPE,
   i_procedure_name     IN   swms_log.procedure_name%TYPE,
   i_msg_text           IN   swms_log.msg_text%TYPE,
   i_msg_no             IN   swms_log.msg_no%TYPE,
   i_sql_err_msg        IN   swms_log.sql_err_msg%TYPE,
   i_application_func   IN   swms_log.application_func%TYPE,
   i_program_name       IN   swms_log.program_name%TYPE
)
IS
   rc PLS_INTEGER;
BEGIN
     $if swms.platform.SWMS_REMOTE_DB $then
        init(i_program_name);
        g_application_func := i_application_func;
        g_program_name := i_program_name;
        ins_msg_async (i_msg_type,
               i_procedure_name,
               i_msg_text,
               i_msg_no,
               i_sql_err_msg
              );
    $else
        ins_msg(
                i_msg_type,
                i_procedure_name,
                i_msg_text,
                i_msg_no,
                i_sql_err_msg
            );
    $end
END;

/* *********************************************************************** */
procedure ins_msg_async_agent(
                       context raw
                      ,reginfo sys.aq$_reg_info
                      ,descr sys.aq$_descriptor
                      ,payload raw
                      ,payloadl number
                      )
  as
     $if swms.platform.SWMS_REMOTE_DB $then
        l_log_msg     log_message_type;
        l_msg_props   dbms_aq.message_properties_t;
        l_queue_opts  dbms_aq.dequeue_options_t;
        l_msg_id      raw(16);
     $end
  begin
    $if swms.platform.SWMS_REMOTE_DB $then
        l_queue_opts.consumer_name := descr.consumer_name;
        l_queue_opts.msgid := descr.msg_id;
        l_queue_opts.visibility := DBMS_AQ.IMMEDIATE;
        dbms_aq.dequeue(descr.queue_name, l_queue_opts, l_msg_props, l_log_msg, l_msg_id);

        --there can be heavy load, but now just log
        ins_msg (l_log_msg.msg_type,
                l_log_msg.procedure_name,
                l_log_msg.msg_text,
                l_log_msg.msg_no,
                l_log_msg.sql_err_msg,
                l_log_msg.machine,
                l_log_msg.osuser,
                l_log_msg.process,
                SYSDATE
               );
      exception
        when others
          then
            DBMS_OUTPUT.PUT_LINE('Error occurred while sending logs to the http server');
    $else
             DBMS_OUTPUT.PUT_LINE('SWMS NON RDS mode');
    $end
  end;

/* Package initialization. Initialize the sys config value for DEBUG */
BEGIN
   g_debug_on := f_debug_syspar;
END pl_text_log;
/
