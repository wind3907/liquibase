REM Updating STS_TEMPLATES old template names
update sts_templates
set TNAME = 'temp_talex'
where TNAME = 'temp_tale';
update sts_templates
set TNAME = 'temp_engx'
where TNAME = 'temp_eng';
update sts_templates
set TNAME = 'temp_engkx'
where TNAME = 'temp_engk';
update sts_templates
set TNAME = 'temp_fre2x'
where TNAME = 'temp_fre2';
REM INSERTING into STS_TEMPLATES
SET DEFINE OFF;
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',1,'Inputs',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',2,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',3,'Type','PreTrip');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',4,'Name','Pre Trip Readings');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',5,'AllCases','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',6,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',7,'Description','Trailer Cooler Temp');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',8,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',9,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',10,'LowLimit','26');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',11,'ProductIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',12,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',13,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',14,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',15,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',16,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',17,'Description','Trailer Freezer Temp');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',18,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',19,'HighLimit','32');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',20,'LowLimit','-10');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',21,'ProductIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',22,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',23,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',24,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',25,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',26,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',27,'Description','Training Route?');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',28,'FieldType','Q');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',29,'ProductIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',30,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',31,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',32,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',33,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',34,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',35,'Description','Team Route?');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',36,'FieldType','Q');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',37,'ProductIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',38,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',39,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',40,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',41,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',42,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',43,'Description','2nd Driver - Enter 0 if None');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',44,'FieldType','A');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',45,'FieldFormat','8');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',46,'ProductIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',47,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',48,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',49,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',50,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',51,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',52,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',53,'Type','CompartmentStart');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',54,'Name','Compartment Readings');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',55,'AllCases','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',56,'Compartment','C');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',57,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',58,'Description','Cooler Item Temp');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',59,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',60,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',61,'LowLimit','26');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',62,'ProductIndicator','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',63,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',64,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',65,'AlwaysPrompt','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',66,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',67,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_eng',68,'Inputs','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',1,'Inputs ',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',2,'Event ',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',3,'Type ','PreTrip');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',4,'Name ','Pre Trip Readings');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',5,'Input ',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',6,'Description','Trailer Cooler Temp');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',7,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',8,'FieldFormat','2.1');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',9,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',10,'LowLimit','26');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',11,'ProductIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',12,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',13,'UnattendedIndicator ',' ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',14,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',15,'Input ','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',16,'Input ',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',17,'Description','Trailer Freezer Temp');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',18,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',19,'FieldFormat','2.1');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',20,'HighLimit','32');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',21,'LowLimit','-10');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',22,'ProductIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',23,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',24,'UnattendedIndicator',' ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',25,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',26,'Input ','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',27,'Input ',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',28,'Description','Training Route?');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',29,'FieldType','Q');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',30,'ProductIndicatorr ','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',31,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',32,'UnattendedIndicator',' ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',33,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',34,'Input ','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',35,'Input ',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',36,'Description','Team Route?');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',37,'FieldType','Q');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',38,'ProductIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',39,'LinkToPrevIndicator ','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',40,'UnattendedIndicator',' ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',41,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',42,'Input ','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',43,'Input ',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',44,'Description','2nd Driver - Enter 0 if None');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',45,'FieldType','A');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',46,'FieldFormat','8');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',47,'ProductIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',48,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',49,'UnattendedIndicator ',' ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',50,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',51,'Input ','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',52,'Event ','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',53,'Event ',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',54,'Type','StopStart');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',55,'Name ','Unattended Stop');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',56,'Input ',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',57,'Description','Invoice');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',58,'UnattendedIndicator','U');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',59,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',60,'Input ','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',61,'Input ',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',62,'Description','Cooler or Frozen Temp1');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',63,'UnattendedIndicator','U');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',64,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',65,'FieldFormat','2.1');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',66,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',67,'LowLimit','-10');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',68,'ProductIndicator','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',69,'Input ','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',70,'Input ',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',71,'Description','Cooler or Frozen Temp2');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',72,'UnattendedIndicator','U');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',73,'FieldType ','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',74,'FieldFormat','2.1');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',75,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',76,'LowLimit','-10');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',77,'ProductIndicator','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',78,'Input ','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',79,'Event ','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_engk',80,'Inputs ','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',1,'Inputs',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',2,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',3,' Type','PreTrip');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',4,' Name','Lecture avant le dpart');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',5,' AllCases','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',6,' Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',7,'Description','Temp. Remorq. Frais');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',8,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',9,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',10,'LowLimit','26');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',11,'ProductIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',12,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',13,'UnattendedIndicator',' ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',14,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',15,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',16,' Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',17,'Description','Temp. Remorq. Surg.');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',18,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',19,'HighLimit','32');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',20,'LowLimit','-10');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',21,'ProductIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',22,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',23,'UnattendedIndicator',' ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',24,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',25,' Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',26,' Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',27,'Description','Itineraire de formation?');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',28,'FieldType','Q');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',29,'ProductIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',30,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',31,'UnattendedIndicator',' ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',32,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',33,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',34,' Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',35,'Description','Itineraire d''equipe?');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',36,'FieldType','Q');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',37,'ProductIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',38,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',39,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',40,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',41,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',42,' Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',43,'Description','2eme conducteur - Entrez 0 si aucun');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',44,'FieldType','A');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',45,'FieldFormat','8');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',46,'ProductIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',47,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',48,'UnattendedIndicator',' ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',49,'AlwaysPrompt','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',50,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',51,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',52,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',53,'Type','StopStart');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',54,'Name','Lecture des sections');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',55,'AllCases','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',56,'Compartment','C');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',57,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',58,'Description','Temp. Produits frais');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',59,'FieldType','N');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',60,'HighLimit','40');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',61,'LowLimit','26');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',62,'ProductIndicator','TRUE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',63,'LinkToPrevIndicator','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',64,'UnattendedIndicator',' ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',65,'AlwaysPrompt','FALSE');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',66,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',67,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_fre2',68,'Inputs','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',1,'Inputs',null);
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
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',21,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',22,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',23,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',24,'AlwaysPrompt','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',25,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',26,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',27,'Description','Training Route?');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',28,'FieldType','Q');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',29,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',30,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',31,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',32,'AlwaysPrompt','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',33,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',34,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',35,'Description','Team Route?');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',36,'FieldType','Q');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',37,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',38,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',39,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',40,'AlwaysPrompt','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',41,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',42,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',43,'Description','2nd Driver - Enter 0 if None');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',44,'FieldType','A');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',45,'FieldFormat','8');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',46,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',47,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',48,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',49,'AlwaysPrompt','true');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',50,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',51,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',52,'Event',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',53,'Type','StopStart');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',54,'Name','Cooler Compartment');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',55,'AllCases','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',56,'Input',null);
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',57,'Description','Temp Tale Alarmed');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',58,'FieldType','Q');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',59,'ProductIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',60,'LinkToPrevIndicator','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',61,'UnattendedIndicator','  ');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',62,'AlwaysPrompt','false');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',63,'AlarmOnResponse','Yes');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',64,'AlarmMessage','Temp Control Measures Ensure reefer is
 running during remaining stops where allowable.
Set the cooler zone to 32F. Close bulkheads and doors
whenever possible, Break coolerfreezer bulkhead
6 during travel to next stop');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',65,'Input','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',66,'Event','/');
Insert into STS_TEMPLATES (TNAME,SEQUENCE_NO,TAG_NAME,TAG_VALUE) values ('temp_tale',67,'Inputs','/');
