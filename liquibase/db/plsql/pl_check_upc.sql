create or replace PACKAGE pl_check_upc IS
/*******************************************************************************
**Package:
**        pl_check_upc. Migrated from check_upc.pc   
**
**  Description:The check_upc program consists of a function called    
**                 Check_Upc_Data_Collection function.  The variable
**                 option is set in the calling function and its value
**                 indicates which program/function is calling to check
**                 the UPC data collection status.                           
**                                                                       
**Called by: 
**        This function will be called from various SWMS's RF functions to check 
**        the status of the previous scans of the UPC's.
*******************************************************************************/
    PROCEDURE check_upc_data_collection (
        i_prod_id             IN                    pm.prod_id%TYPE,
        i_rec_id              IN                    erm.erm_id%TYPE,
        i_option              IN                    NUMBER,
        o_upc_comp_flag       OUT                   VARCHAR2,
        o_upc_scan_function   OUT                   sys_config.config_flag_val%TYPE
    );

    FUNCTION validate_upc (
        i_in_upc     IN           pm.external_upc%TYPE,
        i_upc_type   IN           NUMBER
    ) RETURN BOOLEAN;

END pl_check_upc;
/

create or replace PACKAGE BODY pl_check_upc AS
    
/******************************************************************************
* TYPE             : PROCEDURE                                                *
* NAME             : check_upc_data_collection                                *
* DESCRIPTION      : To check the upc data                                    * 
* INPUT PARAMETERS :  i_prod_id                                               *
*                     i_rec_id                                                *
*                     i_option                                                *
*  Return Values   :  o_upc_comp_flag                                         *
*                     o_upc_scan_function                                     *
* Author       Date        Ver   Description                                  *
* ------------ ----------  ----  -----------------------------------------    *
* KRAJ9028    01/09/2020   1.0    Initial Version                             *
******************************************************************************/

    PROCEDURE check_upc_data_collection (
        i_prod_id             IN                    pm.prod_id%TYPE,
        i_rec_id              IN                    erm.erm_id%TYPE,
        i_option              IN                    NUMBER,
        o_upc_comp_flag       OUT                   VARCHAR2,
        o_upc_scan_function   OUT                   sys_config.config_flag_val%TYPE
    ) IS

        l_func_name           VARCHAR2(50) := 'pl_check_upc.check_upc_data_collection';
        l_function_name       VARCHAR2(11);
        l_prod_id             pm.prod_id%TYPE;
        l_rec_id              erm.erm_id%TYPE;
        l_upc_scan_function   sys_config.config_flag_val%TYPE;
        l_dummy               VARCHAR2(1);
        l_internal_upc        pm.internal_upc%TYPE;
        l_external_upc        pm.external_upc%TYPE;
        l_category            pm.category%TYPE;
        l_split_trk           pm.split_trk%TYPE;
        l_upc_validation      sys_config.config_flag_val%TYPE;
        rf_status             rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Starting check_upc_data_collection', sqlcode, sqlerrm);
        l_function_name := ' ';
        IF i_option = 1 THEN
            l_function_name := 'PUTAWAY';
        ELSIF i_option = 2 THEN
            l_function_name := 'RECEIVING';
        ELSIF i_option = 3 THEN
            l_function_name := 'CYCLE_CNT';
        ELSIF i_option = 4 THEN
            l_function_name := 'WAREHOUSE';
        END IF;

        l_prod_id := i_prod_id;
        l_rec_id := i_rec_id;
        l_upc_scan_function := ' ';
        BEGIN
            l_upc_scan_function := pl_common.f_get_syspar('UPC_SCAN_FUNCTION', 'N');
            IF l_upc_scan_function = 'N' THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to select from sys_config for UPC_SCAN_FUNCTION', sqlcode, sqlerrm);
                rf_status := rf.status_sel_syscfg_fail;
            END IF;

            o_upc_scan_function := l_upc_scan_function;
        END;

        l_upc_validation := pl_common.f_get_syspar('UPC_VALIDATION', 'N');
        /*
        **  Check to see if UPC data has been collected  and sent up to AS400
        **  for the item on the purchase order    
        */
        o_upc_comp_flag := ' ';
        BEGIN
            SELECT
                'x'
            INTO l_dummy
            FROM
                upc_info u
            WHERE
                u.prod_id = l_prod_id
                AND u.rec_id = l_rec_id;

            o_upc_comp_flag := 'Y';
            pl_text_log.ins_msg_async('WARN', l_func_name, 'UPC data already collected for this item on this PO ' ||
                l_prod_id || ' and rec_id = ' || l_rec_id , sqlcode, sqlerrm);
        EXCEPTION
            WHEN OTHERS THEN
                BEGIN
                    SELECT
                        internal_upc,
                        external_upc,
                        category,
                        split_trk
                    INTO
                        l_internal_upc,
                        l_external_upc,
                        l_category,
                        l_split_trk
                    FROM
                        pm
                    WHERE
                        prod_id = l_prod_id;
                    /*If this is a category 11 (Produce) product, don't prompt for UPC. */

                    IF substr(l_category, 2) = '11' THEN
                        o_upc_comp_flag := 'Y';
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'PM Prod id = ' || l_prod_id || ', dont prompt for UPC = ' ||
                            o_upc_comp_flag , sqlcode, sqlerrm);
                    ELSE
                        IF validate_upc(l_external_upc, 2) AND ( l_split_trk = 'N' OR validate_upc(l_internal_upc, 1) ) THEN
                            IF l_upc_validation = 'N' THEN
                                o_upc_comp_flag := 'Y';
                                pl_text_log.ins_msg_async('INFO', l_func_name,
                                    'UPC already collected,no validation required for PM prod id = ' || l_prod_id ||
                                    ' and UPC = ' || o_upc_comp_flag , sqlcode, sqlerrm);
                            ELSE
                                o_upc_comp_flag := 'N';
                                pl_text_log.ins_msg_async('INFO', l_func_name,
                                    'UPC already collected, validation required for PM prod id = ' || l_prod_id ||
                                    ' and UPC = ' || o_upc_comp_flag , sqlcode, sqlerrm);
                            END IF;
                        ELSE
                            o_upc_comp_flag := 'N';
                            pl_text_log.ins_msg_async('INFO', l_func_name,
                                'UPC data not collected yet according to PM prod id = ' || l_prod_id ||
                                ' and UPC = ' || o_upc_comp_flag , sqlcode, sqlerrm);
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'No data found from PM for prod id = ' || l_prod_id,
                            sqlcode, sqlerrm);
                    WHEN TOO_MANY_ROWS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Too Many rows fetched from PM for prod id = ' || l_prod_id,
                            sqlcode, sqlerrm);
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to select data from PM prod id = ' || l_prod_id,
                            sqlcode, sqlerrm);
                END;
        END;

    END check_upc_data_collection;
    
/******************************************************************************                                                 *
* NAME             : validate_upc                                             *
* DESCRIPTION      : To validat UPC data based on even and odd values ,assign *
*                    the l_type based on the UPC value and validate UPC       *
* Called By        : check_upc_data_collection                                *
* INPUT pARAMETERS :  i_in_upc                                                *
*                     i_upc_type                                              *
*RETURN VALUES     : Returns True or False                                    *
*                                                                             *
* Author       Date        Ver   Description                                  *
* ------------ ----------  ----  -----------------------------------------    *
*  KRAJ9028    01/09/2020  1.0    Initial Version                             *
******************************************************************************/

    FUNCTION validate_upc (
        i_in_upc     IN           pm.external_upc%TYPE,
        i_upc_type   IN           NUMBER
    ) RETURN BOOLEAN IS

        l_func_name      VARCHAR2(50) := 'pl_check_upc.validate_upc';
        l_odd_values     NUMBER;
        l_even_values    NUMBER;
        l_end_result     NUMBER;
        l_chk_digit      NUMBER;
        l_mod10_result   NUMBER;
        l_type           VARCHAR2(10);
        l_status         BOOLEAN;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting validate_upc', sqlcode, sqlerrm);
        l_odd_values := 3 * ( to_number((substr(i_in_upc, 1, 1))) + 
                           to_number((substr(i_in_upc, 3, 1))) + 
                           to_number((substr(i_in_upc, 5, 1))) + 
                           to_number((substr(i_in_upc, 7, 1))) + 
                           to_number((substr(i_in_upc, 9, 1))) + 
                           to_number((substr(i_in_upc, 11, 1))) + 
                           to_number((substr(i_in_upc, 13, 1))) );

        l_even_values := ( to_number((substr(i_in_upc, 2, 1))) + 
                              to_number((substr(i_in_upc, 4, 1))) + 
                              to_number((substr(i_in_upc, 6, 1))) + 
                              to_number((substr(i_in_upc, 8, 1))) + 
                              to_number((substr(i_in_upc, 10, 1))) + 
                              to_number((substr(i_in_upc, 12, 1))) );

        l_end_result := l_odd_values + l_even_values;
        l_mod10_result := MOD(l_end_result, 10);
        IF l_mod10_result > 0 THEN
            l_chk_digit := 10 - MOD(l_end_result, 10);
        ELSE
            l_chk_digit := 0;
            IF i_upc_type = 1 THEN
                l_type := 'Internal';
            ELSE
                l_type := 'External';
            END IF;

        END IF;

        IF l_end_result = 0 OR l_chk_digit <> to_number((substr(i_in_upc, 14, 1))) THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, l_type || ' UPC = '
                || i_in_upc || ' is invalid', sqlcode, sqlerrm);

            l_status := FALSE;
        ELSE
            pl_text_log.ins_msg_async('WARN', l_func_name, l_type || ' UPC = '
                || i_in_upc || ' is valid', sqlcode, sqlerrm);

            l_status := TRUE;
        END IF;
        RETURN l_status;
    EXCEPTION
        WHEN OTHERS THEN
            l_status := FALSE;
            pl_text_log.ins_msg_async('WARN', l_func_name, 'validate_upc: UPC = ' || i_in_upc || ' is invalid', NULL, NULL);
            RETURN l_status;
    END validate_upc;

END pl_check_upc;
/

GRANT Execute on pl_check_upc to swms_user;

