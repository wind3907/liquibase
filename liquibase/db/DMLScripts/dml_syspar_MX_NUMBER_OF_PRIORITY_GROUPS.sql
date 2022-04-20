
--SET ECHO ON


/****************************************************************************
** Date:       18-AUG-2015
** Programmer: Brian Bent
** File:       dml_syspar_MX_NUMBER_OF_PRIORITY_GROUPS.sql
** Project:    Symbotic
** 
** This script creates syspar MX_NUMBER_OF_PRIORITY_GROUPS.
** This syspar is used in assigning the matrix priority to the
** FLOATS.MX_PRIORITY column for each normal selection batch within a wave
** (a wave is the route batch number) that is sent to the matrix.
**
** The matrix priority is basically a sub-wave that Symbotic
** uses to process the batches within a wave.  The syspar controls how
** how many sub-waves the batches in a wave are split into which in turn
** determines the matrix priority.  The matrix priority starts with 1 for the
** first sub-wave then 2 for the next sub-wave, and so on.
**
** There will always be as many sub-waves as the value of
** MX_NUMBER_OF_PRIORITY_GROUPS unless the number of batches in the wave is
** less than the MX_NUMBER_OF_PRIORITY_GROUPS.
**
** ** Remember we can have multiple floats per batch so that the value in **
** ** FLOATS.MX_PRIORITY will be the same for each float on the batch.    **
**
** Examples of assigning value to FLOATS.MX_PRIORITY:
**
============================================================================
   Setup:
   MX_NUMBER_OF_PRIORITY_GROUPS: 3
   Number of Normal Selection Batches in the Wave: 58
   Maximum Number Of Floats on Each Batch: 3

ROUTE_BATCH_NO   BATCH_NO   FLOAT_NO PALLET_PULL ROUTE_NO   FLOA MX_PRIORITY
-------------- ---------- ---------- ----------- ---------- ---- -----------
       5478289     381944    7871981 R           6628
       5478289     381944    7872023 R           6632
       5478289     381944    7872024 R           6632
       5478289     381945    7871989 B           6630       D2
       5478289     381946    7871973 N           6628       D2             1
       5478289     381946    7871982 N           6629       D5             1
       5478289     381946    7871990 N           6630       D11            1
       5478289     381949    7872002 N           6631       D11            1
       5478289     381949    7872015 N           6632       D6             1
       5478289     381949    7872025 N           6633       D6             1
       5478289     381952    7871974 N           6628       D1             1
       5478289     381952    7871976 N           6628       D3             1
       5478289     381952    7871978 N           6628       D4             1
       5478289     381953    7871975 N           6628       D5             1
       5478289     381953    7871977 N           6628       D6             1
       5478289     381953    7871979 N           6628       D7             1
       5478289     381954    7871980 N           6628       D8             1
       5478289     381954    7872022 N           6632       D8             1
       5478289     381954    7872033 N           6633       D9             1
       5478289     381955    7871983 N           6629       D1             1
       5478289     381955    7871984 N           6629       D2             1
       5478289     381955    7871985 N           6629       D3             1
       5478289     381956    7871986 N           6629       D4             1
       5478289     381956    7871987 N           6629       D6             1
       5478289     381956    7871988 N           6629       D7             1
       5478289     381957    7871991 N           6630       D1             2
       5478289     381957    7871992 N           6630       D3             2
       5478289     381957    7871993 N           6630       D4             2
       5478289     381958    7871994 N           6630       D5             2
       5478289     381958    7871996 N           6630       D6             2
       5478289     381958    7871998 N           6630       D7             2
       5478289     381959    7871995 N           6630       D9             2
       5478289     381959    7871997 N           6630       D8             2
       5478289     381959    7871999 N           6630       D10            2
       5478289     381960    7872000 N           6630       D12            2
       5478289     381960    7872001 N           6630       D13            2
       5478289     381960    7872032 N           6633       D8             2
       5478289     381961    7872003 N           6631       D3             2
       5478289     381961    7872005 N           6631       D2             2
       5478289     381961    7872006 N           6631       D1             2
       5478289     381962    7872004 N           6631       D4             2
       5478289     381962    7872007 N           6631       D5             2
       5478289     381962    7872008 N           6631       D6             2
       5478289     381963    7872009 N           6631       D7             3
       5478289     381963    7872010 N           6631       D8             3
       5478289     381963    7872011 N           6631       D9             3
       5478289     381964    7872012 N           6631       D10            3
       5478289     381964    7872013 N           6631       D12            3
       5478289     381964    7872014 N           6631       D13            3
       5478289     381965    7872016 N           6632       D1             3
       5478289     381965    7872017 N           6632       D2             3
       5478289     381965    7872018 N           6632       D3             3
       5478289     381966    7872019 N           6632       D4             3
       5478289     381966    7872020 N           6632       D5             3
       5478289     381966    7872021 N           6632       D7             3
       5478289     381968    7872026 N           6633       D2             3
       5478289     381968    7872027 N           6633       D1             3
       5478289     381968    7872028 N           6633       D3             3
       5478289     381969    7872029 N           6633       D4             3
       5478289     381969    7872030 N           6633       D5             3
       5478289     381969    7872031 N           6633       D7             3
61 rows selected.

Selecting the distinct records on the wave:

ROUTE_BATCH_NO   BATCH_NO PALLET_PULL MX_PRIORITY
-------------- ---------- ----------- -----------
       5478289     381944 R
       5478289     381945 B
       5478289     381946 N                     1
       5478289     381949 N                     1
       5478289     381952 N                     1
       5478289     381953 N                     1
       5478289     381954 N                     1
       5478289     381955 N                     1
       5478289     381956 N                     1
       5478289     381957 N                     2
       5478289     381958 N                     2
       5478289     381959 N                     2
       5478289     381960 N                     2
       5478289     381961 N                     2
       5478289     381962 N                     2
       5478289     381963 N                     3
       5478289     381964 N                     3
       5478289     381965 N                     3
       5478289     381966 N                     3
       5478289     381968 N                     3
       5478289     381969 N                     3
21 rows selected.
============================================================================


============================================================================
Same data but with MX_NUMBER_OF_PRIORITY_GROUPS: 4

ROUTE_BATCH_NO   BATCH_NO   FLOAT_NO PALLET_PULL ROUTE_NO   FLOA MX_PRIORITY
-------------- ---------- ---------- ----------- ---------- ---- -----------
       5478289     381944    7871981 R           6628
       5478289     381944    7872023 R           6632
       5478289     381944    7872024 R           6632
       5478289     381945    7871989 B           6630       D2
       5478289     381946    7871973 N           6628       D2             1
       5478289     381946    7871982 N           6629       D5             1
       5478289     381946    7871990 N           6630       D11            1
       5478289     381949    7872002 N           6631       D11            1
       5478289     381949    7872015 N           6632       D6             1
       5478289     381949    7872025 N           6633       D6             1
       5478289     381952    7871974 N           6628       D1             1
       5478289     381952    7871976 N           6628       D3             1
       5478289     381952    7871978 N           6628       D4             1
       5478289     381953    7871975 N           6628       D5             1
       5478289     381953    7871977 N           6628       D6             1
       5478289     381953    7871979 N           6628       D7             1
       5478289     381954    7871980 N           6628       D8             2
       5478289     381954    7872022 N           6632       D8             2
       5478289     381954    7872033 N           6633       D9             2
       5478289     381955    7871983 N           6629       D1             2
       5478289     381955    7871984 N           6629       D2             2
       5478289     381955    7871985 N           6629       D3             2
       5478289     381956    7871986 N           6629       D4             2
       5478289     381956    7871987 N           6629       D6             2
       5478289     381956    7871988 N           6629       D7             2
       5478289     381957    7871991 N           6630       D1             2
       5478289     381957    7871992 N           6630       D3             2
       5478289     381957    7871993 N           6630       D4             2
       5478289     381958    7871994 N           6630       D5             3
       5478289     381958    7871996 N           6630       D6             3
       5478289     381958    7871998 N           6630       D7             3
       5478289     381959    7871995 N           6630       D9             3
       5478289     381959    7871997 N           6630       D8             3
       5478289     381959    7871999 N           6630       D10            3
       5478289     381960    7872000 N           6630       D12            3
       5478289     381960    7872001 N           6630       D13            3
       5478289     381960    7872032 N           6633       D8             3
       5478289     381961    7872003 N           6631       D3             3
       5478289     381961    7872005 N           6631       D2             3
       5478289     381961    7872006 N           6631       D1             3
       5478289     381962    7872004 N           6631       D4             4
       5478289     381962    7872007 N           6631       D5             4
       5478289     381962    7872008 N           6631       D6             4
       5478289     381963    7872009 N           6631       D7             4
       5478289     381963    7872010 N           6631       D8             4
       5478289     381963    7872011 N           6631       D9             4
       5478289     381964    7872012 N           6631       D10            4
       5478289     381964    7872013 N           6631       D12            4
       5478289     381964    7872014 N           6631       D13            4
       5478289     381965    7872016 N           6632       D1             4
       5478289     381965    7872017 N           6632       D2             4
       5478289     381965    7872018 N           6632       D3             4
       5478289     381966    7872019 N           6632       D4             5
       5478289     381966    7872020 N           6632       D5             5
       5478289     381966    7872021 N           6632       D7             5
       5478289     381968    7872026 N           6633       D2             5
       5478289     381968    7872027 N           6633       D1             5
       5478289     381968    7872028 N           6633       D3             5
       5478289     381969    7872029 N           6633       D4             5
       5478289     381969    7872030 N           6633       D5             5
       5478289     381969    7872031 N           6633       D7             5

61 rows selected.

Selecting the distinct records on the wave:

ROUTE_BATCH_NO   BATCH_NO PALLET_PULL MX_PRIORITY
-------------- ---------- ----------- -----------
       5478289     381944 R
       5478289     381945 B
       5478289     381946 N                     1
       5478289     381949 N                     1
       5478289     381952 N                     1
       5478289     381953 N                     1
       5478289     381954 N                     2
       5478289     381955 N                     2
       5478289     381956 N                     2
       5478289     381957 N                     2
       5478289     381958 N                     3
       5478289     381959 N                     3
       5478289     381960 N                     3
       5478289     381961 N                     3
       5478289     381962 N                     4
       5478289     381963 N                     4
       5478289     381964 N                     4
       5478289     381965 N                     4
       5478289     381966 N                     5
       5478289     381968 N                     5
       5478289     381969 N                     5

21 rows selected.
============================================================================

============================================================================
Same data but with MX_NUMBER_OF_PRIORITY_GROUPS: 1

ROUTE_BATCH_NO   BATCH_NO   FLOAT_NO PALLET_PULL ROUTE_NO   FLOA MX_PRIORITY
-------------- ---------- ---------- ----------- ---------- ---- -----------
       5478289     381944    7871981 R           6628
       5478289     381944    7872023 R           6632
       5478289     381944    7872024 R           6632
       5478289     381945    7871989 B           6630       D2
       5478289     381946    7871973 N           6628       D2             1
       5478289     381946    7871982 N           6629       D5             1
       5478289     381946    7871990 N           6630       D11            1
       5478289     381949    7872002 N           6631       D11            1
       5478289     381949    7872015 N           6632       D6             1
       5478289     381949    7872025 N           6633       D6             1
       5478289     381952    7871974 N           6628       D1             1
       5478289     381952    7871976 N           6628       D3             1
       5478289     381952    7871978 N           6628       D4             1
       5478289     381953    7871975 N           6628       D5             1
       5478289     381953    7871977 N           6628       D6             1
       5478289     381953    7871979 N           6628       D7             1
       5478289     381954    7871980 N           6628       D8             1
       5478289     381954    7872022 N           6632       D8             1
       5478289     381954    7872033 N           6633       D9             1
       5478289     381955    7871983 N           6629       D1             1
       5478289     381955    7871984 N           6629       D2             1
       5478289     381955    7871985 N           6629       D3             1
       5478289     381956    7871986 N           6629       D4             1
       5478289     381956    7871987 N           6629       D6             1
       5478289     381956    7871988 N           6629       D7             1
       5478289     381957    7871991 N           6630       D1             1
       5478289     381957    7871992 N           6630       D3             1
       5478289     381957    7871993 N           6630       D4             1
       5478289     381958    7871994 N           6630       D5             1
       5478289     381958    7871996 N           6630       D6             1
       5478289     381958    7871998 N           6630       D7             1
       5478289     381959    7871995 N           6630       D9             1
       5478289     381959    7871997 N           6630       D8             1
       5478289     381959    7871999 N           6630       D10            1
       5478289     381960    7872000 N           6630       D12            1
       5478289     381960    7872001 N           6630       D13            1
       5478289     381960    7872032 N           6633       D8             1
       5478289     381961    7872003 N           6631       D3             1
       5478289     381961    7872005 N           6631       D2             1
       5478289     381961    7872006 N           6631       D1             1
       5478289     381962    7872004 N           6631       D4             1
       5478289     381962    7872007 N           6631       D5             1
       5478289     381962    7872008 N           6631       D6             1
       5478289     381963    7872009 N           6631       D7             1
       5478289     381963    7872010 N           6631       D8             1
       5478289     381963    7872011 N           6631       D9             1
       5478289     381964    7872012 N           6631       D10            1
       5478289     381964    7872013 N           6631       D12            1
       5478289     381964    7872014 N           6631       D13            1
       5478289     381965    7872016 N           6632       D1             1
       5478289     381965    7872017 N           6632       D2             1
       5478289     381965    7872018 N           6632       D3             1
       5478289     381966    7872019 N           6632       D4             1
       5478289     381966    7872020 N           6632       D5             1
       5478289     381966    7872021 N           6632       D7             1
       5478289     381968    7872026 N           6633       D2             1
       5478289     381968    7872027 N           6633       D1             1
       5478289     381968    7872028 N           6633       D3             1
       5478289     381969    7872029 N           6633       D4             1
       5478289     381969    7872030 N           6633       D5             1
       5478289     381969    7872031 N           6633       D7             1
61 rows selected.

ROUTE_BATCH_NO   BATCH_NO PALLET_PULL MX_PRIORITY
-------------- ---------- ----------- -----------
       5478289     381944 R
       5478289     381945 B
       5478289     381946 N                     1
       5478289     381949 N                     1
       5478289     381952 N                     1
       5478289     381953 N                     1
       5478289     381954 N                     1
       5478289     381955 N                     1
       5478289     381956 N                     1
       5478289     381957 N                     1
       5478289     381958 N                     1
       5478289     381959 N                     1
       5478289     381960 N                     1
       5478289     381961 N                     1
       5478289     381962 N                     1
       5478289     381963 N                     1
       5478289     381964 N                     1
       5478289     381965 N                     1
       5478289     381966 N                     1
       5478289     381968 N                     1
       5478289     381969 N                     1
21 rows selected.







**
** 
**
**
** This script needs to be run once when the changes are installed at
** the OpCo.  Inadvertently running this script again will not cause any
** problems.
**
** Records are inserted into tables:
**    - SYS_CONFIG
**
** Syspars Added:
**    - MX_NUMBER_OF_PRIORITY_GROUPS
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    06/08/15 prpbcb   Created.
**
****************************************************************************/


/********************************************************************
**    Insert the syspars
********************************************************************/

COL maxseq_no NOPRINT NEW_VALUE maxseq;

/********************************************************************
**    Create sypar NON_FIFO_COMBINE_PLTS_IN_FLOAT
********************************************************************/
/* Get the max sequence number used in sys_config table. */
SELECT MAX(seq_no) maxseq_no FROM sys_config
/

INSERT INTO sys_config
   (seq_no,
    application_func,
    config_flag_name, 
    config_flag_desc,
    config_flag_val,
    value_required,
    value_updateable,
    value_is_boolean,
    data_type,
    data_precision,
    data_scale,
    sys_config_list,
    lov_query,
    validation_type,
    range_low,
    range_high,
    sys_config_help)
SELECT
   &maxseq + 1 seq_no,
   'MATRIX'                            application_func, 
   'MX_NUMBER_OF_PRIORITY_GROUPS'      config_flag_name,
   'Matrix Nbr of Priority Groups'     config_flag_desc,
   '3'                                 config_flag_val,
   'Y'                                 value_required,
   'Y'                                 value_updateable,
   'N'                                 value_is_boolean,
   'NUMBER'                            data_type,
   2                                   data_precision,
   0                                   data_scale,
   'R'                                 sys_config_list,
   NULL                                lov_query,
   'RANGE'                             validation_type,
   1                                   range_low,
   10                                  range_high,
'This syspar is used in assigning the matrix priority to each selection batch within a wave that is sent to the matrix.'
|| '  Within a wave Symbotic processes the lower matrix priority first.'
|| CHR(10) || CHR(10)
|| 'The matrix priority is basically a sub-wave that Symbotic uses to process'
|| ' the batches within a wave.  The syspar controls how' 
|| ' many sub-waves the batches in a wave are split into which in turn'
|| ' determines the matrix priority.  The matrix priority starts with 1 for the'
|| ' first sub-wave then 2 for the next sub-wave, and so on.'
|| CHR(10) || CHR(10)
|| 'Example:'
|| CHR(10)
|| 'Syspar value: 3'
|| CHR(10)
|| 'Number of Normal Selection Batches in the Wave Sent to Symbotic: 7'
|| CHR(10)
|| 'Wave Number' || CHR(9) || CHR(9) || 'Batch Number' || CHR(9) || CHR(9) || 'Matrix Priority Set To'
|| CHR(10)
|| ' 1210' || CHR(9) || CHR(9) || CHR(9) || '832001' || CHR(9) || CHR(9) || CHR(9) || CHR(9) || '1'
|| CHR(10)
|| ' 1210' || CHR(9) || CHR(9) || CHR(9) || '832002' || CHR(9) || CHR(9) || CHR(9) || CHR(9) || '1'
|| CHR(10)
|| ' 1210' || CHR(9) || CHR(9) || CHR(9) || '832003' || CHR(9) || CHR(9) || CHR(9) || CHR(9) || '1'
|| CHR(10)
|| ' 1210' || CHR(9) || CHR(9) || CHR(9) || '832004' || CHR(9) || CHR(9) || CHR(9) || CHR(9) || '2'
|| CHR(10)
|| ' 1210' || CHR(9) || CHR(9) || CHR(9) || '832005' || CHR(9) || CHR(9) || CHR(9) || CHR(9) || '2'
|| CHR(10)
|| ' 1210' || CHR(9) || CHR(9) || CHR(9) || '832006' || CHR(9) || CHR(9) || CHR(9) || CHR(9) || '3'
|| CHR(10)
|| ' 1210' || CHR(9) || CHR(9) || CHR(9) || '832007' || CHR(9) || CHR(9) || CHR(9) || CHR(9) || '3' sys_config_help
 FROM DUAL
/


