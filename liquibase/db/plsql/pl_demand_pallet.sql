create or replace PACKAGE pl_demand_pallet IS 
/*******************************************************************************
**Package:
**        pl_demand_pallet. Migrated the argc <= 6 logic from TP_pallet_main.pc
**        Migrated the logic of reprocess functionality from pallet_label2.pc
**
**  Description: To reprocess the SN/PO with Damages. The default  value will be
**               REG.              
**                                                                       
**Called by: 
**        This function will be called from demand_pallet.fmb
**        
*******************************************************************************/

    procedure reprocess_main (
        i_rec_id    IN          putawaylst.rec_id%TYPE,
        i_prod_id   IN          pm.prod_id%TYPE,
        i_qty_rec   IN          putawaylst.qty_received%TYPE,
        i_cpv       IN          pm.cust_pref_vendor%TYPE,
        i_uom       IN          putawaylst.uom%TYPE,
        i_queue     IN          print_queues.user_queue%TYPE,
        o_status    OUT         NUMBER
    );

    PROCEDURE reprocess (
        i_rec_id          IN                putawaylst.rec_id%TYPE,
        i_prod_id         IN                pm.prod_id%TYPE,
        i_qty_rec         IN                putawaylst.qty_received%TYPE,
        i_cpv             IN                pm.cust_pref_vendor%TYPE,
        i_uom             IN                putawaylst.uom%TYPE,
        i_ca_dmg_status   IN                VARCHAR2,
        i_prt_flag        IN                VARCHAR2,
        i_queue           IN                print_queues.user_queue%TYPE,
        o_status          OUT               NUMBER
    );

    FUNCTION find_damage_zone_location (
        i_uom           IN              putawaylst.uom%TYPE,
        i_prod_id       IN              pm.prod_id%TYPE,
        i_cpv           IN              pm.cust_pref_vendor%TYPE,
        i_pallet_type   IN              pm.pallet_type%TYPE
    ) RETURN BOOLEAN;



END pl_demand_pallet;
/

create or replace PACKAGE BODY pl_demand_pallet IS

/******************************************************************************
* TYPE             : PROCEDURE                                                *
* NAME             : reprocess_main                                           *
* DESCRIPTION      : To handle the argc => 6 logic in TP_pallet_main.pc file  *
**                   to call reprocess functionality                          * 
* INPUT PARAMETERS :  i_rec_id                                                *
*                     i_prod_id                                               *
*                     i_qty_rec                                               *
*                     i_cpv                                                   *
*                     i_uom                                                   *
*                     i_queue                                                 *
*  Return Values   :  o_status                                                *
*                                                                             *
* Author       Date        Ver   Description                                  *
* ------------ ----------  ----  -----------------------------------------    *
* KRAJ9028    03/30/2020   1.0    Initial Version                             *
******************************************************************************/
    
    ADD_RESERVE       CONSTANT NUMBER := 0;
    RET_VAL           CONSTANT NUMBER := 0;
 
 PROCEDURE reprocess_main (
        i_rec_id    IN          putawaylst.rec_id%TYPE,
        i_prod_id   IN          pm.prod_id%TYPE,
        i_qty_rec   IN          putawaylst.qty_received%TYPE,
        i_cpv       IN          pm.cust_pref_vendor%TYPE,
        i_uom       IN          putawaylst.uom%TYPE,
        i_queue     IN          print_queues.user_queue%TYPE,
        o_status    OUT         NUMBER
    ) IS

        l_func_name       VARCHAR2(50) := 'pl_demand_pallet.reprocess_main';
        l_is_fg_po        VARCHAR2(1);
        l_prt_flag        VARCHAR2(1) := 'Y';
        l_ca_dmg_status   VARCHAR2(4) := 'REG';
        l_queue_spec      BOOLEAN := true;
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Starting reprocess_main with rec id = '
                                            || i_rec_id
                                            || ' Prod id = '
                                            || i_prod_id
                                            || ' Qty Received = '
                                            || i_qty_rec
                                            || ' CPV = '
                                            || i_cpv
                                            || ' UOM = '
                                            || i_uom
                                            || ' Queue = '
                                            || i_queue, sqlcode, sqlerrm);

        BEGIN
          
            IF pl_common.f_is_internal_production_po(i_rec_id) = TRUE THEN
                l_is_fg_po := 'Y';
            ELSE
                l_is_fg_po := 'N';
            END IF;

            pl_text_log.ins_msg_async('INFO', l_func_name, ' l_is_fg_po value = ' || l_is_fg_po, sqlcode, sqlerrm);
            IF l_is_fg_po = 'N' THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Calling reprocess functionality', sqlcode, sqlerrm);
               reprocess(i_rec_id, i_prod_id, i_qty_rec, i_cpv, i_uom, l_ca_dmg_status, l_prt_flag, i_queue, o_status);
            ELSE
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Calling pl_rcv_open_po_find_slot.p_add_fg_demand_lp', sqlcode, sqlerrm);
                BEGIN
                    pl_rcv_open_po_find_slot.p_add_fg_demand_lp(i_rec_id, i_prod_id, i_cpv, i_qty_rec, i_uom, l_ca_dmg_status);
                    o_status := 0;   /* Sucessfully returned from package pl_rcv_open_po_find_slot.p_add_fg_demand_lp */
                EXCEPTION
                WHEN OTHERS THEN
                  pl_text_log.ins_msg_async('INFO', l_func_name, 'Exception at pl_rcv_open_po_find_slot.p_add_fg_demand_lp ', sqlcode, sqlerrm); 
                  o_status := sqlcode;  /* returning sqlcode when the package throws exception */
                END;
            END IF;
       END;
         pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending of  reprocess_main', sqlcode, sqlerrm);
END reprocess_main;

/******************************************************************************
* TYPE             : PROCEDURE                                                *
* NAME             : reprocess                                                *
* DESCRIPTION      : To handle the reprocess functionality from               *
**                   pallet_label2.pc                                         * 
* INPUT PARAMETERS :  i_rec_id                                                *
*                     i_prod_id                                               *
*                     i_qty_rec                                               *
*                     i_cpv                                                   *
*                     i_uom                                                   *
*                     i_queue                                                 *
*  Return Values   :  o_status                                                *
*                                                                             *
* Author       Date        Ver   Description                                  *
* ------------ ----------  ----  -----------------------------------------    *
* KRAJ9028    03/23/2020   1.0    Initial Version                             *
******************************************************************************/

   PROCEDURE reprocess (
        i_rec_id          IN                putawaylst.rec_id%TYPE,
        i_prod_id         IN                pm.prod_id%TYPE,
        i_qty_rec         IN                putawaylst.qty_received%TYPE,
        i_cpv             IN                pm.cust_pref_vendor%TYPE,
        i_uom             IN                putawaylst.uom%TYPE,
        i_ca_dmg_status   IN                VARCHAR2,
        i_prt_flag        IN                VARCHAR2,
        i_queue           IN                print_queues.user_queue%TYPE,
        o_status          OUT               NUMBER
    ) IS

        l_partial_pallet          BOOLEAN := true;
        l_func_name               VARCHAR2(50) := 'pl_demand_pallet.reprocess';
        l_ca_dest_loc             loc.logi_loc%TYPE := ' ';
        l_dontprint_flag          VARCHAR2(1);
        l_ca_dmg_status           VARCHAR2(4);
        l_putaway_dimension       sys_config.config_flag_val%TYPE;
        l_reprocess_flag          BOOLEAN := false;
        l_putaway_flag            BOOLEAN := true;
        l_i_putaway_flag          NUMBER := 0;
        l_qty_received            putawaylst.qty_received%TYPE;
        o_pallet_id               pl_putaway_utilities.t_pallet_id;
        o_msg                     VARCHAR2(500);
        l_erm_type                erm.erm_type%TYPE;
        l_i_total_pallets         NUMBER;
        i_count                   NUMBER := 1;
        l_status                  NUMBER;
        l_allow_flag              sys_config.config_flag_val%TYPE;
        l_pallet_flag             sys_config.config_flag_val%TYPE;
        l_res_loc                 sys_config.config_flag_val%TYPE;
        l_clam_bed_tracked_flag   VARCHAR2(1);
        l_mix_deep_slot           sys_config.config_flag_val%TYPE;
        l_aging_days              NUMBER;
        l_each_pallet_qty         putawaylst.qty_received%TYPE;
        l_loc_key                 sys_config.config_flag_val%TYPE;
        l_dummy                   VARCHAR2(1) := 'Z';
        l_done                    BOOLEAN := true;
        l_find_done               NUMBER;
        l_catch_wt                putawaylst.catch_wt%TYPE;
        l_pallet_type             pm.pallet_type%TYPE;
        l_current_pallet          NUMBER;
        l_num_pallet              NUMBER;
        l_case_cube               NUMBER;
        l_skid_cube               NUMBER;
        l_spc                     NUMBER(5);
        l_ti                      NUMBER(5);
        l_hi                      NUMBER(5);
        l_last_pallet_qty         NUMBER;
        l_lst_pallet_cube         NUMBER;
        l_std_pallet_cube         NUMBER;
        l_print_query_seq         NUMBER;
        l_opco                    api_config.api_val%TYPE;
        l_lang                    sys_config.config_flag_val%TYPE;
        o_no_records_processed    NUMBER;
        o_no_batches_created      NUMBER;
        o_no_batches_existing     NUMBER;
        o_no_batches_not_created  NUMBER;
        l_print_command           VARCHAR2(200);
        v_result                  VARCHAR2 (1000);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Starting reprocess with rec id = '
                                            || i_rec_id
                                            || ' Prod id = '
                                            || i_prod_id
                                            || ' Qty Received = '
                                            || i_qty_rec
                                            || ' CPV = '
                                            || i_cpv
                                            || ' UOM = '
                                            || i_uom
                                            || ' CA Status = '
                                            || i_ca_dmg_status
                                            || ' Print Flag = '
                                            || i_prt_flag 
                                            || ' Queue = ' 
                                            || i_queue, sqlcode, sqlerrm);

        IF ( i_prt_flag = 'N' ) THEN
            l_dontprint_flag := 'N';
        ELSE
            l_dontprint_flag := 'Y';
        END IF;

        IF i_ca_dmg_status = 'DMG' THEN
            l_ca_dmg_status := i_ca_dmg_status;
        ELSE
            l_ca_dmg_status := 'REG';
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Print flag = '
                                            || l_dontprint_flag
                                            || ' CA Status = '
                                            || l_ca_dmg_status, sqlcode, sqlerrm);

        l_reprocess_flag := true;
        l_putaway_dimension := pl_common.f_get_syspar('PUTAWAY_DIMENSION', 'N');
        IF l_putaway_dimension = 'N' THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to retrieve value for PUTAWAY_DIMENSION', sqlcode, sqlerrm);
            o_status := -1;   /* Unsucessfull so returning -1 as output */
            RETURN;
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Value for PUTAWAY_DIMENSION = ' || l_putaway_dimension, sqlcode, sqlerrm);
        BEGIN
            SELECT
                erm_type
            INTO l_erm_type
            FROM
                erm
            WHERE
                erm_id = i_rec_id;
      EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get erm_type for erm id = ' || i_rec_id, sqlcode, sqlerrm);
                o_status := -1;   /* Unsucessfull so returning -1 as output */
                RETURN;
        END;
     
       /**
       ** To Retrive the pallet_type from retrieve_label_content
       ** executing the select statement directly
       **  l_pallet_type will be used later in this progem
       **  While calling find_damage_zone_location function
       */

        BEGIN
            SELECT
                pallet_type
            INTO l_pallet_type
            FROM
                pm
            WHERE
                prod_id = i_prod_id
                AND cust_pref_vendor = i_cpv;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to select pallet type for prod id = '
                                                    || i_prod_id
                                                    || ' CPV = '
                                                    || i_cpv, sqlcode, sqlerrm);
                ROLLBACK;
                RETURN;
        END;

        IF l_putaway_dimension = 'I' THEN /* l_putaway_dimension = 'I'  starts here*/
            BEGIN
                SELECT
                    i_qty_rec * spc
                INTO l_qty_received
                FROM
                    pm
                WHERE
                    prod_id = i_prod_id
                    AND cust_pref_vendor = i_cpv;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to calculate Qty Received for prod id = '
                                                        || i_prod_id
                                                        || ' and CPV = '
                                                        || i_cpv, sqlcode, sqlerrm);
            END;

            BEGIN
               pl_text_log.ins_msg_async('Info', l_func_name, 'calling p_reprocess erm id = ' || i_rec_id, sqlcode, sqlerrm);      
               pl_pallet_label2.p_reprocess(i_rec_id, i_prod_id, i_cpv, i_uom, l_ca_dmg_status, l_putaway_flag, l_qty_received,
               o_pallet_id, o_msg);
                
                IF l_putaway_flag = false THEN
                    l_i_putaway_flag := 0;   /* Denotes success of putaway. */
                    l_i_total_pallets := o_pallet_id.last;
                ELSE
                    l_i_putaway_flag := 1;
                END IF;

                pl_text_log.ins_msg_async('INFO', l_func_name, 'l_i_putaway_flag = '
                                                    || l_i_putaway_flag
                                                    || ' l_i_total_pallets = '
                                                    || l_i_total_pallets, sqlcode, sqlerrm);
            EXCEPTION
                WHEN OTHERS THEN
                    l_i_putaway_flag := 1;
                    o_msg := sqlcode || sqlerrm;
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' Package procedure pl_pallet_label2.p_reprocess had an error ',
                    sqlcode, sqlerrm);
            END;
   
        IF l_i_putaway_flag = 1 THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Reprocess stored proc cal = '
                                                || o_msg
                                                || ' num_pallets = '
                                                || l_i_total_pallets
                                                || ' l_i_putaway_flag = '
                                                || l_i_putaway_flag, sqlcode, sqlerrm);
            o_status := -1;   /* Unsucessfull so returning -1 as output */
            RETURN;
        END IF;
        
        /*
        ** Setting the language id  for report  
        */
     BEGIN 
           l_lang := pl_common.f_get_syspar('LANGUAGE_ENABLE','3');
       EXCEPTION
       WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get SYSPAR value for ,Setting it 3- English', sqlcode, sqlerrm);
            l_lang := 3;
       END;
       
 
        IF l_dontprint_flag = 'Y' THEN     /* l_dontprint_flag = 'Y' started */
        
          /* From the array of pallet_id returned,call the system program to print
          ** license plates
          */
          pl_text_log.ins_msg_async('INFO', l_func_name, 'i_count = ' || i_count || ' l_i_total_pallets = ' || l_i_total_pallets || 
          ' o_pallet_id(i_count) = ' || o_pallet_id(i_count), sqlcode, sqlerrm);
          
          WHILE (i_count <=  l_i_total_pallets AND o_pallet_id(i_count) IS NOT NULL ) 
          LOOP
          
         /*
         ** Cannot send Null as a parameter for l_print_query_seq in the pl_api.display_rpt
         ** to execute a report, inserting the pallet id condition into
         ** print_query table.
         */
         
            BEGIN
                SELECT print_query_seq.nextval INTO l_print_query_seq FROM DUAL;  
                pl_text_log.ins_msg_async('INFO', l_func_name, ' Print query seq = ' || l_print_query_seq, sqlcode, sqlerrm);

                INSERT INTO PRINT_QUERY (print_query_seq, condition)
                    VALUES(l_print_query_seq, 'pallet_id = ''' || o_pallet_id(i_count) || '''');
            EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN
                    UPDATE PRINT_QUERY
                        set condition = 'pallet_id = ''' || o_pallet_id(i_count) || ''''
                    where print_query_seq = l_print_query_seq;
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('ERROR', l_func_name, 'Unable to Insert Data into PRINT_QUERY table ', sqlcode, sqlerrm);
                    o_status := -1;   /* Unsucessfull so returning -1 as output */
                    RETURN;
            END ;
            
            /*
            ** Get the OPCO detal to pass it to pl_api.display_rpt  
            */
            -- BEGIN
            --     SELECT api_val INTO l_opco
            --         FROM api_config 
            --     WHERE api_name = 'SCHEMA';
            -- EXCEPTION
            -- WHEN OTHERS THEN
            --     pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to OPCO details from api_config table ', sqlcode, sqlerrm);
            -- END;
            
              /* 
              ** Calling the report rp1rk with pallet_id only one
              ** i_queue will be passed from Demand_pallet.fmb for both scenarios of QUEUE_SPECIFIED
              **  So the report will be called once and printed at different printer 
              ** based i_queue i.e it can be a default printer or other than that
              ** "swmsprtrpt -c \"pallet_id = \'%s\'\" -P %s rp1rk"
              */
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Values for report Print query seq = ' || l_print_query_seq || ' and OPCO = ' ||
            l_opco || ' and Language = ' || l_lang ||' for report rp1rk with queue = ' || i_queue, sqlcode, sqlerrm);
            -- pl_api.display_rpt(l_print_query_seq,l_opco,'PDF',l_lang,user,'rp1rk','rp1rk', i_queue);

            l_print_command := 'swmsprtrpt -c ' || l_print_query_seq || ' -P ' || i_queue || ' -w rp1rk';

            BEGIN
                v_result:= DBMS_HOST_COMMAND_FUNC(LOWER(REPLACE(USER, 'OPS$', NULL)), l_print_command);
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'ERROR : Cannot open rec id  = ' || i_rec_id, sqlcode, sqlerrm);
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to print license plate for pallet_id  = ' || o_pallet_id(i_count),
                    sqlcode, sqlerrm);
                    o_status := -1;   /* Unsucessfull so returning -1 as output */
                    RETURN;
            END;
            i_count := i_count + 1;
            END LOOP;

            COMMIT;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Successful in commiting after printing license plates  for rec id = ' ||
            i_rec_id, sqlcode, sqlerrm);
         END IF;  /* l_dontprint_flag = 'Y' ends */
      ELSE    /*if (putaway_dimension == 'I') ENDS*/
          /*
          ** Retrieve the home putaway, pallet type and extended case cube flags
          ** from syspar table
          */
           pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside ELSE of if (putaway_dimension == I)', sqlcode, sqlerrm);
            BEGIN
                l_allow_flag := pl_common.f_get_syspar('HOME_PUTAWAY', 'N');
            EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get HOME_PUTAWAY syspar flag ', sqlcode, sqlerrm);
                ROLLBACK;
                o_status := -1;   /* Unsucessfull so returning -1 as output */
                RETURN;
            END;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'Syspar HOME_PUTAWAY value = ' || l_allow_flag, sqlcode, sqlerrm);
            BEGIN
                l_pallet_flag := pl_common.f_get_syspar('PALLET_TYPE_FLAG', 'N');
            EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get PALLET_TYPE_FLAG syspar flag ', sqlcode, sqlerrm);
                ROLLBACK;
                o_status := -1;   /* Unsucessfull so returning -1 as output */
                RETURN;
            END;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Syspar PALLET_TYPE_FLAG value = ' || l_pallet_flag, sqlcode, sqlerrm);
            
            BEGIN
                l_res_loc := pl_common.f_get_syspar('RES_LOC_CO', 'N');
            EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get RES_LOC_CO syspar flag, Setting it as N', sqlcode, sqlerrm);
                l_res_loc := 'N';
            END;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'Syspar RES_LOC_CO value = ' || l_res_loc, sqlcode, sqlerrm); 
          /*
          ** Select syspar MIX_SAME_PROD_DEEP_SLOT. 
          ** Get_mix_same_prod_syspar function logic from pallet_label2.pc is implemented here
          */
            BEGIN
                l_mix_deep_slot := pl_common.f_get_syspar('MIX_SAME_PROD_DEEP_SLOT', 'Y');
            EXCEPTION
            WHEN OTHERS THEN
             /* Unable to select the syspar.  Output aplog message and use "Y" as the value. */
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to select syspar MIX_SAME_PROD_DEEP_SLOT. Will use \"Y\" for the value',
                sqlcode, sqlerrm);
                l_mix_deep_slot := 'Y';
             END;
             pl_text_log.ins_msg_async('INFO', l_func_name, 'Syspar MIX_SAME_PROD_DEEP_SLOT value = ' || l_mix_deep_slot, sqlcode, sqlerrm); 
     
          /*
          ** Added clam_bed tracking info
          */
            l_clam_bed_tracked_flag := 'N';
            BEGIN
                l_clam_bed_tracked_flag := pl_common.f_get_syspar('CLAM_BED_TRACKED', 'N');
            EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get CLAM_BED_TRACKED syspar flag ', sqlcode, sqlerrm);
                l_res_loc := 'N';
                ROLLBACK;
                o_status := -1;   /* Unsucessfull so returning -1 as output */
                RETURN;
            END;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Syspar CLAM_BED_TRACKED value = ' || l_clam_bed_tracked_flag, sqlcode, sqlerrm);
              
            BEGIN
               /* 
               ** Reprocessing logic is moved to pl_one_pallet_label.p_reprocess_po SMOD-2496
               */
                pl_one_pallet_label.p_reprocess_po(i_uom, i_ca_dmg_status, l_pallet_flag, i_rec_id, i_prod_id, i_cpv,
                i_qty_rec, l_pallet_type, l_putaway_dimension);
            EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception at pl_reprocess_po.p_reprocess_po', sqlcode, sqlerrm);
            END;
     pl_text_log.ins_msg_async('WARN', l_func_name, 'Reprocessing Ends', sqlcode, sqlerrm);
    END IF;
             /*
            ** If forklift LM is active create forklift LM batches for the
            ** demand license plates created.
            */
   
           /*
           ** Create_demand_lp_batches(po) function is in pallet_label2.pc 
           ** This function calles another function create_forklift_putaway_batches
           ** create_forklift_putaway_batches function calls existing lmf.create_putaway_batches_for_po
           ** Calling the exisiting package lmf.create_putaway_batches_for_po directly and executing it here
           **
           */
    BEGIN
    pl_lmf.create_putaway_batches_for_po(i_rec_id, o_no_records_processed, o_no_batches_created, o_no_batches_existing, o_no_batches_not_created);
    pl_text_log.ins_msg_async('INFO', l_func_name, 'create forklift labor mgmt putaway batches Done for Rec id = ' || i_rec_id || 
    'o_no_records_processed = ' || o_no_records_processed || ' o_no_batches_created = ' || o_no_batches_created || 
    'o_no_batches_existing = ' || o_no_batches_existing || ' o_no_batches_not_created = ' || o_no_batches_not_created, sqlcode, sqlerrm );
    
    EXCEPTION
    WHEN OTHERS THEN
         pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to create forklift labor mgmt putaway batches.pl_lmf.create_putaway_batches_for_po generated an error',
         sqlcode, sqlerrm );
         o_status := -1;
         RETURN ;

    END;
    o_status := 0;    
    RETURN;
    
END reprocess; 

/*****************************************************************************
**  FUNCTION:
**      find_damage_zone_location
**  DESCRIPTION:
**      This function finds the slot in the default damage zone for a damaged
**      pallet
**
**      Called by: reprocess
** INPUT PARAMETERS:
**      i_uom 
**      i_prod_id 
**      i_cpv 
**      i_pallet_type
**  RETURN VALUES:
**      TRUE for the following:
**           - if a slot is found for the damaged pallet in the default damage
**             damage zone for the product on that pallet.
**      FALSE if the above is not met.
*****************************************************************************/

    FUNCTION find_damage_zone_location (
        i_uom           IN              putawaylst.uom%TYPE,
        i_prod_id       IN              pm.prod_id%TYPE,
        i_cpv           IN              pm.cust_pref_vendor%TYPE,
        i_pallet_type   IN              pm.pallet_type%TYPE
    ) RETURN BOOLEAN IS

        l_func_name         VARCHAR2(50) := 'pl_demand_pallet.find_damage_zone_location';
        l_done              BOOLEAN := false;
        l_ca_dest_loc       loc.logi_loc%TYPE := ' ';
        l_std_pallet_cube   NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Starting to find zone location for UOM = ' || i_uom, sqlcode, sqlerrm);
        IF i_uom = 1 THEN
            BEGIN
                SELECT
                    logi_loc
                INTO l_ca_dest_loc
                FROM
                    (
                        SELECT
                            l.logi_loc
                        FROM
                            loc          l,
                            pm           m,
                            swms_areas   s,
                            lzone        z,
                            zone         e
                        WHERE
                            m.prod_id = i_prod_id
                            AND s.area_code = m.area
                            AND z.zone_id = s.def_dmg_zone
                            AND e.zone_id = z.zone_id
                            AND e.zone_type = 'PUT'
                            AND l.logi_loc = z.logi_loc
                            AND l.status = 'AVL'
                            AND l.perm = 'N'
                            AND l.pallet_type = i_pallet_type
                        ORDER BY
                            l.cube
                    )
                WHERE
                    ROWNUM = 1;

            EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'unable to get select damage location for damaged pallet for prod id = '
                                                        || i_prod_id
                                                        || ' pallet type = '
                                                        || i_pallet_type, sqlcode, sqlerrm);

                ROLLBACK;
                RETURN l_done;
            END;

        ELSE  
          /* i_uom != 1  
          ** Get the smallest open reserve slot that will fit the
          ** damaged pallet ,in the damage zone 
          */
            BEGIN
                SELECT
                    logi_loc
                INTO l_ca_dest_loc
                FROM
                    (
                        SELECT
                            l.logi_loc
                        FROM
                            loc          l,
                            pm           m,
                            swms_areas   s,
                            lzone        z,
                            zone         e
                        WHERE
                            m.prod_id = i_prod_id
                            AND s.area_code = m.area
                            AND z.zone_id = s.def_dmg_zone
                            AND e.zone_id = z.zone_id
                            AND e.zone_type = 'PUT'
                            AND l.logi_loc = z.logi_loc
                            AND l.status = 'AVL'
                            AND l.perm = 'N'
                            AND l.pallet_type = i_pallet_type
                            AND l.cube >= l_std_pallet_cube
                        ORDER BY
                            ( l.cube - l_std_pallet_cube )
                    )
                WHERE
                    ROWNUM = 1;

            EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get select damage location for damaged pallet for prod id = '
                                                        || i_prod_id
                                                        || ' pallet type = '
                                                        || i_pallet_type, sqlcode, sqlerrm);

                ROLLBACK;
                RETURN l_done;
            END;
       END IF;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'pl_one_pallet_label.p_insert_table in find_damage_zone_location ' , sqlcode, sqlerrm);
        pl_one_pallet_label.p_insert_table(l_ca_dest_loc, ADD_RESERVE);
        l_done := true;
        RETURN l_done;
END find_damage_zone_location;

END pl_demand_pallet;
/

GRANT Execute on pl_demand_pallet to swms_user;
