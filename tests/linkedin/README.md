LinkedIn daily post agent

Usage (local):

  LINKEDIN_ACCESS_TOKEN="<token>" \ 
    LINKEDIN_ORG_ID="37873425" \
    python3 tests/linkedin/daily_post_agent.py

Options:
- --org-id / --org-vanity: post on behalf of organization (requires admin & w_organization_social scope).
- --check-only: only inspect last post timestamps (no post performed).
- FORCE_POST=1: force posting regardless of last-post date.

Notes:
- Posting as user requires w_member_social; posting as organization requires w_organization_social and that the token owner is admin of the org.
- Editing Page metadata (About/Vanity/name) is not supported via the public API; use Selenium + human verification for that.
