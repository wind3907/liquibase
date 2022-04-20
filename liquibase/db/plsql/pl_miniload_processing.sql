CREATE OR REPLACE PACKAGE SWMS.pl_miniload_processing
AS
   -- sccs_id=%Z% %W% %G% %I%
   -----------------------------------------------------------------------------
   -- Package Name:
   --   pl_miniload_processing
   --
   -- Description:
   --    Miniloader processing.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- -----------------------------------------------------
   --    01/31/06 acpvxg   Created.
   --    02/20/06 acpmxp   Removed updates to CC tables in procedure
   --                      p_rcv_inv_arr as these updates are taken care of
   --                      during CC processing
   --    02/21/06 acpmxp   Removed put_date as this field is no longer present
   --                      in inv table
   --    03/28/06 acpmxp   Removed processing of failed messages.
   --    03/28/06 prphqb   Query high priority from table           
   --    04/17/06 prphqb   Change carrier CT_LABEL_SIZE from 8 to 18
   --    04/27/06 prphqb   Remove AUTONOMOUS TRANSACTION in p_upd_status, add
   --                      ROLLBACK
   --                   Add pl_text_log.init to get program name.
   --                      Change lv_msg_text to VARCHAR2(1500)
   --    05/15/06 prphqb                   
   --    08/02/06 prpbcb   DN 12121
   --                      Project: 215912-SWMS WAI integration test fixes
   --                      Added parameters i_bln_check_ship_split_only
   --                      to procedure p_convert_uom.
   --                      Change p_convert_uom to induct the qty as
   --                      splits when i_bln_check_ship_split_only is TRUE,
   --                      the item is ship split only and the item is
   --                      splitable.
   --                      Added parameter TRUE to the argument list to call
   --                      to p_convert_uom in procedure p_send_exp_receipt.
   --    08/29/06 prphqb   DN 233796 
   --                      . Need to query for splits already in qty_planned
   --                      minus ordered before doing another ML RPL for splits
   --                      . Must send high priority store order for split RPL
   --                         to block a tray from moving
   --    09/14/06 prpbcb   DN 12151
   --             prphqb   Project:
   --    243093-Send pick complete to ML for all inventory for items ordered
   --                      Pick complete changes.
   --
   --                      Removed "UPPER" applied to columns and variables.
   --                      It was used mainly on the message type and was
   --                      preventing indexes from being used.
   --                      The UPPER is not necessary because the message
   --                      types have defined values.
   --
   --    01/31/07 prpbcb   DN 12214
   --                      Ticket: 326211
   --                      Project: 326211-Miniload Induction Qty Incorrect
   --
   --                      Modified procedure p_send_pending_pickcomp_msg() to
   --                      send pick complete for the outbound location.
   --                      Before it was excluded.
   --
   --                      Added procedure resend_miniload_message() to resend
   --                      a miniload message back to the miniloader.
   --                      This used to be done in form mm4sa.fmb.  Changes
   --                      were made to form mm3sa.fmb to handle resending
   --                      the message.  The form will call
   --                      resend_miniload_message() to resend the message.
   --                      Note: Form mm4sa.fmb will most likely go away
   --                            because the functionality has been moved to
   --                            mm3sa.fmb.
   --
   --                      Moved procodures p_check_hdo and p_insert_hoi
   --                      to package pl_miniload_interface.
   --
   --                      Removed, when appropriate, statements like this
   --                          SELECT REPLACE (lv_user, 'OPS$')
   --                            INTO lv_user
   --                            FROM DUAL;
   --                      and put REPLACE (lv_user, 'OPS$') in the
   --                      update/insert stmt.
   --
   --                      Removed setting the upd_date and the upd_user when
   --                      updating a table if there was a trigger on the table
   --                      doing this.
   --
   --                      Added the following functions to return some of
   --                      the package constants to use in forms 6i since
   --                      a package constant cannot be directly accessed
   --                      from forms 6i.
   --                         - f_get_ct_exp_rec 
   --                         - f_get_ct_new_sku 
   --                         - f_get_ct_modify_sku 
   --                         - f_get_ct_delete_sku 
   --                         - f_get_ct_inv_upd_carr 
   --                         - f_get_ct_success
   --                         - f_get_ct_failure
   --                         - f_get_ct_er_duplicate
   --
   --    03/23/07 prpbcb   DN 12233
   --                      Ticket: 278350
   --                      Project: 278350-Miniload Induction of Multiple LPs
   --
   --                      Made the following changes to procedure
   --                      p_rcv_inv_adj_inc().
   --                      Most of the changes were done while the file was
   --                      checked out under project
   --                      "326211-Miniload Induction Qty Incorrect".
   --                         - Allow inducting a qty greater than the expected
   --                           receipt qty.  This can happen when slotting an
   --                           item into the miniloader and there was more on
   --                           the LP than what SWMS had.
   --
   --                         - Bug fix: When inducting cases (or splits) from
   --                           two or more LP's to the same carrier the last
   --                           induction fails on SWMS.  What is failing is
   --                           the inventory adjustment increase message sent
   --                           to SWMS from the ML.
   --                           The examples below are actual examples from
   --                           OpCo 163.
   -- Example:
   --    LP 614933 has 3 cases of item xxx putaway to the induction location.
   --    LP 614934 has 18 cases of item xxx putaway to the induction location.
   --
   --    3 cases from LP 614933 are inducted to carrier M22415222.  This is
   --    successful.
   --    4 cases from LP 614934 are inducted to carrier M22415222.  This fails.
   --    14 cases from LP 614934 are inducted to carrier M22415223.  This is
   --    successful.
   --
   -- Example:
   --    This is an example of inducting when an item in the main warehouse was
   --    slotted to the ML.
   --    LP DS63A5109 has 6 splits of item xxx dropped to the induction
   --    location.
   --    LP DS63B2108 has 12 splits of item xxx dropped to the induction
   --    location.
   --    LP DS63B2110 has 2 splits of item xxx dropped to the induction
   --    location.
   --
   --    6 splits from LP DS63A5109 are inducted to carrier M16304801.  This is
   --    successful.
   --    12 splits from LP DS63A5109 are inducted to carrier M16304801.  This is
   --    successful.
   --    1 split from LP DS63A5110 is inducted to carrier M16304801.  This
   --    fails.
   --
   --    03/23/07 prpbcb   DN 12232
   --                      Ticket: 237485
   --                      Project:
   --                         237485-Unnecessary miniloader split repl created
   --
   --                      Added function f_is_repl_necessary_for_order().
   --
   --                      Modified procedure p_process_ml_replen() to call
   --                      f_is_repl_necessary_for_order() to determine if it
   --                      is necessary to create a case->split replenishment.
   --                      It may be that an existing replenishment for a
   --                      previous order will cover the current order.
   --                      Only did this when the ML storage ind is B.  We need
   --                      to revisit this before going live when the cases are
   --                      in the main warehouse and splits are in the ML.
   --
   --    09/05/07 prpbcb   DN 12280
   --                      Ticket: 458478
   --                      Project: 458478-Miniload Fixes
   --                      Removed assignment of add_date, add_user, upd_date
   --                      and upd_user.  Default values have been added 
   --                      to the table columns for add_date and add_user and
   --                      a database trigger created to assign the upd_date
   --                      and upd_user.
   --
   --                      Changed the insert stmt for the MINILOAD_TRANS
   --                      table to not strip OPS$ from the user id.  Because
   --                      of how the transaction screen works when querying
   --                      by user id the OPS$ is needed.  This also keeps the
   --                      user id format consistent with the TRANS table.
   --
   --                      Added field
   --                         v_cmt    miniload_trans.cmt%TYPE
   --                      to the t_sku_info record.  This will be used for
   --                      the transction comment for a new or modify sku.
   --                      Before the transaction comment was always set to 
   --                      the item description.  This change was made so
   --                      that the MNI tranaction comment could be set to
   --                      "SUS FLAGGED NON SPLITABLE ITEM AS SPLITABLE.
   --                       SPLIT SKU SENT TO MINILOADER" when SUS makes a
   --                      non-splitable item as splitable and the cases are
   --                      stored in the miniloader.
   --
   --                      Added procedure send_SKU_change() which send a
   --                      new SKU message and/or a change SKU message to
   --                      the miniloader depending on the values of the
   --                      parameters.  See the description in the procedure
   --                      for additional information.
   --
   --    03/04/08 prpbcb   DN 12356
   --                      Project:
   --                          575289-Miniload Replenishment Expiration Date
   --                      Changed
   --              TO_DATE (i_ml_replenishment.v_exp_date, 'DD-MM-YYYY'),
   --                      to
   --              i_ml_replenishment.v_exp_date
   --                      in p_insert_replen.
   --
   --    05/12/08 prpbcb   DN 12386
   --                      Project:
   --                          618130-Cannot Complete Miniload Replenishment
   --                      Function f_find_ml_system() was generating an
   --                      error because the prod id and CPV passed to this
   --                      function were null which resulted in failing to
   --                      send some messages to the miniloader.  One of the
   --                      messages failing was the inventory update for
   --                      carrier for a carrier with the inventory depleted to
   --                      0 for case to split replenishments.  This message is
   --                      sent when the replenishment is confirmed at the
   --                      induction location.  The error was because
   --                      i_prod_id and i_cust_pref_vendor were null which
   --                      for this replenishment situation they would be null.
   --                      They were null because some messages to send to
   --                      the miniloader do not have the prod id and cpv.
   --                      A temporary fix was made to f_find_ml_system()
   --                      which is to select the miniload system from table
   --                      MINILOAD_CONFIG as the first operation.  If this
   --                      is successful then the function returns otherwise
   --                      the regular processing continues which will again
   --                      result in an error if the prod id and cpv parameters
   --                      are null.   This temporary fix will work for now
   --                      because upto this point an OpCo will only have
   --                      one miniload system.
   --                      
   --                      In the miniload replenishment processing no
   --                      check was being made if a previous replenishment
   --                      would cover the qty ordered when cases were stored
   --                      in the main warehouse and splits were stored in the
   --                      miniloader (pm.miniload_storge_ind = 'S') which
   --                      resulted in unnecessary case to split
   --                      replenishments.  Now the check is made.  Procedure
   --                      p_process_ml_replen() was changed to call function
   --                      f_is_repl_necessary_for_order() when
   --                      i_item_status_info.c_ml_storage_ind is 'S'.
   --
   --    07/17/08 prpakp   Change for warehouse option to miniload.
   --
   --    05/12/08 prpbcb   DN 12414
   --                      Project: 562935-Warehouse Move MiniLoad Enhancement
   --                      Move procedure p_wh_move to pl_wh_move.sql
   --
   --    10/16/08 prpbcb   DN 12431
   --                      Project:
   --                    CRQ000000003712-Pick Complete Not Send to Miniload
   --
   --                      Change procedure p_send_pending_pickcomp_msg()
   --                      to check syspar ALWAYS_SEND_PICK_COMPLETE and if
   --                      Y to always send the pick complete for a carrier
   --                      and not look at table MINILOAD_PICKCOMPLETE to see
   --                      if it has already been sent.  We are having issues
   --                      with the logic when looking at the
   --                      MINILOAD_PICKCOMPLETE table that is resulting in
   --                      pick completes not being sent resulting in
   --                      inventory being out of sync between SWMS and the
   --                      miniloader.
   --                      Syspar ALWAYS_SEND_PICK_COMPLETE does not exist
   --                      yet nor will it be created at this time.  When we
   --                      get the logic fixed with table MINILOAD_PICKCOMPLETE 
   --                      and it turns out resending all pick completes is
   --                      slowing down the miniloader then we can create the
   --                      syspar.
   --
   --                      Changed procedure p_send_exp_receipt to also check
   --                      the uom when determining if an expected receipt
   --                      already exists for a LP.
   --                      We ran into some unexpected situations at OpCo 293
   --                      where we had pallets at the induction location with
   --                      cases that needed to be inducted, the item was not
   --                      splittable and an expected reciept existed but was
   --                      for splits.  We wanted to use the same LP but have
   --                      the ER for cases.  The expected receipt for splits
   --                      was over a month old.  Not sure why it was for
   --                      splits.  The OpCo initially did not have enough
   --                      trays so many of the pallets first being received
   --                      where not inducted but put aside in the main
   --                      warehouse.
   --
   --    10/30/08 prpbcb   DN 12434
   --                      Project:
   --                  CRQ000000001006-Embed meaningful messages in miniload
   --
   --                      When processing a message sent from the miniloader
   --                      fails create a meaningful message with details on
   --                      why the message failed.  When a message fails a
   --                      corresponding record will be inserted into the
   --                      MINILOAD_EXCEPTION table.  In the cmt column there
   --                      will be a description of why the message failed.
   --                      The user will be to view the exception from the
   --                      miniload message screen or from the exception
   --                      screen.
   --
   --                      Added:
   --              ct_cmt_num_of_ml_messages       PLS_INTEGER := 5;
   --              ct_cmt_num_of_transactions      PLS_INTEGER := 5;
   --
   --                      Added functions:
   --                         - cmt_carrier_last_ml_messages()
   --                         - cmt_carrier_last_trans()
   --                         - build_exception_cmt()
   --
   --                      Modified procedures:
   --                         - p_insert_miniload_exception()
   --
   --
   --                      Fix bug when creating a split replenishment from a
   --                      case carrier in a pick face when the qty on the case
   --                      carrier was less than the
   --                      PM.CASE_QTY_FOR_SPLIT_RPL.  The program stayed in a
   --                      loop until sequence ml_pallet_id_seq wrapped around
   --                      and eventually resulted in a dup val on index error
   --                      which then cased the loop to exit and a rollback
   --                      performed.
   --                      Modified procedure:
   --                         p_process_ml_replen()
   --                      Added n_spc to t_item_status_info.
   --                      Populate n_spc in procedure p_rcv_item_status.
   --
   --                      Incident 79682
   --                      Modfied procedure p_rcv_inv_adj_inc() adding
   --                            rule_id = 3
   --                      to select statement
   --                         SELECT induction_loc
   --                         INTO lv_induction_loc
   --                         ...
   --                      to fix too many rows error when the item has the
   --                      cases stored in the main warehouse and the splits
   --                      in the miniloader.
   --
   --    12/08/08 prpbcb   DN 12450
   --                      Project:
   --                  CRQ000000006128-Miniloader stop full table scans
   --                      Changed cursor c_msgs_to_host in procedure
   --                      p_receive_msg() to use hints so that the indexes on
   --                      the status and source_system are used.  This is to
   --                      stop the full tables scans on MINILOAD_MESSAGE and
   --                      MINILOAD_ORDER.
   --                      I could not get the cursor to use the indexes
   --                      without the hints.
   --
   --    02/27/09 prpbcb   DN 12509
   --                      Project: CRQ10094-Sub-dividing MSKU lost data
   --
   --                      Tagged along these changes to the CRQ.
   --
   --                      Fix the miniload messages order by in procedure
   --                      cmt_carrier_last_ml_messages().
   --                      Was:
   --                         ORDER BY mlm.add_date desc, mlm.add_date desc;
   --                      Changed to;
   --                         ORDER BY mlm.add_date desc, mlm.message_id desc;
   --
   --                      DN 12502
   --    11/09/09 prpbcb   Added AUTHID CURRENT_USER so the new warehouse
   --                      users (whrcv__ and whfrk__) see the WHMOVE schema
   --                      and not the SWMS schema when pre-receiving into the
   --                      new warehouse before a warehouse move.
   --
   --    12/17/09 prpbcb   DN 12533
   --                      Removed AUTHID CURRENT_USER.  We found a problem in
   --                      pl_rcv_open_po_cursors.f_get_inv_qty when using it.
   --                      We will take a different approach for the new 
   --                      warehouse move users
   --
   --    01/27/10 prpbcb   DN 12512
   --                      Project:
   --               CRQ8828-Miniload Functionality in Warehouse Move Process
   --
   --                      Changed procedure p_rcv_inv_adj_inc() to get the
   --                      induction location from WHMV_MINILOAD_ITEM
   --                      if warehouse move is active and at the point in
   --                      processing where inventory is being created because
   --                      an induction is made on a LP not in inventory
   --                      (this can happen when inducting more than what was
   --                      on the LP or when inducting off a manually created
   --                      expected receipt).  This is to handle moving items
   --                      into the miniloader during the pre-move period.
   --                      It needs to be done this way because the item is
   --                      not yet flagged as a miniload item in the
   --                      SWMS.PM table.
   --
   --    04/07/10 prpbcb   DN 12571
   --                      Project: CRQ15757-Miniload In Reserve Fixes
   --
   --                      Procedure p_insert_miniload_order() was not
   --                      select a value for the message id when creating the
   --                      ct_ship_ord_prio record thus the insert failed.
   --
   --                      In procedures
   --                         p_rcv_inv_arr()
   --                         p_process_ml_replen()
   --                         p_create_highprio_order()
   --                      changed where clause
   --                         WHERE priority_code   = 'HGH'
   --                      to
   --                         WHERE priority_code   = 'HGH'
   --                           AND and unpack_code = 'Y';
   --                       because there is now two records with
   --                       priority_code = 'HGH' as a result of the MLR
   --                       project.
   --
   --                       Added the following to cursor c_other_pick_loc in
   --                       procedure p_process_ml_replen():
   --                          AND i.qoh - i.qty_alloc > 0
   --                       since the LP could have an existing replenishment
   --                       for some of the qty on the LP.
   --
   --                       In procedure p_process_ml_replen () added
   --                        AND logi_loc = l_ml_replenishment.v_orig_pallet_id
   --                       when updating INV and selecting INV record.
   --
   --                      Modified procedure p_send_pending_pickcomp_msg().
   --                      Added call to pl_ml_cleanup.cleanup_replenishments
   --                      to cleanup old miniloader replenishments.  Before
   --                      this was done by swmspurge_ord.sql.  Cleaning
   --                      up the miniloader replenishments is part of the
   --                      picking complete processing.
   --
   --    02/11/11 prpbcb   DN 12604
   --                      Project:
   --                         CRQ20894-Cannot perform miniload replenishment
   --                           (this got cancelled by someone)
   --                         Will use this one
   --                        CRQ20684-Split miniloader replenishments not on RF
   --                      Incidents: 660598
   --                                 656577
   --
   --                      Fix issue with two case to split priority 20
   --                      replenishments created for the same order.
   --                      Modified:
   --                         - p_rcv_item_status
   --                      Created function:
   --                         - is_repl_in_process_for_order
   --
   --                      Added:
   --                         AND i.status = 'AVL'
   --                      to cursor c_total_qty_splits.  It should have been
   --                      there all along.
   --
   --    05/08/11 prpbcb   Change procedure p_send_exp_receipt.
   --                      Added additional criitera in the where clause
   --                      when checking if the expected receipt already exists.
   --                      It should have been like this all along.
   --                      Added:
   --          AND prod_id          = l_miniload_info.vt_exp_receipt_info.v_prod_id
   --          AND cust_pref_vendor = l_miniload_info.vt_exp_receipt_info.v_cust_pref_vendor
   --          AND uom              = l_miniload_info.vt_exp_receipt_info.n_uom
   --          AND qty_expected     = l_miniload_info.vt_exp_receipt_info.n_qty_expected
   --          AND add_date         <= (SYSDATE - (20 / (60 * 24)));
   --
   --    09/21/12 prpbcb   Project:
   --                       CRQ38520-Miniload_cannot_drop_split_replenishment
   --                      Activity:
   --                       CRQ38520-Miniload_cannot_drop_split_replenishment
   --
   --                     The replenlst priority for the split replenishment
   --                     is not correct.  Procedure p_process_ml_replen() is
   --                     using the priority from the shipping order record
   --                     in MINILOAD_ORDER. This is the query:
   --                        SELECT MIN(order_priority)
   --                          INTO l_ml_replenishment.v_priority
   --                          FROM miniload_order
   --                         WHERE order_id = i_item_status_info.v_order_id
   --                           AND message_type = ct_ship_ord_hdr;
   --                     This it not we want. The priority needs to be 20
   --                     which it was set to before the call to
   --                     p_process_ml_replen().  The above select commented 
   --                     out in p_process_ml_replen().
   --
   --
   --    06/18/13 prpbcb   Project:  (this was not completed)
   --                  
   --                      Creating unnecessary replenishments when an order
   --                      comes down after the route was generated.
   --                      We are seeing instances where the order comes down
   --                      during the day which is correct then comes down
   --                      again after the route was generated.  Depending on
   --                      the qoh a non-demand replenishment can get created
   --                      for something thats already picked.  We do not want
   --                      to create a replenishment for something for an order
   --                      that has been picked--has a PIK transaction.
   --                      Modified:
   --                         - function f_is_repl_necessary_for_order
   --
   --    07/22/14 prpbcb   TFS Project:
   --   R12.6.2--WIB#427--Charm6000001721_Do_not_send_duplicate_order_to_the_ML
   --
   --                      Do not send a duplicate order that comes down in the
   --                      ML queue to the miniloader.
   --                      Since we started using the miniloader the order
   --                      was always sent to the miniloader, when it had
   --                      miniloader items on it, regardless if SUS/SAP/IDS
   --                      had already sent the order to SWMS and it had not
   --                      changed.  Apparently we are see some performance
   --                      issues within the miniloader as it basically starts
   --                      processing over again when it receives the same order
   --                      again even if it has not changed.
   --
   --                      FYI  Within the past 10 days there were 632 orders
   --                      sent down at least 5 times at OpCo 388 and 286
   --                      orders at OpCo 056.
   --
   --                      Added procedure "do_not_send_dup_order_to_ml"
   --                      to accomplish this.
   --                      This procedure checks if and order was
   --                      already sent to the miniloader and it has not
   --                      changed.  If this is the case the
   --                      MINILOAD_ORDER.STATUS is set to 'S' which effectively
   --                      keeps script "ml_int.sh" from sending it to the
   --                      miniloader.  This procedure needs to be called after
   --                      the order was inserted into MINILOAD_ORDER and
   --                      before it is committed.
   --
   --                      Procedure "do_not_send_dup_order_to_ml" always
   --                      writes a log message to SWMS_LOG for research
   --                      purposes.
   --
   --                      "swmsmlreader.pc" was changed to call 
   --                      "pl_miniload_processing.do_not_send_dup_order_to_ml".
   --
   --                      Also completed what was started on 06/18/13.
   --                      All the changes are in function
   --                      "f_is_repl_necessary_for_order"
   --
   --
   --    08/19/14 prpbcb   TFS Project:
   --   R12.6.2--WIB#427--Charm6000001721_Do_not_send_duplicate_order_to_the_ML
   --
   --                      Bug fixes.
   --                      Function f_is_repl_necessary_for_order:
   --                         Add "GROUP BY mo.prod_id" to cursor
   --                         "c_total_splits_ordered".
   --                         Set values to 0 if the FETCH from
   --                         "c_total_splits_ordered"
   --                         is null.
   --
   --    08/19/14 prpbcb   TFS Project:
   --   R12.6.2--WIB#427--Charm6000001721_Do_not_send_duplicate_order_to_the_ML
   --
   --                      Bug fixes.
   --                      Procedure get_message_type_info:
   --                        Changed the time to look back for the start of day
   --                        message from 1 day to 3 days to handle weekends.
   --                        The old and new statements are below.
   --
   --                     Old statement:
   --                 (SELECT MAX(s.add_date)
   --                    FROM miniload_message s
   --                   WHERE s.message_type = pl_miniload_processing.ct_start_of_day
   --                     AND s.add_date >= (SYSDATE - 1))
   --
   --                     New statement:
   --                 (SELECT MAX(s.add_date)
   --                    FROM miniload_message s
   --                   WHERE s.message_type = pl_miniload_processing.ct_start_of_day
   --                     AND s.add_date >= (SYSDATE - 3))
   --    2/11/15        mdev3739    Charm6000002987-SF miniload auto scan and auto confirm 
   --                            put enhancement.
   --   12/30/15        MDEV3739   CHARM#6000010239-exception_email_alert
   --                              Added pl_event package cal to insert the exception for sending mail  
   --
   --   04/06/17  pkab6563 - Fixed bug where SWMS was sending unnecessary requests
   --                        to the miniloader to drop cases to the split home.      
   --                        If a pending request will cover new needs, do not send
   --                        new requests.
   --
   --   08/21/17  pkab6563 - Before creating a high priority order to drop a case
   --                        from reserve to the pick face, check to ensure that
   --                        a case is available in reserve. 
   --
   --   10/04/17  pkab6563 - During inventory planned move and inventory arrival, 
   --                        if the location is not in SWMS, add it to SWMS 
   --                        before proceeding further.
   --	01/23/18  jluo6971 - CRQ000000043826 Limit cmt value from
   --				miniload_exception to be inserted up to 400
   --				bytes to swms_failure_event.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- -----------------------------------------------------
   --    07/20/21 bben0556 Brian Bent
   --                      R1 cross dock.
   --                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
   --
   --                      ordd.seq needs to be unique across all Xdock OpCos.
   --                      Call "pl_xdock_op.get_ordd_seq" to get the value for ordd.seq.
   -------------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Public Constants
   ---------------------------------------------------------------------------
   CT_PROGRAM_CODE         CONSTANT VARCHAR2 (50) := 'MLIN';
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
   CT_LABEL_SIZE           CONSTANT NUMBER        := 18; --4/17/06 from 8 to 18
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
   CT_CARRIER_STATUS_SIZE  CONSTANT NUMBER          := 3;
   CT_MESSAGE_STATUS_SIZE  CONSTANT NUMBER          := 1;    
   CT_MESSAGE_TEXT_SIZE       CONSTANT NUMBER          := 200;
   CT_MSG_ID_SIZE           CONSTANT NUMBER          := 7;

   --
   -- Message types.
   --
   CT_EXP_REC          CONSTANT VARCHAR2 (50) := 'ExpectedReceipt';
   CT_EXP_REC_COMP     CONSTANT VARCHAR2 (50) := 'ExpectedReceiptComplete';
   CT_NEW_SKU          CONSTANT VARCHAR2 (50) := 'NewSKU';
   CT_MODIFY_SKU       CONSTANT VARCHAR2 (50) := 'ModifySKU';
   CT_DELETE_SKU       CONSTANT VARCHAR2 (50) := 'DeleteSKU';
   CT_INV_ADJ_INC      CONSTANT VARCHAR2 (50) := 'InventoryAdjustmentIncrease';
   CT_INV_ADJ_DCR      CONSTANT VARCHAR2 (50) := 'InventoryAdjustmentDecrease';
   CT_INV_ARR          CONSTANT VARCHAR2 (50) := 'InventoryArrival';
   CT_INV_LOST         CONSTANT VARCHAR2 (50) := 'InventoryLost';
   CT_INV_PLAN_MOV     CONSTANT VARCHAR2 (50) := 'InventoryPlannedMove';
   CT_INV_UPD_CARR     CONSTANT VARCHAR2 (50) := 'InventoryUpdateForCarrier';
   CT_SHIP_ORD_HDR     CONSTANT VARCHAR2 (50) := 'NewShippingOrderHeader';
   CT_SHIP_ORD_INV     CONSTANT VARCHAR2 (50) := 'NewShippingOrderItemByInventory';
   CT_SHIP_ORD_TRL     CONSTANT VARCHAR2 (50) := 'NewShippingOrderTrailer';
   CT_SHIP_ORD_STATUS  CONSTANT VARCHAR2 (50) := 'ShippingOrderItemStatus';
   CT_SHIP_ORD_PRIO    CONSTANT VARCHAR2 (50) := 'ShippingOrderPriorityUpdate';
   CT_PICK_COMP_CARR   CONSTANT VARCHAR2 (50) := 'PickingCompleteForCarrier';
   CT_START_OF_DAY     CONSTANT VARCHAR2 (50) := 'StartOfDay';
   CT_STORE_ORDER      CONSTANT VARCHAR2 (10) := 'Store';
   CT_HISTORY_ORDER    CONSTANT VARCHAR2 (10) := 'History';
   
   -- ctvgg000 For HK Integration
   -- This message informs the miniload in case of a status change to a carrier.
   -- For ex. From 'AVL' to 'HLD'

   CT_CARRIER_STATUS   CONSTANT VARCHAR2 (50) := 'CarrierStatusChange';
   
   -- Reply from miniload incase of 'CarrierStatusChange' message failure
   CT_MESSAGE_STATUS   CONSTANT VARCHAR2 (50) := 'MessageStatus';


   --
   -- 09/26/07 Brian Bent
   -- Constants used by procedure send_SKU_change.
   --
   CT_SEND_SKU_NEW_CS    CONSTANT PLS_INTEGER := 1; -- Send new SKU for
                                                    -- case.
   CT_SEND_SKU_NEW_SP    CONSTANT PLS_INTEGER := 2; -- Send new SKU for
                                                    -- split.
   CT_SEND_SKU_MOD_CS    CONSTANT PLS_INTEGER := 3; -- Send modify SKU for
                                                    -- case.
   CT_SEND_SKU_MOD_SP    CONSTANT PLS_INTEGER := 4; -- Send modify SKU for
                                                    -- split.
   CT_SEND_SKU_NEW_CS_NEW_SP CONSTANT PLS_INTEGER := 5; -- Send new SKU for
                                                        -- case and split.
   CT_SEND_SKU_MOD_CS_MOD_SP CONSTANT PLS_INTEGER := 6; -- Send modify SKU for
                                                        -- case and split.
   CT_SEND_SKU_NEW_CS_MOD_SP CONSTANT PLS_INTEGER := 7; -- Send new SKU for
                                                        -- case and modify
                                                        -- SKU for split.
   CT_SEND_SKU_MOD_CS_NEW_SP CONSTANT PLS_INTEGER := 8; -- Send modify SKU
                                                        -- for case and
                                                        -- new SKU for
                                                        -- split.


   --------------------------------------------------------------------------
   -- Public Type Declarations
   --------------------------------------------------------------------------

   TYPE t_exp_receipt_info IS RECORD (
      v_msg_type              MINILOAD_MESSAGE.message_type%TYPE,
      v_expected_receipt_id   MINILOAD_MESSAGE.expected_receipt_id%TYPE,
      n_uom                   MINILOAD_MESSAGE.UOM%TYPE,
      v_prod_id               MINILOAD_MESSAGE.prod_id%TYPE,
      v_cust_pref_vendor      MINILOAD_MESSAGE.cust_pref_vendor%TYPE,
      n_qty_expected          MINILOAD_MESSAGE.qty_expected%TYPE,
      v_inv_date              MINILOAD_MESSAGE.inv_date%TYPE

   );

   TYPE t_inv_adj_inc_info IS RECORD (
      v_msg_type              MINILOAD_MESSAGE.message_type%TYPE,
      v_label                 MINILOAD_MESSAGE.carrier_id%TYPE,
      v_sku                   VARCHAR2 (20),
      n_quantity              MINILOAD_MESSAGE.qty_expected%TYPE,
      v_inv_date              MINILOAD_MESSAGE.inv_date%TYPE,
      v_user                  MINILOAD_MESSAGE.add_user%TYPE,
      v_reason                MINILOAD_MESSAGE.reason%TYPE,
      v_expected_receipt_id   MINILOAD_MESSAGE.expected_receipt_id%TYPE
   );

   TYPE t_inv_arrival_info IS RECORD (
      v_msg_type              MINILOAD_MESSAGE.message_type%TYPE,
      v_label                 MINILOAD_MESSAGE.carrier_id%TYPE,
      v_actual_loc            MINILOAD_MESSAGE.dest_loc%TYPE,
      v_sku                   VARCHAR2 (20),
      n_quantity              MINILOAD_MESSAGE.qty_expected%TYPE,
      v_inv_date              MINILOAD_MESSAGE.inv_date%TYPE,
      v_planned_loc           MINILOAD_MESSAGE.planned_loc%TYPE
   );

   TYPE t_exp_receipt_complete_info IS RECORD (
      v_msg_type              MINILOAD_MESSAGE.message_type%TYPE,
      v_expected_receipt_id   MINILOAD_MESSAGE.expected_receipt_id%TYPE,
      v_sku                   VARCHAR2 (20),
      n_qty_exp               MINILOAD_MESSAGE.qty_expected%TYPE,
      n_qty_rcv               MINILOAD_MESSAGE.qty_received%TYPE
   );

   TYPE t_inv_adj_dcr_info IS RECORD (
      v_msg_type              MINILOAD_MESSAGE.message_type%TYPE,
      v_label                 MINILOAD_MESSAGE.carrier_id%TYPE,
      v_sku                   VARCHAR2 (20),
      n_quantity              MINILOAD_MESSAGE.qty_expected%TYPE,
      v_inv_date              MINILOAD_MESSAGE.inv_date%TYPE,
      v_user                  MINILOAD_MESSAGE.add_user%TYPE,
      v_reason                MINILOAD_MESSAGE.reason%TYPE
   );

   TYPE t_sku_info IS RECORD (
      v_msg_type              MINILOAD_MESSAGE.message_type%TYPE,
      n_uom                   PUTAWAYLST.UOM%TYPE,
      v_prod_id               PUTAWAYLST.prod_id%TYPE,
      v_cust_pref_vendor      PUTAWAYLST.cust_pref_vendor%TYPE,
      n_items_per_carrier     MINILOAD_MESSAGE.items_per_carrier%TYPE,
      v_sku_description       MINILOAD_MESSAGE.description%TYPE,      
      v_cmt                   MINILOAD_TRANS.cmt%TYPE,
      v_zone_id                  PM.zone_id%TYPE,
      v_split_zone_id          PM.split_zone_id%TYPE
   );

   TYPE t_carrier_update_info IS RECORD (
      v_msg_type              MINILOAD_MESSAGE.message_type%TYPE,
      v_carrier_id            MINILOAD_MESSAGE.carrier_id%TYPE,
      n_uom                   PUTAWAYLST.UOM%TYPE,
      v_prod_id               PUTAWAYLST.prod_id%TYPE,
      v_cust_pref_vendor      PUTAWAYLST.cust_pref_vendor%TYPE,
      n_qty                   MINILOAD_MESSAGE.qty_expected%TYPE,
      v_inv_date              MINILOAD_MESSAGE.inv_date%TYPE
   );

   TYPE t_inv_planned_mov_info IS RECORD (
      v_msg_type              MINILOAD_MESSAGE.message_type%TYPE,
      v_label                 MINILOAD_MESSAGE.carrier_id%TYPE,
      v_src_loc               MINILOAD_MESSAGE.source_loc%TYPE,
      v_sku                   VARCHAR2(20),
      n_quantity              MINILOAD_MESSAGE.qty_expected%TYPE,
      v_inv_date              MINILOAD_MESSAGE.inv_date%TYPE,
      v_planned_loc           MINILOAD_MESSAGE.planned_loc%TYPE,
      v_order_priority        MINILOAD_ORDER.order_priority%TYPE
   );

   TYPE t_inv_lost_info IS RECORD (
      v_msg_type              MINILOAD_MESSAGE.message_type%TYPE,
      v_label                 MINILOAD_MESSAGE.carrier_id%TYPE,
      v_sku                   VARCHAR2(20),
      n_quantity              MINILOAD_MESSAGE.qty_expected%TYPE,
      v_inv_date              MINILOAD_MESSAGE.inv_date%TYPE,
      v_user                  MINILOAD_MESSAGE.add_user%TYPE,
      v_reason                MINILOAD_MESSAGE.reason%TYPE
   );

   TYPE t_new_ship_ord_hdr_info IS RECORD (
      v_msg_type              MINILOAD_MESSAGE.message_type%TYPE,
      v_order_id              MINILOAD_ORDER.order_id%TYPE,
      v_description           MINILOAD_ORDER.description%TYPE,
      n_order_priority        MINILOAD_ORDER.order_priority%TYPE,
      v_order_type            MINILOAD_ORDER.ORDER_TYPE%TYPE,
      v_order_date            MINILOAD_ORDER.order_date%TYPE
   );

   TYPE t_new_ship_ord_item_inv_info IS RECORD (
      v_msg_type              MINILOAD_ORDER.message_type%TYPE,
      v_order_id              MINILOAD_ORDER.order_id%TYPE,
      v_order_item_id         MINILOAD_ORDER.order_item_id%TYPE,
      n_uom                   MINILOAD_ORDER.UOM%TYPE,
      v_prod_id               MINILOAD_ORDER.prod_id%TYPE,
      v_cust_pref_vendor      MINILOAD_ORDER.cust_pref_vendor%TYPE,
      n_qty                   MINILOAD_ORDER.quantity_requested%TYPE,
      n_sku_priority          MINILOAD_ORDER.sku_priority%TYPE
   );

   TYPE t_new_ship_ord_trail_info IS RECORD (
      v_msg_type              MINILOAD_ORDER.message_type%TYPE,
      v_order_id              MINILOAD_ORDER.order_id%TYPE,
      n_order_item_id_count   MINILOAD_ORDER.order_item_id_count%TYPE
   );

   TYPE t_ship_ord_prio_upd_info IS RECORD (
      v_msg_type              MINILOAD_ORDER.message_type%TYPE,
      v_order_id              MINILOAD_ORDER.order_id%TYPE,
      n_order_priority        MINILOAD_ORDER.order_priority%TYPE
   );

   TYPE t_picking_complete_info IS RECORD (
      v_msg_type              MINILOAD_MESSAGE.message_type%TYPE,
      v_carrier_id            MINILOAD_MESSAGE.carrier_id%TYPE,
      n_quantity              MINILOAD_MESSAGE.qty_received%TYPE,
      v_inv_date              MINILOAD_MESSAGE.inv_date%TYPE,
      n_uom                   MINILOAD_MESSAGE.UOM%TYPE,
      v_cust_pref_vendor      MINILOAD_MESSAGE.cust_pref_vendor%TYPE,
      v_prod_id               MINILOAD_MESSAGE.prod_id%TYPE
   );

   TYPE t_item_status_info IS RECORD (
      v_msg_type              miniload_order.message_type%TYPE,
      v_order_id              miniload_order.order_id%TYPE,
      v_order_item_id         miniload_order.order_item_id%TYPE,
      n_quantity_requested    miniload_order.quantity_requested%TYPE,
      n_quantity_available    miniload_order.quantity_available%TYPE,
      n_uom                   loc.uom%TYPE,
      v_prod_id               pm.prod_id%TYPE,
      v_cust_pref_vendor      pm.cust_pref_vendor%TYPE,
      c_ml_storage_ind        pm.miniload_storage_ind%TYPE,
      v_sku                   VARCHAR2(20),
      n_spc                   pm.spc%TYPE    -- 12/04/08 Brian Bent Added
   );

   TYPE t_ml_replenishment IS RECORD (
      n_uom                   INV.inv_uom%TYPE,
      v_prod_id               PM.prod_id%TYPE,
      v_cust_pref_vendor      PM.cust_pref_vendor%TYPE,
      n_replen_qty            REPLENLST.qty%TYPE,
      v_replen_type           REPLENLST.TYPE%TYPE,
      v_src_loc               REPLENLST.src_loc%TYPE,
      v_dest_loc              REPLENLST.dest_loc%TYPE,
      v_pallet_id             REPLENLST.pallet_id%TYPE,
      v_s_pikpath             REPLENLST.s_pikpath%TYPE,
      v_d_pikpath             REPLENLST.d_pikpath%TYPE,
      v_order_id              REPLENLST.order_id%TYPE,
      v_exp_date              REPLENLST.exp_date%TYPE,
      v_user_id               REPLENLST.gen_uid%TYPE,
      v_parent_pallet_id      REPLENLST.parent_pallet_id%TYPE,
      v_priority              REPLENLST.priority%TYPE,
      v_orig_pallet_id        REPLENLST.orig_pallet_id%TYPE
   );

   TYPE t_start_of_day_info IS RECORD (
      v_msg_type              MINILOAD_ORDER.message_type%TYPE,
      v_order_date            MINILOAD_MESSAGE.order_date%TYPE
   );

   -- For HK Integration ctvgg000
   -- A record type to hold carrier Information
   -- beg add
   TYPE t_carrier_status_info IS RECORD (
      v_msg_type              MINILOAD_MESSAGE.message_type%TYPE,
      v_label                 MINILOAD_MESSAGE.carrier_id%TYPE,
      v_carrier_status        INV.status%TYPE,
      v_user                  MINILOAD_MESSAGE.upd_user%TYPE,
      v_reason                MINILOAD_MESSAGE.reason%TYPE       
   );
   
   TYPE t_msg_status_info IS RECORD (
      v_msg_type              miniload_message.message_type%TYPE,  
      v_msg_id                miniload_message.message_id%TYPE,              
      v_msg_status            CHAR(1),
      v_msg_status_text       VARCHAR2(200) 
   );

   -- end add


   TYPE t_miniload_info IS RECORD (
      vt_exp_receipt_info             t_exp_receipt_info,
      vt_inv_adj_inc_info             t_inv_adj_inc_info,
      vt_inv_arrival_info             t_inv_arrival_info,
      vt_exp_receipt_complete_info    t_exp_receipt_complete_info,
      vt_sku_info                     t_sku_info,
      vt_carrier_update_info          t_carrier_update_info,
      vt_inv_lost_info                t_inv_lost_info,
      vt_inv_adj_dcr_info             t_inv_adj_dcr_info,
      vt_inv_planned_mov_info         t_inv_planned_mov_info,
      vt_new_ship_ord_hdr_info        t_new_ship_ord_hdr_info,
      vt_new_ship_ord_item_inv_info   t_new_ship_ord_item_inv_info,
      vt_new_ship_ord_trail_info      t_new_ship_ord_trail_info,
      vt_ship_ord_prio_upd_info       t_ship_ord_prio_upd_info,
      vt_item_status_info             t_item_status_info,
      vt_picking_complete_info        t_picking_complete_info,
      vt_start_of_day_info            t_start_of_day_info,
      -- ctvgg000 Carrier Status Info record added 
      vt_carrier_status_info          t_carrier_status_info,
      vt_msg_status_info              t_msg_status_info,
      n_uom                           miniload_message.UOM%TYPE,
      v_prod_id                       miniload_message.prod_id%TYPE,
      v_cust_pref_vendor              miniload_message.cust_pref_vendor%TYPE,
      v_exp_date                      miniload_message.add_date%TYPE,
      n_length                        miniload_message.ml_data_len%TYPE,
      v_data                          miniload_message.ml_data%TYPE,
      v_status                        miniload_message.status%TYPE,
      v_trans_type                    trans.trans_type%TYPE,
      v_cmt                           miniload_trans.cmt%TYPE,
      v_sku                           VARCHAR2 (20),
      -- Added For HK Integration ctvgg000 
      -- miniload identifer  
      v_ml_system                     MINILOAD_CONFIG.ml_system%TYPE,
      -- 11/12/08 prpbcb Added n_msg_id
      n_msg_id                        miniload_message.message_id%TYPE       
   );

   PROCEDURE p_send_new_ship_ord_hdr (
      i_new_ship_ord_hdr_info   IN       t_new_ship_ord_hdr_info DEFAULT NULL,
      o_status                  OUT      NUMBER
   );

   PROCEDURE p_send_new_ship_ord_item_inv (
      i_new_ship_ord_item_inv_info   IN       t_new_ship_ord_item_inv_info
                                              DEFAULT NULL,
      o_status                 OUT      NUMBER,
      i_uom_conv_opt           IN       VARCHAR2 DEFAULT 'N'     -- 4/18/06
   );

   PROCEDURE p_send_new_ship_ord_trail (
      i_new_ship_ord_trail_info   IN   t_new_ship_ord_trail_info DEFAULT NULL,
      o_status                    OUT  NUMBER
   );

   PROCEDURE p_send_ship_ord_prio_upd (
      i_ship_ord_prio_upd_info  IN   t_ship_ord_prio_upd_info  DEFAULT NULL,
      o_status                  OUT  NUMBER
   );

   PROCEDURE p_new_sku (
      i_sku_info   IN       t_sku_info DEFAULT NULL,
      o_status     OUT      NUMBER
   );

   PROCEDURE p_modify_sku (
      i_sku_info   IN       t_sku_info DEFAULT NULL,
      o_status     OUT      NUMBER
   );

   PROCEDURE p_delete_sku (
      i_sku_info   IN       t_sku_info DEFAULT NULL,
      o_status     OUT      NUMBER
   );

   FUNCTION f_check_miniload_loc (
      i_plogi_loc          IN   INV.plogi_loc%TYPE,
      i_prod_id            IN   PM.prod_id%TYPE,
      i_cust_pref_vendor   IN   PM.cust_pref_vendor%TYPE,
      i_uom                IN   INV.inv_uom%TYPE
   )
      RETURN VARCHAR2;

   PROCEDURE p_send_exp_receipt (
      i_exp_receipt_info   IN       t_exp_receipt_info DEFAULT NULL,
      o_status             OUT      NUMBER,
      i_check_dup_flag     IN       VARCHAR2 DEFAULT 'Y'
   );

   PROCEDURE p_send_start_of_day (
      i_start_of_day_info   IN       t_start_of_day_info DEFAULT NULL,
      o_status              OUT      NUMBER
   );

   PROCEDURE p_inv_update_for_carrier (
      i_carrier_update_info   IN       t_carrier_update_info,
      o_status                OUT      NUMBER
   );

   PROCEDURE p_receive_msg;

   PROCEDURE p_rcv_inv_adj_inc
     (i_msg      IN       MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_id   IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_status   OUT      NUMBER);

   PROCEDURE p_rcv_inv_adj_dcr (
      i_msg      IN       MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_id   IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_status   OUT      NUMBER);

   PROCEDURE p_rcv_inv_arr
     (i_msg      IN       MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_id   IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_status   OUT      NUMBER);

   PROCEDURE p_rcv_inv_lost
     (i_msg      IN       MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_id   IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_status   OUT      NUMBER);

   PROCEDURE p_rcv_inv_planned_move 
     (i_msg      IN       MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_id   IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_status   OUT      NUMBER);

   PROCEDURE p_rcv_er_complete 
     (i_msg      IN       MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_id   IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_status   OUT      NUMBER);

   PROCEDURE p_insert_ml_pickcomplete (o_status OUT NUMBER);

   PROCEDURE p_picking_batch_process;

   PROCEDURE p_send_pending_pickcomp_msg
                        (o_status                OUT NUMBER,
                         i_order_start_date      IN  DATE    DEFAULT NULL,
                         i_only_list_records_bln IN  BOOLEAN DEFAULT FALSE);

   PROCEDURE p_picking_complete_for_carrier
     (i_picking_complete_info   IN       t_picking_complete_info DEFAULT NULL,
      o_status                  OUT      NUMBER);

   -- beg add
   -- For HK Integration ctvgg000
   -- Procedure to send Carrier Status Change 
   
   PROCEDURE p_send_carrier_status_change
     (i_carrier_status_info     IN       t_carrier_status_info DEFAULT NULL,
      o_status                  OUT      NUMBER);
   
   -- For HK Integration ctvgg000
   -- Procedure to receive Carrier Status Change      
   
   PROCEDURE p_rcv_msg_status 
     (i_msg      IN       MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_id   IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_status   OUT      NUMBER);
   
   -- end add

   PROCEDURE p_split_sku
     (i_sku                IN       VARCHAR2,
      o_uom                OUT      INV.inv_uom%TYPE,
      o_prod_id            OUT      PM.prod_id%TYPE,
      o_cust_pref_vendor   OUT      PM.cust_pref_vendor%TYPE,
      i_log_flag           IN       BOOLEAN DEFAULT TRUE);

   PROCEDURE p_convert_uom 
     (io_uom                      IN OUT   PUTAWAYLST.UOM%TYPE,
      io_quantity                 IN OUT   PUTAWAYLST.qty_expected%TYPE,
      i_prod_id                   IN       PUTAWAYLST.prod_id%TYPE,
      i_cust_pref_vendor          IN       PUTAWAYLST.cust_pref_vendor%TYPE,
      i_bln_check_ship_split_only IN       BOOLEAN DEFAULT FALSE);

   FUNCTION f_generate_sku 
     (i_uom                IN   MINILOAD_MESSAGE.UOM%TYPE,
      i_prod_id            IN   MINILOAD_MESSAGE.prod_id%TYPE,
      i_cust_pref_vendor   IN   MINILOAD_MESSAGE.cust_pref_vendor%TYPE)
   RETURN VARCHAR2;

   PROCEDURE p_insert_miniload_message 
     (i_miniload_info   IN       t_miniload_info,
      i_msg_type        IN       VARCHAR2,
      o_status          OUT      NUMBER,
      i_log_flag        IN       BOOLEAN DEFAULT TRUE);

   PROCEDURE p_insert_miniload_order 
     (i_miniload_info   IN       t_miniload_info DEFAULT NULL,
      i_msg_type        IN       VARCHAR2,
      o_status          OUT      NUMBER,
      i_log_flag        IN       BOOLEAN DEFAULT TRUE);

   PROCEDURE p_insert_miniload_exception 
     (i_miniload_info   IN       t_miniload_info DEFAULT NULL,
      i_msg_type        IN       MINILOAD_MESSAGE.message_type%TYPE,
      o_status          OUT      NUMBER);

   PROCEDURE p_insert_miniload_trans 
     (i_miniload_info   IN       t_miniload_info,
      i_msg_type        IN       MINILOAD_MESSAGE.message_type%TYPE,
      o_status          OUT      NUMBER);

   FUNCTION f_create_message 
      (i_miniload_info   IN   t_miniload_info DEFAULT NULL,
       i_msg_type        IN   VARCHAR2)
   RETURN VARCHAR2;

   FUNCTION f_parse_message 
     (i_msg        IN   MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_type   IN   MINILOAD_MESSAGE.message_type%TYPE,
      i_log_flag   IN   BOOLEAN DEFAULT TRUE)
   RETURN t_miniload_info;

   PROCEDURE p_upd_status 
     (i_msg_id       IN       MINILOAD_MESSAGE.message_id%TYPE,
      i_msg_type     IN       MINILOAD_MESSAGE.message_type%TYPE,
      i_msg_status   IN       MINILOAD_MESSAGE.status%TYPE,
      o_status       OUT      NUMBER,
      i_log_flag     IN       BOOLEAN DEFAULT TRUE);


   PROCEDURE p_rcv_item_status 
     (i_msg      IN       MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_id   IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_status   OUT      NUMBER);

   FUNCTION f_convert_to_splits 
     (i_uom                IN   PUTAWAYLST.UOM%TYPE,
      i_prod_id            IN   PUTAWAYLST.prod_id%TYPE,
      i_cust_pref_vendor   IN   PUTAWAYLST.cust_pref_vendor%TYPE,
      i_quantity           IN   PUTAWAYLST.qty_expected%TYPE,
      i_log_flag           IN   BOOLEAN DEFAULT TRUE)
      RETURN NUMBER;

   PROCEDURE p_process_ml_replen 
     (i_item_status_info   IN       t_item_status_info DEFAULT NULL,
      o_status             OUT      NUMBER);

   PROCEDURE p_create_highprio_order 
     (i_item_status_info   IN       t_item_status_info,
      o_status             OUT      NUMBER,
      i_uom_check          IN       VARCHAR2        DEFAULT 'N');

   PROCEDURE p_insert_replen 
     (i_ml_replenishment   IN       t_ml_replenishment,
      o_status             OUT      NUMBER);

   PROCEDURE p_histord_process;

   PROCEDURE p_create_ndmforminiload 
     (i_replenishment   IN       t_ml_replenishment,
      o_qty_moved       OUT      INV.qoh%TYPE,
      o_status          OUT      NUMBER);

   PROCEDURE p_insert_dummy_itm_status 
         (i_item_status IN      t_item_status_info,
          o_status      OUT     NUMBER);

    PROCEDURE p_insert_inv 
        (i_inv_info   IN       INV%ROWTYPE DEFAULT NULL,
         o_status     OUT      NUMBER);

   PROCEDURE resend_miniload_message
              (i_message_id         IN  MINILOAD_MESSAGE.message_id%TYPE,
               o_message_resent_bln OUT BOOLEAN,
               o_msg                OUT VARCHAR2);

   PROCEDURE can_ML_message_be_resent
          (i_message_id                IN  MINILOAD_MESSAGE.message_id%TYPE,
           o_message_can_be_resent_bln OUT BOOLEAN,
           o_msg                       OUT VARCHAR2);

   FUNCTION can_ML_message_be_resent
              (i_message_id         IN  MINILOAD_MESSAGE.message_id%TYPE)
      RETURN BOOLEAN;
  
  -- For HK Integration ctvgg000
  -- This function returns the miniload system 
  -- when prod_id and cust_pref_vendor are passed*/  
  
   FUNCTION f_find_ml_system 
          (i_prod_id           IN miniload_message.prod_id%TYPE,
           i_cust_pref_vendor  IN miniload_message.cust_pref_vendor%TYPE,
           i_zone_id           IN pm.zone_id%TYPE        DEFAULT NULL,
           i_split_zone_id     IN pm.split_zone_id%TYPE  DEFAULT NULL)
   RETURN VARCHAR2;
  -- end add

   FUNCTION f_get_ct_exp_rec 
      RETURN VARCHAR2;

   FUNCTION f_get_ct_new_sku 
      RETURN VARCHAR2;

   FUNCTION f_get_ct_modify_sku 
      RETURN VARCHAR2;

   FUNCTION f_get_ct_delete_sku 
      RETURN VARCHAR2;

   FUNCTION f_get_ct_inv_upd_carr 
      RETURN VARCHAR2;

   FUNCTION f_get_ct_success
      RETURN NUMBER;

   FUNCTION f_get_ct_failure
      RETURN NUMBER;

   FUNCTION f_get_ct_er_duplicate
      RETURN NUMBER;

   FUNCTION f_is_repl_necessary_for_order
                        (i_prod_id            IN  PM.prod_id%TYPE,
                         i_cust_pref_vendor   IN  PM.cust_pref_vendor%TYPE)
      RETURN BOOLEAN;

   FUNCTION f_is_repl_in_process_for_item
                        (i_prod_id                IN   pm.prod_id%TYPE,
                         i_cust_pref_vendor       IN   pm.cust_pref_vendor%TYPE,
                         o_high_prio_qty_avail    OUT  PLS_INTEGER)
      RETURN BOOLEAN;

   PROCEDURE p_create_missing_location 
               (i_loc_to_create  IN  LOC.logi_loc%TYPE,
                o_status         OUT NUMBER);


   ---------------------------------------------------------------------------
   -- PROCEDURE
   --    send_SKU_change
   --
   -- Description:
   --     This procedure send a new SKU message and/or a change SKU message to
   --     the miniloader depending on the values of the parameters.
   ---------------------------------------------------------------------------
   PROCEDURE send_SKU_change
                   (i_what_to_send         IN  PLS_INTEGER,
                    i_prod_id              IN  PM.prod_id%TYPE,
                    i_cust_pref_vendor     IN  PM.cust_pref_vendor%TYPE,
                    i_descrip              IN  PM.descrip%TYPE,
                    i_spc                  IN  PM.spc%TYPE,    
                    i_case_qty_per_carrier IN  PM.case_qty_per_carrier%TYPE,
                    i_cmt                  IN  MINILOAD_TRANS.cmt%TYPE,
                    i_zone_id               IN  PM.zone_id%TYPE,
                    i_split_zone_id           IN  PM.split_zone_id%TYPE,
                    o_status               OUT NUMBER);

---------------------------------------------------------------------------
-- Procedure:
--    do_not_send_dup_order_to_ml
--
-- Description:
--    This procedure prevents sending a duplicate regular order to the miniloader.
---------------------------------------------------------------------------
PROCEDURE do_not_send_dup_order_to_ml
   (i_order_id  IN  miniload_order.order_id%TYPE);

-- Charm6000002987- Added the below procedure 
PROCEDURE p_miniload_putaway_completion 
                                 (i_pallet_id IN PUTAWAYLST.PALLET_ID%type,
                                  o_status OUT number);
END pl_miniload_processing;
/

CREATE OR REPLACE PACKAGE BODY SWMS.pl_miniload_processing
AS
-- sccs_id=%Z% %W% %G% %I%
---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
   gl_pkg_name           VARCHAR2 (30) := 'pl_miniload_processing';
                                                   -- Package name.
                                                   --  Used in error messages.

---------------------------------------------------------------------------
-- Private Constants
---------------------------------------------------------------------------

   -- Application function for the log messages.
   ct_application_function   CONSTANT VARCHAR2 (9)  := 'INVENTORY';

   -- For starting a new line in the exception comment.
   ct_newline_char  VARCHAR2(1) := CHR(10);

   -- Number of latest miniload_messages and transactions to put in the
   -- the exception comment for a carrier.  The cmt can only hold 2000
   -- characters so these number should be kept low.
   ct_cmt_num_of_ml_messages       PLS_INTEGER := 5;
   ct_cmt_num_of_transactions      PLS_INTEGER := 5;

---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- FUNCTION
--    cmt_carrier_last_trans
--
-- Description:
--    This procedure builds a message that has the last few transactions for
--    a carrier.  The message is intended to be used in the exception 
--    comment and is meant to be displayed in a multi-line form field.
--    CHR(10) is the new line character.
--
--    Example value returned:
--  /        --- Last Transactions ---CHR(10)Item  TranCHR(10)       TypeCHR(10)
--          --------------CHR(10)1234567  MMACHR(10)1234567  MMA
--      It would display in the form like this:
--          --- Last Transactions ---
--         Item     Type
--         ----------------
--         1234567  MIA
--         1234567  MIA
--
-- Parameters:
--    i_pallet_id  - Carrier ID to get the last transactions for.
--
-- Exceptions Raised:
--    None
--
-- Called by:
--    build_exception_cmt
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/14/08 prpbcb   Created.
----------------------------------------------------------------------------
FUNCTION cmt_carrier_last_trans(i_pallet_id  IN  trans.pallet_id%TYPE)
RETURN VARCHAR2 
IS
   l_cmt                 miniload_exception.cmt%TYPE := NULL; -- Return value
   l_num_recs_fetched    PLS_INTEGER := 0;  -- Count of record fetched

   --
   -- The max heading length is 100 but limit the actual value to 80 so that
   -- it is displayed nicely in the screen.
   --
   l_heading_line_1  VARCHAR2(100);
   l_heading_line_2  VARCHAR2(100);
   l_heading_line_3  VARCHAR2(100);

   --
   -- This cursor selects the transactions for the carrier.
   -- 
   CURSOR c_trans(cp_pallet_id   trans.pallet_id%TYPE) IS
      SELECT t.trans_date                                   trans_date,
             t.trans_id                                     trans_id,
             TRIM(TO_CHAR(t.trans_date, 'MM/DD/YY HH24:MI:SS'))
             || ' '   || t.trans_type 
             || '  '  || t.prod_id
             || ' '   || t.cust_pref_vendor
             || '   ' || RPAD(NVL(t.src_loc, ' '), 10)
             || ' '   || RPAD(NVL(t.dest_loc, ' '), 10)
             || ' '
   || LPAD(TO_CHAR(DECODE(t.uom, 1, 0, TRUNC(t.qty / pm.spc)), '9999'), 5) || ' CS'
             || ' '
   || LPAD(TO_CHAR(DECODE(t.uom, 1, t.qty, MOD(t.qty, pm.spc)), '9999'), 5) || ' SP' cmt
        FROM pm, v_trans t
       WHERE t.pallet_id         = cp_pallet_id
         AND pm.prod_id          = t.prod_id
         AND pm.cust_pref_vendor = t.cust_pref_vendor
       ORDER BY t.trans_date desc, t.trans_id desc;

   r_trans  c_trans%ROWTYPE;  -- A record for the cursor.

BEGIN
   l_heading_line_1 := '***** LAST '
          || TRIM(TO_CHAR(ct_cmt_num_of_transactions))
          || ' TRANSACTIONS FOR CARRIER ' || i_pallet_id
          || ' AT TIME OF EXCEPTION *****';

   l_heading_line_2 :=
 'DATE              TYPE ITEM    CPV SRC LOC    DEST LOC          QTY';
   l_heading_line_3 :=
 '----------------- ---- ------- --- ---------- ---------- -----------------';

   -- Debug stuff
   -- DBMS_OUTPUT.PUT_LINE(l_heading_line_1);
   -- DBMS_OUTPUT.PUT_LINE(l_heading_line_2);
   -- DBMS_OUTPUT.PUT_LINE(l_heading_line_3);

   l_cmt := l_heading_line_1
            || ct_newline_char || l_heading_line_2
            || ct_newline_char || l_heading_line_3;

   OPEN c_trans(i_pallet_id);

   LOOP
      EXIT WHEN l_num_recs_fetched >= ct_cmt_num_of_transactions;
      FETCH c_trans INTO r_trans;
      EXIT WHEN c_trans%NOTFOUND;

      l_num_recs_fetched := l_num_recs_fetched + 1;
      l_cmt := l_cmt || ct_newline_char || r_trans.cmt;
  
      -- DBMS_OUTPUT.PUT_LINE(r_trans.cmt);  -- Debug stuff
   END LOOP;

   CLOSE c_trans;

   RETURN(l_cmt);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Write a log message but do not stop processing.
      --
      IF (c_trans%ISOPEN) THEN    -- Cursor cleanup
         CLOSE c_trans;
      END IF;

      pl_log.ins_msg(pl_lmc.ct_warn_msg,
                     'cmt_carrier_last_trans',
                     'Error processing i_pallet_id ' || i_pallet_id || '.'
                     || '  This error will not stop processing.',
                     SQLCODE,
                     SQLERRM,
                     ct_application_function,
                     gl_pkg_name);
   RETURN('cmt_carrier_last_trans: Error processing ' || i_pallet_id);
END cmt_carrier_last_trans;


-------------------------------------------------------------------------------
-- FUNCTION
--    cmt_carrier_last_ml_messages
--
-- Description:
--    This procedure builds a message that has the last few miniload messagess
--    for a carrier.  The message is intended to be used in the exception 
--    comment and is meant to be displayed in a multi-line form field.
--    CHR(10) is the new line character.
--
--    Example value returned:
--          --- Last Miniload Messages ---CHR(10)Item  LocnCHR(10)
--          --------------CHR(10)1234567  FR10A9CHR(10)1234567  FR10A3
--      It would display in the form like this:
--          --- Last Miniload Messages ---
--         Item     Loc
--         ----------------
--         1234567  FR10A9
--         1234567  FR10A3
--
-- Parameters:
--    i_pallet_id  - Carrier ID to get the last miniload messages for.
--
-- Exceptions Raised:
--    None
--
-- Called by:
--    build_exception_cmt
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/14/08 prpbcb   Created.
--    02/27/09 prpbcb   Fix order by.
--                      Was:
--                         ORDER BY mlm.add_date desc, mlm.add_date desc;
--                      Changed to;
--                         ORDER BY mlm.add_date desc, mlm.message_id desc;
--
----------------------------------------------------------------------------
FUNCTION cmt_carrier_last_ml_messages(i_pallet_id  IN  trans.pallet_id%TYPE)
RETURN VARCHAR2 
IS
   l_cmt                 miniload_exception.cmt%TYPE := NULL; -- Return value
   l_num_recs_fetched    PLS_INTEGER := 0;  -- Count of record fetched

   --
   -- The max heading length is 100 but limit the actual value to 80 so that
   -- it is displayed nicely in the screen.
   --
   l_heading_line_1  VARCHAR2(100);
   l_heading_line_2  VARCHAR2(100);
   l_heading_line_3  VARCHAR2(100);
   l_heading_line_4  VARCHAR2(100);

   --
   -- This cursor selects the transactions for the carrier.
   -- We want to fit the comment within 79 characters so we 
   -- abbreviated the message type.
   -- 
   CURSOR c_miniload_message
                 (cp_pallet_id   miniload_message.carrier_id%TYPE) IS
      SELECT mlm.add_date                                    add_date,
             mlm.message_id                                  message_id,
             TRIM(TO_CHAR(mlm.add_date, 'MM/DD/YY HH24:MI:SS'))
             || ' '  || RPAD(TRIM(TO_CHAR(mlm.message_id, '9999999')), 7)
             || ' '  || RPAD(
                         DECODE(mlm.message_type,
                               'DeleteSKU',                   'DelSKU',
                               'ExpectedReceipt',             'ExpRecpt',
                               'ExpectedReceiptComplete',     'ExpRecCm',
                               'InventoryAdjustmentIncrease', 'InvAdjIn',
                               'InventoryArrival',            'InvArr',
                               'InventoryPlannedMove',        'InvPlnMv',
                               'InventoryUpdateForCarrier',   'InvUpCa',
                               'ModifySKU',                   'ModSKU',
                               'NewSKU',                      'NewSKU',
                               'PickingCompleteForCarrier',   'PikCompl',
                               'StartOfDay',                  'StrtDay',
                               SUBSTR(mlm.message_type, 1, 8)), 8)
             || ' '  || RPAD(NVL(mlm.prod_id, ' '), 7)
             || ' '  || RPAD(NVL(TRIM(TO_CHAR(mlm.uom)), ' '), 1)
             || ' '
             || LPAD(NVL(TRIM(TO_CHAR(mlm.qty_expected, '999')), ' '), 3)
             || ' '
             || LPAD(NVL(TRIM(TO_CHAR(mlm.qty_received, '999')), ' '), 3)
             || ' ' || mlm.source_system
             || ' ' || mlm.status
             || ' '  || RPAD(NVL(mlm.source_loc, ' '), 6)
             || ' '  || RPAD(NVL(mlm.planned_loc, ' '), 6)
             || ' '  || RPAD(NVL(mlm.dest_loc, ' '), 6)    cmt
        FROM miniload_message mlm
       WHERE mlm.carrier_id = cp_pallet_id
       ORDER BY mlm.add_date desc, mlm.message_id desc;

   r_miniload_message  c_miniload_message%ROWTYPE;  -- A record for the cursor.

BEGIN
   l_heading_line_1 := '***** LAST '
          || TRIM(TO_CHAR(ct_cmt_num_of_ml_messages))
          || ' MINILOAD MESSAGES FOR CARRIER ' || i_pallet_id
          || ' AT TIME OF EXCEPTION *****';

   l_heading_line_2 :=
'                                           U QTY QTY SRC S SRC    PLAN   DEST';

   l_heading_line_3 :=
'DATE              MSG ID  MESSAGE  ITEM    M EXP RCV SYS T LOC    LOC    LOC';


   l_heading_line_4 :=
'----------------- ------- -------- ------- - --- --- --- - ------ ------ ------';

   -- Debug stuff
   -- DBMS_OUTPUT.PUT_LINE(l_heading_line_1);
   -- DBMS_OUTPUT.PUT_LINE(l_heading_line_2);
   -- DBMS_OUTPUT.PUT_LINE(l_heading_line_3);
   -- DBMS_OUTPUT.PUT_LINE(l_heading_line_4);

   l_cmt := l_heading_line_1
            || ct_newline_char || l_heading_line_2
            || ct_newline_char || l_heading_line_3
            || ct_newline_char || l_heading_line_4;

   OPEN c_miniload_message(i_pallet_id);

   LOOP
      EXIT WHEN l_num_recs_fetched >= ct_cmt_num_of_ml_messages;
      FETCH c_miniload_message INTO r_miniload_message;
      EXIT WHEN c_miniload_message%NOTFOUND;

      l_num_recs_fetched := l_num_recs_fetched + 1;
      l_cmt := l_cmt || ct_newline_char || r_miniload_message.cmt;
  
      -- DBMS_OUTPUT.PUT_LINE(r_miniload_message.cmt); -- Debug stuff
   END LOOP;

   CLOSE c_miniload_message;

   RETURN(l_cmt);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Write a log message but do not stop processing.
      --
      IF (c_miniload_message%ISOPEN) THEN    -- Cursor cleanup
         CLOSE c_miniload_message;
      END IF;

      pl_log.ins_msg(pl_lmc.ct_warn_msg,
                     'cmt_carrier_last_ml_messages',
                     'Error processing i_pallet_id ' || i_pallet_id || '.'
                     || '  This error will not stop processing.',
                     SQLCODE,
                     SQLERRM,
                     ct_application_function,
                     gl_pkg_name);
   RETURN('cmt_carrier_last_ml_messagse: Error processing ' || i_pallet_id);
END cmt_carrier_last_ml_messages;


-------------------------------------------------------------------------------
-- FUNCTION
--    build_exception_cmt
--
-- Description:
--    This procedure builds the comment for an exception.  It is to give
--    an explanation why a miniload message failed processing.
--
-- Parameters:
--    i_miniload_info - Miniload message data.
--    i_msg_type      - The message type being processed.
--    i_pallet_id     - The LP being processed.  This could be taken from
--                      i_miniload_info but knowing it at this point saves
--                      from having to extract it from i_miniload_info.
--
-- Exceptions Raised:
--    None
--
-- Called by:
--    p_insert_miniload_exception
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/14/08 prpbcb   Created.
----------------------------------------------------------------------------
FUNCTION build_exception_cmt
         (i_miniload_info   IN  t_miniload_info,
          i_msg_type        IN  miniload_message.message_type%TYPE,
          i_pallet_id       IN  loc.logi_loc%TYPE)
RETURN VARCHAR2 
IS
   l_cmt                   miniload_exception.cmt%TYPE := NULL; -- Return value

   --
   -- This cursor is used to check if the item exists.
   -- 
   CURSOR c_item(cp_prod_id           pm.prod_id%TYPE,
                 cp_cust_pref_vendor  pm.cust_pref_vendor%TYPE) IS
      SELECT pm.miniload_storage_ind       miniload_storage_ind
        FROM pm
       WHERE pm.prod_id          = cp_prod_id
         AND pm.cust_pref_vendor = cp_cust_pref_vendor;

   --
   -- This cursor is used to check for the carrier in inventory.  Inventory
   -- info is selected to put in the cmt if the carrier has a different
   -- item on it.
   -- 
   CURSOR c_inv(cp_pallet_id         inv.logi_loc%TYPE) IS
      SELECT i.prod_id                     inv_prod_id,
             i.cust_pref_vendor            inv_cust_pref_vendor,
             i.logi_loc                    inv_logi_loc,
             i.plogi_loc                   inv_plogi_loc,
             DECODE(i.inv_uom, 1, 0, TRUNC(i.qoh / pm.spc))  inv_qoh_cases,
             DECODE(i.inv_uom, 1, i.qoh, MOD(i.qoh, pm.spc)) inv_qoh_splits,
             i.status                      inv_status
        FROM pm, inv i
       WHERE i.logi_loc          = cp_pallet_id
         AND pm.prod_id          = i.prod_id
         AND pm.cust_pref_vendor = i.cust_pref_vendor;

   r_item c_item%ROWTYPE;
   r_inv c_inv%ROWTYPE;
BEGIN
   IF (   i_msg_type = ct_inv_plan_mov
       OR i_msg_type = ct_inv_arr) THEN
      --
      -- Inventory Planned Move
      -- Inventory Arrival
      --

      --
      -- Check if the item is valid.
      --
      OPEN c_item(i_miniload_info.v_prod_id,
                  i_miniload_info.v_cust_pref_vendor);
      FETCH c_item INTO r_item;

      IF (c_item%NOTFOUND) THEN
         l_cmt := 'ITEM ' || i_miniload_info.v_prod_id
            || ' CPV ' || i_miniload_info.v_cust_pref_vendor
            || ' IS NOT IN SWMS';
         CLOSE c_item;
      ELSE
         CLOSE c_item;
         --
         -- The item is valid.
         -- Check if the item is stored in the miniloader.
         --
         IF (r_item.miniload_storage_ind = 'N') THEN
            l_cmt := 'THIS ITEM IS NOT STORED IN THE MINILOADER.';
         ELSE
            --
            -- Look for the carrier in inventory.
            --
            OPEN c_inv(i_pallet_id);

            FETCH c_inv INTO r_inv;

            IF (c_inv%NOTFOUND) THEN
               l_cmt := 'CARRIER ' || i_pallet_id || ' IS NOT IN SWMS.';
               CLOSE c_inv;
            ELSE
               CLOSE c_inv;
               --
               -- The carrier is in inventory.
               -- Check if the carrier has another item on it.
               --
               IF (   r_inv.inv_prod_id <> i_miniload_info.v_prod_id
                   OR r_inv.inv_cust_pref_vendor <>
                                    i_miniload_info.v_cust_pref_vendor) THEN
                  l_cmt := 'SWMS HAS ITEM ' || r_inv.inv_prod_id
                        || ' CPV ' || r_inv.inv_cust_pref_vendor
                        || ' ON CARRIER ' || i_pallet_id 
                        || ' AT LOCATION '
                        || r_inv.inv_plogi_loc || '.';
               END IF;
            END IF;
         END IF;
      END IF;  -- end IF (c_item%NOTFOUND) THEN

      -- 
      -- Add to the exception comment the last few miniload messages
      -- and the last few transacations for the carrier.  This is
      -- to help the user determine why the miniload message failed.
      -- 
      l_cmt :=l_cmt || ct_newline_char || ct_newline_char
              || cmt_carrier_last_ml_messages(i_pallet_id)
              || ct_newline_char || ct_newline_char
              || cmt_carrier_last_trans(i_pallet_id);
   ELSE
      --
      -- No comment for i_msg_type.
      --
      NULL;
   END IF;

   RETURN(l_cmt);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Write a log message but do not stop processing.
      --
      pl_log.ins_msg(pl_lmc.ct_fatal_msg,
                     'build_exception_cmt',
                     'Error processing ' || i_msg_type,
                     SQLCODE,
                     SQLERRM,
                     ct_application_function,
                     gl_pkg_name);
   RETURN(l_cmt);
END build_exception_cmt;


---------------------------------------------------------------------------
-- Function:
--    f_boolean_text
--
-- Description:
--    This function returns the string TRUE or FALSE for a boolean.
--
-- Parameters:
--    i_boolean - Boolean value
--
-- Return Values:
--    'TRUE'  - When boolean is TRUE.
--    'FALSE' - When boolean is FALSE.
--
-- Exceptions Raised:
--    pl_exc.e_database_error  - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/21/06 prpbcb   Created.
--                      Should put in pl_common.sql.
--
---------------------------------------------------------------------------
   FUNCTION f_boolean_text (i_boolean IN BOOLEAN)
      RETURN VARCHAR2
   IS
      l_message       VARCHAR2 (256);                       -- Message buffer
      l_object_name   VARCHAR2 (61)  := gl_pkg_name || '.f_boolean_text';
   BEGIN
      IF (i_boolean)
      THEN
         RETURN ('TRUE');
      ELSE
         RETURN ('FALSE');
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name || '(i_boolean)';
         pl_log.ins_msg (pl_lmc.ct_fatal_msg,
                         l_object_name,
                         l_message,
                         SQLCODE,
                         SQLERRM);
         RAISE_APPLICATION_ERROR (Pl_Exc.ct_database_error,
                                  l_object_name || ': ' || SQLERRM
                                 );
   END f_boolean_text;

-------------------------------------------------------------------------------
-- FUNCTION
--    f_is_repl_necessary_for_order
--
-- Description:
--    This function determines if it is necessary to generate a case to
--    split replenishment for an item based on the qty ordered since the
--    last start of day and the current inventory and current replenishments
--    for the item.
--
--    It may be that an existing replenishment for a previous order will cover
--    the current order.
--
--    ************************************************************
--    This function should only be used for a split order.
--    ************************************************************
--
-- Parameters:
--    i_prod_id
--    i_cust_pref_vendor
--
-- Return Values:
--    TRUE    - It is necessary to create the repl.
--    FALSE   - It is not necessary which means there are existing repl(s)
--              with qty to cover the order.
--
-- Exceptions Raised:
--    The when others propagates the exception.
--
-- Called by:
--    - p_process_ml_replen
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/21/07 prpbcb   Created.
--                      For project:
--                         237485-Unnecessary miniloader split repl created
--                      It is not finished yet.  I did some of the work
--                      while the file was checked out for project
--                      "326211-Miniload Induction Qty Incorrect".
--
--    03/23/07 prpbcb   Finish for project
--                        "237485-Unnecessary miniloader split repl created".
--                      Cursor c_repl_qty is not used.  We will look at
--                      the split inventory including records with qty
--                      planned to determine the available splits.
--                      The qty planned records should tie back to a
--                      replenishment which is why we do not have to look
--                      at the actual replenishments.  Now if the qty planned
--                      and the actual replenishments are out of sync then
--                      we may not get the desired results.
--
--    06/13/13 prpbcb   Take into account orders that came down in the ML
--                      queue after the route was generated.  We are seeing
--                      instances where the order comes down during the day
--                      which is correct then comes down again after the
--                      route was generated.  Depending on the qoh a
--                      non-demand replenishment can get created for something
--                      thats already picked.  We do not want to create a
--                      non-demand replenishment for this situation since
--                      order generation would have created a demand
--                      replenishment if necessary.
--                      Changed cursor "c_total_splits_ordered" to exclude
--                      orders that have been picked.  This was done by
--                      looking at the ORDD records.  A more
--                      straight forward would be to match the order id
--                      in the PIK transaction to the the order id in
--                      MINILOAD_ORDER but this will not work for SAP OpCos
--                      because the order_id in MINILOAD_ORDER is the delivery
--                      document number and the order_id in the PIK transaction
--                      is the invoice number which are not the same.
--                      Another approach is to look at FLOAT_DETAIL instead
--                      of ORDD but FLOAT_DETAIL does not have an index on
--                      prod_id which would results on full table scans
--                      of FLOAT_DETAIL.
--                      
----------------------------------------------------------------------------
   FUNCTION f_is_repl_necessary_for_order
                        (i_prod_id            IN  PM.prod_id%TYPE,
                         i_cust_pref_vendor   IN  PM.cust_pref_vendor%TYPE)
      RETURN BOOLEAN
   IS
      l_object_name            VARCHAR2 (30)
                                           := 'f_is_repl_necessary_for_order';

      l_prod_id                pm.prod_id%TYPE;
      l_total_qty_splits       PLS_INTEGER;
      l_total_splits_ordered   PLS_INTEGER;
      l_splits_still_to_pick   PLS_INTEGER;
      l_return_value_bln       BOOLEAN;
      l_high_prio_qty_avail    PLS_INTEGER;

      --
      -- This cursor sums the total case --> split replenishments for an item.
      -- Priority 20 replenishments will always be for case --> split
      -- replenishments.
      --
      -- We only want to look at replenishments created since the last start
      -- of day.  If for some reason there is not a start of day then 3 AM
      -- will be used.
      --
      --
      -- 03/16/07  Brian Bent  This cursor is not used.
      --
      /***********
      CURSOR c_repl_qty IS
         SELECT NVL(SUM(DECODE(r.uom, 1, qty, pm.spc * r.qty)), 0) sum_repl_qty
           FROM inv, pm, replenlst r
          WHERE pm.prod_id            = r.prod_id
            AND pm.cust_pref_vendor   = r.cust_pref_vendor
            AND r.prod_id             = i_prod_id
            AND r.cust_pref_vendor    = i_cust_pref_vendor
            AND r.type                = 'MNL'
            AND r.priority            = 20
            AND inv.prod_id           = r.prod_id
            AND inv.cust_pref_vendor  = r.cust_pref_vendor
            AND inv.logi_loc          = r.pallet_id
            AND r.add_date >=
                      (SELECT NVL(MAX(add_date), TRUNC(SYSDATE) + 3/24)
                         FROM miniload_message
                        WHERE message_type = CT_START_OF_DAY);
      ***********/

      --
      -- This cursor gets a count of the splits ordered for the day minus
      -- what has been picked.
      -- It leaves out high priority store orders and history orders because
      -- we do not want to include these since they are not actual orders.
      -- If for some reason there is not a start of day then 3 AM will be used.
      -- Note: SUS may send the same order multiple times so this is
      --       accounted for.
      --
      -- 06/13/2013  prpbcb Changed to use MAX(message_id) instead of
      -- MAX(ROWID) when getting the latest order for the item.  MAX(ROWID)
      -- may not return the last record which is fine except if the qty is
      -- different between the records.
      --
      -- Do not include split orders that have been picked which will be
      -- determined by looking at the ORDD table.  See the Modification
      -- History for an explanation why the ORDD table was used.
      --   
      --
      CURSOR c_total_splits_ordered
      IS
         SELECT mo.prod_id,
                NVL(SUM(NVL(mo.quantity_requested,0)), 0) total_splits_ordered,
                NVL(SUM(NVL(mo.quantity_requested, 0)), 0)
                      - NVL((SELECT NVL(SUM(NVL(d.qty_ordered, 0)), 0)
                               FROM ordd d
                              WHERE d.prod_id = mo.prod_id
                                AND d.status <> 'NEW'
                                AND d.uom = 1
                              GROUP BY d.prod_id), 0)  splits_still_to_pick
           FROM pm, miniload_order mo
          WHERE mo.message_type     = ct_ship_ord_inv
            AND pm.prod_id          = mo.prod_id
            AND pm.cust_pref_vendor = mo.cust_pref_vendor
            AND mo.prod_id          = i_prod_id
            AND mo.cust_pref_vendor = i_cust_pref_vendor
            AND mo.uom              = 1
            AND mo.add_date >=
                       (SELECT NVL(MAX(add_date), TRUNC(SYSDATE) + 3 / 24)
                          FROM miniload_message m
                         WHERE m.message_type = ct_start_of_day)
            AND mo.message_id =      -- Do not count the same order more than once.
                   (SELECT MAX(message_id)
                      FROM miniload_order mo2
                     WHERE mo2.message_type     = mo.message_type
                       AND mo2.prod_id          = mo.prod_id
                       AND mo2.cust_pref_vendor = mo.cust_pref_vendor
                       AND mo2.order_id         = mo.order_id
                       AND mo2.order_item_id    = mo.order_item_id
                       AND mo2.uom              = mo.uom)
            AND NOT EXISTS       -- Do not include high priority store orders
                                 -- since these are not actual orders.
                  (SELECT 'x'
                     FROM priority_code pc, miniload_order mo_high
                    WHERE mo_high.message_type    = ct_ship_ord_hdr
                      AND mo_high.order_id        = mo.order_id
                      AND mo_high.order_priority  = pc.priority_value
                      AND pc.priority_code        = 'HGH')
            AND NOT EXISTS                   -- Do not include history orders.
                  (SELECT 'x'
                     FROM miniload_order moh_hist
                    WHERE moh_hist.message_type = ct_ship_ord_hdr
                      AND moh_hist.order_id     = mo.order_id
                      AND moh_hist.order_type   = ct_history_order)
          GROUP BY mo.prod_id;

      --
      -- This cursor gets the total splits in inventory for an item thats
      -- available for a split pick.
      -- The inventory record for a pending replenishment to the induction
      -- location will have qty planned and is considered as available.
      -- A split inventory record should not have qty alloc so a check is
      -- is made for this as qty alloc != 0 makes this record suspect.
      --
      -- 06/13/2013  prpbcb Bug fix  The inventory for a pending non-demand
      -- split replenishment from the main warehouse to the miniloader for
      -- an item with cases in the main warehouse and splits in the miniloader
      -- was not being taken into account.
      -- Fixed this by joining to the LOC table and PM table to select any MLS
      -- split slot and to check the miniload_storage_ind so that we include
      -- the inventory for the pending split replenishment.
      -- The pending inventory at the induction location
      -- will have a UOM of 2 until the replenishment is completed at which
      -- time the UOM is updated to 1.
      --
      CURSOR c_total_qty_splits
      IS
         SELECT NVL(SUM(i.qoh + i.qty_planned), 0)
           FROM loc, pm, inv i
          WHERE i.prod_id            = i_prod_id
            AND i.cust_pref_vendor   = i_cust_pref_vendor
            AND (   i.inv_uom        = 1
                 OR pm.miniload_storage_ind = 'S')        -- Brian Bent Added 6/18/2013
            AND i.qty_alloc          = 0
            AND i.status             = 'AVL'  -- Brian Bent  Added 2/16/2011
            AND pm.prod_id           = i.prod_id          -- Brian Bent Added 6/18/2013
            AND pm.cust_pref_vendor  = i.cust_pref_vendor -- Brian Bent Added 6/18/2013
            AND loc.logi_loc         = i.plogi_loc        -- Brian Bent Added 6/18/2013
            AND loc.slot_type = 'MLS';                    -- Brian Bent Added 6/18/2013

   BEGIN
      --
      -- If splits available >= total splits ordered then no replenishment is
      -- necessary.
      --
      -- No need to check for not found on the cursors because the cursors will
      -- always select one row.
      --

      --
      -- Get the splits ordered for the current day.
      --
      OPEN c_total_splits_ordered;

      FETCH c_total_splits_ordered
       INTO l_prod_id, l_total_splits_ordered, l_splits_still_to_pick;

      CLOSE c_total_splits_ordered;

      --
      -- Mon Aug 18 18:18:17 CDT 2014  Brian Bent
      -- Was fetching null values though I thought the select would return 0.
      -- So to work around this I assigned the values to 0 if null.
      --
      IF (l_total_splits_ordered IS NULL) THEN
         l_total_splits_ordered := 0;
      END IF;

      IF (l_splits_still_to_pick IS NULL) THEN
         l_splits_still_to_pick := 0;
      END IF;

      --
      -- Get the splits available in inventory.
      --
      OPEN c_total_qty_splits;

      FETCH c_total_qty_splits
       INTO l_total_qty_splits;

      CLOSE c_total_qty_splits;

      pl_log.ins_msg
           ('INFO',
            l_object_name,
            ' After selecting quantities.'
            || '  Item<' || i_prod_id || '>'
            || '  CPV<' || i_cust_pref_vendor || '>'
            || '  Splits available in inventory<'
            || TO_CHAR (l_total_qty_splits) || '>'
            || '  Splits ordered<'
            || TO_CHAR (l_total_splits_ordered) || '>'
            || '  Splits still to pick<'
            || TO_CHAR (l_splits_still_to_pick) || '>',
            NULL,
            NULL,
            ct_application_function,
            gl_pkg_name
           );

      --
      -- Check the splits available in inventory against the splits ordered.
      --
      -- 07/30/2014  Brian Bent
      -- Take into account what is already picked.
      -- Changed
      --    IF (l_total_qty_splits >= l_total_splits_ordered) THEN
      -- to
      --    IF (l_total_qty_splits >= l_splits_still_to_pick) THEN
      --
      IF (l_total_qty_splits >= l_splits_still_to_pick) THEN
         --
         -- The split inventory qoh + qty planned is >= the splits ordered
         -- for the day so a case to split replenishment is not necessary.
         --
         l_return_value_bln := FALSE;
      ELSE
         l_return_value_bln := TRUE;
         IF f_is_repl_in_process_for_item (i_prod_id, 
                                           i_cust_pref_vendor, 
                                           l_high_prio_qty_avail) THEN
            pl_log.ins_msg
               ('INFO',
                l_object_name,
                ' After call to f_is_repl_in_process_for_item()'
                || '  Item<' || i_prod_id || '>'
                || '  CPV<' || i_cust_pref_vendor || '>'
                || '  High priority qty available<'
                || TO_CHAR (l_high_prio_qty_avail) || '>',                     
                NULL,
                NULL,
                ct_application_function,
                gl_pkg_name
               );
            IF (l_total_qty_splits + l_high_prio_qty_avail >= l_splits_still_to_pick) THEN
               l_return_value_bln := FALSE;
            END IF;
         END IF;   
      END IF;

      RETURN (l_return_value_bln);
   EXCEPTION
      WHEN OTHERS THEN
         -- Log the error.
         pl_text_log.ins_msg ('FATAL',
                              l_object_name,
                              'Error',
                              SQLCODE,
                              SQLERRM);
         pl_log.ins_msg ('FATAL',
                         l_object_name,
                         'Error',
                         SQLCODE,
                         SQLERRM,
                         ct_application_function,
                         gl_pkg_name);
         RAISE;
   END f_is_repl_necessary_for_order;


-------------------------------------------------------------------------------
-- FUNCTION
--    is_repl_in_process_for_order
--
-- Description:
--    This function determines if the case to split replenishment process
--    has started for an item on an order.
--    If it has then TRUE is returned otherwise FALSE is returned.
--
--    This is done by checking if the item and order has a 
--    Shipping order Item Status record with status = 'I'
--
-- Parameters:
--    i_r_item_status_info  - Shipping order Item Status record sent
--                            by the miniloader.
--
-- Return Values:
--    TRUE    - The order has a replenishment in process.
--    FALSE   - The order does not have a replenishment in process.
--
-- Exceptions Raised:
--    The when others propagates the exception.
--
-- Called by:
--    - p_process_ml_replen
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/17/11 prpbcb   Created.
--                      Project:
----------------------------------------------------------------------------
FUNCTION is_repl_in_process_for_order
                        (i_r_item_status_info   IN  t_item_status_info)
RETURN BOOLEAN
IS
   l_object_name         VARCHAR2(30)  := 'is_repl_in_process_for_order';
   l_message             VARCHAR2(256);  -- Message buffer

   l_message_id          miniload_order.message_id%TYPE;  -- Work area
   l_return_value_bln    BOOLEAN;

   --
   -- This cursor looks for a Shipping Order Item Status message with
   -- status 'I'.  An 'I' status indicates the replenishment process has
   -- started for the item and SWMS is waiting for the miniloader to drop a
   -- high priority store order to the pick face.
   --
   CURSOR c_repl_process_started
   IS
      SELECT message_id
        FROM miniload_order mo
       WHERE mo.message_type     = ct_ship_ord_status
         AND mo.order_id         = i_r_item_status_info.v_order_id
         AND mo.order_item_id    = i_r_item_status_info.v_order_item_id
         AND mo.prod_id          = i_r_item_status_info.v_prod_id
         AND mo.cust_pref_vendor = i_r_item_status_info.v_cust_pref_vendor
         AND mo.uom              = i_r_item_status_info.n_uom
         AND mo.status           = 'I'
         AND mo.add_date >=   -- Check from the start of day.  If no start of
                              -- day then use 3 AM.
                    (SELECT NVL(MAX(add_date), TRUNC (SYSDATE) + 3 / 24)
                       FROM miniload_message m
                      WHERE m.message_type = ct_start_of_day);
BEGIN
   OPEN c_repl_process_started;

   FETCH c_repl_process_started INTO l_message_id;
   
   IF (c_repl_process_started%FOUND) THEN
      l_return_value_bln := TRUE;
      l_message := 'Found Shipping Order Item Status with ''I'' status.'
                   || '  Message ID<' || l_message_id || '>';
   ELSE
      l_return_value_bln := FALSE;
      l_message := 'Did not find "Shipping Order Item Status"'
           || ' with ''I'' status.';
   END IF;

   CLOSE c_repl_process_started;

   pl_log.ins_msg
           ('INFO',
            l_object_name,
            'Order<' || i_r_item_status_info.v_order_id || '>'
            || '  Order Item ID<' || i_r_item_status_info.v_order_item_id || '>'
            || '  Item<' || i_r_item_status_info.v_prod_id || '>'
            || '  CPV<' || i_r_item_status_info.v_cust_pref_vendor || '>'
            || '  Qty Requested<' || TO_CHAR( i_r_item_status_info.n_quantity_requested) || '>'
            || '  Qty Available<' || TO_CHAR(i_r_item_status_info.n_quantity_available) || '>'
            || '  UOM<' || TO_CHAR(i_r_item_status_info.n_uom) || '>'
            || '  ' || l_message,
            NULL,
            NULL,
            ct_application_function,
            gl_pkg_name);

   RETURN (l_return_value_bln);
EXCEPTION
   WHEN OTHERS THEN
      -- Log the error.
      pl_text_log.ins_msg ('FATAL',
                           l_object_name,
                           'Error',
                           SQLCODE,
                           SQLERRM);
      pl_log.ins_msg ('FATAL',
                      l_object_name,
                      'Error',
                      SQLCODE,
                      SQLERRM,
                      ct_application_function,
                      gl_pkg_name);
      RAISE;
END is_repl_in_process_for_order;

-------------------------------------------------------------------------------
-- FUNCTION
--    f_is_repl_in_process_for_item
--
-- Description:
--    Given an item, this function determines if there is a high priority 
--    store order for the item. If so, the function will calculate how many 
--    splits will be left over from the current high priority orders sent to
--    the miniloader (to drop cases to the pick face). The left over split qty
--    can potentially be used by the next order for the item w/o the need
--    to drop another case to the pick face.
--    For example, if a customer order needs 2 splits and a high priority 
--    store order is sent to drop a case containing 10 splits, then there
--    will be 8 splits left over. If another order needs 3 splits, we don't
--    need to send another request to the miniloader to drop another case.
--    The left over 8 splits will cover the 3 splits needed.
--
-- Parameters:
--    i_prod_id, 
--    i_cust_pref_vendor, 
--    o_high_prio_qty_avail: split qty that will be left over from
--       current high priority orders sent to miniloader to drop cases
--       to pick face. This qty will be calculated and made available to
--       the calling routine.
--
-- Return Values:
--    TRUE    - There are pending high priority orders and there will be
--              some left-over split qty from those orders. The
--              left over split qty will be returned to the calling
--              routine as an out parameter.
--    FALSE   - There are no pending high priority orders, or there will
--              be no left over split qty from them.
--
-- Exceptions Raised:
--    The when others propagates the exception.
--
-- Called by: (please do a search to find all instances)
--
-- Modification History:
--    Date         Designer   Comments
--    -----------  --------   ---------------------------------------------------
--    06-APR-2017  P. Kabran  Created to fix bug where SWMS did not check
--                            pending high priority orders for item before 
--                            sending more high priority orders to
--                            miniloader.
---------------------------------------------------------------------------------
FUNCTION f_is_repl_in_process_for_item
                        (i_prod_id                IN   pm.prod_id%TYPE,
                         i_cust_pref_vendor       IN   pm.cust_pref_vendor%TYPE,
                         o_high_prio_qty_avail    OUT  PLS_INTEGER)
RETURN BOOLEAN
IS
   l_object_name         VARCHAR2(30)  := 'f_is_repl_in_process_for_item';
   l_message             VARCHAR2(256); 

   l_return_value_bln       BOOLEAN;
   l_spc                    pm.spc%TYPE;
   l_miniload_storage_ind   pm.miniload_storage_ind%TYPE;
   l_qty_short              PLS_INTEGER;

   CURSOR c_splits_short_for_item
   IS
      SELECT mo.order_id,
             NVL(mo.quantity_requested, 0) quantity_requested, 
             NVL(mo.quantity_available, 0) quantity_available
      FROM miniload_order mo
      WHERE mo.message_type      = ct_ship_ord_status
         AND mo.prod_id          = i_prod_id
         AND mo.cust_pref_vendor = i_cust_pref_vendor
         AND mo.uom              = 1
         AND mo.status           IN ('I', 'N', 'S')
         AND NVL(mo.quantity_requested, 0) > NVL(mo.quantity_available, 0)
         AND mo.add_date >=   -- Check from the start of day. If no start of
                              -- day then use 3 AM.
             (SELECT NVL(MAX(add_date), TRUNC(SYSDATE) + 3 / 24)
              FROM miniload_message m
              WHERE m.message_type = ct_start_of_day);

   CURSOR c_high_prio_order_for_item
   IS
      SELECT  mo.order_id, NVL(mo.quantity_requested, 0) quantity_requested
      FROM miniload_order mo
      WHERE mo.message_type      = ct_ship_ord_inv
         AND mo.prod_id          = i_prod_id
         AND mo.cust_pref_vendor = i_cust_pref_vendor
         AND mo.uom              = 2
         AND mo.sku_priority     = 0
         AND mo.status           <> 'F'
         AND mo.add_date >=   -- Check from the start of day.  If no start of
                              -- day then use 3 AM.
             (SELECT NVL(MAX(add_date), TRUNC (SYSDATE) + 3 / 24)
              FROM miniload_message m
              WHERE m.message_type = ct_start_of_day)
         AND EXISTS (SELECT mo2.order_id
                     FROM miniload_order mo2
                     WHERE mo2.message_type = ct_ship_ord_hdr
                        AND mo2.status <> 'F'
                        AND mo2.order_id = mo.order_id
                        AND mo2.order_priority =
                               (SELECT priority_value
                                FROM priority_code
                                WHERE priority_code = 'HGH'
                                AND unpack_code = 'Y'));

BEGIN
   l_return_value_bln := FALSE;
   o_high_prio_qty_avail := 0;
   l_qty_short := 0;

   SELECT spc, miniload_storage_ind
      INTO l_spc, l_miniload_storage_ind
   FROM pm
   WHERE prod_id = i_prod_id
      AND cust_pref_vendor = i_cust_pref_vendor;
 
   IF l_spc IS NULL OR l_spc < 1 THEN
      RETURN l_return_value_bln;
   END IF;

   IF l_miniload_storage_ind = 'B' THEN      -- splits and cases are in miniloader
      FOR r_splits_short IN c_splits_short_for_item LOOP
         l_qty_short := l_qty_short + (r_splits_short.quantity_requested - 
                                       r_splits_short.quantity_available);
      END LOOP;
      l_message := 'Item <' || i_prod_id || '> ' 
                   || 'Miniload storage ind <' || l_miniload_storage_ind || '> '
                   || 'Split qty short <' || l_qty_short || '> ';
   ELSE
      l_message := 'Item <' || i_prod_id || '> ' 
                   || 'Miniload storage ind <' || l_miniload_storage_ind || '> ';
   END IF;

   pl_log.ins_msg
           ('INFO',
            l_object_name,
            l_message,
            NULL,
            NULL,
            ct_application_function,
            gl_pkg_name);

   IF l_qty_short > 0 THEN
      FOR r_high_prio IN c_high_prio_order_for_item LOOP
         l_message := ' High Prio order_id <' || r_high_prio.order_id 
                      || '> Splits ordered <' || r_high_prio.quantity_requested * l_spc || '> ';
         o_high_prio_qty_avail := o_high_prio_qty_avail + r_high_prio.quantity_requested * l_spc;
         pl_log.ins_msg
                 ('INFO',
                  l_object_name,
                  l_message,
                  NULL,
                  NULL,
                  ct_application_function,
                  gl_pkg_name);
      END LOOP;
      l_message := 'Total qty on high prio order <' || o_high_prio_qty_avail || '> ';
      o_high_prio_qty_avail := o_high_prio_qty_avail - l_qty_short;
      l_message := l_message || 'Left over high prio split qty <' || o_high_prio_qty_avail || '> ';
      IF o_high_prio_qty_avail >= 0 THEN
         l_return_value_bln := TRUE;
      END IF;
   END IF;

   pl_log.ins_msg
           ('INFO',
            l_object_name,
            l_message,
            NULL,
            NULL,
            ct_application_function,
            gl_pkg_name);

   RETURN l_return_value_bln;
EXCEPTION
   WHEN OTHERS THEN
      -- Log the error.
      pl_text_log.ins_msg ('FATAL',
                           l_object_name,
                           'Error',
                           SQLCODE,
                           SQLERRM);
      pl_log.ins_msg ('FATAL',
                      l_object_name,
                      'Error',
                      SQLCODE,
                      SQLERRM,
                      ct_application_function,
                      gl_pkg_name);
      RAISE;
END f_is_repl_in_process_for_item;

---------------------------------------------------------------------------------
-- PROCEDURE 
--    p_create_missing_location
--
-- Description:
--    The purpose of this procedure is to create a location in SWMS when the
--    location is in the miniload but missing in SWMS. It adds the location 
--    to loc and lzone.
--
--    The validation of the new location is not very strict. 
--    The only validation is that the aisle has to exist. 
--
-- Parameters:
--    i_loc_to_create: the location to create.
--    o_status: will be set accordingly depending on success or failure.
--       early in the procedure, it is set to ct_success. It will
--       change to ct_failure only if there is a problem/failure.
--
-- Modification History:
--    Date         Designer     Comments
--    -----------  ----------   ------------------------------------------------
--    04-OCT-2017  P. Kabran    Created 
--------------------------------------------------------------------------------
PROCEDURE p_create_missing_location 
             (i_loc_to_create  IN  LOC.logi_loc%TYPE,
              o_status         OUT NUMBER)
IS

   l_object_name       VARCHAR2(30)  := 'p_create_missing_location';
   l_message           VARCHAR2(256);

   l_count             PLS_INTEGER := 0;
   l_pik_aisle         LOC.pik_aisle%TYPE;
   l_pik_slot          LOC.pik_slot%TYPE;
   l_pik_level         LOC.pik_level%TYPE;
   l_pik_path          LOC.pik_path%TYPE;
   l_aisle_side        LOC.aisle_side%TYPE;
   l_floor_height      LOC.floor_height%TYPE;
   l_slot_height       LOC.slot_height%TYPE;
   l_true_slot_height  LOC.true_slot_height%TYPE;
   l_available_height  LOC.available_height%TYPE;
   l_occupied_height   LOC.occupied_height%TYPE;
   l_liftoff_height    LOC.liftoff_height%TYPE;
   l_width_positions   LOC.width_positions%TYPE;
   l_rack_label_type   LOC.rack_label_type%TYPE;
   l_pallet_type       LOC.pallet_type%TYPE;
   l_cube              LOC.cube%TYPE;
   l_loc_level         VARCHAR2(1);
   l_similar_loc       LOC.logi_loc%TYPE;
   l_pik_zone_id       LZONE.zone_id%TYPE;
   l_put_zone_id       LZONE.zone_id%TYPE;
   l_loc_aisle         VARCHAR2(2);
   l_found_similar_loc BOOLEAN := FALSE;
                                        
BEGIN
   o_status := ct_success;

   l_message := 'Attempting to create location <' || i_loc_to_create || '>';
   pl_log.ins_msg
     ('INFO',
      l_object_name,
      l_message,
      NULL,
      NULL,
      ct_application_function,
      gl_pkg_name);

   SELECT COUNT(logi_loc)
      INTO l_count
   FROM loc
   WHERE logi_loc = i_loc_to_create;

   IF l_count > 0 THEN
      l_message := 'location <' 
                   || i_loc_to_create 
                   || '> already exists';
      pl_log.ins_msg
        ('INFO',
         l_object_name,
         l_message,
         NULL,
         NULL,
         ct_application_function,
         gl_pkg_name);
      RETURN;
   END IF;

   -- if the aisle does not exists, do not create the location.

   l_loc_aisle := SUBSTR(i_loc_to_create, 1, 2);

   SELECT COUNT(logi_loc)
      INTO l_count
   FROM loc
   WHERE slot_type = 'MLS' 
      AND SUBSTR(logi_loc, 1, 2) = l_loc_aisle
      AND rownum = 1;

   IF (l_count <= 0) THEN
      l_message := 'No miniload location found in aisle <'
                   || l_loc_aisle
                   || '>. Cannot create new location.';
      pl_log.ins_msg
        ('INFO',
         l_object_name,
         l_message,
         NULL,
         NULL,
         ct_application_function,
         gl_pkg_name);

      o_status := ct_failure;
      RETURN;
   END IF;
 
   -- calculate some of the location attributes

   BEGIN
      l_pik_aisle := ((ASCII(SUBSTR(i_loc_to_create, 1, 1)) - ASCII('A') + 1) * 100) 
                    + (ASCII(SUBSTR(i_loc_to_create, 2, 1)) - ASCII('A') + 1);

      IF (l_pik_aisle < 0) THEN
         l_pik_aisle := 999;
      END IF;

   EXCEPTION
      WHEN OTHERS THEN
         l_pik_aisle := 999;
   END;

   BEGIN
      l_pik_slot := (TO_NUMBER(SUBSTR(i_loc_to_create, 3, 2)) * 10) 
                   + (ASCII(SUBSTR(i_loc_to_create, 5, 1)) - ASCII('A') + 1);

      IF (l_pik_slot < 0) THEN
         l_pik_slot := 999;
      END IF;

   EXCEPTION
      WHEN OTHERS THEN
         l_pik_slot := 999;
   END;

   BEGIN
      l_loc_level := SUBSTR(i_loc_to_create, 6, 1);

      IF (l_loc_level BETWEEN '0' AND '9') THEN
         l_pik_level := TO_NUMBER(l_loc_level);
      ELSE
         l_pik_level := (ASCII(l_loc_level) - ASCII('A')) + 10;
      END IF;

      IF (l_pik_level < 0) THEN
         l_pik_level := 999;
      END IF;

   EXCEPTION
      WHEN OTHERS THEN
         l_pik_level := 999;
   END;

   BEGIN
      SELECT DECODE(MOD(SUBSTR(i_loc_to_create, 3, 2), 2), 0, 'E', 'O')
         INTO l_aisle_side
      FROM DUAL;

   EXCEPTION
      WHEN OTHERS THEN
         l_aisle_side := 'O';  -- default to odd
   END;

   l_pik_path := TO_NUMBER(LPAD(TO_CHAR(l_pik_aisle), 3, '0') 
                        || LPAD(TO_CHAR(l_pik_slot), 3, '0')  
                        || LPAD(TO_CHAR(l_pik_level), 3, '0'));

   BEGIN
      SELECT logi_loc, floor_height, slot_height, true_slot_height, 
             available_height, occupied_height, liftoff_height,
             width_positions, rack_label_type, pallet_type, cube
         INTO l_similar_loc, l_floor_height, l_slot_height, l_true_slot_height, 
              l_available_height, l_occupied_height, l_liftoff_height,
              l_width_positions, l_rack_label_type, l_pallet_type, l_cube
      FROM loc
      WHERE slot_type = 'MLS'
         AND pik_aisle = l_pik_aisle
         AND pik_level = l_pik_level
         AND SUBSTR(logi_loc, 6, 1) = l_loc_level
         AND aisle_side = l_aisle_side
         AND rownum = 1;

   -- we found a similar location to use for certain attributes
   l_found_similar_loc := TRUE;  

   EXCEPTION
      WHEN OTHERS THEN
         l_found_similar_loc := FALSE;  

   END;

   IF (l_found_similar_loc = FALSE) THEN
      BEGIN
         SELECT logi_loc, floor_height, slot_height, true_slot_height, 
                available_height, occupied_height, liftoff_height,
                width_positions, rack_label_type, pallet_type, cube
            INTO l_similar_loc, l_floor_height, l_slot_height, l_true_slot_height, 
                 l_available_height, l_occupied_height, l_liftoff_height,
                 l_width_positions, l_rack_label_type, l_pallet_type, l_cube
         FROM loc
         WHERE slot_type = 'MLS'
            AND pik_aisle = l_pik_aisle
            AND pik_level = l_pik_level
            AND aisle_side = l_aisle_side
            AND rownum = 1;

      -- we found a similar location to use for certain attributes
      l_found_similar_loc := TRUE;  

      EXCEPTION
         WHEN OTHERS THEN
            l_found_similar_loc := FALSE;  

      END;
   END IF;

   IF (l_found_similar_loc = FALSE) THEN
      BEGIN
         SELECT logi_loc, floor_height, slot_height, true_slot_height, 
                available_height, occupied_height, liftoff_height,
                width_positions, rack_label_type, pallet_type, cube
            INTO l_similar_loc, l_floor_height, l_slot_height, l_true_slot_height, 
                 l_available_height, l_occupied_height, l_liftoff_height,
                 l_width_positions, l_rack_label_type, l_pallet_type, l_cube
         FROM loc
         WHERE slot_type = 'MLS'
            AND rownum = 1;

      -- we found a similar location to use for certain attributes
      l_found_similar_loc := TRUE;  

      EXCEPTION
         WHEN OTHERS THEN
            l_found_similar_loc := FALSE;  

      END;
   END IF;

   IF (l_found_similar_loc = FALSE) THEN
      l_message := 'No location found to copy some needed attributes.'
                   || ' Cannot create location.';
      pl_log.ins_msg
        ('INFO',
         l_object_name,
         l_message,
         NULL,
         NULL,
         ct_application_function,
         gl_pkg_name);

      o_status := ct_failure;
      RETURN;
   END IF;

   l_message := 'Found location <' 
                || l_similar_loc 
                || '> to use for certain attributes.';
   pl_log.ins_msg
     ('INFO',
      l_object_name,
      l_message,
      NULL,
      NULL,
      ct_application_function,
      gl_pkg_name);

   -- get PIK and PUT zones for location
   BEGIN
      -- get PIK zone
      SELECT lz.zone_id
         INTO l_pik_zone_id
      FROM lzone lz, zone z
      WHERE lz.logi_loc = l_similar_loc
         AND lz.zone_id = z.zone_id
         AND z.zone_type = 'PIK';

      -- get PUT zone
      SELECT lz.zone_id
         INTO l_put_zone_id
      FROM lzone lz, zone z
      WHERE lz.logi_loc = l_similar_loc
         AND lz.zone_id = z.zone_id
         AND z.zone_type = 'PUT'
         AND z.rule_id = 3;  -- PUT rule id for miniload

   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_message := 'Location <' 
                      || l_similar_loc 
                      || '> has NO PIK/PUT zone';
         pl_log.ins_msg
           ('INFO',
            l_object_name,
            l_message,
            NULL,
            NULL,
            ct_application_function,
            gl_pkg_name);

         o_status := ct_failure;
         RETURN;

      WHEN TOO_MANY_ROWS THEN
         l_message := 'Location <' 
                      || l_similar_loc 
                      || '> has more than 1 PIK/PUT zone';
         pl_log.ins_msg
           ('INFO',
            l_object_name,
            l_message,
            NULL,
            NULL,
            ct_application_function,
            gl_pkg_name);

         o_status := ct_failure;
         RETURN;

      WHEN OTHERS THEN
         -- log the error.
         pl_text_log.ins_msg ('FATAL',
                              l_object_name,
                              'Error',
                              SQLCODE,
                              SQLERRM);
         pl_log.ins_msg ('FATAL',
                         l_object_name,
                         'Error',
                         SQLCODE,
                         SQLERRM,
                         ct_application_function,
                         gl_pkg_name);
         o_status := ct_failure;
         RETURN;

   END; -- get pik and put zones

   -- insert into loc
   INSERT INTO loc
      (logi_loc,
       slot_type,
       pallet_type,
       cube,
       aisle_side,
       status,
       perm,
       uom,
       rank,
       pik_aisle,
       pik_slot,
       pik_level,
       pik_path,
       put_aisle,
       put_slot,
       put_level,
       put_path,
       rack_label_type,
       floor_height,
       slot_height,
       true_slot_height,
       available_height,
       occupied_height,
       liftoff_height,
       width_positions)
   VALUES
      (i_loc_to_create,
       'MLS',
       l_pallet_type,
       l_cube,
       l_aisle_side,
       'AVL',
       'N',
       NULL,
       NULL,
       l_pik_aisle,
       l_pik_slot,
       l_pik_level,
       l_pik_path,
       l_pik_aisle,
       l_pik_slot,
       l_pik_level,
       l_pik_path,
       l_rack_label_type,
       l_floor_height,
       l_slot_height,
       l_true_slot_height,
       l_available_height,
       l_occupied_height,
       l_liftoff_height,
       l_width_positions);

   -- insert into lzone
   INSERT INTO lzone
      (logi_loc, zone_id)
   VALUES
      (i_loc_to_create, l_pik_zone_id);

   INSERT INTO lzone
      (logi_loc, zone_id)
   VALUES
      (i_loc_to_create, l_put_zone_id);

   -- location was successfully created

   COMMIT;
   l_message := 'Location <' 
                || i_loc_to_create 
                || '> successfully created.';
   pl_log.ins_msg
     ('INFO',
      l_object_name,
      l_message,
      NULL,
      NULL,
      ct_application_function,
      gl_pkg_name);

EXCEPTION
   WHEN OTHERS THEN
      -- roll back
      ROLLBACK;

      -- log the error.
      pl_text_log.ins_msg ('FATAL',
                           l_object_name,
                           'Error',
                           SQLCODE,
                           SQLERRM);
      pl_log.ins_msg ('FATAL',
                      l_object_name,
                      'Error',
                      SQLCODE,
                      SQLERRM,
                      ct_application_function,
                      gl_pkg_name);
      o_status := ct_failure;
      RETURN;

END p_create_missing_location;

-------------------------------------------------------------------------
-- Procedure:
--    p_send_new_ship_ord_hdr
--
-- Description:
--     The procedure to send 'New Shipping Order Header' message
--
-- Parameters:
--    i_new_ship_ord_hdr_info  - record holding 'new ship order header msg'
--    i_msg_type - Type of message
--   o_status - return value
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
   PROCEDURE p_send_new_ship_ord_hdr (
      i_new_ship_ord_hdr_info   IN       t_new_ship_ord_hdr_info DEFAULT NULL,
      o_status                  OUT      NUMBER
   )
   IS
      l_miniload_info   t_miniload_info := NULL;
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)   := 'P_SEND_NEW_SHIP_ORD_HDR';
      ln_status         NUMBER (1)      := ct_success;
      e_fail            EXCEPTION;
--Hold return status of functions
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_send_new_ship_ord_hdr');
      l_miniload_info.vt_new_ship_ord_hdr_info := i_new_ship_ord_hdr_info;
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Type: '
         || l_miniload_info.vt_new_ship_ord_hdr_info.v_msg_type
         || ' Order Id: '
         || l_miniload_info.vt_new_ship_ord_hdr_info.v_order_id;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

      IF (l_miniload_info.vt_new_ship_ord_hdr_info.v_order_type NOT IN
                                           (ct_store_order, ct_history_order)
         )
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Invalid Order Type'
            || l_miniload_info.vt_new_ship_ord_hdr_info.v_order_type
            || ' Order Type needs to be either Store or History';
         RAISE e_fail;
      END IF;

      IF (l_miniload_info.vt_new_ship_ord_hdr_info.v_order_type =
                                                                ct_store_order
         )
      THEN
         l_miniload_info.vt_new_ship_ord_hdr_info.v_order_date := NULL;
      END IF;

      l_miniload_info.v_data :=
                           f_create_message (l_miniload_info, ct_ship_ord_hdr);
      lv_msg_text :=
         'Prog Code: ' || ct_program_code || ' Msg : '
         || l_miniload_info.v_data;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      p_insert_miniload_order (l_miniload_info, ct_ship_ord_hdr, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_order';
         RAISE e_fail;
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_send_new_ship_ord_hdr';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_send_new_ship_ord_hdr;

-------------------------------------------------------------------------
-- Procedure:
--    p_send_new_ship_ord_item_inv
--
-- Description:
--     The procedure to send 'New Shipping Order Item By Inventory' message
--
-- Parameters:
--    i_new_ship_ord_hdr_info  - record holding New Shipping Order Item
--                                     By Inventory' message
--    i_msg_type - Type of message
--   o_status - output status
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
   PROCEDURE p_send_new_ship_ord_item_inv (
      i_new_ship_ord_item_inv_info   IN       t_new_ship_ord_item_inv_info
            DEFAULT NULL,
      o_status                       OUT      NUMBER,
      i_uom_conv_opt                 IN       VARCHAR2 DEFAULT 'N'  -- 4/18/06
   )
   IS
      l_miniload_info   t_miniload_info := NULL;
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)   := 'P_SEND_NEW_SHIP_ORD_ITEM_INV';
      ln_status         NUMBER (1)      := ct_success;
      e_fail            EXCEPTION;
--Hold return status of functions
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_send_new_ship_ord_item_inv');
      l_miniload_info.vt_new_ship_ord_item_inv_info :=
                                                 i_new_ship_ord_item_inv_info;

      IF (i_uom_conv_opt = 'Y')
      THEN
         p_convert_uom
            (l_miniload_info.vt_new_ship_ord_item_inv_info.n_uom,
             l_miniload_info.vt_new_ship_ord_item_inv_info.n_qty,
             l_miniload_info.vt_new_ship_ord_item_inv_info.v_prod_id,
             l_miniload_info.vt_new_ship_ord_item_inv_info.v_cust_pref_vendor
            );
      END IF;

      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Type: '
         || l_miniload_info.vt_new_ship_ord_item_inv_info.v_msg_type
         || ' Order Id: '
         || l_miniload_info.vt_new_ship_ord_item_inv_info.v_order_id
         || ' Prod Id: '
         || l_miniload_info.vt_new_ship_ord_item_inv_info.v_prod_id
         || ' CPV: '
         || l_miniload_info.vt_new_ship_ord_item_inv_info.v_cust_pref_vendor
         || ' UOM: '
         || l_miniload_info.vt_new_ship_ord_item_inv_info.n_uom
         || ' Qty: '
         || l_miniload_info.vt_new_ship_ord_item_inv_info.n_qty
         || ' SKU priority: '
         || l_miniload_info.vt_new_ship_ord_item_inv_info.n_sku_priority;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      l_miniload_info.v_sku :=
         f_generate_sku
             (l_miniload_info.vt_new_ship_ord_item_inv_info.n_uom,
              l_miniload_info.vt_new_ship_ord_item_inv_info.v_prod_id,
              l_miniload_info.vt_new_ship_ord_item_inv_info.v_cust_pref_vendor
             );
      l_miniload_info.v_data :=
                           f_create_message (l_miniload_info, ct_ship_ord_inv);
      lv_msg_text :=
         'Prog Code: ' || ct_program_code || ' Msg : '
         || l_miniload_info.v_data;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      p_insert_miniload_order (l_miniload_info, ct_ship_ord_inv, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_order';
         RAISE e_fail;
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         Pl_Text_Log.ins_msg ('FATAL',
                              lv_fname,
                              lv_msg_text,
                              SQLCODE,
                              SQLERRM
                             );
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_send_new_ship_ord_item_inv';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_send_new_ship_ord_item_inv;

-------------------------------------------------------------------------
-- Proedure:
--    p_send_new_ship_ord_trail
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
   PROCEDURE p_send_new_ship_ord_trail (
      i_new_ship_ord_trail_info   IN       t_new_ship_ord_trail_info
            DEFAULT NULL,
      o_status                    OUT      NUMBER
   )
   IS
      l_miniload_info   t_miniload_info := NULL;
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)   := 'P_SEND_NEW_SHIP_ORD_TRAIL';
      ln_status         NUMBER (1)      := ct_success;
      e_fail            EXCEPTION;
--Hold return status of functions
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_send_new_ship_ord_trail');
      l_miniload_info.vt_new_ship_ord_trail_info := i_new_ship_ord_trail_info;
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Type: '
         || l_miniload_info.vt_new_ship_ord_trail_info.v_msg_type
         || ' Order Id: '
         || l_miniload_info.vt_new_ship_ord_trail_info.v_order_id;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      l_miniload_info.v_data :=
                           f_create_message (l_miniload_info, ct_ship_ord_trl);
      lv_msg_text :=
         'Prog Code: ' || ct_program_code || ' Msg : '
         || l_miniload_info.v_data;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      p_insert_miniload_order (l_miniload_info, ct_ship_ord_trl, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_order';
         RAISE e_fail;
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_send_new_ship_ord_trail';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_send_new_ship_ord_trail;

-------------------------------------------------------------------------
-- Procedure:
--    p_send_ship_ord_prio_upd
--
-- Description:
--     The Procedure to send 'Shipping Order Priority Update' message
--
-- Parameters:
--    i_ship_ord_prio_upd_info  - record holding 'Shipping Order Priority
--                                           Update' message
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
--    12/01/05          Created as part of the mini-load changes
---------------------------------------------------------------------------
   PROCEDURE p_send_ship_ord_prio_upd (
      i_ship_ord_prio_upd_info   IN       t_ship_ord_prio_upd_info
            DEFAULT NULL,
      o_status                   OUT      NUMBER
   )
   IS
      l_miniload_info   t_miniload_info := NULL;
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)   := 'P_SHIP_ORD_PRIO_UPD';
      ln_status         NUMBER (1)      := ct_success;
      e_fail            EXCEPTION;
--Hold return status of functions
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_send_ship_ord_prio_upd');
      l_miniload_info.vt_ship_ord_prio_upd_info := i_ship_ord_prio_upd_info;
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Type: '
         || l_miniload_info.vt_ship_ord_prio_upd_info.v_msg_type
         || ' Order Id: '
         || l_miniload_info.vt_ship_ord_prio_upd_info.v_order_id
         || ' Order Prio: '
         || l_miniload_info.vt_ship_ord_prio_upd_info.n_order_priority;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      l_miniload_info.v_data :=
                          f_create_message (l_miniload_info, ct_ship_ord_prio);
      lv_msg_text :=
         'Prog Code: ' || ct_program_code || ' Msg : '
         || l_miniload_info.v_data;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      p_insert_miniload_order (l_miniload_info, ct_ship_ord_prio, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_order';
         RAISE e_fail;
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_send_ship_ord_prio_upd';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_send_ship_ord_prio_upd;

-------------------------------------------------------------------------
-- Procedure:
--    p_new_sku
--
-- Description:
--     This procedure Sends the information about a new SKU.
--
-- Parameters:
--    i_sku_info  - Information to describe the SKU.
--    o_status - return status
--          0  - No errors.
--          1  - Error occured
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/29/05          Created as part of the mini-load changes
-------------------------------------------------------------------------
   PROCEDURE p_new_sku (
      i_sku_info   IN       t_sku_info DEFAULT NULL,
      o_status     OUT      NUMBER
   )
   IS
      l_miniload_info   t_miniload_info;
      ln_status         NUMBER (1)      := ct_success;
      --Hold return status of functions
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)   := 'P_NEW_SKU';
      e_fail            EXCEPTION;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_new_sku');
      l_miniload_info.vt_sku_info := i_sku_info;

      IF (l_miniload_info.vt_sku_info.n_uom = 0)
      THEN
         l_miniload_info.vt_sku_info.n_uom := 2;
      END IF;

      l_miniload_info.v_sku :=
         f_generate_sku (l_miniload_info.vt_sku_info.n_uom,
                         l_miniload_info.vt_sku_info.v_prod_id,
                         l_miniload_info.vt_sku_info.v_cust_pref_vendor
                        );
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Type: '
         || l_miniload_info.vt_sku_info.v_msg_type
         || ' SKU: '
         || l_miniload_info.v_sku;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      l_miniload_info.v_data := f_create_message (l_miniload_info, ct_new_sku);
      lv_msg_text :=
         'Prog Code: ' || ct_program_code || ' Msg : '
         || l_miniload_info.v_data;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      p_insert_miniload_message (l_miniload_info, ct_new_sku, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_message';
         RAISE e_fail;
      END IF;

      l_miniload_info.v_trans_type := 'MNI';
      p_insert_miniload_trans (l_miniload_info, ct_new_sku, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_trans';
         RAISE e_fail;
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
            'Prog Code: ' || ct_program_code
            || ' Error in executing p_new_sku';
         Pl_Text_Log.ins_msg ('FATAL',
                              lv_fname,
                              lv_msg_text,
                              SQLCODE,
                              SQLERRM
                             );
         o_status := ct_failure;
   END p_new_sku;

-------------------------------------------------------------------------
-- Procedure:
--    p_modify_sku
--
-- Description:
--     This procedure Sends the information about a change in an existing SKU.
--
-- Parameters:
--    i_sku_info  - Information to describe the SKU.
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
--    11/29/05          Created as part of the mini-load changes
-------------------------------------------------------------------------
   PROCEDURE p_modify_sku (
      i_sku_info   IN       t_sku_info DEFAULT NULL,
      o_status     OUT      NUMBER
   )
   IS
      l_miniload_info   t_miniload_info;
      ln_status         NUMBER (1)      := ct_success;
      --Hold return status of functions
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)   := 'P_MODIFY_SKU';
      e_fail            EXCEPTION;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_modify_sku');
      l_miniload_info.vt_sku_info := i_sku_info;

      IF (l_miniload_info.vt_sku_info.n_uom = 0)
      THEN
         l_miniload_info.vt_sku_info.n_uom := 2;
      END IF;

      l_miniload_info.v_sku :=
         f_generate_sku (l_miniload_info.vt_sku_info.n_uom,
                         l_miniload_info.vt_sku_info.v_prod_id,
                         l_miniload_info.vt_sku_info.v_cust_pref_vendor
                        );
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Type: '
         || l_miniload_info.vt_sku_info.v_msg_type
         || ' SKU: '
         || l_miniload_info.v_sku;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      l_miniload_info.v_data :=
                             f_create_message (l_miniload_info, ct_modify_sku);
      lv_msg_text :=
         'Prog Code: ' || ct_program_code || ' Msg : '
         || l_miniload_info.v_data;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      p_insert_miniload_message (l_miniload_info, ct_modify_sku, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_message';
         RAISE e_fail;
      END IF;

      l_miniload_info.v_trans_type := 'MMI';
      p_insert_miniload_trans (l_miniload_info, ct_modify_sku, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_trans';
         RAISE e_fail;
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_modify_sku';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_modify_sku;

-------------------------------------------------------------------------
-- Procedure:
--    p_delete_sku
--
-- Description:
--     This procedure Sends the information about deletion of a SKU.
--
-- Parameters:
--    i_sku_info  - Information to describe the SKU.
--   o_status - return status
--          0  - No errors.
--          1  - Error occured
--
-- Exceptions Raised:
--   e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/29/05          Created as part of the mini-load changes
-------------------------------------------------------------------------
   PROCEDURE p_delete_sku (
      i_sku_info   IN       t_sku_info DEFAULT NULL,
      o_status     OUT      NUMBER
   )
   IS
      l_miniload_info   t_miniload_info;
      ln_status         NUMBER (1)      := ct_success;
      --Hold return status of functions
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)   := 'P_DELETE_SKU';
      e_fail            EXCEPTION;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_delete_sku');
      l_miniload_info.vt_sku_info := i_sku_info;

      IF (l_miniload_info.vt_sku_info.n_uom = 0)
      THEN
         l_miniload_info.vt_sku_info.n_uom := 2;
      END IF;

      l_miniload_info.v_sku :=
         f_generate_sku (l_miniload_info.vt_sku_info.n_uom,
                         l_miniload_info.vt_sku_info.v_prod_id,
                         l_miniload_info.vt_sku_info.v_cust_pref_vendor
                        );
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Type: '
         || l_miniload_info.vt_sku_info.v_msg_type
         || ' SKU: '
         || l_miniload_info.v_sku;         
         
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      l_miniload_info.v_data :=
                             f_create_message (l_miniload_info, ct_delete_sku);
      lv_msg_text :=
         'Prog Code: ' || ct_program_code || ' Msg: '
         || l_miniload_info.v_data;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      p_insert_miniload_message (l_miniload_info, ct_delete_sku, ln_status);
        
      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_message';
         RAISE e_fail;
      END IF;

      l_miniload_info.v_trans_type := 'MDI';
      p_insert_miniload_trans (l_miniload_info, ct_delete_sku, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_trans';
         RAISE e_fail;
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
                 'Prog Code: ' || ct_program_code || ' Error in p_delete_sku';
         Pl_Text_Log.ins_msg ('FATAL',
                              lv_fname,
                              lv_msg_text,
                              SQLCODE,
                              SQLERRM
                             );
         o_status := ct_failure;
   END p_delete_sku;

-------------------------------------------------------------------------------
-- Function:
--    f_check_miniload_loc
--
-- Description:
--    This function checks if the scanned location is mini-load induction
--    location.
--
-- Parameters:
--    i_plogi_loc        - Physical location of the inventory.
--    i_prod_id          - Product id.
--    i_cust_pref_vendor - Customer preferred vendor (CPV).
--
-- Return Values:
--    'I' - INVALID LOCATION
--    'Y' - VALID MINI-LOAD LOCATION
--    'N' - NOT A MINI-LOAD ITEM(ERROR)
--
-- Exceptions Raised:
--       e_not_ml_item - When item is not a mini-load item
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/28/05          Created as part of the mini-load changes.
----------------------------------------------------------------------------
   FUNCTION f_check_miniload_loc (
      i_plogi_loc          IN   INV.plogi_loc%TYPE,
      i_prod_id            IN   PM.prod_id%TYPE,
      i_cust_pref_vendor   IN   PM.cust_pref_vendor%TYPE,
      i_uom                IN   INV.inv_uom%TYPE
   )
      RETURN VARCHAR2
   IS
      lv_miniload_ind           VARCHAR2 (1)         := 'I';
      lv_ind_loc                INV.plogi_loc%TYPE;
      lv_miniload_storage_ind   VARCHAR2 (1);
      lv_fname                  VARCHAR2 (50)       := 'F_CHECK_MINILOAD_LOC';
      lv_msg_text               VARCHAR2 (1500);
      ln_status                 NUMBER (6)           := ct_success;
                                                            -- SQL error code
      e_not_ml_item             EXCEPTION;
   BEGIN
      -- Check if the item is a mini-load or not.
      lv_miniload_storage_ind :=
              Pl_Ml_Common.f_get_miniload_ind (i_prod_id, i_cust_pref_vendor);

      IF (lv_miniload_storage_ind = 'N')
      THEN
         lv_miniload_ind := 'N';
         RAISE e_not_ml_item;
      END IF;

      Pl_Ml_Common.get_induction_loc (i_prod_id,
                                      i_cust_pref_vendor,
                                      i_uom,
                                      ln_status,
                                      lv_ind_loc
                                     );

      IF (ln_status = ct_no_data_found)
      THEN
         RETURN 'N';
      ELSIF (ln_status <> ct_success)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in getting Induction Location for the Prod_id: '
            || i_prod_id;
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         RETURN 'I';
      END IF;

      lv_msg_text :=
          'Prog Code: ' || ct_program_code || ' Induction Loc: ' || lv_ind_loc;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

      IF (lv_ind_loc = i_plogi_loc)
      THEN
         lv_miniload_ind := 'Y';
      ELSE
         lv_miniload_ind := 'I';
         lv_msg_text :=
                  'Invalid Induction Location for the Prod_id: ' || i_prod_id;
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
      END IF;

      RETURN lv_miniload_ind;
   EXCEPTION
      WHEN e_not_ml_item
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Not a mini-load item :'
            || i_prod_id;
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         RETURN lv_miniload_ind;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in f_check_miniload_loc'
            || i_prod_id;
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         lv_miniload_ind := 'N';
         RETURN lv_miniload_ind;
   END f_check_miniload_loc;

--------------------------------------------------------------------------------
-- PROCEDURE
--    p_send_exp_receipt
--
-- Description:
--     This procedure sends the expected receipt message.
--
-- Parameters:
--       i_exp_receipt_info - Record type containing expected receipt
--                            related fields.
--       o_status  - Return status from the function.
--                   The values are:
--                      CT_SUCCESS      - The expected receipt created
--                                        successfully.
--                      CT_ER_DUPLICATE - The expected receipt already exists
--                                        for the LP.
--                      CT_FAILURE      - Some type of error occurred.
--
-- Exceptions Raised:
--    No exceptions are propagated out.  o_status will be set to CT_FAILURE
--    when an error occurs.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -------------------------------------------------------
--    11/28/05          Created as part of the mini-load changes.
--    08/02/06          Added TRUE parameter in call to p_convert_uom.
--    10/17/06 prpbcb   Added checking the UOM when determining if an
--                      expected receipt already exists for an LP.
--                      We ran into some unexpected situations at OpCo 293
--                      where we had pallets at the induction location with
--                      cases that needed to be inducted the item was not
--                      splittable and an expected reciept existed but was
--                      for splits.
--    05/08/11 prpbcb   Add additional criitera in the where clause
--                      when checking if the expected receipt already exists.
--                      It should have been like this all along.
--                      Added:
--          AND prod_id          = l_miniload_info.vt_exp_receipt_info.v_prod_id
--          AND cust_pref_vendor = l_miniload_info.vt_exp_receipt_info.v_cust_pref_vendor
--          AND uom              = l_miniload_info.vt_exp_receipt_info.n_uom
--          AND qty_expected     = l_miniload_info.vt_exp_receipt_info.n_qty_expected
--          AND add_date         <= (SYSDATE - (20 / (60 * 24)));
-------------------------------------------------------------------------------
   PROCEDURE p_send_exp_receipt
     (i_exp_receipt_info   IN       t_exp_receipt_info DEFAULT NULL,
      o_status             OUT      NUMBER,
      i_check_dup_flag     IN       VARCHAR2 DEFAULT 'Y')
   IS
      l_dummy           NUMBER          := ct_success;
      l_miniload_info   t_miniload_info := NULL;
      lv_msg_type       VARCHAR2 (50)   := ct_exp_rec;
      lv_fname          VARCHAR2 (50)   := 'P_SEND_EXP_RECEIPT';
      lv_msg_text       VARCHAR2 (1500);
      ln_status         NUMBER (1)      := ct_success;
      e_duplicate       EXCEPTION;
      e_fail            EXCEPTION;
   BEGIN
      --
      -- Reset the global variable used for logging.
      --
      Pl_Text_Log.init ('pl_miniload_processing.p_send_exp_receipt');
      --
      -- Copy i_exp_receipt_info record into the
      -- l_miniload_info.vt_exp_receipt_info record.
      --
      l_miniload_info.vt_exp_receipt_info := i_exp_receipt_info;

      --
      -- Check if the expected receipt is already present in the
      -- MINILOAD_MESSAGE table.
      -- 5/8/2011 Brian Bent Only look back 2 minutes.
      --                     Maybe we should just not worry
      --                     about if one already exists as it
      --                     does no harm in resending another one.
      --                     We are having issues where sometimes
      --                     the ER is not created for a DMD
      --                     which is one reason why maybe we should
      --                     not check if the ER already exists.
      --
      IF i_check_dup_flag = 'Y'
      THEN
         SELECT COUNT (*)
           INTO l_dummy
           FROM miniload_message
          WHERE expected_receipt_id =
                     l_miniload_info.vt_exp_receipt_info.v_expected_receipt_id
            AND message_type     = ct_exp_rec
            AND status           IN ('S', 'N')
            AND prod_id          = l_miniload_info.vt_exp_receipt_info.v_prod_id
            AND cust_pref_vendor = l_miniload_info.vt_exp_receipt_info.v_cust_pref_vendor
            AND uom              = l_miniload_info.vt_exp_receipt_info.n_uom
            AND qty_expected     = l_miniload_info.vt_exp_receipt_info.n_qty_expected
            AND add_date         >= (SYSDATE - (2 / (60 * 24)));

         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Count of exp_recpt msgs sent for pallet_id '
            || l_miniload_info.vt_exp_receipt_info.v_expected_receipt_id
            || ': '
            || l_dummy;
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

         IF (l_dummy > 0) THEN
            --
            -- An expected receipt already exists for the LP.
            --
            RAISE e_duplicate;
         END IF;
      ELSE
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' check for duplicate expected receipts not done. '
            || l_miniload_info.vt_exp_receipt_info.v_expected_receipt_id
            || ': '
            || l_dummy;
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      END IF;

      --
      -- Call the procedure p_convert_uom for uom and quantity processing.
      --
      p_convert_uom (l_miniload_info.vt_exp_receipt_info.n_uom,
                     l_miniload_info.vt_exp_receipt_info.n_qty_expected,
                     l_miniload_info.vt_exp_receipt_info.v_prod_id,
                     l_miniload_info.vt_exp_receipt_info.v_cust_pref_vendor,
                     TRUE
                    );

      --
      -- If i_exp_receipt_info.v_inv_date is null then, put SYSDATE.
      --
      IF (l_miniload_info.vt_exp_receipt_info.v_inv_date IS NULL)
      THEN
         l_miniload_info.vt_exp_receipt_info.v_inv_date := SYSDATE;
      END IF;

      --
      -- Generate SKU.
      --
      l_miniload_info.v_sku :=
         f_generate_sku
                       (l_miniload_info.vt_exp_receipt_info.n_uom,
                        l_miniload_info.vt_exp_receipt_info.v_prod_id,
                        l_miniload_info.vt_exp_receipt_info.v_cust_pref_vendor
                       );
      --
      -- Create the message to be sent.
      --
      l_miniload_info.v_data :=
                               f_create_message (l_miniload_info, lv_msg_type);
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Type: '
         || lv_msg_type
         || ' Pallet Id: '
         || l_miniload_info.vt_exp_receipt_info.v_expected_receipt_id
         || ' Msg: '
         || l_miniload_info.v_data;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      p_insert_miniload_message (l_miniload_info, lv_msg_type, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_message';
         RAISE e_fail;
      END IF;

      o_status := ln_status;
   EXCEPTION
      WHEN e_duplicate THEN
         --
         -- The expected receipt already exists for the LP.  If the user is
         -- in form  mm3sa.fmb  where they can create an expected receipt
         -- then the user needs to resend it and not create new one.  Or the
         -- user needs to create an ER with a new LP.
         --
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Expected Receipt already sent';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_er_duplicate;
      WHEN e_fail THEN
         --
         -- Have some type of error.
         --
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in sending expected receipt message';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_send_exp_receipt;

-------------------------------------------------------------------------
-- Procedure:
--    p_send_start_of_day
--
-- Description:
--     The procedure to send 'Start Of Day' message
--
-- Parameters:
--    i_start_of_day_info  - record holding 'Start Of Day' message
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
--    12/02/05          Created as part of the mini-load changes
---------------------------------------------------------------------------
   PROCEDURE p_send_start_of_day (
      i_start_of_day_info   IN       t_start_of_day_info DEFAULT NULL,
      o_status              OUT      NUMBER
   )
   IS
      l_miniload_info   t_miniload_info := NULL;
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)   := 'P_SEND_START_OF_DAY';
      ln_status         NUMBER (1)      := ct_success;
      --Hold o_status := status of functions
      e_fail            EXCEPTION;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_send_start_of_day');
      l_miniload_info.vt_start_of_day_info := i_start_of_day_info;

      IF (l_miniload_info.vt_start_of_day_info.v_order_date IS NULL)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in processing Start of Day Message: Order Date is not given.'
            || ' StartOfDay message not sent';
         RAISE e_fail;
      END IF;

      l_miniload_info.v_data :=
                           f_create_message (l_miniload_info, ct_start_of_day);
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Type: '
         || l_miniload_info.vt_start_of_day_info.v_msg_type
         || ' Msg: '
         || l_miniload_info.v_data;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      p_insert_miniload_message (l_miniload_info, ct_start_of_day, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_message';
         RAISE e_fail;
      END IF;

      l_miniload_info.v_trans_type := 'MEP';
      p_insert_miniload_trans (l_miniload_info, ct_start_of_day, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_trans';
         RAISE e_fail;
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_send_start_of_day';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_send_start_of_day;

-------------------------------------------------------------------------------
-- Procedure:
--    p_inv_update_for_carrier
--
-- Description:
--     This procedure sends Quantity Adjustment information for a particular carrier
--
-- Parameters:
--    i_carrier_update_info  - Information to sent in Inventory Update for Carrier Msg.
--   o_status - return status
--          0  - No errors.
--          1  - Error occured
--
-- Exceptions Raised:
--    e_fail  If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/29/05          Created as part of the mini-load changes
-------------------------------------------------------------------------
   PROCEDURE p_inv_update_for_carrier (
      i_carrier_update_info   IN       t_carrier_update_info,
      o_status                OUT      NUMBER
   )
   IS
      l_miniload_info   t_miniload_info;
      lv_msg_type       VARCHAR2 (50)   := ct_inv_upd_carr;
      ln_status         NUMBER (1)      := ct_success;
      --Hold return status of functions
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)   := 'P_INV_UPDATE_FOR_CARRIER';
      e_fail            EXCEPTION;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_inv_update_for_carrier');
      l_miniload_info.vt_carrier_update_info := i_carrier_update_info;

      IF (l_miniload_info.vt_carrier_update_info.n_qty <= 0)       --05/10/06
      THEN
         l_miniload_info.v_sku := LPAD (' ', 20, ' ');
         l_miniload_info.vt_carrier_update_info.n_uom := NULL;
         l_miniload_info.vt_carrier_update_info.v_prod_id := NULL;
         l_miniload_info.vt_carrier_update_info.v_cust_pref_vendor := NULL;
         l_miniload_info.vt_carrier_update_info.v_inv_date := NULL;
      ELSE
         p_convert_uom
                   (l_miniload_info.vt_carrier_update_info.n_uom,
                    l_miniload_info.vt_carrier_update_info.n_qty,
                    l_miniload_info.vt_carrier_update_info.v_prod_id,
                    l_miniload_info.vt_carrier_update_info.v_cust_pref_vendor
                   );
         l_miniload_info.v_sku :=
            f_generate_sku
                    (l_miniload_info.vt_carrier_update_info.n_uom,
                     l_miniload_info.vt_carrier_update_info.v_prod_id,
                     l_miniload_info.vt_carrier_update_info.v_cust_pref_vendor
                    );
      END IF;

      l_miniload_info.v_data :=
                               f_create_message (l_miniload_info, lv_msg_type);

      /* Need the Prod Id for finding ML System */
                                     
      IF(l_miniload_info.vt_carrier_update_info.n_qty <= 0)  
      THEN
      l_miniload_info.vt_carrier_update_info.v_prod_id := i_carrier_update_info.v_prod_id;
      l_miniload_info.vt_carrier_update_info.v_cust_pref_vendor := i_carrier_update_info.v_cust_pref_vendor;
      END IF;
      
                                       
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Type: '
         || lv_msg_type
         || ' Msg: '
         || l_miniload_info.v_data;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      p_insert_miniload_message (l_miniload_info, lv_msg_type, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_message';
         RAISE e_fail;
      END IF;

      l_miniload_info.v_trans_type := 'ADJ';

      /*
      * We do not need to write ADJ for miniload_trans table
      * p_insert_miniload_trans (l_miniload_info, lv_msg_type, ln_status);
       */
      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_trans';
         RAISE e_fail;
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_inv_update_for_carrier';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_inv_update_for_carrier;

----------------------------------------------------------------------------
-- PROCEDURE:
--    p_receive_msg
--
-- Description:
--     This procedure processes the messages coming from the miniloader.
--
-- Parameters:
--   o_status - return status
--          0  - No errors.
--          1  - Error occured
--
-- Exceptions Raised:
--    None
--
-- Called By:
--    ml_int.sh
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/28/05          Created as part of the mini-load changes.
--    02/25/06 prpbcb   Re-arranged if statment so the most common message
--                      types are processed first.
--    12/08/08 prpbcb   Changed cursor c_msgs_to_host to use hints so that the
--                      indexes on the status and source_system are used.
--                      This is to stop the full tables scans on
--                      MINILOAD_MESSAGE and MINILOAD_ORDER.
--                      I could not get the cursor to use the indexes without
--                      the hints.
----------------------------------------------------------------------------
   PROCEDURE p_receive_msg
   IS
      lv_msg_type      VARCHAR2 (50);
      lv_status        NUMBER (1)                      := ct_success;
      lv_msg           MINILOAD_MESSAGE.ml_data%TYPE;
      lv_fname         VARCHAR2 (50)                   := 'P_RECEIVE_MSG';
      lv_msg_text      VARCHAR2 (1500);
      ln_status        NUMBER (1);

      CURSOR c_msgs_to_host
      IS
         SELECT /*+ index(miniload_message i_mlm_status_src_system) */
                message_id, message_type, add_date, ml_data_len, ml_data,
                status
           FROM miniload_message
          WHERE status = 'N' and source_system = 'MNL'
            -- acpmxp 28-Mar-2006 Beg Del Removed processing of failed messages
            -- AND status IN ('N', 'F')
         UNION ALL
         SELECT /*+ index(miniload_order i_mlo_status_src_system) */
               message_id, message_type, add_date, ml_data_len, ml_data,
               status
          FROM miniload_order
         WHERE status = 'N' AND source_system = 'MNL'
            -- acpmxp 28-Mar-2006 Beg Del Removed processing of failed messages
            -- AND status IN ('N', 'F')
         ORDER BY message_id, add_date;

      r_msgs_to_host   c_msgs_to_host%ROWTYPE;
   BEGIN

      pl_text_log.init ('pl_miniload_interface.p_receive_msg');

      -- Extract the first 50 characters of the i_data, convert it to
      -- upper case and move it to lv_msg_type field.
      IF NOT c_msgs_to_host%ISOPEN THEN
         OPEN c_msgs_to_host;
      END IF;

      --
      -- Process the messages.
      --
      LOOP
         FETCH c_msgs_to_host
          INTO r_msgs_to_host;
        
         DBMS_OUTPUT.PUT_LINE ('in p_receive_msg in loop ');
         DBMS_OUTPUT.PUT_LINE ('msgid ' || TO_CHAR (r_msgs_to_host.message_id));

         EXIT WHEN c_msgs_to_host%NOTFOUND
                OR c_msgs_to_host%NOTFOUND IS NULL;

         lv_msg_type := r_msgs_to_host.MESSAGE_TYPE;
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Msg Type: '
            || lv_msg_type
            || ' Msg: '
            || r_msgs_to_host.ml_data;

         pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

    --dbms_output.put_line('p_receive_msg ' || lv_msg_text);
         IF lv_msg_type = ct_ship_ord_status THEN
            --
            -- Shipping order item status sent from the miniloader.
            --
            p_rcv_item_status(r_msgs_to_host.ml_data,
                              r_msgs_to_host.message_id,
                              ln_status);
         ELSIF lv_msg_type = ct_inv_arr THEN
            --
            -- Inventory arrival.
            --
            p_rcv_inv_arr (r_msgs_to_host.ml_data,
                           r_msgs_to_host.message_id,
                           ln_status);
         ELSIF lv_msg_type = ct_inv_plan_mov THEN
            --
            -- Inventory planned move.
            --
            --p_rcv_inv_planned_move (r_msgs_to_host.message_id, ln_status);
            p_rcv_inv_planned_move (r_msgs_to_host.ml_data,
                                    r_msgs_to_host.message_id,
                                    ln_status);
         ELSIF lv_msg_type = ct_inv_adj_inc THEN
            --
            -- Inventory adjustment increase.
            --
            p_rcv_inv_adj_inc (r_msgs_to_host.ml_data,
                               r_msgs_to_host.message_id,
                               ln_status);
         ELSIF lv_msg_type = ct_exp_rec_comp THEN
            --
            -- Expected receipt complete.
            --
            p_rcv_er_complete (r_msgs_to_host.ml_data,
                               r_msgs_to_host.message_id,
                               ln_status);
         ELSIF lv_msg_type = ct_inv_adj_dcr THEN
            --
            -- Inventory adjustment decrease.
            --
            p_rcv_inv_adj_dcr (r_msgs_to_host.ml_data,
                               r_msgs_to_host.message_id,
                               ln_status);
         ELSIF lv_msg_type = ct_inv_lost THEN
            --
            -- Inventory lost.
            --
            p_rcv_inv_lost (r_msgs_to_host.ml_data,
                            r_msgs_to_host.message_id,
                            ln_status);
         ELSIF lv_msg_type = ct_message_status THEN
            --
            -- MessageStatus.
            --
            p_rcv_msg_status(r_msgs_to_host.ml_data,
                             r_msgs_to_host.message_id,
                             ln_status);              
         ELSE
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Invalid message type '
               || r_msgs_to_host.MESSAGE_TYPE;
            Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         END IF;

         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message received from mini-load'
            || ' Message type: '
            || r_msgs_to_host.MESSAGE_TYPE;
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
         COMMIT;
      END LOOP;      
      
      IF c_msgs_to_host%ISOPEN
      THEN
         CLOSE c_msgs_to_host;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         IF c_msgs_to_host%ISOPEN
         THEN
            CLOSE c_msgs_to_host;
         END IF;

         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in message processing in p_receive_msg';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         ROLLBACK;
   END p_receive_msg;

-------------------------------------------------------------------------------
-- PROCEDURE:
--    p_rcv_inv_adj_inc
--
-- Description:
--     This procedure processes inventory adjustment increase message from
--     mini-load.  This will usually be an induction.
--
-- Parameters:
--          i_msg       - message from mini-load.
--          i_msg_id    - message id from miniload_message table.
--          o_status    - status from the function.
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
--    11/28/05          Created as part of the mini-load changes.
--    08/22/06 prphqb   Allow creation of new LP even if ER not found
--    03/22/06 prpbcb   Allow inducting a qty greater than the expected
--                      receipt qty.  This can happen when slotting an
--                      item into the miniloader and there was more on
--                      the LP than what SWMS had.
--
--                      Bug fix: When inducting cases (or splits) from two
--                      or more LP's to the same carrier the last induction
--                      fails on SWMS.
--    12/03/08 prpbcb   Added
--                         rule_id = 3
--                      to select statement
--                         SELECT induction_loc
--                         INTO lv_induction_loc
--                         ...
--                      to fix too many rows error when the item has the case
--                      stored in the main warehouse and the splits in the
--                      miniloader.
----------------------------------------------------------------------------
   PROCEDURE p_rcv_inv_adj_inc
     (i_msg      IN       MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_id   IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_status   OUT      NUMBER)
   IS
      lv_fname                       VARCHAR2 (50):= 'P_RCV_INV_ADJ_INC';

      l_miniload_info                t_miniload_info                  := NULL;
      l_carrier_already_in_inv_bln   BOOLEAN;
                                             -- Is the carrier already in inv
      lv_induction_loc               INV.plogi_loc%TYPE;
      ln_qty_orig                    INV.qoh%TYPE;
      lv_ref_pallet_id               MINILOAD_TRANS.ref_pallet_id%TYPE;
      l_inv_info                     INV%ROWTYPE;
      l_count                        NUMBER             := 0;
      l_dummy                        NUMBER             := 0;
      lv_msg_type                    VARCHAR2 (50)      := ct_inv_adj_inc;
      lv_msg_text                    VARCHAR2 (1500);
      ln_qoh                         INV.qoh%TYPE;  -- Inventory QOH for the LP
                                                    -- being inducted.
      l_ml_msg_qty_in_splits         INV.qoh%TYPE;  -- The ML msg qty in splits.
      ln_status                      NUMBER (1)                 := ct_success;
      ln_qty_expected_in_msg         MINILOAD_MESSAGE.qty_expected%TYPE;
                                               -- The qty_expected in the
                                               -- ML ER message.

      ln_total_qty_received          MINILOAD_MESSAGE.qty_received%TYPE;
      ln_actual_qty_expected         MINILOAD_MESSAGE.qty_expected%TYPE;
      v_mini_auto_flag               SYS_CONFIG.config_flag_val%TYPE; -- Charm6000002987 Added variable

      e_fail                         EXCEPTION;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_rcv_inv_adj_inc');
      -- split the raw message from mini-load.
      l_miniload_info := f_parse_message (i_msg, lv_msg_type);
      Pl_Log.ins_msg
               ('INFO',
                lv_fname,
                   'Starting procedure  LP '
                || l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
                || '  Carrier ID '
                || l_miniload_info.vt_inv_adj_inc_info.v_label
                || '  n_quantity: '
                || TO_CHAR (l_miniload_info.vt_inv_adj_inc_info.n_quantity)
                || '  uom: '
                || TO_CHAR (l_miniload_info.n_uom),
                NULL,
                NULL);
      --
      -- Convert the qty in the miniload message to splits.   This qty will
      -- be compared against the inv qty which is in splits.
      --
      l_ml_msg_qty_in_splits :=
         f_convert_to_splits (l_miniload_info.n_uom,
                              l_miniload_info.v_prod_id,
                              l_miniload_info.v_cust_pref_vendor,
                              l_miniload_info.vt_inv_adj_inc_info.n_quantity
                             );
        
        /*Charm6000002987 - Called below procedure for miniload automation - Start*/
        BEGIN
            
            SELECT config_flag_val 
              INTO v_mini_auto_flag
              FROM sys_config
             WHERE config_flag_name = 'MINILOAD_AUTO_FLAG';
             
             IF v_mini_auto_flag = 'Y' THEN
             
                p_miniload_putaway_completion (l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id,
                                                                                                        ln_status );  
             END IF;
        END; 
        
    /*Charm6000002987 - Called below procedure for miniload automation -  End*/
      BEGIN
         --
         -- Select the quantity on the expected receipt that was sent earlier
         -- to the miniloader.
         -- Note:  The expected_receipt_id is the LP.
         --
         SELECT qty_expected
           INTO ln_qty_expected_in_msg
           FROM MINILOAD_MESSAGE
          WHERE message_id =
                   (SELECT MAX (message_id)
                      FROM MINILOAD_MESSAGE
                     WHERE MESSAGE_TYPE = ct_exp_rec
                       AND expected_receipt_id =
                              l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
                       AND prod_id = l_miniload_info.v_prod_id
                       AND cust_pref_vendor =
                                            l_miniload_info.v_cust_pref_vendor
                       AND status = 'S');

         Pl_Log.ins_msg
                ('INFO',
                 lv_fname,
                    'LP '
                 || l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
                 || ' ER msg qty_expected: '
                 || TO_CHAR (ln_qty_expected_in_msg),
                 NULL,
                 NULL);

         BEGIN
            --
            -- Select the quantity that has aleady been inducted.
            --
            SELECT NVL (SUM (qty_received), 0)
              INTO ln_total_qty_received
              FROM MINILOAD_MESSAGE
             WHERE MESSAGE_TYPE = ct_inv_adj_inc
               AND expected_receipt_id =
                      l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
               AND prod_id = l_miniload_info.v_prod_id
               AND cust_pref_vendor = l_miniload_info.v_cust_pref_vendor
               AND status = 'S';

            Pl_Log.ins_msg
                ('INFO',
                 lv_fname,
                    'LP '
                 || l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
                 || ' Qty already inducted: '
                 || TO_CHAR (ln_total_qty_received),
                 NULL,
                 NULL);
         EXCEPTION
            WHEN OTHERS
            THEN
               --
               -- Failed to select the quantity that has already been inducted.
               --
               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Message_id: '
                  || i_msg_id
                  || ' Oracle Failed to select qty already inducted'
                  || '  from miniload_message';
               Pl_Text_Log.ins_msg ('FATAL',
                                    lv_fname,
                                    lv_msg_text,
                                    SQLCODE,
                                    SQLERRM
                                   );
               Pl_Log.ins_msg ('FATAL',
                               lv_fname,
                               lv_msg_text,
                               SQLCODE,
                               SQLERRM
                              );
               ln_status := ct_failure;
               RAISE e_fail;
         END;

         --
         -- Calculate the qty left on the LP to induct based on the miniload
         -- messages expected receipt and inventory adj increase(s).
         --
         ln_actual_qty_expected :=
                             (ln_qty_expected_in_msg - ln_total_qty_received
                             );
         Pl_Log.ins_msg ('INFO',
                         lv_fname,
                            'ln_qty_expected_in_msg '
                         || TO_CHAR (ln_qty_expected_in_msg)
                         || ' ln_total_qty_received '
                         || TO_CHAR (ln_total_qty_received)
                         || ' ln_actual_qty_expected '
                         || TO_CHAR (ln_actual_qty_expected),
                         NULL,
                         NULL);
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Msg Type: '
            || lv_msg_type
            || ' Prod id: '
            || l_miniload_info.v_prod_id
            || ' CPV: '
            || l_miniload_info.v_cust_pref_vendor
            || ' UOM: '
            || l_miniload_info.n_uom
            || ' Qty left on LP to induct: '
            || ln_actual_qty_expected;
         Pl_Text_Log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);
         Pl_Log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            --
            -- Did not find the expected receipt for the LP.
            -- This is an error.
            --
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Message_id: '
               || i_msg_id
               || ' TABLE=MINILOAD_MESSAGE KEY=['
               || l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
               || ','
               || l_miniload_info.v_prod_id
               || ','
               || l_miniload_info.v_cust_pref_vendor
               || '](v_expected_receipt_id,v_prod_id,v_cust_pref_vendor)'
               || ' ACTION=SELECT MESSAGE=expected receipt id not found';

            pl_text_log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM);
            RAISE e_fail;
         WHEN OTHERS THEN
            --
            -- Oracle error when looking for the expected receipt.
            --
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Message_id: '
               || i_msg_id
               || ' TABLE=MINILOAD_MESSAGE KEY=['
               || l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
               || ','
               || l_miniload_info.v_prod_id
               || ','
               || l_miniload_info.v_cust_pref_vendor
               || '](v_expected_receipt_id,v_prod_id,v_cust_pref_vendor)'
               || ' ACTION=SELECT MESSAGE=Oracle Failed to select from'
               || ' miniload_message';

            pl_text_log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM);
            pl_log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE, SQLERRM);
            ln_status := ct_failure;
            RAISE e_fail;
      END;

      BEGIN
         --
         -- Find the LP being inducted.  The INV qoh will be adjusted down for
         -- each carrier inducted.
         --
         SELECT plogi_loc, exp_date, qoh
           INTO lv_induction_loc, l_miniload_info.v_exp_date, ln_qoh
           FROM INV
          WHERE logi_loc =
                     l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
            AND prod_id = l_miniload_info.v_prod_id
            AND cust_pref_vendor = l_miniload_info.v_cust_pref_vendor;

         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || '  Found the LP being inducted in INV   Message_id: '
            || i_msg_id
            || ' plogi_loc: '
            || lv_induction_loc
            || ' Inv QOH: '
            || TO_CHAR (ln_qoh)
            || '  exp_date: '
            || l_miniload_info.v_exp_date;

         pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
         pl_log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);

      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            --
            -- Did not find the LP the miniloader is inducting from in INV.
            -- This is OK.  The user can create an expected receipt for a LP
            -- not in INV to handle situations where an unexpected case or
            -- split is found.  The inventory record will be created by
            -- this procedure.
            --
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Message_id: '
               || TO_CHAR (i_msg_id)
               || '  TABLE=INV  ACTION=SELECT  KEY=['
               || l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
               || ','
               || l_miniload_info.v_prod_id
               || ','
               || l_miniload_info.v_cust_pref_vendor
               || '](v_expected_receipt_id,v_prod_id,v_cust_pref_vendor)'
               || '  MESSAGE=Inventory not present for LP: '
               || l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
               || '.  Inventory will be created for this LP.'
               || '  Carrier ID '
               || l_miniload_info.vt_inv_adj_inc_info.v_label;

            pl_text_log.ins_msg ('WARNING',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM);
            pl_log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);

            --
            -- 12/03/08 Brian Bent
            -- Added: rule_id = 3
            -- to fix too many rows error when the item has the case stored
            -- in the main warehouse and the splits in the miniloader.
            --
            -- 01/27/10 Brian Bent   Warehouse move changes.
            -- Get the induction location from WHMV_MINILOAD_ITEM
            -- if warehouse move is active.  This is handle moving items into
            -- the miniloader during the pre-move period.  It needs to be
            -- done this way because the item is not yet flagged as a miniload
            -- item in the PM table.
            --
            IF (pl_common.f_get_syspar('ENABLE_WAREHOUSE_MOVE', 'N') = 'Y') THEN
               --
               -- whmv_miniload_item has the induction location with the actual
               -- area.  The area needs to be switched to the temporary area
               -- because that is how the location is stored in the SWMS schema.
               --
               SELECT pl_wh_move.get_temp_new_wh_loc(mli.induction_loc)
                 INTO lv_induction_loc
                 FROM whmv_miniload_item mli
                WHERE mli.prod_id = l_miniload_info.v_prod_id
                  AND mli.cust_pref_vendor = l_miniload_info.v_cust_pref_vendor;
            ELSE
               SELECT induction_loc
                 INTO lv_induction_loc
                 FROM ZONE
                WHERE rule_id = 3
                  AND zone_id IN
                    (SELECT zone_id
                       FROM pm
                      WHERE prod_id = l_miniload_info.v_prod_id
                        AND cust_pref_vendor =
                                           l_miniload_info.v_cust_pref_vendor
                     UNION
                     SELECT split_zone_id
                       FROM PM
                      WHERE prod_id = l_miniload_info.v_prod_id
                        AND cust_pref_vendor =
                                           l_miniload_info.v_cust_pref_vendor);
            END IF;

            l_miniload_info.v_exp_date := TRUNC(SYSDATE);
            pl_text_log.ins_msg ('WARNING', lv_fname, 'Step 0', NULL, NULL);
         --pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text,SQLCODE,SQLERRM);
         --RAISE e_fail;
         WHEN OTHERS THEN
            --
            -- Got an oracle error when attempting to select the LP from INV.
            -- This is an error.
            --
            lv_msg_text :=
                        ct_program_code || 'Oracle Failed to select from inv';
            pl_text_log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM);

            pl_log.ins_msg ('INFO', lv_fname, lv_msg_text, SQLCODE, SQLERRM);
            RAISE e_fail;
      END;

      ln_qty_orig := l_miniload_info.vt_inv_adj_inc_info.n_quantity;

      -- IF (ln_qoh < l_miniload_info.vt_inv_adj_inc_info.n_quantity) THEN
      IF (ln_qoh < l_ml_msg_qty_in_splits)
      THEN
         --
         -- The induction qty is more than what the LP has.
         -- 03/12/07 Brian Bent  This was an error but now this will be
         -- allowed.  A message will be logged.
         --
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: ' || TO_CHAR (i_msg_id)
            || '  LP['
            || l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id || ']'
            || '  Item[' || l_miniload_info.v_prod_id || ']'
            || '  CPV[' || l_miniload_info.v_cust_pref_vendor || ']'
            || '  LP['
            || l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id || ']'
            || '  Carrier ID['
            || l_miniload_info.vt_inv_adj_inc_info.v_label || ']'
            || '  UOM[' || TO_CHAR (l_miniload_info.n_uom) || ']'
            || '  Induction qty of '
            || TO_CHAR (l_ml_msg_qty_in_splits)
            || ' (split qty)'
            || ' is more than qty of '
            || TO_CHAR (ln_qoh)
            || ' (split qty) on the pallet being inducted.  This is'
            || ' allowed but will most likely result in an item recon issue'
            || ' because additional inventory has been created.';

         pl_text_log.ins_msg ('INFO', lv_fname, lv_msg_text, SQLCODE, SQLERRM);
         pl_log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);
      END IF;

      --
      -- See if the carrier is in inventory.  It can be if two or more LPs
      -- are inducted to the same carrier.
      --
      SELECT COUNT (*)
        INTO l_dummy
        FROM INV
       WHERE logi_loc         = l_miniload_info.vt_inv_adj_inc_info.v_label
         AND prod_id          = l_miniload_info.v_prod_id
         AND cust_pref_vendor = l_miniload_info.v_cust_pref_vendor;

      IF (l_dummy = 0) THEN
         l_carrier_already_in_inv_bln := FALSE;
      ELSE
         l_carrier_already_in_inv_bln := TRUE;
      END IF;

      IF (   l_miniload_info.vt_inv_adj_inc_info.n_quantity >=
                                                        ln_actual_qty_expected
          OR l_carrier_already_in_inv_bln = TRUE) THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Inventory QOH sufficient.'
            || '  n_quantity: '
            || TO_CHAR (l_miniload_info.vt_inv_adj_inc_info.n_quantity)
            || '  ln_actual_qty_expected: '
            || TO_CHAR (ln_actual_qty_expected)
            || '  LP['
            || l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
            || ']'
            || '  Carrier ID['
            || l_miniload_info.vt_inv_adj_inc_info.v_label
            || ']';
         pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
         pl_log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);

         IF (l_miniload_info.vt_inv_adj_inc_info.n_quantity >
                                                       ln_actual_qty_expected)
         THEN
            --
            -- The qty being inducted is more than the qty on the LP based on
            -- previous inductions of the LP.  Write an exception log.
            --
            p_insert_miniload_exception(l_miniload_info,
                                        lv_msg_type,
                                        ln_status);
         END IF;

         l_miniload_info.vt_inv_adj_inc_info.n_quantity :=
                                                        l_ml_msg_qty_in_splits;

         /*  03/21/07 prpbcb
             f_convert_to_splits
                           (l_miniload_info.n_uom,
                            l_miniload_info.v_prod_id,
                            l_miniload_info.v_cust_pref_vendor,
                            l_miniload_info.vt_inv_adj_inc_info.n_quantity);
         */
         IF (l_carrier_already_in_inv_bln = FALSE) THEN
            --
            -- The carrier does not exist in inventory.  Create it.
            --
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Message_id: '
               || i_msg_id
               || ' New inventory record for mini-load to be created ';

            pl_text_log.ins_msg('WARNING', lv_fname, lv_msg_text, NULL, NULL);
            pl_log.ins_msg('WARNING', lv_fname, lv_msg_text, NULL, NULL);

            -- New inventory record to be created for mini-load item
            BEGIN
               SELECT abc,
                      abc_gen_date,
                      case_type_tmu,
                      exp_ind,
                      lot_id,
                      lst_cycle_date,
                      lst_cycle_reason, 
                      mfg_date,
                      pallet_height,
                      rec_date,
                      rec_id,
                      temperature,
                      weight,
                      status
                 INTO l_inv_info.abc, 
                      l_inv_info.abc_gen_date,
                      l_inv_info.case_type_tmu,
                      l_inv_info.exp_ind,
                      l_inv_info.lot_id,
                      l_inv_info.lst_cycle_date,
                      l_inv_info.lst_cycle_reason,
                      l_inv_info.mfg_date,
                      l_inv_info.pallet_height,
                      l_inv_info.rec_date,
                      l_inv_info.rec_id,
                      l_inv_info.temperature,
                      l_inv_info.weight,
                      l_inv_info.status
                 FROM inv
                WHERE logi_loc =
                      l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
                  AND prod_id          = l_miniload_info.v_prod_id
                  AND cust_pref_vendor = l_miniload_info.v_cust_pref_vendor;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  l_inv_info.abc := 'A';
                  l_inv_info.status := 'AVL';
            END;

            l_inv_info.prod_id := l_miniload_info.v_prod_id;
            l_inv_info.cust_pref_vendor := l_miniload_info.v_cust_pref_vendor;
            -- The miniloader inv date is the SWMS exp date.
            l_inv_info.exp_date :=
                                l_miniload_info.vt_inv_adj_inc_info.v_inv_date;
            l_inv_info.logi_loc := l_miniload_info.vt_inv_adj_inc_info.v_label;
            l_inv_info.plogi_loc   := lv_induction_loc;
            l_inv_info.qoh := l_miniload_info.vt_inv_adj_inc_info.n_quantity;
            l_inv_info.qty_alloc   := 0;
            l_inv_info.qty_planned := 0;
            l_inv_info.min_qty     := 0;
            -- Status is fetched from the existing record for the license plate.
            -- This is because during CC processing status is updated to HLD and
            -- hence the new records status should also have the same status
            l_inv_info.inv_date := l_miniload_info.v_exp_date;
            l_inv_info.inv_uom  := l_miniload_info.n_uom;
            --
            -- Create the carrier in INV.
            --
            p_insert_inv(l_inv_info, ln_status);

            IF (ln_status = ct_failure) THEN
               RAISE e_fail;
            END IF;
         ELSE
            --
            -- The carrier already exists in inventory.
            -- This happens when multiple LPN's are being stored in one carrier.
            --
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Message_id: '
               || i_msg_id
               || '  The carrier exists in inventory.  Updating QOH.';

            pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
            pl_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

            UPDATE INV
               SET qoh = qoh + l_miniload_info.vt_inv_adj_inc_info.n_quantity
             WHERE plogi_loc = lv_induction_loc
               AND logi_loc  = l_miniload_info.vt_inv_adj_inc_info.v_label;

            IF (SQL%ROWCOUNT = 0) THEN
               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Message_id: '
                  || i_msg_id
                  || ' Inventory updated for mini-load item failed, prod_id:'
                  || l_miniload_info.v_prod_id
                  || ','
                  || ' and carrier_id :'
                  || l_miniload_info.vt_inv_adj_inc_info.v_label;
               RAISE e_fail;
            ELSE
               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Message_id: '
                  || i_msg_id
                  || ' Inventory updated for mini-load item, prod_id:'
                  || l_miniload_info.v_prod_id
                  || ','
                  || ' and carrier_id :'
                  || l_miniload_info.vt_inv_adj_inc_info.v_label;

               pl_text_log.ins_msg ('WARNING',
                                    lv_fname,
                                    lv_msg_text,
                                    NULL,
                                    NULL);
               Pl_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
            END IF;
         END IF;

         -- Old inventory records deleted for items in expected receipt( LPN).
         DELETE FROM INV
               WHERE plogi_loc = lv_induction_loc
                 AND logi_loc =
                      l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
                 AND prod_id = l_miniload_info.v_prod_id
                 AND cust_pref_vendor = l_miniload_info.v_cust_pref_vendor;

         IF (SQL%ROWCOUNT = 0)
         THEN
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Message_id: '
               || i_msg_id
               || ' Old Inventory deletion for mini-load item failed, prod_id:'
               || l_miniload_info.v_prod_id
               || ','
               || ' and license #: '
               || l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id;
         -- RAISE e_fail;
         ELSE
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Message_id: '
               || i_msg_id
               || ' Old Inventory deleted for mini-load item, prod_id:'
               || l_miniload_info.v_prod_id
               || ','
               || ' and carrier_id :'
               || l_miniload_info.vt_inv_adj_inc_info.v_label;
            Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
            Pl_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
         END IF;
      ELSIF l_miniload_info.vt_inv_adj_inc_info.n_quantity <
                                                        ln_actual_qty_expected
      THEN
         --
         -- The induction qty is less than qty remaining to be inducted.
         -- This happens when inducting to multiple carriers.
         --
         l_miniload_info.vt_inv_adj_inc_info.n_quantity :=
            f_convert_to_splits
                              (l_miniload_info.n_uom,
                               l_miniload_info.v_prod_id,
                               l_miniload_info.v_cust_pref_vendor,
                               l_miniload_info.vt_inv_adj_inc_info.n_quantity
                              );

         BEGIN
            SELECT ABC, abc_gen_date,
                   case_type_tmu, exp_date,
                   exp_ind, lot_id,
                   lst_cycle_date, lst_cycle_reason,
                   mfg_date, pallet_height,
                   rec_date, rec_id,
                   temperature, weight,
                   status
              INTO l_inv_info.ABC, l_inv_info.abc_gen_date,
                   l_inv_info.case_type_tmu, l_inv_info.exp_date,
                   l_inv_info.exp_ind, l_inv_info.lot_id,
                   l_inv_info.lst_cycle_date, l_inv_info.lst_cycle_reason,
                   l_inv_info.mfg_date, l_inv_info.pallet_height,
                   l_inv_info.rec_date, l_inv_info.rec_id,
                   l_inv_info.temperature, l_inv_info.weight,
                   l_inv_info.status
              FROM INV
             WHERE logi_loc =
                      l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
               AND prod_id = l_miniload_info.v_prod_id
               AND cust_pref_vendor = l_miniload_info.v_cust_pref_vendor;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               l_inv_info.ABC := 'A';
               l_inv_info.status := 'AVL';
         END;

         l_inv_info.prod_id := l_miniload_info.v_prod_id;
         l_inv_info.cust_pref_vendor := l_miniload_info.v_cust_pref_vendor;
         l_inv_info.inv_date := l_miniload_info.vt_inv_adj_inc_info.v_inv_date;
         l_inv_info.logi_loc := l_miniload_info.vt_inv_adj_inc_info.v_label;
         l_inv_info.plogi_loc := lv_induction_loc;
         l_inv_info.qoh := l_miniload_info.vt_inv_adj_inc_info.n_quantity;
         l_inv_info.qty_alloc := 0;
         l_inv_info.qty_planned := 0;
         l_inv_info.min_qty := 0;
-- Status is fetched from the existing record for the license plate.
-- This is because during CC processing status is updated to HLD and
-- hence the new records status should also have the same status
--    l_inv_info.status := 'AVL';
         l_inv_info.inv_uom := l_miniload_info.n_uom;
         p_insert_inv (l_inv_info, ln_status);

         IF (ln_status = ct_failure)
         THEN
            RAISE e_fail;
         END IF;

         --
         -- Remove the qty inducted from the LP at the induction location.
         --
         UPDATE INV
            SET qoh = qoh - l_miniload_info.vt_inv_adj_inc_info.n_quantity
          WHERE plogi_loc = lv_induction_loc
            AND logi_loc =
                     l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id;

         IF (SQL%ROWCOUNT = 0)
         THEN
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Message_id: '
               || i_msg_id
               || ' Inventory update for mini-load item failed, prod_id: '
               || l_miniload_info.v_prod_id
               || ','
               || ' and carrier_id :'
               || l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id;
         -- RAISE e_fail;
         ELSE
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Message_id: '
               || i_msg_id
               || ' Inventory update for mini-load item, prod_id: '
               || l_miniload_info.v_prod_id
               || ','
               || ' and carrier_id :'
               || l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id;
            Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
         END IF;
      END IF;

      --
      -- Log the transaction into mini-load trans table with 'negative qty'
      -- and transaction type 'MII' with pallet id in
      -- l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
      -- and ref_pallet_id in l_miniload_info.vt_inv_adj_inc_info.v_label;
      --
      l_miniload_info.v_trans_type := 'MII';
      l_miniload_info.vt_inv_adj_inc_info.n_quantity := - (ln_qty_orig);
      p_insert_miniload_trans (l_miniload_info, lv_msg_type, ln_status);

      IF (ln_status = ct_success)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' MII Transaction logged with '
            || ' Quantity: '
            || l_miniload_info.vt_inv_adj_inc_info.n_quantity;
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
         --
         -- Log another transaction into mini-load trans table with
         -- 'qty received' and transaction type 'MII' with ref_pallet_id in
         -- l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id
         -- and pallet_id in l_miniload_info.vt_inv_adj_inc_info.v_label.
         --
         lv_ref_pallet_id :=
                     l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id;
         l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id :=
                                   l_miniload_info.vt_inv_adj_inc_info.v_label;
         l_miniload_info.vt_inv_adj_inc_info.v_label := lv_ref_pallet_id;
         l_miniload_info.vt_inv_adj_inc_info.n_quantity := ln_qty_orig;
         p_insert_miniload_trans (l_miniload_info, lv_msg_type, ln_status);

         IF (ln_status = ct_success)
         THEN
            l_miniload_info.v_status := 'S';
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Message_id: '
               || i_msg_id
               || ' MII Transaction logged,'
               || ' Quantity: '
               || l_miniload_info.vt_inv_adj_inc_info.n_quantity;
            Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
         ELSE
            l_miniload_info.v_status := 'F';
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Message_id: '
               || i_msg_id
               || ' MII Transaction logging failed,'
               || ' Quantity: '
               || l_miniload_info.vt_inv_adj_inc_info.n_quantity;
            RAISE e_fail;
         END IF;
      ELSE
         l_miniload_info.v_status := 'F';
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' MII Transaction logging failed,'
            || ' Quantity: '
            || l_miniload_info.vt_inv_adj_inc_info.n_quantity;
         RAISE e_fail;
      END IF;
      
      p_upd_status (i_msg_id, lv_msg_type, l_miniload_info.v_status,
                    ln_status);
      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         l_miniload_info.v_status := 'F';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status
                      );
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         Pl_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN NO_DATA_FOUND
      THEN
         l_miniload_info.v_status := 'F';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status
                      );
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' No data found - p_rcv_inv_adj_inc';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         Pl_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE, SQLERRM);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         l_miniload_info.v_status := 'F';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status
                      );
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Error in executing p_rcv_inv_adj_inc';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         Pl_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE, SQLERRM);
         o_status := ct_failure;
   END p_rcv_inv_adj_inc;

-------------------------------------------------------------------------
-- Procedure:
--    p_rcv_inv_adj_dcr
--
-- Description:
--     This procedure logs the inventory decrease message from the mini-load.
--
-- Parameters:
--    i_msg_id - Message id
--    i_msg  - The message being recieved.
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
--    11/28/05          Created as part of the mini-load changes.
-------------------------------------------------------------------------
   PROCEDURE p_rcv_inv_adj_dcr (
      i_msg      IN       MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_id   IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_status   OUT      NUMBER
   )
   IS
      l_miniload_info   t_miniload_info                := NULL;
      lv_msg_type       VARCHAR2 (50)                  := ct_inv_adj_dcr;
      ln_status         NUMBER (1)                     := ct_success;
      --Hold o_status := status of functions
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)                  := 'P_RCV_INV_ADJ_DCR';
      lv_msg_status     MINILOAD_MESSAGE.status%TYPE   := 'S';
      e_fail            EXCEPTION;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_rcv_inv_adj_dcr');
      l_miniload_info := f_parse_message (i_msg, lv_msg_type);
      l_miniload_info.v_status := 'S';
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Message_id: '
         || i_msg_id
         || ' Msg Type: '
         || lv_msg_type
         || ' Prod Id: '
         || l_miniload_info.v_prod_id
         || ' CPV: '
         || l_miniload_info.v_cust_pref_vendor
         || ' UOM: '
         || l_miniload_info.n_uom;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      --p_insert_miniload_exception (l_miniload_info, lv_msg_type, ln_status);
      l_miniload_info.vt_inv_adj_dcr_info.n_quantity :=
         f_convert_to_splits (l_miniload_info.n_uom,
                              l_miniload_info.v_prod_id,
                              l_miniload_info.v_cust_pref_vendor,
                              l_miniload_info.vt_inv_adj_dcr_info.n_quantity
                             );

      UPDATE INV
         SET qoh = qoh - l_miniload_info.vt_inv_adj_dcr_info.n_quantity
       WHERE logi_loc = l_miniload_info.vt_inv_adj_dcr_info.v_label;

      IF (SQL%ROWCOUNT = 0)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Inventory updated for mini-load item failed, prod_id:'
            || l_miniload_info.v_prod_id
            || ','
            || ' and carrier_id :'
            || l_miniload_info.vt_inv_adj_dcr_info.v_label;
         RAISE e_fail;
      ELSE
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Inventory updated for mini-load item, prod_id:'
            || l_miniload_info.v_prod_id
            || ','
            || ' and carrier_id :'
            || l_miniload_info.vt_inv_adj_dcr_info.v_label;
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      END IF;

      --
      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Error in executing p_insert_miniload_exception';
         RAISE e_fail;
      END IF;

      p_upd_status (i_msg_id, lv_msg_type, lv_msg_status, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Error in executing p_upd_status';
         RAISE e_fail;
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         l_miniload_info.v_status := 'F';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status
                      );
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         l_miniload_info.v_status := 'F';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status
                      );
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Error in executing functions';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_rcv_inv_adj_dcr;

-------------------------------------------------------------------------------
-- PROCEDURE
--    p_rcv_inv_arr
--
-- Description:
--     This procedure processes inventory arrival message from mini-load.
--
-- Parameters:
--    i_msg    IN - message from the mini-load message.
--    i_msg_id IN - message from the mini-load message.
--    o_status OUT - return status from the procedure.
--
-- Called by:
--
-- Exceptions Raised:
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/28/05          Created as part of the mini-load changes.
--    11/10/08          Added call to p_insert_miniload_exception() if update
--                      to inventory fails.
--                      Added populating l_miniload_info.n_msg_id.
--    10/04/17 pkab6563 If the location is not in SWMS, create it before 
--                      proceeding further.
----------------------------------------------------------------------------
   PROCEDURE p_rcv_inv_arr (
      i_msg      IN       MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_id   IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_status   OUT      NUMBER)
   IS
      l_miniload_info                t_miniload_info                  := NULL;
      l_ml_replenishment             t_ml_replenishment               := NULL;
      lv_induction_loc               INV.plogi_loc%TYPE;
      lv_msg_type                    VARCHAR2 (50)              := ct_inv_arr;
      lv_pick_level                  ZONE.max_pick_level%TYPE;
      lv_max_pick_level              ZONE.max_pick_level%TYPE;
      l_dummy                        NUMBER (1);
      lv_pallet_id                   INV.logi_loc%TYPE;
      lv_fname                       VARCHAR2 (50)     := 'P_RCV_INV_ARRIVAL';
      lv_msg_text                    VARCHAR2 (1500);
      l_inv_info                     INV%ROWTYPE;
      ln_pallet_seq                  NUMBER (9);
      lv_user                        INV.upd_user%TYPE;
      ln_status                      NUMBER (1)                 := ct_success;
      lv_is_outbound                 CHAR;
      e_fail                         EXCEPTION;
      e_no_inv_record_updated  EXCEPTION;  -- No inventory record was updated.
      ln_count                       PLS_INTEGER;
      lv_actual_loc                  LOC.logi_loc%TYPE;
      

      -- cursor to select the pending shipping order item status messages
      -- from miniload_order table.
      CURSOR c_ship_order_item_status_chk (
         n_uom                IN   MINILOAD_MESSAGE.UOM%TYPE,
         v_prod_id            IN   MINILOAD_MESSAGE.prod_id%TYPE,
         v_cust_pref_vendor   IN   MINILOAD_MESSAGE.cust_pref_vendor%TYPE
      )
      IS
         SELECT   quantity_requested, quantity_available, order_id,
                  order_priority, message_id, MESSAGE_TYPE
             FROM MINILOAD_ORDER
            WHERE prod_id = v_prod_id
              AND cust_pref_vendor = v_cust_pref_vendor
              -- AND uom = n_uom
              -- AND add_date >= TRUNC (SYSDATE)
              AND MESSAGE_TYPE = ct_ship_ord_status
              AND status = 'I'
         ORDER BY order_priority, add_date DESC;

      r_ship_order_item_status_chk   c_ship_order_item_status_chk%ROWTYPE;
   BEGIN
      -- Reset the global variable
      Pl_Text_Log.init ('pl_miniload_processing.p_rcv_inv_arr');

      l_miniload_info := f_parse_message (i_msg, lv_msg_type);
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Message_id: '
         || i_msg_id
         || ' Msg Type: '
         || lv_msg_type
         || ' Prod Id: '
         || l_miniload_info.v_prod_id
         || ' CPV: '
         || l_miniload_info.v_cust_pref_vendor
         || ' UOM: '
         || l_miniload_info.n_uom
         || ' Plogi_loc: '
         || l_miniload_info.vt_inv_arrival_info.v_actual_loc
         || ' Logi_loc'
         || l_miniload_info.vt_inv_arrival_info.v_label;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

      l_miniload_info.n_msg_id := i_msg_id;

      -- check to see if the miniload location is in loc table
      lv_actual_loc := l_miniload_info.vt_inv_arrival_info.v_actual_loc;
      SELECT COUNT(logi_loc) 
         INTO ln_count
      FROM loc
      WHERE logi_loc = lv_actual_loc;

      -- if location is not in loc, create it.
      IF (ln_count <= 0) THEN
         lv_msg_text := 
               'Location <' 
            || lv_actual_loc
            || '> NOT found in SWMS.loc table; attempting to add it to SWMS now.';
         pl_log.ins_msg
           ('INFO',
            lv_fname,
            lv_msg_text,
            NULL,
            NULL,
            ct_application_function,
            gl_pkg_name);

         p_create_missing_location (lv_actual_loc, ln_status);
         IF (ln_status = ct_failure) THEN
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Message_id: '
               || i_msg_id
               || ' Procedure Name '
               || lv_fname
               || ' Could not create missing location <'
               || lv_actual_loc
               || '>';
            RAISE e_no_inv_record_updated;
         END IF;
      END IF; -- if location not in loc table 

      -- Update the logi_loc to actual location.
      SELECT REPLACE (lv_user, 'OPS$')
        INTO lv_user
        FROM DUAL;

      -- 5/10/06 - upd 2 tables
      UPDATE INV
         SET plogi_loc = l_miniload_info.vt_inv_arrival_info.v_actual_loc
       WHERE logi_loc         = l_miniload_info.vt_inv_arrival_info.v_label
         AND prod_id          = l_miniload_info.v_prod_id
         AND cust_pref_vendor = l_miniload_info.v_cust_pref_vendor;

      IF (SQL%ROWCOUNT = 0) THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Inventory update failed for: '
            || ' Carrier Id = '
            || l_miniload_info.vt_inv_arrival_info.v_label
            || ' actual loc = '
            || l_miniload_info.vt_inv_arrival_info.v_actual_loc
            || ' Prod Id = '
            || l_miniload_info.v_prod_id;
         RAISE e_no_inv_record_updated;
      END IF;

      -- if there's a possibility of RPL, change src loacation too
      IF (SUBSTR (l_miniload_info.vt_inv_arrival_info.v_sku, 1, 1) = 2)
      THEN
         UPDATE REPLENLST
            SET src_loc = l_miniload_info.vt_inv_arrival_info.v_actual_loc
          WHERE orig_pallet_id = l_miniload_info.vt_inv_arrival_info.v_label
            AND status = 'NEW'
            AND TYPE = 'MNL'
            AND prod_id = l_miniload_info.v_prod_id
            AND cust_pref_vendor = l_miniload_info.v_cust_pref_vendor;
      END IF;

      l_miniload_info.v_trans_type := 'MIA';
      p_insert_miniload_trans (l_miniload_info, lv_msg_type, ln_status);

      IF (ln_status = ct_failure) THEN
         l_miniload_info.v_status := 'F';
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Procedure Name '
            || lv_fname
            || ' Insert into miniload_trans failed '
            || l_miniload_info.v_status;
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
         RAISE e_fail;
      END IF;

      -- if a case moves down to pick face, see if it is split RPL related?
      IF (SUBSTR (l_miniload_info.vt_inv_arrival_info.v_sku, 1, 1) = 2)
      THEN
         --if the actual location is a pick face location, then check for pending shipping order item status messages.
         BEGIN
            SELECT 'Y'
              INTO lv_is_outbound
              FROM ZONE
             WHERE outbound_loc =
                              l_miniload_info.vt_inv_arrival_info.v_actual_loc;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               lv_is_outbound := 'N';
            WHEN TOO_MANY_ROWS
            THEN
               lv_is_outbound := 'Y';
         END;

         lv_pick_level :=
            SUBSTR (TRIM (l_miniload_info.vt_inv_arrival_info.v_actual_loc),
                    -1,
                    1
                   );

         BEGIN
            SELECT z.max_pick_level
              INTO lv_max_pick_level
              FROM ZONE z, LZONE lz
             WHERE lz.logi_loc =
                              l_miniload_info.vt_inv_arrival_info.v_actual_loc
               AND z.zone_id = lz.zone_id
               AND z.ZONE_TYPE = 'PUT';
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Message_id: '
                  || i_msg_id
                  || ' TABLE=zone,lzone'
                  || ' ACTION=SELECT MESSAGE= max_pick_level not found in zone and lzone tables'
                  || ' KEY:[logi_loc,zone_type]=['
                  || l_miniload_info.vt_inv_arrival_info.v_actual_loc
                  || ',PUT]';
               Pl_Text_Log.ins_msg ('FATAL',
                                    lv_fname,
                                    lv_msg_text,
                                    SQLCODE,
                                    SQLERRM
                                   );
               ln_status := ct_failure;
               RAISE e_fail;
            WHEN OTHERS
            THEN
               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Message_id: '
                  || i_msg_id
                  || ' TABLE=zone,lzone'
                  || ' ACTION=SELECT MESSAGE= could not select max_pick_level'
                  || ' KEY:[logi_loc,zone_type]=['
                  || l_miniload_info.vt_inv_arrival_info.v_actual_loc
                  || ',PUT]';
               Pl_Text_Log.ins_msg ('FATAL',
                                    lv_fname,
                                    lv_msg_text,
                                    SQLCODE,
                                    SQLERRM
                                   );
               ln_status := ct_failure;
               RAISE e_fail;
         END;

         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Pick Level: '
            || lv_pick_level
            || ' Max Pick Level: '
            || lv_max_pick_level;
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

         IF lv_pick_level <= lv_max_pick_level OR lv_is_outbound = 'Y'
         THEN
            IF NOT c_ship_order_item_status_chk%ISOPEN
            THEN
               OPEN c_ship_order_item_status_chk
                                          (l_miniload_info.n_uom,
                                           l_miniload_info.v_prod_id,
                                           l_miniload_info.v_cust_pref_vendor
                                          );
            END IF;

            LOOP
               FETCH c_ship_order_item_status_chk
                INTO r_ship_order_item_status_chk;

               EXIT WHEN c_ship_order_item_status_chk%NOTFOUND
                     OR c_ship_order_item_status_chk%NOTFOUND IS NULL;
               l_ml_replenishment.v_prod_id := l_miniload_info.v_prod_id;
               l_ml_replenishment.v_cust_pref_vendor :=
                                            l_miniload_info.v_cust_pref_vendor;
               l_ml_replenishment.n_uom := l_miniload_info.n_uom;

               /*
                 l_ml_replenishment.n_replen_qty :=
                    f_convert_to_splits(l_miniload_info.n_uom,
                                        l_miniload_info.v_prod_id,
                                        l_miniload_info.v_cust_pref_vendor,
                                        r_ship_order_item_status_chk.quantity_requested
                                      - r_ship_order_item_status_chk.quantity_available);
               */
               SELECT CEIL
                          (  (  r_ship_order_item_status_chk.quantity_requested
                              - r_ship_order_item_status_chk.quantity_available
                             )
                           / (case_qty_for_split_rpl * spc)
                          )
                 INTO l_ml_replenishment.n_replen_qty
                 FROM PM
                WHERE prod_id = l_miniload_info.v_prod_id
                  AND cust_pref_vendor = l_miniload_info.v_cust_pref_vendor;

               l_ml_replenishment.n_replen_qty :=
                  f_convert_to_splits (l_miniload_info.n_uom,
                                       l_miniload_info.v_prod_id,
                                       l_miniload_info.v_cust_pref_vendor,
                                       l_ml_replenishment.n_replen_qty
                                      );
               l_ml_replenishment.v_replen_type := 'MNL';
               l_ml_replenishment.v_src_loc :=
                              l_miniload_info.vt_inv_arrival_info.v_actual_loc;
               l_ml_replenishment.v_order_id :=
                                         r_ship_order_item_status_chk.order_id;

/* Malini 31-mar-06 Beg Del
         l_ml_replenishment.v_priority :=
                        r_ship_order_item_status_chk.order_priority;
   Malini 31-mar-06 End Del */
--Malini 31-mar-06 Beg Add
               BEGIN
                  SELECT priority_value
                    INTO l_ml_replenishment.v_priority
                    FROM priority_code
                   WHERE priority_code   = 'HGH'
                     AND unpack_code = 'Y';  -- 3/23/2010  Brian Bent Added
               EXCEPTION
                  WHEN OTHERS THEN
                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Query to select Priority Value for  priority code "HGH" from '
                        || ' TABLE=priority_code';
                     RAISE e_fail;
               END;

--Malini 31-mar-06 End Add
               l_ml_replenishment.v_user_id := lv_user;

               SELECT ml_pallet_id_seq.NEXTVAL
                 INTO lv_pallet_id
                 FROM DUAL;

               l_ml_replenishment.v_pallet_id :=
                     l_miniload_info.vt_inv_arrival_info.v_actual_loc
                  || lv_pallet_id;
               Pl_Ml_Common.get_induction_loc
                                          (l_miniload_info.v_prod_id,
                                           l_miniload_info.v_cust_pref_vendor,
                                           l_miniload_info.n_uom,
                                           ln_status,
                                           l_ml_replenishment.v_dest_loc
                                          );

               IF (ln_status <> ct_success)
               THEN
                  lv_msg_text :=
                        'Prog Code: '
                     || ct_program_code
                     || ' Message_id: '
                     || i_msg_id
                     || ' Error in getting Induction Location.'
                     || ' Prod_id: '
                     || l_miniload_info.v_prod_id
                     || ', CPV: '
                     || l_miniload_info.v_cust_pref_vendor
                     || ', UOM: '
                     || l_miniload_info.n_uom;
                  Pl_Text_Log.ins_msg ('FATAL',
                                       lv_fname,
                                       lv_msg_text,
                                       NULL,
                                       NULL);
                  ln_status := ct_failure;
               ELSE
                  lv_msg_text :=
                        'Prog Code: '
                     || ct_program_code
                     || ' Message_id: '
                     || i_msg_id
                     || ' Destination Location: '
                     || l_ml_replenishment.v_dest_loc;
                  Pl_Text_Log.ins_msg ('WARNING',
                                       lv_fname,
                                       lv_msg_text,
                                       NULL,
                                       NULL);
               END IF;

               BEGIN
                  IF (ln_status != ct_failure)
                  THEN
                     SELECT pik_path
                       INTO l_ml_replenishment.v_s_pikpath
                       FROM LOC
                      WHERE logi_loc =
                               l_miniload_info.vt_inv_arrival_info.v_actual_loc;
                  END IF;
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Message_id: '
                        || i_msg_id
                        || ' TABLE=loc'
                        || ' ACTION=SELECT MESSAGE= Pikpath not in loc table for location'
                        || l_ml_replenishment.v_s_pikpath;
                     Pl_Text_Log.ins_msg ('FATAL',
                                          lv_fname,
                                          lv_msg_text,
                                          SQLCODE,
                                          SQLERRM
                                         );
                     ln_status := ct_failure;
                  WHEN OTHERS
                  THEN
                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Message_id: '
                        || i_msg_id
                        || ' Oracle could not select from loc table';
                     Pl_Text_Log.ins_msg ('FATAL',
                                          lv_fname,
                                          lv_msg_text,
                                          SQLCODE,
                                          SQLERRM
                                         );
                     ln_status := ct_failure;
               END;

               BEGIN
                  IF (ln_status != ct_failure)
                  THEN
                     SELECT pik_path
                       INTO l_ml_replenishment.v_d_pikpath
                       FROM LOC
                      WHERE logi_loc = l_ml_replenishment.v_dest_loc;
                  END IF;
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Message_id: '
                        || i_msg_id
                        || ' TABLE=loc'
                        || ' ACTION=SELECT MESSAGE= pikpath not found in loc table for location :'
                        || l_ml_replenishment.v_dest_loc;
                     Pl_Text_Log.ins_msg ('FATAL',
                                          lv_fname,
                                          lv_msg_text,
                                          SQLCODE,
                                          SQLERRM
                                         );
                     ln_status := ct_failure;
                  WHEN OTHERS
                  THEN
                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Message_id: '
                        || i_msg_id
                        || ' Oracle could not select from loc table';
                     Pl_Text_Log.ins_msg ('FATAL',
                                          lv_fname,
                                          lv_msg_text,
                                          SQLCODE,
                                          SQLERRM
                                         );
                     ln_status := ct_failure;
               END;

               BEGIN
                  IF (ln_status != ct_failure)
                  THEN
                     SELECT exp_date,
                            parent_pallet_id
                       INTO l_ml_replenishment.v_exp_date,
                            l_ml_replenishment.v_parent_pallet_id
                       FROM INV
                      WHERE logi_loc =
                                   l_miniload_info.vt_inv_arrival_info.v_label;
                  END IF;
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Message_id: '
                        || i_msg_id
                        || ' TABLE=inv'
                        || ' ACTION=SELECT MESSAGE= exp_date or parent pallet_id not found inv table';
                     Pl_Text_Log.ins_msg ('FATAL',
                                          lv_fname,
                                          lv_msg_text,
                                          SQLCODE,
                                          SQLERRM
                                         );
                     ln_status := ct_failure;
                  WHEN OTHERS
                  THEN
                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Message_id: '
                        || i_msg_id
                        || ' Oracle could not select from inv table';
                     Pl_Text_Log.ins_msg ('FATAL',
                                          lv_fname,
                                          lv_msg_text,
                                          SQLCODE,
                                          SQLERRM
                                         );
                     ln_status := ct_failure;
               END;

               l_ml_replenishment.v_orig_pallet_id :=
                                   l_miniload_info.vt_inv_arrival_info.v_label;
               p_insert_replen (l_ml_replenishment, ln_status);

               IF (ln_status = ct_success)
               THEN
                  UPDATE INV
                     SET qty_alloc =
                                (qty_alloc + l_ml_replenishment.n_replen_qty
                                )
                   WHERE logi_loc =
                                   l_miniload_info.vt_inv_arrival_info.v_label;

                  IF (SQL%ROWCOUNT = 0)
                  THEN
                     lv_msg_text :=
                           'Prog Code'
                        || ct_program_code
                        || ' Message_id: '
                        || i_msg_id
                        || ' Inventory update failed for: '
                        || ' Carrier Id = '
                        || l_miniload_info.vt_inv_arrival_info.v_label;
                     Pl_Text_Log.ins_msg ('FATAL',
                                          lv_fname,
                                          lv_msg_text,
                                          SQLCODE,
                                          SQLERRM
                                         );
                     ln_status := ct_failure;
                  END IF;

                  BEGIN
                     SELECT ABC, abc_gen_date,
                            add_date, case_type_tmu,
                            exp_date, exp_ind,
                            inv_date, lot_id,
                            lst_cycle_date,
                            lst_cycle_reason,
                            mfg_date, min_qty,
                            pallet_height, rec_date,
                            rec_id, status,
                            temperature, weight
                       INTO l_inv_info.ABC, l_inv_info.abc_gen_date,
                            l_inv_info.add_date, l_inv_info.case_type_tmu,
                            l_inv_info.exp_date, l_inv_info.exp_ind,
                            l_inv_info.inv_date, l_inv_info.lot_id,
                            l_inv_info.lst_cycle_date,
                            l_inv_info.lst_cycle_reason,
                            l_inv_info.mfg_date, l_inv_info.min_qty,
                            l_inv_info.pallet_height, l_inv_info.rec_date,
                            l_inv_info.rec_id, l_inv_info.status,
                            l_inv_info.temperature, l_inv_info.weight
                       FROM INV
                      WHERE logi_loc =
                                   l_miniload_info.vt_inv_arrival_info.v_label
                        AND plogi_loc =
                               l_miniload_info.vt_inv_arrival_info.v_actual_loc
                        AND prod_id = l_ml_replenishment.v_prod_id;
                  EXCEPTION
                     WHEN NO_DATA_FOUND
                     THEN
                        lv_msg_text :=
                              'Prog Code: '
                           || ct_program_code
                           || ' TABLE=inv'
                           || ' ACTION=SELECT MESSAGE= record not found inv table'
                           || ' logi_loc = '
                           || l_miniload_info.vt_inv_arrival_info.v_label;
                        Pl_Text_Log.ins_msg ('FATAL',
                                             lv_fname,
                                             lv_msg_text,
                                             SQLCODE,
                                             SQLERRM
                                            );
                        ln_status := ct_failure;
                     WHEN OTHERS
                     THEN
                        lv_msg_text :=
                              'Prog Code: '
                           || ct_program_code
                           || ' Oracle could not select from inv table';
                        Pl_Text_Log.ins_msg ('FATAL',
                                             lv_fname,
                                             lv_msg_text,
                                             SQLCODE,
                                             SQLERRM
                                            );
                        ln_status := ct_failure;
                  END;

                  IF (ln_status != ct_failure)
                  THEN
                     l_inv_info.logi_loc := l_ml_replenishment.v_pallet_id;
                     l_inv_info.prod_id := l_ml_replenishment.v_prod_id;
                     l_inv_info.cust_pref_vendor :=
                                        l_ml_replenishment.v_cust_pref_vendor;
                     l_inv_info.plogi_loc := l_ml_replenishment.v_dest_loc;
                     l_inv_info.qoh := 0;
                     l_inv_info.qty_alloc := 0;
                     l_inv_info.qty_planned :=
                                              l_ml_replenishment.n_replen_qty;
                     l_inv_info.CUBE := 999;
                     l_inv_info.parent_pallet_id := NULL;
                     l_inv_info.dmg_ind := NULL;
                     --l_inv_info.inv_uom := l_ml_replenishment.n_uom;
                     l_inv_info.inv_uom := 1;                      -- 5/19/06
                     p_insert_inv (l_inv_info, o_status);
                  END IF;
               ELSE                                -- If p_insert_replen fails
                  lv_msg_text :=
                        'Prog Code:'
                     || ct_program_code
                     || ' p_insert_replen failed';
                  Pl_Text_Log.ins_msg ('FATAL',
                                       lv_fname,
                                       lv_msg_text,
                                       NULL,
                                       NULL);
               END IF;

               IF (ln_status = ct_success)
               THEN
                  l_miniload_info.v_status := 'S';
               ELSE
                  l_miniload_info.v_status := 'F';
               END IF;

               p_upd_status (r_ship_order_item_status_chk.message_id,
                             r_ship_order_item_status_chk.MESSAGE_TYPE,
                             l_miniload_info.v_status,
                             o_status
                            );
            END LOOP;

            IF (c_ship_order_item_status_chk%ISOPEN)
            THEN
               CLOSE c_ship_order_item_status_chk;
            END IF;
         END IF;
      END IF;

/*
** acpmxp 20-Feb-2006 Beg Del This is taken care of during CC processing
    UPDATE cc
      SET phys_loc = l_miniload_info.vt_inv_arrival_info.v_actual_loc,
          upd_user = lv_user,
          upd_date = SYSDATE
    WHERE logi_loc = l_miniload_info.vt_inv_arrival_info.v_label;

    UPDATE cc_edit
      SET phys_loc = l_miniload_info.vt_inv_arrival_info.v_actual_loc,
          upd_user = lv_user,
          upd_date = SYSDATE
    WHERE logi_loc = l_miniload_info.vt_inv_arrival_info.v_label;

    UPDATE cc_exception_list
      SET phys_loc = l_miniload_info.vt_inv_arrival_info.v_actual_loc
    WHERE logi_loc = l_miniload_info.vt_inv_arrival_info.v_label;

** acpmxp 20-Feb-2006 End Del This is taken care of during CC processing
*/



      IF ln_status = ct_success
      THEN
         l_miniload_info.v_status := 'S';
      ELSE
         l_miniload_info.v_status := 'F';
      END IF;

      o_status := ln_status;
      p_upd_status (i_msg_id, lv_msg_type, l_miniload_info.v_status, o_status);
   EXCEPTION
      WHEN e_no_inv_record_updated THEN
         --
         -- No inventory record was updated with the arrival location.
         -- Most likely because SWMS no longer has the carrier or SWMS
         -- has a different item on the carrier.
         --
         l_miniload_info.v_status := 'F';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status);
         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);

         --
         -- Write an exception log.
         -- We will ignore the return status of p_insert_miniload_exception.
         --
         p_insert_miniload_exception(l_miniload_info,
                                     lv_msg_type,
                                     ln_status);
         o_status := ct_failure;
      WHEN e_fail THEN
         l_miniload_info.v_status := 'F';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status);
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS THEN
         l_miniload_info.v_status := 'F';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status);
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in processing inventory arrival message';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_rcv_inv_arr;

-------------------------------------------------------------------------
-- Procedure:
--    p_rcv_inv_lost
--
-- Description:
--     This procedure Notifies SWMS on a lost inventory
--
-- Parameters:
--    i_msg_id - Message id
--    i_msg  - Inventory Lost msg details
--    o_status - status
--       0  - No errors.
--       1  - Error occured.
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/30/05          Created as part of the mini-load changes
-------------------------------------------------------------------------
   PROCEDURE p_rcv_inv_lost (
      i_msg      IN       MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_id   IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_status   OUT      NUMBER
   )
   IS
      l_miniload_info   t_miniload_info;
      lv_msg_type       VARCHAR2 (50)                  := ct_inv_lost;
      ln_status         NUMBER (1)                     := ct_success;
      --Hold return status of procedures
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)                  := 'P_RCV_INV_LOST';
      lv_msg_status     MINILOAD_MESSAGE.status%TYPE   := 'S';
      e_fail            EXCEPTION;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_rcv_inv_lost');
      l_miniload_info := f_parse_message (i_msg, lv_msg_type);
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Type: '
         || lv_msg_type
         || ' Msg Id: '
         || i_msg_id
         || ' Prod Id: '
         || l_miniload_info.v_prod_id
         || ' CPV: '
         || l_miniload_info.v_cust_pref_vendor
         || ' UOM: ';
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      p_insert_miniload_exception (l_miniload_info, lv_msg_type, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_exception';
         RAISE e_fail;
      END IF;

      p_upd_status (i_msg_id, lv_msg_type, lv_msg_status, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_upd_status';
         RAISE e_fail;
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         l_miniload_info.v_status := 'F';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status
                      );
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         l_miniload_info.v_status := 'F';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status
                      );
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_rcv_inv_lost';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_rcv_inv_lost;

---------------------------------------------------------------------------
-- Procedure:
--    p_rcv_inv_planned_move
--
-- Description:
--     This procedure processes the carrier "planned move" message sent by the
--     miniloader.
--
--     If the processing of the planned move fails, which can happen if SWMS
--     no longer has the carrier or SWMS has another item on the carrier,
--     then a miniload exception record is created.
--
-- Parameters:
--    i_msg_id - Message ID
--    o_status:
--       0  - No errors.
--       1  - Error occured.
--
-- Exceptions Raised:
--    e_fail  If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/29/05          Created as part of the mini-load changes
--    11/10/08          Added call to p_insert_miniload_exception().
--                      Added populating l_miniload_info.n_msg_id.
--    10/04/17 pkab6563 If the planned loc is not in SWMS, create it
--                      before proceeding further. 
-------------------------------------------------------------------------
   PROCEDURE p_rcv_inv_planned_move
         (i_msg      IN       miniload_message.ml_data%TYPE,
          i_msg_id   IN       miniload_message.message_id%TYPE,
          o_status   OUT      NUMBER)
   IS
      l_miniload_info   t_miniload_info;
      lv_msg_type       VARCHAR2 (50)                  := ct_inv_plan_mov;
      ln_status         NUMBER (1)                     := ct_success;
      --Hold return status of functions
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)             := 'P_RCV_INV_PLANNED_MOVE';
      lv_msg_status     MINILOAD_MESSAGE.status%TYPE   := 'S';

      e_fail                   EXCEPTION;
      e_no_inv_record_updated  EXCEPTION;  -- No inventory record was updated.
     
      lv_planned_loc           LOC.logi_loc%TYPE;
      ln_count                 PLS_INTEGER;

   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_rcv_inv_planned_move');
      l_miniload_info := f_parse_message (i_msg, lv_msg_type);
      p_upd_status (i_msg_id, lv_msg_type, lv_msg_status, ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Error in executing p_upd_status';
         RAISE e_fail;
      END IF;

      l_miniload_info.n_msg_id := i_msg_id;

---------------------
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Message_id: '
         || i_msg_id
         || ' Msg Type: '
         || lv_msg_type
         || ' Prod Id: '
         || l_miniload_info.v_prod_id
         || ' CPV: '
         || l_miniload_info.v_cust_pref_vendor
         || ' UOM: '
         || l_miniload_info.n_uom
         || ' Plogi_loc: '
         || l_miniload_info.vt_inv_planned_mov_info.v_planned_loc
         || ' Logi_loc: '
         || l_miniload_info.vt_inv_planned_mov_info.v_label;
      pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

      -- check to ensure planned loc is in SWMS.loc table
      lv_planned_loc := l_miniload_info.vt_inv_planned_mov_info.v_planned_loc;
      SELECT COUNT(logi_loc)
         INTO ln_count
      FROM loc
      WHERE logi_loc = lv_planned_loc;

      -- if location is not in loc, create it.
      IF (ln_count <= 0) THEN
         lv_msg_text :=
               'Location <'
            || lv_planned_loc
            || '> NOT found in SWMS.loc table; attempting to add it to SWMS now.';
         pl_log.ins_msg
           ('INFO',
            lv_fname,
            lv_msg_text,
            NULL,
            NULL,
            ct_application_function,
            gl_pkg_name);

         p_create_missing_location (lv_planned_loc, ln_status);
         IF (ln_status = ct_failure) THEN
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Message_id: '
               || i_msg_id
               || ' Procedure Name '
               || lv_fname
               || ' Could not create missing location <'
               || lv_planned_loc
               || '>';
            RAISE e_no_inv_record_updated;
         END IF;
      END IF; -- if location not in loc table

      UPDATE INV
         SET plogi_loc = l_miniload_info.vt_inv_planned_mov_info.v_planned_loc
       WHERE logi_loc         = l_miniload_info.vt_inv_planned_mov_info.v_label
         AND prod_id          = l_miniload_info.v_prod_id
         AND cust_pref_vendor = l_miniload_info.v_cust_pref_vendor;

      IF (SQL%ROWCOUNT = 0) THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Inventory update failed for: '
            || ' Carrier Id = '
            || l_miniload_info.vt_inv_planned_mov_info.v_label
            || ' planned loc = '
            || l_miniload_info.vt_inv_planned_mov_info.v_planned_loc
            || ' Prod Id = '
            || l_miniload_info.v_prod_id;
         RAISE e_no_inv_record_updated;
      END IF;

      --
      -- If there's a possibility of RPL, change src location too.
      --
      IF (SUBSTR (l_miniload_info.vt_inv_planned_mov_info.v_sku, 1, 1) = 2)
      THEN
         UPDATE REPLENLST
            SET src_loc =
                         l_miniload_info.vt_inv_planned_mov_info.v_planned_loc
          WHERE orig_pallet_id =
                               l_miniload_info.vt_inv_planned_mov_info.v_label
            AND status = 'NEW'
            AND TYPE = 'MNL'
            AND prod_id = l_miniload_info.v_prod_id
            AND cust_pref_vendor = l_miniload_info.v_cust_pref_vendor;
      END IF;

---------------------
      o_status := ct_success;
   EXCEPTION
      WHEN e_no_inv_record_updated THEN
         --
         -- No inventory record was updated with the planned location.
         -- Most likely because SWMS no longer has the carrier or SWMS
         -- has a different item on the carrier.
         --
         lv_msg_status := 'F';
         p_upd_status (i_msg_id, lv_msg_type, lv_msg_status, ln_status);

         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);

         --
         -- Write an exception log.
         -- We will ignore the return status of p_insert_miniload_exception.
         --
         p_insert_miniload_exception(l_miniload_info,
                                     lv_msg_type,
                                     ln_status);
         o_status := ct_failure;
      WHEN e_fail THEN
         lv_msg_status := 'F';
         p_upd_status (i_msg_id, lv_msg_type, lv_msg_status, ln_status);

         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);

         o_status := ct_failure;
      WHEN OTHERS THEN
         lv_msg_status := 'F';
         p_upd_status (i_msg_id, lv_msg_type, lv_msg_status, ln_status);
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Error in executing p_rcv_inv_planned_move';

         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);

         o_status := ct_failure;
   END p_rcv_inv_planned_move;

-------------------------------------------------------------------------
-- PROCEDURE:
--    p_rcv_er_complete
--
-- Description:
--     This procedure processes ER complete message from mini-load.
--
-- Parameters:
--    i_msg       - message from the mini-load.
--    i_msg_id    - message ID in miniload_message
--   o_status - return status
--          0  - No errors.
--          1  - Error occured
--
-- Exceptions Raised:
--    e_fail - When an error occcurs 1 is returned
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/21/05          Created as part of the mini-load changes.
----------------------------------------------------------------------------
   PROCEDURE p_rcv_er_complete (
      i_msg      IN       MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_id   IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_status   OUT      NUMBER
   )
   IS
      l_miniload_info   t_miniload_info;
      lv_msg_type       VARCHAR2 (50)   := ct_exp_rec_comp;
      lv_fname          VARCHAR2 (50)   := 'P_RCV_ER_COMPLETE';
      lv_msg_text       VARCHAR2 (1500);
      ln_status         NUMBER (1)      := ct_success;
      e_fail            EXCEPTION;
   BEGIN
      --reset the global variable
      Pl_Text_Log.init ('pl_miniload_processing.p_rcv_er_complete');
      -- split the raw data.
      l_miniload_info := f_parse_message (i_msg, lv_msg_type);
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Type: '
         || lv_msg_type
         || ' Msg Id: '
         || i_msg_id
         || ' Qty Exp: '
         || l_miniload_info.vt_exp_receipt_complete_info.n_qty_exp
         || ' Qty Rcv: '
         || l_miniload_info.vt_exp_receipt_complete_info.n_qty_rcv;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

      -- Log an exception message, if there is discrepencies in qty expected
      -- and actual qty received.
      IF l_miniload_info.vt_exp_receipt_complete_info.n_qty_exp !=
                        l_miniload_info.vt_exp_receipt_complete_info.n_qty_rcv
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Qty mismatch in Qty Expected and'
            || ' Actual Qty Received '
            || lv_msg_type;
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         p_insert_miniload_exception (l_miniload_info, lv_msg_type, ln_status);
      END IF;

      IF (ln_status = ct_success)
      THEN
         l_miniload_info.v_status := 'S';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status
                      );
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || 'Expected receipt complete message processed';
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      ELSE
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Error in executing p_insert_miniload_exception';
         RAISE e_fail;
      END IF;

      o_status := ln_status;
   EXCEPTION
      WHEN e_fail
      THEN
         l_miniload_info.v_status := 'F';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status
                      );
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         l_miniload_info.v_status := 'F';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status
                      );
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Error in Expected receipt complete message processing';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_rcv_er_complete;
-------------------------------------------------------------------------
-- PROCEDURE:
--    p_rcv_msg_status
--
-- Description:
--     This procedure processes 'MessageStatus' from Miniload
--
-- Parameters:
--    i_msg       - message from the mini-load.
--    i_msg_id    - message ID in miniload_message
--   o_status - return status
--          0  - No errors.
--          1  - Error occured
--
-- Exceptions Raised:
--    e_fail - When an error occcurs 1 is returned
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/14/07 ctvgg000 Created as part of HK Integration
----------------------------------------------------------------------------
   PROCEDURE p_rcv_msg_status (
      i_msg      IN       MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_id   IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_status   OUT      NUMBER
   )
   IS
      l_miniload_info   t_miniload_info;
      lv_msg_type       VARCHAR2 (50)   := ct_message_status;
      lv_fname          VARCHAR2 (50)   := 'P_RCV_MSG_STATUS';
      lv_msg_text       VARCHAR2 (1500);
      ln_status         NUMBER (1)      := ct_success;      
      e_fail            EXCEPTION;
   BEGIN
      --reset the global variable
      Pl_Text_Log.init ('pl_miniload_processing.p_rcv_msg_status');
      -- split the raw data.
      l_miniload_info := f_parse_message (i_msg, lv_msg_type);
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Type: '
         || lv_msg_type
         || ' Msg Id: '
         || i_msg_id     
         || ' Message Status: '
         || l_miniload_info.vt_msg_status_info.v_msg_status;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
        
      BEGIN
          
        SELECT prod_id, cust_pref_vendor, uom
        INTO l_miniload_info.v_prod_id, 
             l_miniload_info.v_cust_pref_vendor, 
             l_miniload_info.n_uom             
        FROM miniload_message                
        WHERE message_id = l_miniload_info.vt_msg_status_info.v_msg_id;
        
        
        EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_msg_text :=
                            'Prog Code: '
                            || ct_program_code
                            || ' Message_id: '
                            || i_msg_id
                            || ' TABLE=miniload_message'
                            || ' ACTION=SELECT MESSAGE= Carrier Status message not found :';                
                        Pl_Text_Log.ins_msg ('FATAL',
                                            lv_fname,
                                            lv_msg_text,
                                            SQLCODE,
                                            SQLERRM
                                            );
                        ln_status := ct_failure;
                    WHEN OTHERS
                    THEN
                        lv_msg_text :=
                            'Prog Code: '
                            || ct_program_code
                            || ' Message_id: '
                            || i_msg_id
                            || ' Oracle could not select from miniload_message table';
                        Pl_Text_Log.ins_msg ('FATAL',
                                            lv_fname,
                                            lv_msg_text,
                                            SQLCODE,
                                            SQLERRM
                                            );
                        ln_status := ct_failure;                        
        END;
          
                                     
      lv_msg_text :=
            'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || 'Carrier Status not processed by Miniload'            
            || lv_msg_type;
      Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
      
      p_insert_miniload_exception (l_miniload_info, lv_msg_type, ln_status);                  
      
      IF (ln_status = ct_success)
      THEN
         l_miniload_info.v_status := 'S';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status
                      );
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || 'MessageStatus message processing complete ';
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      ELSE
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Error in executing p_insert_miniload_exception';
         RAISE e_fail;
      END IF;

      o_status := ln_status;
   EXCEPTION
      WHEN e_fail
      THEN         
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;    
      WHEN OTHERS
      THEN
         l_miniload_info.v_status := 'F';
         p_upd_status (i_msg_id,
                       lv_msg_type,
                       l_miniload_info.v_status,
                       ln_status
                      );
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message_id: '
            || i_msg_id
            || ' Error in MessageStatus message processing';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_rcv_msg_status;

-------------------------------------------------------------------------
-- Procedure:
--    p_insert_ml_pickcomplete
--
-- Description:
--     This procedure fills the order data into ml_pickcomplete table.
--
-- Parameters:
--    o_status: Return Values:
--       0  - No errors.
--       1  - Error occured.
--
-- Exceptions Raised:
--    None. If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/01/05          Created as part of the mini-load changes
---------------------------------------------------------------------------
   PROCEDURE p_insert_ml_pickcomplete (o_status OUT NUMBER)
   IS
      lv_qty_alloc           FLOAT_DETAIL.qty_alloc%TYPE;
      lv_prod_id             FLOAT_DETAIL.prod_id%TYPE;
      lv_cust_pref_vendor    FLOAT_DETAIL.cust_pref_vendor%TYPE;
      ln_uom                 FLOAT_DETAIL.UOM%TYPE;
      lv_src_loc             FLOAT_DETAIL.src_loc%TYPE;
      lv_carrier_id          INV.logi_loc%TYPE;
      lv_min_fd_alloc_time   FLOAT_DETAIL.alloc_time%TYPE;
      lv_msg_text            VARCHAR2 (1500);
      lv_fname               VARCHAR2 (50)      := 'P_INSERT_ML_PICKCOMPLETE';

      CURSOR c_pick_data
      IS
         SELECT   SUM (fd.qty_alloc), MIN (alloc_time), fd.prod_id,
                  fd.cust_pref_vendor, fd.UOM, fd.src_loc, fd.carrier_id
             FROM FLOAT_DETAIL fd, ORDD od, PM p, LZONE lz, ZONE z
            WHERE fd.order_id = od.order_id
              AND fd.order_line_id = od.order_line_id
              AND fd.prod_id = p.prod_id
              AND fd.cust_pref_vendor = p.cust_pref_vendor
              AND fd.UOM IS NOT NULL
              AND NVL (p.miniload_storage_ind, 'N') <> 'N'
              AND fd.src_loc = lz.logi_loc
              AND lz.zone_id = z.zone_id
              AND z.rule_id = 3
              AND z.ZONE_TYPE = 'PUT'
         GROUP BY fd.prod_id,
                  fd.cust_pref_vendor,
                  fd.UOM,
                  fd.src_loc,
                  fd.carrier_id
         ORDER BY fd.prod_id,
                  fd.cust_pref_vendor,
                  fd.UOM,
                  fd.src_loc,
                  fd.carrier_id;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_insert_ml_pickcomplete');

      IF NOT c_pick_data%ISOPEN
      THEN
         OPEN c_pick_data;
      END IF;

      LOOP
         FETCH c_pick_data
          INTO lv_qty_alloc, lv_min_fd_alloc_time, lv_prod_id,
               lv_cust_pref_vendor, ln_uom, lv_src_loc, lv_carrier_id;

         EXIT WHEN c_pick_data%NOTFOUND OR c_pick_data%NOTFOUND IS NULL;

         INSERT INTO MINILOAD_PICKCOMPLETE
                     (qty_alloc, min_fd_alloc_time, prod_id,
                      cust_pref_vendor, UOM, src_loc,
                      carrier_id, pick_complete_ind)
              VALUES (lv_qty_alloc, lv_min_fd_alloc_time, lv_prod_id,
                      lv_cust_pref_vendor, ln_uom, lv_src_loc,
                      lv_carrier_id, 'N');

         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Insertion in miniload_pickcomplete'
            || ' prod_id:'
            || lv_prod_id
            || ' cust pref vendor :'
            || lv_cust_pref_vendor
            || ' uom :'
            || ln_uom
            || ' qty alloc: '
            || lv_qty_alloc
            || ' src loc: '
            || lv_src_loc;
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      END LOOP;

      IF c_pick_data%ISOPEN
      THEN
         CLOSE c_pick_data;
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN OTHERS
      THEN
         IF c_pick_data%ISOPEN
         THEN
            CLOSE c_pick_data;
         END IF;

         lv_msg_text :=
               'Prog Code: ' || ct_program_code || ' Error in ml_pickcomplete';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_insert_ml_pickcomplete;

-------------------------------------------------------------------------
-- Procedure:
--    p_picking_batch_process
--
-- Description:
--    This is a batch process. Once the order generation complete
--    flag is set, It processes the ml_pickcomplete table
--    and calls the procdure p_picking_complete_for_carrier to send
--    to picking complete for carrier messages.
--
-- Parameters:
--
-- Exceptions Raised:
--    None
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/01/05          Created as part of the mini-load changes
---------------------------------------------------------------------------
   PROCEDURE p_picking_batch_process
   IS
      l_picking_complete_info   t_picking_complete_info;
      lv_flag                   SYS_CONFIG.config_flag_val%TYPE;
      lv_msg_text               VARCHAR2 (1500);
      lv_fname                  VARCHAR2 (50)    := 'P_PICKING_BATCH_PROCESS';
      ln_status                 NUMBER (1)                      := ct_success;
      --Hold return status of functions
      e_fail                    EXCEPTION;

      CURSOR c_ml_pickcomplete
      IS
         SELECT   ml.src_loc, ml.prod_id, ml.carrier_id, ml.qty_alloc,
                  ml.pick_complete_ind, ml.UOM, ml.cust_pref_vendor,
                  SUM (fh.qty_alloc) qty_pc
             FROM MINILOAD_PICKCOMPLETE ml, FLOAT_HIST fh
            WHERE ml.src_loc = fh.src_loc
              AND ml.prod_id = fh.prod_id
              AND fh.picktime > ml.min_fd_alloc_time
              AND NVL (fh.qty_short, 0) = 0
              AND pick_complete_ind = 'N'
         GROUP BY ml.src_loc,
                  ml.carrier_id,
                  ml.prod_id,
                  ml.UOM,
                  ml.cust_pref_vendor,
                  ml.qty_alloc,
                  ml.pick_complete_ind
           HAVING ml.qty_alloc = SUM (fh.qty_alloc);
   BEGIN
      SELECT config_flag_val
        INTO lv_flag
        FROM SYS_CONFIG
       WHERE config_flag_name = 'ORDER_GEN_COMPLETE_FOR_DAY';

      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Order Generation Complete flag: '
         || lv_flag;

--   pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      IF (lv_flag = 'Y')
      THEN
         FOR c1 IN c_ml_pickcomplete
         LOOP
            l_picking_complete_info.v_msg_type := ct_pick_comp_carr;
            l_picking_complete_info.v_carrier_id := c1.carrier_id;
            l_picking_complete_info.v_inv_date := SYSDATE;
            l_picking_complete_info.n_uom := c1.UOM;
            l_picking_complete_info.v_prod_id := c1.prod_id;
            l_picking_complete_info.v_cust_pref_vendor := c1.cust_pref_vendor;
            l_picking_complete_info.n_quantity := c1.qty_pc;                --
            p_picking_complete_for_carrier (l_picking_complete_info,
                                            ln_status
                                           );

            IF (ln_status = ct_failure)
            THEN
               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Error in executing p_picking_complete_for_carrier'
                  || ' Prod Id: '
                  || c1.prod_id
                  || ' CPV: '
                  || c1.cust_pref_vendor
                  || ' UOM: '
                  || c1.UOM
                  || ' Carrier Id: '
                  || c1.carrier_id;
               Pl_Text_Log.ins_msg ('WARNING',
                                    lv_fname,
                                    lv_msg_text,
                                    NULL,
                                    NULL);
            ELSE
               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Picking Complete Msg sent '
                  || ct_pick_comp_carr
                  || ' Prod Id: '
                  || c1.prod_id
                  || ' CPV: '
                  || c1.cust_pref_vendor
                  || ' UOM: '
                  || c1.UOM
                  || ' Carrier Id: '
                  || c1.carrier_id;
               Pl_Text_Log.ins_msg ('WARNING',
                                    lv_fname,
                                    lv_msg_text,
                                    NULL,
                                    NULL);

               UPDATE MINILOAD_PICKCOMPLETE
                  SET pick_complete_ind = 'Y'
                WHERE carrier_id = c1.carrier_id;

               IF (SQL%ROWCOUNT = 0)
               THEN
                  lv_msg_text :=
                        'Prog Code: '
                     || ct_program_code
                     || ' Update to miniload_pickcomplete failed'
                     || ' Prod Id: '
                     || c1.prod_id
                     || ' CPV: '
                     || c1.cust_pref_vendor
                     || ' UOM: '
                     || c1.UOM
                     || ' Carrier Id: '
                     || c1.carrier_id;
                  Pl_Text_Log.ins_msg ('FATAL',
                                       lv_fname,
                                       lv_msg_text,
                                       NULL,
                                       NULL);
               END IF;
            END IF;

            COMMIT;
         END LOOP;
      END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         IF c_ml_pickcomplete%ISOPEN
         THEN
            CLOSE c_ml_pickcomplete;
         END IF;

         ROLLBACK;
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Unable to Select Order Generation Complete Syspar';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
      WHEN OTHERS
      THEN
         IF c_ml_pickcomplete%ISOPEN
         THEN
            CLOSE c_ml_pickcomplete;
         END IF;

         ROLLBACK;
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_picking_batch_process';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
   END p_picking_batch_process;

-----------------------------------------------------------------------
-- PROCEDURE:
--    p_send_pending_pickcomp_msg
--
-- Description:
--   This procedure will be called at day end processing to send a
--   picking complete for carrier message to the miniloader.  The
--   miniloader will use the picking complete message to adjust it's
--   inventory.
--
--   ***** Form paovrv.fmb calls this procedure when the user does
--   ***** a DAY close.  
--
--   A picking complete will be sent for all the inventory stored in the
--   miniloader for miniload items that were ordered since the last start
--   of day or from the date passed as a parameter.
--   This can include carriers that nothing was picked from.
--   Example:  Item has three carriers in the miniloader.
--             One carrier had items picked from.
--             A picking complete message will be sent for all three
--             carriers.
--
--   A picking complete will be sent for carriers picked from since the
--   last start of day that no longer exist in inventory.
--
-- Parameters:
--    o_status                - Return Value
--                              0 - No errors.
--                              1 - Error occured.
--    i_order_start_date      - Date to start looking at orders from.  If null
--                              then the last Start Of Day miniload message
--                              is used.  Usually then should be null.
--                              Optional.
--    i_only_list_records_bln - Designates if to only list the items and
--                              carriers that will have a pick complete
--                              sent using dbms_output.  Used for debugging.
--                              Optional.
--
--
-- Exceptions Raised:
--    None
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/02/05          Created as part of the mini-load changes
--    09/14/06 prpbcb   Change cursor c_pick_complete select all the
--                      inventory records for miniload items ordered since
--                      the last start of day and carriers picked from that
--                      no longer exist in inventory.  The old cursor
--                      looked at the FLOAT_DETAIL table to get the carriers.
--
--                      Added parameters i_order_start_date and i_list_only.
--                      Main use is for debugging.
--
--    01/31/07 prpbcb   Change cursor c_pick_complete to include the inventory
--                      at the outbound location since it is possible for an
--                      item to be picked from this location.  Before it was
--                      excluded.
--
--    10/17/08          Changed procedure to to check syspar
--                      ALWAYS_SEND_PICK_COMPLETE and if
--                      Y to always send the pick complete for a carrier
--                      and not look at table MINILOAD_PICKCOMPLETE to see
--                      if it has already been sent.  We are having issues
--                      with the logic when looking at the
--                      MINILOAD_PICKCOMPLETE table that is resulting in
--                      pick completes not being sent resulting in
--                      inventory being out of sync between SWMS and the
--                      miniloader.
--                      Syspar ALWAYS_SEND_PICK_COMPLETE does not exist
--                      yet nor will it be created at this time.  When we
--                      get the logic fixed with table MINILOAD_PICKCOMPLETE 
--                      and it turns out resending all pick completes is
--                      slowing down the miniloader then we can create the
--                      syspar and set it appropriately.
--
--                      Added a second union to cursor c_pick_complete
--                      and changed the second select statement to look
--                      at the TRANS table instead of V_TRANS and the
--                      third select statement to look at OP_trans so we
--                      cut out doing full table scans on MINILOAD_TRANS.
--
--    04/27/10 prpbcb   Added call to pl_ml_cleanup.cleanup_replenishments
--                      to cleanup old miniloader replenishments.  Before
--                      this was done by swmspurge_ord.sql
---------------------------------------------------------------------------
   PROCEDURE p_send_pending_pickcomp_msg (
      o_status                  OUT      NUMBER,
      i_order_start_date        IN       DATE DEFAULT NULL,
      i_only_list_records_bln   IN       BOOLEAN DEFAULT FALSE
   )
   IS
      lv_fname       VARCHAR2(50) := 'P_SEND_PENDING_PICKCOMP_MSG';

      l_always_send_pick_complete sys_config.config_flag_val%TYPE;
                                        -- Syspar ALWAYS_SEND_PICK_COMPLETE

      l_picking_complete_info   t_picking_complete_info;
      l_start_of_day_info       t_start_of_day_info;
      lv_msg_text               VARCHAR2 (1500);
      ln_count                  NUMBER (1)              := 0;
      ln_status                 NUMBER (1)              := ct_success;
      l_order_start_date        DATE;
                                  -- Look for items with date ordered >=
                                  -- to this date.  This will be
                                  -- i_order_start_date if a non null value
                                  -- value passed on the command line or will
                                  -- be the last "Start of Day" miniload
                                  -- message.
      -- Hold return status of functions
      e_fail                    EXCEPTION;

      --
      -- This cursors select the date of the last start of day miniload message.
      -- It accounts for the first day the miniloader is in use as the first
      -- day has no start of day.
      --
      CURSOR c_last_start_of_day
      IS
         SELECT NVL(MAX(add_date), SYSDATE - 1)
           FROM MINILOAD_MESSAGE
          WHERE MESSAGE_TYPE = ct_start_of_day;

      --
      -- The cursor:
      --    - Selects the inventory stored in the miniloader for miniload
      --      items that were ordered (based on the miniload_order table)
      --      since the last start of day.  This can include carriers that
      --      nothing was picked from since all carriers for an item
      --      are sent.  When looking at the miniload_order, history orders
      --      are ignored which is specified by order_id not like 'HIST%'.
      --      This is hard coding but the format of order_id should not change
      --      any.  Hardcoding could be prevented by joining to the miniload
      --      table again and looking at the header record with
      --      order_type = 'History'.
      --    - Select the carriers picked from since the last start of day
      --      that no longer exist in inventory.
      -- Inventory in the induction location is ignored.
      -- The carriers no longer in inventory are processed first.
      --
      -- Some of the information selected is only used in debug messages
      -- such as the "inv_change".
      --
      CURSOR c_pick_complete
               (cp_order_start_date           DATE,
                cp_always_send_pick_complete  sys_config.config_flag_val%TYPE)
      IS
         SELECT   'UPDATE' inv_change,        -- ML inventory will be updated
                                      '2' order_by,
                                               -- Process these records last.
                                                   i.plogi_loc plogi_loc,
                  i.prod_id prod_id, i.cust_pref_vendor cust_pref_vendor,
                  i.logi_loc carrier_id, i.inv_uom UOM, i.qoh qty,
                  i.exp_date exp_date
             FROM zone z, lzone lz, inv i
            WHERE (i.prod_id, i.cust_pref_vendor) IN (
                     SELECT mlo.prod_id, mlo.cust_pref_vendor
                       FROM miniload_order mlo
                      WHERE mlo.source_system = 'SWM'
                        AND mlo.message_type = ct_ship_ord_inv
                        -- Get items ordered since the last start of day
                        AND mlo.add_date >= cp_order_start_date
                        -- Do not look at history orders.
                        AND mlo.order_id NOT LIKE 'HIST%'
                     UNION ALL
                     SELECT t1.prod_id, t1.cust_pref_vendor
                       FROM trans t1
                      WHERE t1.trans_type = 'PIK'
                        AND t1.trans_date >= cp_order_start_date
                     UNION ALL
                     SELECT t1.prod_id, t1.cust_pref_vendor
                       FROM op_trans t1
                      WHERE t1.trans_type = 'PIK'
                        AND t1.trans_date >= cp_order_start_date)
              --
              -- Based on the syspar setting:
              --    Send all pick completes.
              --  OR
              --    Do not resend if already sent for same carrier
              --    and qty by the pick complete option the user
              --    can choose in the order generation screen.
              --
              AND ( (cp_always_send_pick_complete = 'Y') 
                   OR ((cp_always_send_pick_complete = 'N')
                       AND NOT EXISTS
                              (SELECT 'x'
                                 FROM miniload_pickcomplete ml
                                WHERE ml.carrier_id = i.logi_loc
                                  AND ml.qty_alloc = i.qoh
                                  AND ml.pick_complete_ind = 'Y')) )
              AND lz.logi_loc = i.plogi_loc
              AND z.zone_id   = lz.zone_id
              AND z.ZONE_TYPE = 'PUT'
              AND z.rule_id   = 3
              --
              -- Leave out records at the ML inbound location.
              --
              AND i.plogi_loc NOT IN (z.induction_loc)
         UNION ALL
         --
         -- Get the carriers picked from since the last start of day that
         -- no longer exist in inventory.  These need to be deleted from
         -- the miniloader system.
         -- ***** Looking at TRANS table *****
         --
         SELECT   'DELETE'              inv_change,  -- ML inv will be deleted
                  '1'                   order_by,    -- Process these records
                                                     -- first.
                  t2.src_loc            plogi_loc,
                  t2.prod_id            prod_id,
                  t2.cust_pref_vendor   cust_pref_vendor,
                  t2.pallet_id          carrier_id,
                  t2.uom                uom,
                  0                     qty,
                  t2.exp_date           exp_date
             FROM zone    z2,
                  lzone   lz2,
                  trans t2
            WHERE t2.trans_type   = 'PIK'
              AND lz2.logi_loc    = t2.src_loc
              AND z2.zone_id      = lz2.zone_id
              AND z2.ZONE_TYPE    = 'PUT'
              AND z2.rule_id      = 3
              AND t2.src_loc NOT IN (z2.induction_loc)
              AND t2.trans_date  >= cp_order_start_date
              --
              -- Get the carriers not in inventory.
              --
              AND NOT EXISTS (SELECT 'x'
                                FROM inv i2
                               WHERE i2.logi_loc = t2.pallet_id)
         UNION ALL
         --
         -- Get the carriers picked from since the last start of day that
         -- no longer exist in inventory.  These need to be deleted from
         -- the miniloader system.
         -- ***** Looking at OP_TRANS table *****
         --
         SELECT   'DELETE'              inv_change,  -- ML inv will be deleted
                  '1'                   order_by,    -- Process these records
                                                     -- first.
                  t2.src_loc            plogi_loc,
                  t2.prod_id            prod_id,
                  t2.cust_pref_vendor   cust_pref_vendor,
                  t2.pallet_id          carrier_id,
                  t2.uom                uom,
                  0                     qty,
                  t2.exp_date           exp_date
             FROM zone    z2,
                  lzone   lz2,
                  op_trans t2
            WHERE t2.trans_type   = 'PIK'
              AND lz2.logi_loc    = t2.src_loc
              AND z2.zone_id      = lz2.zone_id
              AND z2.ZONE_TYPE    = 'PUT'
              AND z2.rule_id      = 3
              AND t2.src_loc NOT IN (z2.induction_loc)
              AND t2.trans_date  >= cp_order_start_date
              --
              -- Get the carriers not in inventory.
              --
              AND NOT EXISTS (SELECT 'x'
                                FROM inv i2
                               WHERE i2.logi_loc = t2.pallet_id)
         ORDER BY 2, 3;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_send_pending_pickcomp_msg');
      --
      -- Write info log message showing parameters.
      --
      lv_msg_text :=
            'INFO Starting '
         || lv_fname
         || '(o_status'
         || ',i_order_start_date['
         || TO_CHAR (i_order_start_date)
         || ']'
         || ',i_only_list_records_bln['
         || f_boolean_text (i_only_list_records_bln)
         || '])';
      Pl_Text_Log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);

      IF (i_only_list_records_bln = TRUE)
      THEN
         DBMS_OUTPUT.PUT_LINE(lv_fname
                              || '  i_only_list_records_bln is TRUE.');
      END IF;

      --
      -- See if we send all the pick completes or those not already sent.
      --
      l_always_send_pick_complete :=
                pl_common.f_get_syspar('ALWAYS_SEND_PICK_COMPLETE', 'Y');

      --
      -- Set the order start date.
      --
      IF (i_order_start_date IS NOT NULL)
      THEN
         -- Passed as an argument.
         l_order_start_date := i_order_start_date;
      ELSE
         --
         -- Use the date of the last Start of Day miniload message.
         --
         BEGIN
            OPEN c_last_start_of_day;

            FETCH c_last_start_of_day
             INTO l_order_start_date;

            CLOSE c_last_start_of_day;
         EXCEPTION
            WHEN OTHERS THEN
               -- Got an oracle error.
               IF (c_last_start_of_day%ISOPEN) THEN
                  CLOSE c_last_start_of_day;
               END IF;

               lv_msg_text :=
                     'TABLE=miniload_message  ACTION=SELECT'
                  || '  KEY=['
                  || ct_start_of_day
                  || ']'
                  || '  MESSAGE="Failed to select the last Start Of Day.'
                  || '  Will use sysdate - 1 for the value"';
               Pl_Text_Log.ins_msg ('WARNING',
                                    lv_fname,
                                    lv_msg_text,
                                    SQLCODE,
                                    SQLERRM);
               l_order_start_date := SYSDATE - 1;
         END;
      END IF;

      FOR v_rec IN c_pick_complete(l_order_start_date,
                                   l_always_send_pick_complete)
      LOOP
         l_picking_complete_info.v_msg_type         := ct_pick_comp_carr;
         l_picking_complete_info.v_carrier_id       := v_rec.carrier_id;
         l_picking_complete_info.v_inv_date         := v_rec.exp_date;
         l_picking_complete_info.n_uom              := v_rec.uom;
         l_picking_complete_info.v_prod_id          := v_rec.prod_id;
         l_picking_complete_info.v_cust_pref_vendor := v_rec.cust_pref_vendor;

         IF (i_only_list_records_bln = FALSE) THEN
            p_picking_complete_for_carrier (l_picking_complete_info,
                                            ln_status);

            IF (ln_status = ct_failure) THEN
               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Error in executing p_picking_complete_for_carrier'
                  || ' Prod Id: '
                  || v_rec.prod_id
                  || ' CPV: '
                  || v_rec.cust_pref_vendor
                  || ' UOM: '
                  || TO_CHAR (v_rec.UOM)
                  || ' Carrier Id: '
                  || v_rec.carrier_id;
               pl_text_log.ins_msg ('WARNING',
                                    lv_fname,
                                    lv_msg_text,
                                    NULL,
                                    NULL);
            ELSE
               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Picking Complete Msg sent '
                  || ct_pick_comp_carr
                  || ' Prod Id: '
                  || v_rec.prod_id
                  || ' CPV: '
                  || v_rec.cust_pref_vendor
                  || ' UOM: '
                  || TO_CHAR (v_rec.UOM)
                  || ' Carrier Id: '
                  || v_rec.carrier_id;
               Pl_Text_Log.ins_msg ('WARNING',
                                    lv_fname,
                                    lv_msg_text,
                                    NULL,
                                    NULL);

               UPDATE MINILOAD_PICKCOMPLETE
                  SET pick_complete_ind = 'Y'
                WHERE carrier_id = v_rec.carrier_id;

               IF (SQL%ROWCOUNT = 0)
               THEN
                  lv_msg_text :=
                        'Prog Code: '
                     || ct_program_code
                     || ' Update to miniload_pickcomplete failed'
                     || ' Prod Id: '
                     || v_rec.prod_id
                     || ' CPV: '
                     || v_rec.cust_pref_vendor
                     || ' UOM: '
                     || TO_CHAR (v_rec.UOM)
                     || ' Carrier Id: '
                     || v_rec.carrier_id;
                  Pl_Text_Log.ins_msg ('FATAL',
                                       lv_fname,
                                       lv_msg_text,
                                       NULL,
                                       NULL);
               END IF;
            END IF;
         ELSE
            --
            -- i_only_list_records_bln IS TRUE
            --
            DBMS_OUTPUT.PUT_LINE (   lv_fname
                                  || '  INV change['
                                  || v_rec.inv_change
                                  || ']'
                                  || '  Prod Id['
                                  || v_rec.prod_id
                                  || ']'
                                  || '  CPV['
                                  || v_rec.cust_pref_vendor
                                  || ']'
                                  || '  Carrier Id['
                                  || v_rec.carrier_id
                                  || ']'
                                  || '  Qty['
                                  || TO_CHAR (v_rec.qty)
                                  || '](in splits)'
                                  || '  UOM['
                                  || TO_CHAR (v_rec.UOM)
                                  || ']'
                                  || '  Exp Date['
                                  || TO_CHAR (v_rec.exp_date, 'MM/DD/YYYY')
                                  || ']'
                                 );
         END IF;
      END LOOP;

      IF (i_only_list_records_bln = FALSE)
      THEN
         l_start_of_day_info.v_msg_type := ct_start_of_day;
         l_start_of_day_info.v_order_date := SYSDATE;
         p_send_start_of_day (l_start_of_day_info, ln_status);

         IF (ln_status = ct_failure)
         THEN
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Error in executing p_send_start_of_day';
            RAISE e_fail;
         END IF;


         --
         -- 10/21/08 Brian Bent Clear out the pick complete table because we
         -- have sent all pick completes to the ML.  This cleans the slate
         -- getting ready for the next days processing.
         --
         DELETE FROM miniload_pickcomplete;

         lv_msg_text :='Deleted all records in'
                        || ' the MINILOAD_PICKCOMPLETE table.'
                        || '  Number of records delete: ' || SQL%ROWCOUNT;

         pl_log.ins_msg(pl_lmc.ct_info_msg,
                         lv_fname,
                         lv_msg_text,
                         NULL,
                         NULL,
                         ct_application_function,
                         gl_pkg_name);

         /*****************   10/21/08 Brian Bent  Commented this code out.
          *****************   We will always delete all records from the
                              MINILOAD_PICKCOMPLETE table because we are
                              sending all pick completes to the ML.

         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Checking if there are any records with'
            || ' pick_complete_ind = "Y" in table miniload_pickcomplete';
         SELECT COUNT (*)
           INTO ln_count
           FROM MINILOAD_PICKCOMPLETE
          WHERE pick_complete_ind = 'Y';

         IF (ln_count = 0)
         THEN
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' No records in table miniload_pickcomplete with'
               || ' pick_complete_ind = "Y"';
            Pl_Text_Log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);
         ELSE
            DELETE FROM MINILOAD_PICKCOMPLETE
                  WHERE pick_complete_ind = 'Y';

            IF (SQL%ROWCOUNT = 0)
            THEN
               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Deletion from miniload_pickcomplete failed';
               RAISE e_fail;
            END IF;
         END IF;
          *****************
          ****************/
      END IF;                      -- end IF (i_only_list_records_bln = FALSE)

      --
      -- Cleanup the miniloader replenishments.
      -- Start a new block and trap all errors.  We do not want an error
      -- cleaning up the miniloader replenishments to stop processing.
      --
      -- What gets cleaned up depends on the values in columns
      -- DELETE_AT_START_OF_DAY and RETENTION_DAYS in table PRIORITY_CODE.
      -- 
      BEGIN
         pl_ml_cleanup.cleanup_replenishments;
      EXCEPTION
         WHEN OTHERS THEN
            pl_log.ins_msg
                 (pl_lmc.ct_warn_msg,
                  lv_fname,
                  ' Error in executing pl_ml_cleanup.cleanup_replenishments.'
                  || '  This error will not stop processing.',
                  SQLCODE, SQLERRM, ct_application_function, gl_pkg_name);
      END;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_send_pending_pickcomp_msg';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_send_pending_pickcomp_msg;

/*
***********************************************************************
***********************************************************************
----------------------------------------------------------------------
09/14/06 prpbcb The old p_send_pending_pickcomp_msg procedure.
                Keep it around a while.
----------------------------------------------------------------------
PROCEDURE p_send_pending_pickcomp_msg (o_status OUT NUMBER)
IS
   l_picking_complete_info   t_picking_complete_info;
   l_start_of_day_info       t_start_of_day_info;
   lv_msg_text               VARCHAR2 (1500);
   lv_fname                  VARCHAR2 (50)   := 'P_SEND_PENDING_PICKCOMP_MSG';
   ln_count                  NUMBER (1)      := 0;
   ln_status                 NUMBER (1)      := CT_SUCCESS;
   --Hold return status of functions
   e_fail                    EXCEPTION;

   CURSOR c_pick_complete
   IS
      SELECT fd.prod_id, fd.cust_pref_vendor, fd.uom, fd.carrier_id
        FROM float_detail fd, route r, lzone lz, zone z
       WHERE fd.carrier_id IS NOT NULL
         AND fd.route_no = r.route_no
         AND r.status = 'CLS'
         AND fd.src_loc = lz.logi_loc
         AND lz.zone_id = z.zone_id
         AND z.rule_id = 3
         AND z.zone_type = 'PUT'
         AND NOT EXISTS (
                SELECT 1
                  FROM miniload_pickcomplete ml
                 WHERE fd.carrier_id = ml.carrier_id
                   AND pick_complete_ind = 'Y');
BEGIN
   pl_text_log.init('pl_miniload_processing.p_send_pending_pickcomp_msg');

   FOR v_rec IN c_pick_complete
   LOOP
      l_picking_complete_info.v_msg_type := CT_PICK_COMP_CARR;
      l_picking_complete_info.v_carrier_id := v_rec.carrier_id;
      l_picking_complete_info.v_inv_date := SYSDATE;
      l_picking_complete_info.n_uom := v_rec.uom;
      l_picking_complete_info.v_prod_id := v_rec.prod_id;
      l_picking_complete_info.v_cust_pref_vendor := v_rec.cust_pref_vendor;

      p_picking_complete_for_carrier (l_picking_complete_info, ln_status);

      IF (ln_status = CT_FAILURE)
      THEN
         lv_msg_text := 'Prog Code: '
                        || CT_PROGRAM_CODE
                        || ' Error in executing p_picking_complete_for_carrier'
                        || ' Prod Id: '
                        || v_rec.prod_id
                        || ' CPV: '
                        || v_rec.cust_pref_vendor
                        || ' UOM: '
                        || v_rec.uom
                        || ' Carrier Id: '
                        || v_rec.carrier_id;
         pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      ELSE
         lv_msg_text := 'Prog Code: '
                        || CT_PROGRAM_CODE
                        || ' Picking Complete Msg sent '
                        || CT_PICK_COMP_CARR
                        || ' Prod Id: '
                        || v_rec.prod_id
                        || ' CPV: '
                        || v_rec.cust_pref_vendor
                        || ' UOM: '
                        || v_rec.uom
                        || ' Carrier Id: '
                        || v_rec.carrier_id;
         pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

         UPDATE miniload_pickcomplete
            SET pick_complete_ind = 'Y'
          WHERE carrier_id = v_rec.carrier_id;

         IF (SQL%ROWCOUNT=0)
         THEN
            lv_msg_text := 'Prog Code: '
                           || CT_PROGRAM_CODE
                           || ' Update to miniload_pickcomplete failed'
                           || ' Prod Id: '
                           || v_rec.prod_id
                           || ' CPV: '
                           || v_rec.cust_pref_vendor
                           || ' UOM: '
                           || v_rec.uom
                           || ' Carrier Id: '
                           || v_rec.carrier_id;
            pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         END IF;
      END IF;
   END LOOP;

   l_start_of_day_info.v_msg_type := CT_START_OF_DAY;
   l_start_of_day_info.v_order_date := SYSDATE;
   p_send_start_of_day (l_start_of_day_info, ln_status);

   IF (ln_status = CT_FAILURE)
   THEN
      lv_msg_text :=
            'Prog Code: '
         || CT_PROGRAM_CODE
         || ' Error in executing p_send_start_of_day';
      RAISE e_fail;
   END IF;

   lv_msg_text := 'Prog Code: '
                  || CT_PROGRAM_CODE
                  || ' Check if there are any records with pick_complete_ind = "Y" in miniload_pickcomplete';

   SELECT COUNT(*) INTO ln_count
     FROM miniload_pickcomplete
    WHERE pick_complete_ind = 'Y';

   IF ln_count = 0
   THEN
      lv_msg_text := 'Prog Code: '
                      || CT_PROGRAM_CODE
                      || ' No records in miniload_pickcomplete with pick_complete_ind = "Y"';
      pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

   ELSE
      DELETE FROM miniload_pickcomplete
            WHERE pick_complete_ind = 'Y';

      IF (SQL%ROWCOUNT=0)
      THEN
         lv_msg_text := 'Prog Code: '
                        || CT_PROGRAM_CODE
                        || ' Deletion from miniload_pickcomplete failed';
         RAISE e_fail;
      END IF;

   END IF;

   o_status := CT_SUCCESS;
EXCEPTION
   WHEN e_fail
   THEN
      pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
      o_status := CT_FAILURE;
   WHEN OTHERS
   THEN
      lv_msg_text :=
            'Prog Code: '
         || CT_PROGRAM_CODE
         || ' Error in executing p_send_pending_pickcomp_msg';
      pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE, SQLERRM);
      o_status := CT_FAILURE;
END p_send_pending_pickcomp_msg;
***********************************************************************
***********************************************************************
*/

   -------------------------------------------------------------------------
-- Procedure:
--    p_picking_complete_for_carrier
--
-- Description:
--     The procedure to send 'Picking Complete For Carrier' message
--
-- Parameters:
--    i_picking_complete_info  - record holding 'Picking Complete For Carrier' message
--    o_status - Return Value
--       0  - No errors.
--       1  - Error occured.
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/02/05          Created as part of the mini-load changes
---------------------------------------------------------------------------
   PROCEDURE p_picking_complete_for_carrier (
      i_picking_complete_info   IN       t_picking_complete_info DEFAULT NULL,
      o_status                  OUT      NUMBER
   )
   IS
      l_miniload_info   t_miniload_info := NULL;
      ln_count          NUMBER (6);
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)   := 'P_PICKING_COMPLETE_FOR_CARRIER';
      ln_status         NUMBER (1)      := ct_success;
      --Hold return status of functions
      e_fail            EXCEPTION;
   BEGIN
      Pl_Text_Log.init
                     ('pl_miniload_processing.p_picking_complete_for_carrier');
      l_miniload_info.vt_picking_complete_info := i_picking_complete_info;
      -- From the Prod_id and source location, get the QOH from INV table.
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Prod Id: '
         || l_miniload_info.vt_picking_complete_info.v_prod_id
         || ' CPV: '
         || l_miniload_info.vt_picking_complete_info.v_cust_pref_vendor
         || ' UOM: '
         || l_miniload_info.vt_picking_complete_info.n_uom
         || ' Carrier Id: '
         || l_miniload_info.vt_picking_complete_info.v_carrier_id;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

      BEGIN
         SELECT qoh,
                exp_date                                       -- add exp_date
           INTO l_miniload_info.vt_picking_complete_info.n_quantity,
                l_miniload_info.vt_picking_complete_info.v_inv_date
           FROM INV
          WHERE prod_id = i_picking_complete_info.v_prod_id
            AND cust_pref_vendor = i_picking_complete_info.v_cust_pref_vendor
            AND logi_loc = i_picking_complete_info.v_carrier_id;

         p_convert_uom
                  (l_miniload_info.vt_picking_complete_info.n_uom,
                   l_miniload_info.vt_picking_complete_info.n_quantity,
                   l_miniload_info.vt_picking_complete_info.v_prod_id,
                   l_miniload_info.vt_picking_complete_info.v_cust_pref_vendor
                  );
         l_miniload_info.v_sku :=
            f_generate_sku
                  (l_miniload_info.vt_picking_complete_info.n_uom,
                   l_miniload_info.vt_picking_complete_info.v_prod_id,
                   l_miniload_info.vt_picking_complete_info.v_cust_pref_vendor
                  );
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            l_miniload_info.vt_picking_complete_info.n_quantity := 0;
            l_miniload_info.vt_picking_complete_info.n_uom := NULL;
            l_miniload_info.vt_picking_complete_info.v_prod_id := NULL;
            l_miniload_info.vt_picking_complete_info.v_cust_pref_vendor :=
                                                                         NULL;
            l_miniload_info.vt_picking_complete_info.v_inv_date := NULL;
            l_miniload_info.v_sku := LPAD (' ', ct_sku_size, ' ');
      END;

      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Total QOH: '
         || l_miniload_info.vt_picking_complete_info.n_quantity;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      l_miniload_info.v_data :=
                         f_create_message (l_miniload_info, ct_pick_comp_carr);
      lv_msg_text :=
         'Prog Code: ' || ct_program_code || ' Msg: '
         || l_miniload_info.v_data;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      p_insert_miniload_message (l_miniload_info, ct_pick_comp_carr,
                                 ln_status);

      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_message';
         RAISE e_fail;
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN NO_DATA_FOUND
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' TABLE=inv'
            || ' ACTION=SELECT MESSAGE= Error in retrieving qoh '
            || ' Key:[prod_id,cpv,logi_loc]=['
            || l_miniload_info.vt_picking_complete_info.v_prod_id
            || ','
            || l_miniload_info.vt_picking_complete_info.v_cust_pref_vendor
            || ','
            || l_miniload_info.vt_picking_complete_info.v_carrier_id
            || ']';
         Pl_Text_Log.ins_msg ('WARNING',
                              lv_fname,
                              lv_msg_text,
                              SQLCODE,
                              SQLERRM
                             );
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing procedures/functions';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_picking_complete_for_carrier;

-------------------------------------------------------------------------
-- Procedure:
--    p_send_carrier_status_change
--
-- Description:
--    This procedure sends the carrier status change to miniload.
--
-- Parameters:
--    i_carrier_status_info - Carrier Status Info
--
-- Exceptions Raised:
--    None.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/14/07 ctvgg000 Created as a part of HK Integration
---------------------------------------------------------------------------
   PROCEDURE p_send_carrier_status_change (
      i_carrier_status_info   IN       t_carrier_status_info DEFAULT NULL,
      o_status                OUT      NUMBER
   )
   IS
      l_miniload_info    t_miniload_info;
      ln_status            NUMBER (1)      := ct_success;
      --Hold return status of functions
      lv_msg_text        VARCHAR2 (1500);
      lv_fname            VARCHAR2 (50)   := 'P_SEND_CARRIER_STATUS_CHANGE';
      e_fail            EXCEPTION; 
     
   BEGIN   
            
      Pl_Text_Log.init ('pl_miniload_processing.p_send_carrier_status_change');         
          
      l_miniload_info.vt_carrier_status_info := i_carrier_status_info;
      
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Type: '
         || l_miniload_info.vt_carrier_status_info.v_msg_type
         || ' carrier id: '
         || l_miniload_info.vt_carrier_status_info.v_label;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
                  
      SELECT prod_id, cust_pref_vendor, inv_uom 
      INTO l_miniload_info.v_prod_id,
           l_miniload_info.v_cust_pref_vendor, 
           l_miniload_info.n_uom
      FROM inv
      WHERE logi_loc = l_miniload_info.vt_carrier_status_info.v_label;
          
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' prod id '
         || l_miniload_info.v_prod_id                 
         || ' cust pref vendor '
         || l_miniload_info.v_cust_pref_vendor                          
         || ' carrier id: '
         || l_miniload_info.vt_carrier_status_info.v_label;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);             
      
      l_miniload_info.v_data := f_create_message (l_miniload_info, ct_carrier_status);
      
      lv_msg_text :=
         'Prog Code: ' || ct_program_code || ' Msg : '
         || l_miniload_info.v_data;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

      p_insert_miniload_message (l_miniload_info, ct_carrier_status, ln_status);            
      
      IF (ln_status = ct_failure)
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing p_insert_miniload_message';
         RAISE e_fail;
      END IF;
      commit;
      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN         
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;         
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in executing procedures/functions';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_send_carrier_status_change;
-------------------------------------------------------------------------
-- Procedure:
--    p_split_sku
--
-- Description:
--    This procedure is to extract the uom, prod_id, cpv from the SKU information.
--
-- Parameters:
--    i_sku - stock keeping unit
--    o_uom  - unit of measure
--    o_prod_id - product id
--    o_cust_pref_vendor - customer preferred vendor
--
-- Exceptions Raised:
--    None.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/01/05          Created as part of the mini-load changes
---------------------------------------------------------------------------
   PROCEDURE p_split_sku (
      i_sku                IN       VARCHAR2,
      o_uom                OUT      INV.inv_uom%TYPE,
      o_prod_id            OUT      PM.prod_id%TYPE,
      o_cust_pref_vendor   OUT      PM.cust_pref_vendor%TYPE,
      i_log_flag           IN       BOOLEAN DEFAULT TRUE
   )
   IS
      lv_msg_text   VARCHAR2 (1500);
      lv_fname      VARCHAR2 (50)   := 'P_SPLIT_SKU';
   BEGIN
--From the i_sku get the o_uom, o_prod_id, o_cust_pref_vendor as follows:
      o_uom := TO_NUMBER (SUBSTR (i_sku, 1, 1));
      o_prod_id := TRIM (SUBSTR (i_sku, 2, 9));
      o_cust_pref_vendor := TRIM (SUBSTR (i_sku, 11, 10));

      IF (o_cust_pref_vendor IS NULL)
      THEN
         o_cust_pref_vendor := '-';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         lv_msg_text :=
                  'Prog Code: ' || ct_program_code || ' Error in p_split_sku';

         IF (i_log_flag = TRUE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         ELSIF (i_log_flag = FALSE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         END IF;
   END p_split_sku;

-------------------------------------------------------------------------
-- Procedure:
--    p_convert_uom
--
-- Description:
--    if UOM = 0,this function changes the uom to 2 and also updates
--    the quantity to case measure.
--
-- Parameters:
--    io_uom  - unit of measure
--    io_quantity - quantity expected
--    i_prod_id - product id
--    i_cust_pref_vendor - customer preferred vendor
--
-- Exceptions Raised:
--    None.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/01/05          Created as part of the mini-load changes
--    08/02/06 prpbcb   Added parameter i_bln_check_ship_split_only which
--                      designates if the item's ship split only flag needs
--                      to be checked in the processing.  Changed the
--                      processing to not convert the qty to cases if the
--                      item is ship split only and is splitable.
---------------------------------------------------------------------------
   PROCEDURE p_convert_uom (
      io_uom                        IN OUT   PUTAWAYLST.UOM%TYPE,
      io_quantity                   IN OUT   PUTAWAYLST.qty_expected%TYPE,
      i_prod_id                     IN       PUTAWAYLST.prod_id%TYPE,
      i_cust_pref_vendor            IN       PUTAWAYLST.cust_pref_vendor%TYPE,
      i_bln_check_ship_split_only   IN       BOOLEAN DEFAULT FALSE
   )
   IS
      l_auto_ship_flag   PM.auto_ship_flag%TYPE;
      l_split_trk        PM.auto_ship_flag%TYPE;
      ln_spc             PM.spc%TYPE;
      -- local variable to store the no of splits per case
      lv_msg_text        VARCHAR2 (1500);
      lv_fname           VARCHAR2 (50)            := 'P_CONVERT_UOM';
   BEGIN
      --Check the io_uom value
      IF (io_uom = 0)
      THEN
         io_uom := 2;
      END IF;

      --Proceed only if uom is 0 or 2
      IF (io_uom = 2)
      THEN
         -- Get info for the given product id
         SELECT spc, NVL (auto_ship_flag, 'N'), NVL (split_trk, 'N')
           INTO ln_spc, l_auto_ship_flag, l_split_trk
           FROM PM
          WHERE prod_id = i_prod_id AND cust_pref_vendor = i_cust_pref_vendor;

         --
         -- If processing calls to check for the ship split only flag and
         -- the item is ship split only and the item is splitable then the qty
         -- needs to be processed as splits and not converted to cases.
         --
         IF (    i_bln_check_ship_split_only = TRUE
             AND l_auto_ship_flag = 'Y'
             AND l_split_trk = 'Y'
            )
         THEN
            io_uom := 1;
         ELSE
            -- Calculate case quantity
            io_quantity := CEIL (io_quantity / ln_spc);
         END IF;
      END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message=Query to find spc failed'
            || ' Table=pm Key:[prod_id,cpv]=['
            || i_prod_id
            || ','
            || i_cust_pref_vendor
            || ']';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         RAISE;
      WHEN OTHERS
      THEN
         lv_msg_text :=
                'Prog Code: ' || ct_program_code || ' Error in p_convert_uom';
         Pl_Text_Log.ins_msg ('FATAL',
                              lv_fname,
                              lv_msg_text,
                              SQLCODE,
                              SQLERRM
                             );
         RAISE;
   END p_convert_uom;

-------------------------------------------------------------------------
-- Function:
--    f_generate_sku
--
-- Description:
--     The Function to combine uom,prod id and customer prefered vendor
--     to obtain SKU.
--
-- Parameters:
--    i_uom - uom field of sku to be formed
--    i_prod_id - prod_id field of the sku to be formed
--    i_cust_pref_vendor - cust_pref_vendor field of the sku to be formed
--
-- Return Values:
--      The generated SKU.
--
-- Exceptions Raised:
--    None.  If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/02/05          Created as part of the mini-load changes
---------------------------------------------------------------------------
   FUNCTION f_generate_sku (
      i_uom                IN   MINILOAD_MESSAGE.UOM%TYPE,
      i_prod_id            IN   MINILOAD_MESSAGE.prod_id%TYPE,
      i_cust_pref_vendor   IN   MINILOAD_MESSAGE.cust_pref_vendor%TYPE
   )
      RETURN VARCHAR2
   IS
      lv_sku                VARCHAR (20);
      lv_fname              VARCHAR (50)                := 'F_GENERATE_SKU';
      lv_msg_text           VARCHAR (1500);
      lv_uom                INV.inv_uom%TYPE;
      lv_cust_pref_vendor   INV.cust_pref_vendor%TYPE;
   BEGIN
      IF (i_uom = 0)
      THEN
         lv_uom := 2;
      ELSE
         lv_uom := i_uom;
      END IF;

      IF i_cust_pref_vendor = '-'
      THEN
         lv_cust_pref_vendor := ' ';
      ELSIF i_cust_pref_vendor IS NULL
      THEN
         lv_cust_pref_vendor := ' ';
      ELSE
         lv_cust_pref_vendor := i_cust_pref_vendor;
      END IF;

      lv_sku :=
            lv_uom
         || RPAD (i_prod_id, 9, ' ')
         || RPAD (lv_cust_pref_vendor, 10, ' ');
      RETURN lv_sku;
   EXCEPTION
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: ' || ct_program_code || ' Error in SKU Generation';
         Pl_Text_Log.ins_msg ('FATAL',
                              lv_fname,
                              lv_msg_text,
                              SQLCODE,
                              SQLERRM
                             );
         RAISE;
   END f_generate_sku;

-------------------------------------------------------------------------
-- Procedure:
--    p_insert_miniload_message
--
-- Description:
--     This procedure logs the messages into miniload_message table.
--
--     ***** READ THIS *****
--     Do not call any object from this procedure that performs an
--     autonomous transaction such as pl_log.  This is due to this
--     procedure being called from pl_miniload_interface which accesses
--     tables by a database link.
--
-- Parameters:
--    i_miniload_info      - record type containing all message fields
--    i_msg_type           - message type
--    o_status - return status
--          0  - No errors.
--          1  - Error occured
--   i_log_flag - Used by specfic internal functions(DEFAULT 'Y').
--                for logging into error into swms_log.
--
-- Exceptions Raised:
--     e_fail - To report CT_FAILURE
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/28/05           Created as part of the mini-load changes.
--
--   12/13/07 CTVGG000   Changed to insert miniload_identifier along with
--                 other message data
----------------------------------------------------------------------------
   PROCEDURE p_insert_miniload_message (
      i_miniload_info   IN       t_miniload_info,
      i_msg_type        IN       VARCHAR2,
      o_status          OUT      NUMBER,
      i_log_flag        IN       BOOLEAN DEFAULT TRUE
   )
   IS
      lv_fname                 VARCHAR2 (50)   := 'P_INSERT_MINILOAD_MESSAGE';
      lv_msg_text              VARCHAR2 (1500);
      lv_msg_type              MINILOAD_MESSAGE.MESSAGE_TYPE%TYPE;
      ln_msg_id                MINILOAD_MESSAGE.message_id%TYPE  DEFAULT NULL;
      lv_source_system         MINILOAD_MESSAGE.source_system%TYPE
                                                                 DEFAULT NULL;
      lv_expected_receipt_id   MINILOAD_MESSAGE.expected_receipt_id%TYPE
                                                                 DEFAULT NULL;
      lv_prod_id               MINILOAD_MESSAGE.prod_id%TYPE     DEFAULT NULL;
      lv_cust_pref_vendor      MINILOAD_MESSAGE.cust_pref_vendor%TYPE
                                                                 DEFAULT NULL;
      ln_uom                   MINILOAD_MESSAGE.UOM%TYPE         DEFAULT NULL;
      ln_items_per_carrier     MINILOAD_MESSAGE.items_per_carrier%TYPE
                                                                 DEFAULT NULL;
      ln_qty_expected          MINILOAD_MESSAGE.qty_expected%TYPE
                                                                 DEFAULT NULL;
      ln_qty_received          MINILOAD_MESSAGE.qty_received%TYPE
                                                                 DEFAULT NULL;
      lv_carrier_id            MINILOAD_MESSAGE.carrier_id%TYPE  DEFAULT NULL;
      lv_source_loc            MINILOAD_MESSAGE.source_loc%TYPE  DEFAULT NULL;
      lv_planned_loc           MINILOAD_MESSAGE.planned_loc%TYPE DEFAULT NULL;
      lv_dest_loc              MINILOAD_MESSAGE.dest_loc%TYPE    DEFAULT NULL;
      lv_description           MINILOAD_MESSAGE.description%TYPE DEFAULT NULL;
      lv_reason                MINILOAD_MESSAGE.reason%TYPE      DEFAULT NULL;
      lv_inv_date              MINILOAD_MESSAGE.inv_date%TYPE    DEFAULT NULL;
      lv_order_date            MINILOAD_MESSAGE.order_date%TYPE  DEFAULT NULL;
      lv_data                  MINILOAD_MESSAGE.ml_data%TYPE     DEFAULT NULL;
      ln_data_len              MINILOAD_MESSAGE.ml_data_len%TYPE DEFAULT NULL;
      lv_status                MINILOAD_MESSAGE.status%TYPE      DEFAULT NULL;
      ln_order_priority        MINILOAD_MESSAGE.order_priority%TYPE
                                                                 DEFAULT NULL;
      -- ctvgg000 for HK Integration Miniload Identifier
      lv_ml_system             MINILOAD_MESSAGE.ml_system%TYPE    DEFAULT NULL;
      -- carrier status       
            
      lv_message_status           MINILOAD_MESSAGE.ref_message_status%type  DEFAULT NULL;
      lv_ref_message_id           MINILOAD_MESSAGE.ref_message_id%type     DEFAULT NULL; 
      lv_zone_id               PM.zone_id%TYPE DEFAULT NULL;
      lv_split_zone_id           PM.split_zone_id%TYPE DEFAULT NULL;
            
      e_fail                   EXCEPTION;

      CURSOR c_ml_system
      IS
         SELECT   ml_system
             FROM MINILOAD_CONFIG
         ORDER BY ml_system;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_insert_miniload_message');
      lv_msg_type := i_msg_type;

      IF lv_msg_type = ct_exp_rec
      THEN
         lv_msg_type := ct_exp_rec;
         lv_expected_receipt_id :=
                    i_miniload_info.vt_exp_receipt_info.v_expected_receipt_id;
         lv_prod_id := i_miniload_info.vt_exp_receipt_info.v_prod_id;
         ln_uom := i_miniload_info.vt_exp_receipt_info.n_uom;
         lv_cust_pref_vendor :=
                       i_miniload_info.vt_exp_receipt_info.v_cust_pref_vendor;
         ln_qty_expected :=
                           i_miniload_info.vt_exp_receipt_info.n_qty_expected;
         lv_inv_date := i_miniload_info.vt_exp_receipt_info.v_inv_date;
         lv_source_system := 'SWM';
dbms_output.put_line(lv_expected_receipt_id);
dbms_output.put_line(lv_prod_id);
dbms_output.put_line(lv_cust_pref_vendor);
dbms_output.put_line(to_char(ln_uom));
dbms_output.put_line(to_char(ln_qty_expected));
      ELSIF lv_msg_type = ct_exp_rec_comp
      THEN
         lv_msg_type := ct_exp_rec_comp;
         lv_expected_receipt_id :=
            i_miniload_info.vt_exp_receipt_complete_info.v_expected_receipt_id;
         lv_prod_id := i_miniload_info.v_prod_id;
         ln_uom := i_miniload_info.n_uom;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         ln_qty_expected :=
                       i_miniload_info.vt_exp_receipt_complete_info.n_qty_exp;
         ln_qty_received :=
                       i_miniload_info.vt_exp_receipt_complete_info.n_qty_rcv;
         lv_source_system := 'MNL';
      ELSIF lv_msg_type = ct_inv_adj_inc
      THEN
         lv_msg_type := ct_inv_adj_inc;
         lv_carrier_id := i_miniload_info.vt_inv_adj_inc_info.v_label;
         lv_prod_id := i_miniload_info.v_prod_id;
         ln_uom := i_miniload_info.n_uom;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         ln_qty_received := i_miniload_info.vt_inv_adj_inc_info.n_quantity;
         lv_inv_date := i_miniload_info.vt_inv_adj_inc_info.v_inv_date;
         lv_reason := i_miniload_info.vt_inv_adj_inc_info.v_reason;
         lv_expected_receipt_id :=
                    i_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id;
         lv_source_system := 'MNL';
      ELSIF lv_msg_type = ct_inv_arr
      THEN
         lv_msg_type := ct_inv_arr;
         lv_dest_loc := i_miniload_info.vt_inv_arrival_info.v_actual_loc;
         lv_carrier_id := i_miniload_info.vt_inv_arrival_info.v_label;
         lv_prod_id := i_miniload_info.v_prod_id;
         ln_uom := i_miniload_info.n_uom;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         ln_qty_received := i_miniload_info.vt_inv_arrival_info.n_quantity;
         lv_inv_date := i_miniload_info.vt_inv_arrival_info.v_inv_date;
         lv_planned_loc := i_miniload_info.vt_inv_arrival_info.v_planned_loc;
         lv_source_system := 'MNL';
      ELSIF lv_msg_type = ct_inv_adj_dcr
      THEN
         lv_msg_type := ct_inv_adj_dcr;
         lv_carrier_id := i_miniload_info.vt_inv_adj_dcr_info.v_label;
         lv_prod_id := i_miniload_info.v_prod_id;
         ln_uom := i_miniload_info.n_uom;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         ln_qty_received := i_miniload_info.vt_inv_adj_dcr_info.n_quantity;
         lv_inv_date := i_miniload_info.vt_inv_adj_dcr_info.v_inv_date;
         lv_reason := i_miniload_info.vt_inv_adj_dcr_info.v_reason;
         lv_source_system := 'MNL';
      ELSIF lv_msg_type = ct_inv_upd_carr
      THEN
         lv_msg_type := ct_inv_upd_carr;
         lv_carrier_id := i_miniload_info.vt_carrier_update_info.v_carrier_id;
         ln_uom := i_miniload_info.vt_carrier_update_info.n_uom;
         lv_prod_id := i_miniload_info.vt_carrier_update_info.v_prod_id;
         lv_cust_pref_vendor :=
                    i_miniload_info.vt_carrier_update_info.v_cust_pref_vendor;
         ln_qty_received := i_miniload_info.vt_carrier_update_info.n_qty;
         lv_inv_date := i_miniload_info.vt_carrier_update_info.v_inv_date;
         lv_source_system := 'SWM';
      ELSIF lv_msg_type = ct_inv_plan_mov
      THEN
         lv_msg_type := ct_inv_plan_mov;
         lv_carrier_id := i_miniload_info.vt_inv_planned_mov_info.v_label;
         lv_source_loc := i_miniload_info.vt_inv_planned_mov_info.v_src_loc;
         ln_uom := i_miniload_info.n_uom;
         lv_prod_id := i_miniload_info.v_prod_id;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         ln_qty_expected :=
                           i_miniload_info.vt_inv_planned_mov_info.n_quantity;
         lv_inv_date := i_miniload_info.vt_inv_planned_mov_info.v_inv_date;
         lv_planned_loc :=
                        i_miniload_info.vt_inv_planned_mov_info.v_planned_loc;
         ln_order_priority :=
                     i_miniload_info.vt_inv_planned_mov_info.v_order_priority;
         lv_source_system := 'MNL';
      ELSIF lv_msg_type = ct_inv_lost
      THEN
         lv_msg_type := ct_inv_lost;
         lv_carrier_id := i_miniload_info.vt_inv_lost_info.v_label;
         ln_uom := i_miniload_info.n_uom;
         lv_prod_id := i_miniload_info.v_prod_id;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         ln_qty_received := i_miniload_info.vt_inv_lost_info.n_quantity;
         lv_inv_date := i_miniload_info.vt_inv_lost_info.v_inv_date;
         lv_reason := i_miniload_info.vt_inv_lost_info.v_reason;
         lv_source_system := 'MNL';
      ELSIF lv_msg_type = ct_pick_comp_carr
      THEN
         lv_msg_type := ct_pick_comp_carr;
         lv_carrier_id :=
                        i_miniload_info.vt_picking_complete_info.v_carrier_id;
         ln_uom := i_miniload_info.vt_picking_complete_info.n_uom;
         lv_prod_id := i_miniload_info.vt_picking_complete_info.v_prod_id;
         lv_cust_pref_vendor :=
                  i_miniload_info.vt_picking_complete_info.v_cust_pref_vendor;
         ln_qty_received :=
                          i_miniload_info.vt_picking_complete_info.n_quantity;
         lv_inv_date := i_miniload_info.vt_picking_complete_info.v_inv_date;
         lv_source_system := 'SWM';
      ELSIF lv_msg_type = ct_new_sku
      THEN
         lv_msg_type := ct_new_sku;
         lv_prod_id := i_miniload_info.vt_sku_info.v_prod_id;
         ln_uom := i_miniload_info.vt_sku_info.n_uom;
         lv_cust_pref_vendor :=
                               i_miniload_info.vt_sku_info.v_cust_pref_vendor;
         lv_description := i_miniload_info.vt_sku_info.v_sku_description;
         ln_items_per_carrier :=
                              i_miniload_info.vt_sku_info.n_items_per_carrier;
         lv_zone_id        := i_miniload_info.vt_sku_info.v_zone_id;
         lv_split_zone_id := i_miniload_info.vt_sku_info.v_split_zone_id;
         lv_source_system := 'SWM';
         
      ELSIF lv_msg_type = ct_modify_sku
      THEN
         lv_msg_type := ct_modify_sku;
         lv_prod_id := i_miniload_info.vt_sku_info.v_prod_id;
         ln_uom := i_miniload_info.vt_sku_info.n_uom;
         lv_cust_pref_vendor :=
                               i_miniload_info.vt_sku_info.v_cust_pref_vendor;
         lv_description := i_miniload_info.vt_sku_info.v_sku_description;
         ln_items_per_carrier :=
                              i_miniload_info.vt_sku_info.n_items_per_carrier;
         lv_zone_id        := i_miniload_info.vt_sku_info.v_zone_id;
         lv_split_zone_id := i_miniload_info.vt_sku_info.v_split_zone_id;                              
         lv_source_system := 'SWM';         
      ELSIF lv_msg_type = ct_delete_sku
      THEN
         lv_msg_type := ct_delete_sku;
         lv_prod_id := i_miniload_info.vt_sku_info.v_prod_id;
         ln_uom := i_miniload_info.vt_sku_info.n_uom;
         lv_cust_pref_vendor :=
                               i_miniload_info.vt_sku_info.v_cust_pref_vendor;
         lv_source_system := 'SWM';
         lv_zone_id        := i_miniload_info.vt_sku_info.v_zone_id;
         lv_split_zone_id := i_miniload_info.vt_sku_info.v_split_zone_id;
      ELSIF lv_msg_type = ct_start_of_day
      THEN
         lv_msg_type := ct_start_of_day;
         lv_order_date := i_miniload_info.vt_start_of_day_info.v_order_date;
         lv_source_system := 'SWM';
      ELSIF lv_msg_type = ct_carrier_status
      THEN
         lv_msg_type := ct_carrier_status;
         lv_prod_id  := i_miniload_info.v_prod_id;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         ln_uom := i_miniload_info.n_uom;
         lv_carrier_id := i_miniload_info.vt_carrier_status_info.v_label;         
         lv_reason := i_miniload_info.vt_carrier_status_info.v_reason;
         lv_source_system := 'SWM';
      ELSIF lv_msg_type = ct_message_status
      THEN
         lv_msg_type := ct_message_status;                  
         lv_message_status := i_miniload_info.vt_msg_status_info.v_msg_status;         
         lv_ref_message_id := i_miniload_info.vt_msg_status_info.v_msg_id;
         lv_source_system := 'MNL';                        
      ELSE
         lv_msg_text :=
                  ct_program_code || ' Invalid message type: ' || lv_msg_type;
         RAISE e_fail;
      END IF;

      lv_data := i_miniload_info.v_data;
      ln_data_len := LENGTH (i_miniload_info.v_data);
      lv_status := 'N';

    /* moved this to the insert statement
    
       SELECT miniload_message_seq.NEXTVAL
        INTO ln_msg_id
        FROM DUAL;
    */              
dbms_output.put_line('Before insert');    
      BEGIN
         IF (lv_msg_type IN
                (ct_exp_rec,
                 ct_inv_upd_carr,
                 ct_pick_comp_carr,
                 ct_new_sku,
                 ct_modify_sku,                 
                 ct_carrier_status)) THEN
dbms_output.put_line('in if');
            /* For the messages processed in this block, get the miniload
               Id using f_find_ml_system */                                    
            
            lv_ml_system :=f_find_ml_system(lv_prod_id, lv_cust_pref_vendor,
                                            lv_zone_id, lv_split_zone_id); 
dbms_output.put_line(lv_ml_system);
            INSERT INTO MINILOAD_MESSAGE
                        (message_id, MESSAGE_TYPE, source_system,
                         expected_receipt_id, prod_id,
                         cust_pref_vendor, UOM, items_per_carrier,
                         qty_expected, qty_received, carrier_id,
                         source_loc, planned_loc, dest_loc,
                         description, reason, order_date,
                         inv_date, ml_data_len, ml_data, status,
                         order_priority, ml_system 
                        )
                 VALUES (miniload_message_seq.NEXTVAL, i_msg_type, lv_source_system,
                         lv_expected_receipt_id, lv_prod_id,
                         lv_cust_pref_vendor, ln_uom, ln_items_per_carrier,
                         ln_qty_expected, ln_qty_received, lv_carrier_id,
                         lv_source_loc, lv_planned_loc, lv_dest_loc,
                         lv_description, lv_reason, lv_order_date,
                         lv_inv_date, ln_data_len, lv_data, lv_status,
                         ln_order_priority, lv_ml_system
                        );                              
        /*  Only one start of day message will be sent for all the miniload
            systems, make copies of the message and send it to all available
            miniload system  */
         ELSIF (lv_msg_type IN  (ct_start_of_day,ct_delete_sku))
         THEN
dbms_output.put_line('in elsif');
            FOR c1 IN c_ml_system
            LOOP            
            
               INSERT INTO MINILOAD_MESSAGE
                           (message_id, MESSAGE_TYPE, source_system,
                            expected_receipt_id, prod_id,
                            cust_pref_vendor, UOM,
                            items_per_carrier, qty_expected,
                            qty_received, carrier_id, source_loc,
                            planned_loc, dest_loc, description,
                            reason, order_date, inv_date,
                            ml_data_len, ml_data, status,
                            order_priority, ml_system
                           )
                    VALUES (miniload_message_seq.NEXTVAL, i_msg_type, lv_source_system,
                            lv_expected_receipt_id, lv_prod_id,
                            lv_cust_pref_vendor, ln_uom,
                            ln_items_per_carrier, ln_qty_expected,
                            ln_qty_received, lv_carrier_id, lv_source_loc,
                            lv_planned_loc, lv_dest_loc, lv_description,
                            lv_reason, lv_order_date, lv_inv_date,
                            ln_data_len, lv_data, lv_status,
                            ln_order_priority, c1.ml_system
                           );
            END LOOP;

            IF c_ml_system%ISOPEN
            THEN
               CLOSE c_ml_system;
            END IF;
         ELSIF (lv_msg_type IN
                   (ct_inv_adj_inc,
                    ct_inv_adj_dcr,
                    ct_inv_arr,
                    ct_exp_rec_comp,
                    ct_inv_plan_mov,
                    ct_inv_lost,
                    ct_message_status)) THEN
dbms_output.put_line('in elsif 2');
            /* for the messages processed here, miniload system value should
               be passed in by the calling function in the input parameter
               i_miniload_info.v_ml_system */
            
            lv_ml_system := i_miniload_info.v_ml_system;            
            
            INSERT INTO MINILOAD_MESSAGE
                        (message_id, MESSAGE_TYPE,
                         source_system,
                         expected_receipt_id, prod_id,
                         cust_pref_vendor, UOM, items_per_carrier,
                         qty_expected, qty_received, carrier_id,
                         source_loc, planned_loc, dest_loc,
                         description, reason, order_date,
                         inv_date, ml_data_len, ml_data, status,
                         order_priority, ml_system, ref_message_id,
                         ref_message_status)
                 VALUES
                        (miniload_message_seq.NEXTVAL, i_msg_type,
                         lv_source_system,
                         lv_expected_receipt_id, lv_prod_id,
                         lv_cust_pref_vendor, ln_uom, ln_items_per_carrier,
                         ln_qty_expected, ln_qty_received, lv_carrier_id,
                         lv_source_loc, lv_planned_loc, lv_dest_loc,
                         lv_description, lv_reason, lv_order_date,
                         lv_inv_date, ln_data_len, lv_data, lv_status,
                         ln_order_priority, lv_ml_system, lv_ref_message_id,
                         lv_message_status);
         END IF;     
      EXCEPTION
         WHEN OTHERS
         THEN
dbms_output.put_line(sqlerrm);
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Error in creating Message for Message Type: '
               || i_msg_type
               || ' Msg id :'
               || ln_msg_id
               || ' Prod id: '
               || lv_prod_id
               || ' CPV: '
               || lv_cust_pref_vendor
               || ' UOM: '
               || ln_uom;
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
            RAISE e_fail;
      END;

      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' mini-load Message created for Message Type: '
         || i_msg_type
         || ' Msg id :'
         || ln_msg_id
         || ' Prod id: '
         || lv_prod_id
         || ' CPV: '
         || lv_cust_pref_vendor
         || ' UOM: '
         || ln_uom;

      IF (i_log_flag = TRUE)
      THEN
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      ELSIF (i_log_flag = FALSE)
      THEN
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN e_fail
      THEN
         IF (i_log_flag = TRUE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         ELSIF (i_log_flag = FALSE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         END IF;

         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in insertion in miniload_message table for Message Type: '
            || i_msg_type;

         IF (i_log_flag = TRUE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
         ELSIF (i_log_flag = FALSE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
         END IF;

         o_status := ct_failure;
   END p_insert_miniload_message;

-------------------------------------------------------------------------
-- Procedure:
--    p_insert_miniload_order
--
-- Description:
--     This procedure Inserts order messages into mini-load order table
--
-- Parameters:
--    i_miniload_info  - record holding data to be inserted in miniload order
--                       table.
--    i_msg_type - Type of message
--   o_status - return status
--          0  - No errors.
--          1  - Error occured
--   i_log_flag - Used by specfic internal functions(DEFAULT 'Y').
--                for logging into error into swms_log.
--
-- Exceptions Raised:
--    None.  If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/30/05          Created as part of the mini-load changes
--
--   12/13/07 ctvgg000  Changed to insert miniload_identifier along with
--                other message data
---------------------------------------------------------------------------
   PROCEDURE p_insert_miniload_order (
      i_miniload_info   IN       t_miniload_info DEFAULT NULL,
      i_msg_type        IN       VARCHAR2,
      o_status          OUT      NUMBER,
      i_log_flag        IN       BOOLEAN DEFAULT TRUE
   )
   IS
      lv_msg_type             MINILOAD_ORDER.MESSAGE_TYPE%TYPE   DEFAULT NULL;
      ln_msg_id               MINILOAD_ORDER.message_id%TYPE;
      lv_prod_id              MINILOAD_ORDER.prod_id%TYPE        DEFAULT NULL;
      lv_cust_pref_vendor     MINILOAD_ORDER.cust_pref_vendor%TYPE
                                                                 DEFAULT NULL;
      ln_uom                  MINILOAD_ORDER.UOM%TYPE            DEFAULT NULL;
      ln_quantity_requested   MINILOAD_ORDER.quantity_requested%TYPE
                                                                 DEFAULT NULL;
      lv_order_id             MINILOAD_ORDER.order_id%TYPE       DEFAULT NULL;
      lv_order_date           MINILOAD_ORDER.order_date%TYPE     DEFAULT NULL;
      lv_order_item_id        MINILOAD_ORDER.order_item_id%TYPE  DEFAULT NULL;
      lv_description          MINILOAD_ORDER.description%TYPE    DEFAULT NULL;
      lv_order_type           MINILOAD_ORDER.ORDER_TYPE%TYPE     DEFAULT NULL;
      ln_order_priority       MINILOAD_ORDER.order_priority%TYPE DEFAULT NULL;
      ln_order_item_count     MINILOAD_ORDER.order_item_id_count%TYPE
                                                                 DEFAULT NULL;
      ln_quantity_available   MINILOAD_ORDER.quantity_available%TYPE
                                                                 DEFAULT NULL;
      lv_status               MINILOAD_ORDER.status%TYPE         DEFAULT NULL;
      lv_data                 MINILOAD_ORDER.ml_data%TYPE        DEFAULT NULL;
      ln_data_len             MINILOAD_ORDER.ml_data_len%TYPE    DEFAULT NULL;
      lv_source_system        MINILOAD_ORDER.source_system%TYPE  DEFAULT NULL;
      ln_sku_priority         MINILOAD_ORDER.sku_priority%TYPE   DEFAULT NULL;
      lv_msg_text             VARCHAR2 (1500);
      --Hold return status of functions
      lv_fname                VARCHAR2 (50)      := 'P_INSERT_MINILOAD_ORDER';
      /* Miniload Identifier*/
      lv_ml_system            MINILOAD_CONFIG.ml_system%TYPE     DEFAULT NULL;

      CURSOR c_ml_system
      IS
         SELECT   ml_system
             FROM MINILOAD_CONFIG
         ORDER BY ml_system;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_insert_miniload_order');
      -- populate local variables depending on the type of message
      lv_msg_type := i_msg_type;

      IF lv_msg_type = ct_ship_ord_hdr
      THEN
         lv_msg_type := ct_ship_ord_hdr;
         lv_order_id := i_miniload_info.vt_new_ship_ord_hdr_info.v_order_id;
         lv_description :=
                       i_miniload_info.vt_new_ship_ord_hdr_info.v_description;
         ln_order_priority :=
                    i_miniload_info.vt_new_ship_ord_hdr_info.n_order_priority;
         lv_order_type :=
                        i_miniload_info.vt_new_ship_ord_hdr_info.v_order_type;
         lv_order_date :=
                        i_miniload_info.vt_new_ship_ord_hdr_info.v_order_date;
         lv_source_system := 'SWM';
         lv_status := 'N';
      ELSIF lv_msg_type = ct_ship_ord_inv
      THEN
         lv_msg_type := ct_ship_ord_inv;
         lv_order_id :=
                     i_miniload_info.vt_new_ship_ord_item_inv_info.v_order_id;
         lv_order_item_id :=
                i_miniload_info.vt_new_ship_ord_item_inv_info.v_order_item_id;
         ln_quantity_requested :=
                          i_miniload_info.vt_new_ship_ord_item_inv_info.n_qty;
         ln_uom := i_miniload_info.vt_new_ship_ord_item_inv_info.n_uom;
         lv_prod_id :=
                      i_miniload_info.vt_new_ship_ord_item_inv_info.v_prod_id;
         lv_cust_pref_vendor :=
             i_miniload_info.vt_new_ship_ord_item_inv_info.v_cust_pref_vendor;
         ln_sku_priority :=
                 i_miniload_info.vt_new_ship_ord_item_inv_info.n_sku_priority;
         lv_source_system := 'SWM';
         lv_status := 'N';
      ELSIF lv_msg_type = ct_ship_ord_trl
      THEN
         lv_msg_type := ct_ship_ord_trl;
         lv_order_id := i_miniload_info.vt_new_ship_ord_trail_info.v_order_id;
         ln_order_item_count :=
             i_miniload_info.vt_new_ship_ord_trail_info.n_order_item_id_count;
         lv_source_system := 'SWM';
         lv_status := 'N';
      ELSIF lv_msg_type = ct_ship_ord_status
      THEN
         lv_msg_type := ct_ship_ord_status;
         lv_order_id := i_miniload_info.vt_item_status_info.v_order_id;
         lv_order_item_id :=
                          i_miniload_info.vt_item_status_info.v_order_item_id;
         ln_quantity_requested :=
                     i_miniload_info.vt_item_status_info.n_quantity_requested;
         ln_quantity_available :=
                     i_miniload_info.vt_item_status_info.n_quantity_available;
         ln_uom := i_miniload_info.vt_item_status_info.n_uom;
         lv_prod_id := i_miniload_info.vt_item_status_info.v_prod_id;
         lv_cust_pref_vendor :=
                       i_miniload_info.vt_item_status_info.v_cust_pref_vendor;
         lv_source_system := 'MNL';
         lv_status := 'N';
      ELSIF lv_msg_type = ct_ship_ord_prio
      THEN
         lv_msg_type := ct_ship_ord_prio;
         lv_order_id := i_miniload_info.vt_ship_ord_prio_upd_info.v_order_id;
         ln_order_priority :=
                   i_miniload_info.vt_ship_ord_prio_upd_info.n_order_priority;
         lv_source_system := 'SWM';
         lv_status := 'N';
      ELSE
         lv_msg_text :=
                  'Prog Code: ' || ct_program_code || ' Invalid Message Type';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         ROLLBACK;
         o_status := ct_failure;
      END IF;

      lv_data := i_miniload_info.v_data;
      ln_data_len := LENGTH (lv_data);      

      
      IF (lv_msg_type IN (ct_ship_ord_hdr, ct_ship_ord_inv, ct_ship_ord_trl)
         )
      THEN
         
         FOR c1 IN c_ml_system
         LOOP
            
            SELECT miniload_message_seq.NEXTVAL
            INTO ln_msg_id
            FROM DUAL;
            
            INSERT INTO MINILOAD_ORDER
                        (message_id, MESSAGE_TYPE, prod_id,
                         cust_pref_vendor, UOM, sku_priority,
                         order_id, order_date, order_item_id,
                         ORDER_TYPE, order_priority,
                         order_item_id_count, description,
                         quantity_requested, quantity_available,
                         status, ml_data, ml_data_len, source_system,
                         ml_system
                        )
                 VALUES (ln_msg_id, lv_msg_type, lv_prod_id,
                         lv_cust_pref_vendor, ln_uom, ln_sku_priority,
                         lv_order_id, lv_order_date, lv_order_item_id,
                         lv_order_type, ln_order_priority,
                         ln_order_item_count, lv_description,
                         ln_quantity_requested, ln_quantity_available,
                         lv_status, lv_data, ln_data_len, lv_source_system,
                         c1.ml_system
                        );
         END LOOP;
      ELSIF (lv_msg_type = ct_ship_ord_status)
      THEN         
         
         SELECT miniload_message_seq.NEXTVAL
         INTO ln_msg_id
         FROM DUAL;
        
         lv_ml_system := i_miniload_info.v_ml_system;

         INSERT INTO MINILOAD_ORDER
                     (message_id, MESSAGE_TYPE, prod_id,
                      cust_pref_vendor, UOM, sku_priority,
                      order_id, order_date, order_item_id,
                      ORDER_TYPE, order_priority, order_item_id_count,
                      description, quantity_requested,
                      quantity_available, status, ml_data,
                      ml_data_len, source_system, ml_system
                     )
              VALUES (ln_msg_id, lv_msg_type, lv_prod_id,
                      lv_cust_pref_vendor, ln_uom, ln_sku_priority,
                      lv_order_id, lv_order_date, lv_order_item_id,
                      lv_order_type, ln_order_priority, ln_order_item_count,
                      lv_description, ln_quantity_requested,
                      ln_quantity_available, lv_status, lv_data,
                      ln_data_len, lv_source_system, lv_ml_system
                     );
      ELSIF (lv_msg_type = ct_ship_ord_prio) THEN
         lv_ml_system := f_find_ml_system (lv_prod_id, lv_cust_pref_vendor);

         SELECT miniload_message_seq.NEXTVAL
           INTO ln_msg_id
           FROM DUAL;

         INSERT INTO MINILOAD_ORDER
                     (message_id, MESSAGE_TYPE, prod_id,
                      cust_pref_vendor, UOM, sku_priority,
                      order_id, order_date, order_item_id,
                      ORDER_TYPE, order_priority, order_item_id_count,
                      description, quantity_requested,
                      quantity_available, status, ml_data,
                      ml_data_len, source_system, ml_system
                     )
              VALUES (ln_msg_id, lv_msg_type, lv_prod_id,
                      lv_cust_pref_vendor, ln_uom, ln_sku_priority,
                      lv_order_id, lv_order_date, lv_order_item_id,
                      lv_order_type, ln_order_priority, ln_order_item_count,
                      lv_description, ln_quantity_requested,
                      ln_quantity_available, lv_status, lv_data,
                      ln_data_len, lv_source_system, lv_ml_system
                     );
      END IF;

      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' mini-load Order created:'
         || i_msg_type
         || ' Message id : '
         || ln_msg_id
         || ' Order id :'
         || lv_order_id
         || ' Prod Id: '
         || lv_prod_id
         || ' CPV: '
         || lv_cust_pref_vendor
         || ' UOM: '
         || ln_uom;

      IF (i_log_flag = TRUE)
      THEN
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      ELSIF (i_log_flag = FALSE)
      THEN
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      END IF;

      o_status := ct_success;
   EXCEPTION
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in insertion in miniload_order table for Message Type: '
            || i_msg_type;

         IF (i_log_flag = TRUE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
         ELSIF (i_log_flag = FALSE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
         END IF;

         o_status := ct_failure;
   END p_insert_miniload_order;

-------------------------------------------------------------------------
-- Procedure:
--    p_insert_miniload_exception
--
-- Description:
--     This procedure inserts exception messages into mini-load exception
--     table.
--
-- Parameters:
--    i_miniload_info  - record holding data to be inserted in miniload
--                       order table
--    i_msg_type       - Type of message
--    o_status         - return status
--                       0  - No errors.
--                       1  - Error occured
--
-- Exceptions Raised:
--    None.  If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/30/05          Created as part of the miniload changes.
--    11/08/08 prpbcb   Added inventory planned move, inventory arrival.
---------------------------------------------------------------------------
   PROCEDURE p_insert_miniload_exception (
      i_miniload_info   IN       t_miniload_info DEFAULT NULL,
      i_msg_type        IN       miniload_message.message_type%TYPE,
      o_status          OUT      NUMBER)
   IS
      lv_fname              VARCHAR2(50)    := 'P_INSERT_MINILOAD_EXCEPTION';

      lv_msg_type           miniload_exception.msg_type%TYPE     DEFAULT NULL;
      lv_prod_id            miniload_exception.prod_id%TYPE      DEFAULT NULL;
      lv_cust_pref_vendor   miniload_exception.cust_pref_vendor%TYPE
                                                                 DEFAULT NULL;
      ln_seq_id             miniload_exception.exception_id%TYPE;
      ln_uom                miniload_exception.UOM%TYPE          DEFAULT NULL;
      ln_qty_exp            miniload_exception.qty_expected%TYPE DEFAULT NULL;
      ln_act_qty            miniload_exception.actual_qty%TYPE   DEFAULT NULL;
      lv_pallet_id          miniload_exception.pallet_id%TYPE    DEFAULT NULL;
      lv_inv_date           miniload_exception.inv_date%TYPE     DEFAULT NULL;
      lv_cmt                miniload_exception.cmt%TYPE          DEFAULT NULL;
      lv_msg_text           VARCHAR2(1500);
      lv_msg_status    miniload_exception.ref_message_status%TYPE DEFAULT NULL;
      lv_ref_msg_id    miniload_exception.ref_message_id%TYPE DEFAULT NULL;
      lv_cmt_len	NUMBER := 0;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_insert_miniload_exception');
      -- populate local variables depending on the type of message
      lv_msg_type := i_msg_type;                         
      
      IF lv_msg_type = ct_inv_adj_inc THEN
         lv_msg_type         := ct_inv_adj_inc;
         ln_uom              := i_miniload_info.n_uom;
         lv_prod_id          := i_miniload_info.v_prod_id;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         ln_act_qty          := i_miniload_info.vt_inv_adj_inc_info.n_quantity;
         lv_inv_date         := i_miniload_info.vt_inv_adj_inc_info.v_inv_date;
         lv_pallet_id :=
                    i_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id;
         lv_cmt          := i_miniload_info.vt_inv_adj_inc_info.v_reason;
      ELSIF lv_msg_type = ct_inv_plan_mov THEN
         --
         -- Inventory Planned Move
         --
         ln_uom              := i_miniload_info.n_uom;
         lv_prod_id          := i_miniload_info.v_prod_id;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         lv_ref_msg_id       := i_miniload_info.n_msg_id;
         ln_act_qty     := i_miniload_info.vt_inv_planned_mov_info.n_quantity;
         lv_inv_date    := i_miniload_info.vt_inv_planned_mov_info.v_inv_date;
         lv_pallet_id   := i_miniload_info.vt_inv_planned_mov_info.v_label;
         --
         -- Provide details why the inventory planned move failed.
         --
         lv_cmt           := build_exception_cmt(i_miniload_info,
                                                 lv_msg_type,
                                                 lv_pallet_id);
      ELSIF lv_msg_type = ct_inv_arr THEN
         --
         -- Inventory Arrival
         --
         ln_uom              := i_miniload_info.n_uom;
         lv_prod_id          := i_miniload_info.v_prod_id;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         lv_ref_msg_id       := i_miniload_info.n_msg_id;
         ln_act_qty          := i_miniload_info.vt_inv_arrival_info.n_quantity;
         lv_inv_date         := i_miniload_info.vt_inv_arrival_info.v_inv_date;
         lv_pallet_id        := i_miniload_info.vt_inv_arrival_info.v_label;
         --
         -- Provide details why the inventory arrival failed.
         --
         lv_cmt              := build_exception_cmt(i_miniload_info,
                                                    lv_msg_type,
                                                    lv_pallet_id);
      ELSIF lv_msg_type = ct_exp_rec_comp THEN
         lv_msg_type := ct_exp_rec_comp;
         ln_uom := i_miniload_info.n_uom;
         lv_prod_id := i_miniload_info.v_prod_id;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         ln_qty_exp := i_miniload_info.vt_exp_receipt_complete_info.n_qty_exp;
         ln_act_qty := i_miniload_info.vt_exp_receipt_complete_info.n_qty_rcv;
         lv_pallet_id :=
            i_miniload_info.vt_exp_receipt_complete_info.v_expected_receipt_id;
      ELSIF lv_msg_type = ct_inv_adj_dcr THEN
         lv_msg_type := ct_inv_adj_dcr;
         ln_uom := i_miniload_info.n_uom;
         lv_prod_id := i_miniload_info.v_prod_id;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         ln_act_qty := i_miniload_info.vt_inv_adj_dcr_info.n_quantity;
         lv_pallet_id := i_miniload_info.vt_inv_adj_dcr_info.v_label;
         lv_inv_date := i_miniload_info.vt_inv_adj_dcr_info.v_inv_date;
         lv_cmt := i_miniload_info.vt_inv_adj_dcr_info.v_reason;
      ELSIF lv_msg_type = ct_inv_lost THEN
         lv_msg_type := ct_inv_lost;
         ln_uom := i_miniload_info.n_uom;
         lv_prod_id := i_miniload_info.v_prod_id;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         ln_act_qty := i_miniload_info.vt_inv_lost_info.n_quantity;
         lv_pallet_id := i_miniload_info.vt_inv_lost_info.v_label;
         lv_inv_date := i_miniload_info.vt_inv_lost_info.v_inv_date;
         lv_cmt := i_miniload_info.vt_inv_lost_info.v_reason;
      ELSIF lv_msg_type = ct_message_status THEN
         lv_msg_type := ct_message_status;
         ln_uom := i_miniload_info.n_uom;
         lv_prod_id := i_miniload_info.v_prod_id;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         lv_msg_status := i_miniload_info.vt_msg_status_info.v_msg_status;                        
         lv_ref_msg_id := i_miniload_info.vt_msg_status_info.v_msg_id;
      ELSE         
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Invalid message type: '
            || i_msg_type;
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      END IF;

      INSERT INTO MINILOAD_EXCEPTION
                  (exception_id,
                   msg_type,
                   prod_id,
                   cust_pref_vendor,
                   uom,
                   pallet_id,
                   qty_expected,
                   actual_qty,
                   inv_date,
                   cmt,
                   ref_message_status,
                   ref_message_id)
           VALUES 
                  (exception_id_seq.NEXTVAL,
                   lv_msg_type,
                   lv_prod_id,
                   lv_cust_pref_vendor,
                   ln_uom,
                   lv_pallet_id, 
                   ln_qty_exp,
                   ln_act_qty,
                   lv_inv_date,
                   lv_cmt,
                   lv_msg_status,
                   lv_ref_msg_id);
                   
     /* 6000010239-exception_email_alert -Begin */
	lv_cmt_len := LENGTH('PROD_ID-'||lv_prod_id||',PALLET_ID-' ||
		lv_pallet_id||',MSG_TYPE-'||lv_msg_type||',CMT-');
       pl_event.ins_failure_event('MINILOAD_EXCEPTION','Q','CRIT',lv_prod_id,'CRIT:MINILOAD_EXCEPTION',
        'PROD_ID-'||lv_prod_id||',PALLET_ID-' ||lv_pallet_id||',MSG_TYPE-'||lv_msg_type||',CMT-' ||SUBSTR(lv_cmt, 1, 400-lv_cmt_len));    
      /* 6000010239-exception_email_alert -End */
                   
                   
        
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' mini-load Exception created: '
         || i_msg_type
         || ' Exception id : '
         || ln_seq_id
         || ' Prod Id : '
         || lv_prod_id
         || ' CPV: '
         || lv_cust_pref_vendor
         || ' UOM: '
         || ln_uom;
      pl_text_log.ins_msg('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      o_status := ct_success;
   EXCEPTION
      WHEN OTHERS THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error Inserting in miniload_exception table';
         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
--         o_status := ct_failure;
         o_status := ct_success;
   END p_insert_miniload_exception;

---------------------------------------------------------------------------
-- Function:
--    f_create_message
--
-- Description:
--     This function is used to create messages.
--
-- Parameters:
--    i_miniload_info  - Information to describe message contents
--
-- Return Values:
--    l_miniload_info.v_data - message.
--    i_msg_type             - message type.
--
-- Exceptions Raised:
--    e_create_msg - If unknown message type is given
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/29/05          Created as part of the mini-load changes
--    12/14/07 ctvgg00    Added functionality to create carrier status 
--                      message.
---------------------------------------------------------------------------
   FUNCTION f_create_message
                (i_miniload_info   IN   t_miniload_info DEFAULT NULL,
                 i_msg_type        IN   VARCHAR2)
      RETURN VARCHAR2
   IS
      l_miniload_info   t_miniload_info;
      lv_fname          VARCHAR2 (50)   := 'F_CREATE_MESSAGE';
      lv_msg_text       VARCHAR2 (1500);
      lv_msg_type       VARCHAR2 (50)   := i_msg_type;
      ln_status         NUMBER (1);
      e_create_msg      EXCEPTION;
   BEGIN
      lv_msg_type := i_msg_type;

      IF lv_msg_type = ct_exp_rec
      THEN
         l_miniload_info.v_data :=
               RPAD (ct_exp_rec, ct_msg_type_size, ' ')
            || RPAD
                   (i_miniload_info.vt_exp_receipt_info.v_expected_receipt_id,
                    ct_receipt_id_size,
                    ' '
                   )
            || i_miniload_info.v_sku
            || LPAD (i_miniload_info.vt_exp_receipt_info.n_qty_expected,
                     ct_qty_size,
                     '0'
                    )
            || TO_CHAR (i_miniload_info.vt_exp_receipt_info.v_inv_date,
                        'YYYY-MM-DD'
                       );
      ELSIF lv_msg_type = ct_new_sku
      THEN
         l_miniload_info.v_data :=
               RPAD (ct_new_sku, ct_msg_type_size, ' ')
            || i_miniload_info.v_sku
            || RPAD (i_miniload_info.vt_sku_info.v_sku_description,
                     ct_description_size,
                     ' '
                    )
            || LPAD (i_miniload_info.vt_sku_info.n_items_per_carrier,
                     ct_qty_size,
                     '0'
                    );
      ELSIF lv_msg_type = ct_modify_sku
      THEN
         l_miniload_info.v_data :=
               RPAD (ct_modify_sku, ct_msg_type_size, ' ')
            || i_miniload_info.v_sku
            || RPAD (i_miniload_info.vt_sku_info.v_sku_description,
                     ct_description_size,
                     ' '
                    )
            || LPAD (i_miniload_info.vt_sku_info.n_items_per_carrier,
                     ct_qty_size,
                     '0'
                    );
      ELSIF lv_msg_type = ct_delete_sku
      THEN
         l_miniload_info.v_data :=
               RPAD (ct_delete_sku, ct_msg_type_size, ' ')
            || i_miniload_info.v_sku;
      ELSIF lv_msg_type = ct_inv_upd_carr
      THEN
         l_miniload_info.v_data :=
               RPAD (ct_inv_upd_carr, ct_msg_type_size, ' ')
            || RPAD
                  (REPLACE
                         (i_miniload_info.vt_carrier_update_info.v_carrier_id,
                          ct_pre_label
                         ),
                   ct_label_size,
                   ' '
                  )
            || i_miniload_info.v_sku
            || LPAD (i_miniload_info.vt_carrier_update_info.n_qty,
                     ct_qty_size,
                     '0'
                    )
            || NVL
                  (TO_CHAR (i_miniload_info.vt_carrier_update_info.v_inv_date,
                            'YYYY-MM-DD'
                           ),
                   LPAD (' ', ct_date_size, ' ')
                  );
      ELSIF lv_msg_type = ct_ship_ord_hdr
      THEN
         l_miniload_info.v_data :=
               RPAD (ct_ship_ord_hdr, ct_msg_type_size, ' ')
            || RPAD (i_miniload_info.vt_new_ship_ord_hdr_info.v_order_id,
                     ct_order_id_size,
                     ' '
                    )
            || RPAD
                  (NVL
                      (i_miniload_info.vt_new_ship_ord_hdr_info.v_description,
                       ' '
                      ),
                   ct_description_size,
                   ' '
                  )
            || LPAD
                   (i_miniload_info.vt_new_ship_ord_hdr_info.n_order_priority,
                    ct_priority_size,
                    '0'
                   )
            || RPAD (i_miniload_info.vt_new_ship_ord_hdr_info.v_order_type,
                     ct_order_type_size,
                     ' '
                    )
            || NVL
                  (TO_CHAR
                       (i_miniload_info.vt_new_ship_ord_hdr_info.v_order_date,
                        'YYYY-MM-DD'
                       ),
                   LPAD (' ', ct_date_size, ' ')
                  );
      ELSIF lv_msg_type = ct_ship_ord_inv
      THEN
         l_miniload_info.v_data :=
               RPAD (ct_ship_ord_inv, ct_msg_type_size, ' ')
            || RPAD (i_miniload_info.vt_new_ship_ord_item_inv_info.v_order_id,
                     ct_order_id_size,
                     ' '
                    )
            || RPAD
                  (i_miniload_info.vt_new_ship_ord_item_inv_info.v_order_item_id,
                   ct_order_item_id_size,
                   ' '
                  )
            || i_miniload_info.v_sku
            || LPAD (i_miniload_info.vt_new_ship_ord_item_inv_info.n_qty,
                     ct_qty_size,
                     '0'
                    )
            || LPAD
                  (i_miniload_info.vt_new_ship_ord_item_inv_info.n_sku_priority,
                   ct_priority_size,
                   '0'
                  );
      ELSIF lv_msg_type = ct_ship_ord_trl
      THEN
         l_miniload_info.v_data :=
               RPAD (ct_ship_ord_trl, ct_msg_type_size, ' ')
            || RPAD (i_miniload_info.vt_new_ship_ord_trail_info.v_order_id,
                     ct_order_id_size,
                     ' '
                    )
            || LPAD
                  (i_miniload_info.vt_new_ship_ord_trail_info.n_order_item_id_count,
                   ct_count_size,
                   '0'
                  );
      ELSIF lv_msg_type = ct_ship_ord_prio
      THEN
         l_miniload_info.v_data :=
               RPAD (ct_ship_ord_prio, ct_msg_type_size, ' ')
            || RPAD (i_miniload_info.vt_ship_ord_prio_upd_info.v_order_id,
                     ct_order_id_size,
                     ' '
                    )
            || LPAD
                  (i_miniload_info.vt_ship_ord_prio_upd_info.n_order_priority,
                   ct_priority_size,
                   '0'
                  );
      ELSIF lv_msg_type = ct_pick_comp_carr
      THEN
         l_miniload_info.v_data :=
               RPAD (ct_pick_comp_carr, ct_msg_type_size, ' ')
            || RPAD
                  (REPLACE
                       (i_miniload_info.vt_picking_complete_info.v_carrier_id,
                        ct_pre_label
                       ),
                   ct_label_size,
                   ' '
                  )
            || i_miniload_info.v_sku
            || LPAD (i_miniload_info.vt_picking_complete_info.n_quantity,
                     ct_qty_size,
                     '0'
                    )
            || NVL
                  (TO_CHAR
                         (i_miniload_info.vt_picking_complete_info.v_inv_date,
                          'YYYY-MM-DD'
                         ),
                   LPAD (' ', ct_date_size, ' ')
                  );
      ELSIF lv_msg_type = ct_start_of_day
      THEN
         l_miniload_info.v_data :=
               RPAD (ct_start_of_day, ct_msg_type_size, ' ')
            || TO_CHAR (i_miniload_info.vt_start_of_day_info.v_order_date,
                        'YYYY-MM-DD'
                       );
      ELSIF lv_msg_type = ct_carrier_status
      THEN      
      l_miniload_info.v_data :=
              RPAD(ct_carrier_status,ct_msg_type_size, ' ')
           || RPAD
                  (REPLACE
                       (i_miniload_info.vt_carrier_status_info.v_label,
                        ct_pre_label
                       ),
                   ct_label_size,
                   ' '
                  )
           || i_miniload_info.vt_carrier_status_info.v_carrier_status
           || RPAD(i_miniload_info.vt_carrier_status_info.v_user,ct_user_size,' ')
           || RPAD
                  (NVL
                      (i_miniload_info.vt_carrier_status_info.v_reason,
                       ' '
                      ),
                   ct_reason_size,
                   ' '                   
                  );            
      ELSE
         RAISE e_create_msg;
      END IF;

      RETURN l_miniload_info.v_data;
   EXCEPTION
      WHEN e_create_msg
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Invalid Message Type: '
            || lv_msg_type;
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         RAISE;
      WHEN OTHERS
      THEN
         lv_msg_text :=
             'Prog Code: ' || ct_program_code || ' Error in message Creation';
         Pl_Text_Log.ins_msg ('FATAL',
                              lv_fname,
                              lv_msg_text,
                              SQLCODE,
                              SQLERRM
                             );
         RAISE;
   END f_create_message;

-------------------------------------------------------------------------
-- Procedue:
--    p_insert_miniload_trans
--
-- Description:
--     This procedure Inserts order messages into miniload_trans table
--
-- Parameters:
--    i_miniload_info  - record holding data to be inserted in
--                       miniload_trans table
--    i_msg_type - Type of message
--   o_status - return status
--          0  - No errors.
--          1  - Error occured
--
-- Exceptions Raised:
--    None.  If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/30/05          Created as part of the mini-load changes
--    05/10/06 prphqb   MII and MIA has wrong qty (not *spc)
--    09/05/07 prpbcb   MII and MIA has wrong qty (not *spc)
--                      Changed the insert stmt for the MINILOAD_TRANS
--                      table to not strip OPS$ from the user id.  Because
--                      of how the transaction screen works when querying
--                      by user id the OPS$ is needed.  This also keeps the
--                      user id format consistent with the TRANS table.
--
--                      Changed to populate the trans.cmt from the
--                      t_miniload_info.vt_sku_inv.v_cmt for CT_NEW_SKU
--                      and CT_MODIFY_SKU.
---------------------------------------------------------------------------
   PROCEDURE p_insert_miniload_trans (
      i_miniload_info   IN       t_miniload_info,
      i_msg_type        IN       MINILOAD_MESSAGE.MESSAGE_TYPE%TYPE,
      o_status          OUT      NUMBER
   )
   IS
      lv_fname               VARCHAR2 (50)       := 'P_INSERT_MINILOAD_TRANS';
      lv_msg_text            VARCHAR2 (1500);
      lv_msg_type            MINILOAD_MESSAGE.MESSAGE_TYPE%TYPE;
      ln_trans_id            MINILOAD_TRANS.trans_id%TYPE        DEFAULT NULL;
      lv_trans_type          MINILOAD_TRANS.TRANS_TYPE%TYPE      DEFAULT NULL;
      lv_prod_id             MINILOAD_TRANS.prod_id%TYPE         DEFAULT NULL;
      lv_cust_pref_vendor    MINILOAD_TRANS.cust_pref_vendor%TYPE
                                                                 DEFAULT NULL;
      ln_uom                 MINILOAD_TRANS.UOM%TYPE             DEFAULT NULL;
      lv_exp_date            MINILOAD_TRANS.exp_date%TYPE        DEFAULT NULL;
      ln_qty_received        MINILOAD_TRANS.qty%TYPE             DEFAULT NULL;
      ln_items_per_carrier   MINILOAD_TRANS.items_per_carrier%TYPE
                                                                 DEFAULT NULL;
      lv_pallet_id           MINILOAD_TRANS.pallet_id%TYPE       DEFAULT NULL;
      lv_ref_pallet_id       MINILOAD_TRANS.ref_pallet_id%TYPE   DEFAULT NULL;
      lv_dest_loc            MINILOAD_TRANS.dest_loc%TYPE        DEFAULT NULL;
      lv_cmt                 MINILOAD_TRANS.cmt%TYPE             DEFAULT NULL;
      lv_conv_need           CHAR (1)                                := 'N';
   BEGIN
      lv_msg_type := i_msg_type;
      lv_trans_type := i_miniload_info.v_trans_type;

      IF lv_msg_type = ct_inv_adj_inc
      THEN
         ln_uom := i_miniload_info.n_uom;
         lv_prod_id := i_miniload_info.v_prod_id;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         ln_qty_received := i_miniload_info.vt_inv_adj_inc_info.n_quantity;
         lv_exp_date := i_miniload_info.vt_inv_adj_inc_info.v_inv_date;
         lv_pallet_id :=
                    i_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id;
         lv_ref_pallet_id := i_miniload_info.vt_inv_adj_inc_info.v_label;
         lv_cmt := i_miniload_info.vt_inv_adj_inc_info.v_reason;
         lv_conv_need := 'Y';
      ELSIF lv_msg_type = ct_inv_arr
      THEN
         ln_uom := i_miniload_info.n_uom;
         lv_prod_id := i_miniload_info.v_prod_id;
         lv_cust_pref_vendor := i_miniload_info.v_cust_pref_vendor;
         lv_dest_loc := i_miniload_info.vt_inv_arrival_info.v_actual_loc;
         lv_pallet_id := i_miniload_info.vt_inv_arrival_info.v_label;
         ln_qty_received := i_miniload_info.vt_inv_arrival_info.n_quantity;
         lv_exp_date := i_miniload_info.vt_inv_arrival_info.v_inv_date;
         lv_conv_need := 'Y';
      ELSIF lv_msg_type = ct_new_sku
      THEN
         ln_uom := i_miniload_info.vt_sku_info.n_uom;
         lv_prod_id := i_miniload_info.vt_sku_info.v_prod_id;
         lv_cust_pref_vendor :=
                               i_miniload_info.vt_sku_info.v_cust_pref_vendor;
         ln_items_per_carrier :=
                              i_miniload_info.vt_sku_info.n_items_per_carrier;
         lv_cmt := i_miniload_info.vt_sku_info.v_cmt;
      ELSIF lv_msg_type = ct_modify_sku
      THEN
         ln_uom := i_miniload_info.vt_sku_info.n_uom;
         lv_prod_id := i_miniload_info.vt_sku_info.v_prod_id;
         lv_cust_pref_vendor :=
                               i_miniload_info.vt_sku_info.v_cust_pref_vendor;
         ln_items_per_carrier :=
                              i_miniload_info.vt_sku_info.n_items_per_carrier;
         lv_cmt := i_miniload_info.vt_sku_info.v_cmt;
      ELSIF lv_msg_type = ct_delete_sku
      THEN
         ln_uom := i_miniload_info.vt_sku_info.n_uom;
         lv_prod_id := i_miniload_info.vt_sku_info.v_prod_id;
         lv_cust_pref_vendor :=
                               i_miniload_info.vt_sku_info.v_cust_pref_vendor;
      ELSIF lv_msg_type = ct_inv_upd_carr
      THEN
         lv_pallet_id := i_miniload_info.vt_carrier_update_info.v_carrier_id;
         ln_uom := i_miniload_info.vt_carrier_update_info.n_uom;
         lv_prod_id := i_miniload_info.vt_carrier_update_info.v_prod_id;
         lv_cust_pref_vendor :=
                    i_miniload_info.vt_carrier_update_info.v_cust_pref_vendor;
         ln_qty_received := i_miniload_info.vt_carrier_update_info.n_qty;
         lv_exp_date := i_miniload_info.vt_carrier_update_info.v_inv_date;
      ELSIF lv_msg_type = ct_start_of_day
      THEN
         lv_cmt := 'Start of Day';
      ELSE
         lv_msg_text := ct_program_code || 'Invalid message type';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      END IF;

      IF (lv_conv_need = 'Y')
      THEN
         ln_qty_received :=
            f_convert_to_splits (ln_uom,
                                 lv_prod_id,
                                 lv_cust_pref_vendor,
                                 ln_qty_received
                                );
      END IF;

      SELECT trans_id_seq.NEXTVAL
        INTO ln_trans_id
        FROM DUAL;

      INSERT INTO MINILOAD_TRANS
                  (trans_id, TRANS_TYPE, prod_id,
                   cust_pref_vendor, UOM, qty,
                   items_per_carrier, pallet_id, ref_pallet_id,
                   dest_loc, trans_date, user_id, cmt
                  )
           VALUES (ln_trans_id, lv_trans_type, lv_prod_id,
                   lv_cust_pref_vendor, ln_uom, ln_qty_received,
                   ln_items_per_carrier, lv_pallet_id, lv_ref_pallet_id,
                   lv_dest_loc, SYSDATE, USER, lv_cmt
                  );

      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' mini-load Transaction created :'
         || i_msg_type
         || ' Trans id :'
         || ln_trans_id
         || ' Trans type : '
         || lv_trans_type
         || ' Prod Id: '
         || lv_prod_id
         || ' CPV: '
         || lv_cust_pref_vendor
         || ' UOM: '
         || ln_uom;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      o_status := ct_success;
   EXCEPTION
      WHEN OTHERS
      THEN
         lv_msg_text :=
               ct_program_code
            || ' Insert into Trans table failed:'
            || ' Transaction type: '
            || lv_trans_type;
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_insert_miniload_trans;

----------------------------------------------------------------------------
-- Function:
--    f_parse_message
--
-- Description:
--       This function parses the messages from the mini-load and returns
--    the individual field values to the calling program.
--
-- Parameters:
--    i_msg       - message to be parsed
--    i_msg_type  - message type
--
-- Return Value:
--      Record of type l_miniload_info holding the parsed message fields
--
-- Exceptions Raised:
--       none
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/01/05          Created as part of the mini-load changes
--      12/14/07
---------------------------------------------------------------------------
   FUNCTION f_parse_message (
      i_msg        IN   MINILOAD_MESSAGE.ml_data%TYPE,
      i_msg_type   IN   MINILOAD_MESSAGE.MESSAGE_TYPE%TYPE,
      i_log_flag   IN   BOOLEAN DEFAULT TRUE
   )
      RETURN t_miniload_info
   IS
      l_miniload_info   t_miniload_info;
      lv_fname          VARCHAR2 (50)                    := 'F_PARSE_MESSAGE';
      lv_msg_text       VARCHAR2 (1500);
      lv_msg_type       MINILOAD_MESSAGE.MESSAGE_TYPE%TYPE   := i_msg_type;
   BEGIN
            
      l_miniload_info.v_data := i_msg;

      --Extract the fields and move the values to the corresponding variables
      --in the record l_miniload_info.vt_exp_receipt_complete_info.
      IF lv_msg_type = ct_exp_rec_comp
      THEN
         l_miniload_info.vt_exp_receipt_complete_info.v_msg_type :=
                                   TRIM (SUBSTR (i_msg, 1, ct_msg_type_size));
         l_miniload_info.vt_exp_receipt_complete_info.v_expected_receipt_id :=
            TRIM (SUBSTR (i_msg, (1 + ct_msg_type_size), ct_receipt_id_size));
         l_miniload_info.vt_exp_receipt_complete_info.v_sku :=
            SUBSTR (i_msg,
                    (1 + ct_msg_type_size + ct_receipt_id_size),
                    ct_sku_size
                   );
         p_split_sku (l_miniload_info.vt_exp_receipt_complete_info.v_sku,
                      l_miniload_info.n_uom,
                      l_miniload_info.v_prod_id,
                      l_miniload_info.v_cust_pref_vendor,
                      i_log_flag
                     );
         l_miniload_info.vt_exp_receipt_complete_info.n_qty_exp :=
            TO_NUMBER (SUBSTR (i_msg,
                               (  1
                                + ct_msg_type_size
                                + ct_receipt_id_size
                                + ct_sku_size
                               ),
                               ct_qty_size
                              )
                      );
         l_miniload_info.vt_exp_receipt_complete_info.n_qty_rcv :=
            TO_NUMBER (SUBSTR (i_msg,
                               (  1
                                + ct_msg_type_size
                                + ct_receipt_id_size
                                + ct_sku_size
                                + ct_qty_size
                               ),
                               ct_qty_size
                              )
                      );
      ELSIF lv_msg_type = ct_inv_adj_inc
      THEN
         l_miniload_info.vt_inv_adj_inc_info.v_msg_type :=
                                   TRIM (SUBSTR (i_msg, 1, ct_msg_type_size));
         l_miniload_info.vt_inv_adj_inc_info.v_label :=
               ct_pre_label
            || TRIM (SUBSTR (i_msg, (1 + ct_msg_type_size), ct_label_size));
         l_miniload_info.vt_inv_adj_inc_info.v_sku :=
            SUBSTR (i_msg,
                    (1 + ct_msg_type_size + ct_label_size),
                    ct_sku_size
                   );
         p_split_sku (l_miniload_info.vt_inv_adj_inc_info.v_sku,
                      l_miniload_info.n_uom,
                      l_miniload_info.v_prod_id,
                      l_miniload_info.v_cust_pref_vendor,
                      i_log_flag
                     );
         l_miniload_info.vt_inv_adj_inc_info.n_quantity :=
            TO_NUMBER (SUBSTR (i_msg,
                               (  1
                                + ct_msg_type_size
                                + ct_label_size
                                + ct_sku_size
                               ),
                               ct_qty_size
                              )
                      );
         l_miniload_info.vt_inv_adj_inc_info.v_inv_date :=
            TO_DATE (SUBSTR (i_msg,
                             (  1
                              + ct_msg_type_size
                              + ct_label_size
                              + ct_sku_size
                              + ct_qty_size
                             ),
                             ct_date_size
                            ),
                     'YYYY-MM-DD'
                    );
         l_miniload_info.vt_inv_adj_inc_info.v_user :=
            TRIM (SUBSTR (i_msg,
                          (  1
                           + ct_msg_type_size
                           + ct_label_size
                           + ct_sku_size
                           + ct_qty_size
                           + ct_date_size
                          ),
                          ct_user_size
                         )
                 );
         l_miniload_info.vt_inv_adj_inc_info.v_reason :=
            RTRIM (SUBSTR (i_msg,
                           (  1
                            + ct_msg_type_size
                            + ct_label_size
                            + ct_sku_size
                            + ct_qty_size
                            + ct_date_size
                            + ct_user_size
                           ),
                           ct_reason_size
                          )
                  );
         l_miniload_info.vt_inv_adj_inc_info.v_expected_receipt_id :=
            TRIM (SUBSTR (i_msg,
                          (  1
                           + ct_msg_type_size
                           + ct_label_size
                           + ct_sku_size
                           + ct_qty_size
                           + ct_date_size
                           + ct_user_size
                           + ct_reason_size
                          ),
                          ct_receipt_id_size
                         )
                 );
      ELSIF lv_msg_type = ct_inv_arr
      THEN
         DBMS_OUTPUT.PUT_LINE (' Step 1     ');
         l_miniload_info.vt_inv_arrival_info.v_msg_type :=
                                   TRIM (SUBSTR (i_msg, 1, ct_msg_type_size));
         l_miniload_info.vt_inv_arrival_info.v_label :=
                 TRIM (SUBSTR (i_msg, (1 + ct_msg_type_size), ct_label_size));
         l_miniload_info.vt_inv_arrival_info.v_actual_loc :=
            TRIM (SUBSTR (i_msg,
                          (1 + ct_msg_type_size + ct_label_size),
                          ct_location_size
                         )
                 );
         l_miniload_info.vt_inv_arrival_info.v_sku :=
            SUBSTR (i_msg,
                    (1 + ct_msg_type_size + ct_label_size + ct_location_size
                    ),
                    ct_sku_size
                   );
         DBMS_OUTPUT.PUT_LINE (' Step 2     ');
         p_split_sku (l_miniload_info.vt_inv_arrival_info.v_sku,
                      l_miniload_info.n_uom,
                      l_miniload_info.v_prod_id,
                      l_miniload_info.v_cust_pref_vendor,
                      i_log_flag
                     );
         DBMS_OUTPUT.PUT_LINE (' Step 3     ');
         l_miniload_info.vt_inv_arrival_info.n_quantity :=
            TO_NUMBER (SUBSTR (i_msg,
                               (  1
                                + ct_msg_type_size
                                + ct_label_size
                                + ct_location_size
                                + ct_sku_size
                               ),
                               ct_qty_size
                              )
                      );
         l_miniload_info.vt_inv_arrival_info.v_inv_date :=
            TO_DATE (SUBSTR (i_msg,
                             (  1
                              + ct_msg_type_size
                              + ct_label_size
                              + ct_location_size
                              + ct_sku_size
                              + ct_qty_size
                             ),
                             ct_date_size
                            ),
                     'YYYY-MM-DD'
                    );
         l_miniload_info.vt_inv_arrival_info.v_planned_loc :=
            TRIM (SUBSTR (i_msg,
                          (  1
                           + ct_msg_type_size
                           + ct_label_size
                           + ct_location_size
                           + ct_sku_size
                           + ct_qty_size
                           + ct_date_size
                          ),
                          ct_location_size
                         )
                 );
         DBMS_OUTPUT.PUT_LINE (' Step 4     ');
      ELSIF lv_msg_type = ct_inv_adj_dcr
      THEN
         l_miniload_info.vt_inv_adj_dcr_info.v_msg_type :=
                                   TRIM (SUBSTR (i_msg, 1, ct_msg_type_size));
         l_miniload_info.vt_inv_adj_dcr_info.v_label :=
               ct_pre_label
            || TRIM (SUBSTR (i_msg, (1 + ct_msg_type_size), ct_label_size));
         l_miniload_info.vt_inv_adj_dcr_info.v_sku :=
            SUBSTR (i_msg,
                    (1 + ct_msg_type_size + ct_label_size),
                    ct_sku_size
                   );
         p_split_sku (l_miniload_info.vt_inv_adj_dcr_info.v_sku,
                      l_miniload_info.n_uom,
                      l_miniload_info.v_prod_id,
                      l_miniload_info.v_cust_pref_vendor,
                      i_log_flag
                     );
         l_miniload_info.vt_inv_adj_dcr_info.n_quantity :=
            TO_NUMBER (SUBSTR (i_msg,
                               (  1
                                + ct_msg_type_size
                                + ct_label_size
                                + ct_sku_size
                               ),
                               ct_qty_size
                              )
                      );
         l_miniload_info.vt_inv_adj_dcr_info.v_inv_date :=
            TO_DATE (SUBSTR (i_msg,
                             (  1
                              + ct_msg_type_size
                              + ct_label_size
                              + ct_sku_size
                              + ct_qty_size
                             ),
                             ct_date_size
                            ),
                     'YYYY-MM-DD'
                    );
         l_miniload_info.vt_inv_adj_dcr_info.v_user :=
            TRIM (SUBSTR (i_msg,
                          (  1
                           + ct_msg_type_size
                           + ct_label_size
                           + ct_sku_size
                           + ct_qty_size
                           + ct_date_size
                          ),
                          ct_user_size
                         )
                 );
         l_miniload_info.vt_inv_adj_dcr_info.v_reason :=
            RTRIM (SUBSTR (i_msg,
                           (  1
                            + ct_msg_type_size
                            + ct_label_size
                            + ct_sku_size
                            + ct_qty_size
                            + ct_date_size
                            + ct_user_size
                           ),
                           ct_reason_size
                          )
                  );
      ELSIF lv_msg_type = ct_inv_plan_mov
      THEN
         l_miniload_info.vt_inv_planned_mov_info.v_msg_type :=
                                   TRIM (SUBSTR (i_msg, 1, ct_msg_type_size));
         l_miniload_info.vt_inv_planned_mov_info.v_label :=
               ct_pre_label
            || TRIM (SUBSTR (i_msg, (1 + ct_msg_type_size), ct_label_size));
         l_miniload_info.vt_inv_planned_mov_info.v_src_loc :=
            TRIM (SUBSTR (i_msg,
                          (1 + ct_msg_type_size + ct_label_size),
                          ct_location_size
                         )
                 );
         l_miniload_info.vt_inv_planned_mov_info.v_sku :=
            SUBSTR (i_msg,
                    (1 + ct_msg_type_size + ct_label_size + ct_location_size
                    ),
                    ct_sku_size
                   );
         p_split_sku (l_miniload_info.vt_inv_planned_mov_info.v_sku,
                      l_miniload_info.n_uom,
                      l_miniload_info.v_prod_id,
                      l_miniload_info.v_cust_pref_vendor,
                      i_log_flag
                     );
         l_miniload_info.vt_inv_planned_mov_info.n_quantity :=
            TO_NUMBER (SUBSTR (i_msg,
                               (  1
                                + ct_msg_type_size
                                + ct_label_size
                                + ct_location_size
                                + ct_sku_size
                               ),
                               ct_qty_size
                              )
                      );
         l_miniload_info.vt_inv_planned_mov_info.v_inv_date :=
            TO_DATE (SUBSTR (i_msg,
                             (  1
                              + ct_msg_type_size
                              + ct_label_size
                              + ct_location_size
                              + ct_sku_size
                              + ct_qty_size
                             ),
                             ct_date_size
                            ),
                     'YYYY-MM-DD'
                    );
         l_miniload_info.vt_inv_planned_mov_info.v_planned_loc :=
            TRIM (SUBSTR (i_msg,
                          (  1
                           + ct_msg_type_size
                           + ct_label_size
                           + ct_location_size
                           + ct_sku_size
                           + ct_qty_size
                           + ct_date_size
                          ),
                          ct_location_size
                         )
                 );
         l_miniload_info.vt_inv_planned_mov_info.v_order_priority :=
            TO_NUMBER (LTRIM (SUBSTR (i_msg,
                                      (  1
                                       + ct_msg_type_size
                                       + ct_label_size
                                       + ct_location_size
                                       + ct_sku_size
                                       + ct_qty_size
                                       + ct_date_size
                                       + ct_location_size
                                      ),
                                      ct_priority_size
                                     ),
                              0
                             )
                      );
      ELSIF lv_msg_type = ct_inv_lost
      THEN
         l_miniload_info.vt_inv_lost_info.v_msg_type :=
                                   TRIM (SUBSTR (i_msg, 1, ct_msg_type_size));
         l_miniload_info.vt_inv_lost_info.v_label :=
               ct_pre_label
            || TRIM (SUBSTR (i_msg, (1 + ct_msg_type_size), ct_label_size));
         l_miniload_info.vt_inv_lost_info.v_sku :=
            SUBSTR (i_msg,
                    (1 + ct_msg_type_size + ct_label_size),
                    ct_sku_size
                   );
         p_split_sku (l_miniload_info.vt_inv_lost_info.v_sku,
                      l_miniload_info.n_uom,
                      l_miniload_info.v_prod_id,
                      l_miniload_info.v_cust_pref_vendor,
                      i_log_flag
                     );
         l_miniload_info.vt_inv_lost_info.n_quantity :=
            TO_NUMBER (SUBSTR (i_msg,
                               (  1
                                + ct_msg_type_size
                                + ct_label_size
                                + ct_sku_size
                               ),
                               ct_qty_size
                              )
                      );
         l_miniload_info.vt_inv_lost_info.v_inv_date :=
            TO_DATE (SUBSTR (i_msg,
                             (  1
                              + ct_msg_type_size
                              + ct_label_size
                              + ct_sku_size
                              + ct_qty_size
                             ),
                             ct_date_size
                            ),
                     'YYYY-MM-DD'
                    );
         l_miniload_info.vt_inv_lost_info.v_user :=
            TRIM (SUBSTR (i_msg,
                          (  1
                           + ct_msg_type_size
                           + ct_label_size
                           + ct_sku_size
                           + ct_qty_size
                           + ct_date_size
                          ),
                          ct_user_size
                         )
                 );
         l_miniload_info.vt_inv_lost_info.v_reason :=
            TRIM (SUBSTR (i_msg,
                          (  1
                           + ct_msg_type_size
                           + ct_label_size
                           + ct_sku_size
                           + ct_qty_size
                           + ct_date_size
                           + ct_user_size
                          ),
                          ct_reason_size
                         )
                 );
      ELSIF lv_msg_type = ct_ship_ord_status
      THEN
         l_miniload_info.vt_item_status_info.v_msg_type :=
                                   TRIM (SUBSTR (i_msg, 1, ct_msg_type_size));
         l_miniload_info.vt_item_status_info.v_order_id :=
              TRIM (SUBSTR (i_msg, (1 + ct_msg_type_size), ct_order_id_size));
         l_miniload_info.vt_item_status_info.v_order_item_id :=
            TRIM (SUBSTR (i_msg,
                          (1 + ct_msg_type_size + ct_order_id_size),
                          ct_order_item_id_size
                         )
                 );
         l_miniload_info.vt_item_status_info.v_sku :=
            SUBSTR (i_msg,
                    (  1
                     + ct_msg_type_size
                     + ct_order_id_size
                     + ct_order_item_id_size
                    ),
                    ct_sku_size
                   );
         p_split_sku (l_miniload_info.vt_item_status_info.v_sku,
                      l_miniload_info.vt_item_status_info.n_uom,
                      l_miniload_info.vt_item_status_info.v_prod_id,
                      l_miniload_info.vt_item_status_info.v_cust_pref_vendor,
                      i_log_flag
                     );
         l_miniload_info.vt_item_status_info.n_quantity_requested :=
            TO_NUMBER (SUBSTR (i_msg,
                               (  1
                                + ct_msg_type_size
                                + ct_order_id_size
                                + ct_order_item_id_size
                                + ct_sku_size
                               ),
                               ct_qty_size
                              )
                      );
         l_miniload_info.vt_item_status_info.n_quantity_available :=
            TO_NUMBER (SUBSTR (i_msg,
                               (  1
                                + ct_msg_type_size
                                + ct_order_id_size
                                + ct_order_item_id_size
                                + ct_sku_size
                                + ct_qty_size
                               ),
                               ct_qty_size
                              )
                      );
      -- ctvgg for HK Integration
      -- Modified functionality to process 'messageStatus'
      ELSIF lv_msg_type = ct_message_status
      THEN
        l_miniload_info.vt_msg_status_info.v_msg_type :=
                                   TRIM (SUBSTR (i_msg, 1, ct_msg_type_size));                                                     
        l_miniload_info.vt_msg_status_info.v_msg_id :=
            TRIM (SUBSTR (i_msg, (1 + ct_msg_type_size), ct_msg_id_size));
            
         l_miniload_info.vt_msg_status_info.v_msg_status :=
            SUBSTR (i_msg,
                    (1 + ct_msg_type_size + ct_msg_id_size),
                    ct_message_status_size
                   );         
         
         l_miniload_info.vt_msg_status_info.v_msg_status_text :=
             TRIM (SUBSTR (i_msg,
                               (1
                                + ct_msg_type_size
                                + ct_msg_id_size
                                + ct_message_status_size
                               ),
                               ct_message_text_size
                              )
                      );                       
                             
      ELSE
         DBMS_OUTPUT.PUT_LINE (' Step 999     ');
         lv_msg_text :=
                  'Prog Code: ' || ct_program_code || ' Invalid Message Type';

         IF (i_log_flag = TRUE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         ELSIF (i_log_flag = FALSE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         END IF;
      END IF;

      RETURN l_miniload_info;
   EXCEPTION
      WHEN OTHERS
      THEN
         lv_msg_text :=
                 'Prog Code: ' || ct_program_code || ' Parsing of msg failed';

         IF (i_log_flag = TRUE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         ELSIF (i_log_flag = FALSE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         END IF;

         RAISE;
   END f_parse_message;

-------------------------------------------------------------------------
-- Procedure:
--    p_upd_status
--
-- Description:
--     This procedure updates the status of a received message
--
--     ***** READ THIS *****
--     Do not call any object from this procedure that performs an
--     autonomous transaction such as pl_log.  This is due to this
--     procedure being called from pl_miniload_interface which accesses
--     tables by a database link.
--
-- Parameters:
--    i_msg_id - Message ID
--    i_msg_type -The type of message
--
--    o_status - status
--       0  - No errors.
--       1  - Error occured.
--
-- Called by:
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/21/05          Created as part of the mini-load changes
---------------------------------------------------------------------------
   PROCEDURE p_upd_status (
      i_msg_id       IN       MINILOAD_MESSAGE.message_id%TYPE,
      i_msg_type     IN       MINILOAD_MESSAGE.MESSAGE_TYPE%TYPE,
      i_msg_status   IN       MINILOAD_MESSAGE.status%TYPE,
      o_status       OUT      NUMBER,
      i_log_flag     IN       BOOLEAN DEFAULT TRUE
   )
   IS
      -- This will cause remote access error PRAGMA AUTONOMOUS_TRANSACTION;
      lv_msg_text   VARCHAR2 (1500);
      lv_fname      VARCHAR2 (50)   := 'P_UPD_STATUS';
      e_fail        EXCEPTION;
   BEGIN
     
     --
      -- IF 'F' is the status, we must ROLLBACK before writing and
      -- committing status change
      --
      IF (i_msg_status = 'F')
      THEN
         ROLLBACK;
      END IF;

      IF (i_msg_type IN
             (ct_inv_adj_inc,
              ct_inv_adj_dcr,
              ct_inv_arr,
              ct_exp_rec,
              ct_exp_rec_comp,
              ct_inv_plan_mov,
              ct_inv_lost,
              ct_inv_upd_carr,
              ct_pick_comp_carr,
              ct_new_sku,
              ct_modify_sku,
              ct_delete_sku,
              ct_start_of_day,
              ct_carrier_status,
              ct_message_status
             )
         )
      THEN
         UPDATE MINILOAD_MESSAGE
            SET status = i_msg_status
          WHERE message_id = i_msg_id;

         IF (SQL%ROWCOUNT = 0)
         THEN
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Update to Miniload_Message failed'
               || i_msg_type
               || ' Msg id:'
               || i_msg_id;
            RAISE e_fail;
         END IF;
      ELSIF (i_msg_type IN
                (ct_ship_ord_status,
                 ct_ship_ord_hdr,
                 ct_ship_ord_inv,
                 ct_ship_ord_trl,
                 ct_ship_ord_prio
                )
            )
      THEN
         UPDATE MINILOAD_ORDER
            SET status = i_msg_status
          WHERE message_id = i_msg_id;

         IF (SQL%ROWCOUNT = 0)
         THEN
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Update to miniload_order failed'
               || i_msg_type
               || ' Msg id:'
               || i_msg_id;
            RAISE e_fail;
         END IF;
      ELSE
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Invalid Message Type '
            || i_msg_type
            || ' Msg id:'
            || i_msg_id;
         RAISE e_fail;
      END IF;

      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Message Status Updated: '
         || i_msg_type
         || ' Msg id:'
         || i_msg_id
         || ' New Status: '
         || i_msg_status;

      IF (i_log_flag = TRUE)
      THEN
         Pl_Text_Log.ins_msg ('DEBUG', lv_fname, lv_msg_text, NULL, NULL);
      ELSIF (i_log_flag = FALSE)
      THEN
         Pl_Text_Log.ins_msg ('DEBUG', lv_fname, lv_msg_text, NULL, NULL);
      END IF;

      o_status := ct_success;

      IF (i_msg_status = 'F')
      THEN
         COMMIT;
      END IF;
   EXCEPTION
      WHEN e_fail
      THEN
         IF (i_log_flag = TRUE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         ELSIF (i_log_flag = FALSE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         END IF;

         o_status := ct_failure;
      -- ROLLBACK;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in updating status in miniload_message/miniload_order';

         IF (i_log_flag = TRUE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
         ELSIF (i_log_flag = FALSE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
         END IF;

         o_status := ct_failure;
   -- ROLLBACK;
   END p_upd_status;

-------------------------------------------------------------------------
-- Function:
--    f_convert_to_splits
--
-- Description:
--    if UOM = 2,this function changes quantity to splits measure.
--
-- Parameters:
--    i_uom  - unit of measure
--    i_quantity - quantity expected
--    i_prod_id - product id
--    i_cust_pref_vendor - customer preferred vendor
--
-- Returns
--    Converted quantity in splits
--
-- Exceptions Raised:
--    None.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/01/05          Created as part of the mini-load changes
---------------------------------------------------------------------------
   FUNCTION f_convert_to_splits (
      i_uom                IN   PUTAWAYLST.UOM%TYPE,
      i_prod_id            IN   PUTAWAYLST.prod_id%TYPE,
      i_cust_pref_vendor   IN   PUTAWAYLST.cust_pref_vendor%TYPE,
      i_quantity           IN   PUTAWAYLST.qty_expected%TYPE,
      i_log_flag           IN   BOOLEAN DEFAULT TRUE
   )
      RETURN NUMBER
   IS
      ln_spc        PM.spc%TYPE;
      -- local variable to store the no of splits per case
      lv_msg_text   VARCHAR2 (1500);
      lv_fname      VARCHAR2 (50)   := 'F_CONVERT_TO_SPLITS';
   BEGIN
      IF (i_uom = 2
         )  -- only uom=2 is checked as all uom 0 have been converted to uom 2
      THEN
         --Get the spc for the given product id
         SELECT spc
           INTO ln_spc
           FROM PM
          WHERE prod_id = i_prod_id AND cust_pref_vendor = i_cust_pref_vendor;

         RETURN i_quantity * ln_spc;
      ELSE
         RETURN i_quantity;
      END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message=Query to find spc failed'
            || ' Table=pm Key:[prod_id,cpv]=['
            || i_prod_id
            || ','
            || i_cust_pref_vendor
            || ']';

         IF (i_log_flag = TRUE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
         ELSIF (i_log_flag = FALSE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
         END IF;

         RAISE;
      WHEN OTHERS
      THEN
         lv_msg_text :=
            'Prog Code: ' || ct_program_code
            || ' Error in f_convert_to_splits';

         IF (i_log_flag = TRUE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
         ELSIF (i_log_flag = FALSE)
         THEN
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
         END IF;

         RAISE;
   END f_convert_to_splits;

-------------------------------------------------------------------------------
-- Procedure:
--    p_rcv_item_status
--
-- Description:
--    This procedure will process the shipping order item status message sent
--    from the miniloader and calls procedure p_process_ml_replen based
--    on the inventory short.
--
--    If the miniloader does not have sufficient qty to cover the order qty
--    then the processing will be:
--    - If cases ordered:
--         SWMS will attempt to create a create a case
--         replenishment from the main warehouse to the miniloader.
--    - If splits ordered:
--         SWMS will attempt to create a create a case to split
--         replenishment from the miniloader to the miniloader.
--         If there are no cases in the miniloader then
--         SWMS will attempt to create a create a case to split
--         replenishment from the main warehouse to the miniloader.
--
-- Parameters:
--      i_msg_id  - message Id from the miniload_message table.
--      i_msg     - The received message from the miniloader.
--      o_status  - Return value
--                     0  - No errors.
--                     1  - Error occured.
--
-- Exceptions Raised:
--    e_fail  - Raised due to insufficient data or general FAILUREs.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -------------------------------------------------------
--    12/15/05          Created as part of the mini-load changes
--    12/05/08 prpbcb   Populate n_spc
--    02/18/10 prpbcb   Added call to function is_repl_in_process_for_order().
-------------------------------------------------------------------------------
   PROCEDURE p_rcv_item_status 
     (i_msg      IN       miniload_message.ml_data%TYPE,
      i_msg_id   IN       miniload_message.message_id%TYPE,
      o_status   OUT      NUMBER)
   IS
      l_miniload_info   t_miniload_info;
      lv_msg_type       VARCHAR2 (50)                  := ct_ship_ord_status;
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)                  := 'P_RCV_ITEM_STATUS';
      lv_msg_status     MINILOAD_MESSAGE.status%TYPE   := 'S';
      e_fail            EXCEPTION;
      ln_status         NUMBER (1)                     := ct_success;
      l_high_prio_qty_avail PLS_INTEGER;
   BEGIN
      l_miniload_info := f_parse_message(i_msg, lv_msg_type);

      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Msg Id: '
         || i_msg_id
         || ' Msg Type: '
         || lv_msg_type
         || ' Prod id: '
         || l_miniload_info.vt_item_status_info.v_prod_id
         || ' CPV: '
         || l_miniload_info.vt_item_status_info.v_cust_pref_vendor
         || ' UOM: '
         || l_miniload_info.vt_item_status_info.n_uom
         || ' Quantity Requested: '
         || l_miniload_info.vt_item_status_info.n_quantity_requested
         || ' Quantity Available: '
         || l_miniload_info.vt_item_status_info.n_quantity_available;

      pl_text_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL);
      pl_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL);

      --
      -- If the miniloader qoh is less than the qty requested and cases
      -- requested then attempt to create a replenishment from the main
      -- warehouse to the miniloader.
      --
      IF (    l_miniload_info.vt_item_status_info.n_quantity_requested >
                      l_miniload_info.vt_item_status_info.n_quantity_available
          AND l_miniload_info.vt_item_status_info.n_uom = 2)
      THEN
         pl_log.ins_msg('INFO', lv_fname, 
               'Cases ordered and the miniloader cases qoh is less than the'
           || ' qty requested.'
           || '  Create a replenishment, if necessary, for cases from the'
           || ' main warehouse to the miniloader if the item has available'
           || ' cases in the main warehouse.'
           || '  Item['
           || l_miniload_info.vt_item_status_info.v_prod_id || ']'
           || '  CPV['
           || l_miniload_info.vt_item_status_info.v_cust_pref_vendor
           || '].'
           || '  Qty requested cases: '
           ||  TO_CHAR(l_miniload_info.vt_item_status_info.n_quantity_requested)
           || '  Qty available cases: '
           ||  TO_CHAR(l_miniload_info.vt_item_status_info.n_quantity_available),
           NULL, NULL, ct_application_function, gl_pkg_name);

         pl_ml_repl.p_create_ml_case_rpl
             (i_call_type=>'SHP',
              i_prod_id=>l_miniload_info.vt_item_status_info.v_prod_id,
              i_cust_pref_vendor=>l_miniload_info.vt_item_status_info.v_cust_pref_vendor,
              i_qty_reqd=>(l_miniload_info.vt_item_status_info.n_quantity_requested -
                 l_miniload_info.vt_item_status_info.n_quantity_available),
              o_status=>o_status);
      END IF;

      --
      -- If split order and case also in ML and qty > spc, we need to
      -- send high priority store order for case qty to cover "ship splits"
      -- cond.
      --
      IF (    l_miniload_info.vt_item_status_info.n_quantity_requested >
                      l_miniload_info.vt_item_status_info.n_quantity_available
          AND l_miniload_info.vt_item_status_info.n_uom = 1)
      THEN
         --
         -- Splits ordered and the miniloader does not have enough splits to
         -- cover the order quantity.  Perform case to split replenishment
         -- processing.
         --

         pl_log.ins_msg('INFO', lv_fname, 
             'Need replenishment from case to split for item '
         || l_miniload_info.vt_item_status_info.v_prod_id
         || ', CPV '
         || l_miniload_info.vt_item_status_info.v_cust_pref_vendor
         || '.  Splits requested: '
         ||  TO_CHAR(l_miniload_info.vt_item_status_info.n_quantity_requested)
         || '  Splits available: '
         ||  TO_CHAR(l_miniload_info.vt_item_status_info.n_quantity_available),
             NULL, NULL, ct_application_function, gl_pkg_name);

         --
         -- 2/17/2011  Brian Bent
         -- If there is a Shipping Order Item status message for the order
         -- with I status then do nothing as the case to split replenishment
         -- processing is already in process.  SUS can send the order down
         -- multiple times.
         --
         IF (is_repl_in_process_for_order(l_miniload_info.vt_item_status_info)
                = TRUE) THEN
            --
            -- The order was sent previously to the miniloader, the miniloader
            -- replied back it did not have enough qty which started the create
            -- replenishment processing.  SWMS is waiting for the miniloader to
            -- drop a carrier to the pick face.  Since the replenishment processing
            -- is already in progress for the order do nothing.
            --
            pl_log.ins_msg
                 ('INFO', lv_fname,
                  'Order< ' || l_miniload_info.vt_item_status_info.v_order_id || '>'
                  || '  Order Item ID< ' || l_miniload_info.vt_item_status_info.v_order_item_id || '>'
                  || '  Item<' || l_miniload_info.vt_item_status_info.v_prod_id || '>'
                  || '  CPV<' || l_miniload_info.vt_item_status_info.v_cust_pref_vendor || '>'
                  || '  The order was sent down previously which started the'
                  || ' create replenishment processing.  SWMS sent a high priority' 
                  || ' store order to the miniloader and is waiting for'
                  || ' the miniloader to drop a carrier to the pick face.'
                  || '  Since the replenishment processing is in progress do'
                  || ' nothing.',
                  NULL, NULL, ct_application_function, gl_pkg_name);
            o_status := ct_success;
         ELSE
            --
            -- Create a case to split replenishment.
            --
            SELECT pm.miniload_storage_ind,
                   pm.spc
              INTO l_miniload_info.vt_item_status_info.c_ml_storage_ind,
                   l_miniload_info.vt_item_status_info.n_spc
              FROM pm
             WHERE prod_id = l_miniload_info.vt_item_status_info.v_prod_id
               AND cust_pref_vendor =
                           l_miniload_info.vt_item_status_info.v_cust_pref_vendor;

            l_miniload_info.vt_item_status_info.n_quantity_requested :=
               f_convert_to_splits
                    (l_miniload_info.vt_item_status_info.n_uom,
                     l_miniload_info.vt_item_status_info.v_prod_id,
                     l_miniload_info.vt_item_status_info.v_cust_pref_vendor,
                     l_miniload_info.vt_item_status_info.n_quantity_requested);

            l_miniload_info.vt_item_status_info.n_quantity_available :=
               f_convert_to_splits
                    (l_miniload_info.vt_item_status_info.n_uom,
                     l_miniload_info.vt_item_status_info.v_prod_id,
                     l_miniload_info.vt_item_status_info.v_cust_pref_vendor,
                     l_miniload_info.vt_item_status_info.n_quantity_available);

            p_process_ml_replen(l_miniload_info.vt_item_status_info, ln_status);
         END IF;
      END IF;

      IF (ln_status = ct_success) THEN
         l_miniload_info.v_status := 'S';
         o_status := ct_success;
      ELSIF (ln_status = ct_in_progress) THEN
         l_miniload_info.v_status := 'I';
         o_status := ct_success;
      ELSE
         l_miniload_info.v_status := 'F';
         o_status := ct_failure;
      END IF;

      p_upd_status(i_msg_id, lv_msg_type, l_miniload_info.v_status, ln_status);
      o_status := ln_status;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' mini-load Storage Ind not found'
            || ' Key=Prod_id:['
            || l_miniload_info.vt_item_status_info.v_prod_id
            || '] CPV:['
            || l_miniload_info.vt_item_status_info.v_cust_pref_vendor
            || ']';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
      WHEN OTHERS THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in p_rcv_item_status'
            || ' Msg Id: '
            || i_msg_id;

         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_rcv_item_status;

-------------------------------------------------------------------------
-- Procedure:
--    p_histord_process
--
-- Description:
--     This procedure will read the historical order data for the day
--     and generate the replenishment tasks if required.
--
-- Exceptions Raised:
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/15/05          Created as part of the mini-load changes
---------------------------------------------------------------------------
   PROCEDURE p_histord_process
   IS
      l_item_status   t_item_status_info;
      ln_status       NUMBER (1)                               := ct_success;
      --Hold return status of functions
      ln_qoh_sum      MINILOAD_ORDER.quantity_requested%TYPE   DEFAULT NULL;
      lv_msg_text     VARCHAR2 (1500);
      lv_fname        VARCHAR2 (50)                    := 'P_HISTORD_PROCESS';

      CURSOR c_hist_orders
      IS
         SELECT message_id, order_id, order_priority, order_item_id, prod_id,
                UOM, cust_pref_vendor, quantity_requested
           FROM MINILOAD_ORDER
          WHERE MESSAGE_TYPE = ct_ship_ord_inv
            AND status = 'S'
            AND source_system IN ('SWM', 'SUS')
            AND order_id IN (
                   SELECT DISTINCT order_id
                              FROM MINILOAD_ORDER
                             WHERE MESSAGE_TYPE = ct_ship_ord_hdr
                               AND ORDER_TYPE = ct_history_order
                               AND TRUNC (order_date) = TRUNC (SYSDATE)
                               AND source_system IN ('SWM', 'SUS'));
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_histord_process');

      FOR v_rec IN c_hist_orders
      LOOP
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message=Query to select qoh failed.'
            || ' Key:[prod_id,cpv,uom,status]='
            || ' ['
            || v_rec.prod_id
            || ','
            || v_rec.cust_pref_vendor
            || ','
            || v_rec.UOM
            || ',AVL] Table=[inv,loc]';

         SELECT NVL (SUM (qoh - NVL (qty_alloc, 0)), 0)
           INTO l_item_status.n_quantity_available
           FROM INV i, LZONE lz, ZONE z
          WHERE i.prod_id = v_rec.prod_id
            AND i.cust_pref_vendor = v_rec.cust_pref_vendor
            AND i.inv_uom = v_rec.UOM
            AND i.status = 'AVL'
            AND i.plogi_loc = lz.logi_loc
            AND lz.zone_id = z.zone_id
            AND z.rule_id = 3
            AND z.ZONE_TYPE = 'PUT';

         l_item_status.n_quantity_requested :=
            f_convert_to_splits (v_rec.UOM,
                                 v_rec.prod_id,
                                 v_rec.cust_pref_vendor,
                                 v_rec.quantity_requested
                                );

         -- check if the quantity is sufficient for
         IF (l_item_status.n_quantity_requested <=
                                            l_item_status.n_quantity_available
            )
         THEN
            --Log the message as qty sufficient
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Quantity Sufficient For History Order Processing';
            Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
         ELSE
            l_item_status.v_msg_type := ct_ship_ord_inv;
            l_item_status.v_order_id := v_rec.order_id;
            l_item_status.v_order_item_id := v_rec.order_item_id;
            l_item_status.v_prod_id := v_rec.prod_id;
            l_item_status.v_cust_pref_vendor := v_rec.cust_pref_vendor;
            l_item_status.n_uom := v_rec.UOM;
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Message=Query to find miniload_storage_ind failed'
               || ' Table=pm Key:[prod_id,cpv]=['
               || v_rec.prod_id
               || ','
               || v_rec.cust_pref_vendor
               || ']';

            SELECT miniload_storage_ind
              INTO l_item_status.c_ml_storage_ind
              FROM PM
             WHERE prod_id = v_rec.prod_id
               AND cust_pref_vendor = v_rec.cust_pref_vendor;

            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Quantity Insufficient For History Order'
               || ' Processing, calling for replenishment p_process_ml_replen';

            pl_text_log.ins_msg('WARNING', lv_fname, lv_msg_text, NULL, NULL);
            p_process_ml_replen(l_item_status, ln_status);

            IF (ln_status = ct_success) THEN
               COMMIT;
            ELSIF (ln_status = ct_in_progress) THEN
               -- Inserting a dummy ship order item status message
               -- for history order processing.
               p_insert_dummy_itm_status (l_item_status, ln_status);

               IF (ln_status = ct_success) THEN
                  COMMIT;
               ELSE
                  ROLLBACK;
               END IF;
            ELSE
               ROLLBACK;
            END IF;
         END IF;
      END LOOP;

      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' History Order Processing Complete';
--   pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         ROLLBACK;
         pl_text_log.ins_msg('FATAL',
                             lv_fname,
                             lv_msg_text,
                             SQLCODE,
                             SQLERRM);
      WHEN OTHERS THEN
         ROLLBACK;
         lv_msg_text :=
                    'Prog Code: ' || ct_program_code || ' Error in insertion';
         pl_text_log.ins_msg('FATAL',
                             lv_fname,
                             lv_msg_text,
                             SQLCODE,
                             SQLERRM);
   END p_histord_process;


-------------------------------------------------------------------------------
-- Procedure:
--    p_process_ml_replen
--
-- Description:
--    This procedure will be called to process the miniloader replenishments.
--
-- Parameters:
--    i_item_status_info - Record type t_item_status_info
--    o_status           - Return value
--                            0  - No errors.
--                            1  - Error occured.
--                            3  - In Progress.
--
-- Exceptions Raised:
--    None.  If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -------------------------------------------------------
--    12/15/05          Created as part of the mini-load changes
--    12/04/08 prpbcb   Changed cursor c_other_pick_loc to to select
--                      (qoh - qty alloc) for the available qty instead of qoh.
--    03/23/10 prpbcb   Added the following to cursor c_other_pick_loc:
--                         AND i.qoh - i.qty_alloc > 0
--                       since the LP could have an existing replenishment
--                       for some of the qty on the LP.
--
--                       Added
--                         AND logi_loc = l_ml_replenishment.v_orig_pallet_id
--                       when updating INV and selectint INV record.
--
--    08/21/17 pkab6563  Added a check to ensure that there is a case available
--                       in reserve before creating high priority store orders.
-------------------------------------------------------------------------------
   PROCEDURE p_process_ml_replen
              (i_item_status_info   IN     t_item_status_info DEFAULT NULL,
               o_status             OUT    NUMBER)
   IS
      lv_fname                  VARCHAR2 (50)        := 'P_PROCESS_ML_REPLEN';

      l_ml_replenishment        t_ml_replenishment;
      ln_spc                    pm.spc%TYPE;

      -- Qty available (in splits) on carriers with cases.
    ln_qty_available    inv.qoh%TYPE    := 0;
    ln_mwhse_qty_avl    inv.qoh%TYPE    := 0;

      --
      -- Number of splits that need to be replenished to cover the
      -- splits ordered.  It will be rounded up to a full case if
      -- necessary as only case quantities are replenished. 
      --
      ln_replen_qty             replenlst.qty%TYPE;

      ln_replen_qty_for_msg     replenlst.qty%TYPE;  -- Original qty to use
                                                     -- in log message.

      lv_zone_id                zone.zone_id%TYPE;
      ln_rule_id                zone.rule_id%TYPE;
      lv_logi_loc               loc.logi_loc%TYPE;
      ln_inv_uom                inv.inv_uom%TYPE;
      ln_pallet_seq             PLS_INTEGER;
      l_inv_info                inv%ROWTYPE              DEFAULT NULL;
      lv_msg_text               VARCHAR2(1500);
      ln_status                 NUMBER;
      ln_case_qty_per_carrier   PLS_INTEGER;
      ln_high_prio_qty_avail    PLS_INTEGER;
      ln_reserve_qty_avl        inv.qoh%TYPE;
      ln_qty_short              inv.qoh%TYPE;
      ln_total_high_prio_qty    inv.qoh%TYPE;
      l_hi_prio_order_found     BOOLEAN;

      --
      -- pm.case_qty_for_split_rpl converted to splits.
      --
      case_qty_for_split_rpl_in_splt      PLS_INTEGER;

      e_indloc_notfound         EXCEPTION;

      CURSOR c_floating_loc (p_prod_id VARCHAR2, p_cpv VARCHAR2) IS
         SELECT i.plogi_loc,
                (TRUNC (qoh / p.spc) - TRUNC (NVL (qty_alloc, 0) / spc))
                    * p.spc qoh,
                i.qty_alloc,
                i.rec_id,
                i.lot_id,
                NVL(i.exp_date, SYSDATE) exp_date,
                i.exp_ind,
                i.inv_date,
                NVL(i.rec_date, SYSDATE) rec_date,
                NVL(i.mfg_date, SYSDATE) mfg_date,
                i.logi_loc,
                p.min_qty,
                l.uom,
                l.pik_path,
                i.parent_pallet_id,
                p.case_qty_per_carrier,
                --
                -- Select case_qty_for_split_rpl converting it into a split qty
                --
                NVL(p.case_qty_for_split_rpl, 1)
                   * p.spc   case_qty_for_split_rpl_in_splt
           FROM loc l,
                pm p,
                inv i,
                lzone lz,
                zone z
          WHERE i.prod_id           = p_prod_id
            AND i.cust_pref_vendor  = p_cpv
            AND i.status            = 'AVL'
            AND i.inv_uom           IN (0, 2)
            AND l.logi_loc          = lz.logi_loc
            AND lz.logi_loc         = i.plogi_loc
            AND p.prod_id           = i.prod_id
            AND p.cust_pref_vendor  = i.cust_pref_vendor
            AND lz.zone_id          = z.zone_id
            AND z.ZONE_TYPE         = 'PUT'
            AND z.rule_id           = 1
            --
            -- A case qty needs to be avaiable.
            AND (TRUNC(qoh / p.spc) - TRUNC(NVL(qty_alloc, 0) / spc))
                   > 0           -- 2/17/2011 Brian Bent Changed from 
                                 -- "* p.spc > 0"  to  "> 0"
                                 -- No need to multiply by spc.
          ORDER BY NVL(i.exp_date, SYSDATE), i.qoh, i.logi_loc
            FOR UPDATE OF qoh;

      --
      -- This cursor looks for case carriers for the item in a pick face slot.
      -- If we need to get splits in the miniloader then case to split
      -- replenishments are created first from case carriers in a pick
      -- face slot.
      --
      -- 12/14/08 Brian Bent Changed to select qoh - qty alloc
      --          for the available qty instead of qoh.
      -- 02/17/11 Brian Bent  Add the LOC table to the where clause and get the
      --          pick level from LOC and not use substr(plogi_loc, 6, 1)
      --
      CURSOR c_other_pick_loc IS
         SELECT i.plogi_loc,
                i.logi_loc,
                i.exp_date,
                i.qoh - i.qty_alloc,
                i.inv_uom,
                p.case_qty_per_carrier,
                --
                -- Select case_qty_for_split_rpl converting it into a split qty
                --
                NVL(p.case_qty_for_split_rpl, 1) * p.spc
                                              case_qty_for_split_rpl_in_splt
           FROM inv i,
                pm p,
                zone z,
                loc l
          WHERE i.inv_uom          IN (0, 2)   -- Want cases
            AND i.prod_id          = i_item_status_info.v_prod_id
            AND i.cust_pref_vendor = i_item_status_info.v_cust_pref_vendor
            AND i.prod_id          = p.prod_id
            AND i.cust_pref_vendor = p.cust_pref_vendor
            AND i.status           = 'AVL'
            AND l.logi_loc         = i.plogi_loc
            AND p.zone_id          = z.zone_id
            AND z.rule_id          = 3       -- 3 designates the miniloader
            AND l.pik_level        <= z.max_pick_level
            AND i.qoh              > 0 --5/16/06 cannot RPL from 000 to 000
            AND i.qoh - i.qty_alloc > 0   -- 3/23/2010  Brian Bent  Added
          ORDER BY NVL(i.exp_date, SYSDATE), i.qoh;

      --
      -- Patrice Kabran 8/21/17: This cursor looks for high priority 
      -- orders for the item.
      -- its purpose is to find the high priority order matching
      -- an 'I' shipping order item status record for the item.
      -- it will be used in combination with the cursor below it.
      -- the high priority qty requested will be decremented from
      -- the quantity available in reserve when trying to create
      -- new high priority orders. the goal is to avoid creating
      -- new high priority orders if there are no cases available
      -- in reserve or if the cases in reserve are already taken up
      -- by existing high priority orders that are still pending.
      --
      CURSOR c_high_prio_order_for_item (i_order_item_id miniload_order.order_item_id%TYPE, 
                                         i_message_id miniload_order.message_id%TYPE) IS
         SELECT  mo.order_id, 
                 NVL(mo.quantity_requested, 0) quantity_requested,
                 mo.order_item_id
         FROM miniload_order mo
         WHERE  mo.message_type     = ct_ship_ord_inv
            AND mo.prod_id          = i_item_status_info.v_prod_id
            AND mo.cust_pref_vendor = i_item_status_info.v_cust_pref_vendor
            AND mo.order_item_id    = i_order_item_id
            AND mo.message_id       > i_message_id
            AND mo.uom              = 2
            AND mo.sku_priority     = 0
            AND mo.status           <> 'F'
            AND mo.add_date >=   -- Check from the start of day.  If no start of
                              -- day then use 3 AM.
             (SELECT NVL(MAX(add_date), TRUNC (SYSDATE) + 3 / 24)
              FROM miniload_message m
              WHERE m.message_type = ct_start_of_day)
            AND EXISTS (SELECT mo2.order_id
                     FROM miniload_order mo2
                     WHERE mo2.message_type = ct_ship_ord_hdr
                        AND mo2.status <> 'F'
                        AND mo2.order_id = mo.order_id
                        AND mo2.order_priority =
                               (SELECT priority_value
                                FROM priority_code
                                WHERE priority_code = 'HGH'
                                AND unpack_code = 'Y'));

      --
      -- Patrice Kabran 8/21/17: This cursor looks for 'I' status shipping order item status records
      -- for the item. it will be used with the above cursor.
      --
      CURSOR c_I_status_order_for_item IS
      SELECT mo.order_id,
             NVL(mo.quantity_requested, 0) quantity_requested,
             NVL(mo.quantity_available, 0) quantity_available,
             mo.order_item_id,
             mo.message_id
      FROM miniload_order mo
      WHERE  mo.message_type     = ct_ship_ord_status
         AND mo.prod_id          = i_item_status_info.v_prod_id
         AND mo.cust_pref_vendor = i_item_status_info.v_cust_pref_vendor
         AND mo.uom              = 1
         AND mo.status           = 'I'
         AND NVL(mo.quantity_requested, 0) > NVL(mo.quantity_available, 0)
         AND mo.add_date >=   -- Check from the start of day. If no start of
                              -- day then use 3 AM.
             (SELECT NVL(MAX(add_date), TRUNC(SYSDATE) + 3 / 24)
              FROM miniload_message m
              WHERE m.message_type = ct_start_of_day);
      --
      --

      float_loc_rec             c_floating_loc%ROWTYPE   DEFAULT NULL;
      qty_to_be_replenished     inv.qty_alloc%TYPE;
      l_norows                  BOOLEAN                  := FALSE;
   BEGIN
      pl_text_log.init ('pl_miniload_processing.p_process_ml_replen');
      o_status := ct_success;
      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Replenishing For Prod_id:'
         || i_item_status_info.v_prod_id
         || ' CPV:'
         || i_item_status_info.v_cust_pref_vendor
         || ' UOM:'
         || i_item_status_info.n_uom
         || ' mini-load Storage Ind:'
         || i_item_status_info.c_ml_storage_ind;

      pl_text_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL);
      pl_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL,
                     ct_application_function, gl_pkg_name);

      --
      -- If neither splits nor cases are stored in the miniloader, then exit
      -- out of the function.
      --
      IF (i_item_status_info.c_ml_storage_ind = 'N') THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' miniload storage indicator is N so it is not a miniload item.'
            || '  Prod_id<'
            || i_item_status_info.v_prod_id || '>'
            || '  CPV<'
            || i_item_status_info.v_cust_pref_vendor || '>'
            || '  UOM<'
            || TO_CHAR(i_item_status_info.n_uom) || '>';

         pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_success;
      ELSIF (i_item_status_info.c_ml_storage_ind = 'B') THEN
         --
         -- Both splits and cases are stored in the miniloader.
         --
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Query to select total qoh when storage ind is "B"';

         --
         -- Both splits and cases are stored in the miniloader.
         -- See if there is an existing replenishment that will cover
         -- the qty ordered.
         --
         IF (f_is_repl_necessary_for_order
                         (i_item_status_info.v_prod_id,
                          i_item_status_info.v_cust_pref_vendor) = FALSE) THEN
            --
            -- An existing replenishment will cover the qty ordered.
            --
            pl_log.ins_msg
                     ('INFO',
                      lv_fname,
                         'Case to split replenishment not necessary for'
                      || ' item ' || i_item_status_info.v_prod_id
                      || ', CPV ' || i_item_status_info.v_cust_pref_vendor
                      || ' because an existing replenishment will cover the'
                      || ' qty ordered.',
                      NULL, NULL, ct_application_function, gl_pkg_name);
            o_status := ct_success;
            RETURN; -- 03/36/07 Brian Bent Not the best programming practice to
                    -- return from a procedure in the middle.
         END IF;

         SELECT NVL(SUM(DECODE (z.rule_id, 3, i.qoh - NVL(i.qty_alloc, 0), 0)), 0),
                NVL(SUM(DECODE (z.rule_id, 3, 0, i.qoh - NVL(i.qty_alloc, 0))), 0)
           INTO ln_qty_available,
                ln_mwhse_qty_avl
           FROM zone z, lzone l, inv i
          WHERE i.prod_id          = i_item_status_info.v_prod_id
            AND i.cust_pref_vendor = i_item_status_info.v_cust_pref_vendor
            AND i.inv_uom          IN (0, 2)
            AND i.status           = 'AVL'
            AND l.logi_loc         = i.plogi_loc
            AND z.zone_id          = l.zone_id
            AND z.zone_type        = 'PUT';

         lv_msg_text := 'Prog Code: '
                        || ct_program_code
                        || ' Total qty available(in splits) for all "AVL" INV'
                        || ' records with inv_uom = 0 or 2: '
                        || ln_qty_available
                        || '  Prod_id: '
                        || i_item_status_info.v_prod_id
                        || '  CPV: '
                        || i_item_status_info.v_cust_pref_vendor
                        || '  UOM:'
                        || i_item_status_info.n_uom;

         pl_text_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL);
         pl_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL);

         -- Note the quantities are in splits.
         ln_replen_qty := i_item_status_info.n_quantity_requested
                          - i_item_status_info.n_quantity_available;

         -- See if there is a pending high priority order that can 
         -- cover the qty needed.
         IF (f_is_repl_in_process_for_item(i_item_status_info.v_prod_id,
                                           i_item_status_info.v_cust_pref_vendor,
                                           ln_high_prio_qty_avail)) THEN
            o_status := ct_success;
            RETURN;
         END IF;

         --
         -- Save the original number of splits that need to be replenished to
         -- cover the splits ordered.  It will be used in a log message.
         --
         ln_replen_qty_for_msg := ln_replen_qty;

         --
         -- Round up the splits that need to be replenished to a full case.
         -- Only case quantities are replenished. 
         --
        ln_replen_qty := CEIL(ln_replen_qty / i_item_status_info.n_spc)
                       * i_item_status_info.n_spc;

         pl_log.ins_msg
                  ('INFO',
                   lv_fname,
                   'ln_replen_qty(qty in splits needing replenishing to'
                   ||' cover order for splits): '
                   || TO_CHAR(ln_replen_qty_for_msg)
                   || ' Qty rounded up to a full case is: '
                   || TO_CHAR(ln_replen_qty)
                   || '   ln_qty_available(qty available in splits with'
                   || ' inv uom=0 or 2): '
                   || TO_CHAR(ln_qty_available),
                   NULL, NULL, ct_application_function, gl_pkg_name);

         --
         -- Check if the qoh is sufficient for replenishment, and proceed
         -- to replenishment processing.
         --
         IF (ln_qty_available >= ln_replen_qty) THEN
            --
            -- Get the total qty available at all pick face locations.
            --
            pl_log.ins_msg ('INFO',
                            lv_fname,
                            'Getting qty available at all pick faces',
                            NULL, NULL,  ct_application_function, gl_pkg_name);

            --
            -- Get the case qty available on case carriers that are in a
            -- pick face.
            -- ***** Remember the qty from inv is in splits *****
            --
            -- 2/17/20110 Brian Bent  Use LOC table to the location level
            --            and not i_loc SUBSTR(i.plogi_loc, -1, 1)
            --
            SELECT NVL(SUM(i.qoh - NVL(i.qty_alloc, 0)), 0)
              INTO ln_qty_available
              FROM inv i,
                   pm p,
                   zone z,
                   loc l
             WHERE i.inv_uom          IN (0, 2)
               AND i.prod_id          = i_item_status_info.v_prod_id
               AND i.cust_pref_vendor = i_item_status_info.v_cust_pref_vendor
               AND i.prod_id          = p.prod_id
               AND i.cust_pref_vendor = p.cust_pref_vendor
               AND i.status           = 'AVL'
               AND p.zone_id          = z.zone_id
               AND z.rule_id          = 3
               AND l.logi_loc         = i.plogi_loc
               AND l.pik_level        <= z.max_pick_level;

            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Quantity available(in splits) at all case pick face'
               || ' locations with inv_uom=0 or 2: '
               || NVL(ln_qty_available, 0)
               || '  KEY=Prod_id[' || i_item_status_info.v_prod_id || ']'
               || ',CPV[' || i_item_status_info.v_cust_pref_vendor || ']'
               || ',Rule_id[3]  TABLE=inv,pm,zone';

            pl_text_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL);
            pl_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL,
                           ct_application_function, gl_pkg_name);

            -- 8/21/17: get the case qty available on case carriers that are in 
            -- reserve. if we don't have enough, we cannot
            -- send a request to drop a case from reserve.
            --
            SELECT NVL(SUM(i.qoh - NVL(i.qty_alloc, 0)), 0)
              INTO ln_reserve_qty_avl
              FROM inv i,
                   pm p,
                   zone z,
                   loc l
             WHERE i.inv_uom          IN (0, 2)
               AND i.prod_id          = i_item_status_info.v_prod_id
               AND i.cust_pref_vendor = i_item_status_info.v_cust_pref_vendor
               AND i.prod_id          = p.prod_id
               AND i.cust_pref_vendor = p.cust_pref_vendor
               AND i.status           = 'AVL'
               AND p.zone_id          = z.zone_id
               AND z.rule_id          = 3
               AND l.logi_loc         = i.plogi_loc
               AND l.logi_loc        <> z.induction_loc
               AND l.logi_loc        <> z.outbound_loc
               AND l.pik_level        > z.max_pick_level;

            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Available reserve qty (in splits) before potential pending high prio orders: '
               || ln_reserve_qty_avl;

            pl_text_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL);
            pl_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL,
                           ct_application_function, gl_pkg_name);

            -- 8/21/17: the above reserve qty does not take into account the pending
            -- high priority orders. a pending high priority order is not 
            -- reflected in inv.qty_alloc. Therefore, if there are pending   
            -- high priority orders, we need to subtract the requested qty
            -- from the above reserve qty.

            ln_total_high_prio_qty := 0;
            FOR r_i_status_order in c_I_status_order_for_item LOOP
               l_hi_prio_order_found := FALSE;
               FOR r_high_prio_order in 
                     c_high_prio_order_for_item(r_i_status_order.order_item_id, 
                                                r_i_status_order.message_id) LOOP
                  l_hi_prio_order_found := TRUE;
                  lv_msg_text :=
                        'Prog Code: '
                     || ct_program_code
                     || ' Found pending high prio order ID [' || r_high_prio_order.order_id || ']'
                     || ' #cases requested: '
                     || r_high_prio_order.quantity_requested
                     || ' ('
                     || r_high_prio_order.quantity_requested * i_item_status_info.n_spc
                     || ' splits)';

                  pl_text_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL);
                  pl_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL,
                           ct_application_function, gl_pkg_name);
               END LOOP;
               IF l_hi_prio_order_found THEN
                  ln_qty_short := r_i_status_order.quantity_requested 
                                  - r_i_status_order.quantity_available;
                  -- convert to cases
                  ln_qty_short := CEIL(ln_qty_short / i_item_status_info.n_spc); 
                  -- total high priority qty in splits
                  ln_total_high_prio_qty := ln_total_high_prio_qty 
                                            + (ln_qty_short * i_item_status_info.n_spc);
               END IF;
            END LOOP; -- looping through I status records

            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Total qty (in splits) on high prio order: '
               || ln_total_high_prio_qty;

            pl_text_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL);
            pl_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL,
                           ct_application_function, gl_pkg_name);

            -- adjust the available reserve qty
            ln_reserve_qty_avl := ln_reserve_qty_avl - ln_total_high_prio_qty;
            IF (ln_reserve_qty_avl < 0) THEN
               ln_reserve_qty_avl := 0;
            END IF;

            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Available reserve qty (in splits) after potential pending high prio orders: '
               || ln_reserve_qty_avl;

            pl_text_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL);
            pl_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL,
                           ct_application_function, gl_pkg_name);
            
            --
            -- If the replenishment quantity required is available at pick
            -- face location(s) then insert a replenishment task.
            --
            IF (ln_qty_available >= ln_replen_qty) THEN

               /* debug stuff
               pl_log.ins_msg('INFO', lv_fname,
                  'xxxx ln_qty_available is >= ln_replen_qty', NULL, NULL,
                  ct_application_function, gl_pkg_name);
               */

               --
               -- Need to add high priority store order anyway because we
               -- are taking cases out of a pick face for the case to
               -- split replenishment.
               -- Patrice Kabran 8/21/17: adding a check to ensure that we have enough in 
               -- reserve before trying to create the high priority order.
               --
               o_status := ct_success;
               IF (ln_reserve_qty_avl >= ln_replen_qty) THEN 
                  p_create_highprio_order(i_item_status_info, ln_status, 'Y');
                  IF (ln_status != ct_success) THEN
                     o_status := ct_failure;
                  ELSE          
                     o_status := ct_in_progress;
                  END IF;
               ELSE  -- log a message
                  lv_msg_text :=
                        'Prog Code: '
                      || ct_program_code
                      || ' Available reserve qty (' || ln_reserve_qty_avl || ')'
                      || ' not enough to create high prio order for ' 
                      || ln_replen_qty
                      || ' to replace cases taken from pick face.';

                  pl_text_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL);
                  pl_log.ins_msg('INFO', lv_fname, lv_msg_text, NULL, NULL,
                           ct_application_function, gl_pkg_name);
               END IF; 

               IF (o_status = ct_in_progress OR o_status = ct_success) THEN 

                  -- creating replenishment from pick face cases

                  OPEN c_other_pick_loc;

                  --
                  -- Insert replenishment for each of the pick face
                  -- locations until the replenishment quantity is satisfied.
                  --
                  WHILE (ln_replen_qty > 0) LOOP

                     /* debug stuff
                     pl_log.ins_msg('INFO', lv_fname, 'xxxx  in loop',
                            NULL, NULL, ct_application_function, gl_pkg_name);
                     */

                     FETCH c_other_pick_loc
                      INTO l_ml_replenishment.v_src_loc,
                           l_ml_replenishment.v_orig_pallet_id,
                           l_ml_replenishment.v_exp_date,
                           qty_to_be_replenished,
                           ln_inv_uom,
                           ln_case_qty_per_carrier, 
                           case_qty_for_split_rpl_in_splt;

                     EXIT WHEN c_other_pick_loc%NOTFOUND;

                     pl_log.ins_msg('INFO', lv_fname,
                         'src loc[' || l_ml_replenishment.v_src_loc || ']'
                         || '  Orig LP['
                         || l_ml_replenishment.v_orig_pallet_id || ']',
                         NULL, NULL, ct_application_function, gl_pkg_name);

                     --
                     -- Replenishment quantity processing, after each
                     -- replenishment task creation.
                     --
                     -- 12/03/08 Brian Bent  Do not do this.
                     -- ln_replen_qty is always in splits.
                     --
                     -- ln_replen_qty :=
                     --   f_convert_to_splits
                     --               (ln_inv_uom,
                     --                i_item_status_info.v_prod_id,
                     --                i_item_status_info.v_cust_pref_vendor,
                     --                ln_replen_qty);

                     --
                     -- Replenishment the maximum of the following:
                     --    - What is required to cover the order
                     --    - The case qty for split replenishment.
                     -- The assignment, if necessary, will be made only on the
                     -- first run through the loop.
                     --
                     IF (ln_replen_qty < case_qty_for_split_rpl_in_splt) THEN
                        ln_replen_qty := case_qty_for_split_rpl_in_splt;
                     END IF;

                     IF ((ln_replen_qty - qty_to_be_replenished) > 0) THEN
                        ln_replen_qty := ln_replen_qty - qty_to_be_replenished;
                     ELSE
                        qty_to_be_replenished := ln_replen_qty;
                        ln_replen_qty := 0;
                     END IF;

                     l_ml_replenishment.v_prod_id :=
                                                  i_item_status_info.v_prod_id;
                     l_ml_replenishment.v_cust_pref_vendor :=
                                         i_item_status_info.v_cust_pref_vendor;
                     l_ml_replenishment.n_uom := i_item_status_info.n_uom;
                     l_ml_replenishment.v_replen_type := 'MNL';
                     l_ml_replenishment.n_replen_qty := qty_to_be_replenished;

                     pl_ml_common.get_induction_loc
                                       (i_item_status_info.v_prod_id,
                                        i_item_status_info.v_cust_pref_vendor,
                                        i_item_status_info.n_uom,
                                        ln_status,
                                        l_ml_replenishment.v_dest_loc);

                     IF (ln_status <> ct_success) THEN
                        lv_msg_text :=
                              'Prog Code: '
                           || ct_program_code
                           || ' Error in getting Induction Location for the Prod_id: '
                           || i_item_status_info.v_prod_id
                           || ', CPV: '
                           || i_item_status_info.v_cust_pref_vendor
                           || ', UOM: '
                           || i_item_status_info.n_uom;
                        pl_text_log.ins_msg('FATAL',
                                            lv_fname,
                                            lv_msg_text,
                                            NULL,
                                            NULL);
                        RAISE e_indloc_notfound;
                     END IF;

                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Prod id:'
                        || i_item_status_info.v_prod_id
                        || ' Induction Location:'
                        || l_ml_replenishment.v_dest_loc;

                     pl_text_log.ins_msg('INFO',
                                         lv_fname,
                                         lv_msg_text,
                                         NULL,
                                         NULL);
                     pl_log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL,
                                     NULL);

                     SELECT ml_pallet_id_seq.NEXTVAL
                       INTO ln_pallet_seq
                       FROM DUAL;

                     l_ml_replenishment.v_pallet_id :=
                                      l_ml_replenishment.v_src_loc
                                      || TRIM(TO_CHAR(ln_pallet_seq));

                     pl_log.ins_msg('INFO', lv_fname,
                         'v_pallet_id[' || l_ml_replenishment.v_pallet_id || ']'
                         || '  ln_pallet_seq[' || TO_CHAR(ln_pallet_seq) || ']',
                            NULL, NULL, ct_application_function, gl_pkg_name);

                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Query to select source pikpath when storage ind'
                        || ' is "B" and pick loc is present'
                        || ' KEY=logi_loc:[ '
                        || l_ml_replenishment.v_src_loc
                        || ' ] TABLE=loc';

                     SELECT pik_path
                       INTO l_ml_replenishment.v_s_pikpath
                       FROM LOC
                      WHERE logi_loc = l_ml_replenishment.v_src_loc;

                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Query to select dest pikpath when storage ind'
                        || ' is "B" and pick loc is present'
                        || ' KEY=logi_loc:[ '
                        || l_ml_replenishment.v_dest_loc
                        || ' ] TABLE=loc';

                     SELECT pik_path
                       INTO l_ml_replenishment.v_d_pikpath
                       FROM LOC
                      WHERE logi_loc = l_ml_replenishment.v_dest_loc;

                     l_ml_replenishment.v_order_id :=
                                                 i_item_status_info.v_order_id;
                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Query to select order priority from the shipping order header message'
                        || ' KEY=order_id:[ '
                        || i_item_status_info.v_order_id
                        || ' ] and message_type:[ '
                        || ct_ship_ord_hdr
                        || ' ] TABLE=miniload_order';

                     BEGIN
                        SELECT priority_value
                          INTO l_ml_replenishment.v_priority
                          FROM priority_code
                         WHERE priority_code = 'HGH'
                           AND unpack_code = 'Y'; -- 3/23/2010 Brian Bent Added
                     EXCEPTION
                        WHEN OTHERS THEN
                           lv_msg_text :=
                                 'Prog Code: '
                              || ct_program_code
                              || ' Query to select Priority Value for  priority code "HGH" from '
                              || ' TABLE=priority_code';
                           RAISE;
                     END;

                     p_insert_replen(l_ml_replenishment, ln_status);

                     IF (ln_status = ct_success) THEN
                        SELECT REPLACE (USER, 'OPS$')
                          INTO l_inv_info.upd_user
                          FROM DUAL;

                        UPDATE inv
                           SET qty_alloc = qty_alloc + qty_to_be_replenished
                         WHERE plogi_loc = l_ml_replenishment.v_src_loc
                               -- 3/23/2010  Brian Bent Added next stmt
                           AND logi_loc = l_ml_replenishment.v_orig_pallet_id
                           AND prod_id = l_ml_replenishment.v_prod_id;

                        IF (SQL%ROWCOUNT = 0) THEN
                           lv_msg_text :=
                                 'Prog Code: '
                              || ct_program_code
                              || ' Inventory Update failed'
                              || ' Key=plogi_loc:[ '
                              || l_ml_replenishment.v_src_loc
                              || '] prod_id:['
                              || l_ml_replenishment.v_prod_id
                              || '] Table = inv';
                           pl_text_log.ins_msg('FATAL',
                                               lv_fname,
                                               lv_msg_text,
                                               NULL,
                                               NULL,
                                               ct_application_function,
                                               gl_pkg_name);
                        END IF;

                        lv_msg_text :=
                              'Prog Code: '
                           || ct_program_code
                           || ' Query to select inv record when storage ind'
                           || ' is "B" and replenlst record is inserted'
                           || ' Key=plogi_loc:[ '
                           || l_ml_replenishment.v_src_loc
                           || '] prod_id:['
                           || l_ml_replenishment.v_prod_id
                           || '] Table = inv';

                        SELECT prod_id,
                               cust_pref_vendor,
                               logi_loc,
                               plogi_loc,
                               qoh,
                               qty_alloc,
                               qty_planned,
                               status,
                               cube, 
                               parent_pallet_id,
                               dmg_ind,
                               inv_uom,
                               abc, 
                               abc_gen_date,
                               case_type_tmu,
                               exp_date,
                               exp_ind,
                               inv_date,
                               lot_id,
                               lst_cycle_date,
                               lst_cycle_reason,
                               mfg_date,
                               min_qty,
                               pallet_height,
                               rec_date,
                               rec_id,
                               status,
                               temperature,
                               weight
                          INTO l_inv_info.prod_id,
                               l_inv_info.cust_pref_vendor,
                               l_inv_info.logi_loc,
                               l_inv_info.plogi_loc,
                               l_inv_info.qoh,
                               l_inv_info.qty_alloc,
                               l_inv_info.qty_planned,
                               l_inv_info.status,
                               l_inv_info.cube, 
                               l_inv_info.parent_pallet_id,
                               l_inv_info.dmg_ind,
                               l_inv_info.inv_uom,
                               l_inv_info.abc, 
                               l_inv_info.abc_gen_date,
                               l_inv_info.case_type_tmu,
                               l_inv_info.exp_date,
                               l_inv_info.exp_ind,
                               l_inv_info.inv_date,
                               l_inv_info.lot_id,
                               l_inv_info.lst_cycle_date,
                               l_inv_info.lst_cycle_reason,
                               l_inv_info.mfg_date,
                               l_inv_info.min_qty,
                               l_inv_info.pallet_height,
                               l_inv_info.rec_date,
                               l_inv_info.rec_id,
                               l_inv_info.status,
                               l_inv_info.temperature,
                               l_inv_info.weight
                          FROM inv
                         WHERE plogi_loc = l_ml_replenishment.v_src_loc
                               -- 3/23/2010 Brian Bent  Added next stmt.
                           AND logi_loc = l_ml_replenishment.v_orig_pallet_id 
                           AND prod_id = l_ml_replenishment.v_prod_id;

                        l_inv_info.logi_loc  := l_ml_replenishment.v_pallet_id;
                        l_inv_info.plogi_loc := l_ml_replenishment.v_dest_loc;
                        l_inv_info.qty_alloc        := 0;
                        l_inv_info.qty_planned      := qty_to_be_replenished;
                        l_inv_info.inv_uom          := 1;         --5/10/06
                        l_inv_info.qoh              := 0;
                        l_inv_info.CUBE             := 999;
                        l_inv_info.parent_pallet_id := NULL;
                        l_inv_info.dmg_ind          := NULL;
                        l_inv_info.qty_planned      := qty_to_be_replenished;

                        p_insert_inv (l_inv_info, o_status);
                     ELSE
                        lv_msg_text :=
                              'Prog Code: '
                           || ct_program_code
                           || ' p_insert_replen failed';

                        pl_text_log.ins_msg('FATAL',
                                            lv_fname,
                                            lv_msg_text,
                                            NULL,
                                            NULL,
                                            ct_application_function,
                                            gl_pkg_name);
                        o_status := ct_failure;
                        EXIT WHEN o_status = ct_failure;
                     END IF;
                  END LOOP;  -- end WHILE (ln_replen_qty > 0) 

                  CLOSE c_other_pick_loc;

               END IF;    -- end of creating replenishment from pick face cases 
            ELSE
               --
               -- QOH at pick face locations is not sufficient to cover the
               -- needed replenishment qty.  Create high priority store order.
               -- 8/21/17 - ensure we have enough in reserve before attempting
               -- to create high priority order.
               --
               IF (ln_reserve_qty_avl >= ln_replen_qty) THEN 
                  p_create_highprio_order(i_item_status_info, ln_status, 'Y');

                  IF (ln_status = ct_success) THEN
                     o_status := ct_in_progress;
                  ELSE
                     o_status := ct_failure;
                  END IF;
               ELSE
                  lv_msg_text :=
                        'Prog Code: '
                     || ct_program_code
                     || ' Qty available in reserve: '
                     || ln_reserve_qty_avl
                     || '  not sufficient to replenish needed qty ('
                     || ln_replen_qty || ')';

                  pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL,
                                       ct_application_function, gl_pkg_name);
                  pl_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL,
                                  ct_application_function, gl_pkg_name);
                  o_status := ct_success;
               END IF; -- end of checking reserve qty
            END IF;  -- end of checking case qty from pick face
         ELSE                      -- If qoh is insufficient for replenishment
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Available Quantity on Hand(split qty): '
               || ln_qty_available
               || '  Inventory not sufficient for replenishment';

            pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL,
                                 ct_application_function, gl_pkg_name);
            pl_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL,
                            ct_application_function, gl_pkg_name);
            o_status := ct_success;
         END IF;
      ELSIF (i_item_status_info.c_ml_storage_ind = 'S') THEN
         --
         -- Splits in mini-loader, cases in main warehouse.
         --
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Query to select rule_id and zone_id when storage ind is "S"'
            || ' Key= Prod_id:['
            || i_item_status_info.v_prod_id
            || '] CPV:['
            || i_item_status_info.v_cust_pref_vendor
            || '] Table = [pm,zone]';

         --
         -- Splits in mini-loader, cases in main warehouse.
         -- Check if existing replenishment will cover the qty ordered.
         --
         IF (f_is_repl_necessary_for_order
                         (i_item_status_info.v_prod_id,
                          i_item_status_info.v_cust_pref_vendor) = FALSE) THEN
            pl_log.ins_msg
                     ('INFO',
                      lv_fname,
                         'Replenishment not necessary because existing'
                      || ' replenishment will cover the order.',
                      NULL, NULL);
            o_status := ct_success;
            RETURN;
                   -- 05/12/08 Brian Bent Not the best programming practice to
                   -- return from a procedure in the middle.
         END IF;

         SELECT pm.zone_id, zone.rule_id
           INTO lv_zone_id, ln_rule_id
           FROM pm, zone
          WHERE pm.zone_id          = zone.zone_id
            AND pm.prod_id          = i_item_status_info.v_prod_id
            AND pm.cust_pref_vendor = i_item_status_info.v_cust_pref_vendor;

         lv_msg_text :=
                'Prog Code: ' || ct_program_code || ' Rule Id: ' || ln_rule_id;
         pl_text_log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

         --
         -- Picking from home location
         --
         IF (ln_rule_id = 0) THEN
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Query to select logi_loc when storage ind is "S" and'
               || ' rule_id is 0'
               || ' Key= Prod_id:['
               || i_item_status_info.v_prod_id
               || '] CPV:['
               || i_item_status_info.v_cust_pref_vendor
               || '] Table=loc';

            SELECT logi_loc
              INTO lv_logi_loc
              FROM loc
             WHERE prod_id          = i_item_status_info.v_prod_id
               AND cust_pref_vendor = i_item_status_info.v_cust_pref_vendor
               AND uom              IN (0, 2)
               AND perm             = 'Y'
               AND rank             = 1;

            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Prod id:'
               || i_item_status_info.v_prod_id
               || ' logi_loc:'
               || lv_logi_loc;

            pl_text_log.ins_msg('WARNING', lv_fname, lv_msg_text, NULL, NULL);
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Query to select qoh when storage ind is "S" and rule_id'
               || ' is 0'
               || ' Key=Prod_id:['
               || i_item_status_info.v_prod_id
               || '] CPV:['
               || i_item_status_info.v_cust_pref_vendor
               || '] UOM in (0,2) logi_loc=['
               || lv_logi_loc
               || '] Table= (inv,pm)';

            SELECT NVL((TRUNC(qoh / p.spc) - TRUNC(NVL(qty_alloc, 0) / spc))
                        * p.spc, 0),
                   inv_uom,
                   NVL(case_qty_for_split_rpl, 1) * spc
              INTO ln_qty_available,
                   ln_inv_uom, 
                   case_qty_for_split_rpl_in_splt
              FROM inv i, pm p
             WHERE i.prod_id          = p.prod_id
               AND i.cust_pref_vendor = p.cust_pref_vendor
               AND i.prod_id          = i_item_status_info.v_prod_id
               AND i.cust_pref_vendor = i_item_status_info.v_cust_pref_vendor
               AND i.inv_uom          IN (0, 2)
               AND i.status           = 'AVL'
               AND i.plogi_loc        = i.logi_loc
               AND i.plogi_loc        = lv_logi_loc;

            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Prod id:'
               || i_item_status_info.v_prod_id
               || ' Qty available(in splits): '
               || ln_qty_available;

            pl_text_log.ins_msg('WARNING', lv_fname, lv_msg_text, NULL, NULL);

            IF (ln_qty_available >= (  i_item_status_info.n_quantity_requested
                           - i_item_status_info.n_quantity_available)) THEN
               l_ml_replenishment.v_prod_id := i_item_status_info.v_prod_id;
               l_ml_replenishment.v_cust_pref_vendor :=
                                        i_item_status_info.v_cust_pref_vendor;
               l_ml_replenishment.n_uom := i_item_status_info.n_uom;
               l_ml_replenishment.n_replen_qty :=
                    i_item_status_info.n_quantity_requested
                  - i_item_status_info.n_quantity_available;

               IF (l_ml_replenishment.n_replen_qty != case_qty_for_split_rpl_in_splt)
               THEN
                  l_ml_replenishment.n_replen_qty := case_qty_for_split_rpl_in_splt;
               END IF;

               l_ml_replenishment.v_replen_type := 'MNL';
               l_ml_replenishment.v_src_loc := lv_logi_loc;

               pl_ml_common.get_induction_loc
                                       (i_item_status_info.v_prod_id,
                                        i_item_status_info.v_cust_pref_vendor,
                                        i_item_status_info.n_uom,
                                        ln_status,
                                        l_ml_replenishment.v_dest_loc);

               IF (ln_status <> ct_success) THEN
                  lv_msg_text :=
                        'Prog Code: '
                     || ct_program_code
                     || ' Error in getting Induction Location for the Prod_id: '
                     || i_item_status_info.v_prod_id
                     || ', CPV: '
                     || i_item_status_info.v_cust_pref_vendor
                     || ', UOM: '
                     || i_item_status_info.n_uom;

                  pl_text_log.ins_msg('FATAL',
                                      lv_fname,
                                      lv_msg_text,
                                      NULL,
                                      NULL);
                  RAISE e_indloc_notfound;
               END IF;

               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Prod id:'
                  || i_item_status_info.v_prod_id
                  || ' Induction Location:'
                  || l_ml_replenishment.v_dest_loc;

               pl_text_log.ins_msg('WARNING',
                                   lv_fname,
                                   lv_msg_text,
                                   NULL,
                                   NULL);

               SELECT ml_pallet_id_seq.NEXTVAL
                 INTO ln_pallet_seq
                 FROM DUAL;

               l_ml_replenishment.v_pallet_id := lv_logi_loc
                                     || TRIM(TO_CHAR(ln_pallet_seq));

               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Query to select source pikpath when storage ind'
                  || ' is "S", rule_id is 0 and qoh is sufficient'
                  || ' KEY=logi_loc:[ '
                  || l_ml_replenishment.v_src_loc
                  || ' ] TABLE=loc';

               SELECT pik_path
                 INTO l_ml_replenishment.v_s_pikpath
                 FROM loc
                WHERE logi_loc = l_ml_replenishment.v_src_loc;

               lv_msg_text :=
                      'Prog Code: '
                   || ct_program_code
                   || ' Query to select destination pikpath when storage ind'
                   || ' is "S", rule_id is 0 and qoh is sufficient'
                   || ' KEY=logi_loc:[ '
                   || l_ml_replenishment.v_dest_loc
                   || ' ] TABLE=loc';

               SELECT pik_path
                 INTO l_ml_replenishment.v_d_pikpath
                 FROM loc
                WHERE logi_loc = l_ml_replenishment.v_dest_loc;

               l_ml_replenishment.v_order_id := i_item_status_info.v_order_id;
               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Query to select order priority when storage ind'
                  || ' is "S", rule_id is 0 and qoh is sufficient';

               /*****
               09/231/2012  Don't do this.
               SELECT MIN(order_priority)
                 INTO l_ml_replenishment.v_priority
                 FROM miniload_order
                WHERE order_id = i_item_status_info.v_order_id
                  AND message_type = ct_ship_ord_hdr;
               *****/
               --
               -- 09/21/2012 Brian Bent
               -- Get the priority for the split repenishment.
               --
               BEGIN
                  SELECT priority_value
                   INTO l_ml_replenishment.v_priority
                   FROM priority_code
                  WHERE priority_code = 'HGH'
                    AND unpack_code = 'Y';
               EXCEPTION
                  WHEN OTHERS THEN
                     lv_msg_text :=
                        'Prog Code: '
                        || ct_program_code
                        || ' {only splits in ML) Query to select Priority Value for priority code "HGH" from '
                        || ' TABLE=priority_code';
                     RAISE;
               END;

               lv_msg_text := 'Prog Code: '
                              || ct_program_code
                              || ' Prod id['
                              || i_item_status_info.v_prod_id || ']'
                              || '  Priority['
                              || l_ml_replenishment.v_priority || ']';

               pl_text_log.ins_msg ('WARNING',
                                    lv_fname,
                                    lv_msg_text,
                                    NULL,
                                    NULL);
               pl_log.ins_msg('WARNING',
                              lv_fname,
                              lv_msg_text,
                              NULL,
                              NULL);
               lv_msg_text :=
                     'Prog Code:'
                  || ct_program_code
                  || ' Query to select exp date and parent_pallet_id when'
                  || ' storage ind is "S", rule_id is 0 and qoh is sufficient';

               SELECT exp_date,
                      parent_pallet_id
                 INTO l_ml_replenishment.v_exp_date,
                      l_ml_replenishment.v_parent_pallet_id
                 FROM inv
                WHERE logi_loc  = lv_logi_loc
                  AND plogi_loc = logi_loc
                  AND prod_id   = l_ml_replenishment.v_prod_id;

               l_ml_replenishment.v_orig_pallet_id := lv_logi_loc;
               p_insert_replen (l_ml_replenishment, ln_status);

               IF (ln_status = ct_success) THEN
                  SELECT REPLACE (USER, 'OPS$')
                    INTO l_inv_info.upd_user
                    FROM DUAL;

                  UPDATE inv
                     SET qty_alloc =
                                   qty_alloc + l_ml_replenishment.n_replen_qty
                   WHERE logi_loc = lv_logi_loc;

                  IF (SQL%ROWCOUNT = 0) THEN
                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Inventory Update failed'
                        || ' Key=logi_loc:[ '
                        || lv_logi_loc
                        || '] prod_id:['
                        || l_ml_replenishment.v_prod_id
                        || '] Table = inv';

                     pl_text_log.ins_msg('FATAL',
                                         lv_fname,
                                         lv_msg_text,
                                         NULL,
                                         NULL);
                  END IF;

                  lv_msg_text :=
                        'Prog Code: '
                     || ct_program_code
                     || ' Query to select inv record when storage ind'
                     || ' is "S", rule_id is 0 and qoh is sufficient'
                     || ' Key=logi_loc:[ '
                     || lv_logi_loc
                     || '] prod_id:['
                     || l_ml_replenishment.v_prod_id
                     || '] Table = inv';

                  SELECT prod_id, cust_pref_vendor,
                         logi_loc, plogi_loc,
                         qoh, qty_alloc,
                         qty_planned, status,
                         CUBE, parent_pallet_id,
                         dmg_ind, inv_uom,
                         ABC, abc_gen_date,
                         case_type_tmu, exp_date,
                         exp_ind, inv_date,
                         lot_id, lst_cycle_date,
                         lst_cycle_reason, mfg_date,
                         min_qty, pallet_height,
                         rec_date, rec_id,
                         status, temperature,
                         weight
                    INTO l_inv_info.prod_id, l_inv_info.cust_pref_vendor,
                         l_inv_info.logi_loc, l_inv_info.plogi_loc,
                         l_inv_info.qoh, l_inv_info.qty_alloc,
                         l_inv_info.qty_planned, l_inv_info.status,
                         l_inv_info.CUBE, l_inv_info.parent_pallet_id,
                         l_inv_info.dmg_ind, l_inv_info.inv_uom,
                         l_inv_info.ABC, l_inv_info.abc_gen_date,
                         l_inv_info.case_type_tmu, l_inv_info.exp_date,
                         l_inv_info.exp_ind, l_inv_info.inv_date,
                         l_inv_info.lot_id, l_inv_info.lst_cycle_date,
                         l_inv_info.lst_cycle_reason, l_inv_info.mfg_date,
                         l_inv_info.min_qty, l_inv_info.pallet_height,
                         l_inv_info.rec_date, l_inv_info.rec_id,
                         l_inv_info.status, l_inv_info.temperature,
                         l_inv_info.weight
                    FROM inv
                   WHERE logi_loc = lv_logi_loc
                     AND logi_loc = plogi_loc
                     AND prod_id  = l_ml_replenishment.v_prod_id;

                  l_inv_info.logi_loc       := l_ml_replenishment.v_pallet_id;
                  l_inv_info.plogi_loc      := l_ml_replenishment.v_dest_loc;
                  l_inv_info.qty_alloc      := 0;
                  l_inv_info.qty_planned    := l_ml_replenishment.n_replen_qty;
                  l_inv_info.inv_uom        := 1;   --5/19/06
                  l_inv_info.qoh            := 0;
                  l_inv_info.CUBE           := 999;
                  l_inv_info.parent_pallet_id := NULL;
                  l_inv_info.dmg_ind        := NULL;

                  p_insert_inv (l_inv_info, o_status);
               ELSE
                  lv_msg_text :=
                        'Prog Code: '
                     || ct_program_code
                     || ' Error in executing p_insert_replen';

                  pl_text_log.ins_msg('FATAL',
                                      lv_fname,
                                      lv_msg_text,
                                      NULL,
                                      NULL);
                  o_status := ct_failure;
               END IF;
            ELSE                        -- If qoh at home loc is insuffiecient
               l_ml_replenishment.v_prod_id := i_item_status_info.v_prod_id;
               l_ml_replenishment.v_cust_pref_vendor :=
                                        i_item_status_info.v_cust_pref_vendor;
               l_ml_replenishment.n_uom := i_item_status_info.n_uom;
               l_ml_replenishment.n_replen_qty :=
                    i_item_status_info.n_quantity_requested
                  - i_item_status_info.n_quantity_available;

               IF (l_ml_replenishment.n_replen_qty != case_qty_for_split_rpl_in_splt)
               THEN
                  l_ml_replenishment.n_replen_qty := case_qty_for_split_rpl_in_splt;
               END IF;

               l_ml_replenishment.v_order_id := i_item_status_info.v_order_id;
               l_ml_replenishment.v_dest_loc := lv_logi_loc;
               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Query to select order priority when storage ind'
                  || ' is "S", rule_id is 0 and qoh is not sufficient';

               SELECT MIN (order_priority)
                 INTO l_ml_replenishment.v_priority
                 FROM miniload_order
                WHERE order_id = i_item_status_info.v_order_id
                  AND message_type = ct_ship_ord_hdr;

               lv_msg_text :=
                        'Prog Code: '
                     || ct_program_code
                     || ' Creating NDM Replenishment For Prod id:'
                     || i_item_status_info.v_prod_id
                     || ' Priority:'
                     || l_ml_replenishment.v_priority;

               pl_text_log.ins_msg('WARNING',
                                   lv_fname,
                                   lv_msg_text,
                                   NULL,
                                   NULL);
               l_ml_replenishment.v_replen_type := 'NDM';

               --
               -- Create Non demand replenishments for home location.
               --
               p_create_ndmforminiload(l_ml_replenishment,
                                       ln_replen_qty,
                                       ln_status);

               IF (ln_status = ct_success) THEN
                  l_ml_replenishment.v_replen_type := 'MNL';
                  l_ml_replenishment.v_src_loc := lv_logi_loc;
                  pl_ml_common.get_induction_loc
                                      (i_item_status_info.v_prod_id,
                                       i_item_status_info.v_cust_pref_vendor,
                                       i_item_status_info.n_uom,
                                       ln_status,
                                       l_ml_replenishment.v_dest_loc);

                  IF (ln_status <> ct_success) THEN
                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Error in getting Induction Location for the'
                        || ' prod_id: '
                        || i_item_status_info.v_prod_id
                        || ', CPV: '
                        || i_item_status_info.v_cust_pref_vendor
                        || ', UOM: '
                        || i_item_status_info.n_uom;

                     pl_text_log.ins_msg ('FATAL',
                                          lv_fname,
                                          lv_msg_text,
                                          NULL,
                                          NULL);
                     RAISE e_indloc_notfound;
                  END IF;

                  lv_msg_text :=
                        'Prog Code: '
                     || ct_program_code
                     || ' Prod id:'
                     || i_item_status_info.v_prod_id
                     || ' Induction Location:'
                     || l_ml_replenishment.v_dest_loc;

                  pl_text_log.ins_msg ('WARNING',
                                       lv_fname,
                                       lv_msg_text,
                                       NULL,
                                       NULL);
                  lv_msg_text :=
                        'Prog Code:'
                     || ct_program_code
                     || ' Query to select source pikpath when storage ind'
                     || ' is "S", rule_id is 0 and qoh is not sufficient'
                     || ' KEY=logi_loc:[ '
                     || l_ml_replenishment.v_src_loc
                     || ' ] TABLE=loc';

                  SELECT pik_path
                    INTO l_ml_replenishment.v_s_pikpath
                    FROM loc
                   WHERE logi_loc = l_ml_replenishment.v_src_loc;

                  lv_msg_text :=
                        'Prog Code:'
                     || ct_program_code
                     || ' Query to select dest pikpath when storage ind'
                     || ' is "S", rule_id is 0 and qoh is not sufficient'
                     || ' KEY=logi_loc:[ '
                     || l_ml_replenishment.v_dest_loc
                     || ' ] TABLE=loc';

                  SELECT pik_path
                    INTO l_ml_replenishment.v_d_pikpath
                    FROM loc
                   WHERE logi_loc = l_ml_replenishment.v_dest_loc;

                  l_ml_replenishment.v_order_id :=
                                                 i_item_status_info.v_order_id;
                  lv_msg_text :=
                        'Prog Code:'
                     || ct_program_code
                     || ' Query to select exp date and parent_parent_id when storage ind is "S", rule_id is 0 and qoh is not sufficient';

                  SELECT exp_date,
                         parent_pallet_id
                    INTO l_ml_replenishment.v_exp_date,
                         l_ml_replenishment.v_parent_pallet_id
                    FROM inv
                   WHERE logi_loc = lv_logi_loc
                     AND plogi_loc = logi_loc
                     AND prod_id = l_ml_replenishment.v_prod_id;

                  SELECT ml_pallet_id_seq.NEXTVAL
                    INTO ln_pallet_seq
                    FROM DUAL;

                  l_ml_replenishment.v_pallet_id :=
                                         l_ml_replenishment.v_src_loc 
                                         || TRIM(TO_CHAR(ln_pallet_seq));

                  l_ml_replenishment.v_orig_pallet_id := lv_logi_loc;
                  p_insert_replen(l_ml_replenishment, ln_status);

                  IF (ln_status = ct_success) THEN
                     SELECT REPLACE (USER, 'OPS$')
                       INTO l_inv_info.upd_user
                       FROM DUAL;

                     UPDATE inv
                        SET qty_alloc = qty_alloc + ln_replen_qty
                      WHERE logi_loc = lv_logi_loc;

                     IF (SQL%ROWCOUNT = 0) THEN
                        lv_msg_text :=
                              'Prog Code:'
                           || ct_program_code
                           || ' Inventory Update failed'
                           || ' Key=logi_loc:[ '
                           || lv_logi_loc
                           || ']';

                        pl_text_log.ins_msg ('FATAL',
                                             lv_fname,
                                             lv_msg_text,
                                             NULL,
                                             NULL);
                     END IF;

                     lv_msg_text :=
                           'Prog Code:'
                        || ct_program_code
                        || ' Query to select inv record when storage ind'
                        || ' is "S", rule_id is 0 and qoh is not sufficient'
                        || ' Key=plogi_loc:[ '
                        || lv_logi_loc
                        || '] prod_id:['
                        || l_ml_replenishment.v_prod_id
                        || '] Table = inv';

                     SELECT prod_id,
                            cust_pref_vendor,
                            logi_loc,
                            plogi_loc,
                            qoh,
                            qty_alloc,
                            qty_planned,
                            status,
                            cube,
                            parent_pallet_id,
                            dmg_ind,
                            inv_uom,
                            abc,
                            abc_gen_date,
                            case_type_tmu,
                            exp_date,
                            exp_ind,
                            inv_date,
                            lot_id,
                            lst_cycle_date,
                            lst_cycle_reason,
                            mfg_date,
                            min_qty,
                            pallet_height,
                            rec_date,
                            rec_id,
                            status,
                            temperature,
                            weight
                       INTO l_inv_info.prod_id,
                            l_inv_info.cust_pref_vendor,
                            l_inv_info.logi_loc,
                            l_inv_info.plogi_loc,
                            l_inv_info.qoh,
                            l_inv_info.qty_alloc,
                            l_inv_info.qty_planned,
                            l_inv_info.status,
                            l_inv_info.cube,
                            l_inv_info.parent_pallet_id,
                            l_inv_info.dmg_ind,
                            l_inv_info.inv_uom,
                            l_inv_info.abc,
                            l_inv_info.abc_gen_date,
                            l_inv_info.case_type_tmu,
                            l_inv_info.exp_date,
                            l_inv_info.exp_ind,
                            l_inv_info.inv_date,
                            l_inv_info.lot_id,
                            l_inv_info.lst_cycle_date,
                            l_inv_info.lst_cycle_reason,
                            l_inv_info.mfg_date,
                            l_inv_info.min_qty,
                            l_inv_info.pallet_height,
                            l_inv_info.rec_date,
                            l_inv_info.rec_id,
                            l_inv_info.status,
                            l_inv_info.temperature,
                            l_inv_info.weight
                       FROM inv
                      WHERE logi_loc = lv_logi_loc
                        AND logi_loc = plogi_loc
                        AND prod_id = l_ml_replenishment.v_prod_id;

                     l_inv_info.logi_loc    := l_ml_replenishment.v_pallet_id;
                     l_inv_info.plogi_loc   := l_ml_replenishment.v_dest_loc;
                     l_inv_info.qty_alloc        := 0;
                     l_inv_info.qty_planned      := ln_replen_qty;
                     l_inv_info.inv_uom          := 1;        -- 5/19/06
                     l_inv_info.qoh              := 0;
                     l_inv_info.CUBE             := 999;
                     l_inv_info.parent_pallet_id := NULL;
                     l_inv_info.dmg_ind          := NULL;

                     p_insert_inv(l_inv_info, o_status);
                  ELSE
                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Error in excuting p_insert_replen';

                     pl_text_log.ins_msg ('FATAL',
                                          lv_fname,
                                          lv_msg_text,
                                          NULL,
                                          NULL);
                     o_status := ct_failure;
                  END IF;
               ELSE
                  lv_msg_text :=
                        'Prog Code: '
                     || ct_program_code
                     || ' Error in executing p_create_NDMForMiniload';

                  pl_text_log.ins_msg('FATAL',
                                      lv_fname,
                                      lv_msg_text,
                                      NULL,
                                      NULL);
                  o_status := ct_failure;
               END IF;
            END IF;
         ELSIF (ln_rule_id = 1) THEN
            --
            -- Replenishment from floating locations
            --
            ln_replen_qty :=
                 i_item_status_info.n_quantity_requested
               - i_item_status_info.n_quantity_available;

            OPEN c_floating_loc(i_item_status_info.v_prod_id,
                                i_item_status_info.v_cust_pref_vendor);

            l_norows := FALSE;

            WHILE ((ln_replen_qty) > 0 AND l_norows = FALSE)
            LOOP
               FETCH c_floating_loc
                INTO float_loc_rec;

               IF (c_floating_loc%ROWCOUNT = 0) THEN
                  lv_msg_text :=
                        'Prog Code: '
                     || ct_program_code
                     || ' No locations found for replenishment';

                  pl_text_log.ins_msg('WARNING',
                                      lv_fname,
                                      lv_msg_text,
                                      NULL,
                                      NULL);
                  o_status := ct_success;
               END IF;

               IF (c_floating_loc%FOUND)
               THEN
                  IF ((ln_replen_qty - float_loc_rec.qoh) > 0)
                  THEN
                     qty_to_be_replenished := float_loc_rec.qoh;
                     ln_replen_qty := ln_replen_qty - float_loc_rec.qoh;
                  ELSE
                     qty_to_be_replenished := ln_replen_qty;
                     ln_replen_qty := 0;
                  END IF;

                  IF (qty_to_be_replenished != case_qty_for_split_rpl_in_splt) THEN
                     qty_to_be_replenished := case_qty_for_split_rpl_in_splt;
                  END IF;

                  l_ml_replenishment.v_prod_id := i_item_status_info.v_prod_id;
                  l_ml_replenishment.v_cust_pref_vendor :=
                                         i_item_status_info.v_cust_pref_vendor;
                  l_ml_replenishment.n_uom := i_item_status_info.n_uom;
                  l_ml_replenishment.n_replen_qty := qty_to_be_replenished;
                  l_ml_replenishment.v_replen_type := 'MNL';
                  l_ml_replenishment.v_src_loc := float_loc_rec.plogi_loc;

                  pl_ml_common.get_induction_loc
                                       (i_item_status_info.v_prod_id,
                                        i_item_status_info.v_cust_pref_vendor,
                                        i_item_status_info.n_uom,
                                        ln_status,
                                        l_ml_replenishment.v_dest_loc);

                  IF (ln_status <> ct_success) THEN
                     lv_msg_text :=
                           'Prog Code: '
                        || ct_program_code
                        || ' Error in getting Induction Location for'
                        || ' the Prod_id: '
                        || i_item_status_info.v_prod_id
                        || ', CPV: '
                        || i_item_status_info.v_cust_pref_vendor
                        || ', UOM: '
                        || i_item_status_info.n_uom;

                     pl_text_log.ins_msg('FATAL',
                                         lv_fname,
                                         lv_msg_text,
                                         NULL,
                                         NULL);
                     RAISE e_indloc_notfound;
                  END IF;

                  SELECT ml_pallet_id_seq.NEXTVAL
                    INTO ln_pallet_seq
                    FROM DUAL;

                  l_ml_replenishment.v_pallet_id :=
                                           l_ml_replenishment.v_src_loc 
                                           || TRIM(TO_CHAR(ln_pallet_seq));
                  lv_msg_text :=
                        'Prog Code: '
                     || ct_program_code
                     || ' Induction Location: '
                     || l_ml_replenishment.v_dest_loc
                     || ' Pallet Id: '
                     || l_ml_replenishment.v_pallet_id;

                  pl_text_log.ins_msg('WARNING',
                                      lv_fname,
                                      lv_msg_text,
                                      NULL,
                                      NULL);
                  o_status := ct_success;
                  lv_msg_text :=
                        'Prog Code:'
                     || ct_program_code
                     || ' Query to select source pikpath when storage ind'
                     || ' is "S", rule_id is 1 and floating loc is present';

                  SELECT pik_path
                    INTO l_ml_replenishment.v_s_pikpath
                    FROM loc
                   WHERE logi_loc = l_ml_replenishment.v_src_loc;

                  lv_msg_text :=
                         'Prog Code:'
                      || ct_program_code
                      || ' Query to select dest pikpath when storage ind'
                      || ' is "S", rule_id is 1 and floating loc is present';

                  SELECT pik_path
                    INTO l_ml_replenishment.v_d_pikpath
                    FROM loc
                   WHERE logi_loc = l_ml_replenishment.v_dest_loc;

                  l_ml_replenishment.v_order_id :=
                                                 i_item_status_info.v_order_id;
                  lv_msg_text :=
                        'Prog Code:'
                     || ct_program_code
                     || ' Query to select order priority when storage ind'
                     || ' is "S", rule_id is 1 and floating loc is present';

                  SELECT MIN (order_priority)
                    INTO l_ml_replenishment.v_priority
                    FROM miniload_order
                   WHERE order_id = i_item_status_info.v_order_id
                     AND message_type = ct_ship_ord_hdr;

                  lv_msg_text :=
                        'Prog Code:'
                     || ct_program_code
                     || ' Prod id: '
                     || i_item_status_info.v_prod_id
                     || ' Priority: '
                     || l_ml_replenishment.v_priority;
                  pl_text_log.ins_msg ('WARNING',
                                       lv_fname,
                                       lv_msg_text,
                                       NULL,
                                       NULL);
                  lv_msg_text :=
                        'Prog Code:'
                     || ct_program_code
                     || ' Query to select exp date and parent pallet id when'
                     || ' storage ind is "S", rule_id is 1 and floating loc'
                     || ' is present';

                  SELECT exp_date,
                         parent_pallet_id
                    INTO l_ml_replenishment.v_exp_date,
                         l_ml_replenishment.v_parent_pallet_id
                    FROM inv
                   WHERE logi_loc = float_loc_rec.logi_loc
                     AND plogi_loc = float_loc_rec.plogi_loc
                     AND prod_id = i_item_status_info.v_prod_id;

                  l_ml_replenishment.v_orig_pallet_id :=
                                                        float_loc_rec.logi_loc;
                  p_insert_replen (l_ml_replenishment, ln_status);

                  IF (ln_status = ct_failure) THEN
                     lv_msg_text := 'Prog Code: '
                                    || ct_program_code
                                    || ' Error in excuting p_insert_replen';

                     pl_text_log.ins_msg ('FATAL',
                                          lv_fname,
                                          lv_msg_text,
                                          NULL,
                                          NULL);
                     o_status := ct_failure;
                  ELSIF (ln_status = ct_success) THEN
                     SELECT REPLACE (USER, 'OPS$')
                       INTO l_inv_info.upd_user
                       FROM DUAL;

                     UPDATE inv
                        SET qty_alloc = qty_alloc + qty_to_be_replenished
                      WHERE plogi_loc = float_loc_rec.plogi_loc
                        AND logi_loc = float_loc_rec.logi_loc;

                     IF (SQL%ROWCOUNT = 0) THEN
                        lv_msg_text :=
                              'Prog Code:'
                           || ct_program_code
                           || ' Inventory Update failed'
                           || ' Key=logi_loc:[ '
                           || float_loc_rec.logi_loc
                           || '] plogi_loc:[|| '
                           || float_loc_rec.plogi_loc
                           || ']';

                        pl_text_log.ins_msg ('FATAL',
                                             lv_fname,
                                             lv_msg_text,
                                             NULL,
                                             NULL);
                     END IF;

                     lv_msg_text :=
                           'Prog Code:'
                        || ct_program_code
                        || ' Query to select inv record when storage ind'
                        || ' is "S", rule_id is 1 and floating loc is present'
                        || ' Key=plogi_loc:[ '
                        || l_ml_replenishment.v_src_loc
                        || '] prod_id:['
                        || l_ml_replenishment.v_prod_id
                        || '] Table = inv';

                     SELECT prod_id, cust_pref_vendor,
                            logi_loc, plogi_loc,
                            qoh, qty_alloc,
                            qty_planned, status,
                            CUBE, parent_pallet_id,
                            dmg_ind, inv_uom,
                            ABC, abc_gen_date,
                            case_type_tmu, exp_date,
                            exp_ind, inv_date,
                            lot_id, lst_cycle_date,
                            lst_cycle_reason, mfg_date,
                            min_qty, pallet_height,
                            rec_date, rec_id,
                            status, temperature,
                            weight
                       INTO l_inv_info.prod_id, l_inv_info.cust_pref_vendor,
                            l_inv_info.logi_loc, l_inv_info.plogi_loc,
                            l_inv_info.qoh, l_inv_info.qty_alloc,
                            l_inv_info.qty_planned, l_inv_info.status,
                            l_inv_info.CUBE, l_inv_info.parent_pallet_id,
                            l_inv_info.dmg_ind, l_inv_info.inv_uom,
                            l_inv_info.ABC, l_inv_info.abc_gen_date,
                            l_inv_info.case_type_tmu, l_inv_info.exp_date,
                            l_inv_info.exp_ind, l_inv_info.inv_date,
                            l_inv_info.lot_id, l_inv_info.lst_cycle_date,
                            l_inv_info.lst_cycle_reason, l_inv_info.mfg_date,
                            l_inv_info.min_qty, l_inv_info.pallet_height,
                            l_inv_info.rec_date, l_inv_info.rec_id,
                            l_inv_info.status, l_inv_info.temperature,
                            l_inv_info.weight
                       FROM inv
                      WHERE plogi_loc = l_ml_replenishment.v_src_loc
                        AND prod_id = l_ml_replenishment.v_prod_id;

                     l_inv_info.logi_loc := l_ml_replenishment.v_pallet_id;
                     l_inv_info.plogi_loc := l_ml_replenishment.v_dest_loc;
                     l_inv_info.qty_alloc := 0;
                     l_inv_info.qty_planned := qty_to_be_replenished;
                     l_inv_info.inv_uom := 1;                       -- 5/19/06
                     l_inv_info.qoh := 0;
                     l_inv_info.CUBE := 999;
                     l_inv_info.parent_pallet_id := NULL;
                     l_inv_info.dmg_ind := NULL;
                     p_insert_inv (l_inv_info, o_status);
                  END IF;
               ELSE
                  l_norows := TRUE;
               END IF;
            END LOOP;

            IF (c_floating_loc%ISOPEN) THEN
               CLOSE c_floating_loc;
            END IF;
         ELSE
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Invalid Rule ID: '
               || ln_rule_id;

            pl_text_log.ins_msg('FATAL', lv_fname, lv_msg_text, NULL, NULL);
            o_status := ct_failure;
         END IF;
      ELSE
         lv_msg_text :=
               'Prog Code:'
            || ct_program_code
            || ' Invalid Storage Type: '
            || i_item_status_info.c_ml_storage_ind;

         pl_text_log.ins_msg('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      END IF;

      IF (o_status IS NULL) THEN
         o_status := ct_success;
      END IF;
   EXCEPTION
      WHEN e_indloc_notfound THEN
         IF (c_floating_loc%ISOPEN) THEN
            CLOSE c_floating_loc;
         END IF;

         lv_msg_text :=
              lv_msg_text || ' ~ This is the message before the error occured';
         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in p_process_ml_replen: induction location not found';

         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         pl_log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN NO_DATA_FOUND THEN
         IF (c_floating_loc%ISOPEN) THEN
            CLOSE c_floating_loc;
         END IF;

         pl_text_log.ins_msg('FATAL', lv_fname, lv_msg_text, SQLCODE,
                             SQLERRM);
         pl_log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE, SQLERRM);
         o_status := ct_failure;
      WHEN OTHERS THEN
         IF (c_floating_loc%ISOPEN) THEN
            CLOSE c_floating_loc;
         END IF;

         lv_msg_text :=
              lv_msg_text || ' ~ This is the message before the error occured';
         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         pl_Log.ins_msg('FATAL', lv_fname, lv_msg_text, SQLCODE, SQLERRM);

         lv_msg_text :=
            'Prog Code: ' || ct_program_code
            || ' Error in p_process_ml_replen';

         pl_text_log.ins_msg('FATAL', lv_fname, lv_msg_text, SQLCODE,
                             SQLERRM);
         pl_log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE, SQLERRM);
         o_status := ct_failure;
   END p_process_ml_replen;


-------------------------------------------------------------------------
-- Procedure:
--    p_create_highprio_order
--
-- Description:
--    This procedure creates a high priority store order.
--
-- Parameters:
--      i_item_status_info: Record type t_item_status_info
--    o_status: return values:
--       0  - No errors.
--       1  - Error occured.
--
-- Exceptions Raised:
--     e_fail - To log error messages
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/27/05          Created as part of the mini-load changes
--    07/20/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--
--                      Call "pl_xdock_op.get_ordd_seq" for the value of ordd.seq
--                      Changed:
--                         SELECT ordd_seq.NEXTVAL
--                           INTO l_ord_hdr_info.v_order_id
--                           FROM DUAL;
--                      to:
--                         l_ord_hdr_info.v_order_id := pl_xdock_op.get_ordd_seq;
--                      Not sure a change was necessary since the ordd seq
--                      was used for the order_id of a high priority store order.
---------------------------------------------------------------------------
   PROCEDURE p_create_highprio_order
     (i_item_status_info   IN       t_item_status_info,
      o_status             OUT      NUMBER,
      i_uom_check          IN       VARCHAR2 DEFAULT 'N')
   IS
      lv_msg_text      VARCHAR2 (1500);
      l_ord_hdr_info   t_new_ship_ord_hdr_info;
      l_ord_dtl_info   t_new_ship_ord_item_inv_info;
      i_ord_tr_info    t_new_ship_ord_trail_info;
      lv_fname         VARCHAR2 (50)             := 'P_CREATE_HIGHPRIO_ORDER';
      e_fail           EXCEPTION;
      ln_status        NUMBER (1)                   := ct_success;
   BEGIN
      --reset the global variable
      pl_text_log.init ('pl_miniload_processing.p_create_highprio_order');
      l_ord_hdr_info.v_msg_type := ct_ship_ord_hdr;

      BEGIN

         l_ord_hdr_info.v_order_id := pl_xdock_op.get_ordd_seq;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            lv_msg_text :=
                  'Prog code: '
               || ct_program_code
               || ' Order id could not be generated from the sequence';
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
            o_status := ct_failure;
            RAISE e_fail;
         WHEN OTHERS THEN
            lv_msg_text :=
                  'Prog code: '
               || ct_program_code
               || ' Order id could not be generated from the sequence';
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
            o_status := ct_failure;
            RAISE e_fail;
      END;

      BEGIN
         SELECT priority_value
           INTO l_ord_hdr_info.n_order_priority
           FROM priority_code
          WHERE priority_code = 'HGH'
            AND unpack_code = 'Y';     -- 3/23/2010  Brian Bent Added
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            lv_msg_text :=
                  'Prog code: '
               || ct_program_code
               || ' Priority Value for  priority code "HGH" was not found in the table priority_code';
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
            o_status := ct_failure;
            RAISE e_fail;
         WHEN OTHERS THEN
            lv_msg_text :=
                  'Prog code: '
               || ct_program_code
               || ' Oracle could not select from PRIORITY_CODE table';
            pl_text_log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
            o_status := ct_failure;
            RAISE e_fail;
      END;

      l_ord_hdr_info.v_description := 'SWMS High Priority Store Order';
      l_ord_hdr_info.v_order_type := ct_store_order;
      l_ord_hdr_info.v_order_date := NULL;
      lv_msg_text :=
            'Prog code: '
         || ct_program_code
         || ' Sending SWMS High Priority Store Order header message to mini-load';
      pl_text_log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);
      pl_log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);
      p_send_new_ship_ord_hdr (l_ord_hdr_info, ln_status);

      IF ln_status = ct_failure THEN
         lv_msg_text :=
               'Prog code: '
            || ct_program_code
            || ' Error in sending high priority store order header message';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         RAISE e_fail;
      END IF;

      lv_msg_text :=
            'Prog code: '
         || ct_program_code
         || ' SWMS High Priority Store Order header message sent to mini-load ';

      pl_text_log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);
      pl_log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);
      l_ord_dtl_info.v_msg_type := ct_ship_ord_inv;
      l_ord_dtl_info.v_order_id := l_ord_hdr_info.v_order_id;
      l_ord_dtl_info.v_order_item_id := i_item_status_info.v_order_item_id;
      l_ord_dtl_info.v_prod_id := i_item_status_info.v_prod_id;
      l_ord_dtl_info.v_cust_pref_vendor :=
                                         i_item_status_info.v_cust_pref_vendor;
      l_ord_dtl_info.n_uom := i_item_status_info.n_uom;
      l_ord_dtl_info.n_qty :=
           i_item_status_info.n_quantity_requested
         - i_item_status_info.n_quantity_available;
      l_ord_dtl_info.n_sku_priority := 0;

      IF (i_item_status_info.n_uom = 1 AND i_uom_check = 'Y') THEN
         l_ord_dtl_info.n_uom := 2;
      END IF;

      p_convert_uom(l_ord_dtl_info.n_uom,
                    l_ord_dtl_info.n_qty,
                    l_ord_dtl_info.v_prod_id,
                    l_ord_dtl_info.v_cust_pref_vendor);

      lv_msg_text :=
                'Prog code: '
             || ct_program_code
             || ' Sending Shipping Order Item by Invetory message sent'
             || ' to miniloader.';

      pl_text_log.ins_msg('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      pl_log.ins_msg('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      p_send_new_ship_ord_item_inv (l_ord_dtl_info, ln_status, 'Y');

      IF ln_status = ct_failure THEN
         lv_msg_text :=
               'Prog code: '
            || ct_program_code
            || ' Error in sending Shipping Order Item by Invetory message';
         pl_text_log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         RAISE e_fail;
      END IF;

      i_ord_tr_info.v_msg_type := ct_ship_ord_trl;
      i_ord_tr_info.v_order_id := l_ord_hdr_info.v_order_id;

      BEGIN
         --5/15/06 - Should only count 'N' records
         SELECT COUNT (order_item_id)
           INTO i_ord_tr_info.n_order_item_id_count
           FROM MINILOAD_ORDER
          WHERE TRIM (MESSAGE_TYPE) = TRIM (ct_ship_ord_inv)
            AND status = 'N'
            AND order_id = i_ord_tr_info.v_order_id;

         IF (i_ord_tr_info.n_order_item_id_count = 0) THEN
            lv_msg_text :=
                  'Prog code: '
               || ct_program_code
               || ' Unable to get order item id count. '
               || ' No NewShippingOrderItemByInventory messages in miniload_order table'
               || ' for the order: '
               || i_ord_tr_info.v_order_id;

            pl_text_log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
            o_status := ct_failure;
            RAISE e_fail;
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            lv_msg_text :=
                  'Prog code: '
               || ct_program_code
               || ' Unable to get order item id count '
               || ' for the order: '
               || i_ord_tr_info.v_order_id;
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM
                                );
            o_status := ct_failure;
            RAISE e_fail;
      END;

      lv_msg_text :=
            'Prog code: '
         || ct_program_code
         || ' Sending Shipping Order trailer message sent to mini-load ';
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      Pl_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      p_send_new_ship_ord_trail (i_ord_tr_info, ln_status);

      IF ln_status = ct_failure THEN
         lv_msg_text :=
               'Prog code: '
            || ct_program_code
            || ' Error in sending Shipping Order trailer message';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         RAISE e_fail;
      END IF;

      lv_msg_text :=
            'Prog code: '
         || ct_program_code
         || ' SWMS High Priority Store Order Sent to mini-load';
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      o_status := ct_success;
   EXCEPTION
      WHEN e_fail THEN
         lv_msg_text :=
               'Prog code: '
            || ct_program_code
            || ' Error in creating high priority store order';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS THEN
         lv_msg_text :=
               'Prog code: '
            || ct_program_code
            || ' Error in creating high priority store order';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_create_highprio_order;

-------------------------------------------------------------------------------
-- Procedure:
--
--   p_create_ndmforminiload
--
-- Description:
--      In case the home slot does not have enough inventory to satisfy the "
--      Shipping Order Item Status" message requirements then this function
--      will be called to create the NDM replenishment to let down the inventory
--      from Reserve location to Home location
--
-- Parameters:
--       i_replenishment  - Replenishment info
--       o_qty_moved      - Quantity available for NDM replenishment
--       o_status         - Return status.
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -------------------------------------------------------
--    12/15/05          Created as part of the mini-load changes
-------------------------------------------------------------------------------
   PROCEDURE p_create_ndmforminiload (
      i_replenishment   IN       t_ml_replenishment,
      o_qty_moved       OUT      INV.qoh%TYPE,
      o_status          OUT      NUMBER
   )
   IS
      l_ml_replenishment     t_ml_replenishment;
      lv_msg_text            VARCHAR2 (1500);
      lv_fname               VARCHAR2 (50)        := 'P_CREATENDMFORMINILOAD';
      l_norows               BOOLEAN              := FALSE;
      e_fail                 EXCEPTION;
      lv_pallet_id           VARCHAR2 (20);
      qty_tobe_replenished   INV.qty_alloc%TYPE;
      ln_replen_qty          REPLENLST.qty%TYPE;
      ln_status              NUMBER (1)           := ct_success;

      CURSOR c_replen (p_prod_id VARCHAR2, p_cpv VARCHAR2, p_dest_loc VARCHAR2)
      IS
         SELECT        i.plogi_loc,
                         (TRUNC (qoh / p.spc)
                          - TRUNC (NVL (qty_alloc, 0) / spc)
                         )
                       * p.spc qoh,
                       i.qty_alloc, i.rec_id, i.lot_id,
                       NVL (i.exp_date, TRUNC (SYSDATE)) exp_date, i.exp_ind,
                       i.inv_date, NVL (i.rec_date, TRUNC (SYSDATE))
                                                                    rec_date,
                       NVL (i.mfg_date, TRUNC (SYSDATE)) mfg_date,
                       i.logi_loc, p.min_qty,
                       NVL (i.exp_date, TRUNC (SYSDATE)) sort_exp_date,
                       l.UOM, l.pik_path, i.parent_pallet_id
                  FROM LOC l, PM p, INV i, LZONE lz, ZONE z
                 WHERE i.prod_id = p_prod_id
                   AND i.cust_pref_vendor = p_cpv
                   AND i.status = 'AVL'
                   AND i.plogi_loc != p_dest_loc
                   AND l.logi_loc = i.plogi_loc
                   AND p.prod_id = i.prod_id
                   AND p.cust_pref_vendor = i.cust_pref_vendor
                   AND l.logi_loc = lz.logi_loc
                   AND lz.zone_id = z.zone_id
                   AND rule_id != 3
                   AND ZONE_TYPE = 'PUT'
                   AND   (TRUNC (qoh / p.spc)
                          - TRUNC (NVL (qty_alloc, 0) / spc)
                         )
                       * p.spc > 0
              ORDER BY NVL (DECODE (i.plogi_loc,
                                    i.logi_loc, (SYSDATE + 9999),
                                    i.exp_date
                                   ),
                            TRUNC (SYSDATE)
                           ),
                       i.qoh,
                       i.logi_loc
         FOR UPDATE OF qoh;

      r_replen_data          c_replen%ROWTYPE;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_create_ndmforminiload');

      OPEN c_replen (i_replenishment.v_prod_id,
                     i_replenishment.v_cust_pref_vendor,
                     i_replenishment.v_dest_loc
                    );

      ln_replen_qty := i_replenishment.n_replen_qty;

      WHILE (ln_replen_qty > 0 AND l_norows = FALSE)
      LOOP
         FETCH c_replen
          INTO r_replen_data;

         IF c_replen%ROWCOUNT = 0
         THEN
            lv_msg_text :=
                  'Prog code: '
               || ct_program_code
               || ' Inventory insufficient to fulfill NDM Replenishment, for prod_id: '
               || i_replenishment.v_prod_id;
            Pl_Text_Log.ins_msg ('WARN', lv_fname, lv_msg_text, NULL, NULL);
            RAISE e_fail;
         END IF;

         -- For each source location where the product is found insert a replenishment task
         -- with the selected location as source location.
         IF c_replen%FOUND
         THEN
            --deduct the quantity to be replenised, for each location found till the
            --quantity to be replenished is satisfied.
            qty_tobe_replenished := r_replen_data.qoh;

            IF (ln_replen_qty - r_replen_data.qoh) > 0
            THEN
               ln_replen_qty := ln_replen_qty - r_replen_data.qoh;
            ELSE
               ln_replen_qty := 0;
            END IF;

            l_ml_replenishment.v_prod_id := i_replenishment.v_prod_id;
            l_ml_replenishment.v_cust_pref_vendor :=
                                            i_replenishment.v_cust_pref_vendor;
            l_ml_replenishment.n_uom := i_replenishment.n_uom;
            l_ml_replenishment.v_replen_type := 'NDM';
            l_ml_replenishment.v_src_loc := r_replen_data.plogi_loc;
            l_ml_replenishment.v_dest_loc := i_replenishment.v_dest_loc;
            l_ml_replenishment.v_pallet_id := r_replen_data.logi_loc;

            BEGIN
               SELECT pik_path
                 INTO l_ml_replenishment.v_s_pikpath
                 FROM LOC
                WHERE logi_loc = l_ml_replenishment.v_src_loc;
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  lv_msg_text :=
                        'Prog code: '
                     || ct_program_code
                     || ' TABLE=loc'
                     || ' ACTION=SELECT MESSAGE= Src Pikpath not found in loc table for location'
                     || ' Key=logi_loc:['
                     || l_ml_replenishment.v_src_loc
                     || ']';
                  Pl_Text_Log.ins_msg ('FATAL',
                                       lv_fname,
                                       lv_msg_text,
                                       SQLCODE,
                                       SQLERRM
                                      );
                  ln_status := ct_failure;
               WHEN OTHERS
               THEN
                  lv_msg_text :=
                        'Prog code: '
                     || ct_program_code
                     || ' TABLE=loc'
                     || ' ACTION=SELECT MESSAGE= Error in retrieving src pikpath '
                     || ' Key=logi_loc:['
                     || l_ml_replenishment.v_src_loc
                     || ']';
                  Pl_Text_Log.ins_msg ('FATAL',
                                       lv_fname,
                                       lv_msg_text,
                                       SQLCODE,
                                       SQLERRM
                                      );
                  ln_status := ct_failure;
            END;

            BEGIN
               IF (ln_status != ct_failure)
               THEN
                  SELECT pik_path
                    INTO l_ml_replenishment.v_d_pikpath
                    FROM LOC
                   WHERE logi_loc = l_ml_replenishment.v_dest_loc;
               END IF;
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  lv_msg_text :=
                        'Prog code: '
                     || ct_program_code
                     || ' ACTION=SELECT MESSAGE= Dest Pikpath not found in loc table for location.'
                     || ' Key=Logiloc:['
                     || l_ml_replenishment.v_dest_loc
                     || ']';
                  Pl_Text_Log.ins_msg ('FATAL',
                                       lv_fname,
                                       lv_msg_text,
                                       SQLCODE,
                                       SQLERRM
                                      );
                  ln_status := ct_failure;
               WHEN OTHERS
               THEN
                  lv_msg_text :=
                        'Prog code: '
                     || ct_program_code
                     || ' TABLE=loc'
                     || ' ACTION=SELECT MESSAGE= Error in retrieving dest pikpath '
                     || ' Key=Logiloc:['
                     || l_ml_replenishment.v_dest_loc
                     || ']';
                  Pl_Text_Log.ins_msg ('FATAL',
                                       lv_fname,
                                       lv_msg_text,
                                       SQLCODE,
                                       SQLERRM
                                      );
                  o_status := ct_failure;
                  ln_status := ct_failure;
            END;

            l_ml_replenishment.v_order_id := i_replenishment.v_order_id;
            l_ml_replenishment.v_priority := i_replenishment.v_priority;
            l_ml_replenishment.v_exp_date := r_replen_data.exp_date;
            l_ml_replenishment.v_parent_pallet_id :=
                                                r_replen_data.parent_pallet_id;
            l_ml_replenishment.n_replen_qty := qty_tobe_replenished;
            l_ml_replenishment.v_orig_pallet_id := r_replen_data.logi_loc;
            -- Insert a replenishment task for each location.
            p_insert_replen (l_ml_replenishment, ln_status);

            IF ln_status = ct_failure
            THEN
               lv_msg_text :=
                     'Prog code: '
                  || ct_program_code
                  || ' Replenishment task creation failed';
               Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL,
                                    NULL);
               RAISE e_fail;
            END IF;

            UPDATE INV
               SET qty_alloc = qty_alloc + qty_tobe_replenished
             WHERE plogi_loc = r_replen_data.plogi_loc
               AND logi_loc = r_replen_data.logi_loc;

            IF (SQL%ROWCOUNT = 0)
            THEN
               lv_msg_text :=
                     'Prog Code:'
                  || ct_program_code
                  || ' Inventory Update failed'
                  || ' Key=logi_loc:[ '
                  || r_replen_data.logi_loc
                  || '] plogi_loc:[|| '
                  || r_replen_data.plogi_loc
                  || ']';
               Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL,
                                    NULL);
            END IF;

            UPDATE INV
               SET qty_planned = qty_planned + qty_tobe_replenished
             WHERE plogi_loc = l_ml_replenishment.v_dest_loc
               AND plogi_loc = logi_loc;

            IF (SQL%ROWCOUNT = 0)
            THEN
               lv_msg_text :=
                     'Prog Code:'
                  || ct_program_code
                  || ' Inventory Update failed'
                  || ' Key=logi_loc:[ '
                  || l_ml_replenishment.v_dest_loc
                  || ']';
               Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL,
                                    NULL);
            END IF;
         ELSE
            l_norows := TRUE;
         END IF;
      END LOOP;   -- end WHILE (ln_replen_qty > 0 AND l_norows = FALSE)

      IF c_replen%ISOPEN THEN
         CLOSE c_replen;
      END IF;

      o_qty_moved := i_replenishment.n_replen_qty - ln_replen_qty;

      IF ln_replen_qty > 0 THEN
         lv_msg_text :=
               'Prog code: '
            || ct_program_code
            || ' Inventory for NDM Replenishment short by : '
            || ln_replen_qty;
         Pl_Text_Log.ins_msg ('WARN', lv_fname, lv_msg_text, NULL, NULL);
      ELSE
         lv_msg_text :=
               'Prog code: '
            || ct_program_code
            || ' NDM Replenishment created for mini-load';
         Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      END IF;

      o_status := ln_status;
   EXCEPTION
      WHEN e_fail THEN
         IF c_replen%ISOPEN THEN
            CLOSE c_replen;
         END IF;

         lv_msg_text :=
               'Prog code: '
            || ct_program_code
            || ' NDM Replenishment for mini-load failed  ';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         o_status := ct_failure;
      WHEN OTHERS THEN
         IF c_replen%ISOPEN
         THEN
            CLOSE c_replen;
         END IF;

         lv_msg_text :=
               'Prog code: '
            || ct_program_code
            || ' NDM Replenishment for mini-load failed ';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_create_ndmforminiload;

-------------------------------------------------------------------------------
-- Procedure:
--    p_insert_replen
--
-- Description:
--     This procedure will be used to create the replenishment record.
--
-- Parameters:
--    i_ml_replenishment: Input details to create the replenlst record.
--    o_status: Return Values
--       0  - No errors.
--       1  - Error occured.
--
-- Exceptions Raised:
--    None.  If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -------------------------------------------------------
--    12/15/05          Created as part of the mini-load changes
-------------------------------------------------------------------------------
   PROCEDURE p_insert_replen (
      i_ml_replenishment   IN       t_ml_replenishment,
      o_status             OUT      NUMBER
   )
   IS
      lv_status     REPLENLST.status%TYPE;
      ln_task_id    REPLENLST.task_id%TYPE;
      ln_spc        PM.spc%TYPE;
      lv_msg_text   VARCHAR2 (1500);
      lv_fname      VARCHAR2 (50)            := 'P_INSERT_REPLEN';
   BEGIN
      lv_status := 'NEW';
      Pl_Text_Log.init ('pl_miniload_processing.p_insert_replen');

      SELECT NVL (spc, 1)
        INTO ln_spc
        FROM PM
       WHERE prod_id = i_ml_replenishment.v_prod_id
         AND cust_pref_vendor = i_ml_replenishment.v_cust_pref_vendor;

      SELECT repl_id_seq.NEXTVAL
        INTO ln_task_id
        FROM DUAL;

      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Inserting into replenlst - '
         || ' Task Id: '
         || ln_task_id
         || ',Prod_id: '
         || i_ml_replenishment.v_prod_id
         || ',Cust_pref_vendor: '
         || i_ml_replenishment.v_cust_pref_vendor
         || ',UOM: '
         || i_ml_replenishment.n_uom
         || ',Replenisment type: '
         || i_ml_replenishment.v_replen_type
         || ',Pallet id: '
         || i_ml_replenishment.v_pallet_id;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      Pl_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);

      INSERT INTO REPLENLST
                  (task_id, prod_id,
                   cust_pref_vendor, UOM,
                   qty,
                   TYPE, status,
                   src_loc,
                   pallet_id,
                   dest_loc,
                   s_pikpath,
                   d_pikpath, batch_no,
                   order_id, gen_uid,
                   gen_date,
                   exp_date,
                   parent_pallet_id,
                   priority,
                   orig_pallet_id
                  )
           VALUES (ln_task_id, i_ml_replenishment.v_prod_id,
                   i_ml_replenishment.v_cust_pref_vendor, 2,
                   CEIL (i_ml_replenishment.n_replen_qty / ln_spc),
                   i_ml_replenishment.v_replen_type, lv_status,
                   i_ml_replenishment.v_src_loc,
                   i_ml_replenishment.v_pallet_id,
                   i_ml_replenishment.v_dest_loc,
                   i_ml_replenishment.v_s_pikpath,
                   i_ml_replenishment.v_d_pikpath, 0,
                   i_ml_replenishment.v_order_id, REPLACE (USER, 'OPS$'),
                   TRUNC (SYSDATE),
                   i_ml_replenishment.v_exp_date,
                   i_ml_replenishment.v_parent_pallet_id,
                   i_ml_replenishment.v_priority,
                   i_ml_replenishment.v_orig_pallet_id
                  );

      lv_msg_text :=
             'Prog Code: ' || ct_program_code || ' Replenishment task created';
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      o_status := ct_success;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' No spc found'
            || ' Table=pm'
            || ' KEY:[prod_id,cpv]=['
            || i_ml_replenishment.v_prod_id
            || ','
            || i_ml_replenishment.v_cust_pref_vendor
            || ']';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in insert into replenlst';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         Pl_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE, SQLERRM);
         o_status := ct_failure;
   END p_insert_replen;

-------------------------------------------------------------------------------
-- Procedure:
--    p_insert_dummy_itm_status
--
-- Description:
--     This Procedure inserts a dummy shipping order item status message in
--     the miniload_order table for history order processing
--
-- Parameters:
--    i_item_status : Input details to create 'shipping order item status' message.
--    o_status: Return Values
--       0  - No errors.
--       1  - Error occured.
--
-- Exceptions Raised:
--    None.  If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -------------------------------------------------------
--    3/01/06           Created as part of the mini-load changes
-------------------------------------------------------------------------------
   PROCEDURE p_insert_dummy_itm_status (
      i_item_status   IN       t_item_status_info,
      o_status        OUT      NUMBER
   )
   IS
      l_miniload_info   t_miniload_info;
      l_msg_id          NUMBER (7);
      l_msg_status      MINILOAD_ORDER.status%TYPE   := 'I';
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)          := 'P_INSERT_DUMMY_ITM_STATUS';
      lv_ml_system        MINILOAD_ORDER.ML_SYSTEM%TYPE;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_insert_dummy_itm_status');
      l_miniload_info.vt_item_status_info := i_item_status;
      l_miniload_info.vt_item_status_info.v_msg_type := ct_ship_ord_status;
      l_miniload_info.vt_item_status_info.v_sku :=
         f_generate_sku
                      (l_miniload_info.vt_item_status_info.n_uom,
                       l_miniload_info.vt_item_status_info.v_prod_id,
                       l_miniload_info.vt_item_status_info.v_cust_pref_vendor
                      );
      l_miniload_info.v_data :=
            RPAD (ct_ship_ord_status, ct_msg_type_size, ' ')
         || RPAD (l_miniload_info.vt_item_status_info.v_order_id,
                  ct_order_id_size,
                  ' '
                 )
         || RPAD (l_miniload_info.vt_item_status_info.v_order_item_id,
                  ct_order_item_id_size,
                  ' '
                 )
         || l_miniload_info.vt_item_status_info.v_sku
         || LPAD (l_miniload_info.vt_item_status_info.n_quantity_requested,
                  ct_qty_size,
                  '0'
                 )
         || LPAD (l_miniload_info.vt_item_status_info.n_quantity_available,
                  ct_qty_size,
                  '0'
                 );
      /* Insert the miniload system to which the item belongs */
      lv_ml_system :=
             f_find_ml_system(l_miniload_info.vt_item_status_info.v_prod_id,
                       l_miniload_info.vt_item_status_info.v_cust_pref_vendor);
      
      INSERT INTO MINILOAD_ORDER
                  (message_id, MESSAGE_TYPE,
                   prod_id,
                   cust_pref_vendor,
                   UOM,
                   order_id,
                   order_item_id,
                   quantity_requested,
                   quantity_available,
                   status, ml_data,
                   ml_data_len, source_system,ml_system
                  )
           VALUES (miniload_message_seq.NEXTVAL, ct_ship_ord_status,
                   l_miniload_info.vt_item_status_info.v_prod_id,
                   l_miniload_info.vt_item_status_info.v_cust_pref_vendor,
                   l_miniload_info.vt_item_status_info.n_uom,
                   l_miniload_info.vt_item_status_info.v_order_id,
                   l_miniload_info.vt_item_status_info.v_order_item_id,
                   l_miniload_info.vt_item_status_info.n_quantity_requested,
                   l_miniload_info.vt_item_status_info.n_quantity_available,
                   'I', l_miniload_info.v_data,
                   LENGTH (l_miniload_info.v_data), 'MNL',lv_ml_system
                  );

      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Dummy ShippingOrderItemStatus message inserted';
         
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      
      o_status := ct_success;
      
   EXCEPTION
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in inserting dummy ship order item status message';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   
   END p_insert_dummy_itm_status;

-------------------------------------------------------------------------------
-- Procedure:
--    p_insert_inv
--
-- Description:
--     This procedure will be used to create an inventory record.
--
-- Parameters:
--    i_inv_info: Input details to create the inv record.
--    o_status: Return Values
--       0  - No errors.
--       1  - Error occured.
--
-- Exceptions Raised:
--    None.  If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -------------------------------------------------------
--    12/15/05          Created as part of the mini-load changes
-------------------------------------------------------------------------------
   PROCEDURE p_insert_inv (
      i_inv_info   IN       INV%ROWTYPE DEFAULT NULL,
      o_status     OUT      NUMBER
   )
   IS
      lv_msg_text   VARCHAR2 (1500);
      lv_fname      VARCHAR2 (50)   := 'P_INSERT_INV';
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.p_insert_inv');

      INSERT INTO INV
                  (prod_id, cust_pref_vendor,
                   logi_loc, plogi_loc,
                   qoh, qty_alloc,
                   qty_planned, status,
                   CUBE, parent_pallet_id,
                   dmg_ind, inv_uom, ABC,
                   abc_gen_date, case_type_tmu,
                   exp_date, exp_ind,
                   inv_date, lot_id,
                   lst_cycle_date, lst_cycle_reason,
                   mfg_date, min_qty,
                   pallet_height, rec_date,
                   rec_id, temperature,
                   weight
                  )
           VALUES (i_inv_info.prod_id, i_inv_info.cust_pref_vendor,
                   i_inv_info.logi_loc, i_inv_info.plogi_loc,
                   i_inv_info.qoh, i_inv_info.qty_alloc,
                   i_inv_info.qty_planned, i_inv_info.status,
                   i_inv_info.CUBE, i_inv_info.parent_pallet_id,
                   i_inv_info.dmg_ind, i_inv_info.inv_uom, i_inv_info.ABC,
                   i_inv_info.abc_gen_date, i_inv_info.case_type_tmu,
                   i_inv_info.exp_date, i_inv_info.exp_ind,
                   i_inv_info.inv_date, i_inv_info.lot_id,
                   i_inv_info.lst_cycle_date, i_inv_info.lst_cycle_reason,
                   i_inv_info.mfg_date, i_inv_info.min_qty,
                   i_inv_info.pallet_height, i_inv_info.rec_date,
                   i_inv_info.rec_id, i_inv_info.temperature,
                   i_inv_info.weight
                  );

      lv_msg_text :=
            'Prog Code: '
         || ct_program_code
         || ' Insertion in inv - '
         || ' Prod Id: '
         || i_inv_info.prod_id
         || ' CPV: '
         || i_inv_info.cust_pref_vendor
         || ' UOM: '
         || i_inv_info.inv_uom
         || ' Pallet Id: '
         || i_inv_info.logi_loc;
      Pl_Text_Log.ins_msg ('WARNING', lv_fname, lv_msg_text, NULL, NULL);
      o_status := ct_success;
   EXCEPTION
      WHEN OTHERS
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in inserting into inv. Prod id: '
            || i_inv_info.prod_id
            || ' Src Loc: '
            || i_inv_info.plogi_loc
            || ' Carrier id: '
            || i_inv_info.logi_loc;
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         o_status := ct_failure;
   END p_insert_inv;

-------------------------------------------------------------------------------
-- PROCEDURE
--    resend_miniload_message
--
-- Description:
--     This procedure resends a miniload message to the miniloader by
--     updating the status to N.   The calling program needs to do the commit.
--
--     For a message to be resent the following must be met:
--     1.  The message is in the miniload message table.
--     2.  The source system must be SWMS.
--     3.  The status must be S or F.
--
--     Note:  What is actually being done is flagging the message to be
--            resent be setting the status to N.  There is another program
--            running every view secondJs lookijng for messages with a status
--            of N and sending these to the miniloader.
--
-- Parameters:
--    i_message_id         - The message id of the message to resend.
--    o_message_resent_bln - Desigates if the message was resent successfully.
--                              TRUE - the message was resent successfully.
--                              FALSE - the message was not resent successfully.
--                                      o_msg will be populated with why it
--                                      was not resent.
--    o_msg                - Message stating why the message was not resent
--                           if it was not resent successfully.  The calling
--                           program needs should ignore the message if the
--                           message was resent successfully.
--
-- Exceptions Raised:
--    None.  i_message_resent_bln and o_msg are set when an error occurs.
--
-- Called by:
--    Form mm3sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/07/06 prpbcb   Created.
----------------------------------------------------------------------------
   PROCEDURE resend_miniload_message (
      i_message_id           IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_message_resent_bln   OUT      BOOLEAN,
      o_msg                  OUT      VARCHAR2
   )
   IS
      l_object_name                 VARCHAR2 (61)
                                 := gl_pkg_name || '.resend_miniload_message';
      l_message_can_be_resent_bln   BOOLEAN;
      l_status                      MINILOAD_MESSAGE.status%TYPE;
      e_record_locked               EXCEPTION;
      PRAGMA EXCEPTION_INIT (e_record_locked, -54);
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.resend_miniload_message');
      --
      -- See if the message can be resent.  If it cannot then o_msg will
      -- be populated with why.
      --
      can_ml_message_be_resent (i_message_id,
                                l_message_can_be_resent_bln,
                                o_msg
                               );

      IF (l_message_can_be_resent_bln = TRUE)
      THEN
         --
         -- The message can be resent.  Resend it.
         --
         --
         -- Lock the record.
         --
         SELECT     status
               INTO l_status
               FROM MINILOAD_MESSAGE
              WHERE message_id = i_message_id
         FOR UPDATE NOWAIT;

         UPDATE MINILOAD_MESSAGE
            SET status = 'N'
          WHERE message_id = i_message_id AND l_status IN ('F', 'S');

         -- Note:  If we change what status can be resent then other
         --        places in the package need changing too.
         IF (SQL%FOUND)
         THEN
            --
            -- The message was resent (actually it was flagged to be resent).
            --
            o_message_resent_bln := TRUE;
            --
            -- Log resending the message.
            --
            Pl_Text_Log.ins_msg ('INFO',
                                 l_object_name,
                                    'Message '
                                 || TO_CHAR (i_message_id)
                                 || ' resent to miniloader.',
                                 NULL,
                                 NULL);
         ELSE
            --
            -- No record was updated.
            -- Possibly because the status was changed by another user.'
            --
            o_message_resent_bln := FALSE;
            o_msg :=
                  'Message ID['
               || TO_CHAR (i_message_id)
               || ']'
               || '  Status[ '
               || l_status
               || ']'
               || '  Resend failed.  No record was updated.';
            --
            -- Log this.
            --
            Pl_Text_Log.ins_msg
                           ('WARN',
                            l_object_name,
                               o_msg
                            || '  Status may have been changed by another user.',
                            NULL,
                            NULL);
         END IF;
      ELSE
         --
         -- The message cannot be resent.
         -- o_msg has aleady been populated with why it cannot.
         --
         o_message_resent_bln := FALSE;
      END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         --
         -- The message ID was not in the miniload_message table.
         --
         o_message_resent_bln := FALSE;
         o_msg :=
               'Message ID['
            || i_message_id
            || ']'
            || ' is not a valid message ID.  Resend failed.';
      WHEN e_record_locked
      THEN
         --
         -- Someone else has the record locked.
         --
         o_message_resent_bln := FALSE;
         o_msg :=
               'Message ID['
            || i_message_id
            || ']'
            || '  Record locked by another user.  Cannot resend message.'
            || '  Try again later.';
      WHEN OTHERS
      THEN
         --
         -- Got some error.
         --
         o_message_resent_bln := FALSE;
         o_msg :=
               'Message ID['
            || TO_CHAR (i_message_id)
            || ']'
            || '  Resend failed.  SQLCODE '
            || SQLCODE;
         -- Log the error.
         Pl_Text_Log.ins_msg ('WARNING',
                              l_object_name,
                              o_msg,
                              SQLCODE,
                              SQLERRM
                             );
   END resend_miniload_message;

-------------------------------------------------------------------------------
-- PROCEDURE
--    can_ML_message_be_resent
--
-- Description:
--     This procedure determines if a miniload message can be resent back
--     to the miniloader
--
--     For a message to be resent the following must be met:
--     1.  The message is in the miniload message table.
--     2.  The source system must be SWMS.
--     3.  The status must be S or F.
--
-- Parameters:
--    i_message_id  - The message id of the message to resend.
--    o_message_can_be_resent_bln - Desigates if the message can be resent.
--                  Values:
--                     TRUE  - the message can be resent.
--                     FALSE - the message cannot be reset.
--                             o_msg will be populated with why it
--                             cannot be resent.
--    o_msg         - Message stating why the message cannot be resent
--                    if it cannot be resent.
--
-- Exceptions Raised:
--   The when others propagates the exception.
--
--
-- Called by:
--    resend_miniload_message
--    Function can_ML_message_be_resent
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/07/06 prpbcb   Created.
----------------------------------------------------------------------------
   PROCEDURE can_ml_message_be_resent (
      i_message_id                  IN       MINILOAD_MESSAGE.message_id%TYPE,
      o_message_can_be_resent_bln   OUT      BOOLEAN,
      o_msg                         OUT      VARCHAR2
   )
   IS
      l_object_name     VARCHAR2 (61)
                                := gl_pkg_name || '.can_ML_message_be_resent';
      l_source_system   MINILOAD_MESSAGE.source_system%TYPE;
      l_status          MINILOAD_MESSAGE.status%TYPE;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.resend_miniload_message');

      --
      -- Get message info to determine if it can be resent.
      --
      SELECT source_system, status
        INTO l_source_system, l_status
        FROM MINILOAD_MESSAGE
       WHERE message_id = i_message_id;

      --
      -- Determine if the message can be resent based on
      -- the source system and its current status.
      --
      IF (l_source_system = 'SWM')
      THEN
         IF (l_status IN ('F', 'S'))
         THEN
            --
            -- The message status is failed or success.  It can be resent.
            -- Note:  If we change what status can be resent then other
            --        places in the package need changing too.
            --
            o_message_can_be_resent_bln := TRUE;
         ELSE
            --
            -- The message has a status that cannot be resent.
            --
            o_message_can_be_resent_bln := FALSE;
            o_msg :=
                  'Message ID['
               || TO_CHAR (i_message_id)
               || ']'
               || '  Message has status ['
               || l_status
               || ']'
               || ' which cannot be resent.';
         END IF;
      ELSE
         --
         -- The source system is not SWMS.  The message cannot be resent.
         --
         o_message_can_be_resent_bln := FALSE;
         o_msg :=
               'Message ID['
            || TO_CHAR (i_message_id)
            || ']'
            || '  The source system is ['
            || l_source_system
            || '].'
            || '  The message cannot be resent.';
      END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         --
         -- The message ID was not in the miniload_message table.
         --
         o_message_can_be_resent_bln := FALSE;
         o_msg :=
               'Message ID['
            || i_message_id
            || ']'
            || ' is not a valid message ID.  Resend failed.';
      WHEN OTHERS
      THEN
         --
         -- Got some error.
         --
         -- Log the error.
         Pl_Text_Log.ins_msg ('WARNING',
                              l_object_name,
                              o_msg,
                              SQLCODE,
                              SQLERRM
                             );
         RAISE;
   END can_ml_message_be_resent;

-------------------------------------------------------------------------------
-- FUNCTION
--    can_ML_message_be_resent
--
-- Description:
--     This function determines if a miniload message can be resent back
--     to the miniloader.
--
-- Parameters:
--    i_message_id         - The message id of the message.
--
-- Return Values:
--    TRUE   - The message can be resent back to the miniloader.
--    FALSE  - The message cannot be resent back to the miniloader.
--
-- Exceptions Raised:
--   The when others propagates the exception.
--
-- Called by:
--    - Form mm3sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/07/06 prpbcb   Created.
----------------------------------------------------------------------------
   FUNCTION can_ml_message_be_resent (
      i_message_id   IN   MINILOAD_MESSAGE.message_id%TYPE
   )
      RETURN BOOLEAN
   IS
      l_object_name                 VARCHAR2 (61)
                                := gl_pkg_name || '.can_ML_message_be_resent';
      l_message_can_be_resent_bln   BOOLEAN;
      l_msg                         VARCHAR2 (100);    -- Place to store msg.
   BEGIN
      Pl_Text_Log.init ('pl_miniload_processing.can_ML_message_be_resent');
      can_ml_message_be_resent (i_message_id,
                                l_message_can_be_resent_bln,
                                l_msg
                               );
      RETURN (l_message_can_be_resent_bln);
   EXCEPTION
      WHEN OTHERS
      THEN
         -- Log the error.
         Pl_Text_Log.ins_msg ('WARNING',
                              l_object_name,
                              'Error',
                              SQLCODE,
                              SQLERRM
                             );
         RAISE;
   END can_ml_message_be_resent;

-------------------------------------------------------------------------------
-- FUNCTION
--    f_get_ct_exp_rec
--
-- Description:
--     Returns constant CT_EXP_REC.
--     Designed to use in forms 6i since a package constant cannot be
--     directly accessed.
--
-- Parameters:
--    None
--
-- Return Values:
--    Constant CT_EXP_REC
--
-- Exceptions Raised:
--    The when others propagates the exception.
--
-- Called by:
--    - Form mm3sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/15/07 prpbcb   Created.
----------------------------------------------------------------------------
   FUNCTION f_get_ct_exp_rec
      RETURN VARCHAR2
   IS
      l_object_name   VARCHAR2 (61) := gl_pkg_name || '.f_get_ct_exp_rec';
   BEGIN
      RETURN ct_exp_rec;
   EXCEPTION
      WHEN OTHERS
      THEN
         -- Log the error.
         Pl_Text_Log.ins_msg ('WARNING',
                              l_object_name,
                              'Error',
                              SQLCODE,
                              SQLERRM
                             );
         RAISE;
   END f_get_ct_exp_rec;

-------------------------------------------------------------------------------
-- FUNCTION
--    f_get_ct_new_sku
--
-- Description:
--     Returns constant CT_NEW_SKU.
--     Designed to use in forms 6i since a package constant cannot be
--     directly accessed.
--
-- Parameters:
--    None
--
-- Return Values:
--    Constant CT_NEW_SKU
--
-- Exceptions Raised:
--    The when others propagates the exception.
--
-- Called by:
--    - Form mm3sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/15/07 prpbcb   Created.
----------------------------------------------------------------------------
   FUNCTION f_get_ct_new_sku
      RETURN VARCHAR2
   IS
      l_object_name   VARCHAR2 (61) := gl_pkg_name || '.f_get_ct_new_sku';
   BEGIN
      RETURN ct_new_sku;
   EXCEPTION
      WHEN OTHERS
      THEN
         -- Log the error.
         Pl_Text_Log.ins_msg ('WARNING',
                              l_object_name,
                              'Error',
                              SQLCODE,
                              SQLERRM
                             );
         RAISE;
   END f_get_ct_new_sku;

-------------------------------------------------------------------------------
-- FUNCTION
--    f_get_ct_modify_sku
--
-- Description:
--     Returns constant CT_MODIFY_SKU.
--     Designed to use in forms 6i since a package constant cannot be
--     directly accessed.
--
-- Parameters:
--    None
--
-- Return Values:
--    Constant CT_MODIFY_SKU
--
-- Exceptions Raised:
--    The when others propagates the exception.
--
-- Called by:
--    - Form mm3sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/15/07 prpbcb   Created.
----------------------------------------------------------------------------
   FUNCTION f_get_ct_modify_sku
      RETURN VARCHAR2
   IS
      l_object_name   VARCHAR2 (61) := gl_pkg_name || '.f_get_ct_modify_sku';
   BEGIN
      RETURN ct_modify_sku;
   EXCEPTION
      WHEN OTHERS
      THEN
         -- Log the error.
         Pl_Text_Log.ins_msg ('WARNING',
                              l_object_name,
                              'Error',
                              SQLCODE,
                              SQLERRM
                             );
         RAISE;
   END f_get_ct_modify_sku;

-------------------------------------------------------------------------------
-- FUNCTION
--    f_get_ct_delete_sku
--
-- Description:
--     Returns constant CT_DELETE_SKU.
--     Designed to use in forms 6i since a package constant cannot be
--     directly accessed.
--
-- Parameters:
--    None
--
-- Return Values:
--    Constant CT_DELETE_SKU
--
-- Exceptions Raised:
--    The when others propagates the exception.
--
-- Called by:
--    - Form mm3sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/15/07 prpbcb   Created.
----------------------------------------------------------------------------
   FUNCTION f_get_ct_delete_sku
      RETURN VARCHAR2
   IS
      l_object_name   VARCHAR2 (61) := gl_pkg_name || '.f_get_ct_delete_sku';
   BEGIN
      RETURN ct_delete_sku;
   EXCEPTION
      WHEN OTHERS
      THEN
         -- Log the error.
         Pl_Text_Log.ins_msg ('WARNING',
                              l_object_name,
                              'Error',
                              SQLCODE,
                              SQLERRM
                             );
         RAISE;
   END f_get_ct_delete_sku;

-------------------------------------------------------------------------------
-- FUNCTION
--    f_get_ct_inv_upd_carr
--
-- Description:
--     Returns constant CT_INV_UPD_CARR.
--     Designed to use in forms 6i since a package constant cannot be
--     directly accessed.
--
-- Parameters:
--    None
--
-- Return Values:
--    Constant CT_INV_UPD_CARR.
--
-- Exceptions Raised:
--    The when others propagates the exception.
--
-- Called by:
--    - Form mm3sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/15/07 prpbcb   Created.
----------------------------------------------------------------------------
   FUNCTION f_get_ct_inv_upd_carr
      RETURN VARCHAR2
   IS
      l_object_name   VARCHAR2 (61)
                                   := gl_pkg_name || '.f_get_ct_inv_upd_carr';
   BEGIN
      RETURN ct_inv_upd_carr;
   EXCEPTION
      WHEN OTHERS
      THEN
         -- Log the error.
         Pl_Text_Log.ins_msg ('WARNING',
                              l_object_name,
                              'Error',
                              SQLCODE,
                              SQLERRM
                             );
         RAISE;
   END f_get_ct_inv_upd_carr;

-------------------------------------------------------------------------------
-- FUNCTION
--    f_get_ct_success
--
-- Description:
--     Returns constant CT_SUCCESS.
--     Designed to use in forms 6i since a package constant cannot be
--     directly accessed.
--
-- Parameters:
--    None
--
-- Return Values:
--    Constant CT_SUCCESS.
--
-- Exceptions Raised:
--    The when others propagates the exception.
--
-- Called by:
--    - Form mm3sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/15/07 prpbcb   Created.
----------------------------------------------------------------------------
   FUNCTION f_get_ct_success
      RETURN NUMBER
   IS
      l_object_name   VARCHAR2 (61) := gl_pkg_name || '.f_get_ct_success';
   BEGIN
      RETURN ct_success;
   EXCEPTION
      WHEN OTHERS
      THEN
         -- Log the error.
         Pl_Text_Log.ins_msg ('WARNING',
                              l_object_name,
                              'Error',
                              SQLCODE,
                              SQLERRM
                             );
         RAISE;
   END f_get_ct_success;

-------------------------------------------------------------------------------
-- FUNCTION
--    f_get_ct_failure
--
-- Description:
--     Returns constant CT_FAILURE.
--     Designed to use in forms 6i since a package constant cannot be
--     directly accessed.
--
-- Parameters:
--    None
--
-- Return Values:
--    Constant CT_FAILURE.
--
-- Exceptions Raised:
--    The when others propagates the exception.
--
-- Called by:
--    - Form mm3sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/15/07 prpbcb   Created.
----------------------------------------------------------------------------
   FUNCTION f_get_ct_failure
      RETURN NUMBER
   IS
      l_object_name   VARCHAR2 (61) := gl_pkg_name || '.f_get_ct_failure';
   BEGIN
      RETURN ct_failure;
   EXCEPTION
      WHEN OTHERS
      THEN
         -- Log the error.
         Pl_Text_Log.ins_msg ('WARNING',
                              l_object_name,
                              'Error',
                              SQLCODE,
                              SQLERRM
                             );
         RAISE;
   END f_get_ct_failure;

-------------------------------------------------------------------------------
-- FUNCTION
--    f_get_ct_er_duplicate
--
-- Description:
--     Returns constant CT_ER_DUPLICATE.
--     Designed to use in forms 6i since a package constant cannot be
--     directly accessed.
--
-- Parameters:
--    None
--
-- Return Values:
--    Constant CT_ER_DUPLICATE.
--
-- Exceptions Raised:
--    The when others propagates the exception.
--
-- Called by:
--    - Form mm3sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/15/07 prpbcb   Created.
----------------------------------------------------------------------------
   FUNCTION f_get_ct_er_duplicate
      RETURN NUMBER
   IS
      l_object_name   VARCHAR2 (61)
                                   := gl_pkg_name || '.f_get_ct_er_duplicate';
   BEGIN
      RETURN ct_er_duplicate;
   EXCEPTION
      WHEN OTHERS
      THEN
         -- Log the error.
         Pl_Text_Log.ins_msg ('WARNING',
                              l_object_name,
                              'Error',
                              SQLCODE,
                              SQLERRM
                             );
         RAISE;
   END f_get_ct_er_duplicate;

-------------------------------------------------------------------------------
-- PROCEDURE
--    send_SKU_change
--
-- Description:
--     This procedure send a new SKU message and/or a change SKU message to
--     the miniloader depending on the values of the parameters.
--
--     A new SKU message is sent to the miniloader when a non-splitable item
--     is made splitable and the case is in the miniloader.
--
--     A modify SKU message is sent to the miniloader:
--    - When the item description changes.
--          -  Send one for the case SKU if cases are in the miniloader.
--          -  Send one for the split SKU if splits are in the miniloader.
--    - When the case qty per carrier changes except if the new value is
--      0 or null.
--          -  Send one for the case SKU if cases are in the miniloader.
--          -  Send one for the split SKU if splits are in the miniloader.
--
--    If the new/modify SKU processing fails then an aplog message is
--    written.  Processing does not stop.
--
-- Parameters:
--    i_what_to_send       - Designates what to send, either new or modify SKU,
--                           and for what uom--cases and/or splits.
--                           The valid values are the corresponding meaning
--                           are:
--           CT_SEND_SKU_NEW_CS    - Send new SKU for case.
--           CT_SEND_SKU_NEW_SP    - Send new SKU for split.
--           CT_SEND_SKU_MOD_CS    - Send modify SKU for case.
--           CT_SEND_SKU_MOD_SP    - Send modify SKU for split.
--           CT_SEND_SKU_NEW_CS_NEW_SP - Send new SKU for case and split.
--           CT_SEND_SKU_MOD_CS_MOD_SP - Send modify SKU for case and split.
--           CT_SEND_SKU_NEW_CS_MOD_SP - Send new SKU for case and modify SKU
--                                       for split.
--           CT_SEND_SKU_MOD_CS_NEW_SP - Send modify SKU for case and new SKU
--                                       for split.
--    i_prod_id               - Item to send to the ML.
--    i_cust_pref_vendor      - Customer preferred vendor to send to the ML.
--    i_descrip               - Item description  to send to the ML.
--    i_spc                   - Splits per case for the item.
--    i_case_qty_per_carrier  - Splits per case for the item.
--    i_cmt                   - Comment.  The MNI transaction comment will be
--                              populated with this.
--    o_status                - CT_SUCCESS if no errors occured otherwise
--                              CT_FAILURE.
--
-- Exceptions Raised:
--    pl_exc.ct_data_error     -  A parameter had a bad value.
--    pl_exc.ct_database_error -  An oracle error occurred.
--
-- Called by:
--    PM table database trigger.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/20/07 prpbcb   Created.
----------------------------------------------------------------------------
   PROCEDURE send_sku_change (
      i_what_to_send           IN       PLS_INTEGER,
      i_prod_id                IN       pm.prod_id%TYPE,
      i_cust_pref_vendor       IN       pm.cust_pref_vendor%TYPE,
      i_descrip                IN       pm.descrip%TYPE,
      i_spc                    IN       pm.spc%TYPE,
      i_case_qty_per_carrier   IN       pm.case_qty_per_carrier%TYPE,
      i_cmt                    IN       miniload_trans.cmt%TYPE,
      i_zone_id                   IN       pm.zone_id%TYPE,
      i_split_zone_id          IN       pm.split_zone_id%TYPE,
      o_status                 OUT      NUMBER)      
   IS
      l_object_name        VARCHAR2 (61) := gl_pkg_name || '.send_SKU_change';
      l_message            VARCHAR2 (256);                  -- Message buffer

      l_r_sku_info         pl_miniload_processing.t_sku_info; -- Record to use
                                          -- in creating the miniload message.

      e_bad_what_to_send   EXCEPTION; -- i_what_to_send has an unhandled value.
      e_bad_parameter      EXCEPTION; -- One or more of the parameters is null.

------------------------------------------------------------------------
-- Local Procedure:
--    write_log_message
--
-- Description:
--    This procedure writes a swms log message and is called when
--    p_new_sku or p_modify_sku returns a failure status.
--    most of the log messages since they are all pretty much the same
--    except for some of the text.
--
-- Parameters:
--    i_message_type      - Type of message. INFO, FATAL, etc.
--    i_object_name       - Object creating the message.
--    i_r_sku_info        - SKU info.
--    i_message           - Text to put at the end of the message.
--
-- Exceptions raised:
--    None.  An error will be written to swms log.
--
-- Called by:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ------------------------------------------------
--    09/22/07 prpbcb   Created.
------------------------------------------------------------------------
      PROCEDURE write_log_message
        (i_message_type   IN   VARCHAR2,
         i_object_name    IN   VARCHAR2,
         i_r_sku_info     IN   pl_miniload_processing.t_sku_info,
         i_message        IN   VARCHAR2)
      IS
      BEGIN
         Pl_Log.ins_msg (i_message_type,
                         i_object_name,
                         'v_msg_type[' || i_r_sku_info.v_msg_type || ']'
                         || ' Item[' || i_r_sku_info.v_prod_id || ']'
                         || ' CPV[' || i_r_sku_info.v_cust_pref_vendor || ']'
                         || ' UOM[' || i_r_sku_info.n_uom || ']'
                         || '  '
                         || i_message,
                         ct_failure,
                         NULL,
                         ct_application_function,
                         gl_pkg_name);
      EXCEPTION
         WHEN OTHERS THEN
            --
            -- Problem writing the log message.  Log a message but do not
            -- stop processing.
            --
            pl_log.ins_msg
                   ('WARN',
                    'write_log_message',
                    'WHEN OTHERS EXCEPTION.  THIS WILL NOT STOP PROCESSING.',
                    SQLCODE,
                    SQLERRM,
                    ct_application_function,
                    gl_pkg_name);
      END write_log_message;                            -- end local procedure
   BEGIN
      --
      -- Validate the parameters.
      --
      IF (   i_what_to_send         IS NULL
          OR i_prod_id              IS NULL
          OR i_cust_pref_vendor     IS NULL
          OR i_spc                  IS NULL
          OR i_case_qty_per_carrier IS NULL)
      THEN
         RAISE e_bad_parameter;
      END IF;

      --
      -- Populate the common fields.
      --
      l_r_sku_info.v_prod_id          := i_prod_id;
      l_r_sku_info.v_cust_pref_vendor := i_cust_pref_vendor;
      l_r_sku_info.v_sku_description  := i_descrip;
      l_r_sku_info.v_cmt              := i_cmt;
      l_r_sku_info.v_zone_id          := i_zone_id;
      l_r_sku_info.v_split_zone_id    := i_split_zone_id;

      IF (i_what_to_send = ct_send_sku_new_cs) THEN
         --
         -- Send new SKU for case.
         --
         l_r_sku_info.v_msg_type          := pl_miniload_processing.ct_new_sku;
         l_r_sku_info.n_items_per_carrier := i_case_qty_per_carrier;
         l_r_sku_info.n_uom               := 2;
         pl_miniload_processing.p_new_sku (l_r_sku_info, o_status);

         IF (o_status != ct_success) THEN
            write_log_message('WARN',
                              'send_SKU_change',
                              l_r_sku_info,
                              'Send new SKU for case failed');
         END IF;
      ELSIF (i_what_to_send = ct_send_sku_new_sp) THEN
         --
         -- Send new SKU for split.
         --
         l_r_sku_info.v_msg_type          := pl_miniload_processing.ct_new_sku;
         l_r_sku_info.n_items_per_carrier := i_case_qty_per_carrier * i_spc;
         l_r_sku_info.n_uom               := 1;
         pl_miniload_processing.p_new_sku (l_r_sku_info, o_status);

         IF (o_status != ct_success) THEN
            write_log_message('WARN',
                              'send_SKU_change',
                              l_r_sku_info,
                              'Send new SKU for split failed');
         END IF;
      ELSIF (i_what_to_send = ct_send_sku_mod_cs) THEN
         --
         -- Send modify SKU for case.
         --
         l_r_sku_info.v_msg_type      := pl_miniload_processing.ct_modify_sku;
         l_r_sku_info.n_items_per_carrier := i_case_qty_per_carrier;
         l_r_sku_info.n_uom               := 2;
         pl_miniload_processing.p_modify_sku (l_r_sku_info, o_status);

         IF (o_status != ct_success) THEN
            write_log_message('WARN',
                              'send_SKU_change',
                              l_r_sku_info,
                              'Send modify SKU for case failed');
         END IF;
      ELSIF (i_what_to_send = ct_send_sku_mod_sp) THEN
         --
         -- Send modify SKU for split.
         --
         l_r_sku_info.v_msg_type     := pl_miniload_processing.ct_modify_sku;
         l_r_sku_info.n_items_per_carrier := i_case_qty_per_carrier * i_spc;
         l_r_sku_info.n_uom               := 1;
         pl_miniload_processing.p_modify_sku (l_r_sku_info, o_status);

         IF (o_status != ct_success) THEN
            write_log_message('WARN',
                              'send_SKU_change',
                              l_r_sku_info,
                              'Send modify SKU for split failed');
         END IF;
      ELSIF (i_what_to_send = ct_send_sku_new_cs_new_sp) THEN
         --
         -- Send new SKU for case and new SKU for split.
         --
         l_r_sku_info.v_msg_type          := pl_miniload_processing.ct_new_sku;
         l_r_sku_info.n_items_per_carrier := i_case_qty_per_carrier;
         l_r_sku_info.n_uom               := 2;
         pl_miniload_processing.p_new_sku(l_r_sku_info, o_status);

         IF (o_status != ct_success) THEN
            write_log_message('WARN',
                              'send_SKU_change',
                              l_r_sku_info,
                              'Send new SKU for case failed');
         ELSE
            --
            -- Sent new SKU for case successfully.
            -- Send new SKU for split.
            --
            l_r_sku_info.v_msg_type       := pl_miniload_processing.ct_new_sku;
            l_r_sku_info.n_items_per_carrier := i_case_qty_per_carrier * i_spc;
            l_r_sku_info.n_uom               := 1;
            pl_miniload_processing.p_new_sku (l_r_sku_info, o_status);

            IF (o_status != ct_success) THEN
               write_log_message('WARN',
                                 'send_SKU_change',
                                 l_r_sku_info,
                                 'Send new SKU for split failed');
            END IF;
         END IF;
      ELSIF (i_what_to_send = ct_send_sku_mod_cs_mod_sp) THEN
         --
         -- Send modify SKU for case and modify SKU for split.
         --
         l_r_sku_info.v_msg_type      := pl_miniload_processing.ct_modify_sku;
         l_r_sku_info.n_items_per_carrier := i_case_qty_per_carrier;
         l_r_sku_info.n_uom               := 2;
         pl_miniload_processing.p_modify_sku (l_r_sku_info, o_status);

         IF (o_status != ct_success) THEN
            write_log_message('WARN',
                              'send_SKU_change',
                              l_r_sku_info,
                              'Send modify SKU for case failed');
         ELSE
            --
            -- Sent modify new SKU for case successfully.
            -- Send modify SKU for split.
            --
            l_r_sku_info.v_msg_type := pl_miniload_processing.ct_modify_sku;
            l_r_sku_info.n_items_per_carrier := i_case_qty_per_carrier * i_spc;
            l_r_sku_info.n_uom               := 1;
            pl_miniload_processing.p_modify_sku (l_r_sku_info, o_status);

            IF (o_status != ct_success) THEN
               write_log_message('WARN',
                                 'send_SKU_change',
                                 l_r_sku_info,
                                 'Send modify SKU for split failed');
            END IF;
         END IF;
      ELSIF (i_what_to_send = ct_send_sku_new_cs_mod_sp) THEN
         --
         -- Send new SKU for case and modify SKU for split.
         --
         l_r_sku_info.v_msg_type          := pl_miniload_processing.ct_new_sku;
         l_r_sku_info.n_items_per_carrier := i_case_qty_per_carrier;
         l_r_sku_info.n_uom               := 2;
         pl_miniload_processing.p_new_sku (l_r_sku_info, o_status);

         IF (o_status != ct_success) THEN
            write_log_message('WARN',
                              'send_SKU_change',
                              l_r_sku_info,
                              'Send new SKU for case failed');
         ELSE
            --
            -- Sent new SKU for case successfully.
            -- Send modify SKU for split.
            --
            l_r_sku_info.v_msg_type := pl_miniload_processing.ct_modify_sku;
            l_r_sku_info.n_items_per_carrier :=
                                               i_case_qty_per_carrier * i_spc;
            l_r_sku_info.n_uom               := 1;
            pl_miniload_processing.p_modify_sku(l_r_sku_info, o_status);

            IF (o_status != ct_success) THEN
               write_log_message('WARN',
                                 'send_SKU_change',
                                 l_r_sku_info,
                                 'Send modify SKU for split failed');
            END IF;
         END IF;
      ELSIF (i_what_to_send = ct_send_sku_mod_cs_new_sp) THEN
         --
         -- Send modfiy SKU for case and new SKU for split.
         --
         l_r_sku_info.v_msg_type        := pl_miniload_processing.ct_modify_sku;
         l_r_sku_info.n_items_per_carrier := i_case_qty_per_carrier;
         l_r_sku_info.n_uom               := 2;
         pl_miniload_processing.p_modify_sku (l_r_sku_info, o_status);

         IF (o_status != ct_success) THEN
            write_log_message('WARN',
                              'send_SKU_change',
                              l_r_sku_info,
                              'Send modify SKU for case failed');
         ELSE
            --
            -- Sent modify SKU for case successfully.
            -- Send new SKU for split.
            --
            l_r_sku_info.v_msg_type     := pl_miniload_processing.ct_new_sku;
            l_r_sku_info.n_items_per_carrier := i_case_qty_per_carrier * i_spc;
            l_r_sku_info.n_uom               := 1;
            pl_miniload_processing.p_new_sku (l_r_sku_info, o_status);

            IF (o_status != ct_success) THEN
               write_log_message('WARN',
                                 'send_SKU_change',
                                 l_r_sku_info,
                                 'Send new SKU for split failed');
            END IF;
         END IF;
      ELSE
         --
         -- Unhandled value for i_what_to_send.  This is an error.
         --
         RAISE e_bad_parameter;
      END IF;
   EXCEPTION
      WHEN e_bad_parameter THEN
         --
         -- One or more of the parameters (excluding i_what_to_send) is null
         --
         l_message :=
               'i_what_to_send[' || i_what_to_send || ']'
            || '  i_item[' || i_prod_id || ']'
            || '  i_cust_pref_vendor[' || i_cust_pref_vendor || '].'
            || '  i_descrip[' || i_descrip || '].'
            || '  i_spc[' || i_spc || ']'
            || '  i_case_qty_per_carrier[' || i_case_qty_per_carrier || '].'
            || '  One or more of the parameters is null.'
            || '  This stops processing.';

         pl_log.ins_msg (pl_lmc.ct_fatal_msg,
                         l_object_name,
                         l_message,
                         Pl_Exc.ct_data_error,
                         NULL,
                         ct_application_function,
                         gl_pkg_name);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
      WHEN e_bad_what_to_send THEN
         l_message :=
               'i_what_to_send[' || i_what_to_send || ']'
            || ' has an unhandled value.'
            || '  Item[' || i_prod_id || ']'
            || '  CPV[' || i_cust_pref_vendor || '].'
            || '  This stops processing.';

         pl_Log.ins_msg (pl_lmc.ct_fatal_msg,
                         l_object_name,
                         l_message,
                         Pl_Exc.ct_data_error,
                         NULL,
                         ct_application_function,
                         gl_pkg_name);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
      WHEN OTHERS THEN
         l_message :=
               'i_what_to_send[' || i_what_to_send || ']'
            || '  Item[' || i_prod_id || ']'
            || '  CPV[' || i_cust_pref_vendor || '].'
            || '  Encountered an error.  This stops processing.';

         pl_log.ins_msg (pl_lmc.ct_fatal_msg,
                         'send_sku_change',
                         l_message,
                         SQLCODE,
                         SQLERRM,
                         ct_application_function,
                         gl_pkg_name);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_message);
   END send_sku_change;


-------------------------------------------------------------------------
-- Function:
--    f_find_ml_system
--
-- Description:
--    This function returns the miniload system of a SKU when a
--    product id is sent.
--
-- Parameters:
--    i_prod_id - prod_id for which the miniload is to be found
--    i_cust_pref_vendor - cust_pref_vendor field of the prod id
--
-- Return Values:
--      The miniload system identifier.
--
-- Exceptions Raised:
--    None.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/12/07 ctvgg000 Created as part of the HK Integration
---------------------------------------------------------------------------
   FUNCTION f_find_ml_system (
      i_prod_id            IN   miniload_message.prod_id%TYPE,
      i_cust_pref_vendor   IN   miniload_message.cust_pref_vendor%TYPE,
      i_zone_id               IN   pm.zone_id%TYPE       DEFAULT NULL,
      i_split_zone_id       IN   pm.split_zone_id%TYPE DEFAULT NULL
   )
      RETURN VARCHAR2
   IS
      lv_ml_system   miniload_config.ml_system%TYPE;
      lv_msg_text    VARCHAR2(1500);
      lv_fname       VARCHAR2(50)          := 'F_FIND_ML_SYSTEM';
      e_fail         EXCEPTION;
   BEGIN

     --
     -- 05/12/08 Brian Bent  Temporary fix. 
     --
     BEGIN
        SELECT ml_system
          INTO lv_ml_system
          FROM miniload_config;

        RETURN lv_ml_system;
     EXCEPTION
        WHEN TOO_MANY_ROWS THEN
           NULL;
        WHEN OTHERS THEN
           RAISE;
     END;    


      IF ((i_prod_id IS NULL) OR (i_cust_pref_vendor IS NULL)) THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || 'prod_id or cust_pref_vendor is null - Need a valid value';
         RAISE e_fail;
      END IF;

      IF (TRIM(i_zone_id) IS NULL AND TRIM(i_split_zone_id) IS NULL) THEN
         SELECT l.ml_system
           INTO lv_ml_system
           FROM zone z, pm p, loc l
          WHERE p.prod_id          = i_prod_id
            AND p.cust_pref_vendor = i_cust_pref_vendor
            AND z.zone_id          IN (p.zone_id, p.split_zone_id)
            AND z.induction_loc    = l.logi_loc;           
         
      ELSE                      
         SELECT l.ml_system
           INTO lv_ml_system
           FROM zone z, loc l        
          WHERE z.induction_loc = l.logi_loc           
            AND z.zone_id       IN (i_zone_id, i_split_zone_id);         
      END IF;

      RETURN lv_ml_system;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Message=Query to find miniload system failed'
            || ' Table=zone,loc Key:[prod_id,cpv,zone_id, split_zone_id]=['
            || i_prod_id
            || ','
            || i_cust_pref_vendor
            || ','
            || i_zone_id
            || ','
            || i_split_zone_id
            || ']';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         RAISE;
      WHEN e_fail THEN
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         RAISE;
      WHEN OTHERS THEN
         lv_msg_text :=
             'Prog Code: ' || ct_program_code || ' Error in f_find_ml_system';
         Pl_Text_Log.ins_msg ('FATAL',
                              lv_fname,
                              lv_msg_text,
                              SQLCODE,
                              SQLERRM);
         RAISE;
   END;


---------------------------------------------------------------------------
-- Procedure:
--    do_not_send_dup_order_to_ml
--
-- Description:
--    This procedure prevents sending a duplicate regular order to the
--    miniloader.  SUS/SAP/IDS can send the same order down in multiple
--    times in the ML queue
--
--    This is accomplished by seeing if the order was already sent to the
--    miniloader and it has not changed.  If this is the case the
--    MINILOAD_ORDER.STATUS is set to 'S'.  This procedure needs to be
--    called after the order was inserted into MINILOAD_ORDER and before
--    it is committed.
--
--   07/30/2014  Brian Bent
--   I was going to add a check for Historical orders and never to check
--   for a duplicate order but I decided not to as the current proceesing
--   should be fine.
--   Historical orders should be sent to SWMS only once a day and even if
--   for some reason it comes down again making the duplicate check should
--   be fine.
--
-- Parameters:
--    i_prod_id           - The item to send the order for.
--    i_cust_pref_vendor  - The CPV to send the order for.
--    i_order_date        - Send orders with this date.
--    o_status            - Status of call to procedure send_planned_orders().
--
-- Called by:
--    swmsmlreader    
--
-- Exceptions raised:
--    No exceptions are raised back to the calling object as this
--    procedure failing is not a FATAL issue and we do not want
--    to stop processing.
--    If an exception occurs then a message is logged.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/24/14 prpbcb   Created.
--                      This procedure is intended to be called by
--                      swmsmlreader.
---------------------------------------------------------------------------
PROCEDURE do_not_send_dup_order_to_ml
   (i_order_id  IN  miniload_order.order_id%TYPE)
IS
   l_message          VARCHAR2(1024 CHAR);  -- For log messages

   l_message_msg_ids  VARCHAR2(512 CHAR);   -- For log messages
                             -- This is for the message id's of the order
                             -- header and trailer records as we
                             -- always put these in a log message and at
                             -- least one log message is always created.
 
   l_object_name         VARCHAR2(30 CHAR) := 'do_not_send_dup_order_to_ml';

   l_send_order_to_ml  BOOLEAN;  -- Send/not send the order to the miniloader.
                                 -- Set by looking at the previous time the
                                 -- order was sent to SWMS and if the order
                                 -- has changed from the previous time it was
                                 -- sent.

   l_has_order_changed BOOLEAN;  -- Flag that signifies if the order was
                                 -- changed from the previous time it
                                 -- was sent to SWMS.

   --
   -- This record type is used to store the relevant information
   -- about the specified occurrence of a particular message
   -- type for an order.  This information is used to
   -- determine if to send or not send the order
   -- to the miniloader.
   --
   TYPE rt_order_record_info IS RECORD
   (
      order_id       miniload_order.order_id%TYPE,
      message_type   miniload_order.message_type%TYPE,
      row_number     NUMBER,
      message_id     miniload_order.message_id%TYPE,
      order_item_id  miniload_order.order_item_id%TYPE,
      status         miniload_order.status%TYPE,
      add_date       miniload_order.add_date%TYPE
   );

   l_r_current_order_header_info   rt_order_record_info;
   l_r_current_order_trailer_info  rt_order_record_info;
   l_r_prev_order_header_info      rt_order_record_info;
   l_r_prev_order_trailer_info     rt_order_record_info;


   --
   -- This cursor is used to determine if an order that is sent down to SWMS
   -- again has changed from the previous time it was sent.
   -- If this cursor returns no rows then the current order and the previous
   -- order are the same so don't send the current order to the miniloader.
   --
   CURSOR c_order_changed
              (cp_order_id             miniload_order.order_id%TYPE,
               cp_start_message_id_1   NUMBER,
               cp_end_message_id_1     NUMBER,
               cp_start_message_id_2   NUMBER,
               cp_end_message_id_2     NUMBER)
   IS
      SELECT m.message_id,
             m.order_id,
             m.order_item_id,
             m.prod_id, m.uom,
             m.quantity_requested,
             m.add_date,
             'CURRENT' which_order
        FROM miniload_order m
       WHERE m.order_id     = cp_order_id
         AND m.message_type = pl_miniload_processing.ct_ship_ord_inv
         AND m.message_id     BETWEEN cp_start_message_id_1 AND cp_end_message_id_1
         --
         -- Is there something in the current order that is not in the previous order.
         AND (m.order_id, m.order_item_id, m.prod_id, m.uom, m.quantity_requested) NOT IN
               (SELECT m2.order_id, m2.order_item_id, m2.prod_id, m2.uom, m2.quantity_requested
                  FROM miniload_order m2
                 WHERE m2.order_id     = cp_order_id
                   AND m2.message_type = pl_miniload_processing.ct_ship_ord_inv
                   AND m2.message_id   BETWEEN cp_start_message_id_2 AND cp_end_message_id_2)
      UNION
      SELECT m.message_id,
             m.order_id,
             m.order_item_id,
             m.prod_id,
             m.uom,
             m.quantity_requested,
             m.add_date,
             'PREVIOUS' which_order
        FROM miniload_order m
       WHERE m.order_id     = cp_order_id
         AND m.message_type = pl_miniload_processing.ct_ship_ord_inv
         AND m.message_id     BETWEEN cp_start_message_id_2 AND cp_end_message_id_2
         --
         -- Is there something in the previous order that is not in the current order.
         AND (m.order_id, m.order_item_id, m.prod_id, m.uom, m.quantity_requested) NOT IN
               (SELECT m2.order_id, m2.order_item_id, m2.prod_id, m2.uom, m2.quantity_requested
                  FROM miniload_order m2
                 WHERE m2.order_id     = cp_order_id
                   AND m2.message_type = pl_miniload_processing.ct_ship_ord_inv
                   AND m2.message_id   BETWEEN cp_start_message_id_1 AND cp_end_message_id_1)
       ORDER BY 2, 3, 6, 4, 5; -- The order is important


   ---------------------------------------------------------------------------
   -- Local Procedure:
   --    get_message_type_info
   --
   -- Description:
   --    This functions returns information of the specified sequence of
   --    a message type from the MINILOAD_ORDER table.
   --
   --    NOTE:  The processing is based on the message id being sequential for
   --           an order.  The add date was not used because using the
   --           message id was a little faster than using the add date in cursor
   --           "c_order_changed".
   --
   --           The downfall of using the message id is if the message id
   --           sequence wraps around for a particular order then you may not
   --           get the desired results.  But the way we are checking the values
   --           returned by this function in procedure
   --           "do_not_send_dup_order_to_ml" the wrapping of the sequence will
   --           not cause any issues.
   --        
   --    Examples: To get the message info of the last 'NewShippingOrderHeader'
   --              for order 123456 do this in the calling program:
   --              1.  Declare a record variable of type "rt_order_record_info"
   --              2.  Populate the following fields in the record:
   --                  <record variable>.order_id := '123456'
   --                  <record variable>.message_type := pl_miniload_processing.ct_ship_ord_hdr
   --                  <record variable>.row_number := 1;
   --              3.  Call this procedure: "get_message_type_info(<record variable>)
   --
   --              To get the message id of the second to last 'NewShippingOrderHeader'
   --              for order 123456:
   --              1.  Declare a record variable of type "rt_order_record_info"
   --              2.  Populate the following fields in the record:
   --                  <record variable>.order_id := '123456'
   --                  <record variable>.message_type := pl_miniload_processing.ct_ship_ord_hdr
   --                  <record variable>.row_number := 2;
   --              3.  Call this procedure: "get_message_type_info(<record variable>)
   --
   -- Parameters:
   --    io_r_order_record_info - order record information.
   --                             The following fields in the record need to
   --                             be populated before calling this procedure:
   --                                - order_id
   --                                - message_type
   --                                - row_number
   --                             This procedure will populate these fields in
   --                             the record:
   --                                - message_id  
   --                                - order_item_id
   --                                - status
   --                                - add_date
   --                         
   -- Exceptions raised:
   --    No exceptions are raised back to the calling object.
   --    If an exception occurs then a message is logged and
   --    "io_r_order_record_info.message_id" is set to null.
   --    The calling object will need to check "io_r_order_record_info.message_id"
   --    and do the appropriate processing.
   --
   -- Called by:  (list may not be complete)
   --    Procedure  do_not_send_dup_order_to_ml
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/01/14 prpbcb   Created
   ---------------------------------------------------------------------------
   PROCEDURE get_message_type_info
                 (io_r_order_record_info IN OUT  rt_order_record_info)
   IS
      l_message         VARCHAR2(1024 CHAR);  -- For log messages
      l_object_name     VARCHAR2(30   CHAR) := 'get_message_type_info';

      CURSOR c_order_message
                 (cp_order_id      miniload_order.order_id%TYPE,
                  cp_message_type  miniload_order.message_type%TYPE,
                  cp_row           NUMBER)
      IS
         SELECT * FROM
            (SELECT mo.order_id,
                    mo.message_type,
                    mo.message_id,
                    mo.order_item_id,
                    mo.status,
                    mo.add_date,
                    ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY message_id DESC) rn
               FROM miniload_order mo
              WHERE mo.message_type = cp_message_type
                AND mo.add_date >   -- Only look at orders sent after the last Start of Day
                                    -- and the Start of Day needs to be within 3 days.
                                    -- If no Start of Day is found the logic in
                                    -- procedure "do_not_send_dup_order_to_ml" will
                                    -- always send the order to the miniloader.
                      (SELECT MAX(s.add_date)
                         FROM miniload_message s
                        WHERE s.message_type = pl_miniload_processing.ct_start_of_day
                          AND s.add_date >= (SYSDATE - 3))
              GROUP BY mo.order_id,
                       mo.message_id,
                       mo.message_type,
                       mo.order_item_id,
                       mo.status,
                       mo.add_date
            ) t1
          WHERE t1.rn       = cp_row
            AND t1.order_id = cp_order_id;
   BEGIN
      OPEN c_order_message
              (io_r_order_record_info.order_id,
               io_r_order_record_info.message_type,
               io_r_order_record_info.row_number);

      --
      -- NOTE: 7/8/3014 Brian Bent
      --       This populates some fields (with the same value) that were
      --       set in the record when this procedure was called.
      --       This is just how I did the logic.
      --
      FETCH c_order_message INTO io_r_order_record_info.order_id,
                                 io_r_order_record_info.message_type,
                                 io_r_order_record_info.message_id,
                                 io_r_order_record_info.order_item_id,
                                 io_r_order_record_info.status,
                                 io_r_order_record_info.add_date,
                                 io_r_order_record_info.row_number;

      CLOSE c_order_message;
   EXCEPTION
      WHEN OTHERS THEN
         --
         -- Do not stop processing.  Set the message_id to null and log
         -- a message.  The calling object will need to check
         -- the message_id and do the appropriate processing.
         --
         io_r_order_record_info.message_id := NULL;

         l_message := l_object_name
            || '  TABLE=miniload_order  ACTION=SELECT'
            || '  io_r_order_record_info.order_id['     || io_r_order_record_info.order_id            || ']'
            || '  io_r_order_record_info.message_type[' || io_r_order_record_info.message_type        || ']'
            || '  io_r_order_record_info.row_number['   || TO_CHAR(io_r_order_record_info.row_number) || ']'
            || '  MESSAGE="Error in finding the miniload order information.  This will not stop processing.'
            || '  "io_r_order_record_info.message_id" will be set to null.'
            || '  The calling program needs to check if "o_r_order_record_info.message_id"'
            || ' is null and perform the appropriate processing."';

         DBMS_OUTPUT.PUT_LINE(l_message);

         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        ct_application_function,
                        gl_pkg_name);
   END get_message_type_info;

BEGIN
   --
   -- Initialization.
   --
   l_send_order_to_ml   := FALSE;
   l_has_order_changed  := FALSE;

   --
   -- Get the message id of the order header and trailer records for the
   -- last time the order was sent and the time before that.
   -- If any of these are null or the message id's are not in sequence then
   -- the order gets sent to the miniloader.
   --
   -- l_r_current_order_header_info and l_r_current_order_trailer_info should
   -- both be populdated because they are for the order just inserted.
   -- l_r_prev_order_header_info and l_r_prev_order_trailer_info will be null
   -- if this is the first time the order was processed after the
   -- Start of Day message.
   --

   l_r_current_order_header_info.order_id     := i_order_id;
   l_r_current_order_header_info.message_type := pl_miniload_processing.ct_ship_ord_hdr;
   l_r_current_order_header_info.row_number   := 1;
   get_message_type_info(l_r_current_order_header_info);

   l_r_current_order_trailer_info.order_id     := i_order_id;
   l_r_current_order_trailer_info.message_type := pl_miniload_processing.ct_ship_ord_trl;
   l_r_current_order_trailer_info.row_number  := 1;
   get_message_type_info(l_r_current_order_trailer_info);

   l_r_prev_order_header_info.order_id     := i_order_id;
   l_r_prev_order_header_info.message_type := pl_miniload_processing.ct_ship_ord_hdr;
   l_r_prev_order_header_info.row_number   := 2;
   get_message_type_info(l_r_prev_order_header_info);

   l_r_prev_order_trailer_info.order_id     := i_order_id;
   l_r_prev_order_trailer_info.message_type := pl_miniload_processing.ct_ship_ord_trl;
   l_r_prev_order_trailer_info.row_number   := 2;
   get_message_type_info(l_r_prev_order_trailer_info);


   --
   -- Common info for log messages.
   --
   l_message_msg_ids :=
              'i_order_id[' || i_order_id || ']'
           || '  current order header msg id['   || TO_CHAR(l_r_current_order_header_info.message_id)  || ']'
           || '  current order header status['   || l_r_current_order_header_info.status               || ']'
           || '  current order trailer msg id['  || TO_CHAR(l_r_current_order_trailer_info.message_id) || ']'
           || '  previous order header msg id['  || TO_CHAR(l_r_prev_order_header_info.message_id)     || ']'
           || '  previous order header status['  || l_r_prev_order_header_info.status                  || ']'
           || '  previous order trailer msg id[' || TO_CHAR(l_r_prev_order_trailer_info.message_id)    || ']'
           || '  sys_context(module)['           || SYS_CONTEXT('USERENV', 'MODULE')                   || ']';

   --
   -- Debug stuff
   --
   DBMS_OUTPUT.PUT_LINE('l_r_current_order_header_info.message_id[' || l_r_current_order_header_info.message_id || ']');
   DBMS_OUTPUT.PUT_LINE('l_r_current_order_trailer_info.message_id[' || l_r_current_order_trailer_info.message_id || ']');
   DBMS_OUTPUT.PUT_LINE('l_r_prev_order_header_info.message_id['  || l_r_prev_order_header_info.message_id  || ']');
   DBMS_OUTPUT.PUT_LINE('l_r_prev_order_trailer_info.message_id[' || l_r_prev_order_trailer_info.message_id || ']');

   --
   -- Let's send or not send the order to the miniloader...
   --
   IF (   l_r_current_order_header_info.message_id    IS NULL
       OR l_r_current_order_trailer_info.message_id   IS NULL)
   THEN
      --
      -- If this point is reached then there was a problem getting info
      -- about the last time the order was sent to SWMS in the ML queue.
      -- In this situation the order will be sent to the miniloader.
      -- Ideally this should not happen as this procedure should be called after
      -- a order was inserted into MINILOAD_ORDER but before it has been
      -- committed.
      --
      l_send_order_to_ml := TRUE;

      l_message := l_message_msg_ids
          || '  Could not get the order info for the last time the'
          || ' order was sent to SWMS in the ML queue.'
          || '  In this situation the order will be sent to the miniloader.'
          || '  Some reasons this could happen is there is no Start Of Day'
          || ' within the last 24 hours'
          || ' or the order was sent down before the last Start Of Day'
          || ' or this procedure is not called at the correct time'
          || ' or there was an error in procedure "get_message_type_info".'
          || '  Ideally this should not happen as this procedure should be called after'
          || ' a order was inserted into the MINILOAD_ORDER table but before it has been'
          || ' saved.';

      DBMS_OUTPUT.PUT_LINE(l_message);

      pl_log.ins_msg
           (pl_lmc.ct_warn_msg,
            l_object_name,
            l_message,
            NULL, NULL,
            ct_application_function,
            gl_pkg_name);


   ELSIF (   l_r_prev_order_header_info.message_id   IS NULL
          OR l_r_prev_order_trailer_info.message_id  IS NULL)
   THEN
      --
      -- If this point is reached then this is the first time
      -- the order has come down to SWMS or there was some problem
      -- getting info about the previous time the order was sent
      -- to SWMS.
      -- In this situation the order will be sent to the miniloader.
      --
      l_send_order_to_ml := TRUE;

      l_message := l_message_msg_ids
          || '  This is the first time the order has come down to SWMS after'
          || ' the last Start Of Day or'
          || ' there was some problem getting info about the previous time'
          || ' the order was sent to SWMS.  Send the order to the miniloader.'
          || '  If there was a problem getting info about the previous time'
          || ' then there will be a log message stating the reason why.';

      dbms_output.put_line(l_message);

      pl_log.ins_msg
           (pl_lmc.ct_info_msg,
            l_object_name,
            l_message,
            NULL, NULL,
            ct_application_function,
            gl_pkg_name);

   --
   -- Check if things are in sequence if not then send the order to the miniloader.
   --
   ELSIF (   l_r_current_order_header_info.message_id > l_r_current_order_trailer_info.message_id
          OR l_r_prev_order_trailer_info.message_id   > l_r_current_order_header_info.message_id
          OR l_r_prev_order_header_info.message_id    > l_r_prev_order_trailer_info.message_id)
   THEN
      --
      -- If this point is reached then the message id's are not in ascending
      -- order which points to the message id sequence wrapping around.
      -- So go ahead and send the order to the miniloader which is the
      -- easiest thing to do instead of having a bunch more logic to
      -- figure out the order of things.
      --
      l_send_order_to_ml := TRUE;

      l_message := l_message_msg_ids
              || '  The order was previously sent to the miniloader but the'
              || ' header and trailer records message id''s are not in ascending'
              || ' order which indicates the message id sequence'
              || ' wrapped around.  Send the order again to the'
              || ' miniloader as a fail safe measure.';

      DBMS_OUTPUT.PUT_LINE(l_message);

      pl_log.ins_msg
           (pl_lmc.ct_info_msg,
            l_object_name,
            l_message,
            NULL, NULL,
            ct_application_function,
            gl_pkg_name);
   ELSIF (l_r_prev_order_header_info.status <> 'S')
   THEN
      --
      -- If this point is reached then the previous order header status
      -- indicates it was not sent successfully to the miniloader.
      -- So send the order to the miniloader.
      --
      l_send_order_to_ml := TRUE;

      l_message := l_message_msg_ids
              || ' The previous order header status '''
              || l_r_prev_order_header_info.status || ''' for this order'
              || ' indicates it was not sent to the'
              || ' miniloader.  So send the order again to the'
              || ' miniloader regardless if the order changed or not.';

      DBMS_OUTPUT.PUT_LINE(l_message);

      pl_log.ins_msg
           (pl_lmc.ct_info_msg,
            l_object_name,
            l_message,
            NULL, NULL,
            ct_application_function,
            gl_pkg_name);
   ELSE
      --
      -- If this point is reached then the order was sent to SWMS from the host
      -- system again and the message id's are in the expected ascending order.
      -- Check if the order was changed since the last time it was sent.
      -- If no difference then do not sent the order to the miniloader since
      -- it has not changed.
      -- If the cursor returns no record then this indicates the order has
      -- not changed.
      --

      FOR r_order_changed IN c_order_changed
                            (i_order_id,
                             l_r_current_order_header_info.message_id,
                             l_r_current_order_trailer_info.message_id,
                             l_r_prev_order_header_info.message_id,
                             l_r_prev_order_trailer_info.message_id)
      LOOP
         --
         -- If we get in this loop then the order has changed.  Log
         -- what changed.
         --
         l_message := l_message_msg_ids
              || '  -- ORDER CHANGED DETAIL -- The order has changed since the previous time it was sent to SWMS.'
              || '  Send the order to the miniloader.  Following is info that can be used'
              || ' to research exactly what changed if that is desired.' 
              || '  which_order[' || r_order_changed.which_order || ']'
              || '  order_id['    || r_order_changed.order_id    || ']'
              || '  prod_id['     || r_order_changed.prod_id     || ']'
              || '  uom['         || r_order_changed.uom         || ']'
              || '  quantity_requested[' || r_order_changed.quantity_requested || ']'
              || '  order_item_id['      || r_order_changed.order_item_id      || ']'
              || '  add_date['    || TRIM(TO_CHAR(r_order_changed.add_date, 'YYYY-MON-DD HH24:MI:SS DAY')) || ']'
              || '  message_id['  || r_order_changed.message_id  || ']';

         DBMS_OUTPUT.PUT_LINE(l_message);

         pl_log.ins_msg
           (pl_lmc.ct_info_msg,
            l_object_name,
            l_message,
            NULL, NULL,
            ct_application_function,
            gl_pkg_name);

         l_send_order_to_ml := TRUE;
         l_has_order_changed := TRUE;
      END LOOP;
   END IF;

   IF (l_send_order_to_ml = FALSE) THEN
      l_message := l_message_msg_ids
              || '  -- ORDER HAS NOT CHANGED -- This order was previously sent to the miniloader.  The message id'
              || ' of the header record for this previous time is '
              || l_r_prev_order_header_info.message_id
              || ' and the add date is ' || TRIM(TO_CHAR(l_r_prev_order_header_info.add_date, 'YYYY-MON-DD HH24:MI:SS')) || '.'
              || '  The order has not changed so it will not be sent again.'
              || '  The is done by setting the miniload order record status to ''S'' for the current order,'
              || ' it currently should be ''N'',';

      DBMS_OUTPUT.PUT_LINE(l_message);

      pl_log.ins_msg
           (pl_lmc.ct_info_msg,
            l_object_name,
            l_message,
            NULL, NULL,
            ct_application_function,
            gl_pkg_name);

      UPDATE miniload_order m
         SET m.status = 'S'
       WHERE m.order_id = i_order_id
         AND m.status = 'N'
         --
         AND (   m.message_type = pl_miniload_processing.ct_ship_ord_hdr
              OR m.message_type = pl_miniload_processing.ct_ship_ord_inv
              OR m.message_type = pl_miniload_processing.ct_ship_ord_trl
             )
         --
         AND m.message_id BETWEEN l_r_current_order_header_info.message_id
                              AND l_r_current_order_trailer_info.message_id;

      l_message := l_message_msg_ids 
                   || '  -- ORDER HAS NOT CHANGED -- Number of records where the status was changed from ''N'' to ''S'': ' || SQL%ROWCOUNT;

      DBMS_OUTPUT.PUT_LINE(l_message);

      pl_log.ins_msg
           (pl_lmc.ct_info_msg,
            l_object_name,
            l_message,
            NULL, NULL,
            ct_application_function,
            gl_pkg_name);

   ELSIF (l_has_order_changed = TRUE) THEN
      l_message := l_message_msg_ids
              || '  -- ORDER CHANGED -- This order was previously sent to the miniloader.  The message id'
              || ' of the header record for this previous time is '
              || l_r_prev_order_header_info.message_id
              || ' and the add date is ' || TRIM(TO_CHAR(l_r_prev_order_header_info.add_date, 'YYYY-MON-DD HH24:MI:SS')) || '.'
              || '  The order has changed so it will be sent again.  This is'
              || ' done by leaving the current record status as it is--which should be ''N''.'
              || '  NOTE: An order is considered changed if the qty changed,'
              || ' the uom changed or an item was removed or added.';

      DBMS_OUTPUT.PUT_LINE(l_message);

      pl_log.ins_msg
           (pl_lmc.ct_info_msg,
            l_object_name,
            l_message,
            NULL, NULL,
            ct_application_function,
            gl_pkg_name);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Do not stop processing. 
      -- No exceptions are raised back to the calling object as this
      -- procedure failing is not a FATAL issue and we do not want
      -- to stop processing.
      --
      l_message := l_object_name
            || '(i_order_id[' || i_order_id || '])'
            || '  TABLE=miniload_order'
            || '  MESSAGE="Error in determining to send/not send the order'
            || ' to the miniloader.  This will not stop processing.'
            || '  No exceptions are raised back to the calling object as this'
            || ' process failing is not a FATAL issue and we do not want'
            || ' to stop processing.  The worst that will happen is the'
            || ' order will be sent again to the miniloader.';

      DBMS_OUTPUT.PUT_LINE(l_message);

      pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function,
                     gl_pkg_name);
  
END do_not_send_dup_order_to_ml;

/******************************************************************************
   NAME:       p_miniload_putaway_completion
   PURPOSE:    
            This procedure update the putawaylst,batch and inv quantity 
            since auto scanning of miniload
   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/4/2015   mdev3739       1. Charm6000002987-SF miniload auto scan 
                                            and auto confirm put enhancement.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     p_miniload_putaway_completion
      Sysdate:         2/4/2015
      Date and Time:   2/4/2015, 6:17:18 PM, and 2/4/2015 6:17:18 PM
      Username:        mdev3739 (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/

PROCEDURE p_miniload_putaway_completion (
        i_pallet_id IN putawaylst.pallet_id%TYPE,
        o_status OUT number)
  IS
        v_dest_loc          putawaylst.dest_loc%TYPE;
        v_qty_rec           putawaylst.qty_received%TYPE;
        v_qty_exp           putawaylst.qty_expected%TYPE;
        v_cust_pref_vendor  putawaylst.cust_pref_vendor%TYPE;
        v_prod_id           putawaylst.prod_id%TYPE;
        v_spc               pm.spc%TYPE;
        v_case_cube         pm.case_cube%TYPE;
        lv_msg_text         varchar2 (1500);
        lv_fname            varchar2 (50)   := 'P_MINILOAD_PUTAWAY_COMPLETION';
        v_status            erm.status%TYPE;
        v_erm_type          erm.erm_type%TYPE;
        v_erm_id            erm.erm_id%TYPE;
        v_uom               putawaylst.uom%TYPE;
        v_rec_id            putawaylst.rec_id%TYPE;
        v_lot_id            putawaylst.lot_id%TYPE;
        v_weight            putawaylst.weight%TYPE;
        v_mfg_date          putawaylst.mfg_date%TYPE;
        v_exp_date          putawaylst.exp_date%TYPE;
        v_temp              putawaylst.temp%TYPE;
        v_inv_status        putawaylst.inv_status%TYPE;
        v_orig_invoice      putawaylst.orig_invoice%TYPE;
        v_seq_no            putawaylst.seq_no%TYPE;
        v_rec_type          returns.rec_type%TYPE     := ' ';
        v_reason_code       returns.return_reason_cd%TYPE  :='   ';
                     

    BEGIN 
        
         SELECT p.dest_loc,p.qty_received,p.qty_expected,m.spc,m.case_cube,p.cust_pref_vendor,p.prod_id,
                p.uom,p.rec_id,p.lot_id,p.weight,p.mfg_date,p.exp_date,p.temp,p.inv_status,p.orig_invoice,p.seq_no
           INTO v_dest_loc,v_qty_rec,v_qty_exp,v_spc,v_case_cube,v_cust_pref_vendor,v_prod_id,
                v_uom,v_rec_id,v_lot_id,v_weight,v_mfg_date,v_exp_date,v_temp,v_inv_status,v_orig_invoice,v_seq_no
           FROM erd e ,putawaylst p ,pm m 
          WHERE p.pallet_id = i_pallet_id
            AND e.erm_id = p.rec_id
            AND e.prod_id = p.prod_id
            AND p.putaway_put = 'N'
            AND p.prod_id = m.prod_id;
            
          IF v_qty_rec > 0 THEN         
               /* As of now common for reserved,split and home location(both pallets) */                                                                           
               UPDATE inv 
                   SET qoh = qoh + v_qty_rec,
                       qty_planned = DECODE(SIGN(qty_planned - v_qty_exp),
                                            1, (qty_planned - v_qty_exp),
                                            -1, 0,
                                            0),
                       cube = cube + ((v_qty_rec - v_qty_exp) / v_spc) *
                                                                 v_case_cube,
                       parent_pallet_id = NULL
                 WHERE plogi_loc = v_dest_loc
                   AND logi_loc  = i_pallet_id;                   
          ELSE                   
                /* update if qty_rec=0 then clearing the qty_planned */ 
                UPDATE inv 
                        SET qty_planned = DECODE(SIGN(qty_planned - v_qty_exp),
                                                 1, (qty_planned - v_qty_exp),
                                                 -1, 0,
                                                 0),
                            cube = cube - (v_qty_exp / v_spc) * v_case_cube,
                            parent_pallet_id = NULL
                      WHERE plogi_loc = v_dest_loc
                        AND logi_loc =i_pallet_id
                        AND EXISTS (SELECT 1 FROM loc
                                              WHERE uom              IN (0,1,2)
                                                AND rank             = 1
                                                AND perm             = 'Y'
                                                AND prod_id          = v_prod_id 
                                                AND cust_pref_vendor = v_cust_pref_vendor 
                                                AND logi_loc         = v_dest_loc);                   
                   /* Delete if it is not a home slot*/                              
                     IF SQL%ROWCOUNT = 0 THEN
                 
                                DELETE FROM inv
                                            WHERE logi_loc = i_pallet_id
                                              AND plogi_loc = v_dest_loc;                        
                    END IF;                    
           END IF;
                        
        /*deleting the generated forklift batch*/   
        
                 
        DELETE FROM batch 
              WHERE batch_no = (SELECT pallet_batch_no FROM putawaylst 
                                                      WHERE pallet_id= i_pallet_id)
               AND  status ='F';  
               
        /* Taking the erm_type */
        SELECT r.status,r.erm_type,r.erm_id INTO v_status,v_erm_type,v_erm_id
            FROM erm r, putawaylst p 
                WHERE p.pallet_id = i_pallet_id 
                 AND r.erm_id = p.rec_id;
        
        IF v_erm_type = 'CM' THEN
         
        BEGIN  
               
        select rec_type, return_reason_cd
                  into   v_rec_type, v_reason_code
                  from   returns
                  where  obligation_no = v_lot_id
                  and    erm_line_id = v_seq_no;          
        EXCEPTION
        
        WHEN OTHERS THEN
        
        Null;
        
        END;
                  
        END IF;
         
        /* When Po is Open then inserting into trans table */         
        IF v_status =  'OPN' THEN
        
        INSERT INTO trans (trans_id, trans_type, prod_id, cust_pref_vendor,
                                uom, order_type, rec_id, lot_id, exp_date,
                                weight, mfg_date, qty_expected,
                                temp, qty, pallet_id, new_status, reason_code, 
                                dest_loc, trans_date, user_id,
                                order_id, order_line_id, upload_time)
                        VALUES (trans_id_seq.NEXTVAL, 'PUT', v_prod_id, v_cust_pref_vendor,
                                v_uom, v_rec_type, v_rec_id, v_lot_id,v_exp_date,
                                v_weight,v_mfg_date, v_qty_exp,
                                v_temp, v_qty_rec, i_pallet_id, v_inv_status, v_reason_code, 
                                v_dest_loc, SYSDATE, 'SWMS',
                                v_orig_invoice,v_seq_no, TO_DATE('01-JAN-1980'));
                          
                        /*updating the putaway completion for Open PO*/      
                           UPDATE putawaylst
                           SET putaway_put = 'Y'
                         WHERE pallet_id = i_pallet_id;
                        
        
        ELSIF   v_status =  'CLO' OR v_status =  'VCH' THEN   /* When Po is Closed then updating the trans table */
        
            UPDATE trans
             SET user_id = 'SWMS',
            trans_date = SYSDATE
           WHERE rec_id = v_erm_id
             AND trans_type = 'PUT'
             AND pallet_id = i_pallet_id;
           
           /*Deleting the putaway completion for closed PO*/  
           DELETE FROM putawaylst WHERE pallet_id = i_pallet_id;
        
        END IF; 
                                                                                                                          
       COMMIT;
     
        o_status := ct_success;                
         
    EXCEPTION 
        
    WHEN OTHERS THEN
         lv_msg_text :=
               'Prog Code: '
            || ct_program_code
            || ' Error in updating batch,inv and putawaylst table';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
         Pl_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE, SQLERRM);                              
         o_status := ct_failure;      
        
        
    END p_miniload_putaway_completion;

END pl_miniload_processing;
/
SHOW ERRORS
