### Usage

Usage: oma-tool.ps1 [OPTIONS]

OPTIONS:

   -h, Help          : Display this screen.
   
   -SourceFolder     : Source folder that contains AWR reports in HTML format. Default is '.' (current directory).
   
   -TemplateFileName : Excel templatethat will be used for capacity estimations. Default is '.\AWR Analysis template spreadsheet.xlsx'.

oma-tool.ps1 -SourceFolder "C:\Reports" -TemplateFileName "C:\Templates\AWR Analysis template spreadsheet.xlsx"
