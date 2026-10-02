// ForceDecks squat assessments: eccentric deceleration and concentric mean force asymmetry.
let
    Spec = {
        {"Name", {"Name", "Athlete", "Athlete Name"}, "text"},
        {"ExternalId", {"ExternalId", "External Id"}, "text"},
        {"Date", {"Date", "Test Date"}, "date"},
        {"Eccentric Deceleration Impulse % (Asym) (%)", {"Eccentric Deceleration Impulse % (Asym) (%)", "Eccentric Deceleration Impulse % (Asym)"}, "text"},
        {"Concentric Mean Force % (Asym) (%)", {"Concentric Mean Force % (Asym) (%)", "Concentric Mean Force % (Asym)"}, "text"}
    },
    Shaped = Fx[Shape](Athletes[Of]("squat"), Spec),
    Rows = Table.FromRecords(Table.TransformRows(Shaped, (r) => r & [
        Name = Athletes[Display](Athletes[Resolve](r[Name], r[ExternalId])),
        #"Ecc Decel Asym %" = let a = Fx[Asym](r[#"Eccentric Deceleration Impulse % (Asym) (%)"]) in if a = null then null else Number.Abs(a),
        #"Conc Mean Force Asym %" = let a = Fx[Asym](r[#"Concentric Mean Force % (Asym) (%)"]) in if a = null then null else Number.Abs(a)]),
        Table.ColumnNames(Shaped) & {"Ecc Decel Asym %", "Conc Mean Force Asym %"}, MissingField.UseNull),
    Valid = Table.SelectRows(Table.RemoveColumns(Rows, {"ExternalId"}), each [Name] <> null and [Date] <> null),
    Typed = Table.TransformColumnTypes(Table.Distinct(Valid), {
        {"Name", type text}, {"Date", type date},
        {"Eccentric Deceleration Impulse % (Asym) (%)", type text}, {"Concentric Mean Force % (Asym) (%)", type text},
        {"Ecc Decel Asym %", type number}, {"Conc Mean Force Asym %", type number}})
in
    Typed
