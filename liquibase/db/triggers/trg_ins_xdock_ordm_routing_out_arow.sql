/****************************************************************************
  File:
    trg_ins_xdock_ordm_routing_out_arow.sql

  Desc:
    This trigger will insert a record into the xdock_meta_header table and kick
    off the message hub component for communication.

  Modification History:
    Date      Designer        Comments
    --------- --------------- -----------------------------------------------------
    16-JUN-21 mche6435        Initial Commit
****************************************************************************/

CREATE OR REPLACE TRIGGER SWMS.trg_ins_xdock_ordm_routing_out
  AFTER INSERT
  ON SWMS.XDOCK_ORDM_ROUTING_OUT
  FOR EACH ROW
DECLARE
  APPLICATION_FUNC VARCHAR(10) := 'XDOCK';
  PROCEDURE_NAME   VARCHAR(30) := 'trg_ins_xdock_ordm_routing_out';

  response_code   PLS_INTEGER;
BEGIN
  response_code := PL_MSG_HUB_UTLITY.insert_meta_header(
    :NEW.batch_id,
    'XDOCK_ORDM_ROUTING_OUT',
    :NEW.site_to,
    :NEW.site_from,
    1
  );

  IF response_code != 0 THEN
    pl_log.ins_msg(
      'FATAL',
      PROCEDURE_NAME,
      'Failed to successfully run PL_MSG_HUB_UTLITY.insert_meta_header. Response Code: ' || response_code,
      sqlcode,
      sqlerrm,
      APPLICATION_FUNC,
      PROCEDURE_NAME
    );
  END IF;
END trg_ins_xdock_ordm_routing_out;
/
