CREATE OR REPlACE PACKAGE pl_rf_matrix_replen_common
AS
  -------------------------------------------------------------------------------------------
  -- Package
  --   PL_RF_MATRIX_REPLEN_COMMON
  --
  -- Description
  --   This package contains all the common FUNCTIONs required for matrix
  --   replenishment list, matrix replenishment pick and matrix replenishment drop.
  --
  -- Parameters
  --
  -- Modification History
  --
  --   Date           Designer         Comments
  --  -----------    ---------------  -------------------------------------------------------
  --  22-JUl-2014     sred5131         initial Version
  -------------------------------------------------------------------------------------------
  -------------------------------------------------------------------------------------------
  -- Public Constants
  -------------------------------------------------------------------------------------------
  ct_program_code CONSTANT VARCHAR2 (50) := 'PL_RF_MATRIX_REPLEN_COMMON';--'RFMXRPlPK';


---------------------------------------------------------------------------
-- Function:
--    update_scan_method
--
-- Description:
--    This function update scan method in TRANS table for a pallet
--
---------------------------------------------------------------------------  
FUNCTION update_scan_method(
    i_scan_method        IN VARCHAR2,
    i_palletid           IN VARCHAR2,
    i_option             IN VARCHAR2)
  RETURN swms.rf.status;

---------------------------------------------------------------------------
-- Function:
--    reset_task
--
-- Description:
--    This function reset the task again to 'NEW' status  
--
---------------------------------------------------------------------------    
FUNCTION reset_task(
    i_taskid             IN VARCHAR2,
    i_scanned_data       IN VARCHAR2,
    i_equip_id           IN VARCHAR2,
    i_Scan_Method        IN VARCHAR2)
  RETURN swms.rf.status;

---------------------------------------------------------------------------
-- Function:
--    pick_complete
--
-- Description:
--    This function send the message (SYS-06) to matrix when pallet picked from spur location
--
---------------------------------------------------------------------------    
FUNCTION pick_complete(		-- this function is called directly from RF client via SOAP web service
    i_Rf_log_init_Record IN Swms.Rf_log_init_Record,
    i_taskid             IN VARCHAR2,   
    i_equip_id           IN VARCHAR2)
  RETURN swms.rf.status;
  
END pl_rf_matrix_replen_common;
/


CREATE OR REPlACE PACKAGE BODY pl_rf_matrix_replen_common
AS
  -------------------------------------------------------------------------------------------
  -- Package
  --   Pl_RF_MATRIX_REPlEN_COMMON
  --
  -- Description
  --   This package contains all the common FUNCTIONs required for matrix
  --   replenishment list, matrix replenishment pick and matrix replenishment drop.
  --
  -- Modification History
  --
  --   Date           Designer         Comments
  --  -----------    ---------------  -------------------------------------------------------
  --  22-JUl-2014     sred5131         initial Version
  -------------------------------------------------------------------------------------------
  

  
----------------------------------------------------------------------------------
-- Function
--   update_scan_method 
--
-- Description
--   This function update scan method in TRANS table for a pallet             
--
-- Parameters
--
--  Input:
--      i_Rf_log_init_Record    RF initialize Record
--      i_scan_method           Scan Method
--      i_palletid              Pallet ID
--      i_option                Option to update Method1 or Method2 
--
--  Output:
--      N/A
--
--  Return Value:
--      rf.status               RF status message
--
-- Modification History
--
-- Date         User             Defect  Comment
-- --------     ---------        ------------------------------------------
-- 08/07/14     ayad5195         Initial Creation
----------------------------------------------------------------------------------
FUNCTION update_scan_method(
    i_scan_method        IN VARCHAR2,
    i_palletid           IN VARCHAR2,
    i_option             IN VARCHAR2)
  RETURN swms.rf.status
IS
    rf_status swms.rf.status := swms.rf.STATUS_NORMAL;
BEGIN
	BEGIN
		IF i_option = 1 THEN
			UPDATE trans
				SET scan_method1 = i_scan_method
				WHERE pallet_id = i_Palletid
				AND trans_type IN ('IND','PFK', 'PHM')
				AND scan_method1 IS NUll;
		ElSE
			UPDATE trans
				SET scan_method2  = i_scan_method
				WHERE pallet_id = i_palletid
				AND trans_type IN ('IND', 'DFK', 'DHM', 'RPL')
				AND Scan_Method2 iS NULL;
		END IF;

		Pl_Text_log.ins_Msg('',Ct_Program_Code,'Update of TRANS is successful for pallet '||i_Palletid, NUll, NUll);
	EXCEPTION
		WHEN OTHERS THEN
			Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Update of TRANS failed for pallet_id '||i_Palletid,SQLCODE,SQLERRM);
	END;
	RETURN rf_status;
END update_scan_method;


----------------------------------------------------------------------------------
-- Function
--   reset_task 
--
-- Description
--   This function reset the task again to 'NEW' status              
--
-- Parameters
--
--  Input:
--      i_Rf_log_init_Record    RF initialize Record
--      i_taskid                Task ID
--      i_equip_id              Equipment ID
--
--  Output:
--      N/A`
--
--  Return Value:
--      rf.status               RF status message
--
-- Modification History
--
-- Date         User             Defect  Comment
-- --------     ---------        ------------------------------------------
-- 08/07/14     ayad5195         Initial Creation
----------------------------------------------------------------------------------
FUNCTION reset_task(
    i_taskid             IN VARCHAR2,
    i_scanned_data       IN VARCHAR2,
    i_equip_id           IN VARCHAR2,
    i_Scan_Method        IN VARCHAR2 )
  RETURN swms.rf.status 
IS
    rf_status swms.rf.status := swms.rf.STATUS_NORMAL;
    CURSOR c_repl
    IS
        SElECT task_id,
               type,
               src_loc,
               pallet_id,
               REPLACE (user_id, 'OPS$') user_id,
               mx_batch_no,
               labor_batch_no
          FROM replenlst
         WHERE user_id = REPLACE (USER, 'OPS$')
           AND task_id = DECODE (i_Taskid, 0, task_id, i_Taskid)
           AND type IN ('NXL', 'NSP', 'DSP', 'DXL', 'UNA', 'MXL', 'MRL')  -- != 'MNL'
           AND status IN ('PIK', 'HOM');
           
        r_repl  c_repl%ROWTYPE;
        e_fail  EXCEPTION;
BEGIN
    DBMS_OUTPUT.PUT_LINE('TEST RESET_TASK: TEST1, Status  :'||rf_status);

    OPEN c_repl;
    LOOP
        FETCH c_repl INTO r_repl;
        
        IF (c_repl%NOTFOUND) THEN
            EXIT;
        END IF;
        DBMS_OUTPUT.PUT_LINE('TEST RESET_TASK: TEST2, task_id  :'||r_repl.task_id);
        BEGIN
            UPDATE replenlst
                SET status = 'NEW',
                    user_id = NULL,
                    src_loc = NVL(TRIM(i_scanned_data), src_loc)
                WHERE task_id = r_repl.task_id;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('TEST RESET_TASK: Error update replen, task_id :'||r_repl.task_id );
                Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Resetting Task Status failed. ', SQLCODE, SQLERRM);
                rf_status  := rf.STATUS_DATA_ERROR;
                RAISE e_fail;
        END;
            
        DBMS_OUTPUT.PUT_LINE('TEST RESET_TASK: TEST3, src_loc  :'||r_repl.src_loc || '    Pallet_id:'||r_repl.pallet_id);
        Pl_Text_log.ins_Msg(' ',Ct_Program_Code,'Resetting inv for type '|| r_repl.type, NULL, NULL);
        IF r_repl.type IN ('NSP', 'NXL', 'UNA', 'MXL', 'MRL') THEN
            BEGIN
                Pl_Text_log.ins_Msg(' ',Ct_Program_Code,'Resetting inv plogi_loc to '|| NVL(TRIM(i_scanned_data), r_repl.src_loc) || '     Scan Data :'||i_scanned_data, NULL, NULL);
                UPDATE inv
                    SET plogi_loc  = NVL(TRIM(i_scanned_data), r_repl.src_loc)
                    WHERE logi_loc = r_repl.pallet_id
                    AND plogi_loc  = REPLACE (r_repl.user_id, 'OPS$');
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('TEST RESET_TASK: Error update inv, logi_loc :'||r_repl.pallet_id || '     user_id:'||REPLACE (r_repl.user_id, 'OPS$'));
                    Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Resetting Inv Src Loc failed. ', SQLCODE, SQLERRM);
                    rf_status  := rf.STATUS_DATA_ERROR;
                    RAISE e_fail;
            END;
                
            BEGIN
                Pl_Text_log.ins_Msg(' ',Ct_Program_Code,'Resetting batch kvi_from_loc to '|| i_scanned_data, NULL, NULL);
                UPDATE batch
                    SET kvi_from_loc  = NVL(TRIM(i_scanned_data), kvi_from_loc)
                    WHERE batch_no = r_repl.labor_batch_no;
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('TEST RESET_TASK: Error update inv, logi_loc :'||r_repl.pallet_id || '     user_id:'||REPLACE (r_repl.user_id, 'OPS$'));
                    Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Resetting Inv Src Loc failed. ', SQLCODE, SQLERRM);
                    rf_status  := rf.STATUS_DATA_ERROR;
                    RAISE e_fail;
            END;
        END IF;
            
            
        ----------------This was after the routine pl_libswmslm.reset_op_forklift_batch   ---------------------------- 
        DBMS_OUTPUT.PUT_LINE('TEST RESET_TASK: TEST6 Status  :'||rf_status);
        IF TRIM(i_scanned_data) IS NOT NULL THEN
            BEGIN
                    UPDATE trans
                    SET trans_type = 'RPL',
                        dest_loc = i_scanned_data,
                        scan_method2 = i_Scan_Method,
                        trans_date = SYSDATE
                    WHERE trans_type = 'IND'
                    AND user_id = USER
                    AND replen_task_id = r_repl.task_id;
            EXCEPTION   
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('TEST RESET_TASK: Error delete trans, task_id :'||r_repl.task_id || '     user_id:'||REPLACE (r_repl.user_id, 'OPS$'));
                    Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Resetting trans delete failed. ', SQLCODE, SQLERRM);
                    rf_status  := rf.STATUS_DATA_ERROR;
                    RAISE e_fail;
            END;                       
        ELSE
            BEGIN
                DELETE trans
                    WHERE trans_type  IN ('PHM', 'PFK', 'IND', 'DRO')
                    AND user_id = USER
                    AND replen_task_id = r_repl.task_id;
            EXCEPTION   
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('TEST RESET_TASK: Error delete trans, task_id :'||r_repl.task_id || '     user_id:'||REPLACE (r_repl.user_id, 'OPS$'));
                    Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Resetting trans delete failed. ', SQLCODE, SQLERRM);
                    rf_status  := rf.STATUS_DATA_ERROR;
                    RAISE e_fail;
            END;
        END IF; 
        --------------------------------------------
            
        DBMS_OUTPUT.PUT_LINE('TEST RESET_TASK: TEST4, Status  :'||rf_status || '   user_id:'||r_repl.user_id ||'    i_equip_id:'||i_equip_id);
        Pl_Text_log.ins_Msg('',Ct_Program_Code,'TEST Before  pl_libswmslm.reset_op_forklift_batch user_id '||r_repl.user_id ||'   ,  i_equip_id'||i_equip_id, NULL, NULL);
        rf_status := pl_libswmslm.reset_op_forklift_batch (r_repl.user_id, i_equip_id);
        Pl_Text_log.ins_Msg('',Ct_Program_Code,'TEST After  pl_libswmslm.reset_op_forklift_batch user_id Status '||rf_status, NULL, NULL);
        DBMS_OUTPUT.PUT_LINE('TEST RESET_TASK: TEST5, Status  :'||rf_status);
            
        IF rf_status != swms.rf.STATUS_NORMAL THEN
            RAISE e_fail;
        END IF;
            
        ---------------------------Delete TRANS was here --------------------------
          
    END LOOP;   
        
    CLOSE c_repl;   
    
    RETURN rf_status;
EXCEPTION
    WHEN e_fail THEN        
        RETURN rf_status;
END reset_task;

----------------------------------------------------------------------------------
-- Function
--   pick_complete 
--
-- Description
--   This function send the message (SYS-06) to matrix when pallet picked from spur location             
--
-- Parameters
--
--  Input:
--      i_Rf_log_init_Record    RF initialize Record
--      i_taskid                Task ID
--      i_equip_id              Equipment ID
--
--  Output:
--      N/A`
--
--  Return Value:
--      rf.status               RF status message
--
-- Modification History
--
-- Date         User             Defect  Comment
-- --------     ---------        ------------------------------------------
-- 09/04/14     ayad5195         Initial Creation
----------------------------------------------------------------------------------

FUNCTION pick_complete(		-- this function is called directly from RF client via SOAP web service
    i_Rf_log_init_Record IN Swms.Rf_log_init_Record,
    i_taskid             IN VARCHAR2,   
    i_equip_id           IN VARCHAR2)
  RETURN swms.rf.status
IS
    rf_status swms.rf.status := swms.rf.STATUS_NORMAL;      
    l_mx_batch_no    NUMBER;
    e_fail           EXCEPTION;
    l_sys_msg_id     NUMBER;
    l_ret_val        NUMBER;
    l_spur_location  mx_batch_info.spur_location%TYPE;
    l_result         NUMBER;
    l_msg_text       VARCHAR2(512);
    l_err_msg        VARCHAR2(32767);
BEGIN
    rf_status := rf.initialize(i_rf_log_init_record);
    
    IF rf_status = swms.rf.STATUS_NORMAL THEN             
        Pl_Text_log.ins_Msg('',Ct_Program_Code,'Sending pick complete (SYS07) Message to Matrix for task_id '||i_taskid, NULL, NULL);
        
        BEGIN
            SELECT mx_batch_no   
              INTO l_mx_batch_no
              FROM replenlst
            WHERE task_id = i_taskid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                Pl_Text_log.ins_Msg('',Ct_Program_Code,'Unable to get mx_batch_no for task_id '||i_taskid, SQLCODE, SQLERRM);
                rf_status := rf.STATUS_NO_TASK;
                RAISE e_fail;
        END;
        
        --Update the status to mark batch is completed from SPUR and refresh SPUR MONITOR
        UPDATE mx_batch_info
           SET status = 'PIK'
         WHERE batch_no = l_mx_batch_no
           AND batch_type = 'R';         
           
        UPDATE mx_replenlst_cases
           SET status = 'PIK'
         WHERE batch_no = l_mx_batch_no;
        
        BEGIN
            l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;
                                                
            l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                              i_interface_ref_doc => 'SYS07',
                                                              i_rec_ind => 'S',         
                                                              i_batch_id => l_mx_batch_no,
                                                              i_batch_comp_tstamp =>  TO_CHAR(SYSTIMESTAMP, 'DD-MM-YYYY HH:MI:SS:ff9 AM'),
                                                              i_batch_status => 'COMPLETED');
                                                            
            IF l_ret_val = 1 THEN   
                Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Unable to insert record into matrix_out (SYS07) for batch_no '||l_mx_batch_no,NULL,NULL);
                rf_status := rf.STATUS_INSERT_FAIL;
                RAISE e_fail;
            END IF;      
            
            COMMIT;
            Pl_Text_log.ins_Msg('',Ct_Program_Code,'Insert into matrix_out completed for pick complete (SYS07) Message for batch_id '||l_mx_batch_no, NULL, NULL);
            --Schedule job to process matrix_out table and send message to Symbotic
            l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => l_sys_msg_id);
                    
            IF l_ret_val = 1 THEN   
                Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Sending pick complete (SYS07) message to matrix failed for batch_no '||l_mx_batch_no,SQLCODE,SQLERRM);
                rf_status := rf.STATUS_INSERT_FAIL;
                RAISE e_fail;
            END IF;    
        EXCEPTION
            WHEN OTHERS THEN
                Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Sending pick complete (SYS07) Message to Matrix failed for task_id '||i_taskid,SQLCODE,SQLERRM);
                RAISE;
        END;
    END IF;
    
    IF rf_status = swms.rf.STATUS_NORMAL THEN   
        BEGIN 
            BEGIN
                SELECT spur_location
                  INTO l_spur_location
                  FROM mx_batch_info
                 WHERE batch_no = l_mx_batch_no
                   AND batch_type = 'R';
            EXCEPTION   
                WHEN OTHERS THEN
                    l_spur_location := NULL;
            END;
            
            DELETE FROM digisign_jackpot_monitor
                  WHERE batch_no = TO_CHAR(l_mx_batch_no);
                  
            IF SQL%ROWCOUNT > 0 THEN     
                COMMIT;             
                l_result:= pl_digisign.BroadcastJackpotUpdate ('SP07J1', l_err_msg);
                
                IF l_result != 0 THEN
                    l_msg_text := 'Error calling pl_digisign.BroadcastJackpotUpdate from pl_rf_matrix_replen_common.pick_complete';
                    Pl_Text_Log.ins_msg ('FATAL', 'pl_rf_matrix_replen_common.pick_complete', l_msg_text, NULL, l_err_msg);
                END IF;  
            END IF;
            
            IF  l_spur_location NOT LIKE 'SP%J%' THEN
                COMMIT;
                pl_matrix_common.refresh_spur_monitor(l_spur_location);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                 Pl_Text_Log.ins_msg ('FATAL', 'pl_rf_matrix_replen_common.pick_complete', 'Failed to refresh SPUR monitor, unable to find SPUR location of batch '||l_mx_batch_no, SQLCODE, SQLERRM);
        END;
    END IF;
  
    rf.complete (rf_status);
    RETURN rf_status;
EXCEPTION
    WHEN e_fail THEN
        rf.complete (rf_status);
        RETURN rf_status;
    WHEN OTHERS THEN
        rf.logException(); -- log it
        RAISE;
END pick_complete;

END PL_RF_MATRIX_REPLEN_COMMON;
/

SHOW ERRORS
CREATE OR REPLACE PUBLIC SYNONYM pl_rf_matrix_replen_common FOR swms.pl_rf_matrix_replen_common;
