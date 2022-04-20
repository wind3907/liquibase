CREATE OR REPLACE VIEW swms.v_sts_equipment_cust AS
  select cust_id,
 barcode,
 sum(qty) qty,
 sum(qty_returned) qty_returned, 
sum(qty)-sum(qty_returned) qty_remaining 
from sts_equipment 
group by cust_id,barcode;  
    
