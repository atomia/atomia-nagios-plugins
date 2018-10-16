#!/usr/bin/env python3

import argparse
import requests
from urllib.parse import urljoin
from bs4 import BeautifulSoup


def exit_ok(message: str):
    print(f"OK: {message}")
    exit(0)


def exit_warning(message: str):
    print(f"WARNING: {message}")
    exit(1)


def exit_critical(message: str):
    print(f"CRITICAL: {message}")
    exit(2)


def exit_unknown(message: str):
    print(f"UNKNOWN: {message}")
    exit(3)


def parse_arguments():
    global args
    parser = argparse.ArgumentParser(description="Nagios Check Login plugin")
    parser.add_argument("--url", "--uri", help="URL of login form", required=True)
    parser.add_argument("--username", help="Username or Email", required=True)
    parser.add_argument("--password", help="Password", required=True)
    parser.add_argument("--timeout", help="Timeout", default=5)
    parser.add_argument("--matchstring", required=False,
                        help="String to match after login. Login is considered successful if response status is 200"
                             "(OK) and matching string is found in response.")
    args = vars(parser.parse_args())
    args['timeout'] = int(args['timeout'])


def insert_user_credentials(form_data: dict):
    for key in form_data.keys():
        if key is None:
            continue
        elif 'user' in key:
            form_data[key] = args['username']
        elif 'pass' in key:
            form_data[key] = args['password']
        elif 'mail' in key:
            form_data[key] = args['username']


def extract_form_inputs(form):
    fields = form.findAll('input')
    return dict((field.get('name'), field.get('value')) for field in fields)


def verify_login(session: requests.sessions):
    try:
        response_get = session.get(args['url'], timeout=args['timeout'])
        response_get.raise_for_status()

        if not args['matchstring'] in response_get.text:
            raise Exception(f"MatchString not found after login. First 50chars: {response_get.text[0:50]}")

    except requests.exceptions.HTTPError as ex:
        exit_critical(f"[HTTP ERROR][VALIDATE_LOGIN] {ex}")
    except requests.exceptions.ConnectionError as ex:
        exit_critical(f"[CONNECTION ERROR][VALIDATE_LOGIN] {ex}")
    except requests.exceptions.Timeout as ex:
        exit_critical(f"[TIMEOUT][VALIDATE_LOGIN] {ex}")
    except requests.exceptions.RequestException as ex:
        exit_critical(f"[REQUEST ERROR][VALIDATE_LOGIN] {ex}")
    except Exception as ex:
        exit_critical(str(ex))


def main():

    parse_arguments()
    try:
        session = requests.session()
        response_get = session.get(args['url'], timeout=args['timeout'])
        if not (response_get.status_code == 401 or response_get.status_code == 200):
            response_get.raise_for_status()

        page = BeautifulSoup(response_get.text, "html.parser")
        form = page.find('form')
        form_action = urljoin(args['url'], form.get('action'))
        form_data = extract_form_inputs(form)
        insert_user_credentials(form_data)

        response_post = session.post(form_action, data=form_data)
        response_post.raise_for_status()

        if not args['matchstring'] is None:
            verify_login(session)

        exit_ok("Login successful. (Login verification not enabled)")

    except requests.exceptions.HTTPError as ex:
        exit_critical(f"[HTTP ERROR] {ex}")
    except requests.exceptions.ConnectionError as ex:
        exit_critical(f"[CONNECTION ERROR] {ex}")
    except requests.exceptions.Timeout as ex:
        exit_critical(f"[TIMEOUT] {ex}")
    except requests.exceptions.RequestException as ex:
        exit_critical(f"[REQUEST ERROR] {ex}")
    except Exception as ex:
        exit_critical(str(ex))


if __name__ == '__main__':
    main()