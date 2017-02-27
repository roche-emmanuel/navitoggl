-- This is the defaut config file used by the converter.

return {
  -- The input_csv is the file from where the toggle entries are extracted
  input_csv = "D:/Cloud/Documents/Famille/Travail/Manu/Administratif/TimeReports/Navision/toggle_entries.csv",

  -- The output_csv is the file where the Navision entries are written
  output_csv = "D:/Cloud/Documents/Famille/Travail/Manu/Administratif/TimeReports/Navision/current_entries.csv",

  -- Before overriding the content of the output_csv, this content is appended to the archive_csv file if any (this can be null)
  archive_csv = "D:/Cloud/Documents/Famille/Travail/Manu/Administratif/TimeReports/Navision/entries_2017.csv"
}