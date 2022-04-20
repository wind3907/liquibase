CREATE OR REPLACE TRIGGER trg_upd_pm_chk_elg
--------------------------------------------------------------------
   -- trg_upd_pm_chk_elg.sql
   --
   -- Description:
   --     This script contains a trigger which calculates the eligibility
   --     and updates the pm table eligibility flag.
   --
   -- Modification History:
   --    Date      Designer Comments
   --    --------- -------- -------------------------------------------
   --    16-oct-14 Sunil Ontipalli Created as part of the Symbotic Integration
   --    29-Dec-14 Sunil Ontipalli Modified to include g_form_check global varibale
   --    12-Jan-15 Sunil Ontipalli Updated the trigger to check, whether eligibility calc needed or not.
   --    12-Jan-15 Sunil Ontipalli It will not fire Unnecessary if length, width and height is changed, Until unless it has all the info.
   --    12-Jan-15 Sunil Ontipalli Updated the trigger to raise the application error for changing 7 fileds listed below in the code.
--------------------------------------------------------------------
BEFORE  UPDATE
ON swms.pm
FOR EACH ROW
DECLARE
validation_error EXCEPTION;
BEGIN

   IF PL_VR_MATRIX_ELIGIBLE.G_FORM_CHECK = 'N' THEN
      
       pl_text_log.ins_msg('INFO', 'eligibility',
                'Trigger PM ELIGIBLE 1',
                NULL, NULL);
  
     
     IF  nvl(:OLD.diagonal_measurement, -1)   !=  nvl(:NEW.diagonal_measurement, -1)  OR
         nvl(:OLD.recalc_length, -1)          !=  nvl(:NEW.recalc_length, -1)         OR
         nvl(:OLD.recalc_width, -1)           !=  nvl(:NEW.recalc_width, -1)          OR
         nvl(:OLD.recalc_height, -1)          !=  nvl(:NEW.recalc_height, -1)         OR
         nvl(:OLD.mx_stability_recalc, -1)    !=  nvl(:NEW.mx_stability_recalc, -1)   OR
         nvl(:OLD.mx_stability_calc, -1)      !=  nvl(:NEW.mx_stability_calc, -1)     OR
         nvl(:OLD.mx_eligible, 'X-')          !=  nvl(:NEW.mx_eligible, 'X-')               
      THEN
      RAISE validation_error;
     END IF; 
     /*IF UPDATE (diagonal_measurement) THEN
       RAISE validation_error;
     END IF;*/
   
   
     IF :NEW.mx_master_case_flag IS NOT NULL AND :NEW.auto_ship_flag IS NOT NULL AND 
      :NEW.mx_package_type IS NOT NULL AND :NEW.mx_hazardous_type IS NOT NULL THEN
   
        IF  nvl(:OLD.mx_master_case_flag, 'X-')   !=  nvl(:NEW.mx_master_case_flag, 'X-')  OR
            nvl(:OLD.auto_ship_flag, 'X-')        !=  nvl(:NEW.auto_ship_flag, 'X-')       OR
            nvl(:OLD.mx_package_type, 'X-')       !=  nvl(:NEW.mx_package_type, 'X-')      OR
            nvl(:OLD.mx_hazardous_type, 'X-')     !=  nvl(:NEW.mx_hazardous_type, 'X-')    OR
            nvl(:OLD.case_length, -1)             !=  nvl(:NEW.case_length, -1)            OR
            nvl(:OLD.case_width, -1)              !=  nvl(:NEW.case_width, -1)             OR
            nvl(:OLD.case_height, -1)             !=  nvl(:NEW.case_height, -1)            OR
            nvl(:OLD.g_weight, -1)                !=  nvl(:NEW.g_weight, -1)          
        THEN
 
          pl_text_log.ins_msg('INFO', 'eligibility',
                              'Trigger PM ELIGIBLE 2',
                              NULL, NULL);

           --IF :OLD.mx_item_assign_flag = 'Y' OR :NEW.mx_item_assign_flag = 'Y' THEN

           IF UPDATING THEN

              pl_vr_matrix_eligible.chk_item_eligible
              (i_mx_eligible              => :NEW.mx_eligible,
               i_auto_ship_flag           => :NEW.auto_ship_flag,
               i_mx_master_case_flag      => :NEW.mx_master_case_flag,
               i_mx_package_type          => :NEW.mx_package_type,
               i_mx_hazardous_type        => :NEW.mx_hazardous_type,
               i_case_length              => :NEW.case_length,
               i_case_width               => :NEW.case_width,
               i_case_height              => :NEW.case_height,
               i_recal_length             => :NEW.recalc_length,
               i_recal_width              => :NEW.recalc_width,
               i_recal_height             => :NEW.recalc_height,
               i_spc                      => :NEW.spc,
               i_g_weight                 => :NEW.g_weight,
               i_mx_item_assign_flag      => :NEW.mx_item_assign_flag,
               i_area                     => :NEW.area,
               i_mx_why_not_eligible      => :NEW.mx_why_not_eligible,
               i_diagonal_measurement     => :NEW.diagonal_measurement,
               i_mx_stability_calc        => :NEW.mx_stability_calc,
               i_mx_stability_flag        => :NEW.mx_stability_flag,
               i_mx_stability_recalc      => :NEW.mx_stability_recalc);
         
                pl_text_log.ins_msg('INFO', 'eligibility',
                                    'Trigger PM ELIGIBLE 3',
                                     NULL, NULL);

           END IF;
         
           --END IF;
        
        END IF;

     END IF;
   
   END IF;  

EXCEPTION
WHEN validation_error THEN
raise_application_error(-20001, 'You cannot update the fields listed: Diagonal_measurement, Recalc_length, 
                                 Recalc_width, Recalc_height, mx_stability_recalc, mx_stability_calc, mx_eligible');

WHEN OTHERS THEN
RAISE;
END trg_upd_pm_chk_elg;
/