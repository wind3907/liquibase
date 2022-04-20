/****************************************************************************
  File:
    trg_upd_xdock_ordd_in_brow.sql

  Desc:
    This trigger will update XDOCK_ORDD_IN's updated_date and updated_user
    columns when an update is triggered.

  Modification History:
    Date      Designer        Comments
    --------- --------------- -----------------------------------------------------
    10-AUG-21 mche6435        Initial Commit
****************************************************************************/

CREATE OR REPLACE TRIGGER SWMS.trg_upd_xdock_ordd_in_brow
  BEFORE UPDATE
  ON SWMS.XDOCK_ORDD_IN
  FOR EACH ROW
BEGIN
    :NEW.upd_date := SYSDATE;
    :NEW.upd_user := REPLACE(USER, 'OPS$');
END trg_upd_xdock_ordd_in_brow;
/

