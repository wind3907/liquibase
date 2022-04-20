------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_wis_inc_hist.sql, swms, swms.9, 10.1.1 9/7/06 1.4
--
-- View:
--    v_wis_inc_hist
--
-- Description:
--    This view is used in Warehouse Incentive screen for payroll
--    to display incentive details
--
-- Used by:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/11/05 prpakp   Initial Creation
------------------------------------------------------------------------------
create or replace view swms.v_wis_inc_hist as
select  USER_ID,
	JBCD_JOB_CODE, 
	GOAL_TIME, 
	DIRECT_TIME, 
	EXP_PERF,
        ACTL_PERF, 
	sum(INC_PERF) INC_PERF, 
	sum(PERF_INC) PERF_INC, 
	sum(NO_CASE) NO_CASE, 
	sum(ERROR_INC) ERROR_INC,
        sum(TEN_INC) TEN_INC, 
	sum(TOTAL_INC) TOTAL_INC,
        SEND_DATE, SEND_USER
from wis_payroll_hist
group by USER_ID,JBCD_JOB_CODE, GOAL_TIME, 
         DIRECT_TIME, EXP_PERF, ACTL_PERF,SEND_DATE,SEND_USER
/

