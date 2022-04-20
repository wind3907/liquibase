CREATE OR REPlACE PACKAGE pl_rf_matrix_replen_pick
AS
------------------------------------------------------------------------------------------
-- Package
--   PL_RF_MATRIX_REPLEN_PICK
--
-- Description
--   ThIS package contains all the procedures and functions required for the matrix
--   replenishment pick
--
-- Parameters
--
--  input:
--  Equip_id Task_id Scanned_data Scan_method Func1_flag
--
--  Output:
--  RF_STATUS
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------
--    07/18/15 sred5131 initial Version
--    09/25/15 ayad5195 Changed pick_pallet function, to check for new
--                      substitute pallet for same prod_id
--
--    03/17/16 bben0556 Brian Bent
--                      Project:
--                R30.4--WIB#625--Charm6000011676_Symbotic_Throttling_enhancement
--
--                      Picking up more than one DSP at the spur results in
--                      an error because the 1st DSP labor batch tries to 
--                      get completed instead of the subsequent DSP labor
--                      batches merging.  The RF expects all the DSP to be
--                      picked up when the REPLENLST.MX_BATCH_NO is the same.
--
--                      Set the forklift labor merge flag to Y when picking
--                      up more than one DSP replenishment at the spur.
--
--                      Modified function "logon_to_labor_batch".
--                      Changed
--       rf_status := pl_libswmslm.attach_to_OP_dmd_fk_batch(i_lbr_batch, i_user_id, i_Equip_id, ' ' , 'N');
--                      to
--       rf_status := pl_libswmslm.attach_to_OP_dmd_fk_batch(i_lbr_batch, i_user_id, i_Equip_id, 'N' , i_mergeflag);
--
--                      Add INFO log messages to aid in support.
--
--
--    07/19/16 bben0556 Brian Bent
--                            Project:
--                R30.5--WIB#663--CRQ000000007533_Save_what_created_NDM_in_trans_RPL_record
--
--                      Modified "perform_pick()" to populate
--                      these new columns when inserting the trans IND record:
--                         - TRANS.REPLEN_CREATION_TYPE    (from replenlst.replen_type)
--                         - TRANS.REPLEN_TYPE             (from replenlst.type)
--                         - TRANS.TASK_PRIORITY           (from USER_DOWNLOADED_TASKS)
--                         - TRANS.SUGGESTED_TASK_PRIORITY (from USER_DOWNLOADED_TASKS)
--
--
--                      TRANS.REPLEN_CREATION_TYPE added to the transaction
--                      tables to store what created the non-demand
--                      replenishment.  The OpCo wants to know this.
--                      The value comes from column REPLENST.REPLEN_TYPE 
--                      which for non-demand replenishments will have one of
--                      these values:
--       'L' - Created from RF using "Replen By Location" option
--       'H' - Created from Screen using "Replen by Historical" option
--       'R' - Created from screen with options other than "Replen by Historical"
--       'O' - Created from cron job when a store-order is received that
--             requires a replenishment
--
--
--                      TRANS.REPLEN_TYPE added to the transaction tables
--                      to store the replenishment type.  It main purpose is
--                      to store the matrix replenishment type.  The value
--                      will come from REPLENLST.TYPE.
--                      Matrix replenishments have diffent types but we use
--                      RPL for the transaction.  The OpCo wants to know the
--                      matrix replenishment type.  The matrix replenishment
--                      types are in table MX_REPLEN_TYPE which are
--                      listed here.
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
--
--                      TASK_PRIORITY stores the forklift task priority
--                      for the NDM.  I also populated it for DMD's.
--                      The value comes from USER_DOWNLOADED_TASKS.
--
--                      SUGGESTED_TASK_PRIORITY stores the hightest
--                      forklift task priority from the replenishment
--                      list sent to the RF.  The value comes from
--                      USER_DOWNLOADED_TASKS.  Distribution Services
--                      wants to know if the forklift operator is doing
--                      lower priority drops before higher ones.
--
---------------------------------------------------------------------------------------------

  FUNCTION perform_replen_pick(		-- this function is called directly from RF client via SOAP web service
    i_Rf_log_init_Record IN swms.rf_log_init_record,
    i_Taskid             IN VARCHAR2,
    i_Equip_id           IN VARCHAR2,
    i_Scanned_Data       IN VARCHAR2,
    i_Scan_Method        IN VARCHAR2,
    i_Func1_flag         IN VARCHAR2)
  RETURN swms.rf.status;

  FUNCTION pick_pallet(
    i_Taskid             IN VARCHAR2,
    i_Scanned_Data       IN VARCHAR2,
    i_Equip_id           IN VARCHAR2)
  RETURN swms.rf.status;

  FUNCTION perform_pick(
    i_taskid             IN VARCHAR2,
    i_Equip_id           IN VARCHAR2)
  Return swms.rf.status;

  FUNCTION substitute_pallet(
    i_taskid             IN VARCHAR2,
    i_newpallet          IN VARCHAR2)
  RETURN swms.rf.status;
  
  FUNCTION unpick_pallet(
    i_taskid             IN VARCHAR2,    
    i_Scanned_Data       IN VARCHAR2,
    i_Equip_id           IN VARCHAR2,
    i_Scan_Method        IN VARCHAR2)
  RETURN swms.rf.status;
  
  FUNCTION logon_to_labor_batch(
    i_rpl_type           IN VARCHAR2,
    i_user_id            IN VARCHAR2,
    i_Equip_id           IN VARCHAR2,
    i_Taskid             IN VARCHAR2,    
    i_mergeflag          IN VARCHAR2,
    i_lbr_batch          IN VARCHAR2, 
    i_floatno            IN VARCHAR2,
    i_drop_qty           IN NUMBER )
  RETURN swms.rf.status;
 
END pl_rf_matrix_replen_pick;
/


CREATE OR REPlACE PACKAGE BODY pl_rf_matrix_replen_pick
AS
  ------------------------------------------------------------------------------------------
  -- Package
  --   PL_RF_MATRIX_REPLEN_PICK
  --
  -- Description
  --   This package contains all the common procedures and functions required for the matrix
  --   replenishment pick.
  --
  -- Parameters:
  --
  --  input:
  --  Equip_id Task_id Scanned_data Scan_method Func1_flag
  --
  --  Output:
  --  RF_STATUS
  --
  -- ModIFication HIStory
  --
  --   Date           Designer         Comments
  --  -----------    ---------------  ---------------------------------------------------------
  --  18-JUl-2014     sred5131         initial Version
  ---------------------------------------------------------------------------------------------

  --------------------------------------------------------------------------
  -- Private  Constants
  --------------------------------------------------------------------------

  ct_program_code CONSTANT VARCHAR2 (50) := 'PL_RF_MATRIX_REPlEN_PICK';--'RFMXRPlPK';
  ct_application_function   CONSTANT VARCHAR2 (9)  := 'INVENTORY';
  gl_pkg_name   VARCHAR2(30) := $$PLSQL_UNIT;   -- Package name.
                                                -- Used in log messages.



  
  TYPE rpl_rec IS RECORD (
        l_status        VARCHAR(3),
        l_src_loc       VARCHAR(10),
        l_dest_loc      VARCHAR(10),
        l_pallet_id     VARCHAR(18),
        l_prod_id       VARCHAR(9),
        l_exp_date      DATE,
        l_mfg_date      DATE,
        l_qty           NUMBER(7),
        type            VARCHAR2(3),
        mx_batch_no     NUMBER(9),
        uom             replenlst.uom%TYPE
    );  
  ----------------------------------------------------------------
  
  l_loop_count          NUMBER := 1;
  
---------------------------------------------------
-- perform_replen_pick()
---------------------------------------------------
FUNCTION perform_replen_pick(		-- this function is called directly from RF client via SOAP web service
    i_Rf_log_init_Record IN swms.rf_log_init_record,
    i_Taskid             IN VARCHAR2,
    i_Equip_id           IN VARCHAR2,
    i_Scanned_Data       IN VARCHAR2,
    i_Scan_Method        IN VARCHAR2,
    i_Func1_flag         IN VARCHAR2
  )
  RETURN swms.rf.status
IS
  rf_status         swms.rf.status := swms.rf.STATUS_NORMAL;    
  l_palletid        VARCHAR2(18);
  l_replentype      VARCHAR2(20); 
  e_fail            EXCEPTION; 
BEGIN
   --
   -- Log starting the procedure.
   -- Relatively speaking we don't do a lot of matrix replenishments so logging a
   -- message for each one should be fine.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, 'perform_replen_pick',
            'Starting function'
            || ' (i_Rf_log_init_Record'
            || ',i_Taskid['        || i_Taskid       || ']'
            || ',i_Equip_id['      || i_Equip_id     || ']'
            || ',i_Scanned_Data['  || i_Scanned_Data || ']'
            || ',i_Scan_Method['   || i_Scan_Method  || ']'
            || ',i_Func1_flag['    || i_Func1_flag   || '])',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

    rf_status := rf.initialize(i_rf_log_init_record);

    IF rf_status = swms.rf.status_normal THEN
        IF(i_Taskid = 0) THEN
            rf_status := rf.STATUS_NO_TASK;
            RAISE e_fail;
        ELSE
            BEGIN
                SElECT pallet_id 
                  INTO l_palletid 
                  FROM replenlst 
                 WHERE Task_id = i_Taskid;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    rf_status := rf.STATUS_NO_TASK;
                    RAISE e_fail;         
                END;
                
            IF (i_Func1_Flag = 'Y') THEN
                DBMS_OUTPUT.PUT_LINE('TEST 1: Calling unpick_pallet');
                rf_status := unpick_pallet(i_Taskid, i_Scanned_Data, i_Equip_id, i_Scan_Method);
            ELSE
                DBMS_OUTPUT.PUT_LINE('TEST 2: Calling pick_pallet');
                rf_status := pick_pallet(i_Taskid, i_Scanned_Data, i_Equip_id);
            END IF;
        END IF;
    END IF;    /* rf.initialize() returned NORMAL */
    
    IF rf_status = swms.rf.STATUS_NORMAL THEN
        BEGIN
            SElECT type 
              INTO l_replentype 
              FROM replenlst 
             WHERE task_id= i_Taskid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Replnlst Taskid not found' || i_Taskid, SQLCODE, SQLERRM);
                rf_status := rf.STATUS_NO_TASK;
                RAISE e_fail; 
        END;
        
        rf_status := pl_rf_matrix_replen_common.update_scan_method(i_scan_method, l_palletid, 1);          
    ELSE
        RAISE e_fail;
    END IF;

    rf.Complete (rf_status);
    --
    -- Log ending the procedure.
    -- Relatively speaking we don't do a lot of matrix replenishments so logging a
    -- message for each one should be fine.
    --
   pl_log.ins_msg(pl_log.ct_info_msg, 'perform_replen_pick',
            'Ending function'
            || ' (i_Rf_log_init_Record'
            || ',i_Taskid['        || i_Taskid            || ']'
            || ',i_Equip_id['      || i_Equip_id          || ']'
            || ',i_Scanned_Data['  || i_Scanned_Data      || ']'
            || ',i_Scan_Method['   || i_Scan_Method       || ']'
            || ',i_Func1_flag['    || i_Func1_flag        || '])'
            || '  rf_status['      || TO_CHAR(rf_status)  || ']',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

    RETURN rf_status;
EXCEPTION
    WHEN e_fail THEN
       pl_log.ins_msg(pl_log.ct_info_msg, 'perform_replen_pick',
            'Ending function'
            || ' (i_Rf_log_init_Record'
            || ',i_Taskid['        || i_Taskid            || ']'
            || ',i_Equip_id['      || i_Equip_id          || ']'
            || ',i_Scanned_Data['  || i_Scanned_Data      || ']'
            || ',i_Scan_Method['   || i_Scan_Method       || ']'
            || ',i_Func1_flag['    || i_Func1_flag        || '])'
            || '  rf_status['      || TO_CHAR(rf_status)  || ']'
            || '  Error occurred.  In e_fail exception handler.',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

        ROLLBACK;
        rf.complete(rf_status);
        RETURN rf_status;
    WHEN OTHERS THEN
       pl_log.ins_msg(pl_log.ct_info_msg, 'perform_replen_pick',
            'Ending function'
            || ' (i_Rf_log_init_Record'
            || ',i_Taskid['        || i_Taskid            || ']'
            || ',i_Equip_id['      || i_Equip_id          || ']'
            || ',i_Scanned_Data['  || i_Scanned_Data      || ']'
            || ',i_Scan_Method['   || i_Scan_Method       || ']'
            || ',i_Func1_flag['    || i_Func1_flag        || '])'
            || '  rf_status['      || TO_CHAR(rf_status)  || ']'
            || '  Error occurred.',
         SQLERRM, SQLCODE,
         ct_application_function, gl_pkg_name);

        rf.logexception(); -- log it
        RAISE;
END perform_replen_pick;


------------------------------------------
-- pick_pallet
------------------------------------------
FUNCTION pick_pallet(
    i_Taskid             IN VARCHAR2,
    i_Scanned_Data       IN VARCHAR2,
    i_Equip_id           IN VARCHAR2)
  RETURN swms.rf.status
IS

    l_object_name    VARCHAR2(30) := 'pick_pallet';

    rf_status        swms.rf.status := swms.rf.status_normal;
    l_rpl_rec        rpl_rec;
    lscandata        VARCHAR2(20);
    l_cnt            NUMBER;  
    e_fail           EXCEPTION;    
    l_sys_msg_id     NUMBER;
    l_ret_val        NUMBER;
    l_spur_location  mx_batch_info.spur_location%TYPE;
BEGIN
   --
   -- Log starting the procedure.
   -- Relatively speaking we don't do a lot of matrix replenishments so logging a
   -- message for each one should be fine.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
            'Starting function'
            || ' (i_Taskid['        || i_Taskid       || ']'
            || ',i_Scanned_Data['   || i_Scanned_Data || ']'
            || ',i_Equip_id['       || i_Equip_id     || '])',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

    DBMS_OUTPUT.PUT_LINE('TEST 3: pick_pallet  Status:'||rf_status);

    IF rf_status = swms.rf.STATUS_NORMAL THEN
        BEGIN
            SElECT r.status,
                   src_loc,
                   NVL(r.dest_loc, CHR(10)),
                   pallet_id,
                   r.prod_id,
                   r.exp_date,
                   r.mfg_date,
                   DECODE(r.type, 'NDM', DECODE (r.uom, 1, qty, qty / p.spc), qty),
                   r.type,
                   r.mx_batch_no,
                   r.uom
              INTO l_rpl_rec
              FROM pm p,
                   replenlst r
             WHERE task_id            = i_Taskid
               AND p.prod_id          = r.prod_id
               AND p.cust_pref_vendor = r.cust_pref_vendor;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
               --
               -- Task id not in REPLENLST or item not in SWMS.
               -- Log a message and set the return status.
               --
               pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                   'TABLE="pm,replenlst"'
                   || '  KEY=[' || i_Taskid || '](i_Taskid)'
                   || '  ACTION=SELECT  MESSAGE="Task not found"',
                   SQLCODE, SQLERRM,
                   ct_application_function, gl_pkg_name);

                rf_status := rf.STATUS_NOT_FOUND;
                RAISE e_fail;
            WHEN OTHERS THEN
               --
               -- Oracle error.
               -- Log a message and set the return status.
               --
               pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                   'TABLE="pm,replenlst"'
                   || '  KEY=[' || i_Taskid || '](i_Taskid)'
                   || '  ACTION=SELECT  MESSAGE="SELECT failed"',
                   SQLCODE, SQLERRM,
                   ct_application_function, gl_pkg_name);

               rf_status := rf.STATUS_SEL_RPL_FAIL;
               RAISE e_fail;
        END;

        --
        -- Log info message.
        --
        pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                   'TABLE="pm,replenlst"'
                   || '  KEY=[' || i_Taskid || '](i_Taskid)'
                   || '  ACTION=SELECT  MESSAGE="SELECT successful"'
                   || '  l_rpl_rec.l_status['     ||  l_rpl_rec.l_status              || ']'
                   || '  l_rpl_rec.l_src_loc['    ||  l_rpl_rec.l_src_loc             || ']'
                   || '  l_rpl_rec.l_dest_loc['   ||  l_rpl_rec.l_dest_loc            || ']'
                   || '  l_rpl_rec.l_pallet_id['  ||  l_rpl_rec.l_pallet_id           || ']'
                   || '  l_rpl_rec.l_prod_id['    ||  l_rpl_rec.l_prod_id             || ']'
                   || '  l_rpl_rec.l_exp_date['   ||  TO_CHAR(l_rpl_rec.l_exp_date, 'DD-MON-YYYY HH24:MI:SS') || ']'
                   || '  l_rpl_rec.l_mfg_date['   ||  TO_CHAR(l_rpl_rec.l_mfg_date, 'DD-MON-YYYY HH24:MI:SS') || ']'
                   || '  l_rpl_rec.l_qty['        ||  TO_CHAR(l_rpl_rec.l_qty)        || ']'
                   || '  l_rpl_rec.type['         ||  l_rpl_rec.type                  || ']'
                   || '  l_rpl_rec.mx_batch_no['  ||  TO_CHAR(l_rpl_rec.mx_batch_no)  || ']'
                   || '  l_rpl_rec.uom['          ||  TO_CHAR(l_rpl_rec.uom)          || ']',
                   NULL, NULL,
                   ct_application_function, gl_pkg_name);

        
        DBMS_OUTPUT.PUT_LINE('TEST 4: pick_pallet  Task Status:'||l_rpl_rec.l_status);

        IF l_rpl_rec.l_status != 'NEW' THEN
            --
            -- REPLENLST status not NEW.  Already picked or have some other issue.
            -- Log a message and set the return status.
            --
            pl_log.ins_msg(pl_log.ct_error_msg, l_object_name,
                   'TABLE="pm,replenlst"'
                   || '  KEY=[' || i_Taskid || '](i_Taskid)'
                   || '  Selected REPLENLST record.  Expected the status to be "NEW" but'
                   || ' status is [' || l_rpl_rec.l_status || '].  Returning "task already picked" to RF.',
                   NULL, NULL,
                   ct_application_function, gl_pkg_name);

            rf_status := rf.STATUS_TASK_ALREADY_PICKED;
            RAISE e_fail;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('TEST 5: pick_pallet  Pallet ID:'||l_rpl_rec.l_pallet_id || '  i_Scanned_Data: '||i_Scanned_Data);

        IF l_rpl_rec.type IN  ('NXL','DXL') THEN   --NOT IN ('NSP', 'DSP','UNA')
            /************ SELECT COUNT(*)
              INTO l_cnt
              FROM replenlst
             WHERE task_id = i_Taskid
               AND case_no = SUBSTR(i_Scanned_Data, 1, LENGTH(i_Scanned_Data) - 3);
            
            IF l_cnt = 0 THEN
                rf_status := rf.STATUS_INV_LABEL;
                RAISE e_fail;
            END IF; 
        ELSE*****************/
            IF l_rpl_rec.l_pallet_id != i_Scanned_Data THEN
                SElECT COUNT(*)
                  INTO l_cnt
                  FROM pm p,
                       inv i
                 WHERE logi_loc  = i_Scanned_Data   --Changed to look new substitute pallet for same prod_id, qty and exp_date
                   AND qoh / spc = l_rpl_rec.l_qty
                   AND i.Prod_id = l_rpl_rec.l_prod_id
                   AND exp_date  = l_rpl_rec.l_exp_date
                   AND plogi_loc = l_rpl_rec.l_src_loc
                   AND p.prod_id = i.prod_id
                   AND i.status  = 'AVL';
                
                DBMS_OUTPUT.PUT_LINE('TEST 6: l_cnt:'||l_cnt);
                IF l_cnt = 0 THEN
                    rf_status := rf.STATUS_INV_LABEL;
                    RAISE e_fail;
                ELSE
                    rf_status := substitute_pallet(i_Taskid, i_Scanned_Data);             
                END IF;
            END IF;
        END IF; 
    END IF;
 
    IF l_rpl_rec.type IN  ('MXL') THEN   --NOT IN ('NSP', 'DSP','UNA')
        IF l_rpl_rec.l_src_loc != i_Scanned_Data THEN        
            rf_status := rf.STATUS_INV_SRC_LOCATION;
            RAISE e_fail;               
        END IF; 
    END IF;
 
    DBMS_OUTPUT.PUT_LINE('TEST 7: Status :'||rf_status);    

    IF rf_status = swms.rf.STATUS_NORMAL THEN
        DBMS_OUTPUT.PUT_LINE('TEST 7: Calling perform_pick  i_Taskid:'||i_Taskid || '    i_Equip_id:'||i_Equip_id);
        l_loop_count := 1;

        IF l_rpl_rec.mx_batch_no IS NOT NULL THEN
            FOR r_task IN (SELECT task_id FROM replenlst WHERE mx_batch_no = l_rpl_rec.mx_batch_no)
            LOOP
               --
               -- Log info message.
               --
               pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                   'In LOOP "r_task IN (SELECT task_id FROM replenlst WHERE mx_batch_no = l_rpl_rec.mx_batch_no)"'
                   || '  l_rpl_rec.mx_batch_no[' || TO_CHAR(l_rpl_rec.mx_batch_no) || ']'
                   || '  r_task.task_id['        || TO_CHAR(r_task.task_id)        || ']'
                   || '  l_loop_count['          || TO_CHAR(l_loop_count)          || ']',
                   NULL, NULL,
                   ct_application_function, gl_pkg_name);


                Pl_Text_log.ins_Msg(' ',Ct_Program_Code,'TEST  perform_pick for Task_ID' || r_task.task_id, NULL, NULL);

                rf_status := perform_pick(r_task.task_id, i_Equip_id);

                l_loop_count := l_loop_count + 1;

                DBMS_OUTPUT.PUT_LINE('TEST 8: After multiple perform_pick  i_Taskid:'||r_task.task_id || '    i_Equip_id:'||i_Equip_id);

                IF RF_STATUS != swms.rf.STATUS_NORMAL THEN
                    RAISE e_fail;
                END IF; 
            END LOOP;
            
            ------Batch Start Message SYS07 for NSP, UNA, MRL and DSP Task----
            IF l_rpl_rec.type IN  ('NSP', 'DSP', 'UNA', 'MRL') THEN 
                l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;
                                                    
                l_ret_val := pl_matrix_common.populate_matrix_out
                                     (i_sys_msg_id        => l_sys_msg_id,
                                      i_interface_ref_doc => 'SYS07',
                                      i_rec_ind           => 'S',         
                                      i_batch_id          => l_rpl_rec.mx_batch_no,
                                      i_batch_comp_tstamp =>  TO_CHAR(SYSTIMESTAMP, 'DD-MM-YYYY HH:MI:SS:ff9 AM'),
                                      i_batch_status      => 'STARTED');
                                                                
                IF l_ret_val = 1 THEN   
                    Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Unable to insert record into matrix_out (SYS07) for batch_no '||l_rpl_rec.mx_batch_no,NULL,NULL);
                    rf_status := rf.STATUS_INSERT_FAIL;
                    RAISE e_fail;
                END IF;      
                
                COMMIT;

                Pl_Text_log.ins_Msg('',Ct_Program_Code,'Insert into matrix_out completed for pick complete (SYS07) Message for batch_id '||l_rpl_rec.mx_batch_no, NULL, NULL);
                --Schedule job to process matrix_out table and send message to Symbotic
                l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => l_sys_msg_id);
                        
                IF l_ret_val = 1 THEN   
                    Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Sending pick complete (SYS07) message to matrix failed for batch_no '||l_rpl_rec.mx_batch_no,SQLCODE,SQLERRM);
                    rf_status := rf.STATUS_INSERT_FAIL;
                    RAISE e_fail;
                END IF;    
            END IF;   --SYS07 END
            
        ELSE    
            rf_status := perform_pick(i_Taskid, i_Equip_id);

            DBMS_OUTPUT.PUT_LINE('TEST 8: After single perform_pick  i_Taskid:'||i_Taskid || '    i_Equip_id:'||i_Equip_id);
        END IF;    
        
    END IF;

   --
   -- Log end the procedure.
   -- Relatively speaking we don't do a lot of matrix replenishments so logging a
   -- message for each one should be fine.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
            'Ending function'
            || ' (i_Taskid['        || i_Taskid            || ']'
            || ',i_Scanned_Data['   || i_Scanned_Data      || ']'
            || ',i_Equip_id['       || i_Equip_id          || '])'
            || '  rf_status['       || TO_CHAR(rf_status)  || ']',
         NULL, NULL,
         ct_application_function, gl_pkg_name);
    
    RETURN rf_status;
EXCEPTION
    WHEN e_fail THEN
        RETURN rf_status;
END pick_pallet;


-------------------------------------
--Perform Pick
-------------------------------------
FUNCTION perform_pick(
    i_Taskid             IN VARCHAR2,
    i_Equip_id           IN VARCHAR2)
  RETURN swms.rf.status
IS
    l_object_name   VARCHAR2(30) := 'perform_pick';

    rf_status swms.rf.status := swms.rf.STATUS_NORMAL;

    l_rpl_type      VARCHAR2(3);
    l_float_no      NUMBER;
    l_lbr_batch     VARCHAR2(20);
    l_status        VARCHAR(3);        
    l_src_loc       VARCHAR(10);       
    l_dest_loc      VARCHAR(10);        
    l_pallet_id     VARCHAR(18);        
    l_prod_id       VARCHAR(9);       
    l_exp_date      DATE;        
    l_mfg_date      DATE;        
    l_qty           NUMBER(7);  
    l_drop_qty      NUMBER;
    l_uom           NUMBER(2); 
    l_mx_batch_no   replenlst.mx_batch_no%TYPE; 
    e_fail          EXCEPTION;
    l_merge_flag    VARCHAR2(1);
    l_replen_creation_type  replenlst.replen_type%TYPE;  -- 07/22/2016 What created the replenishment.  Value
                                                         -- from column REPLENLST.REPLEN_TYPE,  Should be
                                                         -- populated for non-demand replenishments when
                                                         -- replenishment created.
                                                         -- Values:
                                                         -- 'L' - Created from RF using "Replen By Location" option
                                                         -- 'H' - Created from Screen using "Replen by Historical" option
                                                         -- 'R' - Created from screen with options other than "Replen by Historical"
                                                         -- 'O' - Created from cron job when a store-order is received that
                                                         -- We put this in the IND transaction record "replen_creation_type" column.
    l_task_priority            trans.task_priority%TYPE;
    l_suggested_task_priority  trans.suggested_task_priority%TYPE;


    ORACLE_REC_LOCKED EXCEPTION;
    PRAGMA EXCEPTION_INIT(ORACLE_REC_LOCKED, -54);
BEGIN
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
            'Starting function'
            || ' (i_Taskid['        || i_Taskid       || ']'
            || ',i_Equip_id['       || i_Equip_id     || '])',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

    DBMS_OUTPUT.PUT_LINE('TEST 7A: Status :'|| rf_status);

    IF rf_status = swms.rf.STATUS_NORMAL THEN  --1
        BEGIN
            SELECT type,
                   NVL (float_no, 0),
                   NVL (labor_Batch_No, 'x'),
                   Status,
                   src_loc,
                   NVL (dest_loc, CHR (10)),
                   Pallet_id,
                   Prod_id,
                   Exp_Date,
                   Mfg_Date,
                   qty,
                   NVL (drop_qty, 0),
                   mx_batch_no,
                   replen_type,
                   pl_replenishments.get_task_priority(task_id, USER)  task_priority,             /* -1  is used if task not found in user_downloaded_tasks */
                   pl_replenishments.get_suggested_task_priority(USER) suggested_task_priority    /* -1  is used if task not found in user_downloaded_tasks */
              INTO l_rpl_type,
                   l_float_no,
                   l_lbr_batch,
                   l_status,        
                   l_src_loc,    
                   l_dest_loc,     
                   l_pallet_id,   
                   l_prod_id,  
                   l_exp_date,        
                   l_mfg_date,        
                   l_qty,
                   l_drop_qty,
                   l_mx_batch_no,
                   l_replen_creation_type,
                   l_task_priority,
                   l_suggested_task_priority
              FROM Replenlst
             WHERE Task_id = i_Taskid
               FOR UPDATE OF status NOWAIT;
        EXCEPTION
            WHEN ORACLE_REC_LOCKED THEN
               --
               -- REPLENLST record locked.
               -- Log a message and set the return status.
               --
               pl_log.ins_msg(pl_log.ct_error_msg, l_object_name,
                   'TABLE="replenlst"'
                   || '  KEY=[' || i_Taskid || '](i_Taskid)'
                   || '  ACTION=SELECT  MESSAGE="Replenlst record locked.'
                   || '  Sending record locked by another user to the RF."',
                   SQLCODE, SQLERRM,
                   ct_application_function, gl_pkg_name);

               rf_status := rf.STATUS_REC_lOCK_BY_OTHER;
               RAISE e_fail;
        END;
        
        DBMS_OUTPUT.PUT_LINE('TEST 7B: Task ID :'||i_Taskid);
        
        IF rf_status = swms.rf.STATUS_NORMAL THEN   ---2
            IF l_rpl_type IN ('NXL', 'NSP', 'UNA', 'MXL','MRL') THEN
                DBMS_OUTPUT.PUT_LINE('TEST 7C: l_pallet_id :'||l_pallet_id);
                
                BEGIN
                    SElECT inv_uom
                      INTO l_uom
                      FROM inv
                     WHERE logi_loc = l_pallet_id FOR UPDATE OF plogi_loc NOWAIT;
                EXCEPTION
                    WHEN ORACLE_REC_LOCKED THEN
                       --
                       -- INV record locked.
                       -- Log a message and set the return status.
                       --
                       pl_log.ins_msg(pl_log.ct_error_msg, l_object_name,
                            'TABLE="inv"'
                            || '  KEY=[' || l_pallet_id || '](l_pallet_id)'
                            || '  ACTION=SELECT  MESSAGE="INV record locked.'
                            || '  Sending inv record locked to the RF."',
                            SQLCODE, SQLERRM,
                            ct_application_function, gl_pkg_name);

                        rf_status := rf.STATUS_INV_REC_LOCKED;
                        RAISE e_fail;
                    WHEN OTHERS THEN
                       --
                       -- INV record not found or an oracle error.
                       -- Log a message and set the return status.
                       --
                       pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                            'TABLE="inv"'
                            || '  KEY=[' || l_pallet_id || '](l_pallet_id)'
                            || '  ACTION=SELECT  MESSAGE="Error selecting INV record.'
                            || '  Sending select inv failed to the RF."',
                            SQLCODE, SQLERRM,
                            ct_application_function, gl_pkg_name);

                       rf_status := rf.STATUS_SEL_INV_FAIL;
                       RAISE e_fail;
                END;
            
                DBMS_OUTPUT.PUT_LINE('TEST 7D: l_src_loc :'||l_src_loc);
            
                BEGIN
                    UPDATE inv
                       SET plogi_loc  = REPLACE (USER, 'OPS$')
                     WHERE logi_loc = l_pallet_id
                       AND plogi_loc  =  l_src_loc
                       AND plogi_loc  != logi_loc;
                EXCEPTION 
                    WHEN OTHERS THEN
                       --
                       -- INV record not found or an oracle error.
                       -- Log a message.  Continue processing but this may cause issues later.
                       --
                       pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                            'TABLE="inv"'
                            || '  KEY=[' || l_pallet_id || '](l_pallet_id)'
                            || '  ACTION=UPDATE  MESSAGE="Failed to update plogi_loc to user id.'
                            || '  Continue processing."',
                            SQLCODE, SQLERRM,
                            ct_application_function, gl_pkg_name);

                       Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'perform_pick : Update INV Failed.', SQLCODE, SQLERRM);
                END;
            
                
                DBMS_OUTPUT.PUT_LINE('TEST 7E: l_dest_loc :'||l_dest_loc);
                BEGIN
                    INSERT INTO trans(trans_id,
                                      trans_type,
                                      trans_date,
                                      prod_id,
                                      qty_expected,
                                      qty,
                                      user_id,
                                      src_loc,
                                      dest_loc, 
                                      pallet_id,
                                      batch_no, 
                                      cust_pref_vendor,
                                      exp_date,
                                      mfg_date, 
                                      uom,
                                      labor_batch_no,
                                      replen_task_id,
                                      replen_creation_type,
                                      replen_type,
                                      task_priority,
                                      suggested_task_priority)
                               VAlUES 
                                     (trans_id_seq.NEXTVAL,
                                      'IND',
                                      SYSDATE,
                                      l_prod_id,
                                      l_qty,
                                      l_qty,
                                      USER,
                                      l_src_loc,
                                      l_dest_loc,
                                      l_pallet_id, 
                                      '99',
                                      '-',
                                      l_exp_date,
                                      l_mfg_date,
                                      l_uom,
                                      'FN' || i_Taskid,
                                      i_Taskid,
                                      l_replen_creation_type,
                                      l_rpl_type,
                                      l_task_priority,
                                      l_suggested_task_priority );
                EXCEPTION 
                    WHEN OTHERS THEN
                       --
                       -- Insert into TRANS failed.
                       -- Log a message.  We do not stop processing though this may cause an issue later.
                       --
                       pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                            'TABLE="trans"'
                            || '  i_taskid[' || i_Taskid || ']'
                            || '  ACTION=INWSERT  MESSAGE="Error inserting IND transaction.',
                            SQLCODE, SQLERRM,
                            ct_application_function, gl_pkg_name);

                       Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'perform_pick : Insert Trans Failed.', SQLCODE, SQLERRM);
                END;                           
            END IF;
            
            IF l_loop_count = 1 THEN
                l_merge_flag := 'N';
            ELSE
                l_merge_flag := 'Y';
            END IF;
            
            DBMS_OUTPUT.PUT_LINE('TEST 7F: l_dest_loc :'||l_dest_loc);      

            -- IF (pl_libswmslm.lmf_forklift_active() = swms.rf.STATUS_NORMAL) THEN    -- 04/12/2016 Brian Bent  Use pl_lmf

            IF (pl_lmf.f_forklift_active = TRUE) THEN
               pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                           'Forklift labor is active.  Sign onto labor batch.'
                           || '  i_taskid[' || i_Taskid || ']',
                           NULL, NULL,
                           ct_application_function, gl_pkg_name);

                DBMS_OUTPUT.PUT_LINE('TEST 7G: i_Taskid :'||i_Taskid);  

                rf_status := logon_to_labor_batch(l_rpl_type,
                                                  REPLACE(USER, 'OPS$'), 
                                                  i_Equip_id,
                                                  i_Taskid,
                                                  l_merge_flag,
                                                  l_lbr_batch, 
                                                  l_float_no,
                                                  l_drop_qty);

                DBMS_OUTPUT.PUT_LINE('TEST 7H: rf_status :'||rf_status);  
            END IF;
            
            DBMS_OUTPUT.PUT_LINE('TEST 7I: Status :'||rf_status);

            IF rf_status = swms.rf.STATUS_NORMAL THEN
                BEGIN
                    UPDATE replenlst
                       SET status  = 'PIK',
                           user_id = REPLACE (USER, 'OPS$')
                     WHERE Task_id = i_Taskid;
                EXCEPTION
                    WHEN OTHERS THEN
                       --
                       -- REPLENLST record update failed.
                       -- Log a message and set the return status.
                       --
                       pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                            'TABLE="replenlst"'
                            || '  KEY=[' || i_Taskid || '](i_Taskid)'
                            || '  ACTION=UPDATE  MESSAGE="Failed to update status to PIK and user_id to the user id.'
                            || '  Sending rpl update fail to the RF."',
                            SQLCODE, SQLERRM,
                            ct_application_function, gl_pkg_name);

                        rf_status  := rf.STATUS_RPL_UPDATE_FAIL;
                        RAISE e_fail;
                END;            
            END IF;

            DBMS_OUTPUT.PUT_LINE('TEST 7J: Status :'||rf_status);

        END IF; -- 2 rf_status = swms.rf.STATUS_NORMAL
    END IF; --1 rf_status = swms.rf.STATUS_NORMAL

    --
    -- Log ending the procedure.
    --
    pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
            'Ending function'
            || ' (i_Taskid['  || i_Taskid            || ']'
            || ',i_Equip_id[' || i_Equip_id          || '])'
            || '  rf_status[' || TO_CHAR(rf_status)  || ']',
            NULL, NULL,
            ct_application_function, gl_pkg_name);
  
  RETURN rf_status;
EXCEPTION
    WHEN e_fail THEN
        RETURN rf_status;
END perform_pick;


------------------------------------------
-- substitute_pallet
------------------------------------------
FUNCTION substitute_pallet(
    i_Taskid             IN VARCHAR2,
    i_newpallet          IN VARCHAR2)
  RETURN swms.rf.status
IS
    rf_status   swms.rf.status := swms.rf.STATUS_NORMAL;
    l_new_pallet    VARCHAR2 (20)  := i_newpallet;
    l_msg1          VARCHAR2 (120) := NUll;
    l_msg           VARCHAR2(120);
    
    CURSOR c_repl
    IS
        SElECT pallet_id,
               type,
               src_loc,
               dest_loc,
               inv_dest_loc,
               qty,
               drop_qty,
               prod_id,
               cust_pref_vendor,
               float_no,
               exp_date,
               batch_no,
               order_id
          FROM replenlst
         WHERE task_id = i_Taskid FOR UPDATE OF pallet_id;
         
    r_repl          c_repl%ROWTYPE;
    row_locked      EXCEPTION;
    l_batch_no      batch.batch_no%TYPE;
    l_home_batch_No batch.batch_no%TYPE;
    PRAGMA EXCEPTION_INIT (row_locked, -54);

BEGIN
    BEGIN
        l_msg := NUll;
        
        OPEN c_repl;
        FETCH c_repl iNTO r_repl;
        IF (c_repl%NOTFOUND) THEN
            RAISE NO_DATA_FOUND;
        END IF;

        l_msg := 'Task = ' || i_Taskid || ', old pallet =  ' || r_repl.pallet_id || ', new Pallet = ' || l_new_pallet;
        
        CASE (r_repl.type)
            WHEN 'NXL' THEN
                l_batch_no := 'FN' || i_Taskid;
            WHEN 'NSP' THEN
                l_batch_no := 'FN' || i_Taskid;
            WHEN 'UNA' THEN
                l_batch_no := 'FN' || i_Taskid;
            WHEN 'MRL' THEN
                l_batch_no := 'FN' || i_Taskid; 
            WHEN 'MXL' THEN
                l_batch_no := 'FN' || i_Taskid; 
            WHEN 'DXL' THEN
                l_batch_no := 'FR' || r_repl.float_no;
            WHEN 'DSP' THEN
                l_batch_no := 'FR' || r_repl.float_no;            
            ELSE
                l_batch_no := NUll;
        END CASE;
        
        l_msg1 := '. Before Update Batch ';
        
        UPDATE batch
           SET ref_no      = l_new_pallet
         WHERE batch_no IN (l_batch_no, l_home_batch_No)
           AND Ref_No      = r_repl.Pallet_id;
           
        l_msg1           := '. Before IF NDM  check ';
        
        IF (r_repl.type NOT IN ('NXL', 'NSP', 'UNA', 'MXL', 'MRL')) THEN
            BEGIN
                l_msg1 := '. Before inv update 1';
                UPDATE inv 
                   SET logi_loc = r_repl.pallet_id 
                 WHERE logi_loc = l_new_pallet;
           
                l_msg1 := '. Before trans update';
          
                UPDATE trans
                   SET pallet_id = l_new_pallet,
                       cmt = 'Old Pallet = ' || r_repl.pallet_id
                 WHERE trans_type = 'RPL'
                   AND pallet_id = r_repl.pallet_id
                   AND cmt IS NULL
                   AND replen_task_id = i_Taskid;
             
                l_msg1 := '. Before floats update';
          
                UPDATE floats
                   SET pallet_id  = l_new_pallet
                 WHERE float_no = r_repl.float_no
                   AND pallet_id  = r_repl.pallet_id;
            END;
        ELSE
            UPDATE inv
              SET qty_alloc  = 0
            WHERE logi_loc = r_repl.pallet_id
              AND qty_alloc != 0;
              
            UPDATE inv 
               SET qty_alloc = qoh 
             WHERE logi_loc = l_new_pallet;
        END IF;
        
        l_msg1 := '. Before replenlst update';
      
        UPDATE replenlst 
           SET pallet_id = l_new_pallet 
        WHERE CURRENT OF c_repl;
        
        l_msg1 := '. Before trans insert';
        
        INSERT INTO trans (trans_id, trans_type, trans_date, prod_id, 
                           pallet_id, src_loc, dest_loc, qty, float_no,
                           exp_date, user_id, cmt, qty_expected, cust_pref_vendor,
                           batch_no, order_id, replen_task_id, bck_dest_loc )
                    VAlUES(trans_id_seq.NEXTVAL, 'SPR', SYSDATE, r_repl.prod_id,
                           l_new_pallet, r_repl.src_loc, NVL (r_repl.inv_dest_loc, r_repl.dest_loc), r_repl.qty, r_repl.float_no,
                           r_repl.exp_date, USER, 'Old Pallet = ' || r_repl.pallet_id, r_repl.qty, r_repl.cust_pref_vendor,
                           r_repl.batch_no, r_repl.order_id, i_Taskid, DECODE (r_repl.inv_dest_loc, NULL, NULL, r_repl.dest_loc));
                           
        ClOSE c_repl;
        
        l_msg := l_msg1;
    EXCEPTION
        WHEN row_locked THEN
            l_msg := l_msg || l_msg1;
            rf_status := rf.STATUS_REC_LOCK_BY_OTHER;
        WHEN NO_DATA_FOUND THEN
            l_msg := l_msg || l_msg1;
            rf_status := rf.STATUS_SEL_RPL_FAIL;
        WHEN OTHERS THEN
            l_msg := SQLERRM;
            rf_status := rf.STATUS_DATA_ERROR;
    END;

    IF rf_status = swms.rf.STATUS_NORMAL THEN
        Pl_Text_log.ins_Msg('',Ct_Program_Code,'Message from PL/SQL = ' || l_msg, NULL, NULL);
    ELSE
        Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Error Occured in Substitute Pallet. ' || l_msg, SQLCODE, SQLERRM);
    END IF;
                
    RETURN rf_status;
END substitute_pallet;

------------------------------------------
-- unpick_pallet
------------------------------------------
FUNCTION unpick_pallet(
    i_Taskid             IN VARCHAR2,
    i_Scanned_Data       IN VARCHAR2,
    i_Equip_id           IN VARCHAR2,
    i_Scan_Method        IN VARCHAR2)
  RETURN swms.rf.status
IS
    rf_status swms.rf.status := swms.rf.STATUS_NORMAL;
    l_rpl_rec   rpl_rec;
    lscandata   VARCHAR2(20);
    l_cnt       NUMBER;
    e_fail      EXCEPTION;
BEGIN
    IF rf_status = swms.rf.STATUS_NORMAL THEN
        BEGIN
            SElECT status,
                   src_loc,
                   NVL(dest_loc, CHR(10)),
                   pallet_id,
                   prod_id,
                   exp_date,
                   mfg_date,
                   qty,
                   type,
                   mx_batch_no,
                   uom
              INTO l_rpl_rec
              FROM replenlst
             WHERE task_id = i_Taskid
               AND user_id = REPLACE (USER, 'OPS$');
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                rf_status := rf.STATUS_REPLEN_DONE;
                RAISE e_fail;
        END;
    END IF; 
    
    IF rf_status = swms.rf.STATUS_NORMAL  THEN
        IF l_rpl_rec.l_status != 'PIK' AND l_rpl_rec.l_status != 'HOM' THEN
            rf_status := rf.STATUS_NOT_PIK_YET;         
        ELSE
            IF l_rpl_rec.mx_batch_no IS NOT NULL THEN
                IF TRIM(i_Scanned_Data) IS NOT NULL THEN
                    SELECT COUNT(*)
                      INTO l_cnt
                      FROM loc l, lzone lz, zone z
                     WHERE l.logi_loc = lz.logi_loc
                       AND z.zone_id = lz.zone_id
                       AND l.logi_loc = i_Scanned_Data
                       AND z.rule_id IN (0, 1, 2)
                       AND l.perm != 'Y'
                       AND z.zone_type = 'PUT'; 
                    
                    IF l_cnt = 0 THEN
                        rf_status := rf.STATUS_INV_DEST_LOCATION;
                    RAISE e_fail;
                    END IF;
                END IF;
                
                FOR r_task IN (SELECT task_id FROM replenlst WHERE mx_batch_no =  l_rpl_rec.mx_batch_no)
                LOOP
                    rf_status := pl_rf_matrix_replen_common.reset_task (r_task.task_id, i_Scanned_Data, i_Equip_id, i_Scan_Method);
                END LOOP;
            ELSE    
                rf_status := pl_rf_matrix_replen_common.reset_task (i_Taskid, i_Scanned_Data, i_Equip_id, i_Scan_Method);
            END IF; 
        END IF;
    END IF;    
        
    RETURN rf_status;
EXCEPTION
    WHEN e_fail THEN
        RETURN rf_status;
END unpick_pallet;


---------------------------------------------------
-- logon_to_labor_batch()
---------------------------------------------------  
FUNCTION logon_to_labor_batch(
    i_rpl_type           IN VARCHAR2,
    i_user_id            IN VARCHAR2,
    i_Equip_id           IN VARCHAR2,
    i_Taskid             IN VARCHAR2,    
    i_mergeflag          IN VARCHAR2,
    i_lbr_batch          IN VARCHAR2, 
    i_floatno            IN VARCHAR2,
    i_drop_qty           IN NUMBER )
  RETURN swms.rf.status
IS
    l_object_name       VARCHAR2(30) := 'logon_to_labor_batch';

    rf_status           swms.rf.status := swms.rf.STATUS_NORMAL;
    l_pallet            VARCHAR2(18);
    l_date              DATE;
    l_prev_batch_no     VARCHAR2(14) := NUll;
    l_supervisor_id     VARCHAR2(30) := NUll;   
    l_parent_batch_no   VARCHAR2(14) := ' ';
    l_signon_type       VARCHAR2(1);
    e_fail              EXCEPTION;
    l_is_ndm            CHAR(1) := 'N';
BEGIN
   --
   -- Log starting the function.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
            'Starting function'
            || ' (i_rpl_type['   || i_rpl_type          || ']'
            || ',i_user_id['     || i_user_id           || ']'
            || ',i_Equip_id['    || i_Equip_id          || ']'
            || ',i_Taskid['      || i_Taskid            || ']'
            || ',i_mergeflag['   || i_mergeflag         || ']'
            || ',i_lbr_batch['   || i_lbr_batch         || ']'
            || ',i_floatno['     || i_floatno           || ']'
            || ',i_drop_qty['    || TO_CHAR(i_drop_qty) || '])',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

    DBMS_OUTPUT.PUT_LINE('TEST 7HA: logon_to_labor_batch Status :'||rf_status);

    IF rf_status = swms.rf.STATUS_NORMAL THEN   
        IF (i_mergeflag = 'Y') THEN
            l_signon_type := 'M';
        ELSE
            l_signon_type := 'N';
        END IF;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
               'l_signon_type[' || l_signon_type || ']',
               NULL, NULL, ct_application_function, gl_pkg_name);
        
        BEGIN
            SElECT pallet_id
              INTO l_pallet
              FROM replenlst
             WHERE task_id = i_Taskid
               AND type IN ('NXL', 'NSP', 'UNA', 'MXL', 'MRL')
               AND status = 'NEW';
               
             l_is_ndm := 'Y';  
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_is_ndm := 'N';        
        END;
        
        DBMS_OUTPUT.PUT_LINE('TEST 7HB: l_pallet :'||l_pallet || '   l_is_ndm:'||l_is_ndm );

        IF l_is_ndm = 'Y' THEN
            SElECT MAX (batch_date)
              INTO l_date
              FROM Batch
             WHERE batch_no = 'FN' || l_pallet;
                    
            DELETE
              FROM batch
             WHERE batch_no = 'FN' || l_pallet
               AND status = 'F'
               AND batch_date < l_date;
        END IF; 

        rf_status := pl_libswmslm.lmc_batch_istart(i_user_id, l_prev_batch_no, l_supervisor_id);
        
        Pl_Text_log.ins_Msg('',Ct_Program_Code,'TEST After pl_libswmslm.lmc_batch_istart Status ' || rf_status, NULL, NULL);
        
        IF rf_status != swms.rf.STATUS_NORMAL THEN
            RAISE e_fail;
        END IF;
        DBMS_OUTPUT.PUT_LINE('TEST 7HC: i_rpl_type :'||i_rpl_type );
        
        IF i_rpl_type IN ('NXL', 'NSP', 'UNA', 'MXL', 'MRL') THEN 
            DBMS_OUTPUT.PUT_LINE('TEST 7HD: l_signon_type :'||l_signon_type || '   i_Taskid:'||i_Taskid );
            DBMS_OUTPUT.PUT_LINE('TEST 7HE: l_parent_batch_no :'||l_parent_batch_no || '   i_user_id:'||i_user_id );
            DBMS_OUTPUT.PUT_LINE('TEST 7HF: l_supervisor_id :'||l_supervisor_id || '   i_Equip_id:'||i_Equip_id );

            Pl_Text_log.ins_Msg('',Ct_Program_Code,'TEST Before  pl_libswmslm.lmf_signon_to_forklift_batch l_signon_type '||l_signon_type , NULL, NULL);    

            rf_status := pl_libswmslm.lmf_signon_to_forklift_batch(l_signon_type,
                                                                   'FN' || i_Taskid,
                                                                   l_parent_batch_no, 
                                                                   i_user_id,
                                                                   l_supervisor_id,
                                                                   i_Equip_id);      

            DBMS_OUTPUT.PUT_LINE('TEST 7HG: rf_status :'||rf_status );                                   

            Pl_Text_log.ins_Msg('',Ct_Program_Code,'TEST After  pl_libswmslm.lmf_signon_to_forklift_batch Status '||rf_status, NULL, NULL);         
        ELSE
           -- 'N' is the syspend flag.  
           rf_status := pl_libswmslm.attach_to_OP_dmd_fk_batch(i_lbr_batch, i_user_id, i_Equip_id, 'N' , i_mergeflag);
        END IF;    
    END IF;
    
    RETURN rf_status;
EXCEPTION
    WHEN e_fail THEN    
        RETURN rf_status;
END logon_to_labor_batch;

END PL_RF_MATRIX_REPLEN_PICK;
/

SHOW ERRORS
CREATE OR REPLACE PUBLIC SYNONYM pl_rf_matrix_replen_pick FOR swms.pl_rf_matrix_replen_pick;

