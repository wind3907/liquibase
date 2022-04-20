
CREATE OR REPLACE TRIGGER swms.trg_insupd_miniload_order
BEFORE INSERT OR UPDATE ON swms.miniload_order
FOR EACH ROW
DECLARE
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_insupd_miniload_order.sql, swms, swms.9, 10.1.1 10/29/07 1.1
--
-- Table:
--    MINILOAD_ORDER
--
-- Description:
--    Perform necessary actions when a MINILOAD_ORDER record is inserted
--    or updated is updated.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/05/07 prpbcb   DN 12280
--                      Ticket: 458478
--                      Project: 458478-Miniload Fixes
--                      Created to assign the update user and update date.
--
--    10/18/13 prpbcb   Project: TFS
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
--                      There is a trigger on PLANNED_ORDER_HDR which applies
--                      similar logic on the order date for historical
--                      orders but that trigger does not change the order id
--                      and it keys strictly off the order_date.
--
--                      We also have to change the historical order id in case
--                      the miniloader is using the date embedded in the order
--                      id as the order date. (If it was not necessary to
--                      change the order id then the processing in this trigger
--                      would be greatly simplified as we would only
--                      have to change the order_date in the header record).
--                      The order id format is "HISTYYYYMMDD".  So we will
--                      use the YYYYMMDD as the order date.  Because we need
--                      to change the order id for the detail and trailer
--                      records which have null order date the order date
--                      will be taken from the order id.
--                      The order id format is "HISTYYYYMMDD". 
--
--                      The processing for Historical orders will be:
--                      1.  If the order date is populated and does not 
--                          match the date embedded in the order id then log
--                          a message.  We are expecting them to be the same.
--                          Only the header record should have the order date
--                          populated.
--                      2.  Call "pl_planned_order.correct_order_date" using
--                          the YYYYMMDD in the order id as the order date.
--                          If the order date is "corrected" then log a message
--                          but only for the header record.  We do not want
--                          to log a message for each detail record or the
--                          trailer record.
--                      3.  If the order date was corrected:
--                          a.  Set the order id to
--                              HIST<YYYYMMDD of the corrected order date>
--                          b.  Set the order_date to
--                              HIST<YYYYMMDD>" of the corrected date>
--                              if the order_date is populated.
--
--                      Hopefully this does not cause too much confusion when
--                      researching issues since the order id
--                      and order date sent from the host system can be
--                      changed.
--
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/31/14 prpbcb   Project: TFS
--       R12.6.2--WIB#427--Charm6000001721_Do_not_send_duplicate_order_to_the_ML
--                      I piggy backed this change on this project.
--
--                      For change made on 10/18/13 for project
--  R12.6--WIB#230--CRQ-47092_Miniloader_processing_the_historical_orders_a_day_later
--                      I forget to put in the check to only output the
--                      INFO message that the order date is correct when
--                      processing the header record.  We don't want to
--                      create log messages for the detail and trailer
--                      records as this is unnecessary and would be confusing.
--
--                      I did notice in testing the change for
--                      "Do_not_send_duplicate_order_to_the_ML"
--                      is since this trigger can change the historical
--                      order order id the processing for the duplicate
--                      order for a historical order does not work as
--                      expected.  After reviewing, this will not cause
--                      any issue other than a somewhat misleading log message
--                      in the SWMS_LOG table.
--
--    12/11/15 prpbcb   Project: TFS
-- R30.4--FTP30.3.2--WIB#594--Charm6000010809_Historical_order_date_sent_to_miniloader_is_the_ship_date_instead_of_the_pick_date
--
--                      The change on 10/18/13 for the historical order date
--                      did not change the historical order date in ML_DATA
--                      column which needs to be changed too since at this
--                      point ML_DATA is already built and is what is sent
--                      to the miniloader.
--                      Added:
--  :NEW.ml_data := REPLACE(:NEW.ml_data, l_original_order_id, :NEW.order_id);
--
--  IF (:NEW.message_type = pl_miniload_processing.ct_ship_ord_hdr) THEN
--     :NEW.ml_data := REPLACE(:NEW.ml_data, TO_CHAR(l_original_order_date, 'YYYY-MM-DD'), TO_CHAR(:NEW.order_date, 'YYYY-MM-DD'));
--  END IF;
--                      I'll take the chance the order id and order date
--                      string only exist once in ML_DATA so REPLACE used.
--                      I could have switched things based on the position
--                      of the order id and order date within ML_DATA but
--                      I felt that was not necessary.  I will dual maintain
--                      this change to 12.6.
--
--                      12.6 version is actually more current, mainly log
--                      messages changes, though the functionality is still
--                      the same.  I took the 12.6 changes and applied here.
--                      In SWMS 30 the log message type constants are in pl_log
--                      as opposed to 12.6 which had them in pl_lmc so changed
--                      pl_lmc to pl_log in the log messages.
--
--                      Below is a sample header, detail and trailer record
--                      of how it is today.  Notice in the ML_DATA column
--                      the order id and order date do not match what is
--                      in the ORDER_ID and ORDER_DATE columns.
/**************************************************************************
     ----- Header -----
MESSAGE_ID                    [8525950]
MESSAGE_TYPE                  [NewShippingOrderHeader]
SOURCE_SYSTEM                 [SWM]
ORDER_ID                      [HIST20151209]
ORDER_TYPE                    [History]
ORDER_DATE                    [12/09/2015 00:00:00]
ORDER_PRIORITY                [49]
ORDER_ITEM_ID                 []
ORDER_ITEM_ID_COUNT           []
DESCRIPTION                   [Historical Order]
QUANTITY_REQUESTED            []
QUANTITY_AVAILABLE            []
PROD_ID                       []
CUST_PREF_VENDOR              []
UOM                           []
SKU_PRIORITY                  []
ML_DATA_LEN                   [147]
ML_DATA                       [NewShippingOrderHeader                            HIST20151210             Historical Order                                  49History   2015-12-10]
STATUS                        [S]
ADD_USER                      [SWMS]
ADD_DATE                      [12/09/2015 02:23:09]
UPD_USER                      [SWMS]
UPD_DATE                      [12/09/2015 02:23:59]
ML_SYSTEM                     [HK1]
============================================================
     ----- Detail -----
MESSAGE_ID                    [8525951]
MESSAGE_TYPE                  [NewShippingOrderItemByInventory]
SOURCE_SYSTEM                 [SWM]
ORDER_ID                      [HIST20151209]
ORDER_TYPE                    []
ORDER_DATE                    []
ORDER_PRIORITY                []
ORDER_ITEM_ID                 [0000000001]
ORDER_ITEM_ID_COUNT           []
DESCRIPTION                   []
QUANTITY_REQUESTED            [3]
QUANTITY_AVAILABLE            []
PROD_ID                       [0010312]
CUST_PREF_VENDOR              [-]
UOM                           [2]
SKU_PRIORITY                  [50]
ML_DATA_LEN                   [117]
ML_DATA                       [NewShippingOrderItemByInventory                   HIST20151210             000000000120010312            000000000350]
STATUS                        [S]
ADD_USER                      [SWMS]
ADD_DATE                      [12/09/2015 02:23:09]
UPD_USER                      [SWMS]
UPD_DATE                      [12/09/2015 02:23:59]
ML_SYSTEM                     [HK1]
============================================================
     ----- Trailer -----
MESSAGE_ID                    [8526605]
MESSAGE_TYPE                  [NewShippingOrderTrailer]
SOURCE_SYSTEM                 [SWM]
ORDER_ID                      [HIST20151209]
ORDER_TYPE                    []
ORDER_DATE                    []
ORDER_PRIORITY                []
ORDER_ITEM_ID                 []
ORDER_ITEM_ID_COUNT           [633]
DESCRIPTION                   []
QUANTITY_REQUESTED            []
QUANTITY_AVAILABLE            []
PROD_ID                       []
CUST_PREF_VENDOR              []
UOM                           []
SKU_PRIORITY                  []
ML_DATA_LEN                   [80]
ML_DATA                       [NewShippingOrderTrailer                           HIST20151210             00633]
STATUS                        [S]
ADD_USER                      [SWMS]
ADD_DATE                      [12/09/2015 02:23:51]
UPD_USER                      [SWMS]
UPD_DATE                      [12/09/2015 02:24:01]
ML_SYSTEM                     [HK1]
============================================================
**************************************************************************/
--
------------------------------------------------------------------------------
   l_object_name        VARCHAR2(30) := 'trg_insupd_miniload_order';

   l_embedded_date_in_order_id   DATE; -- The date embedded in the
                                       -- order id for historical orders.
   l_corrected_order_date        DATE; 
   l_original_order_date         DATE;
   l_original_order_id           miniload_order.order_id%TYPE;
BEGIN
   IF INSERTING THEN
      --
      -- ***** Special processing for Historical Orders *****
      -- Correct the order date for historical orders.  See the
      -- modification history on 10/18/13 for more details.
      --
      --
      IF (    UPPER(:NEW.order_id) LIKE 'HIST%'
          AND :NEW.message_type IN
                  (pl_miniload_processing.ct_ship_ord_hdr,
                   pl_miniload_processing.ct_ship_ord_inv,
                   pl_miniload_processing.ct_ship_ord_trl) )
      THEN

         --
         -- Processing a historical order record.
         -- The order id format is "HISTYYYYMMDD".
         --
         -- Change the order id and correct the order date if necessary.
         -- The embedded date in the order id and the order date (if the
         -- record has one) needs to be the order(pick) date.
         -- NOTE: The "NewShippingOrderHeader" record should be the only
         --       record with the order date populated.
         --
         -- Start a new block to trap the errors.  If an error is encountered
         -- then a log message is created.  An error will not stop processing
         -- since an error with the historical orders is not a show stopper.
         --
         -- The dates are TRUNCed in the comparisons as we don't care about
         -- the time.  Actually there should be no time component in the
         -- order date.
         --
         -- Start a new block to trap the errors.
         BEGIN 
            --
            -- Initialization
            --
            l_original_order_id   := :NEW.order_id;  
            l_original_order_date := :NEW.order_date;

            --
            -- Pull out the embedded date in the order id.
            --
            l_embedded_date_in_order_id :=
                    TO_DATE(SUBSTR(:NEW.order_id, 5, 8), 'YYYYMMDD');

            --
            -- The date embedded in the order id and the order
            -- date(if populated) should be the same.  If not log
            -- a message, set the order date to the embedded date
            -- in the order id and continue processing.
            --
            IF (    :NEW.order_date IS NOT NULL
                AND TRUNC(:NEW.order_date) <> TRUNC(l_embedded_date_in_order_id) )
            THEN
               pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                      'Historical order processing--changing the order date'
                   || ' to match the date embedded in the order id.'
                   || '  We have a record where the date embedded in the order id'
                   || ' does not match the order date.  They were expected to be the same.'
                   || '  The order date will be set to the date embedded in the order id.'
                   || '  order id sent to SWMS['    || :NEW.order_id || ']'
                   || '  order date sent to SWMS['  || TO_CHAR(:NEW.order_date, 'DD-MON-YYYY') || ']'
                   || '  message_type['             || :NEW.message_type || ']'
                   || '  date embedded in order id sent to SWMS[' || TO_CHAR(l_embedded_date_in_order_id, 'DD-MON-YYYY') || ']'
                   || '  sys_context module['  || SYS_CONTEXT('USERENV','MODULE') || ']',
                   NULL, NULL, 'ORDER', l_object_name);

               :NEW.order_date := TRUNC(l_embedded_date_in_order_id);
            END IF;

            --
            -- Now correct the order date if necessary.  SWMS is expecting
            -- the order date to be the pick date.
            -- The "correcting" of the order date takes in procedure
            -- "pl_planned_order.correct_order_date".
            --
            --
            -- Log a message stating the order date is being checked out.
            -- Only log the message for the order header record.
            --
            IF (:NEW.message_type = pl_miniload_processing.ct_ship_ord_hdr) THEN
               pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                      'Historical order processing--checking the order date sent from the host system.'
                   || '  SWMS and the miniloader expect the order date to be the pick date.'
                   || '  order id sent to SWMS[' || :NEW.order_id || ']'
                   || '  order date['            || TO_CHAR(:NEW.order_date, 'DD-MON-YYYY') || ']'
                   || '  message_type['          || :NEW.message_type || ']'
                   || '  sys_context module['    || SYS_CONTEXT('USERENV','MODULE') || ']'
                   || '  This log message is output only for the order header record so we do not flood SWMS with log messages.'
                   || '  FYI: SUS is putting the ship date in the order date so this needs to be corrected'
                   || ' before sending the order to the miniloader and is the main reason for this trigger.',
                   NULL, NULL, 'ORDER', l_object_name);
            END IF;

            l_corrected_order_date := pl_planned_order.correct_order_date
                      (i_order_id  => :NEW.order_id,
                       i_add_date   => SYSDATE,
                       i_order_date => l_embedded_date_in_order_id);

            --
            -- If the order date was corrected then:
            -- 1.  Change the order id embedded date to the corrected date.
            --     So this changes the order id.
            -- 2.  Change the order date.
            -- 3.  If the order is populated then set it to the corrected date.
            -- 4.  Log a message but only for the header record so we do not get
            --     flooded with messages for the detail records.
            --
            IF (TRUNC(l_embedded_date_in_order_id) <> TRUNC(l_corrected_order_date))
            THEN
               --
               -- The order date was corrected.
               -- Change the order id.
               --
               :NEW.order_id := SUBSTR(:NEW.order_id, 1, 4)
                                || TO_CHAR(l_corrected_order_date, 'YYYYMMDD');

               --
               -- Change the order date for the record that has it populated
               -- which should be only the header record.
               --
               IF (:NEW.order_date IS NOT NULL) THEN
                  :NEW.order_date := TRUNC(l_corrected_order_date);
               END IF;


               --
               -- Now change the ML_DATA order id and order date.  Note that the
               -- order date is only in the header record.  The order date format in
               -- ML_DATA is YYYY-MM-DD.
               :NEW.ml_data := REPLACE(:NEW.ml_data, l_original_order_id, :NEW.order_id);

               IF (:NEW.message_type = pl_miniload_processing.ct_ship_ord_hdr) THEN
                  :NEW.ml_data := REPLACE(:NEW.ml_data, TO_CHAR(l_original_order_date, 'YYYY-MM-DD'), TO_CHAR(:NEW.order_date, 'YYYY-MM-DD'));
               END IF;


               --
               -- Log a message stating the order id and order date was changed.
               -- Only log the message for the order header record to limit the
               -- number of log messages.
               --
               IF (:NEW.message_type = pl_miniload_processing.ct_ship_ord_hdr)
               THEN
                  pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                      'Historical order processing--order date sent to SWMS'
                   || ' was not the pick date.  It was corrected to the pick date.'
                   || '  This involved changing the order id and the order date in the order header record'
                   || ' and the order id in the detail(s) and the trailer record in the MINILOAD_ORDER table.'
                   || '  It is expected the order will be sent to SWMS only on the date it is to be picked.'
                   || '  new order id['         || :NEW.order_id            || ']'
                   || '  new order date['       || TO_CHAR(:NEW.order_date, 'DD-MON-YYYY') || ']'
                   || '  message_type['         || :NEW.message_type        || ']'
                   || '  original order id['    || l_original_order_id ||  ']'
                   || '  original order date['  || TO_CHAR(l_original_order_date, 'DD-MON-YYYY') || ']'
                   || '  sys_context module['   || SYS_CONTEXT('USERENV','MODULE') || ']'
                   || '  This log message is output only for the order header record so we do not flood SWMS with log messages.'
                   || '  NOTE:  This order will also be in PLANNED_ORDER_HDR and PLANNED_ORDER_DTL with the original order id and date.'
                   || '  The program that creates non-demand replenishments based on historical orders looks'
                   || ' at the historical order add date and not the order date.',
                   NULL, NULL, 'ORDER', l_object_name);
               END IF;
            ELSE
               --
               -- The order date OK.  Log a message if processing the header record.
               --
               IF (:NEW.message_type = pl_miniload_processing.ct_ship_ord_hdr) THEN
                  pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                      'Historical order processing--order date sent to SWMS was correct.'
                   || '  order id['       || :NEW.order_id            || ']'
                   || '  order date['     || TO_CHAR(:NEW.order_date, 'DD-MON-YYYY') || ']'
                   || '  message_type['   || :NEW.message_type        || ']'
                   || '  original order id['    || l_original_order_id ||  ']'
                   || '  original order date['  || TO_CHAR(l_original_order_date, 'DD-MON-YYYY') || ']'
                   || '  sys_context module['     || SYS_CONTEXT('USERENV','MODULE') || ']'
                   || '  This log message is output only for the order header record so we do not flood SWMS with log messages.',
                   NULL, NULL, 'ORDER', l_object_name);
               END IF;
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               --
               -- Encountered an error.  Log a message but do not stop
               -- processing.
               --
               pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                      'Error in trigger.'
                   || '  This will not stop processing.'
                   || '  order_id['       || :NEW.order_id || ']'
                   || '  order_date['     || TO_CHAR(:NEW.order_date, 'DD-MON-YYYY') || ']'
                   || '  message_type['   || :NEW.message_type || ']'
                   || '  sys_context module[' || SYS_CONTEXT('USERENV','MODULE') || ']',
                   SQLCODE, SQLERRM, 'ORDER', l_object_name);

         END; --  end block historical processing
      END IF; -- end if historical order 
   END IF;  -- end if INSERTING

   IF UPDATING THEN
      :new.upd_user := REPLACE(USER, 'OPS$');
      :new.upd_date := SYSDATE;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
             'OLD order_id['   || :OLD.order_id || ']'
          || '  NEW order_id['   || :NEW.order_id || ']'
          || '  OLD message_type[' || :OLD.message_type || ']'
          || '  NEW message_type[' || :NEW.message_type || ']'
          || '  sys_context module[' || SYS_CONTEXT('USERENV','MODULE') || ']'
          || '  Error in trigger.',
          SQLCODE, SQLERRM, 'ORDER', l_object_name);

      RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);

END trg_insupd_miniload_order;
/


