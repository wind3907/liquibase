create or replace PROCEDURE KILL_IDLE_BLOCKER AS 
    status VARCHAR2(500);
    serial VARCHAR2(500);

    CURSOR blocked_sessions
      IS
        select
            blocking_session,
            sid,
            wait_class,
            seconds_in_wait,
            user,
            machine,
            port,
            program
        from
            v$session
        where
            blocking_session is not NULL and seconds_in_wait>300
        order by
            blocking_session;
BEGIN
  $if swms.platform.SWMS_REMOTE_DB $then
  FOR blocked_session IN blocked_sessions
  LOOP    
    select STATUS,serial#
    into status,serial
    from v$session where SID=blocked_session.blocking_session; 
    IF status = 'INACTIVE' THEN
      rdsadmin.rdsadmin_util.kill(
              sid    => blocked_session.blocking_session,
              serial => serial);
      dbms_output.put_line('Killed session id:'|| blocked_session.blocking_session || ', user: '|| blocked_session.user || 
      ', machine:' || blocked_session.machine ||':'|| blocked_session.port|| ', Program: '|| blocked_session.program);
      pl_text_log.ins_msg('INFO', 'KILL_IDLE_BLOCKER', 'Killed session id:'|| blocked_session.blocking_session || ', user: '|| blocked_session.user || 
      ', machine:' || blocked_session.machine ||':'|| blocked_session.port|| ', Program: '|| blocked_session.program, NULL, NULL); 
    END IF;
  END LOOP;
  $else
    DBMS_OUTPUT.PUT_LINE('Kill idle blocker procedure is only required when DB is remote'); 
  $end
END KILL_IDLE_BLOCKER;
/


DECLARE
    l_job_exists      NUMBER;
    l_program_exists  NUMBER;
BEGIN
    $if swms.platform.SWMS_REMOTE_DB $then
    SELECT
        COUNT(*)
    INTO l_job_exists
    FROM
        user_scheduler_jobs
    WHERE
            job_name = 'KILL_IDLE_BLOCKER_SESSION_JOB';

    IF l_job_exists = 1 THEN
        dbms_scheduler.drop_job(job_name => 'KILL_IDLE_BLOCKER_SESSION_JOB');
    END IF;

    SELECT
        COUNT(*)
    INTO l_program_exists
    FROM
        user_scheduler_programs
    WHERE
            program_name = 'KILL_IDLE_BLOCKER_SESSION_PROG';

    IF l_program_exists = 1 THEN
        dbms_scheduler.drop_program(program_name => 'KILL_IDLE_BLOCKER_SESSION_PROG');
    END IF;
    $else
    	DBMS_OUTPUT.PUT_LINE('Kill idle blocker procedure is only required when DB is remote');
    $end
END;
/


BEGIN
	$if swms.platform.SWMS_REMOTE_DB $then
		DBMS_SCHEDULER.CREATE_PROGRAM (
		   program_name          => 'KILL_IDLE_BLOCKER_SESSION_PROG',
		   program_type          => 'PLSQL_BLOCK',
		   program_action        => 'BEGIN KILL_IDLE_BLOCKER; END;',
		   number_of_arguments   => 0,
		   enabled               => TRUE,
		   comments              => 'Kill blocker sessions which are in inactive state');
    $else
        DBMS_OUTPUT.PUT_LINE('Kill idle blocker program is only required when DB is remote'); 
	$end  
END;
/
	
	
BEGIN
	$if swms.platform.SWMS_REMOTE_DB $then
		DBMS_SCHEDULER.CREATE_JOB (
		   job_name             => 'KILL_IDLE_BLOCKER_SESSION_JOB',
		   program_name         => 'KILL_IDLE_BLOCKER_SESSION_PROG',
		   start_date           => '11-AUG-20 1.00.00AM US/Central',
		   repeat_interval      => 'FREQ=MINUTELY;INTERVAL=2',
		   enabled              =>  TRUE,
		   comments             => 'Kill blocker sessions which are in inactive state');
 	$else
        DBMS_OUTPUT.PUT_LINE('Kill idle blocker job is only required when DB is remote'); 
	$end    
END;
/
	
prompt 'KILL_IDLE_BLOCKER_SESSION_JOB scheduler created';
