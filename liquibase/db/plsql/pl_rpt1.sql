rem *****************************************************
rem @(#) src/schema/plsql/pl_rpt1.sql, swms, swms.9, 10.1.1 9/7/06 1.3

rem @(#) File : pl_rpt1.sql
rem @(#) Usage: sqlplus USR/PWD pl_rpt1.sql 

rem ---  Maintenance history  ---
rem 11-MAY-2000 prpksn Initial version

rem *****************************************************

/* This is the SPECIFICATION FOR THE PACKAGE */
create or replace PACKAGE swms.pl_rpt1 as
   g_rpt_tbl    report_table%ROWTYPE;

   PROCEDURE ins_where_cond (i_session_id in varchar2,
			     i_line_no    in number,
			     i_page_break in number,
			     i_where_cond in varchar2,
			     i_error_track_no in varchar2); 

   PROCEDURE ins_report_table ;

   PROCEDURE prt_title_head (i_which_line  in number,
			     i_title       in varchar2,
			     i_report_name in varchar2,
			     o_info out varchar2);
end pl_rpt1;
/

/* PACKAGE BODY FOR PROCEDURES AND FUNCTION */
create or replace PACKAGE BODY swms.pl_rpt1 as

/* ========================================================================== */
   PROCEDURE ins_report_table is

   begin 
     insert into report_table
       (user_session_id,user_id,line_no,page_break,report_type,text)
     values
       (g_rpt_tbl.user_session_id,  replace(USER,'OPS$',null),
	g_rpt_tbl.line_no,          g_rpt_tbl.page_break,
	g_rpt_tbl.report_type,      g_rpt_tbl.text);

     commit;
   end ins_report_table;

   PROCEDURE ins_where_cond (i_session_id in varchar2,
			     i_line_no    in number,
			     i_page_break in number,
			     i_where_cond in varchar2,
			     i_error_track_no in varchar2) is
     l_cond_length  number(3);
   begin
   /* This procedure assume that the max condition that will allow here
      is 3 lines. Each line can contain 116 characters.Max will be 350 */
      g_rpt_tbl.user_session_id := i_session_id;
      g_rpt_tbl.page_break := i_page_break;
      g_rpt_tbl.report_type := 'WHERE';

      g_rpt_tbl.line_no := i_line_no + 1;
      g_rpt_tbl.text := rpad(' ',120);
      ins_report_table;

      g_rpt_tbl.line_no := i_line_no + 1;
      g_rpt_tbl.text := rpad('Error Track No. : '|| i_error_track_no,120);
      ins_report_table;

      g_rpt_tbl.line_no := g_rpt_tbl.line_no + 1;
      g_rpt_tbl.text := rpad('Search Criteria : ',120);
      ins_report_table;
      l_cond_length := length(i_where_cond);
      if l_cond_length < 117 then
	 g_rpt_tbl.line_no := g_rpt_tbl.line_no + 1;
	 g_rpt_tbl.text := i_where_cond;
         ins_report_table;
      elsif l_cond_length between 117 and 233 then
	 g_rpt_tbl.line_no := g_rpt_tbl.line_no + 1;
	 g_rpt_tbl.text := substr(i_where_cond,1,116);
         ins_report_table;
	 g_rpt_tbl.line_no := g_rpt_tbl.line_no + 1;
	 g_rpt_tbl.text := substr(i_where_cond,117,116);
         ins_report_table;
      elsif l_cond_length between 234 and 350 then
	 g_rpt_tbl.line_no := g_rpt_tbl.line_no + 1;
	 g_rpt_tbl.text := substr(i_where_cond,1,116);
         ins_report_table;
	 g_rpt_tbl.line_no := g_rpt_tbl.line_no + 1;
	 g_rpt_tbl.text := substr(i_where_cond,117,116);
         ins_report_table;
	 g_rpt_tbl.line_no := g_rpt_tbl.line_no + 1;
	 g_rpt_tbl.text := substr(i_where_cond,234,116);
         ins_report_table;
      end if;
   end ins_where_cond;

   PROCEDURE prt_title_head (i_which_line  in number,
			     i_title       in varchar2,
			     i_report_name in varchar2,
			     o_info out varchar2) is
    /* o_info is for debugging purpose to see the lenght and string */
    t_today_dt  varchar2(18);
    t_company   varchar2(20);
    t_title     varchar2(50);
    t_first_pad number;
    t_second_pad number;
    t_max_length number := 118;
    t_len_report  number;
    t_len_date number;

    cursor get_maint is
       select to_char(sysdate,'MM/DD/RRRR HH24:MI'),
	      attribute_value
       from maintenance
       where component = 'COMPANY';
    begin
      g_rpt_tbl.report_type := 'TITLE';
      open get_maint;
      fetch get_maint into t_today_dt,t_company;
      if get_maint%notfound then
	  t_today_dt := to_char(sysdate,'MM/DD/RRRR HH24:MI');
	  t_company := 'CANNOT BE FOUND';
      end if;
      t_title := '  ' || i_title || ' ';
      t_len_report := length(i_report_name) + 1;
      /* Process First line of title */
      if i_which_line = 1 then
         t_first_pad := trunc((length(t_title)/2) + (t_max_length/2)) - t_len_report;

	 /* The -5 is for to include the total page print like Page 1 of 10 */
         t_second_pad := t_max_length - t_first_pad - t_len_report - 5;
         g_rpt_tbl.text := i_report_name || ' ' ||
	       lpad(t_title,t_first_pad,' ') || 
	       lpad('PAGE ' || to_char(g_rpt_tbl.page_break),t_second_pad,' ');

          o_info := g_rpt_tbl.text;
      elsif i_which_line = 2 then   /* Process Second line */
          t_len_date := length(t_today_dt) + 1;
          t_first_pad := trunc((length(t_company)/2) + (t_max_length/2)) - t_len_date;
          t_second_pad := t_max_length - t_first_pad - t_len_date;
          g_rpt_tbl.text := t_today_dt || ' ' ||
        		       lpad(t_company,t_first_pad,' ') || 
        		       lpad(replace(USER,'OPS$',null),t_second_pad,' ');
           o_info := g_rpt_tbl.text;
      else
	 o_info := 'Invalid line parameter pass to printing title';
      end if;
   end prt_title_head;
end pl_rpt1;
/
