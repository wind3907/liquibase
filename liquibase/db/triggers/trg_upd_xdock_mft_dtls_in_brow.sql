/****************************************************************************
  File:
    trg_upd_xdock_mft_dtls_in_brow.sql
  Desc:
    This trigger will update XDOCK_MANIFEST_DTLS_IN's updated_date,upd_source and updated_user
    columns when an update is triggered.
  Modification History:
    Date      Designer        Comments
    --------- --------------- -----------------------------------------------------
    30-AUG-21 cjay3161        Initial Commit
****************************************************************************/

CREATE OR REPLACE TRIGGER SWMS.trg_upd_xdock_mft_dtls_in_brow
    BEFORE UPDATE
    ON SWMS.XDOCK_MANIFEST_DTLS_IN
    FOR EACH ROW
BEGIN
    :NEW.upd_date := SYSDATE;
    :NEW.upd_user := REPLACE(USER, 'OPS$');
    :NEW.upd_source := 'XDK';
END trg_upd_xdock_mft_dtls_in_brow;
/