-- Views to provide linkage between ord_cool and batch data
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_ord_cool_batch.sql, swms, swms.9, 10.1.1 10/9/08 1.7
--
-- View:
--    v_ord_cool
--
-- Description:
--    This view is used to provide linkage between ord_cool and batch data.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/18/05 prphqb	D#11870 Initial version.
--    03/08/05 prphqb   11884 Add upd_user to view so SOS can make OTHER work
--    03/25/05 prphqb   11892 Better identifying Bulk pulls                    
--    04/01/05 prphqb   Handle auto_ship_flags in sys_config and pm
--    10/09/08 prpakp   Corrected to allow cool for VRT.
------------------------------------------------------------------------------

-- Views to provide linkage between ord_cool and batch data

create or replace view swms.v_ord_cool_batch02  as 
select  f.route_no, c.order_id, c.order_line_id, d.prod_id, d.cust_pref_vendor, 
	c.seq_no,   
	f.batch_no batch_b, 
	d.qty_alloc qty_b, 
	0 batch_n, 0 qty_n,
        country_of_origin, wild_farm, c.upd_user, pallet_pull
from ord_cool c, floats f, float_detail d, pm p 
where c.order_id = d.order_id
and   c.order_line_id = d.order_line_id
and   d.float_no = f.float_no
and   (f.pallet_pull  != 'R' and f.pallet_pull != 'N')
and   d.prod_id = p.prod_id
and   d.cust_pref_vendor = p.cust_pref_vendor
union all
select  f.route_no, c.order_id, c.order_line_id, d.prod_id, d.cust_pref_vendor,
	c.seq_no,  
        0 batch_b, 0 qty_b, 
        f.batch_no batch_n, 
	decode(s.CONFIG_FLAG_VAL||p.auto_ship_flag,'YY',d.qty_alloc,d.qty_alloc/p.spc) qty_n, 
        country_of_origin, wild_farm, c.upd_user, pallet_pull
from ord_cool c, floats f, float_detail d, pm p, sys_config s
where c.order_id = d.order_id
and   c.order_line_id = d.order_line_id
and   d.float_no = f.float_no
and   f.pallet_pull = 'N'       
and   d.prod_id = p.prod_id
and   d.cust_pref_vendor = p.cust_pref_vendor
and   s.CONFIG_FLAG_NAME = 'AUTO_SHIP_FLAG' 
/
create or replace view swms.v_ord_cool_batch01
as 
select  route_no, order_id, order_line_id, prod_id, cust_pref_vendor, seq_no,   
	max(batch_b) batch_b, max(qty_b) qty_b,  
	max(batch_n) batch_n, max(qty_n) qty_n,  
        country_of_origin, wild_farm, upd_user
from v_ord_cool_batch02
group by route_no, order_id, order_line_id, prod_id, cust_pref_vendor, seq_no,
        country_of_origin, wild_farm, upd_user
/

create or replace view swms.v_ord_cool_batch 
as 
select route_no, order_id, order_line_id, prod_id, cust_pref_vendor, seq_no,
       decode(qty_b, 0, batch_n, decode(sign(qty_n - seq_no +1), 1, batch_n, batch_b)) batch_no,
       decode(qty_b, 0,   qty_n, decode(sign(qty_n - seq_no +1), 1,   qty_n,   qty_b)) qty_alloc,
       decode(qty_b, 0,   'N'  , decode(sign(qty_n - seq_no +1), 1,    'N' ,    'B' )) pallet_pull,
       country_of_origin, wild_farm, upd_user
from v_ord_cool_batch01
/
