CREATE OR REPLACE TRIGGER swms.trg_insupddel_inv_brow
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_insupddel_inv.sql, swms, swms.9, 10.1.1 3/21/07 1.7
--
-- Trigger Name: trg_insupddel_inv
-- Table:
--    INV(Inventory table)
--
-- Description:
--    This trigger populates the INV.PALLET_HEIGHT column and the
--    LOC.AVAILABLE height columns.
--    The pallet height of the home slot will also be calculated.
--    If the home slot is a deep slot(say 2 deep) 
--    and there is enough quantity in the home slot to fit more than 
--    one pallet then the skid is added twice.  
--    The total occupied height(sum of individual pallet heights +skid 
--    heights) in the location is determined and the total height of the 
--    slot(slot_height*deep positions * width positions) is computed and 
--    the locations available height is set to total height of slot minus
--    the total occupied height.        
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/19/02 prpbcb   DN _____  Created.
--                      For RDC non-dependent changes.
--                      DN rs239a 10963  (should not use this one as the
--                                        changes should be done only on rs239b)
--             acppxp  DN rs239b 10994 Update of Occupied height and available 
--                     height in location.
--    10/21/02 acppxp   Allowed negative values in Available height field. 
--    11/11/02 acppxp   Set occupied height to zero if it becomes negative.
--    05/20/03 acppxp   DN#   Updated heights based on the SYSPAR flag setting.
--    05/21/03 acppxp   Updated trigger when location is updated.   
--    05/22/03 acppxp   Updated Userid and update date whenever there is an 
--                      update on inv table.
--    05/24/06 prppxx   Populate rec_date with inv_date if the new record has 
--          NULL value in rec_date. D#12095.
--    07/24/06 prpakp   Changed to make sure that qoh, qty_alloc and qty_planned
--                      will never go negative.
--    03/19/07 prppxx   D#12230 Truncate exp_date to avoid fake EDC transaction.
--    07/15/15 ayad5195 Change to not update loc table for slot type MXI, MXT 
--                      (Symbotic Induction and Staging location) and MLS (Miniload location)
--    01/05/16 ayad5195 Change to not update loc table for slot type MXF, MXC and MXS
--                      (Symbotic location) 
--    10/16/15 avij3336 6000009529 - check for outside location and skip available height calculation
--    01/26/22 pdas8114 Jira 3230 Added sysdate to exp_date when null for insert or update
------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE OR DELETE ON swms.inv
FOR EACH ROW
DECLARE
   l_object_name  VARCHAR2(30) := 'trg_insupddel_inv_brow';
   lv_msg_text  VARCHAR2(300);
   
   l_perm         loc.perm%TYPE;
   l_skid_height  pallet_type.skid_height%TYPE;
   l_deep_positions slot_type.deep_positions%TYPE;
   l_width_positions loc.width_positions%TYPE;
   l_slot_height loc.slot_height%TYPE;
   
   --The total number of pallets that will be there in the slot.
   l_no_pallets_hs  NUMBER;
   --The total height of all the pallet skids.
   l_total_skid_height NUMBER;
   --Total Occupied height in the location
   l_total_occ_height NUMBER;
   l_occ_height NUMBER;
   l_total_available_height NUMBER;
   l_pallet_height NUMBER;
   l_loc         loc.logi_loc%TYPE;
   l_prod_id loc.prod_id%TYPE;
   l_cpv loc.cust_pref_vendor%TYPE;
   l_out_loc                       NUMBER;
   --PUTAWAY_DIMENSION Syspar variable.
   lv_sys_putaway_dimension_flag sys_config.config_flag_val%type;  

    
   
   CURSOR c_item_info(cp_prod_id           pm.prod_id%TYPE,
                      cp_cust_pref_vendor  pm.cust_pref_vendor%TYPE) IS
   SELECT pm.case_height, NVL(pm.spc, 1) spc, pm.ti, pm.hi
   FROM pm
   WHERE pm.prod_id = cp_prod_id
     AND pm.cust_pref_vendor = cp_cust_pref_vendor;

   CURSOR c_loc_info(cp_logi_loc  loc.logi_loc%TYPE) IS
   SELECT NVL(pt.skid_height, 0), l.perm
         ,NVL(l.slot_height,0)
         ,NVL(st.deep_positions,1)
         ,NVL(l.width_positions,1)
         ,NVL(occupied_height,0)
   FROM pallet_type pt, loc l,slot_type st
   WHERE pt.pallet_type = l.pallet_type
         AND st.slot_type=l.slot_type
         AND l.logi_loc = cp_logi_loc;
     
   l_r_item_info c_item_info%ROWTYPE;

BEGIN
 l_out_loc :=0;
    IF ((INSERTING OR UPDATING) AND :new.exp_date is null) then 
        :new.exp_date := :new.inv_date;
    END IF;

    IF (INSERTING OR UPDATING) AND :new.rec_date IS NULL THEN
           :new.rec_date := :new.inv_date;
       IF INSERTING THEN
                lv_msg_text := 'Insert INV without rec_date! ' || 
                'prod/plogi_loc/logi_loc/add_date/add_user:' ||
                :new.prod_id || '/' || :new.plogi_loc || 
                '/' || :new.logi_loc || '/' ||
                TO_CHAR(:new.add_date, 'dd-MON-yy') || '/' ||
                :new.add_user;
       ELSIF UPDATING THEN
                lv_msg_text := 'Update INV without rec_date! ' ||
                                'prod/plogi_loc/logi_loc/upd_date/upd_user:' ||
                                :new.prod_id || '/' || :new.plogi_loc ||
                                '/' || :new.logi_loc || '/' ||
                                TO_CHAR(:new.upd_date, 'dd-MON-yy') || '/' ||
                                :new.upd_user;
       END IF;
           pl_log.ins_msg('INFO',l_object_name,lv_msg_text,NULL,sqlerrm);
        END IF;

    IF (INSERTING OR UPDATING) AND (:new.qoh < 0 or :new.qty_planned < 0 or :new.qty_alloc < 0) THEN
       IF INSERTING THEN
                lv_msg_text := 'Insert INV with Negative qty: ' || 
                'Item / Location / Pallet / Add Date / User / QOH / Qty Exp / Qty Alloc:' ||
                :new.prod_id || '/' || :new.plogi_loc || 
                '/' || :new.logi_loc || '/' ||
                TO_CHAR(:new.add_date, 'dd-MON-yy') || '/' ||
                :new.add_user||'/'||to_char(:new.qoh)||'/'||to_char(:new.qty_planned)||'/'||
                                to_char(:new.qty_alloc);
       ELSIF UPDATING THEN
                lv_msg_text := 'Update INV with Negative qty: ' ||
                'Item / Location / Pallet / Add Date / User / QOH / Qty Exp / Qty Alloc:' ||
                                :new.prod_id || '/' || :new.plogi_loc ||
                                '/' || :new.logi_loc || '/' ||
                                TO_CHAR(:new.upd_date, 'dd-MON-yy') || '/' ||
                                :new.upd_user||'/'||to_char(:new.qoh)||'/'||to_char(:new.qty_planned)||'/'||
                                to_char(:new.qty_alloc);
       END IF;
           if (:new.qoh < 0) then
                :new.qoh := 0;
           end if;
           if (:new.qty_planned < 0) then
                :new.qty_planned := 0;
           end if;
           if (:new.qty_alloc < 0) then
                :new.qty_alloc := 0;
           end if;
           pl_log.ins_msg('INFO',l_object_name,lv_msg_text,NULL,sqlerrm);
        END IF;
   l_pallet_height:=0; 
   --Retrive the value of the PUTAWAY_DIMENSION Syspar and 
   --if it is set to Inches then update the heights.
   lv_sys_putaway_dimension_flag :=pl_common.f_get_syspar('PUTAWAY_DIMENSION');
   IF lv_sys_putaway_dimension_flag IS NULL THEN
      lv_msg_text := 'Oracle;Unable to retrieve SYSPAR PUTAWAY_DIMENSION';
      pl_log.ins_msg('WARN',l_object_name,lv_msg_text,NULL,sqlerrm);         
      RETURN;
    END IF; 
    IF (lv_sys_putaway_dimension_flag = 'I') THEN  

      -- Calculate the pallet height if a new record and the qty > 0
      -- or updating a record and the qty has changed or the prod id has changed.
      IF ((INSERTING AND (:new.qoh > 0 OR :new.qty_planned > 0))
          OR 
         (UPDATING
           AND (   ((:old.qoh + :old.qty_planned) != (:new.qoh + :new.qty_planned))
                OR (:old.prod_id != :new.prod_id)
               OR (:old.cust_pref_vendor != :new.cust_pref_vendor))
                )
           OR (DELETING))
           THEN
             

         IF DELETING THEN
            l_loc:=:old.plogi_loc;
            l_prod_id:=:old.prod_id;
            l_cpv:=:old.cust_pref_vendor;
         ELSE
            l_loc:=:new.plogi_loc;
            l_prod_id:=:new.prod_id;
            l_cpv:=:new.cust_pref_vendor;
         END IF;
         OPEN c_loc_info(l_loc);
         FETCH c_loc_info INTO l_skid_height, l_perm,l_slot_height,
         l_deep_positions,l_width_positions,l_total_occ_height;
         IF (c_loc_info%NOTFOUND) THEN
            -- Ideally should never reach this point.
            l_skid_height := 0;
            l_perm :=  'N';
            -- Create a swms_log record here.
         END IF;
         CLOSE c_loc_info;
   
         OPEN c_item_info(l_prod_id, l_cpv);
         FETCH c_item_info into l_r_item_info;
         CLOSE c_item_info;
   
         IF (l_perm = 'Y') THEN
            l_no_pallets_hs:=ceil(((NVL(:new.qoh,0) + NVL(:new.qty_planned,0)) /
                             l_r_item_info.spc) /
                             (l_r_item_info.ti*l_r_item_info.hi));
            
            --This is to determine how many times the skid height of the pallet 
            --should be considered while computing the pallet height in the home
            --slot.Though there is no tracking on the basis of pallets in the 
            --home slot there will in reality be one pallet per location in the
            --home slots and therfore the skid height has to be considered.
            
            IF  (l_no_pallets_hs- (l_deep_positions*l_width_positions) >=0) THEN
              l_total_skid_height:=(l_deep_positions*l_width_positions)
                                    *l_skid_height;
            ELSE
                l_total_skid_height:=l_no_pallets_hs*l_skid_height; 
            END IF;    
            IF NOT DELETING THEN
            :new.pallet_height :=
                     ceil(((:new.qoh + :new.qty_planned) / l_r_item_info.spc) /
                               l_r_item_info.ti) *
                               l_r_item_info.case_height + l_total_skid_height;
            
            l_pallet_height:=:new.pallet_height;
            ELSE
            l_pallet_height:=0;
            
            END IF;
         
         ELSE
         -- May need more error checking here.
           IF NOT DELETING THEN
              :new.pallet_height :=
               ceil(((:new.qoh + :new.qty_planned) / l_r_item_info.spc) /
                         l_r_item_info.ti) *
                         l_r_item_info.case_height + l_skid_height;
              l_pallet_height:=:new.pallet_height;
           ELSE
              l_pallet_height:=0;
           END IF;
         END IF;
        /* 6000009529 - check for outside location and skip calculation*/
        /* 1- outside storage location */
            SELECT COUNT (1)
              INTO l_out_loc
              FROM loc l, lzone lz, ZONE z
             WHERE z.warehouse_id <> '000'
               AND z.zone_id = lz.zone_id
               AND lz.logi_loc = l.logi_loc
               AND zone_type = 'PUT'
               AND l.logi_loc = l_loc;

          IF l_out_loc = 0 THEN /* warehouse location */
		 
         l_total_available_height :=((l_slot_height*l_deep_positions
                                   *l_width_positions)- 
                                  (nvl(l_pallet_height,0)+nvl(l_total_occ_height,0)
                                   -NVL(:old.pallet_height,0)));
         l_occ_height:=NVL(l_pallet_height,0)+NVL(l_total_occ_height,0)
                                        -NVL(:old.pallet_height,0);
      
         IF l_occ_height<0 THEN
           lv_msg_text:='Occupied Height is negative for slot '|| l_loc;
           pl_log.ins_msg('WARN',l_object_name,lv_msg_text,NULL,sqlerrm);
           l_occ_height:=0;
         END IF;
         --Allowed negative available height
		 IF l_out_loc = 0 THEN /* warehouse location */
         UPDATE LOC set available_height=NVL(l_total_available_height,0),
                     occupied_height=l_occ_height
                     where logi_loc= l_loc
                       and slot_type NOT IN ('MXI', 'MXT', 'MLS', 'MXF', 'MXC', 'MXS');
            END IF;
             
         END IF;
      /* 6000009529 - check for outside location and skip calculation */			   
       ELSE
          IF INSERTING THEN
             :new.pallet_height := 0;
          END IF;
      END IF;
      IF UPDATING AND (:old.plogi_loc!=:new.plogi_loc) THEN
                 /* 6000009529 - check for outside location and skip available height calculation*/
      IF l_out_loc = 0 
      THEN
         UPDATE loc
            SET available_height = available_height - :OLD.pallet_height,
                occupied_height = occupied_height + :OLD.pallet_height
          WHERE logi_loc = :NEW.plogi_loc
		  AND slot_type NOT IN ('MXI', 'MXT', 'MLS', 'MXF', 'MXC', 'MXS');

         UPDATE loc
            SET available_height = available_height + :OLD.pallet_height,
                occupied_height = occupied_height - :OLD.pallet_height
          WHERE logi_loc = :OLD.plogi_loc
		  AND slot_type NOT IN ('MXI', 'MXT', 'MLS', 'MXF', 'MXC', 'MXS');
     -- ELSE
     --       UPDATE loc
     --       SET 
     --           occupied_height = occupied_height + :OLD.pallet_height
     --     WHERE logi_loc = :NEW.plogi_loc;

     --    UPDATE loc
     --       SET 
     --           occupied_height = occupied_height - :OLD.pallet_height
     --     WHERE logi_loc = :OLD.plogi_loc;
      END IF;
      
   /* 6000009529 - check for outside location and skip available height calculation*/

      END IF;  
    END IF;
    --On any Update in INV table
    IF UPDATING THEN
             :new.upd_user := REPLACE(USER, 'OPS$');
             :new.upd_date := SYSDATE;
    END IF;

    IF INSERTING OR UPDATING THEN
             :new.exp_date := trunc(:new.exp_date);
    END IF;
EXCEPTION
  WHEN OTHERS THEN
  --dbms_output.put_line('Location :'||l_loc);
  --return;
  --RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);
  Pl_Text_log.ins_Msg('W','trg_insupddel_inv_brow', 'Trigger trg_insupddel_inv_brow failed ', SQLCODE, SQLERRM);
END trg_insupddel_inv_brow;
/

