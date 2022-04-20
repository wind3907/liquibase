/******************************************************************
*  JIRA 3523 Create LR LM batches
*   
*
******************************************************************/ 

DECLARE
	v_row_count_CR NUMBER := 0;
	v_row_count_DR NUMBER := 0;
	v_row_count_FR NUMBER := 0;
BEGIN


    SELECT COUNT(*)
    INTO  v_row_count_cr
    FROM  swms.job_code
    WHERE jbcd_job_code = 'CRCLIV'
    and LFUN_LBR_FUNC = 'LR';
    
 
	IF v_row_count_cr = 0 THEN
        
		Insert into JOB_CODE (JBCD_JOB_CODE,JBCL_JOB_CLASS,LFUN_LBR_FUNC,WHAR_AREA,ENGR_STD_FLAG,MASK_LVL,DESCRIP,CORP_CODE,TMU_DOC_TIME,TMU_CUBE,TMU_WT,TMU_NO_PIECE,TMU_NO_PALLET,TMU_NO_ITEM,TMU_NO_DATA_CAPTURE,TMU_NO_PO,TMU_NO_STOP,TMU_NO_ZONE,TMU_NO_LOC,TMU_NO_CASE,TMU_NO_SPLIT,TMU_NO_MERGE,TMU_NO_AISLE,TMU_NO_DROP,TMU_ORDER_TIME,EXP_PERF,TMU_NO_CART,TMU_NO_PALLET_PIECE,TMU_NO_CART_PIECE,SN_RCV_JBCD,TMU_NO_SHORT,TMU_NO_CLAM_BED_DATA_CAPTURE,TMU_WALK,TMU_WALK_EQUIPMENT,EXCLUDE_GOAL_CALC) 
		              values ('CRCLIV','CM','LR','C','Y',1,'CLR LIVE-RECEIVERS',null,null,null,null,null,456,null,null,null,null,null,null,null,null,null,null,null,null,null,100,null,null,null,null,null,null,null,null);

	
	END IF;
	
	SELECT COUNT(*)
    INTO  v_row_count_dr
    FROM  swms.job_code
    WHERE jbcd_job_code = 'DRCLIV'
    and LFUN_LBR_FUNC = 'LR';
    
 
	IF v_row_count_dr = 0 THEN
        
		Insert into JOB_CODE (JBCD_JOB_CODE,JBCL_JOB_CLASS,LFUN_LBR_FUNC,WHAR_AREA,ENGR_STD_FLAG,MASK_LVL,DESCRIP,CORP_CODE,TMU_DOC_TIME,TMU_CUBE,TMU_WT,TMU_NO_PIECE,TMU_NO_PALLET,TMU_NO_ITEM,TMU_NO_DATA_CAPTURE,TMU_NO_PO,TMU_NO_STOP,TMU_NO_ZONE,TMU_NO_LOC,TMU_NO_CASE,TMU_NO_SPLIT,TMU_NO_MERGE,TMU_NO_AISLE,TMU_NO_DROP,TMU_ORDER_TIME,EXP_PERF,TMU_NO_CART,TMU_NO_PALLET_PIECE,TMU_NO_CART_PIECE,SN_RCV_JBCD,TMU_NO_SHORT,TMU_NO_CLAM_BED_DATA_CAPTURE,TMU_WALK,TMU_WALK_EQUIPMENT,EXCLUDE_GOAL_CALC)
   		              values ('DRCLIV','DM','LR','D','Y',1,'DRY LIVE-RECEIVERS',null,null,null,null,null,471,null,null,null,null,null,null,null,null,null,null,null,null,null,100,null,null,null,null,null,null,null,null);
	
	END IF;
	
	SELECT COUNT(*)
    INTO  v_row_count_fr
    FROM  swms.job_code
    WHERE jbcd_job_code = 'FRCLIV'
    and LFUN_LBR_FUNC = 'LR';	
	
	IF v_row_count_fr = 0 THEN
        
		Insert into JOB_CODE (JBCD_JOB_CODE,JBCL_JOB_CLASS,LFUN_LBR_FUNC,WHAR_AREA,ENGR_STD_FLAG,MASK_LVL,DESCRIP,CORP_CODE,TMU_DOC_TIME,TMU_CUBE,TMU_WT,TMU_NO_PIECE,TMU_NO_PALLET,TMU_NO_ITEM,TMU_NO_DATA_CAPTURE,TMU_NO_PO,TMU_NO_STOP,TMU_NO_ZONE,TMU_NO_LOC,TMU_NO_CASE,TMU_NO_SPLIT,TMU_NO_MERGE,TMU_NO_AISLE,TMU_NO_DROP,TMU_ORDER_TIME,EXP_PERF,TMU_NO_CART,TMU_NO_PALLET_PIECE,TMU_NO_CART_PIECE,SN_RCV_JBCD,TMU_NO_SHORT,TMU_NO_CLAM_BED_DATA_CAPTURE,TMU_WALK,TMU_WALK_EQUIPMENT,EXCLUDE_GOAL_CALC)
                	  values ('FRCLIV','FM','LR','F','Y',1,'FRZ LIVE-RECEIVERS',null,null,null,null,null,586,null,null,null,null,null,null,null,null,null,null,null,null,null,100,null,null,null,null,null,null,null,null);
	
	END IF;
    
    commit;
END;
/