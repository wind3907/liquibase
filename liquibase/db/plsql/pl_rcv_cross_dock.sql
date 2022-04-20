CREATE OR REPLACE PACKAGE SWMS.pl_rcv_cross_dock
AS
-----------------------------------------------------------------------------
-- Package Name:
--    pl_rcv_cross_dock
--
-- Description:
--    This package is used for Opening European Import Purchase Orders
--    and CMU cross docking.
--    Uses following SPs for
--        * Reading cross-dock dataopening the PO, (read_crossdock_data)
--        * Updating detail records (update_dtl_records)
--        * Assigning Slots (assign_slots)
--        * Creating Inventory records (create_inv_records)
--        * Creating Labor batches (create_labor_batches)
--        * Updating Cross Dock Reference (update_cross_dock_xref)
--        * Opening PO  (open_po)
--        * Closing PO  (close_po)
--
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    04/17/14 Infosys  Created this package.
--    11/26/14 spot3255 Charm# 6000003789 - Ireland Cubic values - Metric conversion project
--                      removed c_crossdock_maxcube and replaced the value with syspar:LOC_CUBE_KEY_VALUE.
--    08/09/19 xzhe5043 CMU changes added 2 procedures
--    08/28/19 vkal9662 CMU related changes added (look for vkal9662) - Multipo beta - with close PO
--    09/05/19 vkal9662 CMU changes jira 2535 remove master order id dependency
--    09/11/19 vkal9662 CMU add SYS_ORDER_ID	 to Cross_dock_data_collect_in, Cross_dock_data_collect
--
--    09/25/19 bben0556 Brian Bent
--                      Project: R30.6.8-Jira-OPCOF-2517-CMU-Project_cross_dock_picking
--
--                      When a CMU is was being closed SWMS updating ERM.MAINT_FLAG
--                      to 'Y' which resulted in swmspowriter sending a RSN transaction
--                      to SUS--which is incorrect.
--                      We should not set the ERM.MAINT_FLAG when a PO/SN is closed.
--                      Modified procedure "close_ei_po".
--                      Changed
--                         UPDATE erm
--                            SET status     = 'CLO',
--                                close_date = SYSDATE,
--                                maint_flag = 'Y'
--                            WHERE erm_id = i_erm_id;
--                      to
--                         UPDATE erm
--                            SET status     = 'CLO',
--                                close_date = SYSDATE
--                            WHERE erm_id = i_erm_id;
--
--
--                      When setting the PO/SN status to OPN for a SN
--                      leave the ERM.MAINT_FLAG as is since we do not send a status change
--                      in the PW queue for a SN.
--                      Modified procedure "open_po".
--
--
--                      When a extended CMU SN is closed "pl_rcv_po_close.sql" is not
--                      updating the ERD qty.  This is because the putawaylst.po_no
--                      is populated with the SN# number and not the PO#.
--                      Modified cursor "c_inv_rec" adding this:
--                         (SELECT erd_lpn.po_no
--                          FROM erd_lpn
--                         WHERE erd_lpn.pallet_id = cd.pallet_id
--                           AND erd_lpn.sn_no     = cd.erm_id) erd_lpn_po_no
--                     and changed the insert into putawaylst table stmt.
--
--    10/02/19 bben0556 Brian Bent
--                      Project: R30.6.8-Jira-OPCOF-2517-CMU-Project_cross_dock_picking
--
--                      Inserting records from CROSS_DOCK_DATA_COLLECT_IN into
--                      CROSS_DOCK DATA_COLLECT fails when there are different
--                      retail customer numbers on different parent LPs.
--                      And bogus CROSS_DOCK_PALLET_XREF records are created.
--
--                      Created new procedure "cmu_upload_cross_dock_data".
--
--                      Changed procedure "upload_cross_dock_data" to call
--                      "cmu_upload_cross_dock_data" and commented out the
--                      European Imports code.  Note that European Imports
--                      most likely will no longer work correctly.
--
--
--    10/08/19 bben0556 Brian Bent
--                      Project: R30.6.8-Jira-OPCOF-2517-CMU-Project_cross_dock_picking
--
--                      Bug fixes.
-----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Global variables
  -----------------------------------------------------------------------------
  e_po_locked             EXCEPTION;
  e_premature_termination EXCEPTION;
  PRAGMA EXCEPTION_INIT (e_po_locked, -54);
  g_rf_flag   CHAR (1);
  g_err_msg   VARCHAR2 (255);
  g_exit_msg  VARCHAR2 (255);
  g_sqlcode   NUMBER;
  g_row_count NUMBER;
  g_rf_confirm_flag sys_config.config_flag_val%TYPE;
  g_putaway_confirm_flag sys_config.config_flag_val%TYPE;
  g_erm_rec erm%ROWTYPE;
  g_pm_rec pm%ROWTYPE;
  g_tmp_weight_rec tmp_weight%ROWTYPE;
  gv_osd_sys_flag sys_config.config_flag_val%TYPE := '';
  g_ei_pallet CHAR (1);
  
TYPE t_clientrectype
IS
  RECORD
  (
    flag             CHAR (1),
    sp_flag          CHAR (1),
    user_id          VARCHAR2 (30),
    sp_supplier_name VARCHAR (500),
    sp_supplier_qty  VARCHAR (100) );
  g_client t_clientrectype;
TYPE t_serverrectype
IS
  RECORD
  (
    sp_current_total  NUMBER,
    sp_supplier_count NUMBER,
    erm_id erm.erm_id%TYPE,
    prod_id pm.prod_id%TYPE,
    cust_pref_vendor pm.cust_pref_vendor%TYPE,
    exp_splits   NUMBER,
    exp_qty      NUMBER,
    rec_splits   NUMBER,
    rec_qty      NUMBER,
    hld_cases    NUMBER,
    hld_splits   NUMBER,
    hld_pallet   NUMBER,
    total_pallet NUMBER,
    num_pallet   NUMBER,
    status       NUMBER );
  g_server t_serverrectype;
  CURSOR c_po_lock (cp_rec_id VARCHAR2)
  IS
    SELECT erm_id
    FROM erm
    WHERE po = cp_rec_id FOR UPDATE OF status,
      close_date,
      maint_flag NOWAIT;
  -----------------------------------------------------------------------------
  -- Public Constants
  -----------------------------------------------------------------------------
  ct_INV_PO       NUMBER      := 90;
  ct_LOCKED_PO    NUMBER      := 112;
  ct_PROGRAM_CODE VARCHAR2(5) := 'RE03';
  ct_SELECT_ERROR NUMBER      := 400;
  -----------------------------------------------------------------------------
  -- Procedures
  -----------------------------------------------------------------------------
  --PROCEDURE XX_call_upload_cross_dock_data_in;
  PROCEDURE XX_upload_cross_dock_data_in(
      p_route_no IN swms_float_detail_in.route_no%TYPE,  --vkal9662 add route_no context and removed master order id context jira 2535
      o_status OUT BOOLEAN);
  PROCEDURE open_all_po_for_rcn(
      i_erm_id IN erm.erm_id%TYPE DEFAULT NULL,
      o_success_flag OUT BOOLEAN );
  PROCEDURE Split_CMU_SN(
      p_sn_no IN VARCHAR2 );
  PROCEDURE open_po(
      i_erm_id IN erm.erm_id%TYPE);
  PROCEDURE update_dtl_records(
      i_erm_id IN erm.erm_id%TYPE);
  PROCEDURE assign_slots(
      i_erm_id IN erm.erm_id%TYPE);
  PROCEDURE assign_area_slots(
      i_erm_id IN erm.erm_id%TYPE,
      i_area   IN cross_dock_data_collect.area%TYPE );
  PROCEDURE create_inv_records(
      i_loc              IN loc.logi_loc%TYPE,
      i_parent_pallet_id IN putawaylst.pallet_id%TYPE,
      i_child_pallet_id  IN putawaylst.pallet_id%TYPE,
      i_seq_no           IN putawaylst.seq_no%TYPE );
  PROCEDURE create_labor_batches(
      i_erm_id           IN erm.erm_id%TYPE,
      i_parent_pallet_id IN putawaylst.pallet_id%TYPE );
  PROCEDURE update_cross_dock_xref(
      i_erm_id IN erm.erm_id%TYPE,
      i_status IN cross_dock_xref.status%TYPE );
  PROCEDURE close_po(
      i_erm_id IN erm.erm_id%TYPE);
  PROCEDURE check_for_data_collection(i_erm_id IN erm.erm_id%TYPE);
  PROCEDURE update_erd(
      i_erm_id IN erm.erm_id%TYPE);

  PROCEDURE close_ei_po(
      i_erm_id IN erm.erm_id%TYPE);

  PROCEDURE update_cross_dock_data_collect(i_erm_id IN erd.erm_id%TYPE);
  PROCEDURE upload_cross_dock_data(i_erm_id IN erm.erm_id%TYPE);
  PROCEDURE upload_cdk_for_msg_id(
      i_msg_id IN cross_dock_data_collect_in.msg_id%TYPE,
      i_rcn_no IN cross_dock_data_collect_in.retail_cust_no%TYPE,
      o_status OUT BOOLEAN );
  PROCEDURE update_erm_for_rcn(
      i_rcn       IN cross_dock_pallet_xref.retail_cust_no%TYPE,
      i_ship_date IN cross_dock_pallet_xref.ship_date%TYPE,
      i_status    IN erm.status%TYPE );
  PROCEDURE lock_po(
      i_rec_id IN VARCHAR2);
  FUNCTION f_is_crossdock_pallet(
      i_id   IN VARCHAR,
      i_type IN CHAR)
    RETURN CHAR;
  FUNCTION f_validate_erd_cdk_qty(
      i_id IN VARCHAR)
    RETURN BOOLEAN;

---------------------------------------------------------------------------
-- Procedure:
--    cmu_upload_cross_dock_data
--
-- Description:
--    This procedure copies the records in the CROSS_DOCK_DATA_COLLECT_IN table
--    into the following tables for the specified CMU SN.
--       - CROSS_DOCK_DATA_COLLECT
--       - CROSS_DOCK_PALLET_XREF
--       - CROSS_DOCK_XREF
---------------------------------------------------------------------------
PROCEDURE cmu_upload_cross_dock_data(i_erm_id IN erm.erm_id%TYPE);

END pl_rcv_cross_dock;
/



/* Formatted on 2014/09/09 18:50 (Formatter Plus v4.8.8) */
CREATE OR REPLACE PACKAGE BODY swms.pl_rcv_cross_dock
AS
  /******************************************************************************
  NAME:       pl_rcv_cross_dock
  PURPOSE:
  REVISIONS:
  Ver        Date        Author           Description
  ---------  ----------  ---------------  ------------------------------------
  1.0        4/17/2014             1. Created this package body.
  ******************************************************************************/
  ---------------------------------------------------------------------------
  -- Private Cursors
  ---------------------------------------------------------------------------
  ---------------------------------------------------------------------------
  -- Private Type Declarations
  ---------------------------------------------------------------------------
  ---------------------------------------------------------------------------
  -- Private Global Variables
  ---------------------------------------------------------------------------
  ct_application_function VARCHAR2(30) := 'RECEIVING';
  gl_pkg_name VARCHAR2 (30) := 'PL_RCV_CROSS_DOCK';
  -- Package name.
  --  Used in error messages.
  gl_e_parameter_null EXCEPTION;
  -- A required parameter to a procedure or
  -- function is null.
  ---------------------------------------------------------------------------
  -- Private Global Variables
  ---------------------------------------------------------------------------
  --------------------------------------------------------------------------
  -- Private Constants
  --------------------------------------------------------------------------
  --  c_crossdock_maxcube   CONSTANT NUMBER (12,4);
  ---------------------------------------------------------------------------
  -- Private Modules
  ---------------------------------------------------------------------------
  ---------------------------------------------------------------------------
  -- Procudure call_upload_cross_dock_data_in and upload_cross_dock_data_in
  -- Description: For CMU changes to load data from staging tables to
  --              cross_dock_data_collect_in table
  -- Initial version: xzhe5043 08/08/2019
  --
  ---------------------------------------------------------------------------
/*
  PROCEDURE XX_call_upload_cross_dock_data_in
  IS
    l_object_name VARCHAR2 (30) := 'UPLOAD_CROSS_DOCK_DATA';
    l_message     VARCHAR2 (512); -- Message buffer
    gl_pkg_name   VARCHAR2 (30) := 'PL_RCV_CROSS_DOCK';
    l_status      BOOLEAN;
    CURSOR c_msg_id
    IS
      SELECT DISTINCT route_no
      FROM SWMS_FLOAT_DETAIL_IN
      WHERE record_status = 'N';
  BEGIN
    FOR r_msg_id IN c_msg_id
    LOOP
      XX_upload_cross_dock_data_in ( r_msg_id.route_no, l_status ); --vkal9662 removed master order id comtext for multi po
      
      IF l_status THEN
        UPDATE swms_floats_in f
        SET RECORD_STATUS = 'S',
          upd_date        = SYSDATE,
          upd_user        = USER
        WHERE EXISTS
          (SELECT 1
          FROM swms_float_detail_in fd
          WHERE fd.float_no     =f.float_no
          AND fd.route_no  = r_msg_id.route_no
          AND fd.CMU_INDICATOR ='C'   );
          
        UPDATE SWMS_FLOAT_DETAIL_IN fd
        SET RECORD_STATUS    = 'S',
          upd_date           = SYSDATE,
          upd_user           = USER
        WHERE  fd.route_no  = r_msg_id.route_no;
        
        UPDATE SWMS_ORDCW_IN cw
        SET RECORD_STATUS = 'S',
          upd_date        = SYSDATE,
          upd_user        = USER
        WHERE EXISTS
          (SELECT 1
          FROM swms_float_detail_in fd
          WHERE 1               =1
          AND fd.FLOAT_NO       = cw.CW_FLOAT_NO
          AND fd.ORDER_ID       = cw.ORDER_ID
          AND fd.order_line_id  = cw.order_line_id
          AND fd.route_no  = r_msg_id.route_no
          AND fd.CMU_INDICATOR ='C'   );
          
        l_message := l_object_name || ' Data Upload successfull for master_order_id[' || r_msg_id.route_no || ']';
        COMMIT;
      ELSE
        UPDATE swms_floats_in f
        SET RECORD_STATUS = 'F',
          upd_date        = SYSDATE,
          upd_user        = USER
        WHERE EXISTS
          (SELECT 1
          FROM swms_float_detail_in fd
          WHERE fd.float_no     =f.float_no
          AND fd.route_no  = r_msg_id.route_no
          AND fd.CMU_INDICATOR ='C'    );
          
        UPDATE SWMS_FLOAT_DETAIL_IN fd
        SET RECORD_STATUS    = 'F',
          upd_date           = SYSDATE,
          upd_user           = USER
        WHERE CMU_INDICATOR ='C'
        AND fd.route_no  = r_msg_id.route_no;
        
        UPDATE SWMS_ORDCW_IN cw
        SET RECORD_STATUS = 'F',
          upd_date        = SYSDATE,
          upd_user        = USER
        WHERE EXISTS
          (SELECT 1
          FROM swms_float_detail_in fd
          WHERE 1               =1
          AND fd.FLOAT_NO       = cw.CW_FLOAT_NO
          AND fd.ORDER_ID       = cw.ORDER_ID
          AND fd.order_line_id  = cw.order_line_id 
          AND fd.route_no  = r_msg_id.route_no
          AND fd.CMU_INDICATOR ='C');
        COMMIT;
        l_message := l_object_name || ' Data Upload failed for master_order_id[' || r_msg_id.route_no|| ']';
        pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, l_message, SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
      END IF;
    END LOOP;
  END;
*/
  PROCEDURE XX_upload_cross_dock_data_in(
      p_route_no IN swms_float_detail_in.route_no%TYPE,  --vkal9662 added route_no context removed masterorder_id context
      o_status OUT BOOLEAN)
  IS
    l_area        VARCHAR2(1);
    l_seq         NUMBER(10);
    l_object_name VARCHAR2 (30) := 'UPLOAD_CROSS_DOCK_DATA_IN';
    l_message     VARCHAR2 (512); -- Message buffer
    gl_pkg_name   VARCHAR2 (30) := 'PL_RCV_CROSS_DOCK';
    CURSOR header_in_cur
    IS
      SELECT DISTINCT fd.end_cust_id ,
        f.ship_date,
        f.door_area,
        el.parent_pallet_id,
        el.sn_no,
        SUBSTR(el.sn_no,instr(el.sn_no,'-')+1,1) area
      FROM swms_floats_in f,
        SWMS_FLOAT_DETAIL_IN fd,
        erd_lpn el
      WHERE f.float_no      =fd.float_no
      AND f.route_no        =fd.route_no
      AND f.route_no        =p_route_no
      AND substr(el.sn_no,1, (instr(el.sn_no,'-')-1))  = substr(fd.route_no ,3)
      AND fd.RDC_OUTBOUND_CHILD_PALLET_ID = el.pallet_id
      AND fd.record_status                ='N';
      
    CURSOR detail_in_cur
    IS
      SELECT DISTINCT fd.end_cust_id ,
        f.ship_date,
        f.door_area,
        el.parent_pallet_id,
        el.master_order_id,
        el.sn_no,
        SUBSTR(sn_no,instr(sn_no,'-')+1,1) area,
        el.erm_line_id,
        el.prod_id,
        el.qty,
        fd.uom,
        fd.carrier_id,
        fd.lot_id,
        fd.order_seq,
        fd.item_seq,
        el.pallet_id,
        el.po_no,
        fd.cmu_indicator
      FROM swms_floats_in f,
        SWMS_FLOAT_DETAIL_IN fd,
        erd_lpn el
      WHERE f.float_no                    =fd.float_no
      AND f.route_no        =fd.route_no
      AND f.route_no        =p_route_no
      AND substr(el.sn_no,1, (instr(el.sn_no,'-')-1))  = substr(fd.route_no ,3)
      AND fd.prod_id                      = el.prod_id
      AND fd.RDC_OUTBOUND_CHILD_PALLET_ID = el.pallet_id
      AND fd.cmu_indicator   ='C'
      AND fd.record_status   ='N';
    CURSOR cw_in_cur
    IS
      SELECT DISTINCT fd.end_cust_id ,
        f.ship_date,
        f.door_area,
        el.parent_pallet_id,
        el.master_order_id,
        el.sn_no,
        SUBSTR(sn_no,instr(sn_no,'-')+1,1) area,
        el.erm_line_id,
        el.prod_id,
        el.qty,
        fd.uom,
        fd.carrier_id,
        fd.lot_id,
        fd.order_seq,
        fd.item_seq,
        cw.case_id,
        fd.mfg_date,
        cw.catch_weight,
        cw.cw_type,
        el.po_no
      FROM swms_floats_in f,
        SWMS_FLOAT_DETAIL_IN fd,
        erd_lpn el,
        SWMS_ORDCW_IN cw
      WHERE f.float_no                    =fd.float_no
      AND fd.prod_id                      = el.prod_id
      AND fd.RDC_OUTBOUND_CHILD_PALLET_ID = el.pallet_id
      AND f.route_no        =fd.route_no
      AND f.route_no        =p_route_no
      AND substr(el.sn_no,1, (instr(el.sn_no,'-')-1))  = substr(fd.route_no ,3)
      AND fd.cmu_indicator   ='C'
      AND fd.FLOAT_NO        = cw.CW_FLOAT_NO
      AND fd.ORDER_ID        = cw.ORDER_ID
      AND fd.order_line_id   = cw.order_line_id
      AND fd.record_status   ='N';
  BEGIN
    SELECT swms.mx_batch_no_seq.nextval INTO l_seq FROM dual;
    FOR header_in_rec IN header_in_cur
    LOOP
      IF header_in_rec.area NOT IN ('F','D','C') THEN
        l_area := header_in_rec.door_area;
      ELSE
        l_area := header_in_rec.area;
      END IF;
      INSERT
      INTO cross_dock_data_collect_in
        (
          sequence_number,
          msg_id,
          interface_type,
          RECORD_STATUS,
          RETAIL_CUST_NO ,
          ship_date,
          PARENT_PALLET_ID,
          erm_id,
          rec_type,
          area,
          cmu_indicator,
          ADD_USER,
          ADD_DATE,
          UPD_USER,
          UPD_DATE
        )
        VALUES
        (
          l_seq,
          l_seq,
          'CMU',
          'N',
          header_in_rec.end_cust_id ,
          header_in_rec.ship_date,
          header_in_rec.PARENT_PALLET_ID,
          header_in_rec.sn_no,
          'P',
          l_area,
          'C',
          USER,
          sysdate,
          USER,
          sysdate
        );
    END LOOP;
    FOR detail_in_rec IN detail_in_cur
    LOOP
      IF detail_in_rec.area NOT IN
        (
          'F','D','C'
        )
        THEN
        l_area := detail_in_rec.door_area;
      ELSE
        l_area := detail_in_rec.area;
      END IF;
      INSERT
      INTO cross_dock_data_collect_in
        (
          sequence_number,
          msg_id,
          interface_type,
          RECORD_STATUS,
          RETAIL_CUST_NO ,
          ship_date,
          PARENT_PALLET_ID,
          erm_id,
          rec_type,
          area,
          master_order_id,
          line_no,
          prod_id,
          qty,
          uom,
	    	  cmu_indicator,
		      pallet_id,
          sys_order_id,
          ADD_USER,
          ADD_DATE,
          UPD_USER,
          UPD_DATE
        )
        VALUES
        (
          l_seq,
          l_seq,
          'CMU',
          'N',
          detail_in_rec.end_cust_id ,
          detail_in_rec.ship_date,
          detail_in_rec.parent_pallet_id,
          detail_in_rec.sn_no,
          'D',
          detail_in_rec.area,
          detail_in_rec.master_order_id,
          detail_in_rec.erm_line_id,
          detail_in_rec.prod_id,
          detail_in_rec.qty,
          detail_in_rec.uom,
		      detail_in_rec.cmu_indicator,
		      detail_in_rec.pallet_id,
          detail_in_rec.po_no,
          USER,
          sysdate,
          USER,
          sysdate
        );
    END LOOP;
    FOR cw_in_rec IN cw_in_cur
    LOOP
      INSERT
      INTO cross_dock_data_collect_in
        (
          sequence_number,
          msg_id,
          interface_type,
          RECORD_STATUS,
          RETAIL_CUST_NO ,
          ship_date,
          PARENT_PALLET_ID,
          erm_id,
          rec_type,
          area,
          master_order_id,
          line_no,
          prod_id,
          qty,
          uom,
          MFG_DATE,
          CATCH_WT,
          CARRIER_ID,
          LOT_ID,
          ORDER_SEQ,
          CASE_ID,
          CW_TYPE,
          SYS_ORDER_ID,
          ADD_USER,
          ADD_DATE,
          UPD_USER,
          UPD_DATE
        )
        VALUES
        (
          l_seq,
          l_seq,
          'CMU',
          'N',
          cw_in_rec.end_cust_id ,
          cw_in_rec.ship_date,
          cw_in_rec.parent_pallet_id,
          cw_in_rec.sn_no,
          'C',
          cw_in_rec.area,
          cw_in_rec.master_order_id,
          cw_in_rec.erm_line_id,
          cw_in_rec.prod_id,
          cw_in_rec.qty,
          cw_in_rec.uom,
          cw_in_rec.MFG_DATE,
          cw_in_rec.CATCH_WEIGHT,
          cw_in_rec.CARRIER_ID,
          cw_in_rec.LOT_ID,
          cw_in_rec.ORDER_SEQ,
          cw_in_rec.CASE_ID,
          cw_in_rec.CW_TYPE,
          cw_in_rec.po_no,
          USER,
          sysdate,
          USER,
          sysdate
        );
    END LOOP;
    o_status := TRUE;
  EXCEPTION
  WHEN OTHERS THEN
    o_status := FALSE;
    raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_message || ': ' || SQLERRM );
  END;
---------------------------------------------------------------------------
-- Procedure:
--    open_po
--
-- Description:
--   As part of European Imports PO Open process, when user wants to open a PO,
--   we open all the corresponding POs for that customer + ship date combination
--
-- Parameters:
--   i_erm_id - PO number that the user wants to open
---------------------------------------------------------------------------
  PROCEDURE open_all_po_for_rcn
    (
      i_erm_id IN erm.erm_id%TYPE DEFAULT NULL,
      o_success_flag OUT BOOLEAN
    )
  IS
    e_null_erm_id   EXCEPTION;
    e_null_door_no  EXCEPTION;
    l_object_name   VARCHAR2 (30 CHAR) := 'OPEN_ALL_PO_FOR_RCN';
    l_dummy         CHAR;
    l_dummy2        CHAR;
    l_cdk_status    CHAR;
    l_null_door_cnt NUMBER;
    l_rcn_no cross_dock_pallet_xref.retail_cust_no%TYPE;
    l_ship_date cross_dock_pallet_xref.ship_date%TYPE;
    CURSOR c_po_for_one_rcn ( i_rcn_no IN cross_dock_pallet_xref.retail_cust_no%TYPE, i_ship_date IN cross_dock_pallet_xref.ship_date%TYPE )
    IS
      SELECT DISTINCT e.erm_id
      FROM cross_dock_pallet_xref x,
        erm e
      WHERE x.erm_id     = e.erm_id
      AND e.status      IN ('WAT', 'NEW', 'SCH')
      AND retail_cust_no = i_rcn_no
      AND x.ship_date    = i_ship_date;
  BEGIN
    pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'BEGIN OF RCN OPEN PO FOR ERM[' || i_erm_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    l_cdk_status := f_is_crossdock_pallet (i_erm_id, 'E');
    IF i_erm_id  IS NOT NULL AND l_cdk_status = 'Y' THEN
      BEGIN
        -- This is being called for a particular EI PO by the user
        SELECT DISTINCT retail_cust_no,
          ship_date
        INTO l_rcn_no,
          l_ship_date
        FROM cross_dock_pallet_xref
        WHERE erm_id = i_erm_id;
        /* if we find null door number even for one PO, we do not open
        any of the PO for that customer until the door number is
        provided for all the POs */
        SELECT COUNT (DISTINCT e.erm_id)
        INTO l_null_door_cnt
        FROM cross_dock_pallet_xref x,
          erm e
        WHERE x.erm_id     = e.erm_id
        AND e.status      IN ('WAT', 'NEW', 'SCH')
        AND retail_cust_no = l_rcn_no
        AND x.ship_date    = l_ship_date
        AND e.door_no     IS NULL;
        IF l_null_door_cnt > 0 THEN
          /* If we reach here, means, one of the erm had null door number
          raise null door number application error */
          o_success_flag := FALSE;
          RAISE e_null_door_no;
        ELSE
          SELECT 'x'
          INTO l_dummy2
          FROM erm
          WHERE erm_id = i_erm_id
          AND status  IN ('NEW', 'SCH', 'WAT');
          pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'OPEN PO CALLED FOR RCN[' || l_rcn_no || '] AND SHIPDATE[' || l_ship_date || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
          -- Update the PO's status to WAT until they are processed completely
          update_erm_for_rcn (l_rcn_no, l_ship_date, 'WAT');
          --
          --          UPDATE erm
          --             SET status = 'WAT'
          --           WHERE erm_id IN (
          --                    SELECT DISTINCT erm_id
          --                               FROM cross_dock_pallet_xref
          --                              WHERE retail_cust_no = l_rcn_no
          --                                AND ship_date = l_ship_date);
          -- Open all the PO's available for this customer
          FOR r_po_for_one_rcn IN c_po_for_one_rcn (l_rcn_no, l_ship_date)
          LOOP
            open_po (r_po_for_one_rcn.erm_id);
          END LOOP;
          o_success_flag := TRUE;
          pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'OPEN PO COMPLETED FOR RCN[' || l_rcn_no || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
        END IF;
      EXCEPTION
      WHEN e_null_door_no THEN
        pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, 'NULL DOOR NUMBER FOR ONE OF THE PO ON THAT CUSTOMER, PLEASE UPDATE THE DOOR NUMBER THROUGH THE SCREEN', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
        raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_object_name || ': ' || 'NULL DOOR NUMBER FOR ONE OF THE PO ON THAT CUSTOMER, PLEASE UPDATE THE DOOR NUMBER THROUGH THE SCREEN' );
      WHEN OTHERS THEN
        pl_log.ins_msg (pl_lmc.ct_warn_msg, l_object_name, 'PO [' || i_erm_id || '] IS ALREADY OPEN OR UNABLE TO SELECT', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
        raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_object_name || ': ' || '2-ERROR OCCURRED WHILE OPENING THE PO' );
      END;
    ELSE
      o_success_flag := FALSE;
      IF i_erm_id    IS NULL THEN
        /* Null erm_id was passed, raise an exception */
        RAISE e_null_erm_id;
        pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, 'NULL ERM ID', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
      ELSE
        pl_log.ins_msg (pl_lmc.ct_warn_msg, l_object_name, 'PO [' || i_erm_id || '] IS NOT MEANT TO BE PROCESSED AS CDK PO', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
      END IF;
    END IF;
  EXCEPTION
  WHEN e_null_erm_id THEN
    pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, 'NULL ERM ID', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_object_name || ': ' || 'NULL ERM ID' );
  WHEN OTHERS THEN
    o_success_flag := FALSE;
    pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, '3-ERROR OCCURRED WHILE OPENING THE PO[' || i_erm_id || '] ' || SQLERRM, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    /* Rollback the changes */
    ROLLBACK;
    /* Update all the POs for the RCN back to NEW */
    update_erm_for_rcn (l_rcn_no, l_ship_date, 'NEW');
    raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM );
  END;
---------------------------------------------------------------------------
-- Procedure:
--    update_erm_for_rcn
--
-- Description:
--      This SP will update the ERM's status that will processed by open PO
--      to WAT until they are marked as OPN by the program.
--      This sub-program is written separetely to have WAT committed
--      separately using autonomous transaction feature.
-- Parameters:
---------------------------------------------------------------------------
  PROCEDURE update_erm_for_rcn(
      i_rcn       IN cross_dock_pallet_xref.retail_cust_no%TYPE,
      i_ship_date IN cross_dock_pallet_xref.ship_date%TYPE,
      i_status    IN erm.status%TYPE )
  IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_object_name VARCHAR2 (30 CHAR) := 'UPDATE_ERM_FOR_RCN';
  BEGIN
    UPDATE erm
    SET status    = i_status
    WHERE erm_id IN
      ( SELECT DISTINCT erm_id
      FROM cross_dock_pallet_xref
      WHERE retail_cust_no = i_rcn
      AND ship_date        = i_ship_date
      )
    AND status IN ('NEW', 'SCH', 'WAT');
    COMMIT;
  EXCEPTION
  WHEN OTHERS THEN
    pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, 'ERROR OCCURRED WHILE UPDATING THE POs STATUS' || SQLERRM, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM );
  END;
---------------------------------------------------------------------------
-- Procedure:
--    open_po
--
-- Description:
-- This SP is the starting point for European Imports Purchase Order. It
-- subsequently calls the others Procedures to Perform PO Open
--
-- Parameters:
---------------------------------------------------------------------------
  PROCEDURE open_po(i_erm_id IN erm.erm_id%TYPE)
  IS
    e_null_erm_id      EXCEPTION;
    l_food_safety_flag VARCHAR2 (20 CHAR);
    l_load_number      VARCHAR2 (12 CHAR);
    l_freezer_count    NUMBER (4);
    l_object_name      VARCHAR2 (30 CHAR) := 'OPEN_PO';
    l_dummy            CHAR;
    l_batch_no batch.batch_no%TYPE;
    l_total_weight     erd_lpn.catch_weight%TYPE;                               
    l_total_cases      erd_lpn.qty%TYPE;

    CURSOR c_parent_pallets (p_erm_id IN erm.erm_id%TYPE) IS
      SELECT parent_pallet_id, pallet_type
      FROM cross_dock_data_collect cd
      WHERE rec_type = 'H'
      AND cd.erm_id  = p_erm_id;

    CURSOR get_weight IS
       SELECT el.prod_id,el.cust_pref_vendor,
	      NVL(SUM(NVL(el.catch_weight, 0)), 0) total_weight,             
	      NVL(SUM(NVL(el.qty, 0)), 0) total_cases                       
       FROM erd_lpn el, pm, erm e
       WHERE el.prod_id          = pm.prod_id         
         AND el.cust_pref_vendor = pm.cust_pref_vendor
	 AND pm.catch_wt_trk     = 'Y'
	 AND el.sn_no            = i_erm_id
	 AND el.sn_no            = e.erm_id
	 AND e.cross_dock_type   = 'MU'
       GROUP BY el.prod_id,el.cust_pref_vendor;

  BEGIN
    IF i_erm_id IS NULL THEN
      RAISE e_null_erm_id;
    END IF;

    IF f_is_crossdock_pallet (i_erm_id, 'E') = 'Y' THEN
      pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'BEGIN OF OPEN PO FOR ERM[' || i_erm_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );

      -- Create/Update ERM/ERD records
      pl_rcv_cross_dock.update_dtl_records (i_erm_id);
      pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'DETAIL RECORDS UPDATED FOR ERM[' || i_erm_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );

      -- Now that the master aNd detail tables for receiving are updated,
      -- assign slots for all the received pallets
      -- This SP in turn creates inventory for pallets for which slots are
      -- allocated. Also, it creates putaway entries and labor batches for PO
      pl_rcv_cross_dock.assign_slots (i_erm_id);

      pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'SLOTS ASSIGNED FOR ERM[' || i_erm_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );

      -- If all success ready for marking PO as Open
      -- food safety changes
      SELECT config_flag_val
      INTO l_food_safety_flag
      FROM sys_config
      WHERE config_flag_name = 'FOOD_SAFETY_ENABLE';

      -- Get the Food Safety Track Items Count
      SELECT COUNT (1)
      INTO l_freezer_count
      FROM erd e,
        pm p,
        haccp_codes hc
      WHERE e.erm_id         = i_erm_id
      AND p.prod_id          = e.prod_id
      AND p.hazardous       IS NOT NULL
      AND p.hazardous        = hc.haccp_code
      AND hc.food_safety_trk = 'Y';

      BEGIN
        --  Locking the PO to disallow more users from opening the same PO at the same time
        SELECT 'x'
        INTO l_dummy
        FROM erm
        WHERE erm_id = i_erm_id
        AND status  IN ('TRF', 'WAT','NEW','SCH') FOR UPDATE OF status NOWAIT;--knha8378 add NEW and SCH on 9-16-2019
        
        --  Get the load number for the ERM table
        SELECT load_no
        INTO l_load_number
        FROM erm
        WHERE erm_id = i_erm_id;

        --  If load number is null, then make it as NL-(last six digits of the PO)
        IF l_load_number IS NULL THEN
          l_load_number  := 'NL-' || SUBSTR (i_erm_id, -6, 6);
        END IF;


         --
         -- Update PO/SN status to OPN.
         --
         -- 09/25/10 Brian Bent  For a SN leave the maint_flag as is since we
         -- do not send a status change in the PW queue for a SN.
         --
         -- If food safety track is enabled, update the ERM table accordingly
         --
        IF l_food_safety_flag = 'Y' AND l_freezer_count > 0 THEN
          UPDATE erm
          SET status              = 'OPN',
              rec_date            = SYSDATE,
              maint_flag          = DECODE(erm_type, 'SN', maint_flag, 'Y'),
              load_no             = l_load_number,
              freezer_trailer_trk = 'N',           -- Update temp track flags
              cooler_trailer_trk  = 'N'
          WHERE erm_id          = i_erm_id;
        ELSE
          --  Update the PO status to OPN (Open)
          UPDATE erm
             SET status              = 'OPN',
                 rec_date            = SYSDATE,
                 maint_flag          = DECODE(erm_type, 'SN', maint_flag, 'Y'),
                 load_no             = l_load_number
          WHERE erm_id = i_erm_id;
        END IF;

	/* Process into tmp_weight table */
	FOR cwt_rec IN get_weight LOOP
	    INSERT INTO tmp_weight
	      (erm_id,prod_id,cust_pref_vendor,total_cases,total_splits,total_weight)
	    VALUES
	      (i_erm_id,cwt_rec.prod_id,cwt_rec.cust_pref_vendor,cwt_rec.total_cases,0,cwt_rec.total_weight);
	END LOOP;

        /* Insert PO open transaction into TRANS table */
        INSERT
        INTO trans
          (
            trans_id,
            trans_type,
            rec_id,
            trans_date,
            user_id
          )
          VALUES
          (
            trans_id_seq.NEXTVAL,
            'ROP',
            i_erm_id,
            SYSDATE,
            USER
          );
        pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'ERM[' || i_erm_id || '] STATUS UPDATED TO OPEN', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
        /*  UPDATE THE CROSS DOCK REFERENCE FOR THE PALLET ID */
        update_cross_dock_xref (i_erm_id, 'OPN');
        pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'CROSS DOCK REFERENCE UPDATED FOR ERM[' || i_erm_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
        /* Now create Forklift batch for all the parent pallet ids in this PO */
        FOR r_parent_pallets IN c_parent_pallets (i_erm_id) LOOP
          /* Check if the batch has already been created for the mentioned parent pallet id */
          BEGIN
            SELECT batch_no
            INTO l_batch_no
            FROM batch
            WHERE ref_no = r_parent_pallets.parent_pallet_id
            AND status   = 'F';
          EXCEPTION
            /* exception will get thrown if above select query return 0 rows */
          WHEN NO_DATA_FOUND THEN
            l_batch_no := NULL;
          END;
          IF l_batch_no IS NULL THEN
            /* if no labor batches are created for the parent pallet id, then create one */
            create_labor_batches (i_erm_id, r_parent_pallets.parent_pallet_id );
          END IF;
        END LOOP;
        pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'END OF OPEN PO FOR ERM[' || i_erm_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
        /* We've reached the point where everything has completed successfully
        We'll commit the changes to release the row lock on the PO*/
        COMMIT;
      EXCEPTION
      WHEN OTHERS THEN
        /* Rollback the changes */
        ROLLBACK;
        /* Log the error message and raise application error */
        pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, 'PO IS ALREADY LOCKED BY ANOTHER USER. ' || SQLERRM, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
        raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM );
      END;
    END IF;
    /* End of open po process for European Imports */
  EXCEPTION
  WHEN e_null_erm_id THEN
    pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, 'Null ERM ID', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_object_name || ': ' || 'Null ERM ID' );
  WHEN OTHERS THEN
    pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, '1-ERROR OCCURRED WHILE OPENING THE PO[' || i_erm_id || '] ' || SQLERRM, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM );
  END;

---------------------------------------------------------------------------
-- Procedure:
--    update_dtl_records
--
-- Description:
--    This SP will update the ERD table for the PO in question with the
--    following details received from European Imports
--      * quantity
--      * temperature
--      * weight
--      * uom
-- Parameters:
--    i_erm_id --> Purchase Order (erm_id)
---------------------------------------------------------------------------
  PROCEDURE update_dtl_records(
      i_erm_id IN erm.erm_id%TYPE)
  IS
    l_message     VARCHAR2 (256); -- Message buffer
    l_object_name VARCHAR2 (30) := 'UPDATE_DTL_RECORDS';
    l_temp_trk pm.temp_trk%TYPE;
    CURSOR c_erd_dtl
    IS
      SELECT prod_id,
        temp,
        catch_wt
      FROM cross_dock_data_collect
      WHERE erm_id     = i_erm_id
      AND rec_type     = 'D'
      AND data_collect = 'C';
  BEGIN
    pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'BEGIN OF ERD UPDATE FOR ERM[' || i_erm_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    /* Poplute the cross dock details for the erm into the cursor */
    FOR r_erd_dtl IN c_erd_dtl
    LOOP
      SELECT temp_trk INTO l_temp_trk FROM pm WHERE prod_id = r_erd_dtl.prod_id;
      UPDATE erd
      SET temp     = DECODE (l_temp_trk, 'Y', r_erd_dtl.temp, ''),
        weight     = r_erd_dtl.catch_wt
      WHERE erm_id = i_erm_id
      AND prod_id  = r_erd_dtl.prod_id;
      pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'UPDATED PROD_ID[' || r_erd_dtl.prod_id || '] OF ERM[' || i_erm_id || '] WITH TEMP TRACK ON ', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
      --         COMMIT to be done at the end of open po;
      pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'END OF ERD UPDATE FOR ERM[' || i_erm_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    END LOOP;
  EXCEPTION
  WHEN OTHERS THEN
    pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, 'ERROR OCCURRED WHILE UPDATING ERD FOR PO[' || i_erm_id || '] ' || SQLERRM, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM );
  END;
---------------------------------------------------------------------------
-- Procedure:
--    assign_slots
--
-- Description:
--    This SP assigns slots by area wise for EI POs
--    Starts with Cooler Parent pallet id and then followed by Freezer pallet ids
-- Parameters:
---------------------------------------------------------------------------
  PROCEDURE assign_slots(
      i_erm_id IN erm.erm_id%TYPE)
  IS
    l_object_name VARCHAR2 (30) := 'ASSIGN_SLOTS';
    CURSOR c_area (l_erm_id IN erm.erm_id%TYPE)
    IS
      SELECT DISTINCT area
      FROM cross_dock_data_collect
      WHERE erm_id = l_erm_id
      AND rec_type = 'H';
  BEGIN
    pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'BEGIN OF SLOT ASSIGNMENTS FOR ERM[' || i_erm_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    /* We start assigning slots area wise for all the distinct areas in the erm */
    FOR r_area IN c_area (i_erm_id)
    LOOP
      assign_area_slots (i_erm_id, r_area.area);
    END LOOP;
    pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'END OF SLOT ASSIGNMENTS FOR ERM[' || i_erm_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
  EXCEPTION
  WHEN OTHERS THEN
    pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, 'ERROR OCCURED WHILE ASSIGNING SLOTS TO PALLETS IN ERM[' || i_erm_id || '] ' || SQLERRM, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM );
  END;
---------------------------------------------------------------------------
-- Procedure:
--    Assign_area_Slots
--
-- Description:
--
-- Parameters:
---------------------------------------------------------------------------
  PROCEDURE assign_area_slots(
      i_erm_id IN erm.erm_id%TYPE,
      i_area   IN cross_dock_data_collect.area%TYPE )
  IS
    l_zone_id ZONE.zone_id%TYPE;
    l_loc loc.logi_loc%TYPE;
    l_message     VARCHAR2 (256); -- Message buffer
    l_object_name VARCHAR2 (30) := 'ASSIGN_AREA_SLOTS';
    l_pallet_type pallet_type.pallet_type%TYPE;
    l_pallets_pending_assignment NUMBER (4);
    l_pallets_assigned           NUMBER (4);
    l_assigned_loc loc.logi_loc%TYPE;
    l_pallet_index NUMBER (4);
    l_loop_index   NUMBER (4);
    l_seq_no putawaylst.seq_no%TYPE;

    /*  Below cursor will only retrieve those pallets that are not yet assigned slots */
    CURSOR c_parent_pallets (p_area IN cross_dock_data_collect.area%TYPE)
    IS
      SELECT parent_pallet_id,
        pallet_type
      FROM cross_dock_data_collect cd
      WHERE rec_type = 'H'
      AND cd.erm_id  = i_erm_id
      AND cd.area    = p_area
      AND NOT EXISTS
        (SELECT 1 FROM putawaylst WHERE parent_pallet_id = cd.parent_pallet_id
        );

    /* Below cursor will retrieve all the child pallets for the parent pallet in question */
    CURSOR c_child_pallets ( p_parent_pallet_id IN cross_dock_data_collect.parent_pallet_id%TYPE )
    IS
      SELECT parent_pallet_id,
        pallet_id
      FROM cross_dock_data_collect cd
      WHERE rec_type          = 'D' --             AND cd.erm_id = i_erm_id
      AND cd.parent_pallet_id = p_parent_pallet_id;

    CURSOR c_avl_locations ( p_pallet_type IN cross_dock_data_collect.pallet_type%TYPE, p_area IN cross_dock_data_collect.area%TYPE )
    IS
      SELECT l.logi_loc,
        st.deep_ind,
        st.deep_positions,
        l.CUBE
      FROM loc l,
        ZONE z,
        lzone lz,
        slot_type st,
        pallet_type pt,
        aisle_info ai
      WHERE lz.zone_id     = z.zone_id
      AND  l.logi_loc     != z.induction_loc
      AND  l.status = 'AVL' /* knha8378 8-29-2019 ensure that it is not damage location */
      AND lz.logi_loc      = l.logi_loc
      AND st.slot_type     = l.slot_type
      AND pt.pallet_type   = l.pallet_type
      AND ai.NAME          = SUBSTR (l.logi_loc, 1, 2)
      AND ai.sub_area_code = p_area
      AND z.zone_type      = 'PUT'
      AND z.rule_id        = 4
      AND l.pallet_type    = NVL (NULL, 'LW')
      AND l.CUBE          <>
        (SELECT NVL (config_flag_val, 999)
        FROM sys_config
        WHERE config_flag_name = 'LOC_CUBE_KEY_VALUE'
        )
    AND l.perm = 'N'
    AND NOT EXISTS
      (SELECT 0 FROM inv i WHERE i.plogi_loc = l.logi_loc
      )
    ORDER BY 3 DESC,
      1;
   
   CURSOR get_default_loc (c_area IN cross_dock_data_collect.area%TYPE) IS -- add by knha8378 to use the default if no location found
     SELECT z.induction_loc
     FROM loc l,zone z, aisle_info ai,lzone lz
     WHERE l.logi_loc = lz.logi_loc
     AND   l.status = 'AVL'
     AND   z.zone_id = lz.zone_id
     AND   ai.name = substr(l.logi_loc,1,2)
     AND   z.rule_id = 4 
     AND   ai.sub_area_code = c_area
     AND   z.zone_type = 'PUT'
     AND   l.logi_loc = nvl(z.induction_loc,'XXXXX');

  TYPE r_parent_pallet_details
IS
  RECORD
  (
    parent_pallet_id cross_dock_data_collect.parent_pallet_id%TYPE := NULL,
    pallet_type cross_dock_data_collect.pallet_type%TYPE           := NULL );
TYPE t_parent_pallet_details
IS
  TABLE OF r_parent_pallet_details INDEX BY BINARY_INTEGER;
  t_parent_details t_parent_pallet_details;
BEGIN
  -- Initialize the index
  l_pallet_index := 0;
  l_loop_index   := 0;
  pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'CHECKING PENDING PALLETS FOR AREA[' || i_area || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );

  /* Get the count of pallets that need to be assigned a location and putaway */
  SELECT COUNT (1)
  INTO l_pallets_pending_assignment
  FROM cross_dock_data_collect cd
  WHERE rec_type = 'H'
  AND erm_id     = i_erm_id
  AND area       = i_area
  AND NOT EXISTS
    (SELECT 1 FROM putawaylst WHERE parent_pallet_id = cd.parent_pallet_id
    );

  IF l_pallets_pending_assignment > 0 THEN
    pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'ITERATING THROUGH PARENT PALLETS', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    FOR r_parent_pallet IN c_parent_pallets (i_area)
    LOOP
      t_parent_details (l_pallet_index).parent_pallet_id := r_parent_pallet.parent_pallet_id;
      t_parent_details (l_pallet_index).pallet_type      := r_parent_pallet.pallet_type;
      l_pallet_index                                     := l_pallet_index + 1;
    END LOOP;

    pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'INITIALISING PALLET SLOT ASSIGNMENT FOR ' || l_pallets_pending_assignment || ' PALLETS', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'FETCHING ZONE ID', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );

    WHILE l_loop_index < l_pallet_index
    LOOP
      pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'FETCHING LOCATION WITH ITEM CUBE AS SYSPAR: LOC_CUBE_KEY_VALUE VALUE', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
      BEGIN
        /* Find locations with cross dock maxcube values */
        SELECT l.logi_loc
        INTO l_loc
        FROM loc l,
          ZONE z,
          lzone lz,
          aisle_info ai
        WHERE z.rule_id      = 4
        AND l.logi_loc      != z.induction_loc
	AND l.status         = 'AVL'
        AND lz.zone_id       = z.zone_id
        AND lz.logi_loc      = l.logi_loc
        AND ai.NAME          = SUBSTR (l.logi_loc, 1, 2)
        AND ai.sub_area_code = i_area
        AND l.CUBE           = (SELECT NVL (config_flag_val, 999)
                                FROM sys_config
                                WHERE config_flag_name = 'LOC_CUBE_KEY_VALUE')
        AND z.zone_type = 'PUT'
        AND ROWNUM      < 2;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg (pl_lmc.ct_warn_msg, l_object_name, 'NO LOCATION WITH ITEM CUBE AS SYSPAR: LOC_CUBE_KEY_VALUE VALUE AVAILABLE FOR PO[' || i_erm_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
        l_loc := NULL;
      END;

      /* If Item with cube size SYSPAR: LOC_CUBE_KEY_VALUE value is found, then direct all the pallets to that location */
      IF l_loc IS NOT NULL THEN
        pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'LOCATION[' || l_loc || '] WITH ITEM CUBE AS SYSPAR: LOC_CUBE_KEY_VALUE VALUE FOUND FOR PALLET[' || t_parent_details (l_loop_index).parent_pallet_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
        /* initialize the seq # to 1 */
        l_seq_no := 1;
        /* For all the child pallets inside the current parent pallet */
        FOR r_child_pallet IN c_child_pallets (t_parent_details (l_loop_index).parent_pallet_id )
        LOOP
          /* Create Inventory and Putaway records for all the child pallets */
          create_inv_records (l_loc, t_parent_details (l_loop_index).parent_pallet_id, r_child_pallet.pallet_id, l_seq_no );
          l_seq_no := l_seq_no + 1;
        END LOOP;
        /* reinitialize the seq # to 1 */
        l_seq_no := 1;
        pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'LOCATION[' || l_loc || '] WITH ITEM CUBE AS SYSPAR: LOC_CUBE_KEY_VALUE VALUE ASSIGNED TO PALLET[' || t_parent_details (l_loop_index).parent_pallet_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
        l_assigned_loc               := l_loc;
        l_loop_index                 := l_loop_index                 + 1;
        l_pallets_pending_assignment := l_pallets_pending_assignment - 1;
      ELSE
        pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'CHECKING FOR DEEP AND REGULAR SLOTS', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
        FOR r_location IN c_avl_locations (t_parent_details (l_loop_index).pallet_type, i_area )
        LOOP
          IF r_location.deep_ind = 'Y' AND r_location.deep_positions <= l_pallets_pending_assignment THEN
            pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'DEEP SLOT FOUND', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
            /* initialize the pallets assigned counter to 0
            This is used only for deep slots*/
            l_pallets_assigned              := 0;
            WHILE r_location.deep_positions <> l_pallets_assigned
            LOOP
              l_assigned_loc := r_location.logi_loc;
              pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'DEEP LOCATION[' || l_assigned_loc || '] FOUND FOR PALLET[' || t_parent_details (l_loop_index).parent_pallet_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
              /* initialize the seq # to 1 */
              l_seq_no := 1;
              FOR r_child_pallet IN c_child_pallets (t_parent_details (l_loop_index).parent_pallet_id )
              LOOP
                create_inv_records (l_assigned_loc, r_child_pallet.parent_pallet_id, r_child_pallet.pallet_id, l_seq_no );
                l_seq_no := l_seq_no + 1;
              END LOOP;
              /* reinitialize the seq # to 1 */
              l_seq_no := 1;
              pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'DEEP LOCATION[' || l_assigned_loc || '] ASSIGNED TO PALLET[' || t_parent_details (l_loop_index).parent_pallet_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
              /* Set counter values */
              l_pallets_pending_assignment := l_pallets_pending_assignment - 1;
              l_pallets_assigned           := l_pallets_assigned           + 1;
              l_loop_index                 := l_loop_index                 + 1;
            END LOOP;
            EXIT;
          ELSE
            IF r_location.deep_ind = 'N' THEN
              /* we have found a regular slot for slotting */
              l_assigned_loc := r_location.logi_loc;
              pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'REGULAR LOCATION[' || l_assigned_loc || '] FOUND FOR PALLET[' || t_parent_details (l_loop_index).parent_pallet_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
              /* initialize the seq # to 1 */
              l_seq_no := 1;
              FOR r_child_pallet IN c_child_pallets (t_parent_details (l_loop_index).parent_pallet_id )
              LOOP
                create_inv_records (l_assigned_loc, r_child_pallet.parent_pallet_id, r_child_pallet.pallet_id, l_seq_no );
                l_seq_no := l_seq_no + 1;
              END LOOP;
              /* reinitialize the seq # to 1 */
              l_seq_no := 1;
              pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'REGULAR LOCATION[' || l_assigned_loc || '] ASSIGNED TO PALLET[' || t_parent_details (l_loop_index).parent_pallet_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
              /* Set counter values */
              l_pallets_pending_assignment := l_pallets_pending_assignment - 1;
              l_loop_index                 := l_loop_index                 + 1;
              EXIT;
            END IF;
          END IF;
        END LOOP;
      END IF;
      IF l_assigned_loc IS NULL THEN
	OPEN get_default_loc (i_area);
	FETCH get_default_loc into l_assigned_loc;
	IF get_default_loc%NOTFOUND THEN
           /* No location was found by the previous sections, * out the location field */
            l_assigned_loc := '*';
            pl_log.ins_msg (pl_lmc.ct_warn_msg, l_object_name, 'NO LOCATION FOUND FOR PALLET[' || t_parent_details (l_loop_index).parent_pallet_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
	END IF;
	CLOSE get_default_loc;
        /* reinitialize the seq # to 1 */
        l_seq_no := 1;
        FOR r_child_pallet IN c_child_pallets (t_parent_details (l_loop_index).parent_pallet_id )
        LOOP
          /* although we say create inv records, but we only mean to
          create putawaylst records for pallets with no slot */
          create_inv_records (l_assigned_loc, r_child_pallet.parent_pallet_id, r_child_pallet.pallet_id, l_seq_no );
          l_seq_no := l_seq_no + 1;
        END LOOP;

        /* reinitialize the seq # to 1 */
        l_seq_no := 1;
        /* Set counter values */
        l_pallets_pending_assignment := l_pallets_pending_assignment - 1;
        l_loop_index                 := l_loop_index                 + 1;
      END IF;
      /* make this field null again */
      l_assigned_loc := NULL;
    END LOOP;
  ELSE
    pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'NO PENDING PALLETS', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
  END IF;
EXCEPTION
WHEN OTHERS THEN
  pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, 'ERROR OCCURED WHILE ASSIGNING SLOTS TO PALLETS IN ERM[' || i_erm_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
  raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM );
END;

---------------------------------------------------------------------------
-- Procedure:
--    create_inv_records
--
-- Description:
--
-- Parameters:
---------------------------------------------------------------------------
PROCEDURE create_inv_records(
    i_loc              IN loc.logi_loc%TYPE,
    i_parent_pallet_id IN putawaylst.pallet_id%TYPE,
    i_child_pallet_id  IN putawaylst.pallet_id%TYPE,
    i_seq_no           IN putawaylst.seq_no%TYPE )
IS
  l_cool_trk haccp_codes.cool_trk%TYPE;
  l_object_name VARCHAR (30) := 'CREATE_INV_RECORDS';
  l_erm_id erm.erm_id%TYPE;

  CURSOR c_inv_rec ( p_erm_id IN erm.erm_id%TYPE, p_parent_pallet_id IN cross_dock_data_collect.parent_pallet_id%TYPE ) IS
    SELECT e.erm_id,
      d.cust_pref_vendor,
      d.qty  AS erd_qty,
      cd.qty AS cdk_qty,
      cd.uom,
      d.prod_id,
      d.weight,
      cd.pallet_id,
      cd.temp,
      cd.exp_date,
      cd.mfg_date,
      cd.catch_wt,
      cd.harvest_date,
      cd.clam_bed_no,
      cd.country_of_origin,
      cd.wild_farm,
      p.abc,
      p.case_cube,
      p.spc,
      p.temp_trk,
      p.exp_date_trk,
      decode(cd.interface_type, 'CMU', 'C', p.catch_wt_trk) catch_wt_trk,
      d.master_order_id,
      --
      -- 09/27/19 Brian Bent CMU change.
      -- The putawaylst.po_no needs to be the PO# from erd_lpn for a SN.
      (SELECT erd_lpn.po_no
         FROM erd_lpn
        WHERE erd_lpn.pallet_id = cd.pallet_id
          AND erd_lpn.sn_no     = cd.erm_id) erd_lpn_po_no
      --
    FROM erm e,
         erd d,
         cross_dock_data_collect cd,
         pm p
    WHERE e.erm_id          = p_erm_id
    AND e.erm_id            = d.erm_id
    AND e.erm_id            = cd.erm_id
    AND d.erm_id            = cd.erm_id
    AND cd.parent_pallet_id = p_parent_pallet_id
    AND cd.pallet_id        = i_child_pallet_id
    AND cd.rec_type         = 'D'
    AND cd.prod_id          = p.prod_id
    AND d.prod_id           = cd.prod_id
    AND d.prod_id           = p.prod_id
    AND d.cust_pref_vendor  = p.cust_pref_vendor
    AND d.ERM_LINE_ID       = cd.line_no;
BEGIN
  pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'BEGIN INV,PUTAWAYLST CREATION FOR PARENT_PALLET_ID[' || i_parent_pallet_id || '] CHILD_PALLET_ID[' || i_child_pallet_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );

  /* Retrieve the PO Number for the current child pallet */
  SELECT erm_id
  INTO l_erm_id
  FROM cross_dock_data_collect
  WHERE pallet_id = i_child_pallet_id
  AND   rec_type = 'D'
  AND   rownum = 1;
  /* Add rec_type and rownum by knha8378 to avoid EXCEPTION too_many_rows */

  FOR r_inv_rec IN c_inv_rec (l_erm_id, i_parent_pallet_id) LOOP
    BEGIN
      SELECT cool_trk
      INTO l_cool_trk
      FROM pm p,
        haccp_codes hc
      WHERE p.hazardous = hc.haccp_code
      AND p.prod_id     = r_inv_rec.prod_id;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_cool_trk := '';
    END;

    SELECT DECODE (l_cool_trk, 'Y', DECODE (r_inv_rec.country_of_origin, '', 'Y', 'C' ), 'N' )
    INTO l_cool_trk
    FROM DUAL;

    INSERT INTO inv
      ( prod_id,
        rec_id,
        mfg_date,
        rec_date,
        exp_date,
        inv_date,
        logi_loc,
        plogi_loc,
        qoh,
        qty_alloc,
        qty_planned,
        min_qty,
        CUBE,
        lst_cycle_date,
        lst_cycle_reason,
        abc,
        abc_gen_date,
        status,
        lot_id,
        weight,
        temperature,
        exp_ind,
        cust_pref_vendor,
        case_type_tmu,
        pallet_height,
        add_date,
        add_user,
        upd_date,
        upd_user,
        parent_pallet_id,
        dmg_ind,
        inv_uom,
        master_order_id
      )
      VALUES
      (
        r_inv_rec.prod_id, -- prod_id
        r_inv_rec.erm_id,  -- rec_id
        r_inv_rec.mfg_date,
        -- mfg_date
        SYSDATE, -- rec_id
        r_inv_rec.exp_date,
        -- exp_date
        SYSDATE, -- inv_date
        i_child_pallet_id,
        -- logi_loc
        i_loc,             -- plogi_loc
        0,                 -- qoh
        0,                 --  qty_alloc
        r_inv_rec.cdk_qty, -- qty_planned
        0,                 -- min_qty,
        (r_inv_rec.cdk_qty / r_inv_rec.spc ) * r_inv_rec.case_cube,
        /* cube  skid cube not included */
        SYSDATE,                    -- lst_cycle_date,
        '',                         -- lst_cycle_reason,
        r_inv_rec.abc,              -- abc,
        SYSDATE,                    -- abc_gen_date,
        'CDK',                      -- status,
        '',                         -- lot_id,
        r_inv_rec.weight,           -- weight,
        r_inv_rec.temp,             -- temprature,
        '',                         -- exp_ind,
        r_inv_rec.cust_pref_vendor, -- cust_pref_vendor,
        '',                         -- cast_type_tmu,
        '',                         --  pallet_height,
        SYSDATE,                    -- add_date,
        REPLACE(USER,'OPS$',NULL),  -- add_user,
        SYSDATE,                    -- upd_date,
        '',                         -- upd_user,
        i_parent_pallet_id,         -- parent pallet Id,
        '',                         -- dmg_ind
        DECODE(r_inv_rec.uom,2,0,r_inv_rec.uom) ,              -- uom,
        r_inv_rec.master_order_id
      );

    --         COMMIT to be done at the end of open po;

    /* insert into putawaylst */
    INSERT INTO putawaylst
      ( pallet_id, rec_id, prod_id, dest_loc, qty, uom, status, inv_status,
        equip_id, putpath, rec_lane_id, zone_id, lot_id, exp_date, weight,
        temp, mfg_date, qty_expected, qty_received, date_code, exp_date_trk,
        lot_trk, catch_wt, temp_trk, putaway_put, seq_no, mispick,
        cust_pref_vendor, erm_line_id, print_status, reason_code, orig_invoice,
        pallet_batch_no, out_src_loc, out_inv_date, rtn_label_printed,
        clam_bed_trk, inv_dest_loc, add_date, add_user,
        upd_date, upd_user, tti_trk, tti, cryovac, parent_pallet_id,
        qty_dmg, po_line_id, sn_no, po_no, printed_date,
        cool_trk, from_splitting_sn_pallet_flag, demand_flag)
      VALUES
      (
        i_child_pallet_id, -- pallet_Id
        r_inv_rec.erm_id,  -- rec_id
        r_inv_rec.prod_id,
        -- prod_id
        i_loc,             -- dest_loc
        r_inv_rec.erd_qty, -- qty
        DECODE(r_inv_rec.uom,2,0,r_inv_rec.uom),     -- uom
        'NEW',             -- status
        'CDK',
        -- inv_status,
        ' ',
        -- equip_id to be added, not null field
        '',  -- putpath
        ' ', -- rec_lane to be added not null field
        '',  -- zone_id
        '',
        -- lot_id field to be added in cross_dock_data_collect table, r_inv_rec.lot_id
        r_inv_rec.exp_date, --comment out by knha8378--> DECODE (r_inv_rec.exp_date_trk, 'Y', r_inv_rec.exp_date, '' ) exp_date
        DECODE (r_inv_rec.catch_wt_trk, 'Y', r_inv_rec.catch_wt,'C',  r_inv_rec.catch_wt, '' ), -- weight,
        '',                                                            -- temp
        r_inv_rec.mfg_date,                                            -- mfg_date
        r_inv_rec.erd_qty,
        -- qty_expected to be added, not null field.
        r_inv_rec.cdk_qty,
        -- qty_received to be added, not null field.
        '',
        DECODE (r_inv_rec.exp_date_trk, '', 'Y', 'C'), -- exp_date_trk
        'N',
        -- to be clarified with lot_id and lot_trk
        r_inv_rec.catch_wt_trk,                                                        -- catch_wt
        DECODE (r_inv_rec.temp_trk, 'Y', DECODE (r_inv_rec.temp, '', 'Y', 'C'), 'N' ), -- temp_trk
        'N',                                                                           -- putaway_put,
        i_seq_no,                                                                      -- seq_no
        '',                                                                            -- mispack
        r_inv_rec.cust_pref_vendor,
        -- cust_pref_vendor
        '',                    -- erm_line_id, to be checked
        '',                    -- print_status
        '',                    -- reason_code
        '',                    -- orig_invoice
        '',                    -- pallet_batch_no
        '',                    -- out_src_loc
        '',                    -- out_inv_date
        '',                    -- rtn_label_printed
        r_inv_rec.clam_bed_no, -- clam_bed_trk
        '',                    -- inv_dest_loc
        SYSDATE,               -- add_date
        REPLACE(USER,'OPS$',NULL),   -- add_user
        SYSDATE,               -- upd_date
        '',                    -- upd_user
        '',                    -- tti_trk
        '',                    -- tti
        '',                    -- cryovac
        i_parent_pallet_id,    -- parent_pallet_id
        '',                    -- qty_dmg
        '',                    -- po_line_id
        r_inv_rec.erm_id,      -- sn_no
        NVL(r_inv_rec.erd_lpn_po_no, r_inv_rec.erm_id),      -- po_no
        '',                    -- printed date
        l_cool_trk,            -- cool_trk
        '',                    -- from_splitting_sn_pallet_flag
        ''                     --  demand_flg
      );
    --         COMMIT to be done at the end of open po;

    IF (r_inv_rec.clam_bed_no <> '') THEN
      INSERT
      INTO trans
        (
          mfg_date,
          trans_type,
          prod_id,
          cust_pref_vendor,
          rec_id
        )
        VALUES
        (
          SYSDATE,
          'RHB',
          r_inv_rec.prod_id,
          r_inv_rec.cust_pref_vendor,
          r_inv_rec.erm_id
        );
    END IF;
  END LOOP;

  pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'END OF INV,PUTAWAYLST CREATION FOR PARENT_PALLET_ID[' || i_parent_pallet_id || '] CHILD_PALLET_ID[' || i_child_pallet_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
EXCEPTION
WHEN OTHERS THEN
  pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, 'ERROR OCCURRED WHILE CREATING INVENTORY/PUTAWAYLST FOR PO[' || l_erm_id || '] ' || SQLERRM, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
  raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM );
END;


---------------------------------------------------------------------------
-- Procedure:
--    create_labor_batches
--
-- Description:
--
-- Parameters:
---------------------------------------------------------------------------
PROCEDURE create_labor_batches
  (
    i_erm_id           IN erm.erm_id%TYPE,
    i_parent_pallet_id IN putawaylst.pallet_id%TYPE
  )
IS
  ct_putaway_task_lp_length CONSTANT PLS_INTEGER := 10;
  l_temp_no                 NUMBER; -- Work area.
  l_batch_no arch_batch.batch_no%TYPE;
  i_cube        NUMBER          := 0;
  i_cube_weight NUMBER          := 0;
  p_case_cube pm.case_cube%TYPE := 0;
  i_weight      NUMBER               := 0;
  i_prod_weight NUMBER               := 0;
  p_weight erd.weight%TYPE           := 0;
  l_object_name VARCHAR (30)         := 'CREATE_LABOR_BATCHES';
  CURSOR c_cross_dock_data_rec
  IS
    SELECT prod_id,
      qty
    FROM cross_dock_data_collect
    WHERE parent_pallet_id = i_parent_pallet_id
    AND rec_type           = 'D';
BEGIN
  pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'BEGIN OF CREATE LABOR BATCH PROCESS FOR ERM_ID[' || i_erm_id || '] AND PARENT_PALLET_ID[' || i_parent_pallet_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
  /* Calculate the cube value and weight value for the pallet */
  --      FOR r_cross_dock_data_rec IN c_cross_dock_data_rec
  --      LOOP
  --         BEGIN
  --            SELECT case_cube
  --              INTO p_case_cube
  --              FROM pm
  --             WHERE prod_id = r_cross_dock_data_rec.prod_id;
  --         EXCEPTION
  --            WHEN NO_DATA_FOUND
  --            THEN
  --               p_case_cube := 0;
  --         END;
  --
  --         i_cube := TRUNC (p_case_cube * r_cross_dock_data_rec.qty);
  --         i_cube_weight := TRUNC (i_cube_weight + i_cube);
  --
  --         BEGIN
  --            SELECT weight
  --              INTO p_weight
  --              FROM erd
  --             WHERE erm_id = i_erm_id
  --               AND prod_id = r_cross_dock_data_rec.prod_id;
  --         EXCEPTION
  --            WHEN NO_DATA_FOUND
  --            THEN
  --               p_weight := 0;
  --         END;
  --
  --         i_weight := p_weight;
  --         i_prod_weight := TRUNC (i_prod_weight + i_weight);
  --      END LOOP;
  /* For EI, cube weight and product weight will be 0 as pallets are built
  during code run time and not at EI */
  i_cube_weight := 0;
  i_prod_weight := 0;
  --      pl_log.ins_msg (pl_lmc.ct_debug_msg,
  --                      l_object_name,
  --                         'CUBE AND WEIGHT VALUES CALCULATED FOR PALLET_ID['
  --                      || i_parent_pallet_id
  --                      || ']',
  --                      NULL,
  --                      NULL,
  --                      pl_rcv_open_po_types.ct_application_function,
  --                      gl_pkg_name
  --                     );
  /*  Prepare the forklift batch number for inserting into batch table */
  IF (LENGTH (i_parent_pallet_id) > ct_putaway_task_lp_length) THEN
    SELECT forklift_lm_batch_no_seq.NEXTVAL INTO l_temp_no FROM DUAL;
    l_batch_no := pl_lmc.ct_forklift_putaway || TO_CHAR (l_temp_no);
  ELSE
    l_batch_no := pl_lmc.ct_forklift_putaway || i_parent_pallet_id;
  END IF;
  pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'PREPARING FORKLIFT BATCH FOR PALLET_ID[' || i_parent_pallet_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
  INSERT
  INTO batch
    (
      batch_no,
      jbcd_job_code,
      status,
      batch_date,
      kvi_from_loc,
      kvi_to_loc,
      kvi_no_case,
      kvi_no_split,
      kvi_no_pallet,
      kvi_no_item,
      kvi_no_po,
      kvi_cube,
      kvi_wt,
      kvi_no_loc,
      total_count,
      total_piece,
      total_pallet,
      ref_no,
      kvi_distance,
      goal_time,
      target_time,
      no_breaks,
      no_lunches,
      kvi_doc_time,
      kvi_no_piece,
      kvi_no_data_capture,
      msku_batch_flag
    )
  SELECT l_batch_no batch_no,
    fk.putaway_jobcode job_code,
    'F' status,
    TRUNC (SYSDATE) batch_date,
    e.door_no kvi_from_loc,
    p.dest_loc kvi_to_loc,
    0.0 kvi_no_case,
    0.0 kvi_no_split,
    1.0 kvi_no_pallet,
    1.0 kvi_no_item,
    1.0 kvi_no_po,
    i_cube_weight kvi_cube,
    i_prod_weight kvi_wt,
    1.0 kvi_no_loc,
    1 total_count,
    0 total_piece,
    1 total_pallet,
    p.parent_pallet_id ref_no,
    0.0 kvi_distance,
    0.0 goal_time,
    0.0 target_time,
    0.0 no_breaks,
    0.0 no_lunches,
    1.0 kvi_doc_time,
    0.0 kvi_no_piece,
    2.0 kvi_no_data_capture,
    'Y' msku_batch_flag
  FROM job_code j,
    fk_area_jobcodes fk,
    swms_sub_areas ssa,
    aisle_info ai,
    pm,
    erm e,
    putawaylst p
  WHERE j.jbcd_job_code   = fk.putaway_jobcode
  AND fk.sub_area_code    = ssa.sub_area_code
  AND ssa.sub_area_code   = ai.sub_area_code
  AND ai.NAME             = SUBSTR (p.dest_loc, 1, 2)
  AND pm.prod_id          = p.prod_id
  AND pm.cust_pref_vendor = p.cust_pref_vendor
  AND e.erm_id            = p.rec_id
  AND p.parent_pallet_id  = i_parent_pallet_id
  AND ROWNUM              = 1;
  --      COMMIT  to be done at the end of open po;
  pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'BATCH[' || l_batch_no || '] CREATED FOR PALLET_ID[' || i_parent_pallet_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
  UPDATE putawaylst
  SET pallet_batch_no    = l_batch_no
  WHERE parent_pallet_id = i_parent_pallet_id
  AND EXISTS
    (SELECT * FROM batch WHERE batch_no = l_batch_no
    );
  --      COMMIT  to be done at the end of open po;
  pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'PUTAWAYLST UPDATED FOR PALLET_ID[' || i_parent_pallet_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
  pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'END OF CREATE LABOR BATCH PROCESS FOR ERM_ID[' || i_erm_id || '] AND PARENT_PALLET_ID[' || i_parent_pallet_id || ']', NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
EXCEPTION
WHEN OTHERS THEN
  pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, 'ERROR OCCURED WHILE CREATING LABOR BATCHES FOR PO[' || i_erm_id || '] ' || SQLERRM, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
  raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM );
END;

---------------------------------------------------------------------------
-- Procedure:
--    close_po
--
-- Description:
--
-- Parameters:
---------------------------------------------------------------------------
PROCEDURE close_po(i_erm_id IN erm.erm_id%TYPE)
IS
  l_object_name VARCHAR2 (8) := 'CLOSE_PO';
  l_rcn_no cross_dock_pallet_xref.retail_cust_no%TYPE;
  l_ship_date cross_dock_pallet_xref.ship_date%TYPE;
  l_cross_dock_type    cross_dock_type.cross_dock_type%TYPE;

  CURSOR c_po_for_one_rcn ( i_rcn_no IN cross_dock_pallet_xref.retail_cust_no%TYPE, i_ship_date IN cross_dock_pallet_xref.ship_date%TYPE ) IS
    SELECT DISTINCT e.erm_id
    FROM cross_dock_pallet_xref x, erm e
    WHERE x.erm_id     = e.erm_id
    AND e.status      IN ('OPN', 'PND', 'OUT')
    AND retail_cust_no = i_rcn_no
    AND x.ship_date    = i_ship_date;
BEGIN
   /* knha8378 - 8-21-2019 handle CMU SN cross dock project */
   select nvl(cross_dock_type,'XX') 
   into l_cross_dock_type
   from erm
   where erm_id = i_erm_id;

   IF l_cross_dock_type = 'MU' then
        lock_po (i_erm_id); -- lock PO

        -- verify PO
        pl_rcv_po_close.verify_po_info (i_erm_id);
        pl_rcv_po_close.check_for_putaway_tasks (); -- check for putaway

        -- check data collection
        check_for_data_collection (i_erm_id);

        -- check for matching quantities
        pl_rcv_po_close.check_for_matching_quantities (i_erm_id);

        -- update inv
        pl_rcv_po_close.update_ei_inv (i_erm_id);

        update_erd (i_erm_id);  -- update erd
        close_ei_po (i_erm_id); -- close po

        /* Release lock on PO*/
        IF c_po_lock%ISOPEN THEN
          CLOSE c_po_lock;
        END IF;
   ELSE
      -- Get the RCN Number and ship date to get the PO group details
      SELECT DISTINCT retail_cust_no, ship_date
      INTO l_rcn_no, l_ship_date
      FROM cross_dock_pallet_xref
      WHERE erm_id = i_erm_id;

      -- Close all the POs in this group
      FOR r_po_for_one_rcn IN c_po_for_one_rcn (l_rcn_no, l_ship_date)
      LOOP
        lock_po (r_po_for_one_rcn.erm_id); -- lock PO

        -- verify PO
        pl_rcv_po_close.verify_po_info (r_po_for_one_rcn.erm_id);
        pl_rcv_po_close.check_for_putaway_tasks (); -- check for putaway

        -- check data collection
        check_for_data_collection (r_po_for_one_rcn.erm_id);

        -- check for matching quantities
        pl_rcv_po_close.check_for_matching_quantities (r_po_for_one_rcn.erm_id);

        -- update inv
        pl_rcv_po_close.update_ei_inv (r_po_for_one_rcn.erm_id);

        update_erd (r_po_for_one_rcn.erm_id);  -- update erd
        close_ei_po (r_po_for_one_rcn.erm_id); -- close po

        /* Release lock on PO*/
        IF c_po_lock%ISOPEN THEN
          CLOSE c_po_lock;
        END IF;
      END LOOP;
   END IF; -- l_cross_dock_type either EI and not MU
END close_po;
---------------------------------------------------------------------------
-- Procedure:
--    check_for_data_collection
--
-- Description:
--
-- Parameters:
---------------------------------------------------------------------------
PROCEDURE check_for_data_collection(
    i_erm_id IN erm.erm_id%TYPE)
IS
  l_object_name           VARCHAR2 (30) := 'CHECK_FOR_DATA_COLLECTION';
  e_premature_termination EXCEPTION;
  l_po_found_bln          BOOLEAN := FALSE;
  g_row_count             NUMBER;
  g_sqlcode               NUMBER;
  g_status                NUMBER;
  g_err_msg               VARCHAR2 (255);
  ct_program_code         VARCHAR2 (5) := 'RE03';
  ct_more_rec_data        NUMBER       := 92;
BEGIN
  SELECT COUNT (*)
  INTO g_row_count
  FROM cross_dock_data_collect
  WHERE erm_id      = i_erm_id
  AND rec_type      = 'D'
  AND data_collect IN ('Y', 'P');
  IF g_row_count    > 0 THEN
    g_err_msg      := 'Data not collected for SN/PO or extended SN/PO ' || i_erm_id || '.';
    pl_text_log.ins_msg ('WARN', ct_program_code, g_err_msg, SQLCODE, SQLERRM );
    g_status := ct_more_rec_data;
    RAISE e_premature_termination;
  END IF;
EXCEPTION
WHEN e_premature_termination THEN
  RAISE;
WHEN OTHERS THEN
  g_sqlcode := SQLCODE;
  g_err_msg := 'Error checking for data collection on SN/PO ' || i_erm_id || '.';
  pl_text_log.ins_msg ('WARN', ct_program_code, g_err_msg, SQLCODE, SQLERRM );
  RAISE e_premature_termination;
END check_for_data_collection;
---------------------------------------------------------------------------
-- Procedure:
--    update_erd
--
-- Description:
--
-- Parameters:
---------------------------------------------------------------------------
PROCEDURE update_erd(i_erm_id IN erm.erm_id%TYPE)
IS
  l_object_name            VARCHAR2 (30) := 'UPDATE_ERD';
  l_catchweight            NUMBER;
  l_avg_weight             NUMBER;
  l_qty                    NUMBER := 0;
  l_total_qty              NUMBER := 0;
  CURSOR c_cross_dock_data_collect IS
    SELECT prod_id,line_no,sum(nvl(qty,0)) sum_qty
    FROM cross_dock_data_collect
    WHERE rec_type = 'D'
    AND erm_id     = i_erm_id
    GROUP BY prod_id,line_no;

  CURSOR c_get_weight (c_prod_id IN pm.prod_id%TYPE, 
		       c_line_no erd.erm_line_id%TYPE) IS
    SELECT sum(nvl(catch_wt,0))
    FROM cross_dock_data_collect
    where rec_type = 'C'
    and   erm_id = i_erm_id
    and   line_no = c_line_no
    and   prod_id = c_prod_id;

BEGIN
/* knha8378 8-22-2019 rewrite the code to update correct */
    FOR each in c_cross_dock_data_collect LOOP
	l_catchweight := 0;
	open c_get_weight (each.prod_id,each.line_no);
	fetch c_get_weight into l_catchweight;
	if c_get_weight%FOUND and l_catchweight > 0 then
	   l_avg_weight := l_catchweight / each.sum_qty;
        else
	   l_avg_weight := 0;
	end if;
	close c_get_weight;
	UPDATE erd
	  set qty_rec = each.sum_qty,
	      weight = decode(l_avg_weight,0,null,each.sum_qty * l_avg_weight)
        WHERE erm_id = i_erm_id
        AND   erm_line_id = each.line_no
	AND   prod_id = each.prod_id;

        UPDATE pm
        SET last_rec_date = SYSDATE
        WHERE prod_id     = each.prod_id;

        UPDATE pm_upc
        SET last_rec_date = SYSDATE
        WHERE prod_id     = each.prod_id;
    END LOOP;
END update_erd;

---------------------------------------------------------------------------
-- Procedure:
--    close_ei_po
--
-- Description: Close the Cross dock PO.
--
-- Parameters:
--      i_erm_id    ERM_ID
---------------------------------------------------------------------------
PROCEDURE close_ei_po(
    i_erm_id IN erm.erm_id%TYPE)
IS
  l_object_name           VARCHAR2 (30) := 'CLOSE_EI_PO';
  e_premature_termination EXCEPTION;
  g_sqlcode               NUMBER;
  g_err_msg               VARCHAR2 (255);
  ct_program_code         VARCHAR2 (5) := 'RE03';
  l_erm_type		  erm.erm_type%type;
BEGIN
  /* knha8378 added on 8/21 for cross dock to handle RDC SN CMU */
  select erm_type 
   into l_erm_type
  from erm
  where erm_id = i_erm_id;

  UPDATE erm
  SET status     = 'CLO',
      close_date = SYSDATE
  WHERE erm_id = i_erm_id;

  /* knha8378  keep same logic for PO close and treat the else for SN CMU */
  if l_erm_type <> 'SN' then
    INSERT INTO trans
      ( trans_id, 
        trans_type, 
	trans_date, 
	rec_id, 
        user_id, 
	cmt, upload_time, 
        batch_no,  
	warehouse_id, 
	po_no
	)
      VALUES
      ( trans_id_seq.NEXTVAL, -- trans_id
        'CLO',                -- trans_type
        SYSDATE,              -- trans_date
        i_erm_id,             -- rec_id
        USER,     -- user_id
        'CROSS DOCK PROCEDURE:pl_rcv_cross_dock.close_ei_po',       -- CMT
        TO_DATE('01-JAN-1980','FXDD-MON-YYYY'),  -- upload_time
        TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')),   -- batch_no
        '000',    -- warehouse_id
        i_erm_id -- PO_no
	); 

      UPDATE cross_dock_xref 
           SET status = 'CLO' 
        WHERE erm_id = i_erm_id;
   else -- SN close logic for CMU 
       INSERT INTO trans 
	  (trans_id, trans_type, rec_id, trans_date, user_id, 
	   upload_time, 
	   batch_no, warehouse_id)
       VALUES
	 (trans_id_seq.NEXTVAL, 'CSN', i_erm_id, SYSDATE, USER, 
	  TO_DATE('01-JAN-1980','FXDD-MON-YYYY'),
	  TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), '000');
		      
      UPDATE cross_dock_xref 
           SET status = 'CLO' 
        WHERE erm_id = i_erm_id;

      UPDATE sn_header
	set status = 'CLO'
      where sn_no = i_erm_id;
   end if;
EXCEPTION
WHEN OTHERS THEN
  g_sqlcode := SQLCODE;
  g_err_msg := 'Oracle error inserting into transaction table.';
  pl_text_log.ins_msg ('WARN', ct_program_code, g_err_msg, SQLCODE, SQLERRM );
  RAISE e_premature_termination;
END close_ei_po;

---------------------------------------------------------------------------
-- Procedure:
--    update_cross_dock_xref
--
-- Description:Update the CROSS_DOCK_XREF with the status of PO
--
-- Parameters:
--      i_erm_id    ERM_ID
--      i_status    STATUS to be updated
---------------------------------------------------------------------------
PROCEDURE update_cross_dock_xref(
    i_erm_id IN erm.erm_id%TYPE,
    i_status IN cross_dock_xref.status%TYPE )
IS
BEGIN
  /*
  UPDATE cross_dock_xref
  SET status = i_status, upd_date = SYSDATE
  WHERE erm_id = i_erm_id;
  */
  UPDATE cross_dock_xref
  SET status    = i_status,
    upd_date    = SYSDATE
  WHERE erm_id IN
    (SELECT rec_id
    FROM putawaylst
    WHERE parent_pallet_id IN
      (SELECT parent_pallet_id
      FROM putawaylst
      WHERE rec_id = i_erm_id
      AND ROWNUM   = 1
      )
    );
END;
--------------------------------------------------------------------------
-- Procedure
-- upload_cross_dock_data
--
-- Description:Upload data from CROSS_DOCK_DATA_COLLECT_IN into
--              CROSS_DOCK_DATA_COLLECT and insert records into
--              CROSS_DOCK_PALLET_XREF which would be later used by OP
--
-- Parameters:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/02/19 bben0556 Brian Bent
--                      Project: R30.6.8-Jira-OPCOF-2517-CMU-Project_cross_dock_picking
--
--                      Comment out the "European Imports" code.  It was
--                      not working correctly for CMU cross docking.
--
--                      Add call to procedure "cmu_upload_cross_dock_data"
---------------------------------------------------------------------------
PROCEDURE upload_cross_dock_data (i_erm_id IN erm.erm_id%TYPE) IS

  l_object_name VARCHAR2 (30) := 'UPLOAD_CROSS_DOCK_DATA';
  l_message     VARCHAR2 (512); -- Message buffer
  gl_pkg_name   VARCHAR2 (30) := 'PL_RCV_CROSS_DOCK';
  l_status      BOOLEAN;

  CURSOR c_msg_id IS
    SELECT DISTINCT msg_id
    FROM cross_dock_data_collect_in
    WHERE record_status = 'N'
    AND   erm_id = i_erm_id;
    
  CURSOR c_rcn_no (i_msg_id cross_dock_data_collect_in.msg_id%TYPE) IS
    SELECT DISTINCT retail_cust_no
    FROM cross_dock_data_collect_in
    WHERE msg_id      = i_msg_id
    AND record_status = 'N';

  CURSOR c_erm_in_rcn ( i_msg_id cross_dock_data_collect_in.msg_id%TYPE, i_rcn_no cross_dock_data_collect_in.retail_cust_no%TYPE ) IS
    SELECT DISTINCT erm_id
    FROM cross_dock_data_collect_in
    WHERE retail_cust_no = i_rcn_no
    AND msg_id           = i_msg_id
    AND cmu_indicator <> 'C' --vkal9662 to data collect only for non CMU 
    AND rec_type         = 'H';
BEGIN
   cmu_upload_cross_dock_data (i_erm_id => i_erm_id);

  /***********************************
  ************************************
  10/02/19  Brian Bent   Comment out the this "European Imports" code
  FOR r_msg_id IN c_msg_id LOOP
    FOR r_rcn_no IN c_rcn_no (r_msg_id.msg_id) LOOP
      upload_cdk_for_msg_id (r_msg_id.msg_id, r_rcn_no.retail_cust_no, l_status );

      IF l_status THEN
        UPDATE cross_dock_data_collect_in
        SET record_status = 'S',
          upd_date        = SYSDATE,
          upd_user        = USER
        WHERE msg_id      = r_msg_id.msg_id;
        l_message        := l_object_name || ' Data Upload successfull for msg_id[' || r_msg_id.msg_id || ']';
        pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, l_message, SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );

        --
        -- Update the data collect flag for all the ERMs in this combination
        --
        FOR r_erm_in_rcn IN c_erm_in_rcn (r_msg_id.msg_id, r_rcn_no.retail_cust_no )
        LOOP
          update_cross_dock_data_collect (r_erm_in_rcn.erm_id);
        END LOOP;

        COMMIT;

        l_message := l_object_name || ' Data collect flag has been updated successfully for msg_id[' || r_msg_id.msg_id || ']';
        pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, l_message, SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
      ELSE
        ROLLBACK;

        UPDATE cross_dock_data_collect_in
        SET record_status = 'F',
          upd_date        = SYSDATE,
          upd_user        = USER
        WHERE msg_id      = r_msg_id.msg_id;
        
        -- Performing a commit so that this does not get rollback next time
        COMMIT;
        l_message := l_object_name || ' Data Upload Failed for msg_id:[' || r_msg_id.msg_id || ']';
        pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, l_message, SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
      END IF;
    END LOOP;
  END LOOP;
  ************************************
  ***********************************/
END upload_cross_dock_data;


---------------------------------------------------------------------------
-- Procedure
-- upload_cdk_for_msg_id
--
-- Description:Upload data from CROSS_DOCK_DATA_COLLECT_IN into
--              CROSS_DOCK_DATA_COLLECT and insert records into
--              CROSS_DOCK_PALLET_XREF which would be later used by OP
--
-- Parameters:
--        i_msg_id    IN    MSG_ID from SAP-PI
--          i_rcn_no      IN     Retail Customer Number
--        o_status    OUT    STATUS of update
---------------------------------------------------------------------------
PROCEDURE upload_cdk_for_msg_id(
    i_msg_id IN cross_dock_data_collect_in.msg_id%TYPE,
    i_rcn_no IN cross_dock_data_collect_in.retail_cust_no%TYPE,
    o_status OUT BOOLEAN )
IS
  l_object_name       VARCHAR2 (30) := 'UPLOAD_CDK_FOR_MSG_ID';
  l_message           VARCHAR2 (512); -- Message buffer
  l_num_pallets       NUMBER (3);
  l_num_items         NUMBER (3);
  l_items_remaining   NUMBER (3);
  l_pallets_remaining NUMBER (3);
  l_items_assigned    NUMBER (3);
  l_counter           NUMBER (1);
  qty_remaining       NUMBER (8);
  pallets_remaining   NUMBER (3);
  items_remaining     NUMBER (3);
  items_assigned      NUMBER (3);
  l_max_qty           NUMBER (3);
  l_items_per_pallet  NUMBER (3);
  l_count             NUMBER (10);
  l_pallet            NUMBER (10);
  l_qty_remaining     NUMBER (3);
  l_qty               NUMBER (3);
  l_qty_per_pallet    NUMBER (3);
  l_spc pm.spc%TYPE;
  l_split_trk pm.split_trk%TYPE;
  l_sysco_shelf_life pm.sysco_shelf_life%TYPE;
  l_cust_shelf_life pm.cust_shelf_life%TYPE;
  l_mfr_shelf_life pm.mfr_shelf_life%TYPE;
  l_shelf_life NUMBER;
  l_mfg_date_trk pm.mfg_date_trk%TYPE;
  l_msg_id cross_dock_data_collect_in.msg_id%TYPE;
  l_erm_id cross_dock_data_collect_in.erm_id%TYPE;
  l_prod_id cross_dock_data_collect_in.prod_id%TYPE;
  v_pallet_id cross_dock_data_collect_in.parent_pallet_id%TYPE;
  l_prev_erm_id cross_dock_data_collect_in.erm_id%TYPE;
  l_prev_pallet_id cross_dock_data_collect_in.parent_pallet_id%TYPE;
  l_rec_type cross_dock_data_collect_in.rec_type%TYPE;
  l_line_no cross_dock_data_collect_in.line_no%TYPE;
  l_exp_date cross_dock_data_collect_in.exp_date%TYPE;
  l_uom cross_dock_data_collect_in.uom%TYPE;
  l_retail_cust_no cross_dock_data_collect_in.retail_cust_no%TYPE;
  l_max_item cross_dock_data_collect_in.prod_id%TYPE;
  l_sys_order_id erm.sys_order_id%TYPE;
  l_ship_date erm.ship_date%TYPE;
  l_po_not_processed  NUMBER;
  l_po_processed      NUMBER;
  e_null_pallet       EXCEPTION;
  e_null_item         EXCEPTION;
  e_null_sys_order_id EXCEPTION;
  e_null_ship_date    EXCEPTION;
  e_po_processed      EXCEPTION;
  gl_pkg_name         VARCHAR2 (30) := 'PL_RCV_CROSS_DOCK';
  l_cross_dock_type varchar2(5);
  l_sysord_id number;
  
  CURSOR c_area ( i_retail_cust_no cross_dock_data_collect_in.retail_cust_no%TYPE, i_msg_id cross_dock_data_collect_in.msg_id%TYPE )
  IS
    SELECT DISTINCT area
    FROM cross_dock_data_collect_in
    WHERE rec_type     = 'P'
    AND retail_cust_no = i_retail_cust_no
    AND msg_id         = i_msg_id;
  r_area c_area%ROWTYPE;
  CURSOR c_rcn_shipdate ( i_rcn_no cross_dock_data_collect_in.retail_cust_no%TYPE, i_msg_id cross_dock_data_collect_in.msg_id%TYPE )
  IS
    SELECT DISTINCT cdk_p.erm_id,
      cdk_in.ship_date
    FROM cross_dock_pallet_xref cdk_p,
      cross_dock_data_collect_in cdk_in
    WHERE cdk_p.retail_cust_no = i_rcn_no
    AND cdk_in.msg_id          = i_msg_id
    AND cdk_in.rec_type        = 'P'
    AND cdk_in.record_status   = 'N'
    AND cdk_in.retail_cust_no  = i_rcn_no
    AND cdk_p.ship_date        = cdk_in.ship_date
    AND cdk_p.parent_pallet_id = cdk_in.parent_pallet_id;
  r_rcn_shipdate c_rcn_shipdate%ROWTYPE;
  CURSOR c_pallet ( i_area cross_dock_data_collect_in.area%TYPE, i_retail_cust_no cross_dock_data_collect_in.retail_cust_no%TYPE, i_msg_id cross_dock_data_collect_in.msg_id%TYPE )
  IS
    SELECT parent_pallet_id
    FROM cross_dock_data_collect_in
    WHERE rec_type     = 'P'
    AND area           = i_area
    AND retail_cust_no = i_retail_cust_no
    AND msg_id         = i_msg_id
    AND record_status  = 'N'
    ORDER BY sequence_number,
      add_date ASC;
  r_pallet c_pallet%ROWTYPE;
  CURSOR c_item ( i_area cross_dock_data_collect_in.area%TYPE, i_retail_cust_no cross_dock_data_collect_in.retail_cust_no%TYPE, i_msg_id cross_dock_data_collect_in.msg_id%TYPE )
  IS
    SELECT erm_id,
      rec_type,
      line_no,
      prod_id,
      qty,
      uom,
      exp_date,
      mfg_date,
      master_order_id,
      order_seq,
      carrier_id,
      lot_id,
      pallet_id,
      interface_type,
      item_seq,
      sys_order_id,-- vkal9662
      catch_wt --knha8378 need to get catch weight for putawaylst table
    FROM cross_dock_data_collect_in
    WHERE rec_type                    = 'D'
    AND retail_cust_no                = i_retail_cust_no
    AND msg_id                        = i_msg_id
    AND area                          = i_area
   -- AND DECODE (area, 'D', 'C', area) = i_area
    AND record_status                 = 'N'
    ORDER BY sequence_number,
      add_date ASC;
  CURSOR c_case_rec (i_prod_id cross_dock_data_collect_in.prod_id%TYPE, 
                     i_sysord_id cross_dock_data_collect_in.sys_order_id%TYPE,
                     i_erm_id cross_dock_data_collect_in.erm_id%TYPE, 
                     i_retail_cust_no cross_dock_data_collect_in.retail_cust_no%TYPE, 
                     i_msg_id cross_dock_data_collect_in.msg_id%TYPE ) IS
    SELECT *
    FROM cross_dock_data_collect_in
    WHERE prod_id      = i_prod_id
    AND erm_id         = i_erm_id
    AND msg_id         = i_msg_id
    AND retail_cust_no = i_retail_cust_no
    AND sys_order_id  = i_sysord_id
    AND rec_type       = 'C';
  r_case_rec c_case_rec%ROWTYPE;
  
  CURSOR C_Multi_PO (p_erm_id cross_dock_data_collect_in.erm_id%TYPE) is 
  select po_no, sn_no 
  from sn_rdc_po
  where sn_no = p_erm_id
  and cmu_indicator ='C';
  
TYPE r_item_rec
IS
  RECORD
  (
    erm_id cross_dock_data_collect_in.erm_id%TYPE,
    rec_type cross_dock_data_collect_in.rec_type%TYPE,
    line_no cross_dock_data_collect_in.line_no%TYPE,
    prod_id cross_dock_data_collect_in.prod_id%TYPE,
    qty cross_dock_data_collect_in.qty%TYPE,
    uom cross_dock_data_collect_in.uom%TYPE,
    exp_date cross_dock_data_collect_in.exp_date%TYPE,
    mfg_date cross_dock_data_collect_in.mfg_date%TYPE,
    master_order_id cross_dock_data_collect_in.master_order_id%TYPE, --vkal9662
    order_seq cross_dock_data_collect_in.order_seq%TYPE,
    carrier_id cross_dock_data_collect_in.carrier_id%TYPE,
    lot_id cross_dock_data_collect_in.lot_id%TYPE,
    pallet_id cross_dock_data_collect_in.pallet_id%TYPE,
    interface_type cross_dock_data_collect_in.interface_type%TYPE,
    item_seq cross_dock_data_collect_in.item_seq%TYPE,
    sys_order_id cross_dock_data_collect_in.sys_order_id%TYPE,
    catch_wt     cross_dock_data_collect_in.catch_wt%TYPE);
  r_item r_item_rec;
BEGIN

    dbms_output.put_line(' First line');

  FOR r_rcn_shipdate IN c_rcn_shipdate (i_rcn_no, i_msg_id) LOOP
    BEGIN
        dbms_output.put_line(' 2 line');
    
      SELECT COUNT (*)
      INTO l_po_not_processed
      FROM cross_dock_xref
      WHERE erm_id = r_rcn_shipdate.erm_id
      AND status   IN ('NEW', 'INC');
      SELECT COUNT (*)
      INTO l_po_processed
      FROM cross_dock_xref
      WHERE erm_id       = r_rcn_shipdate.erm_id
      AND status NOT    IN ('NEW', 'INC');
      IF (l_po_processed = 0 AND l_po_not_processed = 0) THEN
        EXIT;
      END IF;
      IF (l_po_not_processed > 0) THEN
        DELETE
        FROM cross_dock_data_collect
        WHERE erm_id IN
          (SELECT erm_id
          FROM cross_dock_pallet_xref
          WHERE retail_cust_no = i_rcn_no
          AND ship_date        = r_rcn_shipdate.ship_date
          );
        UPDATE cross_dock_xref
        SET status    = 'INC',
          upd_date    = SYSDATE
        WHERE erm_id IN
          (SELECT erm_id
          FROM cross_dock_pallet_xref
          WHERE retail_cust_no = i_rcn_no
          AND ship_date        = r_rcn_shipdate.ship_date
          );
        DELETE
        FROM cross_dock_pallet_xref
        WHERE retail_cust_no = i_rcn_no
        AND ship_date        = r_rcn_shipdate.ship_date;
        EXIT;
      END IF;
      IF (l_po_processed > 0) THEN
        RAISE e_po_processed;
      END IF;
    EXCEPTION
    WHEN e_po_processed THEN
      o_status  := FALSE;
      l_message := l_object_name || 'PO#' || r_rcn_shipdate.erm_id || '  already processed for Retail Customer - ' || i_rcn_no || ' and Ship Date - ' || r_rcn_shipdate.ship_date;
      raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_message || ': ' || SQLERRM );
    END;
  END LOOP;
    dbms_output.put_line(' 3 line');
  
  FOR r_area IN c_area (i_rcn_no, i_msg_id) LOOP
    BEGIN
      /*  Get the pallet count that are available for this RCN + Message combination */
      
      dbms_output.put_line(' 4 line');
      
      SELECT COUNT (parent_pallet_id)
      INTO l_num_pallets
      FROM cross_dock_data_collect_in
      WHERE rec_type     = 'P'
      AND area           = r_area.area
      AND retail_cust_no = i_rcn_no
      AND msg_id         = i_msg_id
      AND record_status  = 'N';
      /*  Get the item count that are available for this RCN + Message combination */
      SELECT COUNT (prod_id)
      INTO l_num_items
      FROM cross_dock_data_collect_in
      WHERE 1=1
      AND area           = r_area.area
      --DECODE (area, 'D', 'C', area) = r_area.area
      AND rec_type       = 'D'
      AND retail_cust_no = i_rcn_no
      AND record_status  = 'N'
      AND msg_id         = i_msg_id;
      /* Exception handling for null items and pallets */
      IF l_num_pallets = 0 THEN
        RAISE e_null_pallet;
      END IF;
      IF l_num_items = 0 THEN
        RAISE e_null_item;
      END IF;
      IF l_num_pallets     <= l_num_items THEN
        l_items_per_pallet := FLOOR (l_num_items / l_num_pallets);
        BEGIN
          FOR r_pallet IN c_pallet (r_area.area, i_rcn_no, i_msg_id) LOOP
            BEGIN
              OPEN c_item (r_area.area, i_rcn_no, i_msg_id);
              l_prev_erm_id := 0;
              
                 dbms_output.put_line(' 5 line');
              FOR l_counter IN 1 .. l_items_per_pallet
              LOOP
                 
                  dbms_output.put_line(' 6 line');
              
                FETCH c_item INTO r_item;
                EXIT  WHEN c_item%NOTFOUND;
                 dbms_output.put_line(' 7 line');
                BEGIN
                  /* Get the SPC for the item */
                  SELECT spc,
                    split_trk,
                    sysco_shelf_life,
                    cust_shelf_life,
                    mfr_shelf_life,
                    mfg_date_trk
                  INTO l_spc,
                    l_split_trk,
                    l_sysco_shelf_life,
                    l_cust_shelf_life,
                    l_mfr_shelf_life,
                    l_mfg_date_trk
                  FROM pm
                  WHERE prod_id = r_item.prod_id;
                EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  o_status  := FALSE;
                  l_message := l_object_name || ' Item not found in PM table[' || r_item.prod_id || ']';
                  pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, l_message, SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
                  raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_message || ': ' || SQLERRM );
                END;
                /* Calculate the manufacture date */
                IF l_sysco_shelf_life  <> 0 AND l_cust_shelf_life <> 0 THEN
                  l_shelf_life         := l_sysco_shelf_life + l_cust_shelf_life;
                ELSIF l_mfr_shelf_life <> 0 THEN
                  l_shelf_life         := l_mfr_shelf_life;
                ELSE
                  l_shelf_life := 0;
                END IF;
                /*  Creating 'D' type record */
                dbms_output.put_line(' before vkal9662 -1 item insert');
                INSERT INTO cross_dock_data_collect
                  ( erm_id,
                    rec_type,
                    line_no,
                    prod_id,
                    qty,
                    uom,
                    pallet_id,
                    parent_pallet_id,
                    exp_date,
                    mfg_date,
		    catch_wt, --knha8378 9-16-2019
                    master_order_id,
                    order_seq,
                    carrier_id,
                    lot_id,
                    interface_type,
                    item_seq,
                    sys_order_id,--vkal9662
                    add_date,
                    add_user,
                    upd_date,
                    upd_user
                  )
                  VALUES
                  (
                    r_item.erm_id,
                    r_item.rec_type,
                    r_item.line_no,
                    r_item.prod_id,
                    r_item.qty ,
                --    DECODE (r_item.uom, 2, r_item.qty * l_spc, r_item.qty ),
                    -- incorrect logic of UOM by knha8378 on DECODE (l_split_trk, 'Y', 1, 0),
                    r_item.uom,
                    decode(r_item.interface_type, 'CMU',  r_item.pallet_id,pallet_id_seq.NEXTVAL),
                    r_pallet.parent_pallet_id,
                    r_item.exp_date,
                    r_item.mfg_date,
		    r_item.catch_wt, --knha8378 need for putawaylst
                    r_item.master_order_id,
                    r_item.order_seq,
                    r_item.carrier_id,
                    r_item.lot_id,
                    r_item.interface_type,
                    r_item.item_seq,
                    r_item.sys_order_id,--vkal9662 -1
                    SYSDATE,
                    USER,
                    SYSDATE,
                    USER
                  );
                dbms_output.put_line('after vkal9662 -1 item insert');
                /* Mark D type record as processed */
                UPDATE cross_dock_data_collect_in
                SET record_status  = 'P',
                  upd_date         = SYSDATE,
                  upd_user         = USER
                WHERE rec_type     = r_item.rec_type
                AND erm_id         = r_item.erm_id
                AND prod_id        = r_item.prod_id
                AND sys_order_id   = r_item.sys_order_id
                AND retail_cust_no = i_rcn_no
                AND msg_id         = i_msg_id;
                dbms_output.put_line('after vkal9662 -1 update, itm'||r_item.prod_id||',erm '|| r_item.erm_id ||',ln '||r_item.line_no);
                /* Creating 'C' type record */
                SELECT COUNT (*)
                INTO l_count
                FROM cross_dock_data_collect_in c,
                  cross_dock_data_collect_in d
                WHERE d.prod_id = r_item.prod_id
                AND d.erm_id    = r_item.erm_id
                AND d.line_no   = r_item.line_no
                AND d.sys_order_id   = r_item.sys_order_id
                AND c.prod_id   = d.prod_id
                AND c.erm_id    = d.erm_id
                AND c.rec_type  = 'C';
                dbms_output.put_line('after vkal9662 -1 l_count ');
                IF l_count > 0 THEN
                  FOR r_case_rec IN c_case_rec (r_item.prod_id,r_item.sys_order_id, r_item.erm_id, i_rcn_no, i_msg_id )
                  LOOP
                    dbms_output.put_line(' before vkal9662 -1 case insert');
                    /* Create C type records */
                    INSERT
                    INTO cross_dock_data_collect
                      (
                        erm_id,
                        rec_type,
                        line_no,
                        prod_id,
                        qty,
                        catch_wt,
                        catch_wt_unit,
                        uom,
                        parent_pallet_id,
                        interface_type,
                        case_id,
                        cw_type,
                        sys_order_id,
                        order_seq,--vkal9662
                        add_date,
                        add_user,
                        upd_date,
                        upd_user
                      )
                      VALUES
                      (
                        r_case_rec.erm_id,
                        r_case_rec.rec_type,
                        r_case_rec.line_no,
                        r_case_rec.prod_id,
                        decode(r_item.interface_type, 'CMU', null,r_case_rec.qty),
                        r_case_rec.catch_wt,
                        r_case_rec.catch_wt_uom,
                        r_item.uom,
                        r_pallet.parent_pallet_id,
                        r_item.interface_type,
                        r_case_rec.case_id, 
                        r_case_rec.cw_type,
                        r_case_rec.sys_order_id,
                        r_case_rec.order_seq,--vkal9662 -1
                        SYSDATE,
                        USER,
                        SYSDATE,
                        USER
                      );
                    dbms_output.put_line('after vkal9662 -1 case insert');
                  END LOOP;
                  /* End of C Type record creation */
                  /* Mark C type record as processed */
                  UPDATE cross_dock_data_collect_in
                  SET record_status  = 'P',
                    upd_date         = SYSDATE,
                    upd_user         = USER
                  WHERE rec_type     = r_item.rec_type
                  AND erm_id         = r_item.erm_id
                  AND prod_id        = r_item.prod_id
                  AND retail_cust_no = i_rcn_no
                  AND msg_id         = i_msg_id;
                  l_message         := l_object_name || ' Catch weight(C) records created for Pallet id [' || r_pallet.parent_pallet_id || ']' || 'erm_id[' || r_item.erm_id || ']' || 'RCN [' || i_rcn_no || ']';
                  pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, l_message, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
                END IF;
                /* IF l_count > 0 */
                /* Creating 'H' type record */
                IF r_item.erm_id != l_prev_erm_id THEN
                  INSERT
                  INTO cross_dock_data_collect
                    (
                      erm_id,
                      rec_type,
                      area,
                      parent_pallet_id,
                      add_date,
                      add_user,
                      upd_date,
                      upd_user
                    )
                    VALUES
                    (
                      r_item.erm_id,
                      'H',
                      DECODE (r_area.area, 'D', 'C', r_area.area ),
                      r_pallet.parent_pallet_id,
                      SYSDATE,
                      USER,
                      SYSDATE,
                      USER
                    );
                  /* Get the sysco order id and ship date for the PO */
                  /* adding exception block to validate if erm is present in the ERM table */
                  BEGIN
                    SELECT sys_order_id, cross_dock_type -- vkal9662 multipo    
                    INTO l_sys_order_id, l_cross_dock_type
                    FROM erm e
                    WHERE erm_id = r_item.erm_id;
                  EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                    l_message := l_object_name || ' Erm id not found in ERM table[' || r_item.erm_id || ']';
                    pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, l_message, SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
                    RAISE e_null_sys_order_id;
                  END;
                  SELECT DISTINCT ship_date
                  INTO l_ship_date
                  FROM cross_dock_data_collect_in
                  WHERE rec_type     = 'P'
                  AND msg_id         = i_msg_id
                  AND retail_cust_no = i_rcn_no;
                  IF l_sys_order_id IS NULL THEN
                    RAISE e_null_sys_order_id;
                  END IF;
                  IF l_ship_date IS NULL THEN
                    RAISE e_null_ship_date;
                  END IF;
                  /* Insert an entry in cross_dock_pallet_xref for ERM_ID*/
                  IF l_cross_dock_type <> 'MU' then 
                  
                  INSERT  INTO cross_dock_pallet_xref c
                    ( retail_cust_no, erm_id, sys_order_id,
                      parent_pallet_id, ship_date, add_user, add_date)
                  SELECT  i_rcn_no, r_item.erm_id, l_sys_order_id,
                      r_pallet.parent_pallet_id,
                      l_ship_date,
                      USER,
                      SYSDATE
                  FROM dual;

                  INSERT INTO CROSS_DOCK_XREF 
                    ( erm_id,
                      sys_order_id,
                      status,
                      add_date)
                    SELECT r_item.erm_id, l_sys_order_id, 'NEW', SYSDATE
                    FROM dual
		    WHERE not exists (select 1 from cross_dock_xref c 
				      where c.erm_id = r_item.erm_id
				      and   c.sys_order_id = l_sys_order_id);
                  ELSE
                   
                  For po_recs in C_Multi_PO(r_item.erm_id) Loop
                  
                   INSERT  INTO cross_dock_pallet_xref
                    (
                      retail_cust_no,
                      erm_id,
                      sys_order_id,
                      parent_pallet_id,
                      ship_date,
                      add_user,
                      add_date
                    )
                    VALUES
                    (
                      i_rcn_no,
                      po_recs.sn_no,
                      po_recs.po_no,
                      r_pallet.parent_pallet_id,
                      l_ship_date,
                      USER,
                      SYSDATE
                    );
                    
                  INSERT INTO CROSS_DOCK_XREF
                    ( erm_id,
                      sys_order_id,
                      status,
                      add_date)
                    SELECT po_recs.sn_no,
                     po_recs.po_no,
                      'NEW',
                      SYSDATE
                    FROM dual
		    WHERE not exists (select 1 from cross_dock_xref c 
				      where c.erm_id = po_recs.sn_no
				      and   c.sys_order_id = po_recs.po_no);
                   
                  End Loop; --vkal9662 Multi PO
                  END IF;  
                  
                  /* Marking H type record as processed */
                  UPDATE cross_dock_data_collect_in
                  SET record_status  = 'P',
                    upd_date         = SYSDATE,
                    upd_user         = USER
                  WHERE rec_type     = 'H'
                  AND erm_id         = r_item.erm_id
                  AND retail_cust_no = i_rcn_no
                  AND msg_id         = i_msg_id;
                  l_prev_erm_id     := r_item.erm_id;
                  l_message         := l_object_name || ' Header records created for Pallet id [' || r_pallet.parent_pallet_id || ']' || 'erm_id[' || r_item.erm_id || ']';
                  pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, l_message, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
                END IF;
                /* IF r_item.erm_id != l_prev_erm_id */
              END LOOP;
              /* items per pallet loop */
              CLOSE c_item;
            EXCEPTION
            WHEN e_null_sys_order_id THEN
              l_message := l_object_name || ' Cannot insert null sys order id for erm id[' || l_erm_id || ']';
              raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_message || ': ' || SQLERRM );
            WHEN e_null_ship_date THEN
              l_message := l_object_name || ' Cannot insert null ship date for erm id[' || l_erm_id || ']';
              raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_message || ': ' || SQLERRM );
            END;
          END LOOP;
          /* For each pallet in the area */
        END;
        items_remaining   := l_num_items - (l_items_per_pallet * l_num_pallets);
        IF items_remaining = 0 THEN
          l_message       := l_object_name || ' All' || r_area.area || ' items are assigned for customer no[' || i_rcn_no || ']';
          pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, l_message, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
        ELSE
          /* Open the cursors */
          OPEN c_pallet (r_area.area, i_rcn_no, i_msg_id);
          OPEN c_item (r_area.area, i_rcn_no, i_msg_id);
          FOR l_counter IN 1 .. items_remaining
          LOOP
            FETCH c_pallet INTO v_pallet_id;
            EXIT
          WHEN c_pallet%NOTFOUND;
            FETCH c_item INTO r_item;
            EXIT
          WHEN c_item%NOTFOUND;
            /* Creating 'C' type record */
            SELECT COUNT (*)
            INTO l_count
            FROM cross_dock_data_collect_in c,
              cross_dock_data_collect_in d
            WHERE d.prod_id = r_item.prod_id
            AND d.erm_id    = r_item.erm_id
            AND d.line_no   = r_item.line_no
            AND d.sys_order_id = r_item.sys_order_id
            AND c.prod_id   = d.prod_id
            AND c.erm_id    = d.erm_id
            AND c.rec_type  = 'C';
            IF l_count      > 0 THEN
              FOR r_case_rec IN c_case_rec (r_item.prod_id,r_item.sys_order_id, r_item.erm_id, i_rcn_no, i_msg_id )
              LOOP
                /* Create C type records */
                dbms_output.put_line(' before vkal9662 -2 case insert');
                INSERT
                INTO cross_dock_data_collect
                  (
                    erm_id,
                    rec_type,
                    line_no,
                    prod_id,
                    qty,
                    catch_wt,
                    catch_wt_unit,
                    uom,
                    parent_pallet_id,
                    interface_type,
                    case_id, 
                    cw_type,
                    sys_order_id,
                    order_seq,--vkal9662 -2
                    add_date,
                    add_user,
                    upd_date,
                    upd_user
                  )
                  VALUES
                  (
                    r_case_rec.erm_id,
                    r_case_rec.rec_type,
                    r_case_rec.line_no,
                    r_case_rec.prod_id,
                    decode(r_item.interface_type, 'CMU', null,r_case_rec.qty),
                    r_case_rec.catch_wt,
                    r_case_rec.catch_wt_uom,
                    r_item.uom,
                    v_pallet_id,
                    r_item.interface_type,
                    r_case_rec.case_id,
                    r_case_rec.cw_type,
                    r_case_rec.sys_order_id,
                    r_case_rec.order_seq,--vkal9662 -2
                    SYSDATE,
                    USER,
                    SYSDATE,
                    USER
                  );
                dbms_output.put_line(' after vkal9662 -2 case insert');
              END LOOP;
              /* Mark C type record as processed */
              UPDATE cross_dock_data_collect_in
              SET record_status  = 'P',
                upd_date         = SYSDATE,
                upd_user         = USER
              WHERE rec_type     = r_item.rec_type
              AND erm_id         = r_item.erm_id
              AND prod_id        = r_item.prod_id
              AND retail_cust_no = i_rcn_no
              AND msg_id         = i_msg_id;
              l_message         := l_object_name || ' Catch weight(C) records created for Pallet id [' || r_pallet.parent_pallet_id || ']' || 'erm_id[' || r_item.erm_id || ']' || 'RCN [' || i_rcn_no || ']' || 'item[' || r_item.prod_id || ']';
              pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, l_message, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
            END IF;
            /* IF l_count > 0 */
            BEGIN
              SELECT spc,
                split_trk,
                sysco_shelf_life,
                cust_shelf_life,
                mfr_shelf_life,
                mfg_date_trk
              INTO l_spc,
                l_split_trk,
                l_sysco_shelf_life,
                l_cust_shelf_life,
                l_mfr_shelf_life,
                l_mfg_date_trk
              FROM pm
              WHERE prod_id = r_item.prod_id;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
              o_status  := FALSE;
              l_message := l_object_name || ' Item not found in PM table[' || r_item.prod_id || ']';
              pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, l_message, SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
              raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_message || ': ' || SQLERRM );
            END;
            /* Calculate the manufacture date */
            IF l_sysco_shelf_life  <> 0 AND l_cust_shelf_life <> 0 THEN
              l_shelf_life         := l_sysco_shelf_life + l_cust_shelf_life;
            ELSIF l_mfr_shelf_life <> 0 THEN
              l_shelf_life         := l_mfr_shelf_life;
            ELSE
              l_shelf_life := 0;
            END IF;
            /* Creating D type record */
            dbms_output.put_line(' before vkal9662 -3  insert');
            INSERT
            INTO cross_dock_data_collect
              (
                erm_id,
                rec_type,
                line_no,
                prod_id,
                qty,
                uom,
                pallet_id,
                parent_pallet_id,
                exp_date,
                mfg_date,
                master_order_id,
                order_seq,
                carrier_id,
                lot_id,
                interface_type,
                item_seq, 
                sys_order_id,--vkal9662 3
                add_date,
                add_user,
                upd_date,
                upd_user
              )
              VALUES
              (
                r_item.erm_id,
                r_item.rec_type,
                r_item.line_no,
                r_item.prod_id,
                r_item.qty ,
              --  DECODE (r_item.uom, 2, r_item.qty * l_spc, r_item.qty ),
                DECODE (l_split_trk, 'Y', 1, 0), 
                decode(r_item.interface_type, 'CMU',  r_item.pallet_id,pallet_id_seq.NEXTVAL),
                v_pallet_id,
                r_item.exp_date,
                DECODE (l_mfg_date_trk, 'Y', r_item.exp_date - l_shelf_life, NULL ),
                r_item.master_order_id,
                r_item.order_seq,
                r_item.carrier_id,
                r_item.lot_id,
                r_item.interface_type,
                r_item.item_seq, 
                r_item.sys_order_id,--vkal9662
                SYSDATE,
                USER,
                SYSDATE,
                USER
              );
            dbms_output.put_line(' after vkal9662 -3  insert');
            /* Updating the item as processed */
            UPDATE cross_dock_data_collect_in
            SET record_status  = 'P',
              upd_date         = SYSDATE,
              upd_user         = USER
            WHERE rec_type     = r_item.rec_type
            AND erm_id         = r_item.erm_id
            AND prod_id        = r_item.prod_id
            AND sys_order_id   = r_item.sys_order_id
            AND retail_cust_no = i_rcn_no
            AND msg_id         = i_msg_id;
          END LOOP;
          /* Close the cursors */
          CLOSE c_item;
          CLOSE c_pallet;
        END IF;
        /* Marking P type records as processed */
        FOR r_pallet IN c_pallet (r_area.area, i_rcn_no, i_msg_id)
        LOOP
          UPDATE cross_dock_data_collect_in
          SET record_status  = 'P',
            upd_date         = SYSDATE,
            upd_user         = USER
          WHERE rec_type     = 'P'
          AND retail_cust_no = i_rcn_no
          AND msg_id         = i_msg_id
          AND area           = r_area.area;
        END LOOP;
      ELSE
        BEGIN
          SELECT erm_id,
            rec_type,
            line_no,
            prod_id,
            qty,
            uom,
            exp_date,
            retail_cust_no,
            sys_order_id
          INTO l_erm_id,
            l_rec_type,
            l_line_no,
            l_prod_id,
            l_qty,
            l_uom,
            l_exp_date,
            l_retail_cust_no,
            l_sysord_id
          FROM cross_dock_data_collect_in
          WHERE rec_type                    = 'D'
          AND retail_cust_no                = i_rcn_no
          AND msg_id                        = i_msg_id
          AND area                          = r_area.area
         -- AND DECODE (area, 'D', 'C', area) = r_area.area
          AND record_status                 = 'N'
          AND ROWNUM                        = 1
          GROUP BY erm_id,
            rec_type,
            line_no,
            prod_id,
            qty,
            uom,
            exp_date,
            retail_cust_no
          HAVING qty =
            (SELECT MAX (qty)
            FROM cross_dock_data_collect_in
            WHERE rec_type                    = 'D'
            AND retail_cust_no                = i_rcn_no
            AND msg_id                        = i_msg_id
            AND area                          = r_area.area
          --  AND DECODE (area, 'D', 'C', area) = r_area.area
            AND record_status                 = 'N'
            );
          SELECT COUNT (*)
          INTO l_count
          FROM cross_dock_data_collect_in c,
            cross_dock_data_collect_in d
          WHERE d.prod_id = l_prod_id
          AND d.erm_id    = l_erm_id
          AND d.line_no   = l_line_no
          AND c.prod_id   = l_prod_id
          AND d.sys_order_id = r_item.sys_order_id
          AND c.erm_id    = d.erm_id
          AND c.rec_type  = 'C';
          IF l_count      > 0 THEN
            FOR r_case_rec IN c_case_rec (l_prod_id,l_sysord_id, l_erm_id, i_rcn_no, i_msg_id )
            LOOP
              /* Creating C type record */
              dbms_output.put_line(' before vkal9662 -4 case insert');
              INSERT
              INTO cross_dock_data_collect
                (
                  erm_id,
                  rec_type,
                  line_no,
                  prod_id,
                  qty,
                  catch_wt,
                  catch_wt_unit,
                  uom,
                  parent_pallet_id,
                  interface_type,
                  case_id,
                  cw_type,
                  sys_order_id,
                  order_seq,--vkal9662
                  add_date,
                  add_user,
                  upd_date,
                  upd_user
                )
                VALUES
                (
                  r_case_rec.erm_id,
                  r_case_rec.rec_type,
                  r_case_rec.line_no,
                  r_case_rec.prod_id,
                  decode(r_item.interface_type, 'CMU', null,r_case_rec.qty),
                  r_case_rec.catch_wt,
                  r_case_rec.catch_wt_uom,
                  r_item.uom,
                  r_pallet.parent_pallet_id,
                  r_item.interface_type,
                  r_case_rec.case_id,
                  r_case_rec.cw_type,
                  r_case_rec.sys_order_id,
                  r_case_rec.order_seq,--vkal9662 4
                  SYSDATE,
                  USER,
                  SYSDATE,
                  USER
                );
              dbms_output.put_line(' after vkal9662 -4 case insert');
            END LOOP;
            /* Marking C type record as processed */
            UPDATE cross_dock_data_collect_in
            SET record_status  = 'P',
              upd_date         = SYSDATE,
              upd_user         = USER
            WHERE rec_type     = l_rec_type
            AND erm_id         = l_erm_id
            AND prod_id        = l_prod_id
            AND retail_cust_no = i_rcn_no
            AND msg_id         = i_msg_id;
          END IF;
          /* IF l_count > 0 */
          l_pallet := l_num_pallets - (l_num_items - 1);
          OPEN c_pallet (r_area.area, i_rcn_no, i_msg_id);
          l_qty_remaining  := l_qty;
          l_qty_per_pallet := FLOOR (l_qty / l_pallet);
          FOR l_counter                   IN 1 .. l_pallet
          LOOP
            FETCH c_pallet INTO v_pallet_id;
            EXIT
          WHEN c_pallet%NOTFOUND;
            IF l_counter        = l_pallet THEN
              l_qty_per_pallet := l_qty_remaining;
            END IF;
            BEGIN
              /* Get the SPC for the item */
              SELECT spc,
                split_trk,
                sysco_shelf_life,
                cust_shelf_life,
                mfr_shelf_life,
                mfg_date_trk
              INTO l_spc,
                l_split_trk,
                l_sysco_shelf_life,
                l_cust_shelf_life,
                l_mfr_shelf_life,
                l_mfg_date_trk
              FROM pm
              WHERE prod_id = l_prod_id;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
              o_status  := FALSE;
              l_message := l_object_name || ' Item not found in PM table[' || l_prod_id || ']';
              pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, l_message, SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
              raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_message || ': ' || SQLERRM );
            END;
            /* Calculate the manufacture date */
            IF l_sysco_shelf_life  <> 0 AND l_cust_shelf_life <> 0 THEN
              l_shelf_life         := l_sysco_shelf_life + l_cust_shelf_life;
            ELSIF l_mfr_shelf_life <> 0 THEN
              l_shelf_life         := l_mfr_shelf_life;
            ELSE
              l_shelf_life := 0;
            END IF;
            /* Creating D type record */
            dbms_output.put_line(' before vkal9662 -5  insert');
            INSERT
            INTO cross_dock_data_collect
              (
                erm_id,
                rec_type,
                line_no,
                prod_id,
                qty,
                uom,
                pallet_id,
                parent_pallet_id,
                exp_date,
                mfg_date,
                master_order_id,
                order_seq,
                carrier_id,
                lot_id,
                interface_type,
                item_seq, 
                sys_order_id,--vkal9662 5
                add_date,
                add_user,
                upd_date,
                upd_user
              )
              VALUES
              (
                l_erm_id,
                l_rec_type,
                l_line_no,
                l_prod_id,
                r_item.qty ,
           --     DECODE (l_uom,2, l_qty_per_pallet * l_spc,l_qty_per_pallet),
                DECODE (l_split_trk, 'Y', 1, 0),
                decode(r_item.interface_type, 'CMU',  r_item.pallet_id,pallet_id_seq.NEXTVAL),
                v_pallet_id,
                l_exp_date,
                DECODE (l_mfg_date_trk, 'Y', l_exp_date - l_shelf_life, NULL ),
                r_item.master_order_id,
                r_item.order_seq,
                r_item.carrier_id,
                r_item.lot_id,
                r_item.interface_type,
                r_item.item_seq, 
                r_item.sys_order_id,--vkal9662
                SYSDATE,
                USER,
                SYSDATE,
                USER
              );
            dbms_output.put_line(' after vkal9662 -5  insert');
            l_qty_remaining := l_qty_remaining - l_qty_per_pallet;
            /* Creating H type record */
            INSERT
            INTO cross_dock_data_collect
              (
                erm_id,
                rec_type,
                area,
                parent_pallet_id,
                add_date,
                add_user,
                upd_date,
                upd_user
              )
              VALUES
              (
                l_erm_id,
                'H',
                r_area.area,
                v_pallet_id,
                SYSDATE,
                USER,
                SYSDATE,
                USER
              );
            BEGIN
              SELECT sys_order_id , cross_dock_type --vkal9662 Multi
              INTO l_sys_order_id , l_cross_dock_type
              FROM erm e 
              WHERE erm_id = l_erm_id;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
              l_message := l_object_name || ' Erm id not found in ERM table[' || l_erm_id || ']';
              pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, l_message, SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
              RAISE e_null_sys_order_id;
            END;
            SELECT DISTINCT ship_date
            INTO l_ship_date
            FROM cross_dock_data_collect_in
            WHERE rec_type     = 'P'
            AND msg_id         = i_msg_id
            AND retail_cust_no = i_rcn_no;
            IF l_sys_order_id IS NULL THEN
              RAISE e_null_sys_order_id;
            END IF;
            IF l_ship_date IS NULL THEN
              RAISE e_null_ship_date;
            END IF;
            /* Insert an entry in cross_dock_pallet_xref for ERM_ID*/
            
            IF l_cross_dock_type <> 'MU' Then
            
            INSERT
            INTO cross_dock_pallet_xref
              (
                retail_cust_no,
                erm_id,
                sys_order_id,
                parent_pallet_id,
                ship_date,
                add_user,
                add_date
              )
              VALUES
              (
                l_retail_cust_no,
                l_erm_id,
                l_sys_order_id,
                v_pallet_id,
                l_ship_date,
                USER,
                SYSDATE
              );
            INSERT
            INTO CROSS_DOCK_XREF
              ( erm_id, sys_order_id, status, add_date)
              SELECT  l_erm_id, l_sys_order_id, 'NEW', SYSDATE
	      FROM dual
              WHERE not exists (select 1 from cross_dock_xref c 
				where c.erm_id = l_erm_id 
				and   c.sys_order_id = l_sys_order_id);
              
            Else -- multi PO
            
             For po_recs in C_Multi_PO(r_item.erm_id) Loop
                  
                   INSERT  INTO cross_dock_pallet_xref
                    (
                      retail_cust_no,
                      erm_id,
                      sys_order_id,
                      parent_pallet_id,
                      ship_date,
                      add_user,
                      add_date
                    )
                    VALUES
                    (
                      i_rcn_no,
                      po_recs.sn_no,
                      po_recs.po_no,
                      r_pallet.parent_pallet_id,
                      l_ship_date,
                      USER,
                      SYSDATE
                    );
                    
                  INSERT INTO CROSS_DOCK_XREF
                    (erm_id, sys_order_id, status, add_date)
                    SELECT po_recs.sn_no, po_recs.po_no, 'NEW', SYSDATE
	          FROM dual
                  WHERE not exists (select 1 from cross_dock_xref c 
				where c.erm_id = po_recs.sn_no
				and   c.sys_order_id = po_recs.po_no);
                   
         End Loop; --vkal9662 Multi PO
              
         End If;  
            /* marking P type record as processed */
            UPDATE cross_dock_data_collect_in
            SET record_status    = 'P',
              upd_date           = SYSDATE,
              upd_user           = USER
            WHERE rec_type       = 'P'
            AND retail_cust_no   = i_rcn_no
            AND parent_pallet_id = v_pallet_id
            AND msg_id           = i_msg_id;
          END LOOP;
          /* For each pallet */
          CLOSE c_pallet;
          /* marking D type record as processed */
          UPDATE cross_dock_data_collect_in
          SET record_status  = 'P',
            upd_date         = SYSDATE,
            upd_user         = USER
          WHERE rec_type     = l_rec_type
          AND prod_id        = l_prod_id
          AND retail_cust_no = l_retail_cust_no
          AND erm_id         = l_erm_id
          AND line_no        = l_line_no
          AND msg_id         = i_msg_id;
        EXCEPTION
        WHEN e_null_sys_order_id THEN
          l_message := l_object_name || ' Cannot insert null sys order id for erm id[' || l_erm_id || ']';
          raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_message || ': ' || SQLERRM );
        WHEN e_null_ship_date THEN
          l_message := l_object_name || ' Cannot insert null ship date for erm id[' || l_erm_id || ']';
          raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_message || ': ' || SQLERRM );
        END;
        BEGIN
          OPEN c_pallet (r_area.area, i_rcn_no, i_msg_id);
          OPEN c_item (r_area.area, i_rcn_no, i_msg_id);
          FOR l_counter IN 1 .. l_num_items - 1
          LOOP
            FETCH c_pallet INTO v_pallet_id;
            EXIT
          WHEN c_pallet%NOTFOUND;
            FETCH c_item INTO r_item;
            EXIT
          WHEN c_item%NOTFOUND;
            /* Check if the fetched item is Catch weight tracked and insert C records */
            /* Creating 'C' type record */
            SELECT COUNT (*)
            INTO l_count
            FROM cross_dock_data_collect_in c,
              cross_dock_data_collect_in d
            WHERE d.prod_id = r_item.prod_id
            AND d.erm_id    = r_item.erm_id
            AND d.line_no   = r_item.line_no
            AND d.sys_order_id = r_item.sys_order_id
            AND c.prod_id   = d.prod_id
            AND c.erm_id    = d.erm_id
            AND c.rec_type  = 'C';
            IF l_count      > 0 THEN
              FOR r_case_rec IN c_case_rec (r_item.prod_id,r_item.sys_order_id, r_item.erm_id, i_rcn_no, i_msg_id )
              LOOP
                /* Create C type records */
                dbms_output.put_line(' before vkal9662 -6 case insert');
                INSERT
                INTO cross_dock_data_collect
                  (
                    erm_id,
                    rec_type,
                    line_no,
                    prod_id,
                    qty,
                    catch_wt,
                    catch_wt_unit,
                    uom,
                    parent_pallet_id,
                    interface_type,
                    case_id,
                    cw_type,
                    sys_order_id,
                    order_seq,--vkal9662 6
                    add_date,
                    add_user,
                    upd_date,
                    upd_user
                  )
                  VALUES
                  (
                    r_case_rec.erm_id,
                    r_case_rec.rec_type,
                    r_case_rec.line_no,
                    r_case_rec.prod_id,
                    decode(r_item.interface_type, 'CMU', null,r_case_rec.qty),
                    r_case_rec.catch_wt,
                    r_case_rec.catch_wt_uom,
                    r_item.uom,
                    v_pallet_id,
                    r_item.interface_type,
                    r_case_rec.case_id,
                    r_case_rec.cw_type,
                    r_case_rec.sys_order_id,
                    r_case_rec.order_seq,--vkal9662
                    SYSDATE,
                    USER,
                    SYSDATE,
                    USER
                  );
                dbms_output.put_line(' after vkal9662 -6 case insert');
              END LOOP;
              /* Mark C type record as processed */
              UPDATE cross_dock_data_collect_in
              SET record_status  = 'P',
                upd_date         = SYSDATE,
                upd_user         = USER
              WHERE rec_type     = r_item.rec_type
              AND erm_id         = r_item.erm_id
              AND prod_id        = r_item.prod_id
              AND retail_cust_no = i_rcn_no
              AND msg_id         = i_msg_id;
              l_message         := l_object_name || ' Catch weight(C) records created for Pallet id [' || v_pallet_id || ']' || 'erm_id[' || r_item.erm_id || ']' || 'RCN[ ' || i_rcn_no || ']' || 'item[' || r_item.prod_id || ']';
              pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, l_message, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
            END IF;
            /* IF l_count > 0 */
            /* Get the SPC for the item */
            BEGIN
              SELECT spc,
                split_trk,
                sysco_shelf_life,
                cust_shelf_life,
                mfr_shelf_life,
                mfg_date_trk
              INTO l_spc,
                l_split_trk,
                l_sysco_shelf_life,
                l_cust_shelf_life,
                l_mfr_shelf_life,
                l_mfg_date_trk
              FROM pm
              WHERE prod_id = r_item.prod_id;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
              o_status  := FALSE;
              l_message := l_object_name || ' Item not found in PM table[' || r_item.prod_id || ']';
              pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, l_message, SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
              raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_message || ': ' || SQLERRM );
            END;
            /* Calculate the manufacture date */
            IF l_sysco_shelf_life  <> 0 AND l_cust_shelf_life <> 0 THEN
              l_shelf_life         := l_sysco_shelf_life + l_cust_shelf_life;
            ELSIF l_mfr_shelf_life <> 0 THEN
              l_shelf_life         := l_mfr_shelf_life;
            ELSE
              l_shelf_life := 0;
            END IF;
            dbms_output.put_line(' before vkal9662 -7 insert');
            /* Creating D type record */
            INSERT
            INTO cross_dock_data_collect
              (
                erm_id,
                rec_type,
                line_no,
                prod_id,
                qty,
                uom,
                pallet_id,
                parent_pallet_id,
                exp_date,
                mfg_date,
                master_order_id,
                order_seq,
                carrier_id,
                lot_id,
                interface_type,
                item_seq, 
                sys_order_id,--vkal9662 7
                add_date,
                add_user,
                upd_date,
                upd_user
              )
              VALUES
              (
                r_item.erm_id,
                r_item.rec_type,
                r_item.line_no,
                r_item.prod_id,
                r_item.qty ,
           --     DECODE (r_item.uom, 2, r_item.qty * l_spc, r_item.qty ),
                DECODE (l_split_trk, 'Y', 1, 0),
                decode(r_item.interface_type, 'CMU',  r_item.pallet_id,pallet_id_seq.NEXTVAL),
                v_pallet_id,
                r_item.exp_date,
                DECODE (l_mfg_date_trk, 'Y', r_item.exp_date - l_shelf_life, NULL ),
                r_item.master_order_id,
                r_item.order_seq,
                r_item.carrier_id,
                r_item.lot_id,
                r_item.interface_type,
                r_item.item_seq,
                r_item.sys_order_id,--vkal9662
                SYSDATE,
                USER,
                SYSDATE,
                USER
              );
            dbms_output.put_line(' after vkal9662 -7 insert');
            /* Creating H type record */
            INSERT
            INTO cross_dock_data_collect
              (
                erm_id,
                rec_type,
                area,
                parent_pallet_id,
                interface_type,
                add_date,
                add_user,
                upd_date,
                upd_user
              )
              VALUES
              (
                r_item.erm_id,
                'H',
                r_area.area,
                --DECODE (r_area.area, 'D', 'C', r_area.area),
                v_pallet_id,
                r_item.interface_type,
                SYSDATE,
                USER,
                SYSDATE,
                USER
              );
            BEGIN
              SELECT sys_order_id, cross_dock_type -- vkal9662 multipo    
              INTO l_sys_order_id, l_cross_dock_type
              FROM erm e
              WHERE erm_id = r_item.erm_id;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
              l_message := l_object_name || ' Erm id not found in ERM table[' || r_item.erm_id || ']';
              pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, l_message, SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
              RAISE e_null_sys_order_id;
            END;
            SELECT DISTINCT ship_date
            INTO l_ship_date
            FROM cross_dock_data_collect_in
            WHERE rec_type     = 'P'
            AND msg_id         = i_msg_id
            AND retail_cust_no = i_rcn_no;
            IF l_sys_order_id IS NULL THEN
              RAISE e_null_sys_order_id;
            END IF;
            IF l_ship_date IS NULL THEN
              RAISE e_null_ship_date;
            END IF;
            /* Insert an entry in cross_dock_pallet_xref for ERM_ID*/
            If l_cross_dock_type <> 'MU' then -- vkal9662 multipo            
        
            INSERT
            INTO cross_dock_pallet_xref
              (
                retail_cust_no,
                erm_id,
                sys_order_id,
                parent_pallet_id,
                ship_date,
                add_user,
                add_date
              )
              VALUES
              (
                i_rcn_no,
                r_item.erm_id,
                l_sys_order_id,
                v_pallet_id,
                l_ship_date,
                USER,
                SYSDATE
              );
            INSERT INTO CROSS_DOCK_XREF
              ( erm_id, sys_order_id, status, add_date)
              SELECT  r_item.erm_id, l_sys_order_id, 'NEW', SYSDATE
	      FROM dual 
	      WHERE not exists (select 1 from cross_dock_xref c 
					  where c.erm_id = r_item.erm_id 
					  and   c.sys_order_id = l_sys_order_id); --knha8378 add to not cause duplication
          Else   
          
              For po_recs in C_Multi_PO(r_item.erm_id) Loop
                  
                   INSERT  INTO cross_dock_pallet_xref
                    (
                      retail_cust_no,
                      erm_id,
                      sys_order_id,
                      parent_pallet_id,
                      ship_date,
                      add_user,
                      add_date
                    )
                    VALUES
                    (
                      i_rcn_no,
                      po_recs.sn_no,
                      po_recs.po_no,
                      r_pallet.parent_pallet_id,
                      l_ship_date,
                      USER,
                      SYSDATE
                    );
                    
                   INSERT  INTO CROSS_DOCK_XREF
                    ( erm_id, sys_order_id, status, add_date )
                    SELECT po_recs.sn_no, po_recs.po_no, 'NEW', SYSDATE 
	            FROM dual 
	            WHERE not exists (select 1 from cross_dock_xref c 
					  where c.erm_id = po_recs.sn_no
					  and   c.sys_order_id = po_recs.po_no); --knha8378 add to not cause duplication
                   
                  End Loop; --vkal9662 Multi PO
          
          
          End if; 
            /* updating the pallet as processed */
            UPDATE cross_dock_data_collect_in
            SET record_status    = 'P',
              upd_date           = SYSDATE,
              upd_user           = USER
            WHERE rec_type       = 'P'
            AND retail_cust_no   = i_rcn_no
            AND parent_pallet_id = v_pallet_id
            AND msg_id           = i_msg_id;
            /* Updating the item as processed */
            UPDATE cross_dock_data_collect_in
            SET record_status  = 'P',
              upd_date         = SYSDATE,
              upd_user         = USER
            WHERE rec_type     = r_item.rec_type
            AND prod_id        = r_item.prod_id
            AND sys_order_id   = r_item.sys_order_id
            AND retail_cust_no = i_rcn_no
            AND erm_id         = r_item.erm_id
            AND msg_id         = i_msg_id;
          END LOOP;
          /* FOR l_counter IN 1 .. l_num_items - 1 */
          /* Marking H type record as processed */
          UPDATE cross_dock_data_collect_in
          SET record_status  = 'P',
            upd_date         = SYSDATE,
            upd_user         = USER
          WHERE rec_type     = 'H'
          AND erm_id         = r_item.erm_id
          AND retail_cust_no = i_rcn_no
          AND msg_id         = i_msg_id;
          /* Close the cursors */
          CLOSE c_pallet;
        EXCEPTION
        WHEN e_null_sys_order_id THEN
          l_message := l_object_name || ' Cannot insert null sys order id for erm id[' || r_item.erm_id || ']';
          raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_message || ': ' || SQLERRM );
        WHEN e_null_ship_date THEN
          l_message := l_object_name || ' Cannot insert null ship date for erm id[' || r_item.erm_id || ']';
          raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_message || ': ' || SQLERRM );
        END;
        /* Closing the cursor here as we use the value in above exception block */
        CLOSE c_item;
      END IF;
      l_message := l_object_name || r_area.area || ' items for rcn[' || i_rcn_no || ']' || 'are processed and assigned pallets';
      pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, l_message, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    EXCEPTION
    WHEN e_null_pallet THEN
      l_message := l_object_name || ' Pallet  cannot be null or zero count for [' || r_area.area || ']' || 'area for rcn no[' || i_rcn_no || ']';
      raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_message || ': ' || SQLERRM );
      o_status := FALSE;
    WHEN e_null_item THEN
      l_message := l_object_name || ' Item  cannot be null or zero count for [' || r_area.area || ']' || 'area for rcn no[' || i_rcn_no || ']';
      raise_application_error (pl_exc.ct_data_error, gl_pkg_name || '.' || l_message || ': ' || SQLERRM );
      o_status := FALSE;
    END;
    /* Updating 'H' type and 'P' type record as processed */
    UPDATE cross_dock_data_collect_in
    SET record_status  = 'P',
      upd_date         = SYSDATE,
      upd_user         = USER
    WHERE rec_type     = 'H'
    AND retail_cust_no = i_rcn_no
    AND msg_id         = i_msg_id;
    UPDATE cross_dock_data_collect_in
    SET record_status  = 'P',
      upd_date         = SYSDATE,
      upd_user         = USER
    WHERE rec_type     = 'P'
    AND retail_cust_no = i_rcn_no
    AND area           = r_area.area
    AND msg_id         = i_msg_id;
    --- po level validation for checking data collect - update data collect -
  END LOOP; -- loop for c_area
  /* Update the output flag to true when the Entire message for RCN has completed successfully */
  o_status := TRUE;
EXCEPTION
WHEN OTHERS THEN
  o_status  := FALSE;
  l_message := l_object_name || ' Data Upload Failed for rcn:[' || i_rcn_no || ']';
  pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, l_message || SQLCODE || SQLERRM, SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
END upload_cdk_for_msg_id;
---------------------------------------------------------------------------
-- Function:
--    f_is_crossdock_pallet
--
-- Description:
--    This function checks whether PO/Pallet in argument is a Cross Dock EI or not
--    return Y for true and N for False
-- Parameters:
--    i_id      --> This can be ERM ID or Pallet ID
--    i_type    --> This determines whether argument 1 is PO or Pallet
---------------------------------------------------------------------------
FUNCTION f_is_crossdock_pallet(
    i_id   IN VARCHAR,
    i_type IN CHAR)
  RETURN CHAR
IS
  l_ret_val CHAR;
  l_count   NUMBER (2);
BEGIN
  CASE i_type
    /* when an erm id is passed as an argument, check if it is cross dock PO */
  WHEN 'E' THEN
    SELECT COUNT (1)
    INTO l_count
    FROM erm e,
      cross_dock_type cdt
    WHERE e.erm_id               = i_id
    AND e.cross_dock_type        = cdt.cross_dock_type
    AND cdt.receive_whole_pallet = 'Y';
    /* when an pallet id is passed as an argument, check if it is cross dock Pallet */
  WHEN 'P' THEN
    SELECT COUNT (1)
    INTO l_count
    FROM erm e,
      cross_dock_type cdt,
      putawaylst p
    WHERE e.erm_id               = p.rec_id
    AND e.cross_dock_type        = cdt.cross_dock_type
    AND p.parent_pallet_id       = i_id
    AND p.inv_status             = 'CDK'
    AND cdt.receive_whole_pallet = 'Y';
  END CASE;
  IF l_count   > 0 THEN
    l_ret_val := 'Y';
  ELSE
    l_ret_val := 'N';
  END IF;
  RETURN l_ret_val;
END;
---------------------------------------------------------------------------
-- Function:
--     f_validate_erd_cdk_qty
--
-- Description:
--    This function checks whether for a PO, qty is in sync between
--      ERD and CROSS_DOCK_DATA_COLLECT
-- Parameters:
--    i_id      --> This will be ERM ID
---------------------------------------------------------------------------
FUNCTION f_validate_erd_cdk_qty(
    i_id IN VARCHAR)
  RETURN BOOLEAN
IS
  l_cdk_qty erd.qty%TYPE;
  l_erd_qty erd.qty%TYPE;
BEGIN
  /* Retrieve the ERD quantity for the PO */
  SELECT SUM (qty)
  INTO l_erd_qty
  FROM erd
  WHERE erm_id = i_id;
  /* Retrieve the CDK quantity for the PO */
  SELECT SUM (qty)
  INTO l_cdk_qty
  FROM cross_dock_data_collect
  WHERE erm_id = i_id
  AND rec_type = 'D';
  /*  If the quantities do not match, we do not allow the user to open the PO */
  IF l_erd_qty <> l_cdk_qty THEN
    RETURN FALSE;
  ELSE
    RETURN TRUE;
  END IF;
END;
---------------------------------------------------------------------------
-- Procedure:
--   update_cross_dock_data_collect
--
-- Description:
--      This SP will update the data collect flags across all
--          the tables and keep them in Sync
-- Parameters:
--    i_erm_id      --> This will be ERM ID
---------------------------------------------------------------------------
PROCEDURE update_cross_dock_data_collect(
    i_erm_id IN erd.erm_id%TYPE)
IS
  l_message               VARCHAR2 (512); -- Message buffer
  l_object_name           VARCHAR2 (30) := 'UPDATE_CROSS_DOCK_DATA_COLLECT';
  l_cross_dock_data_count NUMBER        := 0;
  l_qty                   NUMBER        := 0;
  l_trk_count             NUMBER        := 0;
  l_data_count            NUMBER        := 0;
  l_clam_flg              CHAR (1)      := 'N';
  l_cool_flg              CHAR (1)      := 'N';
  l_country_flg           CHAR (1)      := 'N';
  l_case_flg              CHAR (1)      := 'N';
  b_validate_qty          BOOLEAN       := FALSE;
  CURSOR c_cross_dock_data_rec
  IS
    SELECT prod_id,
      qty,
      temp,
      exp_date,
      mfg_date,
      catch_wt,
      clam_bed_no,
      country_of_origin
    FROM cross_dock_data_collect
    WHERE erm_id = i_erm_id
    AND rec_type = 'D';
  r_cross_dock_data_rec c_cross_dock_data_rec%ROWTYPE;
  CURSOR c_pm_rec
  IS
    SELECT prod_id,
      hazardous,
      temp_trk,
      exp_date_trk,
      mfg_date_trk,
      catch_wt_trk,
      spc
    FROM pm
    WHERE prod_id = r_cross_dock_data_rec.prod_id;
  r_pm_rec c_pm_rec%ROWTYPE;
BEGIN
  OPEN c_cross_dock_data_rec;
  LOOP
    FETCH c_cross_dock_data_rec INTO r_cross_dock_data_rec;
    EXIT
  WHEN c_cross_dock_data_rec%NOTFOUND;
    l_cross_dock_data_count := c_cross_dock_data_rec%ROWCOUNT;
    OPEN c_pm_rec;
    LOOP
      FETCH c_pm_rec INTO r_pm_rec;
      EXIT
    WHEN c_pm_rec%NOTFOUND;
      IF (r_pm_rec.hazardous IS NOT NULL) THEN
        BEGIN
          SELECT h.clambed_trk,
            h.cool_trk
          INTO l_clam_flg,
            l_cool_flg
          FROM haccp_codes h
          WHERE h.haccp_code = r_pm_rec.hazardous;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_message := l_object_name || ' NO DATA FOUND IN HACCP_CODES FOR ITEM:[' || r_pm_rec.prod_id || ']';
          pl_log.ins_msg (pl_lmc.ct_warn_msg, l_object_name, l_message, SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
        END;
      END IF;
      IF (r_pm_rec.catch_wt_trk = 'Y') THEN
        SELECT COUNT (*)
        INTO l_qty
        FROM cross_dock_data_collect c
        WHERE erm_id  = i_erm_id
        AND prod_id   = r_cross_dock_data_rec.prod_id
        AND rec_type  = 'C';
        IF (l_qty     = r_cross_dock_data_rec.qty / r_pm_rec.spc) THEN
          l_case_flg := 'Y';
        ELSE
          l_case_flg := 'N';
        END IF;
      END IF;
      /* 1 TEMPERATURE track validation */
      IF (r_pm_rec.temp_trk             = 'Y') THEN
        l_trk_count                    := l_trk_count + 1;
        IF (r_cross_dock_data_rec.temp IS NOT NULL) THEN
          l_data_count                 := l_data_count + 1;
        END IF;
      END IF;
      /* 1 TEMPERATURE track validation */
      /* 2 EXPIRY DATE track validation */
      IF (r_pm_rec.exp_date_trk             = 'Y') THEN
        l_trk_count                        := l_trk_count + 1;
        IF (r_cross_dock_data_rec.exp_date IS NOT NULL) THEN
          l_data_count                     := l_data_count + 1;
        END IF;
      END IF;
      /* 2 EXPIRY DATE track validation */
      /* 3 CATCH WEIGHT track validation */
      IF (r_pm_rec.catch_wt_trk = 'Y') THEN
        l_trk_count            := l_trk_count + 1;
        IF (l_case_flg          = 'Y') THEN
          l_data_count         := l_data_count + 1;
        END IF;
      END IF;
      /* 3 CATCH WEIGHT track validation */
      /* 4 MANUFACTURE DATE track validation */
      IF (r_pm_rec.mfg_date_trk             = 'Y') THEN
        l_trk_count                        := l_trk_count + 1;
        IF (r_cross_dock_data_rec.mfg_date IS NOT NULL) THEN
          l_data_count                     := l_data_count + 1;
        END IF;
      END IF;
      /* 4 MANUFACTURE DATE track validation */
      /* 5 CLAM BED track validation */
      IF (l_clam_flg                           = 'Y') THEN
        l_trk_count                           := l_trk_count + 1;
        IF (r_cross_dock_data_rec.clam_bed_no IS NOT NULL) THEN
          l_data_count                        := l_data_count + 1;
        END IF;
      END IF;
      /* 5 CLAM BED track validation */
      /* 6 COUNTRY OF ORIGIN track validation */
      IF (l_cool_flg                                 = 'Y') THEN
        l_trk_count                                 := l_trk_count + 1;
        IF (r_cross_dock_data_rec.country_of_origin IS NOT NULL) THEN
          l_data_count                              := l_data_count + 1;
        END IF;
      END IF;
      /* 6 COUNTRY OF ORIGIN track validation */
      UPDATE cross_dock_data_collect
      SET data_collect = (
        CASE
          WHEN (l_trk_count > 0
          AND l_data_count  = 0)
          THEN 'Y'
          WHEN (l_trk_count = 0
          AND l_data_count  = 0)
          THEN 'N'
          WHEN ( (l_trk_count > 0
          AND l_data_count    > 0)
          AND (l_trk_count    = l_data_count) )
          THEN 'C'
          WHEN ( (l_trk_count > 0
          AND l_data_count    > 0)
          AND (l_trk_count    > l_data_count) )
          THEN 'P'
        END )
      WHERE prod_id = r_pm_rec.prod_id
      AND erm_id    = i_erm_id
      AND rec_type  = 'D';
      l_message    := l_object_name || ' Updated data_collect flag in cross_dock_data_collect table for ERM [ ' || i_erm_id || '] PROD ID [' || r_pm_rec.prod_id ||']';
      pl_log.ins_msg (pl_lmc.ct_warn_msg, l_object_name, l_message, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
    END LOOP;
    CLOSE c_pm_rec;
  END LOOP;
  CLOSE c_cross_dock_data_rec;
  UPDATE erm
  SET data_collect = (
    CASE
      WHEN l_cross_dock_data_count =
        (SELECT COUNT (1)
        FROM cross_dock_data_collect
        WHERE erm_id     = i_erm_id
        AND rec_type     = 'D'
        AND data_collect = 'N'
        )
      THEN 'N'
      WHEN l_cross_dock_data_count =
        (SELECT COUNT (1)
        FROM cross_dock_data_collect
        WHERE erm_id      = i_erm_id
        AND rec_type      = 'D'
        AND data_collect IN ('Y', 'N')
        )
      THEN 'Y'
      WHEN l_cross_dock_data_count =
        (SELECT COUNT (1)
        FROM cross_dock_data_collect
        WHERE erm_id      = i_erm_id
        AND rec_type      = 'D'
        AND data_collect IN ('C', 'N')
        )
      THEN 'C'
      ELSE 'P'
    END )
  WHERE erm_id = i_erm_id;
  l_message   := l_object_name || ' Updated data_collect flag in ERM table for ERM [' || i_erm_id || ']';
  pl_log.ins_msg (pl_lmc.ct_warn_msg, l_object_name, l_message, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
  b_validate_qty := pl_rcv_cross_dock.f_validate_erd_cdk_qty (i_erm_id);
  /* update cross dock reference table for PO to have incomplete or
  complete status based on data collected level
  if data_collect in C or N (Complete or Not required) - then NEW
  else data_collect is Y or P (incomplete) - then INC*/
  IF b_validate_qty THEN
    /* Quantity is valid, proceed with data collect check */
    UPDATE cross_dock_xref
    SET status = (
      CASE
        WHEN EXISTS
          ( SELECT 1 FROM erm WHERE erm_id = i_erm_id AND data_collect IN ('C', 'N')
          )
        THEN 'NEW'
        ELSE 'INC'
      END )
    WHERE erm_id = i_erm_id;
  ELSE
    /* Quantity is INvalid, data collect check not required */
    UPDATE cross_dock_xref
    SET status   = 'INC'
    WHERE erm_id = i_erm_id;
    l_message   := l_object_name || ' QUANTITY MISMATCH B/W ERD AND CROSS_DOCK_DATA_COLLECT.MARKING CROSS_DOCK_XREF STATUS AS INC FOR ERM_ID[' || i_erm_id || ']';
    pl_log.ins_msg (pl_lmc.ct_warn_msg, l_object_name, l_message, NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );
  END IF;
END update_cross_dock_data_collect;
-----------------------------------------------------------------------------
-- Procedure lock_po
--   Lock all of the Master PO records (main and extended) for this PO until
--   we are done processing the close request.
-----------------------------------------------------------------------------
PROCEDURE lock_po(
    i_rec_id IN VARCHAR2)
IS
BEGIN
  IF NOT c_po_lock%ISOPEN THEN
    OPEN c_po_lock (i_rec_id);
  END IF;
  BEGIN
    SELECT config_flag_val
    INTO gv_osd_sys_flag
    FROM sys_config
    WHERE config_flag_name = 'OSD_REASON_CODE';
  EXCEPTION
  WHEN OTHERS THEN
    g_sqlcode := SQLCODE;
    g_err_msg := 'ORACLE Unable to get OSD reason code syspar from sys_config.';
    pl_text_log.ins_msg ('WARN', ct_program_code, g_err_msg, SQLCODE, SQLERRM );
    g_server.status := ct_select_error;
    RAISE e_premature_termination;
  END;
EXCEPTION
WHEN e_po_locked THEN
  g_sqlcode := -54;
  g_err_msg := 'ORACLE SN/PO ' || i_rec_id || ' locked by another user.';
  pl_text_log.ins_msg ('WARN', ct_program_code, g_err_msg, -54, SQLERRM );
  g_server.status := ct_locked_po;
  RAISE e_premature_termination;
WHEN OTHERS THEN
  g_sqlcode := SQLCODE;
  g_err_msg := 'ORACLE Unable to lock SN/PO ' || i_rec_id || '.';
  pl_text_log.ins_msg ('WARN', ct_program_code, g_err_msg, SQLCODE, SQLERRM );
  g_server.status := ct_inv_po;
  RAISE e_premature_termination;
END lock_po;


PROCEDURE Split_CMU_SN(p_sn_no IN VARCHAR2 )
IS
  l_count        NUMBER;
  l_cmu_count    NUMBER;
  extd_erm_id    VARCHAR2(20);
  l_no_pallets   NUMBER;
  l_no_cases     NUMBER;
  l_po_no        VARCHAR2(20);
  l_sys_order_id NUMBER;
  l_message      VARCHAR2(250);
  l_stage        VARCHAR2(250);
  l_count_Hold   NUMBER;
  l_cmu_sn_no    erd_lpn.sn_no%TYPE;
  l_object_name  varchar2(30) := 'Split_CMU_SN';

  
  cursor c_mlti_po(p_extd_erm_id varchar2) is
  SELECT distinct po_no
  FROM erd_lpn
  WHERE 1=1
  AND sn_no = p_extd_erm_id;
  
BEGIN

  SELECT COUNT(*),  COUNT(CMU_INDICATOR)
  INTO l_count, l_cmu_count
  FROM erd_lpn
  WHERE sn_no = p_sn_no;
  
 
  
 IF   l_cmu_count>0 then  
 
  SELECT MAX(PO_NO) 
  INTO l_sys_order_id 
  FROM erd_lpn 
  WHERE sn_no = p_sn_no;
 
  IF l_count <> l_cmu_count  THEN
    /* create extended PO */
    SELECT SUBSTR(e1.erm_id,1,10)
      ||NVL(lpad(TO_CHAR(to_number(SUBSTR(e1.erm_id,11))+1),2,'0'),'01')
    INTO extd_erm_id
    FROM erm e1
    WHERE SUBSTR(e1.erm_id,1,10) = SUBSTR(p_sn_no,1,10)
    AND NVL(to_number(SUBSTR(e1.erm_id,11,2)),0) IN
      (SELECT MAX(NVL(to_number(SUBSTR(e2.erm_id,11,2)),0))
      FROM erm e2
      WHERE SUBSTR(e2.erm_id,1,10) = SUBSTR(p_sn_no,1,10));
      
    /* create new erm record */
    l_stage := 'insert extended erm(PO) ';
    
    INSERT
    INTO erm
      ( erm_id,
        erm_type,
        po,
        load_no,
        sched_date,
        exp_arriv_date,
        ship_date,
        rec_date,
        close_date,
        source_id,
        vend_name,
        vend_addr,
        vend_citystatezip,
        phone_no,
        ship_addr1,
        ship_addr2,
        ship_addr3,
        ship_addr4,
        ship_via,
        line_no,
        status,
        carr_id,
        cmt,
        sys_order_id,
        cross_dock_type, 
	cmu_process_complete)
    SELECT extd_erm_id,
      erm_type,
      po,
      load_no,
      TRUNC(SYSDATE),
      exp_arriv_date,
      ship_date,
      rec_date,
      close_date,
      source_id,
      vend_name,
      vend_addr,
      vend_citystatezip,
      phone_no,
      ship_addr1,
      ship_addr2,
      ship_addr3,
      ship_addr4,
      ship_via,
      line_no,
      'SCH',
      carr_id,
      cmt,
      l_sys_order_id,
      'MU',
      'Y'
    FROM erm
    WHERE erm_id = p_sn_no;
    
    
    /* update erd table */
    l_stage := 'Update erd';
    
    UPDATE erd
    SET erm_id           = extd_erm_id
    WHERE erm_id         = p_sn_no
 --   AND master_order_id IS NOT NULL
    AND EXISTS
      (SELECT 'X'
      FROM erd_lpn
      WHERE 1             =1
      AND erd.erm_line_id = erd_lpn.erm_line_id
      AND erd.erm_id      = erd_lpn.sn_no 
      AND erd_lpn.cmu_indicator ='C');
      
    l_stage := 'Update erd_lpn';
    
    UPDATE erd_lpn
    SET sn_no            = extd_erm_id
    WHERE sn_no          = p_sn_no
    AND cmu_indicator    = 'C';
  --  AND master_order_id IS NOT NULL;
    
    SELECT COUNT(*)
    INTO l_no_pallets
    FROM erd_lpn
    WHERE 1   =1
    AND sn_no = extd_erm_id;
    
    SELECT SUM(pm.spc)
    INTO l_no_cases
    FROM erd_lpn, pm
    WHERE erd_lpn.prod_id = pm.prod_id
    AND  erd_lpn.sn_no = extd_erm_id;
    
    l_stage              := 'Insert sn_header';
    
    INSERT
    INTO sn_header
      ( sn_no,
        sched_date,
        ship_date,
        status,
        no_pallets,
        transaction_type,
        record_type,
        vendor_nbr,
        rdc_nbr,
        opco_nbr,
        shipped_cube,
        area,
        anticipated_receipt_date,
        shipment_id,
        no_cases
      )
      (SELECT extd_erm_id,
          sched_date,
          ship_date,
          'SCH',
          l_no_pallets,
          transaction_type,
          record_type,
          vendor_nbr,
          rdc_nbr,
          opco_nbr,
          shipped_cube,
          area,
          anticipated_receipt_date,
          shipment_id,
          l_no_cases
        FROM sn_header
        WHERE sn_no = p_sn_no      );
 
   l_stage   := 'Update original sn_header cases and pallets';    

   update sn_header
   set no_cases = no_cases - l_no_cases,
       no_pallets = no_pallets -  l_no_pallets
   where sn_no =p_sn_no;
      
   /* SELECT max(po_no)
    INTO l_po_no
    FROM erd_lpn
    WHERE 1    =1
    AND sn_no  = extd_erm_id
    AND rownum =1;*/
    
    l_stage   := 'Insert sn_rdc_po';
    
    For i in c_mlti_po(extd_erm_id) loop
    
      INSERT INTO sn_rdc_po(sn_no,po_no, cmu_indicator) 
      VALUES( extd_erm_id, i.po_no, 'C' );
      
    End Loop;  
    
    l_stage := 'Update tmp_weight for new SN';

    UPDATE tmp_weight t
    SET erm_id           = extd_erm_id
    WHERE erm_id         = p_sn_no
    AND EXISTS
      (SELECT 'X'
      FROM erd_lpn
      WHERE t.prod_id     = erd_lpn.prod_id
      AND   t.erm_id      = erd_lpn.sn_no 
      AND   erd_lpn.cmu_indicator ='C');

    /* Use this variable to process cross_dock_data_collect */
     l_cmu_sn_no := extd_erm_id;  
     
     /* knha8378 Oct 28, 2019 Need to update cmu_process_complete */
     UPDATE ERM
       set cmu_process_complete = 'Y'
       WHERE erm_id = p_sn_no;
  ELSE
  
    /* Use this variable to process cross_dock_data_collect */
    l_cmu_sn_no := p_sn_no;
    l_stage := 'All Cross Dock erms , cross_dock_type = MU';
    
    UPDATE erm
    SET cross_dock_type='MU',
        sys_order_id     = l_sys_order_id,
        cmu_process_complete = 'Y'
    WHERE erm_id     = p_sn_no;
    
      For i in c_mlti_po(p_sn_no) loop
    
        Update sn_rdc_po
         set cmu_indicator = 'C'
        where sn_no =p_sn_no
        and po_no= i.po_no;
      
      End Loop;  
    
         dbms_output.put_line(' after vkal9662 -sn-rdc-po');
         
  END IF; --  l_count <> l_cmu_count
    
     
  
  l_stage := 'Split Done';
  
    pl_log.ins_msg
    (pl_log.ct_info_msg, l_object_name,
     'Before Calling pl_cmu_ins_cross_dock l_stage=' || l_stage || '  l_cmu_sn_no:' || l_cmu_sn_no,
     NULL,NULL,
     ct_application_function, gl_pkg_name);

  COMMIT;
  
  If  l_stage = 'Split Done' then
      pl_log.ins_msg
       (pl_log.ct_info_msg, l_object_name,
       'Inside l_stage now for  pl_cmu_ins_cross_dock l_stage=' || l_stage || '  l_cmu_sn_no:' || l_cmu_sn_no,
        NULL,NULL,
        ct_application_function, gl_pkg_name);
  
     --dbms_output.put_line(' after vkal9662 -in split done');
  
     -- calling process to load Cross_dock_data_collect_in table
     l_stage := 'upload_cross_dock_data_in';
     

	/* Do not use this procedure:pl_rcv_cross_dock.call_upload_cross_dock_data_in anymore */
        --pl_rcv_cross_dock.call_upload_cross_dock_data_in;


	/* new package and procedure to insert from erd_lpn first */
	/* then update cross_data_collect_in from other staging tables */
       --knha8378 using new package and procedures and setup l_cmu_sn_no 
	pl_cmu_ins_cross_dock.ins_cdk_from_erd_lpn(l_cmu_sn_no);
        pl_cmu_ins_cross_dock.upd_cdk_from_float(l_cmu_sn_no);
     
      -- calling process to load Cross_dock_data_collect tables
      
      l_stage := 'upload_cross_dock_data';
      
       SELECT count(*) 
	INTO l_count_Hold
       FROM cross_dock_data_collect_in
       WHERE erm_id = l_cmu_sn_no
       AND   record_status = 'H';

       IF l_count_Hold = 0 then
          pl_rcv_cross_dock.upload_cross_dock_data(l_cmu_sn_no); 
          COMMIT;    -- 10/03/19  Brian Bent  Added since pl_rcv_cross_dock.sql no longer commits.
       END IF;
     
      dbms_output.put_line(' after vkal9662 -cross dock uploads');
  End if;  -- l_cmu_count >0 then this is cmu order
   
   pl_log.ins_msg ('INFO', 'Split_CMU_SN', 'CMU Split process Successful for: '|| p_sn_no, SQLCODE, SQLERRM, 'RCV', 'pl_rcv_cross_dock');
 
 ELSE
    UPDATE erm
      SET cmu_process_complete = 'Y'
    WHERE erm_id     = p_sn_no;
    COMMIT;
 END IF; -- l_cmu_count>0
 
EXCEPTION
WHEN OTHERS THEN

  l_message := 'SN SPlit faild for -' || p_sn_no ||',' || extd_erm_id||'-'|| l_stage ;
  pl_log.ins_msg ('FATAL', 'Split_CMU_SN', l_message, SQLCODE, SQLERRM, 'RCV', 'pl_rcv_cross_dock');
  
END Split_CMU_SN;


---------------------------------------------------------------------------
-- Procedure:
--    cmu_upload_cross_dock_data
--
-- Description:
--    This procedure copies the records in the CROSS_DOCK_DATA_COLLECT_IN table
--    into the following tables for the specified CMU SN.
--       - CROSS_DOCK_DATA_COLLECT
--       - CROSS_DOCK_PALLET_XREF
--       - CROSS_DOCK_XREF
--
-- Parameters:
--    i_erm_id - SN to process
--
-- Called By:
--    xxx
--
-- Exceptions Raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/01/19 bben0556 Brian Bent
--                      Created.
---------------------------------------------------------------------------
PROCEDURE cmu_upload_cross_dock_data(i_erm_id IN erm.erm_id%TYPE)
IS
   l_object_name     VARCHAR2 (30) := 'cmu_upload_cross_dock_data';
   l_message         VARCHAR2 (512);      -- Message buffer

   l_parameters       VARCHAR2(80);     -- Used in log messages

   l_num_cddc_in_recs_processed     PLS_INTEGER;   -- Work area
   l_num_cddc_recs_created          PLS_INTEGER;   -- Work area
   l_num_cddc_recs_existing         PLS_INTEGER;   -- Work area
   l_num_rows_updated               PLS_INTEGER;   -- Work area

   l_sqlcode           VARCHAR2(20);     -- Holder for SQLCODE
   l_sqlerrm           VARCHAR2(500);    -- Holder for SQLERRM

   --
   -- This cursor select the message id's to procees for the specified SN.
   -- It is possible the SN is in CROSS_DOCK_DATA_COLLECT_IN under different
   -- message id's with record_status = 'N'.
   -- We will process by message id.
   --
   CURSOR c_msg_id(cp_erm_id  cross_dock_data_collect_in.erm_id%TYPE)
   IS
   SELECT DISTINCT msg_id
     FROM cross_dock_data_collect_in
    WHERE record_status = 'N'
      AND erm_id        = cp_erm_id
    ORDER BY msg_id;


   --
   -- This cursor selects the records in CROSS_DOCK_DATA_COLLECT_IN to process for specified message id.
   --
   CURSOR c_cddc_in(cp_msg_id  cross_dock_data_collect_in.msg_id%TYPE)
   IS
   SELECT cddc_in.msg_id,
          cddc_in.sequence_number,
          cddc_in.interface_type,
          cddc_in.record_status,
          cddc_in.datetime,
          cddc_in.retail_cust_no,
          cddc_in.ship_date,
          cddc_in.parent_pallet_id,
          cddc_in.erm_id,
          cddc_in.rec_type,
          cddc_in.prod_id,
          cddc_in.line_no,
          cddc_in.qty,
          --
          -- 10/03/19 Brian Bent The --CROSS_DOCK_DATA_COLLECT_IN.QTY is already is split so we use the qty as it.
          --CROSS_DOCK_DATA_COLLECT.QTY needs to be in splits
          --DECODE(cddc_in.qty, NULL, NULL, DECODE(cddc_in.uom, 1, cddc_in.qty, cddc_in.qty * pm.spc)) qty_in_splits,  
          --
          cddc_in.uom,
          cddc_in.area,
          cddc_in.pallet_type,
          cddc_in.exp_date,
          cddc_in.catch_wt,
          cddc_in.catch_wt_uom,
          cddc_in.master_order_id,
          cddc_in.carrier_id,
          cddc_in.lot_id,
          cddc_in.case_id,
          cddc_in.order_seq,
          cddc_in.item_seq,
          cddc_in.mfg_date,
          cddc_in.cmu_indicator,
          cddc_in.pallet_id,
          cddc_in.cw_type,
          cddc_in.sys_order_id
     FROM cross_dock_data_collect_in cddc_in,
          pm
    WHERE pm.prod_id (+)        = cddc_in.prod_id
      AND cddc_in.record_status = 'N'
      AND cddc_in.msg_id        = cp_msg_id
    ORDER BY cddc_in.sequence_number;

BEGIN
   l_parameters := '(i_erm_id[' || i_erm_id || '])';   -- Used in log messages

   --
   -- Log starting the procedure;
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure  ' || l_parameters
                     || '  This procedure takes the records in CROSS_DOCK_DATA_COLLECT_IN'
                     || ' and copies them to CROSS_DOCK_DATA_COLLECT and the XREF tables.'
                     || '  It is possible the SN is in CROSS_DOCK_DATA_COLLECT_IN under different'
                     || ' message ids with record_status = N.'
                     || '  We will process by message id.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- It is possible the SN is in CROSS_DOCK_DATA_COLLECT_IN under different
   -- message id's with record_status = 'N'.
   -- We will process by message id.  If any error is encountered then a rollback is
   -- made for that message id.
   --
   FOR r_msg_id IN c_msg_id(i_erm_id)
   LOOP
      pl_log.ins_msg
                 (i_msg_type         => pl_log.ct_info_msg,
                  i_procedure_name   => l_object_name,
                  i_msg_text         => 'Processing CROSS_DOCK_DATA_COLLECT_IN message id[' || r_msg_id.msg_id || ']',
                  i_msg_no           => NULL,
                  i_sql_err_msg      => NULL,
                  i_application_func => ct_application_function,
                  i_program_name     => gl_pkg_name,
                  i_msg_alert        => 'N');

      --
      -- Any error will result in a rollback to this savepoint and CROSS_DOCK_DATA_COLLECT_IN.RECORD_STATUS set to 'F'.
      --
      SAVEPOINT sp_cddc;

      BEGIN
         --
         -- Initialization
         --
         l_num_cddc_in_recs_processed  := 0;   
         l_num_cddc_recs_created       := 0;
         l_num_cddc_recs_existing      := 0;

         dbms_output.put_line('xxx ' || l_object_name || ' i_erm_id[' ||  i_erm_id || ']');

         FOR r_cddc_in IN c_cddc_in(r_msg_id.msg_id)
         LOOP
            dbms_output.put_line('xxx ' || l_object_name || '  Parent LP:' ||   r_cddc_in.parent_pallet_id || '  rec_type:' || r_cddc_in.rec_type);

            l_num_cddc_in_recs_processed := l_num_cddc_in_recs_processed + 1;

            BEGIN
               --
               -- Insert into cross_dock_data_collect checking for dups.
               -- 10/03/19 At this time thee is no primary key on the table so we manually check.
               --
               INSERT INTO cross_dock_data_collect
                       (erm_id,
                        rec_type,
                        line_no,
                        prod_id,
                        qty,
                        uom,
                        area,
                        pallet_id,
                        parent_pallet_id,
                        pallet_type,
                        temp,
                        temp_unit,
                        exp_date,
                        mfg_date,
                        catch_wt,
                        catch_wt_unit,
                        harvest_date,
                        clam_bed_no,
                        country_of_origin,
                        wild_farm,
                        data_collect,
                        rdc_po_no,
                        master_order_id,
                        carrier_id,
                        lot_id,
                        case_id,
                        order_seq,
                        item_seq,
                        interface_type,
                        cw_type,
                        cmu_ind,
                        sys_order_id,
                        add_date,
                        add_user)
                 SELECT
                        r_cddc_in.erm_id                 erm_id,
                        DECODE(r_cddc_in.rec_type, 'P', 'H', r_cddc_in.rec_type) rec_type,
                        r_cddc_in.line_no                line_no,
                        r_cddc_in.prod_id                prod_id,
                        r_cddc_in.qty                    qty,
                        r_cddc_in.uom                    uom,
                        r_cddc_in.area                   area,
                        r_cddc_in.pallet_id              pallet_id,
                        r_cddc_in.parent_pallet_id       parent_pallet_id,
                        r_cddc_in.pallet_type            pallet_type,
                        NULL                             temp,
                        NULL                             temp_unit,
                        r_cddc_in.exp_date               exp_date,
                        r_cddc_in.mfg_date               mfg_date,
                        r_cddc_in.catch_wt               catch_wt,
                        r_cddc_in.catch_wt_uom           catch_wt_unit,
                        NULL                             harvest_date,
                        NULL                             clam_bed_no,
                        NULL                             country_of_origin,
                        NULL                             wild_farm,
                        NULL                             data_collect,
                        NULL                             rdc_po_no,
                        r_cddc_in.master_order_id        master_order_id,
                        r_cddc_in.carrier_id             carrier_id,
                        r_cddc_in.lot_id                 lot_id,
                        r_cddc_in.case_id                case_id,
                        r_cddc_in.order_seq              order_seq,
                        r_cddc_in.item_seq               item_seq,
                        r_cddc_in.interface_type         interface_type,
                        r_cddc_in.cw_type                cw_type,
                        r_cddc_in.cmu_indicator          cmu_indicator,
                        r_cddc_in.sys_order_id           sys_order_id,
                        SYSDATE                          add_date,
                        REPLACE(USER, 'OPS$', NULL)      add_user
                   FROM DUAL;

               l_num_cddc_recs_created  := l_num_cddc_recs_created  + 1;
            EXCEPTION
               WHEN OTHERS THEN
                  DBMS_OUTPUT.PUT_LINE('xxx ' || l_object_name || ' error inserting into CDDC: ' || sqlerrm);

                  pl_log.ins_msg
                     (i_msg_type         => pl_log.ct_fatal_msg,
                      i_procedure_name   => l_object_name,
                      i_msg_text         => l_parameters
                                 || '  Error inserting into CROSS_DOCK_DATA_COLLECT from CROSS_DOCK_DATA_COLLECT_IN.'
                                 || '  Reraise exception.',
                      i_msg_no           => SQLCODE,
                      i_sql_err_msg      => SQLERRM,
                      i_application_func => ct_application_function,
                      i_program_name     => gl_pkg_name,
                      i_msg_alert        => 'N');
                  RAISE;
            END;
         END LOOP;

         dbms_output.put_line('xxx ' || l_object_name || '  after cddc_in loop');

         --
         -- Insert CROSS_DOCK_PALLET_XREF records.
         --
         INSERT INTO cross_dock_pallet_xref
            (retail_cust_no,
             erm_id,
             sys_order_id,
             parent_pallet_id,
             ship_date,
             add_date,
             add_user)
         SELECT DISTINCT
             cddc_in.retail_cust_no,
             cddc_in.erm_id,
             cddc_in.sys_order_id,
             cddc_in.parent_pallet_id,
             cddc_in.ship_date,
             SYSDATE,
             REPLACE(USER, 'OPS$', NULL)
           FROM cross_dock_data_collect_in cddc_in
          WHERE msg_id        = r_msg_id.msg_id
            AND rec_type      = 'D'
            AND record_status = 'N'
            AND NOT EXISTS         -- And the record not already inserted
                  (SELECT 'x'
                     FROM cross_dock_pallet_xref x2
                    WHERE x2.retail_cust_no          = cddc_in.retail_cust_no
                      AND x2.erm_id                  = cddc_in.erm_id
                      AND NVL(x2.sys_order_id, -1)  = NVL(cddc_in.sys_order_id, -1)
                      AND x2.parent_pallet_id        = cddc_in.parent_pallet_id);

         dbms_output.put_line('xxx ' || l_object_name || '  after insert into cross_dock_pallet_xref');
      
         --
         -- Insert CROSS_DOCK_XREF records.
         --
         INSERT INTO cross_dock_xref
               (erm_id,
                sys_order_id,
                status,
                add_date)
         SELECT DISTINCT
                cddc_in.erm_id,
                cddc_in.sys_order_id,
                'NEW',
                SYSDATE
           FROM cross_dock_data_collect_in cddc_in
          WHERE msg_id         = r_msg_id.msg_id
            AND rec_type       = 'D'
            AND record_status  = 'N'
            AND NOT EXISTS         -- And the record not already inserted
                  (SELECT 'x'
                     FROM cross_dock_xref x2
                    WHERE x2.erm_id           = cddc_in.erm_id
                      AND x2.sys_order_id     = cddc_in.sys_order_id
                      AND x2.status           = 'NEW');

         dbms_output.put_line('xxx ' || l_object_name || '  after insert into cross_dock_xref');

         --
         -- If this point reaached then everyting is good.
         -- Flag the CROSS_DOCK_DATA_COLLECT_IN records as processed successfully.
         --
         l_message        := l_object_name || ' Data Upload successfull for message id[' || r_msg_id.msg_id || ']';
         pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, l_message, SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name );

         UPDATE cross_dock_data_collect_in
            SET record_status  = 'S',
                upd_date       = SYSDATE,
                upd_user       = REPLACE(USER, 'OPS$', NULL)
          WHERE msg_id        = r_msg_id.msg_id
            AND record_status = 'N';

         l_num_rows_updated := SQL%ROWCOUNT;

         --
         -- Log how many cross_dock_data_collect_in updated.
         --
         pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         =>
                      'TABLE=cross_dock_data_collect_in'
                   || '  KEY=[' || r_msg_id.msg_id || ',N]'
                   || '(msg_id,record_status)'
                   || '  ACTION=UPDATE'
                   || '  MESSAGE="Updated the record_status to S SQL%ROWCOUNT[' || TO_CHAR(l_num_rows_updated) || ']"',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   EXCEPTION
      WHEN OTHERS THEN
         --
         -- Got some oracle error processing the message.
         -- Rollback to the savepoint.
         -- Set the CROSS_DOCK_DATA_COLLECT.RECORD_STATUS record status to 'F' for the message being processed.
         -- Log a message.
         --
         -- Save the error code and error msg since the rollback to the save point can change them.
         --
         l_sqlcode  := SQLCODE;
         l_sqlerrm  := SQLERRM;

         ROLLBACK TO SAVEPOINT sp_cddc;

         UPDATE cross_dock_data_collect_in
            SET record_status   = 'F',
                upd_date        = SYSDATE,
                upd_user        = REPLACE(USER, 'OPS$')
          WHERE msg_id   = r_msg_id.msg_id;

         l_num_rows_updated := SQL%ROWCOUNT;

         pl_log.ins_msg
             (i_msg_type         => pl_log.ct_fatal_msg,
              i_procedure_name   => l_object_name,
              i_msg_text         => l_parameters
                         || '  Error creating CROSS_DOCK_DATA_COLLECT records from CROSS_DOCK_DATA_COLLECT_IN.'
                         || '  Roll back to the savepoint for message id[' || r_msg_id.msg_id || ']'
                         || '  then set CROSS_DOCK_DATA_COLLECT.RECORD_STATUS set to ''F'''
                         || '  SQL%ROWCOUNT[' || TO_CHAR(l_num_rows_updated)  || ']"',
              i_msg_no           => l_sqlcode,
              i_sql_err_msg      => l_sqlerrm,
              i_application_func => ct_application_function,
              i_program_name     => gl_pkg_name,
              i_msg_alert        => 'N');

      END;
   END LOOP; -- end the "process by msg id" loop;
  

   --
   -- Log ending the procedure;
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure  ' || l_parameters
                 || '  l_num_cddc_in_recs_processed[' || TO_CHAR(l_num_cddc_in_recs_processed) || ']'
                 || '  l_num_cddc_recs_created['      || TO_CHAR(l_num_cddc_recs_created)      || ']'
                 || '  l_num_cddc_in_recs_processed and l_num_cddc_recs_created should always match.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      -- Rollback to the savepoint.
      -- Set the CROSS_DOCK_DATA_COLLECT.RECORD_STATUS record status to 'F' for the SN.
      -- Log a message.
      --
      -- Save the error code and error msg since the rollback to the save point can change them.
      --
      l_sqlcode  := SQLCODE;
      l_sqlerrm  := SQLERRM;

      ROLLBACK TO SAVEPOINT sp_cddc;

      UPDATE cross_dock_data_collect_in
         SET record_status   = 'F',
             upd_date        = SYSDATE,
             upd_user        = REPLACE(USER, 'OPS$', NULL)
       WHERE erm_id    = i_erm_id;

      l_num_rows_updated := SQL%ROWCOUNT;

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_parameters
                         || '  Error creating CROSS_DOCK_DATA_COLLECT records from CROSS_DOCK_DATA_COLLECT_IN.'
                         || '  Rollbacked to the savepoint.'
                         || '  CROSS_DOCK_DATA_COLLECT.RECORD_STATUS set to ''F'''
                         || '  SQL%ROWCOUNT[' || TO_CHAR(l_num_rows_updated)  || ']"',
           i_msg_no           => l_sqlcode,
           i_sql_err_msg      => l_sqlerrm,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');


END cmu_upload_cross_dock_data;


END pl_rcv_cross_dock;
/

