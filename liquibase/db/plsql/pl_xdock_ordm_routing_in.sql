/*******************************************************************************

  Package:
    pl_xdock_ordm_routing_in.sql

  Description:
    This package contains the functionality to transfer data from
    xdock_ordm_routing_in to the ordm table.

    Currently ran by a cron job to run every n minutes.

  Modification History:

  Date        Designer  Comments
  ----------- --------- ------------------------------------------------------
  27-JUL-2021 mche6435  Initial version

*******************************************************************************/
CREATE OR REPLACE PACKAGE SWMS.pl_xdock_ordm_routing_in IS
  PACKAGE_NAME         CONSTANT  VARCHAR2(30 CHAR) := $$PLSQL_UNIT;
  APPLICATION_FUNC     CONSTANT  VARCHAR2(30 CHAR) := 'XDOCK';

  PROCEDURE main_bulk;

  FUNCTION run_prechecks(
    i_delivery_document_id IN ordm.delivery_document_id%TYPE
  ) RETURN BOOLEAN;

  PROCEDURE update_tables(
    i_delivery_document_id  IN ordm.delivery_document_id%TYPE,
    i_site_to_route_no      IN ordm.site_to_route_no%TYPE,
    i_site_to_truck_no      IN ordm.site_to_truck_no%TYPE,
    i_site_to_stop_no       IN ordm.site_to_stop_no%TYPE
  );

  PROCEDURE log_error(
    i_delivery_document_id IN xdock_ordm_routing_in.delivery_document_id%TYPE,
    i_error_code           IN xdock_ordm_routing_in.error_code%TYPE,
    i_error_msg            IN xdock_ordm_routing_in.error_msg%TYPE,
    i_record_status        IN VARCHAR2
  );
END pl_xdock_ordm_routing_in;
/

CREATE OR REPLACE PACKAGE BODY      pl_xdock_ordm_routing_in IS
  /*************************************************************************
    Procedure:
      main_bulk

    Description:
      Main entrypoint procedure for bulk processing.

    Parameters:

    Designer    date      	version
    mche6435    07/26/21  	v1.0
	ECLA1411	11/09/2021	v1.1	OPCOF-3779 - LP Day 2 - Hold Site 2 Routing info until Site 1 routed
  **************************************************************************/
  PROCEDURE main_bulk AS
    l_proc_name VARCHAR2(50) := 'main';

    CURSOR c_xdock_ordm_routing_in IS
      SELECT
        delivery_document_id,
        route_no,
        truck_no,
        stop_no
      FROM XDOCK_ORDM_ROUTING_IN
      WHERE record_status = 'N' OR
		    (record_status = 'H' AND ADD_DATE > (SYSDATE - 2)); 
            -- OPCOF-3779 - LP Day 2 - Hold Site 2 Routing info until Site 1 routed
            -- Also check for records that were put on hold less than equal to 2 days old
  BEGIN
    pl_log.ins_msg('DEBUG', l_proc_name, 'Starting ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    pl_log.ins_msg('DEBUG', l_proc_name, 'Starting ordm_routing_in loop', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    -- Get all valid entries
    FOR r_xdock_ordm_routing_in IN c_xdock_ordm_routing_in
    LOOP
      BEGIN
        -- Run Pre Checks
        IF (run_prechecks(r_xdock_ordm_routing_in.delivery_document_id) = TRUE) THEN
			-- If prechecks pass update ordm and route
			-- Send the route_no, truck_no, stop_no as the site_to_ columns
			update_tables(
						  i_delivery_document_id => r_xdock_ordm_routing_in.delivery_document_id,
						  i_site_to_route_no     => r_xdock_ordm_routing_in.route_no,
						  i_site_to_truck_no     => r_xdock_ordm_routing_in.truck_no,
						  i_site_to_stop_no      => r_xdock_ordm_routing_in.stop_no);
		END IF;
      EXCEPTION
        WHEN OTHERS THEN
          pl_log.ins_msg(
            'WARN',
            l_proc_name,
            'Error when prechecking/updating. delivery_document_id: ' || r_xdock_ordm_routing_in.delivery_document_id,
            sqlcode,
            sqlerrm,
            APPLICATION_FUNC,
            PACKAGE_NAME
          );

          -- Log it to the error section
          log_error(r_xdock_ordm_routing_in.delivery_document_id, sqlcode, sqlerrm, 'F');
      END;
    END LOOP;

    pl_log.ins_msg('DEBUG', l_proc_name, 'Ending ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_proc_name, 'Call to ' || l_proc_name || ' failed.', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
      RAISE;
  END main_bulk;

  /*************************************************************************
    Procedure:
      run_prechecks

    Description:
      Precheck to see if the current entry can run.

    Designer    date      version
    mche6435    07/26/21  v1.0
  **************************************************************************/
  FUNCTION run_prechecks(i_delivery_document_id IN ordm.delivery_document_id%TYPE) RETURN BOOLEAN IS
    l_proc_name VARCHAR2(50) := 'run_prechecks';

    route_missing_or_closed          EXCEPTION;

    l_route_no  route.route_no%TYPE;
    l_route_count PLS_INTEGER;
  BEGIN
    pl_log.ins_msg('DEBUG', l_proc_name, 'Starting ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    -- Check if ORDM entry exists and get route_no if it does
    BEGIN
      SELECT route_no
      INTO l_route_no
      FROM ORDM
      WHERE delivery_document_id = i_delivery_document_id;
    EXCEPTION
      WHEN TOO_MANY_ROWS THEN
        pl_log.ins_msg('WARN', l_proc_name, 'Too many rows returned when retrieving route_no, expected 1: ' || i_delivery_document_id,
						sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
        RAISE_APPLICATION_ERROR(-20001, sqlerrm || 'Too many rows returned when retrieving route_no, expected 1: ' || i_delivery_document_id);
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('WARN', l_proc_name, 'No data found in ordm table, delivery_document_id: ' || i_delivery_document_id, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
		
		-- OPCOF-3779 - LP Day 2 - Hold Site 2 Routing info until Site 1 routed
        log_error(i_delivery_document_id, sqlcode, 'Record status set to HOLD', 'H');

		pl_log.ins_msg('WARN', l_proc_name, 'XDOCK_ORDM_ROUTING_IN record status set to HOLD', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
		
        RETURN FALSE;
        -- END - OPCOF-3779 - LP Day 2 - Hold Site 2 Routing info until Site 1 routed
    END;

    -- Check if Route is closed as we don't want to update if its already closed.
    BEGIN
      SELECT COUNT(1)
      INTO l_route_count
      FROM route
      WHERE route_no = l_route_no
      AND route.status != 'CLS';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg(
          'WARN',
          l_proc_name,
          'Route does not exist or is closed.',
          sqlcode,
          sqlerrm,
          APPLICATION_FUNC,
          PACKAGE_NAME
        );
        RAISE route_missing_or_closed;
    END;

    pl_log.ins_msg('DEBUG', l_proc_name, 'Ending ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
	
	RETURN TRUE;
  EXCEPTION
    WHEN route_missing_or_closed THEN
      pl_log.ins_msg(
        'WARN',
        l_proc_name,
        'Failed prechecks, delivery_document_id: ' || i_delivery_document_id,
        sqlcode,
        sqlerrm,
        APPLICATION_FUNC,
        PACKAGE_NAME
      );
      RAISE_APPLICATION_ERROR(-20001, sqlerrm || ' | Route does not exist with route_no: ' || l_route_no);
    WHEN OTHERS THEN
      pl_log.ins_msg(
        'WARN',
        l_proc_name,
        'Call to ' || l_proc_name || ' failed. delivery_document_id: ' || i_delivery_document_id,
        sqlcode,
        sqlerrm,
        APPLICATION_FUNC,
        PACKAGE_NAME
      );
      RAISE;
  END run_prechecks;

  /*************************************************************************
    Procedure:
      update_tables

    Description:
      Updates the ORDM table using the data from the xdock_ordm_routing_in table.

    Designer    date      version
    mche6435    07/26/21  v1.0
  	ECLA1411	11/09/2021	v1.1	OPCOF-3779 - LP Day 2 - Hold Site 2 Routing info until Site 1 routed
**************************************************************************/
  PROCEDURE update_tables(
    i_delivery_document_id  IN ordm.delivery_document_id%TYPE,
    i_site_to_route_no      IN ordm.site_to_route_no%TYPE,
    i_site_to_truck_no      IN ordm.site_to_truck_no%TYPE,
    i_site_to_stop_no       IN ordm.site_to_stop_no%TYPE
  ) AS
    l_proc_name VARCHAR2(50) := 'update_tables';

    l_rows_changed INTEGER;
  BEGIN
    pl_log.ins_msg('DEBUG', l_proc_name, 'Starting ' || l_proc_name || ', delivery_document_id: ' || i_delivery_document_id
					|| ', site_to_route_no: ' || i_site_to_route_no || ', site_to_truck_no: ' || i_site_to_truck_no || ', site_to_stop_no: '  || i_site_to_stop_no,
					sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    UPDATE ORDM
    SET site_to_route_no = i_site_to_route_no,
        site_to_truck_no = i_site_to_truck_no,
        site_to_stop_no  = i_site_to_stop_no
    WHERE delivery_document_id = i_delivery_document_id;

    l_rows_changed := SQL%ROWCOUNT;

    IF l_rows_changed = 0 THEN
      pl_log.ins_msg('WARN', l_proc_name, 'No ORDM rows were updated, expected 1. delivery_document_id: ' || i_delivery_document_id, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

	  -- OPCOF-3779 - LP Day 2 - Hold Site 2 Routing info until Site 1 routed
      pl_log.ins_msg('WARN', l_proc_name, 'XDOCK_ORDM_ROUTING_IN record status set to HOLD', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
  	  log_error(i_delivery_document_id, sqlcode, 'Record status set to HOLD', 'H');
      -- END - OPCOF-3779 - LP Day 2 - Hold Site 2 Routing info until Site 1 routed

    ELSIF l_rows_changed > 1 THEN
      pl_log.ins_msg('WARN', l_proc_name, 'More ORDM rows were updated than expected. Updated: ' || l_rows_changed || ' expected: 1 |' || ' delivery_document_id: ' || i_delivery_document_id,
					sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
    ELSE
      -- Update xdock_ordm_routing_in status only if ordm was updated.
      pl_log.ins_msg('DEBUG', l_proc_name, 'Updating xdock_ordm_routing_in record status. delivery_document_id: ' || i_delivery_document_id,
					sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

      UPDATE XDOCK_ORDM_ROUTING_IN
      SET record_status = 'S'
      WHERE delivery_document_id = i_delivery_document_id;

      IF SQL%ROWCOUNT = 0 THEN
        pl_log.ins_msg('WARN', l_proc_name, 'No XDOCK_ORDM_ROUTING_IN rows were updated. Expected 1. delivery_document_id: ' || i_delivery_document_id,
          sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

        RAISE_APPLICATION_ERROR(-20001, 'No XDOCK_ORDM_ROUTING_IN rows were updated. Expected 1. delivery_document_id: ' || i_delivery_document_id);
      END IF;
    END IF;

    pl_log.ins_msg('DEBUG', l_proc_name, 'Ending ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('WARN', l_proc_name, 'Call to ' || l_proc_name || ' failed.', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
      RAISE;
  END update_tables;

  /*************************************************************************
    Procedure:
      log_error

    Description:
      Logs the error into the staging table under the error sections and
      sets the status to fail.

    Designer    date      version
    mche6435    08/10/21  v1.0
  **************************************************************************/
  PROCEDURE log_error(
    i_delivery_document_id IN xdock_ordm_routing_in.delivery_document_id%TYPE,
    i_error_code           IN xdock_ordm_routing_in.error_code%TYPE,
    i_error_msg            IN xdock_ordm_routing_in.error_msg%TYPE,
    i_record_status        IN VARCHAR2) AS
    l_proc_name VARCHAR2(50) := 'log_error';

    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    pl_log.ins_msg('DEBUG', l_proc_name, 'Starting ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    UPDATE xdock_ordm_routing_in
    SET error_code = i_error_code,
        error_msg  = i_error_msg,
        record_status = i_record_status
    WHERE delivery_document_id = i_delivery_document_id;
    COMMIT;

    pl_log.ins_msg('DEBUG', l_proc_name, 'Ending ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_proc_name, 'Call to ' || l_proc_name || ' failed.', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
  END log_error;
END pl_xdock_ordm_routing_in;
/

SHOW ERRORS;

GRANT EXECUTE ON SWMS.pl_xdock_ordm_routing_in TO SWMS_User;

CREATE OR REPLACE PUBLIC SYNONYM pl_xdock_ordm_routing_in FOR SWMS.pl_xdock_ordm_routing_in;
