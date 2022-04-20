----------------------------- SAP INTERFACE PACKAGES ------------------------
-----------------------------------------------------------------------------
    
grant all on PL_SAP_INTERFACES to SWMS_SAP; 
grant all on PL_SYNTELIC_INTERFACES to SWMS_SAP;
grant all on PL_CUBITRON_INTERFACES to SWMS_SAP;
grant all on PL_PURGE_STAGETABLE to SWMS_SAP;
grant all on SWMS_LOG to SWMS_SAP;

-- MDI005 --

grant all on SAP_IM_IN to SWMS_SAP;
grant all on SAP_IM_SEQ to SWMS_SAP;

-- MDI012 --

grant all on SAP_CU_IN to SWMS_SAP;
grant all on SAP_CU_SEQ to SWMS_SAP;

-- SMI004 --

grant all on SAP_ML_IN to SWMS_SAP;
grant all on SAP_ML_SEQ to SWMS_SAP;

-- PRI004 --

grant all on SAP_PO_IN to SWMS_SAP;
grant all on SAP_PO_SEQ to SWMS_SAP; 

-- SCI039 --

grant all on SAP_MF_IN to SWMS_SAP;
grant all on SAP_MF_SEQ to SWMS_SAP;

-- SCI042 --

grant all on SAP_SN_IN to SWMS_SAP;
grant all on SAP_SN_SEQ to SWMS_SAP;
grant all on SAP_SN_BATCH_SEQ to SWMS_SAP;

-- SCI014 -- 
grant all on SAP_OR_IN to SWMS_SAP; 
grant all on SAP_OR_SEQ to SWMS_SAP; 

-- MDI031 -- 

grant all on SAP_CS_IN to SWMS_SAP; 
grant all on SAP_CS_SEQ to SWMS_SAP; 

-- SCI015 --

grant all on SAP_CR_OUT to SWMS_SAP;
grant all on SAP_CR_OBJECT_TABLE to SWMS_SAP;
grant all on SAP_CR_SEQ to SWMS_SAP;

-- SCI004 --

grant all on SAP_RT_OUT to SWMS_SAP;
grant all on SAP_RT_OBJECT_TABLE to SWMS_SAP;
grant all on SAP_RT_SEQ to SWMS_SAP;

-- SCI016 --

grant all on SAP_OW_OUT to SWMS_SAP;
grant all on SAP_OW_OBJECT_TABLE to SWMS_SAP;
grant all on SAP_OW_SEQ to SWMS_SAP;

-- SCI003 & SCI006 --

grant all on SAP_IA_OUT to SWMS_SAP;
grant all on SAP_IA_OBJECT_TABLE to SWMS_SAP;
grant all on SAP_IA_SEQ to SWMS_SAP;

-- SCI025 --

grant all on SAP_WH_OUT to SWMS_SAP;
grant all on SAP_WH_OBJECT_TABLE to SWMS_SAP;
grant all on SAP_WH_SEQ to SWMS_SAP;


-- SCI069 -- 
grant all on SAP_LM_OUT to SWMS_SAP;
grant all on SAP_LM_OBJECT_TABLE to SWMS_SAP;
grant all on SAP_LM_SEQ to SWMS_SAP; 

-- SCI098 -- 
grant all on SAP_CONTAINER_OUT to SWMS_SAP;
grant all on SAP_CONTAINER_OBJECT_TABLE to SWMS_SAP;
grant all on SAP_CONTAINER_SEQ to SWMS_SAP;

-- SCI087 -- 

grant all on SAP_EQUIP_OUT to SWMS_SAP;
grant all on SAP_EQUIP_OBJECT_TABLE to SWMS_SAP;
grant all on SAP_EQUIP_SEQ to SWMS_SAP;

----------------------------- SYNTELIC INTERFACES --------------------------
----------------------------------------------------------------------------

-- SCI044-A

grant all on SYNTELIC_LOADMAPPING_IN to SWMS_SAP; 
grant all on SYNTELIC_LOADMAPPING_SEQ to SWMS_SAP; 

grant all on SLS_LOAD_MAP_DETAIL to SWMS_SAP; 

-- SCI056-A
grant all on SYNTELIC_MATERIAL_OUT to SWMS_SAP; 
grant all on SYNTELIC_MATERIAL_SEQ to SWMS_SAP;
grant all on SYNTELIC_MATERIAL_OBJECT_TABLE to SWMS_SAP;

-- SCI043-A

grant all on SYNTELIC_ROUTE_ORDER_OUT to SWMS_SAP;
grant all on SYNTELIC_ROUTE_ORDER_SEQ to SWMS_SAP;
grant all on SYNTELIC_ROUTE_OBJECT_TABLE to SWMS_SAP;
grant all on SYNTELIC_ORDER_OBJECT_TABLE to SWMS_SAP;

-------------------------- CUBITRON INTERFACES ----------------------------------
---------------------------------------------------------------------------------

-- SCI068-C

grant all on CUBITRON_MEASUREMENT_IN to SWMS_SAP; 
grant all on CUBITRON_MEASUREMENT_SEQ to SWMS_SAP; 

-- SCI105-C

grant all on CUBITRON_ITEMMASTER_OUT to SWMS_SAP; 
grant all on SWMS_CUBITRON_ITEMMASTER_SEQ to SWMS_SAP; 
grant all on CUBI_ITEMMASTER_OBJECT_TABLE to SWMS_SAP;

-------------------------- PURGING STAGING TABLES -------------------------------
---------------------------------------------------------------------------------

grant all on PL_PURGE_STAGETABLE to SWMS_SAP;
grant all on SAP_INTERFACE_PURGE to SWMS_SAP; 

-- SAP_TRACE_STAGING_TABLE --

grant select on SAP_TRACE_STAGING_TBL to SWMS_VIEWER;
grant all on SAP_TRACE_STAGING_TBL to SWMS_USER;

-- APPL_ERROR_LOG --

grant select on APPL_ERROR_LOG to SWMS_VIEWER;
grant all on APPL_ERROR_LOG to SWMS_USER;

COMMIT;







