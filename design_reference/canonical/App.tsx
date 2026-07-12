import { useState, useContext, createContext } from "react";
import Screenshots from "./Screenshots";
import {
  Home, Wrench, Settings, Search, Plus, Star, MoreVertical,
  FileText, Image, Camera, GitMerge, Scissors, Archive, Type,
  Lock, Layers, Edit3, PenTool, RefreshCw, Zap, Droplets, Info,
  ChevronRight, Grid3X3, List, ArrowLeft, Share2, Download,
  Shield, HardDrive, Sliders, Moon, Sun, AlignLeft, Battery, Wifi,
  Signal, X, Eye, Trash2, Check,
} from "lucide-react";

// ── Theme system ──────────────────────────────────────────────────────────────

type C = {
  APP_BG: string; SURFACE: string; SURFACE2: string; BORDER: string;
  TEXT: string; MUTED: string; AMBER: string; NAVY: string;
  pageBg: string; pageGlow: string; btnSide: string;
};

const DARK: C = {
  APP_BG:   "#0B0E1C",
  SURFACE:  "#141828",
  SURFACE2: "#1B2036",
  BORDER:   "rgba(255,255,255,0.07)",
  TEXT:     "#EEF1FF",
  MUTED:    "#8891AA",
  AMBER:    "#FFB300",
  NAVY:     "#1E2E8E",
  pageBg:   "linear-gradient(140deg, #050710 0%, #0C1422 55%, #050710 100%)",
  pageGlow: "rgba(30,46,142,0.35)",
  btnSide:  "#121520",
};

const LIGHT: C = {
  APP_BG:   "#F2F4FF",
  SURFACE:  "#FFFFFF",
  SURFACE2: "#E6EAF8",
  BORDER:   "rgba(0,0,0,0.07)",
  TEXT:     "#0D1130",
  MUTED:    "#6271A0",
  AMBER:    "#FFB300",
  NAVY:     "#1E2E8E",
  pageBg:   "linear-gradient(140deg, #D8DEEF 0%, #EEF1FF 55%, #D8DEEF 100%)",
  pageGlow: "rgba(30,46,142,0.1)",
  btnSide:  "#B8C0D8",
};

const ThemeCtx = createContext<{ c: C; isDark: boolean; toggle: () => void }>({
  c: DARK, isDark: true, toggle: () => {},
});
const useT = () => useContext(ThemeCtx);

// ── Data ──────────────────────────────────────────────────────────────────────

const documents = [
  { id: 1, name: "Lease_Agreement.pdf",  type: "pdf", size: "2.4 MB", pages: 12, date: "2h ago",      fav: true  },
  { id: 2, name: "Thesis_Chapter_3.pdf", type: "pdf", size: "8.1 MB", pages: 48, date: "Yesterday",   fav: false },
  { id: 3, name: "Scan_Receipt_12.jpg",  type: "img", size: "1.2 MB", pages: 1,  date: "3 days ago",  fav: false },
  { id: 4, name: "Invoice_Q4_2024.pdf",  type: "pdf", size: "0.8 MB", pages: 4,  date: "1 week ago",  fav: true  },
  { id: 5, name: "Contract_NDA.pdf",     type: "pdf", size: "1.5 MB", pages: 8,  date: "2 weeks ago", fav: false },
  { id: 6, name: "Photo_ID_Scan.jpg",    type: "img", size: "2.8 MB", pages: 1,  date: "3 weeks ago", fav: false },
];
type Doc = typeof documents[0];

const toolGroups = [
  { label: "Create", tools: [
    { name: "Scan Document",      icon: Camera,    color: "#2196F3", desc: "Capture pages with camera"     },
    { name: "Images to PDF",      icon: Image,     color: "#9C27B0", desc: "Combine images into a PDF"     },
  ]},
  { label: "PDF Tools", tools: [
    { name: "Merge PDFs",         icon: GitMerge,  color: "#FF6B35", desc: "Combine multiple PDF files"    },
    { name: "Split PDF",          icon: Scissors,  color: "#FF9800", desc: "Extract pages or ranges"       },
    { name: "Compress PDF",       icon: Archive,   color: "#E53935", desc: "Reduce file size"              },
  ]},
  { label: "Convert & Extract", tools: [
    { name: "Extract Text (OCR)", icon: Type,      color: "#3F51B5", desc: "Recognize text in scans"       },
    { name: "Format Converter",   icon: RefreshCw, color: "#00BCD4", desc: "PDF ↔ Images"                  },
  ]},
  { label: "Annotate & Sign", tools: [
    { name: "Annotate PDF",       icon: PenTool,   color: "#FF9800", desc: "Draw, highlight, add notes"    },
    { name: "Sign PDF",           icon: Edit3,     color: "#4CAF50", desc: "Add your signature"            },
  ]},
  { label: "Organise", tools: [
    { name: "Page Manager",       icon: Layers,    color: "#795548", desc: "Reorder, rotate, delete pages" },
    { name: "Watermark",          icon: Droplets,  color: "#009688", desc: "Text or image overlay"         },
  ]},
  { label: "Security", tools: [
    { name: "Password Protect",   icon: Lock,      color: "#607D8B", desc: "Encrypt your PDF"              },
    { name: "Edit Metadata",      icon: Info,      color: "#8BC34A", desc: "Title, author, keywords"       },
  ]},
  { label: "Batch", tools: [
    { name: "Batch Processing",   icon: Zap,       color: "#FFB300", desc: "Process many files at once"    },
  ]},
];
const homeToolGroups = toolGroups.slice(0, 4);
type Tool = { name: string; icon: React.ComponentType<{ size: number; color: string }>; color: string; desc: string };

// ── Atoms ─────────────────────────────────────────────────────────────────────

function DocThumbnail({ doc, size = "lg" }: { doc: Doc; size?: "sm" | "lg" }) {
  const { c, isDark } = useT();
  const isPdf = doc.type === "pdf";
  const isLg  = size === "lg";
  const lineClr = isDark ? "rgba(255,255,255,0.1)" : "rgba(0,0,0,0.09)";
  return (
    <div style={{ width: isLg ? "100%" : 40, height: isLg ? undefined : 52, aspectRatio: isLg ? "3/4" : undefined, background: c.SURFACE2, borderRadius: isLg ? 8 : 6, overflow: "hidden", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", position: "relative", border: `1px solid ${c.BORDER}`, flexShrink: 0 }}>
      <div style={{ position: "absolute", inset: 0, padding: isLg ? "10px 8px" : "5px 4px", display: "flex", flexDirection: "column", gap: isLg ? 3 : 2 }}>
        {[75, 60, 82, 55, 72, 48].map((w, i) => (
          <div key={i} style={{ height: isLg ? 2 : 1.5, borderRadius: 1, background: lineClr, width: `${w}%` }} />
        ))}
      </div>
      <div style={{ position: "absolute", top: 0, right: 0, width: isLg ? 14 : 7, height: isLg ? 14 : 7, background: c.APP_BG, borderBottomLeftRadius: 4 }} />
      <div style={{ position: "relative", zIndex: 1, background: isPdf ? "#E53935" : "#4CAF50", borderRadius: 3, padding: isLg ? "2px 7px" : "1px 4px", fontSize: isLg ? 10 : 7, fontWeight: 800, color: "#fff", letterSpacing: "0.06em", marginTop: isLg ? 6 : 3 }}>
        {isPdf ? "PDF" : "IMG"}
      </div>
    </div>
  );
}

function FavStar({ on, onToggle }: { on: boolean; onToggle: () => void }) {
  const { c, isDark } = useT();
  return (
    <button
      onClick={(e) => { e.stopPropagation(); onToggle(); }}
      style={{ background: isDark ? "rgba(0,0,0,0.45)" : "rgba(255,255,255,0.75)", borderRadius: "50%", padding: 5, border: "none", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}
    >
      <Star size={11} fill={on ? c.AMBER : "none"} color={on ? c.AMBER : c.MUTED} />
    </button>
  );
}

function DocCard({ doc, view, onTap }: { doc: Doc; view: "grid" | "list"; onTap: () => void }) {
  const { c } = useT();
  const [fav, setFav] = useState(doc.fav);

  if (view === "grid") {
    return (
      <div onClick={onTap} role="button" tabIndex={0} onKeyDown={e => e.key === "Enter" && onTap()} style={{ background: c.SURFACE, border: `1px solid ${c.BORDER}`, borderRadius: 12, padding: 10, textAlign: "left", display: "flex", flexDirection: "column", gap: 8, cursor: "pointer", width: "100%" }}>
        <div style={{ position: "relative", width: "100%", aspectRatio: "3/4" }}>
          <DocThumbnail doc={doc} size="lg" />
          <div style={{ position: "absolute", top: 6, right: 6 }}>
            <FavStar on={fav} onToggle={() => setFav(!fav)} />
          </div>
        </div>
        <div>
          <div style={{ fontSize: 11, fontWeight: 600, color: c.TEXT, lineHeight: 1.3, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{doc.name}</div>
          <div style={{ fontSize: 10, color: c.MUTED, marginTop: 2 }}>{doc.size} · {doc.date}</div>
        </div>
      </div>
    );
  }

  return (
    <div onClick={onTap} role="button" tabIndex={0} onKeyDown={e => e.key === "Enter" && onTap()} style={{ background: c.SURFACE, border: `1px solid ${c.BORDER}`, borderRadius: 10, padding: "10px 12px", display: "flex", alignItems: "center", gap: 12, cursor: "pointer", width: "100%" }}>
      <DocThumbnail doc={doc} size="sm" />
      <div style={{ flex: 1, minWidth: 0, textAlign: "left" }}>
        <div style={{ fontSize: 13, fontWeight: 600, color: c.TEXT, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{doc.name}</div>
        <div style={{ fontSize: 11, color: c.MUTED, marginTop: 2 }}>{doc.type.toUpperCase()} · {doc.size} · {doc.date}</div>
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 8, flexShrink: 0 }}>
        <FavStar on={fav} onToggle={() => setFav(!fav)} />
        <MoreVertical size={16} color={c.MUTED} />
      </div>
    </div>
  );
}

function ToolTile({ tool }: { tool: Tool }) {
  const { c } = useT();
  const Icon = tool.icon;
  return (
    <button style={{ background: c.SURFACE, border: `1px solid ${c.BORDER}`, borderRadius: 12, padding: "13px 16px", display: "flex", alignItems: "center", gap: 12, cursor: "pointer", width: "100%", textAlign: "left" }}>
      <div style={{ width: 40, height: 40, borderRadius: 10, background: `${tool.color}22`, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
        <Icon size={20} color={tool.color} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 13, fontWeight: 600, color: c.TEXT }}>{tool.name}</div>
        <div style={{ fontSize: 11, color: c.MUTED, marginTop: 1 }}>{tool.desc}</div>
      </div>
      <ChevronRight size={16} color={c.MUTED} />
    </button>
  );
}

function SectionLabel({ children }: { children: string }) {
  const { c } = useT();
  return <div style={{ fontSize: 11, fontWeight: 700, color: c.MUTED, letterSpacing: "0.08em", textTransform: "uppercase", padding: "0 16px", marginBottom: 6 }}>{children}</div>;
}

function SectionCard({ children }: { children: React.ReactNode }) {
  const { c } = useT();
  return <div style={{ background: c.SURFACE, margin: "0 16px 20px", borderRadius: 12, border: `1px solid ${c.BORDER}`, overflow: "hidden" }}>{children}</div>;
}

function Toggle({ on, onToggle }: { on: boolean; onToggle: () => void }) {
  const { c } = useT();
  return (
    <button onClick={onToggle} style={{ width: 44, height: 26, borderRadius: 13, background: on ? c.AMBER : c.SURFACE2, border: `1px solid ${on ? c.AMBER : c.BORDER}`, position: "relative", cursor: "pointer", flexShrink: 0, transition: "background 0.2s" }}>
      <div style={{ width: 20, height: 20, borderRadius: "50%", background: "#fff", position: "absolute", top: 2, left: on ? 20 : 2, transition: "left 0.2s" }} />
    </button>
  );
}

type SRProps = {
  icon: React.ComponentType<{ size: number; color: string }>;
  iconColor: string; label: string; value?: string;
  toggle?: boolean; onToggle?: () => void; chevron?: boolean; last?: boolean;
};
function SettingRow({ icon: Icon, iconColor, label, value, toggle, onToggle, chevron, last }: SRProps) {
  const { c } = useT();
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "12px 16px", borderBottom: last ? "none" : `1px solid ${c.BORDER}` }}>
      <div style={{ width: 32, height: 32, borderRadius: 8, background: `${iconColor}22`, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
        <Icon size={16} color={iconColor} />
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 13, fontWeight: 600, color: c.TEXT }}>{label}</div>
        {value && <div style={{ fontSize: 11, color: c.MUTED, marginTop: 1 }}>{value}</div>}
      </div>
      {toggle !== undefined && <Toggle on={toggle} onToggle={onToggle ?? (() => {})} />}
      {chevron && <ChevronRight size={16} color={c.MUTED} />}
    </div>
  );
}

// ── Screens ───────────────────────────────────────────────────────────────────

function HomeRecent({ onDocTap }: { onDocTap: (doc: Doc) => void }) {
  const { c } = useT();
  const [filter, setFilter] = useState("All");
  const [view, setView]     = useState<"grid" | "list">("grid");
  const [showFAB, setShow]  = useState(false);
  const filters  = ["All", "PDF", "Image"];
  const filtered = filter === "All" ? documents : documents.filter(d => filter === "PDF" ? d.type === "pdf" : d.type === "img");

  return (
    <div style={{ flex: 1, position: "relative", display: "flex", flexDirection: "column", overflow: "hidden" }}>
      <div style={{ flex: 1, overflow: "auto", padding: "12px 16px", scrollbarWidth: "none" }}>
        <div style={{ background: c.SURFACE2, borderRadius: 12, display: "flex", alignItems: "center", gap: 8, padding: "10px 14px", border: `1px solid ${c.BORDER}`, marginBottom: 12 }}>
          <Search size={15} color={c.MUTED} />
          <span style={{ fontSize: 13, color: c.MUTED }}>Search documents…</span>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 14 }}>
          {filters.map(f => (
            <button key={f} onClick={() => setFilter(f)} style={{ padding: "5px 12px", borderRadius: 20, fontSize: 12, fontWeight: 600, border: filter === f ? `1px solid ${c.AMBER}` : `1px solid ${c.BORDER}`, background: filter === f ? `${c.AMBER}18` : "transparent", color: filter === f ? c.AMBER : c.MUTED, cursor: "pointer" }}>
              {f}
            </button>
          ))}
          <div style={{ flex: 1 }} />
          <button onClick={() => setView(view === "grid" ? "list" : "grid")} style={{ background: "none", border: "none", cursor: "pointer", color: c.MUTED, display: "flex" }}>
            {view === "grid" ? <List size={18} /> : <Grid3X3 size={18} />}
          </button>
        </div>
        <div style={{ fontSize: 11, fontWeight: 700, color: c.MUTED, letterSpacing: "0.08em", textTransform: "uppercase", marginBottom: 10 }}>
          Recent · {filtered.length} files
        </div>
        {view === "grid" ? (
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, paddingBottom: 80 }}>
            {filtered.map(doc => <DocCard key={doc.id} doc={doc} view="grid" onTap={() => onDocTap(doc)} />)}
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: 8, paddingBottom: 80 }}>
            {filtered.map(doc => <DocCard key={doc.id} doc={doc} view="list" onTap={() => onDocTap(doc)} />)}
          </div>
        )}
      </div>

      {showFAB && (
        <div style={{ position: "absolute", bottom: 68, right: 16, background: c.SURFACE, border: `1px solid ${c.BORDER}`, borderRadius: 16, padding: "6px 0", minWidth: 210, boxShadow: "0 8px 40px rgba(0,0,0,0.25)", zIndex: 10 }}>
          {[{ icon: Camera, label: "Scan Document" }, { icon: FileText, label: "Import from Files" }, { icon: Image, label: "Images to PDF" }].map(({ icon: Icon, label }) => (
            <button key={label} style={{ display: "flex", alignItems: "center", gap: 12, padding: "11px 18px", width: "100%", background: "none", border: "none", cursor: "pointer" }}>
              <Icon size={18} color={c.AMBER} />
              <span style={{ fontSize: 13, fontWeight: 600, color: c.TEXT }}>{label}</span>
            </button>
          ))}
        </div>
      )}

      <div style={{ position: "absolute", bottom: 12, right: 16, zIndex: 11 }}>
        <button onClick={() => setShow(!showFAB)} style={{ width: 52, height: 52, borderRadius: "50%", background: c.AMBER, border: "none", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", boxShadow: `0 4px 24px ${c.AMBER}55` }}>
          {showFAB ? <X size={22} color="#000" /> : <Plus size={22} color="#000" />}
        </button>
      </div>
    </div>
  );
}

function HomeTools() {
  const { c } = useT();
  return (
    <div style={{ flex: 1, overflow: "auto", padding: "12px 16px", scrollbarWidth: "none" }}>
      {homeToolGroups.map(group => (
        <div key={group.label} style={{ marginBottom: 20 }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: c.MUTED, letterSpacing: "0.08em", textTransform: "uppercase", marginBottom: 8 }}>{group.label}</div>
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            {group.tools.map(tool => <ToolTile key={tool.name} tool={tool} />)}
          </div>
        </div>
      ))}
    </div>
  );
}

function HomeScreen({ homeTab, setHomeTab, onDocTap }: { homeTab: string; setHomeTab: (t: string) => void; onDocTap: (doc: Doc) => void }) {
  const { c } = useT();
  return (
    <div style={{ display: "flex", flexDirection: "column", flex: 1, overflow: "hidden" }}>
      <div style={{ padding: "8px 16px 0", display: "flex", alignItems: "center", justifyContent: "space-between", flexShrink: 0 }}>
        <div style={{ fontSize: 22, fontWeight: 800, color: c.TEXT, letterSpacing: "-0.02em" }}>
          Quick<span style={{ color: c.AMBER }}>PDF</span>
        </div>
        <button style={{ background: c.SURFACE2, border: `1px solid ${c.BORDER}`, borderRadius: 10, padding: 8, cursor: "pointer", display: "flex" }}>
          <Search size={18} color={c.MUTED} />
        </button>
      </div>
      <div style={{ display: "flex", padding: "10px 16px 0", gap: 4, flexShrink: 0 }}>
        {["Recent", "Tools"].map(tab => {
          const active = homeTab === tab.toLowerCase();
          return (
            <button key={tab} onClick={() => setHomeTab(tab.toLowerCase())} style={{ padding: "8px 20px", borderRadius: 10, fontSize: 13, fontWeight: 700, border: "none", cursor: "pointer", background: active ? c.NAVY : "transparent", color: active ? "#fff" : c.MUTED, transition: "all 0.15s" }}>
              {tab}
            </button>
          );
        })}
      </div>
      <div style={{ height: 1, background: c.BORDER, margin: "10px 0 0", flexShrink: 0 }} />
      <div style={{ flex: 1, overflow: "hidden", display: "flex", flexDirection: "column" }}>
        {homeTab === "recent" ? <HomeRecent onDocTap={onDocTap} /> : <HomeTools />}
      </div>
    </div>
  );
}

function ToolsScreen() {
  const { c } = useT();
  return (
    <div style={{ display: "flex", flexDirection: "column", flex: 1, overflow: "hidden" }}>
      <div style={{ padding: "8px 16px 0", flexShrink: 0 }}>
        <div style={{ fontSize: 22, fontWeight: 800, color: c.TEXT }}>Tools</div>
        <div style={{ fontSize: 13, color: c.MUTED, marginTop: 1 }}>All PDF utilities — 100% on-device</div>
      </div>
      <div style={{ height: 1, background: c.BORDER, margin: "10px 0 0", flexShrink: 0 }} />
      <div style={{ flex: 1, overflow: "auto", padding: "12px 16px", scrollbarWidth: "none" }}>
        {toolGroups.map(group => (
          <div key={group.label} style={{ marginBottom: 20 }}>
            <div style={{ fontSize: 11, fontWeight: 700, color: c.MUTED, letterSpacing: "0.08em", textTransform: "uppercase", marginBottom: 8 }}>{group.label}</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
              {group.tools.map(tool => <ToolTile key={tool.name} tool={tool} />)}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function SettingsScreen({ onToggleDark }: { onToggleDark: () => void }) {
  const { c, isDark } = useT();
  const [isPremium, setIsPremium] = useState(false);
  return (
    <div style={{ display: "flex", flexDirection: "column", flex: 1, overflow: "hidden" }}>
      <div style={{ padding: "8px 16px 0", flexShrink: 0 }}>
        <div style={{ fontSize: 22, fontWeight: 800, color: c.TEXT }}>Settings</div>
      </div>
      <div style={{ height: 1, background: c.BORDER, margin: "10px 0 0", flexShrink: 0 }} />
      <div style={{ flex: 1, overflow: "auto", padding: "16px 0", scrollbarWidth: "none" }}>

        {!isPremium ? (
          <div style={{ margin: "0 16px 20px", background: "linear-gradient(140deg, #1A2480 0%, #2C3DB8 100%)", borderRadius: 14, padding: 16, border: "1px solid rgba(46,61,184,0.5)" }}>
            <div style={{ fontSize: 14, fontWeight: 800, color: c.AMBER, marginBottom: 4 }}>QuickPDF Premium</div>
            <div style={{ fontSize: 12, color: "rgba(255,255,255,0.7)", marginBottom: 14, lineHeight: 1.5 }}>Remove ads and unlock every feature — all processing stays on your device.</div>
            <div style={{ display: "flex", gap: 8 }}>
              <button onClick={() => setIsPremium(true)} style={{ background: c.AMBER, border: "none", borderRadius: 8, padding: "9px 18px", fontSize: 13, fontWeight: 700, color: "#000", cursor: "pointer" }}>Remove Ads · $2.99</button>
              <button style={{ background: "rgba(255,255,255,0.12)", border: "none", borderRadius: 8, padding: "9px 14px", fontSize: 13, fontWeight: 600, color: "rgba(255,255,255,0.8)", cursor: "pointer" }}>Restore</button>
            </div>
          </div>
        ) : (
          <div style={{ margin: "0 16px 20px", background: `${c.AMBER}12`, borderRadius: 14, padding: "14px 16px", border: `1px solid ${c.AMBER}30`, display: "flex", alignItems: "center", gap: 12 }}>
            <div style={{ width: 30, height: 30, borderRadius: "50%", background: c.AMBER, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
              <Check size={16} color="#000" />
            </div>
            <div>
              <div style={{ fontSize: 13, fontWeight: 700, color: c.AMBER }}>Premium Active</div>
              <div style={{ fontSize: 11, color: c.MUTED, marginTop: 1 }}>Ads removed · All features unlocked</div>
            </div>
          </div>
        )}

        <SectionLabel>Appearance</SectionLabel>
        <SectionCard>
          <SettingRow icon={isDark ? Moon : Sun} iconColor="#9C27B0" label="Dark Mode" toggle={isDark} onToggle={onToggleDark} />
          <SettingRow icon={AlignLeft} iconColor="#2196F3" label="Display Font" value="Plus Jakarta Sans" chevron last />
        </SectionCard>

        <SectionLabel>Processing</SectionLabel>
        <SectionCard>
          <SettingRow icon={Sliders} iconColor="#FF9800" label="Image Quality" value="High (85%)" chevron />
          <SettingRow icon={Type} iconColor="#3F51B5" label="OCR Language" value="English" chevron last />
        </SectionCard>

        <SectionLabel>Storage</SectionLabel>
        <SectionCard>
          <SettingRow icon={HardDrive} iconColor="#4CAF50" label="Documents" value="24 files · 48.2 MB" chevron />
          <SettingRow icon={Trash2} iconColor="#E53935" label="Clear Cache" value="12.4 MB" chevron last />
        </SectionCard>

        <SectionLabel>Privacy & About</SectionLabel>
        <SectionCard>
          <SettingRow icon={Shield} iconColor="#607D8B" label="Privacy Policy" chevron />
          <SettingRow icon={Eye} iconColor="#009688" label="About QuickPDF" value="v3.4.1" chevron last />
        </SectionCard>
      </div>
    </div>
  );
}

function ViewerScreen({ doc, onBack }: { doc: Doc; onBack: () => void }) {
  const { c } = useT();
  const [page, setPage] = useState(1);
  const pages = doc.pages;
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%", background: "#0A0A0A" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "8px 16px", background: "#0E0E0E", borderBottom: "1px solid rgba(255,255,255,0.05)", flexShrink: 0 }}>
        <button onClick={onBack} style={{ background: "none", border: "none", cursor: "pointer", display: "flex" }}>
          <ArrowLeft size={20} color="#fff" />
        </button>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 13, fontWeight: 600, color: "#fff", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{doc.name}</div>
          <div style={{ fontSize: 11, color: "rgba(255,255,255,0.45)" }}>{pages} pages · {doc.size}</div>
        </div>
        <button style={{ background: "none", border: "none", cursor: "pointer", display: "flex" }}><Share2 size={18} color="rgba(255,255,255,0.6)" /></button>
        <button style={{ background: "none", border: "none", cursor: "pointer", display: "flex" }}><Download size={18} color="rgba(255,255,255,0.6)" /></button>
      </div>
      <div style={{ flex: 1, overflow: "auto", padding: "12px 20px", display: "flex", flexDirection: "column", gap: 10, scrollbarWidth: "none", background: "#111" }}>
        {[...Array(Math.min(pages, 6))].map((_, i) => (
          <div key={i} onClick={() => setPage(i + 1)} style={{ background: "#1A1A1A", borderRadius: 4, aspectRatio: "8.5/11", display: "flex", flexDirection: "column", padding: "20px 16px", gap: 6, border: page === i + 1 ? `2px solid ${c.AMBER}` : "2px solid transparent", cursor: "pointer" }}>
            <div style={{ height: 3, background: "rgba(255,255,255,0.55)", borderRadius: 2, width: "50%", marginBottom: 6 }} />
            {[88, 72, 84, 58, 78, 66, 90, 60].map((w, j) => (
              <div key={j} style={{ height: 2, background: "rgba(255,255,255,0.13)", borderRadius: 1, width: `${w}%` }} />
            ))}
            <div style={{ flex: 1 }} />
            <div style={{ fontSize: 9, color: "rgba(255,255,255,0.2)", textAlign: "center" }}>— {i + 1} —</div>
          </div>
        ))}
        {pages > 6 && <div style={{ textAlign: "center", fontSize: 12, color: "#8891AA", padding: 12 }}>{pages - 6} more pages…</div>}
      </div>
      <div style={{ display: "flex", justifyContent: "center", alignItems: "center", gap: 16, padding: "10px 16px", background: "#0E0E0E", borderTop: "1px solid rgba(255,255,255,0.05)", flexShrink: 0 }}>
        <button onClick={() => setPage(Math.max(1, page - 1))} style={{ background: "#1B2036", border: "1px solid rgba(255,255,255,0.07)", borderRadius: 8, padding: "6px 18px", color: "#EEF1FF", fontSize: 18, cursor: "pointer", lineHeight: 1 }}>‹</button>
        <span style={{ fontSize: 13, color: "#EEF1FF", fontWeight: 600, minWidth: 64, textAlign: "center" }}>{page} / {pages}</span>
        <button onClick={() => setPage(Math.min(pages, page + 1))} style={{ background: "#1B2036", border: "1px solid rgba(255,255,255,0.07)", borderRadius: 8, padding: "6px 18px", color: "#EEF1FF", fontSize: 18, cursor: "pointer", lineHeight: 1 }}>›</button>
      </div>
    </div>
  );
}

// ── Shell ─────────────────────────────────────────────────────────────────────

function StatusBar() {
  const { c } = useT();
  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 22px 2px", fontSize: 12, fontWeight: 700, color: c.TEXT, flexShrink: 0 }}>
      <span>9:41</span>
      <div style={{ display: "flex", alignItems: "center", gap: 5 }}>
        <Signal size={13} color={c.TEXT} />
        <Wifi size={13} color={c.TEXT} />
        <Battery size={13} color={c.TEXT} />
      </div>
    </div>
  );
}

function BottomNav({ active, onChange }: { active: string; onChange: (s: string) => void }) {
  const { c } = useT();
  const items = [
    { id: "home",     icon: Home,     label: "Home"     },
    { id: "tools",    icon: Wrench,   label: "Tools"    },
    { id: "settings", icon: Settings, label: "Settings" },
  ];
  return (
    <div style={{ display: "flex", background: c.SURFACE, borderTop: `1px solid ${c.BORDER}`, flexShrink: 0 }}>
      {items.map(({ id, icon: Icon, label }) => {
        const isActive = active === id;
        return (
          <button key={id} onClick={() => onChange(id)} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 3, padding: "9px 0 6px", background: "none", border: "none", cursor: "pointer" }}>
            <div style={{ width: 36, height: 28, borderRadius: 10, background: isActive ? `${c.AMBER}20` : "transparent", display: "flex", alignItems: "center", justifyContent: "center", transition: "background 0.15s" }}>
              <Icon size={20} color={isActive ? c.AMBER : c.MUTED} strokeWidth={isActive ? 2.5 : 1.5} />
            </div>
            <span style={{ fontSize: 10, fontWeight: isActive ? 700 : 500, color: isActive ? c.AMBER : c.MUTED }}>{label}</span>
          </button>
        );
      })}
    </div>
  );
}

function AdBanner() {
  const { c } = useT();
  return (
    <div style={{ background: c.SURFACE2, borderTop: `1px solid ${c.BORDER}`, height: 44, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
      <div style={{ width: 300, height: 28, background: c.SURFACE, border: `1px dashed ${c.BORDER}`, borderRadius: 4, display: "flex", alignItems: "center", justifyContent: "center", gap: 6 }}>
        <span style={{ fontSize: 9, color: c.MUTED, opacity: 0.6, letterSpacing: "0.05em", textTransform: "uppercase" }}>Ad</span>
        <div style={{ width: 1, height: 10, background: c.BORDER }} />
        <span style={{ fontSize: 9, color: c.MUTED, letterSpacing: "0.04em" }}>320×50 banner placeholder</span>
      </div>
    </div>
  );
}

// ── App ───────────────────────────────────────────────────────────────────────

export default function App() {
  const [showScreenshots, setShowScreenshots] = useState(false);
  const [isDark,      setIsDark]      = useState(true);
  const [screen,      setScreen]      = useState("home");
  const [homeTab,     setHomeTab]     = useState("recent");
  const [selectedDoc, setSelectedDoc] = useState<Doc | null>(null);

  const c      = isDark ? DARK : LIGHT;
  const toggle = () => setIsDark(d => !d);

  const handleNavChange = (s: string) => { setScreen(s); setSelectedDoc(null); };
  const isViewer = selectedDoc !== null;

  const phoneShadow = isDark
    ? `0 0 0 1px #1E2440, 0 0 0 2.5px #0B0D1A, 0 70px 140px rgba(0,0,0,0.9), 0 0 80px ${DARK.NAVY}30`
    : `0 0 0 1px #C4CCE8, 0 0 0 2.5px #B0BAD6, 0 40px 100px rgba(0,0,0,0.18), 0 0 60px ${LIGHT.NAVY}15`;

  const renderScreen = () => {
    if (isViewer) return <ViewerScreen doc={selectedDoc!} onBack={() => setSelectedDoc(null)} />;
    switch (screen) {
      case "home":     return <HomeScreen homeTab={homeTab} setHomeTab={setHomeTab} onDocTap={setSelectedDoc} />;
      case "tools":    return <ToolsScreen />;
      case "settings": return <SettingsScreen onToggleDark={toggle} />;
      default:         return null;
    }
  };

  return (
    <ThemeCtx.Provider value={{ c, isDark, toggle }}>
      {showScreenshots && <Screenshots onClose={() => setShowScreenshots(false)} />}
      <div
        style={{
          minHeight: "100vh",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          background: c.pageBg,
          padding: "24px 16px",
          fontFamily: "'Plus Jakarta Sans', system-ui, sans-serif",
          transition: "background 0.35s",
        }}
      >
        {/* Ambient glow */}
        <div style={{ position: "fixed", top: "20%", left: "50%", transform: "translateX(-50%)", width: 560, height: 400, background: `radial-gradient(ellipse, ${c.pageGlow} 0%, transparent 68%)`, pointerEvents: "none", transition: "opacity 0.35s" }} />

        {/* Screenshots button */}
        <button
          onClick={() => setShowScreenshots(true)}
          style={{
            position: "fixed", top: 20, left: 24,
            display: "flex", alignItems: "center", gap: 7,
            padding: "8px 16px", borderRadius: 24,
            background: c.SURFACE, border: `1px solid ${c.BORDER}`,
            cursor: "pointer", zIndex: 100,
            boxShadow: isDark ? "0 4px 20px rgba(0,0,0,0.5)" : "0 4px 20px rgba(0,0,0,0.12)",
            fontSize: 12, fontWeight: 700, color: c.TEXT,
            transition: "all 0.25s",
          }}
        >
          📸 Screenshots
        </button>

        {/* Theme toggle pill */}
        <button
          onClick={toggle}
          style={{
            position: "fixed", top: 20, right: 24,
            display: "flex", alignItems: "center", gap: 7,
            padding: "8px 16px", borderRadius: 24,
            background: c.SURFACE, border: `1px solid ${c.BORDER}`,
            cursor: "pointer", zIndex: 100,
            boxShadow: isDark ? "0 4px 20px rgba(0,0,0,0.5)" : "0 4px 20px rgba(0,0,0,0.12)",
            transition: "all 0.25s",
          }}
        >
          {isDark
            ? <><Sun  size={14} color={c.AMBER} /><span style={{ fontSize: 12, fontWeight: 700, color: c.TEXT }}>Light</span></>
            : <><Moon size={14} color={c.NAVY}  /><span style={{ fontSize: 12, fontWeight: 700, color: c.TEXT }}>Dark</span></>
          }
        </button>

        {/* Phone frame */}
        <div style={{ position: "relative", width: 390, zIndex: 1, flexShrink: 0 }}>
          {/* Physical buttons */}
          <div style={{ position: "absolute", left: -2, top: 118, width: 2, height: 30, background: c.btnSide, borderRadius: "2px 0 0 2px" }} />
          <div style={{ position: "absolute", left: -2, top: 162, width: 2, height: 58, background: c.btnSide, borderRadius: "2px 0 0 2px" }} />
          <div style={{ position: "absolute", left: -2, top: 232, width: 2, height: 58, background: c.btnSide, borderRadius: "2px 0 0 2px" }} />
          <div style={{ position: "absolute", right: -2, top: 150, width: 2, height: 72, background: c.btnSide, borderRadius: "0 2px 2px 0" }} />

          <div style={{ borderRadius: 52, overflow: "hidden", height: 844, display: "flex", flexDirection: "column", background: c.APP_BG, boxShadow: phoneShadow, transition: "background 0.35s, box-shadow 0.35s" }}>
            {/* Dynamic island */}
            <div style={{ background: c.APP_BG, paddingTop: 14, paddingBottom: 8, display: "flex", justifyContent: "center", flexShrink: 0, transition: "background 0.35s" }}>
              <div style={{ width: 120, height: 32, background: "#000", borderRadius: 20 }} />
            </div>

            <StatusBar />

            <div style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden" }}>
              {renderScreen()}
            </div>

            {!isViewer && (
              <>
                <BottomNav active={screen} onChange={handleNavChange} />
                <AdBanner />
              </>
            )}

            {/* Home indicator */}
            <div style={{ display: "flex", justifyContent: "center", paddingBottom: 8, paddingTop: 4, flexShrink: 0, background: isViewer ? "#0E0E0E" : c.SURFACE, transition: "background 0.35s" }}>
              <div style={{ width: 130, height: 5, background: isDark ? "rgba(255,255,255,0.18)" : "rgba(0,0,0,0.15)", borderRadius: 3 }} />
            </div>
          </div>
        </div>

        <p style={{ position: "fixed", bottom: 20, left: "50%", transform: "translateX(-50%)", fontSize: 11, color: isDark ? "rgba(255,255,255,0.18)" : "rgba(0,0,0,0.18)", letterSpacing: "0.06em", textTransform: "uppercase", whiteSpace: "nowrap", zIndex: 2 }}>
          QuickPDF · Offline-first PDF workstation
        </p>
      </div>
    </ThemeCtx.Provider>
  );
}
