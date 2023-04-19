### Usage

Usage: oma-tool.ps1 [OPTIONS]

OPTIONS:

   -h, Help          : Display this screen.
   
   -SourceFolder     : Source folder that contains AWR reports in HTML format. Default is '.' (current directory).
   
   -OutputFile       : Full path of the Excel file that will be created as output. Default is same name as SourceFolder directory name with XLSX extension under SourceFolder directory.
   
   -AzureRegion      : Name of the Azure region to be used when generating Azure resource recommendations. Default is 'westus'.
   
SAMPLE:   
   oma-tool.ps1 -SourceFolder "C:\Reports" -TemplateFileName "C:\Templates\AWR Analysis template spreadsheet.xlsx"
