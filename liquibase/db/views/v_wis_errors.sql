------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_wis_errors.sql, swms, swms.9, 10.1.1 2/22/07 1.4
--
-- View:
--    v_wis_errors
--
-- Description:
--    This view is used in Warehouse Incentive reports to 
--    determine the error rate for each user.
--
-- Used by:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/27/05 prpakp   view for warehouse incentive error quantity
--    10/28/05 prphqb   Add join condition for order_line_id         
--    02/22/07 prpakp   Added the condition to check for labor function
------------------------------------------------------------------------------
create or replace view swms.v_wis_errors as
select v.user_id,v.jbcd_job_code,r.cc_reason_code,v.batch_no,
        nvl(sum(e.ret_qty),0) error_qty,
	nvl(percent_applied,100) percent_applied,
	DISQUALIFY_RATE,v.report_date,v.lfun_lbr_func
from v_wis_qualify v,float_hist h, float_hist_errors e,
	wis_reason_cds r,wis_types w
where h.user_id = v.user_id
and   h.batch_no = substr(v.batch_no,2)
and   r.reason_cd_type = 'RTN'
and   r.reason_cd = e.reason_code
and   (e.order_id = h.order_id
or    e.orig_invoice = h.order_id)
and   e.order_line_id = h.order_line_id
and   e.prod_id = h.prod_id
and   w.wis_type = r.cc_reason_code
and   w.lfun_lbr_func = v.lfun_lbr_func
and   'Y' = decode(v.lfun_lbr_func,'SL',r.lbr_sl,'LD',r.lbr_ld,'FL',r.lbr_fl,'N')
group by v.user_id,v.jbcd_job_code,r.cc_reason_code,percent_applied,
	DISQUALIFY_RATE,v.batch_no,v.report_date,v.lfun_lbr_func
/

