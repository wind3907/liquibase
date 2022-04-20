CREATE OR REPLACE TRIGGER swms.trg_ins_planned_order_dtl
------------------------------------------------------------------------------
-- Trigger:
--    trg_ins_planned_order_dtl
--
-- Description:
--    This script contains a trigger which updates the pm table with the historical order data.
--
--    Any errors are logged to the log table.  Processing does not stop.
--
-- Modification History:
--    Date      Designer Comments
--    --------- -------- ------------------------------------------------------
--    11/11/15                   Sunil Ontipalli
--                               Created as part of the Symbotic Throttling
--    03/02/15  bben0556         Brian Bent
--                               Do not log any messages doing normal processing.
--                               It creates too many messages.
--
--                               Comment out the COMMITs.  We should not have
--                               commits in triggers.
------------------------------------------------------------------------------
AFTER INSERT
ON swms.planned_order_dtl
FOR EACH ROW
DECLARE
   -- l_program_code  VARCHAR2(30) := 'TRG_AI_PLANNED_ORDER_DTL';   -- 03/2/2016 Brian Bent Undecided about this.

   l_bln_item_found  BOOLEAN       :=  TRUE;  -- To keep track if the item is in the PM table.
BEGIN
   -- pl_text_log.ins_msg('INFO', 'trg_ins_planned_order_dtl',
   --                'Trigger trg_ins_planned_order_dtl 1',
   --                 NULL, NULL);

   IF (:NEW.order_id LIKE 'HIST%') THEN
      -- pl_text_log.ins_msg('INFO', 'trg_ins_planned_order_dtl',
      --                    'Trigger trg_ins_planned_order_dtl Obtaining Historical Order data',
      --                    NULL, NULL);

      IF (:NEW.uom = 1) THEN
         BEGIN
            UPDATE pm
               SET pm.hist_split_order = :NEW.qty,
                   pm.hist_split_date  = SYSDATE
             WHERE pm.prod_id            = :NEW.prod_id
               AND pm.cust_pref_vendor   = :NEW.cust_pref_vendor;

             IF (SQL%ROWCOUNT = 0) THEN
                --
                -- Did not find the item in PM table.
                --
                l_bln_item_found := FALSE;
             END IF;

            -- COMMIT;
         EXCEPTION 
            WHEN OTHERS THEN
               --
               -- Encountered an error.  Log a message but do not stop
               -- processing.
               --
               pl_log.ins_msg(pl_log.ct_warn_msg, 'trg_ins_planned_order_dtl',
                    'NEW order_id['               || :NEW.prod_id                    || ']'
                    || '  NEW cust_pref_vendor['  || :NEW.cust_pref_vendor           || ']'
                    || '  sys_context module['    || SYS_CONTEXT('USERENV','MODULE') || ']'
                    || '  Failed to update PM hist_split_order and hist_split_date.'
                    || '  This will not stop processing',
                    SQLCODE, SQLERRM, 'INV', 'trg_ins_planned_order_dtl');
         END;
      ELSIF (:NEW.uom = 2) THEN
         BEGIN
            UPDATE pm
               SET pm.hist_case_order = :NEW.qty,
                   pm.hist_case_date  = SYSDATE
             WHERE pm.prod_id           = :NEW.prod_id
               AND pm.cust_pref_vendor  = :NEW.cust_pref_vendor;

             IF (SQL%ROWCOUNT = 0) THEN
                --
                -- Did not find the item in PM table.
                --
                l_bln_item_found := FALSE;
             END IF;

            -- COMMIT;
         EXCEPTION 
            WHEN OTHERS THEN
               --
               -- Encountered an error.  Log a message but do not stop
               -- processing.
               --
               pl_log.ins_msg(pl_log.ct_warn_msg, 'trg_ins_planned_order_dtl',
                    'NEW order_id['               || :NEW.prod_id                    || ']'
                    || '  NEW cust_pref_vendor['  || :NEW.cust_pref_vendor           || ']'
                    || '  sys_context module['    || SYS_CONTEXT('USERENV','MODULE') || ']'
                    || '  Failed to update PM hist_case_order and hist_case_date.'
                    || '  This will not stop processing',
                    SQLCODE, SQLERRM, 'INV', 'trg_ins_planned_order_dtl');
         END;
      ELSE
         --
         -- Have an unhandled value for :NEW.uom
         -- Log a message but do not stop processing.
         --
         pl_log.ins_msg(pl_log.ct_warn_msg, 'trg_ins_planned_order_dtl',
                    'NEW order_id['               || :NEW.prod_id                    || ']'
                    || '  NEW cust_pref_vendor['  || :NEW.cust_pref_vendor           || ']'
                    || '  NEW uom['               || TO_CHAR(:NEW.uom)               || ']'
                    || '  sys_context module['    || SYS_CONTEXT('USERENV','MODULE') || ']'
                    || '  Have an unhandled value for NEW.uom.'
                    || '  This will not stop processing',
                    SQLCODE, SQLERRM, 'INV', 'trg_ins_planned_order_dtl');
      END IF;

      --
      -- If the item was not in the PM table then log a message.
      -- Do not stop processing.
      --
      IF (l_bln_item_found = FALSE) THEN
         pl_log.ins_msg(pl_log.ct_warn_msg, 'trg_ins_planned_order_dtl',
                    'NEW order_id['               || :NEW.prod_id                    || ']'
                    || '  NEW cust_pref_vendor['  || :NEW.cust_pref_vendor           || ']'
                    || '  sys_context module['    || SYS_CONTEXT('USERENV','MODULE') || ']'
                    || '  Did not find item in PM table.'
                    || '  This will not stop processing',
                    NULL, NULL, 'INV', 'trg_ins_planned_order_dtl');
      END IF;
   END IF;	  
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Log the error, do not stop processing.
      --
      pl_log.ins_msg(pl_log.ct_warn_msg, 'trg_ins_planned_order_dtl',
                    'NEW order_id['               || :NEW.prod_id                    || ']'
                    || '  NEW cust_pref_vendor['  || :NEW.cust_pref_vendor           || ']'
                    || '  sys_context module['    || SYS_CONTEXT('USERENV','MODULE') || ']'
                    || '  Error in trigger in final WHEN-OTHERS'
                    || '  This will not stop processing',
                    SQLCODE, SQLERRM, 'INV', 'trg_ins_planned_order_dtl');
END trg_ins_planned_order_dtl;
/

