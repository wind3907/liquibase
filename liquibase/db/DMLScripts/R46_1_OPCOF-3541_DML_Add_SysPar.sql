SET ECHO OFF
/* *****************************************************************************
Script:   R46_1_OPCOF-3541_DML_Add_SysPar.sql
Purpose:  Ensure creation of the RECEIVING/OSD_OPCO_SWMS system parameter and
          default the value to (N)o. For OSD reasons to be collected, the OpCo
          must be affirmatively configured.
History:
  Date       By       CRQ/Project Description
  ---------- -------- ----------- ----------------------------------------------
  09/28/2021 bgil6182 OPCOF-3541  Created script.
  12/15/2021 bgil6182 OPCOF-3541  Changed use of SYS_CONFIG_SEQ.NextVal to
                                  MAX(Sys_Config.Seq_No)+1
***************************************************************************** */
SET LINESIZE 300
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED
DECLARE
  This_Script                    CONSTANT VARCHAR2(100 CHAR) := 'R46_1_OPCOF-3541_DML_Add_SysPar.sql';

  This_Application               CONSTANT sys_config.application_func%TYPE := 'RECEIVING';
  This_SysparName                CONSTANT sys_config.config_flag_name%TYPE := 'OSD_OPCO_SWMS';
  l_NextSysPar                            sys_config.seq_no%TYPE;

  FUNCTION SysPar_Exists( i_Application IN VARCHAR2
                        , i_SysParName  IN VARCHAR2 ) RETURN BOOLEAN IS
    l_count     NATURAL;
  BEGIN
    SELECT COUNT(*)
      INTO l_count
      FROM swms.sys_config sp
     WHERE UPPER( sp.application_func ) = UPPER( i_Application )
       AND UPPER( sp.config_flag_name ) = UPPER( i_SysParName  );

    RETURN( l_count > 0 );
  END SysPar_Exists;

BEGIN
  IF ( This_Application IS NULL OR This_SysparName IS NULL ) THEN
    IF ( This_Application IS NULL ) THEN
      DBMS_Output.Put_Line( This_Script || ': missing required argument "This_Application".' );
    END IF;
    IF ( This_SysparName IS NULL ) THEN
      DBMS_Output.Put_Line( This_Script || ': missing required argument "This_SysparName".' );
    END IF;
  ELSE
    DBMS_Output.Put( This_Script || ': Adding SysPar ' || This_Application || '/' || This_SysparName );
    IF SysPar_Exists( This_Application, This_SysparName ) THEN
      DBMS_Output.Put_Line( ' skipped, already exists.' );
    ELSE
      DBMS_Output.Put_Line( ' succeeded.' );
      SELECT MAX( sp.seq_no )+1
        INTO l_NextSysPar
        FROM swms.sys_config sp;
      INSERT INTO swms.sys_config( seq_no          , application_func, config_flag_name
                                 , config_flag_desc, config_flag_val , value_required
                                 , value_updateable, value_is_boolean, data_type
                                 , data_precision  , data_scale      , sys_config_list
                                 , sys_config_help , lov_query       , validation_type
                                 , range_low       , range_high      , disabled_flag )
        VALUES( l_NextSysPar                                                                              /*seq_no*/
              , UPPER( This_Application )                                                                 /*application_func*/
              , UPPER( This_SysparName )                                                                  /*config_flag_name*/
              , 'Display OpCo Rec. variances'                                                             /*config_flag_desc*/
              , 'N'                                                                                       /*config_flag_val*/
              , 'N'                                                                                       /*value_required*/
              , 'Y'                                                                                       /*value_updateable*/
              , 'Y'                                                                                       /*value_is_boolean*/
              , 'CHAR'                                                                                    /*data_type*/
              , 1                                                                                         /*data_precision*/
              , NULL                                                                                      /*data_scale*/
              , 'L'                                                                                       /*sys_config_list*/
              , 'Y = display variances and collect reason during receiving, N = do not display variances' /*sys_config_help*/
              , NULL                                                                                      /*lov_query*/
              , NULL                                                                                      /*validation_type*/
              , NULL                                                                                      /*range_low*/
              , NULL                                                                                      /*range_high*/
              , 'N'                                                                                       /*disabled_flag*/
              );

      INSERT INTO swms.sys_config_valid_values( config_flag_name, config_flag_val, description, param_values )
        VALUES( UPPER( This_SysparName )                                                                  /*config_flag_name*/
              , 'N'                                                                                       /*config_flag_val*/
              , 'SWMS receiving variances will not be displayed.'                                         /*description*/
              , NULL                                                                                      /*param_values*/
              );

      INSERT INTO swms.sys_config_valid_values( config_flag_name, config_flag_val, description, param_values )
        VALUES( UPPER( This_SysparName )                                                                  /*config_flag_name*/
              , 'Y'                                                                                       /*config_flag_val*/
              , 'SWMS receiving variances will be displayed and reason codes will be collected.'          /*description*/
              , NULL                                                                                      /*param_values*/
              );

      COMMIT;
    END IF;   /* SysPar existence check */
  END IF;   /* Required arguments check */
EXCEPTION
  WHEN OTHERS THEN
    DBMS_Output.Put_Line( 'failed with exception, ' || SQLERRM );
    ROLLBACK;
    RAISE;
END;
/
