CREATE OR REPLACE PACKAGE      PL_LM_Rcv AS
/*------------------------------------------------------------------------------
  Package:      PL_LM_Rcv

  Purpose:      This package implements scope control for labor management in
                Live-Receiving. Legacy receiving was originally implemented in
                Pro*C at a PO level. Live-Receiving is implemented in PL/SQL at
                the pallet level.

  Assumptions:  Each labor management batch will be unique to a specific pallet
                at the RDC. The RDC never distributes splits, or partial cases.
                When a pallet is scanned during Live-Receiving, the active batch
                for the prior pallet will be closed. Afterwards, the batch for
                the just-scanned pallet will be opened. When a load or PO is
                opened, it will be assumed that one or more receivers could be
                assisting with the load, or PO. When a PO is closed, it can result
                in the closing of multiple active pallets in this PO. Likewise,
                if the load is closed, then all active pallets in each open PO
                within this load will be closed.

  Modification History:
    Date        Developer Project   Description
    ----------  --------- --------- --------------------------------------------
    04/29/2019  bgil6182  S4R-1529  Implement pallet based labor batches for live
                                    receiving.
------------------------------------------------------------------------------*/

/*------------------------------------------------------------------------------
  Procedure:    Create_Receiver_Batches

  Description:  This procedure creates the receiver labor batches for either a
                load/wave, load/route, pallet/float or task.

                The PUTAWAYLST table is the driving table.

------------------------------------------------------------------------------*/
---------------------------------------------------------------------------
-- Function:
--    does_batch_exist
--
-- Description:
--    This function returns TRUE if a labor batch exists in the BATCH table
--    otherwise FALSE.
--    By default the BATCH_DATE is ignored.  The key on the BATCH table is
--    BATCH_NO and BATCH_DATE.
---------------------------------------------------------------------------
-- 7/8/21 m.c. get this from rs184a then add pl_lmc.does_batch_exist 
--        modify cursor c_pallet
-- 9/8/21 m.c. modify create_receiver_batches modify 'RC' to 'LR'
-- 9/30/21 kiet changed K_BatchNo_Prefix value from LR to VR
FUNCTION does_batch_exist
             (i_batch_no    IN  batch.batch_no%TYPE,
              i_batch_date  IN  DATE DEFAULT NULL)
RETURN BOOLEAN;

  PROCEDURE Create_Receiver_Batches( i_load_no    IN  erm.load_no%TYPE            DEFAULT NULL
                                   , i_erm_id     IN  erm.erm_id%TYPE             DEFAULT NULL
                                   , i_pallet_id  IN  putawaylst.pallet_id%TYPE   DEFAULT NULL
                                   , i_task_id    IN  putawaylst.task_id%TYPE     DEFAULT NULL );
END  PL_LM_Rcv;
/


CREATE OR REPLACE PACKAGE BODY PL_LM_Rcv AS

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------

  This_Package          CONSTANT  all_source.name%TYPE            := $$PLSQL_UNIT;
  This_Appl_Context     CONSTANT  swms_log.application_func%TYPE  := 'LABOR';

/*------------------------------------------------------------------------------
  Procedure:    create_receiver_batches

  Description:  This procedure creates the receiver labor batches for either a
                load, po, pallet or task.

                The PUTAWAYLST table is the driving table.

  Parameters:
    i_load_no   - The trailer load (wave) to process.
    i_erm_id    - The purchase order to process.
    i_pallet_id - The pallet to create the batch for.
    i_task_id   - The task #, associated with the pallet, to create the batch for.

 Exceptions raised:
    PL_Exc.CT_Data_Error     - Bad combination of parameters.
    PL_Exc.CT_Database_Error - Got an oracle error.

 Modification History:
    Date        Developer Project   Description
    ----------  --------- --------- --------------------------------------------
    04/29/2019  bgil6182  S4R-1529  Created to replace PRO*C (crt_rcv_lm_bats.pc)
                                    Labor batches will be created by pallet now,
                                    rather than by PO.
	08/08/2019 pdas8114  S4R-1973 LM Flex - Labor changes for Live Receiving Batches
------------------------------------------------------------------------------*/
-- 7/8/21 m.c.get this from rs184a pl_lmc.does_batch_exist
FUNCTION does_batch_exist
             (i_batch_no    IN  batch.batch_no%TYPE,
              i_batch_date  IN  DATE DEFAULT NULL)
RETURN BOOLEAN
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'does_batch_exist';
   l_dummy         VARCHAR2(1);

BEGIN
   BEGIN
      --
      -- Note: BATCH.BATCH_DATE is stored without the time.
      --
      SELECT DISTINCT 'x' INTO l_dummy
        FROM batch
       WHERE batch.batch_no   = i_batch_no
         AND batch.batch_date = NVL(TRUNC(i_batch_date), batch.batch_date);
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
         RETURN FALSE;
   END;

   RETURN TRUE;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function, 'pl_lm_rcv');

                        -- 7/8/21 m.c. replace by 'pl_lm_rcv' gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END does_batch_exist;



  PROCEDURE Create_Receiver_Batches( i_load_no    IN  erm.load_no%TYPE            DEFAULT NULL
                                   , i_erm_id     IN  erm.erm_id%TYPE             DEFAULT NULL
                                   , i_pallet_id  IN  putawaylst.pallet_id%TYPE   DEFAULT NULL
                                   , i_task_id    IN  putawaylst.task_id%TYPE     DEFAULT NULL ) IS
    This_Function           CONSTANT  all_source.name%TYPE            := 'Create_Receiver_Batches';
    K_BatchNo_Prefix        CONSTANT  VARCHAR2(2 CHAR)                := 'VR';
    K_Loc_Not_Yet_Assigned  CONSTANT  loc.logi_loc%TYPE               := PL_Rcv_Open_PO_Types.CT_LR_Dest_Loc;
-- Job Code section mappings
    K_JbCd_LibFunc          CONSTANT  VARCHAR2(2 CHAR)                := 'LR'; -- for SWMS uses LR 'RC'; 
    K_JbCd_Suffix           CONSTANT  VARCHAR2(3 CHAR)                := 'LIV';

    This_Message                      VARCHAR2(4000 CHAR);
--    l_num_pieces                      PLS_INTEGER;
    num_item_data_captures            PLS_INTEGER;
    l_total_cube                      NUMBER;
    l_total_wt                        NUMBER;
    parm_values                       PLS_INTEGER;

    -- 7/8/21 m.c. get from rs184a pl_lmf package

      TYPE t_create_labor_batch_stats_rec IS RECORD
      (num_records_processed         PLS_INTEGER := 0,
       num_batches_created           PLS_INTEGER := 0,
       num_batches_existing          PLS_INTEGER := 0,
       num_not_created_due_to_error  PLS_INTEGER := 0,
       num_with_no_location          PLS_INTEGER := 0,   -- Applies only to receiving putaway batches
       num_live_receiving_location   PLS_INTEGER := 0);  -- Applies only to receiving putaway batches

    L_R_Create_Batch_Stats            T_Create_Labor_Batch_Stats_Rec; --PL_LMF.T_Create_Labor_Batch_Stats_Rec;   -- Keep track of how many batches created

    E_Parameter_Bad_Combination       EXCEPTION;  -- Bad combination of parameters.
    E_Batch_Already_Exists            EXCEPTION;  -- Batch already exists.

    --
    -- This cursor selects the inbound PALLET_IDs to create live-receiving batches for.
    -- Either the specified wave, po/sn, pallet or task.
    --
    CURSOR C_Pallets( i_load_no   IN  erm.load_no%TYPE            -- All pallets in a given trailer load
                    , i_erm_id    IN  erm.erm_id%TYPE             -- All pallets in a given purchase order/shipping notice
                    , i_pallet_id IN  putawaylst.pallet_id%TYPE   -- A single pallet
                    , i_task_id   IN  putawaylst.task_id%TYPE     -- A single task # linked to a single pallet
                    ) IS
      SELECT jbcd.jbcd_job_code                                       rcv_job_code
           , SUBSTR( K_BatchNo_Prefix
                     || LTRIM( TO_CHAR( pal.task_id ) ), 1, 13 )      lm_rcv_batch_no
           , pal.pallet_id                                            rcv_pallet_id
           --
--           , SUM( DECODE( pal.uom
--                        , 1 /*splits*/, ( NVL( pal.qty_received, pal.qty_expected ) / NVL( p.spc, 1 ) )
--                        , 0 ) )                                       num_splits
           --
          , SUM( DECODE( pal.uom
                        , 1 /*splits*/, NVL( pal.qty_received, pal.qty_expected )
                        , TRUNC( NVL( pal.qty_received, pal.qty_expected ) / NVL( p.spc, 1 ) ) )
                                                                    ) num_cases
           --
           , COUNT( DISTINCT pal.rec_id )                             num_pos
           --
           , COUNT( DISTINCT pal.pallet_id )                          num_pallets
           --
           ,   SUM( DECODE( pal.exp_date_trk, 'Y', 1, 'C', 1, 0 ))    --  num_dc_exp_date
             + SUM( DECODE( pal.date_code   , 'Y', 1, 'C', 1, 0 ))    --  num_dc_mfg_date
             + SUM( DECODE( pal.lot_trk     , 'Y', 1, 'C', 1, 0 ))    --  num_dc_lot_trk
             + SUM( DECODE( pal.temp_trk    , 'Y', 1, 'C', 1, 0 ))    --  num_dc_temp
             + 1 /* inbound pallet scan */                            num_lpn_data_captures
           , SUM( DECODE( pal.uom
                        , 1, NVL( pal.qty_received, pal.qty_expected ) * ( p.g_weight / NVL( p.spc, 1 ) )
                        , 0 ) )                                       split_wt
           , SUM( DECODE( pal.uom
                        , 1, NVL( pal.qty_received, pal.qty_expected ) * p.split_cube
                        , 0 ) )                                       split_cube
           , SUM( DECODE( pal.uom
                        , 1, 0
                        , NVL( pal.qty_received, pal.qty_expected ) * ( p.g_weight / NVL( p.spc, 1 ) )
                        ) )                                           case_wt
           , SUM( DECODE( pal.uom
                        , 1, 0
                        , ( NVL( pal.qty_received, pal.qty_expected ) / NVL( p.spc, 1 ) ) * p.case_cube
                         ) )                                       case_cube
           , COUNT( DISTINCT           pal.prod_id
                             || '.' || pal.cust_pref_vendor )         num_items
           , erm.load_no, erm.erm_id, pal.pallet_id, pal.task_id, pal.erm_line_id
           , pal.seq_no, p.area, pal.dest_loc
        FROM putawaylst pal
           , pm p
           , erm
           , job_class jbcl
           , job_code jbcd
       WHERE pal.prod_id = p.prod_id
         AND pal.cust_pref_vendor = p.cust_pref_vendor
         AND pal.rec_id = erm.erm_id
         AND jbcd.whar_area = p.area
         AND jbcd.lfun_lbr_func = 'LR'
         AND jbcd.jbcl_job_class = jbcl.jbcl_job_class
         AND SUBSTR( jbcd.jbcd_job_code, 4, 3 ) = 'LIV'
         AND ( (erm.load_no   = NVL( TRIM( i_load_no  ), erm.load_no ) ) or (erm.load_no is null) ) -- m.c. add this to make it work
         -- 7/9/21 m.c. replace by above AND erm.load_no   = NVL( TRIM( i_load_no   ), erm.load_no   )
         AND erm.erm_id    = NVL( TRIM( i_erm_id    ), erm.erm_id    )
         AND pal.pallet_id = NVL( TRIM( i_pallet_id ), pal.pallet_id )
         AND pal.task_id   = NVL( TRIM( i_task_id   ), pal.task_id   )
      GROUP BY jbcd.jbcd_job_code, erm.load_no, erm.erm_id, pal.pallet_id, pal.task_id
             , pal.erm_line_id   , pal.seq_no , p.area    , pal.dest_loc
      ORDER BY erm.load_no, erm.erm_id, pal.erm_line_id, pal.seq_no;

    r_pallet                          C_Pallets%ROWTYPE;
  BEGIN
    --
    -- Log starting the procedure.
    --
    This_Message := 'Starting procedure '
                 || '( i_load_no='   || NVL( i_load_no         , 'NULL' )
                 || ', i_erm_id='    || NVL( i_erm_id          , 'NULL' )
                 || ', i_pallet_id=' || NVL( i_pallet_id       , 'NULL' )
                 || ', i_task_id='   || NVL( TO_CHAR(i_task_id), 'NULL' )
                 || ' ). This procedure creates the receiver labor batches.';
    PL_Log.Ins_Msg( i_msg_type         => PL_Log.CT_Info_Msg
                  , i_procedure_name   => This_Function
                  , i_msg_text         => This_Message
                  , i_msg_no           => NULL
                  , i_sql_err_msg      => NULL
                  , i_application_func => This_Appl_Context
                  , i_program_name     => This_Package );

    --
    -- Check the parameters.
    -- One and only one of i_load_no, i_erm_id, i_pallet_id and i_task_id can
    -- be populated.
    --
    SELECT   DECODE( i_load_no  , NULL, 0, 1 )
           + DECODE( i_erm_id   , NULL, 0, 1 )
           + DECODE( i_pallet_id, NULL, 0, 1 )
           + DECODE( i_task_id  , NULL, 0, 1 )
      INTO parm_values
      FROM dual;

    IF parm_values <> 1 THEN
      RAISE E_Parameter_Bad_Combination;
    END IF;

    --
    -- Initialize the counts.
    --
    L_R_Create_Batch_Stats.Num_Records_Processed        := 0;
    L_R_Create_Batch_Stats.Num_Batches_Created          := 0;
    L_R_Create_Batch_Stats.Num_Batches_Existing         := 0;
    L_R_Create_Batch_Stats.Num_Not_Created_Due_To_Error := 0;
    L_R_Create_Batch_Stats.Num_With_No_Location         := 0;
    L_R_Create_Batch_Stats.Num_Live_Receiving_Location  := 0;

    FOR r_pallet IN C_Pallets( i_load_no, i_erm_id, i_pallet_id, i_task_id ) LOOP
      L_R_Create_Batch_Stats.Num_Records_Processed := L_R_Create_Batch_Stats.Num_Records_Processed + 1;

      IF r_pallet.dest_loc IS NULL THEN
        L_R_Create_Batch_Stats.Num_With_No_Location := L_R_Create_Batch_Stats.Num_With_No_Location + 1;
      ELSIF r_pallet.dest_loc = K_Loc_Not_Yet_Assigned THEN
        L_R_Create_Batch_Stats.Num_Live_Receiving_Location := L_R_Create_Batch_Stats.Num_Live_Receiving_Location + 1;
      END IF;
      --
      -- Start new block to trap errors.
      --
      BEGIN
        SAVEPOINT sp_receiver;   -- Rollback to here if an error so the error affects only one batch.

        --
        --  Check if the receiving labor batch already exists.
        --

        --7/8/21 m.c. replace by next line IF PL_LMC.Does_Batch_Exist( r_pallet.lm_rcv_batch_no ) THEN

        IF Does_Batch_Exist( r_pallet.lm_rcv_batch_no ) THEN
          RAISE E_Batch_Already_Exists;
        END IF;

        --
        -- Now, collect the item data captures
        --
        IF ( TRIM( i_pallet_id ) IS NULL ) OR
           ( TRIM( i_task_id   ) IS NULL ) THEN
          -- If we are being called at a pallet/task level for an item which requires data collection,
          -- then if 2 or more pallets of the same item, the data capture could be duplicated for each pallet.
          -- At this point, the assumption is that invocation will only be by PO or trailer load.
          num_item_data_captures := 0;
        ELSE
          SELECT COUNT( DISTINCT pal.prod_id || '.' || pal.cust_pref_vendor ) num_dc_weight
            INTO num_item_data_captures
            FROM putawaylst pal
               , pm p
               , erm
           WHERE pal.prod_id = p.prod_id
             AND pal.cust_pref_vendor = p.cust_pref_vendor
             AND pal.rec_id = erm.erm_id
             AND pal.catch_wt IN ( 'Y', 'C' )
             AND erm.load_no   = NVL( TRIM( i_load_no ), erm.load_no )
             AND erm.erm_id    = NVL( TRIM( i_erm_id  ), erm.erm_id  );
        END IF;

        --
        -- Calculate out total volume and total weight
        --
        l_total_cube := r_pallet.case_cube + r_pallet.split_cube;
        l_total_wt   := r_pallet.case_wt   + r_pallet.split_wt;

        This_Message := 'Creating live receiving labor batch ' || NVL( r_pallet.lm_rcv_batch_no, 'NULL' )
                     || ' for pallet ' || NVL( r_pallet.rcv_pallet_id, 'NULL' ) || '.';
        PL_Log.Ins_Msg( i_msg_type         => PL_Log.CT_Info_Msg
                      , i_procedure_name   => This_Function
                      , i_msg_text         => This_Message
                      , i_msg_no           => NULL
                      , i_sql_err_msg      => NULL
                      , i_application_func => This_Appl_Context
                      , i_program_name     => This_Package );
        --
        -- Create the live-receiving batch

        INSERT INTO batch( batch_no
                         , batch_date
                         , status
                         , jbcd_job_code
                         , user_id
                         , ref_no
                         , kvi_cube
                         , kvi_wt
                         , kvi_no_pallet
                         , kvi_no_item
                         , kvi_no_data_capture
                         , kvi_no_po
						 , kvi_no_case
                         )
          VALUES ( r_pallet.lm_rcv_batch_no
                 , TRUNC( SYSDATE )
                 , 'X'
                 , r_pallet.rcv_job_code
                 , NULL
                 , r_pallet.rcv_pallet_id
                 , l_total_cube
                 , l_total_wt
                 , r_pallet.num_pallets
                 , r_pallet.num_items
                 , r_pallet.num_lpn_data_captures + num_item_data_captures
                 , r_pallet.num_pos
				 , r_pallet.num_cases
                 );

        --
        -- Set the goal/target time for the batch.
        --
        PL_LM_Time.Load_GoalTime( r_pallet.lm_rcv_batch_no );

        L_R_Create_Batch_Stats.Num_Batches_Created := L_R_Create_Batch_Stats.Num_Batches_Created + 1;

        BEGIN
          UPDATE putawaylst
             SET lm_rcv_batch_no = r_pallet.lm_rcv_batch_no
           WHERE pallet_id = r_pallet.rcv_pallet_id;
        EXCEPTION
          WHEN OTHERS THEN
            PL_Log.Ins_Msg( i_msg_type         => PL_Log.CT_Warn_Msg
                          , i_procedure_name   => This_Function
                          , i_msg_text         => 'Unable to save live-receiving labor batch[' || r_pallet.lm_rcv_batch_no || ']'
                                               || ' for putaway pallet[' || r_pallet.rcv_pallet_id || '].'
                          , i_msg_no           => SQLCODE
                          , i_sql_err_msg      => SQLERRM
                          , i_application_func => This_Appl_Context
                          , i_program_name     => This_Package );
        END;

      EXCEPTION
        WHEN DUP_VAL_ON_INDEX OR E_Batch_Already_Exists THEN
          --
          -- Batch already exists.  This is OK because this procedure
          -- could have been run again for the same data.
          --
          L_R_Create_Batch_Stats.Num_Batches_Existing := L_R_Create_Batch_Stats.Num_Batches_Existing + 1;
        WHEN OTHERS THEN
          --
          -- There was an error creating the labor batch(s) log a message and rollback to savepoint.
          --
          ROLLBACK TO sp_receiver;  -- Rollback to here if an error so the error affects only one pallet.

          L_R_Create_Batch_Stats.Num_Not_Created_Due_To_Error := L_R_Create_Batch_Stats.Num_Not_Created_Due_To_Error + 1;

          PL_Log.Ins_Msg( i_msg_type         => PL_Log.CT_Info_Msg
                        , i_procedure_name   => This_Function
                        , i_msg_text         => 'Error creating receiver labor batch[' || NVL( r_pallet.lm_rcv_batch_no, 'NULL' ) || ']'
                                                                     || ' for pallet[' || NVL( r_pallet.rcv_pallet_id  , 'NULL' ) || ']'
                                                                     || '. Skipping over this pallet.'
                        , i_msg_no           => SQLCODE
                        , i_sql_err_msg      => SQLERRM
                        , i_application_func => This_Appl_Context
                        , i_program_name     => This_Package );
      END;
    END LOOP;

    --
    -- Log when done.  Note that if there is an exception this message can be bypassed.
    --
    This_Message := 'Ending procedure '
                 || '( i_load_no['   || NVL( i_load_no         , 'NULL' ) || ']'
                 || ', i_erm_id['    || NVL( i_erm_id          , 'NULL' ) || ']'
                 || ', i_pallet_id[' || NVL( i_pallet_id       , 'NULL' ) || ']'
                 || ', i_task_id['   || NVL( TO_CHAR(i_task_id), 'NULL' ) || ']'
                 || ' )'
                 || '. Num_Records_Processed=' || TO_CHAR( L_R_Create_Batch_Stats.Num_Records_Processed );
    IF L_R_Create_Batch_Stats.Num_Batches_Created > 0 THEN
      This_Message := This_Message || ', Num_Batches_Created='         || TO_CHAR( L_R_Create_Batch_Stats.Num_Batches_Created );
    END IF;
    IF L_R_Create_Batch_Stats.Num_Batches_Existing > 0 THEN
      This_Message := This_Message || ', Num_Batches_Existing='        || TO_CHAR( L_R_Create_Batch_Stats.Num_Batches_Existing );
    END IF;
    IF L_R_Create_Batch_Stats.Num_With_No_Location > 0 THEN
      This_Message := This_Message || ', Num_With_No_Location='        || TO_CHAR( L_R_Create_Batch_Stats.Num_With_No_Location );
    END IF;
    IF L_R_Create_Batch_Stats.Num_Live_Receiving_Location > 0 THEN
      This_Message := This_Message || ', Num_Live_Receiving_Location=' || TO_CHAR( L_R_Create_Batch_Stats.Num_Live_Receiving_Location );
    END IF;
    IF L_R_Create_Batch_Stats.Num_Not_Created_Due_To_Error > 0 THEN
      This_Message := This_Message || ', Num_Not_Created_Due_To_Error=' || TO_CHAR( L_R_Create_Batch_Stats.Num_Not_Created_Due_To_Error );
    END IF;
    This_Message := This_Message || '.';

    PL_Log.Ins_Msg( i_msg_type         => PL_Log.CT_Info_Msg
                  , i_procedure_name   => This_Function
                  , i_msg_text         => This_Message
                  , i_msg_no           => NULL
                  , i_sql_err_msg      => NULL
                  , i_application_func => This_Appl_Context
                  , i_program_name     => This_Package );

     commit; --7/13/21 add m.c.

  EXCEPTION
    WHEN E_Parameter_Bad_Combination THEN
      --
      -- Only one of i_load_no, i_erm_id, i_pallet_id and i_task_id can be populated.
      --
      This_Message := '( i_load_no='   || NVL( i_load_no         , 'NULL' )
                   || ', i_erm_id='    || NVL( i_erm_id          , 'NULL' )
                   || ', i_pallet_id=' || NVL( i_pallet_id       , 'NULL' )
                   || ', i_task_id='   || NVL( TO_CHAR(i_task_id), 'NULL' )
                   || ' ). Only one parameter may have a value.';
      PL_Log.Ins_Msg( i_msg_type         => PL_Log.CT_Fatal_Msg
                    , i_procedure_name   => This_Function
                    , i_msg_text         => This_Message
                    , i_msg_no           => NULL
                    , i_sql_err_msg      => NULL
                    , i_application_func => This_Appl_Context
                    , i_program_name     => This_Package );

      Raise_Application_Error( PL_Exc.CT_Data_Error, This_Message );
    WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      This_Message := 'Unexpected exception occurred while creating receiving batches for ';
      IF i_load_no IS NOT NULL THEN
        This_Message := This_Message || 'i_load_no='   || NVL( i_load_no           , 'NULL' ) || '.';
      ELSIF i_erm_id IS NOT NULL THEN
        This_Message := This_Message || 'i_erm_id='    || NVL( i_erm_id            , 'NULL' ) || '.';
      ELSIF i_pallet_id IS NOT NULL THEN
        This_Message := This_Message || 'i_pallet_id=' || NVL( i_pallet_id         , 'NULL' ) || '.';
      ELSE
        This_Message := This_Message || 'i_task_id='   || NVL( TO_CHAR( i_task_id ), 'NULL' ) || '.';
      END IF;
      PL_Log.Ins_Msg( i_msg_type         => PL_Log.CT_Fatal_Msg
                    , i_procedure_name   => This_Function
                    , i_msg_text         => This_Message
                    , i_msg_no           => SQLCODE
                    , i_sql_err_msg      => SQLERRM
                    , i_application_func => This_Appl_Context
                    , i_program_name     => This_Package );

      Raise_Application_Error( PL_Exc.CT_Database_Error, This_Function || ': ' || SQLERRM );
  END Create_Receiver_Batches;
END PL_LM_Rcv;
/
