#!/usr/bin/env python3
"""Build the three existing static Hostinger pages without changing shared site assets."""
from html import escape
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "AppStore/Web"
OUTPUT = BASE / "publish/keptora"

def inline(text):
    value = escape(text)
    value = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", value)
    return re.sub(r"`(.+?)`", r"<code>\1</code>", value)

def markdown(text):
    result, paragraph, listing = [], [], None
    def flush():
        if paragraph:
            result.append("<p>" + inline(" ".join(paragraph)) + "</p>")
            paragraph.clear()
    def close():
        nonlocal listing
        if listing:
            result.append("</" + listing + ">")
            listing = None
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("# "):
            continue
        if not line:
            flush(); close(); continue
        if line.startswith("##"):
            flush(); close()
            result.append("<h2>" + inline(line.lstrip("# ")) + "</h2>")
            continue
        match = re.match(r"(?:- |\d+\. )(.+)", line)
        if match:
            flush()
            kind = "ul" if line.startswith("- ") else "ol"
            if listing != kind:
                close(); result.append("<" + kind + ">"); listing = kind
            result.append("<li>" + inline(match.group(1)) + "</li>")
        else:
            close(); paragraph.append(line)
    flush(); close()
    return "".join(result)

pages = {}
for name in ("index", "privacy", "support"):
    page = (BASE / "previous" / (name + ".html")).read_text()
    assert "<script" not in page, "Unexpected hydration scripts: inspect before editing"
    page = page.replace("macOS 13+", "iPhone (iOS 17+) and Mac (macOS 13+)")
    page = page.replace("Selected photo folders, scan indexes, review decisions and quarantine history stay on your Mac.",
        "Selected photos, videos, scan indexes, review decisions and recovery history stay on your iPhone or Mac.")
    page = page.replace("every approved move reversible",
        "recovery conditions clear before you confirm removal")
    page = page.replace("macOS%20version%3A", "iOS%20or%20macOS%20version%3A")
    if name == "privacy":
        content = (ROOT / "AppStore/PRIVACY_POLICY.md").read_text()
        article = '<article class="policy-article page-shell"><p class="product-kicker">Keptora · iPhone and Mac</p><h1>Privacy Policy</h1>' + markdown(content) + '</article>'
        page, count = re.subn(r'<article class="policy-article page-shell">.*?</article>', lambda _: article, page, flags=re.S)
        assert count == 1
    elif name == "support":
        page = page.replace("Open the app’s About screen and include the displayed version and build when available.",
            "Open Keptora Settings on iPhone or Mac and include the displayed version and build.")
        page = page.replace("<h3>macOS version</h3>", "<h3>iOS or macOS version</h3>")
        page = page.replace("Include the macOS version and Mac model relevant to the problem.",
            "Include the iOS or macOS version and your iPhone or Mac model.")
        content = (ROOT / "AppStore/SUPPORT_PAGE.md").read_text()
        article = '<article class="policy-article page-shell"><h2>iPhone and Mac help</h2>' + markdown(content) + '</article>'
        page = page.replace('<footer class="product-footer', article + '<footer class="product-footer', 1)
    dest = OUTPUT / ("" if name == "index" else name) / "index.html"
    if name in ("privacy", "support"):
        page = page.replace("</head>", "<style>.policy-article ul,.policy-article ol{padding-left:1.5rem;margin:1rem 0;list-style:revert}.policy-article li{line-height:1.8;margin:.45rem 0;color:#5c6259}.policy-article code{overflow-wrap:anywhere}</style></head>")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(page)
    assert "iPhone" in page and "Mac" in page
    assert "Publish this" not in page
    pages[str(dest.relative_to(ROOT))] = hashlib.sha256(page.encode()).hexdigest()
(BASE / "manifest.json").write_text(json.dumps(pages, indent=2) + "\n")
print("Built and verified", len(pages), "static pages; shared styling and navigation preserved.")
