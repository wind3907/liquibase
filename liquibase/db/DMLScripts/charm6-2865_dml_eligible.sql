spool /tmp/Charm_6000002865_DML_Insert_Eligible.lis
--------INSERT STATEMENT FOR MX_FOOD_TYPE
INSERT INTO MX_FOOD_TYPE
(MX_FOOD_TYPE,DESCRIPTION,	MX_DAYS_ROTATE_ALLOW,SLOT_TYPE,MX_DEFAULT_LOCATION)
VALUES
('FOOD',      'FOOD ITEMS'		,0	    ,'MXF'    ,'LX00R9');
INSERT INTO MX_FOOD_TYPE
(MX_FOOD_TYPE,DESCRIPTION,	MX_DAYS_ROTATE_ALLOW,SLOT_TYPE,MX_DEFAULT_LOCATION)
VALUES
('NON_FOOD',   'NON-FOOD ITEMS'		,0	    ,'MXF'    ,'LX00R9');
INSERT INTO MX_FOOD_TYPE
(MX_FOOD_TYPE,DESCRIPTION,	MX_DAYS_ROTATE_ALLOW,SLOT_TYPE,MX_DEFAULT_LOCATION)
VALUES
('CAUSTIC',     'CAUSTIC ITEMS'		,3	    ,'MXC'    ,'LX00R9');

--------INSERT STATEMENT FOR mx_hazardous_type

insert into mx_hazardous_type
(hazardous_type,qualify_for_mx,description)
values
('FLAMMABLE','N','Flammable Item');

insert into mx_hazardous_type
(hazardous_type,qualify_for_mx,description)
values
('EXPANDED_FOAM','N','Foam expanded');

insert into mx_hazardous_type
(hazardous_type,qualify_for_mx,description)
values
('NOT_HAZARDOUS','Y','Non-Hazardous Item');

insert into mx_hazardous_type
(hazardous_type,qualify_for_mx,description)
values
('AEROSOL','N','Aerosol Chemical');

--------INSERT STATEMENT FOR mx_package_type

insert into mx_package_type (pm_container,package_type) values 
('12','12 CASE');
insert into mx_package_type (pm_container,package_type) values 
('4C','QTR CASE');
insert into mx_package_type (pm_container,package_type) values 
('5C','5TH CASE');
insert into mx_package_type (pm_container,package_type) values 
('7C','7TH CASE');
insert into mx_package_type (pm_container,package_type) values 
('8C','8TH CASE');
insert into mx_package_type (pm_container,package_type) values 
('BG','BAG');
insert into mx_package_type (pm_container,package_type) values 
('BN','BIN');
insert into mx_package_type (pm_container,package_type) values 
('BU','BUSHEL');
insert into mx_package_type (pm_container,package_type) values 
('BX','BOX/CASE');
insert into mx_package_type (pm_container,package_type) values 
('CS','BOX/CASE');
insert into mx_package_type (pm_container,package_type) values 
('DR','DRUM');
insert into mx_package_type (pm_container,package_type) values 
('EA','EACH');
insert into mx_package_type (pm_container,package_type) values 
('FC','FULL CASE');
insert into mx_package_type (pm_container,package_type) values 
('HC','HALF CASE');
insert into mx_package_type (pm_container,package_type) values 
('PL','PAIL');
insert into mx_package_type (pm_container,package_type) values 
('PR','PAIR');
insert into mx_package_type (pm_container,package_type) values 
('RL','ROLL');
insert into mx_package_type (pm_container,package_type) values 
('TB','TUB');
insert into mx_package_type (pm_container,package_type) values 
('TK','TANK');
insert into mx_package_type (pm_container,package_type) values 
('TN','TIN');
insert into mx_package_type (pm_container,package_type) values 
('UN','UNIT');

insert into mx_config_eligible (config_name,config_description,config_value)
values ('WEIGHT_NORMALIZER','Weight Normalizer to calculate Stability','100');
insert into mx_config_eligible (config_name,config_description,config_value)
values ('STABILITY_LIMIT','Weight Normalizer to calculate Stability','1.6');
insert into mx_config_eligible (config_name,config_description,config_value)
values ('DIAGONAL_MEASUREMENT','Diagonal Measurement','32');
--
insert into mx_config_eligible (config_name,config_description,config_value)
values ('MIN_CASE_LENGTH','Weight Normalizer to calculate Stability','6.4');
insert into mx_config_eligible (config_name,config_description,config_value)
values ('MAX_CASE_LENGTH','Weight Normalizer to calculate Stability','24');
--
insert into mx_config_eligible (config_name,config_description,config_value)
values ('MIN_CASE_WIDTH','Weight Normalizer to calculate Stability','5');
insert into mx_config_eligible (config_name,config_description,config_value)
values ('MAX_CASE_WIDTH','Weight Normalizer to calculate Stability','23');
--
insert into mx_config_eligible (config_name,config_description,config_value)
values ('MIN_CASE_HEIGHT','Weight Normalizer to calculate Stability','2');
insert into mx_config_eligible (config_name,config_description,config_value)
values ('MAX_CASE_HEIGHT','Weight Normalizer to calculate Stability','28');

insert into mx_config_eligible (config_name,config_description,config_value)
values ('MIN_CASE_WEIGHT','Weight Normalizer to calculate Stability','2');
insert into mx_config_eligible (config_name,config_description,config_value)
values ('MAX_CASE_WEIGHT','Weight Normalizer to calculate Stability','88');

update swms.pm 
 set mx_why_not_eligible = decode(auto_ship_flag,'Y','Ship Split Only NOT Eligible;',mx_why_not_eligible),
     mx_eligible = decode(auto_ship_flag,'Y','N',mx_eligible)
where area='D';

update pm
set mx_min_case = 1, mx_max_case=999
where area='D' and mx_min_case is null and mx_max_case is null;


insert into print_reports
   (report, queue_type, descrip,
    command, fifo, filter, copies, duplex)
values
   ('mi1rf', 'SQLP', 'Item Eligible Maintenance Report',
    'runsqlrpt -c :c :p/:f :r', 'N', NULL, 1, 'N');



