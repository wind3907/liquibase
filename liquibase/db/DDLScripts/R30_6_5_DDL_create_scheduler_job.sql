BEGIN
DBMS_SCHEDULER.CREATE_PROGRAM (
   program_name          => 'DEQUEUE_FP_QUE_PROG',
   program_type          => 'PLSQL_BLOCK',
   program_action        => 'BEGIN PL_SPL_SEND_RECEIVE_MSGS.RECEIVE_MESSAGE; END;',
   number_of_arguments   => 0,
   enabled               => TRUE,
   comments              => 'Dequeue FP Queue Program');
END;
/


BEGIN
DBMS_SCHEDULER.CREATE_JOB (
   job_name             => 'DEQUEUE_FP_QUE_JOB',
   program_name         => 'DEQUEUE_FP_QUE_PROG',
   start_date           => '03-AUG-18 1.00.00AM US/Central',
   repeat_interval      => 'FREQ=MINUTELY;INTERVAL=1',
   --end_date             => '13-MAR-28 1.00.00AM US/Central',
   enabled              =>  TRUE,
   comments             => 'Dequeue FP Queue Job');
END;
/

prompt 'DEQUEUE_FP_QUE_JOB scheduler created';


BEGIN
DBMS_SCHEDULER.CREATE_PROGRAM (
   program_name          => 'PROCESS_FP_INBOUND_PROG',
   program_type          => 'PLSQL_BLOCK',
   program_action        => 'BEGIN PL_SPL_IN.MQ_PROCESS_Q_NAME; END;',
   number_of_arguments   => 0,
   enabled               => TRUE,
   comments              => 'Process FP Inbound Program');
END;
/


BEGIN
DBMS_SCHEDULER.CREATE_JOB (
   job_name             => 'PROCESS_FP_INBOUND_JOB',
   program_name         => 'PROCESS_FP_INBOUND_PROG',
   start_date           => '03-AUG-18 1.00.00AM US/Central',
   repeat_interval      => 'FREQ=MINUTELY;INTERVAL=1',
   --end_date             => '13-MAR-28 1.00.00AM US/Central',
   enabled              =>  TRUE,
   comments             => 'Process FP Inbound Job');
END;
/

prompt 'PROCESS_FP_INBOUND_JOB scheduler created';













BEGIN
DBMS_SCHEDULER.CREATE_PROGRAM (
   program_name          => 'SEND_IA_JOB_PROG',
   program_type          => 'PLSQL_BLOCK',
   program_action        => 'BEGIN PL_SPL_OUT.SEND_IA_OUT; END;',
   number_of_arguments   => 0,
   enabled               => TRUE,
   comments              => 'Send IA data');
END;
/



BEGIN
DBMS_SCHEDULER.CREATE_JOB (
   job_name             => 'SEND_IA_JOB',
   program_name         => 'SEND_IA_JOB_PROG',
   start_date           => '03-AUG-18 1.00.00AM US/Central',
   repeat_interval      => 'FREQ=MINUTELY;INTERVAL=1',
   --end_date             => '13-MAR-28 1.00.00AM US/Central',
   enabled              =>  TRUE,
   comments             => 'Job to Send IA data');
END;
/

prompt 'SEND_IA_JOB scheduler created';

BEGIN
DBMS_SCHEDULER.CREATE_PROGRAM (
   program_name          => 'SEND_OW_JOB_PROG',
   program_type          => 'PLSQL_BLOCK',
   program_action        => 'BEGIN PL_SPL_OUT.SEND_OW_OUT; END;',
   number_of_arguments   => 0,
   enabled               => TRUE,
   comments              => 'Send OW data');
END;
/



BEGIN
DBMS_SCHEDULER.CREATE_JOB (
   job_name             => 'SEND_OW_JOB',
   program_name         => 'SEND_OW_JOB_PROG',
   start_date           => '03-AUG-18 1.00.00AM US/Central',
   repeat_interval      => 'FREQ=MINUTELY;INTERVAL=1',
   --end_date             => '13-MAR-28 1.00.00AM US/Central',
   enabled              =>  TRUE,
   comments             => 'Job to Send OW data');
END;
/

prompt 'SEND_OW_JOB scheduler created';

BEGIN
DBMS_SCHEDULER.CREATE_PROGRAM (
   program_name          => 'SEND_PW_JOB_PROG',
   program_type          => 'PLSQL_BLOCK',
   program_action        => 'BEGIN PL_SPL_OUT.SEND_PW_OUT; END;',
   number_of_arguments   => 0,
   enabled               => TRUE,
   comments              => 'Send PW data');
END;
/



BEGIN
DBMS_SCHEDULER.CREATE_JOB (
   job_name             => 'SEND_PW_JOB',
   program_name         => 'SEND_PW_JOB_PROG',
   start_date           => '03-AUG-18 1.00.00AM US/Central',
   repeat_interval      => 'FREQ=MINUTELY;INTERVAL=1',
   --end_date             => '13-MAR-28 1.00.00AM US/Central',
   enabled              =>  TRUE,
   comments             => 'Job to Send PW data');
END;
/

prompt 'SEND_PW_JOB scheduler created';

BEGIN
DBMS_SCHEDULER.CREATE_PROGRAM (
   program_name          => 'SEND_WH_JOB_PROG',
   program_type          => 'PLSQL_BLOCK',
   program_action        => 'BEGIN PL_SPL_OUT.SEND_WH_OUT; END;',
   number_of_arguments   => 0,
   enabled               => TRUE,
   comments              => 'Send WH data');
END;
/



BEGIN
DBMS_SCHEDULER.CREATE_JOB (
   job_name             => 'SEND_WH_JOB',
   program_name         => 'SEND_WH_JOB_PROG',
   start_date           => '03-AUG-18 1.00.00AM US/Central',
   repeat_interval      => 'FREQ=MINUTELY;INTERVAL=1',
   --end_date             => '13-MAR-28 1.00.00AM US/Central',
   enabled              =>  TRUE,
   comments             => 'Job to Send WH data');
END;
/

prompt 'SEND_WH_JOB scheduler created';

BEGIN
DBMS_SCHEDULER.CREATE_PROGRAM (
   program_name          => 'SEND_SWMS_JOB_PROG',
   program_type          => 'PLSQL_BLOCK',
   program_action        => 'BEGIN PL_SPL_SEND_RECEIVE_MSGS.SEND_MESSAGE; END;',
   number_of_arguments   => 0,
   enabled               => TRUE,
   comments              => 'Send SWMS Data to AQ');
END;
/



BEGIN
DBMS_SCHEDULER.CREATE_JOB (
   job_name             => 'SEND_SWMS_JOB',
   program_name         => 'SEND_SWMS_JOB_PROG',
   start_date           => '03-AUG-18 1.00.00AM US/Central',
   repeat_interval      => 'FREQ=MINUTELY;INTERVAL=1',
   --end_date             => '13-MAR-28 1.00.00AM US/Central',
   enabled              =>  TRUE,
   comments             => 'Job To Send SWMS Data to AQ');
END;
/

prompt 'SEND_SWMS_JOB scheduler created';



