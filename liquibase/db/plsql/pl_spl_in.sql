CREATE OR REPLACE PACKAGE      pl_spl_in
IS
  /*===========================================================================================================
  -- Package
  -- pl_mq_to_aq
  --
  -- Description
  --  This package processes the MQ queue messages and inserts them into Staging tables.
  --
  -- Modification History
  --
  -- Date          User         Version     Comment
  ------------    ---------     ---------   ---------- 
  -- 8/30/18      pkab6563                  For Jira card OPCOF-445 (manifest info from Asian Foods to SWMS): 
  --                                        enabled (uncommented) call to pl_spl_mf_in.parse_mf() in
  --                                        procedure MQ_PROCESS_Q_NAME.
  -- 
  -- 9/04/18      pkab6563                  For Jira card OPCOF-554, added call to pl_spl_cs_in.parse_cs()
  --                                        to procedure MQ_PROCESS_Q_NAME.
  -- 9/05/18      xzhe5043                  For Jira card OPCOF-569, added call to pl_spl_ml_in.parse_ml()
  --                                        to procedure MQ_PROCESS_Q_NAME.
  -- 9/17/18      pkab6563                  Jira #589 - Remove info-only messages to avoid filling up 
  --                                        message table.
  ============================================================================================================*/


  FUNCTION ACTIVE_QUEUE( i_swms_queue_name IN VARCHAR2 ) RETURN BOOLEAN;


  PROCEDURE MQ_PROCESS_Q_NAME;

END pl_spl_in;




/


CREATE OR REPLACE PACKAGE BODY  pl_spl_in
IS
   /*===========================================================================================================
  -- Package body
  -- pl_fp_in
  --
  -- Description
  --  This package processes the MQ queue messages and inserts them into Staging tables.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 04/12/18      mcha1213                       1.0              Initial Creation
  -- 
  ============================================================================================================*/
  This_Package        CONSTANT  VARCHAR2(30 CHAR) := 'PL_SPL_IN';
  This_Application    CONSTANT  VARCHAR2(30 CHAR) := 'FOODPRO_INTERFACE';

  Q_Status_Success    CONSTANT  VARCHAR2(1 CHAR)  := 'S';
  Q_Status_Failure    CONSTANT  VARCHAR2(1 CHAR)  := 'F';
  Q_Status_Queued     CONSTANT  VARCHAR2(1 CHAR)  := 'Q';

  RecType_Route       CONSTANT  VARCHAR2(1 CHAR)  := 'R';
  RecType_Appointment CONSTANT  VARCHAR2(1 CHAR)  := 'A';
  RecType_Order       CONSTANT  VARCHAR2(1 CHAR)  := 'O';
  RecType_Order_Line  CONSTANT  VARCHAR2(1 CHAR)  := 'L';

  K_Shipment_Inbound  CONSTANT  VARCHAR2(1 CHAR)  := '1';
  K_Shipment_Outbound CONSTANT  VARCHAR2(1 CHAR)  := '2';

  g_error_context             VARCHAR2(4000 CHAR) ;
  g_saved_error_code          NUMBER;

  /*Need to revisit the logic for the function below*/
  /*It was converted to a function since the same logic was being copied*/

  v_function_code         sap_im_in.func_code%type;
  v_item_number           sap_im_in.prod_id%type;
  v_descrip          sap_im_in.descrip%type;
  
  l_error_msg  VARCHAR2(400);
  l_error_code VARCHAR2(100);




  PROCEDURE Set_Queue_Status( i_Sequence_No IN NUMBER
                            , i_Status      IN VARCHAR2
                            , i_Err_Code    IN NUMBER     DEFAULT NULL
                            , i_Err_Text    IN VARCHAR2   DEFAULT NULL
                            , i_Old_Status  IN VARCHAR2   DEFAULT NULL
                            ) IS
    This_Function     CONSTANT  VARCHAR2(30 CHAR) := 'Set_Queue_Status';
  BEGIN
    UPDATE mq_queue_in
       SET record_status   = i_Status
         , error_msg       = i_Err_Text
         , error_code      = i_Err_Code
     WHERE sequence_number = i_Sequence_No
       AND ( i_Old_Status IS NULL OR record_status = i_Old_Status );

     commit;  

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      IF ( i_Status <> Q_Status_Queued ) OR ( i_Old_Status IS NULL ) THEN
        PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                      , i_Procedure_Name   => This_Function
                      , i_Msg_Text         => 'Error occurred while conditionally setting status for sequence #' || TO_CHAR( i_Sequence_No ) || ' on MQ_QUEUE_IN table.'
                      , i_Msg_No           => SQLCODE
                      , i_SQL_Err_Msg      => SQLERRM
                      , i_Application_Func => This_Application
                      , i_Program_Name     => This_Package
                      , i_Msg_Alert        => 'N'
                      );
      END IF;
    WHEN OTHERS THEN
      PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                    , i_Procedure_Name   => This_Function
                    , i_Msg_Text         => 'Error occurred while setting status for sequence #' || TO_CHAR( i_Sequence_No ) || ' on MQ_QUEUE_IN table.'
                    , i_Msg_No           => SQLCODE
                    , i_SQL_Err_Msg      => SQLERRM
                    , i_Application_Func => This_Application
                    , i_Program_Name     => This_Package
                    , i_Msg_Alert        => 'N'
                    );

  END Set_Queue_Status;

  FUNCTION ACTIVE_QUEUE(i_swms_queue_name IN VARCHAR2 )
  RETURN BOOLEAN IS
 /*===========================================================================================================
  -- Function
  -- ACTIVE_QUEUE
  --
  -- Description
  --   This Function returns the status of the Interface and the MQ name to process.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 
  ============================================================================================================*/
    This_Function     CONSTANT  VARCHAR2(30 CHAR) := 'ACTIVE_QUEUE';
    l_exist VARCHAR2(1);
  BEGIN
    SELECT 'Y'
      INTO l_exist
      FROM mq_interface_maint
     WHERE AQ_Queue_name = i_swms_queue_name
       AND ACTIVE_FLAG = 'Y';
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                    , i_Procedure_Name   => This_Function
                    , i_Msg_Text         => 'Error Occurred While Accessing MQ_INTERFACE_MAINT table.'
                    , i_Msg_No           => SQLCODE
                    , i_SQL_Err_Msg      => SQLERRM
                    , i_Application_Func => This_Application
                    , i_Program_Name     => This_Package
                    , i_Msg_Alert        => 'N'
                    );
      RETURN FALSE;
  END ACTIVE_QUEUE;



  PROCEDURE MQ_PROCESS_Q_NAME IS
 /*===========================================================================================================
  -- PROCEDURE
  -- MQ_PROCESS_Q_NAME
  --
  -- Description
  --   This PROCEDURE process ------ Queue and places in respective staging tables.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 04/12/18                                    1.0              Initial Creation
  -- 08/30/18           pkab6563                                  enabled (uncommented) call to 
  --                                                              pl_spl_mf_in.parse_mf()
  --
  -- 09/04/18           pkab6563                                  Added call to pl_spl_cs_in.parse_cs()
  --                                                              for CS (item cost update).
  -- 9/05/18            xzhe5043                  				  Added call to pl_spl_ml_in.parse_ml()
  --                                        
  ============================================================================================================*/
    This_Function     CONSTANT  VARCHAR2(30 CHAR) := 'MQ_PROCESS_Q_NAME';
    --------------------------local variables-----------------------------
    CURSOR c_mq_msg IS
      SELECT sequence_number, queue_name, queue_data, record_status
        FROM mq_queue_in
       WHERE queue_name like 'Q_SPL%'
	   and record_status  = 'N';--;
       --for update of record_status;



    l_sequence_number           mq_queue_in.sequence_number%TYPE;
    process_error               EXCEPTION;
    rec_no                      number :=0;
    commit_no                   number :=500;

  BEGIN
    /*
    PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                  , i_Procedure_Name   => This_Function
                  , i_Msg_Text         => 'beginning cycle of checking queues'
                  , i_Msg_No           => NULL
                  , i_SQL_Err_Msg      => NULL
                  , i_Application_Func => This_Application
                  , i_Program_Name     => This_Package
                  , i_Msg_Alert        => 'N'
                  );
    */

    FOR mq_rec IN c_mq_msg LOOP


      --dbms_output.put_line('in pl_spl_in.MQ_PROCESS_Q_NAME queue_name: ' || mq_rec.queue_name);

      /*
                PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                      , i_Procedure_Name   => This_Function
                      , i_Msg_Text         => 'in pl_spl_in.MQ_PROCESS_Q_NAME for mq_rec loop queue_name: ' || mq_rec.queue_name||' seq no= '||mq_rec.sequence_number
                      , i_Msg_No           => NULL
                      , i_SQL_Err_Msg      => NULL
                      , i_Application_Func => This_Application
                      , i_Program_Name     => This_Package
                      , i_Msg_Alert        => 'N'
                      );    
      */

      IF ACTIVE_QUEUE( mq_rec.queue_name ) THEN

      --IF TRUE THEN

        l_sequence_number := mq_rec.sequence_number;
        -----------Checking Whether the Status is 'N' and Locking the Record------------
        -- If more than one dispatcher is running, mark this queue entry as being queued.
         -- 5/4/18 m.c. temp comment it out 
         --Set_Queue_Status( l_sequence_number, Q_Status_Queued, i_Old_Status => 'N' );

        --COMMIT;




        --Processing Vendor Master MF1
        IF mq_rec.queue_name = 'Q_SPL_IM_IN' then 

          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   => This_Function
                        , i_Msg_Text         => 'Receiving IM starting'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => This_Application
                        , i_Program_Name     => This_Package
                        , i_Msg_Alert        => 'N'
                        );
         */

         pl_spl_im_in.parse_im(mq_rec.queue_data, l_sequence_number);	
          
  
          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   => This_Function
                        , i_Msg_Text         =>  'Receiving IM ending'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => This_Application
                        , i_Program_Name     => This_Package
                        , i_Msg_Alert        => 'N'
                        );
         */
        --Processing SKU Updates Item Master


        ELSIF mq_rec.queue_name = 'Q_SPL_CU_IN' then 

          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   => This_Function
                        , i_Msg_Text         => 'Receiving SAP_CU_IN starting'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => This_Application
                        , i_Program_Name     => This_Package
                        , i_Msg_Alert        => 'N'
                        );
           */

		  pl_spl_cu_in.parse_cu(mq_rec.queue_data, l_sequence_number);	



          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   => This_Function
                        , i_Msg_Text         =>  'after call to pl_spl_cu_in.parse_cu  queue_name: ' || mq_rec.queue_name||' seq no= '||mq_rec.sequence_number 
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => This_Application
                        , i_Program_Name     => This_Package
                        , i_Msg_Alert        => 'N'
                        );
          */


        ELSIF mq_rec.queue_name = 'Q_SPL_OR_IN' then 

          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   => This_Function
                        , i_Msg_Text         => 'Receiving SAP_OR_IN starting'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => This_Application
                        , i_Program_Name     => This_Package
                        , i_Msg_Alert        => 'N'
                        );
          */

		  pl_spl_or_in.parse_or(mq_rec.queue_data, l_sequence_number);				

          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   => This_Function
                        , i_Msg_Text         =>  'Receiving SAP_OR_IN  ending'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => This_Application
                        , i_Program_Name     => This_Package
                        , i_Msg_Alert        => 'N'
                        );
          */

        ELSIF mq_rec.queue_name = 'Q_SPL_PO_IN' then 

          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   => This_Function
                        , i_Msg_Text         => 'Receiving SAP_PO_IN starting'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => This_Application
                        , i_Program_Name     => This_Package
                        , i_Msg_Alert        => 'N'
                        );
          */

		  pl_spl_po_in.parse_po(mq_rec.queue_data, l_sequence_number);				

          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   => This_Function
                        , i_Msg_Text         =>  'Receiving SAP_PO_IN  ending'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => This_Application
                        , i_Program_Name     => This_Package
                        , i_Msg_Alert        => 'N'
                        );
          */
        ------ML 
		       ELSIF mq_rec.queue_name = 'Q_SPL_ML_IN' then 

          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   => This_Function
                        , i_Msg_Text         => 'Receiving SAP_ML_IN starting'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => This_Application
                        , i_Program_Name     => This_Package
                        , i_Msg_Alert        => 'N'
                        );
          */

		  pl_spl_ml_in.parse_ml(mq_rec.queue_data, l_sequence_number);				

          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   => This_Function
                        , i_Msg_Text         =>  'Receiving SAP_ML_IN  ending'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => This_Application
                        , i_Program_Name     => This_Package
                        , i_Msg_Alert        => 'N'
                        );
          */
	  ---------ML
        ELSIF mq_rec.queue_name = 'Q_SPL_MF_IN' then 

          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   => This_Function
                        , i_Msg_Text         => 'Receiving SAP_MF_IN starting'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => This_Application
                        , i_Program_Name     => This_Package
                        , i_Msg_Alert        => 'N'
                        );
          */

          pl_spl_mf_in.parse_mf(mq_rec.queue_data, l_sequence_number);				


          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   => This_Function
                        , i_Msg_Text         =>  'Receiving SAP_MF_IN  ending'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => This_Application
                        , i_Program_Name     => This_Package
                        , i_Msg_Alert        => 'N'
                        );                        
          */

        ELSIF mq_rec.queue_name = 'Q_SPL_CS_IN' then 

          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   => This_Function
                        , i_Msg_Text         => 'Receiving SAP_CS_IN starting'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => This_Application
                        , i_Program_Name     => This_Package
                        , i_Msg_Alert        => 'N'
                        );
          */ 

          pl_spl_cs_in.parse_cs(mq_rec.queue_data, l_sequence_number);				

          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   => This_Function
                        , i_Msg_Text         =>  'Receiving SAP_CS_IN  ending'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => This_Application
                        , i_Program_Name     => This_Package
                        , i_Msg_Alert        => 'N'
                        );                        
          */

         ELSE
          g_error_context:= 'SWMS is Currently Under Maintanance, Interface is Turned Off';
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                      , i_Procedure_Name   => This_Function
                      , i_Msg_Text         => g_error_context
                      , i_Msg_No           => NULL
                      , i_SQL_Err_Msg      => NULL
                      , i_Application_Func => This_Application
                      , i_Program_Name     => This_Package
                      , i_Msg_Alert        => 'N'
                      );

         END IF;

      END IF;

      --dbms_output.put_line('in pl_spl_in.mq_process_q_name mq_rec.queue_name = '||mq_rec.queue_name||
        --               ' record_status = '||mq_rec.record_status||
          --            ' before update mq_queue_in to S for sequence_number '|| to_char(mq_rec.sequence_number));

      update mq_queue_in
      set record_status = 'S'
      where sequence_number = mq_rec.sequence_number
        and record_status = 'N';
      --WHERE CURRENT OF c_mq_msg;
      
      --dbms_output.put_line('in pl_spl_in.mq_process_q_name mq_rec.queue_name = '||mq_rec.queue_name||
        --              ' record_status = '||mq_rec.record_status||
          --            ' after update mq_queue_in to S for sequence_number '|| to_char(mq_rec.sequence_number));

      rec_no := rec_no + 1;

      if (rec_no = commit_no) then
         commit;
         rec_no := 0;
      end if;  





    END LOOP;

          /*
          PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                      , i_Procedure_Name   => This_Function
                      , i_Msg_Text         => 'in pl_spl_in.mq_process_q_name after loop before commit'
                      , i_Msg_No           => NULL
                      , i_SQL_Err_Msg      => NULL
                      , i_Application_Func => This_Application
                      , i_Program_Name     => This_Package
                      , i_Msg_Alert        => 'N'
                      );    
         */

    commit;

         /*
              PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                      , i_Procedure_Name   => This_Function
                      , i_Msg_Text         => 'in pl_spl_in.mq_process_q_name after loop after commit'
                      , i_Msg_No           => NULL
                      , i_SQL_Err_Msg      => NULL
                      , i_Application_Func => This_Application
                      , i_Program_Name     => This_Package
                      , i_Msg_Alert        => 'N'
                      );
         */

    --RETURN;
  EXCEPTION
     WHEN OTHERS THEN
      g_saved_error_code := SQLCODE;
      --ROLLBACK;
      
      --Set_Queue_Status( l_sequence_number, Q_Status_Failure, g_saved_error_code, SQLERRM( g_saved_error_code ) );
      
        l_error_msg:= 'Error: pl_spl_in.mq_process_q_name when others Exception';
        l_error_code:= SUBSTR(SQLERRM,1,100);   
        pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_spl_in.mq_process_q_name', l_error_msg,
											SQLCODE, SQLERRM,
											'mq_process_q_name',
											'pl_spl_in',
											'N');
 

  END MQ_PROCESS_Q_NAME;
END pl_spl_in;
/
