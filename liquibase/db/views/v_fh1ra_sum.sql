REM @(#) src/schema/views/v_fh1ra_sum.sql, swms, swms.9, 10.1.1 9/7/06 1.5             
REM File : @(#) src/schema/views/v_fh1ra_sum.sql, swms, swms.9, 10.1.1              
REM Usage: sqlplus USR/PWD @src/schema/views/v_fh1ra_sum.sql, swms, swms.9, 10.1.1 
REM Modification History
REM Date	Name		Comments
REM 10/04/04	prplhj		D#11741 Ticket 34511 For cost calculations, the
REM				returned uom of the item must be considered
REM				since the avg_wt and item cost are saved as
REM				split qtys in SWMS.
REM                             
REM 10/28/04    prphqb      WAI - add join to order_line_id from flaot_hist_errors table
REM 09/30/16 jluo6971 CRQ000000008968 Added the notion of uom that an ordered
REM                   item can be ordered in both case and split on same
REM                   customer and the return can be either or both.

create or replace view swms.v_fh1ra_sum as
select fhe.prod_id prod_id,
         fhe.cust_pref_vendor cust_pref_vendor,
         fhe.order_id order_id,
         fhe.order_id order_line_id,                           -- WAI change
         fhe.reason_code reason_code,
         sum (decode(ret_uom,0,nvl(ret_qty,0),0)) case_qty,
         sum (decode(ret_uom,1,ret_qty,0)) split_qty,
         round (sum((trunc(nvl(fhe.ret_qty,0)) *
		(decode(p.catch_wt_trk,'Y',
			(p.avg_wt*decode(fhe.ret_uom, 1, 1, p.spc)), 1)) *
			p.item_cost)),2) cost,
         p.descrip descrip,
         fhe.ret_qty,
         fhe.returned_prod_id,
         fhe.returned_loc,
         p2.descrip ret_item_descrip,
	 fhe.ret_uom,
         fhe.orig_invoice
from float_hist_errors fhe, pm p, pm p2
where fhe.prod_id = p.prod_id
and   fhe.cust_pref_vendor = p.cust_pref_vendor
and   NVL(fhe.returned_prod_id, fhe.prod_id) = p2.prod_id
group by fhe.prod_id ,
         fhe.cust_pref_vendor ,
         fhe.order_id ,
         fhe.order_line_id ,
         fhe.reason_code ,
         p.descrip,
         fhe.ret_qty,
         fhe.returned_prod_id,
         fhe.returned_loc,
	 fhe.ret_uom,
         p2.descrip,
         fhe.orig_invoice
/

