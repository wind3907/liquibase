INSERT INTO trans_type (trans_type, descrip, retention_days, inv_affecting) 
SELECT 'PIT', 'Putaway from PIT location', 55, 'N' FROM dual WHERE NOT EXISTS (select 1 from trans_type where trans_type = 'PIT');
commit;