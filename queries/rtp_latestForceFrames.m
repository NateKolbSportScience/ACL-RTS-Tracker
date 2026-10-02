// ForceFrame isometric tests. Prone knee flexion is recorded with the athlete face-down, so its
// left and right sides are swapped back to the athlete's own left and right.
let
    Spec = {
        {"Name", {"Name", "Athlete", "Athlete Name"}, "text"},
        {"ExternalId", {"ExternalId", "External Id"}, "text"},
        {"Date", {"Date", "Test Date"}, "date"},
        {"Test", {"Test"}, "text"},
        {"Direction", {"Direction"}, "text"},
        {"Position", {"Position"}, "text"},
        {"L Max Force (N)", {"L Max Force (N)"}, "number"},
        {"R Max Force (N)", {"R Max Force (N)"}, "number"},
        {"Max Imbalance", {"Max Imbalance", "Max Imbalance (%)"}, "number"},
        {"L Max RFD (N/s)", {"L Max RFD (N/s)"}, "number"},
        {"R Max RFD (N/s)", {"R Max RFD (N/s)"}, "number"}
    },
    Shaped = Fx[Shape](Athletes[Of]("forceframe"), Spec),
    Rows = Table.FromRecords(Table.TransformRows(Shaped, (r) =>
        let
            prone = r[Position] = "Knee Flexion - Prone",
            l = if prone then r[#"R Max Force (N)"] else r[#"L Max Force (N)"],
            rr = if prone then r[#"L Max Force (N)"] else r[#"R Max Force (N)"]
        in r & [
            Name = Athletes[Display](Athletes[Resolve](r[Name], r[ExternalId])),
            #"L Max Force (N)" = l,
            #"R Max Force (N)" = rr,
            #"L Max RFD (N/s)" = if prone then r[#"R Max RFD (N/s)"] else r[#"L Max RFD (N/s)"],
            #"R Max RFD (N/s)" = if prone then r[#"L Max RFD (N/s)"] else r[#"R Max RFD (N/s)"],
            #"Max Imbalance" = if r[#"Max Imbalance"] <> null then Number.Abs(r[#"Max Imbalance"])
                else if l = null or rr = null or List.Max({l, rr}) = 0 then null
                else Number.Abs(l - rr) / List.Max({l, rr}) * 100]),
        Table.ColumnNames(Shaped) & {}, MissingField.UseNull),
    NonZero = (x) => x <> null and x <> 0,
    // Drop the empty half of one-direction tests (both sides 0, e.g. knee extension "Squeeze")
    Valid = Table.SelectRows(Table.RemoveColumns(Rows, {"ExternalId"}), each [Name] <> null and [Date] <> null
        and (NonZero([#"L Max Force (N)"]) or NonZero([#"R Max Force (N)"]))),
    Typed = Table.TransformColumnTypes(Table.Distinct(Valid), {
        {"Name", type text}, {"Date", type date}, {"Test", type text}, {"Direction", type text}, {"Position", type text},
        {"L Max Force (N)", type number}, {"R Max Force (N)", type number}, {"Max Imbalance", type number},
        {"L Max RFD (N/s)", type number}, {"R Max RFD (N/s)", type number}})
in
    Typed
