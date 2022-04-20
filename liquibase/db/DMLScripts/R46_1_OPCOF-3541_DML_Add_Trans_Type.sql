SET ECHO OFF
/* *****************************************************************************
Script:   R46_1_OPCOF-3541_DML_Add_Trans_Type.sql
Purpose:  Ensure creation of the VAR transaction type for receiving variances.
History:
  Date       By       CRQ/Project Description
  ---------- -------- ----------- ----------------------------------------------
  11/02/2021 bgil6182 OPCOF-3541  Created script.
***************************************************************************** */
SET LINESIZE 300
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED
DECLARE
  This_Script                     CONSTANT  VARCHAR2(100 CHAR) := 'R46_1_OPCOF-3541_DML_Add_Trans_Type.sql';

  This_TransType                  CONSTANT  trans_type.trans_type%TYPE      := UPPER( 'VAR' );
  This_Description                CONSTANT  trans_type.descrip%TYPE         := 'Receiving Variance';
  This_Retention_Days             CONSTANT  trans_type.retention_days%TYPE  := 55;
  This_Inv_Affecting              CONSTANT  trans_type.inv_affecting%TYPE   := UPPER( 'N' );

  FUNCTION TransType_Exists( i_TransType IN VARCHAR2 ) RETURN BOOLEAN IS
    l_count     NATURAL;
  BEGIN
    SELECT COUNT(*)
      INTO l_count
      FROM swms.trans_type tt
     WHERE UPPER( tt.trans_type ) = UPPER( i_TransType );

    RETURN( l_count > 0 );
  END TransType_Exists;

BEGIN
  -- Enforce input arguments
  IF (    This_TransType      IS NULL
       OR This_Description    IS NULL
       OR This_Retention_Days IS NULL
       OR This_Inv_Affecting  IS NULL
     ) THEN
    IF ( This_TransType IS NULL ) THEN
      DBMS_Output.Put_Line( This_Script || ': missing required argument "This_TransType".' );
    END IF;
    IF ( This_Description IS NULL ) THEN
      DBMS_Output.Put_Line( This_Script || ': missing required argument "This_Description".' );
    END IF;
    IF ( This_Retention_Days IS NULL ) THEN
      DBMS_Output.Put_Line( This_Script || ': missing required argument "This_Retention_Days".' );
    END IF;
    IF ( This_Inv_Affecting IS NULL ) THEN
      DBMS_Output.Put_Line( This_Script || ': missing required argument "This_Inv_Affecting".' );
    END IF;
  ELSE  -- all input arguments are provided
    DBMS_Output.Put( This_Script || ': Adding Trans_Type ' || This_TransType );
    IF TransType_Exists( This_TransType ) THEN
      DBMS_Output.Put_Line( ' skipped, already exists.' );
    ELSE
      DBMS_Output.Put_Line( ' succeeded.' );
      INSERT INTO swms.trans_type( trans_type
                                 , descrip
                                 , retention_days
                                 , inv_affecting
                                 )
        VALUES( UPPER( This_TransType ) /*trans_type*/
              , This_Description        /*descrip*/
              , This_Retention_Days     /*retention_days*/
              , This_Inv_Affecting      /*inv_affecting*/
              );

      COMMIT;
    END IF;   /* TransType existence check */
  END IF;   /* Required arguments check */
EXCEPTION
  WHEN OTHERS THEN
    DBMS_Output.Put_Line( ' failed with exception, ' || SQLERRM );
    ROLLBACK;
    RAISE;
END;
/
