rem *****************************************************
rem @(#) src/schema/plsql/pl_task_indirect.sql, swms, swms.9, 10.1.1 9/7/06 1.4

rem @(#) File : pl_task_indirect.sql
rem @(#) Usage: sqlplus USR/PWD pl_task_indirect.sql

rem ---  Maintenance history  ---
rem 03-JUN-2002 acpakp Initial version
rem 11/2/05     prpakp Commented out call to process_ins_float_hist since pl_lm1 is changed
rem                    to call this and insert data to float_hist.

CREATE OR REPLACE PACKAGE swms.pl_task_indirect IS
/*==============================================================================
This package is called when user enters I as batch number and enters indirect 
job code and password.

The procedures in this package are
1.chk_password - This procedure checks whether the password entered by the user 
                  is valid for not and returns
                  Y - if password is valid.
                  I - if password is invalid.
                  X - if password is not set in the system.
                  N - if password is null.
2.check_job_code - This procedure will check whether the indirect job code entered
                  by the user is valid or not. If the user enters 
                  ISTART - this will check for the existance of ISTART and returns
                           Y - If istart does not exist
                           N - if istart exist
                           E - in case of error selecting.
                  ISTOP - users are not allowed to enter ISTOP here. returns N.
                  Other indirect job codes - this will check for the existance of 
                           the job code and returns
                           Y - if valid.
                           N - if invalid.
3.process_indirect_batch -This is the main procedure. This will check for the 
                  existance of previous batch for the user. If exists and active then 
                  previous batch will be signed off. Then an indirect batch will be 
                  created. If previous batch does not exist then this will create an 
                  indirect batch.
===============================================================================*/

procedure chk_password (i_passwd in sys_config.config_flag_val%TYPE,
                                    o_pass_flag out varchar);

procedure check_job_code(i_job_code in job_code.jbcd_job_code%TYPE,
                         i_user_id in arch_batch.user_id%TYPE,
                         o_valid_flag out varchar);

procedure process_indirect_batch(i_user_id in arch_batch.user_id%TYPE,
                                 i_job_code in job_code.jbcd_job_code%TYPE,
                                 i_ref_no in arch_batch.ref_no%TYPE,
                                 i_forklift_point in point_distance.point_a%TYPE,
                                 o_batch_no out arch_batch.batch_no%TYPE,
                                 o_success_flag out varchar);

END PL_TASK_INDIRECT;
/
/*================================================================================ */
/*================================================================================ */

CREATE OR REPLACE PACKAGE BODY swms.pl_task_indirect IS
/*========================================================================================*/
procedure chk_password (i_passwd in sys_config.config_flag_val%TYPE,
                                    o_pass_flag out varchar) is
/*=========================================================================================
Return Values:
     o_pass_flag - N - if password entered is null.
                   X - if password is not selt in the system.
                   I - if invalid password.
                   Y - if valid.
=========================================================================================*/
  l_passwd  sys_config.config_flag_val%TYPE;
  cursor c_chk_passwd is
    select substr(config_flag_val,1,4)
    from sys_config
    where config_flag_name = 'LBR_MGMT_EXIT_PASSWORD';
begin
   o_pass_flag := 'Y';
   if i_passwd is null then
        o_pass_flag := 'N';
   else
      open c_chk_passwd;
      fetch c_chk_passwd into l_passwd;
      if c_chk_passwd%notfound then
           o_pass_flag := 'X';
      else
           if i_passwd != l_passwd then
               o_pass_flag := 'I';
           else
               o_pass_flag := 'Y';
           end if;
      end if;
   end if;
end;

/*========================================================================================*/
procedure check_job_code(i_job_code in job_code.jbcd_job_code%TYPE,
                         i_user_id in arch_batch.user_id%TYPE,
                         o_valid_flag out varchar) is
/*========================================================================================
Return Values:
      o_valid_flag : ISTART - N - Not allowed here.
                     ISTOP  - N - Not allowed here.
                     Others - Y - if valid
                              N - if invalid.
=========================================================================================*/

  l_var char(1);
  l_exist char;
  cursor c_chk_ind_code is
  select 'X'
  from job_code
  where lfun_lbr_func = 'IN'
  and jbcd_job_code = i_Job_code;
  
  
begin
  if i_job_code = 'ISTART' then
      o_valid_flag := 'N';
  elsif i_job_code = 'ISTOP' then
      o_valid_flag := 'N';
  elsif i_job_code is null then
      o_valid_flag := 'N';
  else
     open c_chk_ind_code;
     fetch c_chk_ind_code into l_var;
     if c_chk_ind_code%notfound then
        o_valid_flag := 'N';
     else 
         o_valid_flag := 'Y';
     end if;
     close c_chk_ind_code;
  end if;
end;

                                   
/*========================================================================================*/
procedure process_indirect_batch(i_user_id in arch_batch.user_id%TYPE,
                                 i_job_code in job_code.jbcd_job_code%TYPE,
                                 i_ref_no in arch_batch.ref_no%TYPE,
                                 i_forklift_point in point_distance.point_a%TYPE,
                                 o_batch_no out arch_batch.batch_no%TYPE,
                                 o_success_flag out varchar) is
/*=========================================================================================
Return Values:
    o_batch_no - batch no of the indirect batch creted. This is used in forklift process,
    o_success_flag - Y - if process is success
                     N - if not.
=========================================================================================*/

  t_do_merge    char(1);
  t_prev_exist  char(1);
  t_total_brk_spent   number;
  l_batch_no arch_batch.batch_no%TYPE;
  indirect_success_bln boolean;
  l_user_supervsr_id arch_batch.user_supervsr_id%TYPE;
  l_lgrp_lbr_grp usr.lgrp_lbr_grp%TYPE;
  l_lfun_lbr_func job_code.lfun_lbr_func%TYPE;
  l_prev_batch_no arch_batch.batch_no%TYPE;
  l_prev_batch_date arch_batch.batch_date%TYPE;
  l_prev_start_time arch_batch.actl_start_time%TYPE;
  l_do_merge char;
  l_prev_exist char;
  l_prev_forklift char;
  l_prev_status arch_batch.status%TYPE;
 
  l_istart_created char;
  l_istart_time arch_batch.actl_start_time%TYPE;
  l_istart_batch_no arch_batch.batch_no%TYPE;

  l_actl_start_time arch_batch.actl_start_time%TYPE;
  l_prev_actl_stop_time arch_batch.actl_stop_time%TYPE;
  l_prev_actl_time_spent arch_batch.actl_time_spent%TYPE;
  error_prob     varchar2(200) := SQLERRM;
begin
   pl_log.g_application_func := 'LABOR';
   pl_log.g_program_name := 'pl_task_indirect.sql';
   /* in get prev batch id l_batch_no is empty, it will not fetch any data.
      so assigning l_batch_no as NO_BATCH */
   l_batch_no := 'NO_BATCH'; 
   l_lfun_lbr_func := 'IN';
   pl_task_assign.validate_userid(i_user_id,l_user_supervsr_id,l_lgrp_lbr_grp);
   pl_task_assign.get_prev_batch(i_user_id,l_batch_no,l_lfun_lbr_func,
                                 l_prev_batch_no,l_prev_batch_date,l_prev_start_time,
                                 l_do_merge,l_prev_exist,l_prev_forklift,l_prev_status);

   l_do_merge := 'N';

   if l_prev_exist = 'N' then
        pl_task_assign.ins_istart('N',i_user_id,l_user_supervsr_id,l_lgrp_lbr_grp,
               i_ref_no,l_istart_created,l_istart_time,l_istart_batch_no);
        l_actl_start_time := l_istart_time;
        pl_task_assign.ins_indirect(i_job_code,'A',i_user_id,
                   l_user_supervsr_id,
                   l_actl_start_time,
                   null, null,
                   null,
                   i_ref_no,
                   o_batch_no);
       o_success_flag := 'Y';
   else
         pl_task_assign.create_istart(i_user_id,l_lgrp_lbr_grp,l_user_supervsr_id);
         l_actl_start_time := sysdate;
         if l_prev_status = 'A' then
            if l_prev_forklift != 'Y' then
                   l_prev_actl_stop_time := l_actl_start_time;
                   l_prev_actl_time_spent :=
                          to_number((l_prev_actl_stop_time - l_prev_start_time) * 1440);
                    pl_lm1.create_schedule(l_prev_batch_no,l_prev_batch_date,
                              l_prev_actl_stop_time,l_prev_actl_time_spent);
                    pl_task_assign.calc_parent_total(l_prev_batch_no);
            end if;
         end if;
          
         /* Commented put since pl_lm1 is changed to call this and insert data to float_hist.
         if substr(l_prev_batch_no,1,1) = 'S' then
               pl_task_assign.process_ins_float_hist(l_prev_batch_no,i_user_id);
         end if;*/

          pl_task_assign.ins_indirect(i_job_code,'A',i_user_id,
                   l_user_supervsr_id,
                   l_actl_start_time,
                   null, null,
                   i_forklift_point,
                   i_ref_no,
                   o_batch_no);
         o_success_flag := 'Y';
              
   end if;
   exception
    when others then
       o_success_flag := 'E';
       error_prob := SQLERRM;
       rollback;
       pl_log.ins_msg('F','process_indirect_batch',
         'Job Code is '||i_job_code  || '  User Id: ' ||i_user_id,null,null);
       pl_log.ins_msg('F','process_indirect_batch',error_prob,null,null);
       commit;
       raise_application_error(-20104,'When Other failed: '|| error_prob);
  end process_indirect_batch;
END PL_TASK_INDIRECT;
/
