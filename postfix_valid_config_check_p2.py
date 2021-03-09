#!/usr/bin/env python2
#
# Name:        postfix_valid_config_check_p2.py
# Date:        2021-03-08
# Author:      dalibor.aleksic@atomia.com
# Version:     1.0_p2
# Parameters:
#              --ignore-warnings   Report OK status even when warnings are found
#              --quiet             Surpress errors/warrings messages
#              --postfix-path      Overide default postfix path
#
# Returns:
#              0 - OK
#              1 - WARNING
#              2 - CRITICAL
#              3 - UNKNOWN
#
# Description: Nagios plugin that alerts when postfix configuration is not valid.
#              It executes "postfix check" command and parses output for errors.
#
import argparse
import subprocess


nagios_status_exit_code = {
    'OK': 0,
    'WARNING': 1,
    'CRITICAL': 2,
    'UNKNOWN': 3
}


def load_arguments():
    """
    Parses script arguments
    """
    global args
    parser = argparse.ArgumentParser('Postfix valid config check')
    parser.add_argument('--ignore-warnings',
                        action='store_true',
                        help="Ignore warnings in configuration")
    parser.add_argument('--postfix-path',
                        default='/usr/sbin/postfix',
                        help="Path to postfix bin (default: /usr/sbin/postfix)")
    parser.add_argument('-q', '--quiet',
                        action='store_true',
                        help="Surpress error and warning details")
    args = parser.parse_args()


def exec_postfix_check():
    """
    Executes 'postfix check' command and returns output
    """
    # Workaround:
    # postfix doesn't display output when detects that stdout/stderr
    # are not attached to console. Using 'script' command it emulates
    # that postfix is run inside console aka stdout/stderr are attached to console
    try:
        process_info = subprocess.check_output(["script --quiet --return --command '%s check' /dev/null" % args.postfix_path],
                                               stderr=subprocess.PIPE,
                                               shell=True,
                                               universal_newlines=True)
        return {
            'returncode': 0,
            'output_lines': process_info.splitlines()
        }
    except subprocess.CalledProcessError as e:
        return {
            'returncode': e.returncode,
            'output_lines': e.output.splitlines()
        }


def run_nagios_check():
    """
    Parses output from 'postfix check' and returns appropriate nagios result
    """
    # Fetch output from postfix check
    postfix_check_result = exec_postfix_check()

    # Return UNKNOWN status if postfix is not installed
    if postfix_check_result['returncode'] == 127:
        print("POSTFIX CONFIG: postfix not installed or --postfix-path=%s invalid" %
              args.postfix_path)
        if not args.quiet:
            print('\n'.join(postfix_check_result['output_lines']))
        exit(nagios_status_exit_code['UNKNOWN'])

    # Classify lines from output
    fatal_lines = []
    error_lines = []
    warning_lines = []
    other_lines = []
    for line in postfix_check_result['output_lines']:
        if 'fatal:' in line:
            fatal_lines.append(line)
        elif 'error:' in line:
            error_lines.append(line)
        elif 'warning:' in line:
            warning_lines.append(line)
        else:
            other_lines.append(line)

    # Return CRITICAL if config is invalid
    if len(fatal_lines) or len(error_lines):
        print("POSTFIX CONFIG: %d fatal errors; %d errors; %d warnings" %
              (len(fatal_lines), len(error_lines), len(warning_lines)))
        if not args.quiet:
            print('\n'.join(fatal_lines))
            print('\n'.join(error_lines))
        exit(nagios_status_exit_code['CRITICAL'])

    # Return WARNING if config is valid but contains warnings. Overridden with --ignore-warnings
    if len(warning_lines) and not args.ignore_warnings:
        print("POSTFIX CONFIG: %d warnings" % len(warning_lines))
        if not args.quiet:
            print('\n'.join(warning_lines))
        exit(nagios_status_exit_code['WARNING'])

    # Plugin validation check
    if postfix_check_result['returncode'] != 0:
        print("POSTFIX CONFIG: PLUGIN ERROR: Detected OK state, but return code is %d (expected 0)" %
              postfix_check_result['returncode'])
        exit(nagios_status_exit_code['CRITICAL'])

    # Return OK if no errors found or warnings are ignored
    if len(warning_lines) and args.ignore_warnings:
        print("POSTFIX CONFIG: OK (%d ignored warnings)" % len(warning_lines))
    else:
        print("POSTFIX CONFIG: OK")
    exit(nagios_status_exit_code['OK'])


# Main
load_arguments()
run_nagios_check()
