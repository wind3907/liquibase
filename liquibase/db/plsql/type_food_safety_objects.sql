/****************************************************************************
** Date:       12-NOV-2019
** File:       food_safety_objects_ddl.sql
**
**             Script for creating objects for food safety
**             server
**    - SCRIPTS
**
**    Modification History:
**    Date       Designer Comments
**    --------   -------- ---------------------------------------------------
**    12/11/19   lnic4226	  food_safety_objects_ddl.sql
**                  

****************************************************************************/

/********    client Object  ************/
create or replace TYPE fst_upd_obj FORCE AS OBJECT (
     erm_id                 VARCHAR2(12),
     door_open_datetime     VARCHAR2(30),
     trailer_front_temp     varchar2(3),
     trailer_middle_temp    varchar2(3),
     trailer_back_temp      varchar2(3),
     temp_collect_datetime  VARCHAR2(30) 
);
/

/********    server Object  ************/

create or replace TYPE fst_qry_obj FORCE AS OBJECT (
     door_open_datetime     VARCHAR2(30),
     trailer_front_temp     VARCHAR2(3),
     trailer_middle_temp    VARCHAR2(3),
     trailer_back_temp      VARCHAR2(3),
     temp_collect_datetime  VARCHAR2(30),
     door_no                VARCHAR2(4)	 
);
/

grant execute on fst_upd_obj  to swms_user;
/
grant execute on fst_qry_obj  to swms_user;
/