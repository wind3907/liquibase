SET ECHO OFF
SET SCAN OFF
SET LINESIZE 300
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED
/*
**********************************************************************************
** Date:       30-nov-2021
** File:       R51_OPCOF_3880_dml_upd_MULTI_SPLIT_NO.sql
**
**             Script to add the columns to SEL_EQUIP
**
**    - SQL Script
**
**    To undo issue the following command. 
**      alter table SWMS.SEL_EQUIP drop column MULTI_SPLIT_NO;
**      alter table SWMS.T_CURR_BATCH drop column MULTI_SPLIT_NO;
**      alter table SWMS.T_CURR_BATCH_SHORT drop column MULTI_SPLIT_NO;
**    Modification History:
**    Date         Designer  Comments
**    -----------  --------  -----------------------------------------------------
**    02-feb-2022  kchi7065  Created
**********************************************************************************
*/

UPDATE sel_equip
SET multi_split_no = 999
WHERE multi_split_no IS NULL;

COMMIT;

