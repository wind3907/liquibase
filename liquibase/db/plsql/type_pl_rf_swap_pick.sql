/********    Client object  ************/
CREATE OR REPLACE TYPE swms.swap_pick_client_obj FORCE AS OBJECT (
  equip_id    VARCHAR2(10),
  task_id     VARCHAR2(10),
  scanned_data  VARCHAR2(18),
  scan_method   VARCHAR2(1),
  func1_flag    VARCHAR2(1)
);
/

SHOW ERRORS

GRANT EXECUTE ON swms.swap_pick_client_obj TO swms_user;
CREATE OR REPLACE PUBLIC SYNONYM swap_pick_client_obj FOR swms.swap_pick_client_obj;

