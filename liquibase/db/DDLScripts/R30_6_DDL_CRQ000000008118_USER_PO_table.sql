
/****************************************************************************
**
** Description:
**    Project:
**       R30.6--WIE#669--CRQ000000008118_Live_receiving_story_222_enabling caching
**
**    Create new table USER_DOWNLOADED_PO and Index on user_id and pallet_id
**
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    07/18/16 sont9212 Sunil Ontipalli
**                      Project:
**          R30.6--WIE#669--CRQ000000008118_Live_receiving_story_222_enabling caching
**
**                      Created.
**
**
****************************************************************************/


CREATE TABLE SWMS.USER_DOWNLOADED_PO
(
  PALLET_ID           VARCHAR2(18 CHAR)               NOT NULL,
  REC_ID              VARCHAR2(12 CHAR)               NOT NULL,
  PROD_ID             VARCHAR2(9 CHAR)                NOT NULL,
  DEST_LOC            VARCHAR2(10 CHAR),
  QTY                 NUMBER(8)                       NOT NULL,
  UOM                 NUMBER(2)                       NOT NULL,
  STATUS              VARCHAR2(3 CHAR)                NOT NULL,
  ZONE_ID             VARCHAR2(5 CHAR),
  LOT_ID              VARCHAR2(30 CHAR),
  EXP_DATE            DATE,
  WEIGHT              NUMBER(9,3),
  TEMP                NUMBER(6,1),
  MFG_DATE            DATE,
  QTY_EXPECTED        NUMBER(8)                       NOT NULL,
  QTY_RECEIVED        NUMBER(8)                       NOT NULL,
  DATE_CODE           VARCHAR2(1 CHAR),
  EXP_DATE_TRK        VARCHAR2(1 CHAR),
  LOT_TRK             VARCHAR2(1 CHAR),
  CATCH_WT            VARCHAR2(1 CHAR),
  TEMP_TRK            VARCHAR2(1 CHAR),
  PUTAWAY_PUT         VARCHAR2(1 CHAR),
  ERM_LINE_ID         NUMBER(4),
  PRINT_STATUS        VARCHAR2(3 CHAR),
  CLAM_BED_TRK        VARCHAR2(1 CHAR),
  ADD_DATE            DATE  DEFAULT SYSDATE,
  ADD_USER            VARCHAR2(50 CHAR) DEFAULT USER,
  UPD_DATE            DATE DEFAULT SYSDATE,
  UPD_USER            VARCHAR2(50 CHAR) DEFAULT USER,
  PUTAWAYLST_ADD_DATE DATE,
  PUTAWAYLST_ADD_USER VARCHAR2(50 CHAR),
  TTI                 VARCHAR2(1 CHAR),
  TTI_TRK             VARCHAR2(1 CHAR),
  CRYOVAC             VARCHAR2(1 CHAR),
  PO_LINE_ID          NUMBER(3),
  COOL_TRK            VARCHAR2(1 CHAR),
  USER_ID             VARCHAR2(50 BYTE)
);

--
-- Create index on USER_DOWNLOADED_PO.user_id and pallet_id
--
CREATE INDEX SWMS.USER_DOWNLOADED_PO_USER_IDX ON SWMS.USER_DOWNLOADED_PO (pallet_id, user_id)
   TABLESPACE SWMS_ITS1
   STORAGE (INITIAL 128K NEXT 64K PCTINCREASE 0)
   PCTFREE 1;