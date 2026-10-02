// Athlete identity shared by every table. Not loaded as a table.
// Rows in any export are matched to the roster by ExternalId first, then by name; exports with
// no Name column fall back to "ID <ExternalId>". Every athlete then gets a stable number, and
// AnonymizeNames swaps real names for athlete_01, athlete_02 ... (the built-in demo athletes are
// public-domain cartoon characters, so the demo always shows their names)
let
    Of = (kind as text) as table =>
        let t = Table.SelectRows(ValdFiles, each [Kind] = kind)[Data]
        in if List.IsEmpty(t) then #table({}, {}) else Table.Combine(t),
    // First of the accepted (normalised) headers that the table has
    Col = (t as table, keys as list) as list =>
        let k = List.First(List.Select(keys, each Table.HasColumns(t, _)), null)
        in if k = null then List.Repeat({null}, Table.RowCount(t)) else Table.Column(t, k),
    NameKeys = {"name", "athlete", "athletename"},
    IdKeys = {"externalid"},
    RosterRaw = Of("roster"),
    RosterNames = List.Transform(Col(RosterRaw, NameKeys), Fx[CleanName]),
    RosterIds = List.Transform(Col(RosterRaw, IdKeys), Fx[CleanName]),
    IdToName = List.Accumulate(List.Zip({RosterIds, RosterNames}), [], (acc, p) =>
        if p{0} = null or p{1} = null or Record.HasFields(acc, p{0}) then acc else Record.AddField(acc, p{0}, p{1})),
    // The name an export row belongs to
    Resolve = (name as any, extId as any) as nullable text =>
        let n = Fx[CleanName](name), id = Fx[CleanName](extId)
        in if id <> null and Record.HasFields(IdToName, id) then Record.Field(IdToName, id)
           else if n <> null then n
           else if id <> null then "ID " & id
           else null,
    DeviceRows = List.Combine(List.Transform(
        Table.SelectRows(ValdFiles, each List.Contains({"cmj", "squat", "slstand", "forceframe"}, [Kind]))[Data],
        (t) => List.Transform(List.Zip({Col(t, NameKeys), Col(t, IdKeys)}), each Resolve(_{0}, _{1})))),
    AllNames = List.Sort(List.Distinct(List.RemoveNulls(RosterNames & DeviceRows))),
    Index = Record.FromList(List.Numbers(1, List.Count(AllNames)), AllNames),
    UseDemo = DataFolder = null or Text.Trim(Text.From(DataFolder)) = "",
    Display = (name as nullable text) as nullable text =>
        if name = null then null
        else if AnonymizeNames and not UseDemo then
            (if Record.HasFields(Index, name) then "athlete_" & Text.PadStart(Text.From(Record.Field(Index, name)), 2, "0") else "athlete_??")
        else name
in
    [Resolve = Resolve, Display = Display, Of = Of, RosterRaw = RosterRaw, Names = AllNames]
