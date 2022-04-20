CREATE OR REPlACE PACKAGE pl_rf_matrix_replen_drop AUTHID CURRENT_USER
AS
------------------------------------------------------------------------------------------
-- Package
--   PL_RF_MATRIX_REPLEN_DROP
--
-- Description
--   This package contains functions and procedures required for the matrix
--   replenishment drop
--
-- Parameters
--
--
-- Modification History
--
--    Date    Designer Comments
--    -------- -------- ---------------------------------------------------------
--   07/24/16 sred5131 Initial version
--
--    07/19/16 bben0556 Brian Bent
--                            Project:
--                R30.5--WIB#663--CRQ000000007533_Save_what_created_NDM_in_trans_RPL_record
--
--                      Modified "drop_pallet()" to populate
--                      these new columns when updating the trans record:
--                         - TRANS.REPLEN_CREATION_TYPE    (from replenlst.replen_type)
--                         - TRANS.REPLEN_TYPE             (from replenlst.type)
--                         - TRANS.TASK_PRIORITY           (from user_downloaded_tasks.priority)
--                         - TRANS.SUGGESTED_TASK_PRIORITY (from user_downloaded_tasks.priority)
--
--                      Changed cursor "c_repl" to select "replen_type"
--                      from the REPLENLST table.
--                      Changed cursor "c_repl" to select "priority"
--                      from the USER_DOWNLOAD_TASKS table.
--
--                      In the TRANS update statement add:
--                      - t.replen_creation_type      = r_repl.replen_type
--                      - t.replen_type               = r_repl.type
--                      - t.task_priority             = r_repl.task_priority
--                      - t.suggested_task_priority   = r_repl.suggested_task_priority
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
  
  -------------------------------------------------------------------------------------------
  -- Public Constants
  -------------------------------------------------------------------------------------------
  Ct_Program_Code CONSTANT VARCHAR2 (50) := 'PL_RF_MATRIX_REPLEN_DROP';--'RFMXRPLDP';
  
FUNCTION perform_replen_drop(		-- this function is called directly from RF client via SOAP web service
    i_Rf_log_init_Record IN swms.rf_log_init_record,
    i_Equip_id           IN VARCHAR2,
    i_Fm_Aisle           IN VARCHAR2,
    i_To_Aisle           IN VARCHAR2,
    i_Taskid             IN Varchar2,
    i_Scanned_Data       IN Varchar2,
    i_Scan_Method        IN Varchar2,
    o_Detail_Collection OUT swms.replen_list_result_obj)
  RETURN swms.rf.status;
  
  FUNCTION drop_pallet(
    i_Taskid             IN VARCHAR2,
    i_Priority          IN VARCHAR2,
    i_Scanned_Data       IN VARCHAR2,
    i_Scan_Method        IN VARCHAR2)
  RETURN swms.rf.status;
END pl_rf_matrix_replen_drop;
/


CREATE OR REPlACE PACKAGE BODY pl_rf_matrix_replen_drop
AS
  ------------------------------------------------------------------------------------------
  -- Package
  --   PL_RF_MATRIX_REPLEN_DROP
  --
  -- Description
  --   This package contains procedures and functions required for the matrix
  --   replenishment drop
  --
  --
  -- Modification History
  --
  --   Date           Designer         Comments
  --  -----------    ---------------  ---------------------------------------------------------
  --  24-JUl-2014     sred5131         initial Version
  ---------------------------------------------------------------------------------------------
FUNCTION perform_replen_drop(		-- this function is called directly from RF client via SOAP web service
	i_Rf_log_init_Record	IN Swms.Rf_log_init_Record,
	i_Equip_id				IN  VARCHAR2,
	i_Fm_Aisle				IN  VARCHAR2,
	i_To_Aisle				IN  VARCHAR2,
	i_Taskid				IN  VARCHAR2,
	i_Scanned_Data			IN  VARCHAR2,
	i_Scan_Method			IN  VARCHAR2,
	o_Detail_Collection		OUT swms.replen_list_result_obj)
RETURN swms.rf.status
AS
	rf_status	swms.rf.status := swms.rf.STATUS_NORMAL;
	l_pallet_id	replenlst.pallet_id%TYPE;
	l_replen_type	replenlst.type%TYPE;
	l_priority	replenlst.priority%TYPE;
	e_fail		EXCEPTION;
	l_refresh_list	NUMBER;
	l_cnt		NUMBER;
BEGIN
	-- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
	-- This must be done before calling rf.Initialize().

	o_Detail_Collection := swms.replen_list_result_obj(swms.replen_list_result_table());


	-- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.
    
	rf_status := rf.initialize ( i_rf_log_init_record ) ;
    DBMS_OUTPUT.PUT_LINE('perform_replen_drop 1:  Status:'||rf_status);
    
	IF rf_status = swms.rf.STATUS_NORMAL THEN
        BEGIN
            IF ( i_Taskid = 0 ) THEN
                rf_status  := rf.STATUS_NO_TASK;
                RAISE e_fail;
            ElSE
                BEGIN
                    SElECT pallet_id,
                           type,
                           priority
                      INTO l_pallet_id,
                           l_replen_type,
                           l_priority
                      FROM replenlst
                     WHERE Task_id = i_Taskid;
                     
                     DBMS_OUTPUT.PUT_LINE('perform_replen_drop 2:  l_pallet_id:'||l_pallet_id ||'     l_replen_type:'||l_replen_type || '    l_priority:'||l_priority );
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        Pl_Text_log.ins_Msg('',Ct_Program_Code,'REPLENLST TaskId not found. '||i_Taskid, NULL, NULL);
                        rf_status := rf.STATUS_NO_TASK;
                        RAISE e_fail;   
                END;
                DBMS_OUTPUT.PUT_LINE('perform_replen_drop 3:  i_Taskid:'||i_Taskid ||'     l_priority:'||l_priority);
                DBMS_OUTPUT.PUT_LINE('perform_replen_drop 4:  i_Scanned_Data:'||i_Scanned_Data ||'     i_Scan_Method:'||i_Scan_Method);
                
                l_refresh_list := 1;
                
                --Check the number of task available in the batch
                SELECT COUNT(*)
                  INTO l_cnt
                  FROM replenlst
                 WHERE mx_batch_no = (SELECT NVL(mx_batch_no, 0) FROM replenlst WHERE task_id = i_Taskid );
                
                --If more than one task (existing) available, we will not refresh the list
                IF l_cnt > 1 THEN
                    l_refresh_list := 0;
                END IF;     
                
                rf_status := drop_pallet(i_Taskid, l_priority, i_Scanned_Data, i_Scan_Method );
                
                DBMS_OUTPUT.PUT_LINE('perform_replen_drop 5:  l_pallet_id:'||l_pallet_id);
            END IF;
            
            IF rf_status = swms.rf.STATUS_NORMAL THEN
                DBMS_OUTPUT.PUT_LINE('perform_replen_drop 6:  l_replen_type:'||l_replen_type);
                IF l_replen_type IN ('DXL', 'DSP') THEN
                    rf_status := pl_rf_matrix_replen_common.update_scan_method(i_Scan_Method, l_pallet_id, 2);
                END IF;
                DBMS_OUTPUT.PUT_LINE('perform_replen_drop 7:  i_Fm_Aisle:'||i_Fm_Aisle ||'   i_To_Aisle:'||i_To_Aisle);
                
                IF l_refresh_list = 1 THEN
                    rf_status := pl_rf_matrix_replen_list.retrieve_replen_list_internal (i_Fm_Aisle, i_To_Aisle, i_Equip_id, i_Taskid, O_Detail_Collection);  
                END IF; 
                DBMS_OUTPUT.PUT_LINE('perform_replen_drop 8:  l_replen_type:'||l_replen_type);            
            ELSE
                RAISE e_fail;
            END IF;
        END;
    END IF;    /* rf.initialize() returned NORMAL */

    --If batch have multiple task left ten don't refresh the list
    IF l_refresh_list = 0 THEN
        rf_status := rf.STATUS_NO_NEW_TASK;
    END IF;
    
    rf.complete (rf_status);
    RETURN rf_status;
EXCEPTION
    WHEN e_fail THEN
        ROLLBACK;
        rf.complete (rf_status);
        RETURN rf_status;
    WHEN OTHERS THEN
        rf.logexception(); -- log it
        RAISE;
END perform_replen_drop;

-------------------------------------
--drop_pallet
-------------------------------------
FUNCTION drop_pallet(
    i_Taskid             IN VARCHAR2,
    i_Priority           IN VARCHAR2,
    i_Scanned_Data       IN VARCHAR2,
    i_Scan_Method        IN VARCHAR2)
  RETURN swms.rf.status
IS
    rf_status           swms.rf.status := swms.rf.STATUS_NORMAL;
    l_spc               pm.spc%TYPE;       
    l_max_qty           pm.max_qty%TYPE;
    l_qty_alloc         inv.qty_alloc%TYPE;
    l_qoh               inv.qoh%TYPE;
    l_temp              NUMBER;
    l_prompt_for_hst    VARCHAR2(40) := 'N';  
    --l_ind_loc           zone.induction_loc%TYPE;  
    l_sys_msg_id        NUMBER;
    l_ret_val           NUMBER;
    l_una_home          BOOLEAN;
    e_fail              EXCEPTION;
    ORACLE_REC_LOCKED   EXCEPTION;
    l_slot_type         loc.slot_type%TYPE; 
    l_inv_status        inv.status%TYPE;
    
    PRAGMA EXCEPTION_INIT(ORACLE_REC_LOCKED, -54);
    
    CURSOR c_repl IS
        SELECT  r.type,
                r.src_loc,
                r.dest_loc,
                NVL (r.inv_dest_loc, r.dest_loc) inv_dest_loc,
                r.status,
                r.pallet_id,
                r.prod_id,
                i.exp_date exp_date,
                i.mfg_date mfg_date,
                NVL (i.rec_id, ' ') rec_id,
                NVL (r.op_acquire_flag, 'N') op_acquire_flag,
                r.qty,
                r.uom,
                i.rec_date rec_date,
                i.inv_date inv_date,
                NVL (i.lot_id, ' ') lot_id,
                p.spc,
                r.mx_batch_no,
                r.replen_type,
                pl_replenishments.get_task_priority(r.task_id, USER) task_priority,             /* -1  is used if task not found in user_downloaded_tasks */
                pl_replenishments.get_suggested_task_priority(USER)  suggested_task_priority    /* -1  is used if task not found in user_downloaded_tasks */
           FROM inv i,
                replenlst r,
                pm p                
          WHERE r.task_id         = i_Taskid            
            AND i.logi_loc        = r.pallet_id
            AND r.prod_id         = p.prod_id
            AND r.type            IN ('NXL', 'NSP', 'UNA', 'MXL', 'MRL')            
      UNION ALL
        SELECT  r.type,
                r.src_loc,
                r.dest_loc,
                NVL (r.inv_dest_loc, r.dest_loc) inv_dest_loc,
                r.status,
                r.pallet_id,
                r.prod_id,
                r.exp_date exp_date,
                r.mfg_date mfg_date,
                r.rec_id rec_id,
                NVL (r.op_acquire_flag, 'N') op_acquire_flag,
                r.qty,
                r.uom,
                SYSDATE,
                SYSDATE,
                ' ',
                p.spc,
                r.mx_batch_no,
                r.replen_type,
                pl_replenishments.get_task_priority(r.task_id, USER) task_priority,             /* -1  is used if task not found in user_downloaded_tasks */
                pl_replenishments.get_suggested_task_priority(USER)  suggested_task_priority    /* -1  is used if task not found in user_downloaded_tasks */
           FROM replenlst r,
                pm p
          WHERE r.task_id          = i_Taskid   
            AND r.prod_id          = p.prod_id         
            AND r.cust_pref_vendor = p.cust_pref_vendor         
            AND r.type             IN ('DXL', 'DSP');
  
    r_repl      c_repl%ROWTYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('drop_pallet 1:  rf_status:'||rf_status);

    IF rf_status = swms.rf.STATUS_NORMAL THEN
        BEGIN
            OPEN c_repl;
            FETCH c_repl INTO r_repl;
            
            IF (c_repl%NOTFOUND) THEN
                Pl_Text_log.ins_Msg('',Ct_Program_Code,'Select from REPLENLST failed for task '||i_Taskid, NULL, NULL);
                Rf_Status := Rf.STATUS_SEL_RPL_FAIL;
                RAISE e_fail;
            END IF;
        EXCEPTION
            WHEN ORACLE_REC_LOCKED THEN
                Pl_Text_log.ins_Msg('',Ct_Program_Code,'REPLENLST record locked for task '||i_Taskid, NULL, NULL);
                rf_status := Rf.STATUS_REC_LOCK_BY_OTHER;
                CLOSE c_repl;
                RAISE e_fail;
        END;
        
        
        CLOSE c_repl;
        
        DBMS_OUTPUT.PUT_LINE('drop_pallet 2:  r_repl.Dest_loc:'||r_repl.Dest_loc ||'        i_Scanned_Data:'||i_Scanned_Data );

        IF rf_status = swms.rf.STATUS_NORMAL THEN
            IF r_repl.type IN ('NXL', 'MXL') AND r_repl.op_acquire_flag != 'Y' THEN
                BEGIN
                    SELECT COUNT(*)
                      INTO l_temp
                      FROM lzone lz, zone z, loc l
                     WHERE lz.zone_id = z.zone_id
                       AND l.logi_loc = lz.logi_loc
                       AND l.logi_loc = i_Scanned_Data
                       AND z.z_area_code = NVL(pl_matrix_common.f_get_pm_area(r_repl.prod_id),'XX')
                       AND l.slot_type IN ('MXI', 'MXT')
                       AND z.zone_type = 'PUT';
                       
                    /*SELECT COUNT(*) 
                      INTO l_temp 
                      FROM loc 
                     WHERE slot_type = 'MXI'
                       AND logi_loc = i_Scanned_Data;*/
                    
                    IF l_temp = 0 THEN
                        Pl_Text_log.ins_Msg('',Ct_Program_Code,'Dest loc doesnt match Scanned Dest '||i_Scanned_Data, NULL, NULL);
                        rf_status := rf.STATUS_INV_DEST_LOCATION;
                        RAISE e_fail;
                    END IF; 
                END;
            END IF;
            
            IF r_repl.type IN ('NSP', 'DSP', 'UNA', 'MRL', 'DXL') OR (r_repl.type = 'NXL' AND r_repl.op_acquire_flag = 'Y') THEN
                IF r_repl.dest_loc != i_Scanned_Data THEN
                    Pl_Text_log.ins_Msg('',Ct_Program_Code,'Dest loc doesnt match Scanned Dest '||i_Scanned_Data, NULL, NULL);
                    rf_status := rf.STATUS_INV_DEST_LOCATION;
                    RAISE e_fail;
                END IF; 
            END IF;
            
            DBMS_OUTPUT.PUT_LINE('drop_pallet 3:  r_repl.status:'||r_repl.status);
            IF r_repl.status != 'PIK' THEN
                Pl_Text_log.ins_Msg('',Ct_Program_Code,'Replen Status is '||r_repl.Status, NULL, NULL);
                rf_status := rf.STATUS_NOT_PIK_YET;
                RAISE e_fail;
            END IF;  
    
            DBMS_OUTPUT.PUT_LINE('drop_pallet 4:  r_repl.Prod_id:'||r_repl.Prod_id);
            BEGIN
                SElECT DECODE (NVL (spc, 0), 0, 1, spc),
                       NVL (max_qty, 0)
                  INTO l_spc,
                       l_max_Qty
                  FROM pm
                 WHERE prod_id = r_repl.Prod_id;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    Pl_Text_log.ins_Msg('',Ct_Program_Code,'Select from PM failed for Product '||r_repl.Prod_id, NULL, NULL);
                    rf_status := rf.STATUS_INV_PRODID;
                    RAISE e_fail;
            END;
            
            IF r_repl.type = 'UNA' THEN         
                SELECT COUNT(*)
                  INTO l_temp
                  FROM loc
                 WHERE perm = 'Y'
                   AND logi_loc = r_repl.dest_loc;
                 
                IF l_temp > 0 THEN
                    l_una_home := TRUE;
                ELSE
                    l_una_home := FALSE;
                END IF;              
            END IF; 
            DBMS_OUTPUT.PUT_LINE('drop_pallet 5:  r_repl.type:'||r_repl.type);
            
            IF (r_repl.type IN ('NXL', 'MXL', 'MRL') AND r_repl.op_acquire_flag != 'Y') OR (r_repl.type = 'UNA' AND l_una_home = FALSE) THEN
                BEGIN
                    SELECT qty_alloc, qoh
                      INTO l_qty_alloc, l_qoh
                      FROM inv
                     WHERE logi_loc = r_repl.pallet_id 
                     FOR UPDATE OF plogi_loc NOWAIT;  
                EXCEPTION
                    WHEN ORACLE_REC_LOCKED THEN
                        Pl_Text_log.ins_Msg('',Ct_Program_Code,'SELECT INV FOR UPDATE failed for logi_loc '||r_repl.pallet_id, NULL, NULL);
                        rf_status := rf.STATUS_INV_REC_LOCKED;
                        RAISE e_fail;
                END; 
                
                IF rf_status = swms.rf.STATUS_NORMAL THEN
                    IF l_qty_alloc - l_qoh != 0 THEN
                        rf.logmsg(rf.LOG_WARNING, 'At drop quantity allocate is not euqal to quantity oh hand for pallet_id :'||r_repl.pallet_id);
                    END IF;
                    
                    BEGIN
                        UPDATE inv
                           SET plogi_loc = i_Scanned_Data,  
                               qty_alloc = 0    
                         WHERE logi_loc = r_repl.pallet_id;  
                    EXCEPTION
                        WHEN OTHERS THEN                    
                            Pl_Text_log.ins_Msg('',Ct_Program_Code,'Update INV failed for Dest loc '||r_repl.inv_dest_loc, NULL, NULL);
                            rf_status := rf.STATUS_INV_UPDATE_FAIL;
                            RAISE e_fail;
                    END;                        
                END IF;      
            END IF;
            
            IF (r_repl.type IN ('NSP') AND r_repl.op_acquire_flag != 'Y') OR (r_repl.type = 'UNA' AND l_una_home = TRUE) THEN
                BEGIN
                    SELECT 0
                      INTO l_temp
                      FROM inv
                     WHERE plogi_loc = r_repl.inv_dest_loc 
                       AND plogi_loc = logi_loc
                     FOR UPDATE OF qoh NOWAIT;   
                EXCEPTION
                    WHEN ORACLE_REC_LOCKED THEN
                        Pl_Text_log.ins_Msg('',Ct_Program_Code,'SELECT INV FOR UPDATE failed for Dest Loc '||r_repl.inv_dest_loc, NULL, NULL);
                        rf_status := rf.STATUS_INV_REC_LOCKED;
                        RAISE e_fail;
                END; 
                
                DBMS_OUTPUT.PUT_LINE('drop_pallet 6:  rf_status:'||rf_status);
                IF rf_status = swms.rf.STATUS_NORMAL THEN
                    BEGIN
                        UPDATE inv
                           SET qoh = qoh + r_repl.qty, --DECODE (inv_uom, 1, r_repl.qty, DECODE (r_repl.type, 'NXL', r_repl.qty, 'NSP', r_repl.qty, r_repl.qty * l_spc)),
                               qty_planned = qty_planned - r_repl.qty, --DECODE (inv_uom, 1, r_repl.qty, DECODE (r_repl.type, 'NXL', r_repl.qty, 'NSP', r_repl.qty, r_repl.qty * l_spc)),
                               exp_date = r_repl.exp_date,
                               mfg_date = r_repl.mfg_date,
                               rec_id = r_repl.rec_id,
                               rec_date = r_repl.rec_date,
                               inv_date = r_repl.inv_date,
                               lot_id = r_repl.lot_id
                         WHERE plogi_loc = r_repl.inv_dest_loc
                           AND plogi_loc = logi_loc;  --REPlACE (USER, 'OPS$');--   -- review with Kaz
                    EXCEPTION
                        WHEN OTHERS THEN                    
                            Pl_Text_log.ins_Msg('',Ct_Program_Code,'Update iNV failed for Dest loc '||r_repl.inv_dest_loc, NULL, NULL);
                            rf_status := rf.STATUS_INV_UPDATE_FAIL;
                            RAISE e_fail;
                    END;        
                    
                    DBMS_OUTPUT.PUT_LINE('drop_pallet 7:  r_repl.uom :'||r_repl.uom );
                    
                    IF r_repl.uom = 1 THEN
                        BEGIN
                            SELECT 0
                              INTO l_temp
                              FROM inv
                             WHERE plogi_loc = REPLACE (USER, 'OPS$')  --   REPLACE r_repl.src_loc 
                             FOR UPDATE OF qoh NOWAIT;   
                         
                        EXCEPTION
                            WHEN ORACLE_REC_LOCKED THEN
                                Pl_Text_log.ins_Msg('',Ct_Program_Code,'SElECT iNV FOR UPDATE failed for Dest loc'||r_repl.Src_loc, NULL, NULL);
                                rf_status := rf.STATUS_INV_REC_LOCKED;
                                RAISE e_fail;
                        END;
                        
                        DBMS_OUTPUT.PUT_LINE('drop_pallet 8:  r_repl.uom :'||r_repl.uom );
                        BEGIN          
                            UPDATE inv
                               SET qoh = qoh - r_repl.qty,
                                   qty_alloc = qty_alloc - r_repl.qty
                             WHERE logi_loc = r_repl.pallet_id  ; --REPlACED r_repl.src_loc;--  review with Kaz
                        EXCEPTION
                            WHEN OTHERS THEN
                                Pl_Text_log.ins_Msg('',Ct_Program_Code,'Update iNV failed for Source loc '||r_repl.src_loc, SQLCODE, SQLERRM);
                                rf_status := rf.STATUS_INV_UPDATE_FAIL;
                                RAISE e_fail;
                        END;
                        DBMS_OUTPUT.PUT_LINE('drop_pallet 9:  SQl%ROWCOUNT :'||SQl%ROWCOUNT );
                    ElSE
                        DBMS_OUTPUT.PUT_LINE('drop_pallet 10:  r_repl.pallet_id :'||r_repl.pallet_id );
                        BEGIN
                            DELETE inv
                             WHERE logi_loc = r_repl.pallet_id
                               AND logi_loc != plogi_loc;
                        EXCEPTION
                            WHEN OTHERS THEN
                                Pl_Text_log.ins_Msg('',Ct_Program_Code,'DElETE inv failed for LP ' || r_repl.Pallet_id || ', Source loc '||r_repl.Src_loc, SQLCODE, SQLERRM);
                                rf_status := rf.STATUS_DEL_INV_FAIL;
                                RAISE e_fail;
                        END;    
                        DBMS_OUTPUT.PUT_LINE('drop_pallet 11:  SQl%ROWCOUNT :'||SQl%ROWCOUNT );
                    END IF;
                END IF;
            END IF;  --IF r_repl.type IN ('NXL', 'NSP') THEN
            
            DBMS_OUTPUT.PUT_LINE('drop_pallet 12:  i_Scan_Method :'||i_Scan_Method );
            BEGIN
                UPDATE trans t
                   SET t.trans_type                    = 'RPL',
                       t.scan_method2                  = i_Scan_Method,
                       t.trans_date                    = SYSDATE,
                       t.replen_creation_type          = r_repl.replen_type,
                       t.replen_type                   = r_repl.type,
                       t.task_priority                 = r_repl.task_priority,
                       t.suggested_task_priority       = r_repl.suggested_task_priority
                 WHERE t.trans_type     = 'IND'
                   AND UPPER(t.user_id) = USER
                   AND t.pallet_id      = r_repl.pallet_id;
                   
            EXCEPTION
                WHEN OTHERS THEN
                    Pl_Text_log.ins_Msg('',Ct_Program_Code,'UPDATE Trans failed for IND trans, User id ' || REPLACE (USER, 'OPS$') || ', Pallet '||r_repl.pallet_id, SQLCODE, SQLERRM);
                    rf_status := rf.STATUS_TRN_UPDATE_FAIL;
                    RAISE e_fail;
            END;
            
            DBMS_OUTPUT.PUT_LINE('drop_pallet 13:  SQl%ROWCOUNT :'||SQl%ROWCOUNT );            
            
            /*IF rf_status = swms.Rf.STATUS_NORMAL AND r_repl.uom != 1 THEN
                DBMS_OUTPUT.PUT_LINE('drop_pallet 14:  ' );
                BEGIN
                    SELECT Pl_Putaway_Utilities.F_Get_Hst_Prompt ( 'R', r_repl.type, r_repl.inv_dest_loc, 
                                                                    r_repl.qty * l_spc, i_Taskid)
                      INTO l_prompt_for_hst
                      FROM Dual;
                EXCEPTION
                    WHEN OTHERS THEN
                        Pl_Text_log.ins_Msg('',Ct_Program_Code,'SELECT Prompt_for_HST failed', SQLCODE, SQLERRM);
                        rf_status := rf.STATUS_SEL_SYSCFG_FAIL;
                        RAISE e_fail;
                END;
                DBMS_OUTPUT.PUT_LINE('drop_pallet 15:  ' );
            END IF;*/
            
            DBMS_OUTPUT.PUT_LINE('drop_pallet 16:  rf_status :'||rf_status );
            IF rf_status = swms.Rf.STATUS_NORMAL  THEN
                BEGIN
                    DELETE replenlst 
                    WHERE task_id = i_Taskid;
                EXCEPTION
                    WHEN OTHERS THEN
                        Pl_Text_log.ins_Msg('',Ct_Program_Code,'DElETE from Replenlst failed for Task '||i_Taskid, SQLCODE, SQLERRM);
                        rf_status := rf.STATUS_DEL_RPL_FAIL;
                        RAISE e_fail;
                END;                    
            END IF;
            DBMS_OUTPUT.PUT_LINE('drop_pallet 17:  sql%count :'||SQL%ROWCOUNT );
            
            
            IF r_repl.type IN ('NXL', 'DXL', 'MXL')  AND rf_status = swms.Rf.STATUS_NORMAL THEN
                BEGIN
                    SELECT l.slot_type
                     INTO l_slot_type
                     FROM lzone lz, zone z, loc l
                    WHERE lz.zone_id = z.zone_id
                      AND l.logi_loc = lz.logi_loc
                      AND l.logi_loc = i_Scanned_Data
                      AND z.z_area_code = pl_matrix_common.f_get_pm_area(r_repl.prod_id)
                      AND l.slot_type IN ('MXI', 'MXT')
                      AND z.zone_type = 'PUT';
                      
                   /* SELECT induction_loc 
                      INTO l_ind_loc
                      FROM zone 
                     WHERE rule_id= 5
                       AND zone_type = 'PUT'
                       AND rownum = 1;*/
                EXCEPTION           
                    WHEN NO_DATA_FOUND THEN
                        Pl_Text_log.ins_Msg('',Ct_Program_Code,'Not able to find Matrix slot type for Task '||i_Taskid, SQLCODE, SQLERRM);
                        rf_status := rf.STATUS_INV_SLOT;
                        RAISE e_fail;
                END;
                
                
                --IF l_ind_loc = i_Scanned_Data THEN
                
                IF l_slot_type = 'MXT' THEN
                    BEGIN
                        UPDATE inv
                           SET mx_xfer_type = r_repl.type
                         WHERE logi_loc = r_repl.pallet_id ;  
                    EXCEPTION
                        WHEN OTHERS THEN
                            Pl_Text_log.ins_Msg('',Ct_Program_Code,'Unable to update mx_xfer_type of inv for pallet id '||r_repl.pallet_id , SQLCODE, SQLERRM);
                            rf_status := rf.STATUS_INV_UPDATE_FAIL;
                            RAISE e_fail;
                    END;
                END IF;
                
                IF l_slot_type =  'MXI' THEN
                    BEGIN
                        SELECT status
                          INTO l_inv_status 
                          FROM inv
                         WHERE logi_loc = r_repl.pallet_id;
                         
                        l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;
                                                            
                        l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                                          i_interface_ref_doc => 'SYS03',
                                                                          i_label_type => 'LPN',   --MSKU
                                                                          i_parent_pallet_id => NULL,
                                                                          i_rec_ind => 'S',    ---H OR D  
                                                                          i_pallet_id => r_repl.pallet_id,
                                                                          i_prod_id => r_repl.prod_id,
                                                                          i_case_qty => TRUNC(r_repl.qty/r_repl.spc),
                                                                          i_exp_date => r_repl.exp_date,
                                                                          i_erm_id => r_repl.rec_id,
                                                                          i_batch_id => r_repl.mx_batch_no,
                                                                          i_trans_type => r_repl.type,
                                                                          i_task_id => i_Taskid,
                                                                          i_inv_status => l_inv_status
                                                                         ); 
                        IF l_ret_val = 1 THEN   
                            rf_status := rf.STATUS_INSERT_FAIL;
                            RAISE e_fail;
                        END IF;                        
                        
                        --Schedule job to process matrix_out table and send message to Symbotic
                        l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => l_sys_msg_id);
                        
                        IF l_ret_val = 1 THEN   
                            rf_status := rf.STATUS_INSERT_FAIL;
                            RAISE e_fail;
                        END IF;    
                        
                        COMMIT;                        
                    EXCEPTION
                        WHEN OTHERS THEN
                            Pl_Text_log.ins_Msg('',Ct_Program_Code,'Not able to insert  from Replenlst failed for Task '||i_Taskid, SQLCODE, SQLERRM);
                            RAISE;
                    END;                                            
                END IF; 
            END IF; 
            
        END IF;  
    END IF;

    RETURN rf_status;
EXCEPTION
    WHEN e_fail THEN
        RETURN rf_status;
END drop_pallet;

END PL_RF_MATRIX_REPLEN_DROP;
/
