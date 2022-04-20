create or replace view swms.v_new_ndm_replen_cnt as
select prod_id, count(*) replen_cnt, sum(qty) replen_qty
  from replenlst
 where type='NDM' and status='NEW'
 group by prod_id;
