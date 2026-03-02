#!/usr/bin/env python3
"""LinkedIn daily-post agent (API-first).

- Objetivo: garantir pelo menos 1 post diário para o perfil pessoal do admin e para a Company Page (rpa4all).
- Estratégia: usar LinkedIn REST API (/v2/ugcPosts and /v2/shares) quando possível; reportar permissões faltantes.
- Entrada/ambiente:
  - LINKEDIN_ACCESS_TOKEN (recomendado)
  - LINKEDIN_ORG_ID or LINKEDIN_ORG_VANITY (opcional; para postar como organização)
  - POST_PERSONAL_MESSAGE, POST_ORG_MESSAGE (opcionais)
  - FORCE_POST=1 (ignora verificação de último post)

Uso:
  LINKEDIN_ACCESS_TOKEN="..." python3 tests/linkedin/daily_post_agent.py --check-only

Observação: editar metadados da Page (About/Vanity/name) não é suportado pela API pública — este agente só posta conteúdo.
"""
import argparse
import datetime
import os
import sys
import time
import json
from typing import Optional

import requests

API_BASE = "https://api.linkedin.com"

# default messages
DEFAULT_PERSONAL = "Atualização diária — verificando presença e novidades. #estouaqui #rpa4all"
DEFAULT_ORG = (
    "RPA4All — soluções de automação e observabilidade. Acompanhe novidades e cases: https://www.rpa4all.com"
)


class LinkedInAgentError(Exception):
    pass


def auth_headers(token: str):
    return {
        "Authorization": f"Bearer {token}",
        "X-Restli-Protocol-Version": "2.0.0",
        "Content-Type": "application/json",
    }


def get_member_urn(token: str) -> str:
    r = requests.get(f"{API_BASE}/v2/me", headers=auth_headers(token))
    if r.status_code != 200:
        raise LinkedInAgentError(f"Failed to fetch /me: {r.status_code} {r.text}")
    body = r.json()
    # expected format: {"id":"...","localizedFirstName":...}
    member_id = body.get("id")
    if not member_id:
        raise LinkedInAgentError("/me response missing id")
    return f"urn:li:person:{member_id}"


def org_urn_from_vanity(token: str, vanity: str) -> Optional[str]:
    # GET /v2/organizations?q=vanityName&vanityName={vanity}
    params = {"q": "vanityName", "vanityName": vanity}
    r = requests.get(f"{API_BASE}/v2/organizations", headers=auth_headers(token), params=params)
    if r.status_code != 200:
        return None
    data = r.json()
    elements = data.get("elements") or []
    if not elements:
        return None
    org_urn = elements[0].get("organizationalTargetUrn") or elements[0].get("id")
    # sometimes API returns id instead of full urn; normalize
    if org_urn and isinstance(org_urn, str) and org_urn.startswith("urn:li:organization:"):
        return org_urn
    if elements[0].get("id"):
        return f"urn:li:organization:{elements[0]['id']}"
    return None


def check_admin_for_org(token: str, member_urn: str, org_urn: str) -> bool:
    # GET /v2/organizationalEntityAcls?q=roleAssignee&role=ADMINISTRATOR&roleAssignee={memberUrn}
    params = {
        "q": "roleAssignee",
        "role": "ADMINISTRATOR",
        "roleAssignee": member_urn,
        # additional filter by organizationalTarget when supported
    }
    r = requests.get(f"{API_BASE}/v2/organizationalEntityAcls", headers=auth_headers(token), params=params)
    if r.status_code != 200:
        return False
    data = r.json()
    for el in data.get("elements", []) or []:
        if el.get("organizationalTarget") == org_urn or (org_urn in json.dumps(el)):
            return True
    return False


def get_last_share_time(token: str, owner_urn: str) -> Optional[datetime.datetime]:
    # Try shares endpoint first
    # GET /v2/shares?q=owners&owners={owner_urn}&count=5
    params = {"q": "owners", "owners": owner_urn, "count": 5}
    r = requests.get(f"{API_BASE}/v2/shares", headers=auth_headers(token), params=params)
    if r.status_code == 200:
        try:
            data = r.json()
            elems = data.get("elements") or []
            if elems:
                # elements[0] likely most recent
                for e in elems:
                    # try multiple timestamp keys
                    ts = None
                    if isinstance(e.get("created"), dict):
                        ts = e["created"].get("time")
                    if not ts:
                        ts = e.get("createdAt") or e.get("lastModified")
                    if ts:
                        return datetime.datetime.utcfromtimestamp(int(ts) / 1000)
        except Exception:
            pass
    # fallback: try ugcPosts
    params = {"q": "authors", "authors": owner_urn, "count": 5}
    r2 = requests.get(f"{API_BASE}/v2/ugcPosts", headers=auth_headers(token), params=params)
    if r2.status_code == 200:
        try:
            data = r2.json()
            elems = data.get("elements") or []
            if elems:
                for e in elems:
                    ts = e.get("created") or e.get("createdAt")
                    if isinstance(ts, dict):
                        tval = ts.get("time")
                        if tval:
                            return datetime.datetime.utcfromtimestamp(int(tval) / 1000)
                    if isinstance(ts, (int, float)):
                        return datetime.datetime.utcfromtimestamp(int(ts) / 1000)
        except Exception:
            pass
    return None


def post_ugc(token: str, author_urn: str, text: str) -> dict:
    body = {
        "author": author_urn,
        "lifecycleState": "PUBLISHED",
        "specificContent": {
            "com.linkedin.ugc.ShareContent": {
                "shareCommentary": {"text": text},
                "shareMediaCategory": "NONE",
            }
        },
        "visibility": {"com.linkedin.ugc.MemberNetworkVisibility": "PUBLIC"},
    }
    r = requests.post(f"{API_BASE}/v2/ugcPosts", headers=auth_headers(token), json=body)
    try:
        return {"status_code": r.status_code, "body": r.json()}
    except Exception:
        return {"status_code": r.status_code, "text": r.text}


def ensure_post_today(token: str, owner_urn: str, message: str, force: bool = False) -> dict:
    now_utc = datetime.datetime.utcnow()
    last = get_last_share_time(token, owner_urn)
    result = {"owner": owner_urn, "last_share": last.isoformat() if last else None, "posted": False, "reason": None}
    if not force and last:
        # consider "today" in UTC
        if last.date() == now_utc.date():
            result["reason"] = "already_posted_today"
            return result
    # attempt to post
    res = post_ugc(token, owner_urn, message)
    if res.get("status_code") in (201, 200):
        result["posted"] = True
        result["reason"] = "posted_via_api"
    else:
        result["reason"] = f"post_failed_api_{res.get('status_code')}"
        result["api_response"] = res
    return result


def main(argv=None):
    p = argparse.ArgumentParser(description="LinkedIn daily post agent (API-first)")
    p.add_argument("--org-vanity", help="organization vanity (ex: rpa4all)")
    p.add_argument("--org-id", help="organization numeric id (ex: 37873425)")
    p.add_argument("--token", help="LinkedIn access token (env LINKEDIN_ACCESS_TOKEN if omitted)")
    p.add_argument("--force", action="store_true", help="Force a post regardless last-post timestamp")
    p.add_argument("--check-only", action="store_true", help="Only check status; do not post")
    p.add_argument("--post-personal-message", help="Message to post for personal account")
    p.add_argument("--post-org-message", help="Message to post for organization")
    args = p.parse_args(argv)

    token = args.token or os.environ.get("LINKEDIN_ACCESS_TOKEN")
    if not token:
        print("Missing LINKEDIN_ACCESS_TOKEN (env or --token). Exiting.")
        return 2

    personal_msg = args.post_personal_message or os.environ.get("POST_PERSONAL_MESSAGE") or DEFAULT_PERSONAL
    org_msg = args.post_org_message or os.environ.get("POST_ORG_MESSAGE") or DEFAULT_ORG
    force = args.force or os.environ.get("FORCE_POST") == "1"

    summary = {"personal": None, "organization": None}

    try:
        member_urn = get_member_urn(token)
        print(f"Detected member urn: {member_urn}")
    except Exception as e:
        print("Failed to determine member urn:", e)
        return 3

    # PERSONAL: check & optionally post
    if args.check_only:
        last_personal = get_last_share_time(token, member_urn)
        print("Personal last share ->", last_personal)
        summary["personal"] = {"last_share": last_personal.isoformat() if last_personal else None}
    else:
        try:
            summary["personal"] = ensure_post_today(token, member_urn, personal_msg, force=force)
            print("Personal ->", summary["personal"])
        except Exception as e:
            summary["personal"] = {"error": str(e)}

    # ORGANIZATION (if requested via env/arg)
    org_urn = None
    if args.org_id:
        org_urn = f"urn:li:organization:{args.org_id}"
    elif args.org_vanity:
        org_urn = org_urn_from_vanity(token, args.org_vanity)
    else:
        env_org_id = os.environ.get("LINKEDIN_ORG_ID")
        env_org_vanity = os.environ.get("LINKEDIN_ORG_VANITY")
        if env_org_id:
            org_urn = f"urn:li:organization:{env_org_id}"
        elif env_org_vanity:
            org_urn = org_urn_from_vanity(token, env_org_vanity)

    if org_urn:
        # check admin privilege
        admin_ok = check_admin_for_org(token, member_urn, org_urn)
        print(f"Organization urn: {org_urn} — admin? {admin_ok}")
        if not admin_ok:
            summary["organization"] = {"error": "member-not-admin-or-missing-scope"}
        else:
            if args.check_only:
                last_org = get_last_share_time(token, org_urn)
                summary["organization"] = {"last_share": last_org.isoformat() if last_org else None}
            else:
                try:
                    summary["organization"] = ensure_post_today(token, org_urn, org_msg, force=force)
                except Exception as e:
                    summary["organization"] = {"error": str(e)}
    else:
        print("No organization configured (set --org-id / --org-vanity or env LINKEDIN_ORG_ID / LINKEDIN_ORG_VANITY)")

    print("--- summary ---")
    print(json.dumps(summary, indent=2, ensure_ascii=False, default=str))

    # exit code 0 if at least one target either already had a post today or we posted
    ok_personal = summary.get("personal") and (summary["personal"].get("posted") or summary["personal"].get("last_share"))
    ok_org = summary.get("organization") and (summary["organization"].get("posted") or summary["organization"].get("last_share"))
    if ok_personal or ok_org:
        return 0
    return 4


if __name__ == "__main__":
    sys.exit(main())
