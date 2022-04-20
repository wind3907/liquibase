/*=============================================================================================
*  OPCOF-759 - Building Master Pallet 
			   New data Types for the Linking the Parent pallet with child pallet
  
=============================================================================================*/
  
create or replace TYPE Parent_Link_LPN_List_Rec FORCE AS
OBJECT
(
    Pallet_Id             VARCHAR2(18 CHAR),   /* INV.LOGI_LOC */
    Parent_Pallet_Id      VARCHAR2(18 CHAR),   /* INV.Parent PALLET_ID*/
    Erm_Type              VARCHAR2(3 CHAR),    /* "PO" */
    Qty_Expected          NUMBER(8),           /* INV.QOH */
    Qty_Received          NUMBER(8),           /* INV.QTY_PRODUCED */
    Dest_Loc              VARCHAR2(10 CHAR)    /* INV.PLOGI_LOC */
);
/

create or replace TYPE Parent_Link_LPN_List_Table FORCE AS
TABLE OF SWMS.Parent_Link_LPN_List_Rec;
/
create or replace TYPE Parent_Link_Item_List_Rec FORCE AS
OBJECT
(
    Prod_Id               VARCHAR2(9 CHAR),    /* PM.PROD_ID */
    Cust_Pref_Vendor      VARCHAR2(10 CHAR),   /* PM.CUST_PREF_VENDOR */
    UOM                   NUMBER(2),           /* LOC.UOM (Unit Of Measure) */
    SPC                   NUMBER(4),           /* PM.SPC (Splits Per Case) */
    Descrip               VARCHAR2(100 CHAR),  /* PM.DESCRIP VARCHAR2(30) extended for possible XML character translations */
    Mfg_SKU               VARCHAR2(14 CHAR),   /* PM.MFG_SKU */
    UCN                   VARCHAR2(6 CHAR),    /* SUBSTR(PM.EXTERNAL_UPC,9,14-9+1) */
    Pick_Loc              VARCHAR2(10 CHAR),   /* LOC.LOGI_LOC */
    Brand                 VARCHAR2(7 CHAR),    /* PM.BRAND */
    LPN_Table             SWMS.Parent_Link_LPN_List_Table
);
/
create or replace TYPE Parent_Link_Item_List_Table FORCE
    AS TABLE OF SWMS.Parent_Link_Item_List_Rec;
/
create or replace TYPE Parent_Link_PO_List_Rec FORCE AS 
OBJECT
(
    Erm_Id                VARCHAR2(12 CHAR),   /* INV.REC_ID */
    Rec_Date              VARCHAR2(10 CHAR),   /* INV.REC_DATE, Format: MMDDYY */
    Item_Table            SWMS.Parent_Link_Item_List_Table
);
/
create or replace TYPE Parent_Link_PO_List_Table FORCE
    AS TABLE OF SWMS.Parent_Link_PO_List_Rec;
/
create or replace TYPE Parent_Link_PO_List_Obj FORCE AS 
OBJECT
(
    PO_Table    SWMS.Parent_Link_PO_List_Table 
);
/
GRANT EXECUTE ON swms.Parent_Link_LPN_List_Rec TO swms_user;
GRANT EXECUTE ON swms.Parent_Link_Item_List_Rec TO swms_user;
GRANT EXECUTE ON swms.Parent_Link_PO_List_Rec TO swms_user;
GRANT EXECUTE ON swms.Parent_Link_PO_List_Obj TO swms_user;
/
SHOW ERRORS
/
