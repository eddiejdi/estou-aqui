#!/usr/bin/env python3
"""OAuth helper para LinkedIn (authorization-code flow).

- Gera a URL de autorização e inicia um pequeno HTTP listener em localhost para receber o `code`.
- Efetua a troca (`accessToken` request) e salva token em `./linkedin_token.json` (não comitar).

Uso (recomendado):
  export LINKEDIN_CLIENT_ID=... \
         LINKEDIN_CLIENT_SECRET=... \
         LINKEDIN_REDIRECT_URI=http://localhost:8080/callback
  python3 tests/linkedin/oauth_helper.py

Parâmetros opcionais:
  --scopes (espaço-separado, ex: "r_liteprofile w_member_social r_organization_social w_organization_social")
  --port (porta do listener local, padrão 8080)

Observações:
- Configure o mesmo redirect URI no painel do app LinkedIn.
- NÃO insira o client secret em repositórios públicos; guarde-o localmente ou em secrets do CI.
"""
import argparse
import http.server
import json
import os
import socketserver
import threading
import urllib.parse
import webbrowser

import requests

TOKEN_PATH = os.path.join(os.path.dirname(__file__), 'linkedin_token.json')


def build_auth_url(client_id, redirect_uri, scopes, state):
    qs = {
        'response_type': 'code',
        'client_id': client_id,
        'redirect_uri': redirect_uri,
        'scope': ' '.join(scopes),
        'state': state,
    }
    return 'https://www.linkedin.com/oauth/v2/authorization?' + urllib.parse.urlencode(qs)


class OAuthHandler(http.server.BaseHTTPRequestHandler):
    server_version = 'LinkedInOAuthHelper/1.0'

    def do_GET(self):
        qs = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(qs)
        if 'code' in params:
            code = params['code'][0]
            self.server.code = code
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(b'<html><body><h2>OK — you can close this window</h2></body></html>')
        else:
            self.send_response(400)
            self.end_headers()

    def log_message(self, format, *args):
        # silence
        return


def exchange_code_for_token(client_id, client_secret, redirect_uri, code):
    url = 'https://www.linkedin.com/oauth/v2/accessToken'
    payload = {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirect_uri,
        'client_id': client_id,
        'client_secret': client_secret,
    }
    headers = {'Content-Type': 'application/x-www-form-urlencoded'}
    r = requests.post(url, data=payload, headers=headers)
    r.raise_for_status()
    return r.json()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--port', type=int, default=8080)
    p.add_argument('--scopes', type=str, default='r_liteprofile w_member_social')
    p.add_argument('--client-id')
    p.add_argument('--client-secret')
    p.add_argument('--redirect-uri')
    args = p.parse_args()

    client_id = args.client_id or os.environ.get('LINKEDIN_CLIENT_ID')
    client_secret = args.client_secret or os.environ.get('LINKEDIN_CLIENT_SECRET')
    redirect_uri = args.redirect_uri or os.environ.get('LINKEDIN_REDIRECT_URI')

    if not client_id or not client_secret or not redirect_uri:
        print('Env/args missing: set LINKEDIN_CLIENT_ID, LINKEDIN_CLIENT_SECRET and LINKEDIN_REDIRECT_URI or pass --client-id/--client-secret/--redirect-uri')
        return 2

    scopes = args.scopes.split()
    state = 'state-' + os.urandom(6).hex()
    auth_url = build_auth_url(client_id, redirect_uri, scopes, state)

    print('\nOpen this URL in your browser and approve the app:')
    print(auth_url)
    try:
        webbrowser.open(auth_url)
    except Exception:
        pass

    # start local server
    handler = OAuthHandler
    with socketserver.TCPServer(('127.0.0.1', args.port), handler) as httpd:
        httpd.code = None

        def serve():
            httpd.serve_forever()

        t = threading.Thread(target=serve, daemon=True)
        t.start()
        print(f'Listening on http://127.0.0.1:{args.port}/ for the callback...')

        # wait for code
        tries = 0
        while tries < 600 and httpd.code is None:
            tries += 1
            threading.Event().wait(0.5)
        httpd.shutdown()

        if not httpd.code:
            print('Timed out waiting for authorization code')
            return 3

        code = httpd.code
        print('Received code — exchanging for access token...')
        tok = exchange_code_for_token(client_id, client_secret, redirect_uri, code)
        print('Token response:')
        print(json.dumps(tok, indent=2, ensure_ascii=False))

        # save token locally
        try:
            with open(TOKEN_PATH, 'w', encoding='utf-8') as f:
                json.dump(tok, f, ensure_ascii=False, indent=2)
            print(f'Saved token to {TOKEN_PATH} (do NOT commit)')
        except Exception as e:
            print('Failed to save token locally:', e)

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
