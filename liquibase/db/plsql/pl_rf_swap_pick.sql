/*******************************************************************************

  Package:
    pl_rf_swap_pick

  Description:
    This package contains functions for the swap pick functionality.

  Modification History:

  Date        Designer  Comments
  ----------- --------- ------------------------------------------------------
  25-MAY-2021 mche6435  Initial version

*******************************************************************************/

CREATE OR REPLACE PACKAGE SWMS.pl_rf_swap_pick AS
  -- Swap pick main, entrypoint for all requests
  FUNCTION swap_pick_main(
    i_rf_log_init_record   IN rf_log_init_record,
    i_client               IN swap_pick_client_obj
  ) RETURN rf.status;

  FUNCTION swap_pick(
    i_task_id      IN replenlst.task_id%TYPE,
    i_scanned_data IN replenlst.src_loc%TYPE,
    i_scan_method  IN trans.scan_method1%TYPE,
    i_equip_id     IN equipment.equip_id%TYPE
  ) RETURN rf.status;

  FUNCTION swap_undo(
    i_task_id   IN replenlst.task_id%TYPE,
    i_equip_id  IN equipment.equip_id%TYPE
  ) RETURN rf.status;

  FUNCTION update_status(
    i_task_id            IN replenlst.task_id%TYPE,
    i_prod_id            IN replenlst.prod_id%TYPE,
    i_src_loc            IN replenlst.src_loc%TYPE,
    i_dest_loc           IN replenlst.dest_loc%TYPE,
    i_user_id            IN replenlst.user_id%TYPE,
    i_cust_pref_vendor   IN replenlst.cust_pref_vendor%TYPE,
    i_batch_no           IN replenlst.batch_no%TYPE,
    i_seq_no             IN replenlst.seq_no%TYPE,
    i_scan_method        IN trans.scan_method1%TYPE,
    i_qty                IN inv.qoh%TYPE,
    i_labor_batch_no     IN replenlst.labor_batch_no%TYPE,
    i_exp_date           IN inv.exp_date%TYPE,
    i_uom                IN inv.inv_uom%TYPE
  ) RETURN rf.status;

  FUNCTION perform_undo(
    i_batch_no   IN replenlst.batch_no%TYPE,
    i_user_id    IN replenlst.user_id%TYPE,
    i_equip_id   IN equipment.equip_id%TYPE
  ) RETURN rf.status;

  FUNCTION swap_pick_prechecks(
    i_task_id       IN replenlst.task_id%TYPE,
    i_scanned_data  IN replenlst.src_loc%TYPE
  ) RETURN rf.status;

  FUNCTION check_batch_started(
    i_batch_no  IN replenlst.batch_no%TYPE
  ) RETURN rf.status;

  FUNCTION labor_batch_login(
    i_user_id   IN batch.user_id%TYPE,
    i_batch_no  IN batch.batch_no%TYPE,
    i_equip_id  IN equipment.equip_id%TYPE
  ) RETURN rf.status;

  FUNCTION check_correct_sequence(
    i_seq_no    IN replenlst.seq_no%TYPE,
    i_batch_no  IN replenlst.batch_no%TYPE
  ) RETURN rf.status;
END pl_rf_swap_pick;
/

CREATE OR REPLACE PACKAGE BODY pl_rf_swap_pick AS
  ROW_LOCKED EXCEPTION;
  PRAGMA exception_init ( ROW_LOCKED, -54 );

  --- Global Declarations ---
  g_package_name        CONSTANT  VARCHAR2(30) := 'pl_rf_swap_pick';
  g_application_func    CONSTANT  VARCHAR2(1)  := 'I';

  /*************************************************************************
    Function:     swap_pick_main
    Description:  Entrypoint function for swap.

    Parameters:
    i_rf_log_init_record   -- RF meta data
    i_client               -- Input information from RF device

    Return Value:
      Dependant on other functions

    Designer    date      version
    mche6435    05/25/21  v1.0
  **************************************************************************/
  FUNCTION swap_pick_main(
    i_rf_log_init_record   IN rf_log_init_record,
    i_client               IN swap_pick_client_obj
  )
  RETURN rf.status AS
    l_func_name   VARCHAR2(50) := 'swap_pick_main';
    rf_status     rf.status := rf.STATUS_NORMAL;
  BEGIN
    rf_status := rf.initialize(i_rf_log_init_record);

    pl_log.ins_msg('INFO', l_func_name, 'Starting ' || l_func_name, sqlcode, sqlerrm, g_application_func, g_package_name);

    IF rf_status != rf.STATUS_NORMAL THEN
      pl_log.ins_msg('FATAL', l_func_name, 'RF init bad status.', sqlcode, sqlerrm, g_application_func, g_package_name);
    ELSE
      IF i_client.task_id IS NULL THEN
        pl_log.ins_msg('FATAL',l_func_name,'No task sent.', sqlcode, sqlerrm, g_application_func, g_package_name);

        RETURN rf.STATUS_DATA_ERROR;
      END IF;

      pl_log.ins_msg('INFO',l_func_name,'Message from CLIENT. task_id = '
        || i_client.task_id
        || ' equip_id = '
        || i_client.equip_id
        || ' scanned_data = '
        || i_client.scanned_data
        || ' func1_flag = '
        || i_client.func1_flag
        || ' scan_method = '
        || i_client.scan_method,sqlcode,sqlerrm, g_application_func, g_package_name);

      IF ( i_client.func1_flag = 'Y' ) THEN
        rf_status := swap_undo(i_client.task_id, i_client.equip_id);
      ELSE
        IF i_client.scanned_data IS NULL THEN
          pl_log.ins_msg('FATAL',l_func_name,'No scanned data.', sqlcode, sqlerrm, g_application_func, g_package_name);

          RETURN rf.STATUS_DATA_ERROR;
        END IF;
        -- Check if swap is runnable under these circumstances.
        rf_status := swap_pick_prechecks(i_client.task_id, i_client.scanned_data);

        IF rf_status = rf.STATUS_NORMAL THEN
          rf_status := swap_pick(i_client.task_id, i_client.scanned_data, i_client.scan_method, i_client.equip_id);
        END IF;
      END IF;
    END IF;

    -- Commit unless RF Status is bad
    IF rf_status = rf.STATUS_NORMAL THEN
      COMMIT;
    ELSE
      pl_text_log.ins_msg_async('WARN', l_func_name, 'Rolling back. Due to error.', sqlcode, sqlerrm, g_application_func, g_package_name);
      ROLLBACK;
    END IF;

    pl_log.ins_msg('INFO', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    rf.complete(rf_status);
    RETURN rf_status;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, ' Call to ' || l_func_name || ' failed ', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      ROLLBACK;
      RAISE;
  END swap_pick_main;

  /*************************************************************************
    Function:     swap_pick
    Description:  Begin steps for picking the pallet

    Parameters:
      i_task_id       -- Replenlst task id
      i_scanned_data  -- Source location of the task
      i_scan_method   -- Scan method used to get scanned data
      i_equip_id      -- ID of used Equipment

    Return Value:
      Dependant on other functions
      STATUS_SEL_RPL_FAIL      -- Replenishment select returned no results
      STATUS_REC_LOCK_BY_OTHER -- Row needed is locked
      STATUS_DATA_ERROR        -- Task ID given is invalid
      STATUS_SEL_INV_FAIL      -- Inv(inventory) table select failed
      STATUS_SEL_LOC_FAIL      -- Loc(location) Table select failed

    Designer    date      version
    mche6435    05/25/21  v1.0
  **************************************************************************/
  FUNCTION swap_pick(
    i_task_id      IN replenlst.task_id%TYPE,
    i_scanned_data IN replenlst.src_loc%TYPE,
    i_scan_method  IN trans.scan_method1%TYPE,
    i_equip_id     IN equipment.equip_id%TYPE
  ) RETURN rf.status AS
    l_func_name     VARCHAR2(50) := 'swap_pick';
    rf_status       rf.status := rf.status_normal;

    l_swap_task        replenlst%ROWTYPE; -- The targeted replenishment task
    l_user_id          replenlst.user_id%TYPE := REPLACE(UPPER(USER),'OPS$');
    l_src_inv_item     inv%ROWTYPE;
    l_src_inv_item_uom loc.uom%TYPE;
  BEGIN
    pl_log.ins_msg('INFO', l_func_name,
      'Starting ' || l_func_name
      || ', task_id: ' || i_task_id
      || ', scanned_data: ' || i_scanned_data
      || ', scan_method: ' || i_scan_method
      || ', equip_id: ' || i_equip_id,
    sqlcode, sqlerrm, g_application_func, g_package_name);

    -- Save and lock the target swap task for update
    pl_log.ins_msg('DEBUG', l_func_name, 'Fetching swap task from replenlst table', sqlcode, sqlerrm, g_application_func, g_package_name);
    BEGIN
      SELECT *
      INTO l_swap_task
      FROM replenlst
      WHERE type = 'SWP'
      AND status = 'NEW'
      AND task_id = i_task_id
      AND src_loc = i_scanned_data
      FOR UPDATE NOWAIT;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Task not found with given parameters.', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN RF.STATUS_SEL_RPL_FAIL;
      WHEN ROW_LOCKED THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Unable to lock task, task_id: ' || i_task_id, sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN RF.STATUS_REC_LOCK_BY_OTHER;
    END;

    rf_status := check_correct_sequence(l_swap_task.seq_no, l_swap_task.batch_no);

    IF rf_status != rf.STATUS_NORMAL THEN
      RETURN rf_status;
    END IF;

    pl_log.ins_msg('DEBUG', l_func_name, 'Fetching inv row from inv table', sqlcode, sqlerrm, g_application_func, g_package_name);
    BEGIN
      SELECT *
      INTO l_src_inv_item
      FROM inv
      WHERE logi_loc = plogi_loc
      AND logi_loc = l_swap_task.src_loc
      AND prod_id = l_swap_task.prod_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg(
          'FATAL',
          l_func_name,
          'No data found in inv table.'|| ' task_id: ' || i_task_id || ' prod_id: ' || l_swap_task.prod_id || ' source_location: ' || l_swap_task.src_loc,
          sqlcode,
          sqlerrm, g_application_func, g_package_name
        );
        RETURN rf.STATUS_SEL_INV_FAIL;
    END;

    pl_log.ins_msg(
      'DEBUG',
      l_func_name,
      'Fetching UOM from loc table. logi_loc: ' || l_swap_task.src_loc || ' prod_id: ' || l_swap_task.prod_id,
      sqlcode,
      sqlerrm,
      g_application_func,
      g_package_name
    );

    BEGIN
      SELECT uom
      INTO l_src_inv_item_uom
      FROM loc
      WHERE logi_loc = l_swap_task.src_loc
      AND prod_id = l_swap_task.prod_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('FATAL',
          l_func_name,
          'Failed to get UOM from the loc table, no data found.',
          sqlcode,
          sqlerrm,
          g_application_func,
          g_package_name);
        RETURN rf.STATUS_SEL_LOC_FAIL;
    END;

    rf_status := update_status(
      i_task_id,
      l_swap_task.prod_id,
      i_scanned_data,
      l_swap_task.dest_loc,
      l_user_id,
      l_swap_task.cust_pref_vendor,
      l_swap_task.batch_no,
      l_swap_task.seq_no,
      i_scan_method,
      l_src_inv_item.qoh,
      l_swap_task.labor_batch_no,
      l_src_inv_item.exp_date,
      l_src_inv_item_uom
    );

    IF rf_status != rf.STATUS_NORMAL THEN
      RETURN rf_status;
    END IF;

    -- Sign on to the labor batch
    rf_status := labor_batch_login(
      l_user_id,
      l_swap_task.labor_batch_no,
      i_equip_id
    );

    IF rf_status != rf.STATUS_NORMAL THEN
      RETURN rf_status;
    END IF;

    pl_log.ins_msg('INFO', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to ' || l_func_name || ' failed. ', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END swap_pick;

  /*************************************************************************
    Function:     update_status
    Description:  Pick up for replenlst swap

    Parameters:
    i_task_id            -- Task ID in replenlst
    i_prod_id            -- Product ID of the item
    i_src_loc            -- Source location of the item
    i_dest_loc           -- Destination location of the item
    i_user_id            -- User ID of the person who picked up the item
    i_cust_pref_vendor   -- Customer preferred vendor of the item
    i_batch_no           -- Batch number associated with the task
    i_seq_no             -- The sequence number of the SWAP task
    i_scan_method        -- The scan method used
    i_qty                -- The qty of the item
    i_labor_batch_no     -- Associated labor batch number on the batch table

    Return Value:
      STATUS_SEL_RPL_FAIL      -- Replenishment select returned no results
      STATUS_SWAP_BAD_SEQUENCE -- Swap pick is done out of order
      STATUS_REC_LOCK_BY_OTHER -- Unable to perform query, rows are locked

    Designer    date      version
    mche6435    05/25/21  v1.0
  **************************************************************************/
  FUNCTION update_status(
    i_task_id            IN replenlst.task_id%TYPE,
    i_prod_id            IN replenlst.prod_id%TYPE,
    i_src_loc            IN replenlst.src_loc%TYPE,
    i_dest_loc           IN replenlst.dest_loc%TYPE,
    i_user_id            IN replenlst.user_id%TYPE,
    i_cust_pref_vendor   IN replenlst.cust_pref_vendor%TYPE,
    i_batch_no           IN replenlst.batch_no%TYPE,
    i_seq_no             IN replenlst.seq_no%TYPE,
    i_scan_method        IN trans.scan_method1%TYPE,
    i_qty                IN inv.qoh%TYPE,
    i_labor_batch_no     IN replenlst.labor_batch_no%TYPE,
    i_exp_date           IN inv.exp_date%TYPE,
    i_uom                IN inv.inv_uom%TYPE
  ) RETURN rf.status AS
    l_func_name                 VARCHAR2(50) := 'update_status';
    rf_status                   rf.status := rf.STATUS_NORMAL;

    l_replen_type               replenlst.type%TYPE := 'SWP';
    l_suggested_task_priority   forklift_task_priority.priority%TYPE := '53';

    r_rowtrans                  trans%rowtype := NULL;
    l_create_trans_status       NUMBER;
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name,
      'Starting ' || l_func_name
      || ', task_id: ' || i_task_id
      || ', prod_id: ' || i_prod_id
      || ', src_loc: ' || i_src_loc
      || ', dest_loc: ' || i_dest_loc
      || ', user_id: ' || i_user_id
      || ', cust_pref_vendor: ' || i_cust_pref_vendor
      || ', batch_no: ' || i_batch_no
      || ', seq_no: ' || i_seq_no
      || ', scan_method: ' || i_scan_method
      || ', qty: ' || i_qty
      || ', labor_batch_no: ' || i_labor_batch_no
      || ', exp_date: ' || i_exp_date
      || ', uom: ' || i_uom,
    sqlcode, sqlerrm, g_application_func, g_package_name);

    BEGIN
      -- Change the status of the replenishment to trans_type: PIK
      -- Update the qty in the replenlst
      UPDATE replenlst
      SET status  = 'PIK',
          user_id = i_user_id,
          qty = i_qty
      WHERE task_id = i_task_id
      AND src_loc = i_src_loc
      AND seq_no = i_seq_no;
    EXCEPTION
      WHEN ROW_LOCKED THEN
        pl_log.ins_msg(
          'FATAL',
          l_func_name,
          'Row locked. Unable to update status task_id: ' || i_task_id,
          sqlcode,
          sqlerrm,
          g_application_func,
          g_package_name
        );
        RETURN rf.STATUS_REC_LOCK_BY_OTHER;
    END;

    INSERT INTO trans (
      trans_id,
      trans_type,
      trans_date,
      prod_id,
      src_loc,
      dest_loc,
      user_id,
      cmt,
      cust_pref_vendor,
      batch_no,
      replen_task_id,
      scan_method1,
      exp_date,
      qty,
      uom,
      labor_batch_no,
      replen_type,
      task_priority,
      suggested_task_priority,
      pallet_id
    )
    VALUES(
      trans_id_seq.NEXTVAL,
      'INS',
      SYSDATE,
      i_prod_id,
      i_src_loc,
      i_dest_loc,
      CONCAT('OPS$', i_user_id),
      'Picked: ' || i_src_loc,
      i_cust_pref_vendor,
      i_batch_no,
      i_task_id,
      i_scan_method,
      i_exp_date,
      i_qty,
      i_uom,
      i_labor_batch_no,
      l_replen_type,
      l_suggested_task_priority,
      l_suggested_task_priority,
      i_src_loc
    );

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN ROW_LOCKED THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Row Locked', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_REC_LOCK_BY_OTHER;
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to ' || l_func_name || ' failed ', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END update_status;

  /*************************************************************************
    Function:     swap_undo
    Description:  Sorts out the scope of tasks to undo

    Parameters:
      i_task_id    -- Task ID in replenlst
      i_location  -- Location of item from logi_loc in replenlst

    Return Value:
      STATUS_DATA_ERROR   -- Batch number is null
      STATUS_SEL_RPL_FAIL -- No data from replenlist

    Assumptions:
    - seq_no is unique per batch

    Designer    date      version
    mche6435    05/25/21  v1.0
  **************************************************************************/
  FUNCTION swap_undo(
    i_task_id   IN replenlst.task_id%TYPE,
    i_equip_id  IN equipment.equip_id%TYPE
  ) RETURN rf.status AS
    l_func_name   VARCHAR2(50) := 'swap_undo';
    rf_status     rf.status := rf.STATUS_NORMAL;

    l_batch_no replenlst.batch_no%TYPE;
  BEGIN
    pl_log.ins_msg('INFO', l_func_name, 'Starting ' || l_func_name || ' task_id: ' || i_task_id, sqlcode, sqlerrm, g_application_func, g_package_name);

    -- Check if task exists and get the batch_no
    BEGIN
      SELECT batch_no
      INTO l_batch_no
      FROM replenlst
      WHERE task_id = i_task_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('FATAL',
          l_func_name,
          'Task does not exist, task_id: ' || i_task_id,
          sqlcode,
          sqlerrm,
          g_application_func,
          g_package_name
        );
        RETURN rf.STATUS_SEL_RPL_FAIL;
    END;

    IF l_batch_no IS NULL THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Batch no. is NULL' || i_task_id , sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_DATA_ERROR;
    END IF;

    -- Check if the tasks has started
    rf_status := check_batch_started(l_batch_no);

    IF rf_status != rf.STATUS_NORMAL THEN
      pl_log.ins_msg(
        'WARN',
        l_func_name,
        'All tasks in batch are in NEW Status nothing to undo. Batch_no: ' || l_batch_no,
        sqlcode,
        sqlerrm,
        g_application_func,
        g_package_name
      );
      RETURN rf_status;
    END IF;

    rf_status := perform_undo(l_batch_no, REPLACE(UPPER(USER),'OPS$'), i_equip_id);

    RETURN rf_status;
  END swap_undo;

  /*************************************************************************
    Function:     perform_undo
    Description:  Undo's everything associated with a particular batch.

    Parameters:
      i_batch_no  -- Batch number of the tasks
      i_user_id   -- User ID
      i_equip_id  -- ID of equipment being used

    Return Value:
      STATUS_DATA_ERROR        -- Data missing in the trans or replenlst table
      STATUS_REC_LOCK_BY_OTHER -- A record is locked, unable to update.
      STATUS_RPL_UPDATE_FAIL   -- Failed to update replenlst
      STATUS_REC_LOCK_BY_OTHER -- Record is locked
      STATUS_DEL_TRANS_FAIL    -- Deleted too many or not enough trans records.

    Designer    date      version
    mche6435    05/25/21  v1.0
  **************************************************************************/
  FUNCTION perform_undo(
    i_batch_no   IN replenlst.batch_no%TYPE,
    i_user_id    IN replenlst.user_id%TYPE,
    i_equip_id   IN equipment.equip_id%TYPE
  )
  RETURN rf.status AS
    l_func_name       VARCHAR2(50) := 'perform_undo';
    rf_status         rf.status := rf.STATUS_NORMAL;

    l_affected_rows   NUMBER := 0;
    l_labor_active    lbr_func.create_batch_flag%TYPE;       -- Used to check if labor is on, if off this function is skipped.
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name,
      'Starting ' || l_func_name
      || ', labor batch no: ' || i_batch_no
      || ', user_id: ' || i_user_id
      || ', equip_id: ' || i_equip_id,
    sqlcode, sqlerrm, g_application_func, g_package_name);

    BEGIN
      SELECT create_batch_flag
      INTO l_labor_active
      FROM lbr_func
      WHERE lfun_lbr_func = 'SW';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('WARN', l_func_name, 'Swap labor flag is not found, defaulting to N', sqlcode, sqlerrm, g_application_func, g_package_name);
        l_labor_active := 'N';
    END;

    IF l_labor_active IS NOT NULL AND l_labor_active = 'Y' THEN
      -- Revert the labor batch
      pl_log.ins_msg(
        'DEBUG',
        l_func_name,
        'Calling pl_lm_fork.reset_op_forklift_batch for user:' || i_user_id || ' and equip_id: ' || i_equip_id, sqlcode,
        sqlerrm,
        g_application_func,
        g_package_name
      );

      rf_status := pl_lm_forklift.reset_swap_batch(i_user_id, i_equip_id);

      IF rf_status != rf.STATUS_NORMAL THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Failed to undo labor batch.', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf_status;
      END IF;
    ELSE
      pl_log.ins_msg(
        'DEBUG',
        l_func_name,
        'Create Batch Flag (SWP) = N. Not running labor batch undo',
        sqlcode,
        sqlerrm,
        g_application_func,
        g_package_name
      );
    END IF;

    -- Revert the replenlst
    pl_log.ins_msg('DEBUG', l_func_name, 'Reverting replenlst.', sqlcode, sqlerrm, g_application_func, g_package_name);
    BEGIN
      UPDATE replenlst
      SET
        status = 'NEW',
        user_id = NULL,
        qty = NULL
      WHERE batch_no = i_batch_no;

      l_affected_rows := SQL%ROWCOUNT;
      IF l_affected_rows < 1 AND l_affected_rows > 2 THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Not enough or too many trans records updated.', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf.STATUS_RPL_UPDATE_FAIL;
      END IF;
    EXCEPTION
      WHEN ROW_LOCKED THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Row locked, unable to undo task.', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf.STATUS_REC_LOCK_BY_OTHER;
      WHEN OTHERS THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Unknown Error. Unable to update replenlst.', sqlcode, sqlerrm, g_application_func, g_package_name);
        rf.logexception();
        RAISE;
    END;

    -- Reset just in case
    l_affected_rows := 0;

    -- Revert the transaction
    pl_log.ins_msg('DEBUG', l_func_name, 'Deleting trans entries.', sqlcode, sqlerrm, g_application_func, g_package_name);
    BEGIN
      DELETE trans
      WHERE (trans_type = 'INS' OR trans_type = 'SWP')
      AND batch_no = i_batch_no
      AND REPLACE(UPPER(user_id),'OPS$') = UPPER(i_user_id);

      l_affected_rows := SQL%ROWCOUNT;
      IF l_affected_rows < 1 AND l_affected_rows > 2 THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Not enough or too many trans records updated.', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf.STATUS_DEL_TRANS_FAIL;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Unknown Error. Unable to delete trans rows.', sqlcode, sqlerrm, g_application_func, g_package_name);
        rf_status := rf.STATUS_DEL_TRANS_FAIL;
        rf.logexception();
        RAISE;
    END;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'General exception in ' || l_func_name, sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END perform_undo;

  /*************************************************************************
    Function:     check_batch_started
    Description:  Checks if the swap batch has started

    Parameters:
      i_batch_no    -- Batch number in replenlst

    Return Value:
      STATUS_SWAP_BATCH_INACTIVE -- Batch is in NEW or HLD status
      STATUS_SEL_RPL_FAIL        -- Failed to find replen data

    Assumptions:
    - Sequence is not considered, will return if any task in the batch is
      not new.

    Designer    date      version
    mche6435    05/25/21  v1.0
  **************************************************************************/
  FUNCTION check_batch_started(
    i_batch_no  IN replenlst.batch_no%TYPE
  ) RETURN rf.status AS
    l_func_name     VARCHAR2(50) := 'check_batch_started';
    rf_status       rf.status := rf.STATUS_SWAP_BATCH_INACTIVE;

    CURSOR c_swap_tasks
    IS
      SELECT *
      FROM replenlst
      WHERE type = 'SWP'
      AND batch_no = i_batch_no
      ORDER BY seq_no ASC;

    r_swap_record   replenlst%ROWTYPE;
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name, 'Starting ' || l_func_name, sqlcode, sqlerrm, g_application_func, g_package_name);

    OPEN c_swap_tasks;
    LOOP
      FETCH c_swap_tasks INTO r_swap_record;
      EXIT WHEN c_swap_tasks%NOTFOUND;

      IF r_swap_record.status != 'NEW' AND r_swap_record.status != 'HLD' THEN
        rf_status := rf.STATUS_NORMAL;
        EXIT;
      END IF;
    END LOOP;
    CLOSE c_swap_tasks;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      pl_log.ins_msg('FATAL', l_func_name, 'No data found for batch_no: ' || i_batch_no, sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_SEL_RPL_FAIL;
    WHEN OTHERS THEN
        pl_log.ins_msg('FATAL', l_func_name, 'General exception. function' || l_func_name, sqlcode, sqlerrm, g_application_func, g_package_name);
        rf.logexception();
        RAISE;
  END;

  /*************************************************************************
    Function:     swap_pick_prechecks
    Description:  Requirements before a swap can be run. This method should
                  only block if the task is the first in the batch.

    Parameters:
      i_task_id        -- Task ID in replenlst
      i_scanned_data   -- The data scanned, this should be the src loc.

    Return Value:
      STATUS_SEL_RPL_FAIL -- Failed to retrieve record from replenlst

    Designer    date      version
    mche6435    05/25/21  v1.0
  **************************************************************************/
  FUNCTION swap_pick_prechecks(
    i_task_id       IN replenlst.task_id%TYPE,
    i_scanned_data  IN replenlst.src_loc%TYPE  -- The source location
  )
  RETURN rf.status AS
    l_func_name   VARCHAR2(50) := 'swap_pick_prechecks';
    rf_status     rf.status := rf.STATUS_NORMAL;

    l_dest_loc    replenlst.dest_loc%TYPE;

    l_seq_no      replenlst.seq_no%TYPE;
    l_batch_no    replenlst.batch_no%TYPE;
  BEGIN
    -- Check that swap is allowed to be run at this time.
    pl_log.ins_msg('DEBUG', l_func_name, 'Starting ' || l_func_name, sqlcode, sqlerrm, g_application_func, g_package_name);

    -- Get the dest loc for the swap so we can test it to see if there are active replens
    -- Also get the sequence number so that we can skip checks if it is not seq 1
    -- This also checks to see if the scanned data is correct
    BEGIN
      SELECT seq_no, dest_loc, batch_no
      INTO l_seq_no, l_dest_loc, l_batch_no
      FROM replenlst
      WHERE type = 'SWP'
      AND status = 'NEW'
      AND task_id = i_task_id
      AND src_loc = i_scanned_data;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg(
          'FATAL',
          l_func_name,
          'No data found, task_id: ' || i_task_id || ' src_loc: ' || i_scanned_data,
          sqlcode,
          sqlerrm,
          g_application_func,
          g_package_name
        );
        RETURN rf.STATUS_SEL_RPL_FAIL;
      WHEN OTHERS THEN
        pl_log.ins_msg(
          'FATAL',
          l_func_name,
          'Failed to get seq_no and dest_loc info for task_id: ' || i_task_id || ' src_loc: ' || i_scanned_data,
          sqlcode,
          sqlerrm,
          g_application_func,
          g_package_name
        );
        rf.logexception();
        RAISE;
    END;

    -- Do not block by time if current task is not the first one.
    IF l_seq_no = 1 THEN
      pl_log.ins_msg('DEBUG', l_func_name, 'Checking if swap is allowed at this time', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf_status := swms.pl_rf_swap_common.check_runnable_time;
    ELSE
      pl_log.ins_msg('DEBUG', l_func_name, 'Task is not first sequence, bypassing time requirement.', sqlcode, sqlerrm, g_application_func, g_package_name);
    END IF;


    IF rf_status != rf.STATUS_NORMAL THEN
      RETURN rf_status;
    END IF;

    -- Check each source location has no blockers
    FOR task in (
      SELECT src_loc
      FROM replenlst
      WHERE type = 'SWP'
      AND batch_no = l_batch_no
    ) LOOP
      -- Verify there are no current active replenishments
      rf_status := swms.pl_rf_swap_common.check_active_replenishments(task.src_loc); -- Assuming scanned data is the location information
      IF rf_status != rf.STATUS_NORMAL THEN
        RETURN rf_status;
      END IF;

      -- Verify that the inv rows are not allocated or planned
      rf_status := swms.pl_rf_swap_common.check_inv_updatable(task.src_loc);
      IF rf_status != rf.STATUS_NORMAL THEN
        RETURN rf_status;
      END IF;
    END LOOP;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to ' || l_func_name || ' failed. ', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END swap_pick_prechecks;

  /*************************************************************************
    Function:     labor_batch_login
    Description:  Login's to the labor batch.

    Parameters:
      i_user_id   -- User ID who is doing the work
      i_batch_no  -- Batch number of the swap task
      i_equip_id  -- Equip ID being used

    Return Value:
      Depends on labor functions

    Designer    date      version
    mche6435    05/25/21  v1.0
  **************************************************************************/
  FUNCTION labor_batch_login(
    i_user_id   IN batch.user_id%TYPE,
    i_batch_no  IN batch.batch_no%TYPE,
    i_equip_id  IN equipment.equip_id%TYPE
  ) RETURN rf.status AS
    l_func_name VARCHAR2(50) := 'labor_batch_login';
    rf_status   rf.status := rf.STATUS_NORMAL;

    l_labor_active      lbr_func.create_batch_flag%TYPE;       -- Used to check if labor is on, if off this function is skipped.
    l_parent_batch_no   batch.batch_no%TYPE := NULL;           -- Each task is independent therefore this is null.
    l_prev_batch_no     batch.batch_no%TYPE;                   -- Set from pl_rf_lm_common.lmc_batch_istart
    l_supervisor_id     batch.user_supervsr_id%TYPE;           -- Set from pl_rf_lm_common.lmc_batch_istart
    l_sign_on_type      VARCHAR2(10) := lmf.lmf_signon_batch;
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name,
      'Starting ' || l_func_name
      || ', user_id: ' || i_user_id
      || ', labor batch no: ' || i_batch_no
      || ', equip id: ' || i_equip_id,
    sqlcode, sqlerrm, g_application_func, g_package_name);

    BEGIN
      SELECT create_batch_flag
      INTO l_labor_active
      FROM lbr_func
      WHERE lfun_lbr_func = 'SW';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('WARN', l_func_name, 'Swap labor flag is not found, defaulting to N', sqlcode, sqlerrm, g_application_func, g_package_name);
        l_labor_active := 'N';
    END;

    IF l_labor_active IS NULL OR l_labor_active != 'Y' THEN
      -- Labor batches for swap are inactive, returning early.
      pl_log.ins_msg(
        'DEBUG',
        l_func_name,
        'Create Batch Flag (SWP) = N. Not running labor batch login',
        sqlcode,
        sqlerrm,
        g_application_func,
        g_package_name
      );
      RETURN rf.STATUS_NORMAL;
    END IF;

    rf_status := pl_rf_lm_common.lmc_batch_istart(i_user_id, l_prev_batch_no, l_supervisor_id);

    IF rf_status != rf.STATUS_NORMAL THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Failed to run lmc_batch_istart', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf_status;
    END IF;

    rf_status := pl_lm_forklift.lmf_signon_to_forklift_batch(l_sign_on_type, i_batch_no, l_parent_batch_no, i_user_id, l_supervisor_id, i_equip_id);

    IF rf_status != rf.STATUS_NORMAL THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Failed to run lmf_signon_to_forklift_batch', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf_status;
    END IF;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  END labor_batch_login;

  /*************************************************************************
    Function:    check_correct_sequence
    Description: Checks if the current given task is the next task

    Parameters:
      i_seq_no    Sequence number of the current task
      i_batch_no  Batch number of the current task

    Return Value:
      STATUS_SEL_RPL_FAIL -- Failed to find tasks given the batch number
      STATUS_SWAP_BAD_SEQUENCE -- Given sequence number is not the next task

    Designer    date      version
    mche6435    05/25/21  v1.0
  **************************************************************************/

  FUNCTION check_correct_sequence(
    i_seq_no    IN replenlst.seq_no%TYPE,
    i_batch_no  IN replenlst.batch_no%TYPE
  ) RETURN rf.status AS
    l_func_name VARCHAR2(50) := 'check_correct_sequence';
    rf_status   rf.status := rf.STATUS_NORMAL;

    l_first_sequence replenlst.seq_no%TYPE;
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name, 'Starting ' || l_func_name, sqlcode, sqlerrm, g_application_func, g_package_name);

    BEGIN
      -- Verify that the sequence is being done in the right order
      SELECT MIN(seq_no)
      INTO l_first_sequence
      FROM replenlst
      WHERE batch_no = i_batch_no
      AND type = 'SWP'
      AND status != 'CMP'; -- Check to make sure the first pallet is dropped (if current pallet is second)
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('FATAL', l_func_name, 'No tasks found. batch_no: ' || i_batch_no, sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf.STATUS_SEL_RPL_FAIL;
    END;

    -- EXIT: if swap is out of correct sequence
    IF i_seq_no IS NULL OR i_seq_no > l_first_sequence THEN
      pl_log.ins_msg(
        'WARN',
        l_func_name,
        'Previous swap task incomplete, current seq_no: ' || i_seq_no || ' First Sequence: ' || l_first_sequence,
        sqlcode,
        sqlerrm,
        g_application_func,
        g_package_name
      );
      RETURN rf.STATUS_SWAP_BAD_SEQUENCE;
    END IF;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);

    RETURN rf_status;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to' || l_func_name || 'failed', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END check_correct_sequence;
END pl_rf_swap_pick;
/

SHOW ERRORS;

GRANT EXECUTE ON SWMS.pl_rf_swap_pick TO SWMS_User;
