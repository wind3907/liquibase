CREATE OR REPLACE TRIGGER trg_upd_xdock_pm_out_brow
    /*
    ===========================================================================================================
    -- Database Trigger
    -- trg_upd_xdock_pm_out_brow
    --
    -- Description.
    -- This script has trigger which copies the update timestamp and updated by user before update on xdock_pm_out
    -- Modification History
    --
    -- Date                User                  Version            Defect  Comment
    -- 05/14/2021          Pdas8114              1.0                       Initial Creation
    ============================================================================================================
    */

    BEFORE UPDATE ON xdock_pm_out
    FOR EACH ROW
BEGIN
    :NEW.upd_date :=Sysdate;
    :NEW.upd_user := Replace(USER, 'OPS$');
END;
/
