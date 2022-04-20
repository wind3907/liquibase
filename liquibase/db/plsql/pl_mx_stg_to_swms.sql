CREATE OR REPLACE
PACKAGE pl_mx_stg_to_swms
IS
    /*===========================================================================================================
    -- Package
    -- pl_mx_stg_to_swms
    --
    -- Description
    --  This package is called by pl_xml_matrix_in.
    --  This package processes the data that is coming from Symbotic to SWMS and updates the 
    --  swms data.
    --
    -- Modification History
    --
    -- Date                User                  Version            Defect  Comment
    -- 08/18/14        Sunil Ontipalli             1.0              Initial Creation
    -- 12/01/14        Abhishek Yadav              1.1              Changed procedure sym03_inv_update and
    --                                                              added procedure sym07_rpln_update
    -- 08/18/15        Sunil Ontipalli             1.2              Changed sym03_inv_update to create STA transaction and put the pallet
    --                                                              on HLD when the pallet is rejected.
    -- 01/04/16        Abhishek Yadav                               Changed procedure sym07_rpln_inv_update to add new type IIR
    -- 03/15/16        Abu                                          Removed the hardcoded value for reason code 'CC' for CSQ COR trans.
    -- 07/27/16        Patrice Kabran                               Added SYM05 add_date and sequence_number to
    --                                                              cursor in sym05_sos_batch_update() to populate corresponding 
    --                                                              sos_batch columns.
    -- 08/22/16        Adi Al Bataineh                              sym12_case_div_update: update on-hold SYS06 cases status to NEW 
    --                                                              when case is diverted to spurs
    ============================================================================================================*/
    PROCEDURE sym03_inv_update(i_mx_msg_id  IN NUMBER DEFAULT NULL);
    
    PROCEDURE sym07_rpln_inv_update (i_mx_msg_id   IN NUMBER DEFAULT NULL);
    
    PROCEDURE sym05_sos_batch_update (i_mx_msg_id  IN NUMBER DEFAULT NULL); 
    
    PROCEDURE sym12_case_div_update (i_mx_msg_id  IN NUMBER DEFAULT NULL);
    
    PROCEDURE sym06_case_skipped_update (i_mx_msg_id  IN NUMBER DEFAULT NULL);
    
    PROCEDURE sym15_bulk_inv_insert(i_mx_msg_id IN NUMBER DEFAULT NULL);
    
    PROCEDURE sym16_case_skip_update(i_mx_msg_id IN NUMBER DEFAULT NULL);
END pl_mx_stg_to_swms;
/

show errors

CREATE OR REPLACE
PACKAGE BODY pl_mx_stg_to_swms
IS
  /*===========================================================================================================
  -- Package Body
  -- pl_mx_stg_to_swms
  --
  -- Description
  --  This package is called by pl_xml_matrix_in.
  --  This package processes the data that is coming into Sysco and updates the
  --  swms data.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 08/18/14        Sunil Ontipalli             1.0              Initial Creation
  -- 08/18/15        Sunil Ontipalli             1.2              Changed sym03_inv_update to create STA transaction and put the pallet
  --                                                              on HLD when the pallet is rejected.
  ============================================================================================================*/
PROCEDURE sym03_inv_update(
    i_mx_msg_id IN NUMBER DEFAULT NULL)
    /*===========================================================================================================
    -- Procedure
    -- sym03_inv_update
    --
    -- Description
    --   This Procedure collects the SYM-03 data from staging table and updates the inv table.
    --
    -- Modification History
    --
    -- Date                User                  Version            Defect  Comment
    -- 08/12/14        Sunil Ontipalli             1.0              Initial Creation
    ============================================================================================================*/
    IS
    ------------------------------local variables-----------------------------------
    l_mx_msg_id              swms.matrix_in.mx_msg_id%TYPE;
    l_interface_ref_doc      swms.matrix_in.interface_ref_doc%TYPE;
    l_record_status          swms.matrix_in.record_status%TYPE;
    l_prod_id                swms.matrix_in.prod_id%TYPE;
    l_pallet_id              swms.matrix_in.pallet_id%TYPE;
    l_po_no                  swms.matrix_in.erm_id%TYPE;
    l_qty_stored             swms.matrix_in.qty_stored%TYPE;
    l_qty_inducted           swms.matrix_in.qty_inducted%TYPE;
    l_qty_damaged            swms.matrix_in.qty_damaged%TYPE;
    l_qty_out_of_tolerance   swms.matrix_in.qty_out_of_tolerance%TYPE;
    l_qty_wrong_item         swms.matrix_in.qty_wrong_item%TYPE;
    l_qty_suspect            swms.matrix_in.qty_suspect%TYPE;
    l_qty_short              swms.matrix_in.qty_short%TYPE;
    l_qty_over               swms.matrix_in.qty_over%TYPE;
    l_trans_type             swms.matrix_in.trans_type%TYPE;
    l_plogi_loc              swms.inv.plogi_loc%TYPE;
    l_outbound_plogi_loc     swms.inv.plogi_loc%TYPE;
    l_length                 NUMBER;
    l_pallet_id_new          swms.matrix_in.pallet_id%TYPE;
    l_spc                    swms.pm.spc%TYPE;
    l_warehouse_id           swms.zone.warehouse_id%TYPE;
    l_slot_type              swms.loc.slot_type%TYPE;
    l_erm_type               erm.erm_type%TYPE;
    l_erm_status             erm.status%TYPE;
    l_parent_pallet_id       matrix_in.parent_pallet_id%TYPE;
    l_rec_id                 inv.rec_id%TYPE;
    l_po_status              erm.status%TYPE;
    l_check_val              VARCHAR2(1);
    l_error_msg              VARCHAR2(100);
    l_error_code             VARCHAR2(100);
    l_pallet_init            VARCHAR2(3);  
    validation_exception     EXCEPTION;
    duplicate_exception      EXCEPTION;
    
    CURSOR c_get_all_inv IS
        SELECT *
          FROM inv
         WHERE prod_id   = l_prod_id
           AND logi_loc  = l_pallet_id;
       
    CURSOR c_mx_msg_id IS
        SELECT DISTINCT(mx_msg_id)
          FROM matrix_in
         WHERE interface_ref_doc = 'SYM03'
           AND record_status     = 'N'
           AND (add_date   <  systimestamp - 1/(24*60) OR i_mx_msg_id IS NOT NULL)
           AND mx_msg_id = NVL(i_mx_msg_id, mx_msg_id); 
   
    CURSOR c_get_matrix_in IS 
        SELECT prod_id, pallet_id, erm_id, qty_stored, qty_inducted,
               qty_damaged, qty_out_of_tolerance, qty_wrong_item, qty_suspect,
               qty_short, qty_over, trans_type  
          FROM matrix_in
         WHERE mx_msg_id = l_mx_msg_id
           AND rec_ind   = 'D';     
BEGIN
    FOR k IN c_mx_msg_id
    LOOP
        -----------------------Initializing the local variables-------------------------
        l_mx_msg_id := k.mx_msg_id;
        ----------------------------Getting the Record status---------------------------  
        BEGIN
            SELECT DISTINCT(record_status)
              INTO l_record_status
              FROM matrix_in
             WHERE mx_msg_id = l_mx_msg_id;
        EXCEPTION
            WHEN OTHERS THEN
                l_error_msg := 'Failed Getting the Record Status, This is a Duplicate MSG';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
        END;
        
        ------------Checking Whether the Status is 'N' and Locking the Record-----------  
        IF UPPER(l_record_status) = 'N' THEN
            BEGIN
                UPDATE matrix_in
                   SET record_status = 'Q'
                 WHERE mx_msg_id = l_mx_msg_id;
                   
                COMMIT;
            EXCEPTION
                WHEN OTHERS THEN
                    ROLLBACK;
                    l_error_msg := 'Failed Updating the Record Status to Q';
                    l_error_code:= SUBSTR(SQLERRM,1,100);
                    RAISE validation_exception;
            END;
            
            -------------------Getting the Data from the Staging Table----------------------   
            FOR j IN c_get_matrix_in
            LOOP                    
                l_prod_id                := j.prod_id;
                l_pallet_id              := j.pallet_id;
                l_po_no                  := j.erm_id;
                l_qty_stored             := j.qty_stored;
                l_qty_inducted           := j.qty_inducted;
                l_qty_damaged            := j.qty_damaged;
                l_qty_out_of_tolerance   := j.qty_out_of_tolerance;
                l_qty_wrong_item         := j.qty_wrong_item;
                l_qty_suspect            := nvl(j.qty_suspect, 0);
                l_qty_short              := j.qty_short;
                l_qty_over               := j.qty_over;
                l_trans_type             := j.trans_type;
        
                -------------Verifying and checking for duplicate message-----------------------
                BEGIN
                    SELECT loc.slot_type 
                      INTO l_slot_type
                      FROM loc, inv 
                     WHERE loc.logi_loc = inv.plogi_loc
                       AND inv.logi_loc = l_pallet_id;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_error_msg := 'Failed Getting the slot type';  
                        l_error_code:= SUBSTR(SQLERRM,1,100);
                        RAISE validation_exception;     
                END;
            
                IF l_slot_type = 'MXF' or l_slot_type = 'MXC' THEN
                    l_error_msg := 'This is a Duplicate Message, This pallet is Already Processed';
                    RAISE duplicate_exception;
                END IF;
            
            /* IF l_qty_stored = 0 THEN 
                    
                     ----Querying the out-duct location of the Inventory------      
            
                     BEGIN
                      SELECT loc.logi_loc
                        INTO l_plogi_loc
                        FROM loc
                       WHERE loc.slot_type     = 'MXO';
                     EXCEPTION
                      WHEN OTHERS THEN
                        l_error_msg := 'Failed Getting the outduct location when Exception';
                        l_error_code:= SUBSTR(SQLERRM,1,100);
                        RAISE validation_exception;
                     END;
                    
                    ---------Updating the Inv with the reject location and quantity stored----------      
                    BEGIN
                        UPDATE INV
                           SET plogi_loc = l_plogi_loc,
                               status    = 'HLD'
                         WHERE prod_id   = l_prod_id
                           AND logi_loc  = l_pallet_id;
                    EXCEPTION
                     WHEN OTHERS THEN
                        ROLLBACK;
                        l_error_msg := 'Failed Updating the location when rejected';
                        l_error_code:= SUBSTR(SQLERRM,1,100);
                        RAISE validation_exception;
                     END;
                     
                     
                     ----------Calculating the Warehouse Id for creating a STA transaction-----------   
                        BEGIN
                            SELECT zn.warehouse_id 
                              INTO l_warehouse_id
                              FROM zone zn, lzone z
                             WHERE zn.zone_id = z.zone_id
                               AND z.logi_loc = l_plogi_loc
                               AND zone_type = 'PUT';
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Calculating the Warehouse Id when Qty is Rejected';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;   
                        
                     -------------------------Getting the spc from pm table--------------------------
                        BEGIN
                            SELECT spc
                              INTO l_spc
                              FROM pm
                             WHERE prod_id = l_prod_id;
                        EXCEPTION
                            WHEN OTHERS THEN
                                l_error_msg := 'Failed Getting the SPC';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                        
                        ------------------Creating a STA transaction for rejected Quantity------------------
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                  rec_id, src_loc, pallet_id, qty_expected,
                                                  qty, reason_code, user_id, uom, upload_time,
                                                  exp_date, old_status, new_status, warehouse_id, cust_pref_vendor )
                                          VALUES (trans_id_seq.nextval, 'STA', sysdate, i.prod_id,
                                                  i.rec_id, l_plogi_loc, l_pallet_id, 
                                                 (l_qty_inducted*l_spc), (l_qty_inducted*l_spc), 'CC', user, i.inv_uom, 
                                                 to_date('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),i.exp_date, 
                                                 i.status, 'HLD', l_warehouse_id, i.cust_pref_vendor);
                            END LOOP;             
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Creating a STA transaction when Qty is rejected';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                         
                        ------------------Creating a MXE transaction for rejected Quantity----------------
                                          
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                  rec_id, src_loc, pallet_id, qty_expected,
                                                  qty, reason_code, user_id, uom, upload_time,
                                                  exp_date, old_status, warehouse_id, cust_pref_vendor )
                                          VALUES (trans_id_seq.nextval, 'MXE', sysdate, i.prod_id,
                                                  i.rec_id, l_plogi_loc, l_pallet_id, 
                                                  (l_qty_inducted*l_spc), (l_qty_inducted*l_spc), 'CC', user, i.inv_uom, 
                                                  null,i.exp_date, 'HLD', l_warehouse_id, i.cust_pref_vendor);
                            END LOOP;             
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Creating a MXE transaction when Qty is rejected';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;

                ELSE     */            

                   -------------------------Getting the spc from pm table--------------------------
                    BEGIN
                        SELECT spc
                          INTO l_spc
                          FROM pm
                         WHERE prod_id = l_prod_id;
                    EXCEPTION
                        WHEN OTHERS THEN
                            l_error_msg := 'Failed Getting the SPC';
                            l_error_code:= SUBSTR(SQLERRM,1,100);
                            RAISE validation_exception;
                    END;
                    
                    ----Validating the Data and Querying the Present Location of the Inventory------      
                
                    BEGIN
                        SELECT loc.logi_loc
                          INTO l_plogi_loc
                          FROM loc,
                               mx_food_type mx,
                               pm
                         WHERE mx.mx_food_type   = pm.mx_food_type
                           AND loc.slot_type     = mx.slot_type
                           AND pm.prod_id        = l_prod_id;
                      EXCEPTION
                        WHEN OTHERS THEN
                            l_error_msg := 'Failed Getting the location when Exception';
                            l_error_code:= SUBSTR(SQLERRM,1,100);
                            RAISE validation_exception;
                    END;
                    
                    ---------Updating the Inv with the actual location and quantity stored----------      
                    BEGIN
                        UPDATE INV
                           SET plogi_loc = l_plogi_loc,
                               qoh       = (l_qty_stored*l_spc)
                         WHERE prod_id   = l_prod_id
                           AND logi_loc  = l_pallet_id;
                    EXCEPTION
                        WHEN OTHERS THEN
                            ROLLBACK;
                            l_error_msg := 'Failed Updating the location when Exception';
                            l_error_code:= SUBSTR(SQLERRM,1,100);
                            RAISE validation_exception;
                    END;
                    
                    ------------Validating the damaged items and Querying the outbound loc----------      
                    IF l_qty_damaged != 0 THEN
                        BEGIN
                          SELECT logi_loc 
                            INTO l_outbound_plogi_loc
                            FROM loc 
                           WHERE slot_type ='MXO';
                        EXCEPTION
                            WHEN OTHERS THEN
                                l_error_msg := 'Failed Getting the outbound location when Damaged';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                    
                        ------Calculating the Length and concatinating the DMG to the pallet ID---------      
                        l_length := LENGTH(l_pallet_id);
                           
                        IF l_length <= 15 THEN
                            l_pallet_id_new  := 'DMG'||l_pallet_id;
                        ELSIF l_length = 16 THEN
                            l_pallet_id_new  := 'DMG'||SUBSTR(l_pallet_id,2);
                        ELSIF l_length = 17 THEN
                            l_pallet_id_new  := 'DMG'||SUBSTR(l_pallet_id,3);   
                        ELSIF l_length = 18 THEN
                            l_pallet_id_new  := 'DMG'||SUBSTR(l_pallet_id,4);
                        END IF;
                        
                        -------------------Inserting the new record with the DMG INV--------------------      
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP         
                                INSERT INTO inv(prod_id, rec_id, mfg_date, rec_date,
                                                exp_date, inv_date, logi_loc, plogi_loc,
                                                qoh, qty_alloc, qty_planned, min_qty,
                                                cube, lst_cycle_date, lst_cycle_reason, abc,
                                                abc_gen_date, status, lot_id, weight, temperature,
                                                exp_ind, cust_pref_vendor,
                                                parent_pallet_id, inv_uom) 
                                        VALUES (i.prod_id, i.rec_id, i.mfg_date, i.rec_date,
                                                i.exp_date, i.inv_date, l_pallet_id_new, l_outbound_plogi_loc,
                                               (l_qty_damaged*l_spc), i.qty_alloc, i.qty_planned, i.min_qty,
                                                i.cube, i.lst_cycle_date, i.lst_cycle_reason, i.abc,
                                                i.abc_gen_date, 'HLD', i.lot_id, i.weight, i.temperature, 
                                                i.exp_ind, i.cust_pref_vendor,
                                                i.parent_pallet_id, i.inv_uom); 
                           END LOOP;            
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Inserting New Record in INV when Damaged';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                        
                        ----------Calculating the Warehouse Id for creating a STA transaction-----------   
                        BEGIN
                            SELECT zn.warehouse_id 
                              INTO l_warehouse_id
                              FROM zone zn, lzone z
                             WHERE zn.zone_id = z.zone_id
                               AND z.logi_loc = l_outbound_plogi_loc
                               AND zone_type = 'PUT';
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Calculating the Warehouse Id when Qty is Damaged';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;   
                        
                        ------------------Creating a STA transaction for Damaged Quantity------------------
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                  rec_id, src_loc, pallet_id, qty_expected,
                                                  qty, reason_code, user_id, uom, upload_time,
                                                  exp_date, old_status, new_status, warehouse_id, cust_pref_vendor )
                                          VALUES (trans_id_seq.nextval, 'STA', sysdate, i.prod_id,
                                                  i.rec_id, l_outbound_plogi_loc, l_pallet_id_new, 
                                                 (l_qty_inducted*l_spc), (l_qty_damaged*l_spc), 'CC', user, i.inv_uom, 
                                                 to_date('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),i.exp_date, 
                                                 i.status, 'HLD', l_warehouse_id, i.cust_pref_vendor);
                            END LOOP;             
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Creating a STA transaction when Qty is Damaged';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                         
                        ------------------Creating a MXE transaction for Damaged Quantiy----------------
                                          
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                  rec_id, src_loc, pallet_id, qty_expected,
                                                  qty, reason_code, user_id, uom, upload_time,
                                                  exp_date, old_status, warehouse_id, cust_pref_vendor )
                                          VALUES (trans_id_seq.nextval, 'MXE', sysdate, i.prod_id,
                                                  i.rec_id, l_outbound_plogi_loc, l_pallet_id_new, 
                                                  (l_qty_inducted*l_spc), (l_qty_damaged*l_spc), 'CC', user, i.inv_uom, 
                                                  null,i.exp_date, 'HLD', l_warehouse_id, i.cust_pref_vendor);
                            END LOOP;             
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Creating a MXE transaction when Qty is Damaged';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                        
                        ------------------For Putaway Create MXP Transaction for Damaged Quantity---------------------------    
                        IF l_trans_type = 'PUT' THEN      
                            BEGIN
                                SELECT erm_type, status
                                  INTO l_erm_type, l_erm_status
                                  FROM erm
                                 WHERE erm_id = l_po_no;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    l_error_msg := 'Failed getting erm_type for erm_id '||l_po_no;
                                    l_error_code:= SUBSTR(SQLERRM,1,100);
                                    RAISE validation_exception;
                            END;
                            
                            ----------Creating a MXP transaction for Damaged Quantity(Regular PO/SN)-----------
                            IF l_erm_type IN ('PO', 'SN') AND l_erm_status IN ('OPN', 'CLO') THEN     
                                BEGIN
                                    FOR i IN c_get_all_inv
                                    LOOP
                                        INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                          rec_id, dest_loc, pallet_id, qty_expected,
                                                          qty, reason_code, user_id, uom, upload_time,
                                                          exp_date, new_status, warehouse_id, cust_pref_vendor )
                                                  VALUES (trans_id_seq.nextval, 'MXP', sysdate, i.prod_id,
                                                          i.rec_id, l_outbound_plogi_loc, l_pallet_id_new, 
                                                          (l_qty_inducted*l_spc), (l_qty_damaged*l_spc), 'CC', user, i.inv_uom, 
                                                          null, i.exp_date, 'AVL', l_warehouse_id, i.cust_pref_vendor);
                                    END LOOP;             
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        ROLLBACK;
                                        l_error_msg := 'Failed Creating a MXP transaction when Qty is Damaged(Regular Put)';
                                        l_error_code:= SUBSTR(SQLERRM,1,100);
                                        RAISE validation_exception;
                                END;            
                            END IF;  /*IF l_erm_type IN ('PO', 'SN')*/            
                        END IF; /*IF l_trans_type = 'PUT'*/  
                      
                    END IF; /*IF l_qty_damaged != 0*/
                    
                    
                ------------Validating the Suspect qty and Querying the outbound loc----------      
                    IF l_qty_suspect != 0 THEN

                        BEGIN
                          SELECT logi_loc
                            INTO l_outbound_plogi_loc
                            FROM loc
                           WHERE slot_type ='MXO';
                        EXCEPTION
                            WHEN OTHERS THEN
                                l_error_msg := 'Failed Getting the outbound location when Suspect';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                    
                     ------Calculating the Length and concatinating the DMG to the pallet ID---------      
                        l_length := LENGTH(l_pallet_id);
                           
                        IF l_length <= 15 THEN
                            l_pallet_id_new  := 'SSP'||l_pallet_id;
                        ELSIF l_length = 16 THEN
                            l_pallet_id_new  := 'SSP'||SUBSTR(l_pallet_id,2);
                        ELSIF l_length = 17 THEN
                            l_pallet_id_new  := 'SSP'||SUBSTR(l_pallet_id,3);   
                        ELSIF l_length = 18 THEN
                            l_pallet_id_new  := 'SSP'||SUBSTR(l_pallet_id,4);
                        END IF;
                        
                      -------------------Inserting the new record with the SSP INV--------------------      
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP         
                                INSERT INTO inv(prod_id, rec_id, mfg_date, rec_date,
                                                exp_date, inv_date, logi_loc, plogi_loc,
                                                qoh, qty_alloc, qty_planned, min_qty,
                                                cube, lst_cycle_date, lst_cycle_reason, abc,
                                                abc_gen_date, status, lot_id, weight, temperature,
                                                Exp_Ind, Cust_Pref_Vendor,
                                                parent_pallet_id, inv_uom, mx_orig_pallet_id) 
                                        VALUES (i.prod_id, i.rec_id, i.mfg_date, i.rec_date,
                                                i.exp_date, i.inv_date, l_pallet_id_new, l_outbound_plogi_loc,
                                               (l_qty_suspect*l_spc), i.qty_alloc, i.qty_planned, i.min_qty,
                                                i.cube, i.lst_cycle_date, i.lst_cycle_reason, i.abc,
                                                i.abc_gen_date, 'HLD', i.lot_id, i.weight, i.temperature, 
                                                I.Exp_Ind, I.Cust_Pref_Vendor,
                                                i.parent_pallet_id, i.inv_uom, l_pallet_id); 
                           END LOOP;            
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Inserting New Record in INV when Suspect';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                        
                        ----------Calculating the Warehouse Id for creating a STA transaction-----------   
                        BEGIN
                            SELECT zn.warehouse_id 
                              INTO l_warehouse_id
                              FROM zone zn, lzone z
                             WHERE zn.zone_id = z.zone_id
                               AND z.logi_loc = l_outbound_plogi_loc
                               AND zone_type = 'PUT';
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Calculating the Warehouse Id when Qty is Suspect';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;   
                        
                        ------------------Creating a STA transaction for Suspect Quantity------------------
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                  rec_id, src_loc, pallet_id, qty_expected,
                                                  qty, reason_code, user_id, uom, upload_time,
                                                  exp_date, old_status, new_status, warehouse_id, cust_pref_vendor )
                                          VALUES (trans_id_seq.nextval, 'STA', sysdate, i.prod_id,
                                                  i.rec_id, l_outbound_plogi_loc, l_pallet_id_new, 
                                                 (l_qty_inducted*l_spc), (l_qty_suspect*l_spc), 'CC', user, i.inv_uom, 
                                                 to_date('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),i.exp_date, 
                                                 i.status, 'HLD', l_warehouse_id, i.cust_pref_vendor);
                            END LOOP;             
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Creating a STA transaction when Qty is Suspect';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                         
                        ------------------Creating a MXE transaction for Suspect Quantiy----------------
                                          
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                  rec_id, src_loc, pallet_id, qty_expected,
                                                  qty, reason_code, user_id, uom, upload_time,
                                                  exp_date, old_status, warehouse_id, cust_pref_vendor )
                                          VALUES (trans_id_seq.nextval, 'MXE', sysdate, i.prod_id,
                                                  i.rec_id, l_outbound_plogi_loc, l_pallet_id_new, 
                                                  (l_qty_inducted*l_spc), (l_qty_suspect*l_spc), 'CC', user, i.inv_uom, 
                                                  null,i.exp_date, 'HLD', l_warehouse_id, i.cust_pref_vendor);
                            END LOOP;             
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Creating a MXE transaction when Qty is Damaged';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                        
                        ------------------For Putaway Create MXP Transaction for Suspect Quantity---------------------------    
                        IF l_trans_type = 'PUT' THEN      
                            BEGIN
                                SELECT erm_type, status
                                  INTO l_erm_type, l_erm_status
                                  FROM erm
                                 WHERE erm_id = l_po_no;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    l_error_msg := 'Failed getting erm_type for erm_id '||l_po_no;
                                    l_error_code:= SUBSTR(SQLERRM,1,100);
                                    RAISE validation_exception;
                            END;
                            
                            ----------Creating a MXP transaction for Suspect Quantity(Regular PO/SN)-----------
                            IF l_erm_type IN ('PO', 'SN') AND l_erm_status IN ('OPN', 'CLO') THEN     
                                BEGIN
                                    FOR i IN c_get_all_inv
                                    LOOP
                                        INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                          rec_id, dest_loc, pallet_id, qty_expected,
                                                          qty, reason_code, user_id, uom, upload_time,
                                                          exp_date, new_status, warehouse_id, cust_pref_vendor )
                                                  VALUES (trans_id_seq.nextval, 'MXP', sysdate, i.prod_id,
                                                          i.rec_id, l_outbound_plogi_loc, l_pallet_id_new, 
                                                          (l_qty_inducted*l_spc), (l_qty_suspect*l_spc), 'CC', user, i.inv_uom, 
                                                          null, i.exp_date, 'AVL', l_warehouse_id, i.cust_pref_vendor);
                                    END LOOP;             
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        ROLLBACK;
                                        l_error_msg := 'Failed Creating a MXP transaction when Qty is Suspect(Regular Put)';
                                        l_error_code:= SUBSTR(SQLERRM,1,100);
                                        RAISE validation_exception;
                                END;            
                            END IF;  /*IF l_erm_type IN ('PO', 'SN')*/            
                        END IF; /*IF l_trans_type = 'PUT'*/  
                      
                    END IF; /*IF l_qty_suspect != 0*/
                    
                    -----Validating the out of tolerance items and Querying the outbound loc--------      
                    IF l_qty_out_of_tolerance != 0 THEN
                        BEGIN
                            SELECT logi_loc 
                              INTO l_outbound_plogi_loc
                              FROM loc 
                             WHERE slot_type ='MXO';
                        EXCEPTION
                            WHEN OTHERS THEN
                                l_error_msg := 'Failed Getting the outbound location when Out of Tolerance';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                        
                        --------Calculating the Length and concatinating the OOT to the pallet ID-------   
                        l_length := LENGTH(l_pallet_id);
                   
                        IF l_length <= 15 THEN
                            l_pallet_id_new  := 'OOT'||l_pallet_id;
                        ELSIF l_length = 16 THEN
                            l_pallet_id_new  := 'OOT'||SUBSTR(l_pallet_id,2);
                        ELSIF l_length = 17 THEN
                            l_pallet_id_new  := 'OOT'||SUBSTR(l_pallet_id,3);
                        ELSIF l_length = 18 THEN
                            l_pallet_id_new  := 'OOT'||SUBSTR(l_pallet_id,4);
                        END IF;
                        
                        ---------------------Inserting the new record with the OOT INV------------------       
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO inv(prod_id, rec_id, mfg_date, rec_date,
                                                exp_date, inv_date, logi_loc, plogi_loc,
                                                qoh, qty_alloc, qty_planned, min_qty,
                                                cube, lst_cycle_date, lst_cycle_reason, abc,
                                                abc_gen_date, status, lot_id, weight, temperature,
                                                exp_ind, cust_pref_vendor, parent_pallet_id, inv_uom) 
                                        VALUES (i.prod_id, i.rec_id, i.mfg_date, i.rec_date,
                                                i.exp_date, i.inv_date, l_pallet_id_new, l_outbound_plogi_loc,
                                                (l_qty_out_of_tolerance*l_spc), i.qty_alloc, i.qty_planned, i.min_qty,
                                                i.cube, i.lst_cycle_date, i.lst_cycle_reason, i.abc,
                                                i.abc_gen_date, i.status, i.lot_id, i.weight, i.temperature, 
                                                i.exp_ind, i.cust_pref_vendor, i.parent_pallet_id, i.inv_uom); 
                            END LOOP;            
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Inserting New Record in INV when Out of Tolerance';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                        
                        ------------Creating a MXE transaction for Out of Tolerance Quantiy-------------
                                      
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                  rec_id, src_loc, pallet_id, qty_expected,
                                                  qty, reason_code, user_id, uom, upload_time,
                                                  exp_date, old_status, warehouse_id, cust_pref_vendor )
                                          VALUES (trans_id_seq.nextval, 'MXE', sysdate, i.prod_id,
                                                  i.rec_id, l_outbound_plogi_loc, l_pallet_id_new, 
                                                 (l_qty_inducted*l_spc), (l_qty_out_of_tolerance*l_spc), 'CC', user, i.inv_uom, 
                                                 null,i.exp_date, i.status, l_warehouse_id, i.cust_pref_vendor);
                            END LOOP;             
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Creating a MXE transaction when Qty is Out of Tolerance';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;       
                        
                        ------------------For Putaway Create MXP Transaction for OOT Quantity---------------------------
                        IF l_trans_type = 'PUT' THEN      
                            BEGIN
                                SELECT erm_type, status 
                                  INTO l_erm_type, l_erm_status
                                  FROM erm
                                 WHERE erm_id = l_po_no;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    l_error_msg := 'Failed getting erm_type for erm_id '||l_po_no;
                                    l_error_code:= SUBSTR(SQLERRM,1,100);
                                    RAISE validation_exception;
                            END;
                            
                            ----------Creating a MXP transaction Out of Tolerance Quantity(Regular PO/SN)-----------
                            IF l_erm_type IN ('PO', 'SN') AND l_erm_status IN ('OPN', 'CLO') THEN                                   
                                BEGIN
                                    FOR i IN c_get_all_inv
                                    LOOP
                                        INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                          rec_id, dest_loc, pallet_id, qty_expected,
                                                          qty, reason_code, user_id, uom, upload_time,
                                                          exp_date, new_status, warehouse_id, cust_pref_vendor )
                                                  VALUES (trans_id_seq.nextval, 'MXP', sysdate, i.prod_id,
                                                          i.rec_id, l_outbound_plogi_loc, l_pallet_id_new, 
                                                          (l_qty_inducted*l_spc), (l_qty_out_of_tolerance*l_spc), 'CC', user, i.inv_uom, 
                                                          NULL, i.exp_date, i.status, l_warehouse_id, i.cust_pref_vendor);
                                    END LOOP;             
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        ROLLBACK;
                                        l_error_msg := 'Failed Creating a MXP transaction when Qty is Damaged(Regular Put)';
                                        l_error_code:= SUBSTR(SQLERRM,1,100);
                                        RAISE validation_exception;
                                END;            
                            END IF;            
                        END IF; /*IF l_trans_type = 'PUT'*/
                    END IF; /*IF l_qty_out_of_tolerance != 0*/
                  
                    ------------Validating the Wrong items and Querying the outbound loc------------      
                    IF l_qty_wrong_item != 0 THEN
                        BEGIN
                            SELECT logi_loc 
                              INTO l_outbound_plogi_loc
                              FROM loc 
                             WHERE slot_type ='MXO';
                        EXCEPTION
                            WHEN OTHERS THEN
                            l_error_msg := 'Failed Getting the outbound location when Wrong Item';
                            l_error_code:= SUBSTR(SQLERRM,1,100);
                            RAISE validation_exception;
                        END;
                        
                        -------Calculating the Length and concatinating the WRG to the pallet ID--------      
                        l_length := LENGTH(l_pallet_id);
                        BEGIN
                            SELECT parent_pallet_id
                              INTO l_parent_pallet_id
                              FROM matrix_in
                             WHERE mx_msg_id = l_mx_msg_id
                               AND rec_ind = 'H'; 
                        EXCEPTION
                            WHEN OTHERS THEN
                            l_error_msg := 'Failed Getting parent_pallet_id from matrix_in for mx_msg_id '|| l_mx_msg_id;
                            l_error_code:= SUBSTR(SQLERRM,1,100);
                            RAISE validation_exception;
                        END;
                        
                        IF l_parent_pallet_id IS NOT NULL THEN
                            l_pallet_init := 'MSK';
                        ELSE    
                            l_pallet_init := 'WRG';
                        END IF;
                        
                        IF l_length <= 15 THEN
                            l_pallet_id_new  := l_pallet_init || l_pallet_id;
                        ELSIF l_length = 16 THEN
                            l_pallet_id_new  := l_pallet_init || SUBSTR(l_pallet_id,2);
                        ELSIF l_length = 17 THEN
                            l_pallet_id_new  := l_pallet_init || SUBSTR(l_pallet_id,3);
                        ELSIF l_length = 18 THEN
                            l_pallet_id_new  := l_pallet_init || SUBSTR(l_pallet_id,4);
                        END IF;
                        
                        -------------------Inserting the new record with the WRG INV--------------------        
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO inv(prod_id, rec_id, mfg_date, rec_date,
                                                exp_date, inv_date, logi_loc, plogi_loc,
                                                qoh, qty_alloc, qty_planned, min_qty,
                                                cube, lst_cycle_date, lst_cycle_reason, abc,
                                                abc_gen_date, status, lot_id, weight, temperature,
                                                exp_ind, cust_pref_vendor, parent_pallet_id, inv_uom) 
                                        VALUES (i.prod_id, i.rec_id, i.mfg_date, i.rec_date,
                                                i.exp_date, i.inv_date, l_pallet_id_new, l_outbound_plogi_loc,
                                                (l_qty_wrong_item*l_spc), i.qty_alloc, i.qty_planned, i.min_qty,
                                                i.cube, i.lst_cycle_date, i.lst_cycle_reason, i.abc,
                                                i.abc_gen_date, 'HLD', i.lot_id, i.weight, i.temperature, 
                                                i.exp_ind, i.cust_pref_vendor, i.parent_pallet_id, i.inv_uom); 
                            END LOOP;            
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Inserting New Record in INV when Wrong Item';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                
                        ----------Calculating the Warehouse Id for creating a STA transaction-----------   
                        BEGIN
                            SELECT zn.warehouse_id 
                              INTO l_warehouse_id
                              FROM zone zn, lzone z
                             WHERE zn.zone_id = z.zone_id
                               AND z.logi_loc = l_outbound_plogi_loc
                               AND zone_type = 'PUT';
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Calculating the Warehouse Id when Wrong Item';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;   
                
                        ------------------Creating a STA transaction for Wrong Item---------------------
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                  rec_id, src_loc, pallet_id, qty_expected,
                                                  qty, reason_code, user_id, uom, upload_time,
                                                  exp_date, old_status, new_status, warehouse_id, cust_pref_vendor )
                                          VALUES (trans_id_seq.NEXTVAL, 'STA', SYSDATE, i.prod_id,
                                                  i.rec_id, l_outbound_plogi_loc, l_pallet_id_new, 
                                                  (l_qty_inducted*l_spc), (l_qty_wrong_item*l_spc), 'CC', USER, i.inv_uom, 
                                                  TO_DATE('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),i.exp_date, 
                                                  i.status, 'HLD', l_warehouse_id, i.cust_pref_vendor);
                            END LOOP;             
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Creating a STA transaction when Wrong Item';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                 
                        ------------------Creating a MXE transaction for WRONG ITEM---------------------
                                  
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                  rec_id, src_loc, pallet_id, qty_expected,
                                                  qty, reason_code, user_id, uom, upload_time,
                                                  exp_date, old_status, warehouse_id, cust_pref_vendor )
                                          VALUES (trans_id_seq.NEXTVAL, 'MXE', SYSDATE, i.prod_id,
                                                  i.rec_id, l_outbound_plogi_loc, l_pallet_id_new, 
                                                  (l_qty_inducted*l_spc), (l_qty_wrong_item*l_spc), 'CC', USER, i.inv_uom, 
                                                  NULL,i.exp_date, 'HLD', l_warehouse_id, i.cust_pref_vendor);
                            END LOOP;             
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Creating a MXE transaction when Wrong Item';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                        
                        ------------------For Putaway Create MXP Transaction for Wrong Quantity---------------------------
                        IF l_trans_type = 'PUT' THEN      
                            BEGIN
                                SELECT erm_type, status
                                  INTO l_erm_type, l_erm_status
                                  FROM erm
                                 WHERE erm_id = l_po_no;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    l_error_msg := 'Failed getting erm_type for erm_id '||l_po_no;
                                    l_error_code:= SUBSTR(SQLERRM,1,100);
                                    RAISE validation_exception;
                            END;
                            
                            ----------Creating a MXP transaction for Wrong Quantity(Regular PO/SN)-----------
                            IF l_erm_type IN ('PO', 'SN') AND l_erm_status IN ('OPN', 'CLO') THEN               
                                BEGIN
                                    FOR i IN c_get_all_inv
                                    LOOP
                                        INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                          rec_id, dest_loc, pallet_id, qty_expected,
                                                          qty, reason_code, user_id, uom, upload_time,
                                                          exp_date, new_status, warehouse_id, cust_pref_vendor )
                                                  VALUES (trans_id_seq.NEXTVAL, 'MXP', SYSDATE, i.prod_id,
                                                          i.rec_id, l_outbound_plogi_loc, l_pallet_id_new, 
                                                          (l_qty_inducted*l_spc), (l_qty_wrong_item*l_spc), 'CC', USER, i.inv_uom, 
                                                          NULL, i.exp_date, 'AVL', l_warehouse_id, i.cust_pref_vendor);
                                    END LOOP;             
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        ROLLBACK;
                                        l_error_msg := 'Failed Creating a MXP transaction when Wrong Item(Regular Put)';
                                        l_error_code:= SUBSTR(SQLERRM,1,100);
                                        RAISE validation_exception;
                                END;
                    
                            END IF;            
                        END IF;   /*IF l_trans_type = 'PUT'*/       
                    END IF;  /*IF l_qty_wrong_item != 0 */     
                    
                    ------------Validating the Short items and Querying the outbound loc------------ 
                    IF l_qty_short != 0 THEN
                        BEGIN
                            SELECT logi_loc 
                              INTO l_outbound_plogi_loc
                              FROM loc 
                             WHERE slot_type ='MXO';
                        EXCEPTION
                            WHEN OTHERS THEN
                                l_error_msg := 'Failed Getting the outbound location when Short Item';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                        
                        -------Calculating the Length and concatinating the SHT to the pallet ID--------      
                        l_length := LENGTH(l_pallet_id);
                   
                        IF l_length <= 15 THEN
                            l_pallet_id_new  := 'SHT'||l_pallet_id;
                        ELSIF l_length = 16 THEN
                            l_pallet_id_new  := 'SHT'||SUBSTR(l_pallet_id,2);
                        ELSIF l_length = 17 THEN
                            l_pallet_id_new  := 'SHT'||SUBSTR(l_pallet_id,3);
                        ELSIF l_length = 18 THEN
                            l_pallet_id_new  := 'SHT'||SUBSTR(l_pallet_id,4);
                        END IF;
                        
                        -------------------Inserting the new record with the SHT INV--------------------        
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO inv(prod_id, rec_id, mfg_date, rec_date,
                                                exp_date, inv_date, logi_loc, plogi_loc,
                                                qoh, qty_alloc, qty_planned, min_qty,
                                                cube, lst_cycle_date, lst_cycle_reason, abc,
                                                abc_gen_date, status, lot_id, weight, temperature,
                                                exp_ind, cust_pref_vendor, parent_pallet_id, inv_uom) 
                                        VALUES (i.prod_id, i.rec_id, i.mfg_date, i.rec_date,
                                                i.exp_date, i.inv_date, l_pallet_id_new, l_outbound_plogi_loc,
                                                (l_qty_short*l_spc), i.qty_alloc, i.qty_planned, i.min_qty,
                                                i.cube, i.lst_cycle_date, i.lst_cycle_reason, i.abc,
                                                i.abc_gen_date, 'HLD', i.lot_id, i.weight, i.temperature, 
                                                i.exp_ind, i.cust_pref_vendor, i.parent_pallet_id, i.inv_uom); 
                            END LOOP;            
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Inserting New Record in INV when Short Item';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;

                        ----------Calculating the Warehouse Id for creating a STA transaction-----------   
                        BEGIN
                            SELECT zn.warehouse_id 
                              INTO l_warehouse_id
                              FROM zone zn, lzone z
                             WHERE zn.zone_id = z.zone_id
                               AND z.logi_loc = l_outbound_plogi_loc
                               AND zone_type = 'PUT';
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Calculating the Warehouse Id when Qty is Short';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;   
                   
                        ------------------Creating a STA transaction for Short Quantity------------------
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                  rec_id, src_loc, pallet_id, qty_expected,
                                                  qty, reason_code, user_id, uom, upload_time,
                                                  exp_date, old_status, new_status, warehouse_id, cust_pref_vendor)
                                          VALUES (trans_id_seq.nextval, 'STA', sysdate, i.prod_id,
                                                  i.rec_id, l_outbound_plogi_loc, l_pallet_id_new, 
                                                  (l_qty_inducted*l_spc), (l_qty_short*l_spc), 'CC', user, i.inv_uom, 
                                                  to_date('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),i.exp_date, 
                                                  i.status, 'HLD', l_warehouse_id, i.cust_pref_vendor);
                            END LOOP;             
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Creating a STA transaction when Qty is Short';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                      
                        ------------------Creating a MXE transaction for Short Quantity------------------                          
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                  rec_id, src_loc, pallet_id, qty_expected,
                                                  qty, reason_code, user_id, uom, upload_time,
                                                  exp_date, old_status, warehouse_id, cust_pref_vendor )
                                          VALUES (trans_id_seq.NEXTVAL, 'MXE', SYSDATE, i.prod_id,
                                                  i.rec_id, l_outbound_plogi_loc, l_pallet_id_new, 
                                                  (l_qty_inducted*l_spc), (l_qty_short*l_spc), 'CC', USER, i.inv_uom, 
                                                  NULL,i.exp_date, 'HLD', l_warehouse_id, i.cust_pref_vendor);
                            END LOOP;             
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Creating a MXE transaction when Qty is Short';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                        
                        ------------------For Putaway Create MXP Transaction for Short Quantity---------------------------
                        IF l_trans_type = 'PUT' THEN      
                            BEGIN
                                SELECT erm_type, status
                                  INTO l_erm_type, l_erm_status
                                  FROM erm
                                 WHERE erm_id = l_po_no;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    l_error_msg := 'Failed getting erm_type and status for erm_id '||l_po_no;
                                    l_error_code:= SUBSTR(SQLERRM,1,100);
                                    RAISE validation_exception;
                            END;
                            
                            ----------Creating a MXP transaction for Short Quantity(Regular PO/SN)-----------
                            IF l_erm_type IN ('PO', 'SN') AND l_erm_status IN ('OPN', 'CLO') THEN                           
                                BEGIN
                                    FOR i IN c_get_all_inv
                                    LOOP
                                        INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                          rec_id, dest_loc, pallet_id, qty_expected,
                                                          qty, reason_code, user_id, uom, upload_time,
                                                          exp_date, new_status, warehouse_id, cust_pref_vendor )
                                                  VALUES (trans_id_seq.NEXTVAL, 'MXP', SYSDATE, i.prod_id,
                                                          i.rec_id, l_outbound_plogi_loc, l_pallet_id_new, 
                                                          (l_qty_inducted*l_spc), (l_qty_short*l_spc), 'CC', USER, i.inv_uom, 
                                                          NULL, i.exp_date, 'HLD', l_warehouse_id, i.cust_pref_vendor);
                                    END LOOP;             
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        ROLLBACK;
                                        l_error_msg := 'Failed Creating a MXP transaction when Qty is Short(Regular Put)';
                                        l_error_code:= SUBSTR(SQLERRM,1,100);
                                        RAISE validation_exception;
                                END;            
                            END IF; /*IF l_erm_type IN ('PO', 'SN')*/           
                        END IF; /*IF l_trans_type = 'PUT' */         
                    END IF; /*IF l_qty_short != 0 THEN*/

                    -----------Validating the over items and logging it in Exception table---------- 
                    IF l_qty_over != 0 THEN      
                        -------Calculating the Length and concatinating the SHT to the pallet ID--------      
                        l_length := LENGTH(l_pallet_id);
                   
                        IF l_length <= 15 THEN
                            l_pallet_id_new  := 'OVR'||l_pallet_id;
                        ELSIF l_length = 16 THEN
                            l_pallet_id_new  := 'OVR'||SUBSTR(l_pallet_id,2);
                        ELSIF l_length = 17 THEN
                            l_pallet_id_new  := 'OVR'||SUBSTR(l_pallet_id,3);
                        ELSIF l_length = 18 THEN
                            l_pallet_id_new  := 'OVR'||SUBSTR(l_pallet_id,4);
                        END IF;
                        
                        ----------Calculating the Warehouse Id for creating a ADJ transaction-----------   
                        BEGIN
                            SELECT zn.warehouse_id 
                              INTO l_warehouse_id
                              FROM zone zn, lzone z
                             WHERE zn.zone_id = z.zone_id
                               AND z.logi_loc = l_plogi_loc
                               AND zone_type = 'PUT';
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Calculating the Warehouse Id when Qty is Over';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END; 
                  
                        -------------------Creating a MXE transaction for Over Quantity------------------                          
                        BEGIN
                            FOR i IN c_get_all_inv
                            LOOP
                                INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                  rec_id, src_loc, pallet_id, qty_expected,
                                                  qty, reason_code, user_id, uom, upload_time,
                                                  exp_date, old_status, warehouse_id, cust_pref_vendor )
                                          VALUES (trans_id_seq.nextval, 'MXE', sysdate, i.prod_id,
                                                  i.rec_id, l_plogi_loc, l_pallet_id_new, 
                                                  (l_qty_inducted*l_spc), (l_qty_over*l_spc), 'CC', USER, i.inv_uom, 
                                                  NULL,i.exp_date, i.status, l_warehouse_id, i.cust_pref_vendor);
                            END LOOP;             
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Creating a MXE transaction when Qty is Over';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                        
                        IF l_trans_type = 'PUT' THEN
                            BEGIN
                                SELECT erm_type, status
                                  INTO l_erm_type, l_erm_status
                                  FROM erm
                                 WHERE erm_id = l_po_no;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    l_error_msg := 'Failed getting erm_type for erm_id '||l_po_no;
                                    l_error_code:= SUBSTR(SQLERRM,1,100);
                                    RAISE validation_exception;
                            END;

                            IF l_erm_type IN ('PO', 'SN') THEN
                                IF l_erm_type = 'SN' THEN
                                    BEGIN
                                        SELECT po_no
                                          INTO l_rec_id 
                                          FROM erd_lpn
                                         WHERE pallet_id = l_pallet_id
                                           AND sn_no = l_po_no; 
                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            l_error_msg := 'Failed getting rec_id from inv for pallet_id '||l_pallet_id;
                                            l_error_code:= SUBSTR(SQLERRM,1,100);
                                            RAISE validation_exception;
                                    END;
                                    
                                    BEGIN
                                        SELECT po_status
                                          INTO l_po_status
                                          FROM rdc_po
                                         WHERE po_no = l_rec_id;
                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            l_error_msg := 'Failed getting po_status from rdc_po for po_no '||l_rec_id;
                                            l_error_code:= SUBSTR(SQLERRM,1,100);
                                            RAISE validation_exception;
                                    END;
                                ELSE
                                    l_rec_id := l_po_no;
                                    
                                    BEGIN
                                        SELECT status
                                          INTO l_po_status
                                          FROM erm
                                         WHERE erm_id = l_rec_id;
                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            l_error_msg := 'Failed getting po_status from erm for erm_id '||l_rec_id;
                                            l_error_code:= SUBSTR(SQLERRM,1,100);
                                            RAISE validation_exception;
                                    END; 
                                END IF;
                                
                                IF l_po_status = 'OPN' THEN
                                    BEGIN
                                        FOR i IN c_get_all_inv
                                        LOOP
                                            INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                              rec_id, src_loc, pallet_id, qty_expected,
                                                              qty, reason_code, user_id, uom, upload_time,
                                                              exp_date, old_status, warehouse_id,cust_pref_vendor)
                                                      VALUES (trans_id_seq.nextval, 'PUT', sysdate, i.prod_id,
                                                              i.rec_id, l_plogi_loc, l_pallet_id_new, (l_qty_inducted*l_spc),
                                                              (l_qty_over*l_spc), 'CC', user, i.inv_uom, to_date('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),
                                                              i.exp_date, i.status, l_warehouse_id, i.cust_pref_vendor);
                                        END LOOP;             
                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            ROLLBACK;
                                            l_error_msg := 'Failed Creating a PUT transaction when Qty is Over';
                                            l_error_code:= SUBSTR(SQLERRM,1,100);
                                            RAISE validation_exception;
                                    END; 
                                    
                                                                
                                    /*UPDATE erd
                                       SET qty = l_qty_inducted
                                      WHERE erm_id = l_rec_id
                                        AND prod_id = l_prod_id;    */
                                  
                                END IF; /*IF l_po_status = 'OPN'*/

/*
/* The next section is commented out as part of Charm 6000012796 to fix incidents like 3696903.
/* We no longer want to send COR transactions to SUS in the event of an overage. 
/*
                                IF l_po_status = 'CLO' THEN
                                    BEGIN
                                        FOR i IN c_get_all_inv
                                        LOOP
                                            INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                              rec_id, src_loc, pallet_id, qty_expected,
                                                              qty, reason_code, user_id, uom, upload_time,
                                                              exp_date, old_status, warehouse_id,cust_pref_vendor)
                                                      VALUES (trans_id_seq.nextval, DECODE(l_erm_type, 'SN', 'CSQ', 'COR'), SYSDATE, i.prod_id,
                                                              i.rec_id, l_plogi_loc, l_pallet_id, (l_qty_inducted*l_spc),
                                                              (l_qty_over*l_spc), '', USER, i.inv_uom, to_date('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),
                                                              i.exp_date, i.status, l_warehouse_id, i.cust_pref_vendor);
                                        END LOOP;             
                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            ROLLBACK;
                                            l_error_msg := 'Failed Creating a CSQ/COR transaction when Qty is Over';
                                            l_error_code:= SUBSTR(SQLERRM,1,100);
                                            RAISE validation_exception;
                                    END; 
                                END IF;  -- IF l_po_status = 'CLO'
************/


                            END IF; /*IF l_erm_type IN ('PO', 'SN')*/
                        END IF; /*IF l_trans_type = 'PUT'*/
                        
                        /*IF l_trans_type = 'MXL' OR l_trans_type = 'NXL'  OR l_trans_type = 'XFR' OR (l_trans_type ='PUT' AND (l_po_status = 'VCH' OR l_erm_type = 'CM')) THEN     
                            ------------------Creating a ADJ transaction for over Quantiy-------------------
                            BEGIN
                                FOR i IN c_get_all_inv
                                LOOP
                                    INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                      rec_id, src_loc, pallet_id, qty_expected,
                                                      qty, reason_code, user_id, uom, upload_time,
                                                      exp_date, old_status, warehouse_id,cust_pref_vendor)
                                              VALUES (trans_id_seq.nextval, 'ADJ', sysdate, i.prod_id,
                                                      i.rec_id, l_plogi_loc, l_pallet_id, (l_qty_inducted*l_spc),
                                                      (l_qty_over*l_spc), 'CC', user, i.inv_uom, to_date('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),
                                                      i.exp_date, i.status, l_warehouse_id, i.cust_pref_vendor);
                                END LOOP;             
                            EXCEPTION
                                WHEN OTHERS THEN
                                    ROLLBACK;
                                    l_error_msg := 'Failed Creating a ADJ transaction when Qty is Over';
                                    l_error_code:= SUBSTR(SQLERRM,1,100);
                                    RAISE validation_exception;
                            END; 
                        END IF; */ /*IF l_trans_type = 'MXL' or l_trans_type = 'NXL' .....*/
                        
                    END IF; /*IF l_qty_over != 0 THE */   
                    
                    ----------------Removing the '0' Quantity record from the inv-------------------    
                    IF l_qty_stored = 0 THEN
                        BEGIN
                            DELETE 
                              FROM inv
                             WHERE prod_id   = l_prod_id
                               AND logi_loc  = l_pallet_id;
                        EXCEPTION
                            WHEN OTHERS THEN
                                ROLLBACK;
                                l_error_msg := 'Failed Deleting the Record from INV where quantity is 0';
                                l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE validation_exception;
                        END;
                    END IF;
            
               -- END IF;
            
            END LOOP;   
            
               
            ------------------Unlocking the Record and Updating to Success------------------      
            BEGIN
                UPDATE matrix_in
                   SET record_status = 'S'
                 WHERE mx_msg_id     = l_mx_msg_id
                   AND record_status = 'Q';
            EXCEPTION
                WHEN OTHERS THEN
                    ROLLBACK;
                    l_error_msg := 'Failed Unlocking the record from Q to S';
                    l_error_code:= SUBSTR(SQLERRM,1,100);
                    RAISE validation_exception;
            END;
            
            COMMIT;
        END IF;    
    END LOOP; /*FOR k IN c_mx_msg_id*/
 
EXCEPTION
    --------------------Any Failure Updating the Status to Failure------------------
    WHEN validation_exception THEN
        ROLLBACK;
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT;

    WHEN duplicate_exception THEN
        ROLLBACK;
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id
           AND record_status = 'Q';
        COMMIT;

    WHEN OTHERS THEN
        ROLLBACK;
        --------------------Any Failure Updating the Status to Failure------------------  
        l_error_msg    := SUBSTR(SQLERRM,1,100);
        l_error_code   := SUBSTR(SQLCODE,1,100);
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT;
END sym03_inv_update;

 /*---------------------------------------------------------------------------
 Procedure:
    sym07_rpln_inv_update

 Description:
    This procedure execute when swms receive SYM07 interface to update the replenishment with 
    actual spur location for DSP, NSP and UNA and create replenishment for MRL (manual release).
    Also update the inventory for UNA and MRL and create inventory for DSP and NSP.

 Parameter:
      Input:
          i_mx_msg_id               Message ID                     
      
      Return:
          N/A
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    02-DEC-2014  ayad5195 Initial Creation.
    04-JAN-2016  ayad5195 Changed the procedure to add new type IIR
---------------------------------------------------------------------------*/ 
PROCEDURE sym07_rpln_inv_update( i_mx_msg_id IN NUMBER DEFAULT NULL)
IS  
    CURSOR c_header IS
        SELECT trans_type, mx_msg_id, spur_loc, batch_id, sequence_timestamp 
          FROM matrix_in
         WHERE interface_ref_doc = 'SYM07'
           AND rec_ind = 'H'
           AND mx_msg_id = NVL(i_mx_msg_id, mx_msg_id)
           AND (add_date   <  systimestamp - 1/(24*60) OR i_mx_msg_id IS NOT NULL)
           AND record_status = 'N';
    
    CURSOR c_detail (i_msg_id IN NUMBER) IS
        SELECT pallet_id, case_qty, prod_id, task_id 
          FROM matrix_in
         WHERE rec_ind = 'D'
           AND mx_msg_id = i_msg_id; 
           
    CURSOR c_inv (i_pallet_id IN VARCHAR2) IS
        SELECT l.pik_path, i.logi_loc, i.plogi_loc, i.qoh, i.exp_date,
               i.parent_pallet_id, i.rec_id, i.lot_id, i.mfg_date, i.rec_date,
               i.qty_planned, i.inv_date, i.min_qty, i.abc, i.inv_uom,
               l.slot_type, i.cust_pref_vendor, i.prod_id 
          FROM inv i, loc l
         WHERE i.logi_loc = i_pallet_id
           AND i.plogi_loc = l.logi_loc;   
           
    CURSOR c_pallet (i_prod_id IN VARCHAR2) IS
          SELECT i.logi_loc, (i.qoh-i.qty_alloc) qoh_avl, i.qty_alloc
          FROM inv i, loc l
         WHERE i.prod_id =  i_prod_id
           AND l.slot_type IN ('MXF', 'MXC')
           AND l.logi_loc = i.plogi_loc
           AND (i.qoh-i.qty_alloc) > 0
     ORDER BY (i.qoh-i.qty_alloc) DESC;
    
         
    l_suggest_loc           pl_putaway_utilities.t_phys_loc;
    l_num_of_locations      NUMBER;
    l_def_spur_loc          replenlst.src_loc%TYPE;
    l_batch_no              NUMBER;
    l_record_status         matrix_in.record_status%TYPE;
    l_error_msg             VARCHAR2(100);
    l_error_code            VARCHAR2(100);
    l_qoh                   inv.qoh%TYPE;
    l_pallet_id             inv.logi_loc%TYPE;
    l_result                NUMBER; 
    l_def_unassign_loc      inv.plogi_loc%TYPE;
    l_frm_loc               inv.plogi_loc%TYPE;
    l_fname                 VARCHAR2 (50)       := 'sym07_rpln_inv_update';
    l_process_cnt           NUMBER := 0;
    g_tabTask               pl_swms_execute_sql.tabTask;
    l_count_commit          NUMBER := 0;
    l_priority              INTEGER;
    l_find_loc              NUMBER := 0;
    l_dest_loc              replenlst.dest_loc%TYPE;    
    l_spc                   pm.spc%TYPE;
    l_lbr_batch_no          replenlst.labor_batch_no%TYPE; 
    l_mx_msg_id             swms.matrix_in.mx_msg_id%TYPE;
    validation_exception    EXCEPTION;
    l_qty_alloc             inv.qty_alloc%TYPE;
    l_cnt_iir               NUMBER; 
    l_length                NUMBER;
    l_pallet_id_new         inv.logi_loc%TYPE;
    l_cnt_pallet            NUMBER;
    l_prod_id               inv.prod_id%TYPE;
    l_qty_delete            NUMBER;
    l_lpn                   inv.logi_loc%TYPE;
    l_pallet_exists         NUMBER;
    l_cust_pref_vendor      inv.cust_pref_vendor%TYPE;
    l_rec_id                inv.rec_id%TYPE;
    l_plogi_loc             inv.plogi_loc%TYPE;
    l_uom                   inv.inv_uom%TYPE;
    l_mfg_date              inv.mfg_date%TYPE;
    l_exp_date              inv.exp_date%TYPE;
    l_status                inv.status%TYPE;
    l_wh_id                 zone.warehouse_id%TYPE;
    
 BEGIN
    Pl_Text_Log.ins_msg ('I', l_fname, 'BEGIN  sym07_rpln_inv_update for i_mx_msg_id='||i_mx_msg_id, NULL, NULL);
    
    l_batch_no := repl_cond_seq.NEXTVAL;
    
    BEGIN
        SELECT logi_loc  
          INTO l_def_unassign_loc
          FROM loc
         WHERE slot_type = 'MXO'
           AND rownum = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_error_msg := 'Prog Code: ' || l_fname
            || ' Default unassign location not found in loc for slot_type MXO';
            l_error_code:= SUBSTR(SQLERRM,1,100);
        RAISE validation_exception; 
    END;
    
    FOR r_hdr IN c_header
    LOOP
        l_mx_msg_id := r_hdr.mx_msg_id;

        BEGIN
            UPDATE matrix_in
               SET record_status = 'Q'
             WHERE mx_msg_id = r_hdr.mx_msg_id
               AND record_status = 'N';
               
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                l_error_msg := 'sym07_rpln_inv_update: Failed Updating the Record Status to Q';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
        END;
        
        Pl_Text_Log.ins_msg ('I', l_fname, 'SPUR Location  r_hdr.spur_loc='||r_hdr.spur_loc, NULL, NULL);
        
        IF r_hdr.spur_loc NOT LIKE 'SP%J%' THEN
            Pl_Text_Log.ins_msg ('I', l_fname, 'Before Insert mx_batch_info r_hdr.spur_loc='||r_hdr.spur_loc, NULL, NULL);
            
            /*Insert into mx_batch_info for baggage claim */    
            INSERT INTO mx_batch_info (sequence_number, batch_no, batch_type, replen_type,
                                       status, spur_location, sequence_timestamp)
                               VALUES (mx_batch_info_seq.NEXTVAL, r_hdr.batch_id, 'R', r_hdr.trans_type,
                                       'AVL', r_hdr.spur_loc,  r_hdr.sequence_timestamp );
        END IF;
        
        FOR r_dtl IN c_detail(r_hdr.mx_msg_id)
        LOOP
            Pl_Text_Log.ins_msg ('I', l_fname, 'In Detail Loop  r_hdr.trans_type='||r_hdr.trans_type, NULL, NULL);
            
            IF r_hdr.trans_type = 'MRL' THEN  /*Manual Release */
                BEGIN
                    SELECT i.qoh, p.spc
                      INTO l_qoh, l_spc
                      FROM inv i, pm p
                     WHERE i.logi_loc = r_dtl.pallet_id
                       AND i.prod_id = p.prod_id
                       AND i.cust_pref_vendor = p.cust_pref_vendor;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        l_error_msg := 'sym07_rpln_inv_update: Failed to select qoh from inv (MRL) for pallet_id '|| r_dtl.pallet_id;
                        l_error_code:= SUBSTR(SQLERRM,1,100);
                        RAISE validation_exception;
                END;
                
                IF l_qoh = r_dtl.case_qty * l_spc THEN /*Full Pallet released*/
                    l_pallet_id := r_dtl.pallet_id;
                    
                    UPDATE inv
                       SET plogi_loc = r_hdr.spur_loc
                     WHERE logi_loc = r_dtl.pallet_id;
                       
                ELSE /*Partial Pallet released*/
                    l_pallet_id := pallet_id_seq.NEXTVAL;
                    
                    INSERT INTO inv (prod_id, rec_id, mfg_date, rec_date, exp_date, inv_date, logi_loc, plogi_loc, 
                                     qoh, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason, 
                                     abc, abc_gen_date, status, lot_id, weight, temperature, exp_ind, cust_pref_vendor,
                                     case_type_tmu, pallet_height, add_date, add_user, upd_date, upd_user, parent_pallet_id,
                                     dmg_ind,inv_uom) 
                              SELECT prod_id, rec_id, mfg_date, rec_date, exp_date, inv_date, l_pallet_id, r_hdr.spur_loc, 
                                     r_dtl.case_qty * l_spc, r_dtl.case_qty * l_spc, 0, min_qty, cube, lst_cycle_date, lst_cycle_reason, 
                                     abc, abc_gen_date, status, lot_id, weight, temperature, exp_ind, cust_pref_vendor,
                                     case_type_tmu, pallet_height, add_date, add_user, upd_date, upd_user, parent_pallet_id,
                                     dmg_ind,inv_uom
                                FROM inv
                               WHERE logi_loc = r_dtl.pallet_id;
                               
                    /*update qoh by reducing the quality released by Symbotic*/
                    UPDATE inv
                       SET qoh = qoh - (r_dtl.case_qty * l_spc),
                           qty_alloc = qty_alloc - (r_dtl.case_qty * l_spc)
                     WHERE logi_loc = r_dtl.pallet_id;         
                END IF;
                
                /*Get the Priority*/
                BEGIN
                    SELECT  priority
                      INTO  l_priority
                      FROM  matrix_task_priority
                     WHERE matrix_task_type = 'MRL'
                       AND severity = 'NORMAL';                        
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        l_priority := 99;
                END;
    
                FOR r_inv IN c_inv(l_pallet_id)
                LOOP
                    /*Find the first location in the zone of the item*/
                    BEGIN
                        SELECT a.logi_loc 
                          INTO l_frm_loc    
                          FROM loc a , (SELECT MIN(l.put_path) put_path
                                          FROM loc l, lzone lz, pm p
                                         WHERE l.logi_loc = lz.logi_loc
                                           AND p.prod_id = r_dtl.prod_id
                                           AND lz.zone_id = p.zone_id) b
                         WHERE a.put_path = b.put_path
                           AND ROWNUM = 1;
                        
                        l_find_loc := 1;    
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            l_find_loc := 0;    
                            l_dest_loc := l_def_unassign_loc;       
                    END; 
                    
                    /*If find the first location in the zone of the item*/ 
                    IF l_find_loc > 0 THEN
                        l_suggest_loc.DELETE;
                        
                        --Get the suggested reserve location for Unassign 
                        pl_putaway_utilities.p_find_xfr_slots(NULL, l_frm_loc, r_dtl.case_qty, l_num_of_locations,
                                                              l_suggest_loc, l_result);
                        
                        IF l_num_of_locations <= 0 AND l_result != 0 THEN
                            l_dest_loc := l_def_unassign_loc;
                          
                        ELSE
                            IF l_suggest_loc.EXISTS(1) THEN
                                l_dest_loc := l_suggest_loc(1);
                            ELSE
                                l_dest_loc := l_def_unassign_loc;                       
                            END IF;
                        END IF; 
                    END IF;
                    
                    INSERT  INTO replenlst ( task_id, prod_id, cust_pref_vendor, uom, qty, type, 
                                             status, src_loc, pallet_id, 
                                             dest_loc, gen_uid, gen_date, exp_date, route_no, route_batch_no, priority, 
                                             parent_pallet_id, add_date, rec_id, lot_id, mfg_date, s_pikpath, 
                                             orig_pallet_id, case_no, print_lpn, batch_no, mx_batch_no)
                                     VALUES (repl_id_seq.NEXTVAL, r_inv.prod_id, r_inv.cust_pref_vendor, 2, r_dtl.case_qty * l_spc, 'MRL',
                                             'PRE', r_inv.plogi_loc, r_inv.logi_loc , 
                                             l_dest_loc, REPLACE (USER, 'OPS$'), SYSDATE, r_inv.exp_date, NULL, NULL, l_priority,
                                             r_inv.parent_pallet_id, SYSDATE, r_inv.rec_id, r_inv.lot_id, r_inv.mfg_date, r_inv.pik_path,
                                             DECODE (r_inv.plogi_loc, r_inv.logi_loc, NULL, r_inv.logi_loc),
                                             r_dtl.task_id, pl_matrix_common.print_lpn_flag('MRL'), l_batch_no, r_hdr.batch_id); --mx_batch_no_seq.NEXTVAL);
                    
                    l_process_cnt := l_process_cnt + 1;                       
                END LOOP;                   
                
            ELSIF r_hdr.trans_type = 'DSP' THEN   /*Demand Split Home Replenishment*/  
                /*Update the status to NEW, so task available to forklift*/
                UPDATE replenlst
                   SET status = 'NEW',
                       src_loc = r_hdr.spur_loc
                 WHERE task_id = r_dtl.task_id
                   AND type = 'DSP'
                   AND status = 'PND';    

                IF SQL%ROWCOUNT = 0 THEN    
                     l_error_msg := 'sym07_rpln_inv_update: Failed to Update replenlst table status for pallet_id '|| r_dtl.pallet_id;
                     l_error_code:= SUBSTR(SQLERRM,1,100);
                     RAISE validation_exception;
                END IF;     
                
                IF (pl_libswmslm.lmf_forklift_active() = swms.rf.STATUS_NORMAL) THEN
                    BEGIN
                        SELECT labor_batch_no
                          INTO l_lbr_batch_no
                          FROM replenlst
                         WHERE task_id = r_dtl.task_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            l_error_msg := 'sym07_rpln_inv_update: Failed to select labor_batch_no from replenlst (DSP) for task_id '|| r_dtl.task_id;
                            l_error_code:= SUBSTR(SQLERRM,1,100);
                            RAISE validation_exception;
                    END;
                    
                    pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07:Updating batch and trans table (DSP) for labor batch no '|| l_lbr_batch_no,
                               NULL, NULL);
                               
                    UPDATE batch  a
                       SET kvi_from_loc = r_hdr.spur_loc
                     WHERE batch_no = l_lbr_batch_no;   
                     
                     UPDATE trans  a
                       SET src_loc = r_hdr.spur_loc
                     WHERE labor_batch_no = l_lbr_batch_no;   
                END IF;
                
            ELSIF r_hdr.trans_type IN ('NSP', 'UNA', 'IIR') THEN   /*Non-Demand Split Home Replenishment AND Un-assign Replenishment*/
            
                pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07:Checking for the batch in mx_inv_request ',
                               NULL, NULL);
                
                SELECT COUNT(*) 
                  INTO l_cnt_iir
                  FROM mx_inv_request 
                 WHERE batch_no = r_hdr.batch_id;
                
               IF l_cnt_iir > 0 THEN
                
                 pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07:This is a IIR Request Batch Id: '||r_hdr.batch_id,
                               NULL, NULL);
                  BEGIN
                      SELECT i.qoh, p.spc, i.qty_alloc, i.prod_id, i.cust_pref_vendor, i.rec_id, 
                             i.plogi_loc, i.inv_uom, i.mfg_date, i.exp_date, i.status
                        INTO l_qoh, l_spc, l_qty_alloc, l_prod_id, l_cust_pref_vendor, l_rec_id, 
                             l_plogi_loc, l_uom, l_mfg_date, l_exp_date, l_status
                        FROM inv i, pm p
                       WHERE i.logi_loc = r_dtl.pallet_id
                         AND i.prod_id = p.prod_id
                         AND i.cust_pref_vendor = p.cust_pref_vendor;
                      
                      l_pallet_exists := 1;   
                  EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                          l_pallet_exists := 0;
                          /*l_error_msg := 'sym07_rpln_inv_update: Failed to select qoh from inv (NSP-UNA) for pallet_id '|| r_dtl.pallet_id;
                          l_error_code:= SUBSTR(SQLERRM,1,100);
                          RAISE validation_exception;*/
                  END;
                    
                  IF l_pallet_exists = 0 THEN
                    BEGIN
                        SELECT qoh, spc, qty_alloc, prod_id, logi_loc, cust_pref_vendor, rec_id, 
                               plogi_loc, inv_uom, mfg_date, exp_date, status
                          INTO l_qoh, l_spc, l_qty_alloc, l_prod_id, l_lpn, l_cust_pref_vendor, l_rec_id, 
                               l_plogi_loc, l_uom, l_mfg_date, l_exp_date, l_status
                        FROM(
                                  SELECT i.qoh, p.spc, i.qty_alloc, i.prod_id, i.logi_loc , i.cust_pref_vendor, i.rec_id, 
                                         i.plogi_loc, i.inv_uom, i.mfg_date, i.exp_date, i.status                                
                                    FROM inv i, pm p
                                   WHERE i.prod_id = r_dtl.prod_id
                                     AND i.prod_id = p.prod_id
                                     AND i.cust_pref_vendor = p.cust_pref_vendor
                                    ORDER BY i.qoh - i.qty_alloc desc)
                        WHERE ROWNUM = 1;
                    EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                          l_error_msg := 'sym07_rpln_inv_update: Failed to select pallet from inv (UNA-IIR) for prod_id '|| r_dtl.pallet_id;
                          l_error_code:= SUBSTR(SQLERRM,1,100);
                          RAISE validation_exception;
                    END;
                  ELSE
                    l_lpn := r_dtl.pallet_id;
                  END IF;
                  
                   ----------Calculating the Warehouse Id for creating a ADJ transaction-----------   
                        BEGIN
                            SELECT zn.warehouse_id 
                              INTO l_wh_id
                              FROM zone zn, lzone z
                             WHERE zn.zone_id = z.zone_id
                               AND z.logi_loc = l_lpn
                               AND zone_type = 'PUT';
                        EXCEPTION
                            WHEN OTHERS THEN
                                l_wh_id := NULL;
                        END; 
                  
                  IF l_qoh/l_spc = r_dtl.case_qty THEN
                   
                   pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07:Qty Released is equal to the Available qty' ,
                               NULL, NULL);
                   ------Calculating the Length and concatenating the IIR to the pallet ID---------      
                      l_length := LENGTH(l_lpn);
                   
                   pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07:length of the pallet Id'||l_length||'  '||l_lpn,
                               NULL, NULL);
                           
                      IF l_length <= 15 THEN
                          l_pallet_id_new  := 'IIR'||l_lpn;
                      ELSIF l_length = 16 THEN
                          l_pallet_id_new  := 'IIR'||SUBSTR(l_lpn,2);
                      ELSIF l_length = 17 THEN
                          l_pallet_id_new  := 'IIR'||SUBSTR(l_lpn,3);   
                      ELSIF l_length = 18 THEN
                          l_pallet_id_new  := 'IIR'||SUBSTR(l_lpn,4);
                      END IF;
                      
                      pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07:the new pallet Id'||l_pallet_id_new,
                               NULL, NULL);
                      
                      SELECT COUNT(*) 
                        INTO l_cnt_pallet 
                        FROM inv 
                       WHERE logi_loc = l_pallet_id_new;
                      
                      IF l_cnt_pallet > 0 THEN
                      
                       l_pallet_id     :=  pallet_id_seq.NEXTVAL;
                       l_pallet_id_new  := 'IIR'||l_pallet_id;
                       
                       
                        pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07:The new pallet created is not unique so Generated from sequence'||l_pallet_id_new,
                               NULL, NULL);
                      END IF;
                      
                   --------------update INV to new pallet Id and Actual spur location----------------
                   BEGIN
                   
                    UPDATE inv
                       SET logi_loc  = l_pallet_id_new,
                           plogi_loc = r_hdr.spur_loc
                     WHERE logi_loc = l_lpn;
                     
                     pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07:Updated INV',
                               NULL, NULL);
                               
                    BEGIN
                     
                    INSERT INTO trans
                                 (trans_id, trans_type, trans_date,
                                  prod_id, cust_pref_vendor,
                                  rec_id, src_loc, pallet_id,
                                  qty_expected, qty, uom,
                                  reason_code, user_id, upload_time,
                                  mfg_date, exp_date,
                                  old_status, warehouse_id)
                           SELECT TRANS_ID_SEQ.NEXTVAL, 'ADJ', SYSDATE,
                                  l_prod_id, l_cust_pref_vendor,
                                  l_rec_id, l_plogi_loc, l_lpn,
                                  l_qoh, -1 * (r_dtl.case_qty) * l_spc, l_uom,
                                  'SW', USER, NULL,
                                  l_mfg_date, l_exp_date,
                                  l_status, l_wh_id
                               FROM DUAL;
                    
                     INSERT INTO trans
                                 (trans_id, trans_type, trans_date,
                                  prod_id, cust_pref_vendor,
                                  rec_id, src_loc, pallet_id,
                                  qty_expected, qty, uom,
                                  reason_code, user_id, upload_time,
                                  mfg_date, exp_date,
                                  old_status, warehouse_id)
                           SELECT TRANS_ID_SEQ.NEXTVAL, 'ADJ', SYSDATE,
                                  l_prod_id, l_cust_pref_vendor,
                                  l_rec_id, l_plogi_loc, l_pallet_id_new,
                                  l_qoh, r_dtl.case_qty * l_spc, l_uom,
                                  'SW', USER, NULL,
                                  l_mfg_date, l_exp_date,
                                  l_status, l_wh_id
                               FROM DUAL; 
                               
                    EXCEPTION
                     WHEN OTHERS THEN
                       pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07: Failed inserting trans'||r_hdr.batch_id,
                               NULL, NULL);
                    END;           
                                                 
                    UPDATE mx_inv_request
                       SET spur_loc     = r_hdr.spur_loc,
                           status       = 'NEW',
                           sym07_status = 'Y'
                     WHERE batch_no     = r_hdr.batch_id;
                     
                      pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07: UPdated Mx_inv_request for the batchId'||r_hdr.batch_id,
                               NULL, NULL);
                   END;
                        
                  ELSIF l_qoh/l_spc > r_dtl.case_qty THEN
                     ------Calculating the Length and concatenating the IIR to the pallet ID---------      
                      l_length := LENGTH(l_lpn);
                           
                      IF l_length <= 15 THEN
                          l_pallet_id_new  := 'IIR'||l_lpn;
                      ELSIF l_length = 16 THEN
                          l_pallet_id_new  := 'IIR'||SUBSTR(l_lpn,2);
                      ELSIF l_length = 17 THEN
                          l_pallet_id_new  := 'IIR'||SUBSTR(l_lpn,3);   
                      ELSIF l_length = 18 THEN
                          l_pallet_id_new  := 'IIR'||SUBSTR(l_lpn,4);
                      END IF;
                      
                        SELECT COUNT(*) 
                          INTO l_cnt_pallet 
                          FROM inv 
                         WHERE logi_loc = l_pallet_id_new;
                      
                      IF l_cnt_pallet > 0 THEN
                       l_pallet_id     :=  pallet_id_seq.NEXTVAL;
                       l_pallet_id_new  := 'IIR'||l_pallet_id;
                      END IF;
                      
                    --------------update INV to new pallet Id and Actual spur location----------------
                    UPDATE inv
                       SET qoh = qoh - (r_dtl.case_qty * l_spc)
                     WHERE logi_loc = l_lpn; 
                      
                      
                      INSERT INTO inv (prod_id, rec_id, mfg_date, rec_date, exp_date, inv_date, logi_loc, plogi_loc, 
                                     qoh, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason, 
                                     abc, abc_gen_date, status, lot_id, weight, temperature, exp_ind, cust_pref_vendor,
                                     case_type_tmu, pallet_height, add_date, add_user, upd_date, upd_user, parent_pallet_id,
                                     dmg_ind,inv_uom) 
                              SELECT prod_id, rec_id, mfg_date, rec_date, exp_date, inv_date, l_pallet_id_new, r_hdr.spur_loc, 
                                     r_dtl.case_qty * l_spc, 0, 0, min_qty, cube, lst_cycle_date, lst_cycle_reason, 
                                     abc, abc_gen_date, status, lot_id, weight, temperature, exp_ind, cust_pref_vendor,
                                     case_type_tmu, pallet_height, add_date, add_user, upd_date, upd_user, parent_pallet_id,
                                     dmg_ind,inv_uom
                                FROM inv
                               WHERE logi_loc = l_lpn;
                      BEGIN
                      
                               
                      INSERT INTO trans
                                 (trans_id, trans_type, trans_date,
                                  prod_id, cust_pref_vendor,
                                  rec_id, src_loc, pallet_id,
                                  qty_expected, qty, uom,
                                  reason_code, user_id, upload_time,
                                  mfg_date, exp_date,
                                  old_status, warehouse_id)
                           SELECT TRANS_ID_SEQ.NEXTVAL, 'ADJ', SYSDATE,
                                  l_prod_id, l_cust_pref_vendor,
                                  l_rec_id, l_plogi_loc, l_lpn,
                                  l_qoh, -1 * (r_dtl.case_qty) * l_spc, l_uom,
                                  'SW', USER, NULL,
                                  l_mfg_date, l_exp_date,
                                  l_status, l_wh_id
                               FROM DUAL;
                    
                     INSERT INTO trans
                                 (trans_id, trans_type, trans_date,
                                  prod_id, cust_pref_vendor,
                                  rec_id, src_loc, pallet_id,
                                  qty_expected, qty, uom,
                                  reason_code, user_id, upload_time,
                                  mfg_date, exp_date,
                                  old_status, warehouse_id)
                           SELECT TRANS_ID_SEQ.NEXTVAL, 'ADJ', SYSDATE,
                                  l_prod_id, l_cust_pref_vendor,
                                  l_rec_id, l_plogi_loc, l_pallet_id_new,
                                  l_qoh, r_dtl.case_qty * l_spc, l_uom,
                                  'SW', USER, NULL,
                                  l_mfg_date, l_exp_date,
                                  l_status, l_wh_id
                               FROM DUAL;   
                      EXCEPTION
                       WHEN OTHERS THEN
                       pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07: Failed inserting trans'||r_hdr.batch_id,
                               NULL, NULL);
                               
                      END;         
                      
                      UPDATE mx_inv_request
                        SET spur_loc     = r_hdr.spur_loc,
                            status       = 'NEW',
                            sym07_status = 'Y'
                      WHERE batch_no     = r_hdr.batch_id;
                      
                  ELSIF l_qoh/l_spc < r_dtl.case_qty THEN
                      ------Calculating the Length and concatenating the IIR to the pallet ID---------      
                      l_length := LENGTH(l_lpn);
                           
                      IF l_length <= 15 THEN
                          l_pallet_id_new  := 'IIR'||l_lpn;
                      ELSIF l_length = 16 THEN
                          l_pallet_id_new  := 'IIR'||SUBSTR(l_lpn,2);
                      ELSIF l_length = 17 THEN
                          l_pallet_id_new  := 'IIR'||SUBSTR(l_lpn,3);   
                      ELSIF l_length = 18 THEN
                          l_pallet_id_new  := 'IIR'||SUBSTR(l_lpn,4);
                      END IF;
                      
                        SELECT COUNT(*) 
                          INTO l_cnt_pallet 
                          FROM inv 
                         WHERE logi_loc = l_pallet_id_new;
                      
                      IF l_cnt_pallet > 0 THEN
                      
                       l_pallet_id      :=  pallet_id_seq.NEXTVAL;
                       l_pallet_id_new  := 'IIR'||l_pallet_id;
                       
                      END IF;
                      
                       UPDATE inv
                          SET logi_loc  = l_pallet_id_new,
                              plogi_loc = r_hdr.spur_loc,
                              qoh       = (r_dtl.case_qty * l_spc)
                        WHERE logi_loc  = l_lpn;
                        
                        BEGIN
                        
                        INSERT INTO trans
                                 (trans_id, trans_type, trans_date,
                                  prod_id, cust_pref_vendor,
                                  rec_id, src_loc, pallet_id,
                                  qty_expected, qty, uom,
                                  reason_code, user_id, upload_time,
                                  mfg_date, exp_date,
                                  old_status, warehouse_id)
                           SELECT TRANS_ID_SEQ.NEXTVAL, 'ADJ', SYSDATE,
                                  l_prod_id, l_cust_pref_vendor,
                                  l_rec_id, l_plogi_loc, l_lpn,
                                  l_qoh, -1 * (r_dtl.case_qty) * l_spc, l_uom,
                                  'SW', USER, NULL,
                                  l_mfg_date, l_exp_date,
                                  l_status, l_wh_id
                               FROM DUAL;
                    
                     INSERT INTO trans
                                 (trans_id, trans_type, trans_date,
                                  prod_id, cust_pref_vendor,
                                  rec_id, src_loc, pallet_id,
                                  qty_expected, qty, uom,
                                  reason_code, user_id, upload_time,
                                  mfg_date, exp_date,
                                  old_status, warehouse_id)
                           SELECT TRANS_ID_SEQ.NEXTVAL, 'ADJ', SYSDATE,
                                  l_prod_id, l_cust_pref_vendor,
                                  l_rec_id, l_plogi_loc, l_pallet_id_new,
                                  l_qoh, r_dtl.case_qty * l_spc, l_uom,
                                  'SW', USER, NULL,
                                  l_mfg_date, l_exp_date,
                                  l_status, l_wh_id
                               FROM DUAL;
                      EXCEPTION
                      WHEN OTHERS THEN
                       pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07: Failed inserting trans'||r_hdr.batch_id,
                               NULL, NULL);
                       END;        
                     
                      UPDATE mx_inv_request
                         SET spur_loc     = r_hdr.spur_loc,
                             status       = 'NEW',
                             sym07_status = 'Y'
                       WHERE batch_no     = r_hdr.batch_id;
                      
                      l_qty_delete := (r_dtl.case_qty*l_spc)-l_qoh;
                      
                       FOR r_plt IN c_pallet (l_prod_id)
                       LOOP
                         
                        
                         IF r_plt.qoh_avl = l_qty_delete THEN
                         
                            IF r_plt.qty_alloc = 0 THEN
                             DELETE FROM inv
                                   WHERE logi_loc  = r_plt.logi_loc;
                            ELSE
                             UPDATE inv
                                SET qoh = qoh - l_qty_delete
                              WHERE logi_loc  = r_plt.logi_loc;
                            END IF;
                            
                            l_qty_delete := 0;
                          
                         ELSIF r_plt.qoh_avl > l_qty_delete THEN
                          
                           UPDATE inv
                              SET qoh = qoh - l_qty_delete
                            WHERE logi_loc  = r_plt.logi_loc;
                         
                            l_qty_delete := 0;
                         
                         ELSE
                           IF r_plt.qty_alloc = 0 THEN
                              DELETE FROM inv
                                   WHERE logi_loc  = r_plt.logi_loc;
                           ELSE
                           
                             UPDATE inv
                                SET qoh = qoh - r_plt.qoh_avl
                              WHERE logi_loc  = r_plt.logi_loc;
                           END IF;
                          
                          l_qty_delete := l_qty_delete - r_plt.qoh_avl;
                          
                         END IF;
                         
                         EXIT WHEN l_qty_delete = 0; 
                       END LOOP;
                      
                      
                  END IF;
                
                pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07: COMPLETED IIR Trans'||r_hdr.batch_id,
                               NULL, NULL);
            ELSE --Normal UNA and NSP
                
                BEGIN
                    SELECT i.qoh, p.spc, i.qty_alloc
                      INTO l_qoh, l_spc, l_qty_alloc
                      FROM inv i, pm p
                     WHERE i.logi_loc = r_dtl.pallet_id
                       AND i.prod_id = p.prod_id
                       AND i.cust_pref_vendor = p.cust_pref_vendor;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        l_error_msg := 'sym07_rpln_inv_update: Failed to select qoh from inv (NSP-UNA) for pallet_id '|| r_dtl.pallet_id;
                        l_error_code:= SUBSTR(SQLERRM,1,100);
                        RAISE validation_exception;
                END;
                
                IF l_qoh = r_dtl.case_qty * l_spc THEN
                    l_pallet_id := r_dtl.pallet_id;
                    
                    UPDATE inv
                       SET plogi_loc = r_hdr.spur_loc
                     WHERE logi_loc = r_dtl.pallet_id;
                   
                ELSE /*Partial Pallet released*/
                    l_pallet_id := pallet_id_seq.NEXTVAL;
                    
                    INSERT INTO inv (prod_id, rec_id, mfg_date, rec_date, exp_date, inv_date, logi_loc, plogi_loc, 
                                     qoh, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason, 
                                     abc, abc_gen_date, status, lot_id, weight, temperature, exp_ind, cust_pref_vendor,
                                     case_type_tmu, pallet_height, add_date, add_user, upd_date, upd_user, parent_pallet_id,
                                     dmg_ind,inv_uom) 
                              SELECT prod_id, rec_id, mfg_date, rec_date, exp_date, inv_date, l_pallet_id, r_hdr.spur_loc, 
                                     r_dtl.case_qty * l_spc, r_dtl.case_qty * l_spc, 0, min_qty, cube, lst_cycle_date, lst_cycle_reason, 
                                     abc, abc_gen_date, status, lot_id, weight, temperature, exp_ind, cust_pref_vendor,
                                     case_type_tmu, pallet_height, add_date, add_user, upd_date, upd_user, parent_pallet_id,
                                     dmg_ind,inv_uom
                                FROM inv
                               WHERE logi_loc = r_dtl.pallet_id;
                    
                    /*update qoh by reducing the quality released by Symbotic*/
                    UPDATE inv
                       SET qoh = qoh - (r_dtl.case_qty * l_spc),
                           qty_alloc = qty_alloc - (r_dtl.case_qty * l_spc)
                     WHERE logi_loc = r_dtl.pallet_id;                  
                    
                END IF;
                
                /*Update the status to NEW, and actual SPUR location, so task available to forklift*/
                UPDATE replenlst
                   SET status = 'NEW',
                       pallet_id = l_pallet_id,
                       src_loc = r_hdr.spur_loc,
                       qty = r_dtl.case_qty * l_spc
                 WHERE pallet_id = r_dtl.pallet_id
                   AND task_id = r_dtl.task_id
                   AND status = 'PND';
                
                IF (pl_libswmslm.lmf_forklift_active() = swms.rf.STATUS_NORMAL) THEN
                    BEGIN
                        SELECT labor_batch_no
                          INTO l_lbr_batch_no
                          FROM replenlst
                         WHERE task_id = r_dtl.task_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            l_error_msg := 'sym07_rpln_inv_update: Failed to select labor_batch_no from replenlst (NSP-UNA) for task_id '|| r_dtl.task_id;
                            l_error_code:= SUBSTR(SQLERRM,1,100);
                            RAISE validation_exception;
                    END;
                    
                    UPDATE batch  a
                       SET ref_no =  l_pallet_id,
                           kvi_from_loc = r_hdr.spur_loc
                     WHERE batch_no = l_lbr_batch_no;   
                END IF;
                
              END IF;   
                       
            END IF; /*IF r_hdr.trans_type = */
            
        END LOOP;
        
        pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07: Came out of All loops '||r_hdr.batch_id,
                               NULL, NULL);
                               
        IF l_process_cnt > 0 THEN
        
          pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07: The process cnt value is '||l_process_cnt,
                               NULL, NULL);
                               
            FOR rec IN ( SELECT task_id FROM replenlst WHERE batch_no = l_batch_no AND status = 'PRE')
            LOOP
                g_tabTask(rec.task_id) := rec.task_id;
            END LOOP;
            
            pl_swms_execute_sql.commit_ndm_repl (g_tabTask, g_tabTask.count, l_count_commit);
            
            IF (l_count_commit != g_tabTask.count) THEN
                l_error_msg := 'Prog Code: ' || l_fname
                || ' Not all the MRL tasks were committed for batch_no ' || l_batch_no;
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
            END IF;
        END IF; 
        
        
        ------------------Unlocking the Record and Updating to Success------------------      
        BEGIN
            UPDATE matrix_in
               SET record_status = 'S'
             WHERE mx_msg_id     = r_hdr.mx_msg_id
               AND record_status = 'Q';
               
               pl_text_log.ins_msg('INFO', 'pl_mx_stg_to_swms.SYM07',
                              'SYM07: Record is succesfully unlocked '||r_hdr.batch_id,
                               NULL, NULL);
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                l_error_msg := 'sym07_rpln_inv_update: Failed Unlocking the record from Q to S';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
        END;
        
        COMMIT;
        
        Pl_Text_Log.ins_msg ('I', 'pl_mx_stg_to_swms.sym07_rpln_inv_update',
                'sym07_rpln_inv_update - Refeshing SPUR monitor for location ' || r_hdr.spur_loc, NULL, NULL);
        
        pl_matrix_common.refresh_spur_monitor(r_hdr.spur_loc);      
        
        Pl_Text_Log.ins_msg ('I', 'pl_mx_stg_to_swms.sym07_rpln_inv_update',
                'sym07_rpln_inv_update - Refeshing SPUR monitor completed for location ' || r_hdr.spur_loc, NULL, NULL);
        
    END LOOP;
EXCEPTION
    --------------------Any Failure Updating the Status to Failure------------------
    WHEN validation_exception THEN
        ROLLBACK;
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT;
    WHEN OTHERS THEN
        ROLLBACK;
        --------------------Any Failure Updating the Status to Failure------------------  
        l_error_msg    := SUBSTR(SQLERRM,1,100);
        l_error_code   := SUBSTR(SQLCODE,1,100);
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT; 
END sym07_rpln_inv_update;

 /*---------------------------------------------------------------------------
 Procedure:
    sym05_sos_batch_update

 Description:
    This procedure execute when swms receive SYM05 interface to update the sos_batch status
    from pending to Future (ready) and actual spur location.

 Parameter:
      Input:
          i_mx_msg_id               Message ID                     
      
      Return:
          N/A
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    04-DEC-2014  ayad5195 Initial Creation.
    28-OCT-2015  sunil ontipalli  Modified to update the float detail with the actual spur when SWMS get a late message from Symbotic.
    27-JUL-2016  P. Kabran - Added add_date and sequence_number to cursor to populate corresponding sos_batch columns.
---------------------------------------------------------------------------*/ 
PROCEDURE sym05_sos_batch_update( i_mx_msg_id IN NUMBER DEFAULT NULL)
IS
    CURSOR c_sys05 IS
        SELECT batch_id, spur_loc, mx_msg_id, sequence_timestamp, add_date, sequence_number
          FROM matrix_in
         WHERE mx_msg_id = NVL(i_mx_msg_id, mx_msg_id)
           AND interface_ref_doc = 'SYM05'
           AND record_status = 'N'
           AND rec_ind = 'S';
    
    l_mx_msg_id             swms.matrix_in.mx_msg_id%TYPE;
    validation_exception    EXCEPTION;
    l_error_msg             VARCHAR2(100);
    l_error_code            VARCHAR2(100);
    l_cnt_float_detail      NUMBER;
    l_sos_status            sos_batch.status%TYPE;
    l_sos_user              sos_batch.picked_by%TYPE;
    l_fd_src_loc            float_detail.src_loc%TYPE;
      l_fd_cnt                NUMBER;
BEGIN   
    
    FOR r_sym05 IN c_sys05
    LOOP        
        l_mx_msg_id := r_sym05.mx_msg_id;
        BEGIN
            UPDATE matrix_in
               SET record_status = 'Q'
             WHERE mx_msg_id = r_sym05.mx_msg_id;
               
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                l_error_msg := 'sym05_sos_batch_update: Failed Updating the Record Status to Q';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
        END;
        
        IF SUBSTR(r_sym05.batch_id, 1, 1) != 'S' THEN
        
            SELECT COUNT(*)
              INTO l_cnt_float_detail
              FROM float_detail fd
             WHERE float_no IN (SELECT float_no FROM floats WHERE batch_no = r_sym05.batch_id)
               AND EXISTS (SELECT 1 FROM loc l
                            WHERE l.logi_loc = fd.src_loc
                              AND l.slot_type IN ('MXF','MXC','MXS'));   
                              
            BEGIN
                    SELECT src_loc
                      INTO l_fd_src_loc
                      FROM float_detail fd, loc l
                     WHERE fd.float_no IN (SELECT float_no from floats where batch_no = r_sym05.batch_id)
                       AND fd.src_loc = l.logi_loc
                       AND ROWNUM = 1;     
            EXCEPTION
             WHEN OTHERS THEN
              l_fd_src_loc := NULL; 
            END;    
            
            /*Update the actual SPUR location*/
            UPDATE float_detail fd
               SET src_loc = r_sym05.spur_loc
             WHERE float_no IN (SELECT float_no FROM floats WHERE batch_no = r_sym05.batch_id)
               AND EXISTS (SELECT 1 FROM loc l
                            WHERE l.logi_loc = fd.src_loc
                              AND l.slot_type IN ('MXF','MXC', 'MXS'));
               
            UPDATE float_hist fh
               SET src_loc = r_sym05.spur_loc
             WHERE batch_no = r_sym05.batch_id
               AND EXISTS (SELECT 1 FROM loc l
                            WHERE l.logi_loc = fh.src_loc
                              AND l.slot_type IN ('MXF','MXC', 'MXS'));
                              
        ELSE
            SELECT COUNT(*)
              INTO l_cnt_float_detail
              FROM sos_short_detail ssd
             WHERE EXISTS (SELECT 1 FROM loc l
                            WHERE l.logi_loc = ssd.pick_location
                              AND l.slot_type IN ('MXF','MXC','MXS'))
               AND EXISTS (SELECT 1 FROM sos_short ss
                            WHERE ss.batch_no = ssd.batch_no
                              AND ss.orderseq = ssd.orderseq
                              AND ss.picktype = ssd.picktype
                              AND ss.short_batch_no = r_sym05.batch_id);    
                              
            UPDATE sos_short_detail ssd
               SET pick_location = r_sym05.spur_loc
             WHERE EXISTS (SELECT 1 FROM loc l
                            WHERE l.logi_loc = ssd.pick_location
                              AND l.slot_type IN ('MXF','MXC', 'MXS'))
               AND EXISTS (SELECT 1 FROM sos_short ss
                            WHERE ss.batch_no = ssd.batch_no
                              AND ss.orderseq = ssd.orderseq
                              AND ss.picktype = ssd.picktype
                              AND ss.short_batch_no = r_sym05.batch_id);
             
            /*UPDATE sos_short
               SET spur_location = r_sym05.spur_loc
             WHERE short_batch_no =  r_sym05.batch_id;*/
        END IF;
        /*UPDATE mx_float_detail_cases
          SET spur_location = r_sym05.spur_loc
        WHERE float_no IN (SELECT float_no FROM floats WHERE batch_no = r_sym05.batch_id);*/
        
        SELECT status
          INTO l_sos_status
          FROM sos_batch
         WHERE batch_no = r_sym05.batch_id;
         
         IF l_sos_status = 'X' THEN
            /*Release the sos batch for selector*/
            UPDATE sos_batch
              SET status = 'F', sym05_add_date = r_sym05.add_date, sym05_sequence_number = r_sym05.sequence_number
            WHERE batch_no = r_sym05.batch_id
              AND status = 'X';
         ELSE
            /*If batch already released and SPUR location is changed then send message to user for correct SPUR location*/
            SELECT COUNT(*)
              INTO l_fd_cnt
              FROM float_detail fd, loc l
             WHERE fd.float_no IN (SELECT float_no from floats where batch_no = r_sym05.batch_id)
               AND fd.src_loc = l.logi_loc
               AND l.slot_type IN ('MXS');
               
            /*if batch has Symbotic pick*/   
            IF  l_fd_cnt > 0 THEN
                BEGIN
                    
                    SELECT picked_by
                      INTO l_sos_user
                      FROM sos_batch
                     WHERE batch_no = r_sym05.batch_id;
                     
                    /*If SPUR location changed*/
                    IF  l_fd_src_loc != r_sym05.spur_loc AND l_sos_user IS NOT NULL THEN
                        rf.SendUserMsg('For Batch '||r_sym05.batch_id || ' Symbotic SPUR location has been changed from '||l_fd_src_loc||' to ' || r_sym05.spur_loc,l_sos_user);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        Pl_Text_Log.ins_msg ('I', 'pl_mx_stg_to_swms.sym05_sos_batch_update',
                                    'sym05_sos_batch_update - Failed to get source location from _detail for batch ' || r_sym05.batch_id, NULL, NULL);
                END;               
            END IF;
         END IF;
        
        --Insert into mx_batch_info if float_detail have Symbotic pick
        IF  l_cnt_float_detail > 0 AND r_sym05.spur_loc NOT LIKE 'SP%J%' THEN
            /*Insert into mx_batch_info for baggage claim */    
            INSERT INTO mx_batch_info (sequence_number, batch_no, batch_type, replen_type,
                                       status, spur_location, sequence_timestamp)
                               VALUES (mx_batch_info_seq.NEXTVAL, r_sym05.batch_id, 'O', NULL,
                                       'AVL', r_sym05.spur_loc,  r_sym05.sequence_timestamp );         
        END IF;
        ------------------Unlocking the Record and Updating to Success------------------      
        BEGIN
            UPDATE matrix_in
               SET record_status = 'S'
             WHERE mx_msg_id     = r_sym05.mx_msg_id
               AND record_status = 'Q';
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                l_error_msg := 'sym05_sos_batch_update: Failed Unlocking the record from Q to S';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
        END;
        
        COMMIT;
        
        Pl_Text_Log.ins_msg ('I', 'pl_mx_stg_to_swms.sym05_sos_batch_update',
                'sym05_sos_batch_update - Refeshing SPUR monitor for location ' || r_sym05.spur_loc, NULL, NULL);
        
        pl_matrix_common.refresh_spur_monitor(r_sym05.spur_loc);    
    END LOOP;
EXCEPTION
    --------------------Any Failure Updating the Status to Failure------------------
    WHEN validation_exception THEN
        ROLLBACK;
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT;

    WHEN OTHERS THEN
        ROLLBACK;
        --------------------Any Failure Updating the Status to Failure------------------  
        l_error_msg    := SUBSTR(SQLERRM,1,100);
        l_error_code   := SUBSTR(SQLCODE,1,100);
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT;     
END sym05_sos_batch_update;


 /*---------------------------------------------------------------------------
 Procedure:
    sym12_case_div_update

 Description:
    This procedure execute when swms receive SYM12 interface, when case is diverted to SPUR
    to update the status and time stamp in table mx_float_detail_cases.

 Parameter:
      Input:
          i_mx_msg_id               Message ID                     
      
      Return:
          N/A
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    05-DEC-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/ 
PROCEDURE sym12_case_div_update( i_mx_msg_id IN NUMBER DEFAULT NULL)
IS
    CURSOR c_sys12 IS
        SELECT batch_id, task_id, prod_id, pallet_id, spur_loc, 
               mx_msg_id, case_barcode, divert_time, lane_id
          FROM matrix_in
         WHERE mx_msg_id = NVL(i_mx_msg_id, mx_msg_id)
           AND interface_ref_doc = 'SYM12'
           AND record_status = 'N'
           AND rec_ind = 'S';
    
    l_mx_msg_id             swms.matrix_in.mx_msg_id%TYPE;
    validation_exception    EXCEPTION;
    l_error_msg             VARCHAR2(100);
    l_error_code            VARCHAR2(100);
    l_chk_order             NUMBER;
    l_cnt                   NUMBER;
    l_spur_location         mx_batch_info.spur_location%TYPE;
    l_batch_type            VARCHAR2(3);
    l_user_id               VARCHAR2(30);
    l_item_descrip          VARCHAR2(30);
    l_truck_no              VARCHAR2(10);
BEGIN   
    
    FOR r_sym12 IN c_sys12
    LOOP        
        l_mx_msg_id := r_sym12.mx_msg_id;
        
        BEGIN
            UPDATE matrix_in
               SET record_status = 'Q'
             WHERE mx_msg_id = r_sym12.mx_msg_id;
               
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                l_error_msg := 'sym12_case_div_update: Failed Updating the Record Status to Q';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
        END;
        
        SELECT COUNT(*)
          INTO l_chk_order
          FROM mx_float_detail_cases
         WHERE case_id = r_sym12.case_barcode;
    
        IF l_chk_order > 0  THEN         /*AND r_sym12.task_id IS NULL*/
            UPDATE mx_float_detail_cases
              SET spur_location = r_sym12.spur_loc,
                  case_divert_timestamp = r_sym12.divert_time,
                  status = DECODE(status, 'PIK', status, 'SHT', status, 'DIV'),
                  lane_id = r_sym12.lane_id
            WHERE case_id = r_sym12.case_barcode;
        ELSE
            INSERT INTO mx_replenlst_cases (batch_no, task_id, case_id, 
                                            prod_id, pallet_id, spur_location, 
                                            lane_id, case_divert_timestamp, status, case_skip_flag)
                                    VALUES (r_sym12.batch_id, r_sym12.task_id, r_sym12.case_barcode, 
                                            r_sym12.prod_id, r_sym12.pallet_id, r_sym12.spur_loc, 
                                            r_sym12.lane_id, r_sym12.divert_time, 'DIV', 'N');     
        END IF;
        
        ------------------Unlocking the Record and Updating to Success------------------      
        BEGIN
            UPDATE matrix_in
               SET record_status = 'S'
             WHERE mx_msg_id     = r_sym12.mx_msg_id
               AND record_status = 'Q';
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                l_error_msg := 'sym12_case_div_update: Failed Unlocking the record from Q to S';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
        END;
     -------------------Updating on-hold Cases in matrix_out table---------------------
        BEGIN
         Update matrix_out
          SET record_status = 'N'
          WHERE interface_ref_doc = 'SYS06'
          AND record_status = 'H'
          AND rec_ind = 'S'
          AND batch_id= r_sym12.batch_id
          AND case_barcode = r_sym12.case_barcode
          AND prod_id = r_sym12.prod_id;
        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := 'Error: Updating the Record status to H';
            l_error_code:= SUBSTR(SQLERRM,1,100);
            RAISE validation_exception;
       END;
     -------------------Updating on-hold Cases in matrix_out table---------------------
        COMMIT;
        
        BEGIN
            /*Find the actual spur location if case diverted to Jackpot*/
            IF r_sym12.spur_loc LIKE 'SP%J%' THEN       
                
                BEGIN
                    SELECT COUNT(*)
                      INTO l_cnt
                      FROM mx_float_detail_cases
                     WHERE case_id = r_sym12.case_barcode;
                       
                    IF l_cnt > 0 THEN  
                        BEGIN
                            SELECT spur_location
                              INTO l_spur_location
                              FROM mx_batch_info
                             WHERE batch_no =  r_sym12.batch_id
                               AND batch_type = 'O';
                        EXCEPTION
                            WHEN OTHERS THEN
                                Pl_Text_Log.ins_msg ('I', 'pl_mx_stg_to_swms.sym12_case_div_update',
                                            'sym12_case_div_update 1- Not able to select from mx_batch_info for SOS batch ' || r_sym12.batch_id, SQLCODE, SQLERRM);
                                l_spur_location := NULL;            
                        END;
                        
                        BEGIN
                        SELECT f.truck_no, b.picked_by, p.descrip
                          INTO l_truck_no, l_user_id, l_item_descrip
                          FROM float_detail fd, floats f, sos_batch b, pm p
                         WHERE fd.order_seq = SUBSTR(r_sym12.case_barcode, 1, LENGTH(r_sym12.case_barcode)-3)
                           AND f.float_no = fd.float_no
                           AND p.prod_id = fd.prod_id
                           AND p.cust_pref_vendor = fd.cust_pref_vendor
                           AND TO_CHAR(f.batch_no)= b.batch_no
                           AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS THEN
                                l_truck_no := NULL;
                                l_user_id := NULL;
                                l_item_descrip := NULL;
                        END;
                        
                        l_batch_type := 'SOS';   
                    ELSE    
                        BEGIN
                            SELECT spur_location
                              INTO l_spur_location
                              FROM mx_batch_info
                             WHERE batch_no =  r_sym12.batch_id
                               AND batch_type = 'R';
                        EXCEPTION
                            WHEN OTHERS THEN
                                Pl_Text_Log.ins_msg ('I', 'pl_mx_stg_to_swms.sym12_case_div_update',
                                            'sym12_case_div_update 1- Not able to select from mx_batch_info for Replen batch ' || r_sym12.batch_id, SQLCODE, SQLERRM);
                                l_spur_location := NULL;                
                        END;
                        
                        BEGIN
                            SELECT r.type, r.user_id, p.descrip
                              INTO l_batch_type, l_user_id, l_item_descrip
                              FROM replenlst r, pm p
                             WHERE r.prod_id = p.prod_id 
                               AND r.cust_pref_vendor = p.cust_pref_vendor
                               AND mx_batch_no = r_sym12.batch_id 
                               AND ROWNUM = 1;      
                        EXCEPTION
                            WHEN OTHERS THEN
                                l_batch_type := 'RPL';
                                l_user_id := NULL;
                        END; 
                    END IF;
                    
                    Pl_Text_Log.ins_msg ('I', 'pl_mx_stg_to_swms.sym12_case_div_update',
                    'sym12_case_div_update 1- Refeshing SPUR monitor for location ' || l_spur_location, NULL, NULL);
                    
                    IF l_spur_location IS NOT NULL AND l_spur_location NOT LIKE 'SP%J%' THEN
                        BEGIN
                            pl_matrix_common.refresh_spur_monitor(l_spur_location);
                        EXCEPTION
                            WHEN OTHERS THEN
                                --ROLLBACK;
                                --l_error_msg := 'sym12_case_div_update: Unable to refresh SPUR monitor';
                                --l_error_code:= SUBSTR(SQLERRM,1,100);
                                --RAISE validation_exception;
                                Pl_Text_Log.ins_msg ('FATAL', 'pl_mx_stg_to_swms.sym12_case_div_update', 'Failed to refresh SPUR monitor for batch '||r_sym12.batch_id, SQLCODE, SQLERRM);
                        END;
                    END IF; 
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        Pl_Text_Log.ins_msg ('FATAL', 'pl_mx_stg_to_swms.sym12_case_div_update', 'Failed to refresh SPUR monitor, unable to find SPUR location of batch '||r_sym12.batch_id, SQLCODE, SQLERRM);
                END;  
                
                
                INSERT INTO digisign_jackpot_monitor (location, divert_time, truck_no, user_id, batch_no, batch_type, 
                                                      spur_location, case_barcode, item_desc, add_date, add_user)
                                              VALUES (r_sym12.spur_loc, SYSDATE, l_truck_no, l_user_id, r_sym12.batch_id, l_batch_type,
                                                      l_spur_location,  r_sym12.case_barcode,  l_item_descrip, SYSDATE, REPLACE(USER, 'OPS$') );
                COMMIT;
                
                DECLARE
                    l_result        NUMBER;
                    l_msg_text      VARCHAR2(512);
                    l_err_msg       VARCHAR2(32767);
                BEGIN          
                    BEGIN
                        l_result:= pl_digisign.BroadcastJackpotUpdate (r_sym12.spur_loc, l_err_msg);
                    EXCEPTION   
                        WHEN OTHERS THEN
                            --ROLLBACK;
                            --l_error_msg := 'sym12_case_div_update: Unable to refresh Jackpot monitor ';
                            --l_error_code:= SUBSTR(SQLERRM,1,100);
                            --RAISE validation_exception;
                            Pl_Text_Log.ins_msg ('FATAL', 'pl_mx_stg_to_swms.sym12_case_div_update', 'Failed to refresh Jackpot monitor for Case_id '||r_sym12.case_barcode, SQLCODE, SQLERRM);
                    END;
                    
                    IF l_result != 0 THEN
                        l_msg_text := 'Error calling pl_digisign.BroadcastJackpotUpdate from pl_mx_stg_to_swms.sym12_case_div_update';
                        Pl_Text_Log.ins_msg ('FATAL', 'pl_mx_stg_to_swms.sym12_case_div_update', l_msg_text, NULL, l_err_msg);
                    END IF;                               
                END;
            ELSE
                Pl_Text_Log.ins_msg ('I', 'pl_mx_stg_to_swms.sym12_case_div_update',
                    'sym12_case_div_update 2- Refeshing SPUR monitor for location ' || r_sym12.spur_loc, NULL, NULL);
                BEGIN   
                    pl_matrix_common.refresh_spur_monitor(r_sym12.spur_loc);
                EXCEPTION
                    WHEN OTHERS THEN
                        ROLLBACK;
                        l_error_msg := 'sym12_case_div_update: Unable to refresh SPUR monitor in ELSE';
                        l_error_code:= SUBSTR(SQLERRM,1,100);
                        RAISE validation_exception;
                END;
            END IF;        
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                l_error_msg := 'sym12_case_div_update: Failed to process record';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
        END;
    END LOOP;
EXCEPTION
    --------------------Any Failure Updating the Status to Failure------------------
    WHEN validation_exception THEN
        ROLLBACK;
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT;

    WHEN OTHERS THEN
        ROLLBACK;
        --------------------Any Failure Updating the Status to Failure------------------  
        l_error_msg    := SUBSTR(SQLERRM,1,100);
        l_error_code   := SUBSTR(SQLCODE,1,100);
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT;     
END sym12_case_div_update;


 /*---------------------------------------------------------------------------
 Procedure:
    sym06_case_skipped_update

 Description:
    This procedure execute when swms receive SYM06 interface when a case is skipped
    by Symbotic to update the skipped flag and skipped type in table mx_float_detail_cases.

 Parameter:
      Input:
          i_mx_msg_id               Message ID                     
      
      Return:
          N/A
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    09-DEC-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/ 
PROCEDURE sym06_case_skipped_update( i_mx_msg_id IN NUMBER DEFAULT NULL)
IS
    CURSOR c_sys06 IS
        SELECT batch_id, case_barcode, prod_id, skip_reason, mx_msg_id
          FROM matrix_in
         WHERE mx_msg_id = NVL(i_mx_msg_id, mx_msg_id)
           AND interface_ref_doc = 'SYM06'
           AND record_status = 'N'
           AND rec_ind = 'S';
    
    l_mx_msg_id             swms.matrix_in.mx_msg_id%TYPE;
    validation_exception    EXCEPTION;
    l_error_msg             VARCHAR2(100);
    l_error_code            VARCHAR2(100);
    l_chk_order             NUMBER;
    l_spur_location         mx_batch_info.spur_location%TYPE;
    l_cnt_replenlst         NUMBER;
    l_cnt_order             NUMBER;
    l_task_id               replenlst.task_id%TYPE;
    l_pallet_id             replenlst.pallet_id%TYPE;
BEGIN   
    
    FOR r_sym06 IN c_sys06
    LOOP        
        l_mx_msg_id := r_sym06.mx_msg_id;
        
        BEGIN
            UPDATE matrix_in
               SET record_status = 'Q'
             WHERE mx_msg_id = r_sym06.mx_msg_id;
               
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                l_error_msg := 'sym06_case_skipped_update: Failed Updating the Record Status to Q';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
        END;
        
        Pl_Text_Log.ins_msg ('I', 'pl_mx_stg_to_swms.sym06_case_skipped_update', 'Processing Case Skip message SYM06 for Case_id [' ||r_sym06.case_barcode||']', NULL, NULL);
        
        SELECT COUNT(*)
          INTO l_cnt_order
          FROM mx_float_detail_cases
         WHERE case_id = r_sym06.case_barcode;
         
        IF  l_cnt_order > 0 THEN
            Pl_Text_Log.ins_msg ('I', 'pl_mx_stg_to_swms.sym06_case_skipped_update', 'Case Skip message SYM06 for Order for Case_id [' ||r_sym06.case_barcode||']', NULL, NULL);
            /*Update Skipped flag and skipped reason*/  
            UPDATE mx_float_detail_cases
               SET case_skip_flag = 'Y',
                   case_skip_reason = r_sym06.skip_reason              
             WHERE case_id = r_sym06.case_barcode;
        ELSE
            Pl_Text_Log.ins_msg ('I', 'pl_mx_stg_to_swms.sym06_case_skipped_update', 'Case Skip message SYM06 checking for replenishment for batch_no [' ||r_sym06.batch_id||']', NULL, NULL);
            SELECT COUNT(*)
              INTO l_cnt_replenlst
              FROM replenlst
             WHERE mx_batch_no = r_sym06.batch_id;
             
            IF l_cnt_replenlst > 0 THEN 
            
                SELECT task_id, pallet_id
                  INTO l_task_id, l_pallet_id 
                  FROM replenlst
                 WHERE mx_batch_no = r_sym06.batch_id
                   AND ROWNUM = 1;
                
                Pl_Text_Log.ins_msg ('I', 'pl_mx_stg_to_swms.sym06_case_skipped_update', 'Case Skip message SYM06 for replenishment for Case_id [' ||r_sym06.case_barcode||']', NULL, NULL);
                INSERT INTO mx_replenlst_cases (batch_no, task_id, case_id, 
                                                prod_id, pallet_id, spur_location, 
                                                lane_id, case_divert_timestamp, status, 
                                                case_skip_flag, CASE_SKIP_REASON)
                                        VALUES (r_sym06.batch_id, l_task_id, r_sym06.case_barcode, 
                                                r_sym06.prod_id, l_pallet_id, NULL, 
                                                NULL, NULL, 'NEW', 
                                                'Y', r_sym06.skip_reason);
            END IF;
        END IF;
        
        ------------------Unlocking the Record and Updating to Success------------------      
        BEGIN
            UPDATE matrix_in
               SET record_status = 'S'
             WHERE mx_msg_id     = r_sym06.mx_msg_id
               AND record_status = 'Q';
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                l_error_msg := 'sym06_case_skipped_update: Failed Unlocking the record from Q to S';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
        END;
        
        COMMIT;
        
        Pl_Text_Log.ins_msg ('I', 'pl_mx_stg_to_swms.sym06_case_skipped_update',
                    'sym06_case_skipped_update - Before Refeshing SPUR monitor ', NULL, NULL);
        BEGIN   
            SELECT spur_location
              INTO l_spur_location
              FROM mx_batch_info
             WHERE batch_no = r_sym06.batch_id
               AND status = 'AVL'
               AND ROWNUM = 1;
            
            Pl_Text_Log.ins_msg ('I', 'pl_mx_stg_to_swms.sym06_case_skipped_update',
                    'sym06_case_skipped_update - Refeshing SPUR monitor for location ' || l_spur_location, NULL, NULL);
                    
            IF  l_spur_location NOT LIKE 'SP%J%' THEN
                pl_matrix_common.refresh_spur_monitor(l_spur_location);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN                                
                Pl_Text_Log.ins_msg ('FATAL', 'pl_mx_stg_to_swms.sym06_case_skipped_update',
                    'sym06_case_skipped_update - Refeshing SPUR monitor Failed for location ' || l_spur_location, SQLCODE, SQLERRM);
        END;
    END LOOP;
EXCEPTION
    --------------------Any Failure Updating the Status to Failure------------------
    WHEN validation_exception THEN
        ROLLBACK;
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT;

    WHEN OTHERS THEN
        ROLLBACK;
        --------------------Any Failure Updating the Status to Failure------------------  
        l_error_msg    := SUBSTR(SQLERRM,1,100);
        l_error_code   := SUBSTR(SQLCODE,1,100);
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT;     
END sym06_case_skipped_update;


PROCEDURE sym15_bulk_inv_insert(
    i_mx_msg_id IN NUMBER DEFAULT NULL)
    /*===========================================================================================================
    -- Procedure
    -- sym15_bulk_inv_insert
    --
    -- Description
    --   This Procedure reads the data from the file in /swms/data/Symbotic and inserts the data into 
    --   matrix_inv_bulk_in.
    --   This procedure also moves the file from /swms/data/Symbotic to /swms/data/Symbotic/archive
    --
    -- Modification History
    --
    -- Date                User                  Version            Defect  Comment
    -- 12/23/14        Sunil Ontipalli             1.0              Initial Creation
    ============================================================================================================*/
    IS
    ------------------------------local variables-----------------------------------
    l_mx_msg_id              swms.matrix_in.mx_msg_id%TYPE;
    l_interface_ref_doc      swms.matrix_in.interface_ref_doc%TYPE;
    l_record_status          swms.matrix_in.record_status%TYPE;
    l_file                   UTL_FILE.FILE_TYPE;
    l_file_name              VARCHAR2(100);
    l_row_count              NUMBER;
    l_prod_id                swms.matrix_inv_bulk_in.prod_id%TYPE;
    l_pallet_id              swms.matrix_inv_bulk_in.pallet_id%TYPE; 
    l_case_quantity          swms.matrix_inv_bulk_in.case_quantity%TYPE;
    l_inv_status             swms.matrix_inv_bulk_in.inv_status%TYPE;
    l_product_date           swms.matrix_inv_bulk_in.product_date%TYPE;
    l_qty_suspect            swms.matrix_inv_bulk_in.qty_suspect%TYPE;
    l_file_cont              VARCHAR2(32767);
    l_error_msg              VARCHAR2(100);
    l_error_code             VARCHAR2(100);
    validation_exception     EXCEPTION;
    l_result                 NUMBER;
    
    CURSOR c_mx_msg_id IS
        SELECT DISTINCT(mx_msg_id)
          FROM matrix_in
         WHERE interface_ref_doc = 'SYM15'
           AND record_status     = 'N'
           AND (add_date   <  systimestamp - 2/(24*60) OR i_mx_msg_id IS NOT NULL)
           AND mx_msg_id = NVL(i_mx_msg_id, mx_msg_id); 
       
BEGIN
    FOR i IN c_mx_msg_id
    LOOP
        -----------------------Initializing the local variables-------------------------
        l_mx_msg_id := i.mx_msg_id;
        ----------------------------Getting the Record status---------------------------  
        BEGIN
            SELECT DISTINCT(record_status)
              INTO l_record_status
              FROM matrix_in
             WHERE mx_msg_id = l_mx_msg_id;
        EXCEPTION
            WHEN OTHERS THEN
                l_error_msg := 'Failed Getting the Record Status, This is a Duplicate MSG';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
        END;
        
        ------------Checking Whether the Status is 'N' and Locking the Record-----------  
        IF UPPER(l_record_status) = 'N' THEN
            BEGIN
                UPDATE matrix_in
                   SET record_status = 'Q'
                 WHERE mx_msg_id = l_mx_msg_id;
                   
                COMMIT;
            EXCEPTION
                WHEN OTHERS THEN
                    ROLLBACK;
                    l_error_msg := 'Failed Updating the Record Status to Q';
                    l_error_code:= SUBSTR(SQLERRM,1,100);
                    RAISE validation_exception;
            END;
        
        ------------Getting the file name and row count values from staging table------------
            BEGIN
                 SELECT file_name, row_count
                   INTO l_file_name, l_row_count
                   FROM matrix_in
                  WHERE mx_msg_id = l_mx_msg_id;
            EXCEPTION
            WHEN OTHERS THEN
                l_error_msg := 'Failed Getting the file name and rowcount';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
            END;
        
        ---------------------------Getting the Actual File Name-----------------------------
        
            BEGIN
                 SELECT SUBSTR(l_file_name , INSTR(l_file_name , '/', -1)+1)
                   INTO l_file_name
                   FROM dual;
            EXCEPTION
            WHEN OTHERS THEN
                l_error_msg := 'Failed Getting the Actual Name of the File';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
            END;
        
        
        ------------Performing File Operation and inserting records in the table------------
        
          l_file := UTL_FILE.FOPEN('SYMBOTIC',l_file_name,'R'); 
    
           LOOP
  
               BEGIN
               
                  UTL_FILE.GET_LINE(l_file,l_file_cont,32767); 
                  
                  
                IF l_file_cont IS NULL THEN
                   EXIT;
                END IF;
                    
                  l_prod_id        := TRIM(SUBSTR(l_file_cont, 1, 9));
                  l_pallet_id      := TRIM(SUBSTR(l_file_cont, 10, 18));
                  l_case_quantity  := TO_NUMBER(SUBSTR(l_file_cont, 28, 10));
                  l_qty_suspect    := TO_NUMBER(SUBSTR(l_file_cont, 38, 10));
                  l_inv_status     := SUBSTR(l_file_cont, 48, 3);
                  l_product_date   := SUBSTR(l_file_cont, 51, 10);             
                  
                  INSERT 
                    INTO matrix_inv_bulk_in(mx_msg_id, prod_id, pallet_id, case_quantity, qty_suspect,
                                            inv_status, product_date, rec_ind)
                  VALUES (l_mx_msg_id, l_prod_id, l_pallet_id, l_case_quantity, l_qty_suspect,
                          l_inv_status, l_product_date, 'S');
                                                   
               EXCEPTION 
                 WHEN UTL_FILE.INVALID_OPERATION THEN
                   ROLLBACK;
                   dbms_output.put_line('Sql error utl '||SQLERRM);
                   UTL_FILE.FCLOSE(l_file);
                    l_error_msg := 'Invalid File Operation';
                    l_error_code:= SUBSTR(SQLERRM,1,100);
                    RAISE validation_exception;
                 WHEN NO_DATA_FOUND THEN
                 EXIT;   
                 WHEN OTHERS THEN
                   ROLLBACK;
                   dbms_output.put_line('Sql error '||SQLERRM);
                   UTL_FILE.FCLOSE(l_file);
                   l_error_msg := 'Unknown Error: See Error Code';
                   l_error_code:= SUBSTR(SQLERRM,1,100);
                   RAISE validation_exception;
               END;
 
           END LOOP;
        --------------Closing the file, Archiving the file, Removing the file----------------
          UTL_FILE.FCLOSE(l_file); 
 
          UTL_FILE.Fcopy ('SYMBOTIC',l_file_name, 'ARCHIVE', l_file_name);

          UTL_FILE.fremove('SYMBOTIC',l_file_name);
          
          l_result := pl_mx_inv_sync.mx_inv_sync(l_mx_msg_id);
          
          IF l_result = 1 THEN
            l_error_msg := 'Faile to process Inventory Sync';
            l_error_code:= '-20001';
            RAISE validation_exception;
          END IF;
                     
            ------------------Unlocking the Record and Updating to Success------------------      
            BEGIN
                UPDATE matrix_in
                   SET record_status = 'S'
                 WHERE mx_msg_id     = l_mx_msg_id
                   AND record_status = 'Q';
            EXCEPTION
                WHEN OTHERS THEN
                    ROLLBACK;
                    l_error_msg := 'Failed Unlocking the record from Q to S';
                    l_error_code:= SUBSTR(SQLERRM,1,100);
                    RAISE validation_exception;
            END; 
            COMMIT;
        END IF;    
    END LOOP; 
 
EXCEPTION
    --------------------Any Failure Updating the Status to Failure------------------  
     WHEN UTL_FILE.INVALID_OPERATION THEN
         ROLLBACK;
         UTL_FILE.FCLOSE(l_file);
         UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT;         
     
     --------------------Any Failure Updating the Status to Failure------------------              
    WHEN validation_exception THEN
        ROLLBACK;
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT;
        
     --------------------Any Failure Updating the Status to Failure------------------
    WHEN OTHERS THEN
        ROLLBACK;  
        l_error_msg    := SUBSTR(SQLERRM,1,100);
        l_error_code   := SUBSTR(SQLCODE,1,100);
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT;
END sym15_bulk_inv_insert;


PROCEDURE sym16_case_skip_update(i_mx_msg_id IN NUMBER DEFAULT NULL)
    /*===========================================================================================================
    -- Procedure
    -- sym16_case_skip_update
    --
    -- Description
    --   This Procedure process order response and update the mx_float_detail_cases table for   
    --   skip cases for which Symbotic is not able to allocate inventory.    
    --
    -- Modification History
    --
    -- Date                User                  Version            Defect  Comment
    -- 03/27/15         Abhishek Yadav            1.0              Initial Creation
    ============================================================================================================*/
    IS
    ------------------------------local variables-----------------------------------
    l_mx_msg_id              swms.matrix_in.mx_msg_id%TYPE;   
    l_error_msg              VARCHAR2(100);
    l_error_code             VARCHAR2(100);
    validation_exception     EXCEPTION;
    l_record_status          swms.matrix_in.record_status%TYPE;
    l_cnt_sos                NUMBER;
    l_cnt_replenlst          NUMBER;
    l_type                   replenlst.type%TYPE;
    l_pallet_id              replenlst.pallet_id%TYPE;
    l_cnt_iir                NUMBER;
    l_case_requested         NUMBER;
    
    CURSOR c_mx_msg_id IS
        SELECT mx_msg_id, batch_id
          FROM matrix_in
         WHERE interface_ref_doc = 'SYM16'
           AND rec_ind = 'H'           
           AND mx_msg_id = NVL(i_mx_msg_id, mx_msg_id); 
           
    CURSOR c_mx_dtl (p_mx_msg_id IN NUMBER)IS
        SELECT case_qty, prod_id, order_id
          FROM matrix_in
         WHERE interface_ref_doc = 'SYM16'
           AND rec_ind = 'D'           
           AND action_code = 'REJECTED'
           AND mx_msg_id = p_mx_msg_id; 
           
BEGIN
    FOR i IN c_mx_msg_id
    LOOP
        -----------------------Initializing the local variables-------------------------
        l_mx_msg_id := i.mx_msg_id;
        ----------------------------Getting the Record status---------------------------  
        BEGIN
            SELECT DISTINCT(record_status)
              INTO l_record_status
              FROM matrix_in
             WHERE mx_msg_id = l_mx_msg_id;
        EXCEPTION
            WHEN OTHERS THEN
                l_error_msg := 'Failed Getting the Record Status, This is a Duplicate MSG';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE validation_exception;
        END;
        
        ------------Checking Whether the Status is 'N' and Locking the Record-----------  
        IF UPPER(l_record_status) = 'N' THEN
            BEGIN
                UPDATE matrix_in
                   SET record_status = 'Q'
                 WHERE mx_msg_id = l_mx_msg_id;
                   
                COMMIT;
            EXCEPTION
                WHEN OTHERS THEN
                    ROLLBACK;
                    l_error_msg := 'Failed Updating the Record Status to Q';
                    l_error_code:= SUBSTR(SQLERRM,1,100);
                    RAISE validation_exception;
            END;
            
            SELECT COUNT(*)
              INTO l_cnt_sos
              FROM sos_batch
             WHERE batch_no = i.batch_id;
             
            FOR rec IN c_mx_dtl(l_mx_msg_id)             
            LOOP
                IF l_cnt_sos > 0 THEN
                    UPDATE mx_float_detail_cases
                       SET case_skip_flag = 'Y',
                           case_skip_reason = 'ACTUAL'              
                     WHERE case_id IN (SELECT case_id 
                                         FROM ( SELECT case_id 
                                                  FROM mx_float_detail_cases 
                                                 WHERE Order_Id = rec.order_id 
                                                   AND Prod_Id =rec.prod_id 
                                                   AND batch_no = i.batch_id
                                                ORDER BY case_id DESC
                                              )
                                        WHERE ROWNUM <= rec.case_qty);
                ELSE
                    SELECT COUNT(*)
                      INTO l_cnt_replenlst
                      FROM replenlst
                     WHERE mx_batch_no = i.batch_id
                       AND prod_id = rec.prod_id ;
                        
                    IF l_cnt_replenlst > 0 THEN     
                        SELECT type, pallet_id
                          INTO l_type, l_pallet_id
                          FROM replenlst
                         WHERE mx_batch_no = i.batch_id
                           AND prod_id = rec.prod_id ;                         
                           
                        UPDATE replenlst
                           SET mx_short_cases = rec.case_qty,
                               qty = qty - DECODE(type, 'DSP', 0, rec.case_qty * (SELECT spc FROM pm WHERE prod_id = rec.prod_id AND ROWNUM = 1))
                         WHERE mx_batch_no = i.batch_id
                           AND prod_id = rec.prod_id ;
                           
                        IF l_type != 'DSP' THEN
                            UPDATE INV
                               SET qty_alloc = qty_alloc - (rec.case_qty * (SELECT spc FROM pm WHERE prod_id = rec.prod_id AND ROWNUM = 1))
                             WHERE logi_loc =  l_pallet_id;
                        END IF;
                    ELSE
                       SELECT count(*) 
                         INTO l_cnt_iir
                         FROM mx_inv_request
                        WHERE batch_no = i.batch_id
                          AND prod_id  = rec.prod_id;
                          
                          IF l_cnt_iir > 0 THEN
                            
                             SELECT qty_requested 
                               INTO l_case_requested
                               FROM mx_inv_request
                              WHERE batch_no = i.batch_id
                                AND prod_id  = rec.prod_id;
                                
                                UPDATE mx_inv_request
                                   SET qty_short = rec.case_qty, 
                                       status    = DECODE(l_case_requested, rec.case_qty, 'SHT', status)
                                 WHERE batch_no = i.batch_id
                                   AND prod_id  = rec.prod_id;    
                          
                          END IF;
                          
                    END IF;    
                           
                END IF;                     
            END LOOP;
        
                     
            ------------------Unlocking the Record and Updating to Success------------------      
            BEGIN
                UPDATE matrix_in
                   SET record_status = 'S'
                 WHERE mx_msg_id     = l_mx_msg_id
                   AND record_status = 'Q';
            EXCEPTION
                WHEN OTHERS THEN
                    ROLLBACK;
                    l_error_msg := 'Failed Unlocking the record from Q to S';
                    l_error_code:= SUBSTR(SQLERRM,1,100);
                    RAISE validation_exception;
            END; 
            COMMIT;
        END IF;    
    END LOOP; 
 
EXCEPTION    
     --------------------Any Failure Updating the Status to Failure------------------              
    WHEN validation_exception THEN
        ROLLBACK;
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT;
        
     --------------------Any Failure Updating the Status to Failure------------------
    WHEN OTHERS THEN        
        ROLLBACK;  
        l_error_msg    := SUBSTR(SQLERRM,1,100);
        l_error_code   := SUBSTR(SQLCODE,1,100);
        UPDATE matrix_in 
           SET record_status = 'F', 
               error_msg     = l_error_msg,
               error_code    = l_error_code
         WHERE mx_msg_id     = l_mx_msg_id;
        COMMIT;
END sym16_case_skip_update;

END pl_mx_stg_to_swms;
/


Show Errors

CREATE OR REPLACE PUBLIC SYNONYM pl_mx_stg_to_swms FOR swms.pl_mx_stg_to_swms;

grant execute on swms.pl_mx_stg_to_swms to swms_user;
