CREATE OR REPLACE PACKAGE      pl_matrix_common AUTHID CURRENT_USER IS 
-----------------------------------------------------------------------------
-- Package Name:
--    pl_matrix_common
--
-- Description:
--    This package contain all the common functions and procedures require
--    for the matrix system.
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    07/14/14 ayad5195 Initial Creation
--    07/25/14 knha8378 Adding function chk_loc_maintainable return true or false
--    08/14/14 vred5319 Adding function allow_adj_swms to return true or false
--    08/18/14 vred5319 Adding function chk_item_assignable to return true or false
--
--    01/21/15 bben0556 Added function "ok_to_alloc_to_vrt_in_this_loc"
--    02/15/15 bben0556 Added function "f_get_mx_msku_dest_loc"
--    08/24/15 ayad5195 Changed populate_mx_wave_number, if all immediate_ind ='Y' 
--                      then only only send wave number as 0, else original wave number
--   08/19/2016 pdas8114 Changed sos_batch_to_matrix_yn to not include chemical batch
-----------------------------------------------------------------------------




---------------------------------------------------------------------------
-- Function:
--    chk_matrix_enable
--
-- Description:
--    Check if matrix system is available in the database
--
---------------------------------------------------------------------------
Ct_Program_Code CONSTANT VARCHAR2 (50) := 'PL_MATRIX_COMMON';
l_success       CONSTANT NUMBER := 0;
l_failure       CONSTANT NUMBER := 1;

TYPE t_phys_loc   IS TABLE OF loc.logi_loc%TYPE INDEX BY BINARY_INTEGER;

FUNCTION chk_matrix_enable RETURN BOOLEAN;

FUNCTION chk_loc_maintainable (i_loc_ai_zn_type  IN VARCHAR2,
                               i_loc_ai_zn_value IN VARCHAR2,
                               o_exception_message OUT VARCHAR2) RETURN VARCHAR2;

FUNCTION allow_adj_swms(i_loc_value IN VARCHAR2,
                        o_exception_message OUT VARCHAR2) RETURN VARCHAR2;

FUNCTION chk_item_assignable(i_item_value IN VARCHAR2,
                             o_exception_message OUT VARCHAR2) RETURN VARCHAR2;
                             
FUNCTION get_sys_config_val(i_config_name IN VARCHAR2) RETURN VARCHAR2;

FUNCTION Matrix_Qty(i_Item_Number        IN VARCHAR2,
                    i_cpv                IN VARCHAR2
                   )
       RETURN NUMBER;
  
FUNCTION Matrix_Qty1(i_Item_Number        IN VARCHAR2,
                     i_cpv                IN VARCHAR2
                     )
       RETURN NUMBER;
                      
FUNCTION populate_matrix_out (i_sys_msg_id          IN NUMBER,
                              i_interface_ref_doc   IN VARCHAR2,
                              i_rec_ind             IN VARCHAR2,
                              i_label_type          IN VARCHAR2 DEFAULT NULL,
                              i_parent_pallet_id    IN VARCHAR2 DEFAULT NULL,   
                              i_pallet_id           IN VARCHAR2 DEFAULT NULL,
                              i_prod_id             IN VARCHAR2 DEFAULT NULL,
                              i_case_qty            IN NUMBER   DEFAULT NULL,
                              i_exp_date            IN DATE     DEFAULT NULL,
                              i_erm_id              IN VARCHAR2 DEFAULT NULL,
                              i_rec_count           IN NUMBER   DEFAULT NULL,
                              i_inv_status          IN VARCHAR2 DEFAULT NULL,
                              i_batch_comp_tstamp   IN VARCHAR2 DEFAULT NULL,
                              i_batch_id            IN VARCHAR2 DEFAULT NULL,
                              i_priority            IN NUMBER   DEFAULT NULL,
                              i_task_id             IN NUMBER   DEFAULT NULL,
                              i_order_gen_time      IN VARCHAR2 DEFAULT NULL,
                              i_exact_pallet_imp    IN VARCHAR2 DEFAULT NULL,
                              i_dest_loc            IN VARCHAR2 DEFAULT NULL,
                              i_trans_type          IN VARCHAR2 DEFAULT NULL,
                              i_wave_number         IN NUMBER   DEFAULT NULL,
                              i_ns_heavy_case_cnt   IN NUMBER   DEFAULT NULL,
                              i_ns_light_case_cnt   IN NUMBER   DEFAULT NULL,
                              i_order_id            IN VARCHAR2 DEFAULT NULL,
                              i_route               IN VARCHAR2 DEFAULT NULL,
                              i_stop                IN NUMBER   DEFAULT NULL,
                              i_order_type          IN VARCHAR2 DEFAULT NULL,
                              i_order_sequence      IN NUMBER   DEFAULT NULL,
                              i_priority_identifier IN NUMBER   DEFAULT NULL,   
                              i_cust_rotation_rules IN VARCHAR2 DEFAULT NULL,
                              i_float_id            IN NUMBER   DEFAULT NULL,
                              i_batch_status        IN VARCHAR2 DEFAULT NULL,
                              i_case_barcode        IN VARCHAR2 DEFAULT NULL,
                              i_spur_loc            IN VARCHAR2 DEFAULT NULL,
                              i_case_grab_tstamp    IN VARCHAR2 DEFAULT NULL 
                             ) 
 RETURN NUMBER;
                              
FUNCTION send_message_to_matrix (i_sys_msg_id  IN NUMBER) 
    RETURN NUMBER;
    
FUNCTION send_orders_to_matrix (i_wave_number IN NUMBER)
    RETURN NUMBER;
    
FUNCTION send_order_batch_to_matrix (i_wave_number IN NUMBER, i_batch_id IN VARCHAR2)
    RETURN NUMBER;
    
FUNCTION print_lpn_flag (i_repln_type IN VARCHAR2) 
     RETURN VARCHAR2;
     
FUNCTION chk_loc( i_loc_ai_zn_type  IN VARCHAR2,
                                i_loc_ai_zn_value IN VARCHAR2 ) RETURN VARCHAR2;

 PROCEDURE delete_ndm_repl (i_tabTask      IN pl_swms_execute_sql.tabTask,
                            i_RowCnt       IN NUMBER,
                            o_delCnt      OUT NUMBER) ;

 PROCEDURE delete_ndm_repl (i_last_qry     IN VARCHAR2,
                            io_RowCnt      IN OUT NUMBER);
                            
 FUNCTION f_get_pm_area (i_prod_id IN VARCHAR2)
     RETURN VARCHAR2;
     
 FUNCTION f_get_mx_dest_loc (i_prod_id IN VARCHAR2)
     RETURN VARCHAR2;

 PROCEDURE p_find_induction_loc
           (i_pallet_id            IN inv.logi_loc%TYPE,           
            io_num_of_req_loc      IN OUT NUMBER,
            o_avl_locations        OUT pl_matrix_common.t_phys_loc); 
            
  FUNCTION chk_prod_mx_assign(i_prod_id IN VARCHAR2)
     RETURN BOOLEAN;           
     
  FUNCTION chk_prod_mx_eligible(i_prod_id IN VARCHAR2)
     RETURN BOOLEAN;         
    
  FUNCTION get_batch_priority (i_priority_code IN VARCHAR2)
     RETURN NUMBER;
     
  FUNCTION sos_batch_to_matrix_yn (i_batch_no IN VARCHAR2)
     RETURN VARCHAR2;  
     
 FUNCTION mx_rpl_task_priority (i_task_type IN VARCHAR2,
                                i_severity  IN VARCHAR2)
     RETURN NUMBER;  
     
 FUNCTION f_get_mx_stg_loc (i_prod_id IN VARCHAR2)
     RETURN VARCHAR2;    
     
 FUNCTION insert_repl_sys05_label (i_caseBarCode        IN VARCHAR2,
                                   i_destLoc            IN VARCHAR2,
                                   i_pallet_id          IN VARCHAR2,
                                   i_prod_id            IN VARCHAR2,
                                   i_descrip            IN VARCHAR2,
                                   i_pack               IN VARCHAR2,
                                   i_prod_size          IN VARCHAR2,
                                   i_brand              IN VARCHAR2,
                                   i_type               IN VARCHAR2,
                                   i_sequence_number    IN NUMBER)
    RETURN NUMBER;
                    
 PROCEDURE refresh_spur_monitor (i_spur_loc IN VARCHAR2);             
 
 FUNCTION f_is_induction_loc_yn (i_loc    IN VARCHAR2) 
   RETURN VARCHAR2;


---------------------------------------------------------------------------
-- Function:
--    ok_to_alloc_to_vrt_in_this_loc
--
-- Description:
--    This function returns 'Y' if the inventory is in a location that
--    can be allocated to a VRT otherwise 'N' is returned.
--    ***** This will be determined by looking at the slot type *****
--
--    A log message is always created when checking the location since
--    VRTs are not that frequent.
--
--    Inventory on hold in a Symbotic location cannot be allocated
--    against a VRT.
--    01/21/15  The question is do we consider the induction
--    location, spur location and outduct or induction as
--    Symbotic locations concerning allocating to a VRT.
--    As of know we do.
---------------------------------------------------------------------------
FUNCTION ok_to_alloc_to_vrt_in_this_loc(i_plogi_loc IN inv.plogi_loc%TYPE)
RETURN VARCHAR2;


---------------------------------------------------------------------------
-- Function:
--    f_get_mx_msku_dest_loc
--
-- Description:
--    This function returns the location to direct the child LP's to on a
--    MSKU for a matrix item for a MSKU on a SN.
--    The location comes from one of three syspars with the area of the
--    item determining what syspar to use.  The location will either be
--    the matrix induction location or the matrix staging location.
--
--    The rule is a mtrix item on MSKU will always be directed to the
--    what is designated by syspars:
--       - MX_MSKU_STAGING_OR_INDUCT_DRY
--       - MX_MSKU_STAGING_OR_INDUCT_CLR
--       - MX_MSKU_STAGING_OR_INDUCT_FRZ
FUNCTION f_get_mx_msku_dest_loc
            (i_prod_id           IN pm.prod_id%TYPE,
             i_cust_pref_vendor  IN pm.cust_pref_vendor%TYPE)
RETURN VARCHAR2;

--Populate mx_wave_number in route table and later use this value to send SYS04
PROCEDURE populate_mx_wave_number (i_wave_number     IN NUMBER);

END pl_matrix_common;
/

show errors


CREATE OR REPLACE PACKAGE BODY      pl_matrix_common IS

/*=============================================================================================
 This package contain all the common functions and procedures require for the matrix system

Modification History
Date           Designer         Comments
-----------    ---------------  --------------------------------------------------------
14-JUL-2014    ayad5195         Initial Creation

=============================================================================================*/


---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := $$PLSQL_UNIT;   -- Package name.
                                              -- Used in error messages.



--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function      VARCHAR2(20) := 'INVENTORY';



---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------










/*---------------------------------------------------------------------------
 Function:
    chk_matrix_enable

 Description:
    Check if matrix system is available in the database

 Parameter:
      N/A

 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    14-JUL-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/

FUNCTION chk_matrix_enable RETURN BOOLEAN IS
   l_matrix_cnt NUMBER;
BEGIN
   SELECT COUNT(*)
     INTO l_matrix_cnt
     FROM zone
    WHERE rule_id = 5;

   IF l_matrix_cnt > 0 THEN
     RETURN TRUE;
   ELSE
     RETURN FALSE;
   END IF;
END chk_matrix_enable;


/*===============================================================================

Description
 check for the maintainable flag to see if this location, aisle or zone maintainable or not
 1. i_loc_ai_zn_type valid values are AI, LOC, ZN;
 2. AI==Aisle check,LOC=Location Check,ZN==Zone check
 3. i_loc_ai_zn_value is the location, aisle name or zone id value.
 4. This function returns 3 varchar2 datatype values: TRUE,FALSE,EXCEPTION
 5. When there is an EXCEPTION then o_exception_message must have a value justifying why

 MODIFICATION HISTORY

 DATE             DESIGNER        COMMENTS
 ----------------------------------------------------------------------------------------------
 24-JUL-2014      Kiet Nhan       INITIAL CREATION
 11-AUG-2014      Vani Reddy      Added outer join to handle blank rule_id's for zone check
 12-AUG-2014      Vani Reddy      Added rownum to handle too many reccords
 12-AUG-2014      Vani Reddy      Modified to return 'TRUE' when no data found as they may not have lzone record etc
 27-AUG-2014      Vani Reddy      Added slot validation
  ==============================================================================================*/


FUNCTION chk_loc_maintainable( i_loc_ai_zn_type  IN VARCHAR2,
                                i_loc_ai_zn_value IN VARCHAR2,
                                o_exception_message OUT VARCHAR2 ) RETURN VARCHAR2 IS
   l_true_or_false   varchar2(6);

BEGIN
if i_loc_ai_zn_type is not null and i_loc_ai_zn_value is not null then
   IF i_loc_ai_zn_type='LOC' THEN
      SELECT    decode(r.maintainable,'N','FALSE','TRUE')
       INTO     l_true_or_false
       FROM    lzone lz, zone z,rules r
     WHERE     z.rule_id = r.rule_id
       AND      lz.zone_id = z.zone_id
       AND      z.zone_type = 'PUT'
       AND      lz.logi_loc = i_loc_ai_zn_value;

   ELSIF i_loc_ai_zn_type='AI' THEN

     SELECT     decode(r.maintainable,'N','FALSE','TRUE')
     INTO       l_true_or_false
     FROM       lzone lz, zone z,aisle_info ai,rules r
     WHERE      z.rule_id = r.rule_id
      AND       lz.zone_id = z.zone_id
      AND       z.zone_type = 'PUT'
      AND       substr(lz.logi_loc,1,2) = ai.name
      AND       ai.name = i_loc_ai_zn_value
      AND       rownum = 1;                                                -- Vani Reddy added to handle too many records
      
   ELSIF i_loc_ai_zn_type='SLOT' THEN                                       -- Vani Reddy added slot validation
     BEGIN                                  
        SELECT       'TRUE'
          INTO        l_true_or_false
          FROM        slot_type s
         WHERE        slot_type not in ('MXI', 'MXC', 'MXF', 'MXS', 'MXO','MXT')
           AND        slot_type = i_loc_ai_zn_value;
     EXCEPTION
       WHEN NO_DATA_FOUND THEN
            l_true_or_false := 'FALSE';
     END;
     
   ELSIF i_loc_ai_zn_type='ZN' THEN

     SELECT       decode(r.maintainable,'N','FALSE','TRUE')
      INTO        l_true_or_false
      From        Zone Z, Rules R
     WHERE        z.rule_id = r.rule_id(+)                                  -- Vani Reddy added outer join to handle for blank rule_id in Zone
     AND          z.zone_id = i_loc_ai_zn_value;

   ELSE
      o_exception_message := 'Invalid type. Correct Type value is LOC, AI or ZN';
      return 'EXCEPTION';
   END IF;

   return l_true_or_false;

else
      o_exception_message := 'Developer passing Type and value as null;therefore, function failed.';
      return 'EXCEPTION';
end if;

 EXCEPTION
   WHEN NO_DATA_FOUND THEN
     /* Vani Reddy commented to return 'TRUE' when no data found as they may not have lzone record etc
        o_exception_message := 'No data found type:'||i_loc_ai_zn_type||' and for value:'||i_loc_ai_zn_value;
        return 'EXCEPTION';*/
      return 'TRUE';                                                           -- Vani Reddy added      
   WHEN TOO_MANY_ROWS THEN
     o_exception_message := 'Too Many Rows return type:'||i_loc_ai_zn_type||' and for value: '||i_loc_ai_zn_value;
      return 'EXCEPTION';

   WHEN OTHERS THEN
     o_exception_message := SQLERRM;
     return 'EXCEPTION';

 END chk_loc_maintainable;


/*===============================================================================
 Function: allow_adj_swms
 
Description
 checks to see if the slot_type for the location does not belong to matrix
 1. i_loc_value is the location 
 2. If the slot_type is not in ('MXC', 'MXF', 'MXS', 'MXO') function passes TRUE otherwise FALSE

 MODIFICATION HISTORY

 DATE             DESIGNER        COMMENTS
 ----------------------------------------------------------------------------------------------
 14-AUG-2014      Vani Reddy       INITIAL CREATION
==============================================================================================*/
FUNCTION allow_adj_swms(i_loc_value IN VARCHAR2,
                        o_exception_message OUT VARCHAR2) RETURN VARCHAR2 IS
   l_true_or_false   varchar2(5);
BEGIN 
   IF i_loc_value IS NOT NULL THEN
      SELECT   'TRUE'
        INTO   l_true_or_false
        FROM   loc 
      WHERE    slot_type not in ('MXI', 'MXC', 'MXF', 'MXS')
        AND    logi_loc = i_loc_value;
   ELSE
      o_exception_message :=  'User passing value is null, function failed.';
      l_true_or_false := 'FALSE'; 
   END IF;

   RETURN l_true_or_false;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      o_exception_message := 'No data found for value: '||i_loc_value;
      RETURN 'FALSE';                                                                                           
   WHEN TOO_MANY_ROWS THEN
      o_exception_message := 'Too Many Rows return for value: '||i_loc_value;
      RETURN 'FALSE';
   WHEN OTHERS THEN
      o_exception_message := SQLERRM;
      RETURN 'FALSE';
END allow_adj_swms;


/*===============================================================================
 Function: chk_item_assignable
 
Description
 checks to see if the item can be slotted to matrix
 1. i_item_value  is prod_id

 MODIFICATION HISTORY

 DATE             DESIGNER        COMMENTS
 ----------------------------------------------------------------------------------------------
 18-AUG-2014      Vani Reddy       INITIAL CREATION
==============================================================================================*/
FUNCTION chk_item_assignable(i_item_value IN VARCHAR2,
                             o_exception_message OUT VARCHAR2) RETURN VARCHAR2 IS
   l_true_or_false          varchar2(5);
   l_auto_ship_flag         varchar2(1);
   l_mx_eligible            varchar2(1);                                 
   l_mx_item_assign_flag    varchar2(1);  
   l_mx_max_case            number(4);   
   l_mx_min_case            number(4);              
   l_mx_food_type           varchar2(8);                           
   l_mx_upc_present_flag    varchar2(1);                                                
   l_mx_multi_upc_problem   varchar2(1);
              
BEGIN 
   IF i_item_value IS NOT NULL THEN
        SELECT  mx_eligible, 
                mx_item_assign_flag,
                mx_max_case, 
                mx_min_case,
                mx_food_type,                                   
                mx_upc_present_flag,                                                           
                mx_multi_upc_problem,
                auto_ship_flag
        INTO    l_mx_eligible,                                      
                l_mx_item_assign_flag, 
                l_mx_max_case, 
                l_mx_min_case,                             
                l_mx_food_type,                                   
                l_mx_upc_present_flag,                                                           
                l_mx_multi_upc_problem,
                l_auto_ship_flag
        FROM    pm
      WHERE    pm.prod_id =  i_item_value;
      
      l_true_or_false := null;
      
      IF nvl(l_auto_ship_flag, 'N') = 'Y' THEN
         o_exception_message := 'This is a ship split only item, cannot be slotted to matrix.';
         l_true_or_false := 'FALSE'; 
      ELSIF l_mx_eligible is null THEN
         o_exception_message := 'This item is not MatrixSelect eligible, cannot be assigned as requested.';
         l_true_or_false := 'FALSE'; 
      ELSIF nvl(l_mx_item_assign_flag, 'N') = 'Y' THEN
         o_exception_message := 'Item already assigned to matrix.';
         l_true_or_false := 'FALSE'; 
      END IF;
      
      IF l_mx_eligible = 'Y' THEN
         IF  nvl(l_mx_max_case, 0) = 0   
              or nvl(l_mx_min_case, 0) = 0  
              or l_mx_food_type is null                                   
              or l_mx_upc_present_flag is null                                                     
              or l_mx_multi_upc_problem is null THEN
            o_exception_message := 'Item not setup, cannot be slotted to matrix.'; 
            l_true_or_false := 'FALSE'; 
         ELSE 
            l_true_or_false := 'TRUE';
         END IF;
      END IF;
   ELSE
      o_exception_message :=  'User passing value for item is null;therefore, function failed.';
      l_true_or_false := 'FALSE'; 
   END IF;

   RETURN l_true_or_false;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      o_exception_message := 'No data found for value: '||i_item_value||' cannot be slotted to matrix.';
      RETURN 'FALSE';                                                                                           
   WHEN TOO_MANY_ROWS THEN
      o_exception_message := 'Too Many Rows return for value: '||i_item_value||' cannot be slotted to matrix.';
      RETURN 'FALSE';
   WHEN OTHERS THEN
      o_exception_message := SQLERRM;
      RETURN 'FALSE';
END chk_item_assignable; 


/*---------------------------------------------------------------------------
 Function:
    get_sys_config_val

 Description:
    Get the configuration value from table SYS_CONFIG for a configuration name

 Parameter:
      N/A

 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    01-AUG-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/
FUNCTION get_sys_config_val (i_config_name IN VARCHAR2) RETURN VARCHAR2 
IS   
  l_config_val   loc.logi_loc%TYPE;
BEGIN
  SELECT config_flag_val
    INTO l_config_val 
    FROM sys_config
   WHERE config_flag_name = i_config_name;
   
   RETURN l_config_val;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
End Get_Sys_Config_Val;
-------------------------------------------------------------------------------------
-- Matrix Quantity
-------------------------------------------------------------------------------------


Function Matrix_Qty(
    i_Item_Number        In Varchar2,
    i_cpv                in Varchar2
     )
  Return Number
Is
L_Qty Number;

    Cursor C1 Is
   Select Nvl(Sum(Decode(Inv.Inv_Uom,1, Inv.Qoh, Inv.Qoh/Pm.Spc) +
        decode(inv.inv_uom,1, inv.qty_planned, inv.qty_planned/pm.spc)),0) qty 
        FROM inv inv, pm pm
       Where Inv.Prod_Id          = I_Item_Number
         And Inv.Cust_Pref_Vendor = I_Cpv
         And Inv.Status           = 'AVL'
         AND inv.prod_id = pm.prod_id;
    
Begin
    Open C1;
   Fetch C1 Into L_Qty;

   If C1%Notfound Then
      RAISE NO_DATA_FOUND;
   end if;
   close c1;

RETURN L_Qty;

EXCEPTION
When NO_DATA_FOUND Then
   raise_application_error(-20001,'An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

end Matrix_Qty;


Function Matrix_Qty1(
    i_Item_Number        In Varchar2,
    i_cpv                in Varchar2
     )
  Return Number
Is
l_Qty Number;

    Cursor C1 Is
   SELECT Nvl(Sum(Decode(Inv.Inv_Uom,1, Inv.Qoh, Inv.Qoh/Pm.Spc) +
        decode(inv.inv_uom,1, inv.qty_planned, inv.qty_planned/pm.spc)),0) qty
        FROM inv, loc, pm
       WHERE inv.prod_id          = I_Item_Number
         AND inv.cust_pref_vendor = i_cpv
         AND pm.prod_id           = inv.prod_id
         AND pm.cust_pref_vendor  = inv.cust_pref_vendor
         AND inv.status           = 'AVL'
         AND inv.plogi_loc        = loc.logi_loc
         AND loc.slot_type IN ('MXC', 'MXF', 'MXI', 'MXT');
    
Begin
    Open C1;
   Fetch C1 Into L_Qty;

   If C1%Notfound Then
      RAISE NO_DATA_FOUND;
   end if;
   close c1;

Return l_Qty;

Exception
When NO_DATA_FOUND Then
   Raise_Application_Error(-20001,'An error was encountered - '||Sqlcode||' -ERROR- '||Sqlerrm);

End Matrix_Qty1;

/*---------------------------------------------------------------------------
 Function:
    populate_matrix_out

 Description:
    Insert record into matrix_out table 

 Parameter:
      Input:
          i_sys_msg_id               msg id
          i_interface_ref_doc        interface ref doc (SYS03, SYS04 etc)
          i_label_type               label type (LPN. MSKU)
          i_parent_pallet_id         Parent Pallet ID
          i_rec_ind                  Record Indicator (S-Single, H-Header, D-Detail)
          i_pallet_id                Pallet ID
          i_prod_id                  Prod ID
          i_case_qty                 Case Quantity
          i_exp_date                 Expiry Date
          i_erm_id                   ERM IDIN
          i_rec_count                Record Count
          i_inv_status               Invoice Status
          i_batch_comp_tstamp        Batch complete time stamp
          i_batch_id                 Batch ID
          i_priority                 Priority 
          i_task_id                  Task ID
          i_order_gen_time           Order generation time stamp
          i_exact_pallet_imp         Pallet Imp
          i_dest_loc                 Destination location
          i_trans_type               Transaction Type (NXL, NSP, MRL, PUT, DXL, DSP, UNA, MXL)
      Output:
          Status  : Success 0
                    Failure 1         

 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    29-AUG-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/

FUNCTION populate_matrix_out (i_sys_msg_id          IN NUMBER,
                              i_interface_ref_doc   IN VARCHAR2,
                              i_rec_ind             IN VARCHAR2,
                              i_label_type          IN VARCHAR2 DEFAULT NULL,
                              i_parent_pallet_id    IN VARCHAR2 DEFAULT NULL,   
                              i_pallet_id           IN VARCHAR2 DEFAULT NULL,
                              i_prod_id             IN VARCHAR2 DEFAULT NULL,
                              i_case_qty            IN NUMBER   DEFAULT NULL,
                              i_exp_date            IN DATE     DEFAULT NULL,
                              i_erm_id              IN VARCHAR2 DEFAULT NULL,
                              i_rec_count           IN NUMBER   DEFAULT NULL,
                              i_inv_status          IN VARCHAR2 DEFAULT NULL,
                              i_batch_comp_tstamp   IN VARCHAR2 DEFAULT NULL,
                              i_batch_id            IN VARCHAR2 DEFAULT NULL,
                              i_priority            IN NUMBER   DEFAULT NULL,
                              i_task_id             IN NUMBER   DEFAULT NULL,
                              i_order_gen_time      IN VARCHAR2 DEFAULT NULL,
                              i_exact_pallet_imp    IN VARCHAR2 DEFAULT NULL,
                              i_dest_loc            IN VARCHAR2 DEFAULT NULL,
                              i_trans_type          IN VARCHAR2 DEFAULT NULL,
                              i_wave_number         IN NUMBER   DEFAULT NULL,
                              i_ns_heavy_case_cnt   IN NUMBER   DEFAULT NULL,
                              i_ns_light_case_cnt   IN NUMBER   DEFAULT NULL,
                              i_order_id            IN VARCHAR2 DEFAULT NULL,
                              i_route               IN VARCHAR2 DEFAULT NULL,
                              i_stop                IN NUMBER   DEFAULT NULL,
                              i_order_type          IN VARCHAR2 DEFAULT NULL,
                              i_order_sequence      IN NUMBER   DEFAULT NULL,
                              i_priority_identifier IN NUMBER   DEFAULT NULL,   
                              i_cust_rotation_rules IN VARCHAR2 DEFAULT NULL,
                              i_float_id            IN NUMBER   DEFAULT NULL,
                              i_batch_status        IN VARCHAR2 DEFAULT NULL,
                              i_case_barcode        IN VARCHAR2 DEFAULT NULL,
                              i_spur_loc            IN VARCHAR2 DEFAULT NULL,
                              i_case_grab_tstamp    IN VARCHAR2 DEFAULT NULL 
                             ) 
 RETURN NUMBER IS

 l_status   VARCHAR2(3); 

 l_record_status    matrix_out.record_status%TYPE;
 l_found_record     BOOLEAN := FALSE;

 CURSOR ck_exist_sys06 is
 select record_status
 from matrix_out
 where batch_id = i_batch_id
 and   interface_ref_doc='SYS06'
 and   prod_id = i_prod_id
 and   case_barcode = i_case_barcode;

 CURSOR ck_exist_sys07 is
 select record_status
 from matrix_out
 where batch_id = i_batch_id
 and   interface_ref_doc='SYS07'
 and   batch_status = i_batch_status;

BEGIN
        /* ONLY FOR SYS06 and SYS07 it is possible to not have a record for i_sys_msg_id because of staging from spur location */
	/* SYS07 AND SYS07 records could have already been sent to Symbotic during the staging process */
 if i_interface_ref_doc='SYS06' then
       open ck_exist_sys06;
       fetch ck_exist_sys06 into l_record_status;
       if ck_exist_sys06%NOTFOUND then
	  l_found_record := FALSE;
       else
	  l_found_record := TRUE;
       end if;
       close ck_exist_sys06;
 end if;
 if i_interface_ref_doc='SYS07' then
       open ck_exist_sys07;
       fetch ck_exist_sys07 into l_record_status;
       if ck_exist_sys07%NOTFOUND then
	  l_found_record := FALSE;
       else
	  l_found_record := TRUE;
       end if;
       close ck_exist_sys07;
 end if;
 if (l_found_record = FALSE) then
    INSERT INTO matrix_out (sys_msg_id,
                            interface_ref_doc,
                            label_type,
                            parent_pallet_id,                                               
                            rec_ind,
                            pallet_id,
                            prod_id,
                            case_qty,
                            expiration_date,
                            erm_id,
                            rec_count,
                            inv_status,
                            batch_complete_timestamp,
                            batch_id,
                            priority,
                            task_id,
                            order_generation_time,
                            exact_pallet_imp,
                            destination_loc,
                            trans_type,
                            wave_number,
                            non_sym_heavy_case_count,
                            non_sym_light_case_count,
                            order_id,
                            route,
                            stop,
                            order_type,
                            order_sequence,
                            priority_identifier,
                            customer_rotation_rules,
                            float_id,
                            batch_status,
                            case_barcode,
                            spur_loc,
                            case_grab_timestamp
                            )
                    VALUES (i_sys_msg_id,
                            i_interface_ref_doc,
                            i_label_type,
                            i_parent_pallet_id,                                               
                            i_rec_ind,
                            i_pallet_id,
                            i_prod_id,
                            i_case_qty,
                            i_exp_date,
                            i_erm_id,
                            i_rec_count,
                            NVL(l_status, i_inv_status),
                            i_batch_comp_tstamp,
                            i_batch_id,
                            i_priority,
                            i_task_id,
                            i_order_gen_time,
                            i_exact_pallet_imp,
                            i_dest_loc,
                            i_trans_type,
                            i_wave_number,
                            i_ns_heavy_case_cnt,
                            i_ns_light_case_cnt,
                            i_order_id,
                            i_route,
                            i_stop,
                            i_order_type,
                            i_order_sequence,
                            i_priority_identifier,
                            i_cust_rotation_rules,
                            i_float_id,
                            i_batch_status,
                            i_case_barcode,
                            i_spur_loc,
                            i_case_grab_tstamp
                            ); 
                   
   end if;
    RETURN l_success;                        
EXCEPTION
    WHEN OTHERS THEN
        Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'Insert into matrix_out failed for pallet_id '||i_pallet_id, SQLCODE, SQLERRM);
        RETURN l_failure;
END populate_matrix_out;                            


/*---------------------------------------------------------------------------
 Function:
    send_message_to_matrix

 Description:
    Schedule job to process matrix_out request and send message to Symbotic 

 Parameter:
      Input:
          i_sys_msg_id               msg id
          i_interface_ref_doc        Interface Ref Doc (SYS03, SYS05, SYS07, SYS08 etc)        
      Output:
          Status  : Success 0
                    Failure 1         

 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    10-SEP-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/
FUNCTION send_message_to_matrix (i_sys_msg_id  IN NUMBER) 
    RETURN NUMBER IS
    l_interface_ref_doc  VARCHAR2(10);   
    l_exception_normal   EXCEPTION;
    l_exception_not_found EXCEPTION;

    cursor ck_interface is
      SELECT interface_ref_doc
        FROM matrix_out
       WHERE sys_msg_id = i_sys_msg_id
         AND ROWNUM = 1;    
BEGIN
      open ck_interface;
      fetch ck_interface INTO l_interface_ref_doc;
      if ck_interface%FOUND  then
       --Schedule the job to process the matrix_out request 
        dbms_scheduler.create_job (job_name    =>  TRIM(l_interface_ref_doc)||'_WEBSERVICE_'||i_sys_msg_id,  
                                   job_type    =>  'PLSQL_BLOCK',  
                                   job_action  =>  'BEGIN swms.pl_xml_matrix_out.initiate_webservice ('||i_sys_msg_id||', '''||TRIM(l_interface_ref_doc)||'''); END;',  
                                   start_date  =>  SYSDATE,  
                                   enabled     =>  TRUE,  
                                   auto_drop   =>  TRUE,  
                                   comments    =>  'Submitting a job to invoke '||TRIM(l_interface_ref_doc)||' webservice');
      else /* did not find i_sys_msg_id inserted */
        /* ONLY FOR SYS06 and SYS07 it is possible to not have a record for i_sys_msg_id because of staging from spur location */
	/* SYS07 AND SYS07 records could have already been sent to Symbotic during the staging process */
        raise l_exception_normal;
      end if;
      close ck_interface;
      RETURN l_success; 
      
EXCEPTION               
    WHEN L_EXCEPTION_NORMAL THEN
        Pl_Text_log.ins_Msg('INFO',Ct_Program_Code,'dbms_scheduler SUCCESS even with NO_DATA_FOUND to schedule job for sys_msg_id '||i_sys_msg_id, SQLCODE, SQLERRM);             
       RETURN l_success;
    WHEN OTHERS THEN
        Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'dbms_scheduler failed to schedule job for SYS03 for sys_msg_id '||i_sys_msg_id, SQLCODE, SQLERRM);             
        RETURN l_failure;   
END send_message_to_matrix;


/*---------------------------------------------------------------------------
 Function:
    send_orders_to_matrix

 Description:
    Schedule job to process matrix_out request and send orders to Symbotic 

 Parameter:
      Input:
          None
      Output:
          Status  : Success 0
                    Failure 1         

 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    07-MAR-2016  spin4795 Initial Creation.
---------------------------------------------------------------------------*/
FUNCTION send_orders_to_matrix(i_wave_number IN NUMBER)
    RETURN NUMBER IS
    l_interface_ref_doc  VARCHAR2(10);   
BEGIN
       --Schedule the job to process the orders to Symbotis 
       dbms_scheduler.create_job (job_name     =>  'MX_ORD_W'||TO_CHAR(i_wave_number),  
                                   job_type    =>  'PLSQL_BLOCK',  
                                   job_action  =>  'BEGIN swms.pl_matrix_order.send_wave('||TO_CHAR(i_wave_number)||'); END;',  
                                   start_date  =>  SYSDATE + (1 / (24 * 60)), -- Start job in one minute to allow time
                                                                              -- for the commit to take place. 
                                   enabled     =>  TRUE,  
                                   auto_drop   =>  TRUE,  
                                   comments    =>  'Submitting a job to invoke MX_ORD_W'||TO_CHAR(i_wave_number));
      RETURN l_success; 
      
EXCEPTION               
    WHEN OTHERS THEN
        Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'dbms_scheduler failed to schedule job to start the MX_ORD_W'||
                            TO_CHAR(i_wave_number), SQLCODE, SQLERRM);             
        RETURN l_failure;   
END send_orders_to_matrix;


/*---------------------------------------------------------------------------
 Function:
    send_order_batch_to_matrix

 Description:
    Schedule job to process matrix_out request and send orders to Symbotic 

 Parameter:
      Input:
          None
      Output:
          Status  : Success 0
                    Failure 1         

 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    07-MAR-2016  spin4795 Initial Creation.
---------------------------------------------------------------------------*/
FUNCTION send_order_batch_to_matrix(i_wave_number IN NUMBER, i_batch_id IN VARCHAR2)
    RETURN NUMBER IS
    l_interface_ref_doc  VARCHAR2(10);   
BEGIN
       --Schedule the job to process the orders to Symbotis 
       dbms_scheduler.create_job (job_name     =>  'MX_ORD_B'||i_batch_id,  
                                   job_type    =>  'PLSQL_BLOCK',  
                                   job_action  =>  'BEGIN swms.pl_matrix_order.send_batch('||TO_CHAR(i_wave_number)||
                                                   ','''||i_batch_id||'''); END;',  
                                   start_date  =>  SYSDATE,
                                   enabled     =>  TRUE,  
                                   auto_drop   =>  TRUE,  
                                   comments    =>  'Submitting a job to invoke MX_ORD_B'||i_batch_id);
      RETURN l_success; 
      
EXCEPTION               
    WHEN OTHERS THEN
        Pl_Text_log.ins_Msg('FATAL',Ct_Program_Code,'dbms_scheduler failed to schedule job to start the MX_ORD_B'||i_batch_id, SQLCODE, SQLERRM);             
        RETURN l_failure;   
END send_order_batch_to_matrix;


/*---------------------------------------------------------------------------
 Function:
    print_lpn_flag

 Description:
    Return the print_lpn flag for a matrix replenishment type

 Parameter:
      Input:
          i_repln_type               Replenishment Type (NXL, MXL, MRL, UNA, NSP, DXL, DSP)
                  
      Output:
          print_lpn_flag  : Y - Yes
                            N - No        

 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    01-SEP-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/
FUNCTION print_lpn_flag (i_repln_type IN VARCHAR2) 
     RETURN VARCHAR2 IS
    l_print_lpn VARCHAR2(1); 
BEGIN
    BEGIN
     SELECT print_lpn
       INTO l_print_lpn
       FROM mx_replen_type
      WHERE type =  i_repln_type;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_print_lpn := 'N';
    END;
    RETURN l_print_lpn;
END print_lpn_flag;  


/*===============================================================================
 Function: chk_loc
 
Description


 MODIFICATION HISTORY

 DATE             DESIGNER        COMMENTS
 ----------------------------------------------------------------------------------------------
 02-SEP-2014      sred5131        Created for calling from req_adj_qty Pro*c program
==============================================================================================*/

FUNCTION chk_loc( i_loc_ai_zn_type  IN VARCHAR2,
                                i_loc_ai_zn_value IN VARCHAR2 ) RETURN VARCHAR2 IS
   l_true_or_false   varchar2(6);

BEGIN
if i_loc_ai_zn_type is not null and i_loc_ai_zn_value is not null then
   IF i_loc_ai_zn_type='LOC' THEN
      SELECT    decode(r.maintainable,'N','FALSE','TRUE')
       INTO     l_true_or_false
       FROM    lzone lz, zone z,rules r
     WHERE     z.rule_id = r.rule_id
       AND      lz.zone_id = z.zone_id
       AND      z.zone_type = 'PUT'
       AND      lz.logi_loc = i_loc_ai_zn_value;

   ELSIF i_loc_ai_zn_type='AI' THEN

     SELECT     decode(r.maintainable,'N','FALSE','TRUE')
     INTO       l_true_or_false
     FROM       lzone lz, zone z,aisle_info ai,rules r
     WHERE      z.rule_id = r.rule_id
      AND       lz.zone_id = z.zone_id
      AND       z.zone_type = 'PUT'
      AND       substr(lz.logi_loc,1,2) = ai.name
      AND       ai.name = i_loc_ai_zn_value
      AND       rownum = 1;                                              
      
   ELSIF i_loc_ai_zn_type='SLOT' THEN                                     
     BEGIN                                  
        SELECT       'TRUE'
          INTO        l_true_or_false
          FROM        slot_type s
         WHERE        slot_type not in ('MXI', 'MXC', 'MXF', 'MXS', 'MXO', 'MXT')
           AND        slot_type = i_loc_ai_zn_value;
     EXCEPTION
       WHEN NO_DATA_FOUND THEN
            l_true_or_false := 'FALSE';
     END;
     
   ELSIF i_loc_ai_zn_type='ZN' THEN

     SELECT       decode(r.maintainable,'N','FALSE','TRUE')
      INTO        l_true_or_false
      From        Zone Z, Rules R
     WHERE        z.rule_id = r.rule_id(+)                                 
     AND          z.zone_id = i_loc_ai_zn_value;

   ELSE
      
      return 'EXCEPTION';
   END IF;

   return l_true_or_false;

else
     
      return 'EXCEPTION';
end if;

 EXCEPTION
   WHEN NO_DATA_FOUND THEN
      return 'TRUE';                                                          
   WHEN TOO_MANY_ROWS THEN
    
      return 'EXCEPTION';

   WHEN OTHERS THEN
     return 'EXCEPTION';

 END chk_loc;

/*---------------------------------------------------------------------------
 Function:
    delete_ndm_repl

 Description:
    Undo the replenishment transaction and delete the replenishment  

 Parameter:
      Input:
          i_last_qry               replenishment query
      Input/Output:   
          io_RowCnt                Record affected         
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    17-SEP-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/ 
 PROCEDURE delete_ndm_repl (i_last_qry     IN VARCHAR2,
                            io_RowCnt      IN OUT NUMBER) IS

    l_tabReplen     pl_swms_execute_sql.tabReplen;
    iIndex          NUMBER;
    l_message       VARCHAR2(512);    -- Message buffer
    l_object_name   VARCHAR2(61) := Ct_Program_Code || '.delete_ndm_repl';
 BEGIN
    EXECUTE IMMEDIATE (i_last_qry) BULK COLLECT INTO l_tabReplen;
    FOR iIndex IN 1..l_tabReplen.COUNT
    LOOP
        BEGIN
            DELETE  replenlst
             WHERE  task_id = l_tabReplen (iIndex).task_id;

            UPDATE inv
               SET qty_alloc = DECODE (SIGN (qty_alloc - l_tabReplen (iIndex).qty),1,qty_alloc - l_tabReplen (iIndex).qty,0)
             WHERE logi_loc = l_tabReplen (iIndex).pallet_id;

            IF (SQL%NOTFOUND) THEN
              -- No row(s) updated. Log message and keep on going.
                          l_message := 'TABLE=inv  ACTION=UPDATE' ||
                          ' KEY=' ||  l_tabReplen (iIndex).pallet_id || '(pallet id)' ||
                          ' MESSAGE="SQL%NOTFOUND true.  Failed to update for delete NDM repl';
                          pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                                         l_message, SQLCODE, SQLERRM);
            END IF;

            UPDATE inv
               SET qty_planned = DECODE(SIGN(qty_planned - l_tabReplen (iIndex).qty),1,qty_planned - l_tabReplen (iIndex).qty,0)
             WHERE plogi_loc = NVL(l_tabReplen (iIndex).inv_dest_loc, l_tabReplen (iIndex).dest_loc);

            IF (SQL%NOTFOUND) THEN
                          l_message := 'TABLE=inv  ACTION=UPDATE' ||
                          ' KEY=' ||  l_tabReplen (iIndex).dest_loc || '(inv_dest_loc)' ||
                          ' MESSAGE="SQL%NOTFOUND true.  Failed to update for delete NDM repl';
                          pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                                         l_message, SQLCODE, SQLERRM);
            END IF;
            
            DELETE FROM trans
             WHERE batch_no = l_tabReplen (iIndex).batch_no
               AND src_loc = l_tabReplen (iIndex).src_loc
               AND dest_loc =l_tabReplen (iIndex).dest_loc
               AND pallet_id = l_tabReplen (iIndex).pallet_id
               AND trans_type = 'RPF';
            
            DELETE FROM batch
             WHERE batch_no = 'FN' || TO_CHAR (l_tabReplen (iIndex).task_id)
               AND status = 'F';

            io_RowCnt := iIndex;

        EXCEPTION WHEN OTHERS THEN
            ROLLBACK;
            io_RowCnt := 0;
            l_message := 'TABLE=erplenlst  ACTION=DELETE,UPDATE' ||
                         ' KEY=' ||  l_tabReplen (iIndex).pallet_id || '(pallet_id)' ||
                         ' MESSAGE="SQL%NOTFOUND true.  Failed to delete NDM repl';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                                         l_message, SQLCODE, SQLERRM);

        END;
    END LOOP;
 END delete_ndm_repl;

 
 /*---------------------------------------------------------------------------
 Function:
    delete_ndm_repl

 Description:
    Undo the replenishment transaction and delete the replenishment  

 Parameter:
      Input:
          i_tabTask               replenishment task table
          i_RowCnt                Number of replenishment task
      Output:     
          o_delCnt                Record affected         
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    17-SEP-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/ 
 PROCEDURE delete_ndm_repl (i_tabTask      IN pl_swms_execute_sql.tabTask,
                            i_RowCnt       IN NUMBER,
                            o_delCnt      OUT NUMBER) IS

    l_message       VARCHAR2(512);    -- Message buffer
    l_object_name   VARCHAR2(61) := Ct_Program_Code || '.delete_ndm_repl2';
    row_index NUMBER := i_tabTask.FIRST;

    CURSOR curReplen (iTask Number) IS
        SELECT task_id, src_loc, dest_loc, inv_dest_loc, pallet_id, qty, batch_no
          FROM replenlst
         WHERE task_id = iTask;
 BEGIN
    o_delCnt := 0;
    LOOP
        EXIT WHEN row_index IS NULL;
        FOR rReplen IN curReplen (i_tabTask(row_index))
        LOOP
            BEGIN
                DELETE replenlst
                 WHERE task_id = rReplen.task_id;

                UPDATE inv
                   SET qty_alloc = DECODE (SIGN (qty_alloc - rReplen.qty), 1, qty_alloc - rReplen.qty, 0)
                 WHERE logi_loc = rReplen.pallet_id;
                   --AND plogi_loc = rReplen.src_loc              

                IF (SQL%NOTFOUND) THEN
                  -- No row(s) updated. Log message and keep on going.
                    l_message := 'TABLE=inv  ACTION=UPDATE' ||
                                 ' KEY=' ||  rReplen.pallet_id || '(pallet id)' ||
                                 ' MESSAGE="SQL%NOTFOUND true.  Failed to update for delete NDM repl task';
                    pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                                    l_message, SQLCODE, SQLERRM);
                END IF;

                UPDATE inv
                   SET qty_planned = DECODE(SIGN(qty_planned - rReplen.qty), 1, qty_planned - rReplen.qty, 0)
                 WHERE plogi_loc = NVL(rReplen.inv_dest_loc, rReplen.dest_loc);

                IF (SQL%NOTFOUND) THEN
                    l_message := 'TABLE=inv  ACTION=UPDATE' ||
                                 ' KEY=' ||  rReplen.dest_loc || '(inv_dest_loc)' ||
                                 ' MESSAGE="SQL%NOTFOUND true.  Failed to update for delete NDM repl task';
                    pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                                   l_message, SQLCODE, SQLERRM);
                END IF;
               
                DELETE 
                  FROM trans
                 WHERE batch_no = rReplen.batch_no
                  AND src_loc = rReplen.src_loc
                  AND dest_loc = rReplen.dest_loc
                  AND pallet_id = rReplen.pallet_id
                  AND trans_type = 'RPF';
            
                DELETE FROM batch
                 WHERE batch_no = 'FN' || TO_CHAR (rReplen.task_id)
                   AND status = 'F';

                o_delCnt := o_delCnt + 1;

            EXCEPTION WHEN OTHERS THEN
                ROLLBACK;
                o_delCnt := 0;
                l_message := 'TABLE=replenlst  ACTION=DELETE,UPDATE' ||
                             ' KEY=' ||  rReplen.pallet_id || '(pallet_id)' ||
                             ' MESSAGE="SQL%NOTFOUND true.  Failed to delete NDM repl';
                pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                               l_message, SQLCODE, SQLERRM);
            END;
        END LOOP;
        row_index := i_tabTask.NEXT(row_index);
    END LOOP;
 END delete_ndm_repl;

  /*---------------------------------------------------------------------------
 Function:
    f_get_pm_area

 Description:
    Get the area from pm for prod_id

 Parameter:
      Input:
          i_prod_id               Prod ID          
      Output:     
          N/A
      Return:
          l_area                  Area
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    18-SEP-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/ 
 FUNCTION f_get_pm_area (i_prod_id IN VARCHAR2)
     RETURN VARCHAR2 IS
     l_area         pm.area%TYPE;
    
 BEGIN   
    SELECT area 
      INTO l_area
      FROM pm
     WHERE prod_id =i_prod_id; 
     
    RETURN l_area;  
 EXCEPTION
    WHEN OTHERS THEN
        Pl_Text_Log.ins_msg ('FATAL', Ct_Program_Code, 'Error f_get_pm_area: Unable to find area from pm for prod_id.'||i_prod_id, SQLCODE,SQLERRM);
        RETURN NULL;
 END f_get_pm_area;
 
 /*---------------------------------------------------------------------------
 Function:
    f_get_mx_dest_loc

 Description:
    Get the SYS_CONFIG matrix destination location for prod_id

 Parameter:
      Input:
          i_prod_id               Prod ID          
      Output:     
          N/A
      Return:
          l_config_value          SYS_CONFIG value
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    18-SEP-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/ 
 FUNCTION f_get_mx_dest_loc (i_prod_id IN VARCHAR2)
     RETURN VARCHAR2 IS
     l_area         pm.area%TYPE;
     l_config_value sys_config.config_flag_val%TYPE;
 BEGIN   
    SELECT area 
      INTO l_area
      FROM pm
     WHERE prod_id =i_prod_id; 
    
    IF l_area = 'D' THEN
        l_config_value := get_sys_config_val('MX_STAGING_OR_INDUCTION_DRY');
    ELSIF l_area = 'F' THEN
        l_config_value := get_sys_config_val('MX_STAGING_OR_INDUCTION_FRZ');
    ELSIF l_area = 'C' THEN
        l_config_value := get_sys_config_val('MX_STAGING_OR_INDUCTION_CLR');
    ELSE
        l_config_value := NULL;
    END IF ;
    
    RETURN l_config_value;  
 EXCEPTION
    WHEN OTHERS THEN
        Pl_Text_Log.ins_msg ('FATAL', Ct_Program_Code, 'Error f_get_mx_dest_loc: Not able to find SYS_CONFIG matrix destination location for prod_id.'||i_prod_id, SQLCODE,SQLERRM);
        RETURN NULL;
 END f_get_mx_dest_loc;

 /*---------------------------------------------------------------------------
 Function:
    p_find_induction_loc

 Description:
    Get the induction location list 

 Parameter:
      Input:
          i_pallet_id               Pallet ID        
          io_num_of_req_loc         Number of location requested/Returned         
      Output:     
          o_avl_locations           List of Induction location 
      Return:
          n/A
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    25-SEP-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/ 
 PROCEDURE p_find_induction_loc
           (i_pallet_id            IN inv.logi_loc%TYPE,           
            io_num_of_req_loc      IN OUT NUMBER,
            o_avl_locations        OUT pl_matrix_common.t_phys_loc)
 IS
    l_prod_id inv.prod_id%TYPE;
    
    CURSOR c_ind_loc IS
        SELECT l.logi_loc
          FROM lzone lz, zone z, loc l
         WHERE lz.zone_id = z.zone_id
           AND l.logi_loc = lz.logi_loc                      
           AND z.z_area_code = NVL(pl_matrix_common.f_get_pm_area(l_prod_id),'XX')
           AND l.slot_type IN ('MXI')
           AND z.zone_type = 'PUT';
           
    ln_num_recs         NUMBER := 1;
    
 BEGIN         
    Pl_Text_log.ins_Msg('','stk_trsfer.pc','Debug get_mx_HST_loc 1 for pallet id '||i_pallet_id, NULL, NULL);
    SELECT prod_id 
      INTO l_prod_id
      FROM inv 
     WHERE logi_loc = i_pallet_id;
     
    Pl_Text_log.ins_Msg('','stk_trsfer.pc','Debug get_mx_HST_loc 1 for prod id '||l_prod_id, NULL, NULL);
   
    FOR rec IN c_ind_loc
    LOOP
        Pl_Text_log.ins_Msg('','stk_trsfer.pc','Debug get_mx_HST_loc 1 IN LOOP LOC '||rec.logi_loc, NULL, NULL);    
        o_avl_locations(ln_num_recs) := rec.logi_loc;

        ln_num_recs := ln_num_recs + 1;   
        
        EXIT WHEN ln_num_recs > io_num_of_req_loc;          
    END LOOP;        
    
    io_num_of_req_loc := ln_num_recs - 1;
 END p_find_induction_loc;

 /*---------------------------------------------------------------------------
 Function:
    chk_prod_mx_assign

 Description:
    Check if prod_id is matrix assigned or not 

 Parameter:
      Input:
          i_prod_id               Product ID                     
      
      Return:
          TRUE
          FALSE
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    02-OCT-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/ 
 FUNCTION chk_prod_mx_assign(i_prod_id IN VARCHAR2)
     RETURN BOOLEAN IS
     l_cnt NUMBER;
 BEGIN 
    SELECT COUNT(*) 
      INTO l_cnt
      FROM pm     
     WHERE mx_item_assign_flag = 'Y'
       AND prod_id = i_prod_id;
       
    IF l_cnt > 0 THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
 END chk_prod_mx_assign;
 
  /*---------------------------------------------------------------------------
 Function:
    chk_prod_mx_eligible

 Description:
    Check if prod_id is matrix Eligible or not 

 Parameter:
      Input:
          i_prod_id               Product ID                     
      
      Return:
          TRUE
          FALSE
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    15-OCT-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/ 
 FUNCTION chk_prod_mx_eligible(i_prod_id IN VARCHAR2)
     RETURN BOOLEAN IS
     l_cnt NUMBER;
 BEGIN 
    SELECT COUNT(*) 
      INTO l_cnt
      FROM pm     
     WHERE mx_eligible = 'Y'
       AND prod_id = i_prod_id;
       
    IF l_cnt > 0 THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
 END chk_prod_mx_eligible;
 
   /*---------------------------------------------------------------------------
 Function:
    get_batch_priority

 Description:
    Return priority value from sos_batch_priority for a priority code 

 Parameter:
      Input:
          i_priority_code               Priority Code                     
      
      Return:
          priority value    NUMBER
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    17-OCT-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/ 
 FUNCTION get_batch_priority (i_priority_code IN VARCHAR2)
     RETURN NUMBER IS
     l_priority_value NUMBER;
 BEGIN
    SELECT priority_value
      INTO l_priority_value
      FROM sos_batch_priority
     WHERE priority_code = i_priority_code;
    
    RETURN l_priority_value;
 EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
 END get_batch_priority;

 /*---------------------------------------------------------------------------
 Function:
    sos_batch_to_matrix_yn

 Description:
    This function return Y or N based on SOS Batch needs to send to Matrix or not.
    If a dry item available in SOS batch, it will return Y to send SO Batch to Matrix else N 

 Parameter:
      Input:
          i_priority_code               Priority Code                     
      
      Return:
          send_sos_to_matrix  VARCHAR2 Y/N
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    23-OCT-2014  ayad5195 Initial Creation.
    19-AUG-2016 pdas8114 Changed sos_batch_to_matrix_yn to not include chemical batch
---------------------------------------------------------------------------*/ 
 FUNCTION sos_batch_to_matrix_yn (i_batch_no IN VARCHAR2)
     RETURN VARCHAR2 IS
    l_send_SOS_to_matrix VARCHAR2(1);
    l_count              NUMBER;
 BEGIN
    l_send_SOS_to_matrix := 'N';
    IF pl_matrix_common.chk_matrix_enable = TRUE THEN
        SELECT COUNT(*) 
          INTO l_count
          FROM floats f, float_detail fd, pm p, aisle_info ai, swms_sub_areas ssa
         WHERE f.batch_no =  i_batch_no
           AND f.float_no = fd.float_no
           AND f.pallet_pull = 'N'
           AND p.prod_id = fd.prod_id
           AND ai.name = SUBSTR(fd.src_loc, 1, 2)
           AND ai.sub_area_code = ssa.sub_area_code
           AND ssa.area_code IN (SELECT distinct z_area_code 
                                   FROM zone 
                                  WHERE rule_id = 5)
          and not exists  (select * from sel_method s
                              where f.fl_method_id = s.method_id
                              and f.group_no = s.group_no
                              and sel_lift_job_code IN (SELECT CONFIG_FLAG_VAL FROM SYS_CONFIG
                                                   WHERE CONFIG_FLAG_NAME = 'MATRIX_DRY_CHEMICAL'));
        
        IF l_count > 0 THEN
          l_send_SOS_to_matrix := 'Y';
        END IF;   
    END IF;
    RETURN l_send_SOS_to_matrix;     
 END sos_batch_to_matrix_yn;

 /*---------------------------------------------------------------------------
 Function:
    mx_rpl_task_priority

 Description:
    This function return priority value bases on the task type and severity.

 Parameter:
      Input:
          i_task_type               Priority Code 
          i_severity                Severity   (UREGNT, NORMAL, HIGH)         
      
      Return:
          priority                  NUMBER
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    03-NOV-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/ 
 FUNCTION mx_rpl_task_priority (i_task_type IN VARCHAR2,
                                i_severity  IN VARCHAR2)
     RETURN NUMBER IS    
    l_priority              NUMBER;
 BEGIN
    SELECT  priority
      INTO  l_priority
      FROM  matrix_task_priority
     WHERE matrix_task_type = i_task_type
       AND severity = i_severity;
    
    RETURN l_priority;     
 EXCEPTION
    WHEN OTHERS THEN
        IF i_severity = '' THEN
            RETURN 1;
        ELSE
            RETURN 99;
        END IF; 
 END mx_rpl_task_priority;
 
 
 
  /*---------------------------------------------------------------------------
 Function:
    f_get_mx_stg_loc

 Description:
    Get the SYS_CONFIG matrix default staging location for prod_id

 Parameter:
      Input:
          i_prod_id               Prod ID          
      Output:     
          N/A
      Return:
          l_config_value          SYS_CONFIG value
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    18-SEP-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/ 
 FUNCTION f_get_mx_stg_loc (i_prod_id IN VARCHAR2)
     RETURN VARCHAR2 IS
     l_area         pm.area%TYPE;
     l_config_value sys_config.config_flag_val%TYPE;
 BEGIN   
    SELECT area 
      INTO l_area
      FROM pm
     WHERE prod_id =i_prod_id; 
    
    IF l_area = 'D' THEN
        l_config_value := get_sys_config_val('MX_DEFAULT_STAGING_DRY');
    ELSIF l_area = 'F' THEN
        l_config_value := get_sys_config_val('MX_DEFAULT_STAGING_CLR');
    ELSIF l_area = 'C' THEN
        l_config_value := get_sys_config_val('MX_DEFAULT_STAGING_FRZ');
    ELSE
        l_config_value := NULL;
    END IF ;
    
    RETURN l_config_value;  
 EXCEPTION
    WHEN OTHERS THEN
        Pl_Text_Log.ins_msg ('FATAL', Ct_Program_Code, 'Error f_get_mx_stg_loc: Not able to find SYS_CONFIG matrix default staging location for prod_id.'||i_prod_id, SQLCODE,SQLERRM);
        RETURN NULL;
 END f_get_mx_stg_loc;
 
 /*---------------------------------------------------------------------------
 Function:
    insert_repl_sys05_label

 Description:
    Get the print stream and insert record into matrix_out_label

 Parameter:
      Input:
          i_caseBarCode             Case Barcode  
          i_destLoc                 Destination Location        
          i_pallet_id               Pallet ID
          i_prod_id                 Prod ID
          i_descrip                 Description
          i_pack                    Pack
          i_prod_size               Prod Size
          i_brand                   Brand
          i_type                    Type,
          i_sequence_number         Sequence Number
      Output:     
          N/A
      Return:
          l_config_value          SYS_CONFIG value
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    18-SEP-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/
 FUNCTION insert_repl_sys05_label (i_caseBarCode        IN VARCHAR2,
                                   i_destLoc            IN VARCHAR2,
                                   i_pallet_id          IN VARCHAR2,
                                   i_prod_id            IN VARCHAR2,
                                   i_descrip            IN VARCHAR2,
                                   i_pack               IN VARCHAR2,
                                   i_prod_size          IN VARCHAR2,
                                   i_brand              IN VARCHAR2,
                                   i_type               IN VARCHAR2,
                                   i_sequence_number    IN NUMBER)
 RETURN NUMBER IS
    
    l_print_stream      CLOB;
    l_msg_text          VARCHAR2(512);
BEGIN
    l_print_stream := pl_mx_gen_label.ZplReplenLabel(caseBarCode => i_caseBarCode,
                                                     destLoc => i_destLoc ,
                                                     lp => i_pallet_id,
                                                     itemNum => i_prod_id,
                                                     descrip => i_descrip,
                                                     pack => i_pack,
                                                     prod_size => i_prod_size,
                                                     brand => i_brand,
                                                     type => i_type
                                                    );
                                                    
    INSERT INTO matrix_out_label (sequence_number, 
                                  barcode, 
                                  print_stream,
                                  encoded_print_stream)
                          VALUES (i_sequence_number, 
                                  i_caseBarCode ,
                                  l_print_stream,
                                  utl_raw.cast_to_varchar2(utl_encode.base64_encode(utl_raw.cast_to_raw(l_print_stream)))
                                  );
    RETURN l_success;
EXCEPTION
    
    WHEN OTHERS THEN
        l_msg_text := 'Prog Code: pl_matrix_xommon.insert_repl_sys05_label - Failed to insert in matrix_out_label for sequence number ' || i_sequence_number ||' and barcode '||i_caseBarCode;          
        Pl_Text_Log.ins_msg ('FATAL', 'pl_matrix_xommon.insert_repl_sys05_label', l_msg_text, SQLCODE, SQLERRM);
        RETURN l_failure;        
                        
END insert_repl_sys05_label;    
    
/*---------------------------------------------------------------------------
 Function:
    refresh_spur_monitor

 Description:
    Refresh the spur monitor table and screen when cases on SPUR dropped or picked  

 Parameter:
      Input:
       N/A
      Output:     
         N/A       
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    30-DEC-2014  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/ 
 PROCEDURE refresh_spur_monitor (i_spur_loc IN VARCHAR2) AS  
         
    CURSOR c_batch IS
        SELECT sequence_number, batch_no, batch_type
          FROM (SELECT sequence_number, batch_no, batch_type 
                  FROM mx_batch_info 
                 WHERE status = 'AVL'
                   AND spur_location = i_spur_loc
                 ORDER BY sequence_number)
         WHERE ROWNUM <= 2
         ORDER BY sequence_number;
    
    l_cnt                NUMBER;
    l_cur_batch          mx_batch_info.batch_no%TYPE;
    l_cur_batch_type     mx_batch_info.batch_type%TYPE;
    l_next_batch         mx_batch_info.batch_no%TYPE;
    l_next_batch_type    mx_batch_info.batch_type%TYPE;
    l_cur_total_cases    NUMBER := 0; 
    l_tot_r_cases        NUMBER := 0;
    l_tot_s_cases        NUMBER := 0;
    l_tot_t_cases        NUMBER := 0;
    l_tot_drop_cases     NUMBER := 0;
    l_drop_r_cases       NUMBER := 0;
    l_drop_s_cases       NUMBER := 0;
    l_drop_t_cases       NUMBER := 0;
    l_drop_ovfl_cases    NUMBER := 0;
    l_drop_jckp_cases    NUMBER := 0;
    l_tot_picked_cases   NUMBER := 0;
    l_picked_r_cases     NUMBER := 0;
    l_picked_s_cases     NUMBER := 0;
    l_picked_t_cases     NUMBER := 0;
    l_picked_ovfl_cases  NUMBER := 0;
    l_picked_jckp_cases  NUMBER := 0;
    l_picked_r_cases2    NUMBER := 0;
    l_picked_s_cases2    NUMBER := 0;
    l_picked_t_cases2    NUMBER := 0;
    l_picked_ovfl_cases2 NUMBER := 0;
    l_picked_jckp_cases2 NUMBER := 0;
    l_tot_picked_cases2  NUMBER := 0;
    l_tot_short_cases    NUMBER := 0;
    l_short_r_cases      NUMBER := 0;
    l_short_s_cases      NUMBER := 0;
    l_short_t_cases      NUMBER := 0;
    l_short_ovfl_cases   NUMBER := 0;
    l_short_jckp_cases   NUMBER := 0;
    l_tot_mx_short_cases NUMBER := 0;
    l_mx_short_r_cases   NUMBER := 0;
    l_mx_short_s_cases   NUMBER := 0;
    l_mx_short_t_cases   NUMBER := 0;
    l_tot_mx_delay_cases NUMBER := 0;
    l_mx_delay_r_cases   NUMBER := 0;
    l_mx_delay_s_cases   NUMBER := 0;
    l_mx_delay_t_cases   NUMBER := 0;
    l_cur_r_truck_no     floats.truck_no%TYPE;
    l_cur_s_truck_no     floats.truck_no%TYPE;
    l_cur_t_truck_no     floats.truck_no%TYPE;
    l_next_r_truck_no    floats.truck_no%TYPE;
    l_next_s_truck_no    floats.truck_no%TYPE;
    l_next_t_truck_no    floats.truck_no%TYPE;
    l_cur_user_id        digisign_spur_monitor.curr_userid%TYPE;
    l_next_user_id       digisign_spur_monitor.next_userid%TYPE;
    L_NEXT_TOTAL_CASES   NUMBER;
    l_err_msg            VARCHAR2(32767);
    l_msg_text           VARCHAR2(512);
    l_result             PLS_INTEGER;
    l_mx_short_sym16     NUMBER;
    l_iir_request        NUMBER;
 BEGIN
    IF i_spur_loc NOT LIKE 'SP%J%' THEN
        UPDATE digisign_spur_monitor 
           SET curr_batch_no           = NULL,
               curr_userid             = NULL,
               next_batch_no           = NULL,
               next_userid             = NULL,
               next_total_cases        = NULL,
               total_cases_all         = NULL,
               total_cases_r           = NULL,
               total_cases_s           = NULL,
               total_cases_t           = NULL,
               total_cases_ovfl        = NULL,
               total_cases_jackpot     = NULL,
               dropped_cases_all       = NULL,
               dropped_cases_r         = NULL,
               dropped_cases_s         = NULL,
               dropped_cases_t         = NULL,
               dropped_cases_ovfl      = NULL, 
               dropped_cases_jackpot   = NULL,
               picked_cases_all        = NULL,
               picked_cases_r          = NULL,
               picked_cases_s          = NULL,
               picked_cases_t          = NULL,
               picked_cases_ovfl       = NULL,
               picked_cases_jackpot    = NULL,
               short_cases_all         = NULL,
               short_cases_r           = NULL,
               short_cases_s           = NULL,
               short_cases_t           = NULL,
               short_cases_ovfl        = NULL,
               short_cases_jackpot     = NULL,
               remaining_cases_all     = NULL,
               remaining_cases_r       = NULL,
               remaining_cases_s       = NULL,
               remaining_cases_t       = NULL,
               remaining_cases_ovfl    = NULL,
               remaining_cases_jackpot = NULL,
               curr_truck_no_r         = NULL,
               curr_truck_no_s         = NULL,         
               curr_truck_no_t         = NULL,
               next_truck_no_r         = NULL,
               next_truck_no_s         = NULL,
               next_truck_no_t         = NULL,
               mx_short_cases_all      = NULL,                                                                                                                                                                                                     
               mx_short_cases_r        = NULL,                                                                                                                                                                                                    
               mx_short_cases_s        = NULL,                                                                                                                                                                                                 
               mx_short_cases_t        = NULL,                                                                                                                                                                                                   
               mx_short_cases_ovfl     = NULL,                                                                                                                                                                                                   
               mx_short_cases_jackpot  = NULL,      
               mx_delayed_cases_all    = NULL,
               mx_delayed_cases_r      = NULL,
               mx_delayed_cases_s      = NULL,
               mx_delayed_cases_t      = NULL,
               mx_delayed_cases_ovfl   = NULL,
               mx_delayed_cases_jackpot= NULL,  
               upd_date                = SYSDATE,
               upd_user                = REPLACE(USER,'OPS$')
         WHERE location = i_spur_loc;
        

        l_cnt := 1;
        l_cur_batch := NULL;
        l_next_batch := NULL;
            
        /*Get the current and next batch from cursor */
        FOR r_batch IN c_batch
        LOOP
            IF l_cnt = 1 THEN
                l_cur_batch := r_batch.batch_no;
                l_cur_batch_type := r_batch.batch_type;
            ELSE
                l_next_batch := r_batch.batch_no;
                l_next_batch_type := r_batch.batch_type;
            END IF;         
            l_cnt := l_cnt + 1;
        END LOOP;
            
        /*if batch found*/  
        IF l_cur_batch IS NOT NULL THEN   
            /*if next batch also found*/
            IF l_next_batch IS NOT NULL THEN
                IF l_next_batch_type = 'O' THEN
                    SELECT COUNT(*) 
                      INTO l_next_total_cases
                      FROM mx_float_detail_cases mfd, floats f
                     WHERE Mfd.Float_No = F.Float_No
                       AND f.batch_no = l_next_batch;    

                    BEGIN
                        SELECT picked_by
                          INTO l_next_user_id
                          FROM sos_batch
                         WHERE batch_no = l_next_batch;
                    EXCEPTION   
                        WHEN NO_DATA_FOUND THEN
                            l_next_user_id := NULL;
                    END;    
                    
                    BEGIN
                        SELECT MAX(DECODE(f.batch_seq, 1, f.truck_no, NULL)) r_truck_no, 
                               MAX(DECODE(f.batch_seq, 2, f.truck_no, NULL)) s_truck_no,
                               MAX(DECODE(f.batch_seq, 3, f.truck_no, NULL)) t_truck_no
                          INTO l_next_r_truck_no,
                               l_next_s_truck_no,
                               l_next_t_truck_no
                          FROM mx_float_detail_cases mfd, floats f
                         WHERE Mfd.Float_No = F.Float_No
                           AND f.batch_no = l_next_batch;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NULL;
                    END;
                    
                ELSE
                    SELECT SUM(TRUNC(r.qty/p.spc))
                      INTO l_next_total_cases
                      FROM replenlst r, pm p
                     WHERE r.mx_batch_no = l_next_batch
                       AND r.prod_id = p.prod_id
                       AND r.cust_pref_vendor = p.cust_pref_vendor;   

                    BEGIN   
                        SELECT user_id
                         INTO l_next_user_id
                         FROM replenlst
                        WHERE mx_batch_no = l_next_batch
                          AND status = 'PIK'
                          AND ROWNUM = 1;
                    EXCEPTION   
                        WHEN NO_DATA_FOUND THEN
                            l_next_user_id := NULL;
                    END;        
                END IF;
            END IF;
                           
            IF l_cur_batch_type = 'O' THEN          
                IF SUBSTR(l_cur_batch, 1, 1) != 'S' THEN 
                    /* Overflow lane Lane_id = 0 */
                    SELECT COUNT(*) total_cases, 
                           COUNT(DECODE(f.batch_seq, 1, DECODE(mfd.spur_location, 'SP07J1', NULL, DECODE(mfd.lane_id, 0, NULL, 1)), NULL)) tot_r_cases, 
                           COUNT(DECODE(f.batch_seq, 2, DECODE(mfd.spur_location, 'SP07J1', NULL, DECODE(mfd.lane_id, 0, NULL, 1)), NULL)) tot_s_cases, 
                           COUNT(DECODE(f.batch_seq, 3, DECODE(mfd.spur_location, 'SP07J1', NULL, DECODE(mfd.lane_id, 0, NULL, 1)), NULL)) tot_t_cases,
                           COUNT(mfd.spur_location) tot_drop_cases,
                           COUNT(DECODE(f.batch_seq, 1, DECODE(mfd.spur_location, i_spur_loc, DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL)) drop_r_cases, 
                           COUNT(DECODE(f.batch_seq, 2, DECODE(mfd.spur_location, i_spur_loc, DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL)) drop_s_cases,
                           COUNT(DECODE(f.batch_seq, 3, DECODE(mfd.spur_location, i_spur_loc, DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL)) drop_t_cases, 
                           COUNT(DECODE(mfd.spur_location, i_spur_loc, DECODE(mfd.lane_id, 0, 1, NULL), NULL)) drop_ovfl_cases, 
                           COUNT(DECODE(mfd.spur_location, 'SP07J1', 1, NULL)) drop_jckp_cases,
                           COUNT(DECODE(mfd.status, 'PIK', 1, NULL)) tot_picked_cases,
                           COUNT(DECODE(f.batch_seq, 1, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) picked_r_cases, 
                           COUNT(DECODE(f.batch_seq, 2, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) picked_s_cases,
                           COUNT(DECODE(f.batch_seq, 3, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) picked_t_cases, 
                           COUNT(DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, 1, NULL), NULL), 'XXXXXX', DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, 1, NULL), NULL), NULL)) picked_ovfl_cases, 
                           COUNT(DECODE(mfd.spur_location, 'SP07J1', DECODE(mfd.status, 'PIK', 1, NULL), NULL)) piked_jckp_cases,
                           COUNT(DECODE(mfd.status, 'SHT', 1, NULL)) tot_short_cases,
                           COUNT(DECODE(f.batch_seq, 1, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) short_r_cases, 
                           COUNT(DECODE(f.batch_seq, 2, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) short_s_cases,
                           COUNT(DECODE(f.batch_seq, 3, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) short_t_cases, 
                           COUNT(DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, 1, NULL), NULL), 'XXXXXX', DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, 1, NULL), NULL), NULL)) short_ovfl_cases,      
                           COUNT(DECODE(mfd.spur_location, 'SP07J1', DECODE(mfd.status, 'SHT', 1, NULL), NULL)) short_jckp_cases,
                           MAX(DECODE(f.batch_seq, 1, f.truck_no, NULL)) r_truck_no, 
                           MAX(DECODE(f.batch_seq, 2, f.truck_no, NULL)) s_truck_no,
                           MAX(DECODE(f.batch_seq, 3, f.truck_no, NULL)) t_truck_no,
                           COUNT(DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'ACTUAL', 1, NULL), NULL)) tot_mx_short_cases, 
                           COUNT(DECODE(f.batch_seq, 1, DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'ACTUAL', 1, NULL), NULL), NULL)) mx_short_r_cases, 
                           COUNT(DECODE(f.batch_seq, 2, DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'ACTUAL', 1, NULL), NULL), NULL)) mx_short_s_cases,
                           COUNT(DECODE(f.batch_seq, 3, DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'ACTUAL', 1, NULL), NULL), NULL)) mx_short_t_cases,
                           COUNT(DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'DELAY', DECODE(mfd.status, 'NEW', 1, 'SHT', 1, NULL), NULL), NULL)) tot_mx_delay_cases, 
                           COUNT(DECODE(f.batch_seq, 1, DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'DELAY', DECODE(mfd.status, 'NEW', 1, 'SHT', 1, NULL), NULL), NULL), NULL)) mx_delay_r_cases, 
                           COUNT(DECODE(f.batch_seq, 2, DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'DELAY', DECODE(mfd.status, 'NEW', 1, 'SHT', 1, NULL), NULL), NULL), NULL)) mx_delay_s_cases,
                           COUNT(DECODE(f.batch_seq, 3, DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'DELAY', DECODE(mfd.status, 'NEW', 1, 'SHT', 1, NULL), NULL), NULL), NULL)) mx_delay_t_cases
                      INTO l_cur_total_cases, 
                           l_tot_r_cases, 
                           l_tot_s_cases, 
                           l_tot_t_cases,
                           l_tot_drop_cases,
                           l_drop_r_cases, 
                           l_drop_s_cases,
                           l_drop_t_cases,
                           l_drop_ovfl_cases,
                           l_drop_jckp_cases,
                           l_tot_picked_cases,
                           l_picked_r_cases,
                           l_picked_s_cases,
                           l_picked_t_cases,
                           l_picked_ovfl_cases,
                           l_picked_jckp_cases,
                           l_tot_short_cases,
                           l_short_r_cases,
                           l_short_s_cases,
                           l_short_t_cases,
                           l_short_ovfl_cases,
                           l_short_jckp_cases,
                           l_cur_r_truck_no,
                           l_cur_s_truck_no,
                           l_cur_t_truck_no,
                           l_tot_mx_short_cases,
                           l_mx_short_r_cases,
                           l_mx_short_s_cases,
                           l_mx_short_t_cases,
                           l_tot_mx_delay_cases,
                           l_mx_delay_r_cases,
                           l_mx_delay_s_cases,
                           l_mx_delay_t_cases
                      FROM mx_float_detail_cases mfd, floats f
                     WHERE Mfd.Float_No = F.Float_No
                       AND f.batch_no = l_cur_batch;

			/* same pick statement as above but look for STG status */
			SELECT
                           COUNT(DECODE(mfd.status, 'STG', 1, NULL)) tot_picked_cases,
                           COUNT(DECODE(f.batch_seq, 1, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'STG', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'STG', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) picked_r_cases, 
                           COUNT(DECODE(f.batch_seq, 2, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'STG', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'STG', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) picked_s_cases,
                           COUNT(DECODE(f.batch_seq, 3, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'STG', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'STG', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) picked_t_cases, 
                           COUNT(DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'STG', DECODE(mfd.lane_id, 0, 1, NULL), NULL), 'XXXXXX', DECODE(mfd.status, 'STG', DECODE(mfd.lane_id, 0, 1, NULL), NULL), NULL)) picked_ovfl_cases, 
                           COUNT(DECODE(mfd.spur_location, 'SP07J1', DECODE(mfd.status, 'STG', 1, NULL), NULL)) piked_jckp_cases
			INTO 
                           l_tot_picked_cases2,
                           l_picked_r_cases2,
                           l_picked_s_cases2,
                           l_picked_t_cases2,
                           l_picked_ovfl_cases2,
                           l_picked_jckp_cases2
                      FROM mx_float_detail_cases mfd, floats f
                     WHERE Mfd.Float_No = F.Float_No
                       AND f.batch_no = l_cur_batch;

			   l_tot_picked_cases := l_tot_picked_cases + nvl(l_tot_picked_cases2,0);
                           l_picked_r_cases := l_picked_r_cases + nvl(l_picked_r_cases2,0);
                           l_picked_s_cases := l_picked_s_cases + nvl(l_picked_s_cases2,0);
                           l_picked_t_cases := l_picked_t_cases + nvl(l_picked_t_cases2,0);
                           l_picked_ovfl_cases := l_picked_ovfl_cases + nvl(l_picked_ovfl_cases2,0);
                           l_picked_jckp_cases := l_picked_jckp_cases + nvl(l_picked_jckp_cases2,0);
                        
                ELSE /*  l_cur_batch_type NOT = 'O' */
                    SELECT COUNT(*) total_cases, 
                           COUNT(DECODE(f.batch_seq, 1, DECODE(mfd.spur_location, 'SP07J1', NULL, DECODE(mfd.lane_id, 0, NULL, 1)), NULL)) tot_r_cases, 
                           COUNT(DECODE(f.batch_seq, 2, DECODE(mfd.spur_location, 'SP07J1', NULL, DECODE(mfd.lane_id, 0, NULL, 1)), NULL)) tot_s_cases, 
                           COUNT(DECODE(f.batch_seq, 3, DECODE(mfd.spur_location, 'SP07J1', NULL, DECODE(mfd.lane_id, 0, NULL, 1)), NULL)) tot_t_cases,
                           COUNT(mfd.spur_location) tot_drop_cases,
                           COUNT(DECODE(f.batch_seq, 1, DECODE(mfd.spur_location, i_spur_loc, DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL)) drop_r_cases, 
                           COUNT(DECODE(f.batch_seq, 2, DECODE(mfd.spur_location, i_spur_loc, DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL)) drop_s_cases,
                           COUNT(DECODE(f.batch_seq, 3, DECODE(mfd.spur_location, i_spur_loc, DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL)) drop_t_cases, 
                           COUNT(DECODE(mfd.spur_location, i_spur_loc, DECODE(mfd.lane_id, 0, 1, NULL), NULL)) drop_ovfl_cases, 
                           COUNT(DECODE(mfd.spur_location, 'SP07J1', 1, NULL)) drop_jckp_cases,
                           COUNT(DECODE(mfd.status, 'PIK', 1, NULL)) tot_picked_cases,
                           COUNT(DECODE(f.batch_seq, 1, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) picked_r_cases, 
                           COUNT(DECODE(f.batch_seq, 2, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) picked_s_cases,
                           COUNT(DECODE(f.batch_seq, 3, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) picked_t_cases, 
                           COUNT(DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, 1, NULL), NULL), 'XXXXXX', DECODE(mfd.status, 'PIK', DECODE(mfd.lane_id, 0, 1, NULL), NULL), NULL)) picked_ovfl_cases, 
                           COUNT(DECODE(mfd.spur_location, 'SP07J1', DECODE(mfd.status, 'PIK', 1, NULL), NULL)) piked_jckp_cases,
                           COUNT(DECODE(mfd.status, 'SHT', 1, NULL)) tot_short_cases,
                           COUNT(DECODE(f.batch_seq, 1, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) short_r_cases, 
                           COUNT(DECODE(f.batch_seq, 2, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) short_s_cases,
                           COUNT(DECODE(f.batch_seq, 3, DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, NULL, 1), NULL), 'XXXXXX', DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, NULL, 1), NULL), NULL), NULL)) short_t_cases, 
                           COUNT(DECODE(NVL(mfd.spur_location, 'XXXXXX'), i_spur_loc, DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, 1, NULL), NULL), 'XXXXXX', DECODE(mfd.status, 'SHT', DECODE(mfd.lane_id, 0, 1, NULL), NULL), NULL)) short_ovfl_cases,      
                           COUNT(DECODE(mfd.spur_location, 'SP07J1', DECODE(mfd.status, 'SHT', 1, NULL), NULL)) short_jckp_cases,
                           MAX(DECODE(f.batch_seq, 1, f.truck_no, NULL)) r_truck_no, 
                           MAX(DECODE(f.batch_seq, 2, f.truck_no, NULL)) s_truck_no,
                           MAX(DECODE(f.batch_seq, 3, f.truck_no, NULL)) t_truck_no,
                           COUNT(DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'ACTUAL', 1, NULL), NULL)) tot_mx_short_cases, 
                           COUNT(DECODE(f.batch_seq, 1, DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'ACTUAL', 1, NULL), NULL), NULL)) mx_short_r_cases, 
                           COUNT(DECODE(f.batch_seq, 2, DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'ACTUAL', 1, NULL), NULL), NULL)) mx_short_s_cases,
                           COUNT(DECODE(f.batch_seq, 3, DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'ACTUAL', 1, NULL), NULL), NULL)) mx_short_t_cases,
                           COUNT(DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'DELAY', DECODE(mfd.status, 'NEW', 1, 'SHT', 1, NULL), NULL), NULL)) tot_mx_delay_cases, 
                           COUNT(DECODE(f.batch_seq, 1, DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'DELAY', DECODE(mfd.status, 'NEW', 1, 'SHT', 1, NULL), NULL), NULL), NULL)) mx_delay_r_cases, 
                           COUNT(DECODE(f.batch_seq, 2, DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'DELAY', DECODE(mfd.status, 'NEW', 1, 'SHT', 1, NULL), NULL), NULL), NULL)) mx_delay_s_cases,
                           COUNT(DECODE(f.batch_seq, 3, DECODE(mfd.case_skip_flag, 'Y', DECODE(UPPER(mfd.case_skip_reason), 'DELAY', DECODE(mfd.status, 'NEW', 1, 'SHT', 1, NULL), NULL), NULL), NULL)) mx_delay_t_cases
                      INTO l_cur_total_cases, 
                           l_tot_r_cases, 
                           l_tot_s_cases, 
                           l_tot_t_cases,
                           l_tot_drop_cases,
                           l_drop_r_cases, 
                           l_drop_s_cases,
                           l_drop_t_cases,
                           l_drop_ovfl_cases,
                           l_drop_jckp_cases,
                           l_tot_picked_cases,
                           l_picked_r_cases,
                           l_picked_s_cases,
                           l_picked_t_cases,
                           l_picked_ovfl_cases,
                           l_picked_jckp_cases,
                           l_tot_short_cases,
                           l_short_r_cases,
                           l_short_s_cases,
                           l_short_t_cases,
                           l_short_ovfl_cases,
                           l_short_jckp_cases,
                           l_cur_r_truck_no,
                           l_cur_s_truck_no,
                           l_cur_t_truck_no,
                           l_tot_mx_short_cases,
                           l_mx_short_r_cases,
                           l_mx_short_s_cases,
                           l_mx_short_t_cases,
                           l_tot_mx_delay_cases,
                           l_mx_delay_r_cases,
                           l_mx_delay_s_cases,
                           l_mx_delay_t_cases
                      FROM mx_float_detail_cases mfd, floats f
                     WHERE Mfd.Float_No = F.Float_No
                       AND mfd.short_batch_no = l_cur_batch;
                END IF; /* l_cur_batch_type = 'O' */
                
                BEGIN
                    SELECT picked_by
                      INTO l_cur_user_id
                      FROM sos_batch
                     WHERE batch_no = l_cur_batch;
                EXCEPTION   
                    WHEN NO_DATA_FOUND THEN
                        l_cur_user_id := NULL;
                END;
                   
            ELSE
                SELECT COUNT(*)
                  INTO l_iir_request
                  FROM mx_inv_request
                 WHERE batch_no = l_cur_batch;
                 
                IF  l_iir_request > 0 THEN
                    SELECT SUM(qty_requested),
                           SUM(qty_requested),
                           SUM(NVL(qty_short, 0))  
                      INTO l_cur_total_cases, 
                           l_tot_r_cases,
                           l_mx_short_sym16
                      FROM mx_inv_request
                     WHERE batch_no = l_cur_batch;
                
                ELSE                 
                    SELECT SUM(TRUNC(r.qty/p.spc)),
                           SUM(TRUNC(r.qty/p.spc)),
                           SUM(NVL(mx_short_cases, 0))  
                      INTO l_cur_total_cases, 
                           l_tot_r_cases,
                           l_mx_short_sym16
                      FROM replenlst r, pm p
                     WHERE r.mx_batch_no = l_cur_batch
                       AND r.prod_id = p.prod_id
                       AND r.cust_pref_vendor = p.cust_pref_vendor;
                END IF;       
                
                SELECT COUNT(*) tot_drop_cases,
                       COUNT(DECODE(spur_location, i_spur_loc, DECODE (lane_id, 1, 1, NULL), NULL)) drop_r_cases,
                       COUNT(DECODE(spur_location, i_spur_loc, DECODE (lane_id, 2, 1, NULL), NULL)) drop_s_cases,
                       COUNT(DECODE(spur_location, i_spur_loc, DECODE (lane_id, 3, 1, NULL), NULL)) drop_t_cases,
                       COUNT(DECODE(spur_location, i_spur_loc, DECODE (lane_id, 0, 1, NULL), NULL)) drop_ovfl_cases,
                       COUNT(DECODE(spur_location, 'SP07J1', 1, NULL)) drop_jckp_cases,
                       COUNT(DECODE(status, 'PIK', 1, NULL)) tot_picked_cases,
                       COUNT(DECODE(spur_location, i_spur_loc, DECODE (lane_id, 1, DECODE(status, 'PIK', 1, NULL), NULL), NULL)) picked_r_cases,
                       COUNT(DECODE(spur_location, i_spur_loc, DECODE (lane_id, 2, DECODE(status, 'PIK', 1, NULL), NULL), NULL)) picked_s_cases,
                       COUNT(DECODE(spur_location, i_spur_loc, DECODE (lane_id, 3, DECODE(status, 'PIK', 1, NULL), NULL), NULL)) picked_t_cases,
                       COUNT(DECODE(spur_location, i_spur_loc, DECODE (lane_id, 0, DECODE(status, 'PIK', 1, NULL), NULL), NULL)) picked_ovfl_cases,
                       COUNT(DECODE(spur_location, 'SP07J1', DECODE(status, 'PIK', 1, NULL), NULL)) pcked_jckp_cases,
                       COUNT(DECODE(case_skip_flag, 'Y', DECODE(UPPER(case_skip_reason), 'ACTUAL', 1, NULL), NULL)) tot_mx_short_cases,
                       COUNT(DECODE(case_skip_flag, 'Y', DECODE(UPPER(case_skip_reason), 'ACTUAL', 1, NULL), NULL)) mx_short_r_cases,
                       COUNT(DECODE(case_skip_flag, 'Y', DECODE(UPPER(case_skip_reason), 'DELAY', 1, NULL), NULL)) tot_mx_delay_cases,
                       COUNT(DECODE(case_skip_flag, 'Y', DECODE(UPPER(case_skip_reason), 'DELAY', 1, NULL), NULL)) mx_delay_r_cases
                  INTO l_tot_drop_cases,
                       l_drop_r_cases, 
                       l_drop_s_cases,
                       l_drop_t_cases,
                       l_drop_ovfl_cases,
                       l_drop_jckp_cases,
                       l_tot_picked_cases,
                       l_picked_r_cases,
                       l_picked_s_cases,
                       l_picked_t_cases,
                       l_picked_ovfl_cases,
                       l_picked_jckp_cases,
                       l_tot_mx_short_cases,
                       l_mx_short_r_cases,
                       l_tot_mx_delay_cases,
                       l_mx_delay_r_cases                      
                  FROM mx_replenlst_cases
                 WHERE batch_no = l_cur_batch;  

                /* Add Actual case skip and symbotic rejected cases from SYM16 message*/ 
                l_tot_mx_short_cases := l_tot_mx_short_cases +  l_mx_short_sym16;
                l_tot_s_cases := l_drop_s_cases;
                l_tot_t_cases := l_drop_t_cases;
                l_tot_r_cases := l_tot_r_cases - NVL( l_drop_ovfl_cases,0) - NVL(l_drop_jckp_cases,0) - NVL(l_tot_s_cases,0) - NVL(l_tot_t_cases,0);
                
                BEGIN   
                    SELECT user_id
                     INTO l_cur_user_id
                     FROM replenlst
                    WHERE mx_batch_no = l_cur_batch
                      AND status = 'PIK'
                      AND ROWNUM = 1;
                EXCEPTION   
                    WHEN NO_DATA_FOUND THEN
                        l_cur_user_id := NULL;
                END;       

                l_mx_short_r_cases := l_tot_mx_short_cases;               
            END IF;
                
            UPDATE digisign_spur_monitor 
               SET curr_batch_no            = l_cur_batch, 
                   curr_userid              = l_cur_user_id, 
                   next_batch_no            = l_next_batch,     
                   next_userid              = l_next_user_id,
                   next_total_cases         = l_next_total_cases, 
                   total_cases_all          = l_cur_total_cases, 
                   total_cases_r            = l_tot_r_cases, 
                   total_cases_s            = l_tot_s_cases, 
                   total_cases_t            = l_tot_t_cases,
                   total_cases_ovfl         = l_drop_ovfl_cases, 
                   total_cases_jackpot      = l_drop_jckp_cases,
                   dropped_cases_all        = l_tot_drop_cases, 
                   dropped_cases_r          = l_drop_r_cases, 
                   dropped_cases_s          = l_drop_s_cases, 
                   dropped_cases_t          = l_drop_t_cases,
                   dropped_cases_ovfl       = l_drop_ovfl_cases, 
                   dropped_cases_jackpot    = l_drop_jckp_cases,
                   picked_cases_all         = l_tot_picked_cases, 
                   picked_cases_r           = l_picked_r_cases, 
                   picked_cases_s           = l_picked_s_cases, 
                   picked_cases_t           = l_picked_t_cases,
                   picked_cases_ovfl        = l_picked_ovfl_cases, 
                   picked_cases_jackpot     = l_picked_jckp_cases,
                   short_cases_all          = l_tot_short_cases, 
                   short_cases_r            = l_short_r_cases, 
                   short_cases_s            = l_short_s_cases, 
                   short_cases_t            = l_short_t_cases,
                   short_cases_ovfl         = l_short_ovfl_cases, 
                   short_cases_jackpot      = l_short_jckp_cases,
                   remaining_cases_all      = l_cur_total_cases - l_tot_picked_cases - l_tot_short_cases,
                   remaining_cases_r        = l_tot_r_cases - l_picked_r_cases - l_short_r_cases,
                   remaining_cases_s        = l_tot_s_cases - l_picked_s_cases - l_short_s_cases,
                   remaining_cases_t        = l_tot_t_cases - l_picked_t_cases - l_short_t_cases,
                   remaining_cases_ovfl     = l_drop_ovfl_cases - l_picked_ovfl_cases - l_short_ovfl_cases,
                   remaining_cases_jackpot  = l_drop_jckp_cases - l_picked_jckp_cases - l_short_jckp_cases,
                   curr_truck_no_r          = l_cur_r_truck_no,
                   curr_truck_no_s          = l_cur_s_truck_no,         
                   curr_truck_no_t          = l_cur_t_truck_no,
                   next_truck_no_r          = l_next_r_truck_no,
                   next_truck_no_s          = l_next_s_truck_no,
                   next_truck_no_t          = l_next_t_truck_no,
                   mx_short_cases_all       = l_tot_mx_short_cases,                                                                                                                                                                                                     
                   mx_short_cases_r         = l_mx_short_r_cases,                                                                                                                                                                                                    
                   mx_short_cases_s         = l_mx_short_s_cases,                                                                                                                                                                                                 
                   mx_short_cases_t         = l_mx_short_t_cases,                                                                                                                                                                                                   
                   mx_short_cases_ovfl      = 0,                                                                                                                                                                                                   
                   mx_short_cases_jackpot   = 0,             
                   mx_delayed_cases_all     = l_tot_mx_delay_cases,
                   mx_delayed_cases_r       = l_mx_delay_r_cases,
                   mx_delayed_cases_s       = l_mx_delay_s_cases,
                   mx_delayed_cases_t       = l_mx_delay_t_cases,
                   mx_delayed_cases_ovfl    = 0,
                   mx_delayed_cases_jackpot = 0,
                   upd_date                 = SYSDATE,
                   upd_user                 = REPLACE(USER,'OPS$')
             WHERE location = i_spur_loc;
        END IF;
        
        COMMIT;
        /*Refresh the SPUR monitor*/
        l_result:= pl_digisign.BroadcastSpurUpdate (i_spur_loc, l_err_msg);
        
        IF l_result != 0 THEN
            l_msg_text := 'Error calling pl_digisign.BroadcastSpurUpdate from pl_matrix_coomon.refresh_spur_monitor';
            Pl_Text_Log.ins_msg ('FATAL', 'pl_matrix_common.refresh_spur_monitor', l_msg_text, NULL, l_err_msg);
        END IF;
    END IF;
 EXCEPTION
    WHEN OTHERS THEN
        l_msg_text := 'Error executing pl_matrix_coomon.refresh_spur_monitor';
        Pl_Text_Log.ins_msg ('FATAL', 'pl_matrix_coomon.refresh_spur_monitor', l_msg_text, SQLCODE, SQLERRM);
        RAISE;
 END refresh_spur_monitor;
 
/*---------------------------------------------------------------------------
 Function:
    f_is_induction_loc_yn

 Description:
    Function return 'Y' if the input location is matrix induction location else return 'N'

 Parameter:
      Input:
       i_loc            Location
      Output:     
         N/A       
          
 Modification History:
    Date         Designer Comments
    -----------  -------- ---------------------------------------------------
    19-JAN-2015  ayad5195 Initial Creation.
---------------------------------------------------------------------------*/  
  FUNCTION f_is_induction_loc_yn (i_loc    IN VARCHAR2) 
   RETURN VARCHAR2 IS
   l_cnt  NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO l_cnt
      FROM loc
     WHERE slot_type = 'MXI'
       AND logi_loc = i_loc;
    
    IF l_cnt > 0 THEN
        RETURN 'Y';
    ELSE
        RETURN 'N';
    END IF;
  END f_is_induction_loc_yn;


---------------------------------------------------------------------------
-- Function:
--    ok_to_alloc_to_vrt_in_this_loc
--
-- Description:
--    This function returns 'Y' if the inventory is in a location that
--    can be allocated to a VRT otherwise 'N' is returned.
--    ***** This will be determined by looking at the slot type *****
--
--    A log message is always created when checking the location since
--    VRTs are not that frequent.
--
--    Inventory on hold in a Symbotic location cannot be allocated
--    against a VRT.
--    01/21/15  The question is do we consider the induction
--    location, spur location and outduct or induction as
--    Symbotic locations concerning allocating to a VRT.
--    As of now we do.
--
-- Parameters:
--    plogi_loc - location to check
--
-- Return Values:
--    Y - OK to allocate inventory in the locaton to a VRT.
--        (Of couse it has to meet the other criteria.
--         See "pl_op_vrt_alloc.sql" for more info)
--    N - Not OK to allocate inventory in the locaton to a VRT.
--
-- Called by:
--    - pl_op_vrt_alloc.sql
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/21/15 bben0556 Created.
---------------------------------------------------------------------------
FUNCTION ok_to_alloc_to_vrt_in_this_loc(i_plogi_loc IN inv.plogi_loc%TYPE)
RETURN VARCHAR2
IS
   l_object_name   VARCHAR2(30) := 'ok_to_alloc_to_vrt_in_this_loc';

   -- Text put in all log messagess.
   l_common_message_text  VARCHAR(200) :=
        'This function is called by pl_op_vrt_alloc.sql when looking'
     || ' for inventory on HLD to allocate to a VRT.'
     || '  The slot type controls if LP''s in the slot can be allocated to a VRT.';

   l_slot_type     loc.slot_type%TYPE;
   l_return_value  VARCHAR2(1);
BEGIN
   BEGIN
      SELECT loc.slot_type INTO l_slot_type
        FROM loc
       WHERE loc.logi_loc = i_plogi_loc;

      IF (l_slot_type IN ('MXC',
                          'MXF',
                          'MXI',
                          'MXO',
                          'MXS',
                          'MXT'))
      THEN
         pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                '(i_plogi_loc['       || i_plogi_loc      || '])'
             || '  This slot has slot type ' || l_slot_type
             || ' which cannot have a VRT allocated against.'
             || '  ' || l_common_message_text,
             NULL, NULL,
             ct_application_function, gl_pkg_name);

         l_return_value := 'N';
      ELSE
         pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                '(i_plogi_loc['       || i_plogi_loc      || '])'
             || '  This slot has slot type ' || l_slot_type
             || ' which can have a VRT allocated against.'
             || '  ' || l_common_message_text,
             NULL, NULL,
             ct_application_function, gl_pkg_name);

         l_return_value := 'Y';
      END IF;

   EXCEPTION
         WHEN NO_DATA_FOUND THEN
            --
            -- Did not find the location in the LOC table.
            -- Ideally this should not happen.
            -- Log a message and return 'N'.
            --
            pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                        '(i_plogi_loc['       || i_plogi_loc      || '])'
                     || '  This is not a valid location.'
                     || '  This will not stop processing.  N will be returned.'
                     || '  ' || l_common_message_text,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

            l_return_value := 'N';
   END;
   
   RETURN(l_return_value);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      -- Log a message and return 'N'.
      --
      pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                        '(i_plogi_loc['       || i_plogi_loc      || '])'
                     || '  Oracle error.  This will not stop processing.'
                     ||  '  N will be returned.'
                     || '  ' || l_common_message_text,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RETURN 'N';
END ok_to_alloc_to_vrt_in_this_loc;


---------------------------------------------------------------------------
-- Function:
--    f_get_mx_msku_dest_loc
--
-- Description:
--    This function returns the location to direct the child LP's to on a
--    MSKU for a matrix item for a MSKU on a SN.
--    The location comes from one of three syspars with the area of the
--    item determining what syspar to use.  The location will either be
--    the matrix induction location or the matrix staging location.
--
--    The rule is a mtrix item on MSKU will always be directed to the
--    what is designated by syspars:
--       - MX_MSKU_STAGING_OR_INDUCT_DRY
--       - MX_MSKU_STAGING_OR_INDUCT_CLR
--       - MX_MSKU_STAGING_OR_INDUCT_FRZ
--
-- Parameters:
--    i_prod_id
--    i_cust_pref_vendor
--
-- Return Values:
--    MSKU child LP destination location.
--    Null can be returned if the item area is not C, D or F.
--
-- Called by:
--    - pl_putaway_utilities.sql
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/15/15 bben0556 Created.
---------------------------------------------------------------------------
FUNCTION f_get_mx_msku_dest_loc
            (i_prod_id           IN pm.prod_id%TYPE,
             i_cust_pref_vendor  IN pm.cust_pref_vendor%TYPE)
RETURN VARCHAR2
IS
   l_pm_area       pm.area%TYPE;
   l_return_value  sys_config.config_flag_val%TYPE;
BEGIN
   l_pm_area := f_get_pm_area(i_prod_id);

   IF (l_pm_area = 'D') THEN
      l_return_value := pl_common.f_get_syspar('MX_MSKU_STAGING_OR_INDUCT_DRY', NULL);
   ELSIF (l_pm_area = 'C') THEN
      l_return_value := pl_common.f_get_syspar('MX_MSKU_STAGING_OR_INDUCT_CLR', NULL);
   ELSIF (l_pm_area = 'F') THEN
      l_return_value := pl_common.f_get_syspar('MX_MSKU_STAGING_OR_INDUCT_FRZ', NULL);
   ELSE
      --
      -- Have an unhandled value for the item's area.
      -- This will not stop processing.  NULL will be returned.
      -- Log a message.
      --
      l_return_value := NULL;

      pl_log.ins_msg(pl_log.ct_warn_msg, 'f_get_mx_msku_dest_loc',
                        '(i_prod_id['          || i_prod_id          || '],'
                     || 'i_cust_pref_vendor['  || i_cust_pref_vendor || '])'
                     || '  Unhandled area for the item[' || l_pm_area || ']'
                     || '  This will not stop processing.  NULL will be returned.',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
   END IF;

   RETURN(l_return_value);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      -- Log a message and return NULL.
      --
      pl_log.ins_msg(pl_log.ct_warn_msg, 'f_get_mx_msku_dest_loc',
                        '(i_prod_id['          || i_prod_id          || '],'
                     || 'i_cust_pref_vendor['  || i_cust_pref_vendor || '])'
                     || '  Oracle error.  This will not stop processing.'
                     || '  NULL will be returned.',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RETURN NULL;
END f_get_mx_msku_dest_loc;

--Populate mx_wave_number in route table and later use this value to send SYS04
PROCEDURE populate_mx_wave_number (i_wave_number IN NUMBER) 
IS
    l_cnt   NUMBER;
BEGIN
    SELECT COUNT(*) 
      INTO l_cnt
      FROM route r, ordm om
     WHERE r.route_batch_no = i_wave_number
       AND om.route_no = r.route_no
       AND NVL(om.immediate_ind, 'N') = 'N'; 
        
    Pl_Text_Log.ins_msg ('I', 'pl_matrix_xommon.populate_mx_wave_number', 'populate_mx_wave_number : Count is :'||l_cnt ||
                         '   for Wave Number ='||TO_CHAR(i_wave_number), SQLCODE, SQLERRM);
    
    UPDATE route
       SET mx_wave_number = DECODE(l_cnt, 0 , 0, i_wave_number)
     WHERE route_batch_no = i_wave_number;
END populate_mx_wave_number;


END pl_matrix_common;
/

SHOW ERRORS
CREATE OR REPLACE PUBLIC SYNONYM pl_matrix_common FOR swms.pl_matrix_common;

