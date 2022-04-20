------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_li1sh.sql, swms, swms.9, 10.1.1 9/7/06 1.2
--
-- View:
--    v_wis_inc_hist_mst
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
create or replace view swms.v_li1sh as
select substr(w.user_id,1,10) user_id,substr(u.user_name,1,30) user_name,
       c.file_no comp_code,b.file_no batch_id,f.file_no file_no,
       e.file_no earn_3_code,
       sum(total_inc) + nvl(adj_amt,0)+nvl(overtime_amt,0) earn_3_amt
from wis_payroll_detail w, wis_payroll_adj a,usr u,
     wis_usr c,wis_usr f, wis_usr b, wis_usr e
where w.user_id = a.user_id(+)
and   w.user_id = replace(u.user_id,'OPS$','')
and c.user_id ='COMPANY_CODE'
and b.user_id = 'BATCH_ID'
and e.user_id = 'EARN_3_CODE'
and f.user_id = w.user_id
group by w.user_id,adj_amt,overtime_amt,u.user_name,
         c.file_no,b.file_no,f.file_no,e.file_no
having sum(total_inc) + nvl(adj_amt,0)+nvl(overtime_amt,0) > 0;

