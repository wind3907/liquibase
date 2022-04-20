create or replace PACKAGE pl_rf_calc_avw AS
    FUNCTION calc_avw_main (
        i_rf_log_init_record   IN                     rf_log_init_record,
        i_client               IN                     calc_avw_client_obj
    ) RETURN rf.status;

    FUNCTION calc_avw (
        i_client IN calc_avw_client_obj
    ) RETURN rf.status;

   FUNCTION tm_calc_total_avw (
        i_client IN calc_avw_client_obj
    ) RETURN rf.status;

END pl_rf_calc_avw;
/

create or replace PACKAGE BODY                            pl_rf_calc_avw AS
 /*******************************************************************************
   FUNCTION:
      calc_avw_main
   called by Java service
   Description:
    Login service for Calculate average
  
   Parameters:
      i_rf_log_init_record      
      i_client
   RETURN VALUE:
   rf status code
    26/11/19    1072666    initial version0.0
  ********************************************************************************/
    FUNCTION calc_avw_main (
        i_rf_log_init_record   IN                     rf_log_init_record,
        i_client               IN                     calc_avw_client_obj
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(50) := 'calc_avw_main';
        rf_status     rf.status := rf.status_normal;
    BEGIN
        rf_status := rf.initialize(i_rf_log_init_record);
        IF rf_status = rf.status_normal THEN
            rf_status := calc_avw(i_client);
        END IF;
        rf.complete(rf_status);
        RETURN rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('FATAL', l_func_name, 'Calculate average call failed', sqlcode, sqlerrm);
            rf.logexception(); -- log it
            RAISE;
    END calc_avw_main;
   
/*************************************************************************
  NAME:  calc_avw
  DESC:  Calculating average
  PARAMETERS:
  INPUT: 
      i_rf_log_init_record -- Object to get the RF status
      i_client		       --  client message
  OUTPUT :
     rf.status 
  
**************************************************************************/
    FUNCTION calc_avw (
        i_client               IN                     calc_avw_client_obj
    ) RETURN rf.status AS
        rf_status     rf.status := rf.status_normal;
        l_func_name   VARCHAR2(30) := 'calc_avw';
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Calc Avw', sqlcode, sqlerrm);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Message receive from client command. Erm_id= '
                                                || i_client.erm_id
                                                || ' prod_id = '
                                                || i_client.prod_id
                                                || ' total_cases = '
                                                || i_client.total_cases
                                                || ' total_splits = '
                                                || i_client.total_splits
                                                || ' total_wt = '
                                                || i_client.total_wt
                                                || ' cust_pref_vendor = '
                                                || i_client.func1_option, sqlcode, sqlerrm);
    
            rf_status := tm_calc_total_avw(i_client);
            rf.complete(rf_status);
        RETURN rf_status;
    EXCEPTION
        WHEN OTHERS THEN
           rf.logexception();  -- log it
            RAISE;
    END calc_avw;

/*************************************************************************
  NAME:  tm_calc_total_avw

  DESC:  Calculating Total Average
  
  PARAMETERS:
  OUTPUT :
     rf.status 
**************************************************************************/

FUNCTION tm_calc_total_avw (
        i_client IN calc_avw_client_obj
    ) RETURN rf.status AS
  
   l_func_name VARCHAR2(30) := 'TM_Calc_Total_Avw';
   rf_status    rf.status := rf.STATUS_NORMAL;
   l_count            NUMBER;
   l_erm_id           tmp_weight.erm_id%TYPE;
   l_prodid           tmp_weight.prod_id%TYPE;
   l_custprefvendor   tmp_weight.cust_pref_vendor%TYPE;
   l_qty              VARCHAR2(7);
   l_weight           VARCHAR2(10); 
   l_qty_cases        VARCHAR2(8); 
   l_qty_splits       VARCHAR2(8); 
   l_case_qty         NUMBER;
   l_split_qty        tmp_weight.total_splits%TYPE;
   l_total_weight     NUMBER;
   l_user_id          VARCHAR2(20);
   l_average_wt       NUMBER;
   l_rate             NUMBER;
   l_spc              NUMBER;
   l_current_avw      putawaylst.weight%TYPE;

   
  BEGIN
    l_prodid  := i_client.prod_id;
	l_custprefvendor := i_client.cust_pref_vendor;
    l_erm_id  := i_client.erm_id; 
    l_user_id := USER;
    
    l_qty_cases  := i_client.total_cases;
    l_qty_splits := i_client.total_splits;
    l_weight 	 := i_client.total_wt;
	
    
    
	pl_text_log.ins_msg_async('INFO',l_func_name,
				   ' AA prodid = ' ||l_prodid || 
				   ' cpv  = ' 	   ||l_custprefvendor||
				   ' ermid = ' 	   ||l_erm_id||
				   ' userid = '    ||l_user_id||
				   ' qty_cases= '  ||l_qty_cases||
				   ' qty_splits= ' ||l_qty_splits||
				   ' weight= '     ||l_weight,sqlcode,sqlerrm);
			   
	BEGIN 
    
    
        SELECT avg_wt, spc INTO l_average_wt, l_spc
		FROM   pm
		WHERE  cust_pref_vendor =  l_custprefvendor
        AND    prod_id 			=  l_prodid;

	EXCEPTION
		WHEN NO_DATA_FOUND
		THEN	
			pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to fetch item from PM table',sqlcode,sqlerrm);
			rf_status := rf.STATUS_INV_PRODID;
	END;	
	
    
	BEGIN
		l_rate := pl_common.f_get_syspar('PCT_TOLERANCE','X');
  
        IF TO_CHAR(l_rate) = 'X' THEN  /*Checking pct tolerance*/
			pl_text_log.ins_msg_async('WARN',l_func_name,'Failed to fetch SYSPAR',sqlcode,sqlerrm);
			rf_status := rf.STATUS_SEL_SYSCFG_FAIL;
        END IF; /*Checking pct tolerance ends*/
	END;
     
     l_total_weight := NVL(TO_NUMBER(l_weight), 0);
     l_case_qty     := NVL(TO_NUMBER(l_qty_cases), 0) * l_spc;
     l_split_qty    := NVL(TO_NUMBER(l_qty_splits), 0);
     l_current_avw  := l_total_weight / (l_case_qty + l_split_qty);
     
	 pl_text_log.ins_msg_async('INFO',l_func_name,
                    'Current Average Weight = '||l_current_avw ||
                    ' Average Weight= '        ||l_average_wt,
                    sqlcode,sqlerrm);
   
	IF ((rf_status = rf.STATUS_NORMAL) AND (i_client.func1_option = '1')) THEN
		BEGIN
				DELETE FROM tmp_weight
                WHERE  cust_pref_vendor = l_custprefvendor
                AND    prod_id  = l_prodid
                AND    erm_id   = l_erm_id ;                
        IF SQL%ROWCOUNT = 0 THEN
              pl_text_log.ins_msg_async('WARN',l_func_name,'Deletion of Item on Po gets failed',sqlcode,sqlerrm);
        END IF;
        END;
		BEGIN
				UPDATE putawaylst
                SET    catch_wt = 'Y'
                WHERE  cust_pref_vendor = l_custprefvendor 
                AND    prod_id = l_prodid
                AND    rec_id  = l_erm_id ;
		             
                IF SQL%ROWCOUNT = 0 THEN 
					pl_text_log.ins_msg_async('WARN',l_func_name,'Updation of catch wt in Putawaylst gets failed.',sqlcode,sqlerrm);
					rf_status := rf.STATUS_ERD_UPDATE_FAIL;
                END IF; 
		EXCEPTION WHEN OTHERS THEN
               rf_status:= rf.STATUS_DATA_ERROR;
        END;
			return rf_status;
	END IF;  /*Checkinh fuctional option =1 ends*/
	
        
	IF  ((((l_average_wt * (1.0 - l_rate / 100)) <= l_current_avw) AND
           (l_current_avw <= (l_average_wt * (1.0 + l_rate / 100)))) AND
          ((((l_case_qty + l_split_qty) > 0) AND (l_current_avw > 0)) OR
           (((l_case_qty + l_split_qty) = 0) AND (l_current_avw = 0))))  THEN  
           
		   rf_status := rf.STATUS_NORMAL;
	ELSE
    	IF (i_client.func1_option = '2') THEN  /*checking func option =2 */
          rf_status := rf.status_normal;
        ELSE
          rf_status := rf.status_weight_out_of_range;
            BEGIN
                pl_event.ins_failure_event('COLLECTDATA', 'Q', 'CRIT', l_prodid, 'CRIT: COLLECTDATA: PO #= '
                                                                             || l_erm_id
                                                                             || ' Item #= '
                                                                             || l_prodid
                                                                             || ' Total weight= '
                                                                             || TO_CHAR(l_total_weight)
                                                                             || ' Total cases= '
                                                                             || TO_CHAR(l_qty_cases), 'Item '
                                                                                                      || l_prodid
                                                                                                      || ' on PO '
                                                                                                      || l_erm_id
                                                                                                      || ' is out of tolerance (weight is '
                                                                                                      || TO_CHAR(l_total_weight)
                                                                                                      || '). Please make sure it is correct.'
                                                                                                      );

            END;
        END IF;  /*checking func option =2  ends*/
    END IF;  /*Calculation check ends*/
 
    IF (rf_status = rf.status_normal) THEN  /*checking status = normal*/
        BEGIN
            UPDATE tmp_weight
            SET
                total_weight = l_total_weight,
                total_cases  = l_case_qty,
                total_splits = l_split_qty
            WHERE cust_pref_vendor = l_custprefvendor AND prod_id = l_prodid
            AND erm_id = l_erm_id;
			 
			IF SQL%rowcount = 0 THEN  
			 BEGIN
                INSERT INTO tmp_weight (
                erm_id,
                prod_id,
                cust_pref_vendor,
                total_weight,
                total_cases,
                total_splits
                 ) VALUES (
                l_erm_id,
                l_prodid,
                l_custprefvendor,
                l_total_weight,
                l_case_qty,
                l_split_qty
                );
 
             EXCEPTION
                WHEN DUP_VAL_ON_INDEX  THEN
                     pl_text_log.ins_msg_async('WARN', l_func_name, 'Insertion of new weight for item on po gets failed', sqlcode, sqlerrm);
                     rf_status := rf.status_erd_update_fail;
                WHEN OTHERS THEN
                      rf_status := rf.status_DATA_ERROR;
             END;
            END IF;
        EXCEPTION
			WHEN OTHERS THEN
				pl_text_log.ins_msg_async('WARN', l_func_name, 'Updation of new weight for item on po gets failed', sqlcode, sqlerrm);
                rf_status:= rf.status_erd_update_fail;
        END;
    END IF;   /*checking status = normal ends*/
                
    IF ((rf_status = rf.status_normal) AND (l_current_avw != 0)
                                                 AND (( l_case_qty + l_split_qty )!= 0)) THEN  /* Checking status, and quantity*/
        BEGIN
            UPDATE putawaylst
            SET
              weight   = l_current_avw,
              catch_wt = 'C'
            WHERE cust_pref_vendor = l_custprefvendor
            AND   prod_id = l_prodid
            AND   rec_id  = l_erm_id;

           IF SQL%rowcount = 0 THEN 
             pl_text_log.ins_msg_async('WARN', l_func_name, 'Updation of catchweight for item in putawaylst gets failed.', sqlcode, sqlerrm);
             rf_status := rf.status_erd_update_fail;
           END IF; 
        
        EXCEPTION
			WHEN OTHERS THEN
                rf_status:= rf.STATUS_DATA_ERROR;
        END;
    END IF;/* Checking status and quantity ends*/

	IF ((rf_status = rf.status_normal) OR (rf_status = rf.status_weight_out_of_range)) THEN 
        COMMIT;
    ELSE
        ROLLBACK;
    END IF; 

	RETURN rf_status;
  END tm_calc_total_avw;
END pl_rf_calc_avw;
/
grant execute on pl_rf_calc_avw  to swms_user;
