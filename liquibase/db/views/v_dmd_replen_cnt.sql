create or replace view swms.v_dmd_replen_cnt as
select prod_id, route_no, min(status) dmd_status, count(*) pending_dmd_repl
  from replenlst
 where type = 'DMD'
   and status in ('NEW','PIK')
 group by prod_id, route_no;
