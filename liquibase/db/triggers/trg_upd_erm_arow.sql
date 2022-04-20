/*********************************************************************************

  File: trg_upd_erm_arow.sql

  Description: Triggers for post update on the ERM table

  Modification History:

    Date      Designer        Comments
    --------- --------------- ----------------------------------------------
    26-AUG-21 mche6435        Initial Commit
    15-SEP-21 mche6435        OPCOF-3672 - Update to arrival only when the last
                              ERM entry for a specific load_no is opened rather
                              than each one.
*********************************************************************************/

CREATE OR REPLACE TRIGGER SWMS.trg_upd_erm_arow
  AFTER UPDATE
  ON SWMS.ERM
  FOR EACH ROW
  WHEN (
    OLD.erm_type = 'XN'
    AND (
      (OLD.status IN ('NEW', 'SCH') AND NEW.status='OPN')
      OR (OLD.status = 'OPN' AND NEW.status = 'SCH')
    )
  )

DECLARE
  APPLICATION_FUNC VARCHAR(10) := 'XDOCK';
  TRIGGER_NAME     VARCHAR(30) := 'trg_upd_erm_arow';

  l_delivery_document_id  ordm.delivery_document_id%TYPE;
  l_rows_updated          PLS_INTEGER;
  l_found_entry           BOOLEAN := FALSE;
  l_erm_open_count        PLS_INTEGER; -- ARRIVAL status should only be set during the last erm open.

  -- Used to bulk set ARRIVAL status
  CURSOR c_all_doc_ids IS
    SELECT DISTINCT om.delivery_document_id
    FROM erd_lpn lp
    INNER JOIN xdock_floats_in f ON lp.parent_pallet_id = f.parent_pallet_id
    INNER JOIN xdock_float_detail_in fd ON f.float_no = fd.float_no
    INNER JOIN ordm om ON fd.order_id = om.order_id
    WHERE lp.sn_no LIKE :NEW.load_no || '-%';

  -- Used to determine 1 erm record after release.
  CURSOR c_specific_doc_id IS
    SELECT DISTINCT om.delivery_document_id
    FROM erd_lpn lp
    INNER JOIN xdock_floats_in f ON lp.parent_pallet_id = f.parent_pallet_id
    INNER JOIN xdock_float_detail_in fd ON f.float_no = fd.float_no
    INNER JOIN ordm om ON fd.order_id = om.order_id
    WHERE lp.sn_no = :NEW.erm_id;

  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  pl_log.ins_msg('DEBUG', TRIGGER_NAME, 'Starting trigger: ' || TRIGGER_NAME, sqlcode, sqlerrm, APPLICATION_FUNC, TRIGGER_NAME);

  -- Case 1: Set XDOCK_ORDER_XREF entry to ARRIVED on ERM new/sch to opn status
  IF :OLD.status IN ('NEW', 'SCH') AND :NEW.status='OPN' THEN
    pl_log.ins_msg('DEBUG', TRIGGER_NAME, 'Counting ERM Rows', sqlcode, sqlerrm, APPLICATION_FUNC, TRIGGER_NAME);
    -- We should only run after all entries are opened.
    SELECT COUNT(0)
    INTO l_erm_open_count
    FROM erm
    WHERE erm_type = 'XN'
    AND status IN ('NEW', 'SCH')
    AND load_no = :NEW.load_no;

    IF l_erm_open_count <= 1 THEN -- Only open if its the last entry to be opened.
      pl_log.ins_msg('DEBUG', TRIGGER_NAME, 'Setting each entry to arrived.', sqlcode, sqlerrm, APPLICATION_FUNC, TRIGGER_NAME);

      -- Retrieve delivery document id related to this erm
      FOR r_deliver_doc_id IN c_all_doc_ids
      LOOP
        l_found_entry := TRUE;
        IF r_deliver_doc_id.delivery_document_id IS NULL THEN
          pl_log.ins_msg('FATAL', TRIGGER_NAME, 'delivery_document_id is null, expected not null', sqlcode, sqlerrm, APPLICATION_FUNC, TRIGGER_NAME);
        ELSE
          pl_log.ins_msg('DEBUG', TRIGGER_NAME, 'Updating ' || r_deliver_doc_id.delivery_document_id, sqlcode, sqlerrm, APPLICATION_FUNC, TRIGGER_NAME);

          -- Update xdock_order_xref
          UPDATE XDOCK_ORDER_XREF
          SET x_lastmile_status = 'ARRIVED'
          WHERE delivery_document_id = r_deliver_doc_id.delivery_document_id;

          l_rows_updated := SQL%ROWCOUNT;

          IF l_rows_updated < 1 THEN
            pl_log.ins_msg(
              'WARN',
              TRIGGER_NAME,
              'Unexpected number of rows updated in XDOCK_ORDER_XREF. delivery_document_id: ' || l_delivery_document_id
                || ' Updated: ' || l_rows_updated
                || ' Expected: >= 1',
              sqlcode,
              sqlerrm,
              APPLICATION_FUNC,
              TRIGGER_NAME
            );
          END IF;
        END IF;
      END LOOP;
    ELSE
      l_found_entry := TRUE; -- Set this since we aren't using it right now to avoid logging.

      pl_log.ins_msg(
        'DEBUG',
        TRIGGER_NAME,
        'More NEW/SCH entries exist with this load_no, skipping arrival setting. row_count: ' || l_erm_open_count,
        sqlcode,
        sqlerrm,
        APPLICATION_FUNC,
        TRIGGER_NAME
      );
    END IF;
  ELSIF :OLD.status = 'OPN' AND :NEW.status = 'SCH' THEN
    -- Case 2: Set XDOCK_ORDER_XREF entry back to INTRANSIT on ERM OPN to SCH (Release XN).
    FOR r_deliver_doc_id IN c_specific_doc_id
    LOOP
      l_found_entry := TRUE;

      IF r_deliver_doc_id.delivery_document_id IS NULL THEN
        pl_log.ins_msg('FATAL', TRIGGER_NAME, 'delivery_document_id is null, expected not null', sqlcode, sqlerrm, APPLICATION_FUNC, TRIGGER_NAME);
      ELSE
        pl_log.ins_msg(
          'DEBUG',
          TRIGGER_NAME,
          'Releasing xdock_order_xref entry with delivery_document_id: ' || r_deliver_doc_id.delivery_document_id,
          sqlcode,
          sqlerrm,
          APPLICATION_FUNC,
          TRIGGER_NAME
        );

        -- Update xdock_order_xref
        UPDATE XDOCK_ORDER_XREF
        SET x_lastmile_status = 'INTRANSIT'
        WHERE delivery_document_id = r_deliver_doc_id.delivery_document_id;

        l_rows_updated := SQL%ROWCOUNT;

        IF l_rows_updated < 1 THEN
          pl_log.ins_msg(
            'WARN',
            TRIGGER_NAME,
            'Unexpected number of rows updated in XDOCK_ORDER_XREF. delivery_document_id: ' || l_delivery_document_id
              || ' Updated: ' || l_rows_updated
              || ' Expected: >= 1',
            sqlcode,
            sqlerrm,
            APPLICATION_FUNC,
            TRIGGER_NAME
          );
        END IF;
      END IF;
    END LOOP;
  END IF;

  IF l_found_entry THEN
    COMMIT;
  ELSE
    pl_log.ins_msg(
      'FATAL',
      TRIGGER_NAME,
      'No delivery_document_id found, no status update occured.',
      sqlcode,
      sqlerrm,
      APPLICATION_FUNC,
      TRIGGER_NAME
    );
    ROLLBACK;
  END IF;

  pl_log.ins_msg('DEBUG', TRIGGER_NAME, 'Ending trigger: ' || TRIGGER_NAME, sqlcode, sqlerrm, APPLICATION_FUNC, TRIGGER_NAME);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    pl_log.ins_msg('FATAL', TRIGGER_NAME, 'No data found, erm_id: ' || :NEW.erm_id, sqlcode, sqlerrm, APPLICATION_FUNC, TRIGGER_NAME);
  WHEN OTHERS THEN
    pl_log.ins_msg('FATAL', TRIGGER_NAME, 'Failed to run ' || TRIGGER_NAME, sqlcode, sqlerrm, APPLICATION_FUNC, TRIGGER_NAME);
END trg_upd_erm_arow;
/

