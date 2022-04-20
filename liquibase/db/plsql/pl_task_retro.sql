rem *****************************************************
rem @(#) src/schema/plsql/pl_task_retro.sql, swms, swms.9, 10.1.1 9/7/06 1.4

rem @(#) File : pl_task_retro.sql
rem @(#) Usage: sqlplus USR/PWD pl_task_retro.sql

rem ---  Maintenance history  ---
rem 03-JUN-2002 acpakp Initial version
rem 15-JUL-2002 acpakp Changed check_retro_batch to return 0 if 
rem                    target time or goal time is null to take care of Oracle8.
rem 05/14/04    prplhj D#11601/11602 Added checking for PO batches in
rem                    process_retro_batch().


CREATE OR REPLACE PACKAGE swms.pl_task_retro IS
/*==========================================================================
This package is called when user enters R and then give the retro batch 
number.
The procedures in this package are
1. check_sched_type - Checks whether the user has a valid schedule, labor
                      group set up and the job code entered has a job class
                      and labor function set up.
2. check_retro_batch_no - checks whether the batch number entered is of 
                      status as F (Future). Whether the user already has a 
                      batch that is active or complete. 
3. process_retro_batch - This is the main procedure in the package. This calls 
                      the other two procedures, validates the data and create
                      retro batches if everything is right and give the status.
                      Also returns the target time and goal time of the batch 
                      for use in feedback.
===========================================================================*/
procedure check_sched_type (i_user_id in arch_batch.user_id%TYPE,
                            i_job_code in job_code.jbcd_job_code%TYPE,
                            o_job_class out job_code.jbcl_job_class%TYPE,
                            o_success out varchar);
procedure check_retro_batch_no(i_user_id in arch_batch.user_id%TYPE,
                               io_retro_batch_no in out arch_batch.batch_no%TYPE,
                               i_ref_no in arch_batch.ref_no%type,
                               o_job_class out job_code.jbcl_job_class%TYPE,
                               o_target_time out arch_batch.target_time%TYPE,
                               o_goal_time out arch_batch.goal_time%TYPE,
                               o_success out varchar);
procedure process_retro_batch(i_user_id in arch_batch.user_id%TYPE,
                                io_retro_batch_no in out arch_batch.batch_no%TYPE,
                                i_ref_no in arch_batch.ref_no%TYPE,
                                o_target_time out arch_batch.target_time%TYPE,
                                o_goal_time out arch_batch.goal_time%TYPE,
                                o_success out varchar);
END pl_task_retro;
/
/*==============================================================================*/
/*================================================================================*/
CREATE OR REPLACE PACKAGE BODY swms.pl_task_retro IS
/*==================================================================================*/
procedure check_sched_type (i_user_id in arch_batch.user_id%TYPE,
                            i_job_code in job_code.jbcd_job_code%TYPE,
                            o_job_class out job_code.jbcl_job_class%TYPE,
                            o_success out varchar) is
/*====================================================================================
Return values:
   o_success : G - Labor group not set for user.
               C - Invalid Job code. Unable to get job class
               S - No active Schedule set up for the user.
               Y - Valid.
====================================================================================*/

  l_job_class   job_code.jbcl_job_class%type;
  l_lgrp_lbr_grp usr.lgrp_lbr_grp%TYPE;
  l_var         char(1);
  
  cursor c_get_lbr_grp is 
  select lgrp_lbr_grp 
  from usr
  where replace(user_id,'OPS$',null) = i_user_id;  

  cursor c_get_jc is
  select jbcl_job_class
  from job_code
  where jbcd_job_code = i_job_code;
  
  cursor c_sched_cur is
  select 'X'
  from sched
  where sched_actv_flag = 'Y'
  and sched_lgrp_lbr_grp = l_lgrp_lbr_grp
  and sched_jbcl_job_class = l_job_class;
 
begin
  open c_get_lbr_grp;
  fetch c_get_lbr_grp into l_lgrp_lbr_grp;
  if c_get_lbr_grp%notfound then
      o_success := 'G';
  else
     open c_get_jc;
     fetch c_get_jc into l_job_class;
     if c_get_jc%notfound then
         o_success := 'C';
     else
          o_job_class := l_job_class;
         open c_sched_cur ;
         fetch c_sched_cur into l_var;
         if c_sched_cur%notfound then
             o_success := 'S'; 
         else
             o_success := 'Y'; 
         end if;
         close c_sched_cur;
     end if;
     close c_get_jc;
   end if;
   close c_get_lbr_grp;
end;

/*==================================================================================*/
procedure check_retro_batch_no(i_user_id in arch_batch.user_id%TYPE,
                               io_retro_batch_no in out arch_batch.batch_no%TYPE,
                               i_ref_no in arch_batch.ref_no%TYPE,
                               o_job_class out job_code.jbcl_job_class%TYPE,
                               o_target_time out arch_batch.target_time%TYPE,
                               o_goal_time out arch_batch.goal_time%TYPE,
                               o_success out varchar) is
/*===================================================================================
Return values:
    o_success: A - User already signed on to a batch. Retro not allowed.
               N - Batch No should be a valid future batch. Retro not allowed.
               G - Labor group not set for user.
               C - Invalid Job code. Unable to get job class
               S - No active Schedule set up for the user.
               Y - Valid.
====================================================================================*/
  l_var  char(1);
  l_batch_no arch_batch.batch_no%TYPE;
  indirect_success_bln boolean;
  l_job_code arch_batch.jbcd_job_code%TYPE;

  cursor c_chk_active is
  select 'X'
  from batch
  where user_id = i_user_id;
  
  cursor c_chk_status is
  select jbcd_job_code,nvl(target_time,0),nvl(goal_time,0)
  from batch
  where batch_no = l_batch_no
  and   status = 'F' ;

begin
  l_batch_no := io_retro_batch_no;
  open c_chk_active;
  fetch c_chk_active into l_var;
  if c_chk_active%found then
      o_success := 'A';     
  else
      pl_task_assign.add_prefix_S(l_batch_no);
      pl_task_assign.add_indirect_entry(l_batch_no,i_ref_no,indirect_success_bln);
      io_retro_batch_no := l_batch_no;
      if indirect_success_bln = TRUE then
 
         open c_chk_status;
         fetch c_chk_status into l_job_code,o_target_time,o_goal_time;
         if c_chk_status%notfound then
             o_success := 'N';
             pl_log.ins_msg('F','check_retro_batch_no',
                  'RETRO BATCH NUMBER must be a valid FUTURE batch.',null,null);
         else
            
             check_sched_type(i_user_id,l_job_code,o_job_class,o_success);
         end if;
         close c_chk_status;
      else
          o_success := 'N';
      end if;
   end if;
   close c_chk_active;
end;
/*==================================================================================*/
  procedure process_retro_batch(i_user_id in arch_batch.user_id%TYPE,
                              io_retro_batch_no in out arch_batch.batch_no%TYPE,
                                i_ref_no in arch_batch.ref_no%TYPE,
                                o_target_time out arch_batch.target_time%TYPE,
                                o_goal_time out arch_batch.goal_time%TYPE,
                                o_success out varchar) is
/*===================================================================================
Return Values:
    o_success: A - User already signed on to a batch. Retro not allowed.
               N - Batch No should be a valid future batch. Retro not allowed.
               G - Labor group not set for user.
               C - Invalid Job code. Unable to get job class
               S - No active Schedule set up for the user.
               T - Unable to get Schedule details.
               U - Unable to update batch.
               Y - Valid.
    o_target_time : Target time of the batch
    o_goal_time   : Goal Time of the batch.
====================================================================================*/


  l_job_class     job_code.jbcl_job_class%type;
  l_start_time    arch_batch.actl_start_time%TYPE;
  l_stop_time     arch_batch.actl_stop_time%TYPE;
  l_start_dur     arch_batch.actl_time_spent%TYPE;
  l_lgrp_lbr_grp  usr.lgrp_lbr_grp%TYPE;
  l_user_supervsr_id arch_batch.user_supervsr_id%TYPE;
  l_success char;
  l_istart_batch_no arch_batch.batch_no%TYPE;
  l_batch_no arch_batch.batch_no%TYPE;
   error_prob     varchar2(200) := SQLERRM;
  cursor c_get_batch_sched is
  select to_date(to_char(sysdate,'MM/DD/RR ') ||
                 to_char(st.start_time,'HH24:MI'),'MM/DD/RR HH24:MI'),
         st.start_dur
  from sched_type st, sched s
  where s.sched_actv_flag = 'Y'
   and s.sched_lgrp_lbr_grp = l_lgrp_lbr_grp
   and s.sched_jbcl_job_class = l_job_class
   and st.sctp_sched_type = s.sched_type;

 begin
   pl_log.g_application_func := 'LABOR';
   pl_log.g_program_name := 'pl_task_retro.sql';
   l_batch_no := io_retro_batch_no;
   pl_task_assign.validate_userid(i_user_id,l_user_supervsr_id,l_lgrp_lbr_grp);
   check_retro_batch_no(i_user_id,l_batch_no,i_ref_no,l_job_class,o_target_time,o_goal_time,l_success);
   if l_success = 'N' then
       -- D11601 Added PO batch processing
       l_batch_no := REPLACE(l_batch_no, 'S', 'PO');
       check_retro_batch_no(i_user_id,l_batch_no,i_ref_no,l_job_class,
                            o_target_time,o_goal_time,l_success);
   end if;
   if l_success != 'Y' then
       o_success := l_success;
   else
      open c_get_batch_sched;
      fetch c_get_batch_sched into l_start_time,l_start_dur;
      if c_get_batch_sched%notfound then
          o_success := 'T';
          pl_log.ins_msg('F','process_retro_batch',
                'Unable to get schedule data in Retro; Data is not set.',null,null);
      else
          l_stop_time := l_start_time + (nvl(l_start_dur,0)/1440);

          pl_task_assign.ins_indirect('ISTART','C',
                        i_user_id,
                        l_user_supervsr_id,
                        l_start_time,
                        l_stop_time,
                        nvl(l_start_dur,0),
                        null,
                        i_ref_no,
                        l_istart_batch_no);
           
          update batch
          set  actl_start_time = l_stop_time,
               status = 'A',
               user_id = i_user_id,
               user_supervsr_id = l_user_supervsr_id
          where batch_no = l_batch_no;
          if sql%notfound then
            o_success := 'U';
            raise_application_error(-20104,'Unable to update Retro batch.');
          else
            begin
               update batch
               set actl_start_time = l_stop_time,
                   actl_stop_time = l_stop_time,
                   user_id = i_user_id,
                   user_supervsr_id = l_user_supervsr_id,
                   goal_time = 0,
                   target_time = 0
              where parent_batch_no = l_batch_no
              and   batch_no != parent_batch_no
              and   status = 'M';
              exception
                 when no_data_found then
                     null;
            end;
            o_success:= 'Y';
            io_retro_batch_no := l_batch_no;
         end if;
      end if;
   end if;
  exception
      when others then
         o_success := 'N';
         error_prob := SQLERRM;
         rollback;
         pl_log.ins_msg('F','process_retro_batch',
           'Batch_no is '||l_batch_no  || '  User Id: ' ||i_user_id,null,null);
         pl_log.ins_msg('F','process_retro_batch',error_prob,null,null);
         commit;
         raise_application_error(-20104,'When Other failed: '|| error_prob);
end;
/*========================================================================================*/   
END;
/

