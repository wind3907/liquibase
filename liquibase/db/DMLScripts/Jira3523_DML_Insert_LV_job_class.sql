/******************************************************************
*  JIRA 3523 Create LR LM batches
*   
*
******************************************************************/ 

DECLARE
	v_row_count_1 NUMBER := 0;
	v_row_count_2 NUMBER := 0;
	v_row_count_3 NUMBER := 0;

BEGIN
    
    SELECT COUNT(*)
    INTO  v_row_count_1
    FROM  swms.job_class
    WHERE jbcl_job_class = 'CM';
 
 
	IF v_row_count_1 = 0 THEN        
		Insert into JOB_CLASS (JBCL_JOB_CLASS,DESCRIP) values ('CM','Cooler Live-Receiving');	
	END IF;

    SELECT COUNT(*)
    INTO  v_row_count_2
    FROM  swms.job_class
    WHERE jbcl_job_class = 'DM';
 
 
	IF v_row_count_2 = 0 THEN        
		Insert into JOB_CLASS (JBCL_JOB_CLASS,DESCRIP) values ('DM','Dry Live-Receiving');	
	END IF;

    SELECT COUNT(*)
    INTO  v_row_count_3
    FROM  swms.job_class
    WHERE jbcl_job_class = 'FM';
 
 
	IF v_row_count_3 = 0 THEN        
		Insert into JOB_CLASS (JBCL_JOB_CLASS,DESCRIP) values ('FM','Freezer Live-Receiving');	
	END IF;	
    
    commit;
END;
/