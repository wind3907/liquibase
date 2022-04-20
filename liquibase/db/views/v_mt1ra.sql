REM @(#) src/schema/views/v_mt1ra.sql, swms, swms.9, 10.1.1 9/7/06 1.3
REM File : @(#) src/schema/views/v_mt1ra.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_mt1ra.sql, swms, swms.9, 10.1.1
REM
REM      MODIFICATION HISTORY
REM  05/17/05 prppxx Modified to use v_trans instead of trans table.
REM                  D#11917.

create or replace view swms.v_mt1ra as
select t.user_id user_id,
              t.rec_id rec_id,
              t.trans_type trans_type,
              t.order_id order_id,
              t.trans_date trans_date,
              t.trans_id trans_id,
              t.prod_id prod_id,
              t.cust_pref_vendor cust_pref_vendor,
              t.qty_expected qty_expected,
              p.spc spc,
              t.qty qty,
              t.uom uom,
              t.src_loc src_loc,
              t.dest_loc dest_loc,
              t.old_status old_status,
              t.new_status new_status,
              a.descrip reason,
              t.mfg_date mfg_date,
              t.lot_id lot_id,
              t.cmt cmt,
              t.reason_code reason_code,
              t.pallet_id pallet_id
       from  adj_type a, pm p, v_trans t
       where t.prod_id = p.prod_id(+)
       and   t.cust_pref_vendor = p.cust_pref_vendor(+)
       and   a.adj_type(+) = t.reason_code;

