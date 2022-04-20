--------------------------------------------------------------------
-- pl_ml_dec.sql
--                                                                              
-- Description:                                                                 
--     This scripts contains a package which will be used for
--     decrypting the password column of the 
--	   miniload_config table.
--                                                                             
-- Modification History:                                                        
--    Date      Designer Comments                                               
--    --------- -------- -------------------------------------------
--    3-Jan-07 CTVGG000 Created as part of the HK Integration                
--------------------------------------------------------------------

CREATE OR REPLACE PACKAGE SWMS.PL_ML_DEC 
AS   
  FUNCTION DECRYPT (p_otext  IN  VARCHAR2) RETURN VARCHAR2;
END PL_ML_DEC;
/

CREATE OR REPLACE PACKAGE BODY SWMS.PL_ML_DEC AS 
 g_key     VARCHAR2(8)  := '12345678';
 g_pad_chr VARCHAR2(1)  := '~'; 
	
-- -----------------------------------------------------
FUNCTION DECRYPT (p_otext  IN  VARCHAR2) RETURN VARCHAR2 IS
-- -----------------------------------------------------
	l_string	VARCHAR2(2048) := p_otext;
	l_decrypted VARCHAR2(2048);

	BEGIN
		dbms_obfuscation_toolkit.DESDecrypt(
			input_string => l_string,
			key_string => g_key,
			decrypted_string => l_decrypted);	
	RETURN RTRIM(l_decrypted, g_pad_chr);

	END DECRYPT;

END PL_ML_DEC;
/

