/****************************************************************************
  File:
    trg_upd_xdock_ordm_routing_in_brow.sql

  Desc:
    This trigger will update XDOCK_ORDM_ROUTING_IN's updated_date and updated_user
    columns when an update is triggered.

  Modification History:
    Date      Designer        Comments
    --------- --------------- -----------------------------------------------------
    14-JUN-21 mche6435        Initial Commit
****************************************************************************/

CREATE OR REPLACE TRIGGER SWMS.trg_upd_xdock_ordm_routing_in
  BEFORE UPDATE
  ON SWMS.XDOCK_ORDM_ROUTING_IN
  FOR EACH ROW
BEGIN
    :NEW.upd_date := SYSDATE;
    :NEW.upd_user := REPLACE(USER, 'OPS$');
END trg_upd_xdock_ordm_routing_in;
/
