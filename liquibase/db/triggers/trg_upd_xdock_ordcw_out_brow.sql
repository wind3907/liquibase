/****************************************************************************

  File:
    trg_upd_xdock_ordcw_out_brow.sql

  Desc:
    This trigger will update XDOCK_ORDCW_OUT's updated_date and updated_user
    columns when an update is triggered.

  Modification History:

    Date      Designer        Comments
    --------- --------------- ----------------------------------------------
    6-JUL-21  mche6435        Initial Commit

****************************************************************************/

CREATE OR REPLACE TRIGGER SWMS.trg_upd_xdock_ordcw_out_brow
  BEFORE UPDATE
  ON SWMS.XDOCK_ORDCW_OUT
  FOR EACH ROW
BEGIN
    :NEW.upd_date := SYSDATE;
    :NEW.upd_user := REPLACE(USER, 'OPS$');
END trg_upd_xdock_ordcw_out_brow;
/
