/*=============================================================================================
  Types for the pl_xml_matrix_in web service
  Date           Designer         Comments
  -----------    ---------------  --------------------------------------------------------
  18-NOV-2014    sunil Ontipalli         Initial Version
  =============================================================================================*/
CREATE OR REPLACE
TYPE      SWMS.PALLET_DETAILS_REC FORCE AS OBJECT(
    pallet_id            VARCHAR2(18),
    erm_id               VARCHAR2(12),
    sku                  VARCHAR2(9),
    stored_time          VARCHAR2(50),
    cases_delivered      NUMBER,
    cases_stored         NUMBER,
    cases_damaged        NUMBER,
    cases_oot            NUMBER,
    cases_wrong          NUMBER,
    cases_suspect        NUMBER);
/

create or replace
TYPE pallet_details_table FORCE
AS TABLE OF Swms.pallet_details_rec;
/

create or replace
TYPE pallet_details_obj FORCE
AS OBJECT(pallet_details_data    pallet_details_table);
/

GRANT EXECUTE ON swms.pallet_details_rec TO swms_user;

GRANT EXECUTE ON swms.pallet_details_rec TO swms_matrix;