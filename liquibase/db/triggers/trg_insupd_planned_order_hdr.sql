
CREATE OR REPLACE TRIGGER swms.trg_insupd_planned_order_hdr
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_insupd_planned_order_hdr.sql
--
-- Table:
--    PLANNED_ORDER_HDR
--
-- Description:
--    Perform necessary actions when a PLANNED_ORDER_HDR record is inserted
--    or updated.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/18/13 prpbcb   Created.
--                      Project: TFS
--  R12.6--WIB#230--CRQ-47092_Miniloader_processing_the_historical_orders_a_day_later
--
--                      --- Change for Historical Orders ---
--                      We are having issues with the order date sent by SUS
--                      in the ML queue which is affecting the processing of
--                      historical orders.
--                      The order date we are getting from SUS is
--                      actually the ship date.  For historical orders the
--                      miniloader looks at the order date to know when to
--                      process the historical orders orders so they get
--                      processed a day late.  So that we
--                      do not have to change SUS this trigger will
--                      set the order date to the correct date by calling
--                      function "pl_planned_orders.correct_order_date".
--                      For more info see the work history in the function.
--
--                      There is a DB trigger on MINILOAD_ORDER which applies
--                      similar logic for historical orders.
--                      The difference in the logic is the MINILOAD_ORDER
--                      trigger can change the historical order id in addition
--                      to changing the order date.
--                      See "trg_insupd_miniload_order.sql" for more info.
------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE ON swms.planned_order_hdr
FOR EACH ROW
DECLARE
   l_object_name        VARCHAR2(30) := 'trg_insupd_planned_order_hdr';
BEGIN
   IF INSERTING THEN
      --
      -- Correct the order date for historical orders.  See the
      -- modification history on 10/18/13 for more details.
      -- If the order date is null then leave things as is.
      --
      IF (    UPPER(:NEW.order_id) LIKE 'HIST%'
          AND :NEW.order_date      IS NOT NULL)
      THEN
         :NEW.order_date := pl_planned_order.correct_order_date
                                                 (i_order_id   => :NEW.order_id,
                                                  i_add_date   => SYSDATE,
                                                  i_order_date => :NEW.order_date);
      END IF;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
             'OLD order_id['   || :OLD.order_id || ']'
          || '  NEW order_id['   || :NEW.order_id || ']'
          || '  sys_context module[' || SYS_CONTEXT('USERENV','MODULE') || ']'
          || '  Error in trigger.',
          SQLCODE, SQLERRM, 'ORDER', l_object_name);

      RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);

END trg_insupd_planned_order_hdr;
/


