--drop trigger trg_ins_upd_del_pm;

CREATE OR REPLACE TRIGGER trg_ins_upd_del_pm
--------------------------------------------------------------------
   -- trg_ins_upd_del_pm.sql
   --
   -- Description:
   --     This script contains a trigger which sends a message to symbotic
   --     by calling a Package.
   --
   -- Modification History:
   --    Date      Designer Comments
   --    --------- -------- -------------------------------------------
   --    03-sep-14 Sunil Ontipalli Created as part of the Symbotic Integration
   --    10-oct-14 Sunil Ontipalli Modified as per the Bussiness Requirement and Checking various Conditions.
   --    25-jun-15 Sunil Ontipalli Modified the code to send delete to Symbotic for all the rule 5 items not the only assigned items.
--------------------------------------------------------------------
AFTER DELETE or INSERT or UPDATE
ON swms.pm
FOR EACH ROW
DECLARE
l_count     NUMBER;
BEGIN

 pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                     'Trigger PM 1',
                      NULL, NULL);
  
  IF DELETING THEN
  
         SELECT COUNT(*)
           INTO l_count
           FROM zone 
          WHERE Rule_Id      = 5
            AND z_area_code  =  :OLD.area;
     
     IF l_count > 0 THEN
           pl_mx_swms_to_pm_out.sys01_pm_out
             (i_func_code              => 'D',
              i_prod_id                => :OLD.prod_id,
              i_description            => :OLD.descrip,
              i_warehouse_area         => :OLD.area,
              i_pack                   => :OLD.pack,
              i_prod_size              => :OLD.prod_size,
              i_prod_size_unit         => :OLD.prod_size_unit,
              i_slotting_flag          => :OLD.mx_designate_slot,
              i_length                 => :OLD.case_length,
              i_width                  => :OLD.case_width,
              i_height                 => :OLD.case_height,
              i_weight                 => :OLD.g_weight,
              i_spc                    => :OLD.spc,
              i_upc_present_flag       => :OLD.mx_upc_present_flag,
              i_problem_upc_flag       => :OLD.mx_multi_upc_problem,
              i_hazardous_type         => :OLD.mx_hazardous_type,
              i_mx_food_type           => :OLD.mx_food_type,
              i_mx_select_eligibility  => :OLD.mx_eligible,
              i_mx_item_assign_flag    => :OLD.mx_item_assign_flag,
              i_sku_tip_flag           => :OLD.mx_stability_flag);
     END IF;
  END IF;     
  
  IF :OLD.mx_item_assign_flag = 'Y' OR :NEW.mx_item_assign_flag = 'Y' THEN
 
         pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                             'Trigger PM 2',
                              NULL, NULL);

      IF :OLD.prod_id               != :NEW.prod_id              OR
         :OLD.descrip               != :NEW.descrip              OR
         :OLD.area                  != :NEW.area                 OR
         :OLD.pack                  != :NEW.pack                 OR
         :OLD.prod_size             != :NEW.prod_size            OR
         :OLD.prod_size_unit        != :NEW.prod_size_unit       OR
         :OLD.mx_designate_slot     != :NEW.mx_designate_slot    OR
         :OLD.case_length           != :NEW.case_length          OR
         :OLD.case_width            != :NEW.case_width           OR
         :OLD.case_height           != :NEW.case_height          OR
         :OLD.g_weight              != :NEW.g_weight             OR
         :OLD.spc                   != :NEW.spc                  OR
         :OLD.mx_upc_present_flag   != :NEW.mx_upc_present_flag  OR
         :OLD.mx_multi_upc_problem  != :NEW.mx_multi_upc_problem OR
         :OLD.mx_hazardous_type     != :NEW.mx_hazardous_type    OR
         :OLD.mx_food_type          != :NEW.mx_food_type         OR
         :OLD.mx_eligible           != :NEW.mx_eligible          OR
         nvl(:OLD.mx_item_assign_flag, 'N')   != :NEW.mx_item_assign_flag  OR
         nvl(:OLD.mx_stability_flag, 'N')      != :NEW.mx_stability_flag
      THEN
    
          IF INSERTING THEN

             IF :NEW.mx_item_assign_flag = 'Y' THEN
                   pl_mx_swms_to_pm_out.sys01_pm_out
                   (i_func_code              => 'A',
                    i_prod_id                => :NEW.prod_id,
                    i_description            => :NEW.descrip,
                    i_warehouse_area         => :NEW.area,
                    i_pack                   => :NEW.pack,
                    i_prod_size              => :NEW.prod_size,
                    i_prod_size_unit         => :NEW.prod_size_unit,
                    i_slotting_flag          => :NEW.mx_designate_slot,
                    i_length                 => :NEW.case_length,
                    i_width                  => :NEW.case_width,
                    i_height                 => :NEW.case_height,
                    i_weight                 => :NEW.g_weight,
                    i_spc                    => :NEW.spc,
                    i_upc_present_flag       => :NEW.mx_upc_present_flag,
                    i_problem_upc_flag       => :NEW.mx_multi_upc_problem,
                    i_hazardous_type         => :NEW.mx_hazardous_type,
                    i_mx_food_type           => :NEW.mx_food_type,
                    i_mx_select_eligibility  => :NEW.mx_eligible,
                    i_mx_item_assign_flag    => :NEW.mx_item_assign_flag,
                    i_sku_tip_flag           => :NEW.mx_stability_flag);

             END IF;
             
          END IF;
      
        pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                            'Trigger PM 3',
                             NULL, NULL);

         IF UPDATING THEN

            pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                                'Trigger PM 4',
                                 NULL, NULL);
               IF NVL(:OLD.mx_item_assign_flag, 'N') = 'N' AND :NEW.mx_item_assign_flag = 'Y' THEN
        
                   pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                                       'Trigger PM 5',
                                        NULL, NULL);

                   pl_mx_swms_to_pm_out.sys01_pm_out
                      (i_func_code              => 'A',
                       i_prod_id                => :NEW.prod_id,
                       i_description            => :NEW.descrip,
                       i_warehouse_area         => :NEW.area,
                       i_pack                   => :NEW.pack,
                       i_prod_size              => :NEW.prod_size,
                       i_prod_size_unit         => :NEW.prod_size_unit,
                       i_slotting_flag          => :NEW.mx_designate_slot,
                       i_length                 => :NEW.case_length,
                       i_width                  => :NEW.case_width,
                       i_height                 => :NEW.case_height,
                       i_weight                 => :NEW.g_weight,
                       i_spc                    => :NEW.spc,
                       i_upc_present_flag       => :NEW.mx_upc_present_flag,
                       i_problem_upc_flag       => :NEW.mx_multi_upc_problem,
                       i_hazardous_type         => :NEW.mx_hazardous_type,
                       i_mx_food_type           => :NEW.mx_food_type,
                       i_mx_select_eligibility  => :NEW.mx_eligible,
                       i_mx_item_assign_flag    => :NEW.mx_item_assign_flag,
                       i_sku_tip_flag           => :NEW.mx_stability_flag);

               ELSE
        
                   pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                                       'Trigger PM 6',
                                       NULL, NULL);
                   pl_mx_swms_to_pm_out.sys01_pm_out
                      (i_func_code              => 'U',
                       i_prod_id                => :NEW.prod_id,
                       i_description            => :NEW.descrip,
                       i_warehouse_area         => :NEW.area,
                       i_pack                   => :NEW.pack,
                       i_prod_size              => :NEW.prod_size,
                       i_prod_size_unit         => :NEW.prod_size_unit,
                       i_slotting_flag          => :NEW.mx_designate_slot,
                       i_length                 => :NEW.case_length,
                       i_width                  => :NEW.case_width,
                       i_height                 => :NEW.case_height,
                       i_weight                 => :NEW.g_weight,
                       i_spc                    => :NEW.spc,
                       i_upc_present_flag       => :NEW.mx_upc_present_flag,
                       i_problem_upc_flag       => :NEW.mx_multi_upc_problem,
                       i_hazardous_type         => :NEW.mx_hazardous_type,
                       i_mx_food_type           => :NEW.mx_food_type,
                       i_mx_select_eligibility  => :NEW.mx_eligible,
                       i_mx_item_assign_flag    => :NEW.mx_item_assign_flag,
                       i_sku_tip_flag           => :NEW.mx_stability_flag);

               END IF;
                 pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                                     'Trigger PM 7',
                                      NULL, NULL);
         END IF;
         
      END IF;
      
  END IF;
 
   pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                       'Trigger PM 8',
                        NULL, NULL);
EXCEPTION
WHEN OTHERS
THEN
RAISE;
END trg_ins_upd_del_pm;
/