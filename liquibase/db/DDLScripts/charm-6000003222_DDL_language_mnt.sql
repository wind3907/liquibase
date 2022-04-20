create table FORMS_XREF_LOCATION
(FORM_NAME      varchar2(30) not null,
 DESCRIPTION    varchar2(100),
 MENU_FORM_PATH varchar2(500),
 MENU_1         varchar2(40),
 MENU_2         varchar2(40),
 MENU_3         varchar2(40),
 MENU_4         varchar2(40),
 MENU_5         varchar2(40),
 MENU_6         varchar2(40),
 MENU_7         varchar2(40),
 MENU_8         varchar2(40),
 MENU_9         varchar2(40),
 MENU_10        varchar2(40),
 MOUSE_ENABLED  varchar2(1));

alter table FORMS_XREF_LOCATION add
( constraint FORMS_XREF_LOCATION_PK
  primary key (form_name));

grant all on FORMS_XREF_LOCATION to public;
create or replace public synonym FORMS_XREF_LOCATION for swms.FORMS_XREF_LOCATION;

create table swms.ml_functionality
(id_functionality number NOT NULL,
 description      varchar2(100) NOT NULL,
 CONSTRAINT pk_ml_functionality
 PRIMARY KEY (id_functionality));

create or replace public synonym ml_functionality for swms.ml_functionality;
grant all on swms.ml_functionality to swms_user;

