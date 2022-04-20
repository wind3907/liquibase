------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_pavpa
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------

--     04/01/10   sth0458   DN12554 - 212 Legacy Enhancements - SCE057 - 
--                          Add UOM field to SWMS
--                          Expanded the length of prod size to accomodate 
--                          for prod size unit.
--                          Changed queries to fetch prod_size_unit 
--                          along with prod_size
--
------------------------------------------------------------------------------
  CREATE OR REPLACE FORCE VIEW "SWMS"."V_PAVPA" ("ORDER_ID", "SHIP_NAME", "SHIP_ADDR1", "ROUTE_NO", "SHIP_CITY", "SHIP_STATE", "SHIP_ZIP", "CUST_ID", "CUST_NAME", "CUST_ADDR1", "CUST_CITY", "CUST_STATE", "CUST_ZIP", "TRUCK_NO", "STOP_NO", "ORDER_LINE_ID", "L_QTY", "L_WH_OUT", "L_UOM", "PROD_ID", "CUST_PREF_VENDOR", "CATEGORY", "PACK", "PROD_SIZE", 
         /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - Begin */
        "PROD_SIZE_UNIT",
        /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - End */
         "BRAND", "DESCRIP", "SPC", "ORDER_INVOICE_INST", "ORDER_SHIPPING_INST", "L_CATCH_WEIGHT") AS 
  select
    x.order_id order_id,
    x.ship_name ship_name,
    x.ship_addr1 ship_addr1,
    x.route_no route_no,
    x.ship_city ship_city,
    x.ship_state ship_state,
    x.ship_zip ship_zip,
    x.cust_id cust_id,
    x.cust_name cust_name,
    x.cust_addr1 cust_addr1,
    x.cust_city cust_city,
    x.cust_state cust_state,
    x.cust_zip cust_zip,
    x.truck_no truck_no,
    x.stop_no stop_no,
    y.order_line_id order_line_id,
    to_char(y.qty_alloc) l_qty,
    decode(y.wh_out_qty, NULL,0,wh_out_qty) l_wh_out,
    to_char(y.uom) l_uom,
    y.prod_id prod_id,
    y.cust_pref_vendor cust_pref_vendor,
    z.category category,
    z.pack pack,
    z.prod_size prod_size,
    /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - Begin */
    z.prod_size_unit prod_size_unit,
    /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - End */
    z.brand brand,
    z.descrip descrip,
    z.spc spc,
    c.order_invoice_inst order_invoice_inst,
    c.order_shipping_inst order_shipping_inst,
    sum(a.catch_weight) l_catch_weight
    from  ordm x, ordd y, pm z,
          ordcw a, route b, rec_order_hdrs c
where   x.route_no  = b.route_no
  and   b.status    = 'CLS'
  and   x.order_id  = y.order_id
  and   y.prod_id   = z.prod_id
  and   y.cust_pref_vendor  = z.cust_pref_vendor
  and   y.order_id  = a.order_id(+)
  and   y.order_line_id = a.order_line_id(+)
  and   x.sys_order_id  = c.sys_order_id(+)
group   by
    x.route_no,     x.order_id,
    y.order_line_id,
    y.prod_id,      y.cust_pref_vendor,
    x.ship_name,
    x.ship_addr1,   x.ship_city,
    x.ship_state,   x.ship_zip,
    x.cust_id,      x.cust_name,
    x.cust_addr1,   x.cust_city,
    x.cust_state,   x.cust_zip,
    x.truck_no,     x.stop_no,
    y.qty_alloc,    y.wh_out_qty,
    y.uom,          z.category,
    z.pack,         z.prod_size,
/* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - Begin */
    z.prod_size_unit,
/* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - End */
    z.brand,        z.descrip,     z.spc,
    c.order_invoice_inst,   c.order_shipping_inst                               
;
 
