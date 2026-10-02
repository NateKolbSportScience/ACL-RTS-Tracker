// Athlete roster: surgery date, operated limb, current phase and an optional photo URL. The phase is set by hand
// (athletes can be ahead of or behind the calendar). Athletes found in the exports but missing
// from the roster still appear, with blank surgery details.
let
    Spec = {
        {"Name", {"Name", "Athlete", "Athlete Name"}, "text"},
        {"ExternalId", {"ExternalId", "External Id"}, "text"},
        {"Injury Type", {"Injury Type", "Injury"}, "text"},
        {"Surgery Date", {"Surgery Date", "Date of Surgery"}, "date"},
        {"Operated Limb", {"Operated Limb", "Limb", "Side"}, "text"},
        {"Current Phase ID", {"Current Phase ID", "Phase ID", "Phase"}, "text"},
        {"Photo URL", {"Photo URL", "Photo", "Headshot", "Image URL"}, "text"}
    },
    Roster = Fx[Shape](Athletes[RosterRaw], Spec),
    Limb = (v) => if v = null then null else let t = Text.Upper(Text.Start(Text.Trim(v), 1)) in if t = "L" then "Left" else if t = "R" then "Right" else null,
    Rows = Table.FromRecords(Table.TransformRows(Roster, (r) => r & [
        Name = Athletes[Display](Athletes[Resolve](r[Name], r[ExternalId])),
        #"Operated Limb" = Limb(r[#"Operated Limb"]),
        #"Injury Type" = if r[#"Injury Type"] = null then "ACL" else r[#"Injury Type"],
        #"Current Phase ID" = if r[#"Current Phase ID"] = null then "1" else Text.From(r[#"Current Phase ID"])]),
        Table.ColumnNames(Roster) & {}, MissingField.UseNull),
    FromRoster = Table.SelectRows(Table.RemoveColumns(Rows, {"ExternalId"}), each [Name] <> null),
    InData = List.Transform(Athletes[Names], Athletes[Display]),          // everyone in any export
    Missing = List.Difference(InData, FromRoster[Name]),
    Extra = Table.FromRecords(List.Transform(Missing, each [Name = _, #"Injury Type" = "ACL", #"Surgery Date" = null, #"Operated Limb" = null, #"Current Phase ID" = "1", #"Photo URL" = null])),
    All = Table.Distinct(Table.Combine({FromRoster, Extra}), {"Name"}),
    Typed = Table.TransformColumnTypes(All, {{"Name", type text}, {"Injury Type", type text}, {"Surgery Date", type date}, {"Operated Limb", type text}, {"Current Phase ID", type text}, {"Photo URL", type text}})
in
    Typed
