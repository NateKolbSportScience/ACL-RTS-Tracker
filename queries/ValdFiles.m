// Every CSV in DataFolder (subfolders included), or the built-in demo exports when DataFolder
// is blank, read and tagged with the kind of export it is. Not loaded as a table.
let
    UseDemo = DataFolder = null or Text.Trim(Text.From(DataFolder)) = "",
    Demo = (b64 as text) as binary => Binary.Decompress(Binary.FromText(b64, BinaryEncoding.Base64), Compression.Deflate),
    DemoFiles = #table({"Content", "Name", "Extension"}, {
        {Demo("DEMO_ATHLETES"), "athletes.csv", ".csv"},
        {Demo("DEMO_CMJ"), "forcedecks_cmj_demo.csv", ".csv"},
        {Demo("DEMO_SQUAT"), "forcedecks_squat_demo.csv", ".csv"},
        {Demo("DEMO_SLSTAND"), "forcedecks_slstand_demo.csv", ".csv"},
        {Demo("DEMO_FORCEFRAME"), "forceframe_demo.csv", ".csv"}}),
    Probe = if UseDemo then [HasError = true] else try Table.RowCount(Folder.Files(DataFolder)),
    AllFiles =
        if UseDemo then DemoFiles
        else if Probe[HasError] then #table({"Content", "Name", "Extension"}, {})
        else Folder.Files(DataFolder),
    CsvFiles = Table.SelectRows(AllFiles, each Text.Lower([Extension]) = ".csv" and not Text.StartsWith([Name], "~$")),
    Read = Table.AddColumn(CsvFiles, "Data", each try Table.Buffer(Fx[ReadCsv]([Content])) otherwise null),
    Valid = Table.SelectRows(Read, each [Data] <> null),
    Tagged = Table.AddColumn(Valid, "Kind", each Fx[Kind]([Data]), type text)
in
    Table.Buffer(Table.SelectColumns(Tagged, {"Name", "Kind", "Data"}))
