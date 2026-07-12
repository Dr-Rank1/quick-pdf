import { X, Shield, Wifi, Lock, Zap, GitMerge, Camera, Star } from "lucide-react";

const AMBER = "#FFB300";
const NAVY  = "#1A237E";

// ── Shared helpers ────────────────────────────────────────────────────────────

function Badge({ children, amber }: { children: string; amber?: boolean }) {
  return (
    <span style={{ background: amber ? `${AMBER}20` : "rgba(255,255,255,0.12)", border: `1px solid ${amber ? AMBER + "50" : "rgba(255,255,255,0.2)"}`, borderRadius: 24, padding: "6px 16px", fontSize: 13, fontWeight: 700, color: amber ? AMBER : "rgba(255,255,255,0.85)", whiteSpace: "nowrap" }}>
      {children}
    </span>
  );
}

function DocCard({ name, type, size, date, fav, accent }: { name: string; type: "pdf" | "img"; size: string; date: string; fav?: boolean; accent?: string }) {
  const clr = type === "pdf" ? "#E53935" : "#4CAF50";
  return (
    <div style={{ background: "rgba(255,255,255,0.07)", borderRadius: 14, padding: 12, border: "1px solid rgba(255,255,255,0.1)", backdropFilter: "blur(8px)" }}>
      <div style={{ aspectRatio: "3/4", background: "rgba(255,255,255,0.05)", borderRadius: 8, marginBottom: 10, display: "flex", alignItems: "center", justifyContent: "center", position: "relative", overflow: "hidden", border: accent ? `1px solid ${accent}30` : undefined }}>
        <div style={{ position: "absolute", inset: 0, padding: "10px 8px", display: "flex", flexDirection: "column", gap: 4 }}>
          {[72, 56, 80, 50, 68, 44].map((w, i) => <div key={i} style={{ height: 2.5, background: "rgba(255,255,255,0.1)", borderRadius: 2, width: `${w}%` }} />)}
        </div>
        <div style={{ position: "absolute", top: 0, right: 0, width: 16, height: 16, background: "rgba(6,10,30,0.8)", borderBottomLeftRadius: 5 }} />
        <div style={{ background: clr, borderRadius: 4, padding: "3px 8px", fontSize: 11, fontWeight: 800, color: "#fff", letterSpacing: "0.06em", position: "relative", zIndex: 1, marginTop: 8 }}>
          {type === "pdf" ? "PDF" : "IMG"}
        </div>
        {fav && <div style={{ position: "absolute", top: 6, right: 6, color: AMBER, fontSize: 13, filter: "drop-shadow(0 1px 3px rgba(0,0,0,0.5))" }}>★</div>}
      </div>
      <div style={{ fontSize: 11, fontWeight: 700, color: "#EEF1FF", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", marginBottom: 3 }}>{name}</div>
      <div style={{ fontSize: 10, color: "rgba(255,255,255,0.4)" }}>{size} · {date}</div>
    </div>
  );
}

function ToolIcon({ icon: Icon, color, label }: { icon: React.ComponentType<{ size: number; color: string }>; color: string; label: string }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 8 }}>
      <div style={{ width: 64, height: 64, borderRadius: 18, background: `${color}22`, border: `1px solid ${color}40`, display: "flex", alignItems: "center", justifyContent: "center", boxShadow: `0 4px 20px ${color}30` }}>
        <Icon size={28} color={color} />
      </div>
      <span style={{ fontSize: 10, fontWeight: 700, color: "rgba(255,255,255,0.7)", textAlign: "center", lineHeight: 1.2 }}>{label}</span>
    </div>
  );
}

function PhoneChrome({ children, style }: { children: React.ReactNode; style?: React.CSSProperties }) {
  return (
    <div style={{ borderRadius: 36, overflow: "hidden", background: "#0B0E1C", border: "2px solid rgba(255,255,255,0.12)", boxShadow: "0 30px 80px rgba(0,0,0,0.6)", ...style }}>
      <div style={{ background: "#0B0E1C", padding: "10px 0 6px", display: "flex", justifyContent: "center" }}>
        <div style={{ width: 80, height: 22, background: "#000", borderRadius: 12 }} />
      </div>
      <div style={{ fontSize: 10, fontWeight: 700, color: "rgba(238,241,255,0.7)", display: "flex", justifyContent: "space-between", padding: "0 14px 4px" }}>
        <span>9:41</span><span>▪▪▪</span>
      </div>
      {children}
    </div>
  );
}

// ── 7 Screenshots ─────────────────────────────────────────────────────────────

// 1 — Document Library Hero
function SS1() {
  return (
    <div style={{ width: "100%", height: "100%", background: "linear-gradient(160deg, #060A1E 0%, #0B1438 45%, #182480 100%)", display: "flex", flexDirection: "column", alignItems: "center", padding: "56px 32px 44px", position: "relative", overflow: "hidden" }}>
      <div style={{ position: "absolute", top: -80, right: -80, width: 320, height: 320, borderRadius: "50%", background: `${AMBER}08`, border: `1px solid ${AMBER}15` }} />
      <div style={{ position: "absolute", bottom: 120, left: -60, width: 200, height: 200, borderRadius: "50%", background: `${NAVY}60` }} />

      <div style={{ fontSize: 40, fontWeight: 800, color: "#fff", letterSpacing: "-0.02em", marginBottom: 8 }}>
        Quick<span style={{ color: AMBER }}>PDF</span>
      </div>
      <div style={{ fontSize: 12, color: "rgba(255,255,255,0.4)", marginBottom: 40, letterSpacing: "0.1em", textTransform: "uppercase" }}>Offline PDF Workstation</div>

      <div style={{ fontSize: 42, fontWeight: 800, color: "#fff", textAlign: "center", lineHeight: 1.1, marginBottom: 14 }}>
        Your Docs.<br />Your Device.
      </div>
      <div style={{ fontSize: 17, color: "rgba(255,255,255,0.6)", textAlign: "center", lineHeight: 1.6, marginBottom: 44 }}>
        Private by design.<br />Powerful by nature.
      </div>

      <div style={{ width: "100%", display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, flex: 1 }}>
        <DocCard name="Lease_Agreement.pdf" type="pdf" size="2.4 MB" date="2h ago" fav />
        <DocCard name="Thesis_Chapter_3.pdf" type="pdf" size="8.1 MB" date="Yesterday" />
        <DocCard name="Scan_Receipt_12.jpg" type="img" size="1.2 MB" date="3 days ago" />
        <DocCard name="Invoice_Q4_2024.pdf" type="pdf" size="0.8 MB" date="1 week ago" fav />
      </div>

      <div style={{ display: "flex", gap: 10, marginTop: 32, flexWrap: "wrap", justifyContent: "center" }}>
        <Badge amber>100% Offline</Badge>
        <Badge>No Account</Badge>
        <Badge>Privacy First</Badge>
      </div>
    </div>
  );
}

// 2 — 13 Tools Powerhouse
function SS2() {
  const tools = [
    { label: "Merge", color: "#FF6B35" },
    { label: "Split", color: "#FF9800" },
    { label: "Compress", color: "#E53935" },
    { label: "OCR", color: "#3F51B5" },
    { label: "Convert", color: "#00BCD4" },
    { label: "Annotate", color: "#FF9800" },
    { label: "Sign", color: "#4CAF50" },
    { label: "Protect", color: "#607D8B" },
    { label: "Watermark", color: "#009688" },
    { label: "Pages", color: "#795548" },
    { label: "Metadata", color: "#8BC34A" },
    { label: "Scan", color: "#2196F3" },
    { label: "Batch", color: "#FFB300" },
  ];
  return (
    <div style={{ width: "100%", height: "100%", background: "linear-gradient(155deg, #08051E 0%, #150838 45%, #260C5C 100%)", display: "flex", flexDirection: "column", alignItems: "center", padding: "56px 32px 44px", position: "relative", overflow: "hidden" }}>
      <div style={{ position: "absolute", top: "30%", left: "50%", transform: "translateX(-50%)", width: 500, height: 300, background: "radial-gradient(ellipse, rgba(100,60,220,0.25) 0%, transparent 70%)", pointerEvents: "none" }} />

      <div style={{ fontSize: 40, fontWeight: 800, color: "#fff", letterSpacing: "-0.02em", marginBottom: 8 }}>
        Quick<span style={{ color: AMBER }}>PDF</span>
      </div>

      <div style={{ fontSize: 46, fontWeight: 800, color: "#fff", textAlign: "center", lineHeight: 1.1, marginBottom: 12, marginTop: 28 }}>
        13 Pro<br />PDF Tools
      </div>
      <div style={{ fontSize: 17, color: "rgba(255,255,255,0.6)", textAlign: "center", marginBottom: 44 }}>
        Everything you need, nothing you don't
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 18, width: "100%", flex: 1, alignContent: "start" }}>
        {tools.map(t => (
          <div key={t.label} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 7 }}>
            <div style={{ width: 56, height: 56, borderRadius: 16, background: `${t.color}20`, border: `1px solid ${t.color}45`, display: "flex", alignItems: "center", justifyContent: "center", boxShadow: `0 4px 16px ${t.color}25` }}>
              <span style={{ fontSize: 20 }}>
                {t.label === "Merge" ? "⤢" : t.label === "Split" ? "✂" : t.label === "Compress" ? "⊡" : t.label === "OCR" ? "T" : t.label === "Convert" ? "⇌" : t.label === "Annotate" ? "✏" : t.label === "Sign" ? "✍" : t.label === "Protect" ? "🔒" : t.label === "Watermark" ? "◈" : t.label === "Pages" ? "⊞" : t.label === "Metadata" ? "ℹ" : t.label === "Scan" ? "⊙" : "⚡"}
              </span>
            </div>
            <span style={{ fontSize: 10, fontWeight: 700, color: "rgba(255,255,255,0.65)", textAlign: "center" }}>{t.label}</span>
          </div>
        ))}
      </div>

      <div style={{ width: "100%", background: "rgba(255,255,255,0.06)", borderRadius: 16, padding: "18px 20px", border: "1px solid rgba(255,255,255,0.1)", marginTop: 32 }}>
        <div style={{ fontSize: 15, fontWeight: 700, color: AMBER, marginBottom: 6 }}>All tools work offline</div>
        <div style={{ fontSize: 13, color: "rgba(255,255,255,0.55)", lineHeight: 1.5 }}>No internet required. No files uploaded. Your PDFs never leave your device.</div>
      </div>
    </div>
  );
}

// 3 — PDF Viewer
function SS3() {
  return (
    <div style={{ width: "100%", height: "100%", background: "linear-gradient(170deg, #050505 0%, #0D0D14 60%, #101424 100%)", display: "flex", flexDirection: "column", alignItems: "center", padding: "56px 28px 44px", position: "relative", overflow: "hidden" }}>
      <div style={{ position: "absolute", top: "20%", right: -40, width: 200, height: 200, borderRadius: "50%", background: `${AMBER}06`, border: `1px solid ${AMBER}12` }} />

      <div style={{ fontSize: 40, fontWeight: 800, color: "#fff", letterSpacing: "-0.02em", marginBottom: 8 }}>
        Quick<span style={{ color: AMBER }}>PDF</span>
      </div>

      <div style={{ fontSize: 44, fontWeight: 800, color: "#fff", textAlign: "center", lineHeight: 1.1, marginBottom: 12, marginTop: 28 }}>
        Crystal Clear<br />Reading
      </div>
      <div style={{ fontSize: 17, color: "rgba(255,255,255,0.5)", textAlign: "center", marginBottom: 36 }}>
        Full-featured viewer with night mode
      </div>

      {/* Stacked pages mockup */}
      <div style={{ flex: 1, width: "100%", position: "relative", display: "flex", alignItems: "center", justifyContent: "center" }}>
        {/* Back page */}
        <div style={{ position: "absolute", top: 20, width: "80%", aspectRatio: "8.5/11", background: "#111", borderRadius: 8, border: "1px solid rgba(255,255,255,0.06)", transform: "rotate(-3deg) translateY(8px)" }} />
        {/* Middle page */}
        <div style={{ position: "absolute", width: "85%", aspectRatio: "8.5/11", background: "#161616", borderRadius: 8, border: "1px solid rgba(255,255,255,0.08)", transform: "rotate(1.5deg)" }} />
        {/* Front page */}
        <div style={{ position: "relative", width: "88%", aspectRatio: "8.5/11", background: "#1A1A1A", borderRadius: 8, border: `2px solid ${AMBER}40`, padding: "22px 18px", display: "flex", flexDirection: "column", gap: 7, boxShadow: `0 0 40px ${AMBER}15, 0 20px 60px rgba(0,0,0,0.8)` }}>
          <div style={{ height: 4, background: "rgba(255,255,255,0.6)", borderRadius: 2, width: "52%", marginBottom: 10 }} />
          {[90, 75, 85, 60, 80, 70, 88, 65, 78, 55, 82, 68].map((w, i) => (
            <div key={i} style={{ height: 2.5, background: "rgba(255,255,255,0.12)", borderRadius: 1.5, width: `${w}%` }} />
          ))}
          <div style={{ height: 14 }} />
          {[72, 88, 60, 80].map((w, i) => (
            <div key={i} style={{ height: 2.5, background: "rgba(255,255,255,0.08)", borderRadius: 1.5, width: `${w}%` }} />
          ))}
          <div style={{ position: "absolute", bottom: 12, right: 14, fontSize: 11, color: "rgba(255,255,255,0.2)" }}>— 1 —</div>
          {/* Page indicator */}
          <div style={{ position: "absolute", bottom: -14, left: "50%", transform: "translateX(-50%)", background: AMBER, borderRadius: 12, padding: "3px 14px", fontSize: 11, fontWeight: 800, color: "#000", whiteSpace: "nowrap" }}>Page 1 of 12</div>
        </div>
      </div>

      <div style={{ display: "flex", gap: 10, marginTop: 48, justifyContent: "center" }}>
        <Badge>Night Mode</Badge>
        <Badge amber>Go to Page</Badge>
        <Badge>Share</Badge>
      </div>
    </div>
  );
}

// 4 — Merge PDFs
function SS4() {
  const files = [
    { name: "Contract_NDA.pdf", pages: 8, size: "1.5 MB" },
    { name: "Appendix_A.pdf",   pages: 4, size: "0.6 MB" },
    { name: "Appendix_B.pdf",   pages: 6, size: "0.9 MB" },
  ];
  return (
    <div style={{ width: "100%", height: "100%", background: "linear-gradient(160deg, #0A0805 0%, #1A1005 40%, #2A1800 100%)", display: "flex", flexDirection: "column", alignItems: "center", padding: "56px 28px 44px", position: "relative", overflow: "hidden" }}>
      <div style={{ position: "absolute", top: "25%", right: -60, width: 260, height: 260, borderRadius: "50%", background: "rgba(255,107,53,0.1)" }} />
      <div style={{ position: "absolute", bottom: "15%", left: -40, width: 180, height: 180, borderRadius: "50%", background: "rgba(255,107,53,0.06)" }} />

      <div style={{ fontSize: 40, fontWeight: 800, color: "#fff", letterSpacing: "-0.02em", marginBottom: 8 }}>
        Quick<span style={{ color: AMBER }}>PDF</span>
      </div>

      <div style={{ fontSize: 46, fontWeight: 800, color: "#fff", textAlign: "center", lineHeight: 1.1, marginBottom: 12, marginTop: 28 }}>
        Merge<br />in Seconds
      </div>
      <div style={{ fontSize: 17, color: "rgba(255,255,255,0.55)", textAlign: "center", marginBottom: 40 }}>
        Combine any number of PDFs in the perfect order
      </div>

      {/* File list */}
      <div style={{ width: "100%", display: "flex", flexDirection: "column", gap: 10, flex: 1 }}>
        {files.map((f, i) => (
          <div key={i} style={{ background: "rgba(255,107,53,0.1)", borderRadius: 14, padding: "14px 16px", border: "1px solid rgba(255,107,53,0.25)", display: "flex", alignItems: "center", gap: 14 }}>
            <div style={{ width: 44, height: 58, background: "rgba(255,255,255,0.06)", borderRadius: 6, border: "1px solid rgba(255,255,255,0.1)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
              <div style={{ background: "#E53935", borderRadius: 3, padding: "2px 5px", fontSize: 9, fontWeight: 800, color: "#fff" }}>PDF</div>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: "#EEF1FF" }}>{f.name}</div>
              <div style={{ fontSize: 11, color: "rgba(255,255,255,0.4)", marginTop: 3 }}>{f.pages} pages · {f.size}</div>
            </div>
            <div style={{ width: 28, height: 28, borderRadius: "50%", background: "rgba(255,255,255,0.08)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 14, color: "rgba(255,255,255,0.4)" }}>⋮</div>
          </div>
        ))}

        <div style={{ background: "rgba(255,255,255,0.04)", borderRadius: 14, padding: "13px 16px", border: "2px dashed rgba(255,255,255,0.12)", display: "flex", alignItems: "center", justifyContent: "center", gap: 10 }}>
          <span style={{ fontSize: 22, color: "rgba(255,255,255,0.2)" }}>+</span>
          <span style={{ fontSize: 13, fontWeight: 600, color: "rgba(255,255,255,0.35)" }}>Add more files…</span>
        </div>
      </div>

      {/* CTA */}
      <div style={{ width: "100%", background: "#FF6B35", borderRadius: 16, padding: "18px 0", marginTop: 28, textAlign: "center" }}>
        <div style={{ fontSize: 17, fontWeight: 800, color: "#fff" }}>Merge 3 PDFs →</div>
        <div style={{ fontSize: 12, color: "rgba(255,255,255,0.7)", marginTop: 4 }}>Total: 18 pages · 3.0 MB</div>
      </div>
    </div>
  );
}

// 5 — Scan to PDF
function SS5() {
  return (
    <div style={{ width: "100%", height: "100%", background: "linear-gradient(160deg, #001220 0%, #001E35 50%, #002A4A 100%)", display: "flex", flexDirection: "column", alignItems: "center", padding: "56px 28px 44px", position: "relative", overflow: "hidden" }}>
      <div style={{ position: "absolute", top: "15%", left: "50%", transform: "translateX(-50%)", width: 400, height: 300, background: "radial-gradient(ellipse, rgba(33,150,243,0.15) 0%, transparent 70%)" }} />

      <div style={{ fontSize: 40, fontWeight: 800, color: "#fff", letterSpacing: "-0.02em", marginBottom: 8 }}>
        Quick<span style={{ color: AMBER }}>PDF</span>
      </div>

      <div style={{ fontSize: 44, fontWeight: 800, color: "#fff", textAlign: "center", lineHeight: 1.1, marginBottom: 12, marginTop: 28 }}>
        Scan to PDF<br />Instantly
      </div>
      <div style={{ fontSize: 17, color: "rgba(255,255,255,0.55)", textAlign: "center", marginBottom: 40 }}>
        Point. Capture. Done. Smart edge detection included.
      </div>

      {/* Camera viewfinder mockup */}
      <div style={{ flex: 1, width: "100%", position: "relative", display: "flex", alignItems: "center", justifyContent: "center" }}>
        <div style={{ width: "90%", aspectRatio: "4/3", background: "rgba(0,0,0,0.5)", borderRadius: 16, position: "relative", overflow: "hidden", border: "2px solid rgba(33,150,243,0.4)", boxShadow: "0 0 40px rgba(33,150,243,0.2)" }}>
          {/* Simulated document in viewfinder */}
          <div style={{ position: "absolute", top: "12%", left: "8%", right: "8%", bottom: "12%", background: "rgba(245,245,230,0.92)", borderRadius: 4 }}>
            {[70, 55, 80, 48, 65, 72, 50, 78].map((w, i) => (
              <div key={i} style={{ height: 3, background: "rgba(0,0,0,0.15)", borderRadius: 2, width: `${w}%`, marginTop: i === 0 ? 16 : 8, marginLeft: 12 }} />
            ))}
          </div>
          {/* Corner markers */}
          {[["top-0 left-0", "border-t-4 border-l-4"], ["top-0 right-0", "border-t-4 border-r-4"], ["bottom-0 left-0", "border-b-4 border-l-4"], ["bottom-0 right-0", "border-b-4 border-r-4"]].map((_, i) => (
            <div key={i} style={{ position: "absolute", width: 24, height: 24, ...[{ top: 8, left: 8 }, { top: 8, right: 8 }, { bottom: 8, left: 8 }, { bottom: 8, right: 8 }][i], borderColor: "#2196F3", borderStyle: "solid", borderWidth: i === 0 ? "3px 0 0 3px" : i === 1 ? "3px 3px 0 0" : i === 2 ? "0 0 3px 3px" : "0 3px 3px 0" }} />
          ))}
          {/* Scan line */}
          <div style={{ position: "absolute", top: "45%", left: 0, right: 0, height: 2, background: "linear-gradient(90deg, transparent, #2196F3, transparent)", opacity: 0.8 }} />
          {/* Capture button hint */}
          <div style={{ position: "absolute", bottom: 14, left: "50%", transform: "translateX(-50%)", width: 52, height: 52, borderRadius: "50%", border: "3px solid rgba(255,255,255,0.7)", display: "flex", alignItems: "center", justifyContent: "center" }}>
            <div style={{ width: 38, height: 38, borderRadius: "50%", background: "rgba(255,255,255,0.9)" }} />
          </div>
        </div>
      </div>

      {/* Page strip */}
      <div style={{ display: "flex", gap: 10, marginTop: 24, width: "100%" }}>
        {[1, 2, 3].map(n => (
          <div key={n} style={{ flex: 1, aspectRatio: "3/4", background: "rgba(33,150,243,0.12)", borderRadius: 8, border: n === 3 ? `2px solid #2196F3` : "1px solid rgba(33,150,243,0.3)", display: "flex", alignItems: "center", justifyContent: "center" }}>
            <span style={{ fontSize: 11, fontWeight: 700, color: n === 3 ? "#2196F3" : "rgba(255,255,255,0.3)" }}>{n}</span>
          </div>
        ))}
        <div style={{ flex: 1, aspectRatio: "3/4", background: "rgba(255,255,255,0.04)", borderRadius: 8, border: "2px dashed rgba(255,255,255,0.15)", display: "flex", alignItems: "center", justifyContent: "center" }}>
          <span style={{ fontSize: 18, color: "rgba(255,255,255,0.2)" }}>+</span>
        </div>
      </div>

      <div style={{ display: "flex", gap: 10, marginTop: 24, justifyContent: "center" }}>
        <Badge>Auto Edge Detect</Badge>
        <Badge amber>Multi-page</Badge>
      </div>
    </div>
  );
}

// 6 — Privacy First
function SS6() {
  const features = [
    { icon: "🔒", title: "Zero Cloud Upload",     desc: "Files never leave your phone"        },
    { icon: "👤", title: "No Account Needed",     desc: "Start working instantly"              },
    { icon: "📵", title: "Works Offline",          desc: "Full power, zero connectivity"        },
    { icon: "🛡️", title: "No Tracking",            desc: "No analytics on your documents"      },
  ];
  return (
    <div style={{ width: "100%", height: "100%", background: "linear-gradient(160deg, #010F07 0%, #021A0C 50%, #04301A 100%)", display: "flex", flexDirection: "column", alignItems: "center", padding: "56px 28px 44px", position: "relative", overflow: "hidden" }}>
      <div style={{ position: "absolute", top: "20%", left: "50%", transform: "translateX(-50%)", width: 420, height: 280, background: "radial-gradient(ellipse, rgba(76,175,80,0.12) 0%, transparent 70%)" }} />

      <div style={{ fontSize: 40, fontWeight: 800, color: "#fff", letterSpacing: "-0.02em", marginBottom: 8 }}>
        Quick<span style={{ color: AMBER }}>PDF</span>
      </div>

      {/* Shield hero */}
      <div style={{ marginTop: 32, marginBottom: 24, width: 100, height: 100, borderRadius: "50%", background: "rgba(76,175,80,0.15)", border: "2px solid rgba(76,175,80,0.35)", display: "flex", alignItems: "center", justifyContent: "center", boxShadow: "0 0 60px rgba(76,175,80,0.2)" }}>
        <Shield size={48} color="#4CAF50" />
      </div>

      <div style={{ fontSize: 44, fontWeight: 800, color: "#fff", textAlign: "center", lineHeight: 1.1, marginBottom: 12 }}>
        Your Privacy.<br />Protected.
      </div>
      <div style={{ fontSize: 17, color: "rgba(255,255,255,0.55)", textAlign: "center", marginBottom: 40 }}>
        No data collection. No cloud sync. No compromise.
      </div>

      {/* Feature list */}
      <div style={{ width: "100%", display: "flex", flexDirection: "column", gap: 12, flex: 1 }}>
        {features.map((f, i) => (
          <div key={i} style={{ background: "rgba(76,175,80,0.08)", borderRadius: 14, padding: "16px 18px", border: "1px solid rgba(76,175,80,0.2)", display: "flex", alignItems: "center", gap: 16 }}>
            <div style={{ width: 44, height: 44, borderRadius: 12, background: "rgba(76,175,80,0.15)", border: "1px solid rgba(76,175,80,0.3)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 22, flexShrink: 0 }}>
              {f.icon}
            </div>
            <div>
              <div style={{ fontSize: 14, fontWeight: 700, color: "#EEF1FF" }}>{f.title}</div>
              <div style={{ fontSize: 12, color: "rgba(255,255,255,0.45)", marginTop: 3 }}>{f.desc}</div>
            </div>
            <div style={{ marginLeft: "auto", width: 22, height: 22, borderRadius: "50%", background: "#4CAF50", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
              <span style={{ fontSize: 12, color: "#fff", fontWeight: 800 }}>✓</span>
            </div>
          </div>
        ))}
      </div>

      <div style={{ marginTop: 28, background: "rgba(76,175,80,0.12)", borderRadius: 16, padding: "14px 24px", border: "1px solid rgba(76,175,80,0.25)", textAlign: "center" }}>
        <div style={{ fontSize: 15, fontWeight: 800, color: "#4CAF50" }}>Trusted by 500,000+ users</div>
        <div style={{ fontSize: 12, color: "rgba(255,255,255,0.45)", marginTop: 4 }}>Students · Freelancers · Professionals</div>
      </div>
    </div>
  );
}

// 7 — Dark & Light Modes
function SS7() {
  const MiniHome = ({ dark }: { dark: boolean }) => {
    const bg      = dark ? "#0B0E1C" : "#F2F4FF";
    const surf    = dark ? "#141828" : "#FFFFFF";
    const surf2   = dark ? "#1B2036" : "#E6EAF8";
    const text    = dark ? "#EEF1FF" : "#0D1130";
    const muted   = dark ? "#8891AA" : "#6271A0";
    const border  = dark ? "rgba(255,255,255,0.07)" : "rgba(0,0,0,0.07)";
    return (
      <div style={{ background: bg, flex: 1, padding: "10px 10px 0", display: "flex", flexDirection: "column", gap: 8 }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 4 }}>
          <div style={{ fontSize: 14, fontWeight: 800, color: text }}>Quick<span style={{ color: AMBER }}>PDF</span></div>
          <div style={{ width: 24, height: 24, background: surf2, borderRadius: 6, border: `1px solid ${border}` }} />
        </div>
        <div style={{ display: "flex", gap: 4, marginBottom: 4 }}>
          <div style={{ background: NAVY, borderRadius: 7, padding: "5px 10px", fontSize: 10, fontWeight: 700, color: "#fff" }}>Recent</div>
          <div style={{ padding: "5px 10px", fontSize: 10, fontWeight: 700, color: muted }}>Tools</div>
        </div>
        <div style={{ background: surf2, borderRadius: 8, padding: "7px 10px", border: `1px solid ${border}`, display: "flex", alignItems: "center", gap: 6, marginBottom: 4 }}>
          <div style={{ width: 10, height: 10, background: muted, borderRadius: "50%", opacity: 0.5 }} />
          <div style={{ fontSize: 10, color: muted }}>Search…</div>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 6 }}>
          {[["Lease_Agreement.pdf", "pdf"], ["Thesis_Ch3.pdf", "pdf"], ["Receipt.jpg", "img"], ["Invoice.pdf", "pdf"]].map(([n, t], i) => (
            <div key={i} style={{ background: surf, borderRadius: 8, padding: 7, border: `1px solid ${border}` }}>
              <div style={{ aspectRatio: "3/4", background: surf2, borderRadius: 5, marginBottom: 5, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <div style={{ background: t === "pdf" ? "#E53935" : "#4CAF50", borderRadius: 2, padding: "1px 4px", fontSize: 7, fontWeight: 800, color: "#fff" }}>{t.toUpperCase()}</div>
              </div>
              <div style={{ fontSize: 8, fontWeight: 600, color: text, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{n}</div>
            </div>
          ))}
        </div>
      </div>
    );
  };

  return (
    <div style={{ width: "100%", height: "100%", background: "linear-gradient(160deg, #060A1E 0%, #0E1430 100%)", display: "flex", flexDirection: "column", alignItems: "center", padding: "56px 28px 44px", position: "relative", overflow: "hidden" }}>
      <div style={{ position: "absolute", top: "30%", left: "50%", transform: "translateX(-50%)", width: 480, height: 240, background: "radial-gradient(ellipse, rgba(255,179,0,0.08) 0%, transparent 70%)" }} />

      <div style={{ fontSize: 40, fontWeight: 800, color: "#fff", letterSpacing: "-0.02em", marginBottom: 8 }}>
        Quick<span style={{ color: AMBER }}>PDF</span>
      </div>

      <div style={{ fontSize: 44, fontWeight: 800, color: "#fff", textAlign: "center", lineHeight: 1.1, marginBottom: 12, marginTop: 28 }}>
        Dark Mode.<br />Light Mode.
      </div>
      <div style={{ fontSize: 17, color: "rgba(255,255,255,0.55)", textAlign: "center", marginBottom: 40 }}>
        Your eyes will thank you. Switch anytime.
      </div>

      {/* Two phone frames */}
      <div style={{ flex: 1, width: "100%", display: "flex", gap: 16, alignItems: "center" }}>
        {/* Dark phone */}
        <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 10 }}>
          <div style={{ width: "100%", borderRadius: 28, overflow: "hidden", border: "2px solid rgba(255,255,255,0.1)", boxShadow: "0 20px 60px rgba(0,0,0,0.7)", background: "#0B0E1C" }}>
            <div style={{ background: "#0B0E1C", padding: "8px 0 4px", display: "flex", justifyContent: "center" }}>
              <div style={{ width: 60, height: 16, background: "#000", borderRadius: 8 }} />
            </div>
            <div style={{ display: "flex", flexDirection: "column", height: 320 }}>
              <MiniHome dark />
            </div>
          </div>
          <div style={{ background: "rgba(255,255,255,0.08)", borderRadius: 20, padding: "5px 14px", fontSize: 12, fontWeight: 700, color: "rgba(255,255,255,0.7)" }}>🌙 Dark</div>
        </div>

        {/* Light phone */}
        <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 10 }}>
          <div style={{ width: "100%", borderRadius: 28, overflow: "hidden", border: "2px solid rgba(255,255,255,0.2)", boxShadow: "0 20px 60px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,255,255,0.1)", background: "#F2F4FF" }}>
            <div style={{ background: "#F2F4FF", padding: "8px 0 4px", display: "flex", justifyContent: "center" }}>
              <div style={{ width: 60, height: 16, background: "#000", borderRadius: 8 }} />
            </div>
            <div style={{ display: "flex", flexDirection: "column", height: 320 }}>
              <MiniHome dark={false} />
            </div>
          </div>
          <div style={{ background: "rgba(255,255,255,0.08)", borderRadius: 20, padding: "5px 14px", fontSize: 12, fontWeight: 700, color: "rgba(255,255,255,0.7)" }}>☀️ Light</div>
        </div>
      </div>

      <div style={{ display: "flex", gap: 10, marginTop: 28, justifyContent: "center" }}>
        <Badge>System Default</Badge>
        <Badge amber>Switch Anytime</Badge>
      </div>
    </div>
  );
}

// ── Gallery ───────────────────────────────────────────────────────────────────

const SHOTS: { title: string; sub: string; Comp: React.FC }[] = [
  { title: "1 — Document Library",    sub: "Home · Recent tab",          Comp: SS1 },
  { title: "2 — 13 Pro PDF Tools",    sub: "Tools catalog",              Comp: SS2 },
  { title: "3 — Crystal Clear PDF",   sub: "Built-in PDF viewer",        Comp: SS3 },
  { title: "4 — Merge in Seconds",    sub: "Merge tool workflow",         Comp: SS4 },
  { title: "5 — Scan to PDF",         sub: "Camera capture flow",        Comp: SS5 },
  { title: "6 — Privacy First",       sub: "Privacy & security",         Comp: SS6 },
  { title: "7 — Dark & Light Modes",  sub: "Theme showcase",             Comp: SS7 },
];

// 9:16 at 405 × 720 display size
const W = 405;
const H = 720;

export default function Screenshots({ onClose }: { onClose: () => void }) {
  return (
    <div style={{ position: "fixed", inset: 0, background: "#050810", zIndex: 200, overflow: "auto", fontFamily: "'Plus Jakarta Sans', system-ui, sans-serif" }}>
      {/* Header */}
      <div style={{ position: "sticky", top: 0, background: "#050810", borderBottom: "1px solid rgba(255,255,255,0.08)", padding: "16px 32px", display: "flex", alignItems: "center", justifyContent: "space-between", zIndex: 10 }}>
        <div>
          <div style={{ fontSize: 18, fontWeight: 800, color: "#EEF1FF" }}>Play Store Screenshots</div>
          <div style={{ fontSize: 12, color: "#8891AA", marginTop: 2 }}>7 screenshots · 9:16 · PNG/JPEG ready · Right-click each to save</div>
        </div>
        <button onClick={onClose} style={{ background: "rgba(255,255,255,0.08)", border: "1px solid rgba(255,255,255,0.12)", borderRadius: 10, padding: "8px 16px", cursor: "pointer", display: "flex", alignItems: "center", gap: 8, color: "#EEF1FF", fontSize: 13, fontWeight: 600 }}>
          <X size={16} color="#EEF1FF" />
          Close
        </button>
      </div>

      {/* Grid */}
      <div style={{ padding: "40px 32px 60px", display: "flex", flexWrap: "wrap", gap: 32, justifyContent: "center" }}>
        {SHOTS.map(({ title, sub, Comp }, i) => (
          <div key={i} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 14 }}>
            {/* Screenshot frame */}
            <div
              id={`export-shot-${i + 1}`}
              data-shot={String(i + 1)}
              style={{
                width: W,
                height: H,
                borderRadius: 24,
                overflow: "hidden",
                boxShadow: "0 24px 80px rgba(0,0,0,0.8), 0 0 0 1px rgba(255,255,255,0.08)",
                cursor: "pointer",
                flexShrink: 0,
              }}
              title="Right-click → Save image as… to export"
            >
              <Comp />
            </div>
            {/* Label */}
            <div style={{ textAlign: "center" }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: "#EEF1FF" }}>{title}</div>
              <div style={{ fontSize: 11, color: "#8891AA", marginTop: 3 }}>{sub} · {W}×{H} px</div>
            </div>
          </div>
        ))}
      </div>

      {/* Footer note */}
      <div style={{ textAlign: "center", padding: "0 32px 40px", fontSize: 12, color: "rgba(255,255,255,0.2)", lineHeight: 1.6 }}>
        To export: right-click a screenshot → "Save image as…" or use browser DevTools → Capture node screenshot for full resolution.
        <br />Play Store requires PNG or JPEG, 9:16, 320–3840px per side, max 8 MB.
      </div>
    </div>
  );
}
