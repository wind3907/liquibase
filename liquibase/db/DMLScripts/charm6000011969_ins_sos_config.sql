---Insert into Sos_Config for SHADING_LABEL_RSTU
Insert Into Sos_Config 
(Seq_No,Warehouse_Area,Config_Flag_Name,Config_Flag_Desc,Config_Flag_Val,
  Value_Required,Value_Updateable,Value_Is_Boolean,Data_Type,Data_Precision,Sys_Config_Help) 
values 
((SELECT max(seq_no) + 1 FROM Sos_Config),'FREEZER','SHADING_LABEL_RSTU','SHADING LABELS FLOAT R-S-T-U','N',
 '1','Y','1','B',0,'No Help Description available');

Insert Into Sos_Config 
(Seq_No,Warehouse_Area,Config_Flag_Name,Config_Flag_Desc,Config_Flag_Val,
Value_Required,Value_Updateable,Value_Is_Boolean,Data_Type,Data_Precision,Sys_Config_Help) 
values 
((SELECT max(seq_no) + 1 FROM Sos_Config),'COOLER', 'SHADING_LABEL_RSTU','SHADING LABELS FLOAT R-S-T-U','N',
'1','Y','1','B',0,'No Help Description available');

Insert Into Sos_Config 
(Seq_No,Warehouse_Area,Config_Flag_Name,Config_Flag_Desc,Config_Flag_Val,
 Value_Required,Value_Updateable,Value_Is_Boolean,Data_Type,Data_Precision,Sys_Config_Help) 
Values 
((SELECT max(seq_no) + 1 FROM Sos_Config),'DRY',    'SHADING_LABEL_RSTU','SHADING LABELS FLOAT R-S-T-U','N',
 '1','Y','1','B',0,'No Help Description available');

