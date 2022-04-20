/*********************************************************************************

  File: trg_ins_upd_ordm_arow.sql

  Description:

    This trigger will insert a record into XDOCK_ORDM_ROUTING_OUT when
    ORDM (Order master) receives a new crossdock(xdock) order (cross_dock_type = X
    and ordm.status = new) or when a new crossdock order in ORDM is updated while
    still new status.

    We will insert a new entry on update to provide a history of row update and
    because rows on the staging table are not expected to be long living.

  Modification History:

    Date      Designer        Comments
    --------- --------------- ----------------------------------------------
    14-JUN-21 mche6435        Initial Commit

*********************************************************************************/

CREATE OR REPLACE TRIGGER SWMS.trg_ins_upd_ordm_arow
  AFTER INSERT
  ON SWMS.ORDM
  FOR EACH ROW
  WHEN (
      NEW.cross_dock_type = 'X'
      AND NEW.STATUS = 'NEW'
      AND NEW.order_id IS NOT NULL
      AND NEW.route_no IS NOT NULL
      AND NEW.truck_no IS NOT NULL
      AND NEW.stop_no IS NOT NULL
      AND NEW.delivery_document_id IS NOT NULL
      AND NEW.site_id IS NOT NULL
      AND NEW.site_from IS NOT NULL
      AND NEW.site_to IS NOT NULL
  )
DECLARE
  APPLICATION_FUNC VARCHAR(10) := 'XDOCK';
  PROCEDURE_NAME   VARCHAR(30) := 'trg_ins_upd_ordm_arow';

  l_batch_id    VARCHAR2(14); -- Generated from pl_xdock_common.get_batch_id
BEGIN
  -- Get batch_id from common function
  BEGIN
    SELECT pl_xdock_common.get_batch_id
    INTO l_batch_id
    FROM dual;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg(
        'FATAL',
        PROCEDURE_NAME,
        'Failed to get batch_id from pl_xdock_common.get_batch_id',
        sqlcode,
        sqlerrm,
        APPLICATION_FUNC,
        PROCEDURE_NAME
      );
      RAISE;
  END;

  INSERT INTO SWMS.XDOCK_ORDM_ROUTING_OUT(
    sequence_number,
    batch_id,
    order_id,
    route_no,
    truck_no,
    stop_no,
    record_status,
    cross_dock_type,
    delivery_document_id,
    site_id,
    site_from,
    site_to,
    site_to_route_no,
    site_to_stop_no,
    site_to_truck_no,
    site_to_door_no,
    add_date,
    add_user
  )
  VALUES (
    XDOCK_SEQNO_SEQ.nextval,
    l_batch_id,
    :NEW.order_id,
    :NEW.route_no,
    :NEW.truck_no,
    :NEW.stop_no,
    'N',
    :NEW.cross_dock_type,
    :NEW.delivery_document_id,
    :NEW.site_id,
    :NEW.site_from,
    :NEW.site_to,
    :NEW.site_to_route_no,
    :NEW.site_to_stop_no,
    :NEW.site_to_truck_no,
    :NEW.site_to_door_no,
    SYSDATE,
    USER
  );
EXCEPTION
  WHEN OTHERS THEN
    pl_log.ins_msg('FATAL', PROCEDURE_NAME,
        'Failed to update XDOCK_ORDM_ROUTING_OUT. | '
        || 'order_id: ' || :NEW.order_id
        || ', route_no: ' || :NEW.route_no
        || ', truck_no: ' || :NEW.truck_no
        || ', stop_no: ' || :NEW.stop_no
        || ', status: ' || :NEW.status
        || ', cross_dock_type: ' || :NEW.cross_dock_type
        || ', delivery_document_id: ' || :NEW.delivery_document_id
        || ', site_id: ' || :NEW.site_id
        || ', site_from: ' || :NEW.site_from
        || ', site_to: ' || :NEW.site_to
        || ', site_to_route_no: ' || :NEW.site_to_route_no
        || ', site_to_stop_no: ' || :NEW.site_to_stop_no
        || ', site_to_truck_no: ' || :NEW.site_to_truck_no
        || ', site_to_door_no: ' || :NEW.site_to_door_no,
    sqlcode, sqlerrm, APPLICATION_FUNC, PROCEDURE_NAME);
    NULL;
END trg_ins_upd_ordm_arow;
/

