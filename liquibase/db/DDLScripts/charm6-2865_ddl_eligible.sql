spool /tmp/charm_6000002865_ddl_mx_item_eligible.lis

CREATE TABLE MX_FOOD_TYPE
( MX_FOOD_TYPE          VARCHAR2(8) not null,
  DESCRIPTION           VARCHAR2(30),
  SLOT_TYPE             VARCHAR2(3),
  MX_DAYS_ROTATE_ALLOW  NUMBER(3),
  MX_DEFAULT_LOCATION   VARCHAR2(10),
  CONSTRAINT MX_FOOD_TYPE_PK PRIMARY KEY (MX_FOOD_TYPE));

GRANT all on MX_FOOD_TYPE to swms_user;
CREATE or replace public synonym MX_FOOD_TYPE for swms.MX_FOOD_TYPE;

create table mx_hazardous_type (HAZARDOUS_TYPE  VARCHAR2(20) not null,
                                QUALIFY_FOR_MX  VARCHAR2(1) not null,
                                DESCRIPTION     VARCHAR2(50));

alter table mx_hazardous_type add (constraint mx_hazardous_type_pk
                                   primary key (hazardous_type));

GRANT all on mx_hazardous_type to swms_user;
CREATE or replace public synonym mx_hazardous_type for swms.mx_hazardous_type;


CREATE TABLE MX_PACKAGE_TYPE
(PM_CONTAINER           VARCHAR2(4) not null,
 PACKAGE_TYPE           VARCHAR2(10),
 constraint mx_package_type_pk primary key (pm_container));

GRANT all on MX_PACKAGE_TYPE to swms_user;
CREATE or replace public synonym MX_PACKAGE_TYPE for swms.MX_PACKAGE_TYPE;


alter table PM ADD
(MX_MAX_CASE            number(4),
 MX_MIN_CASE            number(4),
 MX_ELIGIBLE            varchar2(1),
 MX_ITEM_ASSIGN_FLAG    varchar2(1),
 MX_STABILITY_CALC      number(7,3),
 MX_STABILITY_FLAG      varchar2(3),
 MX_FOOD_TYPE           varchar2(8),
 MX_UPC_PRESENT_FLAG    varchar2(1),
 MX_MASTER_CASE_FLAG    varchar2(1),
 MX_PACKAGE_TYPE        varchar2(10),
 MX_WHY_NOT_ELIGIBLE     varchar2(2000),
 MX_HAZARDOUS_TYPE      varchar2(20),
 MX_STABILITY_RECALC    number(7,3),
 MX_MULTI_UPC_PROBLEM   varchar2(1),
 MX_DESIGNATE_SLOT      varchar2(15));

 alter table swms.pm add 
 (wsh_begin_date       date, 
  wsh_avg_invs         number, 
  wsh_ship_movements   number, 
  wsh_hits             number,
  expected_case_on_po  number,
  diagonal_measurement number,
  recalc_length        number,
  recalc_width         number,
  recalc_height        number);


CREATE TABLE MX_CONFIG_ELIGIBLE
(CONFIG_NAME            varchar2(30) not null,
 CONFIG_DESCRIPTION     varchar2(50),
 CONFIG_VALUE           varchar2(30) not null,
constraint mx_config_eligible_pk primary key (CONFIG_NAME));

GRANT all on MX_CONFIG_ELIGIBLE to swms_user;
CREATE or replace public synonym MX_CONFIG_ELIGIBLE for swms.MX_CONFIG_ELIGIBLE;

spool off;
