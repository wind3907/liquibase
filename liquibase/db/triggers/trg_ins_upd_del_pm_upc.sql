CREATE OR REPLACE 
TRIGGER trg_ins_upd_del_pm_upc
--------------------------------------------------------------------
   -- trg_ins_upd_del_pm.sql
   --
   -- Description:
   --     This script contains a trigger which sends a SYS01 message to symbotic
   --     by calling a Package.
   --
   -- Modification History:
   --    Date      Designer Comments
   --    --------- -------- -------------------------------------------
   --    12-Jun-15 Sunil Ontipalli Created as part of the Symbotic Integration
--------------------------------------------------------------------
AFTER DELETE or INSERT or UPDATE
ON swms.pm_upc
FOR EACH ROW
DECLARE
      l_prod_id                pm.prod_id%type;
      l_descrip                pm.descrip%type;
      l_area                   pm.area%type;
      l_pack                   pm.pack%type;
      l_prod_size              pm.prod_size%type;
      l_prod_size_unit         pm.prod_size_unit%type;
      l_length                 pm.case_length%type;
      l_width                  pm.case_width%type;
      l_height                 pm.case_height%type;
      l_weight                 pm.g_weight%type;
      l_spc                    pm.spc%type;
      l_upc_present_flag       pm.mx_upc_present_flag%type;
      l_problem_upc_flag       pm.mx_multi_upc_problem%type;
      l_hazardous_type         pm.mx_hazardous_type%type;
      l_mx_food_type           pm.mx_food_type%type;
      l_mx_select_eligibility  pm.mx_eligible%type;
      l_mx_item_assign_flag    pm.mx_item_assign_flag%type;
      l_slotting_flag          pm.mx_designate_slot%type;
      l_sku_tip_flag           pm.mx_stability_flag%type;
      l_brand                  pm.brand%type;
BEGIN

 pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                     'Trigger PM_UPC 1',
                      NULL, NULL);
                      
  l_prod_id := :NEW.prod_id;

  IF (INSERTING OR DELETING OR (UPDATING AND :OLD.external_upc != :NEW.external_upc)) AND pl_mx_swms_to_pm_out.pm_insert_del = 'N' THEN
  
   BEGIN
  
      SELECT descrip, area, pack, prod_size, prod_size_unit, mx_designate_slot, case_length, case_width,
             case_height, g_weight, spc, mx_upc_present_flag, mx_multi_upc_problem, mx_hazardous_type,
             mx_food_type, mx_eligible, mx_item_assign_flag, mx_stability_flag
        INTO l_descrip, l_area, l_pack, l_prod_size, l_prod_size_unit, l_slotting_flag, l_length, l_width, 
             l_height, l_weight, l_spc, l_upc_present_flag, l_problem_upc_flag, l_hazardous_type, 
             l_mx_food_type, l_mx_select_eligibility, l_mx_item_assign_flag, l_sku_tip_flag
        FROM pm
       WHERE prod_id = l_prod_id;
   EXCEPTION
    WHEN OTHERS THEN
      pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                     'Trigger PM_UPC 1 ERROR',
                      SQLCODE, SQLERRM);	
   END; 
  
  IF nvl(l_mx_item_assign_flag, 'N') = 'Y' THEN

         pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                             'Trigger PM_UPC 2',
                              NULL, NULL);

      IF DELETING THEN
           pl_mx_swms_to_pm_out.sys01_pm_out
             (i_func_code              => 'U',
              i_prod_id                =>  l_prod_id,                
              i_description            =>  l_descrip,                
              i_warehouse_area         =>  l_area,                   
              i_pack                   =>  l_pack,                   
              i_prod_size              =>  l_prod_size,              
              i_prod_size_unit         =>  l_prod_size_unit,         
              i_slotting_flag          =>  l_slotting_flag,                 
              i_length                 =>  l_length,                 
              i_width                  =>  l_width,                  
              i_height                 =>  l_height,                 
              i_weight                 =>  l_weight,                 
              i_spc                    =>  l_spc,                    
              i_upc_present_flag       =>  l_upc_present_flag,       
              i_problem_upc_flag       =>  l_problem_upc_flag,       
              i_hazardous_type         =>  l_hazardous_type,         
              i_mx_food_type           =>  l_mx_food_type,           
              i_mx_select_eligibility  =>  l_mx_select_eligibility,  
              i_mx_item_assign_flag    =>  l_mx_item_assign_flag,    
              i_sku_tip_flag           =>  l_sku_tip_flag);         
      END IF;                                            


      IF INSERTING THEN

             pl_mx_swms_to_pm_out.sys01_pm_out
             (i_func_code              => 'U',
              i_prod_id                =>  l_prod_id,                
              i_description            =>  l_descrip,                
              i_warehouse_area         =>  l_area,                   
              i_pack                   =>  l_pack,                   
              i_prod_size              =>  l_prod_size,              
              i_prod_size_unit         =>  l_prod_size_unit,         
              i_slotting_flag          =>  l_slotting_flag,                 
              i_length                 =>  l_length,                 
              i_width                  =>  l_width,                  
              i_height                 =>  l_height,                 
              i_weight                 =>  l_weight,                 
              i_spc                    =>  l_spc,                    
              i_upc_present_flag       =>  l_upc_present_flag,       
              i_problem_upc_flag       =>  l_problem_upc_flag,       
              i_hazardous_type         =>  l_hazardous_type,         
              i_mx_food_type           =>  l_mx_food_type,           
              i_mx_select_eligibility  =>  l_mx_select_eligibility,  
              i_mx_item_assign_flag    =>  l_mx_item_assign_flag,    
              i_sku_tip_flag           =>  l_sku_tip_flag); 

      END IF;

        pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                            'Trigger PM_UPC 3',
                             NULL, NULL);

      IF UPDATING THEN

            pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                                'Trigger PM_UPC 4',
                                 NULL, NULL);
         pl_mx_swms_to_pm_out.sys01_pm_out
             (i_func_code              => 'U',
              i_prod_id                =>  l_prod_id,                
              i_description            =>  l_descrip,                
              i_warehouse_area         =>  l_area,                   
              i_pack                   =>  l_pack,                   
              i_prod_size              =>  l_prod_size,              
              i_prod_size_unit         =>  l_prod_size_unit,         
              i_slotting_flag          =>  l_slotting_flag,                 
              i_length                 =>  l_length,                 
              i_width                  =>  l_width,                  
              i_height                 =>  l_height,                 
              i_weight                 =>  l_weight,                 
              i_spc                    =>  l_spc,                    
              i_upc_present_flag       =>  l_upc_present_flag,       
              i_problem_upc_flag       =>  l_problem_upc_flag,       
              i_hazardous_type         =>  l_hazardous_type,         
              i_mx_food_type           =>  l_mx_food_type,           
              i_mx_select_eligibility  =>  l_mx_select_eligibility,  
              i_mx_item_assign_flag    =>  l_mx_item_assign_flag,    
              i_sku_tip_flag           =>  l_sku_tip_flag); 

              
           pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                                     'Trigger PM_UPC 5',
                                      NULL, NULL);

      END IF;

  END IF;

 END IF;

   pl_text_log.ins_msg('INFO', 'sys01_pm_out',
                       'Trigger PM_UPC 6',
                        NULL, NULL);
EXCEPTION
WHEN OTHERS
THEN
RAISE;
END trg_ins_upd_del_pm;
/