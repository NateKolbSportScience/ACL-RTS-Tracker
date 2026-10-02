// Shared helpers used by every import query (not loaded as a table).
let
    // Header key: lower-case letters and digits only, so "Jump Height (Imp-Mom) [cm]",
    // "jump height (imp-mom) (cm)" and R-style "Jump.Height..Imp.Mom...cm." all match
    Key = (h as any) as text =>
        Text.Select(Text.Lower(if h = null then "" else Text.From(h)), {"a".."z", "0".."9"}),
    CleanName = (n as any) as nullable text =>
        let parts = if n = null then {} else List.Select(Text.SplitAny(Text.Trim(Text.From(n)), " #(tab)#(00A0)"), each _ <> "")
        in if List.IsEmpty(parts) then null else Text.Combine(parts, " "),
    ToNumber = (v as any) as nullable number =>
        if v = null then null
        else if v is number then v
        else
            let t = Text.Remove(Text.Trim(Text.From(v)), {"%", " ", "#(00A0)"})
            in if t = "" then null else try Number.FromText(t, "en-US") otherwise null,
    // "2026/09/08" or "2026-09-08" (year first) reads the same whatever ExportCulture is set to
    YearFirst = (t as text) as nullable date =>
        let p = Text.SplitAny(Text.BeforeDelimiter(t & " ", " "), "/-.")
        in if List.Count(p) = 3 and Text.Length(p{0}) = 4
           then try #date(Number.FromText(p{0}), Number.FromText(p{1}), Number.FromText(p{2})) otherwise null
           else null,
    ToDate = (v as any) as nullable date =>
        if v = null then null
        else if v is date then v
        else if v is datetime then DateTime.Date(v)
        else
            let t = Text.Trim(Text.From(v))
            in if t = "" then null
               else if YearFirst(t) <> null then YearFirst(t)
               else try Date.FromText(t, ExportCulture)
               otherwise try DateTime.Date(DateTime.FromText(t, ExportCulture))
               otherwise try Date.FromText(Text.BeforeDelimiter(t, " "), ExportCulture)
               otherwise null,
    // "12.3 L" -> -12.3, "8.1 R" -> 8.1 (left negative, right positive)
    Asym = (v as any) as nullable number =>
        if v = null then null
        else if v is number then v
        else
            let
                tokens = List.Select(Text.SplitAny(Text.Upper(Text.Remove(Text.Trim(Text.From(v)), {"%"})), " ()#(00A0)"), each _ <> ""),
                nums = List.RemoveNulls(List.Transform(tokens, each try Number.FromText(_, "en-US") otherwise null)),
                n = List.First(nums, null),
                isLeft = List.Contains(tokens, "L") or List.Contains(tokens, "LEFT")
            in
                if n = null then null else if isLeft then -Number.Abs(n) else Number.Abs(n),
    Converters = [
        text = (v) => if v = null then null else let t = Text.Trim(Text.From(v)) in if t = "" then null else t,
        number = ToNumber,
        date = ToDate
    ],
    // Read one CSV: detect delimiter, promote headers, normalise header names with Key
    ReadCsv = (content as binary) as table =>
        let
            first = try Lines.FromBinary(content, null, null, 65001){0} otherwise "",
            delimiter = if List.Count(Text.Split(first, ";")) > List.Count(Text.Split(first, ",")) then ";" else ",",
            promoted = Table.PromoteHeaders(Csv.Document(content, [Delimiter = delimiter, Encoding = 65001, QuoteStyle = QuoteStyle.Csv]), [PromoteAllScalars = true]),
            old = Table.ColumnNames(promoted),
            keys = List.Transform(old, Key),
            unique = List.Accumulate(List.Positions(keys), {}, (acc, i) => acc & {if List.Contains(acc, keys{i}) then keys{i} & " #" & Text.From(i) else keys{i}})
        in
            Table.RenameColumns(promoted, List.Zip({old, unique})),
    // Which VALD export is this? Decided from the headers, so file names don't matter
    Kind = (t as table) as text =>
        let c = Table.ColumnNames(t), has = (k) => List.Contains(c, k), any = (p) => List.AnyTrue(List.Transform(c, each Text.StartsWith(_, p)))
        in if has("surgerydate") or has("operatedlimb") then "roster"
           else if has("test") and has("position") and (has("lmaxforcen") or has("maximbalance")) then "forceframe"
           else if any("cop") then "slstand"
           else if List.AnyTrue(List.Transform(c, each Text.Contains(_, "jumpheight"))) then "cmj"
           else if has("eccentricdecelerationimpulseasym") or has("concentricmeanforceasym") then "squat"
           else "other",
    // Map a table onto fixed output columns. Spec rows: {output column, {accepted headers}, type}
    Shape = (t as table, spec as list) as table =>
        let
            cols = Table.ColumnNames(t),
            resolve = (aliases as list) as nullable text => List.First(List.Select(List.Transform(aliases, Key), each List.Contains(cols, _)), null),
            keys = List.Transform(spec, each resolve(_{1}))
        in
            Table.FromRecords(
                Table.TransformRows(t, (r) =>
                    Record.FromList(
                        List.Transform(List.Positions(spec), (i) => if keys{i} = null then null else Record.Field(Converters, spec{i}{2})(Record.Field(r, keys{i}))),
                        List.Transform(spec, each _{0}))),
                List.Transform(spec, each _{0}), MissingField.UseNull)
in
    [Key = Key, CleanName = CleanName, ToNumber = ToNumber, ToDate = ToDate, Asym = Asym, ReadCsv = ReadCsv, Kind = Kind, Shape = Shape]
