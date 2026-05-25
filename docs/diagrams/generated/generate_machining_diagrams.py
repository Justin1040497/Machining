from pathlib import Path
from xml.sax.saxutils import escape


OUT_DIR = Path(__file__).resolve().parent
FONT = (
    "'Helvetica Neue', Helvetica, Arial, 'PingFang SC', "
    "'Microsoft YaHei', 'Microsoft JhengHei', SimHei, sans-serif"
)

COLORS = {
    "bg": "#ffffff",
    "text": "#111827",
    "muted": "#6b7280",
    "stroke": "#d1d5db",
    "blue": "#2563eb",
    "blue_fill": "#eff6ff",
    "blue_stroke": "#bfdbfe",
    "green": "#16a34a",
    "green_fill": "#f0fdf4",
    "green_stroke": "#86efac",
    "orange": "#ea580c",
    "orange_fill": "#fff7ed",
    "orange_stroke": "#fed7aa",
    "purple": "#7c3aed",
    "purple_fill": "#faf5ff",
    "purple_stroke": "#d8b4fe",
    "gray": "#6b7280",
    "gray_fill": "#f9fafb",
    "red": "#dc2626",
    "red_fill": "#fef2f2",
    "red_stroke": "#fecaca",
    "teal": "#0f766e",
    "teal_fill": "#f0fdfa",
    "teal_stroke": "#99f6e4",
}


def e(value):
    return escape(str(value), {'"': "&quot;"})


def svg_open(lines, width, height, title):
    lines.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        f'width="{width}" height="{height}">'
    )
    lines.append("<style>")
    lines.append(
        f"text {{ font-family: {FONT}; letter-spacing: 0; }}"
        " .title { font-size: 22px; font-weight: 700; fill: #111827; }"
        " .subtitle { font-size: 12px; fill: #6b7280; }"
        " .label { font-size: 14px; fill: #111827; }"
        " .small { font-size: 12px; fill: #6b7280; }"
        " .tiny { font-size: 10px; fill: #6b7280; font-weight: 600; }"
    )
    lines.append("</style>")
    lines.append("<defs>")
    marker(lines, "arrow-blue", COLORS["blue"])
    marker(lines, "arrow-green", COLORS["green"])
    marker(lines, "arrow-orange", COLORS["orange"])
    marker(lines, "arrow-purple", COLORS["purple"])
    marker(lines, "arrow-gray", COLORS["gray"])
    marker(lines, "arrow-red", COLORS["red"])
    marker(lines, "arrow-black", COLORS["text"])
    open_marker(lines, "open-gray", COLORS["gray"])
    hollow_triangle(lines, "hollow-triangle", COLORS["gray"])
    diamond_marker(lines, "diamond-fill", COLORS["text"], filled=True)
    diamond_marker(lines, "diamond-hollow", COLORS["gray"], filled=False)
    lines.append("</defs>")
    lines.append(f'<rect width="{width}" height="{height}" fill="{COLORS["bg"]}"/>')
    text(lines, 40, 42, title, anchor="start", size=22, weight=700, css_class="title")


def svg_close(lines):
    lines.append("</svg>")


def marker(lines, marker_id, color):
    lines.append(
        f'<marker id="{marker_id}" markerWidth="10" markerHeight="7" '
        'refX="9" refY="3.5" orient="auto">'
    )
    lines.append(f'<polygon points="0 0, 10 3.5, 0 7" fill="{color}"/>')
    lines.append("</marker>")


def open_marker(lines, marker_id, color):
    lines.append(
        f'<marker id="{marker_id}" markerWidth="12" markerHeight="10" '
        'refX="10" refY="5" orient="auto">'
    )
    lines.append(
        f'<path d="M 1 1 L 10 5 L 1 9" fill="none" stroke="{color}" '
        'stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>'
    )
    lines.append("</marker>")


def hollow_triangle(lines, marker_id, color):
    lines.append(
        f'<marker id="{marker_id}" markerWidth="14" markerHeight="12" '
        'refX="12" refY="6" orient="auto">'
    )
    lines.append(
        f'<path d="M 1 1 L 12 6 L 1 11 Z" fill="#ffffff" stroke="{color}" '
        'stroke-width="1.5" stroke-linejoin="round"/>'
    )
    lines.append("</marker>")


def diamond_marker(lines, marker_id, color, filled):
    fill = color if filled else "#ffffff"
    lines.append(
        f'<marker id="{marker_id}" markerWidth="14" markerHeight="14" '
        'refX="2" refY="7" orient="auto">'
    )
    lines.append(
        f'<path d="M 7 1 L 13 7 L 7 13 L 1 7 Z" fill="{fill}" '
        f'stroke="{color}" stroke-width="1.4"/>'
    )
    lines.append("</marker>")


def text(
    lines,
    x,
    y,
    value,
    *,
    anchor="middle",
    size=14,
    fill=None,
    weight=400,
    css_class=None,
    italic=False,
):
    fill = fill or COLORS["text"]
    style = "font-style:italic;" if italic else ""
    class_attr = f' class="{css_class}"' if css_class else ""
    lines.append(
        f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-size="{size}" '
        f'font-weight="{weight}" fill="{fill}" style="{style}"{class_attr}>{e(value)}</text>'
    )


def multiline_text(lines, x, y, values, *, anchor="middle", size=13, fill=None, gap=17, weight=400):
    for i, value in enumerate(values):
        text(lines, x, y + i * gap, value, anchor=anchor, size=size, fill=fill, weight=weight)


def node(
    lines,
    x,
    y,
    w,
    h,
    title,
    subtitle=None,
    *,
    fill="#ffffff",
    stroke=None,
    rx=8,
    title_size=14,
):
    stroke = stroke or COLORS["stroke"]
    lines.append(
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" ry="{rx}" '
        f'fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>'
    )
    center = x + w / 2
    if subtitle:
        text(lines, center, y + h / 2 - 4, title, size=title_size, weight=700)
        if isinstance(subtitle, list):
            multiline_text(lines, center, y + h / 2 + 15, subtitle, size=11, fill=COLORS["muted"], gap=14)
        else:
            text(lines, center, y + h / 2 + 15, subtitle, size=11, fill=COLORS["muted"])
    else:
        text(lines, center, y + h / 2 + 5, title, size=title_size, weight=700)


def lane(lines, x, y, w, h, label, *, fill, stroke):
    lines.append(
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" ry="10" '
        f'fill="{fill}" fill-opacity="0.62" stroke="{stroke}" stroke-width="1.3" '
        'stroke-dasharray="7,5"/>'
    )
    text(lines, x + 14, y + 22, label, anchor="start", size=11, fill=COLORS["muted"], weight=700)


def cylinder(lines, cx, top, w, h, title, subtitle=None, *, fill=None, stroke=None):
    fill = fill or COLORS["blue_fill"]
    stroke = stroke or COLORS["blue_stroke"]
    rx = w / 2
    ry = max(10, w / 7)
    lines.append(f'<ellipse cx="{cx}" cy="{top}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
    lines.append(f'<rect x="{cx - rx}" y="{top}" width="{w}" height="{h}" fill="{fill}" stroke="none"/>')
    lines.append(f'<line x1="{cx - rx}" y1="{top}" x2="{cx - rx}" y2="{top + h}" stroke="{stroke}" stroke-width="1.5"/>')
    lines.append(f'<line x1="{cx + rx}" y1="{top}" x2="{cx + rx}" y2="{top + h}" stroke="{stroke}" stroke-width="1.5"/>')
    lines.append(f'<ellipse cx="{cx}" cy="{top + h}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
    text(lines, cx, top + h / 2 + 3, title, size=13, weight=700)
    if subtitle:
        text(lines, cx, top + h / 2 + 20, subtitle, size=11, fill=COLORS["muted"])


def arrow(lines, points, *, color=None, marker=None, dash=None, width=2, label=None, label_xy=None):
    color = color or COLORS["blue"]
    marker = marker or "arrow-blue"
    d = "M " + " L ".join(f"{x},{y}" for x, y in points)
    dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
    lines.append(
        f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" '
        f'stroke-linecap="round" stroke-linejoin="round" marker-end="url(#{marker})"{dash_attr}/>'
    )
    if label:
        if label_xy is None:
            label_xy = points[len(points) // 2]
        lx, ly = label_xy
        label_bg(lines, lx, ly - 10, label)
        text(lines, lx, ly - 5, label, size=11, fill=COLORS["muted"])


def label_bg(lines, cx, cy, label, *, bg="#ffffff"):
    w = max(42, len(label) * 6.4 + 12)
    h = 18
    lines.append(
        f'<rect x="{cx - w / 2:.1f}" y="{cy - h / 2:.1f}" width="{w:.1f}" height="{h}" '
        f'rx="4" fill="{bg}" opacity="0.95"/>'
    )


def legend(lines, x, y, items):
    lines.append(f'<g transform="translate({x},{y})">')
    lines.append('<rect x="-12" y="-18" width="260" height="86" rx="8" fill="#ffffff" stroke="#e5e7eb"/>')
    text(lines, 0, -2, "Legend", anchor="start", size=12, weight=700)
    for i, (label, color, marker_id, dash) in enumerate(items):
        yy = 18 + i * 18
        dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
        lines.append(
            f'<line x1="0" y1="{yy}" x2="32" y2="{yy}" stroke="{color}" '
            f'stroke-width="1.8" marker-end="url(#{marker_id})"{dash_attr}/>'
        )
        text(lines, 42, yy + 4, label, anchor="start", size=11, fill=COLORS["muted"])
    lines.append("</g>")


def class_box(lines, x, y, w, title, attrs, methods=None, *, stereotype=None, fill="#ffffff"):
    methods = methods or []
    header_h = 34 if stereotype is None else 48
    attr_h = max(34, 18 + 16 * len(attrs))
    method_h = max(26, 16 + 16 * len(methods))
    h = header_h + attr_h + method_h
    lines.append(
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" fill="{fill}" '
        f'stroke="{COLORS["stroke"]}" stroke-width="1.5"/>'
    )
    lines.append(f'<line x1="{x}" y1="{y + header_h}" x2="{x + w}" y2="{y + header_h}" stroke="{COLORS["stroke"]}"/>')
    lines.append(f'<line x1="{x}" y1="{y + header_h + attr_h}" x2="{x + w}" y2="{y + header_h + attr_h}" stroke="{COLORS["stroke"]}"/>')
    if stereotype:
        text(lines, x + w / 2, y + 18, stereotype, size=11, fill=COLORS["muted"])
        text(lines, x + w / 2, y + 37, title, size=14, weight=700)
    else:
        text(lines, x + w / 2, y + 23, title, size=14, weight=700)
    for i, attr in enumerate(attrs):
        text(lines, x + 10, y + header_h + 20 + i * 16, attr, anchor="start", size=11, fill=COLORS["text"])
    for i, method in enumerate(methods):
        text(lines, x + 10, y + header_h + attr_h + 18 + i * 16, method, anchor="start", size=11, fill=COLORS["muted"])
    return h


def er_entity(lines, x, y, w, title, attrs, *, fill="#ffffff"):
    row_h = 20
    header_h = 32
    h = header_h + row_h * len(attrs) + 12
    lines.append(
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="5" fill="{fill}" '
        f'stroke="{COLORS["stroke"]}" stroke-width="1.5"/>'
    )
    lines.append(f'<rect x="{x}" y="{y}" width="{w}" height="{header_h}" rx="5" fill="#f3f4f6" stroke="none"/>')
    lines.append(f'<line x1="{x}" y1="{y + header_h}" x2="{x + w}" y2="{y + header_h}" stroke="{COLORS["stroke"]}"/>')
    text(lines, x + w / 2, y + 22, title, size=13, weight=700)
    for i, attr in enumerate(attrs):
        yy = y + header_h + 18 + i * row_h
        if attr.startswith("PK "):
            label = attr[3:]
            text(lines, x + 12, yy, label, anchor="start", size=11, fill=COLORS["text"], weight=700)
            lines.append(f'<line x1="{x + 12}" y1="{yy + 2}" x2="{x + 12 + len(label) * 6}" y2="{yy + 2}" stroke="{COLORS["text"]}" stroke-width="1"/>')
        else:
            text(lines, x + 12, yy, attr, anchor="start", size=11, fill=COLORS["muted"])
    return h


def generate_architecture():
    lines = []
    svg_open(lines, 1200, 760, "Machining Architecture")
    text(lines, 40, 64, "Flutter Desktop app with Clean Architecture-style dependency boundaries", anchor="start", size=12, fill=COLORS["muted"])

    lane(lines, 40, 86, 1120, 124, "FEATURES / APP", fill=COLORS["blue_fill"], stroke=COLORS["blue_stroke"])
    lane(lines, 40, 238, 1120, 146, "APPLICATION", fill=COLORS["orange_fill"], stroke=COLORS["orange_stroke"])
    lane(lines, 40, 412, 1120, 110, "DOMAIN", fill=COLORS["green_fill"], stroke=COLORS["green_stroke"])
    lane(lines, 40, 550, 1120, 132, "INFRASTRUCTURE + LOCAL RUNTIME", fill=COLORS["purple_fill"], stroke=COLORS["purple_stroke"])

    node(lines, 76, 128, 160, 54, "Workbench UI", "pages + widgets", fill="#ffffff")
    node(lines, 270, 128, 160, 54, "App Shell", "router + theme", fill="#ffffff")
    node(lines, 464, 128, 160, 54, "Settings Dialog", "app defaults", fill="#ffffff")
    node(lines, 658, 128, 160, 54, "Task Widgets", "list + preview", fill="#ffffff")
    node(lines, 852, 128, 170, 54, "Queue Controls", "start pause retry", fill="#ffffff")

    node(lines, 70, 286, 184, 64, "MediaTaskListNotifier", "UI orchestration", fill="#ffffff")
    node(lines, 296, 286, 170, 64, "Queue Runner", "serial FFmpeg work", fill="#ffffff")
    node(lines, 508, 286, 176, 64, "Command Builder", "plan + args", fill="#ffffff")
    node(lines, 726, 286, 176, 64, "Analyze / Preview", "FFprobe + frames", fill="#ffffff")
    node(lines, 944, 286, 160, 64, "Repository APIs", "tasks + settings", fill="#ffffff")

    node(lines, 120, 444, 160, 50, "MediaTask", "state transitions", fill="#ffffff")
    node(lines, 362, 444, 174, 50, "VideoTaskConfig", "codec mode output", fill="#ffffff")
    node(lines, 612, 444, 190, 50, "MediaAnalysisResult", "duration bitrate codec", fill="#ffffff")
    node(lines, 882, 444, 158, 50, "AppSettings", "global defaults", fill="#ffffff")

    cylinder(lines, 160, 596, 136, 54, "SQLite", "Drift tables", fill="#ffffff", stroke=COLORS["purple_stroke"])
    node(lines, 320, 590, 154, 62, "FFmpeg Runtime", "bundled/custom/PATH", fill="#ffffff")
    node(lines, 512, 590, 154, 62, "Local Services", "locator fs analyzer", fill="#ffffff")
    node(lines, 704, 590, 168, 62, "Process Layer", "starter + observer", fill="#ffffff")
    cylinder(lines, 980, 596, 150, 54, "Temp Files", "logs previews pass", fill="#ffffff", stroke=COLORS["purple_stroke"])

    arrow(lines, [(156, 182), (156, 286)], color=COLORS["blue"], marker="arrow-blue", label="actions", label_xy=(156, 238))
    arrow(lines, [(546, 182), (162, 286)], color=COLORS["blue"], marker="arrow-blue", label="defaults", label_xy=(356, 234))
    arrow(lines, [(748, 182), (164, 286)], color=COLORS["blue"], marker="arrow-blue", label="selection", label_xy=(470, 226))
    arrow(lines, [(938, 182), (380, 286)], color=COLORS["blue"], marker="arrow-blue", label="commands", label_xy=(684, 230))
    arrow(lines, [(254, 318), (296, 318)], color=COLORS["orange"], marker="arrow-orange", label="start")
    arrow(lines, [(466, 318), (508, 318)], color=COLORS["orange"], marker="arrow-orange", label="build")
    arrow(lines, [(684, 318), (726, 318)], color=COLORS["orange"], marker="arrow-orange", label="preview")
    arrow(lines, [(944, 318), (872, 318)], color=COLORS["green"], marker="arrow-green", dash="5,3", label="save")

    for x1, x2, label in [(162, 200, "entity"), (594, 447, "config"), (814, 707, "analysis"), (1024, 961, "settings")]:
        arrow(lines, [(x1, 350), (x1, 390), (x2, 390), (x2, 444)], color=COLORS["green"], marker="arrow-green", label=label, label_xy=((x1 + x2) / 2, 392))

    arrow(lines, [(1024, 350), (1024, 596)], color=COLORS["purple"], marker="arrow-purple", dash="5,3", label="persists")
    arrow(lines, [(380, 350), (380, 590)], color=COLORS["purple"], marker="arrow-purple", label="executes")
    arrow(lines, [(594, 350), (594, 568), (704, 568), (704, 590)], color=COLORS["purple"], marker="arrow-purple", label="process")
    arrow(lines, [(814, 350), (814, 568), (512, 568), (512, 590)], color=COLORS["purple"], marker="arrow-purple", label="implements")
    arrow(lines, [(160, 596), (160, 522)], color=COLORS["green"], marker="arrow-green", dash="5,3", label="restore", label_xy=(160, 550))
    arrow(lines, [(760, 652), (980, 650)], color=COLORS["gray"], marker="arrow-gray", dash="4,3", label="logs")

    legend(lines, 44, 700, [
        ("UI/request flow", COLORS["blue"], "arrow-blue", None),
        ("Business control", COLORS["orange"], "arrow-orange", None),
        ("Persistence/read-write", COLORS["green"], "arrow-green", "5,3"),
        ("Local implementation", COLORS["purple"], "arrow-purple", None),
    ])
    svg_close(lines)
    write_svg("machining-architecture.svg", lines)


def generate_data_flow():
    lines = []
    svg_open(lines, 1200, 720, "Machining Data Flow")
    text(lines, 40, 64, "Main import, analysis, compression, progress, and persistence paths", anchor="start", size=12, fill=COLORS["muted"])

    node(lines, 50, 118, 130, 58, "User", "drops video", fill=COLORS["blue_fill"], stroke=COLORS["blue_stroke"])
    node(lines, 220, 118, 160, 58, "Workbench", "selected paths", fill="#ffffff")
    node(lines, 420, 118, 170, 58, "Task Notifier", "create draft", fill="#ffffff")
    node(lines, 640, 118, 190, 58, "Resolver + Fingerprint", "kind + size/mtime", fill="#ffffff")
    cylinder(lines, 980, 126, 160, 64, "tasks", "analyzing row", fill=COLORS["green_fill"], stroke=COLORS["green_stroke"])

    node(lines, 120, 282, 160, 60, "FFprobe", "JSON streams", fill=COLORS["purple_fill"], stroke=COLORS["purple_stroke"])
    node(lines, 350, 282, 182, 60, "MediaAnalysisResult", "codec bitrate duration", fill="#ffffff")
    node(lines, 590, 282, 174, 60, "CompressionAdvisor", "target bitrate", fill="#ffffff")
    node(lines, 820, 282, 178, 60, "CommandBuilder", "FFmpeg plan", fill="#ffffff")

    node(lines, 120, 470, 160, 60, "QueueRunner", "serial execution", fill="#ffffff")
    node(lines, 350, 470, 170, 60, "FFmpeg Process", "local encode", fill=COLORS["purple_fill"], stroke=COLORS["purple_stroke"])
    node(lines, 590, 470, 174, 60, "ProcessObserver", "out_time_ms", fill="#ffffff")
    cylinder(lines, 980, 478, 160, 64, "Output File", "mp4/mov/mkv", fill=COLORS["blue_fill"], stroke=COLORS["blue_stroke"])
    cylinder(lines, 770, 585, 160, 56, "Temp Artifacts", "logs previews pass", fill=COLORS["gray_fill"], stroke=COLORS["stroke"])

    arrow(lines, [(180, 147), (220, 147)], color=COLORS["blue"], marker="arrow-blue", label="video path")
    arrow(lines, [(380, 147), (420, 147)], color=COLORS["blue"], marker="arrow-blue", label="import")
    arrow(lines, [(590, 147), (640, 147)], color=COLORS["orange"], marker="arrow-orange", label="inspect", label_xy=(615, 126))
    arrow(lines, [(830, 147), (900, 147)], color=COLORS["green"], marker="arrow-green", dash="5,3", label="save draft", label_xy=(866, 126))

    arrow(lines, [(900, 190), (760, 230), (200, 230), (200, 282)], color=COLORS["blue"], marker="arrow-blue", label="input path", label_xy=(520, 214))
    arrow(lines, [(280, 312), (350, 312)], color=COLORS["blue"], marker="arrow-blue", label="json")
    arrow(lines, [(532, 312), (590, 312)], color=COLORS["green"], marker="arrow-green", label="analysis", label_xy=(560, 292))
    arrow(lines, [(764, 312), (820, 312)], color=COLORS["orange"], marker="arrow-orange", label="recommend", label_xy=(792, 292))
    arrow(lines, [(998, 312), (1060, 312), (1060, 190)], color=COLORS["green"], marker="arrow-green", dash="5,3", label="update row", label_xy=(1060, 248))

    arrow(lines, [(1140, 190), (1140, 410), (95, 410), (95, 500), (120, 500)], color=COLORS["blue"], marker="arrow-blue", label="pending task", label_xy=(330, 392))
    arrow(lines, [(280, 500), (350, 500)], color=COLORS["orange"], marker="arrow-orange", label="start args", label_xy=(315, 480))
    arrow(lines, [(520, 500), (590, 500)], color=COLORS["blue"], marker="arrow-blue", label="progress", label_xy=(555, 480))
    arrow(lines, [(764, 500), (900, 500)], color=COLORS["green"], marker="arrow-green", dash="5,3", label="status", label_xy=(832, 480))
    arrow(lines, [(435, 530), (435, 650), (770, 650)], color=COLORS["gray"], marker="arrow-gray", dash="4,3", label="stderr/pass", label_xy=(552, 630))
    arrow(lines, [(520, 486), (900, 486)], color=COLORS["blue"], marker="arrow-blue", label="encoded media", label_xy=(710, 464))
    arrow(lines, [(590, 530), (520, 580), (980, 580), (980, 542)], color=COLORS["green"], marker="arrow-green", dash="5,3", label="completed/failed", label_xy=(756, 560))

    legend(lines, 44, 626, [
        ("Media/request data", COLORS["blue"], "arrow-blue", None),
        ("Control/runtime checks", COLORS["orange"], "arrow-orange", None),
        ("Persistent state writes", COLORS["green"], "arrow-green", "5,3"),
        ("Runtime artifacts", COLORS["gray"], "arrow-gray", "4,3"),
    ])
    svg_close(lines)
    write_svg("machining-data-flow.svg", lines)


def lifeline(lines, x, y, h, label):
    node(lines, x - 62, y, 124, 42, label, fill="#ffffff")
    lines.append(
        f'<line x1="{x}" y1="{y + 42}" x2="{x}" y2="{y + h}" '
        f'stroke="{COLORS["stroke"]}" stroke-width="1.2" stroke-dasharray="5,5"/>'
    )


def message(lines, x1, x2, y, label, *, color=None, dash=None):
    marker_id = "arrow-blue"
    color = color or COLORS["blue"]
    if color == COLORS["green"]:
        marker_id = "arrow-green"
    elif color == COLORS["orange"]:
        marker_id = "arrow-orange"
    elif color == COLORS["purple"]:
        marker_id = "arrow-purple"
    elif color == COLORS["gray"]:
        marker_id = "arrow-gray"
    arrow(lines, [(x1, y), (x2, y)], color=color, marker=marker_id, dash=dash, width=1.8, label=label, label_xy=((x1 + x2) / 2, y - 8))


def activation(lines, x, y, h, fill="#eff6ff"):
    lines.append(
        f'<rect x="{x - 5}" y="{y}" width="10" height="{h}" fill="{fill}" '
        f'stroke="{COLORS["blue_stroke"]}" stroke-width="1"/>'
    )


def generate_sequence():
    lines = []
    svg_open(lines, 1240, 920, "Start Compression Sequence")
    text(lines, 40, 64, "Time-ordered path from UI command to FFmpeg completion and task refresh", anchor="start", size=12, fill=COLORS["muted"])
    xs = {
        "User": 80,
        "UI": 220,
        "Notifier": 390,
        "Repo": 550,
        "Runtime": 710,
        "Queue": 870,
        "Builder": 1030,
        "FFmpeg": 1170,
    }
    for label, x in xs.items():
        lifeline(lines, x, 96, 790, label)

    activation(lines, xs["Notifier"], 150, 620)
    activation(lines, xs["Queue"], 210, 520, fill=COLORS["orange_fill"])
    activation(lines, xs["FFmpeg"], 470, 150, fill=COLORS["purple_fill"])

    y = 160
    message(lines, xs["User"], xs["UI"], y, "click Start")
    y += 48
    message(lines, xs["UI"], xs["Notifier"], y, "startExecutionQueue")
    y += 48
    message(lines, xs["Notifier"], xs["Queue"], y, "start()")
    y += 48
    message(lines, xs["Queue"], xs["Repo"], y, "load tasks", color=COLORS["green"], dash="5,3")
    y += 48
    message(lines, xs["Queue"], xs["Runtime"], y, "read runtime", color=COLORS["orange"])
    y += 48
    message(lines, xs["Queue"], xs["Builder"], y, "build plan", color=COLORS["orange"])
    y += 48
    message(lines, xs["Builder"], xs["Queue"], y, "args + steps", color=COLORS["gray"], dash="4,3")
    y += 48
    message(lines, xs["Queue"], xs["Repo"], y, "markRunning", color=COLORS["green"], dash="5,3")
    y += 48
    message(lines, xs["Queue"], xs["FFmpeg"], y, "start process", color=COLORS["purple"])
    y += 48
    message(lines, xs["FFmpeg"], xs["Queue"], y, "progress events", color=COLORS["blue"])
    y += 48
    message(lines, xs["Queue"], xs["Repo"], y, "save progress", color=COLORS["green"], dash="5,3")
    y += 48
    message(lines, xs["FFmpeg"], xs["Queue"], y, "exit status", color=COLORS["purple"])
    y += 48
    message(lines, xs["Queue"], xs["Repo"], y, "mark completed/failed", color=COLORS["green"], dash="5,3")
    y += 48
    message(lines, xs["Queue"], xs["Queue"], y, "continueAfterTask", color=COLORS["orange"])
    lines.append(
        f'<path d="M {xs["Queue"]},690 C 940,658 940,722 {xs["Queue"]},716" '
        f'fill="none" stroke="{COLORS["orange"]}" stroke-width="1.8" marker-end="url(#arrow-orange)"/>'
    )
    label_bg(lines, xs["Queue"] + 70, 682, "next pending")
    text(lines, xs["Queue"] + 70, 687, "next pending", size=11, fill=COLORS["muted"])
    y += 64
    message(lines, xs["Notifier"], xs["Repo"], y, "poll refresh", color=COLORS["green"], dash="5,3")
    y += 48
    message(lines, xs["Notifier"], xs["UI"], y, "new task list", color=COLORS["blue"])

    legend(lines, 44, 804, [
        ("UI/message", COLORS["blue"], "arrow-blue", None),
        ("Runtime control", COLORS["orange"], "arrow-orange", None),
        ("Repository write/read", COLORS["green"], "arrow-green", "5,3"),
        ("Local process", COLORS["purple"], "arrow-purple", None),
    ])
    svg_close(lines)
    write_svg("machining-sequence-start-compression.svg", lines)


def generate_er():
    lines = []
    svg_open(lines, 1200, 780, "Machining Logical ER Diagram")
    text(lines, 40, 64, "SQLite stores recoverable state; files, logs, previews, and FFmpeg JSON stay outside the database", anchor="start", size=12, fill=COLORS["muted"])

    er_entity(lines, 430, 130, 300, "tasks", [
        "PK id text",
        "input_path, file_name, media_kind",
        "purpose, status, progress",
        "sort_order, output_path, error_message",
        "source_file_size, source_last_modified_at",
        "analysis_* fields",
        "output_format, video_codec, encoder_backend",
        "resolution_preset, compression_*",
        "created_at, started_at, completed_at, failed_at",
    ], fill=COLORS["green_fill"])
    er_entity(lines, 70, 120, 270, "settings", [
        "PK id integer (fixed 1)",
        "default_output_directory",
        "last_selected_output_directory",
        "save_output_to_source_directory",
        "custom_ffmpeg_path, custom_ffprobe_path",
        "show_raw_log, show_advanced_options",
        "default_output_video_codec",
        "default_compression_smart_preset",
        "default_output_file_name_template",
    ], fill=COLORS["blue_fill"])
    er_entity(lines, 80, 520, 260, "VideoTaskConfig", [
        "outputFormat",
        "videoCodec",
        "encoderBackend",
        "resolutionPreset",
        "compressionMode",
        "smartPreset / targetSizeBytes",
    ], fill="#ffffff")
    er_entity(lines, 820, 120, 280, "MediaAnalysisResult", [
        "durationMs",
        "videoWidth, videoHeight",
        "videoCodec, audioCodec",
        "videoBitrate, audioBitrate",
        "containerBitrate, estimatedBitrate",
        "containerFormat",
        "audioChannels, audioSampleRate",
    ], fill="#ffffff")
    er_entity(lines, 835, 380, 250, "SourceFile", [
        "absolute path",
        "file size",
        "last modified at",
        "exists or missing",
    ], fill=COLORS["orange_fill"])
    er_entity(lines, 835, 580, 250, "OutputFile", [
        "output_path",
        "format mp4/mov/mkv",
        "unique suffix if needed",
        "created by FFmpeg",
    ], fill=COLORS["purple_fill"])

    diamond(lines, 380, 255, "seeds")
    diamond(lines, 390, 575, "embeds")
    diamond(lines, 780, 245, "stores")
    diamond(lines, 792, 445, "points to")
    diamond(lines, 792, 620, "produces")

    er_line(lines, 340, 255, 360, 255, "1")
    er_line(lines, 400, 255, 430, 255, "0..N")
    er_line(lines, 340, 575, 370, 575, "1")
    er_line(lines, 410, 575, 430, 420, "1")
    er_line(lines, 730, 245, 760, 245, "1")
    er_line(lines, 800, 245, 820, 245, "0..1")
    er_line(lines, 730, 445, 772, 445, "1")
    er_line(lines, 812, 445, 835, 445, "1")
    er_line(lines, 730, 620, 772, 620, "1")
    er_line(lines, 812, 620, 835, 620, "0..1")

    text(lines, 54, 724, "Note: logical value objects are flattened into tasks columns; there are no database foreign keys between tasks and settings.", anchor="start", size=12, fill=COLORS["muted"])
    svg_close(lines)
    write_svg("machining-er-logical-schema.svg", lines)


def diamond(lines, cx, cy, label):
    lines.append(
        f'<polygon points="{cx},{cy - 24} {cx + 44},{cy} {cx},{cy + 24} {cx - 44},{cy}" '
        f'fill="#ffffff" stroke="{COLORS["stroke"]}" stroke-width="1.5"/>'
    )
    text(lines, cx, cy + 4, label, size=11, fill=COLORS["muted"])


def er_line(lines, x1, y1, x2, y2, cardinality):
    lines.append(
        f'<path d="M {x1},{y1} L {x2},{y2}" fill="none" stroke="{COLORS["gray"]}" '
        'stroke-width="1.5" stroke-dasharray="4,3"/>'
    )
    text(lines, (x1 + x2) / 2, (y1 + y2) / 2 - 7, cardinality, size=11, fill=COLORS["muted"])


def generate_uml():
    lines = []
    svg_open(lines, 1420, 920, "Machining Core UML Class Diagram")
    text(lines, 40, 64, "Selected domain, application, and infrastructure classes on the compression path", anchor="start", size=12, fill=COLORS["muted"])

    class_box(lines, 60, 118, 250, "MediaTask", [
        "+ id: String",
        "+ status: TaskStatus",
        "+ config: VideoTaskConfig",
        "+ analysisResult: MediaAnalysisResult?",
    ], ["+ markRunning()", "+ markCompleted()", "+ markFailed()", "+ replaceInputFile()"], fill=COLORS["green_fill"])
    class_box(lines, 370, 118, 230, "VideoTaskConfig", [
        "+ outputFormat",
        "+ videoCodec",
        "+ encoderBackend",
        "+ compressionMode",
        "+ targetSizeBytes?",
    ], ["+ initial()", "+ copyWith()"])
    class_box(lines, 660, 118, 250, "MediaAnalysisResult", [
        "+ durationMs?",
        "+ videoCodec?",
        "+ preferredBitrate",
        "+ audioChannels?",
    ], [])
    class_box(lines, 970, 118, 240, "AppSettings", [
        "+ defaultOutputDirectory?",
        "+ customFfmpegPath?",
        "+ compressionSettings",
    ], ["+ initial()", "+ withCustomFfmpegPath()"])

    class_box(lines, 60, 390, 270, "MediaTaskListNotifier", [
        "+ build()",
        "+ createDraftFromPath()",
        "+ analyzeTaskById()",
        "+ startExecutionQueue()",
    ], [], fill=COLORS["blue_fill"])
    class_box(lines, 390, 390, 250, "FfmpegTaskQueueRunner", [
        "+ queueStatus",
        "+ foregroundTaskId",
    ], ["+ start()", "+ pauseTask()", "+ cancelTask()"], stereotype="<<interface>>")
    class_box(lines, 700, 390, 290, "DefaultFfmpegTaskQueueRunner", [
        "- _executions",
        "- _foregroundTaskId",
        "- repository",
        "- commandBuilder",
    ], ["+ startTask()", "+ finishObservedTask()", "+ continueAfterTask()"], fill=COLORS["orange_fill"])
    class_box(lines, 1060, 390, 250, "MediaTaskRepository", [
        "+ loadAllTasks()",
        "+ saveTask()",
        "+ replaceAllTasks()",
    ], [], stereotype="<<interface>>")

    class_box(lines, 60, 670, 250, "FfmpegCommandBuilder", [
        "+ build(task)",
        "+ buildPreviewSegment()",
    ], [], stereotype="<<interface>>")
    class_box(lines, 370, 670, 290, "DefaultFfmpegCommandBuilder", [
        "- compressionAdvisor",
        "+ resolveTargetVideoCodec()",
        "+ buildCommandSteps()",
    ], ["+ buildSinglePassArgs()", "+ buildTwoPassTargetSizeSteps()"], fill=COLORS["orange_fill"])
    class_box(lines, 730, 670, 250, "CompressionAdvisor", [
        "+ recommend(task)",
    ], [], stereotype="<<interface>>")
    class_box(lines, 1040, 670, 270, "DriftMediaTaskRepository", [
        "- database: AppDatabase",
        "+ rowToTask()",
        "+ taskToCompanion()",
    ], [], fill=COLORS["purple_fill"])

    # Composition from MediaTask to value objects.
    uml_path(lines, [(310, 170), (370, 170)], marker_start="diamond-fill", label="config", label_xy=(338, 150))
    uml_path(lines, [(185, 118), (185, 94), (785, 94), (785, 118)], marker_start="diamond-hollow", label="analysis?", label_xy=(500, 82))
    uml_path(lines, [(485, 118), (485, 82), (1090, 82), (1090, 118)], dash="4,3", label="settings seed new config", label_xy=(790, 70))

    # Application dependencies and implementations.
    uml_path(lines, [(330, 470), (390, 470)], marker_end="open-gray", label="uses", label_xy=(360, 450))
    uml_path(lines, [(640, 470), (700, 470)], marker_end="hollow-triangle", label="implements", label_xy=(670, 450))
    uml_path(lines, [(990, 470), (1060, 470)], marker_end="open-gray", label="uses", label_xy=(1025, 450))
    uml_path(lines, [(195, 532), (195, 614), (1185, 614), (1185, 532)], marker_end="open-gray", dash="5,4", label="persists tasks", label_xy=(690, 600))

    # Command builder path.
    uml_path(lines, [(310, 738), (370, 738)], marker_end="hollow-triangle", label="implements", label_xy=(340, 718))
    uml_path(lines, [(660, 738), (730, 738)], marker_end="open-gray", label="uses", label_xy=(695, 718))
    uml_path(lines, [(840, 610), (650, 670)], marker_end="open-gray", label="builds plan", label_xy=(750, 632))
    uml_path(lines, [(1180, 610), (1180, 670)], marker_end="hollow-triangle", label="implements", label_xy=(1138, 640))
    uml_path(lines, [(840, 610), (840, 670)], marker_end="open-gray", label="recommend", label_xy=(886, 640))

    legend(lines, 46, 832, [
        ("Dependency", COLORS["gray"], "open-gray", None),
        ("Implementation", COLORS["gray"], "hollow-triangle", None),
        ("Composition", COLORS["text"], "diamond-fill", None),
        ("Optional/flattened relation", COLORS["gray"], "open-gray", "5,4"),
    ])
    svg_close(lines)
    write_svg("machining-uml-core-classes.svg", lines)


def uml_line(lines, x1, y1, x2, y2, *, marker_end=None, marker_start=None, dash=None, label=None):
    dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
    end_attr = f' marker-end="url(#{marker_end})"' if marker_end else ""
    start_attr = f' marker-start="url(#{marker_start})"' if marker_start else ""
    lines.append(
        f'<path d="M {x1},{y1} L {x2},{y2}" fill="none" stroke="{COLORS["gray"]}" '
        f'stroke-width="1.5"{dash_attr}{end_attr}{start_attr}/>'
    )
    if label:
        lx = (x1 + x2) / 2
        ly = (y1 + y2) / 2
        label_bg(lines, lx, ly - 8, label)
        text(lines, lx, ly - 3, label, size=10, fill=COLORS["muted"])


def uml_path(lines, points, *, marker_end=None, marker_start=None, dash=None, label=None, label_xy=None):
    dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
    end_attr = f' marker-end="url(#{marker_end})"' if marker_end else ""
    start_attr = f' marker-start="url(#{marker_start})"' if marker_start else ""
    d = "M " + " L ".join(f"{x},{y}" for x, y in points)
    lines.append(
        f'<path d="{d}" fill="none" stroke="{COLORS["gray"]}" '
        f'stroke-width="1.5"{dash_attr}{end_attr}{start_attr}/>'
    )
    if label:
        if label_xy is None:
            label_xy = points[len(points) // 2]
        lx, ly = label_xy
        label_bg(lines, lx, ly - 8, label)
        text(lines, lx, ly - 3, label, size=10, fill=COLORS["muted"])


def generate_timeline():
    lines = []
    svg_open(lines, 1200, 520, "Machining Product Timeline")
    text(lines, 40, 64, "Roadmap distilled from docs/product/roadmap.md, current version v1.5.0+1", anchor="start", size=12, fill=COLORS["muted"])

    axis_y = 130
    lines.append(f'<line x1="90" y1="{axis_y}" x2="1110" y2="{axis_y}" stroke="{COLORS["stroke"]}" stroke-width="2"/>')
    ticks = [
        (110, "v1.0"),
        (260, "v1.1"),
        (410, "v1.2"),
        (560, "v1.3"),
        (780, "v1.5"),
        (980, "Next"),
    ]
    for x, label in ticks:
        lines.append(f'<circle cx="{x}" cy="{axis_y}" r="5" fill="{COLORS["blue"]}"/>')
        text(lines, x, axis_y - 18, label, size=12, weight=700)

    timeline_bar(lines, 90, 180, 190, "v1.0 Core Compression", [
        "local import",
        "FFprobe analysis",
        "queue + pause/resume",
    ], COLORS["blue_fill"], COLORS["blue_stroke"])
    timeline_bar(lines, 250, 180, 170, "v1.1 Windows + GPU", [
        "windows x64 base",
        "encoder detection",
        "auto backend",
    ], COLORS["teal_fill"], COLORS["teal_stroke"])
    timeline_bar(lines, 400, 180, 175, "v1.2 Workbench UX", [
        "lighter workbench",
        "thumbnails",
        "config window",
    ], COLORS["green_fill"], COLORS["green_stroke"])
    timeline_bar(lines, 555, 180, 215, "v1.3 Smart Compression", [
        "smart presets",
        "target size",
        "estimator + refactor",
    ], COLORS["orange_fill"], COLORS["orange_stroke"])
    timeline_bar(lines, 750, 180, 230, "v1.5 Settings + Release", [
        "settings dialog",
        "default output policy",
        "GPLv3+ release docs",
    ], COLORS["purple_fill"], COLORS["purple_stroke"])

    text(lines, 90, 348, "Planned / next focus", anchor="start", size=13, weight=700)
    timeline_bar(lines, 90, 372, 230, "Theme Preference", [
        "light/dark themes",
        "settings persistence",
    ], "#ffffff", COLORS["stroke"])
    timeline_bar(lines, 350, 372, 270, "Background Compression", [
        "minimize behavior",
        "progress + recovery rules",
    ], "#ffffff", COLORS["stroke"])
    timeline_bar(lines, 650, 372, 300, "FFmpeg License Normalization", [
        "release package checks",
        "legal file placement",
    ], "#ffffff", COLORS["stroke"])

    lines.append(f'<path d="M 780,135 L 780,470" stroke="{COLORS["red"]}" stroke-width="1.5" stroke-dasharray="6,5"/>')
    text(lines, 792, 462, "current documented version", anchor="start", size=11, fill=COLORS["red"], weight=700)

    svg_close(lines)
    write_svg("machining-roadmap-timeline.svg", lines)


def timeline_bar(lines, x, y, w, title, details, fill, stroke):
    h = 122 if len(details) == 3 else 98
    lines.append(
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{fill}" '
        f'stroke="{stroke}" stroke-width="1.5"/>'
    )
    text(lines, x + 12, y + 24, title, anchor="start", size=13, weight=700)
    for i, item in enumerate(details):
        text(lines, x + 16, y + 50 + i * 18, "- " + item, anchor="start", size=11, fill=COLORS["muted"])


def write_svg(filename, lines):
    path = OUT_DIR / filename
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(path)


def main():
    generate_architecture()
    generate_data_flow()
    generate_sequence()
    generate_er()
    generate_uml()
    generate_timeline()


if __name__ == "__main__":
    main()
