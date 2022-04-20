------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_wis_inc_mst.sql, swms, swms.9, 10.1.1 9/7/06 1.2
--
-- View:
--    v_wis_inc_mst
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
--    02/25/06 prpakp   Initial Creation
------------------------------------------------------------------------------
create or replace view swms.v_wis_inc_mst as
select  USER_ID,USER_NAME,
	sum(PERF_INC) PERF_INC, 
	sum(ERROR_INC) ERROR_INC,
        sum(TEN_INC) TEN_INC, 
	sum(TOTAL_INC) TOTAL_INC
from wis_payroll_detail
group by USER_ID,USER_NAME
/

