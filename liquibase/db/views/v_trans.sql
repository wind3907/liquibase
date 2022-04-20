------------------------------------------------------------------------------
-- View:
--    v_trans
--
-- Description:
--     This view is used for all transactions.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    10/14/14 bben0556 Symbotic project.
--                      List each column instead of using select *
--
--                      Add new column "float_detail_seq_no".
--                      It is populated from the FLOAT_DETAIL_SEQ_NO column
--                      when inserting the PIK transaction.  This column
--                      along with the existing float_no column will be used
--                      to find the PIK transaction corresponding to the
--                      FLOAT_DETAIL record.  Without this column
--                      it can difficult to match the FLOAT_DETAIL records to
--                      the corresponding PIK transactions for an item that is
--                      broken across float zones.
--
--    07/19/16 bben0556 Brian Bent
--                      Project:
--                R30.5--WIB#663--CRQ000000007533_Save_what_created_NDM_in_trans_RPL_record
--
--                      Add the following columns:
--    The columns and a brief description are below followed by a more
--    detail description:
--    - REPLEN_CREATION_TYPE - What created the non-demand replenishment.
--    - REPLEN_TYPE          - The "replen type" (DSP, NSP, etc) of the
--                             RPL transaction.  OpCo 007 wanted a easy
--                             way to identify the matrix replenishment
--                             type of the RPL transaction.
--    - TASK_PRIORITY - Forklift task priority of the NDM
--    - SUGGESTED_TASK_PRIORITY - The highest priority of the NDM
--                                list sent to the RF.
--
--    Column REPLEN_CREATION_TYPE stores what created the non-demand
--    replenishment.
--    The values comes from column REPLENST.REPLEN_TYPE which for non-demand
--    replenishments will have one of these values:
--       'L' - Created from RF using "Replen By Location" option
--       'H' - Created from Screen using "Replen by Historical" option
--       'R' - Created from screen with options other than "Replen by Historical"
--       'O' - Created from cron job when a store-order is received that
--             requires a replenishment
--    The appropriate RF host programs will be changed to populate this new
--    column when a non-demand replenishment is dropped.
--
--
--    Column REPLEN_TYPE stores the replenishment type.  The value will come
--    from REPLENLST.TYPE.
--    It main purpose is to store the matrix replenishment type.  
--    Matrix replenishments have diffent types but we use RPL for the
--    transaction type.  The OpCo wants to know the matrix replenishment type
--    for the RPL transaction.
--    The matrix replenishment types are in table MX_REPLEN_TYPE which are
--    listed here.
--               TYPE DESCRIP
--               ---  ----------------------------------------
--               DSP  Demand: Matrix to Split Home 
--               DXL  Demand: Reserve to Matrix
--               MRL  Manual Release: Matrix to Reserve
--               MXL  Assign Item: Home Location to Matrix
--               NSP  Non-demand: Matrix to Split Home
--               NXL  Non-demand: Reserve to Matrix
--               UNA  Unassign Item: Matrix to Main Warehouse
--
--    =======================================================================
--    =======================================================================
--    README    README     README    README    README
--    README    README     README    README    README
--    README    README     README    README    README
--    There is potential confusion in the column naming of "replenlst.replen_type"
--    and the new column "trans.replen_type".  The existing column
--    "replenlst.replen_type" is not actually the type of replenishment but
--    what generated the replenishment so the column name is misleading.
--    I elected to call the column in the trans table "replen_type" since
--    it will be the actual type of replenishment.
--    =======================================================================
--    =======================================================================
--
--
--    TASK_PRIORITY stores the forklift task priority for the NDM.  I also
--    populated it for DMD's.  The value comes from USER_DOWNLOADED_TASKS.
--
--
--    SUGGESTED_TASK_PRIORITY stores the hightest forklift task priority from
--    the replenishment list sent to the RF.
--    The value comes from USER_DOWNLOADED_TASKS.
--    Distribution Services wants to know if the forklift operator is doing
--    lower priority drops before higher ones.
--
--
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    10/08/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3725_Site_2_Create_PIK_transaction_for_cross_dock_pallet
--
--                      Add cross_dock_type.
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swms.v_trans
AS
SELECT t.trans_id,
       t.trans_type,
       t.trans_date,
       t.prod_id,
       t.rec_id,
       t.lot_id,
       t.exp_date,
       t.weight,
       t.temp,
       t.mfg_date,
       t.qty_expected,
       t.uom_expected,
       t.qty,
       t.uom,
       t.src_loc,
       t.dest_loc,
       t.user_id,
       t.order_id,
       t.route_no,
       t.stop_no,
       t.truck_no,
       t.cmt,
       t.old_status,
       t.new_status,
       t.reason_code,
       t.adj_flag,
       t.pallet_id,
       t.upload_time,
       t.order_line_id,
       t.batch_no,
       t.sys_order_id,
       t.sys_order_line_id,
       t.order_type,
       t.returned_prod_id,
       t.diff_weight,
       t.ilr_upload_time,
       t.cust_pref_vendor,
       t.clam_bed_no,
       t.warehouse_id,
       t.float_no,
       t.bck_dest_loc,
       t.labor_batch_no,
       t.tti,
       t.cryovac,
       t.parent_pallet_id,
       t.po_line_id,
       t.sn_no,
       t.po_no,
       t.country_of_origin,
       t.wild_farm,
       t.scan_method1,
       t.scan_method2,
       t.ref_pallet_id,
       t.items_per_carrier,
       t.replen_task_id,
       t.float_detail_seq_no,
       t.replen_creation_type,
       --
       -- 08/22/2016  Brian Bent Decode the replen creation type description.
       -- We do not have a "code" table for it so I decided to decode the
       -- description.
       DECODE(t.replen_creation_type,
              'L', 'RF BY LOCATION',
              'H', 'CRT HISTORICAL ORDER OPTION',
              'R', 'CRT OPTIONS OTHER THAN HISTORICAL',
              'O', 'CRON JOB STORE-ORDER NEEDS REPLEN',
              t.replen_creation_type) replen_creation_type_descrip,
       --
       t.replen_type,
       t.task_priority,
       t.suggested_task_priority,
       t.cross_dock_type
  FROM trans t
UNION ALL
SELECT o.trans_id,
       o.trans_type,
       o.trans_date,
       o.prod_id,
       o.rec_id,
       o.lot_id,
       o.exp_date,
       o.weight,
       o.temp,
       o.mfg_date,
       o.qty_expected,
       o.uom_expected,
       o.qty,
       o.uom,
       o.src_loc,
       o.dest_loc,
       o.user_id,
       o.order_id,
       o.route_no,
       o.stop_no,
       o.truck_no,
       o.cmt,
       o.old_status,
       o.new_status,
       o.reason_code,
       o.adj_flag,
       o.pallet_id,
       o.upload_time,
       o.order_line_id,
       o.batch_no,
       o.sys_order_id,
       o.sys_order_line_id,
       o.order_type,
       o.returned_prod_id,
       o.diff_weight,
       o.ilr_upload_time,
       o.cust_pref_vendor,
       o.clam_bed_no,
       o.warehouse_id,
       o.float_no,
       o.bck_dest_loc,
       o.labor_batch_no,
       o.tti,
       o.cryovac,
       o.parent_pallet_id,
       o.po_line_id,
       o.sn_no,
       o.po_no,
       o.country_of_origin,
       o.wild_farm,
       o.scan_method1,
       o.scan_method2,
       o.ref_pallet_id,
       o.items_per_carrier,
       o.replen_task_id,
       o.float_detail_seq_no,
       o.replen_creation_type,
       --
       -- 08/22/2016  Brian Bent Decode the replen creation type description.
       -- We do not have a "code" table for it so I decided to decode the
       -- description.
       DECODE(o.replen_creation_type,
              'L', 'RF BY LOCATION',
              'H', 'CRT HISTORICAL ORDER OPTION',
              'R', 'CRT OPTIONS OTHER THAN HISTORICAL',
              'O', 'CRON JOB STORE-ORDER NEEDS REPLEN',
              o.replen_creation_type) replen_creation_type_descrip,
       --
       o.replen_type,
       o.task_priority,
       o.suggested_task_priority,
       o.cross_dock_type
  FROM op_trans o
UNION ALL
SELECT m.trans_id,
       m.trans_type,
       m.trans_date,
       m.prod_id,
       m.rec_id,
       m.lot_id,
       m.exp_date,
       m.weight,
       m.temp,
       m.mfg_date,
       m.qty_expected,
       m.uom_expected,
       m.qty,
       m.uom,
       m.src_loc,
       m.dest_loc,
       m.user_id,
       m.order_id,
       m.route_no,
       m.stop_no,
       m.truck_no,
       m.cmt,
       m.old_status,
       m.new_status,
       m.reason_code,
       m.adj_flag,
       m.pallet_id,
       m.upload_time,
       m.order_line_id,
       m.batch_no,
       m.sys_order_id,
       m.sys_order_line_id,
       m.order_type,
       m.returned_prod_id,
       m.diff_weight,
       m.ilr_upload_time,
       m.cust_pref_vendor,
       m.clam_bed_no,
       m.warehouse_id,
       m.float_no,
       m.bck_dest_loc,
       m.labor_batch_no,
       m.tti,
       m.cryovac,
       m.parent_pallet_id,
       m.po_line_id,
       m.sn_no,
       m.po_no,
       m.country_of_origin,
       m.wild_farm,
       m.scan_method1,
       m.scan_method2,
       m.ref_pallet_id,
       m.items_per_carrier,
       m.replen_task_id,
       m.float_detail_seq_no,
       m.replen_creation_type,
       --
       -- 08/22/2016  Brian Bent Decode the replen creation type description.
       -- We do not have a "code" table for it so I decided to decode the
       -- description.
       DECODE(m.replen_creation_type,
              'L', 'RF BY LOCATION',
              'H', 'CRT HISTORICAL ORDER OPTION',
              'R', 'CRT OPTIONS OTHER THAN HISTORICAL',
              'O', 'CRON JOB STORE-ORDER NEEDS REPLEN',
              m.replen_creation_type) replen_creation_type_descrip,
       --
       m.replen_type,
       m.task_priority,
       m.suggested_task_priority,
       m.cross_dock_type
  FROM miniload_trans m
/

