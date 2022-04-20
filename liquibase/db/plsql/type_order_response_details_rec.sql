/*=============================================================================================
  Types for the pl_xml_matrix_in web service
  Date           Designer         Comments
  -----------    ---------------  --------------------------------------------------------
  12-DEC-2014    sunil Ontipalli         Initial Version
  =============================================================================================*/
create or replace
TYPE order_response_details_rec FORCE AS OBJECT(
    order_id          VARCHAR2(14),
    sku               VARCHAR2(9),
    action_code       VARCHAR2(10),
    reason_code       VARCHAR2(25),
    case_quantity     NUMBER);
/

create or replace
TYPE order_response_details_table FORCE
AS TABLE OF Swms.order_response_details_rec;
/

create or replace
TYPE order_response_details_obj FORCE
AS OBJECT(order_response_details_data    order_response_details_table);
/

GRANT EXECUTE ON swms.order_response_details_rec TO swms_user;

GRANT EXECUTE ON swms.order_response_details_rec TO swms_matrix;