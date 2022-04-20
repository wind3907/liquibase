Insert Into Scripts 
(Script_Name,Application_Func,Restartable,Run_Count,Last_Run_Date,Last_Run_User,
 Update_Function,Print_Options,Display_Help,Option_No) 
Values 
('regular_batch_PND_release.sh', 'ORDER PROCESSING', 'Y', 0, Null,Null, 'Y', NULL,
'   Release the regular batch (Symbotic) from pending status, in case of symbotic not able to send batch ready (SYM05) message and update the symbotic location to SP07J1 in float_detail and float_hist table' ,
(select max(option_no)+1 from scripts));

Insert Into Scripts (Script_Name,Application_Func,Restartable,Run_Count,Last_Run_Date,Last_Run_User,Update_Function,Print_Options,Display_Help,Option_No) 
Values ('short_batch_PND_release.sh', 'ORDER PROCESSING', 'Y', 0, Null,Null, 'Y', NULL,
'   Release the short batch (Symbotic) from pending status, in case of symbotic not able to send batch ready (SYM05) message
   and update the symbotic location to SP07J1 in sos_short_detail '
   ,(select max(option_no)+1 from scripts));
   
   Insert Into Scripts (Script_Name,Application_Func,Restartable,Run_Count,Last_Run_Date,Last_Run_User,Update_Function,Print_Options,Display_Help,Option_No) 
Values ('symbotic_inv_daily_status.sh', 'INVENTORY', 'Y', 0, Null,Null, 'N', Null,
'   Status of the symbotic matrix information for inducted items and qty order for shipping for the specified date'
   ,(select max(option_no)+1 from scripts));
   
Insert Into Scripts 
(Script_Name,Application_Func,Restartable,Run_Count,Last_Run_Date,Last_Run_User,
 Update_Function,Print_Options,Display_Help,Option_No) 
Values 
('unslot_dmd.sh', 'MAINTENANCE', 'Y', 0, Null,Null, 'N', NULL,
'   This script will unslot demand status item for items has no pending tasks, no qty on hand, and no schedule POs that are scheduled within 48 hours' ,
(select max(option_no)+1 from scripts));

