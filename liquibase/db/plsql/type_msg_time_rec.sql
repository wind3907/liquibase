/*=============================================================================================
  Types for the pl_xml_matrix_in web service
  Date           Designer         Comments
  -----------    ---------------  --------------------------------------------------------
  03-SEP-2014    sunil Ontipalli         Initial Version
  =============================================================================================*/
create or replace
TYPE msg_time_rec FORCE AS OBJECT(
        message_id          VARCHAR2(30),
        time_stamp          VARCHAR2(50));
/

create or replace
TYPE msg_time_table FORCE 
AS TABLE OF Swms.msg_time_rec;
/

create or replace
TYPE msg_time_obj FORCE 
AS OBJECT(msg_meta_data msg_time_table);
/

GRANT EXECUTE ON swms.msg_time_rec TO swms_user;

GRANT EXECUTE ON swms.msg_time_rec TO swms_matrix;