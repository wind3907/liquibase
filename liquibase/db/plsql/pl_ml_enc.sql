--------------------------------------------------------------------
-- pl_ml_enc.sql
--                                                                              
-- Description:                                                                 
--     This scripts contains a package which will be used for
--     encrypting the password column of the 
--	   miniload_config table.
--                                                                             
-- Modification History:                                                        
--    Date      Designer Comments                                               
--    --------- -------- -------------------------------------------
--    3-Jan-07 CTVGG000 Created as part of the HK Integration                
--------------------------------------------------------------------

CREATE OR REPLACE PACKAGE SWMS.PL_ML_ENC 
AS 
  FUNCTION ENCRYPT (p_itext  IN  VARCHAR2) RETURN VARCHAR2;
  
END PL_ML_ENC;
/

CREATE OR REPLACE PACKAGE BODY SWMS.PL_ML_ENC AS 
 g_key     VARCHAR2(8)  := '12345678';
 g_pad_chr VARCHAR2(1)  := '~'; 

PROCEDURE padstring (p_text  IN OUT  VARCHAR2);

-- ----------------------------------------------------- 
FUNCTION ENCRYPT (p_itext  IN  VARCHAR2) RETURN VARCHAR2 IS 
-- ----------------------------------------------------- 

	l_string VARCHAR2(2048) := p_itext;
	l_encrypted VARCHAR2(2048);
		
	BEGIN	
	
	padstring(l_string);
	
	dbms_obfuscation_toolkit.DESEncrypt(
		    input_string => l_string,
			key_string => g_key,
			encrypted_string =>l_encrypted);
	RETURN l_encrypted;
	
	END ENCRYPT;	

-- --------------------------------------------------
PROCEDURE PADSTRING (p_text  IN OUT  VARCHAR2) IS
-- --------------------------------------------------
	l_units  NUMBER;
	BEGIN
    
		IF LENGTH(p_text) MOD 8 > 0 THEN
			l_units := TRUNC(LENGTH(p_text)/8) + 1;
			p_text  := RPAD(p_text, l_units * 8, g_pad_chr);
		END IF;
	END PADSTRING;
-- --------------------------------------------------
END PL_ML_ENC;
/

