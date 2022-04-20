/****************************************************************************
  File:
    trg_upd_xdock_floats_out_brow.sql
  Desc:
    This trigger will update XDOCK_FLOATS_OUT's updated_date and updated_user
    columns when an update is triggered.
  Modification History:
    Date      Designer        Comments
    --------- --------------- -----------------------------------------------------
    14-JUN-21 mche6435        Initial Commit
****************************************************************************/

CREATE OR REPLACE TRIGGER SWMS.trg_upd_xdock_floats_out_brow
  BEFORE UPDATE
  ON SWMS.XDOCK_FLOATS_OUT
  FOR EACH ROW
BEGIN
    :NEW.upd_date := SYSDATE;
    :NEW.upd_user := REPLACE(USER, 'OPS$');
END trg_upd_xdock_floats_out_brow;
/
