/*******************************************************************************

  Package:
    pl_xdock_floats_info_out.sql

  Description:
    This package contains the functionality to transfer float information into
    staging table XDOCK_FLOATS_OUT.

    Package is assumed idempotent, each run will send the current
    float/float_detail data with the next available sequence_no and batch_id
    to the respective staging tables.

  Modification History:

  Date        Designer  Comments
  ----------- --------- ------------------------------------------------------
  22-JUN-2021 mche6435  Initial version
  03-SEP-2021 bben0556  Brian Bent
                        'S' cross dock type float records not inserted into
                        XDOCK_FLOATS_OUT.
                        Found check for multiple cross dock types on the 
                        route in "run_prechecks" was including demand
                        replenishsments (floats.pallet_pull = 'R')
                        Added to the query:
                           AND pallet_pull <> 'R';

*******************************************************************************/
CREATE OR REPLACE PACKAGE SWMS.pl_xdock_floats_info_out IS
  PACKAGE_NAME      CONSTANT  swms_log.program_name%TYPE     := $$PLSQL_UNIT;
  APPLICATION_FUNC  CONSTANT  swms_log.application_func%TYPE := 'XDOCK';

  PROCEDURE main(
    i_route_no  IN floats.route_no%TYPE
  );

  PROCEDURE process_xdock_floats_out(
    i_route_no  IN floats.route_no%TYPE,
    i_batch_id  IN xdock_floats_out.batch_id%TYPE
  );

  PROCEDURE process_xdock_float_detail_out(
    i_route_no  IN floats.route_no%TYPE,
    i_batch_id  IN xdock_floats_out.batch_id%TYPE
  );

  FUNCTION run_prechecks(
    i_route_no  IN floats.route_no%TYPE
  ) RETURN PLS_INTEGER;
END pl_xdock_floats_info_out;
/

CREATE OR REPLACE PACKAGE BODY SWMS.pl_xdock_floats_info_out IS
  /*************************************************************************
    Procedure:
      main

    Description:
      Main entry point function, generates a batch id for
      xdock_float/float_detail_out tables. This procedure also will call the xdock
      message hub.

    Parameters:
      i_route_no  -- Route number to to add to xdock_float/float_detail_out

    Designer    date      version
    mche6435    06/23/21  v1.0
  **************************************************************************/
  PROCEDURE main(
    i_route_no  IN floats.route_no%TYPE
  ) IS
    l_proc_name          VARCHAR2(50) := 'main';

    l_batch_id           xdock_floats_out.batch_id%TYPE;
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
    pl_log.ins_msg('DEBUG', l_proc_name, 'Generating new batch_id.', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
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

    -- Process floats and float_detail
    pl_log.ins_msg('DEBUG', l_proc_name, 'Starting staging table processes.', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
    process_xdock_floats_out(i_route_no, l_batch_id);
    process_xdock_float_detail_out(i_route_no, l_batch_id);

    -- Process ORDCW(Order CatchWeight)
    pl_xdock_ordcw_out.process_xdock_ordcw_out(i_route_no, l_batch_id);

    COMMIT;

    -- Call message hub to signal transfer xdock_float/float_detail_out
    -- This must happen after the tables are committed
    -- XDOCK_FLOATS_OUT will also call XDOCK_FLOAT_DETAIL_OUT
    pl_log.ins_msg('DEBUG', l_proc_name, 'Calling message hub.', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
    pl_xdock_common.call_message_hub(
      i_route_no     =>  i_route_no,
      i_batch_id     =>  l_batch_id,
      i_stg_tbl_name =>  'XDOCK_FLOATS_OUT'
    );

    pl_log.ins_msg('DEBUG', l_proc_name, 'Ending ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      pl_log.ins_msg('FATAL', l_proc_name, 'Call to' || l_proc_name || 'failed', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
      RAISE;
  END main;

  /*************************************************************************
    Procedure:
      process_xdock_floats_out

    Description:
      This function will add rows to the float out table that are
      crossdock orders.

      Currently setup to run one at a time based on the route
      batch number.

    Parameters:
      i_route_no  -- Route number to use to select from float
      i_batch_id  -- Batch_ID to be applied to all inserts to xdock_floats_out

    Designer    date      version
    mche6435    06/22/21  v1.0
  **************************************************************************/
  PROCEDURE process_xdock_floats_out(
    i_route_no  IN floats.route_no%TYPE,
    i_batch_id  IN xdock_floats_out.batch_id%TYPE
  ) IS
    l_proc_name   VARCHAR2(50) := 'process_xdock_floats_out';
  BEGIN
    pl_log.ins_msg('DEBUG', l_proc_name, 'Starting ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    INSERT INTO XDOCK_FLOATS_OUT(
      sequence_number,
      batch_id,
      batch_no,
      batch_seq,
      float_no,
      float_seq,
      route_no,
      b_stop_no,
      e_stop_no,
      record_status,
      float_cube,
      group_no,
      merge_group_no,
      merge_seq_no,
      merge_loc,
      zone_id,
      equip_id,
      comp_code,
      split_ind,
      pallet_pull,
      pallet_id,
      home_slot,
      drop_qty,
      door_area,
      single_stop_flag,
      status,
      ship_date,
      parent_pallet_id,
      fl_method_id,
      fl_sel_type,
      fl_opt_pull,
      truck_no,
      door_no,
      cw_collect_status,
      cw_collect_user,
      fl_no_of_zones,
      fl_multi_no,
      fl_sel_lift_job_code,
      mx_priority,
      is_sleeve_selection,
      add_date,
      add_user
    )
    SELECT
      XDOCK_SEQNO_SEQ.nextval,
      i_batch_id,
      batch_no,
      batch_seq,
      float_no,
      float_seq,
      route_no,
      b_stop_no,
      e_stop_no,
      'N',
      float_cube,
      group_no,
      merge_group_no,
      merge_seq_no,
      merge_loc,
      zone_id,
      equip_id,
      comp_code,
      split_ind,
      pallet_pull,
      pallet_id,
      home_slot,
      drop_qty,
      door_area,
      single_stop_flag,
      status,
      ship_date,
      parent_pallet_id,
      fl_method_id,
      fl_sel_type,
      fl_opt_pull,
      truck_no,
      door_no,
      cw_collect_status,
      cw_collect_user,
      fl_no_of_zones,
      fl_multi_no,
      fl_sel_lift_job_code,
      mx_priority,
      is_sleeve_selection,
      SYSDATE,
      USER
    FROM floats
    WHERE route_no = i_route_no
    AND cross_dock_type = 'S';

    pl_log.ins_msg('DEBUG', l_proc_name, 'Ending ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_proc_name, 'Call to' || l_proc_name || 'failed', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
      RAISE;
  END process_xdock_floats_out;


  /*************************************************************************
    Procedure:
      process_xdock_float_detail_out

    Description:
      This function will add rows to the float_detail out table that are
      crossdock orders.

      Currently setup to run one at a time based on the route
      batch number.

    Parameters:
      i_route_no  -- Route number to use to select from float_detail
      i_batch_id  -- Batch_ID to be applied to all inserts to xdock_float_detail_out

    Designer    date      version
    mche6435    06/22/21  v1.0
  **************************************************************************/
  PROCEDURE process_xdock_float_detail_out(
    i_route_no  IN floats.route_no%TYPE,
    i_batch_id  IN xdock_floats_out.batch_id%TYPE
  ) IS
    l_proc_name   VARCHAR2(50) := 'process_xdock_float_detail_out';
  BEGIN
    pl_log.ins_msg('DEBUG', l_proc_name, 'Starting ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    INSERT INTO XDOCK_FLOAT_DETAIL_OUT(
      sequence_number,
      batch_id,
      float_no,
      seq_no,
      zone,
      stop_no,
      record_status,
      prod_id,
      src_loc,
      multi_home_seq,
      uom,
      qty_order,
      qty_alloc,
      merge_alloc_flag,
      merge_loc,
      status,
      order_id,
      order_line_id,
      cube,
      copy_no,
      merge_float_no,
      merge_seq_no,
      cust_pref_vendor,
      clam_bed_trk,
      route_no,
      route_batch_no,
      alloc_time,
      rec_id,
      mfg_date,
      exp_date,
      lot_id,
      carrier_id,
      order_seq,
      sos_status,
      cool_trk,
      catch_wt_trk,
      item_seq,
      qty_short,
      st_piece_seq,
      selector_id,
      bc_st_piece_seq,
      short_item_seq,
      sleeve_id,
      add_date,
      add_user
    )
    SELECT
      XDOCK_SEQNO_SEQ.nextval,
      i_batch_id,
      d.float_no,
      d.seq_no,
      d.zone,
      d.stop_no,
      'N',
      d.prod_id,
      d.src_loc,
      d.multi_home_seq,
      d.uom,
      d.qty_order,
      d.qty_alloc,
      d.merge_alloc_flag,
      d.merge_loc,
      d.status,
      d.order_id,
      d.order_line_id,
      d.cube,
      d.copy_no,
      d.merge_float_no,
      d.merge_seq_no,
      d.cust_pref_vendor,
      d.clam_bed_trk,
      d.route_no,
      d.route_batch_no,
      d.alloc_time,
      d.rec_id,
      d.mfg_date,
      d.exp_date,
      d.lot_id,
      d.carrier_id,
      d.order_seq,
      d.sos_status,
      d.cool_trk,
      d.catch_wt_trk,
      d.item_seq,
      d.qty_short,
      d.st_piece_seq,
      d.selector_id,
      d.bc_st_piece_seq,
      d.short_item_seq,
      d.sleeve_id,
      SYSDATE,
      USER
    FROM float_detail d
    LEFT JOIN floats f ON f.float_no = d.float_no
    WHERE d.route_no = i_route_no
    AND f.cross_dock_type = 'S';

    pl_log.ins_msg('DEBUG', l_proc_name, 'Ending ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_proc_name, 'Call to' || l_proc_name || 'failed', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
      RAISE;
  END process_xdock_float_detail_out;

  /*************************************************************************
    Function:     run_prechecks
    Description:  Prechecks to make sure float can run.

    Parameters:
      i_route_no  -- Route number to use to select from floats

    Returns:
      PLS_INTEGER -- 0 if successful anything not 0 is unsuccessful

    Designer    date      version
    mche6435    07/13/21  v1.0
  **************************************************************************/
  FUNCTION run_prechecks(
    i_route_no  IN floats.route_no%TYPE
  ) RETURN PLS_INTEGER AS
    l_func_name VARCHAR2(50) := 'run_prechecks';

    r_floats_xdock_type    floats.cross_dock_type%TYPE;
    r_xdock_route_closed   PLS_INTEGER;

    e_not_xdock_order      EXCEPTION;
    e_route_not_closed     EXCEPTION;
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name, 'Starting ' || l_func_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    -- Verify record is cross dock type
    BEGIN
      SELECT DISTINCT cross_dock_type
      INTO r_floats_xdock_type
      FROM floats
      WHERE route_no = i_route_no
      AND pallet_pull <>  'R';        -- Exclude demand replenishments     09/03/21 Brian Bent Added
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
          'No record found in floats table for route_no: ' || i_route_no,
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
          'Error when selecting distinct cross dock type from floats table',
          sqlcode,
          sqlerrm,
          APPLICATION_FUNC,
          PACKAGE_NAME
        );
        RAISE;
    END;

    IF r_floats_xdock_type != 'S' THEN
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
END pl_xdock_floats_info_out;
/

SHOW ERRORS;

GRANT EXECUTE ON SWMS.pl_xdock_floats_info_out TO SWMS_User;
