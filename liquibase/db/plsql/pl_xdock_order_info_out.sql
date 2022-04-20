/*******************************************************************************

  Package:
    pl_xdock_order_info_out.sql

  Description:
    This package contains the functionality to transfer ordm information into
    staging table XDOCK_ORDM_OUT.

    Package is assumed idempotent, each run will send the current ordm/ordd data
    with the next available sequence_no and batch_id to the respective staging
    tables.

  Modification History:

  Date        Designer  Comments
  ----------- --------- ------------------------------------------------------
  22-JUN-2021 mche6435  Initial version

*******************************************************************************/
CREATE OR REPLACE PACKAGE SWMS.pl_xdock_order_info_out IS
  PACKAGE_NAME      CONSTANT  swms_log.program_name%TYPE     := $$PLSQL_UNIT;
  APPLICATION_FUNC  CONSTANT  swms_log.application_func%TYPE := 'XDOCK';

  PROCEDURE main(
    i_route_no  IN ordm.route_no%TYPE
  );

  PROCEDURE process_xdock_ordm_out(
    i_route_no  IN ordm.route_no%TYPE,
    i_batch_id  IN xdock_ordm_out.batch_id%TYPE
  );

  PROCEDURE process_xdock_ordd_out(
    i_route_no  IN ordm.route_no%TYPE,
    i_batch_id  IN xdock_ordm_out.batch_id%TYPE
  );

  FUNCTION run_prechecks(
    i_route_no  IN ordm.route_no%TYPE
  ) RETURN PLS_INTEGER;
END pl_xdock_order_info_out;
/

CREATE OR REPLACE PACKAGE BODY SWMS.pl_xdock_order_info_out IS
  /*************************************************************************
    Procedure:
      main

    Description:
      Main entry point function, generates a batch id for
      xdock_ordm/ordd_out tables. This procedure also will call the xdock
      message hub.

    Parameters:
      i_route_no  -- Route number to to add to xdock_ordm/ordd_out

    Designer    date      version
    mche6435    06/23/21  v1.0
  **************************************************************************/
  PROCEDURE main(
    i_route_no  IN ordm.route_no%TYPE
  ) IS
    l_proc_name          VARCHAR2(50) := 'main';

    l_batch_id           xdock_ordm_out.batch_id%TYPE;
    l_precheck_result    PLS_INTEGER;
  BEGIN
    pl_log.ins_msg('DEBUG', l_proc_name, 'Starting ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    -- Check if run is necessary
    l_precheck_result := run_prechecks(i_route_no);

    IF l_precheck_result != 0 THEN
      pl_log.ins_msg('DEBUG', l_proc_name, 'Prechecks failed, exiting.', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
      RETURN;
    END IF;

    -- Get batch_id from common function
    pl_log.ins_msg('DEBUG', l_proc_name, 'Getting new batch_id.', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    BEGIN
      l_batch_id := pl_xdock_common.get_batch_id;
    EXCEPTION
      WHEN OTHERS THEN
        pl_log.ins_msg(
          'FATAL',
          l_proc_name,
          'Failed to get batch_id from pl_xdock_common.get_batch_id',
          sqlcode,
          sqlerrm
        );
        RAISE;
    END;

    -- Process ORDM and ORDD
    pl_log.ins_msg('DEBUG', l_proc_name, 'Starting staging table processes.', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
    process_xdock_ordm_out(i_route_no, l_batch_id);
    process_xdock_ordd_out(i_route_no, l_batch_id);

    -- Commit must happen before message hub is able to run
    COMMIT;

    -- Call message hub to signal transfer xdock_ordm/ordd_out
    -- This must happen after the tables are committed
    -- Message hub is setup to where if XDOCK_ORDM_OUT is called it will also work on XDOCK_ORDD_OUT
    pl_log.ins_msg('DEBUG', l_proc_name, 'Calling message hub.', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
    pl_xdock_common.call_message_hub(
      i_route_no     => i_route_no,
      i_batch_id     => l_batch_id,
      i_stg_tbl_name => 'XDOCK_ORDM_OUT'
    );

    pl_log.ins_msg('DEBUG', l_proc_name, 'Ending ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      pl_log.ins_msg('FATAL', l_proc_name, 'Call to ' || l_proc_name || ' failed. ', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
      RAISE;
  END main;

  /*************************************************************************
    Procedure:
      process_xdock_ordm_out

    Description:
      This function will add rows to the ORDM out table that are
      crossdock orders.

      Currently setup to run one at a time based on the route
      batch number.

    Parameters:
      i_route_no  -- Route number to use to select from ordm
      i_batch_id  -- Batch_ID to be applied to all inserts to xdock_ordm_out

    Designer    date      version
    mche6435    06/22/21  v1.0
  **************************************************************************/
  PROCEDURE process_xdock_ordm_out(
    i_route_no  IN ordm.route_no%TYPE,
    i_batch_id  IN xdock_ordm_out.batch_id%TYPE
  ) IS
    l_proc_name   VARCHAR2(50) := 'process_xdock_ordm_out';
  BEGIN
    pl_log.ins_msg('DEBUG', l_proc_name, 'Starting ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    INSERT INTO XDOCK_ORDM_OUT(
      sequence_number,
      batch_id,
      order_id,
      route_no,
      stop_no,
      record_status,
      truck_no,
      trailer_no,
      priority,
      truck_type,
      ship_date,
      status,
      cust_id,
      carr_id,
      wave_number,
      order_type,
      unitize_ind,
      cust_po,
      cust_name,
      cust_contact,
      cust_addr1,
      cust_addr2,
      cust_addr3,
      cust_city,
      cust_state,
      cust_zip,
      cust_cntry,
      ship_id,
      ship_name,
      ship_addr1,
      ship_addr2,
      ship_addr3,
      ship_city,
      ship_state,
      ship_zip,
      ship_cntry,
      sales,
      grpm_id,
      grpm_seq,
      del_time,
      d_pieces,
      c_pieces,
      f_pieces,
      weight,
      sys_order_id,
      sys_order_line_id,
      immediate_ind,
      delivery_method,
      deleted,
      frz_special,
      clr_special,
      dry_special,
      old_stop_no,
      cross_dock_type,
      dod_contract_no,
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
    SELECT
      XDOCK_SEQNO_SEQ.nextval,
      i_batch_id,
      order_id,
      route_no,
      stop_no,
      'N',
      truck_no,
      trailer_no,
      priority,
      truck_type,
      ship_date,
      status,
      cust_id,
      carr_id,
      wave_number,
      order_type,
      unitize_ind,
      cust_po,
      cust_name,
      cust_contact,
      cust_addr1,
      cust_addr2,
      cust_addr3,
      cust_city,
      cust_state,
      cust_zip,
      cust_cntry,
      ship_id,
      ship_name,
      ship_addr1,
      ship_addr2,
      ship_addr3,
      ship_city,
      ship_state,
      ship_zip,
      ship_cntry,
      sales,
      grpm_id,
      grpm_seq,
      del_time,
      d_pieces,
      c_pieces,
      f_pieces,
      weight,
      sys_order_id,
      sys_order_line_id,
      immediate_ind,
      delivery_method,
      deleted,
      frz_special,
      clr_special,
      dry_special,
      old_stop_no,
      cross_dock_type,
      dod_contract_no,
      delivery_document_id,
      site_id,
      site_from,
      site_to,
      site_to_route_no,
      site_to_stop_no,
      site_to_truck_no,
      site_to_door_no,
      SYSDATE,
      USER
    FROM ordm
    WHERE ordm.cross_dock_type = 'S'
    AND ordm.route_no = i_route_no;

    pl_log.ins_msg('DEBUG', l_proc_name, 'Ending ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_proc_name, 'Call to ' || l_proc_name || ' failed. ', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
      RAISE;
  END process_xdock_ordm_out;


  /*************************************************************************
    Procedure:
      process_xdock_ordd_out

    Description:
      This function will add rows to the ORDD out table that are
      crossdock orders.

      Currently setup to run one at a time based on the route
      batch number.

    Parameters:
      i_route_no  -- Route number to use to select from ordd
      i_batch_id  -- Batch_ID to be applied to all inserts to xdock_ordd_out

    Designer    date      version
    mche6435    06/22/21  v1.0
  **************************************************************************/
  PROCEDURE process_xdock_ordd_out(
    i_route_no  IN ordm.route_no%TYPE,
    i_batch_id  IN xdock_ordm_out.batch_id%TYPE
  ) IS
    l_proc_name   VARCHAR2(50) := 'process_xdock_ordd_out';
  BEGIN
    pl_log.ins_msg('DEBUG', l_proc_name, 'Starting ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    INSERT INTO XDOCK_ORDD_OUT(
      sequence_number,
      batch_id,
      order_id,
      order_line_id,
      prod_id,
      cust_pref_vendor,
      lot_id,
      status,
      record_status,
      qty_ordered,
      qty_shipped,
      uom,
      weight,
      partial,
      page,
      inck_key,
      seq,
      area,
      route_no,
      stop_no,
      qty_alloc,
      zone_id,
      pallet_pull,
      sys_order_id,
      sys_order_line_id,
      wh_out_qty,
      reason_cd,
      pk_adj_type,
      pk_adj_dt,
      user_id,
      cw_type,
      qa_ticket_ind,
      deleted,
      pcl_flag,
      pcl_id,
      original_uom,
      dod_cust_item_barcode,
      dod_fic,
      product_out_qty,
      master_order_id,
      remote_local_flg,
      remote_qty,
      rdc_po_no,
      qty_ordered_original,
      original_order_line_id,
      original_seq,
      delivery_document_id,
      add_date,
      add_user
    )
    SELECT
      XDOCK_SEQNO_SEQ.nextval,
      i_batch_id,
      d.order_id,
      d.order_line_id,
      d.prod_id,
      d.cust_pref_vendor,
      d.lot_id,
      d.status,
      'N',
      d.qty_ordered,
      d.qty_shipped,
      d.uom,
      d.weight,
      d.partial,
      d.page,
      d.inck_key,
      d.seq,
      d.area,
      d.route_no,
      d.stop_no,
      d.qty_alloc,
      d.zone_id,
      d.pallet_pull,
      d.sys_order_id,
      d.sys_order_line_id,
      d.wh_out_qty,
      d.reason_cd,
      d.pk_adj_type,
      d.pk_adj_dt,
      d.user_id,
      d.cw_type,
      d.qa_ticket_ind,
      d.deleted,
      d.pcl_flag,
      d.pcl_id,
      d.original_uom,
      d.dod_cust_item_barcode,
      d.dod_fic,
      d.product_out_qty,
      d.master_order_id,
      d.remote_local_flg,
      d.remote_qty,
      d.rdc_po_no,
      d.qty_ordered_original,
      d.original_order_line_id,
      d.original_seq,
      m.delivery_document_id,
      SYSDATE,
      USER
    FROM ordd d
    LEFT JOIN ordm m ON m.order_id = d.order_id
    WHERE m.cross_dock_type = 'S'
    AND m.route_no = i_route_no;

    pl_log.ins_msg('DEBUG', l_proc_name, 'Ending ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_proc_name, 'Call to ' || l_proc_name || ' failed. ', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
      RAISE;
  END process_xdock_ordd_out;

  /*************************************************************************
    FUNCTION:
      run_prechecks

    Description:
      Prechecks to make sure that order information can be ran.

    Parameters:
      i_route_no  -- Route number to use to select from ordm

    Returns:
      PLS_INTEGER -- 0 if successful anything not 0 is unsuccessful

    Designer    date      version
    mche6435    07/12/21  v1.0
  **************************************************************************/
  FUNCTION run_prechecks(
    i_route_no  IN ordm.route_no%TYPE
  ) RETURN PLS_INTEGER IS
    l_func_name VARCHAR2(50) := 'run_prechecks';

    r_ordm_xdock_type      ordm.cross_dock_type%TYPE;
    r_xdock_route_closed   PLS_INTEGER;

    e_not_xdock_order      EXCEPTION;
    e_route_not_closed     EXCEPTION;
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name, 'Starting ' || l_func_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    BEGIN
      SELECT DISTINCT cross_dock_type
      INTO r_ordm_xdock_type
      FROM ordm
      WHERE route_no = i_route_no;
    EXCEPTION
      WHEN TOO_MANY_ROWS THEN
        pl_log.ins_msg(
          'FATAL',
          l_func_name,
          'Too many rows returned. Route has more than 1 cross dock type',
          sqlcode,
          sqlerrm,
          APPLICATION_FUNC,
          PACKAGE_NAME
        );
        RAISE;
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg(
          'FATAL',
          l_func_name,
          'No record found in ordm table for route_no: ' || i_route_no,
          sqlcode,
          sqlerrm,
          APPLICATION_FUNC,
          PACKAGE_NAME
        );
        RAISE;
      WHEN OTHERS THEN
        pl_log.ins_msg(
          'FATAL',
          l_func_name,
          'Error when selecting distinct cross dock type from ordm table',
          sqlcode,
          sqlerrm,
          APPLICATION_FUNC,
          PACKAGE_NAME
        );
        RAISE;
    END;

    IF r_ordm_xdock_type != 'S' THEN
      RAISE e_not_xdock_order;
    END IF;

    -- Route must be Status: Closed
    SELECT COUNT(1)
    INTO r_xdock_route_closed
    FROM route
    WHERE route_no = i_route_no
    AND STATUS = 'CLS';

    IF r_xdock_route_closed = 0 THEN
      RAISE e_route_not_closed;
    END IF;

    RETURN 0;
    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
    WHEN e_not_xdock_order THEN
      pl_log.ins_msg('DEBUG', l_func_name, 'Not a cross dock order', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
      RETURN 1;
    WHEN e_route_not_closed THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Route is not closed.', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
      RETURN 1;
    WHEN NO_DATA_FOUND THEN
      pl_log.ins_msg('DEBUG',
        l_func_name,
        'No Data Found thrown. route_no:' || i_route_no,
        sqlcode,
        sqlerrm,
        APPLICATION_FUNC,
        PACKAGE_NAME
      );
      RETURN 1;
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to ' || l_func_name || ' failed.', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
      RETURN 1;
  END run_prechecks;
END pl_xdock_order_info_out;
/

SHOW ERRORS;

GRANT EXECUTE ON SWMS.pl_xdock_order_info_out TO SWMS_User;
