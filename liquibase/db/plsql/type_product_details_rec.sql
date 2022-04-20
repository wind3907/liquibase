/*=============================================================================================
  Types for the pl_xml_matrix_in web service
  Date           Designer         Comments
  -----------    ---------------  --------------------------------------------------------
  14-NOV-2014    sunil Ontipalli         Initial Version
  =============================================================================================*/
create or replace
TYPE product_details_rec FORCE AS OBJECT(
    task_id          VARCHAR2(10),
    sku              VARCHAR2(9),
    pallet_id        VARCHAR2(18),
    case_quantity    NUMBER);
/

create or replace
TYPE product_details_table FORCE
AS TABLE OF Swms.product_details_rec;
/

create or replace
TYPE product_details_obj FORCE
AS OBJECT(product_details_data    product_details_table);
/

GRANT EXECUTE ON swms.product_details_rec TO swms_user;

GRANT EXECUTE ON swms.product_details_rec TO swms_matrix;