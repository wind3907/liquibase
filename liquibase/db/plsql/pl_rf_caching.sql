create or replace PACKAGE      PL_RF_CACHING AS

Procedure Get_Cache_data(i_erm_id  IN  putawaylst.rec_id%type DEFAULT NULL);

FUNCTION Calculate_cache_flag(i_pallet_id  IN  putawaylst.pallet_id%type DEFAULT NULL) RETURN VARCHAR2;

END PL_RF_CACHING;
/

create or replace PACKAGE BODY PL_RF_CACHING AS

 --------------------------------------------------------------------------------
-- Package:
--    PL_RF_CACHING
--
-- Description:
--    This Package is to implement caching for RF.
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------------
--    02/09/17 sont9212 Sunil Ontipalli, authored
--------------------------------------------------------------------------------

 --------------------------------------------------------------------------------
-- Procedure:
--    Get_Cache_data
--
-- Description:
--    This function loads the temporary table.
--
-- Parameters:
--    i_erm_id     - Po number for which the data to be cached.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------------
--    02/08/17 sont9212 Sunil Ontipalli, authored
--------------------------------------------------------------------------------
Procedure Get_Cache_data( i_erm_id   IN  putawaylst.rec_id%type DEFAULT NULL)
IS
  This_Function   CONSTANT  VARCHAR2(30)  := 'Get_Cache_data';
  This_Message              VARCHAR2(2000);
  l_load_no                 ERM.load_no%type;
  l_curr_user               VARCHAR2(50);
  CURSOR c_get_po_list IS SELECT pallet_id ,rec_id ,prod_id ,dest_loc,qty,uom,status,zone_id,lot_id
           ,exp_date,weight,temp,mfg_date,qty_expected,qty_received,date_code
		   ,exp_date_trk,lot_trk,catch_wt,temp_trk,putaway_put,erm_line_id
		   ,print_status,clam_bed_trk,add_date,add_user,upd_date,upd_user
		   ,tti,tti_trk,cryovac,po_line_id,cool_trk
      FROM putawaylst  
	 WHERE rec_id IN 
	                (SELECT erm_id 
					   FROM erm 
					  WHERE load_no = l_load_no);
	
  BEGIN 
  
    ---Logging an info message for debugging purpose---  
	
     This_Message := 'Get_Cache_data started for PO'
                    || '(erm_id=' || i_erm_Id
                    || ').';
					
     PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                        , i_ModuleName  => This_Function
                        , i_Message     => This_Message
                        , i_Category    => PL_RCV_Open_PO_Types.CT_Application_Function
                        , i_Add_DB_Msg  => FALSE
                        , i_ProgramName => $$PLSQL_UNIT
                        );
						
	 ---Getting the user info into the table--
	 BEGIN
      SELECT USER
          INTO l_curr_user
          FROM Dual;
  	 EXCEPTION
	   WHEN OTHERS THEN
	     PL_Log.Ins_Msg( 'INFO', This_Function, 'get_cache_exception getting user', null, null
                         , PL_RCV_Open_PO_Types.CT_Application_Function, 'PL_RF_lIVE_RECEIVING', 'N' ); 
     END;	  
    
     ---Getting the Load no for the current pallet Id--- 

      BEGIN	  
	     SELECT load_no
           INTO l_load_no		 
		   FROM erm 
		  WHERE erm_id = (i_erm_id);		  
      EXCEPTION
	   WHEN OTHERS THEN
	     PL_Log.Ins_Msg( 'INFO', This_Function, 'get_cache_exception getting load number', null, null
                         , PL_RCV_Open_PO_Types.CT_Application_Function, 'PL_RF_lIVE_RECEIVING', 'N' ); 
      END;	  
      
   ---Deleting the Data from user downloaded po for that user---
   Begin
    Delete from USER_DOWNLOADED_PO where user_id = l_curr_user; 
    
   Exception
   When Others then
    PL_Log.Ins_Msg( 'INFO', This_Function, 'get_cache_exception deleting USER_DOWNLOADED_PO', null, null
                         , PL_RCV_Open_PO_Types.CT_Application_Function, 'PL_RF_lIVE_RECEIVING', 'N' );
   End;
	  
	 ---Getting the list of tasks for all the PO's of that Load and inserting the data into USER_DOWNLOADED_PO--- 
	 
	 FOR I IN c_get_po_list
	 LOOP
		
	  BEGIN
	  
	  INSERT INTO USER_DOWNLOADED_PO(		  
	  pallet_id ,rec_id ,prod_id ,dest_loc,qty,uom,status,zone_id,lot_id
           ,exp_date,weight,temp,mfg_date,qty_expected,qty_received,date_code
		   ,exp_date_trk,lot_trk,catch_wt,temp_trk,putaway_put,erm_line_id
		   ,print_status,clam_bed_trk,putawaylst_add_date,putawaylst_add_user
		   ,tti,tti_trk,cryovac,po_line_id,cool_trk, user_id)
		 VALUES(I.pallet_id ,I.rec_id ,I.prod_id ,I.dest_loc,I.qty,I.uom,I.status,I.zone_id,I.lot_id
           ,I.exp_date,I.weight,I.temp,I.mfg_date,I.qty_expected,I.qty_received,I.date_code
		   ,I.exp_date_trk,I.lot_trk,I.catch_wt,I.temp_trk,I.putaway_put,I.erm_line_id
		   ,I.print_status,I.clam_bed_trk,sysdate,l_curr_user
		   ,I.tti,I.tti_trk,I.cryovac,I.po_line_id,I.cool_trk, l_curr_user);
	  EXCEPTION
       WHEN OTHERS THEN
	     PL_Log.Ins_Msg( 'INFO', This_Function, 'get_cache_exception inserting in USER_DOWNLOADED_PO', null, null
                         , PL_RCV_Open_PO_Types.CT_Application_Function, 'PL_RF_lIVE_RECEIVING', 'N' ); 
	  END;	   
		 
     END LOOP;		 
     
  EXCEPTION

    WHEN OTHERS THEN
      -- Got some oracle error.  Log a message and raise an exception.
	  PL_Log.Ins_Msg( 'INFO', This_Function, 'get_cache_exception Unknown Exception', null, null
                         , PL_RCV_Open_PO_Types.CT_Application_Function, 'PL_RF_lIVE_RECEIVING', 'N' );
						 
      This_Message := 'Unknown error occured when Calculating cache_flag for Rec Id:'||i_erm_id;
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => PL_RCV_Open_PO_Types.CT_Application_Function
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => $$PLSQL_UNIT
                          );
      Raise_Application_Error( PL_Exc.CT_Database_Error
                             ,    $$PLSQL_UNIT || '.'
                               || This_Function  || '-'
                               || PL_RCV_Open_PO_Types.CT_Application_Function || ': '
                               || This_Message
                             );
	
  END Get_Cache_data;

--------------------------------------------------------------------------------
-- Function:
--    Calculate_cache_flag
--
-- Description:
--    This function determines whether caching is needed or not.
--
-- Parameters:
--    i_pallet_id     - Pallet Id from which we derive the Load information.
--
-- Returns:
--     cache_flag     - Function will return one of the following values either N - Refresh the List or Y - Not Refresh the List
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------------
--    02/08/17 sont9212 Sunil Ontipalli, authored
--------------------------------------------------------------------------------

FUNCTION Calculate_cache_flag( i_pallet_id            IN  putawaylst.pallet_id%type DEFAULT NULL)
RETURN VARCHAR2 IS
  This_Function   CONSTANT  VARCHAR2(30)  := 'Calculate_cache_flag';
  This_Message              VARCHAR2(2000);
  l_count                   NUMBER;
  l_load_no                 ERM.load_no%type;
  l_cache_flag              VARCHAR2(1);
  l_curr_user               VARCHAR2(50);
	
  BEGIN
  
    ---Logging an info message for debugging purpose---  
	
     This_Message := 'Calculate_cache_flag function started for Pallet'
                    || '(Pallet_Id=' || i_Pallet_Id
                    || ').';
					
     PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                        , i_ModuleName  => This_Function
                        , i_Message     => This_Message
                        , i_Category    => PL_RCV_Open_PO_Types.CT_Application_Function
                        , i_Add_DB_Msg  => FALSE
                        , i_ProgramName => $$PLSQL_UNIT
                        );
						
	 ---Getting the user info into the table--
	 BEGIN
      SELECT USER
          INTO l_curr_user
          FROM Dual;
  	 EXCEPTION
	   WHEN OTHERS THEN
	     PL_Log.Ins_Msg( 'INFO', This_Function, 'Calculate_Cache_flag_exception getting the current user', null, null
                         , PL_RCV_Open_PO_Types.CT_Application_Function, 'PL_RF_lIVE_RECEIVING', 'N' );
	     l_cache_flag := 'N';
	     RETURN l_cache_flag;
     END;	  
    
     ---Getting the Load no for the current pallet Id--- 

      BEGIN
	  
	     SELECT load_no
           INTO l_load_no		 
		   FROM erm 
		  WHERE erm_id = (SELECT rec_id 
		                    FROM putawaylst 
						   WHERE pallet_id = i_pallet_id);
		  
      EXCEPTION
	   WHEN OTHERS THEN
	     PL_Log.Ins_Msg( 'INFO', This_Function, 'Calculate_Cache_flag_exception getting the load number', null, null
                         , PL_RCV_Open_PO_Types.CT_Application_Function, 'PL_RF_lIVE_RECEIVING', 'N' );
	     l_cache_flag := 'N';
	     RETURN l_cache_flag;
      END;	  
	  
	 ---Getting the list of tasks for all the PO's of that Load and comparing to see whether to refresh or not--- 
					  
	 SELECT COUNT(0) 
	   INTO l_count
	   FROM 				  
	  (((SELECT pallet_id ,rec_id ,prod_id ,dest_loc,qty,uom,status,zone_id,lot_id
           ,exp_date,weight,temp,mfg_date,qty_expected,qty_received,date_code
		   ,exp_date_trk,lot_trk,catch_wt,temp_trk,putaway_put,erm_line_id
		   ,print_status,clam_bed_trk
		   ,tti,tti_trk,cryovac,po_line_id,cool_trk
      FROM putawaylst  
	 WHERE rec_id IN 
	                (SELECT erm_id 
					   FROM erm 
					  WHERE load_no = l_load_no) AND pallet_id <> i_pallet_id))
	 MINUS
	 SELECT pallet_id ,rec_id ,prod_id ,dest_loc,qty,uom,status,zone_id,lot_id
           ,exp_date,weight,temp,mfg_date,qty_expected,qty_received,date_code
		   ,exp_date_trk,lot_trk,catch_wt,temp_trk,putaway_put,erm_line_id
		   ,print_status,clam_bed_trk
		   ,tti,tti_trk,cryovac,po_line_id,cool_trk
      FROM USER_DOWNLOADED_PO
     WHERE user_id = l_curr_user
       AND pallet_id <> i_pallet_id
     UNION ALL
	 (SELECT pallet_id ,rec_id ,prod_id ,dest_loc,qty,uom,status,zone_id,lot_id
           ,exp_date,weight,temp,mfg_date,qty_expected,qty_received,date_code
		   ,exp_date_trk,lot_trk,catch_wt,temp_trk,putaway_put,erm_line_id
		   ,print_status,clam_bed_trk
		   ,tti,tti_trk,cryovac,po_line_id,cool_trk
      FROM USER_DOWNLOADED_PO
     WHERE user_id = l_curr_user
       AND pallet_id <> i_pallet_id
	 MINUS
	 SELECT pallet_id ,rec_id ,prod_id ,dest_loc,qty,uom,status,zone_id,lot_id
           ,exp_date,weight,temp,mfg_date,qty_expected,qty_received,date_code
		   ,exp_date_trk,lot_trk,catch_wt,temp_trk,putaway_put,erm_line_id
		   ,print_status,clam_bed_trk
		   ,tti,tti_trk,cryovac,po_line_id,cool_trk
      FROM putawaylst  
	 WHERE rec_id IN 
	                (SELECT erm_id 
					   FROM erm 
					  WHERE load_no = l_load_no) AND pallet_id <> i_pallet_id));
	 
	  IF l_count = 0 THEN
         l_cache_flag := 'Y';
	  ELSE
	     l_cache_flag := 'N';	  
      END IF;

     RETURN l_cache_flag;
     
  EXCEPTION

    WHEN OTHERS THEN
      -- Got some oracle error.  Log a message and raise an exception.
	  PL_Log.Ins_Msg( 'INFO', This_Function, 'Calculate_Cache_flag_exception Unknown Exception', null, null
                         , PL_RCV_Open_PO_Types.CT_Application_Function, 'PL_RF_lIVE_RECEIVING', 'N' );
      This_Message := 'Unknown error occured when Calculating cache_flag for pallet Id:'||i_pallet_id;
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => PL_RCV_Open_PO_Types.CT_Application_Function
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => $$PLSQL_UNIT
                          );
      Raise_Application_Error( PL_Exc.CT_Database_Error
                             ,    $$PLSQL_UNIT || '.'
                               || This_Function  || '-'
                               || PL_RCV_Open_PO_Types.CT_Application_Function || ': '
                               || This_Message
                             );
  END Calculate_cache_flag;

END PL_RF_CACHING;
/
