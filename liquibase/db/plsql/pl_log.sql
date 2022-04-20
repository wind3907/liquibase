-----------------------------------------------------------------------------
-- Package Name:
--    pl_matrix_op
--
-- Description:
--    Message logging.
--    This package has procedures to insert into table SWMS_LOG.
--
--    The messages can be seen in the "SWMS Log Messages" screen.
--    Menu option Maintenance-->swms loG.
--
-- Columns:
--    process_id   => sequence swms_log_seq will generate the number
--    user_id	   => user id without OPS$ 
--    userenv_id   => userenv('sessionid') session id
--    add_date	   => system date
--    application_func => R = RECEIVING
--                        O = ORDER PROCESS
--                        M = MAINTENANCE,
--                        L = LABOR
--                        I = INVENTORY
--                        D = DRIVER CHECK-IN
--    msg_type     => FATAL
--                    WARN
--                    ERROR
--                    INFO
--                    DEBUG
--    program_name => the program name
--    msg_no  	   => message number use for RF gun code tie with swms_message tbl
--    msg_text	   => message line indicate the problem
--    sql_err_msg  => Any oracle error with oracle message.
--
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    08/29/00 prpksn   Initial version
--    08/20/02 acpakp   Added one more procedure to pass the global
--                      variables as parameters.
--    07/09/03 prpbcb   Add automomous transaction to procedure ins_msg so
--                      that the log record is always committed.
--    04/15/10 sray0453 #D12529
--                      Added procedure ins_msg with 8 parameters for PATROL 
--                      to pickup error message and notify support group.
--  
--    04/17/13 prpbcb   TFS:
--     R12.5.1--WIB#65--CRQ45941_Original_CRQ45202 Order generation shorting items with inventory because of record lock
-- 
--                      Allow USER MSG as an application function.
--                      This is are way (for now) to have a message
--                      specifically for the user.
--  
--                      Added procedures:
--                         - blocking_locks
--                         - locks_on_a_table
--  
--    10/24/14 prpbcb   Symbotic project.
--
--                      Added constants for the message types to reference in
--                      calls to pl_log.ins_log.
--                         - ct_debug_msg
--                         - ct_error_msg
--                         - ct_fatal_msg
--                         - ct_info_msg
--                         - ct_warn_msg
--  
--    12/15/14 prpbcb   Symbotic project.
--                      Log "error" messages too by changing
--    (l_msg_type in ('FATAL', 'WARN', 'INFO')) then
--                      to
--    (l_msg_type in ('FATAL', 'WARN', 'INFO', 'ERROR')) then
--
--
--    12/11/19 bben0556 Brian Bent
--                      Project: R30.6.9--CMU-Jira-OPCOF-2682-Allocation_shorting_and_inv_status_set_to_ERR
--
--                      Comment out unnecessary dbms_output as they clutter the output.
--
--
-----------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE swms.pl_log AS

  /* This two global below need to define one time in the calling program */
  g_application_func  swms_log.application_func%TYPE := 'UNDEFINE';
  g_program_name      swms_log.program_name%TYPE := 'UNDEFINE';
  
  /* Global varible declaration for passing MSG_ALERT value*/
  
  g_msg_alert         swms_log.msg_alert%TYPE :='N';
  
  g_debug_on    boolean;

---------------------------------------------------------------------------
-- Public Constants
---------------------------------------------------------------------------

------------------------------
-- Log message types.
------------------------------
ct_debug_msg     CONSTANT VARCHAR2(1) := 'D';   -- Debug
ct_error_msg     CONSTANT VARCHAR2(1) := 'E';   -- User error, setup issue, configuration issue
ct_fatal_msg     CONSTANT VARCHAR2(1) := 'F';   -- Fatal error
ct_info_msg      CONSTANT VARCHAR2(1) := 'I';   -- Informational
ct_warn_msg      CONSTANT VARCHAR2(1) := 'W';   -- Warning

 
---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

  PROCEDURE ins_msg (i_msg_type          in swms_log.msg_type%TYPE,
		     i_procedure_name    in swms_log.procedure_name%TYPE,
		     i_msg_text		 in swms_log.msg_text%TYPE,
		     i_msg_no            in swms_log.msg_no%TYPE,
		     i_sql_err_msg	 in swms_log.sql_err_msg%TYPE);

  /* Added this procedure to call this package from forms as we cannot 
     set the global variables in forms. These global variables are passed
     as parameters and is set in this procedure */

  PROCEDURE ins_msg (i_msg_type          in swms_log.msg_type%TYPE,
                     i_procedure_name    in swms_log.procedure_name%TYPE,
                     i_msg_text          in swms_log.msg_text%TYPE,
                     i_msg_no            in swms_log.msg_no%TYPE,
                     i_sql_err_msg       in swms_log.sql_err_msg%TYPE,
                     i_application_func  in swms_log.application_func%TYPE,
                     i_program_name      in swms_log.program_name%TYPE);
 
 /*Added this procedure to call this package from SWMS interfaces 
   with parameter i_msg_alert to notify PATROL to pick this message 
   for further processing */
   
 PROCEDURE ins_msg (i_msg_type          in swms_log.msg_type%TYPE,
                    i_procedure_name    in swms_log.procedure_name%TYPE,
                    i_msg_text          in swms_log.msg_text%TYPE,
                    i_msg_no            in swms_log.msg_no%TYPE,
                    i_sql_err_msg       in swms_log.sql_err_msg%TYPE,
                    i_application_func  in swms_log.application_func%TYPE,
                    i_program_name      in swms_log.program_name%TYPE,
                    i_msg_alert         in swms_log.msg_alert%TYPE);                
                   
                   

  FUNCTION f_debug_syspar return BOOLEAN;

---------------------------------------------------------------------------
-- Procedure:
--    blocking_locks
--
-- Description:
--    This procedure logs the locks held by a session that are locking
--    out other sessions.
--
--    This procedure is designed to be called whan a lock is detected.
---------------------------------------------------------------------------
PROCEDURE blocking_locks
             (i_blockee_sid  IN NUMBER   DEFAULT NULL,
              i_message      IN VARCHAR2 DEFAULT NULL);


---------------------------------------------------------------------------
-- Procedure:
--    locks_on_a_table
--
-- Description:
--    This procedure logs the locks on the specified table.
--
--    This procedure is designed to be called whan a lock is detected.
--
-- Parameters:
--    i_table_name - Table name to check for a lock.
--    i_sid_to_exclude  - Exclude locks for this SID.
--                        This should be th SID of the session
--                        requesting the lock.
--                        04/21/2013  Brian Bent  During testing
--                        locks were shown on the i_table_name table even
--                        by the SID reqesting the lock.  Not sure why.
---------------------------------------------------------------------------
PROCEDURE locks_on_a_table
             (i_table_name      IN VARCHAR2,
              i_sid_to_exclude  IN NUMBER);

end pl_log;
/


create or replace PACKAGE BODY swms.pl_log AS
  
  FUNCTION  f_debug_syspar RETURN BOOLEAN
  IS
    l_flag_val  sys_config.config_flag_val%TYPE;
  begin
  /* Initialization section. It will run only one time */
     select config_flag_val into l_flag_val
     from sys_config
     where config_flag_name = 'DEBUG_SWMS_LOG';

     if l_flag_val = 'Y' then
	return TRUE;
     else 
	return FALSE;
     end if;
     exception 
       when no_data_found then
	return FALSE;
       when others then
	 ins_msg('F','pl_log.debug_flag',
	  'WHEN others exception raise in pl_log package',null,null);
      
  end f_debug_syspar;
/* *********************************************************************** */
 PROCEDURE ins_msg (i_msg_type          in swms_log.msg_type%TYPE,
                    i_procedure_name    in swms_log.procedure_name%TYPE,
                    i_msg_text          in swms_log.msg_text%TYPE,
                    i_msg_no            in swms_log.msg_no%TYPE,
                    i_sql_err_msg       in swms_log.sql_err_msg%TYPE,
                    i_application_func  in swms_log.application_func%TYPE,
                    i_program_name      in swms_log.program_name%TYPE) is
 begin
   g_application_func := i_application_func;
   g_program_name := i_program_name;
   ins_msg(i_msg_type,i_procedure_name,i_msg_text,i_msg_no,i_sql_err_msg);
 end;

 /* *********************************************************************** */
 
     PROCEDURE ins_msg (i_msg_type          in swms_log.msg_type%TYPE,
                        i_procedure_name    in swms_log.procedure_name%TYPE,
                        i_msg_text          in swms_log.msg_text%TYPE,
                        i_msg_no            in swms_log.msg_no%TYPE,
                        i_sql_err_msg       in swms_log.sql_err_msg%TYPE,
                        i_application_func  in swms_log.application_func%TYPE,
                        i_program_name      in swms_log.program_name%TYPE,
                        i_msg_alert         in swms_log.msg_alert%TYPE) is
     begin
       g_application_func := i_application_func;
       g_program_name := i_program_name;
       g_msg_alert := i_msg_alert;
       
       ins_msg(i_msg_type,i_procedure_name,i_msg_text,i_msg_no,i_sql_err_msg);
     end;

/* *********************************************************************** */   
 
 
  PROCEDURE ins_msg (i_msg_type          in swms_log.msg_type%TYPE,
		     i_procedure_name    in swms_log.procedure_name%TYPE,
		     i_msg_text          in swms_log.msg_text%TYPE,
		     i_msg_no            in swms_log.msg_no%TYPE,
		     i_sql_err_msg       in swms_log.sql_err_msg%TYPE) is

   PRAGMA AUTONOMOUS_TRANSACTION;

   l_msg_type swms_log.msg_type%TYPE;

begin
   l_msg_type := i_msg_type;

   -- dbms_output.put_line('l_msg_type[' || l_msg_type || ']');

   if l_msg_type not in ('FATAL','WARN','INFO','DEBUG') then
        SELECT DECODE(SUBSTR(UPPER(l_msg_type), 1, 1),
                      'F', 'FATAL',
                      'W', 'WARN',
                      'E', 'ERROR',
                      'I', 'INFO',
                      'D', 'DEBUG',
                      'INFO')
          into l_msg_type
        from dual;
        -- dbms_output.put_line('l_msg_type 2[' || l_msg_type || ']');
   end if;

   -- dbms_output.put_line('l_msg_type 3[' || l_msg_type || ']');

   if (pl_log.g_debug_on and l_msg_type = 'DEBUG') OR
      (l_msg_type in ('FATAL', 'WARN', 'INFO', 'ERROR')) then

     -- dbms_output.put_line('l_msg_type 4[' || l_msg_type || ']');

     insert into swms_log
       (process_id,userenv_id,user_id,add_date,
        application_func,
        msg_type, program_name, procedure_name, msg_no, msg_text,
        sql_err_msg,msg_alert)
     select swms_log_seq.nextval,userenv('SESSIONID'),replace(USER,'OPS$',null),
       sysdate,
       DECODE(SUBSTR(UPPER(pl_log.g_application_func),1,1),
                     'R', 'RECEIVING',
                     'O', 'ORDER PROCESS',
                     'M', 'MAINTENANCE',
                     'I', 'INVENTORY',
                     'D', 'DRIVER CHECKIN',
                     'L', 'LABOR MGT',
                     'U', 'USER MSG',
                     NVL(UPPER(pl_log.g_application_func),'UNKNOWN')),
       l_msg_type,g_program_name,i_procedure_name,i_msg_no,
       i_msg_text, i_sql_err_msg,g_msg_alert
     from dual
     where rownum=1;

     -- dbms_output.put_line('l_msg_type 5[' || l_msg_type || ']');

     COMMIT;
   end if;
EXCEPTION
   WHEN OTHERS THEN
      dbms_output.put_line('l_msg_type 6[' || l_msg_type || ']' || sqlerrm);
      -- Cannot do much else but rollback.
      ROLLBACK;
end ins_msg;


---------------------------------------------------------------------------
-- Procedure:
--    blocking_locks
--
-- Description:
--    This procedure logs the locks held by a session that are locking
--    out other sessions.
--
--    This procedure is designed to be called whan a lock is detected.
--
-- Parameters:
--    i_blockee_sid  - The ORACLE SID that is wanting to obtain a lock.
--                     If null then all sessions locking out other sessions
--                     are logged.
--    i_message      - Text to add to the end of the message built by
--                     this procedure.  This can be null if desired but
--                     it should be provided given since the message created
--                     by this procedure has a format of:
--        User ... has a lock on table ... which is preventing user ...
--        from <i_message>
--
-- Called by:
--    
--
-- Exceptions raised:
--    None.  An error here will not stop processing but an aplog message
--    will be written.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/18/13 prpbcb   Created.
--                      I created this to use for the order generation
--                      short issue due to another session hold a lock.
--                      But I will not be using this procedure for that.
--                      I will use locks_on_a_table() instead.
--                      I will leave this procedure to be used later,
--                      maybe.
---------------------------------------------------------------------------
PROCEDURE blocking_locks
             (i_blockee_sid  IN NUMBER   DEFAULT NULL,
              i_message      IN VARCHAR2 DEFAULT NULL)
IS
   l_msg            VARCHAR2(512);  -- Work area

   CURSOR c_lock(cp_blockee_sid NUMBER)
   IS
      SELECT REPLACE(blocker_session.username, 'OPS$', NULL)  blocker_name,
             blocker_usr.user_name     blocker_user_name,
             blocker.sid               blocker_sid,
             blocker_session.serial#   blocker_serial#,
             blocker_locks.name,
             --
             REPLACE(blockee_session.username, 'OPS$', NULL) blockee_name,
             blockee_usr.user_name    blockee_user_name,
             blockee.sid              blockee_sid,
             blockee_session.serial#  blockee_serial#
        FROM (SELECT sid, id1,id2 FROM v$lock WHERE  block = 1) blocker,
             (SELECT sid, id1,id2 FROM v$lock WHERE request > 0 ) blockee,
             --
             v$session blocker_session,
             v$session blockee_session,
             --
             sys.dba_dml_locks blocker_locks,
             --
             usr blocker_usr,   -- SWMS USR table to get user name
             usr blockee_usr    -- SWMS USR table to get user name
       WHERE blocker.id1              = blockee.id1
         AND blocker.id2              = blockee.id2
         AND blocker_session.sid      = blocker.sid
         AND blockee_session.sid      = blockee.sid
         AND blocker_locks.session_id = blocker.sid
         AND blocker_usr.user_id (+)  = blocker_session.username
         AND blockee_usr.user_id (+)  = blockee_session.username
         AND blockee.sid              = NVL(cp_blockee_sid, blockee.sid);
BEGIN
   l_msg := NULL;

   FOR r_lock IN c_lock(i_blockee_sid) LOOP
      l_msg := 'LOCK MSG-User ' || r_lock.blocker_name
         || '(' || r_lock.blocker_user_name
         || ', sid ' || TO_CHAR(r_lock.blocker_sid)
         || ', serial# ' || TO_CHAR(r_lock.blocker_serial#) || ')'
         || ' has a lock on table "' || r_lock.name || '" which is preventing user '
         || r_lock.blockee_name
         || '(' || r_lock.blockee_user_name
         || ', sid ' || TO_CHAR(r_lock.blockee_sid)
         || ', serial# ' || TO_CHAR(r_lock.blockee_serial#) || ') from '
         || i_message;

      DBMS_OUTPUT.PUT_LINE(l_msg);

      pl_log.ins_msg(pl_lmc.ct_warn_msg, 'blocking_locks',
                     l_msg,
                     NULL, NULL,
                     'MAINTENANCE', 'pl_log');
   END LOOP;

   --
   -- Check if a locks held message was created.  If not then either this
   -- procedure was called when there were no locks or the lock was
   -- released by the time this procedure was called.
   --
   IF (l_msg IS NULL) THEN
      l_msg := 'LOCK MSG-i_blockee_sid[' || TO_CHAR(i_blockee_sid) || ']'
            || '  No locks blocking another session were found.';

      DBMS_OUTPUT.PUT_LINE(l_msg);

      pl_log.ins_msg(pl_lmc.ct_warn_msg, 'blocking_held',
                     l_msg,
                     NULL, NULL,
                     'MAINTENANCE', 'pl_log');
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log a message but do not stop processing.
      --
      pl_log.ins_msg(pl_lmc.ct_warn_msg, 'blocking_locks',
                     '(i_blockee_sid[' || TO_CHAR(i_blockee_sid) || ']'
                     || ' i_message[' || i_message || '])'
                     || '  Error occurred,  This will not stop processing.',
                     SQLCODE, SQLERRM,
                     'MAINTENANCE', 'pl_log');
END blocking_locks;


---------------------------------------------------------------------------
-- Procedure:
--    locks_on_a_table
--
-- Description:
--    This procedure logs the locks on the specified table.
--
--    This procedure is designed to be called whan a lock is detected.
--
-- Parameters:
--    i_table_name - Table name to check for a lock.
--    i_sid_to_exclude  - Exclude locks for this SID.
--                        This should be th SID of the session
--                        requesting the lock.
--                        04/21/2013  Brian Bent  During testing
--                        locks were shown on the i_table_name table even
--                        by the SID reqesting the lock.  Not sure why.
--                        Could be because we are using
--                        PRAGMA AUTONOMOUS_TRANSACTION.
--                        So I added i_sid_to_exclude.
--
-- Called by:
--    
--
-- Exceptions raised:
--    None.  An error here will not stop processing but an aplog message
--    will be written.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/18/13 prpbcb   Created.
---------------------------------------------------------------------------
PROCEDURE locks_on_a_table
             (i_table_name      IN VARCHAR2,
              i_sid_to_exclude  IN NUMBER)
IS
   l_msg            VARCHAR2(512);  -- Work area

   CURSOR c_lock(cp_table_name  VARCHAR2)
   IS
      SELECT REPLACE(sess.username, 'OPS$', NULL) db_user_name,
             usr.user_name          user_name,
             sess.sid               sid,
             sess.serial#           serial#,
             sess.command           command,
             locks.name             name,
             sess.program           program,
             SYS_CONTEXT('USERENV', 'SID') current_user_sid
        FROM v$session sess,
             sys.dba_dml_locks locks,
             usr         -- SWMS USR table to get full user name
       WHERE usr.user_id (+)  = sess.username
         AND sess.sid         <> i_sid_to_exclude
         AND sess.sid         = locks.session_id
         AND locks.name       = UPPER(cp_table_name);

BEGIN
   l_msg := NULL;

   FOR r_lock IN c_lock(i_table_name) LOOP
      l_msg :=
           'LOCK MSG-Lock on table '
         || '"' || r_lock.name  || '"'
         || ' by user '      || r_lock.db_user_name
         || '  Name['        || r_lock.user_name        || ']'
         || '  SID['         || TO_CHAR(r_lock.sid)     || ']'
         || '  Serial#['     || TO_CHAR(r_lock.serial#) || ']'
         || '  Program['     || r_lock.program          || ']'
         || '  Locks by SID ' || TO_CHAR(i_sid_to_exclude) || '(i_sid_to_exclude)'
         || ', are not shown.'
         || '  The SID of the current user is ' || r_lock.current_user_sid;

      DBMS_OUTPUT.PUT_LINE(l_msg);

      pl_log.ins_msg(pl_lmc.ct_warn_msg, 'locks_on_a_table',
                     l_msg,
                     NULL, NULL,
                     'USER MSG', 'pl_log');
   END LOOP;

   --
   -- Check if a locks held message was created.  If not then either this
   -- procedure was called when there were no locks or the lock was
   -- released by the time this procedure was called.
   --
   IF (l_msg IS NULL) THEN
      l_msg := 'LOCK MSG-No locks found on table "' || i_table_name || '"';

      DBMS_OUTPUT.PUT_LINE(l_msg);

      pl_log.ins_msg(pl_lmc.ct_warn_msg, 'locks_on_a_table',
                     l_msg,
                     NULL, NULL,
                     'USER MSG', 'pl_log');
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log a message but do not stop processing.
      --
      pl_log.ins_msg(pl_lmc.ct_warn_msg, 'locks_on_a_table',
                     '(i_table_name[' || i_table_name || '])'
                     || '  Error occurred,  This will not stop processing.',
                     SQLCODE, SQLERRM,
                     'MAINTENANCE', 'pl_log');
END locks_on_a_table;


/* Package initialization. Initialize the sys config value for DEBUG */
BEGIN
  g_debug_on := f_debug_syspar;  
END pl_log;
/
