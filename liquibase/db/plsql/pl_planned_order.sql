CREATE OR REPLACE  PACKAGE swms.pl_planned_order  AS
-- sccs_id=@(#) src/schema/plsql/pl_planned_order.sql, swms, swms.9, 11.2 2/2/10 1.3
-----------------------------------------------------------------------------
-- Package Name:
--   pl_planned_order
--
-- Description:
--    Store Planned Order Information.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    10/21/08 prswp000 Created.
--
--    01/29/09 prpbcb   DN: 12512
--                      Project:
--                CRQ8828-Miniload Functionality in Warehouse Move Process
--
--                      Added procedures to send the planned orders to the
--                      miniloader for an item.  They were added to
--                      pl_wh_move first because they are needed
--                      for the Houston warehouse move and it is easier to
--                      install pl_wh_move at Houston.  Now I am
--                      adding them here.  The names were changed somewhat.
--                      The procedures are:
--                         - ml_send_plan_orders_for_item
--                         - ml_send_plan_orders
--                     Once the procedures are in pl_planned_order.sql
--                     we can remove them from pl_wh_move.sql but we will
--                     need to change trigger trig_whmove_insupd_pm_brow.sql
--                     to call pl_planned_order.ml_send_plan_orders_for_item
--                     instead of
--                     pl_wh_move.send_planned_orders_for_item.
--
--                     When sending the planned orders for an item a
--                     fictitious case order line is created and sent to
--                     the miniloader for the following condition:
--                        - planned order uom is 1
--                        - planned order qty is > spc
--                        - pm.auto_ship_flag is N  (ship split only)
--                        - pm.miniload_storage_ind is B
--                     This is because swms will case up the order qty so
--                     we need the miniloader to drop a case or cases.
--                     To make the order item id unique a '1' is appended
--                     to the order item id.
--
--    11/09/12 prpbcb  Project: CRQ39831-Case_order_sent_to_miniloader
--                     Activity: CRQ39831-Case_order_sent_to_miniloader
--
--                     Changed procedure "ml_send_plan_orders" to NOT send
--                     case orders to the miniloader when splits
--                     are in the miniloader and cases are stored in the
--                     main warehouse.  The miniloader is rejecting the
--                     entire order since the case order item number is not
--                     valid in the miniloader.
--
--    10/18/13 prpbcb   Project: TFS
--  R12.6--WIB#230--CRQ-47092_Miniloader_processing_the_historical_orders_a_day_later
--
--                      --- Change for Historical Orders ---
--                      
--                      Created function correct_order_date().
--
--                      DB triggers on tables PLANNED_ORDER_HDR and
--                      MINILOAD_ORDER call function correct_order_date()
--                      to correct the order date.
--
--                      See the modification history for correct_order_date()
--                      for additional information.
--
--                      We are having issues with the order date sent by SUS
--                      in the ML queue which is affecting the processing of
--                      historical orders.
--                      The order date we are getting from SUS is
--                      actually the ship date.  For historical orders the
--                      miniloader looks at the order date to know when to
--                      process the historical orders orders so they get
--                      processed a day late.  So that we
--                      do not have to change SUS this trigger will
--                      set the order date to the current date as shown below.
--                      SAP and IDS send the correct order date except for
--                      Saturday on IDS.  IDS send Sundays orders on
--                      Saturday so we need to change Saturday to Sunday.
--
--                      Date order sent     Order date    Change order
--                      in ML queue order   ML record     date to
--                      ----------------------------------------------
--                      Monday              Tuesday       Monday
--                      Tuesday             Wednesday     Tuesday
--                      Wednesday           Thursday      Wednesday
--                      Thursday            Friday        Thursday
--                      Friday              Saturday      Friday
--                      Friday              Monday        Sunday
--                      Saturday            Monday        Sunday
--                      Saturday            Saturday      Sunday
--
--                      Friday is a special case because some OpCos do
--                      not ship Friday night.
--                      For Saturday IDS is sending Sundays orders.
--                      SWMS gets nothing on Sunday.
--
--                      NOTE: For regular orders SUS is also sending the
--                            ship date instead fo the order date but this
--                            does not cause any problems because SWMS and
--                            the miniloader do not look at the order date
--                            for regular orders.  SWMS and the miniloader
--                            expect regular orders that come down in the
--                            ML queue are to be picked that day.
--
-----------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Public Constants
   ---------------------------------------------------------------------------
   CT_PROGRAM_CODE         CONSTANT VARCHAR2 (50) := 'FUTORD';
   CT_PRE_LABEL            CONSTANT VARCHAR2 (3)  := '';

   --
   -- Status.
   --
   CT_SUCCESS              CONSTANT NUMBER (1)    := 0;
   CT_FAILURE              CONSTANT NUMBER (1)    := 1;
   CT_ER_DUPLICATE         CONSTANT NUMBER (1)    := 2;
   CT_IN_PROGRESS          CONSTANT NUMBER (1)    := 3;
   CT_NO_DATA_FOUND        CONSTANT NUMBER        := 1403;

   --
   -- Field lengths.
   --
   CT_COUNT_SIZE           CONSTANT NUMBER        := 5;
   CT_DATE_SIZE            CONSTANT NUMBER        := 10;
   CT_DESCRIPTION_SIZE     CONSTANT NUMBER        := 50;
   CT_LABEL_SIZE           CONSTANT NUMBER        := 18;
   CT_LOCATION_SIZE        CONSTANT NUMBER        := 10;
   CT_MSG_TYPE_SIZE        CONSTANT NUMBER        := 50;
   CT_ORDER_ID_SIZE        CONSTANT NUMBER        := 25;
   CT_ORDER_ITEM_ID_SIZE   CONSTANT NUMBER        := 10;
   CT_ORDER_TYPE_SIZE      CONSTANT NUMBER        := 10;
   CT_PRIORITY_SIZE        CONSTANT NUMBER        := 2;
   CT_QTY_SIZE             CONSTANT NUMBER        := 10;
   CT_RECEIPT_ID_SIZE      CONSTANT NUMBER        := 18;
   CT_REASON_SIZE          CONSTANT NUMBER        := 50;
   CT_SKU_SIZE             CONSTANT NUMBER        := 20;
   CT_USER_SIZE            CONSTANT NUMBER        := 10;
   -- ctvgg000 For HK Integration
   -- carrier status size and message status size
   CT_CARRIER_STATUS_SIZE  CONSTANT NUMBER		  := 3;
   CT_MESSAGE_STATUS_SIZE  CONSTANT NUMBER		  := 1;
   CT_MESSAGE_TEXT_SIZE	   CONSTANT NUMBER		  := 200;
   CT_MSG_ID_SIZE		   CONSTANT NUMBER		  := 7;

   --
   -- Message types.
   --
   CT_STORE_ORDER      CONSTANT VARCHAR2 (10) := 'Store';
   CT_HISTORY_ORDER    CONSTANT VARCHAR2 (10) := 'History';

   --------------------------------------------------------------------------
   -- Public Type Declarations
   --------------------------------------------------------------------------

   TYPE t_planned_ord_hdr_info IS RECORD (
      v_order_id              PLANNED_ORDER_HDR.order_id%TYPE,
      v_description           PLANNED_ORDER_HDR.description%TYPE,
      n_order_priority        PLANNED_ORDER_HDR.order_priority%TYPE,
      v_order_type            PLANNED_ORDER_HDR.ORDER_TYPE%TYPE,
      v_order_date            PLANNED_ORDER_HDR.order_date%TYPE
   );

   TYPE t_planned_ord_dtl_info IS RECORD (
      v_order_id              PLANNED_ORDER_DTL.order_id%TYPE,
      v_order_item_id         PLANNED_ORDER_DTL.order_item_id%TYPE,
      n_uom                   PLANNED_ORDER_DTL.UOM%TYPE,
      v_prod_id               PLANNED_ORDER_DTL.prod_id%TYPE,
      v_cust_pref_vendor      PLANNED_ORDER_DTL.cust_pref_vendor%TYPE,
      n_qty                   PLANNED_ORDER_DTL.qty%TYPE,
      n_sku_priority          PLANNED_ORDER_DTL.sku_priority%TYPE
   );

   TYPE t_planned_ord_tlr_info IS RECORD (
      v_order_id              PLANNED_ORDER_HDR.order_id%TYPE,
      n_order_item_id_count   NUMBER
   );

   --
   -- Item info record.
   -- This record is used when sending planned orders to the miniloader
   -- for a specific item.  The calling object populates it then passes
   -- it as a parameter.  Sending planned orders needs info about the item.
   -- Because it can be started from the database trigger on the
   -- PM table we needed a way to pass the required item info to the procedure
   -- because selecting from the PM table in this package would result in the
   -- mutating table message.
   --
   TYPE t_r_item_info_planned_order IS RECORD
   (
      prod_id                pm.prod_id%TYPE,
      cust_pref_vendor       pm.cust_pref_vendor%TYPE,
      spc                    pm.spc%TYPE,
      auto_ship_flag         pm.auto_ship_flag%TYPE,
      miniload_storage_ind   pm.miniload_storage_ind%TYPE
   );



   PROCEDURE p_store_header (
      i_planned_ord_hdr_info   IN       t_planned_ord_hdr_info DEFAULT NULL,
      o_status                 OUT      NUMBER
   );

   PROCEDURE p_store_detail (
      i_planned_ord_dtl_info   IN       t_planned_ord_dtl_info DEFAULT NULL,
      o_status                 OUT      NUMBER
   );

   PROCEDURE p_verify_order (
      i_planned_ord_tlr_info   IN       t_planned_ord_tlr_info DEFAULT NULL,
      o_status                 OUT      NUMBER
   );

   ---------------------------------------------------------------------------
   -- Procedure:
   --    ml_send_plan_orders_for_item
   --
   -- Description:
   --
   --    This procedure sends the planned orders to the miniloaders for a
   --    specified item for a specified date.
   ---------------------------------------------------------------------------
   PROCEDURE ml_send_plan_orders_for_item
            (i_r_item_info_planned_order  IN t_r_item_info_planned_order,
             i_order_date                 IN DATE,
             o_status                     IN OUT PLS_INTEGER);

---------------------------------------------------------------------------
-- Function:
--    correct_order_date
--
-- Description:
--    This function corrects the order date sent from SUS in ithe ML queue.
--    It was created because SUS is sending the ship date down in the
--    ML queue and not the order date.  This affects processing of the
--    historical orders.
---------------------------------------------------------------------------
FUNCTION correct_order_date(i_order_id    planned_order_hdr.order_id%TYPE,
                            i_add_date    IN DATE,
                            i_order_date  IN DATE)
RETURN DATE;


END pl_planned_order;
/

show errors


CREATE OR REPLACE  PACKAGE BODY swms.pl_planned_order  AS
-- sccs_id=@(#) src/schema/plsql/pl_planned_order.sql, swms, swms.9, 11.2 2/2/10 1.3
---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
   gl_pkg_name           VARCHAR2 (30) := 'pl_planned_order';
                                                   -- Package name.
                                                   --  Used in error messages.
   gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                    -- function is null.


---------------------------------------------------------------------------
-- Private Constants
---------------------------------------------------------------------------

   -- Application function to use for the log messages.
   ct_application_function   CONSTANT VARCHAR2 (9)  := 'FUT_ORD';


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------

   --
   -- Sending planned order to miniload record.
   --
   -- The structure matches that of cursor c_planned_order.  If the fields
   -- selected in the cursor changes then this record structure need to be
   -- change to match the cursor.
   --
   TYPE t_r_ml_planned_order IS RECORD
   (
      order_id           planned_order_hdr.order_id%TYPE,
      description        planned_order_hdr.description%TYPE,
      order_priority     planned_order_hdr.order_priority%TYPE,
      order_type         planned_order_hdr.order_type%TYPE,
      order_date         planned_order_hdr.order_date%TYPE,
      order_item_id      planned_order_dtl.order_item_id%TYPE,
      uom                planned_order_dtl.uom%TYPE,
      prod_id            planned_order_dtl.prod_id%TYPE,
      cust_pref_vendor   planned_order_dtl.cust_pref_vendor%TYPE,
      qty                planned_order_dtl.qty%TYPE,
      sku_priority       planned_order_dtl.sku_priority%TYPE,
      spc                pm.spc%TYPE,
      auto_ship_flag     pm.auto_ship_flag%TYPE
   );



---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    ml_send_plan_orders
--
-- Description:
--
--    This procedure sends the planned orders to the miniloader for the
--    specified criteria.  The planned orders are in tables
--    PLANNED_ORDER_HDR and PLANNED_ORDER_DTL.
--
--    The planned orders can be sent for:
--       - An item for a specified date
--       - An item.
--       - An order.
--       - All orders for a specified date.
--     ***************
--     READ ME  ====>   Not all options are implemented yet.  The only thing
--                      that will work correctly is sending planned orders
--                      for an item passing the info about the item
--                      in i_r_item_info_planned_order.
--     ***************
--
--    **************************************************************
--    This procedure is local to this package and is intended to be
--    called by public procedures that sent i_send_for_what to the
--    appropriate value and sent the other parameters to the
--    appropriate values.
--    **************************************************************
--
--    **************************************************************
--    README     README     README     README
--    This procedure can end up being called from the database trigger
--    on the PM table and when it is i_r_item_info_planned_order needs
--    to be populated as we cannot select from the PM table without
--    getting the mutating table message.
--    **************************************************************
--
--    If a procedure call returns a failure status then a log message is
--    written and processing will stop.  The failure status will be
--    returned in o_status.  It will be possible for partial orders to
--    be sent to the miniloader depending when the failure occurs.  This
--    will not cause any problems as the miniloader will reject the order
--    since it will not be complete.
--
-- Parameters:
--    i_send_for_what     - What to send.
--                          The value values are:
--                             'ITEM_AND_DATE'
--                             'ITEM'
--                             'ORDER'
--                             'DATE'
--
--    i_r_item_info_planned_order - Info about the item.  Needs to be populated
--                                  when sending planned orders for a specific
--                                  item.
--
--    i_order_id          - The order to send.
--    i_order_date        - Send orders with this date.
--    o_status            - If 0 then no error occurred otherwise
--                          an error occured.
--
-- Called by:
--    - send_orders_for_item
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/29/10 prpbcb   Created.
--                      It is intended to be called when an item is slotted
--                      to the miniloader to send the orders that came down
--                      in the ML queue before the item was slotted.
--     ***************
--     READ ME  ====>   Not all options are implemented yet.  The only thing
--                      that will work correctly is sending planned orders
--                      for an item passing the info about the item
--                      in i_r_item_info_planned_order.
--     ***************
--
--    11/09/12 prpbcb  Project: CRQ39831-Case_order_sent_to_miniloader
--                     Activity: CRQ39831-Case_order_sent_to_miniloader
--
--                     Changed procedure to NOT send
--                     case orders to the miniloader when splits
--                     are in the miniloader and cases are stored in the
--                     main warehouse.  The miniloader is rejecting the
--                     entire order since the case order item number is not
--                     valid in the miniloader.  Did this by checking
--                     the miniload storage indicator which is a field in
--                     record i_r_item_info_planned_order.
--
---------------------------------------------------------------------------
PROCEDURE ml_send_plan_orders
            (i_send_for_what              IN  VARCHAR2,
             i_r_item_info_planned_order  IN  t_r_item_info_planned_order,
             i_order_id                   IN  planned_order_hdr.order_id%TYPE,
             i_order_date                 IN  DATE,
             o_status                     OUT NUMBER)
IS
   l_message             VARCHAR2(512);  -- Message buffer.
   l_object_name         VARCHAR2(30);   -- Procedure name.  Used in messages.

   l_first_record_bln    BOOLEAN;  -- To know when processing the 1st record.
   l_last_order_id       planned_order_hdr.order_id%TYPE; -- Last order
                            -- processed.  Needed to create the trailer record
                            -- for the last order processed.

   l_order_record_count  PLS_INTEGER;  -- Order detail record count.  This
                                       -- goes in the Order trailer record.

   l_previous_order_id   planned_order_hdr.order_id%TYPE;  -- To know when
                                        -- we switch orders.

   l_r_item_info_planned_order  t_r_item_info_planned_order;  -- Record
                                   -- to hold info about the item.

   -- Miniload order header record.
   l_r_ord_hdr_info  pl_miniload_processing.t_new_ship_ord_hdr_info := NULL;

   -- Miniload order detail record.
   l_r_ord_dtl_info  pl_miniload_processing.t_new_ship_ord_item_inv_info :=NULL;

   -- Miniload order trailer record.
   l_r_ord_tr_info   pl_miniload_processing.t_new_ship_ord_trail_info := NULL;

   e_bad_parameter        EXCEPTION;  -- Invalid parameter.
   e_processing_error     EXCEPTION;  -- A pl_miniload_processing procedure
                                      -- returned a failure status.

   --
   -- This cursor selects the planned orders to send to the miniloader.
   -- Historical orders will not be sent.
   -- The planned orders can be sent for:
   --    - An item for a specified date
   --    - An item.
   --    - An order.
   --    - All orders for a specified date.
   --
   -- Brian Bent  The where clause uses BETWEEN for the order date to use
   -- the index on the order date, if it exists.   We also will not have to
   -- worry about the order date being stored with or without the time
   -- component.
   --
   CURSOR c_planned_order
       (cp_send_for_what              VARCHAR2,
        cp_r_item_info_planned_order  t_r_item_info_planned_order,
        cp_order_id                   VARCHAR2,
        cp_order_date                 DATE) IS
      SELECT h.order_id                                   order_id,
             h.description                                description,
             h.order_priority                             order_priority,
             h.order_type                                 order_type,
             TRUNC(h.order_date)                          order_date,
             d.order_item_id                              order_item_id,
             d.uom                                        uom,
             d.prod_id                                    prod_id,
             d.cust_pref_vendor                           cust_pref_vendor,
             d.qty                                        qty,
             NVL(d.sku_priority, 0)                       sku_priority,
             cp_r_item_info_planned_order.spc             spc,
             cp_r_item_info_planned_order.auto_ship_flag  auto_ship_flag
        FROM planned_order_dtl d,
             planned_order_hdr h
       WHERE d.order_id          = h.order_id
         AND h.order_id NOT LIKE 'HIST%'   -- Leave out historical orders
         AND (
                  --
                  -- Send planned orders for a specified item on a specifed
                  -- date.
                  --
                 (    cp_send_for_what   = 'ITEM_AND_DATE'
                  AND (   (i_r_item_info_planned_order.miniload_storage_ind = 'S' AND d.uom = 1)
                       OR 
                          i_r_item_info_planned_order.miniload_storage_ind = 'B')
                  AND d.prod_id          = i_r_item_info_planned_order.prod_id
                  AND d.cust_pref_vendor =
                            i_r_item_info_planned_order.cust_pref_vendor
                  AND h.order_date       BETWEEN TRUNC(cp_order_date)
                                         AND (TRUNC(cp_order_date) + 1) -
                                                     (1 / (24 * 60 * 60)))
                  --
                  -- Send planned orders for a specified item.
                  --
              OR (    cp_send_for_what   = 'ITEM'
                  AND (   (i_r_item_info_planned_order.miniload_storage_ind = 'S' AND d.uom = 1)
                       OR 
                          i_r_item_info_planned_order.miniload_storage_ind = 'B')
                  AND d.prod_id          = i_r_item_info_planned_order.prod_id
                  AND d.cust_pref_vendor =
                                 i_r_item_info_planned_order.cust_pref_vendor)
                  --
                  -- Send planned order for a specified order.
                  --
              OR (    cp_send_for_what = 'ORDER'
                  AND h.order_id       LIKE cp_order_id)
                  --
                  -- Send planned orders for a specified date.
                  --
              OR (    cp_send_for_what = 'DATE'
                  AND h.order_date     BETWEEN TRUNC(cp_order_date)
                                       AND (TRUNC(cp_order_date) + 1) -
                                                     (1 / (24 * 60 * 60)))
             )
         ORDER BY h.order_id, d.order_item_id;  -- The ordering is important
BEGIN
   --
   -- Check for invalid or null parameters.
   --
   IF (i_send_for_what = 'ITEM_AND_DATE') THEN
      --
      -- Sending planned orders for an item for a specified date.
      -- prod_id, cust_pref_vendor and i_order_date all need to
      -- have a value.
      --
      IF (i_r_item_info_planned_order.prod_id          IS NULL OR
          i_r_item_info_planned_order.cust_pref_vendor IS NULL OR
          i_order_date       IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;
   ELSIF (i_send_for_what = 'ITEM') THEN
      --
      -- Sending planned orders for an item for a specified date.
      -- prod_id, cust_pref_vendor and i_order_date all need to
      -- have a value.
      --
      IF (i_r_item_info_planned_order.prod_id          IS NULL OR
          i_r_item_info_planned_order.cust_pref_vendor IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;
   ELSIF (i_send_for_what = 'ORDER') THEN
      --
      -- Sending planned orders for an order.
      -- i_order_id needs to have a value.
      --
      IF (i_order_id IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;
   ELSIF (i_send_for_what = 'DATE') THEN
      --
      -- Sending planned orders for a date.
      -- i_order_date needs to have a value.
      --
      IF (i_order_date IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;
   ELSE
      --
      -- i_send_for_what has an unhandled value.
      --
      RAISE e_bad_parameter;
   END IF;

   --
   -- Put the parameter record into a local record.
   --
   l_r_item_info_planned_order := i_r_item_info_planned_order;

   --
   -- Send the planned order(s) to the miniloader.
   --

   o_status := pl_miniload_processing.ct_success;
   l_first_record_bln := TRUE;

   FOR r_planned_order IN c_planned_order
                                (i_send_for_what,
                                 l_r_item_info_planned_order,
                                 i_order_id,
                                 i_order_date)
   LOOP
      --
      -- Debug stuff
      -- DBMS_OUTPUT.PUT_LINE('Order ID: '
      --    || RPAD(r_planned_order.order_id, 14)
      --    || '  Order Item ID: ' || RPAD(r_planned_order.order_item_id,  10)
      --    || '  Prod ID: ' || r_planned_order.prod_id
      --    || '  Order Date: '
      --    || TO_CHAR(r_planned_order.order_date, 'MM/DD/YYYY'));
      --

      l_last_order_id := r_planned_order.order_id;

      IF (l_first_record_bln = TRUE) THEN
         --
         -- First record processed.  Perform initialization.
         --
         l_previous_order_id  := r_planned_order.order_id;
         l_order_record_count := 1;
         l_first_record_bln   := FALSE;
      ELSIF (l_previous_order_id <> r_planned_order.order_id) THEN
         --
         -- Order changed.  Send the order trailer for the previous order.
         --
         l_r_ord_tr_info.v_msg_type  := pl_miniload_processing.ct_ship_ord_trl;
         l_r_ord_tr_info.v_order_id            := l_previous_order_id;
         l_r_ord_tr_info.n_order_item_id_count := l_order_record_count;

         pl_miniload_processing.p_send_new_ship_ord_trail(l_r_ord_tr_info,
                                                          o_status);

         IF (o_status <> pl_miniload_processing.ct_success) THEN
            RAISE e_processing_error;
         END IF;

         --
         -- Initialization for current order.
         --
         l_order_record_count := 1;
         l_previous_order_id  := r_planned_order.order_id;
      ELSE
         --
         -- Record being processed is for the same order as the
         -- previous record.
         --
         l_order_record_count := l_order_record_count + 1;
      END IF;

      --
      -- Send the order header if processing the first record for the order.
      --
      IF (l_order_record_count = 1) THEN
         l_r_ord_hdr_info.v_msg_type := pl_miniload_processing.ct_ship_ord_hdr;
         l_r_ord_hdr_info.v_order_id       := r_planned_order.order_id;
         l_r_ord_hdr_info.v_description    := r_planned_order.description;
         l_r_ord_hdr_info.n_order_priority := r_planned_order.order_priority;
         l_r_ord_hdr_info.v_order_type     := r_planned_order.order_type;
         l_r_ord_hdr_info.v_order_date     := TRUNC(r_planned_order.order_date);
 
         pl_miniload_processing.p_send_new_ship_ord_hdr
                                    (l_r_ord_hdr_info, o_status);

         IF (o_status <> pl_miniload_processing.ct_success) THEN
            RAISE e_processing_error;
         END IF;
      END IF;

      --
      -- Send the order detail.
      --
      l_r_ord_dtl_info.v_msg_type := pl_miniload_processing.ct_ship_ord_inv;
      l_r_ord_dtl_info.v_order_id         := r_planned_order.order_id;
      l_r_ord_dtl_info.v_order_item_id    := r_planned_order.order_item_id;
      l_r_ord_dtl_info.n_uom              := r_planned_order.uom;
      l_r_ord_dtl_info.v_prod_id          := r_planned_order.prod_id;
      l_r_ord_dtl_info.v_cust_pref_vendor := r_planned_order.cust_pref_vendor;
      l_r_ord_dtl_info.n_qty              := r_planned_order.qty;
      l_r_ord_dtl_info.n_sku_priority     := r_planned_order.sku_priority;

      pl_miniload_processing.p_send_new_ship_ord_item_inv(l_r_ord_dtl_info,
                                                          o_status);

      IF (o_status <> pl_miniload_processing.ct_success) THEN
         RAISE e_processing_error;
      END IF;

      --
      -- Send a fictitious case order line to the miniloader for the
      -- following condition:
      --   - planned order uom is 1
      --   - planned order qty is > spc
      --   - pm.auto_ship_flag is N 
      --   - pm.miniload_storage_ind is B
      -- This is because swms will case up the order qty.
      -- To make the order item id unique a '1' is appended
      -- to the order item id.
      --
/*
      IF (r_planned_order.uom = 1
          AND r_planned_order.qty /
          || '  prod_id[' || l_r_item_info_planned_order.prod_id || ']'
*/
      

   END LOOP;

   IF (l_order_record_count >= 1) THEN
      --
      -- Send the order trailer for the last order.
      --
      l_r_ord_tr_info.v_msg_type := pl_miniload_processing.ct_ship_ord_trl;
      l_r_ord_tr_info.v_order_id            := l_last_order_id;
      l_r_ord_tr_info.n_order_item_id_count := l_order_record_count;
             
      pl_miniload_processing.p_send_new_ship_ord_trail(l_r_ord_tr_info,
                                                       o_status);

      IF (o_status <> pl_miniload_processing.ct_success) THEN
         RAISE e_processing_error;
      END IF;
   END IF;
EXCEPTION
   WHEN e_processing_error THEN
      --
      -- A pl_miniload_processing procedure returned a failure status.
      --
      o_status := pl_miniload_processing.ct_failure;
   WHEN gl_e_parameter_null THEN
      l_object_name := 'ml_send_plan_orders';

      l_message := 'A required parameter is null.'
          || '  i_send_for_what[' || i_send_for_what || ']'
          || '  prod_id[' || i_r_item_info_planned_order.prod_id || ']'
          || '  CPV[' || i_r_item_info_planned_order.cust_pref_vendor || ']'
          || '  i_order_id[' || i_order_id || ']'
          || '  i_order_date[' || TO_DATE(i_order_date, 'MM/DD/YYYY') || ']';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);
      
      o_status := pl_miniload_processing.ct_failure;
   WHEN e_bad_parameter THEN
      l_object_name := 'ml_send_plan_orders';

      l_message :=  'i_send_for_what'
            || '[' || i_send_for_what || ']'
            || ' has an unhandled value.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);

      o_status := pl_miniload_processing.ct_failure;
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_message :=
          'i_send_for_what[' || i_send_for_what || ']'
          || '  prod_id[' || i_r_item_info_planned_order.prod_id || ']'
          || '  CPV[' || i_r_item_info_planned_order.cust_pref_vendor || ']'
          || '  i_order_id[' || i_order_id || ']'
          || '  i_order_date[' || TO_DATE(i_order_date, 'MM/DD/YYYY') || ']';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      o_status := pl_miniload_processing.ct_failure;
END ml_send_plan_orders;


-------------------------------------------------------------------------
-- Procedure:
--    p_store_header
--
-- Description:
--     The procedure to send 'New Shipping Order Header' message
--
-- Parameters:
--    i_planned_ord_hdr_info  - record holding 'new ship order header msg'
--    o_status - return value
--          0  - No errors.
--          1  - Error occured.
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/30/05          Created as part of the Mini-load changes
---------------------------------------------------------------------------
   PROCEDURE p_store_header (
      i_planned_ord_hdr_info    IN       t_planned_ord_hdr_info DEFAULT NULL,
      o_status                  OUT      NUMBER
   )
   IS
      lv_msg_text       VARCHAR2 (512);
      lv_fname          VARCHAR2 (50)   := 'P_STORE_HEADER';
      ln_status         NUMBER (1)      := ct_success;
      e_fail            EXCEPTION;
   BEGIN
      pl_text_log.init ('pl_planned_order.p_store_header');
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Order Id: '
         || i_planned_ord_hdr_info.v_order_id;
      pl_text_log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);

      IF (i_planned_ord_hdr_info.v_order_type NOT IN (ct_store_order, ct_history_order)) THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Invalid Order Type'
            || i_planned_ord_hdr_info.v_order_type
            || ' Order Type needs to be either Store or History';
         RAISE e_fail;
      END IF;

      DELETE FROM PLANNED_ORDER_DTL
       WHERE ORDER_ID = i_planned_ord_hdr_info.v_order_id;

      DELETE FROM PLANNED_ORDER_HDR
       WHERE ORDER_ID = i_planned_ord_hdr_info.v_order_id;

      INSERT INTO PLANNED_ORDER_HDR (ORDER_ID, DESCRIPTION, ORDER_PRIORITY,
                                     ORDER_TYPE, ORDER_DATE)
      VALUES (i_planned_ord_hdr_info.v_order_id, i_planned_ord_hdr_info.v_description,
              i_planned_ord_hdr_info.n_order_priority, i_planned_ord_hdr_info.v_order_type,
              i_planned_ord_hdr_info.v_order_date);

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_store_header';
         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_store_header;

-------------------------------------------------------------------------
-- Procedure:
--    p_store_detail
--
-- Description:
--     The procedure to send 'New Shipping Order Item By Inventory' message
--
-- Parameters:
--    i_new_ship_ord_hdr_info  - record holding New Shipping Order Item
--                                     By Inventory' message
--    i_msg_type - Type of message
--    o_status - output status
--          0  - No errors.
--          1  - Error occured.
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/30/05          Created as part of the mini-load changes
--    04/18/06 prphqb   Add i_uom_conv_opt as uom conversion flag
--                      Apcom calls is not changed so 'N' is default
--                      Calls from within here should come with 'Y' as param
---------------------------------------------------------------------------
   PROCEDURE p_store_detail (
      i_planned_ord_dtl_info   IN       t_planned_ord_dtl_info DEFAULT NULL,
      o_status                 OUT      NUMBER
   )
   IS
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)   := 'P_STORE_DETAIL';
      ln_status         NUMBER (1)      := ct_success;
      e_fail            EXCEPTION;
--Hold return status of functions
   BEGIN
      pl_text_log.init ('pl_planned_order.p_store_detail');
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Order Id: '
         || i_planned_ord_dtl_info.v_order_id;
      pl_text_log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);

      DELETE FROM PLANNED_ORDER_DTL
       WHERE ORDER_ID = i_planned_ord_dtl_info.v_order_id
         AND ORDER_ITEM_ID = i_planned_ord_dtl_info.v_order_item_id;

      INSERT INTO PLANNED_ORDER_DTL (ORDER_ID, ORDER_ITEM_ID, UOM, PROD_ID,
                                     CUST_PREF_VENDOR, QTY, SKU_PRIORITY)
      VALUES (i_planned_ord_dtl_info.v_order_id, i_planned_ord_dtl_info.v_order_item_id,
              i_planned_ord_dtl_info.n_uom, i_planned_ord_dtl_info.v_prod_id,
              i_planned_ord_dtl_info.v_cust_pref_vendor, i_planned_ord_dtl_info.n_qty,
              i_planned_ord_dtl_info.n_sku_priority);

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_store_header';
         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_store_detail;

-------------------------------------------------------------------------
-- Proedure:
--    p_verify_order
--
-- Description:
--     The procedure to send 'New Shipping Order Trailer' message
--
-- Parameters:
--    i_new_ship_ord_trail_info  - record holding '
--                                 NewShippingOrderTrailer mesg
--    i_msg_type - Type of message
--   o_status - return status
--          0  - No errors.
--          1  - Error occured
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/30/05          Created as part of the mini-load changes
---------------------------------------------------------------------------
   PROCEDURE p_verify_order (
      i_planned_ord_tlr_info   IN       t_planned_ord_tlr_info DEFAULT NULL,
      o_status                 OUT      NUMBER
   )
   IS
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)   := 'P_VERIFY_ORDER';
      ln_status         NUMBER (1)      := ct_success;
      ln_rowcnt         NUMBER;
      e_fail            EXCEPTION;
--Hold return status of functions
   BEGIN
      pl_text_log.init ('pl_planned_order.p_verify_order');
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Order Id: '
         || i_planned_ord_tlr_info.v_order_id;
      pl_text_log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);

      SELECT COUNT(*)
        INTO ln_rowcnt
        FROM PLANNED_ORDER_DTL
       WHERE ORDER_ID = i_planned_ord_tlr_info.v_order_id;

      IF ln_rowcnt = i_planned_ord_tlr_info.n_order_item_id_count THEN
      	lv_msg_text := 'Order ID ' || i_planned_ord_tlr_info.v_order_id ||
      	               ': Actual item count (' || TO_CHAR(ln_rowcnt) ||
      	               ') does not match expected item count (' ||
      	               TO_CHAR(i_planned_ord_tlr_info.n_order_item_id_count) ||
      	               ').';
      	pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_verify_order';
         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_verify_order;


---------------------------------------------------------------------------
-- Procedure:
--    ml_send_plan_orders_for_item
--
-- Description:
--
--    This procedure sends the planned orders to the miniloaders for a
--    specified item for a specified date.
--
-- Parameters:
--    i_r_item_info_planned_order - Info about the items
--    i_order_date        - Send orders for this date.
--    o_status            - Status of call to procedure ml_send_plan_orders().
--
-- Called by:
--      Database trigger on WHMOVE.PM table.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/29/10 prpbcb   Created.
--                      It is intended to be called when an item is slotted
--                      to the miniloader.
---------------------------------------------------------------------------
PROCEDURE ml_send_plan_orders_for_item
            (i_r_item_info_planned_order  IN t_r_item_info_planned_order,
             i_order_date                 IN DATE,
             o_status                     IN OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(512);  -- Message buffer.
   l_object_name   VARCHAR2(30) :='ml_send_plan_orders_for_item'; -- Procedure
                                             -- name.  Used in messages.
BEGIN
   --
   -- ml_send_plan_orders will validate the parameters so it is not done
   -- here.
   --
   pl_planned_order.ml_send_plan_orders
            (i_send_for_what              => 'ITEM_AND_DATE',
             i_r_item_info_planned_order  => i_r_item_info_planned_order,
             i_order_id                   => NULL,
             i_order_date                 => i_order_date,
             o_status                     => o_status);

   --
   -- If ml_send_plan_orders had an error then write a log message.
   --
   IF (o_status <> pl_miniload_processing.ct_success) THEN
      l_message := 'ERROR'
         || '  prod_id[ ' || i_r_item_info_planned_order.prod_id || ']'
         || ' CPV[ ' || i_r_item_info_planned_order.cust_pref_vendor || ']'
         || ' spc[ ' || i_r_item_info_planned_order.spc || ']'
         || ' auto_ship_flag[ ' || i_r_item_info_planned_order.auto_ship_flag
         || ']'
         || ' miniload_storage_ind[ '
         || i_r_item_info_planned_order.miniload_storage_ind || ']'
         || 'i_order_date[ '
         || TO_CHAR(i_order_date, 'MM/DD/YYYY HH24:MI:SS') || ']'
         || '  ml_send_plan_orders returned an error status of '
         || TO_CHAR(o_status);  

      pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_message := 'ERROR'
         || '  prod_id[ ' || i_r_item_info_planned_order.prod_id || ']'
         || ' CPV[ ' || i_r_item_info_planned_order.cust_pref_vendor || ']'
         || ' spc[ ' || i_r_item_info_planned_order.spc || ']'
         || ' auto_ship_flag[ ' || i_r_item_info_planned_order.auto_ship_flag
         || ']'
         || ' miniload_storage_ind[ '
         || i_r_item_info_planned_order.miniload_storage_ind || ']'
         || 'i_order_date[ '
         || TO_CHAR(i_order_date, 'MM/DD/YYYY HH24:MI:SS') || ']'
         || '  ml_send_plan_orders returned an error status of '
         || TO_CHAR(o_status);  

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      o_status := pl_miniload_processing.ct_failure;
END ml_send_plan_orders_for_item;


---------------------------------------------------------------------------
-- Function:
--    correct_order_date
--
-- Description:
--    This function corrects the order date sent from SUS in ithe ML queue.
--    It was created because SUS is sending the ship date down in the
--    ML queue and not the order date.  This affects processing of the
--    historical orders.
--
-- Parameters:
--    i_order_id          - Order id being processed.  It is used in the log
--                          messages.
--    i_add_date          - Date the order sent to SWMS.
--    i_order_date        - Order date to correct
--
-- Return Values:
--    Corrected order date.
--
-- Called by:
--      Database trigger on MINILOAD_ORDER and PLANNED_ORDER_HDR for
--      historical orders.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/18/13 prpbcb   Created.
--                      We are having issues with the order date sent by SUS
--                      in the ML queue which is affecting the processing of
--                      historical orders.
--                      The order date we are getting from SUS is
--                      actually the ship date.  For historical orders the
--                      miniloader looks at the order date to know when to
--                      process the historical orders orders so they get
--                      processed a day late.  So that we
--                      do not have to change SUS this trigger will
--                      set the order date to the current date as shown below.
--                      SAP and IDS send the correct order date except for
--                      Saturday on IDS.  IDS send Sundays orders on
--                      Saturday so we need to change Saturday to Sunday.
--
--                      Date order sent     Order date    Change order
--                      in ML queue order   ML record     date to
--                      ----------------------------------------------
--                      Monday              Tuesday       Monday
--                      Tuesday             Wednesday     Tuesday
--                      Wednesday           Thursday      Wednesday
--                      Thursday            Friday        Thursday
--                      Friday              Saturday      Friday
--                      Friday              Monday        Sunday
--                      Saturday            Monday        Sunday
--                      Saturday            Saturday      Sunday
--
--                      Friday is a special case because some OpCos do
--                      not ship Friday night.
--                      For Saturday IDS is sending Sundays orders.
--                      SWMS gets nothing on Sunday.
--
--                      NOTE: For regular orders SUS is also sending the
--                            ship date instead fo the order date but this
--                            does not cause any problems because SWMS and
--                            the miniloader do not look at the order date
--                            for regular orders.  SWMS and the miniloader
--                            expect regular orders that come down in the
--                            ML queue are to be picked that day.
--
---------------------------------------------------------------------------
FUNCTION correct_order_date(i_order_id    planned_order_hdr.order_id%TYPE,
                            i_add_date    IN DATE,
                            i_order_date  IN DATE)
RETURN DATE
IS
   l_message       VARCHAR2(512);  -- Message buffer.
   l_object_name   VARCHAR2(30) := 'correct_order_date';   -- Procedure name.
                                                           -- Used in messages.

   l_add_date_day_of_week     PLS_INTEGER;
   l_order_date_day_of_week   PLS_INTEGER;
   l_return_value  DATE;

   e_dates_suspect  EXCEPTION;
BEGIN
   --
   -- Check for a null parameter.
   --
   IF (i_order_id IS NULL OR i_add_date IS NULL OR i_order_date IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;

   --
   -- Check the dates.
   -- trunc(i_add_date) should be <= trunc(i_order_date)
   -- and the i_order_date should be no more than 3 days past i_add_date.
   -- If this is not the case then a log message is created and
   -- i_order_date will be returned.  Processing does not stop.
   --
   IF (   TRUNC(i_add_date)   > TRUNC(i_order_date)
       OR TRUNC(i_order_date) > TRUNC(i_add_date) + 3) 
   THEN
      RAISE e_dates_suspect;
   END IF;

   --
   -- Initialization.  
   --
   l_return_value := i_order_date;  -- Start with the order date.  It
                                    -- can be changed below.

   --
   -- Use the day of the week in the comparisons.
   --
   -- Day of week: 1 - Sunday
   --              2 - Monday
   --              3 - Tuesday
   --              4 - Wednesday
   --              5 - Thursday
   --              6 - Friday
   --              7 - Saturday
   --
   l_add_date_day_of_week   := TO_CHAR(i_add_date, 'D');
   l_order_date_day_of_week := TO_CHAR(i_order_date, 'D');

   IF (   (((l_order_date_day_of_week - l_add_date_day_of_week) = 1) AND
          (l_add_date_day_of_week IN (1, 2, 3, 4, 5, 6)))
       OR (l_add_date_day_of_week = 6 AND l_order_date_day_of_week = 2)
       OR (l_add_date_day_of_week = 7 AND l_order_date_day_of_week = 2) )
   THEN
      l_return_value := i_order_date - 1;
   ELSIF (l_add_date_day_of_week = 7 AND l_order_date_day_of_week = 7)
   THEN
      l_return_value := i_order_date + 1;
   END IF;

   -- Debug stuff
   -- DBMS_OUTPUT.PUT_LINE('i_order_id: '   || i_order_id
   --        || '     i_add_date: '      || TO_CHAR(i_order_date, 'DD-MON-YYYY HH24:MI:SS DAY')
   --        || '     i_order_date: '    || TO_CHAR(i_order_date, 'DD-MON-YYYY HH24:MI:SS DAY')
   --        || '     l_return_value: '  || TO_CHAR(l_return_value, 'DD-MON-YYYY HH24:MI:SS DAY') );

   --
   -- Log the input parameters and the return value.
   -- We will show the DAY too.
   --
   l_message := l_object_name
      || '(i_order_id[' || i_order_id || ']'
      || ',i_add_date[' || TO_CHAR(i_add_date, 'DD-MON-YYYY HH24:MI:SS DAY') || ']'
      || ',i_order_date[' || TO_CHAR(i_order_date, 'DD-MON-YYYY HH24:MI:SS DAY') || '])'
      || '  Corrected order date[' || TO_CHAR(l_return_value, 'DD-MON-YYYY HH24:MI:SS DAY') || ']'
      || '  sys_context module[' || SYS_CONTEXT('USERENV','MODULE') || ']';

   pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

   RETURN l_return_value;

EXCEPTION
   WHEN gl_e_parameter_null THEN
      l_message := l_object_name
          ||  '(i_order_id[' || i_order_id || ']'
          ||  ',i_add_date[' || TO_CHAR(i_add_date, 'DD-MON-YYYY HH24:MI:SS')
          || ']'
          ||  ',i_order_date[' || TO_CHAR(i_order_date, 'DD-MON-YYYY HH24:MI:SS')
          || '])'
          || '  sys_context module[' || SYS_CONTEXT('USERENV','MODULE') || ']'
          || '  A parameter is null.  This will not stop processing.'
          || '  i_order_date will be returned.';

         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                        NULL, NULL,
                        ct_application_function, gl_pkg_name);

      RETURN i_order_date;

   WHEN e_dates_suspect THEN
      l_message := l_object_name
          ||  '(i_order_id[' || i_order_id || ']'
          ||  ',i_add_date[' || TO_CHAR(i_add_date, 'DD-MON-YYYY HH24:MI:SS')
          || ']'
          ||  ',i_order_date[' || TO_CHAR(i_order_date, 'DD-MON-YYYY HH24:MI:SS')
          || '])'
          || '  sys_context module[' || SYS_CONTEXT('USERENV','MODULE') || ']'
          || '  trunc(i_add_date) is > trunc(i_order_date) or i_order_date'
          || ' is more than 3 days past i_add_date.  This makes the dates questionable.'
          || '  This will not stop processing.'
          || '  i_order_date will be returned.';

      pl_log.ins_msg(pl_lmc.ct_warn_msg, 'correct_order_date', l_message,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      RETURN i_order_date;

   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      -- Write a log message but do not stop processing.
      -- Do not stop processing
      --
      l_message := l_object_name
          ||  '(i_order_id[' || i_order_id || ']'
          ||  ',i_add_date[' || TO_CHAR(i_add_date, 'DD-MON-YYYY HH24:MI:SS')
          || ']'
          ||  ',i_order_date[' || TO_CHAR(i_order_date, 'DD-MON-YYYY HH24:MI:SS')
          || '])'
          || '  sys_context module[' || SYS_CONTEXT('USERENV','MODULE') || ']'
          || '  Oracle error.  This will not stop processing.'
          || '  i_order_date will be returned.';

      pl_log.ins_msg(pl_lmc.ct_warn_msg, 'correct_order_date', l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RETURN i_order_date;

END correct_order_date;


END pl_planned_order;
/


show errors


-- CREATE OR REPLACE PUBLIC SYNONYM PL_PLANNED_ORDER FOR SWMS.PL_PLANNED_ORDER;

