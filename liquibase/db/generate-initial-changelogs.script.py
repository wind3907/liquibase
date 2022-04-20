from os import listdir
from os.path import isfile, join

RELEASES_DIRECTORY = './schema/releases/'
OUTPUT_DIRECTORY = './liquibase/db/changelog/'
SCHEMA_DIRECTORY = './schema/'
DDL_SCRIPT_DIRECTORY = '../DDLScripts/'
DML_SCRIPT_DIRECTORY = '../DMLScripts/'


# read a file and print it
def read_from_sql(filename, write_file):
    infile = open(filename, 'r')
    data = infile.readlines()
    ddl = False
    dml = False
    for line in data:
        if "DDL Scripts - START" in line:
            ddl = True
            write_line_to_xml("""
    <!-- DDL Scripts - START -->""", write_file)
        if "DDL Scripts - END" in line:
            ddl = False
            write_line_to_xml("""
    <!-- DDL Scripts - END -->""", write_file)
        if "DML Scripts - START" in line:
            dml = True
            write_line_to_xml("""
    <!-- DML Scripts - START -->""", write_file)
        if "DML Scripts - END" in line:
            dml = False
            write_line_to_xml("""
    <!-- DML Scripts - END -->""", write_file)
        if ddl and "PROMPT Running Script:" in line:
            write_change_set_to_xml(line.split("PROMPT Running Script:")[1].strip(), "ddl", write_file)
        if dml and "PROMPT Running Script:" in line:
            write_change_set_to_xml(line.split("PROMPT Running Script:")[1].strip(), "dml", write_file)
    infile.close()


# write to a file
def write_line_to_xml(line, write_file):
    outfile = open(write_file, 'a')
    outfile.write(line)
    outfile.close()


# write to a file
def write_change_set_to_xml(line, type, write_file):
    global unique_id
    outfile = open(write_file, 'a')
    if type == "ddl":
        outfile.write("""
    <changeSet author="initial" id="{}">
        <sqlFile dbms="postgresql"
            encoding="UTF-8"
            path="{}"
            relativeToChangelogFile="true"/>
    </changeSet>""".format(unique_id, DDL_SCRIPT_DIRECTORY + line))
        unique_id += 1
    if type == "dml":
        outfile.write("""
    <changeSet author="initial" id="{}">
        <sqlFile dbms="postgresql"
            encoding="UTF-8"
            path="{}"
            relativeToChangelogFile="true"/>
    </changeSet>""".format(unique_id, DML_SCRIPT_DIRECTORY + line))
        unique_id += 1
    outfile.close()


if __name__ == '__main__':
    unique_id = 1
    master_sql_files = [f for f in listdir(RELEASES_DIRECTORY) if isfile(join(RELEASES_DIRECTORY, f))]
    for file in master_sql_files:
        output_file = OUTPUT_DIRECTORY + "db.changelog-" + '.'.join(file.split(".")[0].split("_")[:2]) + ".xml"
        write_line_to_xml("""
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xmlns:pro="http://www.liquibase.org/xml/ns/pro"
xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
  http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.1.xsd
  http://www.liquibase.org/xml/ns/pro
  http://www.liquibase.org/xml/ns/pro/liquibase-pro-4.1.xsd">
        """, output_file)
        read_from_sql(RELEASES_DIRECTORY + file, output_file)
        write_line_to_xml("\n</databaseChangeLog>\n", output_file)
    print("Script exeuted successfully")



