create or replace PACKAGE pl_rf_validate AS
/*******************************************************************************
**Package:
**        pl_rf_validate. Migrated from validate.pc
**
**Description:
		  Functions for validating Expiry/Manufacturer/harvest date. 
**
**Called by:
**        This is a Common package called from Java.
*******************************************************************************/ 

    FUNCTION validate_main (
        i_rf_log_init_record   IN                     rf_log_init_record,
        i_client_obj           IN                     validate_client_obj
    ) RETURN rf.status;

    FUNCTION validate (
        i_client_obj           IN                     validate_client_obj
    ) RETURN rf.status;

    FUNCTION check_expr_date RETURN rf.status;

    FUNCTION check_mfg_date RETURN rf.status;

    FUNCTION validate_mfg_date (
        i_mfg_date IN VARCHAR2
    ) RETURN rf.status;

    FUNCTION check_hrv_date RETURN rf.status;

    FUNCTION validate_hrv_date (
        i_hrv_date IN VARCHAR2
    ) RETURN rf.status;

END pl_rf_validate;
/

create or replace PACKAGE BODY pl_rf_validate AS

    g_client             validate_client_obj;
    g_pallet_id          putawaylst.pallet_id%TYPE;
    g_expr_date          VARCHAR2(6);
    g_mfg_date           VARCHAR2(6);
    g_prod_id            putawaylst.prod_id%TYPE;
    g_cust_pref_vendor   putawaylst.cust_pref_vendor%TYPE;
    g_hrv_date           VARCHAR2(6);
    g_num_days           NUMBER;
    g_dummy              VARCHAR2(1);
    
/*******************************************************************************
   NAME        :  validate_main
   DESCRIPTION :  Login service for Validate
   CALLED BY   :  Java service  
   PARAMETERS:
   INPUT :
      i_rf_log_init_record      
      i_client_obj
   RETURN VALUE:
	  rf.status 

********************************************************************************/	

	FUNCTION validate_main (
        i_rf_log_init_record   IN                     rf_log_init_record,
        i_client_obj           IN                     validate_client_obj
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(50) := 'validate_main';
        rf_status     rf.status := rf.status_normal;
    BEGIN
        rf_status := rf.initialize(i_rf_log_init_record);
        IF rf_status = rf.status_normal THEN
            rf_status := validate(i_client_obj);
        END IF;
        rf.complete(rf_status);
        RETURN rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('FATAL',l_func_name, 'Validate call failed', sqlcode, sqlerrm);
            rf.logexception();
            RAISE;
    END validate_main;
     
/*************************************************************************
  NAME        :  validate
  DESCRIPTION :  To validate the dates
  Called by   :  Validate_main
  PARAMETERS:
    i_rf_log_init_record -- Object to get the RF status
    i_client_obj		 --  client message
  RETURN VALUE:    rf.status - Output value returned by the package
**************************************************************************/

    FUNCTION validate (
        i_client_obj           IN       validate_client_obj
    ) RETURN rf.status AS

        rf_status      rf.status := rf.status_normal;
        l_func_name    VARCHAR2(30) := 'validate';
        l_which_type   VARCHAR2(10);
        l_req_option   VARCHAR2(1);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Validate', sqlcode, sqlerrm);
        g_client := i_client_obj;
        IF (g_client.req_option = '0') THEN 
            l_which_type := 'exp_date';
        ELSIF (g_client.req_option = '1') THEN 
            l_which_type := 'mfg_date';
        ELSE
            l_which_type := 'hrv_date';
        END IF;   
		pl_text_log.ins_msg_async('INFO', l_func_name, 
                       'MESSAGE SENT FROM CLIENT. Pallet_id = '
                       ||i_client_obj.pallet_id 
                       || ' Expr_date = '
                       ||i_client_obj.expr_date
                       || ' Which_type = '
                       ||l_which_type
                       ||' Mfg_date = '
                       || i_client_obj.mfg_date
                       ||' prod_id = '
                       ||i_client_obj.prod_id 
                       || ' cpv = '
                       ||i_client_obj.cust_pref_vendor
                       ||' option = '
					   ||i_client_obj.req_option, sqlcode, sqlerrm);   
        g_pallet_id := g_client.pallet_id;
        g_expr_date := g_client.expr_date;
        g_mfg_date  := g_client.mfg_date;
        g_prod_id   := g_client.prod_id;
        g_cust_pref_vendor := g_client.cust_pref_vendor;
        IF (i_client_obj.req_option = '0') THEN   
            rf_status := check_expr_date();
        ELSIF (i_client_obj.req_option = '1') THEN  
            rf_status := check_mfg_date();
        ELSE
            g_hrv_date := g_mfg_date;
            rf_status := check_hrv_date();
        END IF;  
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Status after checking Exp/Mfg/Hrv Date= ' || rf_status, sqlcode, sqlerrm);
        IF ((rf_status = rf.status_normal) OR (rf_status = rf.status_exp_warn)) THEN /*Checking status is normal or exp warn*/
            COMMIT;
			pl_text_log.ins_msg_async('INFO', l_func_name, 'Status after Commit', sqlcode, sqlerrm);
        ELSE
            ROLLBACK;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Status after Rollback' || rf_status, sqlcode, sqlerrm);
        END IF;
		RETURN rf_status;
    END validate;
    
/*************************************************************************
  NAME        :  check_expr_date
  DESCRIPTION :  Checking Expiry date
  CALLED BY   :  Validate
  PARAMETERS:
  RETURN VALUE:   rf.status - Output value returned by the package
  
**************************************************************************/

    FUNCTION check_expr_date RETURN rf.status AS
        l_func_name          VARCHAR2(30) := 'check_expr_date';
        l_po_number          putawaylst.rec_id%TYPE;
        l_language_id        NUMBER;
        rf_status            rf.status := rf.status_normal;
        l_sysco_shelf_life   NUMBER;
        l_cust_shelf_life    NUMBER;
        l_mfr_shelf_life     NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Checking expiration date', sqlcode, sqlerrm);
        BEGIN
            SELECT
                nvl(sysco_shelf_life, 0),
                nvl(cust_shelf_life, 0),
                nvl(mfr_shelf_life, 0)
            INTO
                l_sysco_shelf_life,
                l_cust_shelf_life,
                l_mfr_shelf_life
            FROM
                pm
            WHERE
                prod_id = g_prod_id
                AND cust_pref_vendor = g_cust_pref_vendor;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to select shelf life from pm', sqlcode, sqlerrm);
				return rf.STATUS_NOT_FOUND;
        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Expiration Date= '
                                            || g_expr_date
                                            || ' prod_id= '
                                            || g_prod_id
                                            || ' CPV= '
                                            || g_cust_pref_vendor
                                            || ' Sysco Shelf Life= '
                                            || l_sysco_shelf_life
                                            || ' Cust. Shelf Life= '
                                            || l_cust_shelf_life
                                            || ' Mfg Shelf Life= '
                                            || l_mfr_shelf_life, sqlcode, sqlerrm);
        BEGIN
            SELECT
                'x'
            INTO g_dummy
            FROM
                dual
            WHERE
                (TO_DATE(g_expr_date, 'FXMMDDRR') - trunc(SYSDATE)) >= 7;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'No data found', sqlcode, sqlerrm);
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Error checking expiration date against exp warning report number of days for item', sqlcode, sqlerrm);
                RETURN rf.status_invalid_exp_date;  
        END;
        BEGIN
            l_language_id := pl_common.f_get_syspar('LANGUAGE_ENABLE', 'X');
            IF TO_CHAR(l_language_id) = 'X' THEN  
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to fetch SYSPAR', sqlcode, sqlerrm);
            END IF;
            string_translation.set_current_language(l_language_id);
            BEGIN 
                SELECT
                  rec_id
                INTO l_po_number
                FROM 
                    putawaylst
                WHERE
                    pallet_id = g_pallet_id;
            EXCEPTION 
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection from putawaylst table gets failed.', sqlcode, sqlerrm);
            END;
            pl_event.ins_failure_event('EXPIRATION_DATE', 'Q', 'WARN', g_prod_id, string_translation.get_string(120119, g_prod_id, g_pallet_id, l_po_number), string_translation.get_string(120116, g_prod_id, g_pallet_id, l_po_number, TO_CHAR(TO_DATE(g_expr_date, 'MMDDYY'), 'DD-MON-YYYY')));
        END;
        IF ((l_sysco_shelf_life != 0) AND (l_cust_shelf_life != 0)) THEN 
            BEGIN
                SELECT
                    'x'
                INTO g_dummy
                FROM
                    dual
                WHERE
                    (TO_DATE(g_expr_date, 'FXMMDDRR') - trunc(SYSDATE)) > (l_sysco_shelf_life + l_cust_shelf_life);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Difference of Expiration date and sysdate is less than sum of sysco shelf life and customer shelf life', sqlcode, sqlerrm);
                    RETURN rf.status_sys_cust_warn;
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Error checking expiration date against sysco and customer shelf life for item', sqlcode, sqlerrm);
                    RETURN rf.status_invalid_exp_date; 
            END;
        ELSIF (l_mfr_shelf_life != 0) THEN 
            BEGIN
                SELECT
                    'x'
                INTO g_dummy
                FROM
                    dual
                WHERE
                    (TO_DATE(g_expr_date, 'FXMMDDRR') - SYSDATE) > l_mfr_shelf_life;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' Difference between Expiration date and sysdate is lesser than manufacturer shelf life',sqlcode, sqlerrm);
                    RETURN rf.status_mfr_shelf_warn;
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' Error checking expiration date against mfr shelf life for item.', sqlcode, sqlerrm);
                    RETURN rf.status_invalid_exp_date; 
            END;
        END IF; 
        BEGIN
            g_num_days := pl_common.f_get_syspar('EXPIR_WARN_DAYS', 'X');
            IF TO_CHAR(g_num_days) = 'X' THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get expir_warn_days.', sqlcode, sqlerrm);
                return rf.STATUS_NOT_FOUND;
            END IF; 
        END;
        BEGIN
            SELECT
                'x'
            INTO g_dummy
            FROM
                dual
            WHERE
                (TO_DATE(g_expr_date, 'FXMMDDRR') - trunc(SYSDATE)) >= g_num_days;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Checking Exp Warn Days.', sqlcode, sqlerrm);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Item is on expiration warning report', sqlcode, sqlerrm);
                RETURN rf.status_exp_warn;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Error checking expiration date against exp warning report number of days for item',sqlcode, sqlerrm);
                RETURN rf.status_invalid_exp_date; 
        END;
        RETURN rf_status;
    END check_expr_date;

/*************************************************************************
  NAME        :  check_mfg_date
  DESCRIPTION :  Checking Manufacturer date
  CALLED BY   :  Validate
  PARAMETERS:
  RETURN VALUE:    rf.status - Output value returned by the package
  
**************************************************************************/

    FUNCTION check_mfg_date RETURN rf.status AS
        l_shelf_life   NUMBER;
        l_func_name    VARCHAR2(30) := 'check_mfg_date';
        rf_status      rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Checking manufacturer date.', sqlcode, sqlerrm);
        rf_status := validate_mfg_date(g_mfg_date);
        IF (rf_status != rf.status_normal) THEN  
            RETURN rf_status;
        END IF;		
        BEGIN
            SELECT
                nvl(mfr_shelf_life, 0)
            INTO l_shelf_life
            FROM
                pm
            WHERE
                prod_id = g_prod_id
                AND cust_pref_vendor = g_cust_pref_vendor;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to select mfr shelf life for item', sqlcode, sqlerrm);
				return rf.STATUS_NOT_FOUND;
        END;
        /*
        ** If the item has a manufacturer shelf life then check it against
        ** the manufacturer date entered by the user on the RF unit.
        */
        IF (l_shelf_life != 0) THEN 
            BEGIN
                SELECT
                    'x'
                INTO g_dummy
                FROM
                    dual
                WHERE
                    ((TO_DATE(g_mfg_date, 'FXMMDDRR') + l_shelf_life) < SYSDATE);
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Manufacturer date for Item is past shelf life', sqlcode, sqlerrm);
                RETURN rf.status_past_shelf_warn;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'No data found from pm table', sqlcode, sqlerrm);
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Error checking mfg date against mfr shelf life for item', sqlcode, sqlerrm);
                    RETURN rf.status_invalid_mfg_date;
            END;
        END IF; 
        /*
        ** assign a new expiration date based on mfg_date
        */
        BEGIN
            SELECT
                TO_CHAR((TO_DATE(g_mfg_date, 'FXMMDDRR') + l_shelf_life), 'MMDDYY')
            INTO g_expr_date
            FROM
                dual;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Error selecting mfg_date', sqlcode, sqlerrm);
                RETURN rf.status_invalid_mfg_date;
        END;
        BEGIN
            g_num_days := pl_common.f_get_syspar('EXPIR_WARN_DAYS', 'X');
            IF TO_CHAR(g_num_days) = 'X' THEN  
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get expir_warn_days', sqlcode, sqlerrm);
                return rf.STATUS_NOT_FOUND;
            END IF; 
        END;
        BEGIN
            SELECT
                'x'
            INTO g_dummy
            FROM
                dual
            WHERE
                TO_DATE(g_expr_date, 'FXMMDDRR') - SYSDATE >= g_num_days;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Item is on expiration warning report', sqlcode, sqlerrm);
                rf_status := rf.status_exp_warn;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Error checking expiration date against exp warning report.', sqlcode, sqlerrm);
                RETURN rf.status_invalid_exp_date;
        END;
        /*
        **  update putawaylst with new expiration date
        */
        BEGIN
            UPDATE putawaylst
            SET
                exp_date = TO_DATE(g_expr_date, 'FXMMDDRR')
            WHERE
                pallet_id = g_pallet_id;

            IF SQL%rowcount = 0  THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to update putawaylst', sqlcode, sqlerrm);
                rf_status := rf.STATUS_NOT_FOUND;
            END IF;  
        EXCEPTION
            WHEN OTHERS THEN
				rf_status:= rf.STATUS_DATA_ERROR;
        END;
        RETURN rf_status;
    END check_mfg_date;

/*************************************************************************
  NAME        :  validate_mfg_date
  DESCRIPTION :  Validating Manufacturer date
  CALLED BY   :  check_mfg_date  
  PARAMETERS:
  INPUT PARAMETER  : i_mfg_date

  RETURN VALUE	   : rf.status - Output value returned by the package
  
**************************************************************************/

    FUNCTION validate_mfg_date (
        i_mfg_date IN VARCHAR2
    ) RETURN rf.status AS
        l_dummy       VARCHAR2(1);
        l_mfg_date    VARCHAR2(6) ; 
        l_func_name   VARCHAR2(30) := 'validate_mfg_date';
        rf_status     rf.status := rf.status_normal;
    BEGIN
    pl_text_log.ins_msg_async('INFO', l_func_name, 'starting  ' || l_func_name , sqlcode, sqlerrm);
        IF (i_mfg_date = '0') THEN
         pl_text_log.ins_msg_async('INFO', l_func_name, 'i_mfg_date == ' || i_mfg_date, sqlcode, sqlerrm);
            rf_status := rf.status_normal;
        ELSE
            l_mfg_date := i_mfg_date;
            l_dummy := 'N';
             pl_text_log.ins_msg_async('INFO', l_func_name, 'date = ' || l_mfg_date, sqlcode, sqlerrm);
             pl_text_log.ins_msg_async('INFO', l_func_name, 'sysdate == ' ||  to_char(SYSDATE, 'MMDDRR'), sqlcode, sqlerrm);
            
            BEGIN
                SELECT
                    'Y'
                INTO l_dummy
                FROM
                    dual
                WHERE
                    TO_DATE(l_mfg_date, 'MMDDRR') >   trunc(SYSDATE);

                pl_text_log.ins_msg_async('INFO', l_func_name, 'Mfg date is greater than the sysdate', sqlcode, sqlerrm);
                rf_status := rf.status_invalid_mfg_date;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Mfg date '||l_mfg_date||' is valid', sqlcode, sqlerrm);
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'mfg date failed validation, required format FXMMDDRR', sqlcode, sqlerrm);
                    rf_status := rf.status_invalid_mfg_date; 
            END;
        END IF; 
        RETURN rf_status;
    END validate_mfg_date;

/*************************************************************************
  NAME        :  check_hrv_date
  DESCRIPTION :  Checking Harvest Date
  CALLED BY   :  Validate  
  PARAMETERS:
  RETURN VALUE:   rf.status - Output value returned by the package
  
**************************************************************************/

    FUNCTION check_hrv_date RETURN rf.status AS
        l_mfg_date     VARCHAR2(10);
        l_exp_date     VARCHAR2(10);
        l_func_name    VARCHAR2(30) := 'check_hrv_date';
        rf_status      rf.status := rf.status_normal;
        l_shelf_life   NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Checking harvest date', sqlcode, sqlerrm);
        rf_status := validate_hrv_date(g_hrv_date);
        IF (rf_status != rf.status_normal) THEN  /*checking status is other than normal*/
            RETURN rf_status;
        END IF;   
        BEGIN
            SELECT
                nvl(mfr_shelf_life, 0)
            INTO l_shelf_life
            FROM
                pm
            WHERE
                prod_id = g_prod_id
                AND cust_pref_vendor = g_cust_pref_vendor;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to select mfr shelf life for item', sqlcode, sqlerrm);
				return rf.STATUS_NOT_FOUND;
        END;
        IF (l_shelf_life != 0) THEN  
            BEGIN
                SELECT
                    'x'
                INTO g_dummy
                FROM
                    dual
                WHERE
                    ((TO_DATE(g_hrv_date, 'FXMMDDRR') + l_shelf_life) < SYSDATE);
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Hrv date and l_shelf_life is less than sysdate', sqlcode, sqlerrm);
                RETURN rf.status_past_shelf_warn;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Manufacturer date + l_shelf_line is greater than sysdate', sqlcode, sqlerrm);
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Erroron Checking hrv date against mfr shelf life for the item', sqlcode,
                    sqlerrm);
                    RETURN rf.status_invalid_hrv_date; 
            END;
        END IF;  
        BEGIN
            SELECT
                TO_CHAR(mfg_date, 'MMDDRR'),
                TO_CHAR(exp_date, 'MMDDRR')
            INTO
                l_mfg_date,
                l_exp_date
            FROM
                putawaylst
            WHERE
                prod_id = g_prod_id
                AND cust_pref_vendor = g_cust_pref_vendor
                AND pallet_id = g_pallet_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to select mfg_date, exp_date for item.', sqlcode, sqlerrm);
				return rf.STATUS_NOT_FOUND;
        END;
        IF l_mfg_date IS NOT NULL THEN 
            IF (g_hrv_date != l_mfg_date) THEN 
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Harvest date should not be less than manufacture date', sqlcode, sqlerrm);
                IF (sqlcode >= -1899) AND (sqlcode <= -1800) THEN 
                    RETURN rf.status_invalid_hrv_date;
                ELSE
                    RETURN rf.status_hrv_date_warn;
                END IF; 
            END IF; 
        END IF;   
        IF l_exp_date IS NOT NULL THEN 
            IF (g_hrv_date != l_exp_date) THEN  
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Harvest date should not be less than Expiry  date', sqlcode, sqlerrm);
                IF (sqlcode >= -1899) AND (sqlcode <= -1800) THEN 
                    RETURN rf.status_invalid_hrv_date;
                ELSE
                    RETURN rf.status_hrv_date_warn;
                END IF; 
            END IF;
        END IF;  
        RETURN rf_status;
    END check_hrv_date;

/*************************************************************************
  NAME        :  validate_hrv_date
  DESCRIPTION :  Validating Harvest Date
  CALLED BY   :  check_hrv_date  
  PARAMETERS  :
  INPUT PARAMETER   : i_hrv_date
  RETURN VALUE		: rf.status - Output value returned by the package
  
**************************************************************************/

    FUNCTION validate_hrv_date (
        i_hrv_date VARCHAR2
    ) RETURN rf.status AS
        l_dummy       VARCHAR2(1);
        l_hrv_date    VARCHAR2(12);
        l_func_name   VARCHAR2(30) := 'validate_hrv_date';
        rf_status     rf.status := rf.status_normal;
    BEGIN
        IF (i_hrv_date = 0) THEN 
            rf_status := rf.status_normal;
        ELSE
            l_hrv_date := i_hrv_date;
            l_dummy := 'N';
            BEGIN
                SELECT
                    'Y'
                INTO l_dummy
                FROM
                    dual
                WHERE
                    TO_DATE(l_hrv_date, 'FXMMDDRR') > trunc(SYSDATE);
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Harvest date is greater than the sysdate', sqlcode, sqlerrm);
                rf_status := rf.status_invalid_hrv_date;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Harvest date is less than or equal to sysdate', sqlcode, sqlerrm);
                  --  rf_status := rf.status_invalid_hrv_date; pdas8114 Jira-4000 Getting Invalid Harvest date on doing legacy receiving.
            END;
        END IF;  
        RETURN rf_status;
    END validate_hrv_date;
END pl_rf_validate;
/

grant execute on pl_rf_validate  to swms_user;
