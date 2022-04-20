REM @(#) src/schema/views/v_mt1rb.sql, swms, swms.9, 10.1.1 9/7/06 1.3
REM File : @(#) src/schema/views/v_mt1rb.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_mt1rb.sql, swms, swms.9, 10.1.1
REM
REM      MODIFICATION HISTORY
REM  05/17/05 prppxx Modified to use v_trans instead of trans table.
REM                  D#11917.

create or replace view swms.v_mt1rb as
select t.trans_id,
        t.trans_type,
        t.user_id,
        t.trans_date,
    decode(trans_type,'RTN',decode(uom,0,t.qty),'PAW',decode(uom,0,t.qty,2,t.qty
),decode(uom,0,floor(t.qty/nvl(spc,1)),2,floor(t.qty/nvl(spc,1)))) qty,
        decode(uom,1,t.qty) splits,
        t.prod_id,
        t.cust_pref_vendor,
        t.pallet_id,
        t.route_no,
        t.batch_no,
        t.src_loc,
        t.dest_loc,
        t.reason_code,
        t.rec_id,
        p.spc,
        t.uom,
        p.split_trk
  from v_trans t, pm p
 where t.prod_id = p.prod_id (+)
   and t.cust_pref_vendor = p.cust_pref_vendor (+);

