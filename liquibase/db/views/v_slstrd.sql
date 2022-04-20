CREATE OR REPLACE VIEW SWMS.V_SLSTRD ("TRUCK_NO", "ROUTE_NO", "TYPE_SEQ", "BARCODE", "EQUIPMENT_TYPE", "MANIFEST_NO", "PALLET", "ADD_DATE","ADD_USER", "QTY", "QTY_RETURNED", "EDIT_SEQ", "EDIT_TYPE", "SHIP_DATE", "INBOUND_COUNT", "UPD_USER", "LOADER_COUNT") AS 
select 
  sa.truck_no,
  sa.route_no,
  sa.type_seq,
  sa.barcode,
  sa.equipment_type,
  sa.manifest_no,
  sa.pallet,
  sa.add_date,
  sa.add_user,
  se.qty,
  se.qty_returned,
  sa.Edit_seq,
  sa.Edit_Type,
  sa.ship_date,
  sa.Inbound_count,
  sa.upd_user,
  sa.loader_count
From
(SELECT s.truck_no, s.route_no, l.type_seq, l.barcode, l.equipment_type, s.manifest_no,
       s.pallet, s.add_date, s.add_user, s.Edit_seq, s.Edit_Type, s.ship_date, s.Inbound_count,
       s.upd_user, s.loader_count  
from sls_user_truck_accessory s, las_truck_equipment_type l
where s.type_seq = l.type_seq) sa
LEFT OUTER JOIN
(SELECT s.truck_no, s.route_no, l.type_seq, s.barcode, l.equipment_type, s.cust_id, s.add_date, sum(s.qty) qty, sum(s.qty_returned) qty_returned
from sts_equipment s, las_truck_equipment_type l 
where s.barcode = l.barcode group by s.truck_no, s.route_no, l.type_seq, s.barcode, l.equipment_type, s.cust_id, s.add_date) se
ON ( sa.truck_no = se.truck_no and  sa.route_no = se.route_no and  sa.barcode = se.barcode )
UNION
select 
  se1.truck_no,
  se1.route_no,
  se1.type_seq,
  se1.barcode,
  se1.equipment_type,
  sa1.manifest_no,
  sa1.pallet,
  sa1.add_date,
  sa1.add_user,
  se1.qty,
  se1.qty_returned,
  sa1.Edit_seq,
  sa1.Edit_Type,
  se1.add_date,
  sa1.Inbound_count,
  sa1.upd_user,
  sa1.loader_count
From
(SELECT s.truck_no, s.route_no, l.type_seq, l.barcode, l.equipment_type, s.manifest_no,
       s.pallet, s.add_date, s.add_user, s.Edit_seq, s.Edit_Type, s.ship_date, s.Inbound_count,
       s.upd_user, s.loader_count  
from sls_user_truck_accessory s, las_truck_equipment_type l
where s.type_seq = l.type_seq) sa1
RIGHT OUTER JOIN
(SELECT s.truck_no, s.route_no, l.type_seq, s.barcode, l.equipment_type, s.cust_id, s.add_date, sum(s.qty) qty, sum(s.qty_returned) qty_returned
from sts_equipment s, las_truck_equipment_type l 
where s.barcode = l.barcode group by s.truck_no, s.route_no, l.type_seq, s.barcode, l.equipment_type, s.cust_id, s.add_date) se1
ON (sa1.truck_no = se1.truck_no and  sa1.route_no = se1.route_no and  sa1.barcode = se1.barcode );