rem *****************************************************
rem @(#) src/schema/plsql/pl_task_merge.sql, swms, swms.9, 10.1.1 9/7/06 1.5

rem @(#) File : pl_task_merge.sql
rem @(#) Usage: sqlplus USR/PWD pl_task_merge.sql

rem ---  Maintenance history  ---
rem 03-JUN-2002 acpakp Initial version
rem 05/21/04    prplhj D#11601/11602 Added PO batch processing
rem 10/28/05    prpakp Changed upd_goal_target procedure to check the
rem                    doc time of the child batch instead of parent batch. 

CREATE OR REPLACE PACKAGE swms.pl_task_merge IS
/*===========================================================================
This package is to merge two batches.
The procedures are

1.chk_master_batch - this will check whether the batch entered as parent
                      is valid or not.
2.chk_second_batch - this will check whether the second batch enteed as
                     child is valid or not.
                     This also returns the target time and goal time of this batch
                     since this data will be lost after merge.
3.get batch_details - this will get all the details about the batch given.
4.upd_goal_target  - This updates the parent batch 
                     goal time - if engr_std_flag = Y
                     target time -  if engr_std_flag = N
                     with the time given by the user - tmu_doc_time from job 
                     code table for the job code of the batch.
5.calculate_parent_total_non_S - This will calculare the total count, total_piece
                     total_pallet for non selector batches. There is a procedure in 
                     PL_TASK_ASSIGN to calculate for selector batches.
6.process_merge_batch - This is the main procedure in this package.
                     This will merge the two batches entered. If the parent batch 
                     is of status F(Future) then there is no active batch for the 
                     user. Check for ISTART and if not exists create an ISTART and 
                     merge the batches.

===========================================================================*/

procedure chk_master_batch(i_user_id  in arch_batch.user_id%TYPE,
                           i_master_batch_no in arch_batch.batch_no%TYPE,
                           o_lbr_func out job_code.lfun_lbr_func%TYPE,
                           o_valid out varchar);
procedure chk_second_batch(i_master_batch_no in arch_batch.batch_no%TYPE,
                           i_master_lbr_func in job_code.lfun_lbr_func%TYPE,
                           i_second_batch_no in arch_batch.batch_no%TYPE,
                           o_target_time out number,
                           o_goal_time out number,
                           o_valid out varchar);

procedure get_batch_details(i_batch_no in arch_batch.batch_no%TYPE,
                            o_status out arch_batch.status%TYPE,
                            o_actl_start_time out arch_batch.actl_start_time%TYPE,
                            o_lgrp_lbr_grp out usr.lgrp_lbr_grp%TYPE,
                            o_user_supervsr_id out arch_batch.user_supervsr_id%TYPE,
                            o_parent_batch_no out arch_batch.ref_no%TYPE,
                            o_ref_no out arch_batch.ref_no%TYPE,
                            o_goal_time out arch_batch.goal_time%TYPE,
                            o_target_time out arch_batch.target_time%TYPE);

procedure upd_goal_target (i_batch_no in arch_batch.batch_no%TYPE,
                           i_goal_target in arch_batch.goal_time%TYPE,
                           i_child_batch in arch_batch.batch_no%TYPE);

procedure calc_parent_total_non_S (i_parent_batch in arch_batch.batch_no%TYPE);

procedure process_merge_batch(i_master_batch_no in arch_batch.batch_no%TYPE,
                          i_second_batch_no in arch_batch.batch_no%TYPE,
                          i_user_id in arch_batch.user_id%TYPE,
                          o_success out varchar);

END pl_task_merge;
/
/*================================================================================*/
CREATE OR REPLACE PACKAGE BODY swms.pl_task_merge  IS
/*=======================================================================================*/

procedure chk_master_batch(i_user_id  in arch_batch.user_id%TYPE,
                           i_master_batch_no in arch_batch.batch_no%TYPE,
                           o_lbr_func out job_code.lfun_lbr_func%TYPE,
                           o_valid out varchar) IS
/*========================================================================================
Return Values:
   o_lbr_func - Labor function of the batch entered.
   o_valid    - N - Batch Not found.
                Y - Valid.
========================================================================================*/

   l_batch_no arch_batch.batch_no%TYPE;
   l_master_batch_no arch_batch.batch_no%TYPE;

   cursor c_chk_master is
   select batch_no,lfun_lbr_func
   from batch_monitor_view
   where ((user_id = i_user_id and status = 'A' and
          batch_no = l_master_batch_no)
   OR    (status = 'F'
          and not exists (select 'X'
                          from batch
                          where user_id=i_user_id
                          and   status = 'A')
          and batch_no = l_master_batch_no))
    and lfun_lbr_func <> 'FL';
begin
  l_master_batch_no := i_master_batch_no;
  if l_master_batch_no is not null then
     pl_task_assign.add_prefix_S(l_master_batch_no);
     open c_chk_master;
     fetch c_chk_master into l_batch_no,o_lbr_func;
     if c_chk_master%notfound then
       -- D#11601 Added PO batch checking
       close c_chk_master;
       l_master_batch_no := REPLACE(l_master_batch_no, 'S', 'PO');
       open c_chk_master;
       fetch c_chk_master into l_batch_no,o_lbr_func;
       if c_chk_master%notfound then
         o_valid := 'N';
       else
         o_valid := 'Y';
       end if;
     else
       o_valid := 'Y';
     end if;
     close c_chk_master;
  else
    o_valid := 'N';
  end if;
end chk_master_batch; 
/*=======================================================================================*/
procedure chk_second_batch(i_master_batch_no in arch_batch.batch_no%TYPE,
                           i_master_lbr_func in job_code.lfun_lbr_func%TYPE,
                           i_second_batch_no in arch_batch.batch_no%TYPE,
                           o_target_time out number,
                           o_goal_time out number,
                           o_valid out varchar) IS
/*=======================================================================================
Return Values:
   o_valid : N - Invalid
             S - Master and Second are Same
             Y - Valid.
   o_target_time : Target time of the second batch 
   o_goal_time   : Goal Time of the second batch
=======================================================================================*/
l_second_batch_no arch_batch.batch_no%TYPE;
l_master_batch_no arch_batch.batch_no%TYPE;
l_batch_no arch_batch.batch_no%TYPE;
l_valid VARCHAR2(1);

  cursor c_ck_second is
  select batch_no,target_time,goal_time
  from batch_monitor_view
  where status = 'F'
  and   batch_no = l_second_batch_no
  and   lfun_lbr_func = i_master_lbr_func;
begin
   l_second_batch_no := i_second_batch_no;
   l_master_batch_no := i_master_batch_no;

   pl_task_assign.add_prefix_S(l_second_batch_no);
   pl_task_assign.add_prefix_S(l_master_batch_no);
   if l_second_batch_no is null then
      l_valid := 'N';
   else
      if l_master_batch_no = l_second_batch_no then
           l_valid := 'S';
      else
          open c_ck_second ;
          fetch c_ck_second into l_batch_no,o_target_time,o_goal_time;
          if c_ck_second%notfound then
              l_valid := 'N';
          else
              l_valid := 'Y';
          end if;
          close c_ck_second;
      end if;
   end if;
   -- D#11601 Added PO batch checking
   if l_valid = 'N' then
      l_second_batch_no := REPLACE(l_second_batch_no, 'S', 'PO');
      l_master_batch_no := REPLACE(l_master_batch_no, 'S', 'PO');
      if l_second_batch_no is null then
         l_valid := 'N';
      else
         if l_master_batch_no = l_second_batch_no then
            l_valid := 'S';
         else
            open c_ck_second ;
            fetch c_ck_second into l_batch_no,o_target_time,o_goal_time;
            if c_ck_second%notfound then
               l_valid := 'N';
            else
               l_valid := 'Y';
            end if;
            close c_ck_second;
         end if;
      end if;
   end if;
   o_valid := l_valid;
end chk_second_batch;
/*=========================================================================================*/
procedure get_batch_details(i_batch_no in arch_batch.batch_no%TYPE,
                            o_status out arch_batch.status%TYPE,
                            o_actl_start_time out arch_batch.actl_start_time%TYPE,
                            o_lgrp_lbr_grp out usr.lgrp_lbr_grp%TYPE,
                            o_user_supervsr_id out arch_batch.user_supervsr_id%TYPE,
                            o_parent_batch_no out arch_batch.ref_no%TYPE,
                            o_ref_no out arch_batch.ref_no%TYPE,
                            o_goal_time out arch_batch.goal_time%TYPE,
                            o_target_time out arch_batch.target_time%TYPE) is
cursor c_batch is
     select status,actl_start_time,lgrp_lbr_grp,
            user_supervsr_id,parent_batch_no,ref_no,
            goal_time,target_time
     from batch_monitor_view
     where batch_no = i_batch_no;

begin
   open c_batch;
   fetch c_batch into o_status,o_actl_start_time,o_lgrp_lbr_grp,
         o_user_supervsr_id,o_parent_batch_no,o_ref_no,
         o_goal_time,o_target_time;
   if c_batch%NOTFOUND then
      raise_application_error(-20104,'Unable to get batch details.');          
   end if;
   close c_batch;
end get_batch_details;
/*=========================================================================================*/
procedure upd_goal_target (i_batch_no in arch_batch.batch_no%TYPE,
                           i_goal_target in arch_batch.goal_time%TYPE,
                           i_child_batch in arch_batch.batch_no%TYPE) is

   l_engr_std_flag job_code.engr_std_flag%TYPE;
   l_tmu_doc_time  job_code.tmu_doc_time%TYPE;
   l_goal_target   arch_batch.goal_time%TYPE;
  
   cursor c_jc_cur is
   select j.engr_std_flag
   from batch b, job_code j
   where b.batch_no = i_batch_no
   and   b.jbcd_job_code = j.jbcd_job_code;

   cursor c_jc_child is
   select  round(nvl(j.tmu_doc_time,0)/1667,0)
   from batch b, job_code j
   where b.batch_no = i_child_batch
   and   b.jbcd_job_code = j.jbcd_job_code;
   
begin
   open c_jc_cur;
   fetch c_jc_cur into l_engr_std_flag;
   if c_jc_cur%notfound then
      raise_application_error(-20104,'Invalid Job Code for batch no : ' || i_batch_no); 
   else
      if nvl(i_goal_target,0) > 0 then
	     open c_jc_child;
             fetch  c_jc_child into l_tmu_doc_time;
             if c_jc_child%notfound then
                 l_tmu_doc_time := 0;
             end if;
             if nvl(i_goal_target,0) > l_tmu_doc_time and l_tmu_doc_time != 0 then
                 l_goal_target := i_goal_target - l_tmu_doc_time;
             else
                 l_goal_target := i_goal_target;
             end if;
      else
         l_goal_target := i_goal_target;
      end if;

      if l_engr_std_flag = 'Y' then
          update batch
          set goal_time = l_goal_target,
              target_time = 0
          where batch_no = i_batch_no;
          if sql%notfound then
             raise_application_error(-20104,'Unable to update parent batch in upd_goal_target');
          end if;
       else
          update batch
          set goal_time = 0,
              target_time = l_goal_target
          where batch_no = i_batch_no;
          if sql%notfound then
             raise_application_error(-20104,'Unable to update parent batch in upd_goal_target');
          end if;
       end if;
   end if;
   close c_jc_cur;
end;
/*======================================================================================================*/
procedure calc_parent_total_non_S (i_parent_batch in arch_batch.batch_no%TYPE) is

  l_batch_cnt number := 0;
  l_total_piece   number := 0;
  l_total_pallet  number := 0;
  l_batch_count   number := 0;

    /* We search for the total of childs batch information ONLY */
    /* because parent is already calculate of the first round */
   
  cursor c_conn_by_cur is
     select sum(nvl(kvi_no_piece,0)),sum(nvl(kvi_no_pallet,0))
     from batch
     where (batch_no = i_parent_batch OR parent_batch_no = i_parent_batch);
  
  /* With MULTI batch we want to count only the Parent Batch */
  /* and not the the child batch. But you can have a child that */
  /* is MULTI batch that are within MULTI or REG batch */
  /* As for the Merge in Task Assign, we do want to count them */
  /* as separate batch */
  
  cursor c_parent_multi is
     select count(*)
     from batch
     where  batch_no not like parent_batch_no || '_'
     and    (batch_no = i_parent_batch OR parent_batch_no = i_parent_batch);
begin
   l_batch_count := 0;
   l_total_piece := 0;
   l_total_pallet := 0;
   open c_conn_by_cur;
   fetch c_conn_by_cur into l_total_piece,l_total_pallet;
   if c_conn_by_cur%notfound then
      l_total_piece := 0;
      l_total_pallet := 0;
      l_batch_count := 0;
   else
      open c_parent_multi;
      fetch c_parent_multi into l_batch_count;
      if c_parent_multi%notfound or nvl(l_batch_count,0) = 0 then
          l_batch_count := 0;
      end if;
      close c_parent_multi;
   end if;
   
   update batch
   set total_count = l_batch_count,
       total_piece = l_total_piece,
       total_pallet = l_total_pallet
   where batch_no = i_parent_batch;
   if sql%notfound then
      raise_application_error(-20104,'Notifify SWMS Tech-Unable to Update Total--Count/Piece');
   end if;
end;
/*=========================================================================================*/
procedure process_merge_batch(i_master_batch_no in arch_batch.batch_no%TYPE,
                          i_second_batch_no in arch_batch.batch_no%TYPE,
                          i_user_id in arch_batch.user_id%TYPE,
                          o_success out varchar) is
/*============================================================================================
Return Values:
   o_success : Y - Batch Merged
               N - Not Merged.
=============================================================================================*/

/*Second Variables*/
l_status arch_batch.status%TYPE;
l_actl_start_time arch_batch.actl_start_time%TYPE;
l_lgrp_lbr_grp usr.lgrp_lbr_grp%TYPE;
l_user_supervsr_id arch_batch.user_supervsr_id%TYPE;
l_parent_batch_no arch_batch.ref_no%TYPE;
l_ref_no arch_batch.ref_no%TYPE;
l_goal_time arch_batch.goal_time%TYPE;
l_target_time arch_batch.target_time%TYPE;

/*Master Variables*/
l_m_status arch_batch.status%TYPE;
l_m_actl_start_time arch_batch.actl_start_time%TYPE;
l_m_lgrp_lbr_grp usr.lgrp_lbr_grp%TYPE;
l_m_user_supervsr_id arch_batch.user_supervsr_id%TYPE;
l_m_parent_batch_no arch_batch.ref_no%TYPE;
l_m_ref_no arch_batch.ref_no%TYPE;
l_m_goal_time arch_batch.goal_time%TYPE;
l_m_target_time arch_batch.target_time%TYPE;
l_m_batch_no arch_batch.batch_no%TYPE;
l_s_batch_no arch_batch.batch_no%TYPE;

l_istart_exist char;
l_istart_created char;
l_istart_stop_time arch_batch.actl_stop_time%TYPE;
l_batch_no arch_batch.batch_no%TYPE;

l_total_merge_time arch_batch.goal_time%TYPE;
 error_prob     varchar2(200) := SQLERRM;
begin
   pl_log.g_application_func := 'LABOR';
   pl_log.g_program_name := 'pl_task_merge.sql';
   l_m_batch_no := i_master_batch_no;
   l_s_batch_no := i_second_batch_no;
   pl_task_assign.add_prefix_S(l_m_batch_no);
   pl_task_assign.add_prefix_S(l_s_batch_no);
   get_batch_details(l_m_batch_no, l_m_status,l_m_actl_start_time,
                     l_m_lgrp_lbr_grp,l_m_user_supervsr_id,
                     l_m_parent_batch_no,l_m_ref_no,l_m_goal_time,
                     l_m_target_time);
   get_batch_details(l_s_batch_no,l_status,l_actl_start_time,
                     l_lgrp_lbr_grp,l_user_supervsr_id,
                     l_parent_batch_no,l_ref_no,
                     l_goal_time,l_target_time);

    if l_m_status in ('F','A') then
       o_success := 'Y';
       if l_m_status = 'F' then
          pl_task_assign.check_for_istart(i_user_id,l_istart_exist);
          if l_istart_exist = 'N' then
             pl_task_assign.validate_userid(i_user_id,l_m_user_supervsr_id,l_m_lgrp_lbr_grp);
             pl_task_assign.ins_istart('N',i_user_id,l_m_user_supervsr_id,l_m_lgrp_lbr_grp,
                         null,l_istart_created,l_istart_stop_time,l_batch_no);
             l_m_actl_start_time := l_istart_stop_time;
          else
             l_m_actl_start_time := sysdate;
          end if;
          
          update batch
          set status = 'A',
              actl_start_time = l_m_actl_start_time,
              user_id = i_user_id,
              user_supervsr_id = l_m_user_supervsr_id
          where batch_no = l_m_batch_no;
          if sql%notfound then
             o_success := 'N';
             raise_application_error(-20104,'Unable to update batch in Merge in process_merge_batch.');          
          end if;
      else
          pl_task_assign.create_istart(i_user_id,l_m_lgrp_lbr_grp,l_m_user_supervsr_id);
          l_actl_start_time := l_m_actl_start_time;
      end if;
      if l_m_parent_batch_no is null or l_m_parent_batch_no != l_m_batch_no then
           /* This update the previous Active Batch */
           /* on the parent column. If it is not already a parent */
           update batch
           set parent_batch_no = l_m_batch_no,
               parent_batch_date = trunc(sysdate,'DD')
           where batch_no = l_m_batch_no;
           if sql%notfound then
              o_success := 'N';
              raise_application_error(-20104,'Unable to update parent batch no in Merge.');          
           end if;
            
           pl_task_assign.upd_pre_merge(i_user_id,l_m_user_supervsr_id,l_m_batch_no,l_m_actl_start_time);
      end if;
      pl_task_assign.upd_curr_batch('M',l_m_actl_start_time,l_m_actl_start_time,l_s_batch_no,i_user_id,
                     l_m_user_supervsr_id,null,null);

      upd_goal_target(l_s_batch_no,0,'0');

      update batch
      set total_count = 0,
          total_piece = 0,
          total_pallet = 0
      where batch_no = l_s_batch_no;
      if sql%notfound then
          o_success := 'N';
          raise_application_error(-20104,'Unable to update batch in Merge. Batch_no='||l_s_batch_no);
      end if;
      if l_parent_batch_no is not null or l_ref_no='MULTI' then
           pl_task_assign.upd_pre_merge(i_user_id,l_m_user_supervsr_id,l_parent_batch_no,l_m_actl_start_time);
      end if;
        --
        /* This update the parent field of a Merge batch to */
        /* show this is a child batch. The upd_pre_merge must proceed */
        /* before this procedure */
      update batch
      set parent_batch_no = l_m_batch_no,
          parent_batch_date = trunc(sysdate,'DD')
      where batch_no = l_s_batch_no;
      if sql%notfound then
          o_success := 'N';
          raise_application_error(-20104,'Unable to update parent batch no in Merge.Batch_no='||l_s_batch_no);          
      end if;
      
      /* Goal and Target time must be re-calculate */
      if nvl(l_m_goal_time,0) > 0 OR
         nvl(l_goal_time,0) > 0 then
          l_total_merge_time := nvl(l_goal_time,0) +
                                    nvl(l_m_goal_time,0);
      elsif nvl(l_target_time,0) > 0 OR
            nvl(l_m_target_time,0) > 0 then
          l_total_merge_time := nvl(l_target_Time,0) +
                                  nvl(l_m_target_time,0);
      else
          l_total_merge_time := 0;
      end if;
       
       upd_goal_target(l_m_batch_no,l_total_merge_time,l_s_batch_no);
     
       if substr(l_m_batch_no,1,1) = 'S' then
          pl_task_assign.calc_parent_total(l_m_batch_no);
       else
          calc_parent_total_non_S(l_m_batch_no);
           null;
       end if;
       
    else
       o_success := 'N';
       raise_application_error(-20104,'The parent batch have a status of ' || l_m_status);
    end if;
  exception
      when others then
         o_success := 'E';
         error_prob := SQLERRM;
         rollback;
         pl_log.ins_msg('F','process_merge_batch',
           'Batch_no is '||l_m_batch_no  || '  Second: ' ||l_s_batch_no,null,null);
         pl_log.ins_msg('F','process_merge_batch',error_prob,null,null);
         commit;
         raise_application_error(-20104,'When Other failed: '|| error_prob);
end;
/*======================================================================================================================*/
END pl_task_merge;
/
