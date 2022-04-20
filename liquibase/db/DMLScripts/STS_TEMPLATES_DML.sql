/****************************************************************************
** File:       STS_TEMPLATES_DML.sql
**
** Desc: Script to insert  data for sts templates
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    24-Oct-2018 Vishnupriya K.     setup data for sts templates
**    
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM STS_TEMPLATES;
  

IF (v_column_exists = 0)  THEN


--REM INSERTING into STS_TEMPLATES 
--SET DEFINE OFF; 
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',1,'Inputs',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',2,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',3,'Type','PreTrip');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',4,'Name','Pre Trip Readings');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',5,'AllCases','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',6,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',7,'Description','Trailer Cooler Temp');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',8,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',9,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',10,'LowLimit','26');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',11,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',12,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',13,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',14,'AlwaysPrompt','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',15,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',16,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',17,'Description','Trailer Freezer Temp');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',18,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',19,'HighLimit','32');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',20,'LowLimit','-10');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',21,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',22,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',23,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',24,'AlwaysPrompt','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',25,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',26,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',27,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',28,'Type','CompartmentStart');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',29,'Name','Compartment Readings');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',30,'AllCases','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',31,'Compartment','C');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',32,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',33,'Description','Cooler Item Temp');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',34,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',35,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',36,'LowLimit','26');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',37,'ProductIndicator','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',38,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',39,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',40,'AlwaysPrompt','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',41,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',42,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',43,'Inputs','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',1,'Inputs',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',2,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',3,'Type','PreTrip');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',4,'Name','Lecture avant le dpart');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',5,'AllCases','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',6,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',7,'Description','Temp. Remorq. Frais');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',8,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',9,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',10,'LowLimit','26');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',11,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',12,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',13,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',14,'AlwaysPrompt','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',15,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',16,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',17,'Description','Temp. Remorq. Surg.');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',18,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',19,'HighLimit','32');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',20,'LowLimit','-10');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',21,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',22,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',23,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',24,'AlwaysPrompt','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',25,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',26,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',27,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',28,'Type','StopStart');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',29,'Name','Lecture des sections');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',30,'AllCases','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',31,'Compartment','C');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',32,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',33,'Description','Temp. Produits frais');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',34,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',35,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',36,'LowLimit','26');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',37,'ProductIndicator','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',38,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',39,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',40,'AlwaysPrompt','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',41,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',42,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',43,'Inputs','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',1,'Inputs',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',2,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',3,'Type','PreTrip');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',4,'Name','Lecture avant le dpart');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',5,'AllCases','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',6,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',7,'Description','Temp. Remorq. Frais');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',8,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',9,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',10,'LowLimit','26');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',11,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',12,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',13,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',14,'AlwaysPrompt','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',15,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',16,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',17,'Description','Temp. Remorq. Surg.');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',18,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',19,'HighLimit','32');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',20,'LowLimit','-10');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',21,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',22,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',23,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',24,'AlwaysPrompt','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',25,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',26,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',27,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',28,'Type','CompartmentStart');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',29,'Name','Lecture des sections');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',30,'AllCases','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',31,'Compartment','C');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',32,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',33,'Description','Temp. Produits frais');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',34,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',35,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',36,'LowLimit','26');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',37,'ProductIndicator','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',38,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',39,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',40,'AlwaysPrompt','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',41,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',42,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre',43,'Inputs','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',1,'Inputs',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',21,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',22,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',23,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',24,'AlwaysPrompt','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',25,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',26,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',27,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',28,'Type','StopStart');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',29,'Name','Cooler Compartment');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',30,'AllCases','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',31,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',32,'Description','Temp Tale Alarmed');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',33,'FieldType','Q');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',34,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',35,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',36,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',37,'AlwaysPrompt','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',38,'AlarmOnResponse','Yes');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',39,'AlarmMessage','Temp Control Measures Ensure reefer is
 running during remaining stops where allowable. 
Set the cooler zone to 32F. Close bulkheads and doors 
whenever possible, Break coolerfreezer bulkhead 
6 during travel to next stop');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',40,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',41,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',42,'Inputs','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',2,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',3,'Type','PreTrip');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',4,'Name','Pre Trip Readings');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',5,'AllCases','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',6,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',7,'Description','Trailer Cooler Temp');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',8,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',9,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',10,'LowLimitLowLimit','26');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',11,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',12,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',13,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',14,'AlwaysPrompt','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',15,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',16,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',17,'Description','Trailer Freezer Temp');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',18,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',19,'HighLimit','32');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',20,'LowLimit','-10');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',1,'Inputs',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',2,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',3,'Type','PreTrip');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',4,'Name','Pre Trip Readings');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',5,'AllCases','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',6,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',7,'Description','Trailer Cooler Temp');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',8,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',9,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',10,'LowLimit','26');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',11,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',12,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',13,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',14,'AlwaysPrompt','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',15,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',16,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',17,'Description','Trailer Freezer Temp');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',18,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',19,'HighLimit','32');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',20,'LowLimit','10');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',21,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',22,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',23,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',24,'AlwaysPrompt','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',25,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',26,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',27,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',28,'Type','StopStart');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',29,'Name','Compartment Readings');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',30,'AllCases','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',31,'Compartment','C');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',32,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',33,'Description','Cooler Item Temp');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',34,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',35,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',36,'LowLimit','26');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',37,'ProductIndicator','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',38,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',39,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',40,'AlwaysPrompt','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',41,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',42,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng2',43,'Inputs','/');

commit;
                         
End If;
End;			
/				  