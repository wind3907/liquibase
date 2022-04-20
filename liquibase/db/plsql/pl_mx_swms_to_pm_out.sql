CREATE OR REPLACE PACKAGE SWMS.pl_mx_swms_to_pm_out AUTHID CURRENT_USER
IS
  /*===========================================================================================================
  -- Package
  -- pl_mx_swms_to_pm_out
  --
  -- Description
  --  This package is invoked by a trigger on pm table.
  --  This package collects the data from pm table and send a message to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 08/18/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
   pm_insert_del    VARCHAR2(1) := 'N';
PROCEDURE sys01_pm_out(
      i_func_code             IN VARCHAR2,
      i_prod_id               IN pm.prod_id%type,
      i_description           IN VARCHAR2,
      i_warehouse_area        IN pm.area%type,
      i_pack                  IN pm.pack%type,
      i_prod_size             IN pm.prod_size%type,
      i_prod_size_unit        IN pm.prod_size_unit%type,
      i_slotting_flag         IN pm.mx_designate_slot%type,
      i_length                IN pm.case_length%type,
      i_width                 IN pm.case_width%type,
      i_height                IN pm.case_height%type,
      i_weight                IN pm.g_weight%type,
      i_spc                   IN pm.spc%type,
      i_upc_present_flag      IN pm.mx_upc_present_flag%type,
      i_problem_upc_flag      IN pm.mx_multi_upc_problem%type,
      i_hazardous_type        IN pm.mx_hazardous_type%type,
      i_mx_food_type          IN pm.mx_food_type%type,
      i_mx_select_eligibility IN pm.mx_eligible%type,
      i_mx_item_assign_flag   IN pm.mx_item_assign_flag%type,
      i_sku_tip_flag          IN pm.mx_stability_flag%type);
  END pl_mx_swms_to_pm_out;
/

CREATE OR REPLACE PACKAGE BODY SWMS.pl_mx_swms_to_pm_out
IS
  /*===========================================================================================================
  -- Package
  -- pl_mx_swms_to_pm_out
  --
  -- Description
  --  This package is invoked by a trigger on pm table.
  --  This package collects the data from pm table and send a message to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 08/27/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
PROCEDURE sys01_pm_out(
      i_func_code             IN VARCHAR2,
      i_prod_id               IN pm.prod_id%type,
      i_description           IN VARCHAR2,
      i_warehouse_area        IN pm.area%type,
      i_pack                  IN pm.pack%type,
      i_prod_size             IN pm.prod_size%type,
      i_prod_size_unit        IN pm.prod_size_unit%type,
      i_slotting_flag         IN pm.mx_designate_slot%type,
      i_length                IN pm.case_length%type,
      i_width                 IN pm.case_width%type,
      i_height                IN pm.case_height%type,
      i_weight                IN pm.g_weight%type,
      i_spc                   IN pm.spc%type,
      i_upc_present_flag      IN pm.mx_upc_present_flag%type,
      i_problem_upc_flag      IN pm.mx_multi_upc_problem%type,
      i_hazardous_type        IN pm.mx_hazardous_type%type,
      i_mx_food_type          IN pm.mx_food_type%type,
      i_mx_select_eligibility IN pm.mx_eligible%type,
      i_mx_item_assign_flag   IN pm.mx_item_assign_flag%type,
      i_sku_tip_flag          IN pm.mx_stability_flag%type)
  /*===========================================================================================================
  -- Procedure
  -- sys01_pm_out
  --
  -- Description
  --   This Procedure is invoked by a trigger name ' ' on pm table and sends a message to symbotic
  --   about the change.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 08/27/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
PRAGMA AUTONOMOUS_TRANSACTION;
------------------------------local variables-----------------------------------
      l_func_code              VARCHAR2(1);
      l_prod_id                pm.prod_id%type;
      l_description            VARCHAR2(50);
      l_warehouse_area         pm.area%type;
      l_pack                   pm.pack%type;
      l_prod_size              pm.prod_size%type;
      l_prod_size_unit         pm.prod_size_unit%type;
      l_length                 pm.case_length%type;
      l_width                  pm.case_width%type;
      l_height                 pm.case_height%type;
      l_weight                 pm.g_weight%type;
      l_spc                    pm.spc%type;
      l_case_weight            pm.g_weight%type;
      l_upc_present_flag       pm.mx_upc_present_flag%type;
      l_problem_upc_flag       pm.mx_multi_upc_problem%type;
      l_hazardous_type         pm.mx_hazardous_type%type;
      l_mx_food_type           pm.mx_food_type%type;
      l_mx_select_eligibility  pm.mx_eligible%type;
      l_mx_item_assign_flag    pm.mx_item_assign_flag%type;
      l_sys_msg_id             matrix_pm_out.sys_msg_id%type;
      l_upc                    pm_upc.external_upc%type;
      l_cust_rot_rules         matrix_pm_out.customer_rot_rule_flag%type;
      l_expiration_window      mx_food_type.mx_days_rotate_allow%type;
      l_slotting_flag          pm.mx_designate_slot%type;
      l_sku_tip_flag           pm.mx_stability_flag%type;
      l_brand                  pm.brand%type;
      l_sequence_number        NUMBER;
      l_error_msg              VARCHAR2(100);
      l_error_code             VARCHAR2(100);
      validation_exception     EXCEPTION;
CURSOR c_upc
  IS
    SELECT 
  DISTINCT external_upc
      FROM pm_upc
     WHERE prod_id = l_prod_id;

BEGIN

------------------------Initializing the local variables------------------------
      l_func_code             := i_func_code;
      l_prod_id               := i_prod_id;
      l_description           := i_description;
      l_warehouse_area        := i_warehouse_area;
      l_pack                  := i_pack;
      l_prod_size             := i_prod_size;
      l_prod_size_unit        := i_prod_size_unit;
      l_length                := i_length;
      l_width                 := i_width;
      l_height                := i_height;
      l_weight                := i_weight;
      l_spc                   := i_spc;
      l_upc_present_flag      := i_upc_present_flag;
      l_problem_upc_flag      := i_problem_upc_flag;
      l_hazardous_type        := i_hazardous_type;
      l_mx_food_type          := i_mx_food_type;
      l_mx_select_eligibility := i_mx_select_eligibility;
      l_mx_item_assign_flag   := i_mx_item_assign_flag;
      l_slotting_flag         := i_slotting_flag;
      l_sku_tip_flag          := i_sku_tip_flag;


-------------------------Calculating the Case Weight----------------------------
l_case_weight := (l_weight * l_spc);
-------------------------Generating the sys_msg_id and sequence number------------------------------
l_sys_msg_id  := mx_sys_msg_id_seq.nextval();

-------------------------Need to work on slotting flag
---------------Defaulting the customer rotation rule flag to 'Y'----------------
l_cust_rot_rules := 'Y';
------------------------Calculating the Expiration Window-----------------------
BEGIN

SELECT mft.mx_days_rotate_allow
  INTO l_expiration_window
  FROM mx_food_type mft, pm
 WHERE mft.mx_food_type = pm.mx_food_type
   AND pm.prod_id       = l_prod_id ;

EXCEPTION
WHEN OTHERS THEN
RAISE validation_exception;
END;

------------Modifying the description as per the Bussiness----------------------
-------------Description format(pm): brand_pack/size_descrip--------------------
---------------------Getting the brand value from pm----------------------------
BEGIN

SELECT pm.brand
  INTO l_brand
  FROM pm
 WHERE pm.prod_id  = l_prod_id ;

EXCEPTION
WHEN OTHERS THEN
RAISE validation_exception;
END;

---------------------Generating the decsription String--------------------------

BEGIN

l_description  := l_brand||'_'||l_pack||'/'||l_prod_size||'_'||l_description;

EXCEPTION
WHEN OTHERS THEN
l_error_msg := sqlerrm;
RAISE validation_exception;
END;


------Inserting the new row into the staging table as a header record-----------

BEGIN
  INSERT INTO matrix_pm_out
  (sys_msg_id, interface_ref_doc, rec_ind, func_code,
   prod_id, description, warehouse_area, pack, prod_size, prod_size_unit,
   slotting_flag,
   case_length, case_width, case_height, weight, upc_present_flag,
   problem_case_upc_flag, hazardous_type, food_type, mx_sel_eligibility_flag,
   mx_item_assign_flag, customer_rot_rule_flag, expiration_window
   , sku_tip_flag
   )
   VALUES
   (l_sys_msg_id, 'SYS01', 'H', l_func_code,
    l_prod_id, l_description, l_warehouse_area, l_pack, l_prod_size, l_prod_size_unit,
    l_slotting_flag,
    l_length, l_width, l_height, l_case_weight, l_upc_present_flag,
    l_problem_upc_flag, l_hazardous_type, l_mx_food_type, l_mx_select_eligibility,
    l_mx_item_assign_flag, l_cust_rot_rules, l_expiration_window
   , l_sku_tip_flag
   );
 EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK;
 RAISE validation_exception;
 END;


--Inserting child rows with the upc data into staging table as a child record---

FOR i in c_upc
LOOP
EXIT WHEN c_upc%NOTFOUND;
IF lpad(i.external_upc,14,'0') != '00000000000000' THEN
 BEGIN
  INSERT INTO matrix_pm_out
  (sys_msg_id, interface_ref_doc, rec_ind, func_code,
   prod_id, description, upc
   )
   VALUES
   (l_sys_msg_id, 'SYS01', 'D', l_func_code,
    l_prod_id, l_description, i.external_upc
   );
 EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK;
  RAISE validation_exception;
 END;
 END IF;
END LOOP;
COMMIT;


BEGIN
    dbms_scheduler.create_job
    (
      job_name        =>  'SYS01_WEBSERVICE_'||l_sys_msg_id,
      job_type        =>  'PLSQL_BLOCK',
      job_action      =>  'BEGIN pl_xml_matrix_out . sys01_item_master ('||l_sys_msg_id||'); END;',
      start_date      =>  SYSDATE,
      enabled         =>  TRUE,
      auto_drop       =>  TRUE,
      comments        =>  'Submiting a job to invoke SYS01 webservice');
EXCEPTION
WHEN OTHERS THEN
l_error_msg := sqlerrm;
  RAISE validation_exception;
END;

EXCEPTION
WHEN validation_exception THEN
--need to raise an alert
--commit;
--WHEN OTHERS THEN
NULL;
END sys01_pm_out;
END pl_mx_swms_to_pm_out;
/


CREATE OR REPLACE PUBLIC SYNONYM pl_mx_swms_to_pm_out FOR swms.pl_mx_swms_to_pm_out;

grant execute on swms.pl_mx_swms_to_pm_out to swms_user;

grant execute on swms.pl_mx_swms_to_pm_out to swms_matrix;