CREATE OR REPLACE PACKAGE      pl_sts_interfaces
AS

   -- sccs_id=@(#) src/schema/plsql/pl_sts_interfaces.sql,
   -----------------------------------------------------------------------------
   -- Package Name:
   --   pl_sts_interfaces
   --
   -- Description:
   --    Processing of Stored procedures and table functions for interfaces(SCI011, SCI012) using staging tables.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- -----------------------------------------------------
   --    02/09/15 SPOT3255 Created.
   --    03/05/15 AVIJ3336 Added logic to populate the sts outbound staging table.
   --    09/23/15 SPOT3255 Removed column:Notes from cursor:get_stop_record
   --                      to eliminate the duplicated orders on STS.
   --    10/28/15 spot3255 Charm#6000009282: Restricted the route process(P_STS_IMPORT) to SWMS
   --					   if route was already processed

   --   29/10/15 MDEV3739  Charm#6000008485 - Populating the catch weight column and catch_wt_trk in
   --                     the STS_ROUTE_OUT table.
   --   05-Jan-17 jluo6971 CRQ000000017293 Fixed issues on same STS barcode
   --                      piece values for 2+floats/same item
   --                      using bc_st_piece_seq. --- REMOVED the changes done in this CRQ
   --   11/22/16 skam7488  Changes has been doen to format the date while fetching the data from sts_route_out
   --                      CRQ000000017293-Modified the code not to update the sts_process_flag to 'N' if the
   --                      process is already running to avoid duplicate barcode issue.
   --   01/17/17 skam7488  CRQ000000017293-Incorporated the missed date format changes.
   --   02/14/17 avij3336  CRQ000000022702 - 1. Reffer product id as character
   --                           			       2. update STS_PROCESS_RUN_FLAG  to 'N' in exception block
   --                                                             3. Changes in stop record cursor
   --   06/22/17 rrav5434  CRQ000000032720 - Added customer validation for unique stop records
   --   07/20/17 vkal9662  CRQ-31290 GS1 Barcode Flag chnages included
   --   08/02/17 lnic4226
   --			        chyd9155  CRQ34059 -To process the returns record received at stop level from STS
  --									      and send RTN and STC(stop close) at real time
    --   10/13/2017 chyd9155	CRQ-34059- added manifest close validation before adding returns
   --   03/28/2017 chyd9155 CRQ-47055 -Correct duplicate return pickup request for Non-POD customers and POD disabled OPCO
   --   04/13/2018 vkal9662/mpham Jira 399-added validations to handle return duplicates that may occur due to STS process
   --   08/15/2018 mpha8134 Add check if Tripmaster is done (count the CMP status return records). If tripmaster is done,
   --                       don't delete or modify returns. This was added to prevent data deletion when STS uploads multiple times
   --                       after Tripmaster is done.r
   --   08/01/2019 mcha1213 Jira OPCOF-2478 Returned quantity from STS is out of synch with SWMS
   --   10/13/19            Jira OPCOF-2510  10/02/19 take out Michael rs.reason_cd not like 'T%'
   --                          do not send 'STC' with T%, D% until MFC
   --                       in Pod_create_rtn only send to trans if it is route close
   --                       for R% or N% also send RTN to trans
   --   10/25/19            put back no STC for D T N01
   --   10/27/19            modify 'STC'
   --   03/24/20            Jira-2604 Missing Pick Up Request between STS and SWMS
   --   03/25/20   vkal9662 Jira-2872 Changes made to snd_sts_route_details process to use
   --                       Ship date used by majority of ordm recordsin a route
   --   05/04/21 spin4795   Jira 3317 Provided barcode sequence fix to mirror the barcodes
   --                       in the .BC files.
   --   06/04/21 spin4795   Jira 3371 Eliminated the duplicate barcodes that sometimes cause
   --                       the route to be rejected by STS.
   -----------------------------------------------------------------------------

-- Table  Function for SCI011
    FUNCTION swms_sts_func RETURN STS_ROUTE_OUT_OBJECT_TABLE;

    PROCEDURE delete_dup_barcodes(   i_route_no     IN   VARCHAR2,
                                     i_route_date   IN     DATE
                                     );

    PROCEDURE snd_sts_route_details(   i_route_no     IN   VARCHAR2,
                                       i_route_date   IN     DATE
                                        );

    PROCEDURE P_STS_IMPORT_ASSET (i_route_no     sts_route_in.route_no%TYPE,
     i_cust_id      sts_route_in.cust_id%TYPE,
     i_barcode      sts_route_in.barcode%TYPE,
     i_qty          sts_route_in.quantity%TYPE,
     i_route_date   sts_route_in.route_date%TYPE,
     i_time_stamp   sts_route_in.time_stamp%TYPE,
     i_event_type   sts_route_in.event_type%TYPE,
     o_status       OUT NUMBER);

    PROCEDURE P_STS_IMPORT;

    PROCEDURE POD_create_RTN (
   i_manifest_number     IN   VARCHAR2,
   i_stop_number         IN   NUMBER,
   RTN_process_flag      OUT  BOOLEAN,
   i_cust_id             IN   VARCHAR2,
   i_route_no            in    varchar2,
   i_msg_id              in    varchar2);

END pl_sts_interfaces;
/


CREATE OR REPLACE PACKAGE BODY      pl_sts_interfaces
AS
---------------------------------------------------------------------------
-- Private Modules
-------------------------------------------------------------------------------
-- FUNCTION
--    swms_sts_func
--
-- Description:
--     This function retrieves the data from Oracle staging table SAP_ROUTE_OUT
--     and sends the result set data for SCI011 to SAP through PI middle ware.
--
-- Parameters:
--      Nonea
--
-- Return Values:
--    SAP_ROUTE_OUT_OBJECT_TABLE
--
-- Exceptions Raised:
--   The when OTHERS propagates the exception.
--
-- Called by:
--    SAP-PI
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/09/15 SPOT3255 Created.
----------------------------------------------------------------------------
/* Formatted on 2015/03/12 17:12 (Formatter Plus v4.8.8) */
FUNCTION swms_sts_func
   RETURN sts_route_out_object_table
AS
   PRAGMA AUTONOMOUS_TRANSACTION;
   l_sts_tab         sts_route_out_object_table
                                             := sts_route_out_object_table();
   MESSAGE           VARCHAR2 (2000);
   lv_batch_id       NUMBER (8);
   batch_id_resend   NUMBER (8);
   lv_loop           NUMBER;

   CURSOR c_rec_to_be_processed
   IS
      SELECT   route_no, route_date, sequence_no
          FROM sts_route_out
         WHERE record_status = 'N' AND batch_id IS NULL
      ORDER BY sequence_no;

   CURSOR c_rec_to_be_resend
   IS
      SELECT   route_no, route_date, sequence_no
          FROM sts_route_out
         WHERE record_status = 'N' AND batch_id IS NOT NULL
      ORDER BY sequence_no;
BEGIN
   BEGIN
      UPDATE sts_route_out
         SET record_status = 'N'
       WHERE record_status = 'Q';

            COMMIT ;
      SELECT   MIN (batch_id)
          INTO batch_id_resend
          FROM sts_route_out
         WHERE record_status = 'N' AND batch_id IS NOT NULL
      ORDER BY sequence_no;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END;

   IF batch_id_resend IS NOT NULL
   THEN
      lv_batch_id := batch_id_resend;

      FOR r_rec_to_be_resend IN c_rec_to_be_resend
      LOOP
         FOR i_index IN (SELECT   sequence_no, record_type, route_no,
                                  TO_CHAR(route_date, 'YYYY-MM-DD HH24:MI:SS') route_date, driver_id, trailer,
                                  trailer_loc, useitemseq, useitemzone,
                                  instructions, checkin_assets_ind, stop_no,
                                  cust_id, ship_name, ship_addr1, ship_addr2,
                                  stop_csz, cust_contact, stop_phone,
                                  stop_alerts, stop_directions, alt_stop_no,
                                  TO_CHAR(sched_arriv_time, 'YYYY-MM-DD HH24:MI:SS') sched_arriv_time,
                                  TO_CHAR(sched_dept_time, 'YYYY-MM-DD HH24:MI:SS') sched_dept_time,
                                  manifest_no, TO_CHAR(stop_open_time, 'YYYY-MM-DD HH24:MI:SS') stop_open_time,
                                  TO_CHAR(stop_close_time, 'YYYY-MM-DD HH24:MI:SS') stop_close_time, loc_scan_timeout,
                                  invoice_print_mode, strattification,
                                  delivery_days, TO_CHAR(delivery_window_start, 'YYYY-MM-DD HH24:MI:SS') delivery_window_start,
                                  TO_CHAR(delivery_window_end, 'YYYY-MM-DD HH24:MI:SS') delivery_window_end, invoice_no, terms,
                                  deliv_type, salesperson_id, salesperson,
                                  invoice_cube, remit_to_addr1,
                                  remit_to_addr2, invoice_wgt, invoice_amt,
                                  invoice_type, invoice_print_type,
                                  show_price_ind, tax_ind, po_no, tax_id,
                                  TO_CHAR(due_date, 'YYYY-MM-DD HH24:MI:SS') due_date, sales_phone, tax, seq_no,
                                  prod_id, descrip, qty, credit_ref_no,
                                  orig_wms_item_type, wms_item_type,
                                  disposition, return_reason_cd,
                                  return_prod_id, ordd_seq, item_id,
                                  parent_item_id, planned_qty, high_qty,
                                  bulk_item, item_class, order_no, zone_name,
                                  allow_unload, unload_parent, splitflag,
                                  catch_weight_flag, alt_prod_id, pack,
                                  prod_size, compartment, invoice_group,
                                  otherzone_float, lot_no_ind, barcode,
                                  catch_weights, in_route_split_mode,
                                  split_price, split_tax, promoation_desc,
                                  promoation_discount, add_chg_desc,
                                  add_chg_amt, add_invoice_desc, float_id,
                                  order_line_state, lower(gs1_barcode_flag) gs1_barcode_flag
                             FROM sts_route_out
                            WHERE record_status = 'N'
                              AND batch_id = batch_id_resend
                              AND route_no = r_rec_to_be_resend.route_no
                              AND route_date = r_rec_to_be_resend.route_date
                         ORDER BY sequence_no)
         LOOP
            UPDATE sts_route_out
               SET record_status = 'Q'
             WHERE batch_id = batch_id_resend
               AND sequence_no = i_index.sequence_no;

                    COMMIT;
            MESSAGE :=
                  'STS_ROUTE_OUT:ERROR:RECORD_TYPE:'
               || i_index.record_type
               || ':ITEM:'
               || i_index.prod_id
               || ':STOP#:'
               || i_index.stop_no
               || ':ROUTE#:'
               || i_index.route_no
               || ':SEQUENCE#:'
               || i_index.sequence_no;
            l_sts_tab.EXTEND;
            l_sts_tab (l_sts_tab.COUNT) :=
               sts_route_out_object (lv_batch_id,
                                     i_index.record_type,
                                     i_index.route_no,
                                     i_index.driver_id,
                                     i_index.trailer,
                                     i_index.trailer_loc,
                                     i_index.useitemseq,
                                     i_index.useitemzone,
                                     i_index.instructions,
                                     i_index.checkin_assets_ind,
                                     i_index.stop_no,
                                     i_index.cust_id,
                                     i_index.ship_name,
                                     i_index.ship_addr1,
                                     i_index.ship_addr2,
                                     i_index.stop_csz,
                                     i_index.cust_contact,
                                     i_index.stop_phone,
                                     i_index.stop_alerts,
                                     i_index.stop_directions,
                                     i_index.alt_stop_no,
                                     i_index.manifest_no,
                                     i_index.loc_scan_timeout,
                                     i_index.invoice_print_mode,
                                     i_index.strattification,
                                     i_index.delivery_days,
                                     i_index.invoice_no,
                                     i_index.terms,
                                     i_index.deliv_type,
                                     i_index.salesperson_id,
                                     i_index.salesperson,
                                     i_index.invoice_cube,
                                     i_index.remit_to_addr1,
                                     i_index.remit_to_addr2,
                                     i_index.invoice_wgt,
                                     i_index.invoice_amt,
                                     i_index.invoice_type,
                                     i_index.invoice_print_type,
                                     i_index.show_price_ind,
                                     i_index.tax_ind,
                                     i_index.po_no,
                                     i_index.tax_id,
                                     i_index.sales_phone,
                                     i_index.tax,
                                     i_index.seq_no,
                                     i_index.prod_id,
                                     i_index.descrip,
                                     i_index.qty,
                                     i_index.credit_ref_no,
                                     i_index.orig_wms_item_type,
                                     i_index.wms_item_type,
                                     i_index.disposition,
                                     i_index.return_reason_cd,
                                     i_index.return_prod_id,
                                     i_index.ordd_seq,
                                     i_index.item_id,
                                     i_index.parent_item_id,
                                     i_index.planned_qty,
                                     i_index.high_qty,
                                     i_index.bulk_item,
                                     i_index.item_class,
                                     i_index.order_no,
                                     i_index.zone_name,
                                     i_index.allow_unload,
                                     i_index.unload_parent,
                                     i_index.splitflag,
                                     i_index.catch_weight_flag,
                                     i_index.alt_prod_id,
                                     i_index.pack,
                                     i_index.prod_size,
                                     i_index.compartment,
                                     i_index.invoice_group,
                                     i_index.otherzone_float,
                                     i_index.lot_no_ind,
                                     i_index.barcode,
                                     i_index.catch_weights,
                                     i_index.in_route_split_mode,
                                     i_index.split_price,
                                     i_index.split_tax,
                                     i_index.promoation_desc,
                                     i_index.promoation_discount,
                                     i_index.add_chg_desc,
                                     i_index.add_chg_amt,
                                     i_index.add_invoice_desc,
                                     i_index.float_id,
                                     i_index.order_line_state,
                                     i_index.route_date,
                                     i_index.sched_arriv_time,
                                     i_index.sched_dept_time,
                                     i_index.stop_open_time,
                                     i_index.stop_close_time,
                                     i_index.delivery_window_start,
                                     i_index.delivery_window_end,
                                     i_index.due_date,
                                     i_index.gs1_barcode_flag
                                    );
         END LOOP;

      END LOOP;
   ELSE
      FOR r_rec_to_be_processed IN c_rec_to_be_processed
      LOOP
         lv_loop := 0;

         FOR i_index IN (SELECT   sequence_no, record_type, route_no,
                                  TO_CHAR(route_date, 'YYYY-MM-DD HH24:MI:SS') route_date, driver_id, trailer,
                                  trailer_loc, useitemseq, useitemzone,
                                  instructions, checkin_assets_ind, stop_no,
                                  cust_id, ship_name, ship_addr1, ship_addr2,
                                  stop_csz, cust_contact, stop_phone,
                                  stop_alerts, stop_directions, alt_stop_no,
                                  TO_CHAR(sched_arriv_time, 'YYYY-MM-DD HH24:MI:SS') sched_arriv_time,
                                  TO_CHAR(sched_dept_time, 'YYYY-MM-DD HH24:MI:SS') sched_dept_time,
                                  manifest_no, TO_CHAR(stop_open_time, 'YYYY-MM-DD HH24:MI:SS') stop_open_time,
                                  TO_CHAR(stop_close_time, 'YYYY-MM-DD HH24:MI:SS') stop_close_time, loc_scan_timeout,
                                  invoice_print_mode, strattification,
                                  delivery_days, TO_CHAR(delivery_window_start, 'YYYY-MM-DD HH24:MI:SS') delivery_window_start,
                                  TO_CHAR(delivery_window_end, 'YYYY-MM-DD HH24:MI:SS') delivery_window_end, invoice_no, terms,
                                  deliv_type, salesperson_id, salesperson,
                                  invoice_cube, remit_to_addr1,
                                  remit_to_addr2, invoice_wgt, invoice_amt,
                                  invoice_type, invoice_print_type,
                                  show_price_ind, tax_ind, po_no, tax_id,
                                  TO_CHAR(due_date, 'YYYY-MM-DD HH24:MI:SS') due_date, sales_phone, tax, seq_no,
                                  prod_id, descrip, qty, credit_ref_no,
                                  orig_wms_item_type, wms_item_type,
                                  disposition, return_reason_cd,
                                  return_prod_id, ordd_seq, item_id,
                                  parent_item_id, planned_qty, high_qty,
                                  bulk_item, item_class, order_no, zone_name,
                                  allow_unload, unload_parent, splitflag,
                                  catch_weight_flag, alt_prod_id, pack,
                                  prod_size, compartment, invoice_group,
                                  otherzone_float, lot_no_ind, barcode,
                                  catch_weights, in_route_split_mode,
                                  split_price, split_tax, promoation_desc,
                                  promoation_discount, add_chg_desc,
                                  add_chg_amt, add_invoice_desc, float_id,
                                  order_line_state, lower(gs1_barcode_flag) gs1_barcode_flag
                             FROM sts_route_out
                            WHERE record_status = 'N'
                              AND batch_id IS NULL
                              AND route_no = r_rec_to_be_processed.route_no
                              AND route_date =
                                              r_rec_to_be_processed.route_date
                         ORDER BY sequence_no)
         LOOP
            IF lv_loop = 0
            THEN
               SELECT MAX (batch_id)
                 INTO lv_batch_id
                 FROM sts_route_out;

               IF lv_batch_id IS NULL
               THEN
                  lv_batch_id := 1;
               ELSE
                  lv_batch_id := lv_batch_id + 1;
               END IF;

               lv_loop := 1;
            END IF;

            UPDATE sts_route_out
               SET batch_id = lv_batch_id,
                   record_status = 'Q'
             WHERE sequence_no = i_index.sequence_no
               AND batch_id IS NULL
               AND route_no = i_index.route_no
               AND TO_CHAR(route_date,'YYYY-MM-DD HH24:MI:SS') = i_index.route_date;

                    COMMIT ;
            MESSAGE :=
                  'STS_ROUTE_OUT :ITEM:'
               || i_index.prod_id
               || ':STOP#:'
               || i_index.stop_no
               || ':ROUTE#:'
               || i_index.route_no
               || ':SEQUENCE#:'
               || i_index.sequence_no
               || 'BATCH ID:'
               || lv_batch_id;
            l_sts_tab.EXTEND;
            l_sts_tab (l_sts_tab.COUNT) :=
               sts_route_out_object (lv_batch_id,
                                     i_index.record_type,
                                     i_index.route_no,
                                     i_index.driver_id,
                                     i_index.trailer,
                                     i_index.trailer_loc,
                                     i_index.useitemseq,
                                     i_index.useitemzone,
                                     i_index.instructions,
                                     i_index.checkin_assets_ind,
                                     i_index.stop_no,
                                     i_index.cust_id,
                                     i_index.ship_name,
                                     i_index.ship_addr1,
                                     i_index.ship_addr2,
                                     i_index.stop_csz,
                                     i_index.cust_contact,
                                     i_index.stop_phone,
                                     i_index.stop_alerts,
                                     i_index.stop_directions,
                                     i_index.alt_stop_no,
                                     i_index.manifest_no,
                                     i_index.loc_scan_timeout,
                                     i_index.invoice_print_mode,
                                     i_index.strattification,
                                     i_index.delivery_days,
                                     i_index.invoice_no,
                                     i_index.terms,
                                     i_index.deliv_type,
                                     i_index.salesperson_id,
                                     i_index.salesperson,
                                     i_index.invoice_cube,
                                     i_index.remit_to_addr1,
                                     i_index.remit_to_addr2,
                                     i_index.invoice_wgt,
                                     i_index.invoice_amt,
                                     i_index.invoice_type,
                                     i_index.invoice_print_type,
                                     i_index.show_price_ind,
                                     i_index.tax_ind,
                                     i_index.po_no,
                                     i_index.tax_id,
                                     i_index.sales_phone,
                                     i_index.tax,
                                     i_index.seq_no,
                                     i_index.prod_id,
                                     i_index.descrip,
                                     i_index.qty,
                                     i_index.credit_ref_no,
                                     i_index.orig_wms_item_type,
                                     i_index.wms_item_type,
                                     i_index.disposition,
                                     i_index.return_reason_cd,
                                     i_index.return_prod_id,
                                     i_index.ordd_seq,
                                     i_index.item_id,
                                     i_index.parent_item_id,
                                     i_index.planned_qty,
                                     i_index.high_qty,
                                     i_index.bulk_item,
                                     i_index.item_class,
                                     i_index.order_no,
                                     i_index.zone_name,
                                     i_index.allow_unload,
                                     i_index.unload_parent,
                                     i_index.splitflag,
                                     i_index.catch_weight_flag,
                                     i_index.alt_prod_id,
                                     i_index.pack,
                                     i_index.prod_size,
                                     i_index.compartment,
                                     i_index.invoice_group,
                                     i_index.otherzone_float,
                                     i_index.lot_no_ind,
                                     i_index.barcode,
                                     i_index.catch_weights,
                                     i_index.in_route_split_mode,
                                     i_index.split_price,
                                     i_index.split_tax,
                                     i_index.promoation_desc,
                                     i_index.promoation_discount,
                                     i_index.add_chg_desc,
                                     i_index.add_chg_amt,
                                     i_index.add_invoice_desc,
                                     i_index.float_id,
                                     i_index.order_line_state,
                                     i_index.route_date,
                                     i_index.sched_arriv_time,
                                     i_index.sched_dept_time,
                                     i_index.stop_open_time,
                                     i_index.stop_close_time,
                                     i_index.delivery_window_start,
                                     i_index.delivery_window_end,
                                     i_index.due_date,
									          i_index.gs1_barcode_flag
                                    );
         END LOOP;

      END LOOP;
   END IF;

   RETURN l_sts_tab;

EXCEPTION
   WHEN OTHERS
   THEN

   ROLLBACK;

      pl_log.ins_msg ('FATAL',
                      'swms_sts_func',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'swms_sts_func',
                      'N'
                     );
END swms_sts_func;

PROCEDURE snd_sts_route_details (
   i_route_no     IN   VARCHAR2,
   i_route_date        DATE
)
IS
   MESSAGE         VARCHAR2 (2000);
   l_bc_seq        NUMBER;
   l_pick_up_seq   NUMBER;
   l_curr_stop_no  NUMBER;
   l_prev_stop_no  NUMBER;
   l_rounded_stop_no NUMBER;   --CRQ22702
   l_prev_cust_id  sts_route_view.cust_id%TYPE;
   l_num_of_items  NUMBER;
   l_rowcount      NUMBER;
   l_flt_seq       VARCHAR2 (4);
   l_object_name   VARCHAR2 (120);
   i               number;
   l_time_in     VARCHAR2(25);
   l_time_out    VARCHAR2(25);
   l_b_hr_fr     VARCHAR2(25);
   l_b_hr_to     VARCHAR2(25);
   l_seq         NUMBER;
   l_prod_id     pm.prod_id%TYPE;
   l_high_qty    VARCHAR2(1);
   l_reg_bc_qty  NUMBER;
   l_ordd_seq    NUMBER;
   l_reg_ordd_seq NUMBER;
   l_prev_ordd_seq NUMBER;
   l_curr_ordd_seq NUMBER;
   l_curr_float_seq floats.float_seq%TYPE;
   l_prev_float_seq floats.float_seq%TYPE;
   l_curr_prod_id   pm.prod_id%TYPE;
   l_prev_prod_id   pm.prod_id%TYPE;
   l_curr_ordd      NUMBER;
   l_prev_ordd      NUMBER;
   l_h_seq         NUMBER;
   l_count         NUMBER;
   l_success_flag  BOOLEAN;
   l_sos_status    VARCHAR2(1);
   l_process_flag  VARCHAR2(1);
   l_false         VARCHAR2(6) :='FALSE';
   l_CUST_GS1_BARCODE  VARCHAR2(6);
--   l_tmp_bc_seq		NUMBER := 0;
--   l_batch_id      NUMBER;
/* Charm6000008485- added the below variable */
   v_catch_weight  ordcw.catch_weight%TYPE;
   v_catch_wt_trk pm.catch_wt_trk%TYPE;
   v_obligation_no  manifest_stops.obligation_no%TYPE;
   i_route_Shpdt  ORDM.ship_date%TYPE;
   l_bc_st_piece_seq NUMBER;

   SeqQuantity NUMBER;
   StartCaseSeq NUMBER;

   PRAGMA AUTONOMOUS_TRANSACTION;

   CURSOR get_route_record (
      i_rotue_no     route.route_no%TYPE,
      i_route_date   route.dl_time%TYPE
   )
   IS
      SELECT DISTINCT s.route_no, s.route_date, trailer, truck_no
                 FROM las_truck t, sts_route_view s
                WHERE t.truck(+) = s.truck_no
                  AND s.route_no = i_route_no
                  AND s.route_date = i_route_date
                  AND s.truck_no IS NOT NULL;

   CURSOR get_stop_record (
      i_rotue_no     route.route_no%TYPE,
      i_route_date   route.dl_time%TYPE
   )
   IS
      SELECT  distinct  stop_no, cust_id, regexp_replace(ship_name,'[[:space:]]+',' ') ship_name,
      regexp_replace(ship_addr1,'[[:space:]]+',' ') ship_addr1,
      regexp_replace(ship_addr2,'[[:space:]]+',' ') ship_addr2,
                      substr(TRIM (ship_city ||' '|| ship_state ||' '|| ship_zip),1,30) stop_csz,
                      cust_contact, manifest_no,to_char(route_date,'mm/dd/yyyy') route_date
             FROM sts_route_view
                WHERE route_no = i_route_no
                  AND route_date = i_route_date
                  AND sts_sort not in ('3','2')
             ORDER BY stop_no;

   CURSOR get_invoice_record (
      i_rotue_no     route.route_no%TYPE,
      i_route_date   route.dl_time%TYPE,
      i_stop_no      sts_route_out.stop_no%TYPE
   )
   IS
      SELECT DISTINCT obligation_no, route_date, terms, sts_sort,stop_no,
                      salesperson_id, salesperson, invoice_cube, invoice_wgt,
                      invoice_amt
                 FROM sts_route_view
                WHERE route_no = i_route_no
                  AND route_date = i_route_date
                  AND stop_no = i_stop_no
                  AND sts_sort = '1'
             ORDER BY stop_no,sts_sort;

   CURSOR get_sch_return_record (
      i_rotue_no     route.route_no%TYPE,
      i_route_date   route.dl_time%TYPE
   )
   IS
      SELECT DISTINCT prod_id,CUST_ID descrip, shipped_qty, orig_invoice, container,
                      disposition, return_reason_cd, return_prod_id,
                      SUBSTR (obligation_no, 2), ordd_seq
                 FROM sts_route_view
                WHERE route_no = i_route_no
                  AND route_date = i_route_date
                  AND sts_sort = '2';

   CURSOR get_alt_loc_record (
      i_rotue_no     route.route_no%TYPE,
      i_route_date   route.dl_time%TYPE,
      i_stop_no      ordd.stop_no%TYPE,
      i_truck_no     route.truck_no%TYPE
         )
   IS
      SELECT ordd_seq || LPAD (case_seq, 3, 0) barcode,
           DECODE (float_seq,
                              NULL, NULL,
                              'F' || rpad(truck_no,4,' ') || float_seq
                             ) float_id,
                      truck_zone
                 FROM sts_route_view
                WHERE route_no = i_route_no
                  AND route_date = i_route_date
                  AND stop_no = i_stop_no
                  AND sts_sort = '3'
                  order by ordd_seq;


   CURSOR get_delivery_pallet_record (
      i_rotue_no     route.route_no%TYPE,
      i_route_date   route.dl_time%TYPE,
      i_stop_no      sts_route_out.stop_no%TYPE
   )
   IS
      SELECT DISTINCT float_seq, 'F' || rpad(truck_no,4,' ') ||float_seq item_id,
                      ' ' parent_item_id, 'N' high_quantity, 'N' bulk_item,
                      'C ' itemclass,
                      'Pallet ' || truck_no || ' ' || float_seq itemdesc,
                      truck_zone zone_name,
                      DECODE (unitize_ind,
                              'Y', 'Y',
                              DECODE (pallet_pull, 'B', 'Y', 'N')
                             ) allowunload,
                      'N' unloadparent, 'N' otherzonefloat,
                      DECODE (pallet_pull, 'B', 'N', 'Y') splitflag,
                      '' catchweightflag, '' alternateproductid,
                      ' ' prod_size, SUBSTR (float_seq, 1, 1) compartment,'1' Planned_qty, '1' Qty,
                      ' ' taxflag, '0' taxperitem,float_no
                 FROM sts_route_view s
                WHERE s.route_no = i_route_no
                  AND s.route_date = i_route_date
                  AND stop_no = i_stop_no
				  AND s.float_seq IS NOT NULL
--                  and float_no <> 0
                  AND s.sts_sort = '1'
                  order by s.float_seq;

   CURSOR get_delivery_item_record (
      i_rotue_no     route.route_no%TYPE,
      i_route_date   route.dl_time%TYPE,
      i_stop_no      sts_route_out.stop_no%TYPE,
      i_float_seq    floats.float_seq%TYPE
   )
   IS
        SELECT ordd_seq,float_seq_no,sos_status,
           DECODE (float_seq,
                   NULL, NULL,
                   '    ',NULL,    -- in some rare cases float seq is neither null nor blank it is of length 4 spaces.. got this scenarion from opco 045
                  'F' || rpad(truck_no,4,' ') || float_seq
                  ) parent_item_id,
        decode(s.uom,1,s.qty_ordered,(s.qty_ordered/p.spc))  planned_qty,
        nvl(decode(s.uom,1,(s.qty_alloc - s.wh_out_qty),((s.qty_alloc/p.spc) - s.wh_out_qty)),0) qty,
           'N' high_qty, 'N' bulk_item,
           'O ' item_class, DECODE (uom, 1, 'S', 'CS') wms_item_type,
           cust_po order_no, s.prod_id, s.descrip, truck_zone, 'Y' allowunload,
           DECODE (unitize_ind,
                   'Y', 'Y',
                   DECODE (pallet_pull, 'B', 'Y', 'N')
                  ) unloadparent,
           s.split_trk, SUBSTR (s.catch_wt_trk, 1, 1) catch_wt_trk,
           s.vendor_id alternateproductid, s.spc pack, s.prod_size, s.area compartment,
           other_zone_float otherzonefloat, '0' price, '0' invoiceseq,
           ' ' taxflag, '0' taxperitem, ' ' invoice_group,
           obligation_no invoice_no, nvl(p.gs1_barcode_flag,l_FALSE) gs1_barcode_flag
      FROM sts_route_view s, pm p
     WHERE route_no = i_route_no
       AND route_date = i_route_date
       AND stop_no = i_stop_no
       AND float_seq = i_float_seq
       and s.prod_id = p.prod_id
       AND sts_sort = '1'
        order by uom desc,
        s.prod_id,float_seq_no asc;

   CURSOR get_barcode_pallet_record (
      i_rotue_no     route.route_no%TYPE,
      i_route_date   route.dl_time%TYPE
   )
   IS
   SELECT DISTINCT float_no, float_seq, rpad(truck_no,4,' ') || float_seq barcode,
                      'F' || rpad(truck_no,4,' ') || float_seq item_id, '0' prod_id,
                      'N' bulk_item, 'N' order_line_state
                 FROM sts_route_view
                WHERE route_no = i_route_no
                  AND route_date = i_route_date
                  AND float_seq IS NOT NULL
--                  and float_no <> 0
                  AND sts_sort NOT IN ('2', '3')
                  order by float_Seq;

   CURSOR get_barcode_item_record (
      i_route_no     route.route_no%TYPE,
      i_route_date   DATE,
      i_float_no     floats.float_no%TYPE,
      i_float_seq    floats.float_seq%TYPE
   )
   IS
        SELECT DISTINCT s.prod_id, decode(s.uom,1,sum(qty_ordered),
                                             sum(qty_ordered)/p.spc) qty,float_no,float_seq,ordd_seq,stop_no,sos_status, nvl(p.gs1_barcode_flag,l_FALSE) gs1_barcode_flag
                     FROM sts_route_view s, pm p
                    WHERE route_no = i_route_no
                      AND route_date = i_route_date
                      AND float_no = i_float_no
                      and s.prod_id = p.prod_id
                      AND sts_sort NOT IN ('2', '3')
                      group by s.prod_id,s.uom,p.spc,float_no,float_seq,ordd_seq,stop_no,sos_status,gs1_barcode_flag
                      order by prod_id,ordd_Seq;


   CURSOR get_stop_asset_record (
      i_rotue_no     route.route_no%TYPE,
      i_route_date   DATE,
      i_stop_no      ordd.stop_no%TYPE
   )
   IS
      SELECT barcode, qty_at_stop
        FROM sts_route_view
       WHERE route_no = i_route_no
         AND route_date = i_route_date
         AND stop_no = i_stop_no
         AND sts_sort = '4';



   CURSOR get_sched_return_record (
      i_rotue_no     route.route_no%TYPE,
      i_route_date   DATE,
      i_stop_no      ordd.stop_no%TYPE
         )
   IS
      SELECT cust_id, prod_id, descrip, shipped_qty, orig_invoice,ordd_seq,
             DECODE (uom, 1, 'S', container) origwmsitemtype,
             DECODE (uom, 1, 'S', container) wmsitemtype, disposition,
             return_reason_cd, '0' weight, return_prod_id,
             SUBSTR (obligation_no, 2, 16) invoice_no, '0' invoice_amt
        FROM sts_route_view
       WHERE route_no = i_route_no
         AND route_date = i_route_date
         AND sts_sort = '2'
         AND stop_no = i_stop_no;

    --Charm#6000008485 - Added the invoice_no in the below cursor

    CURSOR c_float_seq_no ( i_rotue_no     route.route_no%TYPE,
      i_route_date   DATE,
      i_prod_id pm.prod_id%TYPE,
      i_ordd_seq sts_route_out.ordd_seq%TYPE,
      i_float_seq floats.float_seq%TYPE
           )
      IS
      select sum(planned_qty) qty, substr(item_id,9,4) l_bc_seq,ordd_seq,float_id,high_qty,invoice_no, nvl(gs1_barcode_flag,l_FALSE) gs1_barcode_flag   --for barcode records, planned qty should be taken into account rather than qty
                        from sts_route_out
                        where record_type='DI'
                        and prod_id = i_prod_id
                        and route_no = i_route_no
                        and route_date = i_route_date
                        and ordd_seq = i_ordd_seq
                        and batch_id is null
                        and record_status = 'N'
            and ((parent_item_id is not null and trim(substr(parent_item_id,6,3)) = i_float_seq)
                             or
                             (parent_item_id is null))
                        group by planned_qty,item_id,ordd_seq,float_id,high_qty,parent_item_id,invoice_no,gs1_barcode_flag ;


     CURSOR get_high_qty_barcode (   i_rotue_no     route.route_no%TYPE,
      i_route_date   DATE,
      i_prod_id pm.prod_id%TYPE,
      i_ordd_seq sts_route_out.ordd_seq%TYPE,
      i_float_seq    floats.float_seq%TYPE,
      i_float_id  sts_route_out.float_id%TYPE
   )
      IS
            select  (planned_qty) qty,  ordd_seq || substr(item_id,9,4) item_id,ordd_seq,float_id, nvl(gs1_barcode_flag,l_FALSE) gs1_barcode_flag
                        from sts_route_out
                        where record_type='DI'
                        and record_status ='N'
			and prod_id = i_prod_id
                        and route_no = i_route_no
                        and route_date = i_route_date
                        and ordd_seq = i_ordd_seq
                        and batch_id is null
                        and float_id = i_float_id
                        and ((parent_item_id is not null and trim(substr(parent_item_id,6,3)) = i_float_seq)
                             or
                             (parent_item_id is null))
                       group by planned_qty,item_id,ordd_seq,float_id, gs1_barcode_flag;

      CURSOR c_high_qty_items (   i_rotue_no     route.route_no%TYPE,
      i_route_date   DATE)
      IS
                       SELECT   s.prod_id,s.ordd_seq,float_seq_no, nvl(p.gs1_barcode_flag,l_FALSE) gs1_barcode_flag
                                FROM sts_route_view s, pm p
                               WHERE route_no = i_route_no
                                 AND route_date = i_route_date
                                 AND sts_sort = 1
                                 AND s.catch_wt_trk != 'Y'
                                 AND s.prod_id = p.prod_id
                            GROUP BY s.prod_id,s.ordd_seq,float_seq_no,
                                     sts_sort,
                                     sos_status,
                                     s.catch_wt_trk,
                                     multi_no,
                                     s.uom,
                                     s.qty_ordered,
                                     p.spc,
									 p.gs1_barcode_flag
                              HAVING DECODE (s.uom, 1, s.qty_ordered, (s.qty_ordered / p.spc)) > s.multi_no
                            UNION
                            SELECT s.prod_id,s.ordd_seq,float_Seq_no, nvl(p.gs1_barcode_flag,l_FALSE) gs1_barcode_flag
                              FROM sts_route_view s, pm p
                             WHERE route_no = i_route_no
                               AND route_date = i_route_date
                               AND sts_sort = 1
                               AND s.prod_id = p.prod_id
                               AND sos_status = 'N';

      -- Added new cursor for Jira 3317
      CURSOR get_low_qty_barcode (i_rotue_no     route.route_no%TYPE,
                                 i_route_date   DATE,
                                 i_prod_id      pm.prod_id%TYPE,
                                 i_ordd_seq     sts_route_out.ordd_seq%TYPE,
                                 i_float_seq    floats.float_seq%TYPE,
                                 i_float_id  sts_route_out.float_id%TYPE
                                )
      IS
          SELECT route_no, route_date, prod_id, ordd_seq, float_seq, selector_id,
                 qty_ordered, qty_short, total_qty, qty_alloc, uom, spc, multi_no, catch_wt_trk, sos_status,
                 bc_st_piece_seq, decode(uom,1,' split',' case') unit,
                 qty_ordered/decode(uom,1,1,spc) qty_ordered_u, qty_short qty_short_u,
                 total_qty/decode(uom,1,1,spc) total_qty_u, qty_alloc/decode(uom,1,1,spc) qty_alloc_u
            FROM sts_route_view s
           WHERE route_no = i_route_no
             AND route_date = i_route_date
             AND prod_id = i_prod_id
             AND ordd_seq = i_ordd_seq
             AND float_seq = i_float_seq
             AND sos_status||to_char(float_seq_no) = i_float_id
             AND (qty_ordered / decode(uom,1,1,spc) <= multi_no or catch_wt_trk = 'Y')
             AND sos_status <> 'N';

  -- Jira 2872 The below cursor looks at all the shipdates from ordm for a route
  -- and the shipdate used by majority of ordm records will be used
  CURSOR c_ship_date(i_routeno varchar2) IS
    SELECT COUNT(ship_date) shipdt_count,  ship_date
    FROM ORDM
    WHERE 1=1
    and route_no = i_routeno
    GROUP BY ship_date,route_no
    ORDER BY  COUNT(ship_date) DESC , ship_date;



BEGIN
l_prev_stop_no := -1;
l_num_of_items := 0;
l_bc_seq := 0;
l_object_name := 'SND_STS_ROUTE_DETAILS';
l_curr_stop_no := 0;
l_rounded_stop_no :=0;   --CRQ22702
l_prev_cust_id :=0;
l_pick_up_seq := 1;
l_prev_ordd_seq := -1;
l_curr_ordd_seq := 0;
l_success_flag := TRUE;
l_sos_status := '';
l_process_flag :='N';


SELECT CONFIG_FLAG_VAL
  INTO l_process_flag
  FROM sys_config
 WHERE config_flag_name = 'STS_PROCESS_RUN_FLAG';

 IF l_process_flag = 'N' THEN
 BEGIN
	UPDATE sys_config
		SET CONFIG_FLAG_VAL = 'Y'
	WHERE config_flag_name = 'STS_PROCESS_RUN_FLAG';
	COMMIT;

	EXCEPTION
      WHEN OTHERS THEN
      l_success_flag := FALSE;

      MESSAGE := 'ERROR OCCURRED WHILE SETTING STS_PROCESS_RUN_FLAG TO Y';

        pl_log.ins_msg ('FATAL',
                      'SND_STS_ROUTE_DETAILS',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'swms_sts_func',
                      'N'
                     );
  END;

  --Jira 2872 begin
  BEGIN
    i_route_Shpdt := NULL;
    FOR i IN c_ship_date(i_route_no)
    LOOP
      i_route_Shpdt    := i.ship_date;

      IF i_route_Shpdt IS NOT NULL THEN
        EXIT;
      END IF;
    END LOOP;
    /* if unable to obtain a route date */
    IF ( i_route_Shpdt IS NULL ) THEN
       MESSAGE := 'Route Date is Undefined' || ' for Route ' || i_route_no;

        pl_log.ins_msg ('FATAL',
                      'SND_STS_ROUTE_DETAILS',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'swms_sts_func',
                      'N'
                     );
    END IF;
  END;

  --Jira 2872  the ship date( i_route_Shpdt) derived is passed in every cursor below as route_Date

   FOR r IN get_route_record (i_route_no,  i_route_Shpdt)
   LOOP
      --insert into staging table
       MESSAGE := 'BEGIN populating STS_ROUTE_OUT table for Route:'
            || r.route_no
            || ' Route Date:'
            || r.route_date;

        pl_log.ins_msg ('DEBUG',
                      'SND_STS_ROUTE_DETAILS',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'swms_sts_func',
                      'N'
                     );

      BEGIN
      dbms_output.put_line('RT: route='||r.route_no||' route_date='||to_char(r.route_date,'DD-MON-YY')||' trailer='||r.trailer);

      INSERT INTO sts_route_out
                  (sequence_no, interface_type, record_status, datetime,
                   record_type, route_no, route_date, driver_id, trailer,
                   trailer_loc, useitemseq, useitemzone, instructions,
                   add_invoice_desc, checkin_assets_ind, add_user, add_date,
                   upd_user, upd_date
                  )
           VALUES (sts_route_out_seq.NEXTVAL, 'STS', 'N', SYSDATE,
                   'RT', r.route_no, r.route_date, '', r.trailer,
                   '', 'N', 'Y', '',
                   '', '', REPLACE (USER, 'OPS$', NULL), SYSDATE,
                   REPLACE (USER, 'OPS$', NULL), SYSDATE
                  );

      EXCEPTION
      WHEN OTHERS THEN
      l_success_flag := FALSE;

      MESSAGE := 'ERROR OCCURRED IN POPULATING RT RECORD'
            || r.route_no
            || ' Route Date:'
            || r.route_date;

        pl_log.ins_msg ('FATAL',
                      'SND_STS_ROUTE_DETAILS',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'swms_sts_func',
                      'N'
                     );

      END;

      FOR st IN get_stop_record (i_route_no,  i_route_Shpdt)
      LOOP

           BEGIN
            /* Formatted on 2015/03/11 15:37 (Formatter Plus v4.8.8) */
		    SELECT   time_in, time_out, business_hrs_from, business_hrs_to
		        INTO l_time_in, l_time_out, l_b_hr_fr, l_b_hr_to
		        FROM sts_route_view
		       WHERE route_no = r.route_no
		         AND route_date = r.route_date
		         AND stop_no = st.stop_no
		         AND sts_sort = 1
		    GROUP BY time_in, time_out, business_hrs_from, business_hrs_to, prod_id
		      HAVING prod_id =
		                (SELECT MIN (prod_id)
		                   FROM sts_route_view
		                  WHERE route_no = r.route_no
		                    AND route_date = r.route_date
		                    AND stop_no = st.stop_no
		                    AND sts_sort = 1);

			EXCEPTION
			WHEN OTHERS THEN

		      MESSAGE :=
		              'STS_ROUTE_OUT : Unable to fetch Time in/out, Business Hour from/to for'
		           || ':STOP#:'
		           || st.stop_no
		           || ':ROUTE#:'
		           || R.route_no
		           ;

			     pl_log.ins_msg ('WARN',
			                          'SND_STS_ROUTE_DETAILS',
			                          MESSAGE,
			                          SQLCODE,
			                          SQLERRM,
			                          'ORDER PROCESSING',
			                          'SND_STS_ROUTE_DETAILS',
			                          'N'
			                         );

			END;


	         l_time_in := st.route_date ||' '||l_time_in;
	         l_time_out:= st.route_date ||' '||l_time_out;
	         l_b_hr_fr := st.route_date ||' '||l_b_hr_fr;
	         l_b_hr_to := st.route_date ||' '||l_b_hr_to;

			BEGIN
				select round(st.stop_no) into l_rounded_stop_no from dual;  -- to keep the sequence of stop no as 1,2,3,...

			EXCEPTION
			WHEN OTHERS THEN

				l_success_flag := FALSE;

			MESSAGE :=
                        'STS_ROUTE_OUT : Unable to get rounded stop_no for '
                     || ':STOP#:'
                     || st.stop_no
                     || ':ROUTE#:'
                     || R.route_no
                     ;

			pl_log.ins_msg ('FATAL',
                                'SND_STS_ROUTE_DETAILS',
                                MESSAGE,
                                SQLCODE,
                                SQLERRM,
                                'ORDER PROCESSING',
                                'SND_STS_ROUTE_DETAILS',
                                'N'
                               );

			END;
			BEGIN

				--CRQ22702 removed the cust id validation for building the stop record.
			      if l_rounded_stop_no > l_prev_stop_no then
							    l_curr_stop_no := l_rounded_stop_no;

			      else
			            l_curr_stop_no := l_rounded_stop_no + 1;

                               --  CRQ000000032720  validation for building unique stop record for different customer
                              if l_curr_stop_no = l_prev_stop_no then

                                      l_curr_stop_no := l_curr_stop_no + 1;

                               END IF;

                              if l_curr_stop_no < l_prev_stop_no then

                                     l_curr_stop_no := l_prev_stop_no + 1;
                              END IF;


			      end if;

				  BEGIN

				     select nvl(GS1_BARCODE_ACTIVE, 'N') into l_CUST_GS1_BARCODE
				     from  SPL_RQST_CUSTOMER
				     where CUSTOMER_ID = st.cust_id;
				  EXCEPTION
				  WHEN OTHERS THEN
				     l_CUST_GS1_BARCODE := 'N';
				  END;

                  dbms_output.put_line('ST: stop_no='||l_curr_stop_no||' cust_id='||st.cust_id||' ship_name='||st.ship_name||
                                       ' alt_stop_no='||st.stop_no||' manifest_no='||to_char(st.manifest_no));

			      INSERT INTO sts_route_out
			                 (sequence_no, interface_type, record_status, datetime,route_no,route_date,
			                  record_type, stop_no, cust_id, ship_name,
			                  ship_addr1, ship_addr2, stop_csz,
			                  cust_contact, alt_stop_no, manifest_no,
			                  sched_arriv_time, sched_dept_time, stop_open_time,
			                  stop_close_time, add_user,
			                  add_date, upd_user, upd_date
			                 )
			          VALUES (sts_route_out_seq.NEXTVAL, 'STS', 'N', SYSDATE,r.route_no,r.route_date,
			                  'ST', l_curr_stop_no, st.cust_id, st.ship_name,
			                  st.ship_addr1, st.ship_addr2, st.stop_csz,
			                  st.cust_contact, st.stop_no, st.manifest_no,
			                  to_date(l_time_in,'mm/dd/yyyy hh24:mi:ss'), to_date(l_time_out,'mm/dd/yyyy hh24:mi:ss'),
			                  to_date(l_b_hr_fr,'mm/dd/yyyy hh24:mi:ss'),
			                  to_date(l_b_hr_to,'mm/dd/yyyy hh24:mi:ss'), REPLACE (USER, 'OPS$', NULL),
			                  SYSDATE, REPLACE (USER, 'OPS$', NULL), SYSDATE
			                 );

					l_prev_stop_no := l_curr_stop_no;

			        MESSAGE := 'INSERTED STOP RECORD FOR Route:'
			        || r.route_no
			        || ' Route Date:'
			        || r.route_date
			        || ' Stop No: '
			        || st.stop_no;

			        pl_log.ins_msg ('DEBUG',
			                      'SND_STS_ROUTE_DETAILS',
			                      MESSAGE,
			                      SQLCODE,
			                      SQLERRM,
			                      'ORDER PROCESSING',
			                      'swms_sts_func',
			                      'N'
			                     );



				EXCEPTION
				WHEN OTHERS THEN
					l_success_flag := FALSE;

		            MESSAGE := 'ERROR OCCURRED IN POPULATING ST RECORD'
		            || r.route_no
		            || ' Route Date:'
		            || r.route_date
		            || ' Stop No: '
		            || st.stop_no;

		            pl_log.ins_msg ('FATAL',
		                          'SND_STS_ROUTE_DETAILS',
		                          MESSAGE,
		                          SQLCODE,
		                          SQLERRM,
		                          'ORDER PROCESSING',
		                          'swms_sts_func',
		                          'N'
		                         );
			END;



         FOR iv IN get_invoice_record (i_route_no,  i_route_Shpdt, st.stop_no)
         LOOP

         BEGIN
               dbms_output.put_line('IV: obligation_no='||iv.obligation_no||' cube='||to_char(iv.invoice_cube)||
                                    ' weight='||to_char(iv.invoice_wgt)||' amount='||to_char(iv.invoice_amt));

               INSERT INTO sts_route_out
                           (sequence_no, interface_type, record_status,route_no,
                            datetime, record_type, invoice_no, route_date,
                            terms, salesperson_id, salesperson,
                            invoice_cube, invoice_wgt, invoice_amt,
                            add_user, add_date,
                            upd_user, upd_date
                           )
                    VALUES (sts_route_out_seq.NEXTVAL, 'STS', 'N',r.route_no,
                            SYSDATE, 'IV', iv.obligation_no, iv.route_date,
                            iv.terms, iv.salesperson_id, iv.salesperson,
                            iv.invoice_cube, iv.invoice_wgt, iv.invoice_amt,
                            REPLACE (USER, 'OPS$', NULL), SYSDATE,
                            REPLACE (USER, 'OPS$', NULL), SYSDATE
                           );


                    MESSAGE := 'INSERTING INVOICE RECORD FOR Route:'
                    || r.route_no
                    || ' Route Date:'
                    || r.route_date
                    || ' Invoice No:'
                    || iv.obligation_no;

                pl_log.ins_msg ('DEBUG',
                              'SND_STS_ROUTE_DETAILS',
                              MESSAGE,
                              SQLCODE,
                              SQLERRM,
                              'ORDER PROCESSING',
                              'swms_sts_func',
                              'N'
                             );
         EXCEPTION
         WHEN OTHERS THEN

           l_success_flag := FALSE;
            MESSAGE := 'ERROR OCCURRED IN POPULATING IV RECORD'
            || r.route_no
            || ' Route Date:'
            || r.route_date;

            pl_log.ins_msg ('FATAL',
                          'SND_STS_ROUTE_DETAILS',
                          MESSAGE,
                          SQLCODE,
                          SQLERRM,
                          'ORDER PROCESSING',
                          'swms_sts_func',
                          'N'
                         );
         END;

         END LOOP;                                       -- invoice loop close

         FOR dp IN get_delivery_pallet_record (i_route_no,i_route_Shpdt, st.stop_no)
           LOOP

              BEGIN

                 IF dp.float_no <> 0 then   -- to handle rare cases where sometimes float seq is not null but of 4 blank spaces - opco 045

                  dbms_output.put_line('DIP: item_id='||dp.item_id||' parent_item_id='||dp.parent_item_id||
                                       ' high_quantity?='||dp.high_quantity||' bulk_item?='||dp.bulk_item||
                                       ' split_flag='||dp.splitflag||
                                       ' planned_qty='||to_char(dp.planned_qty)||' qty='||to_char(dp.qty));

                  INSERT INTO sts_route_out
                              (sequence_no, interface_type, record_status,route_no,route_date,
                               datetime, record_type, item_id,
                               parent_item_id, high_qty,
                               bulk_item, item_class, descrip,
                               zone_name, allow_unload,
                               unload_parent, splitflag,
                               catch_weight_flag, alt_prod_id,
                               prod_size, compartment,planned_qty,qty,tax_ind,tax,
                               otherzone_float, add_user,
                               add_date, upd_user, upd_date
                              )
                       VALUES (sts_route_out_seq.NEXTVAL, 'STS', 'N',r.route_no,r.route_date,
                               SYSDATE, 'DI', dp.item_id,
                               dp.parent_item_id, dp.high_quantity,
                               dp.bulk_item, dp.itemclass, dp.itemdesc,
                               dp.zone_name, dp.allowunload,
                               dp.unloadparent,
                               dp.splitflag, dp.catchweightflag,
                               dp.alternateproductid, dp.prod_size,
                               dp.compartment,dp.planned_qty,dp.qty,dp.taxflag,dp.taxperitem,
                               dp.otherzonefloat, REPLACE (USER, 'OPS$', NULL),
                               SYSDATE, REPLACE (USER, 'OPS$', NULL), SYSDATE
                              );

                END IF;


                  FOR di IN get_delivery_item_record (i_route_no,
                                                      i_route_Shpdt,
                                                      st.stop_no,
                                                      dp.float_seq
                                                     )
                  LOOP

                    BEGIN
                      dbms_output.put_line('DII: ordd_seq='||to_char(di.ordd_seq)||
                                           ' float_id='||di.sos_status||di.float_seq_no||
                                           ' item_id='||LPAD(to_char(di.ordd_seq),8,'-')||LPAD(l_num_of_items, 4,'0')||
                                           ' parent_item_id='||di.parent_item_id||
                                           ' high_quantity?='||di.high_qty||' bulk_item?='||di.bulk_item||
                                           ' planned_qty='||to_char(di.planned_qty)||' qty='||to_char(di.qty)||
                                           ' prod_id='||di.prod_id||' split_trk='||di.split_trk||
                                           ' catch_wt_trk='||di.catch_wt_trk||
                                           ' l_cust_gs1_barcode='||l_CUST_GS1_BARCODE||
                                           ' gs1_barcode_flag='||di.gs1_barcode_flag);

                     INSERT INTO sts_route_out
                                 (sequence_no, interface_type,
                                  record_status, datetime, record_type,route_no,route_date,ordd_seq,float_id,
                                  item_id, parent_item_id,
                                  planned_qty, qty, high_qty,
                                  bulk_item, item_class,
                                  wms_item_type, order_no, prod_id,
                                  descrip, zone_name, allow_unload,
                                  unload_parent, invoice_no,
                                  splitflag, catch_weight_flag,
                                  alt_prod_id, pack,
                                  prod_size, compartment,
                                  otherzone_float, invoice_amt,
                                  seq_no, tax_ind, tax,
                                  invoice_group,
                                  add_user, add_date,
                                  upd_user, upd_date,
								  gs1_barcode_flag
                                 )
                          VALUES (sts_route_out_seq.NEXTVAL, 'STS',
                                  'N', SYSDATE, 'DI',r.route_no,r.route_date,di.ordd_seq,di.sos_status||di.float_seq_no,
                                  LPAD (di.ordd_seq, 8, '-') || LPAD (l_num_of_items, 4, '0'), di.parent_item_id,
                                  di.planned_qty, di.qty, di.high_qty,
                                  di.bulk_item, di.item_class,
                                  di.wms_item_type, di.order_no, di.prod_id,
                                  di.descrip, di.truck_zone, di.allowunload,
                                  di.unloadparent, di.invoice_no,
                                  di.split_trk, di.catch_wt_trk,
                                  di.alternateproductid, di.pack,
                                  di.prod_size, di.compartment,
                                  di.otherzonefloat, di.price,
                                  di.invoiceseq, di.taxflag, di.taxperitem,
                                  di.invoice_group,
                                  REPLACE (USER, 'OPS$', NULL), SYSDATE,
                                  REPLACE (USER, 'OPS$', NULL), SYSDATE,
								  decode(l_CUST_GS1_BARCODE, 'Y', di.gs1_barcode_flag , L_FALSE)
                                 );


                     l_num_of_items := l_num_of_items + 1;

                    EXCEPTION
                    WHEN OTHERS THEN
                    l_success_flag := FALSE;

                        MESSAGE := 'ERROR OCCURRED IN POPULATING DELIVERY ITEM RECORD'
                        || r.route_no
                        || ' Route Date:'
                        || r.route_date
                        || ' Delivery Item: '
                        || di.parent_item_id
                        || '  '
                        || di.ordd_seq;

                        pl_log.ins_msg ('FATAL',
                                      'SND_STS_ROUTE_DETAILS',
                                      MESSAGE,
                                      SQLCODE,
                                      SQLERRM,
                                      'ORDER PROCESSING',
                                      'swms_sts_func',
                                      'N'
                                     );

                    END;

                  END LOOP;                         --delivery item loop close

              EXCEPTION
                WHEN OTHERS THEN
                l_success_flag := FALSE;
                  MESSAGE := 'ERROR OCCURRED IN INSERTING DELIVERY PALLET RECORD FOR Route:'
                    || r.route_no
                    || ' Route Date:'
                    || r.route_date
                    || ' Float info: '
                    || dp.parent_item_id
                    || '  '
                    || dp.item_id;

                pl_log.ins_msg ('FATAL',
                              'SND_STS_ROUTE_DETAILS',
                              MESSAGE,
                              SQLCODE,
                              SQLERRM,
                              'ORDER PROCESSING',
                              'swms_sts_func',
                              'N'
                             );

               END;

           END LOOP;                          --delivery pallet loop close


                 MESSAGE := 'INSERTED DELIVERY ITEM RECORD FOR Route:'
                    || r.route_no
                    || ' Route Date:'
                    || r.route_date;

                pl_log.ins_msg ('DEBUG',
                              'SND_STS_ROUTE_DETAILS',
                              MESSAGE,
                              SQLCODE,
                              SQLERRM,
                              'ORDER PROCESSING',
                              'swms_sts_func',
                              'N'
                             );

               -- open cursor for high qty items and upate 'DI' record with high qty.


               FOR hq in c_high_qty_items (r.route_no,r.route_date)
               LOOP

               BEGIN

                dbms_output.put_line('HIQTY: prod_id='||hq.prod_id||' ordd_seq='||to_char(hq.ordd_seq)||
                                     ' float_seq_no='||hq.float_seq_no||' Count='||to_char(l_rowcount));

                UPDATE sts_route_out
                   SET high_qty = 'Y'
                 WHERE route_no = r.route_no
                   AND route_date = r.route_date
                   AND record_type = 'DI'
                   AND prod_id = hq.prod_id
                   AND ordd_seq = hq.ordd_seq
                   and substr(float_id,2) = hq.float_seq_no
                   and record_status not in ('S','P');

               EXCEPTION
               WHEN OTHERS THEN
               l_success_flag := FALSE;

                  MESSAGE := 'ERROR OCCURRED IN UPDATING HIGH QTY ITEMS'
                        || r.route_no
                        || ' Route Date:'
                        || r.route_date
                        || ' Prod Id: '
                        || hq.prod_id
                        || ' Ordd Seq: '
                        || hq.ordd_seq
                        || ' Float Seq No: '
                        || hq.float_seq_no;

                    pl_log.ins_msg ('FATAL',
                                  'SND_STS_ROUTE_DETAILS',
                                  MESSAGE,
                                  SQLCODE,
                                  SQLERRM,
                                  'ORDER PROCESSING',
                                  'swms_sts_func',
                                  'N'
                                 );

               END;

               END LOOP;

                 MESSAGE := 'UPDATED ALL HIGH QTY ITEMS FOR Route:'
                    || r.route_no
                    || ' Route Date:'
                    || r.route_date;

                pl_log.ins_msg ('DEBUG',
                              'SND_STS_ROUTE_DETAILS',
                              MESSAGE,
                              SQLCODE,
                              SQLERRM,
                              'ORDER PROCESSING',
                              'swms_sts_func',
                              'N'
                             );

                FOR al IN get_alt_loc_record (i_route_no,
                                              i_route_Shpdt,
                                              st.stop_no,
                                              r.truck_no )
               LOOP

               BEGIN
                 IF al.barcode IS NOT NULL AND
                    (al.float_id IS NOT NULL OR al.truck_zone IS NOT NULL) THEN
                   dbms_output.put_line('AL: barcode='||al.barcode||' float_id='||al.float_id||
                                        ' zone_name='||al.truck_zone);
                   INSERT INTO sts_route_out
                              (sequence_no, interface_type, record_status,
                               datetime, record_type, barcode, float_id,
                               zone_name, add_user,
                               add_date, upd_user, upd_date,route_no,route_date
                              )
                       VALUES (sts_route_out_seq.NEXTVAL, 'STS', 'N',
                               SYSDATE, 'AL', al.barcode, al.float_id,
                               al.truck_zone, REPLACE (USER, 'OPS$', NULL),
                               SYSDATE, REPLACE (USER, 'OPS$', NULL), SYSDATE,r.route_no,r.route_date
                              );
                 END IF;
               EXCEPTION
               WHEN OTHERS THEN

               l_success_flag := FALSE;

               MESSAGE := 'ERROR OCCURRED IN INSERTING AL RECORD'
                        || r.route_no
                        || ' Route Date:'
                        || r.route_date
                        || ' Barcode: '
                        || AL.BARCODE
                        || ' Float Id '
                        || AL.FLOAT_ID;


                    pl_log.ins_msg ('FATAL',
                                  'SND_STS_ROUTE_DETAILS',
                                  MESSAGE,
                                  SQLCODE,
                                  SQLERRM,
                                  'ORDER PROCESSING',
                                  'swms_sts_func',
                                  'N'
                                 );


               END;

               END LOOP;

               MESSAGE := 'PROCESSED CASE EXCEPTIONS FOR Route:'
                    || r.route_no
                    || ' Route Date:'
                    || r.route_date;

                pl_log.ins_msg ('DEBUG',
                              'SND_STS_ROUTE_DETAILS',
                              MESSAGE,
                              SQLCODE,
                              SQLERRM,
                              'ORDER PROCESSING',
                              'swms_sts_func',
                              'N'
                             );

           -- STS_SORT = 2 PICKUP RECORD
               FOR sr IN get_sched_return_record (i_route_no,
                                                 i_route_Shpdt,
                                                  st.stop_no  )
               LOOP

               BEGIN
                  dbms_output.put_line('SR: seq_no='||LPAD(l_pick_up_seq,3,'0')||' cust_id='||sr.cust_id||
                                       ' prod_id='||sr.prod_id||' qty='||sr.shipped_qty||'order_no='||sr.orig_invoice||
                                       ' return_reason_cd='||sr.return_reason_cd);

                  INSERT INTO sts_route_out
                              (sequence_no, interface_type, record_status,
                               datetime, record_type, seq_no,
                               CUST_ID, prod_id, descrip,
                               qty, order_no,
                               orig_wms_item_type, wms_item_type,
                               disposition, return_reason_cd,
                               invoice_wgt, return_prod_id, invoice_no,
                               invoice_amt, add_user,
                               add_date, upd_user, upd_date,route_no,route_date
                              )
                       VALUES (sts_route_out_seq.NEXTVAL, 'STS', 'N',
                               SYSDATE, 'SR', LPAD (l_pick_up_seq, 3, 0),
                               sr.cust_id, sr.prod_id, sr.descrip,
                               sr.shipped_qty, sr.orig_invoice,
                               sr.origwmsitemtype, sr.wmsitemtype,
                               sr.disposition, sr.return_reason_cd,
                               sr.weight, sr.return_prod_id, sr.invoice_no,
                               sr.invoice_amt, REPLACE (USER, 'OPS$', NULL),
                               SYSDATE, REPLACE (USER, 'OPS$', NULL), SYSDATE,r.route_no,r.route_date
                              );



                  -- insert return barcode record if ordd seq is not null for this pick up.

                  IF sr.ordd_seq is not null then
                    dbms_output.put_line('RB: cust_id='||sr.cust_id||' prod_id='||sr.prod_id||
                                         ' ordd_seq='||to_char(sr.ordd_seq)||' seq_no='||lpad(l_pick_up_seq,3,'0'));

                    INSERT INTO sts_route_out
                              (sequence_no, interface_type, record_status,
                               datetime, record_type,cust_id,prod_id,ordd_seq,seq_no,
                               add_user,
                               add_date, upd_user, upd_date,route_no,route_date
                              )
                       VALUES (sts_route_out_seq.NEXTVAL, 'STS', 'N',
                               SYSDATE, 'RB',sr.cust_id,sr.prod_id,sr.ordd_seq,lpad(l_pick_up_seq,3,0),
                               REPLACE (USER, 'OPS$', NULL),
                               SYSDATE, REPLACE (USER, 'OPS$', NULL), SYSDATE,
                               r.route_no,r.route_date
                              );
                  end if;

                  l_pick_up_seq := l_pick_up_seq + 1;

                EXCEPTION
                WHEN OTHERS THEN
                l_success_flag := FALSE;

                  MESSAGE := 'ERROR OCCURRED IN PROCESSING SR RECORD'
                        || r.route_no
                        || ' Route Date:'
                        || r.route_date
                        || ' Cust Id: '
                        || sr.cust_id
                        || ' Prod Id: '
                        || sr.prod_id;

                    pl_log.ins_msg ('FATAL',
                                  'SND_STS_ROUTE_DETAILS',
                                  MESSAGE,
                                  SQLCODE,
                                  SQLERRM,
                                  'ORDER PROCESSING',
                                  'swms_sts_func',
                                  'N'
                                 );

                END;

               END LOOP;

               MESSAGE := 'PROCESSED RETURN RECORDS FOR Route:'
                    || r.route_no
                    || ' Route Date:'
                    || r.route_date;

                pl_log.ins_msg ('DEBUG',
                              'SND_STS_ROUTE_DETAILS',
                              MESSAGE,
                              SQLCODE,
                              SQLERRM,
                              'ORDER PROCESSING',
                              'swms_sts_func',
                              'N'
                             );


         FOR sa IN get_stop_asset_record (i_route_no,  i_route_Shpdt, st.stop_no)
         LOOP

         BEGIN
            dbms_output.put_line('SA: barcode='||sa.barcode||' qty='||to_char(sa.qty_at_stop));

            INSERT INTO sts_route_out
                        (sequence_no, interface_type, record_status,
                         datetime, record_type, barcode, qty,
                         add_user, add_date,
                         upd_user, upd_date,route_no,route_date
                        )
                 VALUES (sts_route_out_seq.NEXTVAL, 'STS', 'N',
                         SYSDATE, 'SA', sa.barcode, sa.qty_at_stop,
                         REPLACE (USER, 'OPS$', NULL), SYSDATE,
                         REPLACE (USER, 'OPS$', NULL), SYSDATE,r.route_no,r.route_date
                        );

         EXCEPTION
         WHEN OTHERS THEN
         l_success_flag := FALSE;

             MESSAGE := 'ERROR OCCURRED IN POPULATING SA RECORD'
                || r.route_no
                || ' Route Date:'
                || r.route_date
                || ' Barcode: '
                || sa.barcode;

            pl_log.ins_msg ('FATAL',
                          'SND_STS_ROUTE_DETAILS',
                          MESSAGE,
                          SQLCODE,
                          SQLERRM,
                          'ORDER PROCESSING',
                          'swms_sts_func',
                          'N'
                         );

         END;

         END LOOP;

         l_prev_stop_no := l_curr_stop_no;
		 l_prev_cust_id := st.cust_id;

      END LOOP;

             MESSAGE := 'PROCESSED STOP ASSET RECORDS FOR Route:'
                    || r.route_no
                    || ' Route Date:'
                    || r.route_date;

                pl_log.ins_msg ('DEBUG',
                              'SND_STS_ROUTE_DETAILS',
                              MESSAGE,
                              SQLCODE,
                              SQLERRM,
                              'ORDER PROCESSING',
                              'swms_sts_func',
                              'N'
                             );

                                         --  stop loop close

--      --- Barcode records for this stop.
      FOR bp IN get_barcode_pallet_record (i_route_no,  i_route_Shpdt)
      LOOP

        IF bp.float_no <> 0 then             -- to handle rare cases where sometimes float seq is not null but of 4 blank spaces - opco 045
        BEGIN
         dbms_output.put_line('BC1: item_id='||bp.item_id||' barcode='||bp.barcode||
                              ' prod_id='||bp.prod_id||' qty=1 order_line_state='||bp.order_line_state||
                              ' bulk_item='||bp.bulk_item);

         INSERT INTO sts_route_out
                     (sequence_no, interface_type, record_status, datetime,
                      record_type, item_id, barcode, prod_id,qty,
                      order_line_state, bulk_item,
                      add_user, add_date,
                      upd_user, upd_date,route_no,route_date
                     )
              VALUES (sts_route_out_seq.NEXTVAL, 'STS', 'N', SYSDATE,
                      'BC', bp.item_id, bp.barcode, bp.prod_id,'1',
                      bp.order_line_state, bp.bulk_item,
                      REPLACE (USER, 'OPS$', NULL), SYSDATE,
                      REPLACE (USER, 'OPS$', NULL), SYSDATE,r.route_no,r.route_date
                     );



             MESSAGE := 'INSERTING BARCODE PALLET RECORD '
                    || r.route_no
                    || ' Route Date:'
                    || r.route_date
                    || ' Prod Id: '
                    || bp.prod_id
                    || ' Item ID: '
                    || bp.item_id
                    || ' Barcode: '
                    || bp.barcode
                    || ' Float No: '
                    || bp.float_no;

                pl_log.ins_msg ('INFO',
                              'SND_STS_ROUTE_DETAILS',
                              MESSAGE,
                              SQLCODE,
                              SQLERRM,
                              'ORDER PROCESSING',
                              'swms_sts_func',
                              'N'
                             );


        EXCEPTION
        WHEN OTHERS THEN

        l_success_flag := FALSE;

        MESSAGE := 'ERROR OCCURED IN INSERTING BARCODE PALLET RECORD '
                    || r.route_no
                    || ' Route Date:'
                    || r.route_date
                    || ' Prod Id: '
                    || bp.prod_id
                    || ' Float No: '
                    || bp.float_no;

                pl_log.ins_msg ('FATAL',
                              'SND_STS_ROUTE_DETAILS',
                              MESSAGE,
                              SQLCODE,
                              SQLERRM,
                              'ORDER PROCESSING',
                              'swms_sts_func',
                              'N'
                             );

        END;

        END IF;


        MESSAGE := 'INSERTED BARCODE FLOAT RECORDS FOR Route:'
                    || r.route_no
                    || ' Route Date:'
                    || r.route_date;

                pl_log.ins_msg ('DEBUG',
                              'SND_STS_ROUTE_DETAILS',
                              MESSAGE,
                              SQLCODE,
                              SQLERRM,
                              'ORDER PROCESSING',
                              'swms_sts_func',
                              'N'
                             );

        FOR bi IN get_barcode_item_record (i_route_no,
                                           i_route_Shpdt,
                                           bp.float_no,
                                           bp.float_seq )
        LOOP

          BEGIN

                  select sum(decode(high_qty,'Y',1,planned_qty)) into l_seq
                                      from sts_route_out
                                      where route_no = r.route_no
                                      and route_date= r.route_date
                                      and prod_id= bi.prod_id
                                      and record_type='DI'
                                      and record_status = 'N'
					and ordd_seq = bi.ordd_seq
--                                      and float_seq_no
                                      and ((parent_item_id is not null and trim(substr(parent_item_id,6,3)) = bp.float_seq)
                             or
                             (parent_item_id is null))
                                      group by parent_item_id;

              dbms_output.put_line('INFO: prod_id='||bi.prod_id||' ordd_seq='||to_char(bi.ordd_seq)||
                                   ' float_no='||to_char(bi.float_no)||' float_seq='||bp.float_seq||' l_seq='||to_char(l_seq));

		/*
		** CRQ000000017293 Use the bc_st_piece_seq to go to the next
		** barcode piece if there is 2+ floats on the same item. The
		** min() function is used to take the minimum value in case
		** we have 2+ float_detail records on different floats
		*/
	/*	BEGIN
			SELECT MIN(NVL(bc_st_piece_seq, 0))  INTO l_tmp_bc_seq
			FROM sts_route_view
			WHERE route_no = r.route_no
			AND route_date = r.route_date
			AND ordd_seq = bi.ordd_seq
			AND float_no = bi.float_no
			AND float_seq = bi.float_seq
			AND sts_sort NOT IN ('2', '3');
		EXCEPTION
			WHEN OTHERS THEN
				l_tmp_bc_seq := l_seq;
		END;
		l_seq := NVL(l_seq, 0) + NVL(l_tmp_bc_seq, 0) - 1; */

          EXCEPTION
          WHEN OTHERS THEN
          l_success_flag := FALSE;

             MESSAGE := 'ERROR OCCURED IN FETCHING ORDD SEQ - REG BC FOR PROD '
                    || r.route_no
                    || ' Route Date:'
                    || r.route_date
                    || ' Prod Id: '
                    || bi.prod_id
                    || ' Float No: '
                    || bi.float_no;

                pl_log.ins_msg ('FATAL',
                              'SND_STS_ROUTE_DETAILS',
                              MESSAGE,
                              SQLCODE,
                              SQLERRM,
                              'ORDER PROCESSING',
                              'swms_sts_func',
                              'N'
                             );

          END;



         MESSAGE := 'INSERTED BARCODE ITEM RECORDS FOR Route:'
                    || r.route_no
                    || ' Route Date:'
                    || r.route_date;

                pl_log.ins_msg ('DEBUG',
                              'SND_STS_ROUTE_DETAILS',
                              MESSAGE,
                              SQLCODE,
                              SQLERRM,
                              'ORDER PROCESSING',
                              'swms_sts_func',
                              'N'
                             );





                FOR cc in c_float_Seq_no(r.route_no,r.route_date,bi.prod_id,bi.ordd_seq,bp.float_seq)
                LOOP

                    l_sos_status := substr(cc.float_id,1,1);

                                select count(*) into l_count
                    from sts_route_out where
                        route_no = r.route_no
                        and route_date = r.route_date
                        and record_type ='BC'
                        and record_status = 'N'
			and prod_id <> '0'  --CRQ22702
                        and float_id = cc.float_id
                        and substr(barcode,1,8) in
                        (SELECT  ordd_seq
--                        into l_ordd_seq
                    FROM     sts_route_view
                       WHERE route_date = r.route_date
                       and route_no  = r.route_no
                         AND float_seq IS NOT NULL
                         and ordd_seq = cc.ordd_seq
--                         AND sos_status <> 'N'
                    GROUP BY ordd_seq, prod_id, float_seq
                      HAVING COUNT (float_seq_no) > 1 AND COUNT (DISTINCT sos_status) > 1);

           --Charm#6000008485 - Incase of high quantity then taking sum of catchweights and catch_wt_trk -START

            IF cc.high_qty ='Y' THEN

                BEGIN

                    SELECT obligation_no INTO v_obligation_no
                                            FROM manifest_stops
                                                WHERE invoice_no = cc.invoice_no;

                EXCEPTION WHEN NO_DATA_FOUND THEN

                v_obligation_no := cc.invoice_no;


                END;


                BEGIN

                  SELECT SUM(o.catch_weight),p.catch_wt_trk INTO v_catch_weight,v_catch_wt_trk
                                            FROM ordcw o, pm p
                                                WHERE o.order_id=v_obligation_no
                                                AND o.PROD_ID=bi.prod_id
                                                AND o.prod_id=p.prod_id
                                                AND o.order_line_id = (select order_line_id from ordd
                                                                                          where order_id=v_obligation_no
                                                                                            and prod_id=bi.prod_id
                                                                                            and seq= bi.ordd_seq
                                                                                            and route_no=r.route_no )
                                                GROUP BY p.catch_wt_trk;

                EXCEPTION WHEN NO_DATA_FOUND THEN

                  v_catch_weight :=0;
                  v_catch_wt_trk:='N';
                END;

            END IF;

            --Charm#6000008485 - Incase of high quantity then taking sum of catchweights -END



           IF l_count > 0 then
              continue;
           ELSE

               IF cc.high_qty = 'Y' and l_sos_status = 'N' then

               FOR bh in get_high_qty_barcode (r.route_no,r.route_date,bi.prod_id,bi.ordd_seq,bp.float_seq,cc.float_id)
               LOOP
               BEGIN
                   dbms_output.put_line('BC2: float_id='||cc.float_id||' barcode='||to_char(bi.ordd_seq)||
                                        ' item_id='||bh.item_id||' prod_id='||bi.prod_id||
                                        ' qty='||to_char(bi.qty)||' bulk_item='||bp.bulk_item||
                                        ' order_line_state='||bp.order_line_state||
                                        ' catch_wt_trk='||v_catch_wt_trk||' catch_weights='||to_char(v_catch_weight));


                --Charm#6000008485 - Added catchweight column and catch_wt_trk in the below insert query
                   INSERT INTO sts_route_out
                                  (sequence_no, interface_type, record_status,float_id,
                                   datetime, record_type, barcode,
                                   item_id,
                                   prod_id, qty, bulk_item,
                                   order_line_state,catch_weight_flag,catch_weights,
                                   add_user, add_date,
                                   upd_user, upd_date,route_no,route_date
                                  )
                           VALUES (sts_route_out_seq.NEXTVAL, 'STS', 'N',cc.float_id,
                                   SYSDATE, 'BC', bi.ordd_seq ,
                                   Bh.item_id,
                                   bi.prod_id, bi.qty, bp.bulk_item,
                                   bp.order_line_state,v_catch_wt_trk,v_catch_weight,
                                   REPLACE (USER, 'OPS$', NULL), SYSDATE,
                                   REPLACE (USER, 'OPS$', NULL), SYSDATE,r.route_no,r.route_date
                                  );

               EXCEPTION
               WHEN OTHERS THEN
               l_success_flag := FALSE;

               MESSAGE := 'ERROR OCCURED IN INSERTING BARCODE PALLET RECORD '
                    || r.route_no
                    || ' Route Date:'
                    || r.route_date
                    || ' Prod Id: '
                    || bi.prod_id
                    || ' Ordd Seq: '
                    || bi.ordd_SEq;

                pl_log.ins_msg ('FATAL',
                              'SND_STS_ROUTE_DETAILS',
                              MESSAGE,
                              SQLCODE,
                              SQLERRM,
                              'ORDER PROCESSING',
                              'swms_sts_func',
                              'N'
                             );


               END;


               END LOOP;

               ELSIF cc.high_qty = 'Y'  and (l_sos_status = 'C' or
               l_sos_status = 'S' or l_sos_status = 'H' ) then --multi pick on SOS device, need to provide sequencing to barcode,1 barcode should get print

               FOR bh in get_high_qty_barcode (r.route_no,r.route_date,bi.prod_id,bi.ordd_seq,bp.float_seq,cc.float_id)
               LOOP

               BEGIN

/*
                  l_curr_ordd_seq := bh.ordd_seq;

                  IF l_curr_ordd_seq = l_prev_ordd_seq then  -- incase if we have more than 1 high qty item in same ordd seq
                    l_h_seq := bh.qty + 1;
                  else
                    l_h_seq := '1';
                  end if;
*/
                  BEGIN
                    SELECT max(bc_st_piece_seq) INTO l_h_seq
                      FROM sts_route_view
                     WHERE route_no = r.route_no
                       AND route_date = r.route_date
                       AND prod_id = bi.prod_id
                       AND ordd_seq = bi.ordd_seq
                       AND sos_status = SUBSTR(cc.float_id,1,1)
                       AND float_seq_no = TO_NUMBER(SUBSTR(cc.float_id,2));
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      l_h_seq := 1;
                  END;

                   dbms_output.put_line('BC3: float_id='||cc.float_id||' barcode='||to_char(bi.ordd_seq)||lpad(l_h_seq,3,'0')||
                                        ' item_id='||bh.item_id||' prod_id='||bi.prod_id||' qty='||to_char(bi.qty)||
                                        ' bulk_item='||bp.bulk_item||' order_line_state='||bp.order_line_state||
                                        ' catch_weight_flag='||v_catch_wt_trk||' catch_weight='||to_char(v_catch_weight));

                  --Charm#6000008485 - Added catchweight columnand catch_wt_trk in the below insert query

                   INSERT INTO sts_route_out
                                  (sequence_no, interface_type, record_status,float_id,
                                   datetime, record_type, barcode,
                                   item_id,
                                   prod_id, qty, bulk_item,
                                   order_line_state,catch_weight_flag,catch_weights,
                                   add_user, add_date,
                                   upd_user, upd_date,route_no,route_date
                                  )
                           VALUES (sts_route_out_seq.NEXTVAL, 'STS', 'N',cc.float_id,
                                   SYSDATE, 'BC', bi.ordd_seq|| lpad(l_h_seq ,3,0),
                                   Bh.item_id,
                                   bi.prod_id, bi.qty, bp.bulk_item,
                                   bp.order_line_state,v_catch_wt_trk,v_catch_weight,
                                   REPLACE (USER, 'OPS$', NULL), SYSDATE,
                                   REPLACE (USER, 'OPS$', NULL), SYSDATE,r.route_no,r.route_date
                                  );


                   l_prev_ordd_seq := l_curr_ordd_seq;

               EXCEPTION
               WHEN OTHERS THEN
               l_success_flag := FALSE;

                    MESSAGE := 'ERROR OCCURED IN INSERTING BARCODE PALLET RECORD '
                    || r.route_no
                    || ' Route Date:'
                    || r.route_date
                    || ' Prod Id: '
                    || bi.prod_id
                    || ' Ordd Seq: '
                    || bi.ordd_SEq;

                pl_log.ins_msg ('FATAL',
                              'SND_STS_ROUTE_DETAILS',
                              MESSAGE,
                              SQLCODE,
                              SQLERRM,
                              'ORDER PROCESSING',
                              'swms_sts_func',
                              'N'
                             );

               END;

               END LOOP;

               ELSE

-- Jira 3317 - Invalid Barcode Error in STS - This problem occurs when STS is sent a different barcode then the one printed by SOS.  Real problem is the barcode numbers are -- calculated once by SOS and again here by SWMS before sending to STS.  Added the "b1" loop around the "i" loop.

                  FOR bl in get_low_qty_barcode (r.route_no,r.route_date,bi.prod_id,bi.ordd_seq,bp.float_seq,cc.float_id) LOOP
                    IF bl.selector_id IS NOT NULL THEN
                       -- .NET Pick
                       IF bl.uom = 1 THEN
                         SeqQuantity := bl.qty_ordered;
                       ELSE
                         SeqQuantity := bl.qty_alloc_u;
                       END IF;
                       StartCaseSeq := bl.bc_st_piece_seq;
                       IF bl.qty_short > 0 THEN
                         StartCaseSeq := StartCaseSeq - (SeqQuantity - bl.qty_short_u);
                       END IF;
--                       BCQuantity := bl.total_qty_u;
                    ELSE
                       StartCaseSeq := 1;
--                       BCQuantity := bl.qty_ordered_u;
                    END IF;

                    l_bc_st_piece_seq := bl.bc_st_piece_seq;

                    dbms_output.put_line('BC_INFO: selector_id='||bl.selector_id||' UOM='||to_char(bl.uom)||' qty_ordered='||to_char(bl.qty_ordered)||
                                         ' qty_alloc_u='||to_char(bl.qty_alloc_u)||' bc_st_piece_seq='||to_char(bl.bc_st_piece_seq)||' qty_short='||
                                         to_char(bl.qty_short)||' total_qty_u='||to_char(bl.total_qty_u)||' qty_ordered_u='||to_char(bl.qty_ordered_u));
                    dbms_output.put_line('BC_INFO: SeqQuantity='||to_char(SeqQuantity)||' StartCaseSeq='||to_char(StartCaseSeq)||
                                         ' l_bc_st_piece_seq='||to_char(l_bc_st_piece_seq));


--                FOR i in l_bc_st_piece_seq..(l_bc_st_piece_seq+bl.qty_ordered_u-bl.qty_short-1) loop
--                FOR i in l_bc_st_piece_seq..(l_bc_st_piece_seq+bl.qty_ordered_u-1) LOOP
                  FOR i IN 0..bl.qty_ordered_u-1 LOOP
                  begin
                    --Charm#6000008485 - Other than High quantity selecting the individual Catchweight and catch_wt_trk field -START

                    BEGIN

                    SELECT max(obligation_no) INTO v_obligation_no
                                            FROM manifest_stops
                                                WHERE invoice_no = cc.invoice_no;

                    EXCEPTION WHEN NO_DATA_FOUND THEN

                        v_obligation_no := cc.invoice_no;


                    END;

                    BEGIN

                    select catch_weight,catch_wt_trk INTO v_catch_weight,v_catch_wt_trk from (SELECT ROW_NUMBER()
                                    OVER (ORDER BY o.seq_no) As ID,o.catch_weight,p.catch_wt_trk
                                          FROM ordcw o,pm p
                                            WHERE o.order_id = v_obligation_no
                                              AND o.PROD_ID = bi.prod_id
                                              AND o.prod_id = p.prod_id
                                              AND o.order_line_id = (select order_line_id from ordd
                                                                                          where order_id = v_obligation_no
                                                                                            and prod_id = bi.prod_id
                                                                                            and seq = bi.ordd_seq
                                                                                            and route_no = r.route_no))
                                              WHERE id=l_seq;

                        /*SELECT o.catch_weight,p.catch_wt_trk INTO v_catch_weight,v_catch_wt_trk
                                          FROM ordcw o,pm p
                                            WHERE o.order_id = v_obligation_no
                                              AND o.PROD_ID = bi.prod_id
                                              AND o.prod_id = p.prod_id
                                              AND seq_no = l_seq;*/

                    EXCEPTION WHEN NO_DATA_FOUND THEN

                    v_catch_weight := 0;
                    v_catch_wt_trk := 'N';

                    END;

                   --Charm#6000008485 - END

                    dbms_output.put_line('BC4: float_id='||cc.float_id||' barcode='||to_char(bl.ordd_seq)||lpad(i+StartCaseSeq,3,'0')||
                                         ' item_id='||to_char(bi.ordd_seq)||LPAD(cc.l_bc_seq,4,'0')||' prod_id='||bl.prod_id||
                                         ' qty_ordered_u='||to_char(bl.qty_ordered_u)||bl.unit||' qty_short_u='||to_char(bl.qty_short_u)||bl.unit||
                                         ' l_bc_st_piece_seq='||to_char(l_bc_st_piece_seq)||
                                         ' bulk_item='||bp.bulk_item||' order_line_state='||bp.order_line_state||
                                         ' catch_weight_flag='||v_catch_wt_trk||' catch_weight='||to_char(v_catch_weight));

                   --Charm#6000008485 - Added catchweight column and catch_wt_trk field  in the below insert query

                    INSERT INTO sts_route_out
                              (sequence_no, interface_type, record_status,float_id,
                               datetime, record_type, barcode,
                               item_id,
                               prod_id, qty, bulk_item,
                               order_line_state,catch_weight_flag,catch_weights,
                               add_user, add_date,
                               upd_user, upd_date,route_no,route_date
                              )
                       VALUES (sts_route_out_seq.NEXTVAL, 'STS', 'N',cc.float_id,
                               SYSDATE, 'BC', to_char(bi.ordd_seq) || LPAD (i+StartCaseSeq, 3, 0),
                               to_char(bi.ordd_seq) || LPAD (cc.l_bc_seq, 4, 0),
                               bi.prod_id, bi.qty, bp.bulk_item,
                               bp.order_line_state,v_catch_wt_trk,v_catch_weight,
                               REPLACE (USER, 'OPS$', NULL), SYSDATE,
                               REPLACE (USER, 'OPS$', NULL), SYSDATE,r.route_no,r.route_date
                              );


                     l_seq:= l_seq - 1;

                    EXCEPTION
                    WHEN OTHERS THEN

                    l_success_flag := FALSE;

                         MESSAGE := 'ERROR OCCURED IN INSERTING BARCODE PALLET RECORD '
                            || r.route_no
                            || ' Route Date:'
                            || r.route_date
                            || ' Prod Id: '
                            || bi.prod_id
                            || ' Ordd Seq: '
                            || bi.ordd_SEq;

                    pl_log.ins_msg ('FATAL',
                                  'SND_STS_ROUTE_DETAILS',
                                  MESSAGE,
                                  SQLCODE,
                                  SQLERRM,
                                  'ORDER PROCESSING',
                                  'swms_sts_func',
                                  'N'
                                 );

                    END;

                   end loop;
                 END LOOP;  -- low qty barcode loop close
               end if;
             END IF;


             l_count:=0;
             l_ordd_seq:=0;

           END LOOP;

        END LOOP;                                  -- barcode item loop close


      END LOOP;                                   -- barcode pallet loop close

      MESSAGE := 'END populating STS_ROUTE_OUT table for Route:'
            || r.route_no
            || ' Route Date:'
            || r.route_date;

        pl_log.ins_msg ('DEBUG',
                      'SND_STS_ROUTE_DETAILS',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'swms_sts_func',
                      'N'
                     );

            --   to avoid duplicate barcodes marking the multistoppick indicator as 'Y'

        Begin

            UPDATE STS_ROUTE_OUT set BULK_ITEM = 'Y'
            WHERE route_no = r.route_no
            AND route_date = r.route_date
            AND record_type = 'BC'
            and batch_id is null
            and barcode in (
                    SELECT  distinct barcode
                        FROM sts_route_out
                       WHERE record_type = 'BC'
                         AND record_status = 'N'
			 AND prod_id <> '0'  --CRQ22702
                         AND route_no = r.route_no
                         AND route_date = r.route_date
                         AND batch_id is null
                    GROUP BY barcode
                      HAVING COUNT (*) > 1
            );

        EXCEPTION
        WHEN OTHERS THEN
        l_success_flag := FALSE;

                         MESSAGE := 'ERROR OCCURED WHILE UPDATING MULTISTOP BULK INDICATOR AS Y '
                            || r.route_no
                            || ' Route Date:'
                            || r.route_date;


                    pl_log.ins_msg ('FATAL',
                                  'SND_STS_ROUTE_DETAILS',
                                  MESSAGE,
                                  SQLCODE,
                                  SQLERRM,
                                  'ORDER PROCESSING',
                                  'swms_sts_func',
                                  'N'
                                 );
        END;

   END LOOP;

   delete_dup_barcodes(i_route_no, i_route_date);

   IF l_success_flag = TRUE THEN
    COMMIT;
   ELSE
    ROLLBACK;
   END IF;

BEGIN
	UPDATE sys_config
		SET CONFIG_FLAG_VAL = 'N'
	WHERE config_flag_name = 'STS_PROCESS_RUN_FLAG';
	COMMIT;

	EXCEPTION
      WHEN OTHERS THEN
      l_success_flag := FALSE;

      MESSAGE := 'ERROR OCCURRED WHILE SETTING STS_PROCESS_RUN_FLAG TO N';

        pl_log.ins_msg ('FATAL',
                      'SND_STS_ROUTE_DETAILS',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'swms_sts_func',
                      'N'
                     );
 END;

 ELSE

                     MESSAGE := 'STS PROCESS IS ALREADY RUNNING ';
                     pl_log.ins_msg ('FATAL',
                                  'SND_STS_ROUTE_DETAILS',
                                  MESSAGE,
                                  SQLCODE,
                                  SQLERRM,
                                  'ORDER PROCESSING',
                                  'swms_sts_func',
                                  'N'
                                 );

END IF;
--lnic4226 CRQ000000017293-Modified the code not to update the sts_process_flag to 'N' if the process is already running to avoid duplicate barcode issue.

EXCEPTION
WHEN OTHERS THEN

ROLLBACK;

	--  CRQ22702 updating process run flag back to 'N' to enable the next session to run.
	UPDATE sys_config
			SET CONFIG_FLAG_VAL = 'N'
		WHERE config_flag_name = 'STS_PROCESS_RUN_FLAG';
	COMMIT;

    MESSAGE := 'ERROR running SND_STS_ROUTE_DETAILS ';

        pl_log.ins_msg ('FATAL',
                      'SND_STS_ROUTE_DETAILS',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'swms_sts_func',
                      'N');
-- route loop close
END snd_sts_route_details;

 PROCEDURE P_STS_IMPORT_ASSET
(i_route_no     sts_route_in.route_no%TYPE,
 i_cust_id      sts_route_in.cust_id%TYPE,
 i_barcode      sts_route_in.barcode%TYPE,
 i_qty          sts_route_in.quantity%TYPE,
 i_route_date   sts_route_in.route_date%TYPE,
 i_time_stamp   sts_route_in.time_stamp%TYPE,
 i_event_type   sts_route_in.event_type%TYPE,
 o_status       OUT NUMBER)
IS

/******************************************************************************
   NAME:       P_STS_IMPORT_ASSET
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/18/2015   mdev3739       1. Created this procedure.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     P_STS_IMPORT_ASSET
      Sysdate:         2/18/2015
      Date and Time:   2/18/2015, 7:36:12 PM, and 2/18/2015 7:36:12 PM
      Username:        mdev3739 (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/

v_qty               sts_equipment.qty%TYPE;
v_qty_returned      sts_equipment.qty_returned%TYPE;
v_date              sts_equipment.add_date%TYPE;
v_remain_qty        sts_equipment.qty%TYPE;
v_orig_qty          sts_route_in.quantity%TYPE;
v_truck_no          sts_equipment.truck_no%TYPE;

CURSOR c_sts_import_asset IS
SELECT qty, qty_returned, to_char( add_date, 'YYYYMMDDHH24MISS' )
      FROM sts_equipment
      WHERE route_no = i_route_no
        AND cust_id = i_cust_id
        AND barcode = i_barcode
        AND status = 'D'
        AND ( qty - qty_returned > 0 );
BEGIN

/* Previous equipment Update */
   IF i_event_type = 'P' THEN

    OPEN c_sts_import_asset;
     LOOP
    FETCH c_sts_import_asset INTO v_qty,v_qty_returned,v_date;
    EXIT WHEN c_sts_import_asset%NOTFOUND;


        IF v_orig_qty > 0 THEN
            v_remain_qty := v_qty - v_qty_returned;

            IF ( v_remain_qty <= v_orig_qty ) THEN

                v_orig_qty := v_orig_qty - v_remain_qty ;
                v_qty_returned := v_qty_returned + v_remain_qty ;

            ELSE

                v_qty_returned := v_qty_returned + v_orig_qty;

                v_orig_qty := 0;
            END IF;

        END IF;

          UPDATE STS_EQUIPMENT
               SET qty_returned = v_qty_returned
                WHERE route_no = i_route_no
                AND cust_id = i_cust_id
                AND barcode = i_barcode
                AND add_date = v_date;

    END LOOP;

    END IF;


        SELECT DISTINCT TRUCK_NO
        INTO v_truck_no
        FROM STS_ITEMS
        WHERE ROUTE_NO = i_route_no AND
              ROUTE_DATE = i_route_date AND
              ROWNUM = 1;

        INSERT INTO STS_EQUIPMENT (ROUTE_NO, TRUCK_NO, CUST_ID, BARCODE,
                              STATUS, QTY, QTY_RETURNED, ADD_DATE)
              VALUES ( i_route_no,v_truck_no ,i_cust_id ,i_barcode ,
                       i_event_type,v_orig_qty,0,i_time_stamp );
        o_status := 0; -- Success

   EXCEPTION
     WHEN NO_DATA_FOUND THEN

     dbms_output.put_line('subprogram'||SQLCODE||SQLERRM );
       pl_log.ins_msg( 'FATAL', 'P_STS_IMPORT_ASSET','Error in processing the sts_route_in records', SQLCODE,  SQLERRM, 'O', 'STS_RETURN' );
        o_status := 1;  -- Failiure
     WHEN OTHERS THEN
     dbms_output.put_line('subprogram'||SQLCODE||SQLERRM );
       -- Consider logging the error and then re-raise
       pl_log.ins_msg( 'FATAL', 'P_STS_IMPORT_ASSET','Error in processing the sts_route_in records', SQLCODE,  SQLERRM, 'O', 'STS_RETURN' );
        o_status := 1;  -- Failiure
END P_STS_IMPORT_ASSET;

PROCEDURE P_STS_IMPORT IS
/******************************************************************************
   NAME:       P_STS_IMPORT
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/17/2015   mdev3739       1. Created this procedure.

   NOTES:

   This procedure is common for return,cash/check,assets. We are processing the
   each message_id and inserting into

   Automatically available Auto Replace Keywords:
      Object Name:     P_STS_IMPORT
      Sysdate:         2/17/2015
      Date and Time:   2/17/2015, 2:27:42 PM, and 2/17/2015 2:27:42 PM
      Username:        mdev3739 (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/
MESSAGE         VARCHAR2 (2000);
v_msg_id            sts_route_in.msg_id%TYPE;
v_route_sts         sts_route_in.route_no%TYPE;
v_sts_route         sts_route_in%ROWTYPE;
--v_add_date          sts_route_in.add_date%TYPE;
v_qty               sts_route_in.qty_split%TYPE;
v_check_batch_no    sts_cash_batch.batch_no%TYPE;
v_route_date        sts_cash_batch.route_date%TYPE;
v_count_cash        sts_route_in.credit_amt%TYPE;
v_alt_stop_sts      sts_route_in.alt_stop_no%TYPE;
v_manifest_no       sts_route_in.manifest_no%TYPE;
v_up_dt             sts_route_in.upd_date%TYPE;
RTN_process_flag    BOOLEAN;
v_pod_flag            manifest_stops.pod_flag%type;
v_opco_pod_flag       sys_config.config_flag_val%type;
v_invoice           manifest_stops.obligation_no%type;
status              VARCHAR2(3);
v_count_stc         NUMBER;
v_count             NUMBER;
v_count_cmp_rtn     NUMBER;
v_status            NUMBER  :=0;
e_failed            EXCEPTION;
v_split_cd          sts_route_in.wms_item_type%TYPE;
v_orig_split_cd     sts_route_in.orig_wms_item_type%TYPE;
l_curr_cust_id      sts_route_in.cust_id%TYPE;
l_prev_cust_id      sts_route_in.cust_id%TYPE;
l_cash_inc          NUMBER;
l_check_inc         NUMBER;
v_count_check       NUMBER;
l_check_no          VARCHAR2(5);
l_curr_type         VARCHAR2(15);
l_prev_type         VARCHAR2(15);
l_item_seq          NUMBER;
l_cash_item_seq     NUMBER;
l_chk_item_seq      NUMBER;
v_cash_batch_no     sts_cash_batch.batch_no%TYPE;
l_whole_pallet_reject VARCHAR2(2);
l_count             NUMBER;
l_rt_count          NUMBER;

--i                   integer :=0;
l_whole_pallet_reject_1 VARCHAR2(2);
v_split_cd_1        sts_route_in.wms_item_type%TYPE;

i_cnt               NUMBER; --10/13/19

i_td_cnt_1            number; --10/27/19
i_rn_cnt_1            number; --10/27/19






    /* Cursor for taking all message id*/
    CURSOR c_sts_route IS
    SELECT DISTINCT msg_id
                         FROM sts_route_in
                            WHERE record_status = 'N'
                            ORDER BY msg_id;

    /* Cursor for processing the message id one by one*/

	-- for Jira #OPCOF-2478
	CURSOR c_rj(per_message_id varchar2) IS
	select manifest_no, route_no,  msg_id, alt_stop_no, prod_id, invoice_num, record_type, return_reason_cd,  quantity,
    weight, return_prod_id, item_id, wms_item_type, sum(return_qty) return_qty
    from sts_route_in
	WHERE msg_id=per_message_id
    AND record_status = 'N'
    and record_type = 'RJ'
	group by manifest_no, route_no,  msg_id, alt_stop_no, prod_id, invoice_num, record_type, return_reason_cd, quantity,
    weight, return_prod_id, item_id, wms_item_type;


    CURSOR c_sts_route_message_id(per_message_id varchar2) IS
    SELECT * FROM sts_route_in
                    WHERE msg_id=per_message_id
                      AND record_status = 'N'
                      ORDER BY sequence_no;


    /* Cursor to fetch Cash invoice per message id */
    /* Need to process Money Order as Cash record */
    CURSOR c_cash_invoice ( i_msg_id sts_route_in.msg_id%TYPE,
    i_route_no sts_route_in.route_no%TYPE,
    i_route_date sts_route_in.route_date%TYPE)
 --   i_add_date sts_route_in.add_date%TYPE)
    IS
    SELECT   cust_id,credit_amt,invoice_num,check_no,manifest_no,event_type
        FROM sts_route_in
       WHERE msg_id = i_msg_id
         AND route_no = i_route_no
         AND route_date = i_route_date
         AND record_status = 'N'
         AND record_type = 'IV'
         AND event_type in ('Money Order', 'Cash')
         AND credit_amt <> '0'
    --     and add_date = i_add_date
    ORDER BY cust_id;

    CURSOR c_check_invoice ( i_msg_id sts_route_in.msg_id%TYPE,
    i_route_no sts_route_in.route_no%TYPE,
    i_route_date sts_route_in.route_date%TYPE)
  --  i_add_date sts_route_in.add_date%TYPE)
    IS
        SELECT  cust_id,credit_amt,manifest_no,invoice_num,check_no
        FROM sts_route_in
       WHERE msg_id = i_msg_id
         AND route_no = i_route_no
         AND route_date = i_route_date
         AND record_status = 'N'
         AND record_type = 'IV'
         AND event_type = 'Check'
         AND credit_amt <> '0'
     --    and add_date = i_add_date
    ORDER BY cust_id;
 --Added for CRQ34059, cursor to fetch ST records per msg id
    CURSOR c_stop_records ( i_msg_id sts_route_in.msg_id%TYPE)
    IS
    SELECT manifest_no,cust_id,alt_stop_no,route_date,route_no
    FROM sts_route_in
    WHERE msg_id = i_msg_id
    AND record_type = 'ST'
    order by datetime;
    CURSOR c_return_records ( i_msg_id sts_route_in.msg_id%TYPE, i_stop_no sts_route_in.alt_stop_no%TYPE )
    IS
    SELECT invoice_num,manifest_no,alt_stop_no
    from sts_route_in
    WHERE msg_id = i_msg_id
    AND record_type in ('RJ','SR')
	AND INVOICE_NUM IS NOT NULL
	AND alt_stop_no=i_stop_no
    order by datetime;



BEGIN

   OPEN c_sts_route;
   LOOP
        v_count_cash := 1;
        v_count_check := 1;
        v_count_cmp_rtn := 0;
        l_curr_cust_id := 0;
        l_prev_cust_id := -1;
        l_cash_inc     := 1;
        l_check_inc    := 1;
        l_curr_type    :=0;
        l_prev_type    := -1;
		l_count		   := 0;

   FETCH c_sts_route INTO v_msg_id;
   --,v_add_date;
   EXIT WHEN c_sts_route%NOTFOUND;

    SELECT DISTINCT route_no,route_date INTO v_route_sts,v_route_date
                                  FROM sts_route_in
                                  WHERE msg_id=v_msg_id
                                    AND record_type='RT';

		/*Jira 399-added validations to handle return duplicates or not creating Returns in the STS process */
	select config_flag_val into v_opco_pod_flag
    from sys_config where config_flag_name='POD_ENABLE';

    IF v_opco_pod_flag='N' THEN
    SELECT COUNT (*) INTO l_rt_count
	  FROM sts_route_in
	 WHERE     record_type = 'RT'
		   AND record_status = 'S'
		   AND msg_id = v_msg_id
		   AND route_no = v_route_sts
		   AND route_date = v_route_date;

	IF (l_rt_count>0) THEN
	-- Failing the batch as it was already processed to SWMS.
	UPDATE STS_ROUTE_IN
	   SET RECORD_STATUS = 'F'
	 WHERE     msg_id = v_msg_id
		   AND route_no = v_route_sts
		   AND route_date = v_route_date;
	COMMIT;
	CONTINUE;
	END IF;
	END IF;
	-- Retrieving the count of ST records that was processed.
  -- Added for CRQ34059
	FOR c_available in c_stop_records(v_msg_id)
    LOOP
    SELECT COUNT (*) INTO l_count
      FROM sts_route_in
     WHERE     record_type = 'ST'
           AND record_status = 'S'
           AND route_no = c_available.route_no
           AND route_date = c_available.route_date
           AND alt_stop_no = c_available.alt_stop_no;


    IF (l_count>0) THEN
        -- If there are any CMP status returns for the manifest, then tripmaster is complete.
        SELECT count(*) INTO v_count_cmp_rtn
        FROM returns r
        WHERE r.manifest_no = c_available.manifest_no
        AND r.status = 'CMP';

        SELECT manifest_status INTO status
        FROM manifests
        WHERE manifest_no=c_available.manifest_no;

        FOR c_avail in c_return_records(v_msg_id,c_available.alt_stop_no)

        LOOP
            SELECT distinct nvl(pod_flag,'N') INTO v_pod_flag
            FROM manifest_stops
            WHERE manifest_no= c_avail.manifest_no
            and stop_no=floor( to_number(c_avail.alt_stop_no))
            and obligation_no=c_avail.invoice_num;

            -- Added v_count_cmp_rtn to check if Tripmaster is done. If tripmaster is done, then don't delete anything
            IF v_pod_flag='N' and status='OPN' and v_count_cmp_rtn = 0 then
                delete from returns
                where manifest_no= c_avail.manifest_no
                and stop_no=floor( to_number(c_avail.alt_stop_no))
                and obligation_no=c_avail.invoice_num;
                COMMIT;

            END IF;
        END LOOP;
    END IF;
    END LOOP;

    for r_rj in c_rj(v_msg_id)
    loop

	      --i := i+1;
	      SELECT SUBSTR (r_rj.item_id, 1, 1)
          INTO l_whole_pallet_reject_1
          FROM DUAL;

		  SELECT DECODE (r_rj.wms_item_type, 'S', 1,0)
                          INTO v_split_cd_1
                          FROM DUAL;

	      if l_whole_pallet_reject_1 <> 'F' THEN
            dbms_output.put_line('loop in RJ' );
            STS_RETURN( r_rj.manifest_no,
                        r_rj.route_no,
                        r_rj.alt_stop_no,
                        'I',
                        r_rj.invoice_num,
                        r_rj.prod_id,
                        '-',
                        r_rj.return_reason_cd,
                        r_rj.return_qty,
                        v_split_cd_1,
                        r_rj.weight,
                        NULL,
                        r_rj.return_prod_id,
                        NULL,
                        r_rj.quantity,
                        v_split_cd_1,
                        NULL, NULL);
       	  end if;

	end loop;

    /* Opening the cursor to process the each record */

        OPEN c_sts_route_message_id(v_msg_id);
        LOOP
            FETCH c_sts_route_message_id INTO v_sts_route;
            EXIT WHEN c_sts_route_message_id%NOTFOUND;


        /* selecting the splic_cd to insert into return table */

                    SELECT DECODE (v_sts_route.wms_item_type, 'S', 1,0)
                          INTO v_split_cd
                          FROM DUAL;

                            /* Formatted on 2015/03/27 20:20 (Formatter Plus v4.8.8) */
                    SELECT DECODE (v_sts_route.orig_wms_item_type, 'S', 1,0)
                      INTO v_orig_split_cd
                      FROM DUAL;

                      /* for whole pallet reject scenario */

                      /* Formatted on 2015/03/31 11:53 (Formatter Plus v4.8.8) */
                            SELECT SUBSTR (v_sts_route.item_id, 1, 1)
                              INTO l_whole_pallet_reject
                              FROM DUAL;


                  /*  IF v_sts_route.record_type = 'RT' THEN

                         v_route_sts := v_sts_route.route_no;
                         v_route_date := v_sts_route.route_date;

                    END IF;

                    IF v_sts_route.record_type = 'ST' THEN

                        v_alt_stop_sts := v_sts_route.alt_stop_no;
                        v_manifest_no  := v_sts_route.manifest_no;

                    END IF;*/

             /* putting the rejects, shorts, splits and pickup returns info to the database */



            IF v_sts_route.record_type = 'DI' AND v_sts_route.return_qty > 0 THEN


                sts_return(v_sts_route.manifest_no,
                           v_sts_route.route_no,
                           v_sts_route.alt_stop_no,
                           'I',
                           v_sts_route.invoice_num,
                           v_sts_route.prod_id,
                           '-',
                           v_sts_route.return_reason_cd,
                           v_sts_route.return_qty,
                           v_split_cd,
                           NULL, NULL, NULL, NULL,
                           v_sts_route.quantity,
                           v_split_cd,
                           NULL,NULL);

     --        IF v_status = 1 THEN
     --               RAISE  e_failed;
     --        END IF;

            ELSIF v_sts_route.record_type = 'SR' THEN

            STS_RETURN( v_sts_route.manifest_no,
                        v_sts_route.route_no,
                        v_sts_route.alt_stop_no,
                        'P',
                        v_sts_route.invoice_num,
                        v_sts_route.prod_id,
                        '-',
                        v_sts_route.return_reason_cd,
                        v_sts_route.return_qty,
                        v_split_cd,
                        v_sts_route.weight,
                        v_sts_route.disposition,
                        v_sts_route.return_prod_id,
                        NULL,
                        v_sts_route.quantity,
                        v_orig_split_cd,
                        NULL,NULL);

      --        IF v_status = 1 THEN
      --              RAISE  e_failed;
      --        END IF;
             /*
            ELSIF v_sts_route.record_type = 'RJ' and l_whole_pallet_reject <> 'F' THEN
            dbms_output.put_line('loop in RJ' );
            STS_RETURN( v_sts_route.manifest_no,
                        v_sts_route.route_no,
                        v_sts_route.alt_stop_no,
                        'I',
                        v_sts_route.invoice_num,
                        v_sts_route.prod_id,
                        '-',
                        v_sts_route.return_reason_cd,
                        v_sts_route.return_qty,
                        v_split_cd,
                        v_sts_route.weight,
                        NULL,
                        v_sts_route.return_prod_id,
                        NULL,
                        v_sts_route.quantity,
                        v_split_cd,
                        NULL, NULL);
              */
       --      IF v_status = 1 THEN

       --      dbms_output.put_line(v_status );
       --             RAISE  e_failed;

       --      END IF;

            ELSIF v_sts_route.record_type = 'SP' THEN

                IF v_sts_route.hight_qty = 'Y' THEN

                    v_qty := v_sts_route.qty_split;
                ELSE
                    v_qty := 1;
                END IF;


            STS_RETURN( v_sts_route.manifest_no,
                        v_sts_route.route_no,
                        v_sts_route.alt_stop_no,
                        'I',
                        v_sts_route.invoice_num,
                        v_sts_route.prod_id,
                        '-',
                        v_sts_route.refusal_reason_cd,
                        v_qty,
                        v_split_cd,
                        v_sts_route.weight_adj,
                        NULL,
                        NULL,
                        NULL,
                        v_sts_route.quantity,
                        v_split_cd,
                        NULL, NULL);

           --  IF v_status = 1 THEN
           --         RAISE  e_failed;
          --   END IF;

            END IF;

            /* putting the cash and check info to the database as a each item */


           /* Calling the sts_impor_ Asset Program */

           IF v_sts_route.RECORD_TYPE = 'AT' THEN

                P_STS_IMPORT_ASSET (v_sts_route.route_no,
                                    v_sts_route.cust_id,
                                    v_sts_route.barcode,
                                    v_sts_route.quantity,
                                    v_sts_route.route_date,
                                    v_sts_route.time_stamp,
                                    v_sts_route.event_type,
                                    v_status);

                IF v_status = 1 THEN
                    RAISE  e_failed;
                END IF;

           END IF;

        END LOOP;

       CLOSE c_sts_route_message_id;

/* CASH processing */

       /* To check whether batch existing or not for cash/check upload for the same route date*/

        SELECT COUNT(1) INTO v_count FROM sts_cash_batch
                            WHERE ROWNUM = 1
                                AND upload_time IS NULL
                                AND route_no = 'CASH'
                                AND route_date = v_route_date;
--                                FOR UPDATE NOWAIT;

        IF v_count > 0 THEN

         /* Formatted on 2015/03/27 20:25 (Formatter Plus v4.8.8) */
        SELECT batch_no
          INTO v_cash_batch_no
          FROM sts_cash_batch
         WHERE ROWNUM = 1
           AND upload_time IS NULL
           AND route_no = 'CASH'
           AND route_date = v_route_date
           FOR UPDATE NOWAIT;

        /* Formatted on 2015/03/27 20:28 (Formatter Plus v4.8.8) */
        SELECT nvl(MAX (item_seq),0)
          INTO l_cash_item_seq
          FROM sts_cash_item
         WHERE batch_no = v_cash_batch_no;

         l_cash_item_seq := l_cash_item_seq +1;

        END IF;


        /* Insert entry into CASH_BATCH table for CASH */

         /* putting the cash and check info to the database as a batch */

      IF v_cash_batch_no IS NULL THEN

      select sts_cash_batch_no_seq.NEXTVAL into v_cash_batch_no from dual;

      INSERT INTO STS_CASH_BATCH
           ( batch_no, route_no, route_date, total_items)
          VALUES ( v_cash_batch_no,
                   'CASH',
                   v_route_date,
                   v_count_cash
                 );

        l_cash_item_seq := 1;

      END IF;

      FOR r_cash_invoice IN c_cash_invoice (v_msg_id,v_route_sts,v_route_date)
      LOOP

      l_curr_cust_id := r_cash_invoice.cust_id;
      l_curr_type := r_cash_invoice.event_type;

      IF l_curr_cust_id = l_prev_cust_id  AND l_curr_type = l_prev_type THEN

        l_cash_inc := l_cash_inc + 1;

      END IF;

      l_check_no := 'CASH';

         /* Formatted on 2015/03/26 21:21 (Formatter Plus v4.8.8) */
        INSERT INTO sts_cash_item
                    (batch_no,
                     item_seq,
                     cust_id,
                     amount,
                     invoice_num,
                     invoice_date,
                     check_num,
                     manifest_no
                    )
             VALUES (v_cash_batch_no,
                     l_cash_item_seq,
                     r_cash_invoice.cust_id,
                     r_cash_invoice.credit_amt,
                     r_cash_invoice.invoice_num,
                     SYSDATE,
                     lpad(l_check_no || l_cash_inc,8,' '),
                     r_cash_invoice.manifest_no
                    );

--           v_count_cash := v_count_cash+1;

           l_prev_cust_id := l_curr_cust_id;
           l_prev_type := l_curr_type;
           l_cash_item_seq := l_cash_item_seq + 1;

     END LOOP;

       /* CHECK processing */

       /* To check whether batch existing or not for cash/check upload for the same route date*/

        SELECT COUNT(1) INTO v_count FROM sts_cash_batch
                            WHERE ROWNUM = 1
                                AND upload_time IS NULL
                                AND route_no = 'CHEC'
                                AND route_date = v_route_date;
--                                FOR UPDATE NOWAIT;

        IF v_count > 0 THEN

         /* Formatted on 2015/03/27 20:25 (Formatter Plus v4.8.8) */
        SELECT batch_no
          INTO v_check_batch_no
          FROM sts_cash_batch
         WHERE ROWNUM = 1
           AND upload_time IS NULL
           AND route_no = 'CHEC'
           AND route_date = v_route_date
           FOR UPDATE NOWAIT;

        /* Formatted on 2015/03/27 20:28 (Formatter Plus v4.8.8) */
        SELECT nvl(MAX (item_seq),0)
          INTO l_chk_item_seq
          FROM sts_cash_item
         WHERE batch_no = v_check_batch_no;

         l_chk_item_seq := l_chk_item_seq + 1;

        END IF;


        /* Insert entry into CASH_BATCH table for CASH */

         /* putting the cash and check info to the database as a batch */

      IF v_check_batch_no IS NULL THEN

      select sts_cash_batch_no_seq.NEXTVAL into v_check_batch_no from dual;

      INSERT INTO STS_CASH_BATCH
           ( batch_no, route_no, route_date, total_items)
          VALUES ( v_check_batch_no,
                   'CHEC',
                   v_route_date,
                   v_count_check
                 );

       l_chk_item_seq := 1;

      END IF;

     FOR r_check_invoice IN c_check_invoice (v_msg_id,v_route_sts,v_route_date)
     LOOP

     INSERT INTO sts_cash_item
                    (batch_no,
                     item_seq,
                     cust_id,
                      amount,
                     invoice_num,
                     invoice_date,
                     check_num,
                     manifest_no
                    )
             VALUES (v_check_batch_no,
                     l_chk_item_seq,
                     r_check_invoice.cust_id,
                     r_check_invoice.credit_amt,
                     r_check_invoice.invoice_num,
                     SYSDATE,
                     SUBSTR (r_check_invoice.check_no, 1, 8),
                      r_check_invoice.manifest_no
                    );

--          v_count_check := v_count_check+1;

            l_chk_item_seq := l_chk_item_seq + 1;

     END LOOP;


      dbms_output.put_line('value of v_status'||v_status );
     /* Updating the messgae_id as completed */

    UPDATE sts_route_in SET record_status = 'S'
                            WHERE msg_id = v_msg_id;

    IF  v_status = 0 THEN
    COMMIT;
    END IF;
    --Added for CRQ34059, to process returns if customer level POD flag and syspar POD_ENABLE
    --is turned ON
    SELECT distinct manifest_no,to_date('01-JAN-1980','DD-MON-YYYY') INTO v_manifest_no,v_up_dt
    FROM sts_route_in
    WHERE msg_id=v_msg_id AND record_type='ST';

    FOR c_available in c_stop_records (v_msg_id)
    LOOP
    select config_flag_val INTO v_opco_pod_flag
    from sys_config
    where config_flag_name='POD_ENABLE';

    select distinct pod_flag INTO v_pod_flag
    from manifest_stops
    where manifest_no=v_manifest_no
    and stop_no=floor( to_number(c_available.alt_stop_no))
    and customer_id=c_available.cust_id;

		select count(*)
		into i_cnt
		from sts_route_in
		where alt_stop_no = floor( to_number(c_available.alt_stop_no) )
		and msg_id=v_msg_id
		and ( (return_reason_cd like 'T%') or (return_reason_cd like 'D%') or (return_reason_cd = 'N01') );

    IF  v_pod_flag='Y' and v_opco_pod_flag ='Y' THEN
    POD_create_RTN(v_manifest_no,c_available.alt_stop_no,RTN_process_flag,c_available.cust_id, c_available.route_no,v_msg_id);
    --insert stop close(STC) after successful processing of item returns.
    v_count_stc :=0;
    SELECT count(*) INTO v_count_stc
    FROM trans
    WHERE trans_type='STC'
    AND  stop_no=floor( to_number(c_available.alt_stop_no))
    AND  cust_id = c_available.cust_id
    AND  route_no=c_available.route_no
    AND  rec_id=v_manifest_no;


	    --10/27


 	      select count(*)
		   into i_td_cnt_1
           from sts_route_in
           where
           --record_status = 'N'
		   --and route_no = i_route_no --msg_id = t_msg_id
		   --and
           msg_id = v_msg_id
		   and ( (return_reason_cd like 'T%') or
		         (return_reason_cd like 'D%') or
		         (return_reason_cd = 'N01' ) );


           	   pl_log.ins_msg ('INFO',
                      'pl_sts_interfaces',
                      'in pls_sts_interface.p_sts_import before insert STC msg_id= '||v_msg_id||
                      ' i_td_cnt_1 = '||to_char(i_td_cnt_1),
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'pls_sts_interface.pod_create_rtn',
                      'u'
                     );

	    select count(*)
		   into i_rn_cnt_1
           from sts_route_in
           where
           msg_id = v_msg_id
		   and ( (return_reason_cd like 'R%') or
		         (return_reason_cd like 'W%') or
		         (return_reason_cd like 'N%' and return_reason_cd != 'N01') );


        pl_log.ins_msg ('INFO',
                      'pl_sts_interfaces',
                      'in pls_sts_interface.p_sts_import before insert STC msg_id= '||v_msg_id||
                      ' i_rn_cnt_1 = '||to_char(i_rn_cnt_1),
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'pls_sts_interface.pod_create_rtn',
                      'u'
                     );




    -- 10/27


    IF  v_count_stc > 0 THEN
       NULL;
    ELSE
    --IF (RTN_process_flag=TRUE) THEN
	--  if (RTN_process_flag=TRUE and i_cnt = 0) THEN --10/13/19
	  --if ( (RTN_process_flag=TRUE and i_td_cnt_1 = 0) -- take out 10/29/19
        --     or (RTN_process_flag=TRUE and i_rn_cnt_1 > 0)) THEN
	  if ( (RTN_process_flag=TRUE) and (i_td_cnt_1 = 0)) THEN
         BEGIN
               INSERT INTO TRANS
               (      TRANS_ID,
                      TRANS_TYPE,
                      TRANS_DATE,
                      batch_no,
                      ROUTE_NO,
                      STOP_NO,
                      REC_ID,
                      UPLOAD_TIME,
                      USER_ID,
                      CUST_ID
                      )
               VALUES
               (      TRANS_ID_SEQ.NEXTVAL,
                      'STC',
                      SYSDATE,
                      '88',
                      c_available.route_no,
                      floor( to_number(c_available.alt_stop_no)),
                      v_manifest_no,
                      v_up_dt,
                      'SWMS',
                      c_available.cust_id
                      );
                /*
				pl_log.ins_msg ('INFO',
                      'pl_sts_interfaces',
                      'rtn_process_flag is TRUE and i_cnt=0 not TorD inserted to trans for STC for manifest='||v_manifest_no||
					     ' stop '||floor( to_number(c_available.alt_stop_no)),
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'p_sts_import',
                      'u'
                     );
				*/

				pl_log.ins_msg ('INFO',
                      'pl_sts_interfaces',
                      'rtn_process_flag is TRUE inserted to trans for STC for manifest='||v_manifest_no||
					     ' stop '||floor( to_number(c_available.alt_stop_no)),
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'p_sts_import',
                      'u'
                     );

                UPDATE MANIFEST_STOPS SET POD_STATUS_FLAG='S'
                WHERE stop_no=floor( to_number(c_available.alt_stop_no))
                AND  manifest_no=v_manifest_no;

			COMMIT;
            EXCEPTION
               WHEN OTHERS THEN
         MESSAGE := 'Insert STC into Trans Failed';

        pl_log.ins_msg ('FATAL',
                      'SND_STS_ROUTE_DETAILS',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'Create_RTN',
                      'u'
                     );


          END;
    ELSE
        UPDATE MANIFEST_STOPS SET POD_STATUS_FLAG='F'
        WHERE stop_no=floor( to_number(c_available.alt_stop_no))
        AND  manifest_no=v_manifest_no;
        COMMIT;
    END IF;
    END IF;
    END IF;
   END LOOP;
   END LOOP;
  CLOSE c_sts_route;


EXCEPTION

     WHEN e_failed THEN

     pl_log.ins_msg( 'FATAL', 'P_STS_IMPORT','Error in processing the sts_route_in records', SQLCODE,  SQLERRM, 'O', 'STS_RETURN' );
     dbms_output.put_line('error'||SQLCODE||SQLERRM );
     ROLLBACK;
       /* Updating the messgae_id as failed */
      UPDATE sts_route_in SET record_status = 'F'
                            WHERE msg_id=v_msg_id;

      COMMIT;

     WHEN NO_DATA_FOUND THEN

      pl_log.ins_msg( 'FATAL', 'P_STS_IMPORT','Error in processing the sts_route_in records', SQLCODE,  SQLERRM, 'O', 'STS_RETURN' );
      dbms_output.put_line('error'||SQLCODE||SQLERRM );
    ROLLBACK;
           /* Updating the messgae_id as failed */
            UPDATE sts_route_in SET record_status = 'F'
                            WHERE msg_id=v_msg_id;
     COMMIT;

     WHEN OTHERS THEN

      dbms_output.put_line('error'||SQLCODE||SQLERRM );
  pl_log.ins_msg( 'FATAL', 'P_STS_IMPORT','Error in processing the sts_route_in records', SQLCODE,  SQLERRM, 'O', 'STS_RETURN' );
        ROLLBACK;
            /* Updating the messgae_id as failed */
            UPDATE sts_route_in SET record_status = 'F'
                            WHERE msg_id=v_msg_id;
         COMMIT;

END P_STS_IMPORT;

PROCEDURE POD_create_RTN (
   i_manifest_number     IN   VARCHAR2,
   i_stop_number         IN   NUMBER,
   RTN_process_flag      OUT  BOOLEAN,
   i_cust_id             IN   VARCHAR2,
   i_route_no            in varchar2,
   i_msg_id              in varchar2)
IS
         v_reason_group  VARCHAR2(3);
         status          VARCHAR2(3);
         v_rc            VARCHAR2(3);
         v_up_dt         DATE;
         v_route         VARCHAR2(10) := NULL; -- D#10516 Added
         v_orig_inv      VARCHAR2(16) := NULL; -- D#10516 Added
         l_success_flag  BOOLEAN := TRUE;
         MESSAGE         VARCHAR2 (2000);
         v_returns_count NUMBER := 0;
         v_RTN_count     NUMBER := 0;
         v_count         NUMBER := 0;
		 v_stc_count     NUMBER := 0;

         i_pod_cnt       number; --10/13/19
		 i_rn_cnt       number; --10/18/19
		 i_td_cnt		number; --10/26/19

         CURSOR RTNS_CURSOR (manifest_number number, stop_number number,customer_id varchar2) IS
         select r.manifest_no, r.route_no, r.stop_no, r.rec_type, r.obligation_no,
                r.prod_id, r.cust_pref_vendor, r.return_reason_cd, r.returned_qty,
                r.returned_split_cd, catchweight, temperature, disposition,
                r.returned_prod_id, erm_line_id, reason_group, p.catch_wt_trk,
                DECODE(r.obligation_no,
                       NULL, r.obligation_no,
                       DECODE(INSTR(r.obligation_no, 'L'),
                              0, r.obligation_no,
                              SUBSTR(r.obligation_no, 1, INSTR(r.obligation_no, 'L') - 1))) ob_no
         from   returns r, reason_cds rc, pm p, manifest_stops m
         where  r.manifest_no = manifest_number
         AND    r.manifest_no = m.manifest_no
         AND    rc.reason_cd_type = 'RTN'
         AND    rc.reason_cd = r.return_reason_cd
         -- 10/2 AND    (rc.reason_cd not like 'T%' AND rc.reason_group != 'DMG')
         AND    r.prod_id = p.prod_id
         AND    r.cust_pref_vendor = p.cust_pref_vendor
         AND    r.stop_no = floor( to_number(stop_number))
         AND    m.stop_no = r.stop_no
         AND    m.customer_id = customer_id
         order  by obligation_no,rec_type, r.prod_id
         ;

         BEGIN


        SELECT manifest_status,route_no INTO status,v_route
           FROM manifests
           WHERE manifest_no = i_manifest_number;

         /*  10/16/19 take out
        select count(*)
		into i_pod_cnt
		from sts_route_in
		where alt_stop_no = floor( to_number(i_stop_number) )
        and manifest_no = i_manifest_number
		--and msg_id=v_msg_id
		and (return_reason_cd like 'T%' or return_reason_cd like 'D%');
        */

	    select count(*)
		   into i_pod_cnt  -- if is 1 it is stop close, > 1 it is route close
           from sts_route_in
           where msg_id = i_msg_id
		   --take out 10/25/19 and record_status = 'N'
		   --and route_no = i_route_no --msg_id = t_msg_id
		   --and msg_id = i_msg_id
		   and (record_type = 'ST' or record_type = 'ET');

           	   pl_log.ins_msg ('INFO',
                      'pl_sts_interfaces',
                      'in pls_sts_interface.pod_create_rtn msg_id= '||i_msg_id||
                      ' i_pod_cnt = '||to_char(i_pod_cnt),
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'pls_sts_interface.pod_create_rtn',
                      'u'
                     );

	    select count(*)
		   into i_rn_cnt
           from sts_route_in
           where
           --record_status = 'N'
		   --and route_no = i_route_no --msg_id = t_msg_id
		   --and
           msg_id = i_msg_id
		   and ( (return_reason_cd like 'R%') or
		         (return_reason_cd like 'W%') or
		         (return_reason_cd like 'N%' and return_reason_cd != 'N01') );


           	   pl_log.ins_msg ('INFO',
                      'pl_sts_interfaces',
                      'in pls_sts_interface.pod_create_rtn msg_id= '||i_msg_id||
                      ' i_rn_cnt = '||to_char(i_rn_cnt),
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'pls_sts_interface.pod_create_rtn',
                      'u'
                     );

		select count(*)
			into i_td_cnt
			from sts_route_in
			WHERE msg_id = i_msg_id
			and ((return_reason_cd like 'D%') or (return_reason_cd like 'T%') or (return_reason_cd = 'N01'));

        pl_log.ins_msg ('INFO',
                      'pl_sts_interfaces',
                      'in pls_sts_interface.pod_create_rtn msg_id= '||i_msg_id||
                      ' i_td_cnt = '||to_char(i_td_cnt),
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'pls_sts_interface.pod_create_rtn',
                      'u'
                     );


        IF status = 'CLS' THEN
        MESSAGE:= 'Manifest is already Closed';
        pl_log.ins_msg ('FATAL',
                      'SND_STS_ROUTE_DETAILS',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'Create_RTN',
                      'u'
                     );
        ELSE
         IF STATUS = 'PAD' THEN
            v_up_dt:= NULL;
         ELSE
            v_up_dt:= to_date('01-JAN-1980','DD-MON-YYYY');

         END IF;
         FOR RTNS_REC IN RTNS_CURSOR (i_manifest_number,i_stop_number,i_cust_id)
         LOOP
            BEGIN
               v_returns_count:= v_returns_count +1;
               l_success_flag:= TRUE;
               v_rc:= RTNS_REC.RETURN_REASON_CD;
               SELECT REASON_GROUP
               INTO V_REASON_GROUP
               FROM REASON_CDS
               WHERE REASON_CD = v_rc
               AND REASON_CD_TYPE = 'RTN';
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
         l_success_flag:= FALSE;
         MESSAGE:= 'Invalid Reason Code';

        pl_log.ins_msg ('FATAL',
                      'SND_STS_ROUTE_DETAILS',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'Create_RTN',
                      'u'
                     );
            END;

        IF rtns_rec.rec_type = 'I' THEN
        IF v_rc IN ('MPR', 'MPK') THEN
            IF rtns_rec.returned_prod_id IS NULL THEN
         l_success_flag := FALSE;
         MESSAGE :='Mispick item is missing for invoice';
        pl_log.ins_msg ('FATAL',
                      'SND_STS_ROUTE_DETAILS',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'Create_RTN',
                      'u'
                     );
            ELSIF NVL(rtns_rec.returned_qty, 0) = 0 THEN
         l_success_flag:= FALSE;
         MESSAGE:= ' Mispick quantity is missing for invoice ';

        pl_log.ins_msg ('FATAL',
                      'SND_STS_ROUTE_DETAILS',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'Create_RTN',
                      'u'
                     );
            END IF;
        ELSIF NVL(rtns_rec.returned_qty, 0) = 0 THEN
         l_success_flag := FALSE;
         MESSAGE := 'Returned Quantity should be greater than 0';

        pl_log.ins_msg ('FATAL',
                      'SND_STS_ROUTE_DETAIL',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'Create_RTN',
                      'u'
                     );
        END IF;
        END IF;

         v_orig_inv := NULL;
         if rtns_rec.rec_type IN ('P', 'D') then
            begin
                select DECODE(INSTR(orig_invoice, 'L'),
                                0, orig_invoice,
                                SUBSTR(orig_invoice, 1, INSTR(orig_invoice, 'L') - 1))
                into v_orig_inv
                from manifest_dtls where
                manifest_no=i_manifest_number and
                prod_id=rtns_rec.prod_id and
                rec_type IN ('P', 'D') and
                obligation_no=rtns_rec.obligation_no;
            exception when no_data_found then null;
            when too_many_rows then null;
            end;
         end if;

      --
      -- if we have an overage situation, the invoice
      -- is accurate don?t bother letting systar know
      -- (i.e. we don?t need to write a trans record.).
      -- DN#4121:acpjjs:Trans required for all returns.
      -- DN#5233:acpjjs:Manifest_no is loaded into REC_ID.
      -- DN#10516:Added orig_invoice to lot_id. If no route, use route
      --          from MANIFESTS. Put returned_prod_id to CMT for W10
      --          reason code. Added order_line_id.
      -- DN#10537: Added temperature
            BEGIN

               select count(*) INTO v_count
               from trans
               where rec_id=i_manifest_number
               and order_id= DECODE(INSTR(rtns_rec.obligation_no, 'L'),
                                0, rtns_rec.obligation_no,
                                SUBSTR(RTNS_REC.OBLIGATION_NO, 1,
                                       INSTR(rtns_rec.obligation_no, 'L') - 1))
               and prod_id=RTNS_REC.PROD_ID
               and stop_no=RTNS_REC.STOP_NO
			   and reason_code=RTNS_REC.RETURN_REASON_CD
			   and trans_type='RTN';

			   select count(*) into v_stc_count
               from trans
               where rec_id=i_manifest_number
               and trans_type='STC'
               and stop_no=RTNS_REC.STOP_NO;

               IF v_count > 0 or v_stc_count > 0 THEN
				  NULL;
               --ELSE  -- 10/13/19
			   elsif ( (i_pod_cnt > 1 and i_td_cnt =0 ) or
			           (i_pod_cnt = 1 and i_rn_cnt >0 ) )then --10/25/19
			   --elsif ( i_rn_cnt >0 )then --10/13/19
                  INSERT INTO TRANS
                  (      TRANS_ID,
                      TRANS_TYPE,
                      TRANS_DATE,
                      batch_no,
                      ROUTE_NO,
                      STOP_NO,
                      ORDER_ID,
                      PROD_ID,
                      CUST_PREF_VENDOR,
                      REC_ID,
                      WEIGHT,
                      temp,
                      QTY,
                      UOM,
                      REASON_CODE,
                      lot_id,
                      ORDER_TYPE,
                      order_line_id,
                      RETURNED_PROD_ID,
                      UPLOAD_TIME,
                      cmt,
                      USER_ID
                      )
                  VALUES
                  (      TRANS_ID_SEQ.NEXTVAL,
                      'RTN',
                      SYSDATE,
                      '88',
                      NVL(RTNS_REC.ROUTE_NO, v_route),
                      RTNS_REC.STOP_NO,
                      DECODE(INSTR(rtns_rec.obligation_no, 'L'),
                                0, rtns_rec.obligation_no,
                                SUBSTR(RTNS_REC.OBLIGATION_NO, 1,
                                       INSTR(rtns_rec.obligation_no, 'L') - 1)),
                      RTNS_REC.PROD_ID,
                      RTNS_REC.CUST_PREF_VENDOR,
                      i_manifest_number,
                      RTNS_REC.CATCHWEIGHT,
                      rtns_rec.temperature,
                      RTNS_REC.RETURNED_QTY,
                      RTNS_REC.RETURNED_SPLIT_CD,
                      RTNS_REC.RETURN_REASON_CD,
                      v_orig_inv,
                      RTNS_REC.REC_TYPE,
                      rtns_rec.erm_line_id,
                      RTNS_REC.RETURNED_PROD_ID,
                      v_up_dt,
                      'Return created from STS.' || DECODE(rtns_rec.return_reason_cd, 'W10',
                                                        ' Returned item #' || rtns_rec.returned_prod_id,
                                                        NULL),
                      'SWMS'
                      );

					  pl_log.ins_msg ('INFO',
                      'pl_sts_interfaces',
                      'in pls_sts_interface.pod_create_rtn inserted to trans for RTN for rec_id='||i_manifest_number||
					     ' stop '||rtns_rec.stop_no|| ' route= '||NVL(RTNS_REC.ROUTE_NO, v_route) ||'prod_id ='||RTNS_REC.PROD_ID ,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'p_sts_import',
                      'u'
                     );


                -- Update rtn_sent_ind to Y if the RTN trans is created
                UPDATE returns
                SET rtn_sent_ind = 'Y',
                    pod_rtn_ind = 'S'
                WHERE manifest_no = i_manifest_number
                    AND route_no = nvl(rtns_rec.route_no, v_route)
                    AND stop_no = rtns_rec.stop_no
                    AND prod_id = rtns_rec.prod_id
                    AND returned_qty = rtns_rec.returned_qty
                    AND obligation_no = DECODE(INSTR(rtns_rec.obligation_no, 'L'),
                                            0, rtns_rec.obligation_no,
                                            SUBSTR(RTNS_REC.OBLIGATION_NO, 1,
                                            INSTR(rtns_rec.obligation_no, 'L') - 1))
                    AND return_reason_cd = rtns_rec.return_reason_cd;

               END IF;
            EXCEPTION
               WHEN OTHERS THEN
         l_success_flag := FALSE;
         MESSAGE := 'Insert RTN into Trans Failed';

        pl_log.ins_msg ('FATAL',
                      'SND_STS_ROUTE_DETAILS',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'Create_RTN',
                      'u'
                     );
            END;
   IF l_success_flag = TRUE THEN
    COMMIT;
    v_RTN_count:= v_RTN_count+1;
   ELSE
    ROLLBACK;
   END IF;
   END LOOP;

    IF v_returns_count = v_RTN_count THEN
    RTN_process_flag:= TRUE;

	   --10/13/19
	   pl_log.ins_msg ('INFO',
                      'pl_sts_interfaces',
                      'in pls_sts_interface.pod_create_rtn before return RTN_process_flag= TRUE',
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'pls_sts_interface.pod_create_rtn',
                      'u'
                     );

    ELSE
    RTN_process_flag:= FALSE;

	       -- 10/13/19
		   pl_log.ins_msg ('INFO',
                      'pl_sts_interfaces',
                      'in pls_sts_interface.pod_create_rtn before return RTN_process_flag= FALSE',
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'pls_sts_interface.pod_create_rtn',
                      'u'
                     );

    END IF;

    END IF;
    END POD_create_RTN;

PROCEDURE delete_dup_barcodes(i_route_no     IN   VARCHAR2,
                              i_route_date   IN     DATE
                             ) IS
   -- 5/3/21 mc add this to get rid of duplicate barcode

   CURSOR d_cur is
   SELECT batch_id, item_id, barcode, prod_id, count(*)
     FROM sts_route_out
    WHERE route_no = i_route_no
      and record_type = 'BC'
      and record_status = 'N'
      and prod_id is not null
      AND route_date = i_route_date
    GROUP BY batch_id, item_id, barcode, prod_id
   having count(*) > 1;

   t_seq_no sts_route_out.sequence_no%type;
   message  VARCHAR2(2000);
   l_success_flag  BOOLEAN := TRUE;
begin
   pl_log.ins_msg ('INFO',
                   'DELETE_DUP_BARCODES',
                   'in pl_sts_interface.delete_dup_barcodes checking for duplicate barcode block for route '||i_route_no||
                   ' route date '||to_char(i_route_date,'mm/dd/yyyy'),
                   SQLCODE,
                   SQLERRM,
                   'ORDER PROCESSING',
                   'pls_sts_interface.delete_dup_barcodes',
                   'N'
                   );

   FOR r_cur IN d_cur LOOP
      -- add 3/8/21
      begin
         pl_log.ins_msg ('INFO',
                         'DELETE_DUP_BARCODES',
                         'in pl_sts_interface.delete_dup_barcodes checking for duplicate barcode block in for r_cur loop '||
                         ' item_id '||r_cur.item_id||' barcode '||r_cur.barcode||' prod_id '||r_cur.prod_id||' has duplicate barcode',
                         SQLCODE,
                         SQLERRM,
                         'ORDER PROCESSING',
                         'pls_sts_interface.delete_dup_barcodes',
                         'N'
                         );

         update sts_route_out a
            set record_status = 'I' -- ignore --batch_id = null
          where a.batch_id = r_cur.batch_id
            and a.route_no = i_route_no
            and a.record_type = 'BC'
            and a.record_status = 'N'
            and a.item_id = r_cur.item_id
            and a.barcode = r_cur.barcode
            and a.prod_id = r_cur.prod_id
            and a.sequence_no NOT IN (SELECT MIN(sequence_no)
                                        from sts_route_out b
                                       where b.batch_id = r_cur.batch_id
                                         and b.route_no = i_route_no
                                         and b.record_type = 'BC'
                                         and b.record_status = 'N'
                                         and b.item_id = r_cur.item_id
                                         and b.barcode = r_cur.barcode
                                         and b.prod_id = r_cur.prod_id);

         --dbms_output.put_line('sequence_no to be deleted is '||t_seq_no);

         pl_log.ins_msg ('INFO',
                         'DELETE_DUP_BARCODES',
                         'in pl_sts_interface.delete_dup_barcodes checking for duplicate barcode block after update batch_id to null for'||
                         ' item_id '||r_cur.item_id||' barcode '||r_cur.barcode||' prod_id '||r_cur.prod_id,
                         SQLERRM,
                         'ORDER PROCESSING',
                         'pls_sts_interface.delete_dup_barcodes',
                         'N'
                        );

      exception
         WHEN OTHERS THEN
            l_success_flag := FALSE;
            message := 'WOT error from r_cur loop';
            dbms_output.put_line('wot error at the r_cur loop messag='||message||' sqlcode='||sqlcode||
                                 ' sqlerrm='||sqlerrm);
                                 pl_log.ins_msg ('FATAL',
                                 'DELETE_DUP_BARCODES',
                                 MESSAGE,
                                 SQLCODE,
                                 SQLERRM,
                                 'ORDER PROCESSING',
                                 'pls_sts_interface.delete_dup_barcodes',
                                 'N'
                                );
            --raise;
      end;
   end loop; -- r_cur loop

EXCEPTION
   WHEN OTHERS THEN
      l_success_flag := FALSE;
      message := 'WOT error from anonymous block to delete double barcode';
      dbms_output.put_line('wot error at the r_cur loop messag='||message||' sqlcode='||sqlcode||
                           ' sqlerrm='||sqlerrm);

      pl_log.ins_msg ('FATAL',
                      'DELETE_DUP_BARCODES',
                      MESSAGE,
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'pls_sts_interface.delete_dup_barcodes',
                      'N'
                     );
      -- raise;
end delete_dup_barcodes;

-- end of get rid of duplicate barcode block
END pl_sts_interfaces;
/
