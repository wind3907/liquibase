/*******************************************************************************

  Package:
    pl_xdock_ordcw_out.sql

  Description:
    This package contains the functionality to transfer order catchweight
    information into staging table xdock_ordcw_out.

    Package is assumed idempotent, each run will send the current data
    to the respective staging tables.

    Order Catchweight Out is current intended to be grouped with the Floats
    and Float Detail staging tables and ran in package pl_xdock_floats_info_out.

  Modification History:

  Date        Designer  Comments
  ----------- --------- ------------------------------------------------------
  20-JUL-2021 mche6435  Initial version

*******************************************************************************/
CREATE OR REPLACE PACKAGE SWMS.pl_xdock_ordcw_out IS
  PROCEDURE process_xdock_ordcw_out(
    i_route_no  IN route.route_no%TYPE,
    i_batch_id  IN xdock_floats_out.batch_id%TYPE
  );
END pl_xdock_ordcw_out;
/

CREATE OR REPLACE PACKAGE BODY SWMS.pl_xdock_ordcw_out IS
  PACKAGE_NAME         CONSTANT  VARCHAR2(30 CHAR) := $$PLSQL_UNIT;
  APPLICATION_FUNC     CONSTANT  VARCHAR2(10)       := 'XDOCK';

  /*************************************************************************
    Procedure:
      process_xdock_ordcw_out

    Description:
      This function will add rows to the ordcw out table that are
      crossdock orders.

      Currently setup to run one at a time based on the route inserting all
      ordcw rows related to the route under one batch number.

    Parameters:
      i_route_no  -- Route number to use to select from the Float table
      i_batch_id  -- Batch ID to be applied to all inserts to xdock_ordcw_out

    Designer    date      version
    mche6435    07/20/21  v1.0
  **************************************************************************/
  PROCEDURE process_xdock_ordcw_out(
    i_route_no  IN route.route_no%TYPE,
    i_batch_id  IN xdock_floats_out.batch_id%TYPE
  ) IS
    l_proc_name   VARCHAR2(50) := 'process_xdock_ordcw_out';
  BEGIN
    pl_log.ins_msg('DEBUG', l_proc_name, 'Starting ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    INSERT INTO XDOCK_ORDCW_OUT(
      sequence_number,
      batch_id,
      record_status,
      route_no,
      order_id,
      order_line_id,
      seq_no,
      prod_id,
      cust_pref_vendor,
      catch_weight,
      cw_type,
      uom,
      cw_float_no,
      cw_scan_method,
      order_seq,
      case_id,
      cw_kg_lb,
      pkg_short_used,
      add_date,
      add_user
    )
    SELECT
      XDOCK_SEQNO_SEQ.nextval,
      i_batch_id,
      'N',
      i_route_no,
      cw.order_id,
      order_line_id,
      seq_no,
      prod_id,
      cust_pref_vendor,
      catch_weight,
      cw_type,
      uom,
      cw_float_no,
      cw_scan_method,
      order_seq,
      case_id,
      cw_kg_lb,
      pkg_short_used,
      SYSDATE,
      USER
    FROM ordcw cw
    LEFT JOIN ordm o ON o.order_id = cw.order_id
    WHERE o.route_no = i_route_no
    AND cross_dock_type = 'S';

    pl_log.ins_msg('DEBUG', l_proc_name, 'Ending ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_proc_name, 'Call to' || l_proc_name || 'failed', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
      RAISE;
  END process_xdock_ordcw_out;
END pl_xdock_ordcw_out;
/

SHOW ERRORS;

GRANT EXECUTE ON SWMS.pl_xdock_ordcw_out TO SWMS_User;
