"""Make the first Magana team owner. Run on the server, once (never through the web):

    sudo docker compose -f docker-compose.prod.yml exec magana \\
        python -m app.team_setup --email you@example.com --name "Your Name"

It refuses if an owner already exists: from then on, owners add team members in the portal
(Magana team). The new owner signs in at teachers.magana.ng with that email; the first sign-in
sets up the authenticator app and shows the backup codes once.

Development only (MAGANA_ENV=development): --role and --totp-secret make test accounts whose
authenticator is already set up, for the portal's end-to-end tests.
"""
from __future__ import annotations

import argparse
import os
import sys

from . import accounts as A
from . import portal_api, team


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="python -m app.team_setup", description="Make the first Magana team owner.")
    p.add_argument("--email", required=True)
    p.add_argument("--name", required=True)
    p.add_argument("--role", default="owner", choices=team.ROLES, help=argparse.SUPPRESS)
    p.add_argument("--totp-secret", default=None, help=argparse.SUPPRESS)
    a = p.parse_args(argv)
    dev = os.environ.get("MAGANA_ENV") == "development"
    if (a.role != "owner" or a.totp_secret) and not dev:
        print("--role and --totp-secret are for development only.", file=sys.stderr)
        return 2
    email = a.email.strip().lower()
    if not portal_api.EMAIL.match(email):
        print("That doesn't look like an email address.", file=sys.stderr)
        return 2
    with A.db() as con:
        if not dev and team.active_owners(con) > 0:
            print("A Magana team owner already exists. Owners add team members in the portal: Magana team.",
                  file=sys.stderr)
            return 1
        if team.is_staff_email(con, email):
            print("That email belongs to a teacher or school admin. A team member needs a different email.",
                  file=sys.stderr)
            return 1
        if team.member_by_email(con, email):
            print("That email is already a team member.", file=sys.stderr)
            return 1
        mid = team.create(con, email, a.name, a.role, "active", None)
        if a.totp_secret:
            con.execute("UPDATE team_members SET totp_sealed = ?, totp_confirmed_at = ? WHERE id = ?",
                        (team.seal(a.totp_secret), A.iso(A.now()), mid))
        A.audit(con, None, "server", "team_owner_created" if a.role == "owner" else "team_member_created", mid,
                role=a.role)
    print(f"Done: {email} is a Magana team {team.ROLE_LABEL[a.role]}. Sign in at {portal_api.portal_url()}/sign-in/: "
          "the first sign-in sets up the authenticator app and shows the backup codes once.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
