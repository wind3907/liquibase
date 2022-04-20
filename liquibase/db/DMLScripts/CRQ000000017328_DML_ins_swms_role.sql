

insert into swms_role 
(ROLE_NAME,DESCRIP,ADD_DATE,ADD_USER,UPD_DATE,UPD_USER)
values ('INV_CNTRL','SWMS INV CONTROL',sysdate,user,sysdate,user);
update usr set role_name='INV_CNTRL' where role_name like 'Inv Cntl';

delete from swms_role where role_name like 'Inv Cntl';

REM insert into swms_role values ('CORP_APPDEV','CORP USERS',sysdate,user,sysdate,user);
REM insert into swms_role values ('CORP_USER','CORP USERS',sysdate,user,sysdate,user);
REM insert into swms_role values ('OPERATIONS_REVIEW','OPERATIONS_REVIEW',sysdate,user,sysdate,user);
REM insert into swms_role values ('CUSTOMER_SUPPORT_GROUP','CUSTOMER_SUPPORT_GROUP',sysdate,user,sysdate,user);

insert into swms_role 
(ROLE_NAME,DESCRIP,ADD_DATE,ADD_USER,UPD_DATE,UPD_USER)
values ('INBOUND_OUTBOUND_CLERK','INBOUND OUTBOUND CLERK',sysdate,user,sysdate,user);
update usr set role_name='INBOUND_OUTBOUND_CLERK' where role_name like 'INBOUND_OUT%';
delete from swms_role where role_name = 'INBOUND/OUTBOUND CLERKS';


insert into swms_role 
(ROLE_NAME,DESCRIP,ADD_DATE,ADD_USER,UPD_DATE,UPD_USER)
values ('CORP_ACCOUNT_ADMIN','CORPORATE ACCOUNT ADMIN',sysdate,user,sysdate,user);
update usr set role_name='CORP_ACCOUNT_ADMIN' where role_name = 'CORP_ACCT_ADMIN';
delete from swms_role where role_name = 'CORP_ACCT_ADMIN';

insert into swms_role 
(ROLE_NAME,DESCRIP,ADD_DATE,ADD_USER,UPD_DATE,UPD_USER)
values ('COORDINATOR','SWMS COORDINATOR',sysdate,user,sysdate,user);
insert into swms_role 
(ROLE_NAME,DESCRIP,ADD_DATE,ADD_USER,UPD_DATE,UPD_USER)
values ('INV_CNTRL_MGR','INVENTORY CONTROL MANAGER',sysdate,user,sysdate,user);
insert into swms_role 
(ROLE_NAME,DESCRIP,ADD_DATE,ADD_USER,UPD_DATE,UPD_USER)
values ('WAREHOUSE','WAREHOUSE USER',sysdate,user,sysdate,user);
insert into swms_role 
(ROLE_NAME,DESCRIP,ADD_DATE,ADD_USER,UPD_DATE,UPD_USER)
values ('WAREHOUSE_MGMT','WAREHOUSE MANAGEMENT',sysdate,user,sysdate,user);
insert into swms_role 
(ROLE_NAME,DESCRIP,ADD_DATE,ADD_USER,UPD_DATE,UPD_USER)
values ('ROUTER','ROUTER',sysdate,user,sysdate,user);
insert into swms_role 
(ROLE_NAME,DESCRIP,ADD_DATE,ADD_USER,UPD_DATE,UPD_USER)
values ('IMAGING_ASSOCIATE','IMAGING ASSOCIATE',sysdate,user,sysdate,user);
insert into swms_role 
(ROLE_NAME,DESCRIP,ADD_DATE,ADD_USER,UPD_DATE,UPD_USER)
values ('YARD_SPOTTER','YARD SPOTTER',sysdate,user,sysdate,user);

update swms_role
 set CORP_USR_FLG=null;

update swms_role
 set CORP_USR_FLG='Y'
where role_name like 'CORP%'
or role_name = 'CUST_SUPP_GROUP';

update swms_role
 set CORP_APPDEV_FLAG = 'Y'
where role_name = 'CORP_APPDEV';

