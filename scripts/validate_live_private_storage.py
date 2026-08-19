import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import psycopg


PROJECT_URL = os.environ.get(
    "SUPABASE_URL",
    "https://yftazblpmicqtamyiwyb.supabase.co",
).rstrip("/")
STORAGE_BASE_URL = f"{PROJECT_URL}/storage/v1"
PUBLISHABLE_KEY = os.environ["SUPABASE_PUBLISHABLE_KEY"]
SERVICE_ROLE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
PASSWORD = os.environ["SUPABASE_DB_PASSWORD"]
# Required, not defaulted. Every other secret here already comes from the
# environment; this one carried the shared live test password as a literal
# default, which put a working production credential in the repo (S9-8).
USER_PASSWORD = os.environ["LIVE_VALIDATION_PASSWORD"]
PREFIX = os.environ.get(
    "LIVE_STORAGE_PREFIX",
    f"codex.storage.{int(time.time())}",
)
DB = {
    "host": os.environ.get(
        "SUPABASE_DB_HOST",
        "aws-1-eu-west-1.pooler.supabase.com",
    ),
    "port": int(os.environ.get("SUPABASE_DB_PORT", "6543")),
    "user": os.environ.get(
        "SUPABASE_DB_USER",
        "postgres.yftazblpmicqtamyiwyb",
    ),
    "password": PASSWORD,
    "dbname": os.environ.get("SUPABASE_DB_NAME", "postgres"),
    "sslmode": os.environ.get("SUPABASE_DB_SSLMODE", "require"),
}

RESULTS = []
USER_IDS = []
COMPANY_IDS = []
EMPLOYEE_IDS = []
ROOM_IDS = []
VEHICLE_IDS = []
STORAGE_OBJECTS = []
SENSITIVE_KEYS = {"access_token", "refresh_token"}


class FatalError(RuntimeError):
    pass


def sanitize(value):
    if isinstance(value, dict):
        return {
            key: ("[redacted]" if key in SENSITIVE_KEYS else sanitize(item))
            for key, item in value.items()
        }
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
    RESULTS.append({"name": name, "ok": bool(passed), "details": details})
    print(f"{'PASS' if passed else 'FAIL'} | {name} | {details}", flush=True)


def need(name, passed, details=""):
    rec(name, passed, details)
    if not passed:
        raise FatalError(f"{name}: {details}")


def req_json(method, url, headers, body=None):
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


def req_raw(method, url, headers, body=None):
    request = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


def headers(token=None, content_type="application/json"):
    request_headers = {
        "apikey": PUBLISHABLE_KEY,
        "Accept": "application/json",
        "x-client-info": "codex-live-storage-validation",
    }
    if content_type:
        request_headers["Content-Type"] = content_type
    if token:
        request_headers["Authorization"] = f"Bearer {token}"
    return request_headers


def admin_headers():
    return {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Accept": "application/json",
        "Content-Type": "application/json",
        "x-client-info": "codex-live-storage-validation",
    }


def signin(email, password):
    status, payload = req_json(
        "POST",
        f"{PROJECT_URL}/auth/v1/token?grant_type=password",
        headers(),
        {"email": email, "password": password},
    )
    need(f"sign in {email}", status == 200, status_details(status, payload, redact=True))
    return {"email": email, "token": payload["access_token"], "user_id": payload["user"]["id"]}


def mkuser(email, password, user_type, display_name):
    status, payload = req_json(
        "POST",
        f"{PROJECT_URL}/auth/v1/admin/users",
        admin_headers(),
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
    return req_json(
        "POST",
        f"{PROJECT_URL}/rest/v1/rpc/{name}",
        headers(session["token"]),
        params or {},
    )


def fn(session, name, body):
    return req_json(
        "POST",
        f"{PROJECT_URL}/functions/v1/{name}",
        headers(session["token"]),
        body,
    )


def ins(session, table, payload):
    request_headers = headers(session["token"])
    request_headers["Prefer"] = "return=representation"
    return req_json(
        "POST",
        f"{PROJECT_URL}/rest/v1/{table}?select=*",
        request_headers,
        payload,
    )


def sel(session, table, query):
    return req_json(
        "GET",
        f"{PROJECT_URL}/rest/v1/{table}?{urllib.parse.urlencode(query, doseq=True)}",
        headers(session["token"]),
    )


def storage_upload(session, bucket, object_path, content, content_type):
    encoded_path = urllib.parse.quote(object_path, safe="/")
    request_headers = headers(session["token"], content_type=content_type)
    request_headers["x-upsert"] = "true"
    status, payload = req_raw(
        "POST",
        f"{STORAGE_BASE_URL}/object/{bucket}/{encoded_path}",
        request_headers,
        body=content,
    )
    if payload:
        try:
            parsed = json.loads(payload.decode("utf-8"))
        except Exception:
            parsed = payload.decode("utf-8", errors="ignore")
    else:
        parsed = None
    return status, parsed


def create_signed_url(session, bucket, object_path, expires_in=60):
    encoded_path = urllib.parse.quote(object_path, safe="/")
    status, payload = req_json(
        "POST",
        f"{STORAGE_BASE_URL}/object/sign/{bucket}/{encoded_path}",
        headers(session["token"]),
        {"expiresIn": expires_in},
    )
    signed_url = None
    if isinstance(payload, dict) and payload.get("signedURL"):
        signed_url = payload["signedURL"]
        if signed_url.startswith("/"):
            signed_url = f"{STORAGE_BASE_URL}{signed_url}"
        elif not signed_url.startswith("http"):
            signed_url = f"{STORAGE_BASE_URL}/{signed_url.lstrip('/')}"
    return status, payload, signed_url


def fetch_url(url, token=None):
    request_headers = {"Accept": "*/*", "x-client-info": "codex-live-storage-validation"}
    if token:
        request_headers["Authorization"] = f"Bearer {token}"
        request_headers["apikey"] = PUBLISHABLE_KEY
    return req_raw("GET", url, request_headers)


def mk_owner(slug, company_name, org_type):
    email = f"{PREFIX}+{slug}-owner@gmail.com"
    mkuser(email, USER_PASSWORD, "company", company_name)
    session = signin(email, USER_PASSWORD)
    status, payload = rpc(
        session,
        "complete_company_signup",
        {
            "company_name": company_name,
            "whatsapp_number": "+27110000000",
            "org_type": org_type,
            "ceo_first_name": "Storage",
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
            "password": USER_PASSWORD,
            "first_name": label.split("_")[-1].title(),
            "last_name": "Storage",
            "whatsapp_number": "+27110000001",
            "role": role,
        },
    )
    need(
        f"create managed employee {label}",
        status == 200 and payload.get("success") is True,
        f"status={status} payload={payload}",
    )
    employee = payload["employee"]
    EMPLOYEE_IDS.append(employee["id"])
    USER_IDS.append(employee["user_id"])
    session = signin(email, USER_PASSWORD)
    session["employee_id"] = employee["id"]
    session["company_id"] = employee["company_id"]
    session["role"] = employee["role"]
    return session


def public_object_url(bucket, object_path):
    encoded_path = urllib.parse.quote(object_path, safe="/")
    return f"{STORAGE_BASE_URL}/object/public/{bucket}/{encoded_path}"


def cleanup():
    grouped_storage_paths = {}
    for bucket_name, object_path in STORAGE_OBJECTS:
        grouped_storage_paths.setdefault(bucket_name, []).append(object_path)

    for bucket_name, object_paths in grouped_storage_paths.items():
        status, payload = req_json(
            "DELETE",
            f"{STORAGE_BASE_URL}/object/{bucket_name}",
            admin_headers(),
            {"prefixes": object_paths},
        )
        if status not in (200, 204):
            print(
                f"CLEANUP_WARNING storage {bucket_name}: {status_details(status, payload)}",
                flush=True,
            )

    try:
        with psycopg.connect(**DB) as conn:
            with conn.cursor() as cur:
                if ROOM_IDS:
                    cur.execute(
                        "delete from public.chat_messages where chat_room_id = any(%s::uuid[])",
                        (ROOM_IDS,),
                    )
                    cur.execute(
                        "delete from public.chat_rooms where id = any(%s::uuid[])",
                        (ROOM_IDS,),
                    )
                if VEHICLE_IDS:
                    cur.execute(
                        "delete from public.fleet_vehicles where id = any(%s::uuid[])",
                        (VEHICLE_IDS,),
                    )
                if COMPANY_IDS:
                    cur.execute(
                        "delete from public.broadcast_messages where payload ->> 'company_id' = any(%s::text[])",
                        ([str(value) for value in COMPANY_IDS],),
                    )
                    cur.execute(
                        "delete from public.notifications where company_id = any(%s::uuid[])",
                        (COMPANY_IDS,),
                    )
                    cur.execute(
                        "delete from public.employee_status_history where company_id = any(%s::uuid[])",
                        (COMPANY_IDS,),
                    )
                if EMPLOYEE_IDS:
                    cur.execute(
                        "delete from public.notifications where employee_id = any(%s::uuid[])",
                        (EMPLOYEE_IDS,),
                    )
                    cur.execute(
                        "delete from public.employee_status_history where employee_id = any(%s::uuid[])",
                        (EMPLOYEE_IDS,),
                    )
                if USER_IDS:
                    cur.execute(
                        "delete from public.notifications where user_id = any(%s::uuid[]) or actioned_by_id = any(%s::uuid[])",
                        (USER_IDS, USER_IDS),
                    )
                    cur.execute(
                        "delete from public.employees where user_id = any(%s::uuid[])",
                        (USER_IDS,),
                    )
                    cur.execute(
                        "delete from public.companies where user_id = any(%s::uuid[])",
                        (USER_IDS,),
                    )
                    cur.execute(
                        "delete from public.profiles where id = any(%s::uuid[])",
                        (USER_IDS,),
                    )
                    cur.execute(
                        "delete from auth.identities where user_id = any(%s::uuid[])",
                        (USER_IDS,),
                    )
                    cur.execute(
                        "delete from auth.users where id = any(%s::uuid[])",
                        (USER_IDS,),
                    )
            conn.commit()
    except Exception as exc:
        print(f"CLEANUP_WARNING database cleanup failed: {exc}", flush=True)


def main():
    print("Creating live validation users...", flush=True)
    mine_owner = mk_owner("mine-storage", f"Test Storage Mine {PREFIX}", "mineSupplier")
    transporter_owner = mk_owner(
        "transporter-storage",
        f"Test Storage Transporter {PREFIX}",
        "transporter",
    )

    mine_security = mk_employee(mine_owner, "mine_security_storage", "security")
    mine_controller = mk_employee(mine_owner, "mine_controller_storage", "controllerWB")
    mine_admin = mk_employee(mine_owner, "mine_admin_storage", "admin")
    transporter_driver = mk_employee(transporter_owner, "transporter_driver_storage", "driver")
    transporter_management = mk_employee(
        transporter_owner,
        "transporter_management_storage",
        "management",
    )

    print("Validating employee asset storage...", flush=True)
    profile_path = f"profile_photos/{mine_security['employee_id']}/photo.png"
    id_doc_path = f"id_documents/{mine_security['employee_id']}/id_document.pdf"
    driver_license_path = (
        f"license_documents/{transporter_driver['employee_id']}/license.pdf"
    )

    status, payload = storage_upload(
        mine_security,
        "employee_assets",
        profile_path,
        b"employee-profile-photo",
        "image/png",
    )
    need("security uploads own profile photo", status in (200, 201), status_details(status, payload))
    STORAGE_OBJECTS.append(("employee_assets", profile_path))

    status, payload = storage_upload(
        mine_security,
        "employee_assets",
        id_doc_path,
        b"%PDF-1.4 employee-id-document",
        "application/pdf",
    )
    need("security uploads own id document", status in (200, 201), status_details(status, payload))
    STORAGE_OBJECTS.append(("employee_assets", id_doc_path))

    status, payload = rpc(
        mine_security,
        "update_my_employee_profile",
        {
            "profile_photo_url_input": profile_path,
            "id_document_url_input": id_doc_path,
        },
    )
    need(
        "security profile stores raw employee asset paths",
        status == 200
        and payload.get("profile_photo_url") == profile_path
        and payload.get("id_document_url") == id_doc_path,
        status_details(status, payload),
    )

    status, payload, signed_url = create_signed_url(
        mine_security,
        "employee_assets",
        profile_path,
    )
    need("security signs own profile photo", status == 200 and signed_url is not None, status_details(status, payload))
    status, payload = fetch_url(signed_url)
    need("security signed profile photo downloads", status == 200, f"status={status} bytes={len(payload)}")

    status, payload, signed_url = create_signed_url(
        mine_controller,
        "employee_assets",
        profile_path,
    )
    need("controller signs same-company profile photo", status == 200 and signed_url is not None, status_details(status, payload))

    status, payload, signed_url = create_signed_url(
        mine_controller,
        "employee_assets",
        id_doc_path,
    )
    need("controller blocked from same-company id document", status >= 400, status_details(status, payload))

    status, payload, signed_url = create_signed_url(
        mine_admin,
        "employee_assets",
        id_doc_path,
    )
    need("admin signs same-company id document", status == 200 and signed_url is not None, status_details(status, payload))

    status, payload, signed_url = create_signed_url(
        transporter_owner,
        "employee_assets",
        profile_path,
    )
    need("cross-company owner blocked from employee profile photo", status >= 400, status_details(status, payload))

    status, payload = fetch_url(public_object_url("employee_assets", profile_path))
    need("employee asset public URL blocked", status >= 400, f"status={status}")

    print("Validating transporter document access and fleet copy...", flush=True)
    status, payload = storage_upload(
        transporter_driver,
        "employee_assets",
        driver_license_path,
        b"%PDF-1.4 transporter-license",
        "application/pdf",
    )
    need("driver uploads own license document", status in (200, 201), status_details(status, payload))
    STORAGE_OBJECTS.append(("employee_assets", driver_license_path))

    status, payload = rpc(
        transporter_driver,
        "update_my_employee_profile",
        {"license_document_url_input": driver_license_path},
    )
    need(
        "driver profile stores raw license path",
        status == 200 and payload.get("license_document_url") == driver_license_path,
        status_details(status, payload),
    )

    vehicle_reg = f"STO-{str(int(time.time()))[-6:]}"
    status, payload = rpc(
        transporter_owner,
        "create_fleet_vehicle",
        {
            "target_company_id": transporter_owner["company_id"],
            "vehicle_registration_number": vehicle_reg,
        },
    )
    need("transporter owner creates fleet vehicle", status == 200, status_details(status, payload))
    vehicle = payload
    VEHICLE_IDS.append(vehicle["id"])

    status, payload = rpc(
        transporter_management,
        "assign_fleet_driver",
        {
            "target_vehicle_id": vehicle["id"],
            "target_driver_employee_id": transporter_driver["employee_id"],
        },
    )
    need("transporter management assigns driver", status == 200, status_details(status, payload))
    need(
        "fleet driver license path copied as raw path",
        payload.get("driver_license_document_url") == driver_license_path,
        status_details(status, payload),
    )

    status, payload, signed_url = create_signed_url(
        transporter_management,
        "employee_assets",
        driver_license_path,
    )
    need("transporter management signs driver license", status == 200 and signed_url is not None, status_details(status, payload))

    status, payload, signed_url = create_signed_url(
        mine_admin,
        "employee_assets",
        driver_license_path,
    )
    need("cross-company admin blocked from driver license", status >= 400, status_details(status, payload))

    print("Validating chat file storage...", flush=True)
    status, payload = ins(
        mine_admin,
        "chat_rooms",
        {
            "name": f"Storage Room {PREFIX}",
            "participant_ids": [mine_admin["user_id"], mine_security["user_id"]],
        },
    )
    need(
        "same-company chat room insert for storage validation",
        status == 201 and isinstance(payload, list) and len(payload) == 1,
        status_details(status, payload),
    )
    room = payload[0]
    ROOM_IDS.append(room["id"])

    chat_path = f"{room['id']}/chat_attachment.png"
    status, payload = storage_upload(
        mine_admin,
        "chat_files",
        chat_path,
        b"chat-attachment",
        "image/png",
    )
    need("chat participant uploads room attachment", status in (200, 201), status_details(status, payload))
    STORAGE_OBJECTS.append(("chat_files", chat_path))

    status, payload = ins(
        mine_admin,
        "chat_messages",
        {
            "chat_room_id": room["id"],
            "content": "Storage attachment",
            "sender_id": mine_admin["user_id"],
            "sender_name": "Mine Admin",
            "file_url": chat_path,
            "file_type": "image/png",
            "file_name": "chat_attachment.png",
        },
    )
    need(
        "chat message stores raw attachment path",
        status == 201
        and isinstance(payload, list)
        and len(payload) == 1
        and payload[0].get("file_url") == chat_path,
        status_details(status, payload),
    )

    status, payload, signed_url = create_signed_url(
        mine_security,
        "chat_files",
        chat_path,
    )
    need("room participant signs chat attachment", status == 200 and signed_url is not None, status_details(status, payload))

    status, payload, signed_url = create_signed_url(
        transporter_owner,
        "chat_files",
        chat_path,
    )
    need("outsider blocked from chat attachment", status >= 400, status_details(status, payload))

    status, payload = fetch_url(public_object_url("chat_files", chat_path))
    need("chat file public URL blocked", status >= 400, f"status={status}")

    passed = sum(1 for item in RESULTS if item["ok"])
    failed = sum(1 for item in RESULTS if not item["ok"])
    print(
        "SUMMARY_JSON=" + json.dumps(
            {"prefix": PREFIX, "passed": passed, "failed": failed, "results": RESULTS}
        ),
        flush=True,
    )


if __name__ == "__main__":
    try:
        main()
    except FatalError as exc:
        print(f"VALIDATION_FAILED={exc}", flush=True)
        sys.exit(1)
    finally:
        cleanup()
        print("CLEANUP_DONE", flush=True)
