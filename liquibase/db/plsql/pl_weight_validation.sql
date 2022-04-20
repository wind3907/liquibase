CREATE OR REPLACE PACKAGE PL_WEIGHT_VALIDATION IS
    FUNCTION validate_weight(i_prod_id PM.prod_id%TYPE, i_cust_pref_vendor PM.cust_pref_vendor%TYPE, i_erm_id TMP_WEIGHT.erm_id%TYPE, i_qty_received TMP_WEIGHT.total_cases%TYPE, i_weight TMP_WEIGHT.total_weight%TYPE, i_func1_option VARCHAR2) RETURN PLS_INTEGER;
END PL_WEIGHT_VALIDATION;
/

CREATE OR REPLACE PACKAGE BODY PL_WEIGHT_VALIDATION IS
    trk_yes CONSTANT VARCHAR2(1) := 'Y';
    trk_collected CONSTANT VARCHAR2(1) := 'C';

    FUNCTION get_catch_weight_Ind(i_prod_id PM.prod_id%TYPE, i_cust_pref_vendor PM.cust_pref_vendor%TYPE, i_erm_id TMP_WEIGHT.erm_id%TYPE) RETURN VARCHAR2 IS
        catch_weight_ind VARCHAR2(1);
    BEGIN
        SELECT catch_wt INTO catch_weight_ind FROM putawaylst 
        WHERE rec_id = i_erm_id AND prod_id = i_prod_id AND cust_pref_vendor = i_cust_pref_vendor and rownum=1;
        RETURN NVL(catch_weight_ind,'N');
    EXCEPTION WHEN OTHERS THEN 
        RETURN 'N';
    END get_catch_weight_Ind;
   
    FUNCTION validate_weight(i_prod_id PM.prod_id%TYPE, i_cust_pref_vendor PM.cust_pref_vendor%TYPE, i_erm_id TMP_WEIGHT.erm_id%TYPE, i_qty_received TMP_WEIGHT.total_cases%TYPE, i_weight TMP_WEIGHT.total_weight%TYPE, i_func1_option VARCHAR2) RETURN PLS_INTEGER IS
        pct_tolerance_param_name CONSTANT SYS_CONFIG.config_flag_name%TYPE := 'PCT_TOLERANCE' ;
        status PLS_INTEGER := PL_SWMS_Error_Codes.Normal;
        message VARCHAR2(2000);
        l_avg_wt pm.avg_wt%type;
        l_spc  pm.spc%type;
        l_rate sys_config.config_flag_val%type; 
        l_tot_weight NUMBER;
        l_case_qty NUMBER;
        l_split_qty NUMBER;
        l_current_avw NUMBER;
        v_weight putawaylst.weight%type; 
        v_catch_wt putawaylst.catch_wt%type; 
        Catch_Wt_Ind putawaylst.catch_wt%type;
        EXC_DB_Locked_With_NoWait       EXCEPTION;
        EXC_DB_Locked_With_Wait         EXCEPTION; 
        PRAGMA EXCEPTION_INIT( EXC_DB_Locked_With_NoWait,    -54 );
        PRAGMA EXCEPTION_INIT( EXC_DB_Locked_With_Wait  , -30006 );
        l_catch_wt putawaylst.catch_wt%type;
        l_weight   putawaylst.weight%type;
        l_total_weight tmp_weight.total_weight%type;
        PROCEDURE log_error(message VARCHAR2) IS
         BEGIN
            PL_SYSCO_MSG.msg_out(
              PL_SYSCO_MSG.MSGLVL_ERROR, 'validate_weight', message || ', Erm_id# '|| i_erm_id || ', Prod_id# ' || i_prod_id,
              PL_RCV_OPEN_PO_TYPES.CT_Application_Function, true, $$PLSQL_UNIT
          );
         END log_error;  
    BEGIN
     Catch_Wt_Ind := get_catch_weight_Ind(i_prod_id , i_cust_pref_vendor , i_erm_id );
     IF (Catch_Wt_Ind <> 'N') THEN
        BEGIN
            SELECT avg_wt, spc INTO l_avg_wt, l_spc
            FROM pm
            WHERE cust_pref_vendor = i_cust_pref_vendor AND prod_id = i_prod_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                status := PL_SWMS_ERROR_CODES.INV_PRODID;
            WHEN OTHERS THEN
                log_error('Exception: Failed to lookup Average Weight');
                RF.LogException();
                RAISE;
        END;
        
        IF (status = PL_SWMS_ERROR_CODES.NORMAL) THEN   
            BEGIN
                SELECT config_flag_val INTO l_rate
                FROM sys_config
                WHERE config_flag_name = pct_tolerance_param_name;
            EXCEPTION
                WHEN OTHERS THEN
                    log_error('Exception: Failed to lookup ' || pct_tolerance_param_name || ' system parameter.');
                    status := RF.STATUS_SEL_SYSCFG_FAIL;
            END;
        END IF;
        
        IF (status = PL_SWMS_ERROR_CODES.Normal) THEN
            ---Calculating the average weight of one split---
            l_tot_weight := i_weight;
            l_case_qty := i_qty_received; -- Putting split qty in cases to keep it consistent with the Pro C code (previous functionality)
            l_split_qty := 0;
            l_current_avw := l_tot_weight / (l_case_qty + l_split_qty);
            ---If allowed, Calculating to check whether the weight is in the range---)
            IF (l_avg_wt * (1.0 - l_rate / 100) <= l_current_avw) AND 
                (l_current_avw <= (l_avg_wt * (1.0 + l_rate / 100))) AND 
                ((((l_case_qty + l_split_qty) > 0) AND l_current_avw > 0) OR (((l_case_qty + l_split_qty) = 0) AND l_current_avw = 0)) THEN
                status := PL_SWMS_ERROR_CODES.Normal;	
            ELSE -- To override catch weight if entered the second time from the RF Devices
                IF(i_func1_option = 'Y') THEN -- Override Weight eventhough weight is out of tolerance
                    status := PL_SWMS_ERROR_CODES.Normal;
                ELSE
                    status := RF.STATUS_WEIGHT_OUT_OF_RANGE;

                    -- Insert collect data into swms_failure_event table
                    pl_event.ins_failure_event('COLLECTDATA', 
                                                'Q', 
                                                'CRIT', 
                                                i_prod_id, 
                                                'CRIT: COLLECTDATA: PO #' || i_erm_id || ' Item #' || i_prod_id || ' Total weight=' || to_char(i_weight) || ' Total cases=' || to_char(l_case_qty / l_spc),
                                                'Item ' || i_prod_id || ' on PO ' || i_erm_id || ' is out of tolerance (weight is ' || to_char(i_weight) || '). Please make sure it is correct.');
                END IF;
            END IF;
        END IF;
        
        IF (status = PL_SWMS_ERROR_CODES.Normal) THEN
          BEGIN
            SELECT total_weight
             INTO l_total_weight
            FROM tmp_weight
            WHERE cust_pref_vendor = i_cust_pref_vendor 
            AND prod_id = i_prod_id 
            AND erm_id = i_erm_id
            FOR UPDATE OF total_weight WAIT 5;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
                log_error('Exception: Failed to lookup Tmp Weight' );
            WHEN EXC_DB_Locked_With_NoWait OR
               EXC_DB_Locked_With_Wait   THEN
                  log_error('Exception: Failed to update tmp_weight.');
                  status := PL_SWMS_Error_Codes.Lock_PO;
          END;
        END IF;
        
        IF (status = PL_SWMS_ERROR_CODES.Normal) THEN -- total_cases is already in splits
            BEGIN
                UPDATE tmp_weight 
                  SET total_weight = l_tot_weight, 
                      total_cases = l_case_qty, 
                      total_splits = l_split_qty
                WHERE cust_pref_vendor = i_cust_pref_vendor 
                AND prod_id = i_prod_id 
                AND erm_id = i_erm_id;
                
                IF sql%notfound THEN
                    log_error('Exception: Failed to Update putawaylst. Trying to Insert into tmp_weight');
                        INSERT INTO tmp_weight(erm_id, prod_id, cust_pref_vendor, total_weight, total_cases, total_splits)
                        VALUES (i_erm_id, i_prod_id, i_cust_pref_vendor, l_tot_weight, l_case_qty, l_split_qty);
                END IF;
                
            EXCEPTION
                WHEN OTHERS THEN
                        log_error('Exception: ' || SQLCODE ||' -ERROR- '|| SQLERRM);
                        status := RF.STATUS_WEIGHT_INSERT_FAILED;
            END;
        END IF;

        -- Updating the putawaylist with average weight and catch weight flag to 'C'-Collected
        IF (status = PL_SWMS_ERROR_CODES.Normal AND l_current_avw <> 0 AND (l_case_qty + l_split_qty) <> 0) THEN
            BEGIN
                BEGIN
                  FOR lock_rec IN (SELECT pal.cust_pref_vendor,pal.prod_id,pal.rec_id, pal.pallet_id
                                  FROM putawaylst pal
                                  WHERE cust_pref_vendor = i_cust_pref_vendor 
                                  AND prod_id = i_prod_id 
                                  AND rec_id = i_erm_id) 
                  LOOP
                  SELECT pal.weight,pal.catch_wt
                   INTO l_weight,l_catch_wt
                  FROM putawaylst pal
                  WHERE cust_pref_vendor = lock_rec.cust_pref_vendor 
                  AND prod_id = lock_rec.prod_id 
                  AND rec_id = lock_rec.rec_id
                  AND pallet_id = lock_rec.pallet_id
                  FOR UPDATE OF status WAIT 5;
                  END LOOP;
               -- Exclusive lock is held, now let's perform the update.
                  UPDATE putawaylst SET weight = l_current_avw, catch_wt = trk_collected
                  WHERE cust_pref_vendor = i_cust_pref_vendor 
                  AND prod_id = i_prod_id 
                  AND rec_id = i_erm_id;
                   IF sql%notfound THEN
                      log_error('Exception: Failed to Update putawaylst.');
                      status := RF.STATUS_PUTAWAYLST_UPDATE_FAIL;
                   END IF;
                   
                 UPDATE USER_DOWNLOADED_PO set weight = l_current_avw, catch_wt = trk_collected
                 WHERE  prod_id = i_prod_id AND rec_id = i_erm_id and user_id = (select user from dual);
                EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     NULL;
                  WHEN EXC_DB_Locked_With_NoWait OR
                     EXC_DB_Locked_With_Wait   THEN
                       status := PL_SWMS_Error_Codes.Lock_PO;
                END; 
                   
            EXCEPTION
                WHEN OTHERS THEN
                    log_error('Exception: ' || SQLCODE ||' -ERROR- '|| SQLERRM);
                    status := RF.STATUS_PUTAWAYLST_UPDATE_FAIL;
            END;
        END IF;

     END IF;
      RETURN status;
    EXCEPTION
        WHEN OTHERS THEN
            log_error(
                '(i_prod_id =[' || NVL(i_prod_id, 'NULL') || '] (i_erm_id =[' || NVL(i_erm_id, 'NULL') || ']' ||
                '(i_qty_received =[' || NVL(to_char(i_qty_received), 'NULL') || '] (i_weight =[' || NVL(to_char(i_weight), 'NULL') || ']' ||
                '(i_func1_option =[' || NVL(i_func1_option, 'NULL') || ']) - Failed to Validate Weight.'
            );
            RETURN PL_SWMS_ERROR_CODES.Data_Error;
    END validate_weight;
    
END PL_WEIGHT_VALIDATION;
/