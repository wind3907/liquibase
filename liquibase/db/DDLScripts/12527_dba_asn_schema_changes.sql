/****************************************************************************
** sccs_id=%Z% %W% %G% %I%
**
** Date:       09-09-09
** Programmer: ctvgg000	
** File:       12527_dba_asn_schema_changes.sql
** Defect#:    12527
** Project ID: 340369
** Project:    ASN to all OPCO's
**
**
** Add a new column to store VSN # in the ERM table.
**
****************************************************************************/

ALTER TABLE SWMS.ERM
  ADD (vn_no VARCHAR2(12));
  
ALTER TABLE SWMS.SN_HEADER
  ADD (vn_no VARCHAR2(12));  
  
INSERT INTO SWMS.REC_TYPE
(REC_TYPE, DESCRIP)
VALUES
('VN', 'Vendor Shipment Notification' );


INSERT INTO SWMS.TRANS_TYPE
(
TRANS_TYPE, DESCRIP, RETENTION_DAYS, INV_AFFECTING)
VALUES
('VSR','VSN Reject','55','N');

INSERT INTO SWMS.TRANS_TYPE
(
TRANS_TYPE, DESCRIP, RETENTION_DAYS, INV_AFFECTING)
VALUES
('VSN','VSN Received','55','N');

ALTER TABLE SWMS.SN_HEADER MODIFY (RDC_NBR VARCHAR2(5) NULL);
