"""Render a local UX status report without changing the versioned registry."""
import argparse
import collections
import html
import json
import os
from pathlib import Path
from urllib.parse import quote


def render(registry, output, evidence_root=None):
    data = json.loads(registry.read_text(encoding="utf-8"))
    findings = data["findings"]
    ids = [item["id"] for item in findings]
    if len(ids) != len(set(ids)):
        raise ValueError("Duplicate finding IDs")
    allowed = set(data["statusPolicy"])
    for item in findings:
        if item["status"] not in allowed:
            raise ValueError("Unknown finding status: " + item["id"])
    esc = lambda value: html.escape(str(value), quote=True)
    counts = collections.Counter(item["status"] for item in findings)
    body = "<h1>Piko UX review</h1><p>Registry revision " + esc(data["revision"]) + " · "
    body += " · ".join(esc(key) + ": " + str(value) for key, value in counts.items()) + "</p>"
    body += "<p>This report preserves recorded status. Rendering is not verification and never closes a finding.</p>"
    for item in findings:
        body += '<details id="' + esc(item["id"]) + '"><summary>'
        body += esc(item["priority"] + " · " + item["id"] + " · " + item["title"]) + "</summary>"
        for key in ["status", "screen", "summary", "impact", "confidence", "reach", "workPackage", "decision"]:
            body += "<p><strong>" + esc(key) + ":</strong> " + esc(item.get(key, "Not recorded")) + "</p>"
        body += "<h2>Acceptance</h2><ul>" + "".join("<li>" + esc(x) + "</li>" for x in item["acceptance"]) + "</ul>"
        body += "<p>Requirements: " + esc(", ".join(item["requirements"])) + "</p>"
        body += "<p>Dependencies: " + esc(", ".join(item.get("dependencies", []))) + "</p>"
        body += "<h2>Evidence</h2><ul>"
        for ref in item.get("evidenceRefs", []):
            label = " · ".join(str(ref[k]) for k in ["review", "kind", "id", "ref", "revision"] if k in ref)
            path, fragment = None, ""
            if evidence_root:
                if ref.get("review") in ["original-review", "original-android-review"]:
                    path, fragment = evidence_root / "index.html", "#" + item["id"]
                elif ref.get("review") == "style-copy-review" and ref.get("ref"):
                    path = evidence_root / "style-review" / ref["ref"]
                elif ref.get("file"):
                    path = evidence_root / ref["file"]
            if path and path.is_file():
                link = quote(os.path.relpath(path, output.parent).replace(os.sep, "/"), safe="/") + fragment
                label = '<a href="' + esc(link) + '">' + esc(label or path.name) + "</a>"
            else:
                label = esc(label) + " (local evidence link unavailable)"
            body += "<li>" + label + "</li>"
        body += "</ul><h2>Verification</h2><pre>" + esc(json.dumps(item.get("verification", item.get("verifiedAt")), ensure_ascii=False, indent=2)) + "</pre>"
        body += "<h2>History</h2><ul>" + "".join("<li>" + esc(event.get("date", "")) + " · " + esc(event.get("event", "")) + "</li>" for event in item.get("history", [])) + "</ul></details>"
    document = '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Piko UX review</title><style>body{font:16px/1.6 system-ui;max-width:1000px;margin:32px auto;padding:0 20px;background:#F6F7FB;color:#34365B}details{padding:20px;margin:16px 0;background:#FFFDF8;border-radius:16px}summary{font-weight:700;cursor:pointer}h2{font-size:18px}a{color:#4D64AE}pre{white-space:pre-wrap}li{margin:8px 0}</style>'
    document += body + '<script>const item=document.getElementById(location.hash.slice(1));if(item)item.open=true;</script></html>'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(document, encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", type=Path, default=Path("docs/ux-findings.json"))
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--evidence-root", type=Path)
    args = parser.parse_args()
    render(args.registry, args.out, args.evidence_root)
