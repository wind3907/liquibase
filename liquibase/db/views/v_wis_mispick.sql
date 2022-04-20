------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_wis_mispick.sql, lm, swms.9, 10.1.1 9/7/06 1.4
--
-- View:
--    v_wis_mispick
--
-- Description:
--    This view is used in Warehouse Incentive reports.
--
-- Used by:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/23/04 prpksn   view for warehouse incentive
--    10/28/05 prphqb   Add join condition using order_line_id from float_hist_errors
------------------------------------------------------------------------------

create or replace view swms.v_wis_mispick as
select a.batch_no,
       a.batch_date,
       a.user_id,
       a.lgrp_lbr_grp,
       a.jbcd_job_code, 
       a.ref_no,
       a.user_supervsr_id,
       a.lfun_lbr_func,
       a.jbcl_job_class,
       a.whar_area,
       a.actl_start_time,
       a.actl_stop_time,
       a.actl_time_spent,
       a.report_date,
       e.ret_qty,
       e.ret_uom,
       e.reason_code,
       r.cc_reason_code
from reason_cds r,float_hist fh,float_hist_errors e,v_wis_qualify a
where fh.order_id = e.order_id
and   fh.order_line_id = e.order_line_id
and   r.reason_cd_type = 'RTN'
and   r.reason_cd = e.reason_code
and   fh.prod_id = e.prod_id
and   e.ret_qty > 0
and   'S' || fh.batch_no = a.batch_no;

