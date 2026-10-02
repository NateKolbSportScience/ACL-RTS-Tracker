// ForceDecks single-leg stance: centre-of-pressure excursion per leg. Uses the export's total
// excursion when present, otherwise the resultant of the medial-lateral and anterior-posterior ranges.
let
    Spec = {
        {"Name", {"Name", "Athlete", "Athlete Name"}, "text"},
        {"ExternalId", {"ExternalId", "External Id"}, "text"},
        {"Date", {"Date", "Test Date"}, "date"},
        {"Total Excursion L (mm)", {"CoP Total Excursion [mm] (L)", "Total Excursion [mm] (L)"}, "number"},
        {"Total Excursion R (mm)", {"CoP Total Excursion [mm] (R)", "Total Excursion [mm] (R)"}, "number"},
        {"CoP Range - Medial-Lateral [mm] (L)", {"CoP Range - Medial-Lateral [mm] (L)"}, "number"},
        {"CoP Range - Medial-Lateral [mm] (R)", {"CoP Range - Medial-Lateral [mm] (R)"}, "number"},
        {"CoP Range - Anterior-Posterior [mm] (L)", {"CoP Range - Anterior-Posterior [mm] (L)"}, "number"},
        {"CoP Range - Anterior-Posterior [mm] (R)", {"CoP Range - Anterior-Posterior [mm] (R)"}, "number"}
    },
    Shaped = Fx[Shape](Athletes[Of]("slstand"), Spec),
    Resultant = (ml, ap) => if ml = null or ap = null then null else Number.Sqrt(Number.Power(ml, 2) + Number.Power(ap, 2)),
    Rows = Table.FromRecords(Table.TransformRows(Shaped, (r) => r & [
        Name = Athletes[Display](Athletes[Resolve](r[Name], r[ExternalId])),
        #"Total Excursion L (mm)" = if r[#"Total Excursion L (mm)"] <> null then r[#"Total Excursion L (mm)"]
            else Resultant(r[#"CoP Range - Medial-Lateral [mm] (L)"], r[#"CoP Range - Anterior-Posterior [mm] (L)"]),
        #"Total Excursion R (mm)" = if r[#"Total Excursion R (mm)"] <> null then r[#"Total Excursion R (mm)"]
            else Resultant(r[#"CoP Range - Medial-Lateral [mm] (R)"], r[#"CoP Range - Anterior-Posterior [mm] (R)"])]),
        Table.ColumnNames(Shaped) & {}, MissingField.UseNull),
    Valid = Table.SelectRows(Table.RemoveColumns(Rows, {"ExternalId"}), each [Name] <> null and [Date] <> null),
    Typed = Table.TransformColumnTypes(Table.Distinct(Valid), {
        {"Name", type text}, {"Date", type date}, {"Total Excursion L (mm)", type number}, {"Total Excursion R (mm)", type number},
        {"CoP Range - Medial-Lateral [mm] (L)", type number}, {"CoP Range - Medial-Lateral [mm] (R)", type number},
        {"CoP Range - Anterior-Posterior [mm] (L)", type number}, {"CoP Range - Anterior-Posterior [mm] (R)", type number}})
in
    Typed
