SET ECHO OFF
SET LINESIZE 132
SET PAGESIZE 60
SET TERMOUT ON

/*******************************************************************************
**
** Script Name:     UpdBckupTbls.sql
**
** Purpose:         Recent updates were made to some of the original tables for
**                  the *_BCKUP tables. Those updates were made without making
**                  duplicate modifications to the *_BCKUP tables also. This
**                  script synchronizes the tables again (without removing the
**                  BKUP_DATE column first since it already contains data).
**
** History:
**  Date       Developer    Description
**  ---------- ------------ ----------------------------------------------------
**  06/17/2016 Jim Gilliam  Created this script.
**  06/18/2016 Jim Gilliam  (1) Removed creation of backup table before making
**                          changes, (2) removed modify for BCKUP columns whose
**                          data type or nullability was different, (3) modified
**                          original table VARCHAR2 lengths to specify CHAR
**                          rather than BYTE.
**  06/28/2016 Jim Gilliam  Added SOS_SHORT_BCKUP table
**
*******************************************************************************/

/* CHANGE 1:
**
** Original Table:      FLOATS
** Backup Table:        FLOATS_BCKUP
** Modify Orig Columns: FL_SEL_LIFT_JOB_CODE
** New Backup Columns:  FL_NO_OF_ZONES, FL_MULTI_NO,
**                      FL_SEL_LIFT_JOB_CODE, MX_PRIORITY
*/

ALTER TABLE swms.floats
    MODIFY ( fl_sel_lift_job_code  VARCHAR2(6 Char) ) ; -- 6 Byte >> 6 Char

ALTER TABLE swms.floats_bckup
    ADD ( fl_no_of_zones        NUMBER(3) ,
          fl_multi_no           NUMBER(3) ,
          fl_sel_lift_job_code  VARCHAR2(6 Char) ,
          mx_priority           NUMBER(2) ) ;

/* CHANGE 2:
**
** Original Table:      ORDCB
** Backup Table:        ORDCB_BCKUP
** New Backup Columns:  ORDER_SEQ, CASE_ID
*/

ALTER TABLE swms.ordcb_bckup
    ADD ( order_seq             NUMBER(8) ,
          case_id               NUMBER(13) ) ;

/* CHANGE 3:
**
** Original Table:      ORDCW
** Backup Table:        ORDCW_BCKUP
** New Backup Columns:  ORDER_SEQ, CASE_ID, CW_KG_LB
**                  
*/

ALTER TABLE swms.ordcw_bckup
    ADD ( order_seq             NUMBER(8) ,
          case_id               NUMBER(13) ,   
          cw_kg_lb              NUMBER(9,3) ) ;

/* CHANGE 4:
**
** Original Table:      ORDM
** Backup Table:        ORDM_BCKUP
** New Backup Columns:  CROSS_DOCK_TYPE
**                  
*/

ALTER TABLE swms.ordm_bckup
    ADD ( cross_dock_type       VARCHAR2(2 Char) ) ;

/* CHANGE 5:
**
** Original Table:      ORD_COOL
** Backup Table:        ORD_COOL_BCKUP
** New Backup Columns:  ORDER_SEQ, CASE_ID
**                  
*/

ALTER TABLE swms.ord_cool_bckup
    ADD ( order_seq             NUMBER(8) ,
          case_id               NUMBER(13) ) ;

/* CHANGE 6:
**
** Original Table:      ROUTE
** Backup Table:        ROUTE_BCKUP
** New Backup Columns:  MX_WAVE_NUMBER
**
*/

ALTER TABLE swms.route_bckup
    ADD ( mx_wave_number        NUMBER(7) ) ;

/* CHANGE 7:
**
** Original Table:      SOS_BATCH
** Backup Table:        SOS_BATCH_BCKUP
** New Backup Columns:  PRIORITY
**                  
*/

ALTER TABLE swms.sos_batch_bckup
    ADD ( priority              NUMBER(2) ) ;

/* CHANGE 8:
**
** Original Table:      SOS_SHORT
** Backup Table:        SOS_SHORT_BCKUP
** Modify Orig Columns: FL_SEL_LIFT_JOB_CODE
** New Backup Columns:  PIK_STATUS, SPUR_LOCATION, FLOAT_NO,
**                      FLOAT_DETAIL_SEQ_NO, WH_OUT_QTY
**                  
*/

ALTER TABLE swms.sos_short
    MODIFY ( pik_status            VARCHAR2(1 Char) ,      -- 1 Byte >> 1 Char
             spur_location         VARCHAR2(10 Char) ) ;   -- 10 Byte >> 10 Char

ALTER TABLE swms.sos_short_bckup
    ADD ( pik_status            VARCHAR2(1 Char)
        , spur_location         VARCHAR2(10 Char)
        , float_no              NUMBER(9)
        , float_detail_seq_no   NUMBER(3)
        , wh_out_qty            NUMBER(7) ) ;
