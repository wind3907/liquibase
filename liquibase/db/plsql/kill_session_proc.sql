create or replace procedure kill_session(
    sid IN VARCHAR2,
    serial IN VARCHAR2
) 
IS
  /* ------------------------------------------ */
  /* Procedure KILL_SESSION                     */
  /* CREATED BY - APRI0734                      */
  /* This is called by form session_lock.fmb    */
  /* To kill sessions.                          */
  /* ------------------------------------------ */
$if swms.platform.SWMS_REMOTE_DB $then
    BEGIN
        rdsadmin.rdsadmin_util.kill(sid, serial);
    END;
$else
    BEGIN
        EXECUTE IMMEDIATE 'ALTER SYSTEM KILL SESSION '''||sid || ',' || serial ||'''';
    END;
$end
/
show errors;
