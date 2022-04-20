REM @(#) src/schema/views/v_fh1ra.sql, swms, swms.9, 10.1.1 9/7/06 1.5
REM File : @(#) src/schema/views/v_fh1ra.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_fh1ra.sql, swms, swms.9, 10.1.1
REM

REM MODIFICATION HISTORY
REM 06/18/02 acpakp Changed the view to be in sync with the selection in the 
REM                 screen from float_hist_errors on fh1sa.fmb
REM                 Ignore DOD batch numbers created by alloc_inv if there is
REM                 a selection entry for the order_id and prod_id. If no 
REM                 selection data then consider DOD batches and null batches 
REM                 so that the report will be printed when no order found in 
REM                 float_hist.
REM 12/28/04 prpakp Changed to display the correct user name if the batch is 
REM		    selected by both the selector and the short runner.
REM 09/30/16 jluo6971 CRQ000000008968 Added the notion of uom that an ordered
REM                   item can be ordered in both case and split on same
REM                   customer and the return can be either or both.

create or replace view swms.v_fh1ra as
select fh.ship_date ship_date,
 fh.picktime,
 fh.src_loc src_loc,
 fh.cust_id cust_id,
 fh.route_no route_no,
 fh.stop_no stop_no,
 decode(substr(fh.batch_no,1,3),'DOD','',fh.batch_no) batch_no,
 fh.user_id user_id,
 fh.short_user_id,
 decode(nvl(fh.qty_short,0),0,'O',decode(sign(fh.qty_order-fh.qty_short),0,'S','B')) user_type,
 s.prod_id prod_id,
 s.cust_pref_vendor cust_pref_vendor,
 s.order_id order_id,
 s.reason_code reason_code,
 s.ret_qty,
 s.case_qty case_qty,
 s.split_qty split_qty,
 s.cost Cost,
 s.descrip descrip,
 u.badge_no badge_no,
 u.user_name user_name,
 u1.user_name short_user_name,
 min(fh.order_line_id) order_line_id,
 s.returned_prod_id,
 s.ret_item_descrip rtn_descrip,
 s.returned_loc,
 s.orig_invoice,
 fh.scan_type
from float_hist fh, v_fh1ra_sum s, usr u, pm, usr u1
where fh.order_id = NVL(s.orig_invoice, s.order_id)
  and fh.prod_id = s.prod_id
  and fh.cust_pref_vendor = s.cust_pref_vendor
  and fh.prod_id = pm.prod_id
  and fh.cust_pref_vendor = pm.cust_pref_vendor
  and 'OPS$' || fh.user_id = u.user_id(+)
  and 'OPS$' || fh.short_user_id = u1.user_id(+)
  and s.ret_qty > 0
  and decode(fh.uom, 2, 0, fh.uom) = decode(s.ret_uom, 2, 0, s.ret_uom) 
  and (
        (
          (batch_no is null or batch_no like 'DOD%')
           and  not exists (select 'x' from float_hist fh1
                   where fh1.prod_id = fh.prod_id
                   and fh1.cust_pref_vendor = fh.cust_pref_vendor
                   and fh1.order_id = fh.order_id
                   and fh1.batch_no is not null
                   and fh1.batch_no not like 'DOD%')
        )
        or  (batch_no is not null and batch_no not like 'DOD%')
     )
group by fh.ship_date, fh.picktime, fh.src_loc, fh.cust_id, fh.route_no,
         fh.stop_no, decode(substr(fh.batch_no,1,3),'DOD','',fh.batch_no), 
         fh.short_user_id,decode(nvl(fh.qty_short,0),0,'O',decode(sign(fh.qty_order-fh.qty_short),0,'S','B')),
	 s.prod_id,fh.user_id,
         s.cust_pref_vendor, s.order_id, s.reason_code,
         s.ret_qty, s.case_qty, s.split_qty, s.cost,
         s.descrip, u.badge_no, u.user_name, u1.user_name,
         s.returned_prod_id, s.ret_item_descrip, s.returned_loc, s.orig_invoice,
         fh.scan_type
/
