/****************************************************************************
** Date:       08-NOV-2019
** File:       process_msku_objects_ddl.sql
**
**             Script for creating table objects for Process Msku
**             client and server
**    - SCRIPTS
**
**    Modification History:
**    Date       Designer Comments
**    --------   -------- ---------------------------------------------------
**    08/11/13   KRAJ9028  process_msku_objects_ddl.sql
**                  

****************************************************************************/

/********    Client Objects and Table  ************/
create or replace TYPE add_lptype_list_obj1 FORCE AS OBJECT (
    pallet_id   VARCHAR2(18),
    type        VARCHAR2(2)
);
/
create or replace type  add_lptype_list_result_table force as table of  add_lptype_list_obj1; 
/
create or replace type  add_lptype_list_result_obj FORCE AS OBJECT ( result_table add_lptype_list_result_table );
/
grant execute on add_lptype_list_obj1 to swms_user;
grant execute on add_lptype_list_result_table  to swms_user;
grant execute on add_lptype_list_result_obj to swms_user;
/


/********    Server Objects and Table  ************/
create or replace TYPE add_lp_list_obj1 FORCE AS OBJECT (
    prod_id           VARCHAR2(9),
    pallet_id         VARCHAR2(18),
    cust_pref_vendor  VARCHAR2(10)
);
/
create or replace type  add_lp_list_result_table force as table of  add_lp_list_obj1;  
/
create or replace type  add_lp_list_result_obj FORCE AS OBJECT ( result_table add_lp_list_result_table );
/

grant execute on add_lp_list_obj1  to swms_user;
grant execute on add_lp_list_result_table to swms_user;
grant execute on add_lp_list_result_obj  to swms_user;
/

