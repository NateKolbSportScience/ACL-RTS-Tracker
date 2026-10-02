// ForceDecks countermovement jumps (bilateral CMJ rows only).
let
    Raw = Athletes[Of]("cmj"),
    CmjOnly = if not Table.HasColumns(Raw, "testtype") then Raw
        else Table.SelectRows(Raw, each
            let t = if [testtype] = null then "" else Text.Lower(Text.From([testtype]))
            in (Text.Contains(t, "cmj") or Text.Contains(t, "countermovement"))
               and not Text.Contains(t, "sl") and not Text.Contains(t, "single") and not Text.Contains(t, "rebound")),
    Spec = {
        {"Name", {"Name", "Athlete", "Athlete Name"}, "text"},
        {"ExternalId", {"ExternalId", "External Id"}, "text"},
        {"Date", {"Date", "Test Date"}, "date"},
        {"Jump Height (Imp-Mom) (cm)", {"Jump Height (Imp-Mom) [cm]"}, "number"},
        {"__JumpHeightIn", {"Jump Height (Imp-Mom) in Inches [in]", "Jump Height (Imp-Mom) [in]"}, "number"},
        {"Contraction Time (ms)", {"Contraction Time [ms]"}, "number"},
        {"Peak Power / BM (W/kg)", {"Peak Power / BM [W/kg]", "Peak Power/BM [W/kg]"}, "number"},
        {"Vertical Velocity at Takeoff (m/s)", {"Vertical Velocity at Takeoff [m/s]"}, "number"},
        {"Eccentric Braking RFD (N/s)", {"Eccentric Braking RFD [N/s]"}, "number"},
        {"Force at Zero Velocity (N)", {"Force at Zero Velocity [N]"}, "number"},
        {"Concentric Impulse % (Asym) (%)", {"Concentric Impulse % (Asym) (%)", "Concentric Impulse % (Asym)"}, "text"},
        {"Eccentric Braking Impulse % (Asym) (%)", {"Eccentric Braking Impulse % (Asym) (%)", "Eccentric Braking Impulse % (Asym)"}, "text"}
    },
    Shaped = Fx[Shape](CmjOnly, Spec),
    Rows = Table.FromRecords(Table.TransformRows(Shaped, (r) => r & [
        Name = Athletes[Display](Athletes[Resolve](r[Name], r[ExternalId])),
        #"Test Type" = "CMJ",
        #"Jump Height (Imp-Mom) (cm)" = if r[#"Jump Height (Imp-Mom) (cm)"] <> null then r[#"Jump Height (Imp-Mom) (cm)"]
            else if r[__JumpHeightIn] <> null then r[__JumpHeightIn] * 2.54 else null,
        #"Eccentric Braking Impulse % (Asym) Direction" = Fx[Asym](r[#"Eccentric Braking Impulse % (Asym) (%)"]),
        #"Concentric Impulse % (Asym) Direction" = Fx[Asym](r[#"Concentric Impulse % (Asym) (%)"])]),
        Table.ColumnNames(Shaped) & {"Test Type", "Eccentric Braking Impulse % (Asym) Direction", "Concentric Impulse % (Asym) Direction"}, MissingField.UseNull),
    Valid = Table.SelectRows(Table.RemoveColumns(Rows, {"__JumpHeightIn", "ExternalId"}), each [Name] <> null and [Date] <> null),
    Typed = Table.TransformColumnTypes(Table.Distinct(Valid), {
        {"Name", type text}, {"Test Type", type text}, {"Date", type date},
        {"Jump Height (Imp-Mom) (cm)", type number}, {"Contraction Time (ms)", type number}, {"Peak Power / BM (W/kg)", type number},
        {"Vertical Velocity at Takeoff (m/s)", type number}, {"Eccentric Braking RFD (N/s)", type number},
        {"Force at Zero Velocity (N)", type number}, {"Concentric Impulse % (Asym) (%)", type text},
        {"Eccentric Braking Impulse % (Asym) (%)", type text}, {"Eccentric Braking Impulse % (Asym) Direction", type number},
        {"Concentric Impulse % (Asym) Direction", type number}})
in
    Typed
