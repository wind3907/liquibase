------------------------------------------------------------------------------
-- View:
--    v_replen_type
--
-- Description:
--    This view lists the different replenishment types.
--    It was created so that we can provide a list of values for the new
--    TRANS table column REPLEN_TYPE in the mt1ra transaction form.
--
--    Matrix replenishments have diffent types but we use RPL for the
--    transaction type.  OpCo 007 Virginia wants to know the matrix replenishment
--    type for the RPL transaction so we added the REPLEN_TYPE column to the
--    TRANS table (and OP_TRANS and MINILOAD_TRANS).  The appropriate programs
--    changed to populate TRANS.REPLEN_TYPE.
--
--    I could not find a "type" table for DMD, NDM and BLK so I used the
--    FORKLIFT_TASK_PRIORITY table.
--
--    I could not find a "type" table for the miniloader replenishment types
--    MNL and RLP so they are hardcoded here.
--
--    The matrix replenishment types are in table MX_REPLEN_TYPE which are
--    listed here.
--               TYPE DESCRIP
--               ---  ----------------------------------------
--               DSP  Demand: Matrix to Split Home
--               DXL  Demand: Reserve to Matrix
--               MRL  Manual Release: Matrix to Reserve
--               MXL  Assign Item: Home Location to Matrix
--               NSP  Non-demand: Matrix to Split Home
--               NXL  Non-demand: Reserve to Matrix
--               UNA  Unassign Item: Matrix to Main Warehouse
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/19/16 bben0556 Brian Bent
--                      Project:
--                R30.5--WIB#663--CRQ000000007533_Save_what_created_NDM_in_trans_RPL_record
--
--                      Created.
--                      Description of FORKLIFT_TASK_PRIORITY and MX_REPLEN_TYPE tables.
--
--     descr forklift_task_priority
--     Name                                      Null?    Type
--     ----------------------------------------- -------- ----------------------------
--     FORKLIFT_TASK_TYPE                        NOT NULL VARCHAR2(3 CHAR)
--     SEVERITY                                  NOT NULL VARCHAR2(16 CHAR)
--     PRIORITY                                  NOT NULL NUMBER(2)
--     REMARKS                                   NOT NULL VARCHAR2(1024 CHAR)
--     
--     descr mx_replen_type
--     Name                                      Null?    Type
--     ----------------------------------------- -------- ----------------------------
--     TYPE                                      NOT NULL VARCHAR2(3)
--     DESCRIP                                            VARCHAR2(100)
--     PRINT_LPN                                          VARCHAR2(1)
--     SHOW_TRAVEL_KEY                                    VARCHAR2(1)
--     MX_EXACT_PALLET_IMP                                VARCHAR2(4)
--   
--
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.v_replen_type
(
   replen_type,
   descrip,
   sort_group
)
AS
SELECT DISTINCT forklift_task_type,
       DECODE(forklift_task_type, 'NDM', 'Non-Demand Replenishment',
                                  'DMD', 'Demand Replenishment',
                                  'BLK', 'Bulk Pull',
                                   forklift_task_type) descrip,
       1 sort_group       -- Intended the form LOV will order by sort_group, replen_type  08/22/2016  Brian Bent Decided not to order by this in the LOV
  FROM forklift_task_priority
UNION
SELECT mx_replen_type.type,
       mx_replen_type.descrip,
       2 sort_group       -- Intended the form LOV will order by sort_group, replen_type  08/22/2016  Brian Bent Decided not to order by this in the LOV
  FROM mx_replen_type
       -- 08/19/2016  Brian Bent  Check for a rule id 5 zone so that we do not
       -- list the matrix replenishment types at opcos that do
       -- not have Symbotic.  Only Virginia has Symbotic.
 WHERE EXISTS (SELECT 'x' FROM zone WHERE rule_id = 5)
UNION
SELECT 'MNL',
       'Miniloader Replenishment',
       3 sort_group       -- Intended the form LOV will order by sort_group, replen_type 08/22/2016  Brian Bent Decided not to order by this in the LOV
  FROM DUAL
UNION
SELECT 'RLP',
       'Miniloader Replenishment Put Back to Reserve',
       3 sort_group       -- Intended the form LOV will order by sort_group, replen_type 08/22/2016  Brian Bent Decided not to order by this in the LOV
  FROM DUAL
/


CREATE OR REPLACE PUBLIC SYNONYM v_replen_type
FOR swms.v_replen_type
/

GRANT SELECT ON v_replen_type TO swms_user;
GRANT SELECT ON v_replen_type TO swms_viewer;

