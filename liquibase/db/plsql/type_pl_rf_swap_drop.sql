/********    Client object  ************/
CREATE OR REPLACE TYPE swms.swap_drop_client_obj FORCE AS OBJECT (
  equip_id           VARCHAR2(10),
  include_bulkpull   VARCHAR2(1),
  include_replen     VARCHAR2(1),
  from_aisle         VARCHAR2(2),
  to_aisle           VARCHAR2(2),
  task_id            VARCHAR2(10),
  scanned_data       VARCHAR2(10),
  scan_method        VARCHAR2(1),
  proximity          VARCHAR2(1),
  location           VARCHAR2(10)
);
/

/********    Server Objects and Table  ************/
-- Object returned if another swap task exists
CREATE OR REPLACE TYPE swms.swap_drop_next_task_obj FORCE AS OBJECT (
  task_id          VARCHAR2(10),   -- replenlst
  type             VARCHAR2(3),    -- replenlst
  src_loc          VARCHAR2(10),   -- replenlst
  dest_loc         VARCHAR2(10),   -- replenlst
  qty              NUMBER(7),      -- replenlst
  prod_id          VARCHAR2(9),    -- replenlst
  cpv              VARCHAR2(10),   -- replenlst/pm (cust_pref_vendor)
  descrip          VARCHAR2(30),   -- pm
  mfg_id           VARCHAR2(14)    -- pm
);
/

-- Replen list record from pl_rf_replen_list: p_populatereplenlist
CREATE OR REPLACE TYPE swms.swap_drop_replen_list_rec FORCE AS OBJECT (
  task_id          VARCHAR2(10),
  type             VARCHAR2(3),
  src_loc          VARCHAR2(10),
  dest_loc         VARCHAR2(10),
  pallet_id        VARCHAR2(18),
  priority         NUMBER(2),
  qty              NUMBER(7),
  prod_id          VARCHAR2(9),
  cpv              VARCHAR2(10),
  descrip          VARCHAR2(30),
  mfg_id           VARCHAR2(14),
  truck_no         VARCHAR2(10),
  door_no          NUMBER(4),
  drop_qty         NUMBER(7),
  blocked          VARCHAR2(1)   -- Swap blocked if replen/inv change is happening.
);
/

-- Table to hold the replen list records
CREATE OR REPLACE
TYPE SWMS.swap_drop_replen_list_table FORCE AS
TABLE OF SWMS.swap_drop_replen_list_rec;
/

-- Object to hold the table type
CREATE OR REPLACE
TYPE SWMS.swap_drop_replen_list_obj  FORCE
AS OBJECT(
  no_of_records   NUMBER(4),
  replen_list     SWMS.swap_drop_replen_list_table
);
/

SHOW ERRORS

GRANT EXECUTE ON swms.swap_drop_client_obj TO swms_user;
CREATE OR REPLACE PUBLIC SYNONYM swap_drop_client_obj FOR swms.swap_drop_client_obj;

GRANT EXECUTE ON swms.swap_drop_next_task_obj TO swms_user;
CREATE OR REPLACE PUBLIC SYNONYM swap_drop_next_task_obj FOR swms.swap_drop_next_task_obj;

GRANT EXECUTE ON swms.swap_drop_replen_list_rec TO swms_user;
CREATE OR REPLACE PUBLIC SYNONYM swap_drop_replen_list_rec FOR swms.swap_drop_replen_list_rec;

GRANT EXECUTE ON swms.swap_drop_replen_list_obj  TO swms_user;
CREATE OR REPLACE PUBLIC SYNONYM swap_drop_replen_list_obj FOR swms.swap_drop_replen_list_obj;
