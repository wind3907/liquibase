/*******************************************************************************

  Package:
    pl_rf_swap_common

  Description:
    This package contains common functions for the swap functionality.

  Modification History:

  Date        Designer  Comments
  ----------- --------- ------------------------------------------------------
  25-MAY-2021 mche6435  Initial version

*******************************************************************************/

CREATE OR REPLACE PACKAGE SWMS.pl_rf_swap_common AS
  FUNCTION check_active_replenishments(
    i_location  IN replenlst.dest_loc%TYPE
  ) RETURN rf.status;

  FUNCTION check_runnable_time RETURN rf.status;

  FUNCTION check_inv_updatable(
    i_location  IN inv.plogi_loc%TYPE
  ) RETURN rf.status;
END pl_rf_swap_common;
/

SHOW ERRORS;

CREATE OR REPLACE PACKAGE BODY SWMS.pl_rf_swap_common AS
  ROW_LOCKED EXCEPTION;
  PRAGMA exception_init ( ROW_LOCKED, -54 );

  --- Global Declarations ---

  g_package_name        CONSTANT  VARCHAR2(30) := 'pl_rf_swap_common';
  g_application_func    CONSTANT  VARCHAR2(1)  := 'I';

  /*************************************************************************
    Function:     check_active_replenishments
    Description:  Check if any replenishment is active given a location

    Parameters:
      i_location  -- Physical location in the warehouse

    Return Value:
      STATUS_DMD_RPL_FOUND_IN_SWP  -- Demand Replenishment Found in the given locations
      STATUS_NDM_REL_FOUND_IN_SWP  -- Non Demand Replenishment Found in the given locations

    Designer    date      version
    mche6435    05/25/21  v1.0
  **************************************************************************/
  FUNCTION check_active_replenishments(
    i_location  IN replenlst.dest_loc%TYPE
  ) RETURN rf.status AS
    l_func_name   VARCHAR2(50) := 'check_active_replenishments';
    rf_status     rf.status := rf.STATUS_NORMAL;

    CURSOR c_active_replenishments
    IS
      SELECT *
      FROM replenlst
      WHERE type in ('DMD', 'NDM')
      AND dest_loc = i_location
      OR src_loc = i_location;

    r_replenishment         replenlst%ROWTYPE;
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name, 'Starting ' || l_func_name || ', location: ' || i_location, sqlcode, sqlerrm, g_application_func, g_package_name);
    -- Find if any active replenishments for a given location
    OPEN c_active_replenishments;
    LOOP
      FETCH c_active_replenishments INTO r_replenishment;
        EXIT WHEN c_active_replenishments%notfound;

      IF r_replenishment.type = 'DMD' THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Active DMD on location: ' || i_location, sqlcode, sqlerrm, g_application_func, g_package_name);
        rf_status := rf.STATUS_DMD_RPL_FOUND_IN_SWP;
        EXIT;
      END IF;

      IF r_replenishment.type = 'NDM' THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Active NDM on location: ' || i_location, sqlcode, sqlerrm, g_application_func, g_package_name);
        rf_status := rf.STATUS_NDM_REL_FOUND_IN_SWP;
        EXIT;
      END IF;
    END LOOP;
    CLOSE c_active_replenishments;

    pl_log.ins_msg(
      'DEBUG',
      l_func_name,
      'Ending ' || l_func_name || ', Location: ' || i_location || ', Status = ' || rf_status,
      sqlcode,
      sqlerrm,
      g_application_func,
      g_package_name
    );
    RETURN rf_status;
  END check_active_replenishments;

  /*************************************************************************
    Function:     check_inv_updatable
    Description:  Checks the inventory status' to check if we safely act on
                  the inventory

    Parameters:
      i_location   -- Location to check inventory qty.

    Return Value:
      STATUS_INV_HLD_FOUND_IN_SWP -- Inventory status is HLD.
      STATUS_INV_ALLOCATED_QTY    -- Inventory has allocated qty.
      STATUS_SEL_INV_FAIL         -- Failed to get data in inv

    Designer    date      version
    mche6435    05/25/21  v1.0
  **************************************************************************/

  FUNCTION check_inv_updatable(
    i_location  IN inv.plogi_loc%TYPE
  ) RETURN rf.status AS
    l_func_name     VARCHAR2(50) := 'check_inv_updatable';
    rf_status       rf.status := rf.STATUS_NORMAL;

    l_qty_alloc     inv.qty_alloc%TYPE;
    l_qty_planned   inv.qty_planned%TYPE;
    l_status        inv.status%TYPE;
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name, 'Starting ' || l_func_name || ', location: ' || i_location, sqlcode, sqlerrm, g_application_func, g_package_name);

    SELECT qty_alloc, qty_planned, status
    INTO l_qty_alloc, l_qty_planned, l_status
    FROM inv
    WHERE logi_loc = plogi_loc
    AND logi_loc = i_location;

    IF l_status = 'HLD' THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Inventory is in hld status. location: ' || i_location, sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_INV_HLD_FOUND_IN_SWP;
    END IF;

    IF l_qty_alloc != 0 OR l_qty_planned != 0 THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Inventory has qty alloc or planned is not 0. location: ' || i_location, sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_INV_ALLOCATED_QTY;
    END IF;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      pl_log.ins_msg('FATAL', l_func_name, 'No data found in inv table, location: ' || i_location, sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_SEL_INV_FAIL;
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to' || l_func_name || 'failed', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END check_inv_updatable;

  /*************************************************************************
    Function:     check_runnable_time
    Description:  SWAP is time locked to prevent row update collisions with
                  other processes. This function will verify if we can run
                  swaps.

    Parameters:

    Return Value:
      STATUS_OUTSIDE_SWAP_WINDOW  -- Outside allowed swap window

    Designer    date      version
    mche6435    05/25/21  v1.0
  **************************************************************************/
  FUNCTION check_runnable_time
  RETURN rf.status AS
    CURSOR c_swap_sys_pars
    IS
      SELECT *
      FROM sys_config
      WHERE CONFIG_FLAG_NAME in ('SWAP_WINDOW_START', 'SWAP_WINDOW_END');

    l_func_name                   VARCHAR2(50) := 'check_runnable_time';
    l_swap_window                 sys_config%ROWTYPE;

    l_swap_window_start           VARCHAR2(5); --DATE;
    l_swap_window_end             VARCHAR2(5); --DATE;

    l_swap_window_start_default   VARCHAR2(5) := '07:00';  -- 7 AM (DEFAULT)
    l_swap_window_end_default     VARCHAR2(5) := '17:00';  -- 5 PM (DEFAULT)

    l_current_time                VARCHAR2(5);

    rf_status                     rf.status := rf.STATUS_NORMAL;
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name, 'Starting ' || l_func_name, sqlcode, sqlerrm, g_application_func, g_package_name);

    -- Pull the values from System Parameters
    OPEN c_swap_sys_pars;
    LOOP
      FETCH c_swap_sys_pars INTO l_swap_window;
        EXIT WHEN c_swap_sys_pars%notfound;

      IF l_swap_window.config_flag_name = 'SWAP_WINDOW_START' THEN
        l_swap_window_start := l_swap_window.config_flag_val;
      END IF;

      IF l_swap_window.config_flag_name = 'SWAP_WINDOW_END' THEN
        l_swap_window_end := l_swap_window.config_flag_val;
      END IF;
    END LOOP;
    CLOSE c_swap_sys_pars;

    -- Set default values if System Parameters are not set
    IF l_swap_window_start IS NULL OR l_swap_window_end IS NULL THEN
      l_swap_window_start := l_swap_window_start_default;
      l_swap_window_end := l_swap_window_end_default;
    END IF;

    l_current_time := TO_CHAR(SYSDATE, 'HH24:MI');

    IF l_current_time NOT BETWEEN l_swap_window_start AND l_swap_window_end THEN
      pl_log.ins_msg('WARN', l_func_name, 'Outside of allowed Swap time.', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_OUTSIDE_SWAP_WINDOW;
    END IF;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf.STATUS_NORMAL;
  END check_runnable_time;
END pl_rf_swap_common;
/

SHOW ERRORS;

GRANT EXECUTE ON SWMS.pl_rf_swap_common TO SWMS_User;
