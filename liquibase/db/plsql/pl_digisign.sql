create or replace package swms.pl_digisign as

    function BroadcastSpurUpdate
    (
        i_location              in  varchar2,
        o_errMsg                out varchar2
    ) return pls_integer;

    function BroadcastJackpotUpdate
    (
        i_location              in  varchar2,
        o_errMsg                out varchar2
    ) return pls_integer;


end pl_digisign;
/
show errors;


create or replace package body swms.pl_digisign as

    /*----------------------------------------------------------------*/
    /* Function BroadcastSpurUpdate                                   */
    /*----------------------------------------------------------------*/

    function BroadcastSpurUpdate
    (
        i_location              in  varchar2,
        o_errMsg                out varchar2
    ) return pls_integer
    IS
        result      pls_integer := 0;
        rc          pls_integer;
        data_out    varchar2(2048);
        tcpConn     utl_tcp.connection;
        remHost     constant string(255) := 'localhost';
        remPort     constant pls_integer := 6252;

    BEGIN
        o_errMsg := null;

        select 
            '"' ||  'UPDATE_SPUR_DATA'                          || '",' ||
            '"' ||  '1.1.0.0'                                   || '",' ||
            '"' || replace( dsm.location,           '"','""')   || '",' ||
            '"' || replace( dsm.curr_batch_no,      '"','""')   || '",' ||
            '"' || replace( dsm.curr_userid,        '"','""')   || '",' ||
            '"' || replace( dsm.curr_truck_no_r,    '"','""')   || '",' ||
            '"' || replace( dsm.curr_truck_no_s,    '"','""')   || '",' ||
            '"' || replace( dsm.curr_truck_no_t,    '"','""')   || '",' ||
            '"' || replace( dsm.next_batch_no,      '"','""')   || '",' ||
            '"' || replace( dsm.next_userid,        '"','""')   || '",' ||
            '"' || replace( dsm.next_total_cases,   '"','""')   || '",' ||
            '"' || replace( dsm.next_truck_no_r,    '"','""')   || '",' ||
            '"' || replace( dsm.next_truck_no_s,    '"','""')   || '",' ||
            '"' || replace( dsm.next_truck_no_t,    '"','""')   || '",' ||
                            dsm.total_cases_all                 || ','  ||
                            dsm.total_cases_r                   || ','  ||
                            dsm.total_cases_s                   || ','  ||
                            dsm.total_cases_t                   || ','  ||
                            dsm.total_cases_ovfl                || ','  ||
                            dsm.total_cases_jackpot             || ','  ||
                            dsm.dropped_cases_all               || ','  || -- "In Lane" on monitor display
                            dsm.dropped_cases_r                 || ','  ||
                            dsm.dropped_cases_s                 || ','  ||
                            dsm.dropped_cases_t                 || ','  ||
                            dsm.dropped_cases_ovfl              || ','  ||
                            dsm.dropped_cases_jackpot           || ','  ||
                            dsm.mx_short_cases_all              || ','  ||
                            dsm.mx_short_cases_r                || ','  ||
                            dsm.mx_short_cases_s                || ','  ||
                            dsm.mx_short_cases_t                || ','  ||
                            dsm.mx_short_cases_ovfl             || ','  ||
                            dsm.mx_short_cases_jackpot          || ','  ||
                            dsm.mx_delayed_cases_all            || ','  ||
                            dsm.mx_delayed_cases_r              || ','  ||
                            dsm.mx_delayed_cases_s              || ','  ||
                            dsm.mx_delayed_cases_t              || ','  ||
                            dsm.mx_delayed_cases_ovfl           || ','  ||
                            dsm.mx_delayed_cases_jackpot        || ','  ||
                            dsm.picked_cases_all                || ','  ||
                            dsm.picked_cases_r                  || ','  ||
                            dsm.picked_cases_s                  || ','  ||
                            dsm.picked_cases_t                  || ','  ||
                            dsm.picked_cases_ovfl               || ','  ||
                            dsm.picked_cases_jackpot            || ','  ||
                            dsm.short_cases_all                 || ','  ||
                            dsm.short_cases_r                   || ','  ||
                            dsm.short_cases_s                   || ','  ||
                            dsm.short_cases_t                   || ','  ||
                            dsm.short_cases_ovfl                || ','  ||
                            dsm.short_cases_jackpot             || ','  ||
                            dsm.remaining_cases_all             || ','  ||
                            dsm.remaining_cases_r               || ','  ||
                            dsm.remaining_cases_s               || ','  ||
                            dsm.remaining_cases_t               || ','  ||
                            dsm.remaining_cases_ovfl            || ','  ||
                            dsm.remaining_cases_jackpot
        into data_out
        from swms.digisign_spur_monitor dsm
        where upper(i_location) = dsm.location;

        begin
            tcpConn := 
                utl_tcp.open_connection(
                    remote_host => remHost,
                    remote_port => remPort,
                    charset     => 'AL32UTF8',      -- was 'US7ASCII'
                    tx_timeout  => 10
                );

            rc := utl_tcp.write_line(tcpConn, data_out);

            utl_tcp.flush(tcpConn);

        exception -- we only catch UTL_TCP exceptions
            when
                utl_tcp.buffer_too_small        OR
                utl_tcp.end_of_input            OR
                utl_tcp.network_error           OR
                utl_tcp.bad_argument            OR
                utl_tcp.partial_multibyte_char  OR
                utl_tcp.transfer_timeout        OR
                utl_tcp.network_access_denied
            then
                result      := sqlcode;
                o_errMsg    := sqlerrm;
        end;

        begin
            utl_tcp.close_connection(tcpConn);
        exception
            when others then
                null;
        end;

        return result;
    exception
        when others then
            Pl_Text_Log.Ins_Msg ('FATAL', 'pl_digisign.BroadcastSpurUpdate', 'Unable to refresh SPUR monitor '||i_location, SQLCODE, SQLERRM);
            return 1;
    end BroadcastSpurUpdate;



    /*----------------------------------------------------------------*/
    /* Function BroadcastJackpotUpdate                                   */
    /*----------------------------------------------------------------*/

    function BroadcastJackpotUpdate
    (
        i_location              in  varchar2,
        o_errMsg                out varchar2
    ) return pls_integer
    IS
        result          pls_integer := 0;
        rc              pls_integer;
        data_out        varchar2(2048);

        availRows       number;
        fetchedRows     number := 0;
        csvRows         clob;

        tcpConn         utl_tcp.connection;
        remHost         constant string(255) := 'localhost';
        remPort         constant pls_integer := 6252;

    cursor c1 is    -- we want the oldest nn rows in ascending order
        select * from (
            select 
                '"' || to_char(djm.divert_time, 'YYYY-MM-DD HH24:MI:SS')    || '",' ||
                '"' || replace( djm.truck_no,           '"','""')           || '",' ||
                '"' || replace( djm.user_id,            '"','""')           || '",' ||
                '"' || replace( djm.batch_no,           '"','""')           || '",' ||
                '"' || replace( djm.batch_type,         '"','""')           || '",' ||
                '"' || replace( djm.spur_location,      '"','""')           || '",' ||
                '"' || replace( djm.case_barcode,       '"','""')           || '",' ||
                '"' || replace( djm.item_desc,          '"','""')           || '"'
            as csvRow
            from swms.digisign_jackpot_monitor djm
            where
                upper(i_location) = upper(djm.location)
            order by djm.divert_time asc
        ) query1
        where rownum <= 15
        order by rownum desc;

    BEGIN
        o_errMsg := null;

        select count(1) 
        into availRows 
        from digisign_jackpot_monitor djm 
        where upper(i_location) = upper(djm.location);
    
        for row in c1 loop
            exit when c1%notfound;
            fetchedRows := fetchedRows + 1;
            csvRows := csvRows || ',' || row.csvRow;
        end loop;

        select 
            '"' || 'UPDATE_JACKPOT_DATA'                        || '",' ||
            '"' || '1.1.0.0'                                    || '",' ||
            '"' || i_location                                   || '",' ||
                    availRows                                   || ','  ||
                    fetchedRows
        into data_out
        from dual;

        data_out := data_out || csvRows;

        begin
            tcpConn := 
                utl_tcp.open_connection(
                    remote_host => remHost,
                    remote_port => remPort,
                    charset     => 'AL32UTF8',      -- was 'US7ASCII'
                    tx_timeout  => 10
                );

            rc := utl_tcp.write_line(tcpConn, data_out);

            utl_tcp.flush(tcpConn);

        exception -- we only catch UTL_TCP exceptions
            when
                utl_tcp.buffer_too_small        OR
                utl_tcp.end_of_input            OR
                utl_tcp.network_error           OR
                utl_tcp.bad_argument            OR
                utl_tcp.partial_multibyte_char  OR
                utl_tcp.transfer_timeout        OR
                utl_tcp.network_access_denied
            then
                result      := sqlcode;
                o_errMsg    := sqlerrm;
        end;

        begin
            utl_tcp.close_connection(tcpConn);
        exception
            when others then
                null;
        end;

        return result;
    exception
        when others then
            Pl_Text_Log.Ins_Msg ('FATAL', 'pl_digisign.BroadcastJackpotUpdate', 'Unable to refresh Jackpot monitor '||i_location, SQLCODE, SQLERRM);
            return 1;   
    end BroadcastJackpotUpdate;

end pl_digisign;
/
show errors;


alter package swms.pl_digisign compile plsql_code_type = native;

grant execute on swms.pl_digisign to swms_user;
create or replace public synonym pl_digisign for swms.pl_digisign;
