------------------------------------------------------------------------------
-- View:
--    v_tmp_weight
--
-- Description:
--    This is a view of the tmp_weight with PM,PUTAWAYLST tables. 
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--	  08/31/15 spot3255 View created.
--    09/29/15 kraj6630 View Modified to populate the item similar to check in screen 
--    01/06/16 kraj6630 View Modified to populate the item similar to check in screen
--    06/23/16 jluo6971 Use distinct on prod_id from putawaylst since an item
--			can be in > 1 pallet depending on its TiXHi.
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SWMS.V_TMP_WEIGHT
(
ERM_ID,
PROD_ID,
MFG_SKU,
PALLET_ID,
PARENT_PALLET_ID,
CUST_PREF_VENDOR,
TOTAL_CASES,
TOTAL_SPLITS,
TOTAL_WEIGHT,
OTHER
)
AS
SELECT ERM_ID,
TW.PROD_ID,
MFG_SKU,
(SELECT MAX(PALLET_ID) FROM PUTAWAYLST WHERE ERM_ID=TW.ERM_ID AND PROD_ID=TW.PROD_ID),
(SELECT MAX(PARENT_PALLET_ID) FROM PUTAWAYLST WHERE ERM_ID=TW.ERM_ID AND PROD_ID=TW.PROD_ID),
TW.CUST_PREF_VENDOR,
TOTAL_CASES,
TOTAL_SPLITS,
TOTAL_WEIGHT,
DECODE (SUBSTR (brand, 1, 3), 'SYS', ' SYS', 'Z')
          || DECODE (
                SUBSTR (brand, 1, 3),
                'SYS', (SELECT DISTINCT PUTAWAYLST.PROD_ID
             FROM PUTAWAYLST
             WHERE REC_ID = TW.ERM_ID AND PUTAWAYLST.PROD_ID = TW.PROD_ID),
                DECODE (mfg_sku,
                        NULL, RPAD ('~', 15, '~'),
                        RPAD (mfg_sku, 15, ' ')))
          OTHER
FROM TMP_WEIGHT TW, PM
WHERE TW.PROD_ID = PM.PROD_ID;
CREATE OR REPLACE PUBLIC SYNONYM V_TMP_WEIGHT FOR SWMS.V_TMP_WEIGHT;
GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.V_TMP_WEIGHT TO SWMS_USER;
GRANT SELECT ON SWMS.V_TMP_WEIGHT TO SWMS_VIEWER;
