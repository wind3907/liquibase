ALTER TABLE inv ADD(mx_orig_pallet_id VARCHAR2(18));

CREATE INDEX pm_ext_upc_k ON pm_upc(external_upc);

