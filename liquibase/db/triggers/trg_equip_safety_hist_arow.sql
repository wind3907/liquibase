CREATE OR REPLACE TRIGGER swms.trg_equip_safety_hist_arow
AFTER INSERT ON swms.equip_safety_hist
FOR EACH ROW
WHEN (NEW.STATUS = 'X')
DECLARE
------------------------------------------------------------------------------
-- Table:
--    EQUIP_SAFETY_HIST
--
-- Description:
--    This trigger performs various actions when any equipment details are 
--    added or updated.
--
-- Exceptions raised:
--    
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/10/10 ykri0358 swms212 Created
--                      Project: swms212-Equipment defect details should  
--                      be sent to SAP ECC for SAP OPCO(SCI087). 
--    04/21/14 bnim1623 add equip table validation (charm6*1025)
--    11/08/19 pkab6563 Jira card OPCOF-778: changed validation of equip_id
--                      to be from equipment and equip instead of equip only.
------------------------------------------------------------------------------

    l_object_name       VARCHAR2(30) := 'trg_equip_safety_hist_arow'; -- Object Name 
    
   -- l_sapflag           VARCHAR2(6);    -- SAP or Non SAP OpCo 
    
    l_message           VARCHAR2(70);  -- Message for error logging
    
    l_inspection_date   VARCHAR2(19);
    l_equip_name        sap_equip_out.equip_name%TYPE;
            
BEGIN
    
    /*BEGIN 
        SELECT config_flag_val 
        INTO l_sapflag
        FROM sys_config
        WHERE config_flag_name = 'HOST_TYPE';
        
    EXCEPTION 
        WHEN OTHERS THEN
            l_message := 'Error in reading host_type information';
            pl_log.ins_msg('INFO', l_object_name, l_message, SQLCODE, SQLERRM, 'MAINTAINENCE', 'TRG_EQUIP_SAFETY_HIST_AROW.SQL','N');
    END; */
    
    --IF l_sapflag = 'SAP' THEN
    
        l_inspection_date := to_char(:NEW.add_date,'MM/DD/YYYY HH:MI:SS');
        
        BEGIN
        
            SELECT name
            INTO l_equip_name
            FROM equip_param
            WHERE seq = :NEW.seq 
              and (Exists (SELECT 1 FROM equipment WHERE equip_id = :NEW.equip_id)
                   OR 
                   Exists (SELECT 1 FROM equip WHERE equip_id = :NEW.equip_id));
            
            IF SQLCODE = 0 THEN 
                BEGIN
                    INSERT INTO SAP_EQUIP_OUT
                    (sequence_number, interface_type, record_status, datetime,
                    equip_id, inspection_date, equip_name, status, 
                    add_user, add_date, upd_user, upd_date)
                    values(SAP_EQUIP_SEQ.nextval, 'EQUIP', 'N', SYSDATE,
                    :NEW.equip_id, to_date(l_inspection_date, 'MM/DD/YYYY HH24:MI:SS'), l_equip_name, :NEW.status_type, 
                    replace(USER,'OPS$',NULL), SYSDATE, replace(USER,'OPS$',NULL), SYSDATE);
            
                    IF SQLCODE = 0 THEN 
                        l_message := 'SAP_EQUIP_OUT INSERT SUCESSFUL EQUIP#:'|| :NEW.equip_id || ',' ||  :NEW.add_date || ',' || :NEW.status_type;
                        pl_log.ins_msg('INFO', l_object_name, l_message, NULL, NULL, 'MAINTAINENCE', 'TRG_EQUIP_SAFETY_HIST_AROW.SQL','N');
                    END IF;
                
                EXCEPTION
                    WHEN OTHERS THEN 
                        l_message := 'SAP_EQUIP_OUT INSERT FAILED EQUIP#:'|| :NEW.equip_id || ',' ||  :NEW.add_date || ',' || :NEW.status_type;
                        pl_log.ins_msg('FATAL', l_object_name, l_message, SQLCODE, SQLERRM, 'MAINTAINENCE', 'TRG_EQUIP_SAFETY_HIST_AROW.SQL','Y');
                END;
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN 
                l_message := 'EQUIP_PARAM RETRIEVAL OF NAME FAILED EQUIP#:'|| :NEW.equip_id ;
                pl_log.ins_msg('INFO', l_object_name, l_message, SQLCODE, SQLERRM, 'MAINTAINENCE', 'TRG_EQUIP_SAFETY_HIST_AROW.SQL','N');
                        
        END;
           
    --END IF;
    
END trg_equip_safety_hist_arow;
/ 
