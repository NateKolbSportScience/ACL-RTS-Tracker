"""Simulated VALD exports for the ACL RTS Tracker demo.

Built from scratch: no real athlete data is used or derived. Three post-ACL-reconstruction
athletes (public-domain cartoon characters) at different stages, each with ~6 months of
healthy pre-injury baseline testing, of rehab are simulated across ForceDecks (CMJ, squat,
single-leg stand) and ForceFrame. The operated limb's strength recovers towards
the other side along exponential curves (quadriceps slowest, rate of force development
slower than peak force), jump and squat asymmetries close over time, and every test has
test-retest noise. One athlete recovers slowly and sits a phase behind the calendar.

Writes one CSV per device plus the athlete roster into sample_data/.
"""
import csv
from datetime import datetime
import math
import random
from datetime import date, timedelta
from pathlib import Path

SEED = 412
G = 9.81
OUT = Path(__file__).resolve().parent.parent / "sample_data"
LAST_TEST = date(2026, 9, 28)

# Demo athletes are early cartoon characters whose original 1927-28 versions are in the US public
# domain (Wikimedia Commons). Not affiliated with or endorsed by Disney.
# name, external id, operated limb, surgery date, current phase id, recovery speed (1 = typical), photo
COMMONS = "https://commons.wikimedia.org/wiki/Special:FilePath/{}?width=300"
ATHLETES = [
    ("Mickey Mouse", "DEMO101", "Right", date(2025, 11, 10), 4, 1.10,
     COMMONS.format("Mickey_Mouse_-_Steamboat_Willie_(1928).jpg")),
    ("Oswald the Lucky Rabbit", "DEMO102", "Left", date(2026, 2, 9), 3, 1.00,
     COMMONS.format("Oswald_the_Lucky_Rabbit_(1928).svg")),
    ("Pete", "DEMO103", "Right", date(2026, 3, 9), 2, 0.60,          # slow responder, a phase behind the calendar
     COMMONS.format("Pete_in_Steamboat_Willie_(1928)_(cropped).jpg")),
]

FD_COMMON = ["Name", "ExternalId", "Test Type", "Date", "Time", "BW [KG]", "Reps", "Tags", "Additional Load [lb]"]
CMJ_HEADERS = FD_COMMON + [
    "Jump Height (Imp-Mom) [cm]", "Contraction Time [ms] ", "Peak Power / BM [W/kg] ", "Bodyweight in Pounds [lbs] ",
    "CMJ Stiffness [N/m] ", "Vertical Velocity at Takeoff [m/s] ", "Eccentric Braking RFD [N/s] ",
    "Positive Impulse [N s] ", "Concentric Mean Force [N] ", "Concentric Impulse % (Asym) (%)",
    "Velocity at Peak Power [m/s] ", "Force at Zero Velocity [N] ", "Countermovement Depth [cm] ",
    "Eccentric Braking Impulse % (Asym) (%)"]
SQUAT_HEADERS = FD_COMMON + [
    "Eccentric Deceleration Impulse % (Asym) (%)", "Concentric Mean Force % (Asym) (%)",
    "Eccentric Mean Force % (Asym) (%)", "Concentric Mean Force [N] ", "Eccentric Mean Force [N] ",
    "Countermovement Depth [cm] "]
SLS_HEADERS = FD_COMMON + [
    "CoP Range - Medial-Lateral [mm] (L)", "CoP Range - Medial-Lateral [mm] (R)",
    "CoP Range - Anterior-Posterior [mm] (L)", "CoP Range - Anterior-Posterior [mm] (R)",
    "CoP Total Excursion [mm] (L)", "CoP Total Excursion [mm] (R)",
    "CoP Mean Velocity [mm/s] (L)", "CoP Mean Velocity [mm/s] (R)",
    "Test Duration [s] (L)", "Test Duration [s] (R)"]
FF_HEADERS = ["Name", "ExternalId", "Date", "Time", "Test", "Direction", "Position", "Mode", "L Reps", "R Reps",
              "L Max Force (N)", "R Max Force (N)", "Max Imbalance", "L Avg Force (N)", "R Avg Force (N)",
              "Avg Imbalance", "L Max RFD (N/s)", "R Max RFD (N/s)", "Tags"]
ROSTER_HEADERS = ["Name", "ExternalId", "Injury Type", "Surgery Date", "Operated Limb", "Current Phase ID", "Photo URL"]

# ForceFrame tests the tracker reads: (test, direction, position, healthy max force range N, recovery tau weeks, start deficit)
FF_TESTS = [
    ("Knee Extension", "Pull", "Knee Extension - Seated (90)", (420, 560), 16, 0.45),
    ("Knee Flexion", "Pull", "Knee Flexion - Custom", (240, 340), 13, 0.30),
    ("Hip Extension", "Pull", "Hip Extension - Prone", (280, 380), 10, 0.22),
]


def us_date(d: date) -> str:
    return f"{d.month}/{d.day}/{d.year}"


def clock(rng: random.Random) -> str:
    h, m = rng.choice([8, 9, 10, 11, 13, 14]), rng.randint(0, 59)
    return f"{(h - 1) % 12 + 1}:{m:02d} {'AM' if h < 12 else 'PM'}"


def asym_text(value: float) -> str:
    """ForceDecks style: magnitude then the higher side, e.g. '6.4 L'."""
    return f"{abs(value):.1f} {'L' if value < 0 else 'R'}"


def lsi(week: float, start_deficit: float, tau: float, speed: float) -> float:
    """Limb symmetry index of the operated side (0-1), recovering exponentially."""
    return 1 - start_deficit * math.exp(-max(week, 0) * speed / tau)


def sided(op: str, operated: float, other: float):
    """Return (left, right) given operated/non-operated values."""
    return (operated, other) if op == "Left" else (other, operated)


def sessions(surgery: date, from_week: int, every_weeks: int, rng: random.Random):
    d = surgery + timedelta(weeks=from_week)
    d -= timedelta(days=d.weekday())            # Monday of that week
    while d <= LAST_TEST:
        if rng.random() < 0.96:                  # occasional missed session
            yield min(d + timedelta(days=rng.choice([0, 0, 1, 2])), LAST_TEST)
        d += timedelta(weeks=every_weeks)


def pre_injury(surgery: date, every_weeks: int, rng: random.Random):
    """Healthy baseline testing in the ~6 months before the injury (injury 3 weeks before surgery)."""
    injury = surgery - timedelta(weeks=3)
    d = injury - timedelta(weeks=24)
    d -= timedelta(days=d.weekday())
    while d < injury - timedelta(days=4):
        if rng.random() < 0.9:
            yield d + timedelta(days=rng.choice([0, 0, 1, 2]))
        d += timedelta(weeks=every_weeks)


def main():
    rng = random.Random(SEED)
    rows = {k: [] for k in ("cmj", "squat", "sls", "ff")}
    roster = []
    for name, ext, op, surgery, phase, speed, photo in ATHLETES:
        roster.append([name, ext, "ACL", surgery.isoformat(), op, phase, photo])
        sign_op = -1 if op == "Left" else 1               # ForceDecks asym sign of the operated side being higher
        bw = rng.uniform(78, 100)
        ff_base = {t[2]: rng.uniform(*t[3]) for t in FF_TESTS}
        jh_base, depth = rng.uniform(36, 46), rng.uniform(28, 36)
        ct_base = rng.uniform(680, 820)
        sway = rng.uniform(430, 520)

        def week(d):
            return (d - surgery).days / 7

        # ForceFrame knee / hip isometrics: pre-injury baseline, then from week 4 roughly every 3 weeks
        for d in [*pre_injury(surgery, 3, rng), *sessions(surgery, 4, 3, rng)]:
            w = week(d)
            healthy = d < surgery
            t = clock(rng)
            for test, direction, position, _, tau, deficit in FF_TESTS:
                if healthy:
                    good, bad = (ff_base[position] * rng.gauss(1, 0.04) for _ in range(2))
                else:
                    good = ff_base[position] * min(1.0, 0.9 + w * 0.005) * rng.gauss(1, 0.04)
                    bad = ff_base[position] * lsi(w, deficit, tau, speed) * rng.gauss(1, 0.05)
                lf, rf = sided(op, bad, good)
                rfd_lsi = 1.0 if healthy else lsi(w, deficit + 0.12, tau * 1.3, speed)
                lr, rr = sided(op, bad / (1.0 if healthy else lsi(w, deficit, tau, speed)) * rfd_lsi * 6.2 * rng.gauss(1, 0.05),
                               good * 6.2 * rng.gauss(1, 0.05))
                la, ra = lf * rng.uniform(0.86, 0.93), rf * rng.uniform(0.86, 0.93)
                rows["ff"].append([name, ext, us_date(d), t, test, direction, position, "ISO", 3, 3,
                                   f"{lf:.1f}", f"{rf:.1f}", f"{abs(lf - rf) / max(lf, rf) * 100:.1f}",
                                   f"{la:.1f}", f"{ra:.1f}", f"{abs(la - ra) / max(la, ra) * 100:.1f}",
                                   f"{lr:.0f}", f"{rr:.0f}", ""])

        # ForceDecks squat and single-leg stand: pre-injury baseline, then from week 8 roughly every 3 weeks
        for d in [*pre_injury(surgery, 6, rng), *sessions(surgery, 8, 3, rng)]:
            w = week(d)
            healthy = d < surgery
            if healthy:
                ecc, conc, eccm = rng.gauss(0, 3), rng.gauss(0, 2), rng.gauss(0, 2)
            else:
                ecc = -sign_op * (2 + 18 * math.exp(-(w - 8) * speed / 10)) + rng.gauss(0, 1.5)
                conc = -sign_op * (1.5 + 10 * math.exp(-(w - 8) * speed / 10)) + rng.gauss(0, 1.2)
                eccm = -sign_op * (1.5 + 9 * math.exp(-(w - 8) * speed / 11)) + rng.gauss(0, 1.2)
            cmf = bw * G * rng.uniform(1.05, 1.15)
            rows["squat"].append([name, ext, "SQT", us_date(d), clock(rng), f"{bw:.1f}", 5, "", 0,
                                  asym_text(ecc), asym_text(conc), asym_text(eccm), f"{cmf:.0f}",
                                  f"{cmf * rng.uniform(0.95, 1.0):.0f}", f"{-rng.uniform(55, 70):.1f}"])
            op_exc = sway * (1 if healthy else 1 + 0.75 * math.exp(-(w - 8) * speed / 9)) * rng.gauss(1, 0.07)
            ok_exc = sway * rng.gauss(1, 0.06)
            ex_l, ex_r = sided(op, op_exc, ok_exc)
            row = [name, ext, "SLSB", us_date(d), clock(rng), f"{bw:.1f}", 1, "", 0]
            ml = [ex * rng.uniform(0.045, 0.06) for ex in (ex_l, ex_r)]
            ap = [ex * rng.uniform(0.08, 0.10) for ex in (ex_l, ex_r)]
            row += [f"{ml[0]:.1f}", f"{ml[1]:.1f}", f"{ap[0]:.1f}", f"{ap[1]:.1f}",
                    f"{ex_l:.0f}", f"{ex_r:.0f}", f"{ex_l / 20:.1f}", f"{ex_r / 20:.1f}", 20, 20]
            rows["sls"].append(row)

        # ForceDecks CMJ: pre-injury baseline every 2 weeks, then weekly from week 12
        for d in [*pre_injury(surgery, 2, rng), *sessions(surgery, 12, 1, rng)]:
            w = week(d)
            healthy = d < surgery
            prog = 0.0 if healthy else math.exp(-(w - 12) * speed / 14)
            jh = jh_base * (1 - 0.35 * prog) * rng.gauss(1, 0.04)
            v = math.sqrt(2 * G * jh / 100)
            dep = depth * (1 - 0.25 * prog) * rng.gauss(1, 0.05)
            cmf = bw * G * (1 + jh / dep)
            fzv = cmf * rng.uniform(1.12, 1.2)
            ct = ct_base * (1 + 0.30 * prog) * rng.gauss(1, 0.04)      # slower, longer jumps early in rehab
            if healthy:
                ecc, conc = rng.gauss(0, 3), rng.gauss(0, 2)
            else:
                ecc = -sign_op * (3 + 22 * math.exp(-(w - 12) * speed / 12)) + rng.gauss(0, 2)
                conc = -sign_op * (2 + 13 * math.exp(-(w - 12) * speed / 12)) + rng.gauss(0, 1.5)
            rows["cmj"].append([
                name, ext, "CMJ", us_date(d), clock(rng), f"{bw:.1f}", 3, "", 0,
                f"{jh:.1f}", f"{ct:.0f}", f"{21 * v * rng.gauss(1, 0.03):.2f}", f"{bw * 2.20462:.1f}",
                f"{fzv / (dep / 100):.0f}", f"{v:.3f}", f"{fzv * rng.uniform(1.8, 2.6) * (1 - 0.3 * prog):.0f}",
                f"{bw * v + bw * G * ct / 1000 * 0.5:.1f}", f"{cmf:.0f}", asym_text(conc),
                f"{v * rng.uniform(0.92, 0.97):.3f}", f"{fzv:.0f}", f"{-dep:.1f}", asym_text(ecc)])

    OUT.mkdir(parents=True, exist_ok=True)
    files = [("athletes.csv", ROSTER_HEADERS, roster),
             ("forcedecks_cmj_demo.csv", CMJ_HEADERS, rows["cmj"]),
             ("forcedecks_squat_demo.csv", SQUAT_HEADERS, rows["squat"]),
             ("forcedecks_slstand_demo.csv", SLS_HEADERS, rows["sls"]),
             ("forceframe_demo.csv", FF_HEADERS, rows["ff"])]
    for fname, headers, data in files:
        if fname != "athletes.csv":
            i = headers.index("Date")
            data.sort(key=lambda r: (r[0], datetime.strptime(r[i], "%m/%d/%Y")))
        with open(OUT / fname, "w", newline="") as f:
            csv.writer(f).writerows([headers] + data)
        print(f"{fname}: {len(data)} rows")


if __name__ == "__main__":
    main()
