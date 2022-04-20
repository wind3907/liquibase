DECLARE

  v_prg1_cnt NUMBER := 0;
  v_prg2_cnt NUMBER := 0;
  v_job1_cnt NUMBER := 0;
  v_job2_cnt NUMBER := 0;  
BEGIN

 
    SELECT count(*)
    into v_prg1_cnt
    FROM DBA_SCHEDULER_PROGRAMS
    where program_name = 'UPS_INTERFACE_DATA_PROG'
    and owner = 'SWMS';
    
    if (v_prg1_cnt = 0) then
    
    	DBMS_SCHEDULER.CREATE_PROGRAM (
        program_name          => 'UPS_INTERFACE_DATA_PROG',
        program_type          => 'PLSQL_BLOCK',
        program_action        => 'BEGIN PL_UPS_FLOAT_DETAIL.LOAD_UPS_FLOAT_DETAIL_TAB; END;',
        number_of_arguments   => 0,
        enabled               => TRUE,
        comments              => 'Get UPS interface data Program');
    
        dbms_output.put_line('UPS_INTERFACE_DATA_PROG scheduler created');	    
    
  
        pl_log.ins_msg(
                'INFO',
                'DDL_create_ups_job_scheduler',
                'from create ups job scheduler script it is CW opco UPS_INTERFACE_DATA_PROG scheduler created ',
                sqlcode,
                sqlerrm,
                'O',
                'UPS installation'
            );

    end if;
        
    select count(*)
    into v_job1_cnt
    from dba_scheduler_jobs
    where job_name = 'UPS_INTERFACE_DATA_JOB'
    and owner = 'SWMS';
    
 
    if (v_job1_cnt=0) then
    
    	DBMS_SCHEDULER.CREATE_JOB (
        job_name             => 'UPS_INTERFACE_DATA_JOB',
        program_name         => 'UPS_INTERFACE_DATA_PROG',
        start_date           => '26-JUL-19 1.00.00AM US/Central',
        repeat_interval      => 'FREQ=MINUTELY;INTERVAL=5',
        --end_date             => '13-MAR-28 1.00.00AM US/Central',
        enabled              =>  FALSE,
        comments             => 'Get UPS interface data Job');	    

       dbms_output.put_line('UPS_INTERFACE_DATA_JOB scheduler created');	    
    
  
        pl_log.ins_msg(
                'INFO',
                'DDL_create_ups_job_scheduler',
                'from create ups job scheduler script it is CW opco UPS_INTERFACE_DATA_JOB scheduler created ',
                sqlcode,
                sqlerrm,
                'O',
                'UPS installation'
            );
            

    end if;
    
    SELECT count(*)
    into v_prg2_cnt
    FROM DBA_SCHEDULER_PROGRAMS
    where program_name = 'SEND_SHIPPING_INFO_TO_UPS_PROG'
    and owner = 'SWMS';
    
    if (v_prg2_cnt = 0) then
    
    	DBMS_SCHEDULER.CREATE_PROGRAM (
        program_name          => 'SEND_SHIPPING_INFO_TO_UPS_PROG',
        program_type          => 'PLSQL_BLOCK',
        program_action        => 'BEGIN PL_UPS_FLOAT_DETAIL.UPS_FLOAT_DET_XML; END;',
        number_of_arguments   => 0,
        enabled               => TRUE,
        comments              => 'Send shipping data to UPS Program');
    
        dbms_output.put_line('SEND_SHIPPING_INFO_TO_UPS_PROG scheduler created');	    
    
  
        pl_log.ins_msg(
                'INFO',
                'DDL_create_ups_job_scheduler',
                'from create ups job scheduler script it is CW opco SEND_SHIPPING_INFO_TO_UPS_PROG scheduler created ',
                sqlcode,
                sqlerrm,
                'O',
                'UPS installation'
            );

    end if;
    
    
    select count(*)
    into v_job2_cnt
    from dba_scheduler_jobs
    where job_name = 'SEND_SHIPPING_INFO_TO_UPS_JOB'
    and owner = 'SWMS';
 
    if (v_job2_cnt=0) then
    
    	DBMS_SCHEDULER.CREATE_JOB (
        job_name             => 'SEND_SHIPPING_INFO_TO_UPS_JOB',
        program_name         => 'SEND_SHIPPING_INFO_TO_UPS_PROG',
        start_date           => '26-JUL-19 1.00.00AM US/Central',
        repeat_interval      => 'FREQ=MINUTELY;INTERVAL=5',
        --end_date             => '13-MAR-28 1.00.00AM US/Central',
        enabled              =>  FALSE,
        comments             => 'Send shipping data to UPS Job');
    
 
       dbms_output.put_line('SEND_SHIPPING_INFO_TO_UPS_JOB scheduler created');	    
    
  
        pl_log.ins_msg(
                'INFO',
                'DDL_create_ups_job_scheduler',
                'from create ups job scheduler script it is CW opco SEND_SHIPPING_INFO_TO_UPS_JOB scheduler created ',
                sqlcode,
                sqlerrm,
                'O',
                'UPS installation'
            );
             

    end if;    
    

   
EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Error' || sqlcode || sqlerrm);
            pl_log.ins_msg(
                'FATAL',
                'DDL_create_ups_job_scheduler',
                'Error from create ups job scheduler script  when others then ',
                sqlcode,
                sqlerrm,
                'O',
                'UPS installation'
            );
  
End;	
/
