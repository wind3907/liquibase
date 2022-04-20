
--*****************************************************************
-- SCE012-Enhancement Check Trailer and Product Temperatures
-- Script to add four new columns to the ERM table
--*****************************************************************

Insert into DATA_CONF(FLD_NAME,FLD_LABEL,HELP_MESSAGE) Values ('FREEZER_TEMP','Freezer Temperature','Freezer Temperature');

Insert into DATA_CONF(FLD_NAME,FLD_LABEL,HELP_MESSAGE) Values ('COOLER_TEMP','Cooler Temperature','Cooler Temperature');

--*****************************************************************
-- SCE014 - Finalize Goods Receipt in SWMS Receiving shortages, Overages and Damage
-- 1. Modification of view 'v_prp1sc' to include a new column reason code in the 
-- select statement 
-- 2. Script to delete any existing 'DOS' records if present in the REASON_CDS table
-- 3. Script to insert the new records into the REASON_CDS table with the reason code 
	  type as DOS
-- 4. Script to insert a new record of the reason code type 'DOS' into the REASON_CD_TYPES 
      table
-- SCI003 - Goods Receipt Data from SWMS to SAP 
-- 5. Updated the reason codes O,S,D and Q for SCI003.
--*****************************************************************
-- Table changes 

--1) Script to delete any existing 'DOS' records if present in the REASON_CDS table

Delete from REASON_CDS where REASON_CD_TYPE = 'DOS';

--2) Script to insert the new records into the REASON_CDS table with the reason code type as DOS

Insert into REASON_CDS(REASON_CD_TYPE, REASON_CD, REASON_DESC, RESALE, REASON_GROUP, MISC, CC_REASON_CODE) values
('DOS', 'O', 'Overage', null, null , 'N', 'O');

Insert into REASON_CDS(REASON_CD_TYPE, REASON_CD, REASON_DESC, RESALE, REASON_GROUP, MISC, CC_REASON_CODE) values 
('DOS', 'S', 'Shortage', null, null , 'N', 'S');

Insert into REASON_CDS(REASON_CD_TYPE, REASON_CD, REASON_DESC, RESALE, REASON_GROUP, MISC, CC_REASON_CODE) values 
('DOS', 'D', 'Damage', null, null , 'N', 'D');

Insert into REASON_CDS(REASON_CD_TYPE, REASON_CD, REASON_DESC, RESALE, REASON_GROUP, MISC, CC_REASON_CODE) values 
('DOS', 'Q', 'Quality', null, null , 'N', 'Q');

--3) Script to insert a new record of the reason code type 'DOS' into the REASON_CD_TYPES table

Insert into REASON_CD_TYPES values('DOS','Damage, Overage and Shortage');

--*****************************************************************
-- SCE015-Generate forced replenishment
-- Script to add 
--*****************************************************************
-- Table changes 
Insert into TRANS_TYPE Values ('RPF', 'Forced Replenishment',55,'N');

--*****************************************************************
-- SCE066- Add Flags to SWMS for Alfmark and BSCC
-- Script to update two tables
--*****************************************************************

Insert into DATA_CONF(FLD_NAME,FLD_LABEL,HELP_MESSAGE) Values ('CARRIER_ID','Carrier Id','Carrier Identification');

Update DATA_CONF
Set FLD_LABEL = 'BSCC',
    HELP_MESSAGE = 'BSCC'
Where FLD_NAME = 'FREIGHT'
  And Exists(Select 1 
               From SYS_CONFIG 
              Where CONFIG_FLAG_NAME='HOST_TYPE' 
                And CONFIG_FLAG_VAL='SAP');
--*****************************************************************
-- SCE020- Non-Inventory Asset Tracking In STS
-- Script to insert 3 records in to print_reports table for printing sql reports
--*****************************************************************
--1) Script to insert a new record in to print_reports table for printing the report slstrb.sql
Insert into print_reports(report,queue_type,descrip,command,fifo,filter,copies,duplex) values
('slstrb','SQLP','Returns Non - Inventory Accessory Report Details - by Customer','runsqlrpt -c :c :p/:f :r','N','','1','N');

--2) Script to insert a new record in to print_reports table for printing the report slstrc.sql
Insert into print_reports(report,queue_type,descrip,command,fifo,filter,copies,duplex) values
('slstrc','SQLP','Returns Non - Inventory Accessory Report Details - by Ship Date','runsqlrpt -c :c :p/:f :r','N','','1','N');       

--3) Script to insert a new record in to print_reports table for printing the report slstrd.sql
Insert into print_reports(report,queue_type,descrip,command,fifo,filter,copies,duplex) values
('slstrd','SQLP','Returns Non - Inventory Accessory Exception Report Details','runsqlrpt -c :c :p/:f :r','N','','1','N'); 

--*****************************************************************
-- SCE016- Set Resale flags to Y for select ADJ reason codes
-- Script to update reason_cds table  
--*****************************************************************

Update REASON_CDS 
Set RESALE='Y' 
Where REASON_CD_TYPE = 'ADJ' 
And REASON_CD in ('WH','SP','TD','SR');


--*****************************************************************
-- SCE047- Print manifest report in swms 
--*****************************************************************
--1) Script to insert a new record in to print_reports table for printing the report mf1ra

Insert into print_reports(report,queue_type,descrip,command,fifo,filter,copies,duplex) values
('mf1ra','SQLP','Manifest Document','mf1ra -c :c -t :t -u :u -o :p/:f :r','Y','1',1,'N');


--*****************************************************************
-- SCE085 - Non-FIFO non demand replenishment and AWM changes 
-- Script to add a new column demand_flag to PUTAWAYLST Table
--*****************************************************************
Insert into sys_config (SEQ_NO,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,
                        VALUE_REQUIRED,VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,DATA_TYPE,DATA_PRECISION,
                        DATA_SCALE,SYS_CONFIG_LIST,SYS_CONFIG_HELP, VALIDATION_TYPE
                        ) values (344,'INVENTORY CONTROL','NON_DEMAND_REPLENISHMENT_ORDER','Sort order for ND replen','N',
                        'Y','Y','N','CHAR',1,0,'L','Order by expiry date for ndm replen A-for all items D-for date tracked items N-no sort on expiry date', 'LIST');

Insert into sys_config_valid_values(CONFIG_FLAG_NAME, CONFIG_FLAG_VAL,DESCRIPTION) Values('NON_DEMAND_REPLENISHMENT_ORDER', 'A','All items');

Insert into sys_config_valid_values(CONFIG_FLAG_NAME, CONFIG_FLAG_VAL,DESCRIPTION) Values('NON_DEMAND_REPLENISHMENT_ORDER', 'D','Date Tracked Items Only');

Insert into sys_config_valid_values(CONFIG_FLAG_NAME, CONFIG_FLAG_VAL,DESCRIPTION) Values('NON_DEMAND_REPLENISHMENT_ORDER', 'N','No sort by exp date');

