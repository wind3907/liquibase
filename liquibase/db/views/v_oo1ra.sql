REM @(#) src/schema/views/v_oo1ra.sql, swms, swms.9, 10.1.1 1/21/08 1.4
REM File : @(#) src/schema/views/v_oo1ra.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_oo1ra.sql, swms, swms.9, 10.1.1
REM
CREATE OR REPLACE VIEW SWMS.V_OO1RA AS
SELECT d.prod_id,
       p.descrip,
       d.qty_ordered qty_expected,
       d.qty_alloc qty,
       m.truck_no,
       m.route_no,
       m.stop_no,
       d.order_id,
       d.order_line_id,
       d.cust_pref_vendor,
       r.sch_time,
       r.method_id,
       r.status,
       r.route_batch_no,
       m.cust_id,
       m.cust_name,
       d.uom,
       d.seq,
       p.spc
  FROM pm p, ordd d, ordm m, route r
 WHERE m.route_no = r.route_no
   AND d.order_id = m.order_id
   AND d.status = 'SHT'
   AND p.prod_id = d.prod_id
   AND p.cust_pref_vendor = d.cust_pref_vendor
/

