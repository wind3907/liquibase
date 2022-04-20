CREATE OR REPLACE VIEW swms.v_sts_equipment AS
  SELECT cust_id,
  truck_no,
  route_no,
  barcode,
  add_date,
  sum(decode(status,'D',qty,0)) qty,
  sum(decode(status,'P',qty_returned,0)) qty_returned
  FROM sts_equipment
  GROUP BY truck_no,route_no,barcode,add_date,cust_id;
