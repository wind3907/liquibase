create or replace view swms.v_slstrb as
select s.cust_id,
	s.add_date ,
 	s.truck_no,
 	s.route_no,
    l.equipment_type,
    s.barcode,
    s.qty,
    s.Qty_returned,
    t.Qty_remaining
from  las_truck_equipment_type l,v_sts_equipment_cust t,v_sts_equipment s
where s.barcode = l.barcode and 
t.barcode = l.barcode and
t.barcode = s.barcode and 
t.cust_id = s.cust_id ;

