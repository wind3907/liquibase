------------------------------------------------------------------------------
-- File:
--    v_opcos.sql
--
-- View:
--    v_opcos
--
-- Description:
--    Project: R1 Cross docking  (Xdock)
--             Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--
--    Script to create a view of the SWMS OpCos.
--    This view created to use in the building of the ORDD.SEQ_NO as
--    the ORDD.SEQ_NO needs to be unique across OpCos for 'S' cross dock orders
--
--    The view is based on table STS_OPCO_DCID as this has all the OpCos.
--    As of 08/04/21 the table definition is:
--       Name                                      Null?    Type
--       ----------------------------------------- -------- ----------------------------
--       DCID                                               VARCHAR2(25)
--       OPCO_ID                                            VARCHAR2(25)
--       OPCO_NAME                                          VARCHAR2(500)
--       TMPLT                                              VARCHAR2(500)
--
--    The ORDD.SEQ needs to be unique at Site 2 (last mile site).
--    This is what we will do at Site 1 (fulfullment site) to ensure the ORDD.SEQ is unique at Site 2.
--    Create a 5 digit sequence called XDOCK_ORDD_SEQ
--       START WITH 10000
--       MAXVALUE   99999
--       MINVALUE   10000
--       CYCLE
--       CACHE 20
--       ORDER;
--    Create a function to return the ordd.seq for document type 'S' orders.
--    The function will return:  XDOCK_ORDD_SEQ.NEXTVAL || TO_NUMBER(LPAD(TRIM(opco#), 3, '0'))  -- opco# is the Site 1 opco number
--    The programs that insert into ORDD changed to use this function for ORDD.SEQ
--
--    In order to keep the ordd.seq unique at Site 2 between regular orders and
--    cross dock orders--either S or X--the ordd.seq for regular orders cannot end in a OpCo number.
--    So the function that returns the ordd.seq will not return an ordd.seq
--    that ends in a OpCo number for a regular order.
--    Example:
--       Site 1 OpCos are 002 and 037
--       Site 2 OpCo is 016
--       Site 2 is going to get two cross dock orders from 002 and 037.
--       Site 2 is sending one cross dock to some OpCo
--          ordd.seq from Site 1 Opco 002    ordd.seq from Site 1 Opco 027     ordd.seq Site 2 is sending out
--          ----------------------------     ------------------------------    --------------------------------
--          80001002                         80001027                          80001016
--          80002002                         80002027
--          80003002                    
--          80004002
--
--      So for regulars orders at Site 2 these values are not available to use for the ordd.seq
--      as they are used by the above cross dock orders.
--          80001002, 80001027, 80001016
--          80002002, 80002027
--          80003002                    
--          80004002
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/14/21 bben0556 Brian Bent
--                      R1 cross dock  (Xdock)
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--                      Created.
--
------------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Create view of table opcos
-- This view is what will be used in the programs for the OpCos.
--------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.v_opcos
AS
SELECT opco_id        opco_no,      -- use opco_no instead of opco_id
       opco_name      opco_name
 FROM sts_opco_dcid
/

CREATE OR REPLACE PUBLIC SYNONYM v_opcos FOR swms.v_opcos;

GRANT SELECT ON swms.v_opcos TO swms_user;
GRANT SELECT ON swms.v_opcos TO swms_viewer;

