set echo off
CREATE OR REPLACE PACKAGE swms.pl_rf_build_master_lp AS

---------------------------------------------------------------------------
   -- Package Name:
   -- pl_rf_build_master_lp
   --
   -- Description:
   --    Common procedures and functions for Building Master Pallet. 
   --	 These functions have been called directly by RF client code.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- --------------------------------------------------
   --    06/27/19 sban3548   Initial Version
   --                     
   --------------------------------------------------------------------------

   e_record_locked_after_waiting  EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_record_locked_after_waiting, -30006);

   -- Global Type Declarations
   G_RF_Date_Format        CONSTANT  VARCHAR2(20) := RF.Serialized_Date_Pattern;
   SUBTYPE   Server_Status   IS  PLS_INTEGER;
   
  ------------------------------------------------------------------------
  -- Procedure Declarations
  ------------------------------------------------------------------------

/* START OPCOF-759 : Added for Linking Master pallet with child pallets for FoodPro */ 

FUNCTION Link(
    i_RF_Log_Init_Record    IN      RF_Log_Init_Record,            /* Input: RF device initialization record */
    i_Child_LP              IN      VARCHAR2,                       /* Input: Child LP */
    i_Parent_LP             IN      VARCHAR2,                      /* Input: Parent LP */
    i_Scan_Method           IN      VARCHAR2,                      /* Input: (S)can or (K)eyboard */
    o_Detail_Collection     OUT     Parent_Link_PO_List_Obj        /* Output: complex object of arrays */
)
RETURN RF.Status;

FUNCTION Unlink(
    i_RF_Log_Init_Record    IN      RF_Log_Init_Record,            /* Input: RF device initialization record */
    i_Child_LP              IN      VARCHAR2,                      /* Input: Child LP */
    i_Scan_Method           IN      VARCHAR2,                      /* Input: (S)can or (K)eyboard */
    o_Detail_Collection     OUT     Parent_Link_PO_List_Obj        /* Output: complex object of arrays */
)
RETURN RF.Status;

FUNCTION Refresh(
    i_RF_Log_Init_Record    IN      RF_Log_Init_Record,            /* Input: RF device initialization record */
    i_LP                    IN      VARCHAR2,                      /* Input: Any parent or child LP */
    i_Scan_Method           IN      VARCHAR2,                      /* Input: (S)can or (K)eyboard */
    o_Detail_Collection     OUT     Parent_Link_PO_List_Obj        /* Output: complex object of arrays */
)
RETURN RF.Status;

FUNCTION NewParent(
    i_RF_Log_Init_Record    IN      RF_Log_Init_Record,            /* Input: RF device initialization record */
    o_NewParentLp           OUT     VARCHAR2                       /* Output: LP of new parent */
)
RETURN RF.Status;
/* END OPCOF-759 : Added for Linking Master pallet with child pallets for FoodPro */ 

END pl_rf_build_master_lp;
/
SHOW ERRORS;


CREATE OR REPLACE PACKAGE BODY SWMS.pl_rf_build_master_lp  AS

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
G_Msg_Category        CONSTANT  VARCHAR2(30)          := PL_RCV_Open_PO_Types.CT_Application_Function;

gl_pkg_name  CONSTANT VARCHAR2(30) := 'pl_rf_build_master_lp';   -- Package name.  Used
                                                   -- in messages.

gl_application_func CONSTANT VARCHAR2(30) := 'RCV_BUILD_MASTER_PALLET';

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.
                                 
---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------

FUNCTION f_parent_exists_in_inv(i_parent_pallet_id IN inv.parent_pallet_id%TYPE)
RETURN BOOLEAN IS
   l_count integer;
BEGIN

   SELECT count(parent_pallet_id)
   INTO l_count
   FROM inv
   WHERE parent_pallet_id = i_parent_pallet_id;

   IF l_count > 0 THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;

END f_parent_exists_in_inv;

----------------------------------------------------------------------------------------------
-- Function:
--    validate_parent_pallet
--
-- Description:
--    This function will check and validate that the parent pallet satisfies to below conditions:
--       1. Parent pallet supplied is not one of the child pallet
--       2. Parent pallet should not already exists in a different location
----------------------------------------------------------------------------------------------
FUNCTION validate_parent_pallet(i_parent_pallet_id IN inv.logi_loc%TYPE, i_loc IN inv.plogi_loc%TYPE)
RETURN RF.Status IS 
   l_plogi_loc 		inv.plogi_loc%TYPE;
   l_child_cnt 		NUMBER := 0;
   l_loc_cnt 		NUMBER := 0;
   
BEGIN
	-- Check if Parent LP is not one of the child				
	  SELECT count(logi_loc)
	  INTO l_child_cnt 
	  FROM inv
	  WHERE logi_loc = i_parent_pallet_id;
	  
	-- Check if this Parent LP already exists in different location
	  SELECT count(distinct plogi_loc)
	  INTO l_loc_cnt 
	  FROM inv
	  WHERE plogi_loc != i_loc
	  AND parent_pallet_id = i_parent_pallet_id;

	  IF l_child_cnt > 0 OR l_loc_cnt > 0 THEN
		  pl_log.ins_msg('INFO','PL_RF_BUILD_MASTER_LP',
							   'Parent pallet is NOT valid pallet=['
								||i_parent_pallet_id||']'
								,NULL,NULL);
		
		  RETURN rf.STATUS_INVALID_PARENT_LP;
	  ELSE
		  RETURN rf.STATUS_NORMAL;
	  END IF;

   EXCEPTION
      WHEN OTHERS THEN
	  	  pl_log.ins_msg('INFO','PL_RF_BUILD_MASTER_LP.validate_parent_pallet()',
						   'Exeptionreturned for parent LP=['
							||i_parent_pallet_id
							||'], Loc=['||i_loc 
							||'], SQLERRM='||SQLERRM
							 ,NULL,SQLCODE);
 
         RETURN rf.STATUS_INV_LABEL;
		 
END validate_parent_pallet;
				  
----------------------------------------------------------------------------------------------
-- Function:
--    validate_child_pallet
--
-- Description:
--    This function will check and validate that the pallet satisfies to below conditions:
--       1. A child pallet cannot be a home/pick location
--       2. A child pallet must be in a location within BTP zone of rule 9 
----------------------------------------------------------------------------------------------
FUNCTION validate_child_pallet(i_pallet_id IN inv.logi_loc%TYPE ) 
RETURN RF.Status IS

   l_plogi_loc 			inv.plogi_loc%TYPE;
   l_lzone_count 		integer;
   l_parent_pallet_cnt	number := 0;
   l_status				inv.status%TYPE;

BEGIN

      SELECT plogi_loc, status 
        INTO l_plogi_loc, l_status 
        FROM inv
       WHERE logi_loc = i_pallet_id;
	
   -- Validate that this is not the home/pick location
   IF l_plogi_loc = i_pallet_id THEN
      RETURN rf.STATUS_INV_LABEL;
   END IF;

   IF l_status='HLD' THEN
		RETURN rf.STATUS_PALLET_ON_HOLD;
   END IF;
   
   SELECT count(1)
   INTO l_lzone_count
   FROM zone z, lzone lz
   WHERE z.zone_id = lz.zone_id
   AND z.zone_type = 'PUT'
   AND z.rule_id in ('9') 
   AND lz.logi_loc = l_plogi_loc;

   IF l_lzone_count > 0 THEN
	  pl_log.ins_msg('INFO','PL_RF_BUILD_MASTER_LP',
						   'Child pallet is valid pallet=['
							||i_pallet_id||']'
							 ,NULL,NULL);
    
      RETURN rf.STATUS_NORMAL;
   ELSE
      RETURN rf.STATUS_INV_ZONE;
   END IF;
   
   -- Validate if the child LP is already linked with another parent LP
   BEGIN
      SELECT count(parent_pallet_id)
      INTO l_parent_pallet_cnt 
      FROM inv
      WHERE logi_loc = i_pallet_id
	  AND parent_pallet_id IS NOT NULL
	  AND status = 'CDK';
	  
	   IF l_parent_pallet_cnt > 0 THEN
		  pl_log.ins_msg('INFO','PL_RF_BUILD_MASTER_LP',
							   'Child pallet is already linked with another parent=['
								||i_pallet_id||']'
								 ,NULL,NULL);
		
		  RETURN rf.STATUS_LP_ALREADY_LINKED;
	   ELSE
		  RETURN rf.STATUS_NORMAL;
	   END IF;
   END;

EXCEPTION
      WHEN no_data_found THEN
	  	  pl_log.ins_msg('INFO','PL_RF_BUILD_MASTER_LP.validate_child_pallet()',
						   'No data found returned for LP=['
							||i_pallet_id||'], SQLERRM='||SQLERRM
							 ,NULL,SQLCODE);
			RETURN rf.STATUS_INV_LABEL;
 
	  WHEN OTHERS THEN
	  	  pl_log.ins_msg('INFO','PL_RF_BUILD_MASTER_LP.validate_child_pallet()',
						   'Exception occured for LP=['
							||i_pallet_id||'], SQLERRM='||SQLERRM
							 ,NULL,SQLCODE);
 
			RETURN rf.STATUS_INV_LABEL;

END validate_child_pallet;

FUNCTION Get_Parent_Link_LPN_List(i_erm_Id 		IN 	VARCHAR2,
								  i_Prod_Id		IN	VARCHAR2,								  
								  i_Cust_Pref_Vendor IN VARCHAR2 
								  )
RETURN Parent_Link_LPN_List_Table IS
    This_Function       CONSTANT  VARCHAR2(30 CHAR)                 := 'Get_Parent_Link_LPN_List' ;
    This_Message                  VARCHAR2(2000 CHAR);
    LPN_Tbl                       Parent_Link_LPN_List_Table;
    l_Erm_Type                    erm.erm_type%TYPE;
  BEGIN
    
    -- Get the erm type for this PO, it's hard-coded to "PO" for FoodPro
    l_Erm_Type := 'PO';

        SELECT Parent_Link_LPN_List_Rec( Pallet_Id
                          , Parent_Pallet_Id  
						  , Erm_Type              
                          , Qty_Expected 
						  , Qty_Received
                          , Dest_Loc )                          
        BULK COLLECT INTO LPN_Tbl
          FROM ( SELECT DISTINCT
                    i.logi_loc                                Pallet_Id
				  , NVL(i.parent_pallet_id,' ')				  Parent_Pallet_Id  	
                  , l_Erm_Type                                Erm_Type  
                  , NVL(i.qoh, 0)	                          Qty_Expected
                  , NVL(i.qty_produced,  0)                   Qty_Received
                  , i.plogi_loc                               Dest_Loc
               FROM inv i 
              WHERE i.rec_id           = i_erm_id AND
					i.prod_id  		   = i_prod_id AND
					i.cust_pref_vendor = i_cust_pref_vendor AND 
					i.status		   != 'HLD' 
             ORDER BY i.logi_loc );

    This_Message := NVL( TO_CHAR(LPN_Tbl.LAST-LPN_Tbl.FIRST+1), 0 ) || ' pallets returned for '
                    || '(rec_id='         || i_erm_id
                    || ',prod_id=' 		  || i_prod_id
					|| ',cust_pref_vendor=' 		  || i_cust_pref_vendor
                    || ').';
	  pl_log.ins_msg('INFO',This_Function, This_Message, NULL,SQLCODE);

    RETURN( LPN_Tbl );
  EXCEPTION
    WHEN OTHERS THEN
      This_Message := 'Exception: BULK COLLECT getting list of LPNs/pallets.';
	  pl_log.ins_msg('INFO',This_Function, This_Message, NULL,SQLCODE);
					  
    RAISE;
END Get_Parent_Link_LPN_List;

FUNCTION Get_Parent_Link_Item_List( i_erm_id IN VARCHAR2, Table_Status OUT Server_Status )
  RETURN Parent_Link_Item_List_Table IS
    This_Function   CONSTANT  VARCHAR2(30 CHAR) := 'Get_Parent_Link_Item_List' ;
    This_Message              VARCHAR2(2000 CHAR);

    Item_Tbl                 Parent_Link_Item_List_Table;
    item                     Parent_Link_Item_List_Rec;
    num_pallets              PLS_INTEGER;
    is_table_empty           BOOLEAN;
    --l_prod_PO                char;
  BEGIN
    Table_Status:= PL_SWMS_Error_Codes.Normal;

    SELECT Parent_Link_Item_List_Rec( "Prod_Id" 
                           , "Cust_Pref_Vendor" 
						   , "UOM" 
                           , "Spc" 
                           , "Descrip"          
						   , "Mfg_SKU"
                           , "UCN"
                           , "Pick_Loc"           
						   , "Brand"
                           , Parent_Link_LPN_List_Table() )
    BULK COLLECT INTO Item_Tbl
      FROM ( SELECT DISTINCT
                    pm.prod_id                            "Prod_Id"
                  , pm.cust_pref_vendor                   "Cust_Pref_Vendor"
                  , loc.uom                               "UOM"
                  , pm.spc                                "Spc"
                  , pm.descrip                            "Descrip"
                  , pm.mfg_sku                            "Mfg_SKU"
                  , SUBSTR(pm.external_upc,9,14-9+1)      "UCN"
                  , loc.logi_loc                          "Pick_Loc"
				  , pm.brand							  "Brand" 
               FROM pm 
			   INNER JOIN inv ON ( inv.prod_id = pm.prod_id AND inv.cust_pref_vendor = pm.cust_pref_vendor ) 
			   LEFT OUTER JOIN loc         ON ( loc.prod_id = pm.prod_id and loc.cust_pref_vendor = pm.cust_pref_vendor 
												and loc.uom in ( 0, 2 ) and loc.rank = 1 )
               WHERE inv.rec_id = i_erm_Id 
			     AND inv.status != 'HLD' 
             ORDER BY pm.prod_id );
    
	    Is_Table_empty := Item_Tbl IS EMPTY;
      
      IF Is_Table_empty THEN 
        Table_Status := RF.STATUS_INV_PO; 
         This_Message := 'No items returned for '
                      || '(PO_NO=' || i_erm_Id
                      || ').';
      
         PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                             , i_ModuleName  => This_Function
                             , i_Message     => This_Message
                             , i_Category    => G_Msg_Category
                             , i_Add_DB_Msg  => FALSE
                             , i_ProgramName => gl_pkg_name );
      END IF;
    
	    IF NOT is_table_empty THEN
        This_Message := NVL( TO_CHAR(Item_Tbl.LAST-Item_Tbl.FIRST+1), 0 ) || ' items returned for '
                          || '(PO_NO=' || i_erm_Id
                          || ').';
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => TRUE
                            , i_ProgramName => gl_pkg_name
                            );

        FOR item IN Item_Tbl.First..Item_Tbl.Last LOOP
          Item_Tbl(item).LPN_Table := Get_Parent_Link_LPN_List( i_erm_Id, Item_Tbl(item).Prod_Id, Item_Tbl(item).Cust_Pref_Vendor );
          num_pallets := ( NVL( Item_Tbl(item).LPN_Table.Last, -1 )
                - NVL( Item_Tbl(item).LPN_Table.First, 0 )
                + 1 );  
        END LOOP;
      END IF;

    RETURN( Item_Tbl );

  EXCEPTION
    WHEN OTHERS THEN
      This_Message := 'Exception: BULK COLLECT getting list of Product/Items.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => gl_pkg_name 
                          );
      RAISE;
END Get_Parent_Link_Item_List;
  
FUNCTION Get_PO_List_Within_Loc( i_loc IN VARCHAR2 )
  RETURN SWMS.Parent_Link_PO_List_Table IS
    This_Function   CONSTANT  VARCHAR2(30 CHAR) := 'Get_PO_List_Within_Loc' ;
    This_Message              VARCHAR2(2000 CHAR);
    PO_Tbl                    Parent_Link_PO_List_Table;
    
  BEGIN
	SELECT Parent_Link_PO_List_Rec( "erm_id", "rec_date", Parent_Link_Item_List_Table())
    BULK COLLECT INTO PO_Tbl 
    FROM (SELECT DISTINCT i.rec_Id    "erm_id", 
				 TO_CHAR( i.Rec_Date, G_RF_Date_Format ) "rec_date" 
			FROM inv i
		   WHERE i.plogi_loc = i_loc 
			 AND i.status != 'HLD'
		ORDER BY i.rec_Id ) ; 
	
    This_Message := NVL( TO_CHAR(PO_Tbl.LAST-PO_Tbl.FIRST+1), 0 ) || ' POs returned for '
                    || '(Loc=' || i_loc
                    || ').';
    pl_log.ins_msg('INFO',This_Function, This_Message, NULL, NULL);
								
    RETURN( PO_Tbl );
  EXCEPTION
    WHEN OTHERS THEN
      This_Message := 'Exception: BULK COLLECT getting list of POs.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => gl_pkg_name
                          );
      RAISE;
END Get_PO_List_Within_Loc;
  
FUNCTION Get_Return_Object_PO( i_loc IN VARCHAR2 )
RETURN SWMS.Parent_Link_PO_List_Obj IS
    This_Function   CONSTANT  VARCHAR2(30 CHAR) := 'Get_Return_Object_PO' ;
    This_Message              VARCHAR2(2000 CHAR);
    o_table_status           Server_Status;
    o_Detail_Collection      Parent_Link_PO_List_Obj;
    PO_Tbl                   Parent_Link_PO_List_Table;
    RF_Status               rf.status := rf.STATUS_NORMAL;
    e_fail                   EXCEPTION;
    
BEGIN
    PO_Tbl := Get_PO_List_Within_Loc( i_loc );
        
    FOR po IN NVL(PO_Tbl.First,0)..NVL(PO_Tbl.Last,-1) LOOP
         This_Message := 'PO(' || TO_CHAR(po) || ').ERM_Id=' || PO_Tbl(po).ERM_Id || ', .Rec_Date=' || PO_Tbl(po).Rec_Date ;
         pl_log.ins_msg('INFO', gl_pkg_name||'.'||This_Function, This_Message, sqlcode, SQLERRM);
        PO_Tbl(po).Item_Table := Get_Parent_Link_Item_List( PO_Tbl(po).ERM_Id, o_table_status );
		  
         IF o_table_status <>  RF.Status_Normal THEN
            RF_Status := o_table_status;
            RAISE e_fail;
         END IF;
          
		  This_Message := 'PO(' || TO_CHAR(po) || ').Item_Table Count=' || ( PO_Tbl(po).Item_Table.Last - PO_Tbl(po).Item_Table.First + 1 );
          pl_log.ins_msg('INFO', gl_pkg_name||'.'||This_Function, This_Message, sqlcode, SQLERRM);
    END LOOP;

    o_Detail_Collection := Parent_Link_PO_List_Obj( PO_Tbl );
    return o_Detail_Collection;
END Get_Return_Object_PO; 

  
/*  Function Link() : This function has been directly called by RF program 
	a.	Takes the supplied child and parent LPs and links them in the database.
	b.	If successful, outputs a refreshed list 	
*/
FUNCTION Link(
    i_RF_Log_Init_Record    IN      RF_Log_Init_Record,            /* Input: RF device initialization record */
    i_Child_LP              IN      VARCHAR2,                       /* Input: Child LP */
    i_Parent_LP             IN      VARCHAR2,                      /* Input: Parent LP */
    i_Scan_Method           IN      VARCHAR2,                      /* Input: (S)can or (K)eyboard */
    o_Detail_Collection     OUT     Parent_Link_PO_List_Obj        /* Output: complex object of arrays */
)
RETURN RF.Status IS

   function_name CONSTANT  swms_log.procedure_name%TYPE := 'Link';
   l_message               swms_log.msg_text%TYPE;
   l_pallet_id             inv.logi_loc%TYPE;
   l_parent                inv.parent_pallet_id%TYPE;
   RF_Status               rf.status := rf.STATUS_NORMAL;
   l_erm_id                inv.rec_Id%TYPE;
   l_order_id		   	   inv.inv_order_id%TYPE;
   l_loc				   inv.plogi_loc%TYPE;
   o_table_status           Server_Status;
   e_fail                   EXCEPTION;
   PO_Tbl                   Parent_Link_PO_List_Table;
   l_temp_cnt				NUMBER := 0;
   l_temp_erm_cnt			NUMBER := 0;   

  BEGIN
	-- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
    -- This must be done before calling rf.Initialize().
    o_Detail_Collection     := Parent_Link_PO_List_Obj( Parent_Link_PO_List_Table( ) );

    -- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.
    RF_Status := RF.Initialize( i_RF_Log_Init_Record );

    IF ( RF_Status = RF.Status_Normal ) THEN
		-- main business logic BEGINs...
		-- Record input from RF device to web service

		RF.LogMsg(RF.Log_Info, function_name || ': Input from RF'
                             || ': Child LPN='            || NVL( i_Child_LP              , 'NULL' )
							 || ', Parent LPN='           || NVL( i_Parent_LP             , 'NULL' )
                             || ', Scan_Method='          || NVL( i_Scan_Method			  ,	'NULL' )
				);
				
	  	-- Validate if the child pallet is valid	
		RF_Status := validate_child_pallet(i_Child_LP);
		
	    IF RF_Status = rf.STATUS_NORMAL THEN
		     BEGIN

				SELECT parent_pallet_id, rec_id, plogi_loc, inv_order_id 
				INTO l_parent, l_erm_id, l_loc, l_order_id 
				FROM inv
				WHERE logi_loc = i_Child_LP 
				  AND status = 'AVL'
				FOR UPDATE OF parent_pallet_id WAIT 3;

				RF_Status := validate_parent_pallet(i_Parent_LP, l_loc);

				-- If input Parent LP is not child LP and it doesn't exists already in different location 
				-- Add the new child to the parent and set INV.STATUS 
				IF RF_Status = rf.STATUS_NORMAL THEN			
					UPDATE inv
					   SET parent_pallet_id = i_Parent_LP,
						   status = 'CDK' 					   
					 WHERE logi_loc = i_Child_LP
					   AND status = 'AVL';

							-- Insert Child LP first 
						Insert into CROSS_DOCK_DATA_COLLECT (ERM_ID, REC_TYPE, PROD_ID, QTY, UOM, PALLET_ID, PARENT_PALLET_ID, ADD_USER, ADD_DATE) 
						select REC_ID, 'D', INV.PROD_ID, QOH, nvl(ORDD.UOM, 2), LOGI_LOC, PARENT_PALLET_ID, 'SWMS', SYSDATE  
						  from INV, ORDD 
						 where INV.INV_ORDER_ID = ORDD.ORDER_ID
                           and INV.PROD_ID = ORDD.PROD_ID
                           and LOGI_LOC = i_Child_LP 
                           and ROWNUM=1;
						
						-- Insert Catch Weight records for all the cases of this child pallet 
						Insert into CROSS_DOCK_DATA_COLLECT (ERM_ID, REC_TYPE, PROD_ID, PALLET_ID, PARENT_PALLET_ID, CATCH_WT, ADD_USER, ADD_DATE) 
						select REC_ID,'C', PROD_ID, LOGI_LOC, l_parent, weight, 'SWMS', SYSDATE 
						  from inv_cases i 
						 where LOGI_LOC = i_Child_LP;
						 
						-- check if parent exists first, Insert if no Parent exists already 
						select count(parent_pallet_id) 
						  into l_temp_cnt
						  from CROSS_DOCK_PALLET_XREF 
						 where PARENT_PALLET_ID=i_Parent_LP;
						
						if (l_temp_cnt = 0) then 
							Insert into CROSS_DOCK_PALLET_XREF (RETAIL_CUST_NO,ERM_ID,SYS_ORDER_ID,PARENT_PALLET_ID,SHIP_DATE, ADD_USER,ADD_DATE) 
							select i.INV_CUST_ID, i.REC_ID, i.INV_ORDER_ID, i.PARENT_PALLET_ID, i.SHIP_DATE, 'SWMS', SYSDATE 
							  from inv i 
							 where i.PARENT_PALLET_ID=i_Parent_LP;
						end if;
						
							-- check if the po and order_id already exists before inserting 
						select count(*) 
						  into l_temp_erm_cnt 
						  from CROSS_DOCK_XREF 
						 where erm_id = l_erm_id
						   and sys_order_id = l_order_id;
						
						if (l_temp_erm_cnt = 0) then
							Insert into CROSS_DOCK_XREF (ERM_ID,SYS_ORDER_ID,STATUS,ADD_DATE) 
							Select l_erm_id, l_order_id, 'NEW', SYSDATE from dual;
						end if;
																	   
					COMMIT;
				    pl_log.ins_msg(
						'INFO', function_name, 'child pallet_id [' || i_Child_LP || '] linked with parent pallet ['|| i_Parent_LP 
								|| ']', sqlcode, SQLERRM);
								
				ELSE
					ROLLBACK;
				END IF;
				
		     EXCEPTION 
			     WHEN NO_DATA_FOUND THEN
					-- If the inputted LP does not exist, then return an error.
					RF.Complete(rf.STATUS_INV_LABEL);
					RETURN rf.STATUS_INV_LABEL;

				 WHEN OTHERS THEN
					  pl_log.ins_msg(
						'FATAL', function_name, 'Unable to LINK parent pallet ['|| i_Parent_LP 
								|| '], child pallet_id [' || i_Child_LP || ']', sqlcode, SQLERRM);
			 END;
		ELSE
			RF.Complete(rf.STATUS_INVALID_PARENT_LP);
			RETURN rf.STATUS_INVALID_PARENT_LP;			
	    END IF; --child validation
		
        o_Detail_Collection := Get_Return_Object_PO( l_loc );

	    ELSE
		  ROLLBACK;
	    END IF; -- Initialization 
  	   
    RF.Complete(RF_Status);

	RETURN RF_Status;
	
 EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- If the inputted LP does not exist, then return an error.
		RF.Complete(rf.STATUS_INV_LABEL);
        RETURN rf.STATUS_INV_LABEL;
    WHEN OTHERS THEN
        ROLLBACK;
            pl_log.ins_msg('INFO',function_name,
                                    'Exception: While linking the Master pallet with child=['
                                    ||i_Child_LP||'], Parent['
                                    ||i_Parent_LP ||']'
                                    ||' ACTION=UPDATE REASON='
                                    ||'Unable to update INV table '
                                    ||'SQLERRM='||SQLERRM
                                     ,NULL,SQLCODE);
	 RF.LogException( );     -- log it
	
	 RF.Complete(rf.STATUS_INV_LABEL);
     RETURN rf.STATUS_INV_LABEL;

END Link;

FUNCTION Unlink(
    i_RF_Log_Init_Record    IN      RF_Log_Init_Record,            /* Input: RF device initialization record */
    i_Child_LP              IN      VARCHAR2,                      /* Input: Child LP */
    i_Scan_Method           IN      VARCHAR2,                      /* Input: (S)can or (K)eyboard */
    o_Detail_Collection     OUT     Parent_Link_PO_List_Obj        /* Output: complex object of arrays */
)
RETURN RF.Status IS

   function_name CONSTANT  swms_log.procedure_name%TYPE := 'Unlink';
   l_message               swms_log.msg_text%TYPE;
   l_Parent_LP             inv.logi_loc%TYPE := NULL;
   l_Child_LP              inv.logi_loc%TYPE := NULL;
   RF_Status               rf.status := rf.STATUS_NORMAL;
   l_loc				   inv.plogi_loc%TYPE;
   o_table_status           Server_Status;
   e_fail                   EXCEPTION;
   PO_Tbl                   Parent_Link_PO_List_Table;
   l_erm_id				    inv.rec_id%TYPE;
   l_order_id				inv.inv_order_id%TYPE;
   l_status 				inv.status%TYPE;
   l_child_count			NUMBER := 0;
   l_temp					NUMBER := 0;
  BEGIN
	-- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
    -- This must be done before calling rf.Initialize().
    o_Detail_Collection     := Parent_Link_PO_List_Obj( Parent_Link_PO_List_Table( ) );

    -- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.
    RF_Status := RF.Initialize( i_RF_Log_Init_Record );

    IF ( RF_Status = RF.Status_Normal ) THEN
		-- main business logic BEGINs...
		-- Record input from RF device to web service
		RF.LogMsg(RF.Log_Info, function_name || ': Input from RF'
                             || ': Child LPN='            || NVL( i_Child_LP              , 'NULL' )
                             || ', Scan_Method='          || NVL( i_Scan_Method			  ,	'NULL' )
				);
	  	
	    RF_Status := validate_child_pallet(i_Child_LP);

	    -- Add the new child to the parent
	    IF RF_Status = rf.STATUS_NORMAL THEN
		     --BEGIN
				SELECT parent_pallet_id, plogi_loc, rec_id, inv_order_id, status  
				INTO l_Parent_LP, l_loc, l_erm_id, l_order_id, l_status 
				FROM inv
				WHERE logi_loc = i_Child_LP
				FOR UPDATE OF parent_pallet_id WAIT 3;
			
				-- If input Parent LP is not same as exisitng parent LP
				IF ( l_Parent_LP IS NOT NULL) THEN 
					UPDATE inv
					   SET parent_pallet_id = NULL,
						   status = 'AVL'
					 WHERE logi_loc = i_Child_LP;
					
					-- Delete Unlinked child LP 
					DELETE FROM CROSS_DOCK_DATA_COLLECT 
					 WHERE PALLET_ID = i_Child_LP
					   AND PARENT_PALLET_ID = l_Parent_LP;
					
					-- Check if any more child LPs for the same parent of unlinked LP
					SELECT COUNT(PALLET_ID) INTO l_child_count 
					  FROM CROSS_DOCK_DATA_COLLECT 
					 WHERE PARENT_PALLET_ID = l_Parent_LP
					   AND ERM_ID = l_erm_id;
					
					IF l_child_count = 0 THEN 
						DELETE FROM CROSS_DOCK_PALLET_XREF  
						 WHERE PARENT_PALLET_ID = l_Parent_LP
						   AND ERM_ID = l_erm_id;		 
					END IF;				

					-- Check if any more parent LPs exists for same PO
					SELECT COUNT(PARENT_PALLET_ID) INTO l_temp  
					  FROM CROSS_DOCK_PALLET_XREF 
					 WHERE --PARENT_PALLET_ID = l_Parent_LP AND 
					    ERM_ID = l_erm_id;
					
					IF l_temp = 0 THEN 
						DELETE FROM CROSS_DOCK_XREF  
						 WHERE ERM_ID = l_erm_id;
						   --AND SYS_ORDER_ID = l_order_id;		 
					END IF; 
					 
					COMMIT;
				    pl_log.ins_msg(
						'INFO', function_name, 'Unlink completed successfully, For Parent ['|| l_Parent_LP  
								|| '], child pallet_id [' || i_Child_LP || ']', sqlcode, SQLERRM);

				ELSE
					ROLLBACK;
				END IF;
		     /*EXCEPTION 
				WHEN OTHERS THEN
					  pl_log.ins_msg(
						'FATAL', function_name, 'Unable to Unlink pallet from Parent ['|| l_Parent_LP  
								|| '], child pallet_id [' || i_Child_LP || ']', sqlcode, SQLERRM);
			 END; */
	    END IF;
		
        o_Detail_Collection := Get_Return_Object_PO( l_loc );
	ELSE
		--ROLLBACK;
	    pl_log.ins_msg(
			'FATAL', function_name, 'Unable to Unlink child pallet_id [' || i_Child_LP || ']', sqlcode, SQLERRM);

		RF.Complete(rf.STATUS_INV_LABEL);
        RETURN rf.STATUS_INV_LABEL;
	END IF;
  	   
    RF.Complete(RF_Status);
	RETURN RF_Status;
	
 EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- If the inputted LP does not exist, then return an error.
	    pl_log.ins_msg(
				'INFO', function_name, 'No data found in Unlink for child pallet_id [' || i_Child_LP || ']', sqlcode, SQLERRM);
		RF.Complete(rf.STATUS_INV_LABEL);
        RETURN rf.STATUS_INV_LABEL;
    WHEN OTHERS THEN
        --ROLLBACK;
            pl_log.ins_msg('INFO',function_name,
                                    'Exception: While Unlinking the Parent pallet with child=['
                                    ||i_Child_LP||']'
                                    ||' ACTION=UPDATE REASON='
                                    ||'Unable to Unlink Pallet Id '
                                    ||'SQLERRM='||SQLERRM
                                     ,NULL,SQLCODE);
		RF.LogException( );     -- log it
		RF.Complete(rf.STATUS_INV_LABEL);
        RETURN rf.STATUS_INV_LABEL;
END Unlink;


FUNCTION Refresh(
    i_RF_Log_Init_Record    IN      RF_Log_Init_Record,            /* Input: RF device initialization record */
    i_LP                    IN      VARCHAR2,                      /* Input: Any parent or child LP */
    i_Scan_Method           IN      VARCHAR2,                      /* Input: (S)can or (K)eyboard */
    o_Detail_Collection     OUT     Parent_Link_PO_List_Obj        /* Output: complex object of arrays */
)
RETURN RF.Status IS
   function_name  CONSTANT swms_log.procedure_name%TYPE := 'Refresh';
   l_parent                inv.parent_pallet_id%TYPE;
   l_loc                   inv.plogi_loc%TYPE;
   status                  rf.status := rf.STATUS_NORMAL;
   l_message               varchar2(2000);
   
BEGIN
    -- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
    -- This must be done before calling rf.Initialize().
    o_Detail_Collection     := Parent_Link_PO_List_Obj( Parent_Link_PO_List_Table( ) );
   
   l_message := 'Input from RF: i_pallet_id=' || i_LP ||', Scan Method='||i_Scan_Method;
   pl_log.ins_msg('INFO',function_name, l_message, NULL,SQLCODE);        
 
   RF.LogMsg(RF.Log_Info, function_name || ': Input from RF'
                             || ': LPN='            || NVL( i_LP                    ,'NULL' )
							 || ', Scan_Method='    || NVL( i_Scan_Method			 ,'NULL' )
				);
	
   status := rf.initialize(i_rf_log_init_record);
   IF status != rf.STATUS_NORMAL THEN
      RF.Complete(status);
      RETURN status;
   END IF;
   
   -- Check if the input LP is a parent. 
   IF NOT f_parent_exists_in_inv(i_LP) THEN
		  pl_log.ins_msg('INFO',function_name, 'Input LP is not Parent LP', NULL,SQLCODE);

		-- Check to see if the LP exists in inventory. If it does, then get the location for that LP.
        -- If not, check if the input LP is parent LP
   
        -- Check to make sure that the pallet isn't the home location, and that it's in the correct zone 
         status := validate_child_pallet(i_LP);

         IF status != rf.STATUS_NORMAL THEN
            RF.Complete(status);
            RETURN status;
         END IF;

         SELECT inv.parent_pallet_id, inv.plogi_loc 
         INTO l_parent, l_loc 
         FROM inv
         WHERE inv.logi_loc = i_LP;
	    pl_log.ins_msg('INFO',function_name, 'parent LP for LP='||i_LP||', Parent LP=' ||l_parent||', Loc='||l_loc, NULL,SQLCODE);        
    ELSE
        SELECT inv.plogi_loc 
         INTO l_loc 
         FROM inv
         WHERE inv.parent_pallet_id = i_LP
         AND ROWNUM=1;
	    pl_log.ins_msg('INFO',function_name, 'Parent LP=' ||l_parent||', Loc='||l_loc, NULL,SQLCODE);        
    END IF;
    
	IF (l_loc IS NOT NULL) THEN 
	    pl_log.ins_msg('INFO',function_name, 'Location is Not null.  LP='||i_LP||', Parent LP=' ||l_parent||', Loc='||l_loc, NULL,SQLCODE);        	
        o_Detail_Collection := Get_Return_Object_PO( l_loc );
        pl_log.ins_msg('INFO',function_name, 'l_loc='||l_loc, NULL,SQLCODE);      
	ELSE
		    pl_log.ins_msg('INFO',function_name, 'Location is  null.  LP='||i_LP||', Parent LP=' ||l_parent||', Loc='||l_loc, NULL,SQLCODE);        	
	END IF;
    
   RF.Complete(rf.STATUS_NORMAL);
   RETURN rf.STATUS_NORMAL;
 EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- If the inputted LP does not exist, then return an error.
	  	  pl_log.ins_msg('INFO','PL_RF_BUILD_MASTER_LP.Refresh()',
						   'No data found returned for LP=['
							||i_LP||'], SQLERRM='||SQLERRM
							 ,NULL,SQLCODE);
 		RF.Complete(rf.STATUS_INV_LABEL);
        RETURN rf.STATUS_INV_LABEL;
    WHEN OTHERS THEN
        ROLLBACK; 
          pl_log.ins_msg('INFO',function_name,
                                    'Exception: Refresh LP=['
                                    ||i_LP||'] '||'SQLERRM='||SQLERRM
                                     ,NULL,SQLCODE);
 	 RF.LogException( );     -- log it
     RF.Complete(rf.STATUS_INV_LABEL);
     RETURN rf.STATUS_INV_LABEL;
END Refresh;

FUNCTION NewParent(
    i_RF_Log_Init_Record    IN      RF_Log_Init_Record,            /* Input: RF device initialization record */
    o_NewParentLp           OUT     VARCHAR2                       /* Output: LP of new parent */
)
RETURN RF.Status IS 
   function_name  CONSTANT swms_log.procedure_name%TYPE := 'NewParent';
   l_parent                inv.parent_pallet_id%TYPE;
   status                  rf.status := rf.STATUS_NORMAL;
   l_message               varchar2(2000);
   
BEGIN
    -- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
    -- This must be done before calling rf.Initialize().
	o_NewParentLp			:=  ' ';
   
    l_message := 'Input from RF: NewParent() function call';
    pl_log.ins_msg('INFO',function_name, l_message, NULL,SQLCODE);        
 
    RF.LogMsg(RF.Log_Info, function_name || 'Input from RF: starting function...' );
	
    status := rf.initialize(i_rf_log_init_record);
    IF status != rf.STATUS_NORMAL THEN
       RF.Complete(status);
       RETURN status;
    END IF;
    
    -- Create a new parent LP
    l_parent := pl_common.f_get_new_pallet_id;
    pl_log.ins_msg('INFO',function_name, 'New Parent LP=' ||l_parent, NULL,SQLCODE);        

    o_NewParentLp := l_parent;
    pl_log.ins_msg('INFO',function_name, 'o_NewParentLp='||o_NewParentLp, NULL,SQLCODE);
            
    RF.Complete(rf.STATUS_NORMAL);
    RETURN rf.STATUS_NORMAL;
 EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
            pl_log.ins_msg('FATAL',function_name,
                                    'Exception: In NewParent SQLERRM='||SQLERRM
                                     ,NULL,SQLCODE);
 	 RF.LogException( );     -- log it
END NewParent;
/* END OPCOF-759 : Added for Linking Parent pallet with child pallets for FoodPro */ 

END pl_rf_build_master_lp;
/
show errors;


alter package swms.pl_rf_build_master_lp compile plsql_code_type = native;

grant execute on swms.pl_rf_build_master_lp to swms_user;
create or replace public synonym pl_rf_build_master_lp for swms.pl_rf_build_master_lp;
