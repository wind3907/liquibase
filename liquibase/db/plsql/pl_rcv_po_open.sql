create or replace PACKAGE pl_rcv_po_open AS
  ---------------------------------------------------------------------------
  -- Package:
  --    Migrated from the folowing programs
  --  TP_PALLET_MAIN.pc / crt_rcv_lm_bats.pc / TP_RUN_WK_SHEET /
  -- Description:
  --    This will be the base package
  --    Logic to process Current PO From front end is handled
  --    Logic to process Scheduled PO From front end is handled
  --    Logic to process Scheduled PO based on OPEN_PO_SCHED_HOUR is handled
  --    Reports related to Receiving module will be handled in separate Web services
  --    Reprocess and find_damage_zone_location will be handled in another story card - 506
  --
  --  Called By : Java API
  ---------------------------------------------------------------------------
    PROCEDURE p_execute_frm (
        p_userid            IN  VARCHAR2,
        func_parameters     IN  VARCHAR2,
        o_out_status        OUT VARCHAR2
    );

    PROCEDURE p_open_po_main (
        i_erm_id         IN               erm.erm_id%TYPE,
        i_schdfromdate   IN               VARCHAR2,
        i_schdtodate     IN               VARCHAR2,
        i_out_storage    IN               VARCHAR2,
        o_out_status     OUT              VARCHAR2
    );

    PROCEDURE p_open_current (
        i_erm_id       IN             erm.erm_id%TYPE,
        o_out_status   OUT            VARCHAR2
    );

    PROCEDURE p_open_scheduled (
        i_schdfromdate   IN               VARCHAR2,
        i_schdtodate     IN               VARCHAR2,
        o_out_stat       OUT              VARCHAR2
    );

    PROCEDURE p_open_out_storage (
        i_erm_id        IN              erm.erm_id%TYPE,
        i_out_storage   IN              VARCHAR2,
        o_out_status    OUT             VARCHAR2
    );

    PROCEDURE p_open_schedule_po (
        i_hour_passed_fr   IN                 VARCHAR2,
        i_hour_passed_to   IN                 VARCHAR2,
        o_out_status       OUT                VARCHAR2
    );

    PROCEDURE p_create_receiving_batch (
        i_erm_id      IN            erm.erm_id%TYPE,
        o_crb_batch   OUT           VARCHAR2
    );

    PROCEDURE p_crt_rcv_lm_bats (
        i_erm_id        IN              erm.erm_id%TYPE,
        o_lm_bats_crt   OUT             VARCHAR2
    );

    FUNCTION f_is_forklift_active RETURN BOOLEAN;

    FUNCTION f_update_auto_po_door_no (
        i_erm_id   IN         erm.erm_id%TYPE
    ) RETURN NUMBER;

    FUNCTION f_update_erm_door_no (
        i_erm_id   IN         erm.erm_id%TYPE
    ) RETURN NUMBER;

END pl_rcv_po_open;
/

create or replace PACKAGE BODY  pl_rcv_po_open IS

   DO_NOT_OPEN_PO      CONSTANT NUMBER := 1;
   SWMS_NORMAL         CONSTANT NUMBER := 0;
   
   row_locked EXCEPTION;
   PRAGMA EXCEPTION_INIT(row_locked, -54);

  /*************************************************************************
  ** execute_frm
  **  Description: Main Program to be called from the PL/SQL wrapper/Forms
  **  Called By : DBMS_HOST_COMMAND_FUNC
  **  PARAMETERS:
  **      p_userid - user id of the session owner
  **      func_parameters - Function parameted passed from Frontend as Input
  **      o_out_status   - Output parameter returned to front end
  **  RETURN VALUES:
  **      Success or Failure message will be sent
  **
  ****************************************************************/
    PROCEDURE p_execute_frm (
        p_userid            IN  VARCHAR2,
        func_parameters     IN  VARCHAR2,
        o_out_status        OUT VARCHAR2
    ) IS
        l_func_name                 VARCHAR2(50)    := 'pl_rcv_po_open.execute_frm';
        v_count                     NUMBER          := 0;
        v_prams_list                c_prams_list;
        l_status_error CONSTANT     VARCHAR2(5)     := 'ERROR';
        l_queue_spec                print_queues.user_queue%TYPE;
        l_ca_dmg_status             VARCHAR2(4)     := 'REG';
        l_dontprint_flag            VARCHAR2(1);
        i                           PLS_INTEGER;
    BEGIN
        v_prams_list := F_SPLIT_PRAMS (func_parameters);
        v_count := v_prams_list.count;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'F_SPLIT_PRAMS invoked...', sqlcode, sqlerrm);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'F_SPLIT_PRAMS size:' || v_count, sqlcode, sqlerrm);

        i := v_prams_list.first;
        WHILE (i IS NOT NULL) LOOP
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Param value of ' || i ||': ' || v_prams_list(i), sqlcode, sqlerrm);
            i := v_prams_list.NEXT(i);
        END LOOP;

        /*
        * Existing Pro*C parameter verification
        */
        IF (v_count = 1 and v_prams_list(1) != 'a') or (v_count = 2 and v_prams_list(1) != 'p') THEN
            pl_text_log.ins_msg_async(l_status_error, l_func_name, 'KEY=[' || v_prams_list(1) || ']  ACTION=[VALIDATION]  MESSAGE=[Unable to open SN/PO]  REASON=[Invalid arguments]', sqlcode, sqlerrm);
            o_out_status := 'KEY=[' || v_prams_list(1) || ']; Invalid arguments';
            RETURN;
        ELSIF v_count = 3 or v_count = 4 THEN
            pl_text_log.ins_msg_async(l_status_error, l_func_name, 'KEY=[None]  ACTION=[VALIDATION]  MESSAGE=[Unable to open SN/PO]  REASON=[Invalid number of arguments]', sqlcode, sqlerrm);
            o_out_status := 'Invalid number of arguments';
            RETURN;
        ELSIF v_count = 7 and v_prams_list(7) != 'DMG' and v_prams_list(7) != 'REG' THEN
            pl_text_log.ins_msg_async(l_status_error, l_func_name, 'KEY=[None]  ACTION=[VALIDATION]  MESSAGE=[Unable to process]  REASON=[Invalid option:should be either DMG or REG]', sqlcode, sqlerrm);
            o_out_status := 'Invalid option:should be either DMG or REG';
            RETURN;
        ELSIF v_count = 8 and v_prams_list(8) != 'N' and v_prams_list(8) != 'Y' THEN
            pl_text_log.ins_msg_async(l_status_error, l_func_name, 'KEY=[None]  ACTION=[VALIDATION]  MESSAGE=[Unable to process]  REASON=[Invalid option:Don''t print LPN should be either Y or N]', sqlcode, sqlerrm);
            o_out_status := 'Invalid option:Don''t print LPN should be either Y or N';
            RETURN;
        ELSIF v_count > 8 THEN
            pl_text_log.ins_msg_async(l_status_error, l_func_name, 'KEY=[None]  ACTION=[VALIDATION]  MESSAGE=[Unable to open SN/PO]  REASON=[Too many arguments]', sqlcode, sqlerrm);
            o_out_status := 'Too many arguments';
            RETURN;
        END IF;

        IF v_count = 6 THEN
            l_queue_spec := v_prams_list(6);
        ELSIF v_count = 7 THEN
            l_ca_dmg_status := v_prams_list(7);
            l_dontprint_flag := 'N';
        ELSIF v_count = 8 THEN
            l_dontprint_flag := CASE v_prams_list(8)
                WHEN 'Y' THEN 'Y'
                ELSE 'N'
            END;
        END IF;

        IF v_count = 1 or v_count = 2 THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'pallet_label=[' || v_prams_list(1) || '];', sqlcode, sqlerrm);
            IF v_prams_list(1) = 'p' THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'l_erm_id=[' || v_prams_list(2) || '];', sqlcode, sqlerrm);
                pl_rcv_po_open.p_open_po_main(v_prams_list(2), NULL, NULL, 'N', o_out_status);
            ELSIF v_prams_list(1) = 'a' THEN
                pl_one_pallet_label.p_all_pallet_label(o_out_status);
            END IF;
        ELSE
            pl_text_log.ins_msg_async('INFO', l_func_name, 'l_erm_id=[' || v_prams_list(1) || ']; i_prod_id=[' || v_prams_list(2) || ']; i_qty_rec=[' || v_prams_list(3) || ']; i_cpv=[' || v_prams_list(4) || ']; i_uom=[' || v_prams_list(5) || ']; l_ca_dmg_status=[' || l_ca_dmg_status || ']; l_dontprint_flag=[' || l_dontprint_flag || ']; l_queue_spec=[' || l_queue_spec || '];', sqlcode, sqlerrm);
            pl_demand_pallet.reprocess(v_prams_list(1), v_prams_list(2), v_prams_list(3), v_prams_list(4), v_prams_list(5), l_ca_dmg_status, l_dontprint_flag, l_queue_spec, o_out_status);
        END IF;

    EXCEPTION WHEN OTHERS THEN
        pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception Raised at ' || l_func_name || 'for params ' || func_parameters, sqlcode, sqlerrm);
        o_out_status := 'FAILURE';
    END p_execute_frm;
    
  /*************************************************************************
  ** p_open_po_main
  **  Description: To Finalize to open a new PO or scheduled POs Based on the
  **               input passed from Frontend. 
  **               Logic taken form PO forms to execute based on
  **               opening Current Po, Scheduled PO, Outside Storage
  **  Called By : Java API
  **  PARAMETERS:
  **      i_erm_id - ERM# passed from Frontend as Input
  **      i_schdfromdate - From time passed from frontend as input
  **      i_schdtodate  - To time passed from frontend as input
  **      out_storag  - Outside storage passed from frontend as input
  **                    Default Value will be N
  **      o_out_status   - Output parameter returned to front end
  **  RETURN VALUES:
  **      Success or Failure message will be sent
  **
  ****************************************************************/

    PROCEDURE p_open_po_main (
        i_erm_id         IN             erm.erm_id%TYPE,
        i_schdfromdate   IN             VARCHAR2,
        i_schdtodate     IN             VARCHAR2,
        i_out_storage    IN             VARCHAR2,
        o_out_status     OUT            VARCHAR2
    ) IS

        l_func_name        VARCHAR2(50) := 'pl_rcv_po_open.p_open_po_main';
        l_err_msg          VARCHAR2(4000);
        l_po_type          VARCHAR(2);
    
    BEGIN
      
      /* Finalising the flow of PO Open */
      /* If condition to Pass a single PO(current) from front end for PO opening */
      
        IF i_erm_id IS NOT NULL AND i_schdfromdate IS NULL AND i_schdtodate IS NULL AND i_out_storage = 'N' THEN
            /*Check if PO is of type XN (i.e: XSN - R1 Cross dock)*/
            BEGIN
                SELECT erm_type
                INTO l_po_type
                FROM erm
                WHERE erm_id = i_erm_id;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception Raised at '|| l_func_name || ' due to no type for PO# = ' || i_erm_id, sqlcode, sqlerrm);
                    o_out_status := 'FAILURE';
            END;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'Calling Open current with Po# : ' || i_erm_id, sqlcode, sqlerrm);
            IF (l_po_type = 'XN') THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Calling Xdock_Receving package to open XSN : ' || i_erm_id, sqlcode, sqlerrm);
                pl_xdock_receiving.p_open_xsn(i_erm_id, l_err_msg);
                pl_text_log.ins_msg_async('INFO', l_func_name, 'After Xdock_Receving package to open XSN : ' || i_erm_id||' Status '||l_err_msg, sqlcode, sqlerrm);
                IF l_err_msg = 'FAILURE' THEN
                    ROLLBACK; -- TO remove the lock aquired when trying to open it.
                END IF;
            ELSE
                p_open_current(i_erm_id, l_err_msg);
            END IF;
        ELSIF i_erm_id IS NULL AND i_schdfromdate IS NOT NULL AND i_schdtodate IS NOT NULL AND i_out_storage = 'N' THEN
        /*if condition for passing multiple scheduled PO for opening from Front end   */
         /* Passing the HH:MM directly as input parameters for Scheduled Hours  */
            pl_text_log.ins_msg_async('INFO', l_func_name, 'schedule from time: ' || i_schdfromdate || 
            'schedule to time: ' || i_schdtodate, sqlcode, sqlerrm);
             p_open_scheduled(i_schdfromdate, i_schdtodate, l_err_msg);
        ELSIF i_erm_id IS NULL AND i_schdfromdate IS NULL AND i_schdtodate IS NULL AND i_out_storage = 'N' THEN
         /*if condition for passing multiple scheduled PO based on cron job  SYSCONFIG  OPEN_PO_SCHED_HOUR  */
            pl_text_log.ins_msg_async('INFO', l_func_name, 'OPEN_PO_SCHED_HOUR schedule from time: ' || i_schdfromdate ||
            'OPEN_PO_SCHED_HOUR schedule to time: ' || i_schdtodate, sqlcode, sqlerrm);
            p_open_scheduled(i_schdfromdate, i_schdtodate, l_err_msg);
            
        ELSIF ( i_erm_id IS NOT NULL ) AND i_schdfromdate IS NULL AND i_schdtodate IS NULL AND i_out_storage = 'Y' THEN
         /* If condition to Pass PO from front end to open PO for outside storage */
            pl_text_log.ins_msg_async('INFO', l_func_name, 'OPEN outside Storage', sqlcode, sqlerrm);

  ---- To be called from UI Front end. Only structure is defined now
            p_open_out_storage(i_erm_id, i_out_storage, l_err_msg);
        END IF;

        o_out_status := l_err_msg;
    EXCEPTION
    WHEN OTHERS THEN
      pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception Raised at ' || l_func_name || 'for PO# = ' || i_erm_id, sqlcode, sqlerrm);
      o_out_status := 'FAILURE'; 
    END p_open_po_main;
    
  /*************************************************************************
  ** p_open_current
  **  Description: open a single new PO Based on the input passed from Frontend
  **               Code logic was based on PO oracle forms
  **  Called By : open_po_main
  **  PARAMETERS:
  **      i_erm_id - ERM# passed from Frontend as Input
  **      o_out_status   - Output parameter returned to front end
  **  RETURN VALUES:
  **      Success or Failure message will be sent
  **
  ****************************************************************/

    PROCEDURE p_open_current (
        i_erm_id     IN           erm.erm_id%TYPE,
        o_out_status OUT        VARCHAR2
    ) IS
                      
        l_func_name                     VARCHAR2(50) := 'pl_rcv_po_open.p_open_current';
        l_po_locking                    VARCHAR2(5);
        l_po_chk                        VARCHAR2(5);
        l_opl_status                    VARCHAR2(100);
        l_po_exist                      NUMBER := 0;
        l_pallet_status                 VARCHAR2(100);
        l_po_status                     VARCHAR2(4);
        l_out_status1                   VARCHAR2(300);
        o_no_records_processed          NUMBER;
        o_no_batches_created            NUMBER;
        o_no_batches_existing           NUMBER;
        o_no_not_created_due_to_error   NUMBER;
    BEGIN
        BEGIN
            SELECT
                'x'
            INTO l_po_chk
            FROM
                erm
            WHERE
                erm_id = i_erm_id;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
               pl_text_log.ins_msg_async('FATAL', l_func_name, i_erm_id || ' Invalid PO Number ', sqlcode, sqlerrm);
               o_out_status := 'Invalid PO Number' || i_erm_id;
               l_po_exist := 1;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, ' Unable to Check PO# ' || i_erm_id, sqlcode, sqlerrm);
                o_out_status := 'Unable to Check PO #' || i_erm_id;
               l_po_exist := 1;   
        END;

        IF l_po_exist < 1 THEN  /* IF PO/SN is available then lock the table */
            BEGIN
                SELECT
                    'x'
                INTO l_po_locking
                FROM
                    erm
                WHERE
                    erm_id = i_erm_id
                    AND status IN (
                        'NEW',
                        'SCH',
                        'TRF'
                    )
                FOR UPDATE OF status NOWAIT;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, i_erm_id || ' SN/PO is already open ', sqlcode, sqlerrm);
                    o_out_status := i_erm_id || ' SN/PO is already open ';
                    l_po_exist := 1;
                    RETURN;
               WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, i_erm_id || 'Issue in checking the PO ', sqlcode, sqlerrm);
                    o_out_status :=  ' Issue in checking the PO ' || i_erm_id;
                    l_po_exist := 1;
                    RETURN;     
            END;

        END IF; /* IF PO/SN is available then lock the table ends */

        IF l_po_exist < 1 THEN  /*  IF PO/SN is available then  continue with locking the record **/
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Calling sn/po: '
                                                || i_erm_id
                                                || '--'
                                                || l_po_locking, sqlcode, sqlerrm);

            IF l_po_locking != 'x' THEN  /* IF PO/SN is not available then log the error  */
                pl_text_log.ins_msg_async('FATAL', l_func_name, 'Unable to lock SN/PO to open sn/po: ' || i_erm_id, sqlcode, sqlerrm);
                o_out_status := 'Unable to lock SN/PO to open sn/po';
                RETURN;
            ELSE
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Currently processing request to open sn/po: ' ||i_erm_id, sqlcode,sqlerrm)
                ;
                pl_one_pallet_label.p_one_pallet_label(i_erm_id, l_pallet_status);
                BEGIN
                    SELECT
                        status
                    INTO l_po_status
                    FROM
                        erm
                    WHERE
                        erm_id = i_erm_id;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        o_out_status := 'FAILURE';
                        RETURN;
                    WHEN OTHERS THEN
                        o_out_status := 'FAILURE';
                        RETURN;    
                END;

                IF l_po_status = 'OPN' THEN  /* IF PO status is OPN then process creating batches */
                    p_crt_rcv_lm_bats(i_erm_id, l_opl_status);
                    pl_text_log.ins_msg_async('INFO', l_func_name,'Po# ' || i_erm_id || ' status = ' || l_opl_status, sqlcode,sqlerrm);
                  
                    pl_lmf.create_putaway_batches_for_po(i_erm_id, o_no_records_processed, o_no_batches_created, 
                    o_no_batches_existing, o_no_not_created_due_to_error);
                    COMMIT;
                    l_out_status1 := 'SUCCESS';
                ELSE
                   l_out_status1 :=   l_pallet_status;
                END IF;  /* IF PO status is OPN then process creating batches ends */

                l_opl_status := l_out_status1;
                o_out_status := l_out_status1;
            END IF;   /* IF PO/SN is not available then log the error ends */

        END IF; /*  IF PO/SN is available then  continue with locking the record  ends **/
     EXCEPTION
    WHEN OTHERS THEN
      pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception Raised at ' || l_func_name || 'for PO# = ' || i_erm_id, sqlcode, sqlerrm);
      o_out_status := 'FAILURE'; 
    END p_open_current;
    
  /*************************************************************************
  ** p_crt_rcv_lm_bats
  **  Description: Exam the lm flag and create_rc_batch_flag to determain 
  **               wether to create lm receiving batch for PO or not.
  **               Logic form crt_rcv_lm_bats.pc -- crt_rcv_lm_bats 
  **  Called By : p_open_current
  **  Calls :p_create_receiving_batch
  **  PARAMETERS:
  **      i_erm_id - ERM# passed from Frontend as Input
  **      o_lm_bats_crt   - Output parameter returned to front end
  **                        Gives Success or Error message on failure
  **  RETURN VALUES:
  **      Success or Failure message will be sent
  **
  ****************************************************************/

    PROCEDURE p_crt_rcv_lm_bats (
        i_erm_id        IN          erm.erm_id%TYPE,
        o_lm_bats_crt   OUT         VARCHAR2
    ) IS

        l_lbr_mgmt_flag          VARCHAR2(1);
        l_func_name              VARCHAR2(50) := 'pl_rcv_po_open.p_crt_rcv_lm_bats';
        l_create_rc_batch_flag   VARCHAR2(1) := 'N';
        l_dummy                  VARCHAR2(1);
        l_crb_status             VARCHAR2(10) := 'SUCCESS';
    BEGIN
        o_lm_bats_crt := 'SUCCESS';
        l_lbr_mgmt_flag := pl_common.f_get_syspar('LBR_MGMT_FLAG', 'N');
        IF ( l_lbr_mgmt_flag = 'Y' ) THEN    /*IF LBR_MGMT_FLAG is Y continue creating batches  */
            BEGIN
                SELECT 
                    create_batch_flag
                INTO l_create_rc_batch_flag
                FROM
                    lbr_func
                WHERE
                    lfun_lbr_func = 'RC';

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, ' ORACLE unable to get labor mgmt receiving batch flag. ' || i_erm_id, sqlcode, sqlerrm);
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, ' Others : unable to get labor mgmt receiving batch flag. ' || i_erm_id, sqlcode, sqlerrm);
            END;

            IF ( l_create_rc_batch_flag = 'Y' ) THEN  /*  check wheteher the PO is available  */
                BEGIN
                    SELECT
                        'x'
                    INTO l_dummy
                    FROM
                        erm
                    WHERE
                        erm_id = i_erm_id;

                EXCEPTION
                    WHEN NO_DATA_FOUND  THEN
                        l_dummy := 'y';
                    WHEN OTHERS THEN
                        l_dummy := 'y';   
                END;

                IF l_dummy = 'x' THEN /* PO available then proceed to create batches  */
                    p_create_receiving_batch(i_erm_id, l_crb_status);
                 ELSE 
                    pl_text_log.ins_msg_async('INFO', l_func_name, ' Po# ' || i_erm_id || ' is not availabe for creating batches.' , sqlcode, sqlerrm); 
                END IF;

                pl_text_log.ins_msg_async('INFO', l_func_name, ' End of get labor mgmt receiving batch flag for erm  = ' || i_erm_id, sqlcode, sqlerrm);
                o_lm_bats_crt := l_crb_status;
            END IF;  /*  check whether the PO is available  */

        END IF; /*IF LBR_MGMT_FLAG is Y continue creating batches ends */
   EXCEPTION
   WHEN OTHERS THEN
      pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception Raised at ' || l_func_name || 'for PO# = ' || i_erm_id, sqlcode, sqlerrm);
      o_lm_bats_crt := 'FAILURE';
   END p_crt_rcv_lm_bats;
   
  /*************************************************************************
  ** p_create_receiving_batch
  **
  **  Description: For each non extended PO opened by SMWS, one Gagnon receiving
  **  batch will be created.  The batch's area will be determined by the area
  **  where the Receiving Worksheet is sent.  Since there are three major
  **  warehouse door areas allowed in SWMS, there will be three job codes for
  **  receiving: Freezer Receiving, Cooler Receiving, and Dry Receiving.
  **  Logic from crt_rcv_lm_bats.pc
  **
  **  Called By : p_crt_rcv_lm_bats
  **  Calls :
  **  PARAMETERS:
  **      i_erm_id - ERM# passed from Frontend as Input
  **      o_crb_batch   - Output parameter returned to front end
  **  RETURN VALUES:
  **      Success or Failure message will be sent
  **
  ****************************************************************/

    PROCEDURE p_create_receiving_batch (
        i_erm_id    IN          erm.erm_id%TYPE,
        o_crb_batch   OUT         VARCHAR2
    ) IS

        l_func_name           VARCHAR2(50) := 'pl_rcv_po_open.p_create_receiving_batch';
        l_found               VARCHAR2(5) := 'FALSE';
        l_jobcode             batch.jbcd_job_code%TYPE;
        l_batch               batch.batch_no%TYPE;
        l_dest_loc            putawaylst.dest_loc%TYPE;
        l_pallet_id           putawaylst.pallet_id%TYPE;
        l_sm_dest_loc         putawaylst.dest_loc%TYPE;
        l_sm_pallet_id        putawaylst.pallet_id%TYPE;
        l_area                pm.area%TYPE;
        l_pm_area             pm.area%TYPE;
        l_num_splits          NUMBER;
        l_num_pieces          NUMBER;
        l_num_cases           NUMBER;
        l_num_pallets         NUMBER;
        l_num_items           NUMBER;
        l_num_po              NUMBER;
        l_num_data_captures   NUMBER;
        l_num_dc_lot_trk      NUMBER;
        l_num_dc_exp_date     NUMBER;
        l_num_dc_mfr_date     NUMBER;
        l_num_dc_catch_wt     NUMBER;
        l_num_dc_temp         NUMBER;
        l_num_dc_tti          NUMBER;
        l_dest_loc_arr        VARCHAR2(1);
        l_erm_type            erm.erm_type%TYPE;
        l_kvi_details         NUMBER := 0;
        l_jbcd_job_code_check NUMBER := 0;
        l_job_status          NUMBER;
        l_batch_cnt           NUMBER;
        l_batch_no_po         batch.batch_no%TYPE;
        l_batch_status        VARCHAR2(20);
        
        CURSOR c_pallet_destlocs IS
        SELECT
            put.pallet_id,
            put.dest_loc,
            pm.area
        FROM
            putawaylst put,
            pm
        WHERE
            put.rec_id = i_erm_id
            AND pm.prod_id = put.prod_id
            AND pm.cust_pref_vendor = put.cust_pref_vendor
        ORDER BY
            put.pallet_id DESC;

    BEGIN
         pl_text_log.ins_msg_async('INFO', l_func_name, ' Starting p_create_receiving_batch ' || i_erm_id, sqlcode, sqlerrm);
        BEGIN

            /*  check if ERM is an XDOCK, and dest_loc of putawaylst is a DOOR. 
                IF so take the last character of XN ERM as the l_area.
                an example ERM of a XN: 031735755-D
            */
            BEGIN
                SELECT erm_type
                INTO l_erm_type
                FROM  erm
                WHERE erm_id = i_erm_id;

            EXCEPTION
                WHEN OTHERS THEN
                    l_found := 'FALSE';
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'OTHERS : Error getting the type of PO#' || i_erm_id, sqlcode, sqlerrm);      
            END;

            IF l_erm_type = 'XN' THEN 
                l_area :=  substr(i_erm_id,-1);
                l_batch := 'PO' || ltrim(i_erm_id);
            ELSE
                SELECT
                    s.area_code,
                    'PO' || ltrim(i_erm_id)
                INTO
                    l_area,
                    l_batch
                FROM
                    swms_sub_areas   s,
                    aisle_info       ai,
                    putawaylst       p
                WHERE
                    s.sub_area_code = ai.sub_area_code
                    AND ai.name = substr(p.dest_loc, 1, 2)
                    AND p.dest_loc <> 'LR'
                    AND p.pallet_id = (
                        SELECT
                            MIN(p2.pallet_id)
                        FROM
                            putawaylst p2
                        WHERE
                            p2.rec_id = i_erm_id
                    );
            END IF;
    
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
			BEGIN                
                OPEN c_pallet_destlocs;
                WHILE l_found= 'FALSE' LOOP
                    FETCH c_pallet_destlocs INTO
                        l_pallet_id,
                        l_dest_loc,
                        l_pm_area;
                    IF c_pallet_destlocs%NOTFOUND THEN
                        EXIT;
                    END IF;
                    IF c_pallet_destlocs%found THEN   /* When record available assign value */
                        l_dest_loc_arr := substr(l_dest_loc, 1, 1);
                    END IF;
                    
                    IF ( l_dest_loc_arr != '*' AND ( l_dest_loc != 'LR' ) ) THEN /* Check the l_dest_loc values  */ 
                        BEGIN
                            SELECT
                                area_code,
                                'PO' || ltrim(i_erm_id)
                            INTO
                                l_area,
                                l_batch
                            FROM
                                swms_sub_areas   s,
                                aisle_info       ai
                            WHERE
                                s.sub_area_code = ai.sub_area_code
                                AND ai.name = substr(l_dest_loc, 1, 2);

                            l_found := 'TRUE';
                        EXCEPTION
                            WHEN OTHERS THEN
                                l_found := 'FALSE';
                                pl_text_log.ins_msg_async('INFO', l_func_name, 'OTHERS : Error getting swms area code from the list of items in the PO#' 
                                || i_erm_id, sqlcode, sqlerrm);      
                        END;
                    ELSE
                        l_sm_pallet_id := l_pallet_id;
                        l_sm_dest_loc := l_dest_loc;
                    END IF;
                END LOOP;
					
                CLOSE c_pallet_destlocs;
            EXCEPTION
            WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'OTHERS : Error getting swms area code from the list of items in the PO#' 
                    || i_erm_id, sqlcode, sqlerrm);   
                    o_crb_batch := 'FAILURE';
                    RETURN;
            END;     

            IF ( l_found = 'FALSE' ) THEN  /* check l_found value  */
                IF ( length(l_sm_dest_loc) = 1 AND l_sm_dest_loc = '*' ) THEN /* checking sm_dest_loc length and * value  */ 
                    BEGIN
                        SELECT
                            area_code,
                            'PO' || ltrim(i_erm_id)
                        INTO
                            l_area,
                            l_batch
                        FROM
                            swms_sub_areas   s,
                            aisle_info       ai,
                            inv              i,
                            loc              l,
                            putawaylst       p
                        WHERE
                            s.sub_area_code = ai.sub_area_code
                            AND ai.name = substr(i.plogi_loc, 1, 2)
                            AND p.pallet_id = l_sm_pallet_id
                            AND i.prod_id = p.prod_id
                            AND i.plogi_loc = l.logi_loc
                            AND l.perm = 'Y';

                    EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                            /*
                            ** Default the area code to 'D'
                            */
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'ORACLE error getting home_slot base on pallet_id', sqlcode, sqlerrm);
                        SELECT 'D', 'PO'||LTRIM(i_erm_id)
                                    INTO l_area, l_batch
                                    FROM  dual;
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'OTHERS : ORACLE error getting home_slot base on pallet_id.l_sm_pallet_id = '
                            || l_sm_pallet_id, sqlcode, sqlerrm);
                            o_crb_batch := 'FAILURE';
                            RETURN;
                    END;
                ELSIF ( length(l_sm_dest_loc) = 2 AND ( ( l_sm_dest_loc = '**' ) OR ( l_sm_dest_loc = 'LR' ) ) ) THEN
                    BEGIN
                        SELECT
                            area_code,
                            'PO' || ltrim(i_erm_id)
                        INTO
                            l_area,
                            l_batch
                        FROM
                            swms_sub_areas   s,
                            aisle_info       ai,
                            pm               m,
                            putawaylst       p
                        WHERE
                            s.sub_area_code = ai.sub_area_code
                            AND ai.name = substr(m.last_ship_slot, 1, 2)
                            AND p.pallet_id = l_sm_pallet_id
                            AND m.prod_id = p.prod_id
                            AND m.cust_pref_vendor = p.cust_pref_vendor;

                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            IF ( l_sm_dest_loc = 'LR' ) THEN  /* sm_dest_loc = 'LR'  */ 
                                BEGIN
                                    SELECT
                                        area_code,
                                        'PO' || ltrim(i_erm_id)
                                    INTO
                                        l_area,
                                        l_batch
                                    FROM
                                        swms_sub_areas s
                                    WHERE
                                        s.area_code = l_pm_area;

                                EXCEPTION
                                    WHEN OTHERS THEN
                                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Could not determine the area for the receiving labor' 
                                        || 'batch which is used to determine the job code.  Will default to area D', sqlcode, sqlerrm);
                                        SELECT
                                            'D',
                                            'PO' || ltrim(i_erm_id)
                                        INTO
                                            l_area,
                                            l_batch
                                        FROM
                                            dual;

                                END;
                            END IF;
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'OTHERS : ORACLE error getting last_ship_slot.l_sm_pallet_id = '
                            ||l_sm_pallet_id, sqlcode, sqlerrm);
                            o_crb_batch := 'FAILURE';
                            RETURN;  
                        END;

                        
                ELSE
                    pl_text_log.ins_msg_async('INFO', l_func_name,  'Internal error in case of no slots found', sqlcode, sqlerrm);
                END IF;  /*  sm_dest_loc = 'LR' ends */
            END IF;
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'ORACLE unable to get area code base on min(pallet_id)', sqlcode, sqlerrm);
        END;  /* checking sm_dest_loc length and * value  ends */ 

                  /* Use New SN Receiving Labor Management Job Codes*/
    
                    /*  ASN to all OPCOs project
                    ** Use Jobcode 'SNNOR' for VN Receving. 
                    ** We havent created New Job Codes for VN yet. Once created 
                    ** start using VN job codes.
                    */
                    l_jobcode := l_area || 'RCNOR';
                    BEGIN 
                        SELECT
                            erm_type,
                            DECODE(erm_type, 'SN', l_area|| 'SNNOR', 'VN', l_area|| 'SNNOR', l_area|| 'RCNOR')
                        INTO
                            l_erm_type,
                            l_jobcode
                        FROM
                            erm
                        WHERE
                            erm_id = i_erm_id;

                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            l_erm_type:='PO';
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'ORACLE unable to get erm type and default job code', sqlcode, sqlerrm);
                        WHEN OTHERS THEN
                            l_erm_type:='PO';
                            pl_text_log.ins_msg_async('INFO', l_func_name, ' OTHERS : ORACLE unable to get erm type and default job code', sqlcode, sqlerrm);
                     END;

                    BEGIN
                        -- Story 3603 (kchi7065) Added erm_type XN to erm types allowable for receiving job codes. 
                        SELECT
                            jbcd_job_code
                        INTO l_jobcode
                        FROM
                            job_code
                        WHERE
                            1 = (
                                SELECT
                                    COUNT(*)
                                FROM
                                    job_code
                                WHERE
                                    lfun_lbr_func = 'RC'
                                    AND whar_area = l_area
                                    AND nvl(sn_rcv_jbcd, 'N') = DECODE(l_erm_type, 'SN', 'Y', 'VN', 'Y', 'XN', 'Y', 'N')
                            )
                            AND lfun_lbr_func = 'RC'
                            AND nvl(sn_rcv_jbcd, 'N') = DECODE(l_erm_type, 'SN', 'Y', 'VN', 'Y', 'XN', 'Y',  'N')
                            AND whar_area = l_area;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            pl_text_log.ins_msg_async('INFO', l_func_name,  'ORACLE unable to get job code.', sqlcode, sqlerrm);
                        WHEN OTHERS THEN
                            l_jbcd_job_code_check := 1;
                            pl_text_log.ins_msg_async('WARNING', l_func_name,  'OTHERS ORACLE unable to get job code.', sqlcode, sqlerrm);
                    END;
                        
                    IF l_jbcd_job_code_check = 0 THEN   /* l_jbcd_job_code_check check */
                        l_num_pieces := 0;
                        l_num_cases := 0;
                        l_num_items := 0;
                        l_num_po := 0;
                        l_num_pallets := l_num_data_captures;
                        BEGIN
                            SELECT
                                SUM(DECODE(y.uom, 1, y.qty_received, 0)),
                                SUM(DECODE(y.uom, 2, y.qty_received / p.spc, 0, y.qty_received / p.spc, 0)),
                                COUNT(DISTINCT y.pallet_id),
                                COUNT(DISTINCT y.prod_id),
                                SUM(DECODE(p.lot_trk, 'Y', 1, 0)),
                                SUM(DECODE(p.exp_date_trk, 'Y', 1, 0)),
                                SUM(DECODE(p.mfg_date_trk, 'Y', 1, 0)),
                                COUNT(DISTINCT DECODE(p.catch_wt_trk, 'Y', y.prod_id, 0)) - least(1, SUM(DECODE(p.catch_wt_trk, 'Y'
                                , 0, 1))),
                                COUNT(DISTINCT DECODE(p.temp_trk, 'Y', y.prod_id, 0)) - least(1, SUM(DECODE(p.temp_trk, 'Y', 0, 1
                                ))),
                                COUNT(DISTINCT DECODE(y.tti_trk, 'Y', y.prod_id, 0)) - least(1, SUM(DECODE(y.tti_trk, 'Y', 0, 1))
                                )
                            INTO
                                l_num_splits,
                                l_num_cases,
                                l_num_pallets,
                                l_num_items,
                                l_num_dc_lot_trk,
                                l_num_dc_exp_date,
                                l_num_dc_mfr_date,
                                l_num_dc_catch_wt,
                                l_num_dc_temp,
                                l_num_dc_tti
                            FROM
                                pm           p,
                                putawaylst   y
                            WHERE
                                p.prod_id = y.prod_id
                                AND y.rec_id = i_erm_id;

                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                pl_text_log.ins_msg_async('INFO', l_func_name,  'ORACLE unable to get KVIs for receiving lm batch.', sqlcode, sqlerrm);
                                l_kvi_details := 1;
                            WHEN OTHERS THEN
                                pl_text_log.ins_msg_async('INFO', l_func_name,  'OTHERS unable to get KVIs for receiving lm batch.', sqlcode, sqlerrm);
                                l_kvi_details := 1;   
                        END;

                        IF l_kvi_details = 0 THEN   /* l_kvi_details check */
                            l_num_pieces := l_num_cases + l_num_splits;
                            l_num_data_captures := l_num_dc_lot_trk + l_num_dc_exp_date + l_num_dc_mfr_date + l_num_dc_catch_wt + l_num_dc_temp
                            + l_num_dc_tti;
                            l_num_po := l_num_po + 1;
                            pl_text_log.ins_msg_async('INFO', l_func_name,  'Going to insert batch table.', sqlcode, sqlerrm);
                            l_batch_no_po := 'PO' || i_erm_id;

                            INSERT INTO batch (
                                batch_no,
                                batch_date,
                                status,
                                jbcd_job_code,
                                user_id,
                                ref_no,
                                kvi_no_piece,
                                kvi_no_case,
                                kvi_no_item,
                                kvi_no_pallet,
                                kvi_no_data_capture,
                                kvi_no_po
                            ) VALUES (
                                l_batch_no_po,
                                trunc(SYSDATE),
                                'X',
                                l_jobcode,
                                NULL,
                                i_erm_id,
                                l_num_pieces,
                                l_num_cases,
                                l_num_items,
                                l_num_pallets,
                                l_num_data_captures,
                                l_num_po
                            );

                            SELECT
                                COUNT(*)
                            INTO l_batch_cnt
                            FROM
                                batch
                            WHERE
                                ref_no = i_erm_id
                                AND jbcd_job_code = l_jobcode
                                AND batch_date = trunc(SYSDATE)
                                AND status = 'X';

                            IF l_batch_cnt < 1 THEN   /* check batch count ends */
                                pl_text_log.ins_msg_async('INFO', l_func_name, 'ORACLE unable to create receiving batch', 
                                sqlcode, sqlerrm);
                            ELSE
                                pl_batch_download.p_lm_download(l_batch_no_po, l_batch_status);
                                IF ( l_batch_status = 'SUCCESS' ) THEN /* check l_batch_status */
                                    pl_text_log.ins_msg_async('INFO', l_func_name, 'LM Batch Is Created', sqlcode, sqlerrm);
                                    o_crb_batch := l_batch_status;
                                ELSE
                                    pl_text_log.ins_msg_async('INFO', l_func_name,  'LM Batch Is Not Created', sqlcode, sqlerrm);
                                    o_crb_batch := l_batch_status;
                                END IF;  /* check l_batch_status ends */

                            END IF; /* check batch count ends */

                        END IF; /* l_kvi_details check ends */
                    END IF; /* l_jbcd_job_code_check check ends */
    EXCEPTION
    WHEN OTHERS THEN
      pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception Raised at ' || l_func_name || 'for PO# = ' || i_erm_id, sqlcode, sqlerrm);
      o_crb_batch := 'FAILURE';
    END p_create_receiving_batch;
    
  /*************************************************************************
  ** p_open_scheduled
  **  Description: To open scheduled POs based on From time and To time.
  **               Scheduled date will be defaulted to Sysdate.
  **                  Based Oracle Form Logic
  **  Called By : open_po_main
  **  Calls :
  **  PARAMETERS :
  **      i_schdfromdate - From time passed from frontend as input
  **      i_schdtodate  - To time passed from frontend as input
  **      o_out_status   - Output parameter returned to front end
  **  RETURN VALUES:
  **      Success or Failure message will be sent
  **
  ****************************************************************/

    PROCEDURE p_open_scheduled (
        i_schdfromdate   IN             VARCHAR2,
        i_schdtodate     IN             VARCHAR2,
        o_out_stat       OUT            VARCHAR2
    ) IS

        l_func_name          VARCHAR2(50) := 'pl_rcv_po_open.p_open_scheduled';
        l_open_all_po        VARCHAR2(1);
        l_from_hour_passed   VARCHAR2(8);
        l_to_hour_passed     VARCHAR2(8);
        l_out_status         VARCHAR2(200);
        l_opl_status         VARCHAR2(200);
        l_count              NUMBER;
        l_new_to_hours       VARCHAR2(5);
        l_am_pm_flag         VARCHAR2(2);
    BEGIN
  /* Sysdate will be defaulted as Schedule date*/
      /* chking the From time and To Time  */
        pl_text_log.ins_msg_async('INFO', l_func_name,  'open POs by hour flag' || l_open_all_po, sqlcode, sqlerrm);

        IF i_schdfromdate IS NULL THEN  /* Schedule from date calc */
            l_from_hour_passed := '00:00:01';
        ELSE
            l_from_hour_passed := i_schdfromdate;
        END IF;  /* Schedule from date calc ends */

        IF i_schdtodate IS NULL THEN /* Schedule to date calc */
            l_to_hour_passed := '23:59';
        ELSE
            l_to_hour_passed := i_schdtodate;
        END IF; /* Schedule to date calc ends */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'initialize l_from_hour_passed' || l_from_hour_passed || 
        'initialize l_to_hour_passed' || l_to_hour_passed, sqlcode, sqlerrm);
        IF i_schdfromdate IS NOT NULL AND i_schdtodate IS NOT NULL THEN  /* when from and to date are null */
             p_open_schedule_po(l_from_hour_passed, l_to_hour_passed, l_out_status);
        ELSE
        /* Getting the OPEN_PO_HOURLY flag */
            l_open_all_po := pl_common.f_get_syspar('OPEN_PO_HOURLY', 'N');
            IF l_open_all_po = 'Y' THEN        /*  l_open_all_po value check  */        
          /* Getting the OPEN_PO_SCHED_HOUR time */
                l_new_to_hours := pl_common.f_get_syspar('OPEN_PO_SCHED_HOUR', 'N');
                IF l_new_to_hours != 'N' THEN   /* OPEN_PO_SCHED_HOUR value check */ 
                    l_am_pm_flag := substr(l_new_to_hours, 3, 2);

            /*   Finding the PM/AM of the hrs and converting them to 24hrs format */
                    IF l_am_pm_flag = 'AM' THEN  /* Hrs calc based on AM or PM */ 
                        l_to_hour_passed := substr(l_new_to_hours, 1, 2)
                                          || ':00';
                    ELSE
                        l_to_hour_passed := ( substr(l_new_to_hours, 1, 2) + 12 )
                                          || ':00';
                    END IF; /* Hrs calc based on AM or PM Ends */ 

                    pl_text_log.ins_msg_async('INFO', l_func_name, 'OPEN_PO_SCHED_HOUR l_from_hour_passed' || l_from_hour_passed || 
                    'OPEN_PO_SCHED_HOUR l_to_hour_passed' || l_to_hour_passed, sqlcode, sqlerrm);
                    
                    p_open_schedule_po(l_from_hour_passed, l_to_hour_passed, l_out_status);
                END IF;   /* OPEN_PO_SCHED_HOUR value check ends*/ 

            ELSIF l_open_all_po = 'N' THEN
                pl_text_log.ins_msg_async('INFO', 'TABLE=SYS_CONFIG', 'OPEN_PO_HOURLY Flag is N ', sqlcode, sqlerrm);
                l_out_status := -1;
            END IF;   /*  l_open_all_po value check ends */   

        END IF;  /* when from and to date are null ends */

        o_out_stat := l_out_status;
        IF o_out_stat = -1 THEN  /* o_out_stat to be passed  */ 
            o_out_stat := 'PO(s) not processed. ';
        ELSE
            o_out_stat := 'SUCCESS';
        END IF;  /* o_out_stat to be passed  ends*/ 
    EXCEPTION
    WHEN OTHERS THEN
      pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception Raised at ' || l_func_name || ' for Scheduled Hours', sqlcode, sqlerrm);
      o_out_stat := 'FAILURE';
    END p_open_scheduled;

  /*************************************************************************
  ** p_open_schedule_po
  **  Description: To open scheduled POs based on From time and To time.
  **                 
  **  Called By : p_open_scheduled
  **  Calls :
  **  PARAMETERS :
  **      i_hour_passed_fr - From time passed from frontend as input
  **      i_hour_passed_to  - To time passed from frontend as input
  **      o_out_status   - Output parameter returned to front end
  **  RETURN VALUES:
  **      Success or Failure message will be sent
  **
  ****************************************************************/
  
    PROCEDURE p_open_schedule_po (
        i_hour_passed_fr   IN               VARCHAR2,
        i_hour_passed_to   IN               VARCHAR2,
        o_out_status       OUT              VARCHAR2
    ) IS

        l_func_name              VARCHAR2(50) := 'pl_rcv_po_open.p_open_schedule_po';
        
        CURSOR c_po_opn (
            from_time VARCHAR2,
            to_time VARCHAR2
        ) IS
        SELECT
            e.erm_id
        FROM
            swms_areas       s,
            swms_sub_areas   sa,
            aisle_info       ai,
            loc              l,
            erd              d,
            erm              e
        WHERE
            e.status IN (
                'NEW',
                'SCH'
            )
            AND e.warehouse_id = '000'
            AND d.erm_id = e.erm_id
            AND d.prod_id = l.prod_id (+)
            AND d.cust_pref_vendor = l.cust_pref_vendor (+)
            AND sa.sub_area_code (+) = ai.sub_area_code
            AND ai.name (+) = substr(l.logi_loc, 1, 2)
            AND sa.area_code = s.area_code (+)
            AND nvl(l.uom, 0) IN (
                0,
                2
            )
            AND d.erm_line_id IN (
                SELECT
                    MIN(erm_line_id)
                FROM
                    erd
                WHERE
                    erd.erm_id = e.erm_id
            )
            AND trunc(e.sched_date) = trunc(SYSDATE)
            AND ( e.sched_date BETWEEN TO_DATE(TO_CHAR(SYSDATE, 'dd-mon-yyyy')
                                               || from_time, 'dd-mon-yyyy hh24:mi:ss') AND TO_DATE(TO_CHAR(SYSDATE, 'dd-mon-yyyy'
                                               )
                                                                                                   || to_time, 'dd-mon-yyyy hh24:mi:ss'
                                                                                                   ) )
        ORDER BY
            nvl(s.sort, 0),
            e.load_no,
            e.sched_date;

        l_erm_id                 erm.erm_id%TYPE;
        l_new_erm_id             erm.erm_id%TYPE;
        l_erm_id_lenght          NUMBER;
        l_auto_open_po_flag      VARCHAR2(1);
        l_dummy                  VARCHAR2(1);
        l_pallet_status          VARCHAR2(100);
        l_opl_status             VARCHAR2(100);
        l_po_status              VARCHAR2(5);
        l_new_dflt_cool_prt      VARCHAR2(10);
        l_new_dflt_dry_prt       VARCHAR2(10);
        l_cool_parm_src          VARCHAR2(7) := 'file';
        l_dry_parm_src           VARCHAR2(7) := 'file';
        l_order_by               VARCHAR2(100);
        l_live_receiving_syspar  sys_config.config_flag_val%TYPE;
        l_sched_print_PO_syspar  sys_config.config_flag_val%TYPE;
        l_print_lumper_syspar    sys_config.config_flag_val%TYPE;
        l_print_lumper_flag      VARCHAR2(1);
        l_ch_live_receiving_syspar      VARCHAR2(1);
        l_ch_sched_print_PO_syspar      VARCHAR2(1);
        l_dest_loc_flg           VARCHAR2(1);
        l_prt_q                  VARCHAR2(10);
        l_ca_erm_type            VARCHAR2(3);
        l_ch_print_reports_bln   BOOLEAN;
        l_command                VARCHAR2(256);
        l_rc                     VARCHAR2(500);
        out_stat                 VARCHAR2(100);
        l_forklift_active_bln    BOOLEAN;
        o_no_records_processed   NUMBER;
        o_no_batches_created     NUMBER;
        o_no_batches_existing           NUMBER;
        o_no_not_created_due_to_error   NUMBER;
        l_query_seq              NUMBER;
        l_print_condition        VARCHAR2(200);
    BEGIN
         pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting p_open_schedule_po ', sqlcode, sqlerrm);

         /* Reading Printer Configurations */

         BEGIN
            SELECT config_flag_val
            INTO l_new_dflt_cool_prt
            FROM sys_config
            WHERE application_func = 'RECEIVING'
             AND config_flag_name = 'COOLER_PRINTER';

            IF l_new_dflt_cool_prt IS NULL THEN
                l_new_dflt_cool_prt := 'wrk11';  /* hard coded default printer */
            ELSE
                l_cool_parm_src := 'syspar';
            END IF;

         EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_new_dflt_cool_prt := 'wrk11';
                return;
            WHEN OTHERS THEN
                l_new_dflt_cool_prt := 'wrk11';
                return;
         END;

         BEGIN
            SELECT config_flag_val
            INTO l_new_dflt_dry_prt
            FROM sys_config
            WHERE application_func = 'RECEIVING'
             AND config_flag_name = 'DRY_PRINTER';

            IF l_new_dflt_dry_prt IS NULL THEN
                l_new_dflt_dry_prt := 'wrk11';  /* hard coded default printer */
            ELSE
                l_dry_parm_src := 'syspar';
            END IF;

         EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_new_dflt_dry_prt := 'wrk11';
                return;
            WHEN OTHERS THEN
                l_new_dflt_dry_prt := 'wrk11';
                return;
         END;


         BEGIN
         SELECT ltrim(rtrim(b.Param_values))
         INTO  l_order_by
         FROM sys_config a, sys_config_valid_values b
         WHERE a.application_func = 'RECEIVING'
          AND a.CONFIG_FLAG_NAME = b.CONFIG_FLAG_NAME
          AND a.CONFIG_FLAG_NAME = 'RP1RE_SORT'
          AND a.config_flag_val =  b.config_flag_val;

         pl_text_log.ins_msg_async('INFO' , l_func_name, l_order_by, '10', 'Test Orderby', 'TP_wk_sheet', 'N');

         EXCEPTION
            WHEN OTHERS THEN
            l_order_by := 'Order by e.erm_id';
         END;

         /* Dynamic OrderBy code with sys par end Jun 19 2017 vkal9662
          09/01/2016  Brian Bent  Live Receiving
          Moved selecting the PRINT_LUMPER syspar to this point.
          Before it was done a little later in the code.
          We need to know the value before we get to the Live
          Receiving active syspar so that we can log a message
          if Live Receiving is on and PRINT_LUMPER is off.
         */

            BEGIN
                l_print_lumper_syspar := pl_common.f_get_syspar('PRINT_LUMPER', 'N');
            EXCEPTION
                WHEN OTHERS THEN
                    /* Error retieving the Print Lumper syspar.  Log a message and use 'N' for the value. */
                    l_print_lumper_syspar := 'N';

                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Error select syspar PRINT_LUMPER.  Will use N as the value.',
                       sqlcode, sqlerrm);
            END;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'Syspar PRINT_LUMPER has value [' || l_print_lumper_syspar || ']', NULL, NULL);

            l_print_lumper_flag := l_print_lumper_syspar;

            /* 08/30/2016  Brian Bent Get the Live Receiving syspar. Do error checking. */
            BEGIN
                l_live_receiving_syspar := pl_common.f_get_syspar('ENABLE_LIVE_RECEIVING', 'x');

                IF (l_live_receiving_syspar = 'x') THEN
                    --
                    -- Did not find the Live Receiving syspar.  Log a message and
                    -- use 'N' for the value.
                    --
                    l_live_receiving_syspar := 'N';

                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Syspar ENABLE_LIVE_RECEIVING not found.  Will use N as the value.', NULL, NULL);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    --
                    -- Error retieving the Live Receiving syspar.  Log a message and
                    -- use 'N' for the value.
                    --
                    l_live_receiving_syspar := 'N';

                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Error select syspar ENABLE_LIVE_RECEIVING.  Will use N as the value.', sqlcode, sqlerrm);
            END;

            --
            -- Log the ENABLE_LIVE_RECEIVING syspar
            --
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Syspar ENABLE_LIVE_RECEIVING has value ['|| l_live_receiving_syspar || ']', NULL, NULL);

            --
            -- Log a message stating if live receiving is on or off and what
            -- receiving documents will be printed.
            --
            IF (l_live_receiving_syspar = 'Y') THEN
                IF (l_print_lumper_syspar = 'Y') THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name,'LIVE RECEIVING is active and syspar PRINT_LUMPER is Y.'
                       || ' Only the lumper worksheet rp4ra is printed and the receiving load worksheet rp1rn is printed.', NULL, NULL);
                ELSE
                    pl_text_log.ins_msg_async('WARN', l_func_name,
                       'LIVE RECEIVING is active and syspar PRINT_LUMPER is ['|| l_print_lumper_syspar || '].'
                       || ' The lumper worksheet rp4ra will not be printed.  The receiving load worksheet rp1rn is printed.', NULL, NULL);
                END IF;
            END IF;

            l_ch_live_receiving_syspar := l_live_receiving_syspar;

            --
            -- 04/28/2017  Jim Gilliam Get the Schedule Print PO Worksheet syspar.
            --
            BEGIN
                l_sched_print_PO_syspar := pl_common.f_get_syspar('PRINT_SCHEDULED_PO_WORKSHEETS', 'x');

                IF (l_sched_print_PO_syspar = 'x') THEN
                    --
                    -- Did not find the Schedule Print PO Worksheet syspar.  Log a message
                    -- and use 'Y' for the value.
                    --
                    l_sched_print_PO_syspar := 'Y';

                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Syspar PRINT_SCHEDULED_PO_WORKSHEETS not found.  Will use Y as the value.', NULL, NULL);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    --
                    -- Error retrieving the Schedule Print PO Worksheet syspar.  Log a
                    -- message and use 'Y' for the value.
                    --
                    l_sched_print_PO_syspar := 'Y';

                    pl_text_log.ins_msg_async('WARN', l_func_name,
                       'Error select syspar PRINT_SCHEDULED_PO_WORKSHEETS.  Will use Y as the value.',
                       sqlcode, sqlerrm);
            END;

            --
            -- Log the PRINT_SCHEDULED_PO_WORKSHEETS syspar
            --
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Syspar PRINT_SCHEDULED_PO_WORKSHEETS has value ['|| l_sched_print_PO_syspar || ']', NULL, NULL);

            --
            -- If live receiving is on and Schedule Print PO Worksheet is on or off then log a message
            -- stating how PO receiving documents will be printed.
            --
            IF (l_live_receiving_syspar = 'Y') THEN
                IF (l_sched_print_PO_syspar = 'Y') THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name,
                       'LIVE RECEIVING is active and syspar PRINT_SCHEDULED_PO_WORKSHEETS is Y.'
                       || ' The PO worksheet may be printed via schedule and Live Receiving hip printer.', NULL, NULL);
                ELSE
                    pl_text_log.ins_msg_async('WARN', l_func_name,
                       'LIVE RECEIVING is active and syspar PRINT_SCHEDULED_PO_WORKSHEETS is N.'
                       || ' The PO worksheet may be printed only via Live Receiving hip printer.', NULL, NULL);
                END IF;
            END IF;

            l_ch_sched_print_PO_syspar := l_sched_print_PO_syspar;


            pl_text_log.ins_msg_async('INFO', l_func_name, 'Cooler printer set to '
                                                 || l_new_dflt_cool_prt
                                                 || ' by' || l_cool_parm_src, NULL, NULL);

            pl_text_log.ins_msg_async('INFO', l_func_name, 'Dry printer set to '
                                                 || l_new_dflt_dry_prt
                                                 || ' by' || l_dry_parm_src, NULL, NULL);

         FOR po_opn_record IN c_po_opn(i_hour_passed_fr, i_hour_passed_to) LOOP
            l_erm_id := po_opn_record.erm_id;
            BEGIN
                IF pl_common.f_is_internal_production_po(l_erm_id) THEN
                    l_auto_open_po_flag := 'Y';
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'ERM#'
                                                        || l_erm_id
                                                        || ' is an internal production PO', NULL, NULL);

                ELSE
                    l_auto_open_po_flag := 'N';
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'ERM#'
                                                        || l_erm_id
                                                        || ' is not an internal production PO', NULL, NULL);

                END IF;

            END;

            l_forklift_active_bln := f_is_forklift_active;

            IF ( l_auto_open_po_flag = 'Y' ) THEN
                  IF ( f_update_auto_po_door_no(l_erm_id) != SWMS_NORMAL ) THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Could not update erm.door_no with syspar door no.', NULL, NULL);
                         continue;
                  END IF;
            ELSIF ( l_forklift_active_bln = TRUE ) THEN
                IF ( f_update_erm_door_no(l_erm_id) != SWMS_NORMAL ) THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Could not update the erm door# to the forklift door number.', NULL, NULL);
                    continue;
                END IF;
            END IF;

            BEGIN
                SELECT
                    'x'
                INTO l_dummy
                FROM
                    erm
                WHERE
                    erm_id = l_erm_id
                    AND status IN (
                        'SCH',
                        'NEW'
                    )
                FOR UPDATE OF status NOWAIT;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'ORACLE PO locked by another user', NULL, NULL);
                    o_out_status := 'FAILURE';
                    RETURN;
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'OTHERS PO locked by another user', NULL, NULL);
                    o_out_status := 'FAILURE';
                    RETURN;    
            END;

            pl_one_pallet_label.p_one_pallet_label(l_erm_id, l_pallet_status);
            BEGIN
                SELECT
                    status
                INTO l_po_status
                FROM
                    erm
                WHERE
                    erm_id = l_erm_id;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    out_stat := 'FAILURE';
                    return;
                WHEN OTHERS THEN
                    out_stat := 'FAILURE';
                    return;    
            END;

            IF l_po_status = 'OPN' THEN  /* IF PO status is OPN then process creating batches */
                p_crt_rcv_lm_bats(l_erm_id, l_opl_status);
                pl_lmf.create_putaway_batches_for_po(l_erm_id, o_no_records_processed, o_no_batches_created, 
                o_no_batches_existing, o_no_not_created_due_to_error);
                COMMIT; /* Commit after batch creation */

                /* Worksheet printing related changes */

                BEGIN
                    SELECT DECODE(SUBSTR(dest_loc, 1, 1), 'F', '1','C', '1','I', '1','K', '1', '0')
                    INTO l_dest_loc_flg
                    FROM putawaylst
                    WHERE rec_id = l_erm_id;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception in l_dest_loc_flg reading', sqlcode, sqlerrm);
                END;

                IF (l_dest_loc_flg = '1') THEN
                    l_prt_q := l_new_dflt_cool_prt;
                ELSE
                    l_prt_q := l_new_dflt_dry_prt;
                END IF;

                BEGIN
                    SELECT erm_type
                    INTO l_ca_erm_type
                    FROM erm
                    WHERE erm_id = l_erm_id;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'ORACLE unable to get erm_type', sqlcode, sqlerrm);
                END;

                /*
                ** Initialization
                */
                l_ch_print_reports_bln := FALSE;

                /*
                ** acppzp if it is a PO then print
                ** the report otherwise not
                */

                BEGIN
                  SELECT print_query_seq.nextval INTO l_query_seq FROM DUAL;
                EXCEPTION
                  WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to select print query sequence', sqlcode, sqlerrm);
                    o_out_status := 'FAILURE';
                    EXIT;
                END;

                /*
                **  14-OCT-09 ctvgg000 - ASN to all OPCOs project
                **	Do not print Labels for SN or VN.
                **	Added VN to if condition to print only worksheet.
                */
                IF (l_ca_erm_type = 'SN' OR l_ca_erm_type = 'VN') THEN
                     /*
                     ** Processing a SN or VN.
                     ** Run report rp1re which prints only the PO worksheet.
                     */
                      BEGIN
                        SELECT INSTR(l_erm_id,' ') - 1, SUBSTR(l_erm_id,0,INSTR(l_erm_id,' '))
                        INTO l_erm_id_lenght, l_new_erm_id
                        FROM DUAL;
                      EXCEPTION
                        WHEN OTHERS THEN
                          l_new_erm_id := l_erm_id;
                      END;

                     l_print_condition := 'erm_id = ''' || l_erm_id_lenght || '.' || l_erm_id_lenght || l_new_erm_id || '''';

                     l_command := 'swmsprtrpt -c ' || l_query_seq || ' -P ' || l_prt_q || ' -w rp1re';

                     l_ch_print_reports_bln := TRUE;
                ELSE
                    /*
                    ** Processing a PO.
                    ** Print:
                    */

                    l_print_condition := 'erm_id = ''' || l_erm_id || '''';

                    IF ( l_ch_live_receiving_syspar = 'Y' ) THEN
                        /*
                        ** Live Receiving is active.  Print the worksheet and lumper worksheet if the
                        ** print lumper worksheet syspar is Y.
                        */
                        IF (l_print_lumper_flag = 'Y') THEN
                            l_command := 'swmsprtrpt -c ' || l_query_seq || ' -P ' || l_prt_q || ' -w rp1ro';

                            l_ch_print_reports_bln := TRUE;
                        END IF;
                    ELSIF (l_print_lumper_flag = 'Y') THEN
                        /*
                        ** Run report rp1fl which prints PO worksheet, labels and lumper worksheet
                        */

                        /* CRQ22877:
                        (void) sprintf(command,
                              "swmsprtrpt -c \"erm_id = \'%8.8s\'\" -P %.7s -w rp1fl",
                                erm_id, prt_q); */

                         l_command := 'swmsprtrpt -c ' || l_query_seq || ' -P ' || l_prt_q || ' -w rp1fl';

                         l_ch_print_reports_bln := TRUE;
                    ELSE
                        /*
                        ** Run report rp1rg which prints PO worksheet and labels.
                        */

                        l_command := 'swmsprtrpt -c ' || l_query_seq || ' -P ' || l_prt_q || ' -w rp1rg';

                        l_ch_print_reports_bln := TRUE;

                    END IF;

                END IF;

                IF (l_ch_print_reports_bln = TRUE) THEN
                    IF ( l_ch_live_receiving_syspar = 'Y' AND l_ch_sched_print_PO_syspar = 'N' ) THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Standard Live Receiving is active. Skipping print of labels PO worksheets.', NULL, NULL);
                    ELSE
                        BEGIN
                          INSERT INTO print_query(print_query_seq, condition) 
                            values(l_query_seq, l_print_condition);
                          COMMIT;
                        EXCEPTION
                          WHEN DUP_VAL_ON_INDEX THEN
                            update print_query
                              set condition = l_print_condition
                            where print_query_seq = l_query_seq;
                            COMMIT;
                          WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'Error on print_query insert', sqlcode, sqlerrm);
                            o_out_status := 'FAILURE';
                            EXIT;
                        END;

                        BEGIN
                          pl_text_log.ins_msg_async('INFO', l_func_name, 'Exceuting the Report Print Command [' || l_command || ']', NULL, NULL);
                          l_rc := DBMS_HOST_COMMAND_FUNC(LOWER(REPLACE(USER, 'OPS$', NULL)), l_command);

                          pl_text_log.ins_msg_async('INFO', l_func_name, 'Report Print Command Executed. Return Code - ' || l_rc, NULL, NULL);
                        EXCEPTION
                          WHEN OTHERS THEN
                            o_out_status := 'FAILURE';
                            EXIT;
                        END;
                    END IF;

                END IF;

            END IF;
            o_out_status := l_pallet_status;
         END LOOP;
         COMMIT;

        /*
        ** 12/18/2016 Brian Bent
        ** Print the load worksheet(s) if live receving is active.
        */
        IF (l_ch_live_receiving_syspar = 'Y') THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Live Receiving is active. Print the receiving load worksheets by calling "pl_rcv_print_po.print_load_worksheets_by_hour".', NULL, NULL);

           BEGIN
              --
              -- 12/18/2016 Brian Bent
              -- Live Receiving is active.  Print the load worksheet(s).
              -- This procedure called below without arguments will print the
              -- load worksheets for POs based on the open by hour syspars
              -- which should match up to the "where condition" passed to
              -- this program.
              -- The goal in the near future is do away with this PRO*C
              -- program and do everying in PL/SQL.
              --
              pl_rcv_print_po.print_load_worksheets_by_hour;
           EXCEPTION
              WHEN OTHERS THEN
                 pl_text_log.ins_msg_async('WARN', l_func_name, 'Error in the PL/SQL block calling pl_rcv_print_po.print_load_worksheets_by_hour to print the load worksheet(s).
                  This will not stop processing', sqlcode, sqlerrm);
                 o_out_status := 'FAILURE';
           END;
        END IF;

        COMMIT;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'after final commit.', sqlcode, sqlerrm);
    EXCEPTION
    WHEN OTHERS THEN
      pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception Raised at ' || l_func_name || 'for PO# = ' || l_erm_id , sqlcode, sqlerrm);     
      o_out_status := 'FAILURE';
    END p_open_schedule_po;
    
  /*************************************************************************
  ** p_open_out_storage
  **  Description: To open scheduled POs based on warehouse
  **                 
  **  Called By :  p_open_po_main
  **  Calls :
  **  PARAMETERS :
  **      i_erm_id - From time passed from frontend as input
  **      i_out_storage  - To time passed from frontend as input
  **      o_out_status   - Output parameter returned to front end
  **  RETURN VALUES:
  **      Success or Failure message will be sent
  **
  ****************************************************************/   

    PROCEDURE p_open_out_storage (
        i_erm_id      IN            erm.erm_id%TYPE,
        i_out_storage   IN            VARCHAR2,
        o_out_status    OUT           VARCHAR2
    ) IS
        
        l_func_name     VARCHAR2(50) := 'pl_rcv_po_open.p_open_out_storage';
    BEGIN
      ---OUTSIDE STROAGE Logic Needs to be written based on oracle forms coding.
      --- Story SMOD 1299 created to handle this.
        o_out_status := i_out_storage;
    END p_open_out_storage;
    
 
/*****************************************************************************
**  FUNCTION:
**      is_forkift_active
**
**  DESCRIPTION:
**      This function determines if forklift labor mgmt is active.
**
**  PARAMETERS:
**      none.
**
**  RETURN VALUES:
**      Y  - Forklift labor mgmt is active.
**      N  - Forklift labor mgmt is not active.
**
**
*****************************************************************************/

    FUNCTION f_is_forklift_active RETURN BOOLEAN IS
        l_forklift_active   VARCHAR2(10);
        l_status            BOOLEAN;
        l_func_name         VARCHAR2(50) := 'pl_rcv_po_open.f_is_forklift_active';
    BEGIN
      BEGIN
        IF ( pl_lmf.f_forklift_active ) THEN  /* Calling  pl_lmf.f_forklift_active    */
            l_forklift_active := 'Y';
        ELSE
            l_forklift_active := 'N';
        END IF; /* Calling  pl_lmf.f_forklift_active ends   */
      EXCEPTION
      WHEN OTHERS THEN
         /*
        ** Got an error in the pl/sql block.  Set forklift active to N.
        */
        l_forklift_active := 'N';
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Error calling pl_lmf.f_forklift_active.  Setting forklift_active to N', sqlcode,
        sqlerrm);
       
      END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Setting forklift_active to' || l_forklift_active, NULL, NULL);
        IF ( l_forklift_active = 'Y' ) THEN   /* Calling  l_forklift_active ends   */
             l_status :=  TRUE;
        ELSE
            l_status :=   FALSE;
        END IF;  /* ends  l_forklift_active ends   */

      RETURN l_status;
    EXCEPTION
    WHEN OTHERS THEN
      pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception Raised at ' || l_func_name , sqlcode, sqlerrm);  
      l_status := FALSE;
      RETURN l_status;
    END f_is_forklift_active;
    
  /*****************************************************************************
**  FUNCTION:
**      update_erm_door_no
**
**  DESCRIPTION:
**      This function updates the erm door number to the corresponding
**       forklift labor mgmt door number.
**
**       Only call this function when forklift labor mgmt is on.
**
**  PARAMETERS:
**      i_erm_id  - PO number to update.
**
**  RETURN VALUES:
**      SWMS_NORMAL - Successfully updated door number, door number already
**                    a forklift door number or an ORACLE error occurred.
**                    An ORACLE error does not prevent the PO from being
**                    opened.
**      DO_NOT_OPEN_PO  -  Unable to find the forklift door number for
**                         the PO.  Do not open the PO.
**
*****************************************************************************/    

    FUNCTION f_update_erm_door_no (
        i_erm_id   IN         erm.erm_id%TYPE
    ) RETURN NUMBER IS
        l_func_name               VARCHAR2(50) := 'pl_rcv_po_open.f_update_erm_door_no';
        l_status                  VARCHAR2(1);
        l_update_successful_bln   BOOLEAN;
        l_ret_val                 NUMBER;
    BEGIN
        BEGIN
            pl_lmf.update_erm_door_no(i_erm_id, l_update_successful_bln);
            IF ( l_update_successful_bln = TRUE ) THEN  /*  l_update_successful_bln starts */
                l_status   := 'Y';
            ELSE
                l_status := 'N';
            END IF;   /*  l_update_successful_bln Ends */
        EXCEPTION
            WHEN ROW_LOCKED THEN  
             /*
             ** Procedure pl_lmf.update_erm_door_no unable to update door number
             ** because of record lock.  Do not open the PO.
                */
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Error attempting to update the erm door#.This PO will not be opened.', sqlcode,
                sqlerrm);
                
                l_ret_val := DO_NOT_OPEN_PO; 
            WHEN OTHERS THEN  --- when the package fails
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Error attempting to update the erm door number. Continue process to open the PO.', NULL,
                NULL);
                 l_ret_val :=  SWMS_NORMAL;
               
        END;

        IF l_status = 'Y' THEN   /*  l_success starts */
            l_ret_val := SWMS_NORMAL;
        ELSE
            /*
            ** If this point is reached then the erm door no is null
            ** or there is no corresponding forklift labor mgmt door number.
            ** Do not open the PO.
            */
            l_ret_val := DO_NOT_OPEN_PO;
             pl_text_log.ins_msg_async('INFO', l_func_name, 'Failed to find the corresponding forklift labor mgmt door number in the point_distance table.  PO not opened.
             The door number will have to be entered through the screen then the PO generated.', NULL, NULL);
            
        END IF;   /*  l_status Ends */
        
        IF (l_ret_val = SWMS_NORMAL) THEN
            COMMIT;
        END IF;    
        
        RETURN l_ret_val;
    EXCEPTION
    WHEN OTHERS THEN
      pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception Raised at ' || l_func_name || 'for PO# = ' || i_erm_id, sqlcode, sqlerrm);   
      l_ret_val := DO_NOT_OPEN_PO;
      RETURN l_ret_val;
    END f_update_erm_door_no;
       
 
/*****************************************************************************
**  FUNCTION:
**      update_auto_po_door_no
**
**  DESCRIPTION:
**      This function updates the erm door number to the corresponding
**       forklift labor mgmt door number.
**
**       Only call this function when forklift labor mgmt is on.
**
**  PARAMETERS:
**      i_erm_id  - PO number to update.
**
**  RETURN VALUES:
**      SWMS_NORMAL - Able to retrieve
**      DO_NOT_OPEN_PO  -  Unable the door number for
**                         the PO.  Do not open the PO.
**
*****************************************************************************/  

    FUNCTION f_update_auto_po_door_no (
        i_erm_id   IN         erm.erm_id%TYPE
    ) RETURN NUMBER IS

        l_func_name   VARCHAR2(50) := 'pl_rcv_po_open.f_update_auto_po_door_no';
        l_success     VARCHAR2(1);
        l_door_no     sys_config.config_flag_val%TYPE;
        l_ret_val                 NUMBER;
    BEGIN
        BEGIN
            l_door_no := pl_common.f_get_syspar('AUTO_OPEN_PO_DOOR_NO', 'N');
          /* set value to x if value is null */
            IF l_door_no = 'N' THEN    /*  l_door_no starts */
                l_success := 'N';
            ELSE
                UPDATE erm
                SET
                    door_no = l_door_no
                WHERE
                    erm_id = i_erm_id;
             
                IF SQL%notfound THEN    /*  SQL Start  */
                    l_success := 'N';
                ELSIF SQL%found THEN
                    l_success := 'Y';
                END IF;   /*  SQL Ends  */

            END IF;    /*  l_door_no Ends */
     EXCEPTION
            WHEN OTHERS THEN  --- When the package Fails
                l_success := 'N';
                 raise_application_error(-20000, sqlcode
                                                || '-'
                                                || sqlerrm);
         END;

        IF ( l_success = 'Y' ) THEN
            l_ret_val :=  SWMS_NORMAL;
        ELSE
            l_ret_val :=  DO_NOT_OPEN_PO;
        END IF;
        RETURN l_ret_val;
    EXCEPTION
    WHEN OTHERS THEN
      pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception Raised at ' || l_func_name || 'for PO# = ' || i_erm_id , sqlcode, sqlerrm); 
      l_ret_val := DO_NOT_OPEN_PO;
      RETURN l_ret_val;
    END f_update_auto_po_door_no;

END pl_rcv_po_open;
/

GRANT Execute on pl_rcv_po_open to swms_user;

