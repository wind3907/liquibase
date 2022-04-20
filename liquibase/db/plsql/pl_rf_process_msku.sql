create or replace PACKAGE pl_rf_process_msku AS
    FUNCTION process_msku_main (
        i_rf_log_init_record   IN                     rf_log_init_record,
        i_req_option           IN                     VARCHAR2,
        i_client               IN                     add_lptype_list_result_obj,
        o_server               OUT                    add_lp_list_result_obj
    ) RETURN rf.status;

    FUNCTION buildmskusummarylist (
        i_childlp IN erd_lpn.pallet_id%TYPE
    ) RETURN rf.status;

    FUNCTION cr_subdiv_fl_putaway_batches (
        i_pallet_id IN erd_lpn.pallet_id%TYPE
    ) RETURN rf.status;

END pl_rf_process_msku;
/

create or replace PACKAGE BODY pl_rf_process_msku AS 
   /************************************************************************
   * FUNCTION          : process_msku_main                                 *
   *                                                                       *
   * DESCRIPTION     :  This is the main Function  called for the          *
   *                     process_msku Program.                             *
   *                                                                       * 
   *INPUT Parameters :  i_rf_log_init_record  - Object to get the RF status*
   *                    add_lptype_list_result_obj - Client message        * 
   *                    add_lp_list_result_obj  - server message           * 
   *OUTPUT Parameters:   rf.status - Output value returned by the package  *
   *                                                                       *
   * DATE          USER                COMMENT                             *
   *11/05/2019     KRAJ9028      Created process_msku_main                 *      
   ************************************************************************/
    g_client add_lptype_list_result_obj;
    g_server add_lp_list_result_obj;
    g_result_table add_lp_list_result_table := add_lp_list_result_table();
    MSKU_SUBDIV_MULTIPLIER CONSTANT NUMBER := 5;
    NUM_PALLETS_MSKU CONSTANT NUMBER := 60; 
FUNCTION process_msku_main (
    i_rf_log_init_record   IN                     rf_log_init_record,
    i_req_option           IN                     VARCHAR2,
    i_client               IN                     add_lptype_list_result_obj,
    o_server               OUT                    add_lp_list_result_obj
) RETURN rf.status AS

    l_func_name              VARCHAR2(50) := 'process_msku_main';
    l_rf_status              rf.status := rf.status_normal;
    l_hi_o_error             NUMBER;
    l_hsz_pallet_type        erd_lpn.pallet_type%TYPE;
    l_hsz_pallet_id          erd_lpn.pallet_id%TYPE;
    l_hi_status              NUMBER;
    l_hsz_crt_message        VARCHAR2(4000);
    i_create_batch_status    rf.status := rf.status_normal;
    i_status                 rf.status := rf.status_normal;
    l_hi_count_pallet_ids    NUMBER;
    i                        NUMBER := 0;
    req_opt_list             CONSTANT NUMBER := 2;
    l_count_lp                NUMBER;
    REQ_OPT_SUBDIV           CONSTANT NUMBER := 1;
    l_hsz_sn_no              VARCHAR2(20);
    l_hsz_old_parent_id      erd_lpn.pallet_id%TYPE;
    l_hsz_one_child_pallet   erd_lpn.pallet_id%TYPE;
    l_hsz_parent_pallet_id   erd_lpn.pallet_id%TYPE;
    l_child_type             VARCHAR2(2);
    l_hsz_old_child_pallet   erd_lpn.pallet_id%TYPE;
    lb_status                BOOLEAN;
    o_error                  BOOLEAN;
    o_crt_message            VARCHAR2(4000);
    parent_pallet_arr        pl_msku.t_parent_pallet_id_arr;
    CURSOR cur_child_pallets IS
    SELECT
        pallet_id
    FROM
        erd_lpn
    WHERE
        parent_pallet_id = l_hsz_old_parent_id;

BEGIN
    l_rf_status := rf.initialize(i_rf_log_init_record);
    pl_text_log.ins_msg_async('INFO', l_func_name, 'starting process msku main process', sqlcode, sqlerrm);
IF l_rf_status = rf.status_normal THEN      /* checking the l_rf_status  */
    g_client := i_client;
    l_hi_count_pallet_ids := TO_CHAR(g_client.result_table.count);
    IF ( i_req_option = req_opt_list ) THEN  /* checking the i_req_option parameter */
        l_rf_status := rf.status_normal;
        l_count_lp := buildmskusummarylist(g_client.result_table(1).pallet_id);
        pl_text_log.ins_msg_async('WARN', l_func_name, 'l_count_lp ' || l_count_lp, sqlcode, sqlerrm);
        o_server := g_server;
        IF ( l_count_lp = 0 ) THEN
            l_rf_status := rf.status_data_error;    
        ELSIF ( l_count_lp > (MSKU_SUBDIV_MULTIPLIER * NUM_PALLETS_MSKU ) ) THEN
            l_rf_status := rf.status_msku_subdiv_limit;
            l_count_lp := 0;
            pl_text_log.ins_msg_async('WARN', l_func_name, 'l_count_lp ' || l_count_lp, sqlcode, sqlerrm);
        END IF;
        pl_text_log.ins_msg_async('WARN', l_func_name, 'LP Count: ' || l_count_lp, sqlcode, sqlerrm);
        BEGIN
         rf.complete(l_rf_status);
         RETURN 0;
        EXCEPTION
            WHEN OTHERS THEN
                rf.logexception();  
                RAISE;
        END;    
      END IF;  /* checking the i_req_option parameter ends */

    IF ( i_req_option != REQ_OPT_SUBDIV ) THEN
        BEGIN
         rf.complete(l_rf_status);
         RETURN 1;
        EXCEPTION
            WHEN OTHERS THEN
                rf.logexception();  
                RAISE;
        END;    
    END IF;
           /* sub divide begins */
    pl_text_log.ins_msg_async('INFO', l_func_name, 'g_client.result_table.count: ' || g_client.result_table.count, sqlcode, sqlerrm);
    l_hi_o_error := 0;
    l_hsz_pallet_type := 'LW';
    l_hsz_one_child_pallet := g_client.result_table(1).pallet_id;
    pl_text_log.ins_msg_async('INFO', l_func_name, ' Get parent by passing child -' || l_hsz_one_child_pallet, sqlcode, sqlerrm);
             
             /* get old parent pallet id and sn_no */
            BEGIN
                SELECT
                    sn_no,
                    parent_pallet_id
                INTO
                    l_hsz_sn_no,
                    l_hsz_old_parent_id
                FROM
                    erd_lpn
                WHERE
                    pallet_id = l_hsz_one_child_pallet;

            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' Sub-divide validations failed for pallet_id: -' || l_hsz_pallet_id, sqlcode
                    , sqlerrm);
                    l_rf_status := rf.status_cannot_divide_msku;
            END;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'Got Parent: = ' || l_hsz_old_parent_id, sqlcode, sqlerrm);
            l_hsz_pallet_id := g_client.result_table(1).pallet_id;
            pl_text_log.ins_msg_async('INFO', l_func_name, ' Calling p_sub_div, pallet_id = '
                                                 || l_hsz_pallet_id
                                                 || ', pallet_type = '
                                                 || l_hsz_pallet_type, sqlcode, sqlerrm);
             
         /* Call the sub_divide PL/SQL code passing the first pallet id from input array and a null parent pallet id 
            as IN OUT parameter. New parent pallet id will be generated for the sub-divided pallet ids.*/

            l_child_type := g_client.result_table(1).type; /* process the first scanned lp */
            BEGIN
                pl_text_log.ins_msg_async('INFO', l_func_name, ' process_msku_main pl_msku.p_sub_divide_msku_pallet before While loop', sqlcode, sqlerrm);
                pl_msku.p_sub_divide_msku_pallet(l_hsz_pallet_id, l_hsz_parent_pallet_id, l_hsz_pallet_type, l_child_type, l_hi_status
                );
                pl_text_log.ins_msg_async('WARN', l_func_name, 'pl_msku.p_sub_divide_msku_pallet new parent pallet_id: ' || l_hsz_parent_pallet_id, sqlcode, sqlerrm);
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' pl_msku.p_sub_divide_msku_pallet Failed', sqlcode, sqlerrm);
            END;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'Returned from p_sub_div,got parent = '
                                                 || l_hsz_parent_pallet_id
                                                 || ', status = '
                                                 || l_hi_status, sqlcode, sqlerrm);
/* Need to start looping here and look at each LP and its type */
/* If type is 'L', do the same as before and divide it by this LP */
/* If type is 'I', write new PL to divide it by this item */           
/* Use new_child_type[i] = 'L' or  'I' to check */
          /* Call sub-divide procedure for the rest of the pallet ids in the
             input array of child pallet ids */

            pl_text_log.ins_msg_async('INFO', l_func_name, 'Calling p_sub_div loop, hi_count_pallet_ids: = '
                                                 || l_hi_count_pallet_ids
                                                 || ', status =  '
                                                 || l_hi_status, sqlcode, sqlerrm);

            i := 1;
            WHILE ( i < l_hi_count_pallet_ids AND l_hi_status = 0 ) LOOP
                l_hsz_pallet_id := g_client.result_table(i).pallet_id;
                l_child_type := g_client.result_table(i).type;
                i := i + 1;
                BEGIN
                 pl_text_log.ins_msg_async('INFO', l_func_name, ' calling  pl_msku.p_sub_divide_msku_pallet in While loop', sqlcode, sqlerrm);
                    pl_msku.p_sub_divide_msku_pallet(l_hsz_pallet_id, l_hsz_parent_pallet_id, l_hsz_pallet_type, l_child_type, l_hi_status
                    );
                    pl_text_log.ins_msg_async('WARN', l_func_name, '  l_hi_status' || l_hi_status, sqlcode, sqlerrm);
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, '  pl_msku.p_sub_divide_msku_pallet Failed', sqlcode, sqlerrm);
                END;

                pl_text_log.ins_msg_async('INFO', l_func_name, 'Returned from p_sub_div pallet = '
                                                     || l_hsz_pallet_id
                                                     || ', status =  '
                                                     || l_hi_status, sqlcode, sqlerrm);

            END LOOP;

            IF ( l_hi_status = 0 ) THEN  /* checking the l_hi_status before cursor value */
                OPEN cur_child_pallets;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'cur_child_pallets cursor opened, l_hi_status: ' || l_hi_status, sqlcode, sqlerrm);
             /* call update_msku for the child pallets 
                selected from the cursor declared above */
                LOOP
                    FETCH cur_child_pallets INTO l_hsz_old_child_pallet;
                    EXIT WHEN cur_child_pallets%NOTFOUND;
                    BEGIN
                    
                        lb_status := pl_msku.f_update_msku_info_by_lp(l_hsz_sn_no, l_hsz_old_parent_id, l_hsz_old_child_pallet, l_hsz_pallet_type
                        , 'N');
                        IF lb_status = true THEN
                            l_hi_status := 0;
                        ELSE
                            l_hi_status := 1;
                        END IF;
                    EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'failed pl_msku.f_update_msku_info_by_lp', sqlcode, sqlerrm);
                        l_rf_status := rf.status_not_found;
                        EXIT;
                    END;

                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Returned from p_update_msku, l_hi_status: ' || l_hi_status, sqlcode, sqlerrm);
                    IF ( l_hi_status = 1 ) THEN   /* checking the l_hi_status value */
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'update_msku_info failed,parent_pallet_id', sqlcode, sqlerrm);
                        l_rf_status := rf.status_not_found;
                        EXIT;
                   END IF;  /* checking the l_hi_status value  ends*/

                END LOOP;

                CLOSE cur_child_pallets;
                IF ( l_hi_status = 0 ) THEN   /* checking the l_hi_status value */
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'call assign_msku: sn_no ' || l_hsz_sn_no, sqlcode, sqlerrm);
                    parent_pallet_arr(1) := l_hsz_old_parent_id;
                    parent_pallet_arr(2) := l_hsz_parent_pallet_id;
                    pl_msku.p_assign_msku_putaway_slots(l_hsz_sn_no, parent_pallet_arr, o_error, o_crt_message);
                    IF o_error THEN   /* checking the o_error value  */
                        l_hi_o_error := 1;
                        l_hsz_crt_message := o_crt_message;
                    ELSE
                        l_hi_o_error := 0;
                    END IF;   /* checking the o_error value ends */

                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Returned from p_assign_msku ' || l_hsz_sn_no, sqlcode, sqlerrm);
                    IF ( l_hi_o_error = 1 ) THEN   /* checking the l_hi_o_error value  */
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Call to p_assign_msku_putaway_slots failed.'|| l_hsz_sn_no, sqlcode , sqlerrm);
                        l_rf_status := rf.status_not_found;  
                    ELSE
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'add parent_pallet_id to the server ' || l_hsz_sn_no, sqlcode, sqlerrm);
                        l_rf_status := rf.status_normal;
                    END IF; /* checking the l_hi_o_error value ends */

                END IF;   /* checking the l_hi_status value ends */

            END IF;  /* checking the l_hi_status before cursor value ends*/

        ELSE
            l_rf_status := rf.status_cannot_divide_msku;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Sub-divide validations failed for pallet_id = ' || l_hsz_pallet_id, sqlcode, sqlerrm
            );
        END IF; /* checking the l_rf_status  */

        IF l_rf_status = rf.status_normal THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, ' Commit before quit', sqlcode, sqlerrm);
            COMMIT;
            i_create_batch_status := cr_subdiv_fl_putaway_batches(l_hsz_one_child_pallet);
            COMMIT WORK;
        ELSE
            pl_text_log.ins_msg_async('INFO', l_func_name, ' Status bad...Rollback before quit', sqlcode, sqlerrm);
            ROLLBACK;
        END IF;
    
        rf.complete(l_rf_status);
        RETURN l_rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            rf.logexception();  -- log it
            RAISE;
    END process_msku_main;

/*****************************************************************************
**  FUNCTION:
**      buildmskusummarylist
**
**  DESCRIPTION:
**      This function builds the msku summary list
**
**  PAREMETERS:
**      i_childlp -  pallet_id 
**  
**  RETURN VALUES:
**      l_count_lp  retuns the count
**
*****************************************************************************/

    FUNCTION buildmskusummarylist (
        i_childlp IN erd_lpn.pallet_id%TYPE
    ) RETURN rf.status AS

        l_func_name              VARCHAR2(50) := 'buildmskusummarylist';
        l_rf_status              rf.status := rf.status_normal;
        l_prod_id                erd_lpn.prod_id%TYPE;
        l_pallet_id              erd_lpn.pallet_id%TYPE;
        l_cpv                    erd_lpn.cust_pref_vendor%TYPE;
        l_hostchildlp            erd_lpn.pallet_id%TYPE;
        l_lsz_old_parent_id      erd_lpn.pallet_id%TYPE;
        l_hsz_old_parent_id      erd_lpn.pallet_id%TYPE;
        lsz_old_parent_id        erd_lpn.pallet_id%TYPE;
        l_count_lp                NUMBER;
        l_result_table add_lp_list_result_table:=add_lp_list_result_table();
        CURSOR c_summarylp IS
        SELECT
            prod_id,
            pallet_id,
            cust_pref_vendor
        FROM
            erd_lpn
        WHERE
            parent_pallet_id = l_hsz_old_parent_id
        ORDER BY
            prod_id,
            pallet_id;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'starting buildmskusummarylist ', sqlcode, sqlerrm);
        l_hostchildlp := i_childlp;
		  /* get old parent pallet id and sn_no */
        BEGIN
            SELECT
                parent_pallet_id
            INTO l_hsz_old_parent_id
            FROM
                erd_lpn
            WHERE
                pallet_id = l_hostchildlp;

            lsz_old_parent_id := l_hsz_old_parent_id;
        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'buildmskusummarylist When No Data Found ', sqlcode, sqlerrm);
                lsz_old_parent_id := i_childlp;
            WHEN OTHERS THEN
                l_count_lp := 0;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'buildmskusummarylist When Others ', sqlcode, sqlerrm);
                RETURN l_count_lp;
        END;
    
    BEGIN
    l_count_lp:=0;
       FOR erd_lpn_rec in c_summarylp
        LOOP
            l_count_lp:=l_count_lp+1;
            l_prod_id := erd_lpn_rec.prod_id;
            l_pallet_id := erd_lpn_rec.pallet_id;
            l_cpv := erd_lpn_rec.cust_pref_vendor;   
            IF c_summarylp%notfound THEN
		    RETURN l_count_lp;
            END IF;
        IF ( l_count_lp >= MSKU_SUBDIV_MULTIPLIER * NUM_PALLETS_MSKU ) THEN
         pl_text_log.ins_msg_async('INFO', l_func_name, 'Count LP = '
                                                    || l_count_lp
                                                    || 'M*N = '
                                                    || MSKU_SUBDIV_MULTIPLIER * NUM_PALLETS_MSKU, sqlcode, sqlerrm);
         RETURN l_count_lp;
            END IF;
            l_result_table.extend;
             l_result_table(l_result_table.count):=add_lp_list_obj1(l_prod_id,l_pallet_id,l_cpv);
            g_result_table:=l_result_table;
           g_server:=add_lp_list_result_obj(g_result_table);
     END LOOP;
      RETURN l_count_lp;
	    EXCEPTION
        WHEN NO_DATA_FOUND THEN
         pl_text_log.ins_msg_async('INFO', l_func_name, 'No record for'||l_hsz_old_parent_id, sqlcode, sqlerrm);
        return l_count_lp;        
                WHEN OTHERS THEN
                    l_rf_status := rf.status_data_error;
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Cannot read from ERD_LPN using parent LP= '||l_hsz_old_parent_id, sqlcode, sqlerrm);
                    l_count_lp := 0;
                    RETURN l_count_lp;
            END;
     pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending buildmskusummarylist ', sqlcode, sqlerrm);
    END buildmskusummarylist;

/*****************************************************************************
**  FUNCTION:
**      cr_subdiv_fl_putaway_batches
**
**  DESCRIPTION:
**      This function re-creates the forklift putaway batch for a 
**      sub-divided MSKU.  The batches are re-created for the entire
**      SN which means there will most likely be batches already existing.
**      This will not cause any issues.
**
**  PAREMETERS:
**      i_pallet_id - Pallet id of one of the child LP's on either the
**                    original MSKU or the sub-divided MSKU.
**                    It does not matter which one it is.
**
**  RETURN VALUES:
**      -1 if anything fails otherwise ORACLE_NORMAL.
**
**  Modification History:
**     DATE      DESIGNER  COMMENTS
**     --------  --------  --------------------------------------------------
**
**                         In the near future this needs to be changed to
**                         not try and re-create the batches for the
**                         entire SN.  What can be done is make
**                         pl_lmf.create_msku_putaway_batches a global
**                         procedure (right now it is private to the package)
**                         and call it.
*****************************************************************************/

    FUNCTION cr_subdiv_fl_putaway_batches (
        i_pallet_id IN erd_lpn.pallet_id%TYPE
    ) RETURN rf.status AS

        l_func_name                VARCHAR2(50) := 'cr_subdiv_fl_putaway_batches';
        l_ret_val                   NUMBER := 0;
        l_no_records_processed     NUMBER := 0;
        l_no_batches_created       NUMBER := 0;
        l_no_batches_existing      NUMBER := 0;
        l_no_batches_not_created   NUMBER := 0;
        l_pallet_id                erd_lpn.pallet_id%TYPE;
        l_erm_id                   erm.erm_id%TYPE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'starting cr_subdiv_fl_putaway_batches ', sqlcode, sqlerrm);
        l_pallet_id := i_pallet_id;
  
        SELECT
            rec_id
        INTO l_erm_id
        FROM
            putawaylst
        WHERE
            pallet_id = l_pallet_id;
   IF ( SQL%found ) THEN
             -- Log a message to track progress.
    pl_text_log.ins_msg_async('INFO', l_func_name, 'Re-creating batches for sub-divided MSKU, ERM ID=['
    || l_erm_id || '], child pallet used to get the erm id=[' || l_pallet_id || '] ', sqlcode, sqlerrm);
    BEGIN
        pl_lmf.create_putaway_batches_for_po(l_erm_id, l_no_records_processed, l_no_batches_created, l_no_batches_existing, l_no_batches_not_created
        );
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Re-created batches for sub-divided MSKU.Batches area created for the entire SN', sqlcode, sqlerrm);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'l_erm_id = '
                                            || l_erm_id
                                            || '  #records processed = '
                                            || l_no_records_processed
                                            || '  #batches created = '
                                            || l_no_batches_created, sqlcode, sqlerrm);

        pl_text_log.ins_msg_async('INFO', l_func_name, ' #batches already existing = '
                                            || l_no_batches_existing
                                            || '  #batches not created = '
                                            || l_no_batches_not_created, sqlcode, sqlerrm);

    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to create forklift labor mgmt putaway batches for sub-divided MSKU. Error in PL/SQL block', sqlcode, sqlerrm);
            l_ret_val := -1;
    END;

    ELSE
          -- Did not find the pallet in the putawaylst table.
           -- Log a message and continue processing.  This will not be a
           -- fatal error at this time.  We will see how this works out.
        pl_text_log.ins_msg_async('WARN', l_func_name, 'Did not found the pallet : ' || l_pallet_id , sqlcode, sqlerrm);
    END IF;

    return l_ret_val;
END cr_subdiv_fl_putaway_batches;

END pl_rf_process_msku;
/

GRANT EXECUTE ON pl_rf_process_msku TO swms_user;