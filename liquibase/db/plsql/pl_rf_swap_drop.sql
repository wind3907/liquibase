/*******************************************************************************

  Package:
    pl_rf_swap_drop

  Description:
    This package containers functions for the swap drop functionality.

  Modification History:

  Date        Designer  Comments
  ----------- --------- ------------------------------------------------------
  25-MAY-2021 mche6435  Initial version

*******************************************************************************/

CREATE OR REPLACE PACKAGE SWMS.pl_rf_swap_drop AS
  -- Swap Drop main, entrypoint for all requests
  FUNCTION swap_drop_main(
    i_rf_log_init_record   IN   rf_log_init_record,
    i_client               IN   swap_drop_client_obj,
    o_replen_list          OUT  swap_drop_replen_list_obj,
    o_next_task            OUT  swap_drop_next_task_obj
  ) RETURN rf.status;

  FUNCTION swap_drop(
    i_client        IN   swap_drop_client_obj,
    o_replen_list   OUT  swap_drop_replen_list_obj,
    o_next_task     OUT  swap_drop_next_task_obj
  ) RETURN rf.status;

  FUNCTION finalize_swap(
    i_loc1   IN loc.logi_loc%TYPE,
    i_loc2   IN loc.logi_loc%TYPE
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
    i_scan_method2       IN trans.scan_method2%TYPE
  ) RETURN rf.status;

  FUNCTION update_cycle_counts(
    i_loc1      IN whmveloc_hist.oldloc%TYPE,
    i_loc2      IN whmveloc_hist.oldloc%TYPE,
    i_prod_id2   IN pm.prod_id%TYPE,
    i_cpv2       IN pm.cust_pref_vendor%TYPE
  ) RETURN rf.status;

  FUNCTION swap_location(
    i_prod_id1  IN loc.prod_id%TYPE,
    i_cpv1      IN loc.cust_pref_vendor%TYPE,
    i_rank1     IN loc.rank%TYPE,
    i_uom1      IN loc.uom%TYPE,
    i_loc1      IN loc.logi_loc%TYPE,
    i_prod_id2  IN loc.prod_id%TYPE,
    i_cpv2      IN loc.cust_pref_vendor%TYPE,
    i_rank2     IN loc.rank%TYPE,
    i_uom2      IN loc.uom%TYPE,
    i_loc2      IN loc.logi_loc%TYPE
  ) RETURN rf.status;

  FUNCTION swap_cc_home_tasks(
    i_loc1  IN cc.logi_loc%TYPE,
    i_loc2  IN cc.logi_loc%TYPE
  ) RETURN rf.status;

  FUNCTION swap_cc_home_adjs(
    i_loc1   IN loc.logi_loc%TYPE,
    i_loc2   IN loc.logi_loc%TYPE
  ) RETURN rf.status;

  FUNCTION swap_warehouse_move(
    i_loc1       IN whmveloc_hist.oldloc%TYPE,
    i_prod_id1   IN pm.prod_id%TYPE,
    i_loc2       IN whmveloc_hist.oldloc%TYPE,
    i_prod_id2   IN pm.prod_id%TYPE
  ) RETURN rf.status;

  FUNCTION swap_inventory(
    i_loc1   IN inv.logi_loc%TYPE,
    i_loc2   IN inv.logi_loc%TYPE
  ) RETURN rf.status;

  FUNCTION sync_pm_with_loc(
    i_prod_id   IN loc.prod_id%TYPE,
    i_cpv       IN loc.cust_pref_vendor%TYPE,
    i_location  IN loc.logi_loc%TYPE,
    i_uom       IN loc.uom%TYPE
  ) RETURN rf.status;

  FUNCTION verify_task_matches_inv(
    i_batch_no  IN replenlst.batch_no%TYPE,
    i_src_loc   IN inv.logi_loc%TYPE,
    i_dest_loc  IN inv.logi_loc%TYPE
  ) RETURN rf.status;
END pl_rf_swap_drop;
/

CREATE OR REPLACE PACKAGE BODY pl_rf_swap_drop AS
	ROW_LOCKED EXCEPTION;
  PRAGMA exception_init ( ROW_LOCKED, -54 );

  --- Global Declarations ---

  g_package_name        CONSTANT  VARCHAR2(30)     := 'pl_rf_swap_drop';
  g_application_func    CONSTANT  VARCHAR2(1)      := 'I';

  /*************************************************************************
    Function:     swap_drop_main
    Description:  Entrypoint function for swap drop package, handles the RF
                  initialization and completion

    Parameters:
      i_rf_log_init_record   -- rf_log_init_record,
      i_client               -- Data sent form client,
      o_replen_list        -- Cursor containing post drop replen lst,
      o_next_task            -- Contains data for the RF screen if there is
                                a next task to be performed.

    Return Value:
      Relays the RF Status of other calls.

    Designer		date			version
    mche6435	  05/25/21	v1.0
  **************************************************************************/

  FUNCTION swap_drop_main(
    i_rf_log_init_record   IN   rf_log_init_record,
    i_client               IN   swap_drop_client_obj,
    o_replen_list          OUT  swap_drop_replen_list_obj,
    o_next_task            OUT  swap_drop_next_task_obj
  )
  RETURN rf.status AS
    l_func_name   VARCHAR2(50) := 'swap_drop_main';
    rf_status     rf.status := rf.STATUS_NORMAL;
  BEGIN
    rf_status := rf.initialize(i_rf_log_init_record);
    pl_log.ins_msg('INFO', l_func_name, 'Starting ' || l_func_name, sqlcode, sqlerrm, g_application_func,  g_package_name);

    IF rf_status = rf.STATUS_NORMAL THEN
      pl_log.ins_msg('INFO',l_func_name,'Message from CLIENT. equip_id = '
        ||i_client.equip_id
        ||' include_bulkpull = '
        ||i_client.include_bulkpull
        ||' include_replen = '
        ||i_client.include_replen
        ||' from_aisle = '
        ||i_client.from_aisle
        ||' to_aisle = '
        ||i_client.to_aisle
        ||' task_id = '
        ||i_client.task_id
        ||' scanned_data = '
        ||i_client.scanned_data
        ||' scan_method = '
        ||i_client.scan_method
        ||' proximity = '
        ||i_client.proximity
        ||' location = '
        ||i_client.location,sqlcode,sqlerrm, g_application_func, g_package_name);

      rf_status := swap_drop(i_client, o_replen_list, o_next_task);
    ELSE
      pl_log.ins_msg('FATAL', l_func_name, 'swap_drop_main: rf initialize failed', sqlcode, sqlerrm, g_application_func, g_package_name);
    END IF;

    -- No task     = Replen list returned is empty still successful
    -- No new task = no change in replen list
    IF rf_status = rf.STATUS_NORMAL OR rf_status = rf.STATUS_NO_NEW_TASK OR rf_status = rf.STATUS_NO_TASK THEN
      COMMIT;
    ELSE
      pl_log.ins_msg('WARN', l_func_name, 'Rolling back. Due to error. rf_status: ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
      ROLLBACK;
    END IF;

    pl_log.ins_msg('INFO', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm);
    rf.complete(rf_status);
    RETURN rf_status;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, ' Call to ' || l_func_name || ' failed.', sqlcode, sqlerrm);
      rf.logexception();
      ROLLBACK;
      RAISE;
  END swap_drop_main;

  /*************************************************************************
    Function:     swap_drop
    Description:  Main function for actual swap drop.

    Parameters:
      i_client       -- Client Data
      o_replen_list  -- Replen list return object (If last drop)
      o_next_task    -- Next task return object (If not last drop)

    Return Value:
      STATUS_NOT_IN_PM_TABLE   -- prod_id and cust_pref_vendor not found in pm table
      STATUS_NOT_PIK_YET       -- Can't drop because task is not picked yet
      STATUS_NO_TASK           -- Task id is NULL or 0
      STATUS_SEL_RPL_FAIL      -- No data in replenlst found given parameters
      STATUS_SEL_INV_FAIL      -- No data in inv found given parameters
      STATUS_NO_NEW_TASK       -- from p_populatereplenlist from replen_list,
                                  Caching, theres no new task from before
      STATUS_DATA_ERROR        -- Logic failure somewhere
      STATUS_REC_LOCK_BY_OTHER -- Record is locked by someone else
      STATUS_DATA_ERROR        -- General error, needs back end help to correct
      STATUS_NOT_IN_PM_TABLE   -- Item is not in the PM table

    Designer		date			version
    mche6435	  05/25/21	v1.0
  **************************************************************************/
  FUNCTION swap_drop(
    i_client        IN   swap_drop_client_obj,
    o_replen_list   OUT  swap_drop_replen_list_obj,
    o_next_task     OUT  swap_drop_next_task_obj
  ) RETURN rf.status AS
    l_func_name               VARCHAR2(50) := 'swap_drop';
    rf_status                 rf.status := rf.STATUS_NORMAL;

    l_swap_task               replenlst%ROWTYPE;    -- The targeted swap task

    l_first_swap_task         replenlst%ROWTYPE; -- First swap task in the batch sequence
    l_final_swap_task         replenlst%ROWTYPE; -- The last task in the batch sequence
    l_final_swap_task_desc    pm.descrip%TYPE;
    l_final_swap_task_mfg_id  pm.mfg_sku%TYPE;
    l_final_swap_task_qoh     inv.qoh%TYPE;


    c_replen_list             SYS_REFCURSOR;

    -- Used to be a record type to pull from dynamic query cursor
    TYPE replen_list_rec IS RECORD (
      task_id          replenlst.task_id%TYPE,
      type             replenlst.type%TYPE,
      src_loc          replenlst.src_loc%TYPE,
      dest_loc         replenlst.dest_loc%TYPE,
      pallet_id        replenlst.pallet_id%TYPE,
      priority         replenlst.priority%TYPE,
      qty              replenlst.qty%TYPE,
      prod_id          replenlst.prod_id%TYPE,
      cpv              replenlst.cust_pref_vendor%TYPE,
      descrip          pm.descrip%TYPE,
      mfg_id           pm.mfg_sku%TYPE,
      truck_no         replenlst.truck_no%TYPE,
      door_no          replenlst.door_no%TYPE,
      drop_qty         replenlst.drop_qty%TYPE,
      blocked          VARCHAR2(1)   -- Swap blocked if replen/inv change is happening.
    );

    l_no_records      NUMBER(4);

    r_replen_list     replen_list_rec;

    t_replen_list     swap_drop_replen_list_table := swap_drop_replen_list_table();
  BEGIN
    pl_log.ins_msg('INFO', l_func_name,
      'Starting ' || l_func_name
      || ', task_id: ' || i_client.task_id
      || ', scanned_data: ' || i_client.scanned_data
      || ', scan_method: ' || i_client.scan_method,
    sqlcode, sqlerrm, g_application_func, g_package_name);

    -- Save, lock, and verify existance of the swap task
    -- Return no_task if no task is found
    IF i_client.task_id = 0 OR i_client.task_id IS NULL THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Task ID is 0 or null, task_id: ', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN RF.STATUS_DATA_ERROR;
    END IF;

    BEGIN
      SELECT *
      INTO l_swap_task
      FROM replenlst
      WHERE type = 'SWP'
      AND task_id = i_client.task_id
      AND dest_loc = i_client.scanned_data
      FOR UPDATE NOWAIT;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Task not found with given parameters', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN RF.STATUS_SEL_RPL_FAIL;
      WHEN ROW_LOCKED THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Unable to lock task, task_id: ' || i_client.task_id, sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN RF.STATUS_REC_LOCK_BY_OTHER;
      WHEN OTHERS THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Failed to get swap task in ' || l_func_name, sqlcode, sqlerrm, g_application_func, g_package_name);
        rf.logexception();
        RAISE;
    END;

    IF l_swap_task.status = 'NEW' THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Task not in PIK status.', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_NOT_PIK_YET;
    END IF;

    IF l_swap_task.status != 'PIK' THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Invalid replen task status. status: ' || l_swap_task.status, sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_DATA_ERROR;
    END IF;

    -- Update replenlst and trans table to show task is "dropped"
    rf_status := update_status(
      l_swap_task.task_id,
      l_swap_task.prod_id,
      l_swap_task.src_loc,
      l_swap_task.dest_loc,
      REPLACE(UPPER(USER),'OPS$'),
      l_swap_task.cust_pref_vendor,
      l_swap_task.batch_no,
      l_swap_task.seq_no,
      i_client.scan_method
    );

    IF rf_status != rf.STATUS_NORMAL THEN
      RETURN rf_status;
    END IF;

    /***********************************
    * IF scanned task is the last task *
    *     - update inventory           *
    *     - return replen list         *
    * ELSE                             *
    *     - return the next task       *
    ************************************/
    pl_log.ins_msg('DEBUG', l_func_name, 'Getting last task record from replenlst', sqlcode, sqlerrm, g_application_func, g_package_name);
    BEGIN
      SELECT *
      INTO l_final_swap_task
      FROM (
          SELECT *
          FROM replenlst
          WHERE type = 'SWP'
          AND batch_no = l_swap_task.batch_no
          ORDER BY seq_no DESC
      ) WHERE rownum = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Missing sequence data for batch_no: ' || l_swap_task.batch_no, sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN RF.STATUS_SEL_RPL_FAIL;
      WHEN OTHERS THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Failed to get the last task in the sequence.', sqlcode, sqlerrm, g_application_func, g_package_name);
        rf.logexception();
        RAISE;
    END;

    IF rf_status = rf.STATUS_NORMAL AND l_swap_task.seq_no = l_final_swap_task.seq_no THEN
      -- Task is the last task.
      pl_log.ins_msg('INFO', l_func_name, 'Last swap task in seq.', sqlcode, sqlerrm, g_application_func, g_package_name);

      rf_status := verify_task_matches_inv(l_swap_task.batch_no, l_swap_task.src_loc, l_swap_task.dest_loc);

      IF rf_status != rf.STATUS_NORMAL THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Replenlst task count does not equal the amount of inventory moved.', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf_status;
      END IF;


      /*
        Finalize swap using the src and dest loc of the first task.
        This is because the second swap task might not exist.
      */

      BEGIN
        SELECT *
        INTO l_first_swap_task
        FROM replenlst
        WHERE batch_no = l_swap_task.batch_no
        AND seq_no = 1;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          pl_log.ins_msg('FATAL', l_func_name, 'Unable to find the first task in sequence in replenlst table', sqlcode, sqlerrm, g_application_func, g_package_name);
          RETURN rf.STATUS_SEL_RPL_FAIL;
      END;

      rf_status := finalize_swap(l_first_swap_task.src_loc, l_first_swap_task.dest_loc);

      IF rf_status != rf.STATUS_NORMAL THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Failed to finalize swap.', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf_status;
      END IF;

      -- Get the updated replenlst.
      pl_log.ins_msg('INFO', l_func_name, 'Generating new replenlst.', sqlcode, sqlerrm, g_application_func, g_package_name);

      pl_rf_replen_list.p_populatereplenlist(
        'N',
        i_client.task_id,
        i_client.include_bulkpull,
        i_client.include_replen,
        i_client.from_aisle,
        i_client.to_aisle,
        i_client.proximity,
        i_client.location,
        'N',
        rf_status,
        c_replen_list
      );

      pl_log.ins_msg('INFO', l_func_name, 'p_populatereplenlist called', sqlcode, sqlerrm, g_application_func, g_package_name);

      IF rf_status = rf.STATUS_NO_NEW_TASK THEN
        -- CASE: Replen list is not different
        -- l_numrows is counted in the java wrapper associated due to the inefficient counting methods in plsql
        pl_log.ins_msg('DEBUG', l_func_name, 'Replen list has no new task.', sqlcode, sqlerrm, g_application_func, g_package_name);

        o_replen_list := swap_drop_replen_list_obj(0, t_replen_list);
      ELSIF rf_status = rf.STATUS_NO_TASK THEN
        -- CASE: Replen list is completely empty.
        pl_log.ins_msg('DEBUG', l_func_name, 'Replen list has no task at all.', sqlcode, sqlerrm, g_application_func, g_package_name);

        o_replen_list := swap_drop_replen_list_obj(0, t_replen_list);
      ELSIF rf_status != rf.STATUS_NORMAL THEN
        -- CASE: replen list had an error
        pl_log.ins_msg('FATAL', l_func_name, 'Error populating replenlst. rf_status: ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf_status;
      ELSE
        -- CASE: Replen List created a new list.
        -- Convert the Ref Cursor into an object table.
        BEGIN
          pl_log.ins_msg('INFO', l_func_name, 'Inserting Cursor into recordtype.', sqlcode, sqlerrm, g_application_func, g_package_name);
          LOOP
            FETCH c_replen_list INTO r_replen_list;
            EXIT WHEN c_replen_list%NOTFOUND;

            t_replen_list.extend();
            t_replen_list(t_replen_list.last) := swap_drop_replen_list_rec(
              task_id   =>    r_replen_list.task_id,
              type      =>    r_replen_list.type,
              src_loc   =>    r_replen_list.src_loc,
              dest_loc  =>    r_replen_list.dest_loc,
              pallet_id =>    r_replen_list.pallet_id,
              priority  =>    r_replen_list.priority,
              qty       =>    r_replen_list.qty,
              prod_id   =>    r_replen_list.prod_id,
              cpv       =>    r_replen_list.cpv,
              descrip   =>    r_replen_list.descrip,
              mfg_id    =>    r_replen_list.mfg_id,
              truck_no  =>    r_replen_list.truck_no,
              door_no   =>    r_replen_list.door_no,
              drop_qty  =>    r_replen_list.drop_qty,
              blocked   =>    r_replen_list.blocked
            );
          END LOOP;

          pl_log.ins_msg('INFO', l_func_name, 'Inserting Row Count of: ' || l_no_records, sqlcode, sqlerrm, g_application_func, g_package_name);
          l_no_records := c_replen_list%ROWCOUNT;
        EXCEPTION
          WHEN OTHERS THEN
            pl_log.ins_msg('FATAL', l_func_name, 'Bulk collect into t_replen_list failed.', sqlcode, sqlerrm, g_application_func, g_package_name);
            rf.logexception();
            RAISE;
        END;

        pl_log.ins_msg('INFO', l_func_name, 'Replen List Fetched', sqlcode, sqlerrm, g_application_func, g_package_name);
        o_replen_list := swap_drop_replen_list_obj(
          no_of_records => l_no_records,
          replen_list   => t_replen_list
        );
      END IF;
    ELSE
      -- CASE: Sequence is not the last task in batch so return the next batch
      pl_log.ins_msg('INFO', l_func_name, 'Next task: ' || l_final_swap_task.task_id, sqlcode, sqlerrm, g_application_func, g_package_name);
      -- Return without replenlst but add next task details
      BEGIN
        SELECT descrip, mfg_sku
        INTO l_final_swap_task_desc, l_final_swap_task_mfg_id
        FROM pm
        WHERE prod_id = l_final_swap_task.prod_id
        AND cust_pref_vendor = l_final_swap_task.cust_pref_vendor;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          pl_log.ins_msg('FATAL', l_func_name,
            'replen_task: ' || l_final_swap_task.task_id
            || ' | Missing data for prod_id: ' || l_final_swap_task.prod_id
            || ' cust_pref_vendor: ' || l_final_swap_task.cust_pref_vendor,
          sqlcode, sqlerrm, g_application_func, g_package_name);
          RETURN rf.STATUS_NOT_IN_PM_TABLE;
      END;

      -- Get quantity for the RF Screen
      -- Quantity is probably not correct in the replenlst so get it from inventory.
      BEGIN
        SELECT qoh
        INTO l_final_swap_task_qoh
        FROM inv
        WHERE plogi_loc = logi_loc
        AND logi_loc = l_final_swap_task.src_loc;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          pl_log.ins_msg('FATAL', l_func_name, 'No data found, logi_loc: ' || l_final_swap_task.src_loc, sqlcode, sqlerrm, g_application_func, g_package_name);
          RETURN rf.STATUS_SEL_INV_FAIL;
      END;

      o_next_task := swap_drop_next_task_obj(
        l_final_swap_task.task_id,
        l_final_swap_task.type,
        l_final_swap_task.src_loc,
        l_final_swap_task.dest_loc,
        l_final_swap_task_qoh,
        l_final_swap_task.prod_id,
        l_final_swap_task.cust_pref_vendor,
        l_final_swap_task_desc,
        l_final_swap_task_mfg_id
      );
    END IF;

    pl_log.ins_msg('INFO', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to ' || l_func_name || ' failed.', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END swap_drop;

  /*************************************************************************
    Function:     update_status
    Description:  Function containing steps for confirming pallet drop
                  which updates the replenlst and trans table. This function
                  does not update the inventory.

    Parameters:
      i_task_id           -- Task Id
      i_prod_id           -- Product Id
      i_src_loc           -- Source Location
      i_dest_loc          -- Destination location
      i_user_id           -- User Id
      i_cust_pref_vendor  -- Customer Preferred Vendor
      i_batch_no          -- Batch Number
      i_seq_no            -- Sequence Number
      i_scan_method2      -- Scan method for trans table

    Return Value:
      STATUS_TRN_UPDATE_FAIL   -- Unable to update the trans table.
      STATUS_SEL_RPL_FAIL      -- No data found in replnlst with given data
      STATUS_NO_TASK           -- Task id is null or 0
      STATUS_REC_LOCK_BY_OTHER -- Record is locked unable to update
      STATUS_DATA_ERROR        -- Backend help is needed to fix

    Designer		date			version
    mche6435	  05/25/21	v1.0
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
    i_scan_method2       IN trans.scan_method2%TYPE
  )
  RETURN rf.status AS
    l_func_name   VARCHAR2(50) := 'update_status';
    rf_status     rf.status := rf.STATUS_NORMAL;

    l_task_exists NUMBER(3);
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name,
      'Starting ' || l_func_name
      || ', task_id: ' || i_task_id
      || ', prod_id: ' || i_prod_id
      || ', src_loc: ' || i_src_loc
      || ', dest_loc: ' || i_dest_loc
      || ', user_id: ' || i_user_id
      || ', cpv: ' || i_cust_pref_vendor
      || ', batch_no: ' || i_batch_no
      || ', seq_no: ' || i_seq_no
      || ', scan_method2: ' || i_scan_method2,
    sqlcode, sqlerrm, g_application_func, g_package_name);

    pl_log.ins_msg('DEBUG', l_func_name, 'Checking task exists.', sqlcode, sqlerrm, g_application_func, g_package_name);

    -- Check to see if task exists.
    BEGIN
      SELECT COUNT(1)
      INTO l_task_exists
      FROM replenlst
      WHERE task_id = i_task_id
      AND batch_no = i_batch_no
      AND user_id = i_user_id
      AND src_loc = i_src_loc
      AND dest_loc = i_dest_loc
      AND seq_no = i_seq_no
      AND cust_pref_vendor = i_cust_pref_vendor;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg(
          'FATAL',
          l_func_name,
          'Update to replenlst failed, task not found. task_id: ' || i_task_id || ' batch_no: ' || i_batch_no || ' user: ' || i_user_id,
          sqlcode,
          sqlerrm,
          g_application_func,
          g_package_name
        );
        RETURN rf.STATUS_SEL_RPL_FAIL;
      WHEN OTHERS THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Call to ' || l_func_name || ' failed. ', sqlcode, sqlerrm, g_application_func, g_package_name);
        rf.logexception();
        RAISE;
    END;

    IF l_task_exists != 1 THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Task with given arguments does not exist.', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_DATA_ERROR;
    END IF;

    pl_log.ins_msg('DEBUG', l_func_name, 'Updating Replen task from PIK to CMP.', sqlcode, sqlerrm, g_application_func, g_package_name);
    -- Update Replen task from PIK to CMP
    BEGIN
      UPDATE replenlst
      SET status = 'CMP'
      WHERE task_id = i_task_id
      AND batch_no = i_batch_no
      AND user_id = i_user_id
      AND src_loc = i_src_loc
      AND dest_loc = i_dest_loc
      AND seq_no = i_seq_no
      AND cust_pref_vendor = i_cust_pref_vendor;

      IF SQL%ROWCOUNT <> 1 THEN
        pl_log.ins_msg('FATAL', l_func_name, 'No rows or too many replenlst records updated', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf.STATUS_RPL_UPDATE_FAIL;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Call to ' || l_func_name || ' failed. Failed to update replenlst', sqlcode, sqlerrm, g_application_func, g_package_name);
        rf.logexception();
        RAISE;
    END;

    pl_log.ins_msg('DEBUG', l_func_name, 'Updating trans_type in transaction to SWP', sqlcode, sqlerrm, g_application_func, g_package_name);
    -- Update the transaction from INS to SWP
    BEGIN
      UPDATE trans
      SET trans_type = 'SWP',
          cmt = 'Dropped: ' || i_dest_loc,
          scan_method2 = i_scan_method2
      WHERE replen_task_id = i_task_id
      AND replen_type = 'SWP'
      AND batch_no = i_batch_no
      AND cust_pref_vendor = i_cust_pref_vendor
      AND REPLACE(UPPER(user_id),'OPS$') = UPPER(i_user_id);

      IF SQL%ROWCOUNT <> 1 THEN
        pl_log.ins_msg('FATAL', l_func_name, 'No rows or too many trans records updated', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf.STATUS_TRN_UPDATE_FAIL;
      END IF;
    EXCEPTION
      WHEN ROW_LOCKED THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Cannot Update trans, record locked.', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf.STATUS_REC_LOCK_BY_OTHER;
      WHEN OTHERS THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Call to ' || l_func_name || ' failed. ', sqlcode, sqlerrm, g_application_func, g_package_name);
        rf.logexception();
        RAISE;
    END;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to ' || l_func_name || ' failed. ', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END update_status;

  /*************************************************************************
    Function:     update_cycle_counts
    Description:  Function to update cycle counts

    Parameters:
      i_loc1   -- home location 1
      i_loc2   -- home location 2
      i_prod_id2   -- product id
      i_cpv2    -- cust_pref_vendor of item 2

    Return Value:

    Designer    date      version
    mche6435    06/08/21  v1.0
  **************************************************************************/
  FUNCTION update_cycle_counts(
    i_loc1      IN whmveloc_hist.oldloc%TYPE,
    i_loc2      IN whmveloc_hist.oldloc%TYPE,
    i_prod_id2   IN pm.prod_id%TYPE,
    i_cpv2       IN pm.cust_pref_vendor%TYPE
  ) RETURN rf.status AS
    l_func_name VARCHAR2(50) := 'update_cycle_counts';
    rf_status   rf.status := rf.STATUS_NORMAL;

    l_cctemp      VARCHAR2(10);
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name, 'Starting ' || l_func_name, sqlcode, sqlerrm, g_application_func, g_package_name);
    pl_log.ins_msg('DEBUG', l_func_name,
      'Starting ' || l_func_name
      || ', home1: ' || i_loc1
      || ', home2: ' || i_loc2
      || ', prod_id2: ' || i_prod_id2
      || ', cpv2: ' || i_cpv2,
    sqlcode, sqlerrm, g_application_func, g_package_name);

    SELECT 'SWPC' || SUBSTR(USER, 4, 6)
    INTO l_cctemp
    FROM dual;

    IF i_prod_id2 <> 'NULL' THEN
      rf_status := swap_cc_home_tasks(i_loc1, l_cctemp);

      IF rf_status = rf.STATUS_NORMAL THEN
        rf_status := swap_cc_home_tasks(i_loc2, i_loc1);
      END IF;

      IF rf_status = rf.STATUS_NORMAL THEN
        rf_status := swap_cc_home_tasks(l_cctemp, i_loc2);
      END IF;

      IF rf_status = rf.STATUS_NORMAL THEN
        rf_status := swap_cc_home_adjs(i_loc1, l_cctemp);
      END IF;

      IF rf_status = rf.STATUS_NORMAL THEN
        rf_status := swap_cc_home_adjs(i_loc2, i_loc1);
      END IF;

      IF rf_status = rf.STATUS_NORMAL THEN
        rf_status := swap_cc_home_adjs(l_cctemp, i_loc2);
      END IF;
    ELSE
      rf_status := swap_cc_home_tasks(i_loc1, i_loc2);
      IF rf_status = rf.STATUS_NORMAL THEN
        rf_status := swap_cc_home_adjs(i_loc1, i_loc2);
      END IF;
    END IF;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to' || l_func_name || 'failed', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END update_cycle_counts;

  /*************************************************************************
    Function:     finalize_swap
    Description:  Updates all item data

                  This should only be used if the drop is successful on the
                  LAST task in the batch.

    Parameters:
      i_loc1   -- First location in the batch sequence
      i_loc2   -- Last location in the batch sequence

    Return Value:
      STATUS_SEL_LOC_FAIL -- Failed to select from loc(location) table

    Designer    date      version
    mche6435    06/03/21  v1.0
  **************************************************************************/
  FUNCTION finalize_swap(
    i_loc1   IN loc.logi_loc%TYPE,
    i_loc2   IN loc.logi_loc%TYPE
  ) RETURN rf.status AS
    l_func_name VARCHAR2(50) := 'finalize_swap';
    rf_status   rf.status := rf.STATUS_NORMAL;

    r_loc1  loc%ROWTYPE;
    r_loc2  loc%ROWTYPE;
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name,
      'Starting ' || l_func_name
      || ', loc1: ' || i_loc1
      || ', loc2: ' || i_loc2,
    sqlcode, sqlerrm, g_application_func, g_package_name);

    -- Gather Data that will be used
    BEGIN
      pl_log.ins_msg('DEBUG', l_func_name, 'Fetching location 1 data', sqlcode, sqlerrm, g_application_func, g_package_name);
      SELECT *
      INTO r_loc1
      FROM loc
      WHERE logi_loc = i_loc1
      FOR UPDATE NOWAIT;

      pl_log.ins_msg('DEBUG', l_func_name, 'Fetching location 2 data', sqlcode, sqlerrm, g_application_func, g_package_name);
      SELECT *
      INTO r_loc2
      FROM loc
      WHERE logi_loc = i_loc2
      FOR UPDATE NOWAIT;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Could not fetch location data.', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf.STATUS_SEL_LOC_FAIL;

    END;

    rf_status := update_cycle_counts(r_loc1.logi_loc, r_loc2.logi_loc, r_loc2.prod_id, r_loc2.cust_pref_vendor);

    IF rf_status != rf.STATUS_NORMAL THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Failed to successfully update cycle counts', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf_status;
    END IF;

    -- Make updates to all values being swapped
    rf_status := swap_inventory(i_loc1, i_loc2);

    IF rf_status != rf.STATUS_NORMAL THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Failed to swap inventory', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf_status;
    END IF;

    rf_status := swap_location(
      r_loc1.prod_id,
      r_loc1.cust_pref_vendor,
      r_loc1.rank,
      r_loc1.uom,
      r_loc1.logi_loc,
      r_loc2.prod_id,
      r_loc2.cust_pref_vendor,
      r_loc2.rank,
      r_loc2.uom,
      r_loc2.logi_loc
    );

    IF rf_status != rf.STATUS_NORMAL THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Failed to update loc table', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf_status;
    END IF;

    -- Sync PM with changes to loc table
    IF rf_status = rf.STATUS_NORMAL AND r_loc1.uom != 1 AND r_loc1.rank = 1 AND r_loc1.prod_id IS NOT NULL THEN
      rf_status := sync_pm_with_loc(r_loc1.prod_id, r_loc1.cust_pref_vendor, r_loc2.logi_loc, r_loc1.uom);
    END IF;

    IF rf_status = rf.STATUS_NORMAL AND r_loc2.uom != 1 AND r_loc2.rank = 1 AND r_loc2.prod_id IS NOT NULL THEN
      rf_status := sync_pm_with_loc(r_loc2.prod_id, r_loc2.cust_pref_vendor, r_loc1.logi_loc, r_loc2.uom);
    END IF;

    IF rf_status != rf.STATUS_NORMAL THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Error when syncing pm with loc table', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf_status;
    END IF;

    -- Updating Warehouse Move
    rf_status := swap_warehouse_move(i_loc1, r_loc1.prod_id, i_loc2, r_loc2.prod_id);

    IF rf_status != rf.STATUS_NORMAL THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Failed to swap warehouse move history', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf_status;
    END IF;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to' || l_func_name || 'failed', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END finalize_swap;

  /*************************************************************************
    Function:     swap_location
    Description:  Swaps the location tables

    Parameters:
      i_prod_id1  -- Product 1: prod_id
      i_cpv1      -- Product 1: customer preferred vendor
      i_rank1     -- Product 1: rank
      i_uom1      -- Product 1: Unit of measure
      i_loc1      -- Product 1: location logi_loc
      i_prod_id2  -- Product 2: prod_id
      i_cpv2      -- Product 2: customer preferred vendor
      i_rank2     -- Product 2: rank
      i_uom2      -- Product 2: Unit of measure
      i_loc2      -- Product 2: location logi_loc

    Return Value:
      STATUS_LOC_UPDATE_FAILED -- Failed to update the location table

    Designer    date      version
    mche6435    06/03/21  v1.0
  **************************************************************************/
  FUNCTION swap_location(
    i_prod_id1  IN loc.prod_id%TYPE,
    i_cpv1      IN loc.cust_pref_vendor%TYPE,
    i_rank1     IN loc.rank%TYPE,
    i_uom1      IN loc.uom%TYPE,
    i_loc1      IN loc.logi_loc%TYPE,
    i_prod_id2  IN loc.prod_id%TYPE,
    i_cpv2      IN loc.cust_pref_vendor%TYPE,
    i_rank2     IN loc.rank%TYPE,
    i_uom2      IN loc.uom%TYPE,
    i_loc2      IN loc.logi_loc%TYPE
  ) RETURN rf.status AS
    l_func_name VARCHAR2(50) := 'swap_location';
    rf_status   rf.status := rf.STATUS_NORMAL;
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name, 'Starting ' || l_func_name, sqlcode, sqlerrm, g_application_func, g_package_name);

    UPDATE loc
    SET prod_id =
      CASE WHEN logi_loc = i_loc1 THEN i_prod_id2
           WHEN logi_loc = i_loc2 THEN i_prod_id1
      END,
      cust_pref_vendor =
      CASE WHEN logi_loc = i_loc1 THEN i_cpv2
           WHEN logi_loc = i_loc2 THEN i_cpv1
      END,
      rank =
      CASE WHEN logi_loc = i_loc1 THEN i_rank2
           WHEN logi_loc = i_loc2 THEN i_rank1
      END,
      uom =
      CASE WHEN logi_loc = i_loc1 THEN i_uom2
           WHEN logi_loc = i_loc2 THEN i_uom1
      END
    WHERE logi_loc IN (i_loc1, i_loc2);

    IF SQL%ROWCOUNT = 0 THEN
      pl_log.ins_msg('FATAL', l_func_name, 'No loc records updated. There should at least be 1.', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_LOC_UPDATE_FAILED;
    END IF;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN ROW_LOCKED THEN
      pl_log.ins_msg('FATAL', l_func_name, 'loc table: row locked', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_LOC_UPDATE_FAILED;
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to' || l_func_name || 'failed', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END swap_location;

  /*************************************************************************
    Function:     swap_cc_home_tasks
    Description:  Swap the values in cycle count and cycle count edit

    Parameters:
      i_loc1   -- logi_loc (location) of slot
      i_slot2   -- logi_loc (location) of slot

    Return Value:

    Designer    date      version
    mche6435    06/03/21  v1.0
  **************************************************************************/
  FUNCTION swap_cc_home_tasks(
    i_loc1  IN cc.logi_loc%TYPE,
    i_loc2  IN cc.logi_loc%TYPE
  ) RETURN rf.status AS
    l_func_name VARCHAR2(50) := 'swap_cc_home_tasks';
    rf_status   rf.status := rf.STATUS_NORMAL;
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name, 'Starting ' || l_func_name, sqlcode, sqlerrm, g_application_func, g_package_name);

    -- Swap data in cycle count
    UPDATE cc
    SET phys_loc = i_loc2,
        logi_loc = i_loc2
    WHERE phys_loc = i_loc1
    AND logi_loc = i_loc1;

    UPDATE cc_edit
    SET phys_loc = i_loc2,
        logi_loc = i_loc2
    WHERE phys_loc = i_loc1
    AND logi_loc = i_loc1;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN ROW_LOCKED THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Unable to update cycle count(cc) table rows locked', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_CC_UPDATE_FAILED;
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to' || l_func_name || 'failed', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END swap_cc_home_tasks;

  /*************************************************************************
    Function:     swap_cc_home_adjs
    Description:  Swap cycle count home adjs? Seems to create a transaction

    Parameters:
      i_loc1  -- location
      i_loc2  -- location

    Return Value:

    Designer    date      version
    mche6435    06/08/21  v1.0
  **************************************************************************/
  FUNCTION swap_cc_home_adjs(
    i_loc1   IN loc.logi_loc%TYPE,
    i_loc2   IN loc.logi_loc%TYPE
  ) RETURN rf.status AS
    l_func_name VARCHAR2(50) := 'swap_cc_home_adjs';
    rf_status   rf.status := rf.STATUS_NORMAL;
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name, 'Starting ' || l_func_name, sqlcode, sqlerrm, g_application_func, g_package_name);

    UPDATE trans
    SET src_loc = i_loc2,
        pallet_id = i_loc2
    WHERE adj_flag = 'Y'
    AND trans_type = 'CYC'
    AND src_loc = i_loc1
    AND pallet_id = i_loc1;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to' || l_func_name || 'failed', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END swap_cc_home_adjs;

  /*************************************************************************
    Function:     swap_warehouse_move
    Description:  Updates the warehouse move table

    Parameters:
      i_loc1      -- Location of product 1
      i_prod_id1  -- Product ID of product 1
      i_loc2      -- Location of product 2
      i_prod_id2  -- Product ID of product 2

    Return Value:

    Designer    date      version
    mche6435    06/03/21  v1.0
  **************************************************************************/
  FUNCTION swap_warehouse_move(
    i_loc1       IN whmveloc_hist.oldloc%TYPE,
    i_prod_id1   IN pm.prod_id%TYPE,
    i_loc2       IN whmveloc_hist.oldloc%TYPE,
    i_prod_id2   IN pm.prod_id%TYPE
  ) RETURN rf.status AS
    l_func_name VARCHAR2(50) := 'swap_warehouse_move';
    rf_status   rf.status := rf.STATUS_NORMAL;

    l_whmove_user all_users.username%TYPE;
    l_whmove_flag VARCHAR2(1);
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name, 'Starting ' || l_func_name, sqlcode, sqlerrm, g_application_func, g_package_name);

    --- Check if this option is used
    pl_log.ins_msg('DEBUG', l_func_name, 'Looking for WHMOVE user.', sqlcode, sqlerrm, g_application_func, g_package_name);
    BEGIN
      SELECT username
      INTO l_whmove_user
      FROM all_users
      WHERE username = 'WHMOVE';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('WARN', l_func_name, 'WHMOVE user not found, skipping updates for whmveloc_hist', sqlcode, sqlerrm, g_application_func, g_package_name);
        l_whmove_flag := 'N';
    END;

    pl_log.ins_msg('DEBUG', l_func_name, 'Getting sys_config', sqlcode, sqlerrm, g_application_func, g_package_name);
    BEGIN
      SELECT config_flag_val
      INTO l_whmove_flag
      FROM whmove.sys_config
      WHERE application_func = 'INVENTORY CONTROL'
      AND config_flag_name = 'ENABLE_WAREHOUSE_MOVE';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('FATAL', l_func_name, 'No data found for in sys_config table for ENABLE_WAREHOUSE_MOVE', sqlcode, sqlerrm, g_application_func, g_package_name);
        l_whmove_flag := 'N';
    END;

    IF l_whmove_flag != 'Y' THEN
      pl_log.ins_msg('WARN', l_func_name, 'whmove flag is not "Y", skipping.', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_NORMAL;
    END IF;

    pl_log.ins_msg('DEBUG', l_func_name, 'Starting whmove swap.', sqlcode, sqlerrm, g_application_func, g_package_name);

    UPDATE whmveloc_hist
    SET oldloc = i_loc2
    WHERE oldloc = i_loc1
    AND prod_id = i_prod_id1;

    UPDATE whmveloc_hist
    SET oldloc = i_loc1
    WHERE oldloc = i_loc2
    AND prod_id = i_prod_id2;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to' || l_func_name || 'failed', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END swap_warehouse_move;

  /*************************************************************************
    Function:     swap_inventory
    Description:  Swaps the data in inventory

    Parameters:
      i_loc1   -- Location of inventory (logi_loc)
      i_loc2   -- Location of inventory (logi_loc)

    Return Value:
      STATUS_INV_UPDATE_FAIL -- Updated 0 or updated too many records.
      STATUS_INV_REC_LOCKED  -- Inventory records are locked.

    Designer    date      version
    mche6435    06/03/21  v1.0
  **************************************************************************/
  FUNCTION swap_inventory(
    i_loc1   IN inv.logi_loc%TYPE,
    i_loc2   IN inv.logi_loc%TYPE
  ) RETURN rf.status AS
    l_func_name VARCHAR2(50) := 'swap_inventory';
    rf_status   rf.status := rf.STATUS_NORMAL;
  BEGIN
    pl_log.ins_msg('INFO', l_func_name,
      'Starting ' || l_func_name
      || ', loc1: ' || i_loc1
      || ', loc2: ' || i_loc2,
    sqlcode, sqlerrm, g_application_func, g_package_name);

    UPDATE inv
    SET
      plogi_loc =
        CASE WHEN plogi_loc = i_loc1 THEN i_loc2
             WHEN plogi_loc = i_loc2 THEN i_loc1
        END,
      logi_loc =
        CASE WHEN logi_loc = i_loc1 THEN i_loc2
             WHEN logi_loc = i_loc2 THEN i_loc1
        END
    WHERE logi_loc = plogi_loc
    AND plogi_loc IN (i_loc1, i_loc2);

    IF SQL%ROWCOUNT = 0 THEN
      pl_log.ins_msg('FATAL', l_func_name, 'No inventory was updated. There should at least be 1.', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_INV_UPDATE_FAIL;
    END IF;

    pl_log.ins_msg('INFO', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN ROW_LOCKED THEN
      pl_log.ins_msg('INFO', l_func_name, 'Cannot update inv locations, records locked.', sqlcode, sqlerrm, g_application_func, g_package_name);
      RETURN rf.STATUS_INV_REC_LOCKED;
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to' || l_func_name || 'failed', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END swap_inventory;

  /*************************************************************************
    Function:     sync_pm_with_loc
    Description:  Updates the pm table depending on the new changes in loc

    Parameters:
      i_prod_id   -- prod_id of the product
      i_cpv       -- Customer preferred vendor of the product
      i_location  -- Location of the product
      i_uom       -- UOM of the product

    Return Value:
      STATUS_ZONE_NOT_FOUND -- No records returned for given inputs
      STATUS_SEL_LOC_FAIL   -- Failed to select from location table
      STATUS_PM_UPDATE_FAIL -- No pm record updated (expected greater than 0)

    Designer    date      version
    mche6435    06/02/21  v1.0
  **************************************************************************/
  FUNCTION sync_pm_with_loc(
    i_prod_id   IN loc.prod_id%TYPE,
    i_cpv       IN loc.cust_pref_vendor%TYPE,
    i_location  IN loc.logi_loc%TYPE,
    i_uom       IN loc.uom%TYPE
  ) RETURN rf.status AS
    l_func_name VARCHAR2(50) := 'sync_pm_with_loc';
    rf_status   rf.status := rf.STATUS_NORMAL;

    l_put_area         swms_sub_areas.area_code%TYPE;
    l_put_zone         zone.zone_id%TYPE;
    l_pallet_type      loc.pallet_type%TYPE;
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name,
      'Starting ' || l_func_name
      || ', prod_id: ' || i_prod_id
      || ', cust_pref_vendor: ' || i_cpv
      || ', location: ' || i_location
      || ', uom: ' || i_uom,
    sqlcode, sqlerrm, g_application_func, g_package_name);

    pl_log.ins_msg('DEBUG', l_func_name, 'Fetching zone data', sqlcode, sqlerrm, g_application_func, g_package_name);
    -- get put area and put zone
    BEGIN
      IF i_uom != 1 THEN
        SELECT s.area_code, z.zone_id
        INTO l_put_area, l_put_zone
        FROM swms_sub_areas s, zone z
        LEFT JOIN lzone lz ON z.zone_id = lz.zone_id
        WHERE
          s.sub_area_code = (
            SELECT ai.sub_area_code
            FROM aisle_info ai
            WHERE ai.name = SUBSTR(i_location, 1, 2)
          )
        AND z.zone_type = 'PUT'
        AND lz.logi_loc = i_location;
      ELSE
        SELECT s.area_code, z.zone_id
        INTO l_put_area, l_put_zone
        FROM swms_sub_areas s, zone z
        LEFT JOIN lzone lz ON z.zone_id = lz.zone_id
        LEFT JOIN loc    l ON lz.logi_loc = l.logi_loc
        WHERE
          s.sub_area_code = (
            SELECT ai.sub_area_code
            FROM aisle_info ai
            WHERE ai.name = SUBSTR(l.logi_loc, 1, 2)
          )
        AND z.zone_type = 'PUT'
        AND l.uom IN (0, 2)
        AND l.rank = 1
        AND l.perm = 'Y'
        AND l.cust_pref_vendor = i_cpv
        AND l.prod_id = i_prod_id;
      END IF;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('FATAL', l_func_name, 'No Zone Data found', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf.STATUS_ZONE_NOT_FOUND;
    END;

    pl_log.ins_msg('DEBUG', l_func_name, 'Fetching pallet type', sqlcode, sqlerrm, g_application_func, g_package_name);
    -- Get pallet type
    BEGIN
      SELECT loc.pallet_type
      INTO l_pallet_type
      FROM loc
      WHERE loc.logi_loc = i_location
      AND loc.prod_id = i_prod_id
      AND loc.cust_pref_vendor = i_cpv
      AND loc.uom IN (0, 2)
      AND loc.rank = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Failed to get pallet type from loc', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf.STATUS_SEL_LOC_FAIL;
    END;

    pl_log.ins_msg('DEBUG', l_func_name, 'Updating PM table', sqlcode, sqlerrm, g_application_func, g_package_name);
    BEGIN
      UPDATE pm
      SET area = l_put_area,
          stage = l_put_area,
          zone_id = l_put_zone,
          pallet_type = l_pallet_type
      WHERE cust_pref_vendor = i_cpv
      AND prod_id = i_prod_id;

      IF SQL%ROWCOUNT = 0 THEN
        pl_log.ins_msg('FATAL', l_func_name, 'No rows were updated', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf.STATUS_PM_UPDATE_FAIL;
      END IF;
    EXCEPTION
      WHEN ROW_LOCKED THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Unable to update pm table, row locked.', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf.STATUS_PM_UPDATE_FAIL;
    END;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to' || l_func_name || 'failed', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END sync_pm_with_loc;

  /*************************************************************************
    Function:     verify_task_matches_inv
    Description:  Verify that the number of tasks matches the number of
                  expected inventory to move.

    Parameters:
      i_batch_no  -- replenlst batch number (Used to id tasks in batch)
      i_src_loc   -- Source location of task
      i_dest_loc  -- Destination location of task

    Return Value:
      STATUS_SEL_RPL_FAIL -- Failed to select from replenlst table
      STATUS_SEL_INV_FAIL -- Failed to select from inventory table

    Designer    date      version
    mche6435    06/03/21  v1.0
  **************************************************************************/
  FUNCTION verify_task_matches_inv(
    i_batch_no  IN replenlst.batch_no%TYPE,
    i_src_loc   IN inv.logi_loc%TYPE,
    i_dest_loc  IN inv.logi_loc%TYPE
  ) RETURN rf.status AS
    l_func_name   VARCHAR2(50) := 'verify_task_matches_inv';
    rf_status     rf.status := rf.STATUS_NORMAL;

    l_task_count  NUMBER(1); -- amount of tasks, should only be 1 or 2
    l_inv_count   NUMBER(1); -- amount of inv to be swapped, should only be 1 or 2
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name,
      'Starting ' || l_func_name
      || ', batch_no: ' || i_batch_no
      || ', src_loc: ' || i_src_loc
      || ', dest_loc: ' || i_dest_loc,
    sqlcode, sqlerrm, g_application_func, g_package_name);

    -- Number of tasks
    pl_log.ins_msg('DEBUG', l_func_name, 'Counting Tasks', sqlcode, sqlerrm, g_application_func, g_package_name);
    BEGIN
      SELECT COUNT(*)
      INTO l_task_count
      FROM replenlst
      WHERE batch_no = i_batch_no;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Failed to get number of tasks, No data found for batch_no: ' || i_batch_no, sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf.STATUS_SEL_RPL_FAIL;
    END;

    pl_log.ins_msg('DEBUG', l_func_name, 'Counting Inv items', sqlcode, sqlerrm, g_application_func, g_package_name);
    -- Number of inventory items
    BEGIN
      SELECT COUNT(*)
      INTO l_inv_count
      FROM inv
      WHERE logi_loc = plogi_loc -- Force home location only
      AND logi_loc in (i_src_loc, i_dest_loc);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('FATAL', l_func_name, 'Failed to get number of inv items, No data found for given src and dest locs. ', sqlcode, sqlerrm, g_application_func, g_package_name);
        RETURN rf.STATUS_SEL_INV_FAIL;
    END;

    IF l_task_count != l_inv_count THEN
      rf_status := rf.STATUS_DATA_ERROR;
    END IF;

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name || ', Status = ' || rf_status, sqlcode, sqlerrm, g_application_func, g_package_name);
    RETURN rf_status;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to' || l_func_name || 'failed', sqlcode, sqlerrm, g_application_func, g_package_name);
      rf.logexception();
      RAISE;
  END verify_task_matches_inv;
END pl_rf_swap_drop;
/

SHOW ERRORS;

GRANT EXECUTE ON SWMS.pl_rf_swap_drop TO SWMS_User;
