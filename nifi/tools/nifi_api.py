"""Minimal NiFi 2.x REST client for lab automation on VM1 (run with sudo; reads /root/nt132-secrets/nifi_ui.cred).
TLS: localhost self-signed cert -> verification disabled for this management client only (not TLS evidence)."""
import json, ssl, sys, os, urllib.request, urllib.parse, urllib.error
BASE = "https://localhost:8443/nifi-api"
SEC = "/root/nt132-secrets"
_ctx = ssl.create_default_context(); _ctx.check_hostname = False; _ctx.verify_mode = ssl.CERT_NONE
_tok = None
def _token(refresh=False):
    global _tok
    tf = f"{SEC}/nifi.token"
    if not refresh and _tok: return _tok
    if not refresh and os.path.exists(tf):
        _tok = open(tf).read().strip(); return _tok
    u, p = open(f"{SEC}/nifi_ui.cred").read().splitlines()[:2]
    data = urllib.parse.urlencode({"username": u, "password": p}).encode()
    req = urllib.request.Request(BASE + "/access/token", data=data, method="POST",
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    _tok = urllib.request.urlopen(req, context=_ctx).read().decode()
    old = os.umask(0o077); open(tf, "w").write(_tok); os.umask(old)
    return _tok
def call(method, path, body=None, retry=True, raw=False):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method,
        headers={"Authorization": "Bearer " + _token(), "Content-Type": "application/json"})
    try:
        r = urllib.request.urlopen(req, context=_ctx).read().decode()
        return r if raw else (json.loads(r) if r else None)
    except urllib.error.HTTPError as e:
        if e.code == 401 and retry:
            _token(refresh=True); return call(method, path, body, False, raw)
        raise RuntimeError(f"{method} {path} -> HTTP {e.code}: {e.read().decode()[:800]}")
get = lambda p: call("GET", p)
post = lambda p, b: call("POST", p, b)
put = lambda p, b: call("PUT", p, b)
def delete(p): return call("DELETE", p)
def rev(ent): return {"version": ent["revision"]["version"]}
import time
def set_params(ctx_id, params):
    """params: list of (name, value, sensitive). Async update request, polls until complete."""
    ctx = get(f"/parameter-contexts/{ctx_id}")
    body = {"revision": rev(ctx), "id": ctx_id, "component": {"id": ctx_id,
            "parameters": [{"parameter": {"name": n, "value": v, "sensitive": s}} for n, v, s in params]}}
    req = post(f"/parameter-contexts/{ctx_id}/update-requests", body)["request"]
    rid = req["requestId"]
    for _ in range(60):
        r = get(f"/parameter-contexts/{ctx_id}/update-requests/{rid}")["request"]
        if r["complete"]: break
        time.sleep(1)
    delete(f"/parameter-contexts/{ctx_id}/update-requests/{rid}")
    if r.get("failureReason"): raise RuntimeError(r["failureReason"])
    return r["state"]
def secret(name):
    return open(f"{SEC}/{name}").read().strip()
BP = {"backPressureObjectThreshold": 100, "backPressureDataSizeThreshold": "10 MB", "flowFileExpiration": "0 sec"}
def flow(pg): return get(f"/flow/process-groups/{pg}")["processGroupFlow"]["flow"]
def find(pg, name, kind="processors"):
    m = [x for x in flow(pg)[kind] if x["component"]["name"] == name]
    if len(m) != 1: raise RuntimeError(f"{kind} {name!r} in {pg}: {len(m)} matches")
    return m[0]
def update_proc(pid, props=None, auto_term=None, **config):
    p = get(f"/processors/{pid}")
    cfg = dict(config)
    if props is not None: cfg["properties"] = props
    if auto_term is not None: cfg["autoTerminatedRelationships"] = auto_term
    return put(f"/processors/{pid}", {"revision": rev(p), "component": {"id": pid, "config": cfg}})
def create_proc(pg, ptype, name, x, y, bundle=None):
    body = {"revision": {"version": 0}, "component": {"type": ptype, "name": name, "position": {"x": x, "y": y}}}
    if bundle: body["component"]["bundle"] = bundle
    return post(f"/process-groups/{pg}/processors", body)
def _ctype(ent):
    t = ent["component"].get("type", "")
    if "inputPort" in ent or t == "INPUT_PORT": return "INPUT_PORT"
    if "outputPort" in ent or t == "OUTPUT_PORT": return "OUTPUT_PORT"
    return "PROCESSOR" if "." in t else t
def connect(pg, src_id, src_type, rels, dst_id, dst_type, **extra):
    existing = [c for c in flow(pg)["connections"] if c["component"]["source"]["id"] == src_id
                and c["component"]["destination"]["id"] == dst_id]
    comp = {"source": {"id": src_id, "groupId": pg, "type": src_type},
            "destination": {"id": dst_id, "groupId": pg, "type": dst_type}, **BP, **extra}
    if rels: comp["selectedRelationships"] = rels
    if existing:
        c = existing[0]; comp["id"] = c["id"]
        return put(f"/connections/{c['id']}", {"revision": rev(c), "component": comp})
    return post(f"/process-groups/{pg}/connections", {"revision": {"version": 0}, "component": comp})
def run_state(kind, cid, state):
    e = get(f"/{kind}/{cid}")
    return put(f"/{kind}/{cid}/run-status", {"revision": rev(e), "state": state})
def errors(pid):
    return get(f"/processors/{pid}")["component"].get("validationErrors") or []
def queue_list(conn_id):
    r = post(f"/flowfile-queues/{conn_id}/listing-requests", None)["listingRequest"]
    for _ in range(30):
        r = get(f"/flowfile-queues/{conn_id}/listing-requests/{r['id']}")["listingRequest"]
        if r["finished"]: break
        time.sleep(0.5)
    delete(f"/flowfile-queues/{conn_id}/listing-requests/{r['id']}")
    return r.get("flowFileSummaries", [])
def ff_detail(conn_id, uuid):
    return get(f"/flowfile-queues/{conn_id}/flowfiles/{uuid}")["flowFile"]
def ff_content(conn_id, uuid):
    return call("GET", f"/flowfile-queues/{conn_id}/flowfiles/{uuid}/content", raw=True)
def conn_by(pg, src_name, dst_name):
    m = [c for c in flow(pg)["connections"] if c["component"]["source"]["name"] == src_name and c["component"]["destination"]["name"] == dst_name]
    return m[0]["id"]
def queued(pg):
    return {(c["component"]["source"]["name"] + " -> " + c["component"]["destination"]["name"]): c["status"]["aggregateSnapshot"]["flowFilesQueued"] for c in flow(pg)["connections"] if c["status"]["aggregateSnapshot"]["flowFilesQueued"]}
