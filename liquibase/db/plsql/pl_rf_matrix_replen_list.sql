/* *************************************************************************/
-- Package Specification
/**************************************************************************/

CREATE OR REPlACE PACKAGE PL_RF_MATRIX_REPLEN_LIST
AS
------------------------------------------------------------------------------------------
-- Package
--   Pl_Rf_Matrix_Replen_list
--
-- Description
--   This package contains procedures and functions required for the matrix
--   replenishment list             
--
-- Modification History
--
--   Date           Designer         Comments
--  -----------    ---------------  ---------------------------------------------------------
--  02-JUL-2014     sred5131         initial Version
---------------------------------------------------------------------------------------------

  FUNCTION Retrieve_Replen_list(		-- this function is called directly from RF client via SOAP web service
    i_Rf_log_init_Record IN swms.rf_log_init_record,
    i_Fm_Aisle           IN VARCHAR2,
    i_To_Aisle           IN VARCHAR2,
    i_Equip_id           IN VARCHAR2,
    i_Task_id            IN VARCHAR2,
    o_Detail_Collection  OUT swms.replen_list_result_obj)
  RETURN swms.rf.status;

  FUNCTION Retrieve_Replen_list_internal(
    i_Fm_Aisle           IN VARCHAR2,
    i_To_Aisle           IN VARCHAR2,
    i_Equip_id           IN VARCHAR2,
    i_Task_id            IN VARCHAR2,
    o_Detail_Collection  OUT swms.replen_list_result_obj)
  RETURN swms.rf.status;
END PL_RF_MATRIX_REPLEN_LIST;
/


/**************************************************************************/
-- Package Body
/**************************************************************************/

CREATE OR REPlACE PACKAGE BODY PL_RF_MATRIX_REPLEN_LIST
AS
  ------------------------------------------------------------------------------------------
  -- Package
  --   PL_RF_MATRIX_REPLEN_LIST
  --
  -- Description
  --   This package contains all the common procedures and functions required for the matrix
  --   replenishment list
  --
  -- Modification History
  --
  --   Date           Designer         Comments
  --  -----------    ---------------  ---------------------------------------------------------
  --  02-JUL-2014     sred5131         initial Version
  ---------------------------------------------------------------------------------------------
  
   
----------------------------------------------------------------------------------
-- Function
--   Retrieve_Replen_list 
--
-- Description
--   This procedure create replenishment list for RF devices             
--
-- Parameters
--
--  input:
--    i_Fm_Aisle i_To_Aisle
--
--  Output:
--    Priority  Type  Src_loc  Pallet_id  Ti  Hi  Dest_loc  Qty  Task_id  Prod_id
--    Descrip  Mfg_Sku  Cust_Pref_Vendor  Case_No
--
-- Modification History
--
-- Date         User             Defect  Comment
-- --------     ---------        ------------------------------------------
-- 07/18/14     ayad5195         create get_induction_loc procedure
----------------------------------------------------------------------------------
  

FUNCTION Retrieve_Replen_list(		-- this function is called directly from RF client via SOAP web service
    i_Rf_log_init_Record IN  swms.rf_log_init_record,
    i_Fm_Aisle           IN  VARCHAR2,
    i_To_Aisle           IN  VARCHAR2,
    i_Equip_id           IN  VARCHAR2,
    i_Task_id            IN  VARCHAR2,
    o_Detail_Collection  OUT swms.replen_list_result_obj )
  RETURN swms.rf.status
IS
    rf_status swms.rf.status := swms.rf.STATUS_NORMAL;

BEGIN
	-- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
	-- This must be done before calling rf.Initialize().

    o_Detail_Collection := swms.replen_list_result_obj(replen_list_result_table());


	-- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.

    rf_status := rf.initialize(i_rf_log_init_record);

    IF rf_status = rf.STATUS_NORMAL THEN
        -- main business logic BEGINs...
	
		rf_status := Retrieve_Replen_list_internal(i_Fm_Aisle,i_To_Aisle,i_Equip_id,i_Task_id,o_Detail_Collection);
	END IF;

    rf.Complete (rf_status);
    RETURN rf_status;

EXCEPTION
    WHEN OTHERS THEN
        rf.logexception(); -- log it
        RAISE;
END Retrieve_Replen_list;


FUNCTION Retrieve_Replen_list_internal(
    i_Fm_Aisle           IN  VARCHAR2,
    i_To_Aisle           IN  VARCHAR2,
    i_Equip_id           IN  VARCHAR2,
    i_Task_id            IN  VARCHAR2,
    o_Detail_Collection  OUT swms.replen_list_result_obj )
  RETURN swms.rf.status
IS
    rf_status swms.rf.status := swms.rf.STATUS_NORMAL;
    l_result_table swms.replen_list_result_table;
    l_result_innertable swms.replen_list_result_table1;  
    
    larea           VARCHAR2(20);
    lfrompickaisle  NUMBER;
    ltopickaisle    NUMBER;
    lfm             NUMBER;
    larea2          VARCHAR2(20);    
    l_curuser       VARCHAR2(20);
    l_count          NUMBER;
    e_fail          EXCEPTION;
    l_rec_cnt       NUMBER;      
    l_inner_cnt     NUMBER;
    l_first_time    BOOLEAN := TRUE;
    l_prev_rec      tmp_usrdnldtasks%ROWTYPE;
    l_prev_batch_no tmp_usrdnldtasks.mx_batch_no%TYPE;

BEGIN
    -- main business logic BEGINs...
        
    larea := LTRIM (RTRIM(i_fm_aisle));
        
    IF (LENGTH (larea) = 1) 
    THEN            
        -- If Area is entered by the user then get the max and min pick aisle value of that area
        SELECT MIN (pick_aisle),
                MAX (pick_aisle)
            INTO lfrompickaisle,
                ltopickaisle
            FROM swms_sub_areas s,
                aisle_info ai
            WHERE s.area_code = larea
            AND ai.sub_area_code = s.sub_area_code;
                   
        IF lfrompickaisle IS NULL THEN
            rf_status := rf.STATUS_INV_AISLE;   -- Return Invalid Aisle error
            RAISE e_fail;
        END IF;
    ElSE
        BEGIN               
            --Get the area and pick_aisle for input from aisle value
            SELECT area_code,
                    pick_aisle
                INTO larea,
                    lfrompickaisle
                FROM swms_sub_areas s,
                    aisle_info ai
                WHERE ai.name = LTRIM(RTRIM(i_fm_aisle))
                AND s.sub_area_code = ai.sub_area_code;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                rf_status := rf.STATUS_INV_AISLE;  -- Return Invalid Aisle error
                RAISE e_fail;
        END;
            
        --If input to aisle value is NULL then use MAX pick_aisle of the from aisle area
        IF (i_to_aisle IS NUll) THEN                    
            SELECT MAX (pick_aisle)
                INTO lToPickAisle
                FROM swms_sub_areas s,
                    aisle_info ai
                WHERE s.area_code = lArea
                AND ai.sub_area_code = s.sub_area_code;                  
        ElSE
            --Get the area and pick aisle for input to aisle value
            BEGIN
                SELECT area_code,
                        pick_aisle
                    INTO larea2,
                        ltopickaisle
                    FROM swms_sub_areas s,
                        aisle_info ai
                    WHERE ai.name = i_to_aisle
                    AND s.sub_area_code = ai.sub_area_code;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    rf_status := rf.STATUS_INV_TO_AISLE; -- Return Invalid To Aisle error
                    RAISE e_fail;
            END;
        END IF;
    END IF;
            
    --If area of input from_aisle and to_asile is not equal then return area mismatch error
    IF (larea   != larea2) THEN
        rf_status := rf.STATUS_AREA_MISMATCH;
        RAISE e_fail;
    END IF;
      
    --Swap the small pick_aisle value to from_pick_aisle and big value to to_pick_aisle
    lfm := lfrompickaisle;
    lfrompickaisle := LEAST (lfrompickaisle, ltopickaisle);
    ltopickaisle   := GREATEST(lfm, ltopickaisle) ;


    --Reset the replenishment task that are in 'PIK' status for the same user before building the list      
    FOR r_pik IN (SELECT * FROM replenlst WHERE status = 'PIK' AND user_id = REPLACE (USER, 'OPS$'))
    LOOP
        rf_status := pl_rf_matrix_replen_common.reset_task (r_pik.task_id, NULL, i_Equip_id, NULL);
    END LOOP;
        
    BEGIN      
        INSERT INTO tmp_usrdnldtasks
        (
            task_id, type, src_loc, dest_loc, pallet_id,        
            priority, qty, prod_id, ti, hi,
            cust_pref_vendor, descrip, mfg_sku, truck_no, door_no,         
            drop_qty, s_pikpath, d_pikpath, route_batch_no, seq_no,           
            exp_date, case_no, mx_batch_no, print_lpn, logi_loc,                
            brand, pallet_type, uom, erm_id, erm_date, spc , pack, prod_size, show_travel_key              
        )
        SELECT rp.task_id, rp.type, rp.src_loc, rp.dest_loc, rp.pallet_id,        
                rp.priority, rp.qty, rp.prod_id, p.ti, p.hi,               
                rp.cust_pref_vendor, rp.descrip, rp.mfg_sku, rp.truck_no, rp.door_no,         
                rp.drop_qty, rp.s_pikpath, rp.d_pikpath, rp.route_batch_no, rp.seq_no,           
                rp.exp_date, rp.case_no, rp.mx_batch_no, rp.print_lpn, NVL((SELECT logi_loc 
                                                                            FROM loc 
                                                                            WHERE loc.perm = 'Y' 
                                                                            AND loc.prod_id = p.prod_id 
                                                                            AND loc.uom IN (0 ,2)
                                                                            AND loc.rank = 1
                                                                            AND rownum = 1), ' '),                                                                            
                p.brand , rp.pallet_type, rp.uom, rp.rec_id, rp.rec_date, p.spc, p.pack, p.prod_size, DECODE(l.slot_type, 'MXS',mr.show_travel_key, 'N')  
            FROM v_matrix_replen_list rp,
                pm p,
                mx_replen_type mr,
                loc l
            WHERE /*(rp.src_pik_aisle BETWEEN lfrompickaisle AND ltopickaisle  
                    OR */
                rp.dest_pik_aisle BETWEEN lfrompickaisle AND ltopickaisle --)
            AND rp.prod_id   = p.prod_id
            AND mr.type = rp.type
            AND rp.src_loc = l.logi_loc
            AND rp.area_code = larea
        ORDER BY rp.priority ASC;   
    
    EXCEPTION
        WHEN OTHERS THEN
            rf_status := rf.STATUS_DATA_ERROR;
            RAISE e_fail;
    END;
    
    IF rf_status = rf.STATUS_NORMAL AND i_Task_id != 0  THEN
        SELECT USER 
          INTO l_curuser 
          FROM Dual;
          
        DELETE
          FROM user_downloaded_tasks
         WHERE task_id = i_Task_id
           AND user_id = l_curuser;
        
        SELECT COUNT (0)
          INTO l_count
          FROM ((
                    SELECT  task_id, priority
                      FROM  tmp_usrdnldtasks
                    MINUS
                    SELECT  task_id, priority
                      FROM  user_downloaded_tasks
                     WHERE  user_id = USER
                )
              UNION ALL
                (
                    SELECT  task_id, priority
                      FROM  user_downloaded_tasks
                     WHERE  user_id = USER
                    MINUS
                    SELECT  task_id, priority
                      FROM  tmp_usrdnldtasks
                ));
                
        IF l_count = 0 THEN     
            rf_status := rf.STATUS_NO_NEW_TASK;
            RAISE e_fail;
        END IF;
    END IF;
    
    IF rf_status = rf.STATUS_NORMAL THEN
        DBMS_OUTPUT.PUT_LINE('test1');
        SELECT USER 
          INTO l_curuser 
          FROM Dual;
        
        IF rf_status != rf.STATUS_NORMAL THEN 
            RAISE e_fail;
        END IF;
        
        --Delete all task from table user_downloaded_tasks for the user to refresh the list
        DELETE
          FROM user_downloaded_tasks
         WHERE user_id = l_curuser;
    
        DBMS_OUTPUT.PUT_LINE('test2');
        
        l_result_table := replen_list_result_table(); 
        l_result_innertable := replen_list_result_table1();
        l_rec_cnt := 1;     
        
        
        
        FOR rpl_rec IN (SELECT * FROM tmp_usrdnldtasks ORDER BY mx_batch_no, priority)
        LOOP
            DBMS_OUTPUT.PUT_LINE('List TEST 1:  l_result_innertable:'||l_result_innertable.LAST ||  '     ,rpl_rec.mx_batch_no:'||rpl_rec.mx_batch_no ||'  ,l_prev_batch_no:'||l_prev_batch_no);
            IF rpl_rec.mx_batch_no IS NOT NULL THEN
                IF l_first_time THEN
                    DBMS_OUTPUT.PUT_LINE('List TEST 2:  l_result_innertable:'||l_result_innertable.LAST);
                    l_prev_batch_no := rpl_rec.mx_batch_no;
                    l_first_time := FALSE;      
                    l_inner_cnt := 1;                               
                END IF;
                
                DBMS_OUTPUT.PUT_LINE('List TEST 1A:  l_result_innertable:'||l_result_innertable.LAST ||  '     ,rpl_rec.mx_batch_no:'||rpl_rec.mx_batch_no ||'  ,l_prev_batch_no:'||l_prev_batch_no);
                IF l_prev_batch_no != rpl_rec.mx_batch_no THEN
                DBMS_OUTPUT.PUT_LINE('List TEST 3:  l_result_innertable:'||l_result_innertable.LAST);
                    l_result_table.EXTEND(1);
                    SELECT replen_list_result_record(l_prev_rec.priority,
                                                     l_prev_rec.type,
                                                     l_prev_rec.src_loc,    
                                                     l_prev_rec.pallet_id,
                                                     l_prev_rec.ti,
                                                     l_prev_rec.hi,
                                                     l_prev_rec.print_lpn,
                                                     l_prev_rec.show_travel_key,
                                                     l_result_innertable
                                                ) 
                      INTO l_result_table(l_rec_cnt) 
                      FROM dual;
                  
                    l_prev_batch_no := rpl_rec.mx_batch_no;
                    l_rec_cnt := l_rec_cnt + 1;
                    l_inner_cnt := 1;
                    l_result_innertable.DELETE;
                END IF;
                DBMS_OUTPUT.PUT_LINE('List TEST 4:  l_result_innertable:'||l_result_innertable.LAST);
                        l_prev_rec := rpl_rec;
                        l_result_innertable.EXTEND(1);
                        DBMS_OUTPUT.PUT_LINE('List TEST 5:  l_result_innertable:'||l_result_innertable.LAST || '      ,mx_batch_no :'||rpl_rec.mx_batch_no);
                        l_result_innertable (l_inner_cnt) := replen_list_inner_type(rpl_rec.dest_loc,                                                                                      
                                                                                    rpl_rec.qty,
                                                                                    rpl_rec.task_id,
                                                                                    rpl_rec.prod_id,
                                                                                    rpl_rec.descrip,
                                                                                    rpl_rec.mfg_sku,
                                                                                    rpl_rec.cust_pref_vendor,
                                                                                    rpl_rec.case_no,
                                                                                    rpl_rec.logi_loc,
                                                                                    rpl_rec.brand,
                                                                                    TO_CHAR(rpl_rec.exp_date, RF.SERIALIZED_DATE_PATTERN),
                                                                                    rpl_rec.pallet_type,
                                                                                    rpl_rec.uom,
                                                                                    rpl_rec.erm_id,
                                                                                    TO_CHAR(rpl_rec.erm_date, RF.SERIALIZED_DATE_PATTERN),
                                                                                    rpl_rec.pack,
                                                                                    rpl_rec.prod_size
                                                                                   );
                        l_inner_cnt := l_inner_cnt + 1;
                
                
            ELSE
                IF l_prev_batch_no IS NOT NULL THEN
                    DBMS_OUTPUT.PUT_LINE('List TEST 6:  l_result_innertable:'||l_result_innertable.LAST);
                    l_result_table.EXTEND(1);
                    SELECT replen_list_result_record(l_prev_rec.priority,
                                                     l_prev_rec.type,
                                                     l_prev_rec.src_loc,    
                                                     l_prev_rec.pallet_id,
                                                     l_prev_rec.ti,
                                                     l_prev_rec.hi,
                                                     l_prev_rec.print_lpn,
                                                     l_prev_rec.show_travel_key,
                                                     l_result_innertable
                                                ) 
                      INTO l_result_table(l_rec_cnt) 
                      FROM dual;
                  
                    dbms_output.put_line('Outer Count NOT-NULL2:'||l_rec_cnt || '           '||l_prev_rec.type);                   
                    l_rec_cnt := l_rec_cnt + 1;
                    l_prev_batch_no := NULL;
                    l_first_time := TRUE;
                    l_result_innertable.DELETE;
                END IF;
                
                dbms_output.put_line('SELECT TEST rpl_rec.task_id:'||rpl_rec.task_id || '           '||l_prev_rec.type); 
                l_result_table.EXTEND(1);
                SELECT replen_list_result_record(priority,
                                                 type,
                                                 src_loc,   
                                                 pallet_id,
                                                 ti,
                                                 hi,
                                                 print_lpn,
                                                 show_travel_key,
                                                 replen_list_result_table1( replen_list_inner_type(dest_loc,
                                                                                                   qty,
                                                                                                   task_id,
                                                                                                   prod_id,
                                                                                                   descrip,
                                                                                                   mfg_sku,
                                                                                                   cust_pref_vendor,
                                                                                                   case_no,
                                                                                                   logi_loc,
                                                                                                   brand,
                                                                                                   TO_CHAR(exp_date, RF.SERIALIZED_DATE_PATTERN),
                                                                                                   pallet_type,
                                                                                                   uom,
                                                                                                   erm_id,
                                                                                                   TO_CHAR(erm_date, RF.SERIALIZED_DATE_PATTERN),
                                                                                                   pack,
                                                                                                   prod_size
                                                                                                  )
                                                                          )
                                                )           
                  INTO l_result_table(l_rec_cnt) 
                  FROM tmp_usrdnldtasks
                 WHERE task_id =  rpl_rec.task_id;
            
                l_rec_cnt:= l_rec_cnt + 1;
            END IF;
        END LOOP;
        
        IF l_prev_batch_no IS NOT NULL THEN
            l_result_table.EXTEND(1);
            SELECT replen_list_result_record(l_prev_rec.priority,
                                             l_prev_rec.type,
                                             l_prev_rec.src_loc,    
                                             l_prev_rec.pallet_id,
                                             l_prev_rec.ti,
                                             l_prev_rec.hi,
                                             l_prev_rec.print_lpn,
                                             l_prev_rec.show_travel_key,
                                             l_result_innertable
                                            ) 
              INTO l_result_table(l_rec_cnt) 
              FROM dual;                  
         END IF;
        
        IF l_result_table IS NULL OR l_result_table.COUNT = 0 THEN
            rf_status := swms.rf.STATUS_NO_TASK;
            RAISE e_fail;
        ElSE
            o_Detail_Collection := swms.replen_list_result_obj(l_result_table); -- set OUT parm to temp table
        END IF;
      
        DBMS_OUTPUT.PUT_LINE('test4');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('test5');
    
    INSERT INTO user_downloaded_tasks(user_id, task_id, priority)
        SELECT l_curuser, task_id, priority FROM tmp_usrdnldtasks;   
  
    DBMS_OUTPUT.PUT_LINE('test6');  
  
    rf.logmsg(rf.log_debug,'message10');
  
    RETURN rf_status;
EXCEPTION
    WHEN e_fail THEN
        RETURN rf_status;
END Retrieve_Replen_list_internal;

END PL_RF_MATRIX_REPLEN_LIST;
/
