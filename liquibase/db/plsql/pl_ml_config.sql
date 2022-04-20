-------------------------------------------------------------------------
-- Procedure:
--    p_create_links
--
-- Description:
--		Procedure to create links to the available source systems.
--		This procedure will be run whenever there is a modification to 	
--		the miniload_config table.
--
-- Parameters:
--		None
--
-- Exceptions raised:
--		None
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/26/07 ctvgg000 Created as part of the HK Automation
---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE
swms.p_create_links
authid current_user
IS

-- The following cursor gets the database information of the available 
-- miniloads from miniload_config table to create links
 CURSOR c_mnl_config
  IS
  SELECT 
	ML_SYSTEM,SWMS_ML_SYNONYM,ML_SWMS_SYNONYM,
	SWMS_ML_TABLE,ML_SWMS_TABLE,ML_INV_VIEW,
	IP_ADDR,USER_ID,PL_ML_DEC.DECRYPT(PASSWORD) as PASSWORD,
	SID 
  FROM MINILOAD_CONFIG ORDER BY  ML_SYSTEM;

 v_createLink	VARCHAR2(2000);
 v_dropLink		VARCHAR2(2000);
 v_ml_synonym	VARCHAR2(2000);
 v_ml_inv		VARCHAR2(5000);  
 v_sqlInv		VARCHAR2(5000);  
 n_counter		NUMBER(2) := 0;
 n_check		NUMBER(1) := 0;
 e_fail			EXCEPTION;

BEGIN

	-- loop through each record from miniload_config	
	
	FOR C1 IN c_mnl_config  
	LOOP

		DBMS_OUTPUT.NEW_LINE();
		DBMS_OUTPUT.PUT_LINE ('******************** ' || C1.ml_system || ' ********************');
		DBMS_OUTPUT.NEW_LINE();
		
		BEGIN									
			--Drop miniload database link if it exists.
			v_dropLink := ' DROP PUBLIC DATABASE LINK ' || C1.ml_system  || '.WORLD' ;
			EXECUTE IMMEDIATE v_dropLink;
			DBMS_OUTPUT.PUT_LINE ('Public Database Link ' || C1.ml_system || '.WORLD dropped');
			
		EXCEPTION
		WHEN OTHERS THEN NULL;					
		END;
				
		BEGIN				
			
			-- create links for each miniload database available in miniload_config.
			v_createLink := 'CREATE PUBLIC DATABASE LINK ' || C1.ml_system  || '.WORLD connect to ' || C1.user_id || ' identified by ' || C1.password || ' using'|| '''' || '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST='|| C1.ip_addr ||')(PORT=1521))(CONNECT_DATA=(SID=' || C1.SID ||')))' || '''';			
						
			EXECUTE IMMEDIATE v_createLink;								
			DBMS_OUTPUT.PUT_LINE('Public Database Link '|| C1.ml_system || '.WORLD created for Miniload system '|| C1.ml_system);
						
			
			--create synonym for HDO and HOI tables
			v_ml_synonym := 'CREATE OR REPLACE PUBLIC SYNONYM ' || C1.SWMS_ML_SYNONYM || ' FOR ' || C1.SWMS_ML_TABLE || '@' || C1.ml_system || '.WORLD'; 
			EXECUTE IMMEDIATE v_ml_synonym;		
			DBMS_OUTPUT.PUT_LINE('Public Synonym ' || C1.SWMS_ML_SYNONYM || ' created for Miniload table ' || C1.SWMS_ML_TABLE);
		
			v_ml_synonym := 'CREATE OR REPLACE PUBLIC SYNONYM ' || C1.ML_SWMS_SYNONYM || ' FOR ' || C1.ML_SWMS_TABLE || '@' || C1.ml_system || '.WORLD'; 
			EXECUTE IMMEDIATE v_ml_synonym;					
			DBMS_OUTPUT.PUT_LINE('Public Synonym ' || C1.ML_SWMS_SYNONYM || ' created for Miniload table ' || C1.ML_SWMS_TABLE);
								
		EXCEPTION
		
		WHEN OTHERS THEN 
			
			DBMS_OUTPUT.PUT_LINE('Could not create Link, Check MINILOAD_CONFIG table for Miniload ' || c1.ml_system || '! ');		
		
		END;
		
		
		IF(n_counter != 0) THEN 					

			v_ml_inv := v_ml_inv || ' UNION ALL ';			
									
		END IF;										
		
		IF(C1.SID != 'STGDIR')	THEN	
			v_ml_inv := v_ml_inv || 'SELECT SKU,QOH,EXP_DATE,STATUS,CARRIER_ID,LOCATION FROM ' || C1.ML_INV_VIEW || '@' || C1.ml_system || '.WORLD';		
		ELSE 		
			v_ml_inv := v_ml_inv || 'SELECT SKU,QOH,EXP_DATE,STATUS,CARRIER_ID,LOCATION FROM ' || C1.ML_INV_VIEW ;											
		END IF;
				
			
		n_counter	:= n_counter + 1;					
	
	END LOOP;
	
	DBMS_OUTPUT.NEW_LINE();
	DBMS_OUTPUT.PUT_LINE ('**************** MINILOAD VIEW *****************'); 
	DBMS_OUTPUT.NEW_LINE();	
	
	
	IF(n_counter != 0) THEN						
		BEGIN	 			 		
	 				
			v_sqlInv := 'CREATE OR REPLACE VIEW V_ML_INV AS ' || v_ml_inv;																
				
			EXECUTE IMMEDIATE v_sqlInv;
			EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM V_ML_INV FOR V_ML_INV';
			EXECUTE IMMEDIATE 'GRANT DELETE,SELECT,INSERT,UPDATE ON V_ML_INV TO SWMS_USER';
			EXECUTE IMMEDIATE 'GRANT SELECT ON V_ML_INV TO SWMS_VIEWER';
			DBMS_OUTPUT.PUT_LINE('Miniload View V_ML_INV created');					
	 
	EXCEPTION
		WHEN OTHERS THEN 			
			DBMS_OUTPUT.PUT_LINE('ML INV View cannot be created, One or more views not found!');									
		END;	  	
	ELSE				
		DBMS_OUTPUT.PUT_LINE('No Record in MINILOAD_CONFIG');
	END IF;
	
	DBMS_OUTPUT.NEW_LINE();
	

EXCEPTION 
  WHEN OTHERS THEN 
  DBMS_OUTPUT.PUT_LINE('Please check MINILOAD_CONFIG for correctness of data!');  
END P_CREATE_LINKS;
/ 

