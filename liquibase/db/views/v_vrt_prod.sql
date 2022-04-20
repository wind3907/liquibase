CREATE OR REPLACE VIEW swms.v_vrt_prod (route_no, order_type, order_id, prod_id, cust_pref_vendor, qty_ordered, qty_alloc)
AS
SELECT  od.route_no, o.order_type, od.order_id, od.prod_id, od.cust_pref_vendor,
        SUM (od.qty_ordered), SUM (od.qty_alloc)
  FROM  ordd od, ordm o
 WHERE  o.order_type = 'VRT'
   AND  od.order_id = o.order_id
 GROUP  BY od.route_no, o.order_type, od.order_id, od.prod_id, od.cust_pref_vendor
/

