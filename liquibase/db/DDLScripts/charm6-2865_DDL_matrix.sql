--
-- September 2014
-- Main Symbotic DML script.
--
-- 11/18/2014 Brian Bent
-- Add order processing changes.
--


ALTER TABLE REPLENLST ADD
(MX_BATCH_NO            number(9),
 CASE_NO                varchar2(14),
 PRINT_LPN              varchar2(1));

ALTER TABLE rules add (MAINTAINABLE VARCHAR2(1));

ALTER TABLE inv ADD (MX_XFER_TYPE   VARCHAR2(3));

-- drop sequence swms.rf_log_sequence;
create sequence swms.rf_log_sequence cache 20 order;
create or replace public synonym rf_log_sequence for swms.rf_log_sequence;

--
-- 11/18/2014  Brian Bent
-- Ended this statement with "/" instead of ";" because of unexpected behavior
-- using ";" when the objects already existed.  When using ";" this statement
-- and all the following statements were not processed.  Using "/" the
-- following error is diplayed and all the following statments processed.
--
--ERROR at line 1:
--ORA-22866: cannot replace a type with table dependents
--
create or replace type swms.rf_log_init_record force as object(
    device          varchar2(20),
    application     varchar2(10),
    mac_address     varchar2(17),   -- eg. 00-15-70-f3-17-8f
    ap_mac_address  varchar2(17),
    culture_name    varchar2(12),   -- in Microsoft .Net format, eg. "fr-CA", "es-ES_tradnl", or blank
    sequence        number(9),      -- client transaction sequence number
    resending       varchar2(1)     -- Y or N
)
/

grant execute on swms.rf_log_init_record to swms_user;

-- drop table swms.rf_log;

create table swms.rf_log (
    add_date            timestamp with local time zone
                                        not null,   -- from CURRENT_TIMESTAMP built-in
    msg_seq             number          not null,   -- from swms.rf_log_sequence
    user_id             varchar2(30)    not null,   -- from USER built-in
    ip_address          varchar2(45),               -- can handle ipv6 formatted addresses if necessary
    sid                 number,                     -- from v$session and sys_context('userenv','sid')
    serial#             number,                     -- from v$session
    caller_owner        varchar2(30),               -- from owa_util.who_called_me
    caller_name         varchar2(30),               -- from owa_util.who_called_me
    caller_lineno       number,                     -- from owa_util.who_called_me
    caller_caller_t     varchar2(30),               -- from owa_util.who_called_me
    rf_status           number(5),                  -- rf.STATUS
    event               varchar2(10)    not null,   -- rf.LOG_EVENT_APP_MSG, etc.
    msg_priority        varchar2(8)     not null,   -- rf.LOG_INFO, rf.LOG_WARNING, etc.
    msg_text            varchar2(2048)  not null,   -- caller supplied
    init_record         swms.rf_log_init_record
);

grant all on swms.rf_log to swms_user;
create or replace public synonym rf_log for swms.rf_log;

-- drop sequence swms.rf_msg_sequence;
create sequence swms.rf_msg_sequence cache 20 order;
create or replace public synonym rf_msg_sequence for swms.rf_msg_sequence;


/* drop constraint first, else drop table will fail ORA-02449 */

--alter table swms.rf_msg_status drop constraint fk_msg_seq;

-- drop table swms.rf_msg;
create table swms.rf_msg (
    msg_seq             number          not null,   -- from swms.rf_msg_sequence
    msg_text            varchar2(256)   not null,   -- caller supplied
    add_date            date            not null,   -- from CURRENT_TIMESTAMP built-in
    add_user            varchar2(30)    not null,   -- from USER built-in; this is also the msg 'sender'
    primary key(msg_seq)
);

grant all on swms.rf_msg to swms_user;
create or replace public synonym rf_msg for swms.rf_msg;


--drop table swms.rf_msg_status;
create table swms.rf_msg_status (
    msg_seq             number          not null,   -- foreign key
    to_user             varchar2(30)    not null,   -- receiver of msg
    when_sent           date,                       -- NULL if not yet sent
    constraint fk_msg_seq
        foreign key(msg_seq)
        references swms.rf_msg(msg_seq)
        on delete cascade
);

grant all on swms.rf_msg_status to swms_user;
create or replace public synonym rf_msg_status for swms.rf_msg_status;

CREATE TABLE SWMS.MATRIX_TASK_PRIORITY
(
      MATRIX_TASK_TYPE VARCHAR2(3 CHAR) NOT NULL,
      SEVERITY VARCHAR2(16 CHAR) NOT NULL,
      PRIORITY NUMBER(2) NOT NULL,
      REMARKS VARCHAR2(1024 CHAR),
      PRIMARY KEY(MATRIX_TASK_TYPE, SEVERITY)
);

grant all on SWMS.MATRIX_TASK_PRIORITY to swms_user;
create or replace public synonym MATRIX_TASK_PRIORITY for swms.MATRIX_TASK_PRIORITY;

--DROP TABLE MATRIX_IN;

CREATE TABLE SWMS.MATRIX_IN
  (
    SEQUENCE_NUMBER       NUMBER(10)       NOT NULL,
  MX_MSG_ID             VARCHAR2(30)       NOT NULL,
  INTERFACE_REF_DOC     VARCHAR2(10)       NOT NULL,
  REC_IND               VARCHAR2(1)        NOT NULL,
  REC_COUNT             NUMBER(3),
  RECORD_STATUS         VARCHAR2(1)        NOT NULL,
  ADD_DATE              DATE               DEFAULT SYSDATE               NOT NULL,
  ADD_USER              VARCHAR2(30)       DEFAULT USER                  NOT NULL,
  UPD_DATE              DATE               DEFAULT SYSDATE,
  UPD_USER              VARCHAR2(30)       DEFAULT USER,
  PROD_ID               VARCHAR2(9),
  ERM_ID                VARCHAR2(10),
  PARENT_PALLET_ID      VARCHAR2(18),
  PALLET_ID             VARCHAR2(18),
  MX_REASON_CODE        VARCHAR2(3),
  CASE_QTY              NUMBER(7),
  QTY_STORED            NUMBER(7),
  SPUR_LOC              VARCHAR2(10),
  ORDER_TYPE            VARCHAR2(10),
  SELECTION_REL_SEQ     NUMBER(10),
  BATCH_ID              VARCHAR2(14),
  ORDER_ID              VARCHAR2(14),
  TASK_ID               NUMBER(10),
  RELEASE_TYPE          VARCHAR2(15),
  QTY_INDUCTED          NUMBER(10),
  QTY_DAMAGED           NUMBER(10),
  QTY_OUT_OF_TOLERANCE  NUMBER(10),
  QTY_WRONG_ITEM        NUMBER(10),
  QTY_SHORT             NUMBER(10),
  QTY_OVER              NUMBER(10),
  STORED_TIME           TIMESTAMP(6),
  MSG_TIME              TIMESTAMP(6),
  ERROR_MSG             VARCHAR2(100),
  ERROR_CODE            VARCHAR2(100),
  TRANS_TYPE            VARCHAR2(3),
  SEQUENCE_TIMESTAMP    TIMESTAMP(6),
  CASE_BARCODE          VARCHAR2(20),
  SKIP_REASON           VARCHAR2(10),
  ACTION_CODE           VARCHAR2(10),
  REASON_CODE           VARCHAR2(25),
  LANE_ID               NUMBER,
  LAST_CASE             VARCHAR2(1),
  DIVERT_TIME           TIMESTAMP(6),
  LABEL_TYPE            VARCHAR2(4),
  MESSAGE_NAME          VARCHAR2(25),
  SYMBOTIC_STATUS       VARCHAR2(25),
  FILE_NAME             VARCHAR2(50),
  FILE_TIMESTAMP        TIMESTAMP(6),
  ROW_COUNT             NUMBER,
  INTERFACE_TYPE        VARCHAR2(10),
  USER_ID               VARCHAR2(20),
  CELL_ID               VARCHAR2(20),
  EVENT_TIMESTAMP       TIMESTAMP(6),
  REWORKED_QTY          NUMBER,
  VERIFIED_QTY          NUMBER,
  REJECTED_QTY          NUMBER
  );

grant all on SWMS.MATRIX_IN to swms_user;
grant all on SWMS.MATRIX_IN to swms_mx;
create or replace public synonym MATRIX_IN for SWMS.MATRIX_IN;

--DROP SEQUENCE MATRIX_IN_SEQ;

CREATE SEQUENCE MATRIX_IN_SEQ
MINVALUE 1000
MAXVALUE 99999999999
ORDER
START WITH 1000
INCREMENT BY 1;

create or replace public synonym MATRIX_IN_SEQ for SWMS.MATRIX_IN_SEQ;

--DROP TABLE MATRIX_OUT;

CREATE TABLE SWMS.MATRIX_OUT
(
  SEQUENCE_NUMBER           NUMBER(10)     NOT NULL,
  SYS_MSG_ID                VARCHAR2(10)   NOT NULL,
  INTERFACE_REF_DOC         VARCHAR2(10)   NOT NULL,
  REC_IND                   VARCHAR2(1)    NOT NULL,
  REC_COUNT                 NUMBER,
  RECORD_STATUS             VARCHAR2(1)    NOT NULL,
  ADD_DATE                  DATE           DEFAULT SYSDATE               NOT NULL,
  ADD_USER                  VARCHAR2(30)   DEFAULT USER                  NOT NULL,
  UPD_DATE                  DATE           DEFAULT NULL,
  UPD_USER                  VARCHAR2(30)   DEFAULT NULL,
  PRIORITY                  NUMBER,
  PROD_ID                   VARCHAR2(10),
  PARENT_PALLET_ID          VARCHAR2(18),
  PALLET_ID                 VARCHAR2(18),
  BATCH_ID                  VARCHAR2(14),
  WAVE_NUMBER               NUMBER,
  ROUTE                     VARCHAR2(10),
  STOP                      NUMBER(7,2),
  BATCH_COMPLETE_TIMESTAMP  VARCHAR2(50),
  BATCH_STATUS              VARCHAR2(20),
  ORDER_ID                  VARCHAR2(14),
  ORDER_TYPE                VARCHAR2(3),
  TRANS_TYPE                VARCHAR2(3),
  LABEL_TYPE                VARCHAR2(4),
  EXPIRATION_DATE           DATE,
  SPUR_LOC                  VARCHAR2(10),
  CASE_BARCODE              VARCHAR2(20),
  CASE_GRAB_TIMESTAMP       VARCHAR2(50),
  NON_SYM_HEAVY_CASE_COUNT  NUMBER,
  NON_SYM_LIGHT_CASE_COUNT  NUMBER,
  ORDER_SEQUENCE            NUMBER,
  PRIORITY_IDENTIFIER       NUMBER,
  CASE_QTY                  NUMBER(7),
  ERM_ID                    VARCHAR2(10),
  INV_STATUS                VARCHAR2(3),
  ORDER_GENERATION_TIME     VARCHAR2(50),
  TASK_ID                   VARCHAR2(10),
  FLOAT_ID                  NUMBER,
  CUSTOMER_ROTATION_RULES   VARCHAR2(10),
  DESTINATION_LOC           VARCHAR2(10),
  EXACT_PALLET_IMP          VARCHAR2(4),
  ERROR_MSG                 VARCHAR2(2000),
  ERROR_CODE                VARCHAR2(100),
  FILE_NAME                 VARCHAR2(50),
  FILE_TIMESTAMP            VARCHAR2(50)
);

grant all on SWMS.MATRIX_OUT to swms_user;
grant all on SWMS.MATRIX_OUT to swms_mx;
create or replace public synonym MATRIX_OUT for SWMS.MATRIX_OUT;

--DROP SEQUENCE MATRIX_OUT_SEQ;

CREATE SEQUENCE MATRIX_OUT_SEQ
MINVALUE 1000
MAXVALUE 99999999999
ORDER
START WITH 1000
INCREMENT BY 1;

create or replace public synonym MATRIX_OUT_SEQ for SWMS.MATRIX_OUT_SEQ;

--DROP TABLE MATRIX_PM_OUT;

CREATE TABLE SWMS.MATRIX_PM_OUT
  (
    SEQUENCE_NUMBER         NUMBER(10,0)      NOT NULL ENABLE,
    SYS_MSG_ID              VARCHAR2(10)      NOT NULL ENABLE,
    INTERFACE_REF_DOC       VARCHAR2(10)      NOT NULL ENABLE,
    REC_IND                 VARCHAR2(1)       NOT NULL ENABLE,
    REC_COUNT               NUMBER(3,0),
    RECORD_STATUS           VARCHAR2(1)       NOT NULL ENABLE,
    ADD_DATE                DATE              DEFAULT SYSDATE NOT NULL ENABLE,
    ADD_USER                VARCHAR2(30)      DEFAULT USER NOT NULL ENABLE,
    UPD_DATE                DATE              DEFAULT NULL,
    UPD_USER                VARCHAR2(30)      DEFAULT NULL,
    FUNC_CODE               VARCHAR2(1),
    PROD_ID                 VARCHAR2(9),
    DESCRIPTION             VARCHAR2(50),
    WAREHOUSE_AREA          VARCHAR2(1),
    PACK                    VARCHAR2(4),
    PROD_SIZE               VARCHAR2(6),
    PROD_SIZE_UNIT          VARCHAR2(3),
    SLOTTING_FLAG           VARCHAR2(15),
    CASE_LENGTH             NUMBER,
    CASE_WIDTH              NUMBER,
    CASE_HEIGHT             NUMBER,
    WEIGHT                  NUMBER(9,3),
    PACK_SIZE               NUMBER,
    UPC_PRESENT_FLAG        VARCHAR2(1),
    UPC                     VARCHAR2(15),
    PROBLEM_CASE_UPC_FLAG   VARCHAR2(1),
    HAZARDOUS_TYPE          VARCHAR2(20),
    FOOD_TYPE               VARCHAR2(8), 
    MX_SEL_ELIGIBILITY_FLAG VARCHAR2(1),
    MX_ITEM_ASSIGN_FLAG     VARCHAR2(1),
    CUSTOMER_ROT_RULE_FLAG  VARCHAR2(1),
    EXPIRATION_WINDOW       NUMBER,
    SKU_TIP_FLAG            VARCHAR2(3),
    ERROR_MSG               VARCHAR2(2000),
    ERROR_CODE              VARCHAR2(100)
  );

grant all on SWMS.MATRIX_PM_OUT to swms_user;
grant all on SWMS.MATRIX_PM_OUT to swms_mx;
create or replace public synonym MATRIX_PM_OUT for SWMS.MATRIX_PM_OUT;

--DROP SEQUENCE MATRIX_PM_OUT_SEQ;

CREATE SEQUENCE MATRIX_PM_OUT_SEQ
MINVALUE 1000
MAXVALUE 99999999999
ORDER
START WITH 1000
INCREMENT BY 1;

create or replace public synonym MATRIX_PM_OUT_SEQ for SWMS.MATRIX_PM_OUT_SEQ;

CREATE TABLE SWMS.MATRIX_PM_BULK_OUT
(
  SEQUENCE_NUMBER           NUMBER(10)     NOT NULL,
  SYS_MSG_ID                VARCHAR2(10)   NOT NULL,
  REC_IND                   VARCHAR2(1)    NOT NULL,
  ADD_DATE                  DATE           DEFAULT SYSDATE       NOT NULL,
  ADD_USER                  VARCHAR2(30)   DEFAULT USER          NOT NULL,
  UPD_DATE                  DATE           DEFAULT NULL,
  UPD_USER                  VARCHAR2(30)   DEFAULT NULL,
  PROD_ID                   VARCHAR2(10),
  DESCRIPTION               VARCHAR2(30),
  AREA                      VARCHAR2(1),
  PACK                      VARCHAR2(4),
  PROD_SIZE                 VARCHAR2(6),
  PROD_SIZE_UNIT            VARCHAR2(3),
  MX_DESIGNATE_SLOT         VARCHAR2(15),
  CASE_LENGTH               NUMBER,
  CASE_WIDTH                NUMBER,
  CASE_HEIGHT               NUMBER,
  CASE_WEIGHT               NUMBER,
  MX_UPC_PRESENT_FLAG       VARCHAR2(5),
  UPC                       VARCHAR2(14),
  MX_MULTI_UPC_PROBLEM      VARCHAR2(5),
  MX_HAZARDOUS_TYPE         VARCHAR2(20),
  MX_FOOD_TYPE              VARCHAR2(8),
  MX_ELIGIBLE               VARCHAR2(5),
  EXPIRATION_WINDOW         NUMBER,
  MX_TIP_OVER_FLAG          VARCHAR2(5)
);

grant all on SWMS.MATRIX_PM_BULK_OUT to swms_user;
grant all on SWMS.MATRIX_PM_BULK_OUT to swms_mx;
create or replace public synonym MATRIX_PM_BULK_OUT for SWMS.MATRIX_PM_BULK_OUT;

--DROP SEQUENCE MATRIX_PM_BULK_OUT_SEQ;

CREATE SEQUENCE MATRIX_PM_BULK_OUT_SEQ
MINVALUE 1000
MAXVALUE 99999999999
START WITH 1000
INCREMENT BY 1;

create or replace public synonym MATRIX_PM_BULK_OUT_SEQ for SWMS.MATRIX_PM_BULK_OUT_SEQ;

CREATE TABLE SWMS.MATRIX_INV_BULK_IN
(
  SEQUENCE_NUMBER           NUMBER(10)     NOT NULL,
  MX_MSG_ID                 VARCHAR2(10)   NOT NULL,
  REC_IND                   VARCHAR2(1)    NOT NULL,
  RECORD_STATUS             VARCHAR2(1)    NOT NULL,
  ADD_DATE                  DATE           DEFAULT SYSDATE       NOT NULL,
  ADD_USER                  VARCHAR2(30)   DEFAULT USER          NOT NULL,
  UPD_DATE                  DATE           DEFAULT NULL,
  UPD_USER                  VARCHAR2(30)   DEFAULT NULL,
  PROD_ID                   VARCHAR2(10),
  PALLET_ID                 VARCHAR2(18),
  CASE_QUANTITY             VARCHAR2(3),
  INV_STATUS                VARCHAR2(3),
  PRODUCT_DATE              VARCHAR2(50)               
);

grant all on SWMS.MATRIX_INV_BULK_IN to swms_user;
grant all on SWMS.MATRIX_INV_BULK_IN to swms_mx;
create or replace public synonym MATRIX_INV_BULK_IN for SWMS.MATRIX_INV_BULK_IN;

CREATE SEQUENCE MATRIX_INV_BULK_IN_SEQ
MINVALUE 1000
MAXVALUE 99999999999
START WITH 1000
INCREMENT BY 1;

create or replace public synonym MATRIX_INV_BULK_IN_SEQ for SWMS.MATRIX_INV_BULK_IN_SEQ;

CREATE TABLE matrix_interface_maint
(
interface_name     VARCHAR2(10),
description        VARCHAR2(30),
package_proc       VARCHAR2(50),
staging_table      VARCHAR2(30),
active_flag        VARCHAR2(1),
add_date           DATE DEFAULT SYSDATE,
add_user           VARCHAR2(30) DEFAULT USER,
upd_date           DATE DEFAULT NULL,
upd_user           VARCHAR2(30) DEFAULT NULL
);

grant all on SWMS.matrix_interface_maint to swms_user;
grant all on SWMS.matrix_interface_maint to swms_mx;
create or replace public synonym matrix_interface_maint for SWMS.matrix_interface_maint;

CREATE SEQUENCE MX_SYS_MSG_ID_SEQ
MINVALUE 1000
MAXVALUE 99999999999
START WITH 1000
INCREMENT BY 1;

create or replace public synonym MX_SYS_MSG_ID_SEQ for SWMS.MX_SYS_MSG_ID_SEQ;


--DROP SEQUENCE mx_batch_no_seq;

CREATE SEQUENCE mx_batch_no_seq 
MINVALUE 1000
MAXVALUE 99999999999
START WITH 1000
INCREMENT BY 1;


CREATE OR REPLACE PUBLIC SYNONYM mx_batch_no_seq for swms.mx_batch_no_seq;
GRANT SELECT ON mx_batch_no_seq to swms_user;

--DROP TABLE mx_replen_type;

CREATE TABLE mx_replen_type
(type                 VARCHAR2(3),
 descrip              VARCHAR2(100),
 print_lpn            VARCHAR2(1),
 show_travel_key      VARCHAR2(1),
 mx_exact_pallet_imp  VARCHAR2(4),
 PRIMARY KEY(type)
 );
 
CREATE OR REPLACE PUBLIC SYNONYM mx_replen_type FOR swms.mx_replen_type;
GRANT ALL ON SWMS.mx_replen_type TO swms_user;
 
--DROP TABLE tmp_usrdnldtasks;

CREATE GLOBAL TEMPORARY TABLE tmp_usrdnldtasks(task_id          NUMBER(10),
                                               type             VARCHAR2(3),
                                               src_loc          VARCHAR2(10),
                                               dest_loc         VARCHAR2(10),
                                               pallet_id        VARCHAR2(18),
                                               priority         NUMBER(2),
                                               qty              NUMBER (7),
                                               prod_id          VARCHAR2(9),
                                               ti               NUMBER(4),
                                               hi               NUMBER(4),
                                               cust_pref_vendor VARCHAR2(10),
                                               descrip          VARCHAR2(30),
                                               mfg_sku          VARCHAR2(14),
                                               truck_no         VARCHAR2(10),
                                               door_no          NUMBER(4),
                                               drop_qty         NUMBER(7),
                                               s_pikpath        NUMBER(9),
                                               d_pikpath        NUMBER(9),
                                               route_batch_no   NUMBER,
                                               seq_no           NUMBER(4),
                                               exp_date         DATE,
                                               case_no          VARCHAR2(14),
                                               mx_batch_no      NUMBER(9),
                                               print_lpn        VARCHAR2(1),
                                               logi_loc         VARCHAR2(10),
                                               brand            VARCHAR2(7),
                                               pallet_type      VARCHAR2(2),
                                               uom              NUMBER(2),
                                               erm_id           VARCHAR2(12),
                                               erm_date         DATE,
                                               spc              NUMBER(4),
                                               pack             VARCHAR2(4),
                                               prod_size        VARCHAR2(6),
                                               show_travel_key  VARCHAR2(1));

CREATE OR REPLACE PUBLIC SYNONYM tmp_usrdnldtasks for swms.tmp_usrdnldtasks;
GRANT ALL ON tmp_usrdnldtasks to swms_user;    


CREATE TABLE SWMS.MATRIX_OUT_LABEL
  (
    SEQUENCE_NUMBER         NUMBER,
    BARCODE                 VARCHAR2(20),
    PRINT_STREAM            CLOB,
        ENCODED_PRINT_STREAM    CLOB
  );
  
grant all on SWMS.MATRIX_OUT_LABEL to swms_user;
grant all on SWMS.MATRIX_OUT_LABEL to swms_mx;
create or replace public synonym MATRIX_OUT_LABEL for SWMS.MATRIX_OUT_LABEL;

ALTER TABLE swms.slot_type 
ADD calculate_loc_heights_flag VARCHAR2(1) DEFAULT 'Y' NOT NULL;

ALTER TABLE swms.slot_type
ADD CONSTRAINT check_loc_heights_flag
  CHECK (calculate_loc_heights_flag IN ('Y', 'N'));
  
ALTER TABLE SOS_BATCH ADD (PRIORITY NUMBER(2) DEFAULT 2);
ALTER TABLE SOS_BATCH_HIST ADD (PRIORITY NUMBER(2));
  
--DROP TABLE SOS_batch_priority;

CREATE TABLE SOS_batch_priority
(priority_code   VARCHAR2(10),
 priority_value  NUMBER(2),
 description     VARCHAR2(50),
 PRIMARY KEY (priority_code)
 );
 
CREATE OR REPLACE PUBLIC SYNONYM SOS_batch_priority for swms.SOS_batch_priority;

GRANT ALL ON swms.SOS_batch_priority to SWMS_USER;  

--DROP TABLE sos_short_detail;

CREATE TABLE sos_short_detail
(
    batch_no             VARCHAR2(7)  NOT NULL,
    orderseq             NUMBER(8)    NOT NULL,
    picktype             VARCHAR2(2)  NOT NULL,
    location             VARCHAR2(6)  NOT NULL,
    case_barcode         VARCHAR2(20) NOT NULL,
    short_reason         VARCHAR2(8)  NOT NULL,
        float_no             NUMBER(9),
    float_detail_seq_no  NUMBER(3),
        pick_location        VARCHAR2(6),
        pallet_id            VARCHAR2(18)
);

CREATE UNIQUE INDEX SWMS.XPKSOS_SHORT_DETAIL ON SWMS.SOS_SHORT_DETAIL
( orderseq, location, picktype, case_barcode);

CREATE OR REPLACE PUBLIC SYNONYM sos_short_detail FOR swms.sos_short_detail;

GRANT ALL ON sos_short_detail to SWMS_USER;


---------------------------------------------------------------
---------------------------------------------------------------
-- Start Order Processing
---------------------------------------------------------------
---------------------------------------------------------------
--
-- New Sequences:
--    - mx_release_order_seq   
--         This sequence is used to mark the order the matrix releases
--         the batches.  By release we mean the batch is
--         available for a selector to download.
--         This sequence is used to populate column SOS_BATCH.MX_RELEASE_SEQ.
--         Script "swms_move_pik_trans.sh" will reset this sequence similar
--         to sequence FLOAT_BATCH_NO_SEQ so that the sequence will not wrap
--         in the middle of selection.
--         "sos_batchsel" will be modified to include SOS_BATCH.MX_RELEASE_SEQ
--         in the ordering.
-- 
-- 
-- Table Modifications:
--    --------------------------------------------
--    SOS_BATCH
--    --------------------------------------------
--    Add columns:
--       - mx_release_seq          NUMBER(8)
--            The column is used to release the SOS batches to the selector
--            in the order matrix releases them.
--
--    --------------------------------------------
--    ORDCW
--    --------------------------------------------
--    Add columns:
--       - case_id
--
--    --------------------------------------------
--    ORDCB
--    --------------------------------------------
--    Add columns:
--       - case_id
--
--    --------------------------------------------
--    ORD_COOL
--    --------------------------------------------
--    Add columns:
--       - case_id
--
--    --------------------------------------------
--    TRANS
--    --------------------------------------------
--    Add columns:
--       - float_detail_seq_no    It will be populated from the
--                                FLOAT_DETAIL_SEQ_NO column when
--                                inserting the PIK transaction.
--                                This column along with the existing
--                                float_no column will be used to find
--                                the PIK transaction corresponding to the
--                                FLOAT_DETAIL record.  Without this column
--                                it can difficult as an item that is
--                                broken across floats zones will each have a
--                                PIK transaction but you cannot exactly match
--                                the FLOAT_DETAIL record to the corresponding
--                                PIK transation.
--                                Created as NUMBER(4) as opposed to the FLOAT_DETAIL
--                                table NUMBER(3) for room to grow ???
--
--    --------------------------------------------
--    OP_TRANS
--    --------------------------------------------
--    Add columns:
--       - replen_task_id        This is to get OP_TRANS in sync with TRANS.
--       - float_detail_seq_no 
--
--    --------------------------------------------
--    MINILOAD_TRANS
--    --------------------------------------------
--    Add columns:
--       - replen_task_id         This is to get MINILOAD_TRANS in sync with TRANS.
--       - float_detail_seq_no 
--
--    --------------------------------------------
--    FLOATS
--    --------------------------------------------
--    Save SEL_EQUIP.NO_OF_ZONES and SEL_EQUIP.MULTI_NO in the FLOATS table
--    and save SEL_METHOD.SEL_LIFT_JOB_CODE in the FLOATS table and change view
--    V_SOS_BATCH_INFO and V_SOS_BATCH_INFO_SHORT  to get these values from
--    FLOATS and not look at SEL_EQUIP and SEL_METHOD.  We had OpCo's change
--    SEL_METHOD and/or SEL_EQUIP after a route was generated and before the
--    batches were picked on SOS which either prevented the batch from getting
--    downloaded to SOS or caused issues once the batch was downloaded.
--    So basically in views V_SOS_BATCH_INFO and V_SOS_BATCH_INFO_SHORT do not
--    select from SEL_EQUIP and SEL_METHOD.  The values that were being
--    selected will now be in the FLOATS table.
--    Add columns:
--       - fl_no_of_zones
--       - fl_multi_no
--       - fl_sel_lift_job_code 
--                              
--
--
-- New Tables:
--    --------------------------------------------
--    MX_FLOAT_DETAIL_CASES
--    --------------------------------------------
--    Table for matrix cases.
--    It will have a record for each matrix case to pick.
--    Populated during order generation from tables FLOATS and FLOAT_DETAIL
--    when the "matrix" is active.
--    Updated by "sos_batchupd" and the data collection screens
--    and by the "short" processing.
--    This table has several extra columns from FLOATS and FLOAT_DETAIL so
--    that we can avoid joins back to FLOATS and FLOAT_DETAIL.
--
-----------------------------------------------------------------------------

--------------------------------------------------------------------------
-- ORDCW table changes
--------------------------------------------------------------------------
--
-- The 1st component of the case_id.
-- The appropriate programs will be changed to populate this column
-- from FLOAT_DETAIL.ORDER_SEQ.
--
ALTER TABLE swms.ordcw ADD (order_seq  NUMBER(8)); 

--
-- Case id
-- UK.
-- Derived from order_seq and seq_no.
--
ALTER TABLE swms.ordcw ADD
  (case_id     NUMBER(13) GENERATED ALWAYS AS ((order_seq * 1000) + seq_no) VIRTUAL);

--
-- Create unique key on table ORDCW case_id.
--
CREATE UNIQUE INDEX ordcw_case_id_uk ON swms.ordcw(case_id)
   TABLESPACE SWMS_ITS1
   STORAGE (INITIAL 128K NEXT 64K PCTINCREASE 0)
   PCTFREE 3;


--------------------------------------------------------------------------
-- ORDCB table changes
--------------------------------------------------------------------------
--
-- The 1st component of the case_id.
-- The appropriate programs will be changed to populate this column
-- from FLOAT_DETAIL.ORDER_SEQ.
--
ALTER TABLE swms.ordcb ADD (order_seq  NUMBER(8)); 

--
-- Case id
-- UK.
-- Derived from order_seq and seq_no.
--
ALTER TABLE swms.ordcb ADD
  (case_id     NUMBER(13) GENERATED ALWAYS AS ((order_seq * 1000) + seq_no) VIRTUAL);

--
-- Create unique key on table ORDCB case_id
-- Storage clause rather small since we do not have many ORDCB records.
--
CREATE UNIQUE INDEX ordcb_case_id_uk ON swms.ordcb(case_id)
   TABLESPACE SWMS_ITS1
   STORAGE (INITIAL 128K NEXT 128K PCTINCREASE 0)
   PCTFREE 3;

--------------------------------------------------------------------------
-- ORD_COOL table changes
--------------------------------------------------------------------------
--
-- The 1st component of the case_id.
-- The appropriate programs will be changed to populate this column
-- from FLOAT_DETAIL.ORDER_SEQ.
--
ALTER TABLE swms.ord_cool ADD (order_seq  NUMBER(8)); 

--
-- Case id
-- UK.
-- Derived from order_seq and seq_no.
--
ALTER TABLE swms.ord_cool ADD
  (case_id     NUMBER(13) GENERATED ALWAYS AS ((order_seq * 1000) + seq_no) VIRTUAL);

--
-- Create unique key on table ORD_COOL case_id.
-- Storage based on about 300 records.  Though 256K is rather generous.
--
CREATE UNIQUE INDEX ord_cool_case_id_uk ON swms.ord_cool(case_id)
   TABLESPACE SWMS_ITS1
   STORAGE (INITIAL 256K NEXT 128K PCTINCREASE 0)
   PCTFREE 3;

--------------------------------------------------------------------------
-- Add columns to TRANS table.
--------------------------------------------------------------------------
ALTER TABLE swms.trans ADD (float_detail_seq_no   NUMBER(4));

--------------------------------------------------------------------------
-- Add columns to OP_TRANS table.
--------------------------------------------------------------------------
ALTER TABLE swms.op_trans ADD (replen_task_id        NUMBER(10));
ALTER TABLE swms.op_trans ADD (float_detail_seq_no   NUMBER(4));

--------------------------------------------------------------------------
-- Add columns to MINILOAD_TRANS table.
--------------------------------------------------------------------------
ALTER TABLE swms.miniload_trans ADD (replen_task_id        NUMBER(10));
ALTER TABLE swms.miniload_trans ADD (float_detail_seq_no   NUMBER(4));

--------------------------------------------------------------------------
-- Add columns to FLOATS table.
--------------------------------------------------------------------------
ALTER TABLE swms.floats ADD (fl_no_of_zones         NUMBER(3));
ALTER TABLE swms.floats ADD (fl_multi_no            NUMBER(3));
ALTER TABLE swms.floats ADD (fl_sel_lift_job_code   VARCHAR2(6));

--------------------------------------------------------------------------
-- Create table MX_FLOAT_DETAIL_CASES
--------------------------------------------------------------------------
--
-- Table for each case and split from the matrix.
-- It will have a record for each case to pick--matrix and non-matrix.
-- Populated during order generation based on the FLOAT_DETAIL QTY_ALLOC AND UOM.
--
-- Table size roughly based on these counts from opco 007 for one day and record size of 140 bytes.
-- TRUNC(F.B P PIECE_COUNT
-- --------- - -----------
-- 05-OCT-14 N         571
-- 06-OCT-14 N       55972
-- 07-OCT-14 N       49099
--
CREATE TABLE swms.mx_float_detail_cases
(
   -- 9/11/2014 Brian Bent Don't think this sequence number is needed so won't have it.
   --  sequence_number            NUMBER         NOT NULL, -- PK.  Comes from a never wrapping sequence.
   --
   order_seq                      NUMBER(8) NOT NULL,    -- PK.  From FLOAT_DETAIL.order_seq.
                                                         -- The 1st component of the case_id.
   seq_no                         NUMBER(4) NOT NULL,    -- PK.  This is the case number of the case_id -- 1, 2, etc
                                                         -- The 2nd component of the case_id.
   --
   case_id                        NUMBER(13) GENERATED ALWAYS AS ((order_seq * 1000) + seq_no) VIRTUAL,
                                                         -- UK.
                                                         -- Derived from order_seq and seq_no.
                                                         -- This has to match the barcode value.
                                                         -- Format: FLOAT_DETAIL.ORDER.SEQ plus 3 digit case number.
                                                         -- The ORDD.SEQ sequence is always 8 digits.
                                                         -- This is the selection label barcode.
                                                         -- Examples: 12345678001
                                                         --           12345678002
                                                         --           12345678003
                                                         -- If we ever need the "seq_no" to 4 places then
                                                         -- (order_seq * 1000) needs to change to
                                                         -- (order_seq * 10000)
                                                         -- Note that ORDD.SEQ is populated to FLOAT_DETAIL.ORDER_SEQ.
   --
   batch_no                       NUMBER(9)      NOT NULL,  -- From FLOATS.BATCH_NO
   order_id                       VARCHAR2(14)   NOT NULL,  -- From FLOAT_DETAIL.ORDER_ID
   order_line_id                  NUMBER(3)      NOT NULL,  -- From FLOAT_DETAIL.ORDER_LINE_ID
   uom                            NUMBER(1)      NOT NULL,  -- 2 - case, 1 - split  From FLOAT_DETAIL.UOM
                                                            -- 10/13/2014  Brian Bent Will always be 2 at this time
                                                            -- since only cases are in the matrix.
   --
   prod_id                        VARCHAR2(9)    NOT NULL,  -- From FLOAT_DETAIL.PROD_ID
   cust_pref_vendor               VARCHAR2(10)   NOT NULL,  -- From FLOAT_DETAIL.CUST_PREF_VENDOR
   --
   -- Columns so we can easily tie this record back to the FLOAT_DETAIL record. 
   -- float_no and seq_no in the FLOAT_DETAIL table are the primary key.
   float_no                       NUMBER(9)      NOT NULL,  -- From FLOAT_DETAIL.FLOAT_NO
   float_detail_seq_no            NUMBER(9)      NOT NULL,  -- From FLOAT_DETAIL.SEQ_NO
   --
   float_detail_zone              NUMBER(2)      NOT NULL,  -- From FLOAT_DETAIL.ZONE.  The zone on the float.
   --
   swms_pallet_id                 VARCHAR2(18)   NOT NULL,  -- The pallet SWMS picked from.
   --
   mx_pallet_id                   VARCHAR2(18),             -- The pallet the matrix picked from.  The matrix can
                                                            -- pick from a pallet different from what SWMS picked from.
                                                            -- Populated when processing the matrix case release message.
   --
   case_short_flag                VARCHAR2(1) NOT NULL,     -- Y or N.  Set to N when the record is created.  Set to Y
                                                            -- if the selector shorts the case.
   short_reason                   VARCHAR2(8),              -- Matches SOS_SHORT
   --
   case_release_timestamp         TIMESTAMP WITH LOCAL TIME ZONE,
                                                            -- When the matrix releases the case to the convayer
                                                            -- Set when SWMS processes the matrix case release message.
                                                            -- It is initially null.
                                                            -- The datatype is still in question-- DATE or TIMESTAMP
   --
   case_divert_timestamp          TIMESTAMP WITH LOCAL TIME ZONE,
                                                            -- When the matrix diverts the case to the spur-lane.
                                                            -- Set when SWMS processes the matrix case divert message.
                                                            -- It is initially null.  The datatype is still in question.
   --
   spur_location                  VARCHAR2(10),             -- Spur the case sent to by the matrix.  This will be in the
                                                            -- matrix batch release message.
                                                            -- It is initially null.
                                                            -- This can be changed by the matrix case divert message because
                                                            -- the matrix could send it to the jackpot lane.
   --
   lane_id                        NUMBER(2),                -- Spur lane. 1-R, 2-S, 3-T, 4-over flow, ?-jackpot
                                                            -- We have this at order generation time in FLOATS.BATCH_SEQ
   --
   selector_id                    VARCHAR2(30),             -- The selector who picked the case.
   scan_date                      DATE,                     -- Date/time the selector scanned/keyed the case.  It is the selector pick time.
   scan_type                      VARCHAR2(1),              -- I - Item, U - UPC, S - Slot, C - Case barcode
   scan_method                    VARCHAR2(1),              -- Selector keyed, scanned or tab/enter.
                                                            -- K - Keyed, S - Scanned or T - tab/enter.
   status                         VARCHAR2(3) NOT NULL,     -- NEW-Generated  -- When OP creates the record.
                                                            -- REL-Matrix released 
                                                            -- DIV-Matrix diverted
                                                            -- PIK-Picked by selector
                                                            -- SHT-Selector shorts case
                                                            -- NRL-Matrix not released--??? Huh
   case_skip_flag                 VARCHAR2(1) DEFAULT 'N',  --Yes=Y - No=N      Case skip by symbotic   
   case_skip_reason               VARCHAR2(10),             -- Case skip reason ACTUAL OR DELAY
   short_batch_no                 VARCHAR2(14),  
   --
   add_date                       DATE          DEFAULT SYSDATE NOT NULL,
   add_user                       VARCHAR2(30)  DEFAULT REPLACE(USER, 'OPS$') NOT NULL,
   upd_date                       DATE,                     -- Populated by DB trigger
   upd_user                       VARCHAR2(30)              -- Populated by DB trigger
)
TABLESPACE swms_dts1
STORAGE (INITIAL 2M NEXT 1M PCTINCREASE 0)
PCTFREE 10;

GRANT SELECT ON swms.mx_float_detail_cases TO SWMS_VIEWER;

GRANT ALL ON swms.mx_float_detail_cases TO SWMS_USER;

CREATE OR REPLACE PUBLIC SYNONYM mx_float_detail_cases FOR swms.mx_float_detail_cases;


--------------------------------------------------------------------------
-- Create primary key on table MX_FLOAT_DETAIL_CASES
--------------------------------------------------------------------------
ALTER TABLE swms.mx_float_detail_cases ADD CONSTRAINT mx_float_detail_cases_pk
   PRIMARY KEY (order_seq, seq_no)
   USING INDEX
       TABLESPACE SWMS_ITS1
       STORAGE (INITIAL 1M NEXT 512K  PCTINCREASE 0)
       PCTFREE 5;

--------------------------------------------------------------------------
-- Create unique key on table mx_float_detail_cases
--------------------------------------------------------------------------
CREATE UNIQUE INDEX mx_float_detail_cases_uk ON swms.mx_float_detail_cases(case_id)
   TABLESPACE SWMS_ITS1
   STORAGE (INITIAL 1M NEXT 512K  PCTINCREASE 0)
   PCTFREE 5;

---------------------------------------------------------------
---------------------------------------------------------------
-- End Order Processing
---------------------------------------------------------------
---------------------------------------------------------------

------------------Adding the Digisign tables-------------------
--drop table swms.digisign_host_config;

create table swms.digisign_host_config (
        hostname                        varchar2(255)   not null,
        function                        varchar2(30)    not null,       -- PL/SQL refresh function in package   
        location                        varchar2(10)    not null,       -- spur or location to monitor
        interval                        number                  not null        -- seconds between refresh requests
);

grant all on swms.digisign_host_config to swms_user;
create or replace public synonym digisign_host_config for swms.digisign_host_config;

-- drop table swms.digisign_spur_monitor;

create table swms.digisign_spur_monitor (
        location                        varchar2(10)    not null,
        curr_batch_no                   varchar2(14),
        curr_userid                     varchar2(30),
        next_batch_no                   varchar2(14),
        next_userid                     varchar2(30),
        next_total_cases                number(4),
        total_cases_all                 number(4),
        total_cases_r                   number(4),
        total_cases_s                   number(4),
        total_cases_t                   number(4),
        total_cases_ovfl                number(4),
        total_cases_jackpot             number(4),
        dropped_cases_all               number(4),
        dropped_cases_r                 number(4),
        dropped_cases_s                 number(4),
        dropped_cases_t                 number(4),
        dropped_cases_ovfl              number(4),
        dropped_cases_jackpot           number(4),
        picked_cases_all                number(4),
        picked_cases_r                  number(4),
        picked_cases_s                  number(4),
        picked_cases_t                  number(4),
        picked_cases_ovfl               number(4),
        picked_cases_jackpot            number(4),
        remaining_cases_all             number(4),
        remaining_cases_r               number(4),
        remaining_cases_s               number(4),
        remaining_cases_t               number(4),
        remaining_cases_ovfl            number(4),
        remaining_cases_jackpot         number(4),
        short_cases_all                 number(4),
        short_cases_r                   number(4),
        short_cases_s                   number(4),
        short_cases_t                   number(4),
        short_cases_ovfl                number(4),
        short_cases_jackpot             number(4),
        primary key(location)
);

grant all on swms.digisign_spur_monitor to swms_user;
create or replace public synonym digisign_spur_monitor for swms.digisign_spur_monitor;

create table swms.digisign_jackpot_monitor (
    location                varchar2(10)    not null,
    divert_time             date,
    truck_no                varchar2(10),
    user_id                 varchar2(30),
    batch_no                varchar2(14),
    batch_type              varchar2(3),    /* SOS, or DSP, NSP, UNA, MRL, etc. */
    spur_location           varchar2(10),
    case_barcode            varchar2(20),
    item_desc               varchar2(30),
    add_date                date            default sysdate not null,
    add_user                varchar2(30)    default REPLACE(USER, 'OPS$')    not null    
);

grant all on swms.digisign_jackpot_monitor to swms_user;
create or replace public synonym digisign_jackpot_monitor for swms.digisign_jackpot_monitor;

--Drop table mx_replenlst_cases;
CREATE TABLE mx_replenlst_cases
(
batch_no                NUMBER(9)               NOT NULL,
task_id                 NUMBER(10),
case_id                     NUMBER(13)          NOT NULL,
prod_id                         VARCHAR2(9)     NOT NULL,
pallet_id                       VARCHAR2(18)    NOT NULL,
spur_location                   VARCHAR2(10)    NOT NULL,                                                                                                                                                                                  
lane_id                 NUMBER(2),
case_divert_timestamp   TIMESTAMP(6),
status                          VARCHAR2(3)     NOT NULL,  /*Diverted - DIV, Picked- PIK*/
primary key(case_id)
);

CREATE OR REPLACE PUBLIC SYNONYM mx_replenlst_cases FOR swms.mx_replenlst_cases;

GRANT ALL ON mx_replenlst_cases to SWMS_USER;

--DROP SEQUENCE mx_batch_no_seq;

CREATE SEQUENCE mx_batch_info_seq
MINVALUE 1000
MAXVALUE 99999999999
START WITH 1000
INCREMENT BY 1; 

CREATE OR REPLACE PUBLIC SYNONYM mx_batch_info_seq FOR SWMS.mx_batch_info_seq;

--Drop table mx_batch_info;

CREATE TABLE mx_batch_info
(
sequence_number         NUMBER(9)               NOT NULL,       
batch_no                VARCHAR2(14)    NOT NULL,
batch_type              VARCHAR2(1)             NOT NULL,   /*Replenishment -R,  Order-O*/
replen_type             VARCHAR2(3),                            /*NSP, DSP, UNA*/ 
status                          VARCHAR2(3)             NOT NULL  , /*AVL, PIK, END*/
spur_location           VARCHAR2(10)    NOT NULL,   
sequence_timestamp      TIMESTAMP(6), 
PRIMARY KEY (sequence_number)
);

CREATE OR REPLACE PUBLIC SYNONYM mx_batch_info FOR swms.mx_batch_info;

GRANT ALL ON mx_batch_info to SWMS_USER;

--------------------------------------------------------------------------
-- Add columns to sos_short table.
--------------------------------------------------------------------------
ALTER TABLE swms.sos_short ADD (pik_status   VARCHAR2(1));

ALTER TABLE swms.sos_short ADD (spur_location VARCHAR2(10));

ALTER TABLE SOS_SHORT ADD (float_no             NUMBER(9),
                           float_detail_seq_no  NUMBER(3));

DROP INDEX XPKSOS_SHORT;

CREATE UNIQUE INDEX XPKSOS_SHORT ON sos_short(orderseq, location, picktype, float_no, float_detail_seq_no);


--------------------------------------------------------------------------
-- Add columns to float_hist table.
--------------------------------------------------------------------------
ALTER TABLE swms.float_hist ADD (scan_method VARCHAR2(1));

--------------------------------------------------------------------------
-- Add columns to t_curr_batch table.
--------------------------------------------------------------------------
 ALTER TABLE t_curr_batch ADD(label_max_seq NUMBER);
 
--------------------------------------------------------------------------
-- Add columns to t_curr_batch_short table.
--------------------------------------------------------------------------
 ALTER TABLE t_curr_batch_short ADD(label_max_seq NUMBER);
 
--------------------------------------------------------------------------
-- Add columns to auto_orders table.
--------------------------------------------------------------------------
ALTER TABLE auto_orders ADD(mx_exact_pallet_imp  VARCHAR2(4));

--Drop table SWMS.ORDCW_AUDIT;

CREATE TABLE SWMS.ORDCW_AUDIT
(
  ORDER_ID          VARCHAR2(14 BYTE)           NOT NULL,
  ORDER_LINE_ID     NUMBER(3)                   NOT NULL,
  PROD_ID           VARCHAR2(9 BYTE),
  CUST_PREF_VENDOR  VARCHAR2(10 BYTE),
  CATCH_WEIGHT      NUMBER(9,3),
  CW_TYPE           VARCHAR2(1 BYTE),
  UOM               NUMBER(1),
  ORDCW_ADD_DATE    DATE                        DEFAULT sysdate,
  ADD_USER          VARCHAR2(30 BYTE)           DEFAULT user,
  UPD_DATE          DATE,
  UPD_USER          VARCHAR2(30 BYTE),
  CW_FLOAT_NO       NUMBER(7),
  CW_SCAN_METHOD    CHAR(1 BYTE),
  ADD_DATE          DATE                        DEFAULT sysdate,
  RECORD_TYPE       VARCHAR2(10 BYTE)         
);

COMMENT ON TABLE SWMS.ORDCW_AUDIT IS 'ORDCW AUDIT FOR CATCHWEIGHT LOG FOR TICKET 1625287';

CREATE OR REPLACE PUBLIC SYNONYM ORDCW_AUDIT FOR SWMS.ORDCW_AUDIT;

GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.ORDCW_AUDIT TO SWMS_USER;

GRANT SELECT ON SWMS.ORDCW_AUDIT TO SWMS_VIEWER;



--Drop table swms.mx_inv_exception;
CREATE TABLE swms.mx_inv_exception
(
PROD_ID                                  VARCHAR2(9)  NOT NULL ,
STATUS                                   VARCHAR2(3)  NOT NULL,   /*HLD, AVL*/
SYNC_DATE                                DATE             NOT NULL,        
MX_MSG_ID                                VARCHAR2(30) NOT NULL,
QTY_SWMS                                 NUMBER(7),
QTY_SYMBOTIC                     NUMBER(7),
QTY_DIFF                                 NUMBER(7)
);

GRANT ALL ON SWMS.MX_INV_EXCEPTION TO SWMS_USER;

CREATE OR REPLACE PUBLIC SYNONYM MX_INV_EXCEPTION FOR SWMS.MX_INV_EXCEPTION;


--Drop table swms.mx_inv_hist;
CREATE TABLE mx_inv_hist(
FUNCTION                                         VARCHAR2(10) NOT NULL, /*UPDATE, INSERT, MATCH, DELETE*/
SYNC_DATE                                        DATE             NOT NULL,
MX_MSG_ID                                        VARCHAR2(30) NOT NULL ,
PROD_ID_OLD                                      VARCHAR2(9),
PROD_ID_NEW                                      VARCHAR2(9),
REC_ID                                           VARCHAR2(12),
MFG_DATE                                         DATE,
REC_DATE                                         DATE,
EXP_DATE_OLD                             DATE,
EXP_DATE_NEW                             DATE,
INV_DATE                                         DATE,
LOGI_LOC                                         VARCHAR2(18),
PLOGI_LOC                                        VARCHAR2(10),
QOH_OLD                                          NUMBER(7),
QOH_NEW                                          NUMBER(7),
QTY_ALLOC                                        NUMBER(7),
QTY_PLANNED                                      NUMBER(7),
MIN_QTY                                          NUMBER(7),
CUBE                                             NUMBER(7,2),
LST_CYCLE_DATE                           DATE,
LST_CYCLE_REASON                         VARCHAR2(2),
ABC                                                      VARCHAR2(1),
ABC_GEN_DATE                             DATE,
STATUS_OLD                                       VARCHAR2(3),
STATUS_NEW                                       VARCHAR2(3),
LOT_ID                                           VARCHAR2(30),
WEIGHT                                           NUMBER(9,3),
TEMPERATURE                                      NUMBER,
EXP_IND                                          VARCHAR2(1),
CUST_PREF_VENDOR                         VARCHAR2(10),
CASE_TYPE_TMU                            NUMBER(9,4),
PALLET_HEIGHT                            NUMBER(6,1),
ADD_DATE                                         DATE,
ADD_USER                                         VARCHAR2(10),
UPD_DATE                                         DATE,
UPD_USER                                         VARCHAR2(10),
PARENT_PALLET_ID                         VARCHAR2(18),
DMG_IND                                          VARCHAR2(1),
INV_UOM                                          NUMBER(2),
MX_XFER_TYPE                             VARCHAR2(3)
);

GRANT ALL ON SWMS.MX_INV_HIST TO SWMS_USER;

CREATE OR REPLACE PUBLIC SYNONYM MX_INV_HIST FOR SWMS.MX_INV_HIST;


---Alter table Replenlst
ALTER TABLE REPLENLST ADD
( MX_SHORT_CASES         NUMBER(7));

---Alter table auto_orders
ALTER TABLE auto_orders ADD (priority NUMBER DEFAULT 3);

ALTER TABLE matrix_in ADD (QTY_SUSPECT      NUMBER(10));

ALTER TABLE matrix_inv_bulk_in ADD (QTY_SUSPECT  NUMBER(10));

ALTER TABLE matrix_inv_bulk_in MODIFY (MX_MSG_ID  VARCHAR2(30));

ALTER TABLE matrix_inv_bulk_in MODIFY (CASE_QUANTITY  NUMBER(10));

ALTER TABLE digisign_spur_monitor ADD 
       (curr_truck_no_r                 varchar2(10),
        curr_truck_no_s                 varchar2(10),
        curr_truck_no_t                 varchar2(10),
        next_truck_no_r                 varchar2(10),
        next_truck_no_s                 varchar2(10),
        next_truck_no_t                 varchar2(10),
                mx_short_cases_all              number(4),
        mx_short_cases_r                number(4),
        mx_short_cases_s                number(4),
        mx_short_cases_t                number(4),
        mx_short_cases_ovfl             number(4),
        mx_short_cases_jackpot          number(4),
        upd_date                        date            default sysdate not null,
        upd_user                        varchar2(30)    default REPLACE(USER, 'OPS$')    not null);

alter table swms.digisign_spur_monitor
    add (
        mx_delayed_cases_all        number(4),
        mx_delayed_cases_r          number(4),
        mx_delayed_cases_s          number(4),
        mx_delayed_cases_t          number(4),
        mx_delayed_cases_ovfl       number(4),
        mx_delayed_cases_jackpot    number(4)
    );


ALTER TABLE mx_replenlst_cases ADD (case_skip_flag   VARCHAR2(1) DEFAULT 'N',
                                    case_skip_reason VARCHAR2(10));

ALTER TABLE MATRIX_OUT_LABEL ADD (add_date           DATE DEFAULT SYSDATE,
                                  add_user           VARCHAR2(30) DEFAULT USER,
                                  upd_date           DATE DEFAULT NULL,
                                  upd_user           VARCHAR2(30) DEFAULT NULL
                                  );

ALTER TABLE matrix_pm_bulk_out MODIFY description VARCHAR2(50); 


                                                                        