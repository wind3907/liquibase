create or replace PACKAGE lmf
AS	
/****************************************************************************
**  This is the include file necessary for Labor Management Forklift 
**  functionality. Migrated from lmf.h
**  Called by: 
**        pl_rf_lm_common
**  Other Function declaration are not required here. 
**  It is handled in pl_lm_forklift package
******************************************************************************/
    SUBTYPE LMF is VARCHAR2(8); -- not null non-negative integer
	
	FORKLIFT_BATCH_ID            CONSTANT LMF := 'F';
	LMF_SUSPEND_BATCH            CONSTANT LMF := 'S';
	LMF_MERGE_BATCH              CONSTANT LMF := 'M';
	LMF_SIGNON_BATCH             CONSTANT LMF := 'N';
	FORKLIFT_PUTAWAY             CONSTANT LMF := 'P';
	FORKLIFT_DROP_TO_HOME        CONSTANT LMF := 'D';
	FORKLIFT_PALLET_PULL         CONSTANT LMF := 'U';
	FORKLIFT_COMBINE_PULL        CONSTANT LMF := 'B';
	FORKLIFT_DEMAND_RPL          CONSTANT LMF := 'R';
	FORKLIFT_NONDEMAND_RPL       CONSTANT LMF := 'N';
    FORKLIFT_HOME_SLOT_XFER      CONSTANT LMF := 'H';
    FORKLIFT_INV_ADJ             CONSTANT LMF := 'I';
    FORKLIFT_SWAP                CONSTANT LMF := 'S';
	FORKLIFT_TRANSFER            CONSTANT LMF := 'X';
	FORKLIFT_DMD_RPL_HS_XFER     CONSTANT LMF := 'E'; /* Putback to reserve a demand replenish that has been partially completed */
	FORKLIFT_CYCLE_COUNT         CONSTANT LMF := 'C';
    FORKLIFT_RETURNS_PUTAWAY     CONSTANT LMF := 'T';      /* Returns T batch */
    FORKLIFT_MSKU_RTN_TO_RESERVE CONSTANT LMF := 'M';  /* MSKU return to reserve batch after a NDM or DMD */
    HAUL_BATCH_ID                CONSTANT LMF := 'H';
    
    
    FUNCTION DropToHomeBatch (
        i_batch_no      IN      VARCHAR2 )
    RETURN NUMBER;
    
    FUNCTION PalletPullBatch (
        i_batch_no      IN      VARCHAR2 )
    RETURN NUMBER;
    
    FUNCTION PutawayBatch (
        i_batch_no      IN      VARCHAR2 )
    RETURN NUMBER;
    
    FUNCTION DemandReplBatch (
        i_batch_no      IN      VARCHAR2)
    RETURN NUMBER;
    
    FUNCTION NonDemandReplBatch (
        i_batch_no      IN      VARCHAR2 )
    RETURN NUMBER;
    
    FUNCTION HomeSlotBatch (
        i_batch_no      IN      VARCHAR2 )
    RETURN NUMBER;
	
END lmf;
/

create or replace PACKAGE BODY lmf IS

/******************************************************************************                                                 *
* NAME             : DropToHomeBatch                                          *
* DESCRIPTION      : To get the return value based on the FORKLIFT_BATCH_ID   *
*                    and FORKLIFT_DROP_TO_HOME for the batch no passed.       *
* Called By        : pl_rf_lm_common                                          *
* INPUT pARAMETERS :  i_batch_no (Batch no)                                   *
*                                                                             *
*RETURN VALUES     : Returns 1 or 0                                           *
*                                                                             *
* Author       Date        Ver   Description                                  *
* ------------ ----------  ----  -----------------------------------------    *
*  KRAJ9028    03/18/2020  1.0    Initial Version                             *
******************************************************************************/

FUNCTION DropToHomeBatch (
        i_batch_no      IN      VARCHAR2 )
RETURN NUMBER IS
        l_func_name VARCHAR2(50) := 'lmf.DropToHomeBatch';
        l_ret_val NUMBER := 0;
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting check_upc_data_collection', sqlcode, sqlerrm);
        IF SUBSTR(i_batch_no, 1, 1) = FORKLIFT_BATCH_ID 
            AND SUBSTR(i_batch_no, 2, 1) = FORKLIFT_DROP_TO_HOME THEN
                l_ret_val := 1;
        ELSE
            l_ret_val := 0;
        END IF;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending DropToHomeBatch with return value = ' || l_ret_val, sqlcode, sqlerrm);
        RETURN l_ret_val; 
END DropToHomeBatch;
  
/******************************************************************************                                                 *
* NAME             : PalletPullBatch                                          *
* DESCRIPTION      : To get the return value based on the FORKLIFT_BATCH_ID   *
*                    and FORKLIFT_PALLET_PULL for the batch no passed.        *
* Called By        : pl_rf_lm_common                                          *
* INPUT pARAMETERS :  i_batch_no (Batch no)                                   *
*                                                                             *
*RETURN VALUES     : Returns 1 or 0                                           *
*                                                                             *
* Author       Date        Ver   Description                                  *
* ------------ ----------  ----  -----------------------------------------    *
*  KRAJ9028    03/18/2020  1.0    Initial Version                             *
******************************************************************************/

FUNCTION PalletPullBatch (
        i_batch_no      IN      VARCHAR2 )
  RETURN NUMBER IS
  l_func_name VARCHAR2(50) := 'lmf.PalletPullBatch';
  l_ret_val NUMBER := 0;
  BEGIN
  pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting PalletPullBatch with batch# = ' || i_batch_no, sqlcode, sqlerrm);
        IF SUBSTR(i_batch_no, 1, 1) = FORKLIFT_BATCH_ID 
            AND SUBSTR(i_batch_no, 2, 1) = FORKLIFT_PALLET_PULL THEN
                l_ret_val := 1;
        ELSE
            l_ret_val := 0;
        END IF;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending PalletPullBatch with return value = ' || l_ret_val, sqlcode, sqlerrm);
        RETURN l_ret_val; 
END PalletPullBatch;

/******************************************************************************                                                 *
* NAME             : PutawayBatch                                          *
* DESCRIPTION      : To get the return value based on the FORKLIFT_BATCH_ID   *
*                    and FORKLIFT_PUTAWAY for the batch no passed.            *
* Called By        : pl_rf_lm_common                                          *
* INPUT pARAMETERS :  i_batch_no (Batch no)                                   *
*                                                                             *
*RETURN VALUES     : Returns 1 or 0                                           *
*                                                                             *
* Author       Date        Ver   Description                                  *
* ------------ ----------  ----  -----------------------------------------    *
*  KRAJ9028    03/18/2020  1.0    Initial Version                             *
******************************************************************************/

FUNCTION PutawayBatch (
        i_batch_no      IN      VARCHAR2 )
RETURN NUMBER IS
  l_func_name VARCHAR2(50) := 'lmf.PutawayBatch';
  l_ret_val NUMBER := 0;
  BEGIN
  pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting PutawayBatch with batch# = ' || i_batch_no, sqlcode, sqlerrm);
        IF SUBSTR(i_batch_no, 1, 1) = FORKLIFT_BATCH_ID 
            AND SUBSTR(i_batch_no, 2, 1) = FORKLIFT_PUTAWAY THEN
                l_ret_val := 1;
        ELSE
            l_ret_val := 0;
        END IF;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending PutawayBatch with return value = ' || l_ret_val, sqlcode, sqlerrm);
        RETURN l_ret_val; 
END PutawayBatch;

/******************************************************************************                                                 *
* NAME             : DemandReplBatch                                          *
* DESCRIPTION      : To get the return value based on the FORKLIFT_BATCH_ID   *
*                    and FORKLIFT_DEMAND_RPL for the batch no passed.         *
* Called By        : pl_rf_lm_common                                          *
* INPUT pARAMETERS :  i_batch_no (Batch no)                                   *
*                                                                             *
*RETURN VALUES     : Returns 1 or 0                                           *
*                                                                             *
* Author       Date        Ver   Description                                  *
* ------------ ----------  ----  -----------------------------------------    *
*  KRAJ9028    03/18/2020  1.0    Initial Version                             *
******************************************************************************/

FUNCTION DemandReplBatch (
        i_batch_no      IN      VARCHAR2)
RETURN NUMBER IS
  l_func_name VARCHAR2(50) := 'lmf.DemandReplBatch';
  l_ret_val NUMBER := 0;
BEGIN
  pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting DemandReplBatch with batch# = ' || i_batch_no, sqlcode, sqlerrm);
        IF SUBSTR(i_batch_no, 1, 1) = FORKLIFT_BATCH_ID 
            AND SUBSTR(i_batch_no, 2, 1) = FORKLIFT_DEMAND_RPL THEN
                l_ret_val := 1;
        ELSE
            l_ret_val := 0;
        END IF;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending DemandReplBatch with return value = ' || l_ret_val, sqlcode, sqlerrm);
        RETURN l_ret_val; 
END DemandReplBatch;

/******************************************************************************                                                 *
* NAME             : NonDemandReplBatch                                       *
* DESCRIPTION      : To get the return value based on the FORKLIFT_BATCH_ID   *
*                    and FORKLIFT_NONDEMAND_RPL for the batch no passed.      *
* Called By        : pl_rf_lm_common                                          *
* INPUT pARAMETERS :  i_batch_no (Batch no)                                   *
*                                                                             *
*RETURN VALUES     : Returns 1 or 0                                           *
*                                                                             *
* Author       Date        Ver   Description                                  *
* ------------ ----------  ----  -----------------------------------------    *
*  KRAJ9028    03/18/2020  1.0    Initial Version                             *
******************************************************************************/
    
FUNCTION NonDemandReplBatch (
        i_batch_no      IN      VARCHAR2 )
RETURN NUMBER IS
  l_func_name VARCHAR2(50) := 'lmf.NonDemandReplBatch';
  l_ret_val NUMBER := 0;
BEGIN
  pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting NonDemandReplBatch with batch# = ' || i_batch_no, sqlcode, sqlerrm);
        IF SUBSTR(i_batch_no, 1, 1) = FORKLIFT_BATCH_ID 
            AND SUBSTR(i_batch_no, 2, 1) = FORKLIFT_NONDEMAND_RPL THEN
                l_ret_val := 1;
        ELSE
            l_ret_val := 0;
        END IF;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending NonDemandReplBatch with return value = ' || l_ret_val, sqlcode, sqlerrm);
        RETURN l_ret_val; 
END NonDemandReplBatch;

/******************************************************************************                                                 *
* NAME             : HomeSlotBatch                                            *
* DESCRIPTION      : To get the return value based on the FORKLIFT_BATCH_ID   *
*                    and FORKLIFT_HOME_SLOT_XFER OR FORKLIFT_DMD_RPL_HS_XFER  *
*                    for the batch no passed.                                 *
* Called By        : pl_rf_lm_common                                          *
* INPUT pARAMETERS :  i_batch_no (Batch no)                                   *
*                                                                             *
*RETURN VALUES     : Returns 1 or 0                                           *
*                                                                             *
* Author       Date        Ver   Description                                  *
* ------------ ----------  ----  -----------------------------------------    *
*  KRAJ9028    03/18/2020  1.0    Initial Version                             *
******************************************************************************/

FUNCTION HomeSlotBatch (
        i_batch_no      IN      VARCHAR2 )
RETURN NUMBER IS
  l_func_name VARCHAR2(50) := 'lmf.HomeSlotBatch';
  l_ret_val NUMBER := 0;
BEGIN
  pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting HomeSlotBatch with batch# = ' || i_batch_no, sqlcode, sqlerrm);
        IF (SUBSTR(i_batch_no, 1, 1) = FORKLIFT_BATCH_ID 
                AND SUBSTR(i_batch_no, 2, 1) = FORKLIFT_HOME_SLOT_XFER) OR
           (SUBSTR(i_batch_no, 1, 1) = FORKLIFT_BATCH_ID 
                AND SUBSTR(i_batch_no, 2, 1) = FORKLIFT_DMD_RPL_HS_XFER) THEN
                l_ret_val := 1;
        ELSE
            l_ret_val := 0;
        END IF;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending HomeSlotBatch with return value = ' || l_ret_val, sqlcode, sqlerrm);
        RETURN l_ret_val; 
END HomeSlotBatch;

END lmf;
/

GRANT Execute on lmf to swms_user;
