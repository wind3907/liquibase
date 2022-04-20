DECLARE
        n_count                                 PLS_INTEGER;
        SQL_stmt                                VARCHAR2(2000 CHAR);

BEGIN
      
  SELECT COUNT(*)
  INTO n_count
        FROM user_constraints
  WHERE table_name = 'CROSS_DOCK_PALLET_XREF'
        AND constraint_name = 'CROSS_DOCK_PALLET_XREF_PK';  

  IF N_COUNT > 0 THEN
   SQL_stmt :=
    'ALTER TABLE SWMS.CROSS_DOCK_PALLET_XREF DROP CONSTRAINT CROSS_DOCK_PALLET_XREF_PK'; 
            EXECUTE IMMEDIATE SQL_stmt;    
  END IF;
        
  SELECT COUNT(*)
  INTO n_count
  FROM user_constraints
  WHERE table_name = 'CROSS_DOCK_XREF'
        AND constraint_name = 'ERM_ID_UNIQUE';  

  IF N_COUNT > 0 THEN
     SQL_stmt := 'ALTER TABLE SWMS.CROSS_DOCK_XREF DROP CONSTRAINT ERM_ID_UNIQUE';
            EXECUTE IMMEDIATE SQL_stmt;
  END IF;

  SELECT COUNT(*)
  INTO n_count
  FROM user_constraints
  WHERE table_name = 'CROSS_DOCK_PALLET_XREF'
    AND constraint_name = 'CROSS_DOCK_PALLET_XREF_PK';  

   IF N_COUNT = 0 THEN
             SQL_stmt := 'ALTER TABLE CROSS_DOCK_PALLET_XREF '
      || 'ADD CONSTRAINT CROSS_DOCK_PALLET_XREF_PK PRIMARY KEY (RETAIL_CUST_NO, PARENT_PALLET_ID, ERM_ID, SYS_ORDER_ID ) ';
          
         EXECUTE IMMEDIATE SQL_stmt;         

   END IF;
END;
/

