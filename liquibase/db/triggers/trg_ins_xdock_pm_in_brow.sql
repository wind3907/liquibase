CREATE OR REPLACE TRIGGER trg_ins_xdock_pm_in_brow
    /*
    ===========================================================================================================
    -- Database Trigger
    -- trg_ins_xdock_pm_in_brow
    --
    -- Description.
    -- This script has trigger on xdock_pm_in
    -- Modification History
    --
    -- Date                User                  Version            Defect  Comment
    -- 05/14/2021          Pdas8114              1.0                Initial Creation
    ============================================================================================================
    */

    BEFORE INSERT ON xdock_pm_in
    FOR EACH ROW
BEGIN
    :NEW.SEQUENCE_NUMBER :=  xdock_seqno_seq.NEXTVAL;
END;
/
