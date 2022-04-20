/*=============================================================================================
  Types for the pl_xml_matrix_in web service
  Date           Designer         Comments
  -----------    ---------------  --------------------------------------------------------
  12-DEC-2014    sunil Ontipalli         Initial Version
  =============================================================================================*/
create or replace
TYPE pallet_id_list_rec FORCE AS OBJECT(
    pallet_id        VARCHAR2(18));
/

create or replace
TYPE pallet_id_list_table FORCE
AS TABLE OF Swms.pallet_id_list_rec;
/

create or replace
TYPE pallet_id_list_obj FORCE
AS OBJECT(pallet_id_list_data    pallet_id_list_table);
/

GRANT EXECUTE ON swms.pallet_id_list_rec TO swms_user;

GRANT EXECUTE ON swms.pallet_id_list_rec TO swms_matrix;