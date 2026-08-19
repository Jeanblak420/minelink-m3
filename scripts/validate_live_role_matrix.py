import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import psycopg


URL = os.environ.get("SUPABASE_URL", "https://yftazblpmicqtamyiwyb.supabase.co").rstrip("/")
PUB = os.environ["SUPABASE_PUBLISHABLE_KEY"]
SRK = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
# Required, not defaulted — see validate_live_private_storage.py (S9-8).
PW = os.environ["LIVE_VALIDATION_PASSWORD"]
PREFIX = os.environ.get("LIVE_VALIDATION_PREFIX", f"codex.live.{int(time.time())}")
DB = {
    "host": os.environ["SUPABASE_DB_HOST"],
    "port": int(os.environ.get("SUPABASE_DB_PORT", "6543")),
    "user": os.environ["SUPABASE_DB_USER"],
    "password": os.environ["SUPABASE_DB_PASSWORD"],
    "dbname": os.environ.get("SUPABASE_DB_NAME", "postgres"),
    "sslmode": os.environ.get("SUPABASE_DB_SSLMODE", "require"),
}

R = []
USER_IDS = []
COMPANY_IDS = []
EMP_IDS = []
ROOM_IDS = []
SENSITIVE_KEYS = {"access_token", "refresh_token"}


class FatalError(RuntimeError):
    pass


def sanitize(value):
    if isinstance(value, dict):
        return {key: ("[redacted]" if key in SENSITIVE_KEYS else sanitize(item)) for key, item in value.items()}
    if isinstance(value, list):
        return [sanitize(item) for item in value]
    return value


def compact(value, limit=600):
    text = value if isinstance(value, str) else json.dumps(value, default=str)
    return text if len(text) <= limit else text[:limit] + "...<truncated>"


def status_details(status, payload, redact=False):
    rendered = sanitize(payload) if redact else payload
    return compact(f"status={status} payload={rendered}")


def rec(name, passed, details=""):
    details = compact(details)
    R.append({"name": name, "ok": bool(passed), "details": details})
    print(f"{'PASS' if passed else 'FAIL'} | {name} | {details}", flush=True)


def need(name, passed, details=""):
    rec(name, passed, details)
    if not passed:
        raise FatalError(f"{name}: {details}")


def req(method, url, headers, body=None):
    data = None if body is None else json.dumps(body).encode("utf-8")
    request = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read().decode("utf-8")
            return response.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="ignore")
        try:
            payload = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            payload = {"raw": raw}
        return exc.code, payload


def hdr(token=None):
    headers = {
        "apikey": PUB,
        "Accept": "application/json",
        "Content-Type": "application/json",
        "x-client-info": "codex-live-validation",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def admin_hdr():
    return {
        "apikey": SRK,
        "Authorization": f"Bearer {SRK}",
        "Accept": "application/json",
        "Content-Type": "application/json",
        "x-client-info": "codex-live-validation",
    }


def signin(email, password):
    status, payload = req("POST", f"{URL}/auth/v1/token?grant_type=password", hdr(), {"email": email, "password": password})
    need(f"sign in {email}", status == 200, status_details(status, payload, redact=True))
    return {"email": email, "token": payload["access_token"], "user_id": payload["user"]["id"]}


def mkuser(email, password, user_type, display_name):
    status, payload = req(
        "POST",
        f"{URL}/auth/v1/admin/users",
        admin_hdr(),
        {
            "email": email,
            "password": password,
            "email_confirm": True,
            "user_metadata": {"user_type": user_type, "display_name": display_name},
        },
    )
    need(f"admin create {email}", status in (200, 201), f"status={status} payload={payload}")
    USER_IDS.append(payload["id"])
    return payload["id"]


def rpc(session, name, params=None):
    return req("POST", f"{URL}/rest/v1/rpc/{name}", hdr(session["token"]), params or {})


def fn(session, name, body):
    return req("POST", f"{URL}/functions/v1/{name}", hdr(session["token"]), body)


def ins(session, table, payload):
    headers = hdr(session["token"])
    headers["Prefer"] = "return=representation"
    return req("POST", f"{URL}/rest/v1/{table}?select=*", headers, payload)


def sel(session, table, query):
    return req("GET", f"{URL}/rest/v1/{table}?{urllib.parse.urlencode(query, doseq=True)}", hdr(session["token"]))


def notes(session):
    status, payload = sel(session, "notifications", {"select": "id,type,title,role_scope,is_read,created_at", "order": "created_at.desc"})
    need(f"load notifications {session['email']}", status == 200, f"status={status} payload={payload}")
    return payload


def find_note(session, note_type=None, title=None, role_scope=None):
    for item in notes(session):
        if note_type is not None and item.get("type") != note_type:
            continue
        if title is not None and title not in item.get("title", ""):
            continue
        if role_scope is not None and item.get("role_scope") != role_scope:
            continue
        return item
    return None


def mk_owner(slug, company_name, org_type):
    email = f"{PREFIX}+{slug}-owner@gmail.com"
    mkuser(email, PW, "company", company_name)
    session = signin(email, PW)
    status, payload = rpc(
        session,
        "complete_company_signup",
        {
            "company_name": company_name,
            "whatsapp_number": "+27110000000",
            "org_type": org_type,
            "ceo_first_name": "Live",
            "ceo_last_name": "Owner",
        },
    )
    need(f"complete company signup {slug}", status == 200, f"status={status} payload={payload}")
    session["company_id"] = payload["id"]
    COMPANY_IDS.append(payload["id"])
    return session


def mk_employee(owner, label, role):
    email = f"{PREFIX}+{label.replace('_', '-')}@gmail.com"
    status, payload = fn(
        owner,
        "company-user-admin",
        {
            "action": "create_employee",
            "email": email,
            "password": PW,
            "first_name": label.split("_")[-1].title(),
            "last_name": "Live",
            "whatsapp_number": "+27110000001",
            "role": role,
        },
    )
    need(f"create managed employee {label}", status == 200 and payload.get("success") is True, f"status={status} payload={payload}")
    employee = payload["employee"]
    EMP_IDS.append(employee["id"])
    session = signin(email, PW)
    session["employee_id"] = employee["id"]
    session["company_id"] = employee["company_id"]
    session["role"] = employee["role"]
    return session


def mk_candidate(label, first_name, last_name):
    email = f"{PREFIX}+{label}@gmail.com"
    mkuser(email, PW, "employee", f"{first_name} {last_name}")
    session = signin(email, PW)
    status, payload = rpc(
        session,
        "complete_employee_signup",
        {
            "first_name": first_name,
            "last_name": last_name,
            "whatsapp_number": "+27110000002",
            "is_south_african_citizen": True,
        },
    )
    need(f"complete employee signup {label}", status == 200, f"status={status} payload={payload}")
    session["employee_id"] = payload["id"]
    EMP_IDS.append(payload["id"])
    return session


def must_insert(session, table, payload, should_pass, label):
    status, data = ins(session, table, payload)
    need(label, (status in (200, 201)) == should_pass, f"status={status} payload={data}")


def cleanup():
    if not (USER_IDS or COMPANY_IDS or EMP_IDS):
        return
    with psycopg.connect(**DB) as conn:
        with conn.cursor() as cur:
            if ROOM_IDS:
                cur.execute("delete from public.chat_messages where chat_room_id = any(%s::uuid[])", (ROOM_IDS,))
                cur.execute("delete from public.chat_rooms where id = any(%s::uuid[])", (ROOM_IDS,))
            if COMPANY_IDS:
                company_text = [str(value) for value in COMPANY_IDS]
                cur.execute("delete from public.broadcast_messages where payload ->> 'company_id' = any(%s::text[])", (company_text,))
                cur.execute("delete from public.gate_checks where company_id = any(%s::uuid[])", (COMPANY_IDS,))
                cur.execute("delete from public.security_incidents where company_id = any(%s::uuid[])", (COMPANY_IDS,))
                cur.execute("delete from public.weighbridge_records where company_id = any(%s::uuid[])", (COMPANY_IDS,))
                cur.execute("delete from public.fleet_vehicles where company_id = any(%s::uuid[])", (COMPANY_IDS,))
                cur.execute("delete from public.notifications where company_id = any(%s::uuid[])", (COMPANY_IDS,))
                cur.execute("delete from public.employee_status_history where company_id = any(%s::uuid[])", (COMPANY_IDS,))
            if EMP_IDS:
                cur.execute("delete from public.notifications where employee_id = any(%s::uuid[])", (EMP_IDS,))
                cur.execute("delete from public.employee_status_history where employee_id = any(%s::uuid[])", (EMP_IDS,))
            if USER_IDS:
                cur.execute(
                    "delete from public.notifications where user_id = any(%s::uuid[]) or actioned_by_id = any(%s::uuid[])",
                    (USER_IDS, USER_IDS),
                )
                cur.execute("delete from public.employees where user_id = any(%s::uuid[])", (USER_IDS,))
                cur.execute("delete from public.companies where user_id = any(%s::uuid[])", (USER_IDS,))
                cur.execute("delete from public.profiles where id = any(%s::uuid[])", (USER_IDS,))
                cur.execute("delete from auth.identities where user_id = any(%s::uuid[])", (USER_IDS,))
                cur.execute("delete from auth.users where id = any(%s::uuid[])", (USER_IDS,))
        conn.commit()


def main():
    owners = {}
    users = {}

    print("Creating company owners...", flush=True)
    owners["mine"] = mk_owner("mine", f"Test Live Mine {PREFIX}", "mineSupplier")
    owners["buyer"] = mk_owner("buyer", f"Test Live Buyer {PREFIX}", "buyer")
    owners["transporter"] = mk_owner("transporter", f"Test Live Transporter {PREFIX}", "transporter")

    print("Creating managed employees...", flush=True)
    users["mine_security"] = mk_employee(owners["mine"], "mine_security", "security")
    users["mine_controller"] = mk_employee(owners["mine"], "mine_controller", "controllerWB")
    users["mine_admin"] = mk_employee(owners["mine"], "mine_admin", "admin")
    users["mine_management"] = mk_employee(owners["mine"], "mine_management", "management")
    users["buyer_admin"] = mk_employee(owners["buyer"], "buyer_admin", "admin")
    users["buyer_management"] = mk_employee(owners["buyer"], "buyer_management", "management")
    users["transporter_driver"] = mk_employee(owners["transporter"], "transporter_driver", "driver")
    users["transporter_admin"] = mk_employee(owners["transporter"], "transporter_admin", "admin")
    users["transporter_management"] = mk_employee(owners["transporter"], "transporter_management", "management")
    rec("mine employee matrix created", True, "security/controller/admin/management")
    rec("buyer employee matrix created", True, "admin/management")
    rec("transporter employee matrix created", True, "driver/admin/management")

    print("Validating company chat contacts RPC...", flush=True)
    status, payload = rpc(users["mine_admin"], "list_company_chat_contacts", {"target_company_id": owners["mine"]["company_id"]})
    need("mine admin list chat contacts", status == 200 and len(payload) >= 4, f"status={status} count={len(payload) if isinstance(payload, list) else payload}")
    status, payload = rpc(owners["buyer"], "list_company_chat_contacts", {"target_company_id": owners["mine"]["company_id"]})
    need("buyer owner cannot read mine contacts", status == 200 and payload == [], f"status={status} payload={payload}")

    print("Validating chat room creation and message flow...", flush=True)
    status, payload = ins(
        users["mine_admin"],
        "chat_rooms",
        {"name": "Mine Admin Security Room", "participant_ids": [users["mine_admin"]["user_id"], users["mine_security"]["user_id"]]},
    )
    need("same-company chat room insert", status == 201 and isinstance(payload, list) and len(payload) == 1, f"status={status} payload={payload}")
    room = payload[0]
    ROOM_IDS.append(room["id"])
    status, payload = ins(
        users["mine_admin"],
        "chat_rooms",
        {"name": "Cross Company Chat Room", "participant_ids": [users["mine_admin"]["user_id"], users["transporter_driver"]["user_id"]]},
    )
    need("cross-company chat room blocked", status >= 400, f"status={status} payload={payload}")
    text = f"Live chat ping {PREFIX}"
    status, payload = ins(
        users["mine_admin"],
        "chat_messages",
        {"chat_room_id": room["id"], "content": text, "sender_id": users["mine_admin"]["user_id"], "sender_name": "Admin Live"},
    )
    need("chat message insert", status == 201 and isinstance(payload, list) and len(payload) == 1, f"status={status} payload={payload}")
    message = payload[0]
    status, payload = sel(users["mine_security"], "chat_messages", {"select": "id,content,is_read", "chat_room_id": f"eq.{room['id']}", "order": "timestamp.asc"})
    need("security reads chat message", status == 200 and any(row["id"] == message["id"] for row in payload), f"status={status} payload={payload}")
    status, payload = rpc(users["mine_security"], "mark_chat_messages_read", {"target_chat_room_id": room["id"], "target_message_id": message["id"]})
    need("mark chat message read", status == 200 and payload == 1, f"status={status} payload={payload}")
    with psycopg.connect(**DB) as conn:
        with conn.cursor() as cur:
            cur.execute("select last_message_content, last_message_sender_id from public.chat_rooms where id=%s", (room["id"],))
            last_content, last_sender = cur.fetchone()
            cur.execute("select is_read from public.chat_messages where id=%s", (message["id"],))
            is_read = cur.fetchone()[0]
    need("chat room trigger updated summary", last_content == text and str(last_sender) == users["mine_admin"]["user_id"], f"last_content={last_content} last_sender={last_sender}")
    need("chat message stored as read", is_read is True, f"is_read={is_read}")

    print("Validating broadcasts...", flush=True)
    mine_title = f"Mine Live Broadcast {PREFIX}"
    status, payload = ins(
        owners["mine"],
        "broadcast_messages",
        {"event": "company_announcement", "payload": {"company_id": owners["mine"]["company_id"], "title": mine_title, "message": "Owner broadcast", "importance": "high"}, "created_by": owners["mine"]["user_id"]},
    )
    need("mine owner broadcast insert", status == 201, f"status={status} payload={payload}")
    status, payload = ins(
        users["mine_admin"],
        "broadcast_messages",
        {"event": "company_announcement", "payload": {"company_id": owners["mine"]["company_id"], "title": f"Mine Admin Broadcast {PREFIX}", "message": "Admin broadcast", "importance": "normal"}, "created_by": users["mine_admin"]["user_id"]},
    )
    need("mine admin broadcast insert", status == 201, f"status={status} payload={payload}")
    status, payload = ins(
        users["mine_security"],
        "broadcast_messages",
        {"event": "company_announcement", "payload": {"company_id": owners["mine"]["company_id"], "title": f"Mine Security Broadcast {PREFIX}", "message": "Security should fail", "importance": "normal"}, "created_by": users["mine_security"]["user_id"]},
    )
    need("mine security broadcast blocked", status >= 400, f"status={status} payload={payload}")
    status, payload = sel(users["mine_controller"], "broadcast_messages", {"select": "id,payload"})
    need("mine controller sees mine broadcasts", status == 200 and any((row.get("payload") or {}).get("title") == mine_title for row in payload), f"status={status} payload_count={len(payload) if isinstance(payload, list) else payload}")
    status, payload = sel(owners["buyer"], "broadcast_messages", {"select": "id,payload"})
    need("buyer owner cannot see mine broadcasts", status == 200 and not any((row.get("payload") or {}).get("title") == mine_title for row in payload), f"status={status} payload_count={len(payload) if isinstance(payload, list) else payload}")
    buyer_title = f"Buyer Live Broadcast {PREFIX}"
    status, payload = ins(
        owners["buyer"],
        "broadcast_messages",
        {"event": "company_announcement", "payload": {"company_id": owners["buyer"]["company_id"], "title": buyer_title, "message": "Buyer owner broadcast", "importance": "high"}, "created_by": owners["buyer"]["user_id"]},
    )
    need("buyer owner broadcast insert", status == 201, f"status={status} payload={payload}")
    status, payload = sel(users["mine_admin"], "broadcast_messages", {"select": "id,payload"})
    need("mine admin cannot see buyer broadcast", status == 200 and not any((row.get("payload") or {}).get("title") == buyer_title for row in payload), f"status={status} payload_count={len(payload) if isinstance(payload, list) else payload}")

    print("Validating operations permissions...", flush=True)
    must_insert(owners["mine"], "weighbridge_records", {"company_id": owners["mine"]["company_id"], "direction": "outbound", "gross_weight": 100, "tare_weight": 20, "net_weight": 80}, True, "mine owner weighbridge allowed")
    must_insert(users["mine_controller"], "weighbridge_records", {"company_id": owners["mine"]["company_id"], "direction": "inbound", "gross_weight": 90, "tare_weight": 15, "net_weight": 75}, True, "mine controller weighbridge allowed")
    must_insert(users["mine_admin"], "weighbridge_records", {"company_id": owners["mine"]["company_id"], "direction": "outbound", "gross_weight": 88, "tare_weight": 12, "net_weight": 76}, True, "mine admin weighbridge allowed")
    must_insert(users["mine_management"], "weighbridge_records", {"company_id": owners["mine"]["company_id"], "direction": "inbound", "gross_weight": 77, "tare_weight": 11, "net_weight": 66}, True, "mine management weighbridge allowed")
    must_insert(users["mine_security"], "weighbridge_records", {"company_id": owners["mine"]["company_id"], "direction": "outbound", "gross_weight": 70, "tare_weight": 10, "net_weight": 60}, False, "mine security weighbridge blocked")
    must_insert(owners["mine"], "security_incidents", {"company_id": owners["mine"]["company_id"], "severity": "high", "title": f"Owner incident {PREFIX}", "description": "owner ok"}, True, "mine owner security incident allowed")
    must_insert(users["mine_security"], "security_incidents", {"company_id": owners["mine"]["company_id"], "severity": "medium", "title": f"Security incident {PREFIX}", "description": "security ok"}, True, "mine security incident allowed")
    must_insert(users["mine_admin"], "security_incidents", {"company_id": owners["mine"]["company_id"], "severity": "medium", "title": f"Admin incident {PREFIX}", "description": "admin ok"}, True, "mine admin security incident allowed")
    must_insert(users["mine_management"], "security_incidents", {"company_id": owners["mine"]["company_id"], "severity": "medium", "title": f"Management incident {PREFIX}", "description": "management ok"}, True, "mine management security incident allowed")
    must_insert(users["mine_controller"], "security_incidents", {"company_id": owners["mine"]["company_id"], "severity": "low", "title": f"Controller incident {PREFIX}", "description": "controller blocked"}, False, "mine controller security incident blocked")
    must_insert(owners["mine"], "gate_checks", {"company_id": owners["mine"]["company_id"], "check_type": "entry", "gate_status": "cleared", "notes": "owner ok"}, True, "mine owner gate check allowed")
    must_insert(users["mine_security"], "gate_checks", {"company_id": owners["mine"]["company_id"], "check_type": "exit", "gate_status": "blocked", "notes": "security ok"}, True, "mine security gate check allowed")
    must_insert(users["mine_admin"], "gate_checks", {"company_id": owners["mine"]["company_id"], "check_type": "entry", "gate_status": "cleared", "notes": "admin ok"}, True, "mine admin gate check allowed")
    must_insert(users["mine_management"], "gate_checks", {"company_id": owners["mine"]["company_id"], "check_type": "exit", "gate_status": "pending", "notes": "management ok"}, True, "mine management gate check allowed")
    must_insert(users["mine_controller"], "gate_checks", {"company_id": owners["mine"]["company_id"], "check_type": "entry", "gate_status": "cleared", "notes": "controller blocked"}, False, "mine controller gate check blocked")

    print("Validating fleet and transporter notifications...", flush=True)
    status, payload = rpc(owners["transporter"], "create_fleet_vehicle", {"target_company_id": owners["transporter"]["company_id"], "vehicle_registration_number": f"LIVE-{str(int(time.time()))[-6:]}"})
    need("transporter owner create fleet vehicle", status == 200, f"status={status} payload={payload}")
    vehicle = payload
    status, payload = rpc(users["transporter_driver"], "create_fleet_vehicle", {"target_company_id": owners["transporter"]["company_id"], "vehicle_registration_number": f"DRV-{str(int(time.time()))[-5:]}"})
    need("transporter driver fleet create blocked", status >= 400, f"status={status} payload={payload}")
    status, payload = rpc(users["transporter_management"], "assign_fleet_driver", {"target_vehicle_id": vehicle["id"], "target_driver_employee_id": users["transporter_driver"]["employee_id"]})
    need("transporter management assign driver", status == 200, f"status={status} payload={payload}")
    status, payload = sel(users["transporter_driver"], "fleet_vehicles", {"select": "id,vehicle_registration_number,assigned_driver_employee_id", "company_id": f"eq.{owners['transporter']['company_id']}"})
    need("transporter driver reads fleet vehicle", status == 200 and any(row["id"] == vehicle["id"] for row in payload), f"status={status} payload={payload}")
    need("owner received fleet driver assigned notification", find_note(owners["transporter"], "fleetDriverAssigned") is not None, "owner notification present")
    need("transporter admin received fleet driver assigned notification", find_note(users["transporter_admin"], "fleetDriverAssigned") is not None, "admin notification present")
    need("transporter management received fleet driver assigned notification", find_note(users["transporter_management"], "fleetDriverAssigned") is not None, "management notification present")
    need("driver received fleet driver assigned notification", find_note(users["transporter_driver"], "fleetDriverAssigned") is not None, "driver notification present")

    print("Validating employee request, approval, and decline notifications...", flush=True)
    users["candidate_accept"] = mk_candidate("candidate-accept", "Accept", "Candidate")
    status, payload = rpc(users["candidate_accept"], "request_company_link", {"target_company_id": owners["mine"]["company_id"]})
    need("candidate request company link", status == 200, f"status={status} payload={payload}")
    need("mine owner got employee request notification", find_note(owners["mine"], "employeeRequest") is not None, "owner notification present")
    need("mine admin got employee request notification", find_note(users["mine_admin"], "employeeRequest") is not None, "admin notification present")
    need("mine management got employee request notification", find_note(users["mine_management"], "employeeRequest") is not None, "management notification present")
    need("candidate got company request sent notification", find_note(users["candidate_accept"], "employeeRequest") is not None, "candidate notification present")
    status, payload = rpc(users["mine_management"], "approve_employee_request", {"target_employee_id": users["candidate_accept"]["employee_id"]})
    need("management approve employee request", status == 200, f"status={status} payload={payload}")
    status, payload = rpc(users["mine_admin"], "assign_employee_role", {"target_employee_id": users["candidate_accept"]["employee_id"], "target_role": "security"})
    need("admin assign employee role", status == 200, f"status={status} payload={payload}")
    need("candidate got role assigned notification", find_note(users["candidate_accept"], "roleAssigned") is not None, "candidate role notification present")
    users["candidate_decline"] = mk_candidate("candidate-decline", "Decline", "Candidate")
    status, payload = rpc(users["candidate_decline"], "request_company_link", {"target_company_id": owners["mine"]["company_id"]})
    need("decline candidate request company link", status == 200, f"status={status} payload={payload}")
    status, payload = rpc(users["mine_admin"], "decline_employee_request", {"target_employee_id": users["candidate_decline"]["employee_id"]})
    need("admin decline employee request", status == 200, f"status={status} payload={payload}")
    need("candidate got request declined notification", find_note(users["candidate_decline"], "requestDeclined") is not None, "decline notification present")

    print("Validating dismissal workflow and notifications...", flush=True)
    status, payload = rpc(users["mine_management"], "initiate_employee_dismissal", {"target_employee_id": users["candidate_accept"]["employee_id"], "dismissal_reason_input": "Live validation dismissal check"})
    need("management initiate dismissal", status == 200, f"status={status} payload={payload}")
    need("dismissed employee got dismissal initiated notification", find_note(users["candidate_accept"], "dismissalInitiated") is not None, "dismissal notification present")
    status, payload = rpc(users["candidate_accept"], "submit_employee_dismissal_appeal", {"appeal_reason_input": "Live validation appeal"})
    need("employee submit dismissal appeal", status == 200, f"status={status} payload={payload}")
    need("owner got dismissal appeal notification", find_note(owners["mine"], "dismissalAppeal") is not None, "owner appeal notification present")
    need("admin got dismissal appeal notification", find_note(users["mine_admin"], "dismissalAppeal") is not None, "admin appeal notification present")
    need("management got dismissal appeal notification", find_note(users["mine_management"], "dismissalAppeal") is not None, "management appeal notification present")
    status, payload = rpc(owners["mine"], "resolve_employee_dismissal", {"target_employee_id": users["candidate_accept"]["employee_id"], "uphold_dismissal": False, "decision_reason_input": "Live validation reversal"})
    need("owner resolve dismissal", status == 200, f"status={status} payload={payload}")
    need("employee got dismissal final notification", find_note(users["candidate_accept"], "dismissalFinal") is not None, "dismissal final notification present")

    print("Validating role-scoped notifications and read APIs...", flush=True)
    status, payload = rpc(users["mine_management"], "create_actioned_notification", {"target_user_id": users["mine_security"]["user_id"], "notification_title": f"Security Live Alert {PREFIX}", "notification_message": "Security notification check", "notification_type": "securityAlert", "target_company_id": owners["mine"]["company_id"], "target_employee_id": users["mine_security"]["employee_id"], "notification_actioned_by": "Mine Management", "notification_actioned_by_id": users["mine_management"]["user_id"], "notification_role_scope": "security", "notification_org_type": "mineSupplier", "notification_importance": "high", "notification_metadata": {"prefix": PREFIX}})
    need("management create security notification", status == 200, f"status={status} payload={payload}")
    security_note = payload
    status, payload = rpc(users["mine_management"], "create_actioned_notification", {"target_user_id": users["mine_controller"]["user_id"], "notification_title": f"Controller Live Action {PREFIX}", "notification_message": "Controller notification check", "notification_type": "controllerAction", "target_company_id": owners["mine"]["company_id"], "target_employee_id": users["mine_controller"]["employee_id"], "notification_actioned_by": "Mine Management", "notification_actioned_by_id": users["mine_management"]["user_id"], "notification_role_scope": "controllerWB", "notification_org_type": "mineSupplier", "notification_importance": "high", "notification_metadata": {"prefix": PREFIX}})
    need("management create controller notification", status == 200, f"status={status} payload={payload}")
    status, payload = rpc(owners["mine"], "create_actioned_notification", {"target_user_id": users["mine_management"]["user_id"], "notification_title": f"Management Live Action {PREFIX}", "notification_message": "Management notification check", "notification_type": "managementAction", "target_company_id": owners["mine"]["company_id"], "target_employee_id": users["mine_management"]["employee_id"], "notification_actioned_by": "Mine Owner", "notification_actioned_by_id": owners["mine"]["user_id"], "notification_role_scope": "management", "notification_org_type": "mineSupplier", "notification_importance": "normal", "notification_metadata": {"prefix": PREFIX}})
    need("owner create management notification", status == 200, f"status={status} payload={payload}")
    need("security received securityAlert", find_note(users["mine_security"], "securityAlert", role_scope="security") is not None, "security notification present")
    need("controller received controllerAction", find_note(users["mine_controller"], "controllerAction", role_scope="controllerWB") is not None, "controller notification present")
    need("management received managementAction", find_note(users["mine_management"], "managementAction", role_scope="management") is not None, "management notification present")
    status, payload = rpc(users["mine_security"], "set_notification_read", {"target_notification_id": security_note["id"], "read_state": True})
    need("security mark notification read", status == 200 and payload.get("is_read") is True, f"status={status} payload={payload}")
    status, payload = rpc(users["transporter_driver"], "mark_all_notifications_read", {})
    need("driver mark all notifications read", status == 200 and isinstance(payload, int) and payload >= 1, f"status={status} payload={payload}")

    passed = sum(1 for item in R if item["ok"])
    failed = sum(1 for item in R if not item["ok"])
    print("SUMMARY_JSON=" + json.dumps({"prefix": PREFIX, "passed": passed, "failed": failed, "results": R}), flush=True)


if __name__ == "__main__":
    try:
        main()
    except FatalError as exc:
        print(f"VALIDATION_FAILED={exc}", flush=True)
        sys.exit(1)
    finally:
        cleanup()
        print("CLEANUP_DONE", flush=True)
