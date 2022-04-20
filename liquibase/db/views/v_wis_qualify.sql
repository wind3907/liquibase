------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_wis_qualify.sql, lm, swms.9, 10.1.1 9/7/06 1.6
--
-- View:
--    v_wis_qualify
--
-- Description:
--    This view is used in Warehouse Incentive reports to determine who is qualify.
--
-- Used by:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/23/04 prpksn   view for warehouse incentive
--    09/22/04 prpakp   added the reporting_id which was missing.
--    03/11/05 prpakp   Corrected to look at batches that 
--			have status M along with C
--    11/10/05 prpakp   Changed to have pick qty to be cases for loader.
------------------------------------------------------------------------------
create or replace view swms.v_wis_qualify as
select a.batch_no,
       a.parent_batch_no,
       a.batch_date,
       a.status,
       a.report_date,
       a.user_id,
       u.user_name,
       u.reporting_id,
       u.lgrp_lbr_grp,
       a.jbcd_job_code, 
       a.ref_no,
       a.user_supervsr_id,
       jc.lfun_lbr_func,
       jc.jbcl_job_class,
       jc.whar_area,
       round((to_number(actl_stop_time - actl_start_time) * 24),2) total_work_hrs,
       nvl(a.goal_time,0) + nvl(a.target_time,0) goal_time,
       a.actl_start_time, a.actl_stop_time, a.actl_time_spent,
       nvl(wuj.perf_percent,100) expect_perf,
     decode(jc.lfun_lbr_func,'FL',a.total_pallet,'LD',a.total_pallet,a.total_piece) pick_qty
from job_code jc, wis_user_jc_perf wuj, usr u,arch_batch a
where u.user_id = 'OPS$' || a.user_id
and   wuj.user_id (+) = a.user_id
and   wuj.jbcd_job_code (+) = a.jbcd_job_code
and   jc.jbcd_job_code = a.jbcd_job_code
and   not exists (select 'x'
		  from wis_user_ineligible i
		  where i.user_id = a.user_id
		  and   a.actl_start_time between from_date and to_date)
and   a.status in ('C','M');

