CREATE OR REPLACE PACKAGE      pl_mx_inv_sync IS 
-----------------------------------------------------------------------------
-- Package Name:
--    pl_mx_inv_sync
--
-- Description:
--    This package functions to sync the symbotic inventory with SWMS inventory
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    03/05/15 ayad5195 Initial Creation for Symbotic invoice sync
--
-----------------------------------------------------------------------------
Ct_Program_Code CONSTANT VARCHAR2 (50) := 'PL_MX_INV_SYNC';
l_success       CONSTANT NUMBER := 0;
l_failure       CONSTANT NUMBER := 1;

---------------------------------------------------------------------------
-- Function:
--    mx_inv_sync
--
-- Description:
--    Sync Symbotic inventory with SWMS inventory 
--    Return 0-Success and 1-Failure
---------------------------------------------------------------------------
FUNCTION mx_inv_sync(i_mx_msg_id IN VARCHAR2) RETURN NUMBER;

END pl_mx_inv_sync;
/

show errors


CREATE OR REPLACE PACKAGE BODY      pl_mx_inv_sync IS

/*=============================================================================================
 This package functions to sync the symbotic inventory with SWMS inventory

Modification History
Date           Designer         Comments
-----------    ---------------  --------------------------------------------------------
03-Mar-2015    ayad5195         Initial Creation

=============================================================================================*/

/*---------------------------------------------------------------------------
 Function:
    mx_inv_sync

 Description:
    Sync Symbotic inventory with SWMS inventory

 Parameter:
      N/A

 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    02-Mar-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/
FUNCTION mx_inv_sync(i_mx_msg_id IN VARCHAR2) RETURN NUMBER IS
    CURSOR c_mx_prod IS
        SELECT prod_id, inv_status, SUM(symbotic_inv) symbotic_inv
          FROM (
                SELECT prod_id, inv_status, case_quantity symbotic_inv
                  FROM matrix_inv_bulk_in
                 WHERE mx_msg_id = i_mx_msg_id                 
                UNION ALL
                SELECT prod_id, 'HLD' inv_status, qty_suspect symbotic_inv
                  FROM matrix_inv_bulk_in
                 WHERE mx_msg_id = i_mx_msg_id
                   AND qty_suspect > 0
                )
         GROUP BY prod_id, inv_status    
         ORDER BY prod_id, inv_status desc;
            
    CURSOR c_symb_inv (i_prod_id    IN VARCHAR2,
                       i_inv_status IN VARCHAR2) IS
        SELECT sequence_number, mx_msg_id, rec_ind, record_status, add_date, add_user,       
               upd_date, upd_user, prod_id, pallet_id, case_quantity, inv_status, TO_DATE(product_date,'YYYY/MM/DD') product_date, qty_suspect          
          FROM matrix_inv_bulk_in
         WHERE prod_id = i_prod_id
           AND inv_status = i_inv_status
           AND mx_msg_id = i_mx_msg_id;
    
    CURSOR c_swms_inv IS        
        SELECT i.prod_id, i.rec_id, i.mfg_date, i.rec_date, i.exp_date, i.inv_date,          
               i.logi_loc, i.plogi_loc, i.qoh, i.qty_alloc, i.qty_planned, i.min_qty,          
               i.cube, i.lst_cycle_date, i.lst_cycle_reason, i.abc, i.abc_gen_date,     
               i.status, i.lot_id, i.weight, i.temperature, i.exp_ind, i.cust_pref_vendor, 
               i.case_type_tmu, i.pallet_height, i.add_date, i.add_user, i.upd_date, i.upd_user,
               i.parent_pallet_id, i.dmg_ind, i.inv_uom, i.mx_xfer_type,  
               l.slot_type 
          FROM inv i, loc l
         WHERE i.plogi_loc = l.logi_loc
           AND l.slot_type IN ('MXC', 'MXF')
           AND NOT EXISTS (SELECT 1 
                             FROM matrix_inv_bulk_in mi
                            WHERE mi.pallet_id = i.logi_loc
                              AND mx_msg_id = i_mx_msg_id); 
                  
    CURSOR c_swms_suspect IS        
        SELECT i.prod_id, i.rec_id, i.mfg_date, i.rec_date, i.exp_date, i.inv_date,          
               i.logi_loc, i.plogi_loc, i.qoh, i.qty_alloc, i.qty_planned, i.min_qty,          
               i.cube, i.lst_cycle_date, i.lst_cycle_reason, i.abc, i.abc_gen_date,     
               i.status, i.lot_id, i.weight, i.temperature, i.exp_ind, i.cust_pref_vendor, 
               i.case_type_tmu, i.pallet_height, i.add_date, i.add_user, i.upd_date, i.upd_user,
               i.parent_pallet_id, i.dmg_ind, i.inv_uom, i.mx_xfer_type,  
               l.slot_type 
          FROM inv i, loc l
         WHERE i.plogi_loc = l.logi_loc
           AND l.slot_type = 'MXO'
           AND i.logi_loc like 'SSP%'
           AND NOT EXISTS (SELECT 1 
                             FROM matrix_inv_bulk_in mi
                            WHERE mi.pallet_id = i.mx_orig_pallet_id
                              AND mx_msg_id = i_mx_msg_id); 
                              
    CURSOR c_cur_exception IS   
        SELECT prod_id, (qty_swms - qty_symbotic) qty_diff
          FROM( SELECT prod_id, SUM(qty_swms) qty_swms, SUM(qty_symbotic) qty_symbotic
                  FROM mx_inv_exception
                 WHERE mx_msg_id = i_mx_msg_id 
                 GROUP BY prod_id)
         WHERE qty_swms - qty_symbotic != 0;                                       
                
    l_prod_id               inv.prod_id%TYPE;
    l_qoh                   inv.qoh%TYPE;
    l_qty_alloc             inv.qty_alloc%TYPE;
    l_qty_planned           inv.qty_planned%TYPE;
    l_status                inv.status%TYPE;
    l_exp_date              inv.exp_date%TYPE;    
    l_plogi_loc             inv.plogi_loc%TYPE;
    l_warehouse_id          zone.warehouse_id%TYPE; 
    l_outduct_loc           inv.plogi_loc%TYPE;
    l_pallet_id_new         matrix_in.pallet_id%TYPE;
    l_spc                   pm.spc%TYPE;
    l_function              mx_inv_hist.function%TYPE;
    l_swms_inv_found        NUMBER;
    l_inv_hist_cnt          NUMBER;
    l_swms_inv              NUMBER;
    l_susp_inv              NUMBER;
    l_swms_prod_inv         NUMBER;
    l_susp_prod_inv         NUMBER;
    l_slot_type             loc.slot_type%TYPE;
    l_symbotic_loc          loc.logi_loc%TYPE;
    l_length                NUMBER;
    l_suspect_exists        NUMBER;
    l_suspect_qty           NUMBER;
    l_cnt_exception         NUMBER;
    l_cnt                   NUMBER;
    l_qty_swms              NUMBER; 
    l_qty_symbotic          NUMBER;
    l_symbotic_prod_inv     NUMBER;
    l_prod_skip             NUMBER;
    l_old_status            VARCHAR2(3);
    l_new_status            VARCHAR2(3);
    l_sta_qty               inv.qoh%TYPE;
    
BEGIN
    FOR rec_prod IN c_mx_prod
    LOOP
        l_prod_skip:= 0;
        
        BEGIN
            SELECT spc
              INTO l_spc 
              FROM pm
             WHERE prod_id = rec_prod.prod_id
               AND ROWNUM = 1;
               
            --Find Symbotic location for the prod_id
            SELECT l.logi_loc
              INTO l_symbotic_loc
              FROM mx_food_type mft, pm p, loc l 
             WHERE mft.mx_food_type  = p.mx_food_type
               AND p.prod_id = rec_prod.prod_id
               AND mft.slot_type = l.slot_type
               AND ROWNUM = 1;   
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Skipping the Item as either prod_id not exists in SWMS or mx_food_type in PM table is not set for PROD_ID '||rec_prod.prod_id, SQLCODE, SQLERRM);
                l_prod_skip := 1;
                INSERT INTO mx_inv_exception (prod_id, status, sync_date, mx_msg_id,   
                                              qty_swms, qty_symbotic, qty_diff)
                                      VALUES (rec_prod.prod_id, rec_prod.inv_status, SYSDATE, i_mx_msg_id,                                    
                                              0, rec_prod.symbotic_inv, rec_prod.symbotic_inv); 
                                  
                
        END;
        
        /*if item present in SWMS*/
        IF l_prod_skip = 0 THEN
            --Total Symbotic inventory by item
            SELECT SUM(NVL(case_quantity, 0)) + SUM(NVL(qty_suspect, 0))
              INTO l_symbotic_prod_inv      
              FROM matrix_inv_bulk_in
             WHERE mx_msg_id = i_mx_msg_id 
               AND prod_id = rec_prod.prod_id;       
                   
            --Total SWMS normal inventory by item 
            SELECT NVL(SUM(NVL(i.qoh, 0)), 0)
              INTO l_swms_prod_inv
              FROM inv i ,loc l, pm p
             WHERE i.prod_id = rec_prod.prod_id           
               AND i.prod_id = p.prod_id
               AND i.cust_pref_vendor = p.cust_pref_vendor         
               AND i.plogi_loc = l.logi_loc
               AND l.slot_type IN ('MXF', 'MXC');
             
            --Total SWMS suspect inventory by item   
            SELECT NVL(SUM(NVL(i.qoh, 0)),0)
              INTO l_susp_prod_inv
              FROM inv i ,loc l, pm p
             WHERE i.prod_id = rec_prod.prod_id
               AND i.prod_id = p.prod_id
               AND i.cust_pref_vendor = p.cust_pref_vendor         
               AND i.plogi_loc = l.logi_loc
               AND i.logi_loc LIKE 'SSP%'          
               AND l.slot_type IN ('MXO');   
               
            --Total SWMS inventory by item and status 
            SELECT NVL(SUM(NVL(i.qoh, 0)), 0)
              INTO l_swms_inv
              FROM inv i ,loc l, pm p
             WHERE i.prod_id = rec_prod.prod_id
               AND i.status = rec_prod.inv_status
               AND i.prod_id = p.prod_id
               AND i.cust_pref_vendor = p.cust_pref_vendor         
               AND i.plogi_loc = l.logi_loc
               AND l.slot_type IN ('MXF', 'MXC');
             
            --Total SWMS suspect inventory by item  and status 
            SELECT NVL(SUM(NVL(i.qoh, 0)),0)
              INTO l_susp_inv
              FROM inv i ,loc l, pm p
             WHERE i.prod_id = rec_prod.prod_id
               AND i.status = rec_prod.inv_status
               AND i.prod_id = p.prod_id
               AND i.cust_pref_vendor = p.cust_pref_vendor         
               AND i.plogi_loc = l.logi_loc
               AND i.logi_loc LIKE 'SSP%'          
               AND l.slot_type IN ('MXO');
            
            
               
            Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Insert mx_inv_exception prod_id '||rec_prod.prod_id ||'   inv_status '|| rec_prod.inv_status || '  l_swms_inv='||l_swms_inv||'  l_susp_inv ='||l_susp_inv||'   rec_prod.symbotic_inv * l_spc ='||rec_prod.symbotic_inv * l_spc, SQLCODE, SQLERRM);
            
            INSERT INTO mx_inv_exception (prod_id, status, sync_date, mx_msg_id,   
                                          qty_swms, qty_symbotic, qty_diff)
                                  VALUES (rec_prod.prod_id, rec_prod.inv_status, SYSDATE, i_mx_msg_id,                                    
                                          l_swms_inv + l_susp_inv, rec_prod.symbotic_inv * l_spc, ( rec_prod.symbotic_inv * l_spc) - (l_swms_inv + l_susp_inv)); 
                
            FOR rec_symb IN c_symb_inv(rec_prod.prod_id, rec_prod.inv_status) 
            LOOP
                l_swms_inv_found := 1;
                   
                BEGIN
                    SELECT i.prod_id, i.qoh, i.status, i.exp_date, l.slot_type, i.plogi_loc, i.qty_alloc,i.qty_planned
                      INTO l_prod_id, l_qoh, l_status, l_exp_date, l_slot_type, l_plogi_loc, l_qty_alloc, l_qty_planned
                      FROM inv i, pm p, loc l
                     WHERE i.logi_loc = rec_symb.pallet_id
                        AND i.prod_id = p.prod_id
                        AND i.cust_pref_vendor = p.cust_pref_vendor
                        AND i.plogi_loc = l.logi_loc;
                EXCEPTION    
                    WHEN NO_DATA_FOUND THEN
                        l_swms_inv_found := 0;
                END;
                
                IF l_swms_inv_found = 0 THEN --If SWMS inventory not found then insert the inventory using inv_hist
                    IF rec_symb.case_quantity > 0 THEN
                        BEGIN
                            --Find Symbotic location for the prod_id
                            SELECT l.logi_loc
                              INTO l_symbotic_loc
                              FROM mx_food_type mft, pm p, loc l 
                             WHERE mft.mx_food_type  = p.mx_food_type
                               AND p.prod_id = rec_symb.prod_id
                               AND mft.slot_type = l.slot_type
                               AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS THEN
                                Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Select logi_loc failed for prod_id '||rec_symb.prod_id, SQLCODE, SQLERRM);
                                RAISE;
                        END;
                        
                        SELECT COUNT(*)
                          INTO l_inv_hist_cnt
                          FROM inv_hist
                         WHERE logi_loc =  rec_symb.pallet_id
                           AND prod_id = rec_symb.prod_id;
                        
                        IF l_inv_hist_cnt > 0 THEN  --If inv_hist record found, use record to insert inv record
                            Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Insert inv - INV_HIST record found for pallet_id '||rec_symb.pallet_id, NULL, NULL);
                            
                            INSERT INTO inv (prod_id, rec_id, mfg_date, rec_date, exp_date, inv_date, 
                                             logi_loc, plogi_loc, qoh, qty_alloc, qty_planned,
                                             min_qty, cube, lst_cycle_date, lst_cycle_reason, abc, abc_gen_date,
                                             status, lot_id, weight, temperature, exp_ind, cust_pref_vendor,
                                             case_type_tmu, pallet_height, add_date, add_user, 
                                             parent_pallet_id, dmg_ind, inv_uom)
                                             --, upd_date, upd_user, mx_xfer_type, update_done) 
                                      SELECT rec_symb.prod_id, i.rec_id, i.mfg_date, i.rec_date, rec_symb.product_date, i.inv_date, 
                                             i.logi_loc, l_symbotic_loc, rec_symb.case_quantity * l_spc, 0, 0, 
                                             i.min_qty, i.cube, i.lst_cycle_date, i.lst_cycle_reason, i.abc, i.abc_gen_date,
                                             rec_symb.inv_status, i.lot_id, i.weight, i.temperature, i.exp_ind, i.cust_pref_vendor,
                                             i.case_type_tmu, i.pallet_height, i.inv_add_date, i.inv_add_user,
                                             i.parent_pallet_id, i.dmg_ind, i.inv_uom  
                                        FROM inv_hist i
                                       WHERE i.logi_loc =  rec_symb.pallet_id
                                         AND i.inv_del_date = (SELECT MAX(inv_del_date) 
                                                                 FROM inv_hist
                                                                WHERE logi_loc = rec_symb.pallet_id);           
                            
                        ELSE  --if inv_hist record not exists, the insert manually
                            Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Insert inv - INV_HIST record not found for pallet_id '||rec_symb.pallet_id, NULL, NULL);
                            
                            INSERT INTO inv (prod_id, exp_date, inv_date, 
                                             logi_loc, plogi_loc, qoh, qty_alloc, qty_planned,
                                             min_qty, abc, status, cust_pref_vendor)
                                    VALUES (rec_symb.prod_id, rec_symb.product_date, SYSDATE, 
                                            rec_symb.pallet_id, l_symbotic_loc, rec_symb.case_quantity * l_spc, 0, 0, 
                                            0, 'B', rec_symb.inv_status, '-');
                        END IF;
                                                           
                        --If inventory count not matching in SWMS and symbotic for PROD_ID then create ADJ TRANS 
                        IF (l_swms_prod_inv + l_susp_prod_inv) != (l_symbotic_prod_inv * l_spc) THEN
                            Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Insert trans 1 for pallet_id '||rec_symb.pallet_id, NULL, NULL);  
                            /*INSERT INTO trans (trans_id, trans_type, trans_date, prod_id, cust_pref_vendor,
                                               exp_date, qty_expected, qty, uom, src_loc, user_id,
                                               old_status, reason_code, pallet_id, upload_time, warehouse_id,
                                               rec_id, po_no, cmt)
                                        SELECT trans_id_seq.NEXTVAL                     trans_id,
                                               'ADJ'                                    trans_type,
                                               SYSDATE                                  trans_date,
                                               prod_id                                  prod_id,
                                               '-'                                      cust_pref_vendor,
                                               exp_date                                 exp_date,
                                               0                                        qty_expected,
                                               qoh                                      qty,
                                               DECODE(inv_uom, 1, 1, 2)                 uom,
                                               plogi_loc                                src_loc,
                                               USER                                     user_id,
                                               status                                   old_status,
                                               'CC'                                     reason_code,
                                               logi_loc                                 pallet_id,
                                               to_date('01-JAN-1980', 'FXDD-MON-YYYY')  upload_time,
                                               '000'                                    warehouse_id,
                                               rec_id                                   rec_id,
                                               rec_id                                   po_no,
                                               'Symbotic Inventory Sync'                cmt
                                          FROM inv
                                         WHERE logi_loc = rec_symb.pallet_id;    */                 
                        END IF; 
                        
                        Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Insert mx_inv_hist for function = INSERT for pallet_id '||rec_symb.pallet_id, NULL, NULL);  
                        --Record inventory Insert operation in MX_INV_HIST               
                        INSERT INTO mx_inv_hist (function, sync_date, mx_msg_id, prod_id_old, prod_id_new, rec_id, mfg_date,
                                                 rec_date, exp_date_old, exp_date_new, inv_date, logi_loc, plogi_loc, qoh_old,
                                                 qoh_new, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                                 abc, abc_gen_date, status_old, status_new, lot_id, weight, temperature, exp_ind,
                                                 cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                                 upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type)
                                          SELECT 'INSERT', SYSDATE, i_mx_msg_id, prod_id, prod_id, rec_id, mfg_date,
                                                 rec_date, exp_date, exp_date, inv_date, logi_loc, plogi_loc, 0,
                                                 qoh, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                                 abc, abc_gen_date, status, status, lot_id, weight, temperature, exp_ind,
                                                 cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                                 upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type
                                            FROM inv
                                           WHERE logi_loc = rec_symb.pallet_id;                     
                    END IF; /*IF rec_symb.case_quantity > 0 */
                ELSE -- If inventory found check for changed attributes 
                    Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Checking Quantity received  Symbotic ='|| rec_symb.case_quantity ||'  l_qty_alloc = '||l_qty_alloc ||'  l_qty_planned = '||l_qty_planned ||' l_plogi_loc ='|| l_plogi_loc, NULL, NULL);
                    IF rec_symb.case_quantity = 0 AND l_qty_alloc = 0 AND l_qty_planned = 0 AND rec_symb.pallet_id != l_plogi_loc THEN
                        Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Quantity Caused Delete  SWMS ='||TRUNC(l_qoh/l_spc) ||'  Symbotic ='|| rec_symb.case_quantity, NULL, NULL);
                        l_function := 'DELETE';
                    ELSIF TRUNC(l_qoh/l_spc) != rec_symb.case_quantity THEN
                        Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Quantity Caused Update  SWMS ='||TRUNC(l_qoh/l_spc) ||'  Symbotic ='|| rec_symb.case_quantity, NULL, NULL);
                        l_function := 'UPDATE';
                    ELSIF l_status != rec_symb.inv_status  THEN
                        Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Status Caused Update  SWMS ='||l_status ||'  Symbotic ='|| rec_symb.inv_status, NULL, NULL);
                        l_function := 'UPDATE';
                    ELSIF TRUNC(l_exp_date) != TRUNC(rec_symb.product_date) THEN
                        Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Exp Date Caused Update  SWMS ='||TRUNC(l_exp_date) ||'  Symbotic ='|| TRUNC(rec_symb.product_date), NULL, NULL);
                        l_function := 'UPDATE';
                    ELSIF l_prod_id != rec_symb.prod_id THEN
                        Pl_Text_log.ins_Msg('I',Ct_Program_Code,'prod_id Caused Update  SWMS ='||l_prod_id ||'  Symbotic ='|| rec_symb.prod_id, NULL, NULL);
                        l_function := 'UPDATE';
                    ELSE
                        l_function := 'MATCH';
                    END IF;                              
                    
                    IF l_slot_type NOT IN ('MXF', 'MXC') THEN --IF inventory in not in matrix, change the pallet_id of inventory outside matrix and insert new inventory for matrix
                        Pl_Text_log.ins_Msg('I',Ct_Program_Code,'l_slot_type NOT IN (MXF, MXC) for pallet_id '||rec_symb.pallet_id, NULL, NULL);
                        IF l_prod_id != rec_symb.prod_id THEN
                            Pl_Text_log.ins_Msg('I',Ct_Program_Code,'In l_prod_id != rec_symb.prod_id  l_prod_id ['||l_prod_id||']  rec_symb.prod_id['||rec_symb.prod_id||']', NULL, NULL);
                            UPDATE inv
                               SET logi_loc = SUBSTR('RCN'||rec_symb.pallet_id, 1, 18)
                             WHERE logi_loc = rec_symb.pallet_id;
                             
                            Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Insert into inv When slot_type not in MXC and MXF for pallet_id ['||rec_symb.pallet_id||']', NULL, NULL); 
                            INSERT INTO inv (prod_id, exp_date, inv_date, 
                                             logi_loc, plogi_loc, qoh, qty_alloc, qty_planned,
                                             min_qty, abc, status, cust_pref_vendor)
                                     VALUES (rec_symb.prod_id, rec_symb.product_date, SYSDATE, 
                                             rec_symb.pallet_id, l_symbotic_loc, rec_symb.case_quantity * l_spc, 0, 0, 
                                             0, 'B', rec_symb.inv_status, '-');  
            
                            --If inventory count not matching in SWMS and symbotic for PROD_ID then create ADJ TRANS 
                            IF (l_swms_prod_inv + l_susp_prod_inv) != (l_symbotic_prod_inv * l_spc) THEN
                                Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Insert trans 2 for pallet_id '||rec_symb.pallet_id, NULL, NULL);  
                               /* INSERT INTO trans (trans_id, trans_type, trans_date, prod_id, cust_pref_vendor,
                                                   exp_date, qty_expected, qty, uom, src_loc, user_id,
                                                   old_status, reason_code, pallet_id, upload_time, warehouse_id,
                                                   rec_id, po_no, cmt)
                                            SELECT trans_id_seq.NEXTVAL                     trans_id,
                                                   'ADJ'                                    trans_type,
                                                   SYSDATE                                  trans_date,
                                                   prod_id                                  prod_id,
                                                   '-'                                      cust_pref_vendor,
                                                   exp_date                                 exp_date,
                                                   0                                        qty_expected,
                                                   qoh                                      qty,
                                                   DECODE(inv_uom, 1, 1, 2)                 uom,
                                                   plogi_loc                                src_loc,
                                                   USER                                     user_id,
                                                   status                                   old_status,
                                                   'CC'                                     reason_code,
                                                   logi_loc                                 pallet_id,
                                                   to_date('01-JAN-1980', 'FXDD-MON-YYYY')  upload_time,
                                                   '000'                                    warehouse_id,
                                                   rec_id                                   rec_id,
                                                   rec_id                                   po_no,
                                                   'Symbotic Inventory Sync'                cmt
                                              FROM inv
                                             WHERE logi_loc = rec_symb.pallet_id;           */          
                            END IF; 
                    
                            --Record inventory Insert operation in MX_INV_HIST               
                            INSERT INTO mx_inv_hist (function, sync_date, mx_msg_id, prod_id_old, prod_id_new, rec_id, mfg_date,
                                             rec_date, exp_date_old, exp_date_new, inv_date, logi_loc, plogi_loc, qoh_old,
                                             qoh_new, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                             abc, abc_gen_date, status_old, status_new, lot_id, weight, temperature, exp_ind,
                                             cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                             upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type)
                                      SELECT 'INSERT', SYSDATE, i_mx_msg_id, prod_id, prod_id, rec_id, mfg_date,
                                             rec_date, exp_date, exp_date, inv_date, logi_loc, plogi_loc, 0,
                                             qoh, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                             abc, abc_gen_date, status, status, lot_id, weight, temperature, exp_ind,
                                             cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                             upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type
                                        FROM inv
                                       WHERE logi_loc = rec_symb.pallet_id; 
                                               
                        ELSE   --IF l_prod_id != rec_symb.prod_id THEN
                            Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Else l_prod_id != rec_symb.prod_id  rec_symb.prod_id['||rec_symb.pallet_id||']', NULL, NULL);
                            BEGIN
                            SELECT l.logi_loc
                              INTO l_symbotic_loc
                              FROM loc l, mx_food_type mft, pm p
                             WHERE p.prod_id = rec_symb.prod_id
                               AND mft.mx_food_type = p.mx_food_type
                               AND mft.slot_type = l.slot_type
                               AND rownum = 1;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Not able to find matrix location for prod_id ['||rec_symb.prod_id||']', SQLCODE, SQLERRM);
                                    
                                    SELECT l.logi_loc
                                      INTO l_symbotic_loc
                                      FROM loc l
                                     WHERE l.slot_type = 'MXF'
                                       AND rownum = 1;
                            END;
                            
                            UPDATE inv
                               SET plogi_loc = l_symbotic_loc
                             WHERE logi_loc = rec_symb.pallet_id; 
                             
                             
                            IF l_function = 'UPDATE' THEN
                                Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before update of inv when slot_type not in MXF and MXC for pallet_id ['||rec_symb.pallet_id||']', NULL, NULL); 
                                
                                --Record inventory UPDATE operation in MX_INV_HIST               
                                INSERT INTO mx_inv_hist (function, sync_date, mx_msg_id, prod_id_old, prod_id_new, rec_id, mfg_date,
                                                         rec_date, exp_date_old, exp_date_new, inv_date, logi_loc, plogi_loc, qoh_old,
                                                         qoh_new, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                                         abc, abc_gen_date, status_old, status_new, lot_id, weight, temperature, exp_ind,
                                                         cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                                         upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type)
                                                  SELECT 'UPDATE', SYSDATE, i_mx_msg_id, l_prod_id, rec_symb.prod_id, rec_id, mfg_date,
                                                         rec_date, l_exp_date, rec_symb.product_date, inv_date, logi_loc, plogi_loc, l_qoh,
                                                         rec_symb.case_quantity * l_spc, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                                         abc, abc_gen_date, l_status, rec_symb.inv_status, lot_id, weight, temperature, exp_ind,
                                                         cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                                         upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type
                                                    FROM inv
                                                   WHERE logi_loc = rec_symb.pallet_id; 

                            
                                --If inventory count not matching in SWMS and symbotic for PROD_ID then create ADJ TRANS 
                                IF (l_swms_prod_inv + l_susp_prod_inv) != (l_symbotic_prod_inv * l_spc) AND TRUNC(l_qoh/l_spc) != rec_symb.case_quantity THEN
                                    Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Insert trans 3 for pallet_id '||rec_symb.pallet_id, NULL, NULL);  
                                    /*INSERT INTO trans (trans_id, trans_type, trans_date, prod_id, cust_pref_vendor,
                                                       exp_date, qty_expected, qty, uom, src_loc, user_id,
                                                       old_status, reason_code, pallet_id, upload_time, warehouse_id,
                                                       rec_id, po_no, cmt)
                                                SELECT trans_id_seq.NEXTVAL                     trans_id,
                                                       'ADJ'                                    trans_type,
                                                       SYSDATE                                  trans_date,
                                                       prod_id                                  prod_id,
                                                       '-'                                      cust_pref_vendor,
                                                       exp_date                                 exp_date,
                                                       qoh                                      qty_expected,
                                                       (rec_symb.case_quantity * l_spc) - qoh   qty,
                                                       DECODE(inv_uom, 1, 1, 2)                 uom,
                                                       plogi_loc                                src_loc,
                                                       USER                                     user_id,
                                                       status                                   old_status,
                                                       'CC'                                     reason_code,
                                                       logi_loc                                 pallet_id,
                                                       to_date('01-JAN-1980', 'FXDD-MON-YYYY')  upload_time,
                                                       '000'                                    warehouse_id,
                                                       rec_id                                   rec_id,
                                                       rec_id                                   po_no,
                                                       'Symbotic Inventory Sync'                cmt
                                                  FROM inv
                                                 WHERE logi_loc = rec_symb.pallet_id;          */           
                                END IF; 
                                
                                UPDATE inv
                                   SET prod_id = rec_symb.prod_id,
                                       qoh = rec_symb.case_quantity * l_spc,
                                       status = rec_symb.inv_status,
                                       exp_date = rec_symb.product_date
                                 WHERE logi_loc = rec_symb.pallet_id;    

                                --If status is changed then create STA transaction 
                                IF l_status != rec_symb.inv_status THEN
                                    ----------Calculating the Warehouse Id for creating a STA transaction-----------   
                                    BEGIN
                                        SELECT zn.warehouse_id 
                                          INTO l_warehouse_id
                                          FROM zone zn, lzone z
                                         WHERE zn.zone_id = z.zone_id
                                           AND z.logi_loc = l_symbotic_loc
                                           AND zone_type = 'PUT';
                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Failed finding the Warehouse Id for logi_loc ['||l_symbotic_loc||']', SQLCODE, SQLERRM); 
                                            --l_error_msg := 'Failed Calculating the Warehouse Id when Qty is Suspect';
                                            --l_error_code:= SUBSTR(SQLERRM,1,100);
                                            RAISE;
                                    END;   
                                    
                                    Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Inserting trans for STA 1 for pallet ['||rec_symb.pallet_id||']', NULL, NULL);  
                                    ------------------Creating a STA transaction for Suspect Quantity------------------
                            
                                    /*INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                      rec_id, src_loc, pallet_id, qty_expected,
                                                      qty, reason_code, user_id, uom, upload_time,
                                                      exp_date, old_status, new_status, warehouse_id, cust_pref_vendor )
                                               SELECT trans_id_seq.NEXTVAL, 'STA', SYSDATE, i.prod_id,
                                                      i.rec_id, l_symbotic_loc, rec_symb.pallet_id, 
                                                      NULL, i.qoh, 'CC', USER, DECODE(i.inv_uom, 1, 1, 2), 
                                                      TO_DATE('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),i.exp_date, 
                                                      l_status, rec_symb.inv_status, l_warehouse_id, i.cust_pref_vendor
                                                FROM inv i
                                               WHERE i.logi_loc = rec_symb.pallet_id ;       */                                
                                END IF;  
                            
                            ELSIF l_function = 'DELETE' THEN
                                 Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before delete of inv when slot_type not in MXF and MXC for pallet_id ['||rec_symb.pallet_id||']', NULL, NULL); 
                            
                                DELETE FROM inv                                  
                                 WHERE logi_loc = rec_symb.pallet_id;
                            END IF; 
                            
                        END IF;
                          
                    ELSE   --IF l_slot_type NOT IN ('MXF', 'MXC')    
                        IF l_function = 'UPDATE' AND l_prod_id != rec_symb.prod_id THEN
                            INSERT INTO mx_inv_hist (function, sync_date, mx_msg_id, prod_id_old, prod_id_new, rec_id, mfg_date,
                                                 rec_date, exp_date_old, exp_date_new, inv_date, logi_loc, plogi_loc, qoh_old,
                                                 qoh_new, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                                 abc, abc_gen_date, status_old, status_new, lot_id, weight, temperature, exp_ind,
                                                 cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                                 upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type)
                                          SELECT 'DELETE', SYSDATE, i_mx_msg_id, l_prod_id, rec_symb.prod_id, rec_id, mfg_date,
                                                 rec_date, l_exp_date, rec_symb.product_date, inv_date, logi_loc, plogi_loc, qoh,
                                                 0, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                                 abc, abc_gen_date, status, status, lot_id, weight, temperature, exp_ind,
                                                 cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                                 upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type
                                            FROM inv
                                           WHERE logi_loc = rec_symb.pallet_id;                             
                                
                            INSERT INTO mx_inv_hist (function, sync_date, mx_msg_id, prod_id_old, prod_id_new, rec_id, mfg_date,
                                         rec_date, exp_date_old, exp_date_new, inv_date, logi_loc, plogi_loc, qoh_old,
                                         qoh_new, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                         abc, abc_gen_date, status_old, status_new, lot_id, weight, temperature, exp_ind,
                                         cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                         upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type)
                                  SELECT 'INSERT', SYSDATE, i_mx_msg_id, rec_symb.prod_id, rec_symb.prod_id, rec_id, mfg_date,
                                         rec_date, rec_symb.product_date, rec_symb.product_date, inv_date, logi_loc, plogi_loc, 0,
                                         rec_symb.case_quantity * l_spc, 0, 0, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                         abc, abc_gen_date, rec_symb.inv_status, rec_symb.inv_status, lot_id, weight, temperature, exp_ind,
                                         cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                         upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type
                                    FROM inv
                                   WHERE logi_loc = rec_symb.pallet_id;
                            
                            DELETE FROM inv WHERE logi_loc = rec_symb.pallet_id;
                            
                            INSERT INTO inv (prod_id, exp_date, inv_date, 
                                             logi_loc, plogi_loc, qoh, qty_alloc, qty_planned,
                                             min_qty, abc, status, cust_pref_vendor)
                                     VALUES (rec_symb.prod_id, rec_symb.product_date, SYSDATE, 
                                             rec_symb.pallet_id, l_plogi_loc, rec_symb.case_quantity * l_spc, 0, 0, 
                                             0, 'B', rec_symb.inv_status, '-');        
                        ELSE
                            Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Insert MX_INV_HIST for function ['||l_function || ']   rec_symb.pallet_id['||rec_symb.pallet_id||']', NULL, NULL);
                            --Record inventory UPDATE/MATCH operation in MX_INV_HIST               
                            INSERT INTO mx_inv_hist (function, sync_date, mx_msg_id, prod_id_old, prod_id_new, rec_id, mfg_date,
                                                     rec_date, exp_date_old, exp_date_new, inv_date, logi_loc, plogi_loc, qoh_old,
                                                     qoh_new, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                                     abc, abc_gen_date, status_old, status_new, lot_id, weight, temperature, exp_ind,
                                                     cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                                     upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type)
                                              SELECT l_function, SYSDATE, i_mx_msg_id, l_prod_id, rec_symb.prod_id, rec_id, mfg_date,
                                                     rec_date, l_exp_date, rec_symb.product_date, inv_date, logi_loc, plogi_loc, l_qoh,
                                                     rec_symb.case_quantity * l_spc, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                                     abc, abc_gen_date, l_status, rec_symb.inv_status, lot_id, weight, temperature, exp_ind,
                                                     cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                                     upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type
                                                FROM inv
                                               WHERE logi_loc = rec_symb.pallet_id; 
                                               
                            --If attributes changed UPDATE the inventory                      
                            IF l_function = 'UPDATE' THEN
                                Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before update of inv for pallet_id ['||rec_symb.pallet_id||']', NULL, NULL); 
                                
                                --If inventory count not matching in SWMS and symbotic for PROD_ID then create ADJ TRANS 
                                IF (l_swms_prod_inv + l_susp_prod_inv) != (l_symbotic_prod_inv * l_spc) AND TRUNC(l_qoh/l_spc) != rec_symb.case_quantity THEN
                                    Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Insert trans 4 for pallet_id '||rec_symb.pallet_id, NULL, NULL);  
                                   /* INSERT INTO trans (trans_id, trans_type, trans_date, prod_id, cust_pref_vendor,
                                                       exp_date, qty_expected, qty, uom, src_loc, user_id,
                                                       old_status, reason_code, pallet_id, upload_time, warehouse_id,
                                                       rec_id, po_no, cmt)
                                                SELECT trans_id_seq.NEXTVAL                     trans_id,
                                                       'ADJ'                                    trans_type,
                                                       SYSDATE                                  trans_date,
                                                       prod_id                                  prod_id,
                                                       '-'                                      cust_pref_vendor,
                                                       exp_date                                 exp_date,
                                                       qoh                                      qty_expected,
                                                       (rec_symb.case_quantity * l_spc) - qoh   qty,
                                                       DECODE(inv_uom, 1, 1, 2)                 uom,
                                                       plogi_loc                                src_loc,
                                                       USER                                     user_id,
                                                       status                                   old_status,
                                                       'CC'                                     reason_code,
                                                       logi_loc                                 pallet_id,
                                                       to_date('01-JAN-1980', 'FXDD-MON-YYYY')  upload_time,
                                                       '000'                                    warehouse_id,
                                                       rec_id                                   rec_id,
                                                       rec_id                                   po_no,
                                                       'Symbotic Inventory Sync'                cmt
                                                  FROM inv
                                                 WHERE logi_loc = rec_symb.pallet_id;       */              
                                END IF; 
                                
                                UPDATE inv
                                   SET prod_id = rec_symb.prod_id,
                                       qoh = rec_symb.case_quantity * l_spc,
                                       status = rec_symb.inv_status,
                                       exp_date = rec_symb.product_date
                                 WHERE logi_loc = rec_symb.pallet_id;
                                
                                --If status is changed then create STA transaction 
                                IF l_status != rec_symb.inv_status THEN
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
                                            Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Failed finding the Warehouse Id for logi_loc ['||l_plogi_loc||']', SQLCODE, SQLERRM); 
                                            --l_error_msg := 'Failed Calculating the Warehouse Id when Qty is Suspect';
                                            --l_error_code:= SUBSTR(SQLERRM,1,100);
                                            RAISE;
                                    END;   
                                    
                                    Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Inserting trans for STA 2 for pallet ['||rec_symb.pallet_id ||']', NULL, NULL);  
                                    ------------------Creating a STA transaction for Suspect Quantity------------------
                            
                                    /*INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                      rec_id, src_loc, pallet_id, qty_expected,
                                                      qty, reason_code, user_id, uom, upload_time,
                                                      exp_date, old_status, new_status, warehouse_id, cust_pref_vendor )
                                               SELECT trans_id_seq.NEXTVAL, 'STA', SYSDATE, i.prod_id,
                                                      i.rec_id, l_plogi_loc, rec_symb.pallet_id, 
                                                      NULL, i.qoh, 'CC', USER, DECODE(i.inv_uom, 1, 1, 2), 
                                                      TO_DATE('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),i.exp_date, 
                                                      l_status, rec_symb.inv_status, l_warehouse_id, i.cust_pref_vendor
                                                FROM inv i
                                               WHERE i.logi_loc = rec_symb.pallet_id ;  */       
                                       
                                END IF;  
                            ELSIF l_function = 'DELETE' THEN
                                Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before update of inv for pallet_id ['||rec_symb.pallet_id||']', NULL, NULL); 
                                DELETE FROM inv
                                 WHERE logi_loc = rec_symb.pallet_id;
                            
                            END IF;  
                        END IF; --IF l_function = 'UPDATE' AND l_prod_id != rec_symb.prod_id THEN
                    END IF;    
                          
                END IF;
                
                ---Suspect Case Handling
                Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Suspect case check  rec_symb.qty_suspect ['||rec_symb.qty_suspect||']', NULL, NULL); 
                
                l_length := LENGTH(rec_symb.pallet_id);
                   
                IF l_length <= 15 THEN
                    l_pallet_id_new  := 'SSP'||rec_symb.pallet_id;
                ELSIF l_length = 16 THEN
                    l_pallet_id_new  := 'SSP'||SUBSTR(rec_symb.pallet_id,2);
                ELSIF l_length = 17 THEN
                    l_pallet_id_new  := 'SSP'||SUBSTR(rec_symb.pallet_id,3);   
                ELSIF l_length = 18 THEN
                    l_pallet_id_new  := 'SSP'||SUBSTR(rec_symb.pallet_id,4);
                END IF;               
             
                Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Suspect pallet is ['||l_pallet_id_new||']', NULL, NULL); 
                
                --Check if suspect case inventory already exists 
                l_suspect_exists := 1;
                
                BEGIN   
                    SELECT logi_loc
                      INTO l_outduct_loc
                      FROM loc
                     WHERE slot_type = 'MXO'
                       AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS THEN
                        Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Not able to find outduct location for slot_type MXO', NULL, NULL); 
                        RAISE;                
                END;
                
                ----------Calculating the Warehouse Id for creating a STA transaction-----------   
                BEGIN
                    SELECT zn.warehouse_id 
                      INTO l_warehouse_id
                      FROM zone zn, lzone z
                     WHERE zn.zone_id = z.zone_id
                       AND z.logi_loc = l_outduct_loc
                       AND zone_type = 'PUT';
                EXCEPTION
                    WHEN OTHERS THEN
                        Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Failed finding the Warehouse Id for logi_loc ['||l_outduct_loc||']', SQLCODE, SQLERRM); 
                        --l_error_msg := 'Failed Calculating the Warehouse Id when Qty is Suspect';
                        --l_error_code:= SUBSTR(SQLERRM,1,100);
                        l_warehouse_id := '000';
                        RAISE;
                END; 
                            
                BEGIN
                    SELECT qoh
                      INTO l_suspect_qty
                      FROM inv
                     WHERE logi_loc = l_pallet_id_new
                       AND prod_id = rec_symb.prod_id;
                 EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        l_suspect_exists := 0;
                END;
                
                IF NVL(rec_symb.qty_suspect, 0) = 0 AND l_suspect_exists = 1 THEN
                    Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Deleting Suspect pallet ['||l_pallet_id_new||']', NULL, NULL); 
                    
                    SELECT COUNT(*)
                      INTO l_cnt_exception        
                      FROM mx_inv_exception
                     WHERE prod_id = rec_symb.prod_id
                       AND status = 'HLD'
                       AND mx_msg_id = i_mx_msg_id;
                    
                    -- if exception record not exists then Insert   
                    IF l_cnt_exception = 0 THEN
                         SELECT NVL(SUM(NVL(i.qoh, 0)), 0)
                          INTO l_swms_inv
                          FROM inv i ,loc l, pm p
                         WHERE i.prod_id = rec_symb.prod_id
                           AND i.status = 'HLD'
                           AND i.prod_id = p.prod_id
                           AND i.cust_pref_vendor = p.cust_pref_vendor         
                           AND i.plogi_loc = l.logi_loc
                           AND (l.slot_type IN ('MXF', 'MXC')   
                               OR
                                (l.slot_type = 'MXO' AND i.logi_loc LIKE 'SSP%'));                     
                    
                        INSERT INTO mx_inv_exception (prod_id, status, sync_date, mx_msg_id,   
                                                      qty_swms, qty_symbotic, qty_diff)
                                              VALUES (rec_symb.prod_id, 'HLD', SYSDATE, i_mx_msg_id,                                    
                                                      l_swms_inv, 0, (l_swms_inv * -1 )); 
                            
                    END IF;
                    
                    INSERT INTO mx_inv_hist (function, sync_date, mx_msg_id, prod_id_old, prod_id_new, rec_id, mfg_date,
                                                 rec_date, exp_date_old, exp_date_new, inv_date, logi_loc, plogi_loc, qoh_old,
                                                 qoh_new, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                                 abc, abc_gen_date, status_old, status_new, lot_id, weight, temperature, exp_ind,
                                                 cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                                 upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type)
                                          SELECT 'DELETE', SYSDATE, i_mx_msg_id, rec_symb.prod_id, rec_symb.prod_id, rec_id, mfg_date,
                                                 rec_date, l_exp_date, rec_symb.product_date, inv_date, logi_loc, plogi_loc, qoh,
                                                 0, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                                 abc, abc_gen_date, 'HLD', 'HLD', lot_id, weight, temperature, exp_ind,
                                                 cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                                 upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type
                                            FROM inv
                                           WHERE logi_loc = l_pallet_id_new; 
                                               
                    --Send STA transaction before deleting the suspect pallet                          
                    IF l_suspect_qty > 0 THEN   
                        
                        INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                              rec_id, src_loc, pallet_id, qty_expected,
                                              qty, reason_code, user_id, uom, upload_time,
                                              exp_date, old_status, new_status, warehouse_id, cust_pref_vendor )
                                       SELECT trans_id_seq.NEXTVAL, 'STA', SYSDATE, i.prod_id,
                                              i.rec_id, l_outduct_loc, l_pallet_id_new, 
                                              0, l_suspect_qty, 'CC', USER, i.inv_uom, 
                                              TO_DATE('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),i.exp_date, 
                                              'HLD', 'AVL', l_warehouse_id, i.cust_pref_vendor
                                        FROM inv i
                                       WHERE i.logi_loc = l_pallet_id_new ;    
                    END IF;           

                    DELETE FROM inv
                     WHERE logi_loc = l_pallet_id_new;
                     
                ELSIF  NVL(rec_symb.qty_suspect, 0) > 0 THEN   -- If suspect case present    
                    
                    Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Check Suspect pallet exists ['||l_suspect_exists||']', NULL, NULL); 
                    
                    IF l_suspect_exists > 0 THEN  -- If suspect case inventory exists then Update QOH Else insert the new Suspect case inventory
                    
                        --Check for change l_function = UPDATE and qty_suspect       
                        IF l_suspect_qty != rec_symb.qty_suspect * l_spc THEN
                    
                            Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Suspect pallet exists ['||l_pallet_id_new||']', NULL, NULL); 
                        
                            --Record inventory UPDATE operation in MX_INV_HIST               
                            INSERT INTO mx_inv_hist (function, sync_date, mx_msg_id, prod_id_old, prod_id_new, rec_id, mfg_date,
                                                     rec_date, exp_date_old, exp_date_new, inv_date, logi_loc, plogi_loc, qoh_old,
                                                     qoh_new, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                                     abc, abc_gen_date, status_old, status_new, lot_id, weight, temperature, exp_ind,
                                                     cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                                     upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type)
                                              SELECT 'UPDATE', SYSDATE, i_mx_msg_id, l_prod_id, rec_symb.prod_id, rec_id, mfg_date,
                                                     rec_date, l_exp_date, rec_symb.product_date, inv_date, logi_loc, plogi_loc, qoh,
                                                     rec_symb.qty_suspect * l_spc, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                                     abc, abc_gen_date, status, status, lot_id, weight, temperature, exp_ind,
                                                     cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                                     upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type
                                                FROM inv
                                               WHERE logi_loc = l_pallet_id_new; 
                            
                            --If inventory count not matching in SWMS and symbotic for PROD_ID then create ADJ TRANS 
                            IF (l_swms_prod_inv + l_susp_prod_inv) != (l_symbotic_prod_inv * l_spc) THEN
                                Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Insert trans 5 for pallet_id '||l_pallet_id_new, NULL, NULL);  
                                /*INSERT INTO trans (trans_id, trans_type, trans_date, prod_id, cust_pref_vendor,
                                                   exp_date, qty_expected, qty, uom, src_loc, user_id,
                                                   old_status, reason_code, pallet_id, upload_time, warehouse_id,
                                                   rec_id, po_no, cmt)
                                            SELECT trans_id_seq.NEXTVAL                     trans_id,
                                                   'ADJ'                                    trans_type,
                                                   SYSDATE                                  trans_date,
                                                   prod_id                                  prod_id,
                                                   '-'                                      cust_pref_vendor,
                                                   exp_date                                 exp_date,
                                                   qoh                                      qty_expected,
                                                   (rec_symb.qty_suspect * l_spc) - qoh   qty,
                                                   DECODE(inv_uom, 1, 1, 2)                 uom,
                                                   plogi_loc                                src_loc,
                                                   USER                                     user_id,
                                                   status                                   old_status,
                                                   'CC'                                     reason_code,
                                                   logi_loc                                 pallet_id,
                                                   to_date('01-JAN-1980', 'FXDD-MON-YYYY')  upload_time,
                                                   '000'                                    warehouse_id,
                                                   rec_id                                   rec_id,
                                                   rec_id                                   po_no,
                                                   'Symbotic Inventory Sync'                cmt
                                              FROM inv
                                             WHERE logi_loc = l_pallet_id_new; */                   
                            END IF; 
                            
                            --Send STA transaction before deleting the suspect pallet                          
                            IF l_suspect_qty > rec_symb.qty_suspect * l_spc THEN
                                l_old_status := 'HLD';
                                l_new_status := 'AVL';
                                l_sta_qty := l_suspect_qty - (rec_symb.qty_suspect * l_spc);
                            ELSE
                                l_old_status := 'AVL';
                                l_new_status := 'HLD';
                                l_sta_qty := (rec_symb.qty_suspect * l_spc) - l_suspect_qty;
                            END IF;
                            
                            INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                  rec_id, src_loc, pallet_id, qty_expected,
                                                  qty, reason_code, user_id, uom, upload_time,
                                                  exp_date, old_status, new_status, warehouse_id, cust_pref_vendor )
                                           SELECT trans_id_seq.NEXTVAL, 'STA', SYSDATE, i.prod_id,
                                                  i.rec_id, l_outduct_loc, l_pallet_id_new, 
                                                  0, l_sta_qty, 'CC', USER, i.inv_uom, 
                                                  TO_DATE('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),i.exp_date, 
                                                  l_old_status, l_new_status, l_warehouse_id, i.cust_pref_vendor
                                            FROM inv i
                                           WHERE i.logi_loc = l_pallet_id_new ;    
                                    
                    
                            UPDATE inv
                               SET qoh = rec_symb.qty_suspect * l_spc,
                                   prod_id = rec_symb.prod_id,                               
                                   --status = rec_symb.inv_status,
                                   exp_date = rec_symb.product_date
                             WHERE logi_loc = l_pallet_id_new;                       
                            
                        END IF; 
                    ELSE --If suspect pallet not exists then create new inventory
                        Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Suspect pallet not exists ['||l_pallet_id_new||']', NULL, NULL); 
                        
                        SELECT COUNT(*)
                          INTO l_cnt
                          FROM inv
                         WHERE logi_loc = rec_symb.pallet_id;
                         
                        
                        Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Inserting suspect case inventory for pallet ['||l_pallet_id_new||']', NULL, NULL);  
                        IF l_cnt > 0 THEN 
                            INSERT INTO inv (prod_id, rec_id, mfg_date, rec_date, exp_date, inv_date, 
                                         logi_loc, plogi_loc, qoh, qty_alloc, qty_planned,
                                         min_qty, cube, lst_cycle_date, lst_cycle_reason, abc, abc_gen_date,
                                         status, lot_id, weight, temperature, exp_ind, cust_pref_vendor,
                                         case_type_tmu, pallet_height, add_date, add_user, 
                                         parent_pallet_id, dmg_ind, inv_uom, mx_orig_pallet_id)
                                         --, upd_date, upd_user, mx_xfer_type, update_done) 
                                  SELECT rec_symb.prod_id, i.rec_id, i.mfg_date, i.rec_date, rec_symb.product_date, i.inv_date, 
                                         l_pallet_id_new, l_outduct_loc, rec_symb.qty_suspect * l_spc, 0, 0, 
                                         i.min_qty, i.cube, i.lst_cycle_date, i.lst_cycle_reason, i.abc, i.abc_gen_date,
                                         'HLD', i.lot_id, i.weight, i.temperature, i.exp_ind, i.cust_pref_vendor,
                                         i.case_type_tmu, i.pallet_height, i.add_date, i.add_user,
                                         i.parent_pallet_id, i.dmg_ind, i.inv_uom, rec_symb.pallet_id  
                                    FROM inv i
                                   WHERE i.logi_loc =  rec_symb.pallet_id;
                        ELSE
                            SELECT COUNT(*)
                              INTO l_cnt
                              FROM inv_hist
                             WHERE logi_loc = rec_symb.pallet_id;
                             
                            IF l_cnt > 0 THEN
                                INSERT INTO inv (prod_id, rec_id, mfg_date, rec_date, exp_date, inv_date, 
                                                 logi_loc, plogi_loc, qoh, qty_alloc, qty_planned,
                                                 min_qty, cube, lst_cycle_date, lst_cycle_reason, abc, abc_gen_date,
                                                 status, lot_id, weight, temperature, exp_ind, cust_pref_vendor,
                                                 case_type_tmu, pallet_height, add_date, add_user, 
                                                 parent_pallet_id, dmg_ind, inv_uom, mx_orig_pallet_id)
                                                 --, upd_date, upd_user, mx_xfer_type, update_done) 
                                          SELECT rec_symb.prod_id, i.rec_id, i.mfg_date, i.rec_date, rec_symb.product_date, i.inv_date, 
                                                 l_pallet_id_new, l_outduct_loc, rec_symb.qty_suspect * l_spc, 0, 0, 
                                                 i.min_qty, i.cube, i.lst_cycle_date, i.lst_cycle_reason, i.abc, i.abc_gen_date,
                                                 'HLD', i.lot_id, i.weight, i.temperature, i.exp_ind, i.cust_pref_vendor,
                                                 i.case_type_tmu, i.pallet_height, i.inv_add_date, i.inv_add_user,
                                                 i.parent_pallet_id, i.dmg_ind, i.inv_uom,  rec_symb.pallet_id 
                                            FROM inv_hist i
                                           WHERE i.logi_loc =  rec_symb.pallet_id
                                             AND i.inv_del_date = (SELECT MAX(inv_del_date) 
                                                                     FROM inv_hist
                                                                    WHERE logi_loc = rec_symb.pallet_id);
                            ELSE                                        
                                INSERT INTO inv (prod_id, exp_date, inv_date, 
                                                 logi_loc, plogi_loc, qoh, qty_alloc, qty_planned,
                                                 min_qty, abc, status, cust_pref_vendor, mx_orig_pallet_id)
                                         VALUES (rec_symb.prod_id, rec_symb.product_date, SYSDATE, 
                                                 l_pallet_id_new, l_outduct_loc, rec_symb.qty_suspect * l_spc, 0, 0, 
                                                 0, 'B', 'HLD', '-', rec_symb.pallet_id);
                            END IF;
                        END IF;
                        
                        INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                                  rec_id, src_loc, pallet_id, qty_expected,
                                                  qty, reason_code, user_id, uom, upload_time,
                                                  exp_date, old_status, new_status, warehouse_id, cust_pref_vendor )
                                           SELECT trans_id_seq.NEXTVAL, 'STA', SYSDATE, i.prod_id,
                                                  i.rec_id, l_outduct_loc, l_pallet_id_new, 
                                                  0, (rec_symb.qty_suspect * l_spc), 'CC', USER, i.inv_uom, 
                                                  TO_DATE('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),i.exp_date, 
                                                  'AVL', 'HLD', l_warehouse_id, i.cust_pref_vendor
                                            FROM inv i
                                           WHERE i.logi_loc = l_pallet_id_new;
                                           
                        --If inventory count not matching in SWMS and symbotic for PROD_ID then create ADJ TRANS 
                        /*IF (l_swms_prod_inv + l_susp_prod_inv) != (l_symbotic_prod_inv * l_spc) THEN
                            Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Insert trans 6 for pallet_id '||l_pallet_id_new, NULL, NULL);  
                            INSERT INTO trans (trans_id, trans_type, trans_date, prod_id, cust_pref_vendor,
                                               exp_date, qty_expected, qty, uom, src_loc, user_id,
                                               old_status, reason_code, pallet_id, upload_time, warehouse_id,
                                               rec_id, po_no, cmt)
                                        SELECT trans_id_seq.NEXTVAL                     trans_id,
                                               'ADJ'                                    trans_type,
                                               SYSDATE                                  trans_date,
                                               prod_id                                  prod_id,
                                               '-'                                      cust_pref_vendor,
                                               exp_date                                 exp_date,
                                               0                                        qty_expected,
                                               qoh                                      qty,
                                               DECODE(inv_uom, 1, 1, 2)                 uom,
                                               plogi_loc                                src_loc,
                                               USER                                     user_id,
                                               status                                   old_status,
                                               'CC'                                     reason_code,
                                               logi_loc                                 pallet_id,
                                               to_date('01-JAN-1980', 'FXDD-MON-YYYY')  upload_time,
                                               '000'                                    warehouse_id,
                                               rec_id                                   rec_id,
                                               rec_id                                   po_no,
                                               'Symbotic Inventory Sync'                cmt
                                          FROM inv
                                         WHERE logi_loc = l_pallet_id_new;                    
                        END IF;*/
                            
                        Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Inserting mx_inv_hist for suspect case pallet ['||l_pallet_id_new||']', NULL, NULL);    
                        --Record inventory Insert operation in MX_INV_HIST               
                        INSERT INTO mx_inv_hist (function, sync_date, mx_msg_id, prod_id_old, prod_id_new, rec_id, mfg_date,
                                         rec_date, exp_date_old, exp_date_new, inv_date, logi_loc, plogi_loc, qoh_old,
                                         qoh_new, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                         abc, abc_gen_date, status_old, status_new, lot_id, weight, temperature, exp_ind,
                                         cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                         upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type)
                                  SELECT 'INSERT', SYSDATE, i_mx_msg_id, prod_id, prod_id, rec_id, mfg_date,
                                         rec_date, exp_date, exp_date, inv_date, logi_loc, plogi_loc, 0,
                                         qoh, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                         abc, abc_gen_date, status, status, lot_id, weight, temperature, exp_ind,
                                         cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                         upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type
                                    FROM inv
                                   WHERE logi_loc = l_pallet_id_new; 
                                       
                        ----------Calculating the Warehouse Id for creating a STA transaction-----------   
                        BEGIN
                            SELECT zn.warehouse_id 
                              INTO l_warehouse_id
                              FROM zone zn, lzone z
                             WHERE zn.zone_id = z.zone_id
                               AND z.logi_loc = l_outduct_loc
                               AND zone_type = 'PUT';
                        EXCEPTION
                            WHEN OTHERS THEN
                                Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Failed finding the Warehouse Id for logi_loc ['||l_outduct_loc||']', SQLCODE, SQLERRM); 
                                --l_error_msg := 'Failed Calculating the Warehouse Id when Qty is Suspect';
                                --l_error_code:= SUBSTR(SQLERRM,1,100);
                                RAISE;
                        END;   
                        
                        Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Inserting trans for suspect case pallet ['||l_pallet_id_new||']', NULL, NULL);  
                        ------------------Creating a STA transaction for Suspect Quantity------------------
                
                        /*INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                                          rec_id, src_loc, pallet_id, qty_expected,
                                          qty, reason_code, user_id, uom, upload_time,
                                          exp_date, old_status, new_status, warehouse_id, cust_pref_vendor )
                                   SELECT trans_id_seq.nextval, 'STA', sysdate, i.prod_id,
                                          i.rec_id, l_outduct_loc, l_pallet_id_new, 
                                          0, (rec_symb.qty_suspect * l_spc), 'CC', user, i.inv_uom, 
                                          TO_DATE('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),i.exp_date, 
                                          i.status, 'HLD', l_warehouse_id, i.cust_pref_vendor
                                    FROM inv i
                                   WHERE i.logi_loc = l_pallet_id_new ; */                                      
                                    
                    END IF;              
                END IF;
                        
            END LOOP;
        END IF; --IF l_prod_skip = 1 THEN
    END LOOP;
    
    --Get all SWMS inventory which is not exists in Symbotic and Delete it
    FOR rec_swms IN c_swms_inv
    LOOP        
        --Check if exception record already inserted        
        SELECT COUNT(*)
          INTO l_cnt_exception        
          FROM mx_inv_exception
         WHERE prod_id =  rec_swms.prod_id
           AND status = rec_swms.status
           AND mx_msg_id = i_mx_msg_id;
        
        -- if exception record not exists then Insert   
        IF l_cnt_exception = 0 THEN
             SELECT SUM(NVL(i.qoh, 0))
              INTO l_swms_inv
              FROM inv i ,loc l, pm p
             WHERE i.prod_id = rec_swms.prod_id
               AND i.status = rec_swms.status
               AND i.prod_id = p.prod_id
               AND i.cust_pref_vendor = p.cust_pref_vendor         
               AND i.plogi_loc = l.logi_loc
               AND l.slot_type IN ('MXF', 'MXC')
               AND NOT EXISTS (SELECT 1 
                                 FROM matrix_inv_bulk_in mi
                                WHERE mi.pallet_id = i.logi_loc
                                  AND mx_msg_id = i_mx_msg_id); 
           
        
            INSERT INTO mx_inv_exception (prod_id, status, sync_date, mx_msg_id,   
                                          qty_swms, qty_symbotic, qty_diff)
                                  VALUES (rec_swms.prod_id, rec_swms.status, SYSDATE, i_mx_msg_id,                                    
                                          l_swms_inv, 0, (l_swms_inv * -1 )); 
                
        END IF;
    
        Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Inserting mx_inv_hist for not pallet not exists['||rec_swms.logi_loc||']', NULL, NULL);  
        --Record inventory Insert operation in MX_INV_HIST               
        INSERT INTO mx_inv_hist (function, sync_date, mx_msg_id, prod_id_old, prod_id_new, rec_id, mfg_date,
                                 rec_date, exp_date_old, exp_date_new, inv_date, logi_loc, plogi_loc, qoh_old,
                                 qoh_new, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                 abc, abc_gen_date, status_old, status_new, lot_id, weight, temperature, exp_ind,
                                 cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                 upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type)
                          SELECT 'DELETE', SYSDATE, i_mx_msg_id, prod_id, prod_id, rec_id, mfg_date,
                                 rec_date, exp_date, exp_date, inv_date, logi_loc, plogi_loc, qoh,
                                 0, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                 abc, abc_gen_date, status, status, lot_id, weight, temperature, exp_ind,
                                 cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                 upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type
                            FROM inv
                           WHERE logi_loc = rec_swms.logi_loc;   
        
        BEGIN
            SELECT qty_swms, qty_symbotic
              INTO l_qty_swms, l_qty_symbotic        
              FROM mx_inv_exception
             WHERE prod_id =  rec_swms.prod_id
               AND status = rec_swms.status
               AND mx_msg_id = i_mx_msg_id;
        EXCEPTION
            WHEN OTHERS THEN
                Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Not able to find the record in mx_inv_exception  for prod_id['||rec_swms.prod_id||']  and status =['||rec_swms.status||']', SQLCODE, SQLERRM);  
                RAISE;
        END;
        
        --If inventory count not matching in SWMS and symbotic for PROD_ID then create ADJ TRANS 
        IF l_qty_swms != l_qty_symbotic THEN
            Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Insert trans 7 for pallet_id '||rec_swms.logi_loc, NULL, NULL);  
            /*INSERT INTO trans (trans_id, trans_type, trans_date, prod_id, cust_pref_vendor,
                               exp_date, qty_expected, qty, uom, src_loc, user_id,
                               old_status, reason_code, pallet_id, upload_time, warehouse_id,
                               rec_id, po_no, cmt)
                        SELECT trans_id_seq.NEXTVAL                     trans_id,
                               'ADJ'                                    trans_type,
                               SYSDATE                                  trans_date,
                               prod_id                                  prod_id,
                               '-'                                      cust_pref_vendor,
                               exp_date                                 exp_date,
                               qoh                                      qty_expected,
                               qoh * -1                                 qty,
                               DECODE(inv_uom, 1, 1, 2)                 uom,
                               plogi_loc                                src_loc,
                               USER                                     user_id,
                               status                                   old_status,
                               'CC'                                     reason_code,
                               logi_loc                                 pallet_id,
                               to_date('01-JAN-1980', 'FXDD-MON-YYYY')  upload_time,
                               '000'                                    warehouse_id,
                               rec_id                                   rec_id,
                               rec_id                                   po_no,
                               'Symbotic Inventory Sync'                cmt
                          FROM inv
                         WHERE logi_loc = rec_swms.logi_loc;  */                    
        END IF;
        
        --Delete the SWMS inventory
        DELETE 
          FROM inv
         WHERE logi_loc = rec_swms.logi_loc;
         
    END LOOP;
    
    
    --Get all SWMS SUSPECT inventory which is not exists in Symbotic and Delete it
    FOR rec_ssp IN c_swms_suspect
    LOOP        
        --Check if exception record already inserted        
        SELECT COUNT(*)
          INTO l_cnt_exception        
          FROM mx_inv_exception
         WHERE prod_id =  rec_ssp.prod_id
           AND status = 'HLD'
           AND mx_msg_id = i_mx_msg_id;
        
        -- if exception record not exists then Insert   
        IF l_cnt_exception = 0 THEN
            SELECT NVL(SUM(NVL(i.qoh, 0)), 0)
              INTO l_swms_inv
              FROM inv i ,loc l, pm p
             WHERE i.prod_id = rec_ssp.prod_id
               AND i.status = 'HLD'
               AND i.prod_id = p.prod_id
               AND i.cust_pref_vendor = p.cust_pref_vendor         
               AND i.plogi_loc = l.logi_loc
               AND (l.slot_type IN ('MXF', 'MXC')   
                   OR
                    (l.slot_type = 'MXO' AND i.logi_loc LIKE 'SSP%'));                     
        
            INSERT INTO mx_inv_exception (prod_id, status, sync_date, mx_msg_id,   
                                          qty_swms, qty_symbotic, qty_diff)
                                  VALUES (rec_ssp.prod_id, 'HLD', SYSDATE, i_mx_msg_id,                                    
                                          l_swms_inv, 0, (l_swms_inv * -1 )); 
                
        END IF;
    
        Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Before Inserting mx_inv_hist for not pallet not exists['||rec_ssp.logi_loc||']', NULL, NULL);  
        --Record inventory Insert operation in MX_INV_HIST               
        INSERT INTO mx_inv_hist (function, sync_date, mx_msg_id, prod_id_old, prod_id_new, rec_id, mfg_date,
                                 rec_date, exp_date_old, exp_date_new, inv_date, logi_loc, plogi_loc, qoh_old,
                                 qoh_new, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                 abc, abc_gen_date, status_old, status_new, lot_id, weight, temperature, exp_ind,
                                 cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                 upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type)
                          SELECT 'DELETE', SYSDATE, i_mx_msg_id, prod_id, prod_id, rec_id, mfg_date,
                                 rec_date, exp_date, exp_date, inv_date, logi_loc, plogi_loc, qoh,
                                 0, qty_alloc, qty_planned, min_qty, cube, lst_cycle_date, lst_cycle_reason,
                                 abc, abc_gen_date, status, status, lot_id, weight, temperature, exp_ind,
                                 cust_pref_vendor, case_type_tmu, pallet_height, add_date, add_user, upd_date,
                                 upd_user, parent_pallet_id, dmg_ind, inv_uom, mx_xfer_type
                            FROM inv
                           WHERE logi_loc = rec_ssp.logi_loc;   
        
        INSERT INTO trans(trans_id, trans_type, trans_date, prod_id,
                  rec_id, src_loc, pallet_id, qty_expected,
                  qty, reason_code, user_id, uom, upload_time,
                  exp_date, old_status, new_status, warehouse_id, cust_pref_vendor )
           SELECT trans_id_seq.NEXTVAL, 'STA', SYSDATE, i.prod_id,
                  i.rec_id, l_outduct_loc, i.logi_loc, 
                  0, rec_ssp.qoh, 'CC', USER, i.inv_uom, 
                  TO_DATE('01/01/1980 00:00:00', 'MM/DD/YYYY hh24:mi:ss'),i.exp_date, 
                  'HLD', 'AVL', l_warehouse_id, i.cust_pref_vendor
            FROM inv i
           WHERE i.logi_loc = rec_ssp.logi_loc;
                   
        --Delete the SWMS inventory
        DELETE 
          FROM inv
         WHERE logi_loc = rec_ssp.logi_loc;
         
    END LOOP;
    
    UPDATE Matrix_Inv_Bulk_In
       SET record_status = 'S'
      WHERE mx_msg_id = i_mx_msg_id;
      
     UPDATE sys_config
        SET config_flag_val = 'N'
      WHERE config_flag_name = 'MX_INV_SYNC_FLAG';
      
      COMMIT;
    
    RETURN 0;
EXCEPTION
    WHEN OTHERS THEN
        Pl_Text_log.ins_Msg('I',Ct_Program_Code,'Failed to process inventory sync ', SQLCODE, SQLERRM);   
        ROLLBACK;
         UPDATE Matrix_Inv_Bulk_In
            SET record_status = 'F'
          WHERE mx_msg_id = i_mx_msg_id;
          
          COMMIT;
      
        RETURN 1;
END mx_inv_sync;
   
END pl_mx_inv_sync;
/

SHOW ERRORS
CREATE OR REPLACE PUBLIC SYNONYM pl_mx_inv_sync FOR swms.pl_mx_inv_sync;