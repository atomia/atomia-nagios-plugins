#!/usr/bin/env python3

"""
Author: Dalibor Aleksic (dalibor.aleksic@atomia.com)
Versions:

21.09.2020:
  1.0: Initial version
  Dalibor Aleksic (dalibor.aleksic@atomia.com)

"""

import argparse
import subprocess
from os import path


def load_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument('--nfs',
                        action='store_true',
                        help="Check NFS mountpoints")
    return parser.parse_args()


def get_drbd_role():
    output = subprocess.run(
        "drbd-overview | grep ':storage/' | awk '{print $3}' | awk -F'/' '{print $1}'",
        check=True,
        shell=True,
        stdout=subprocess.PIPE,
        universal_newlines=True)
    return output.stdout.lower().replace('\n','')


def is_mountpoint_in_fstab(mountpoint):
    output = subprocess.run(
        "grep -Rv '^#' /etc/fstab | awk '{print $2}'",
        check=True,
        shell=True,
        stdout=subprocess.PIPE,
        universal_newlines=True)
    return "%s\n" % mountpoint in output.stdout


def is_mountpoint_mounted(mountpoint):
   output = subprocess.run(
        "mount -l | awk '{print $3}'",
        check=True,
        shell=True,
        stdout=subprocess.PIPE,
        universal_newlines=True)
   return "%s\n" % mountpoint in output.stdout

state_ok=0
state_warning=1
state_critical=2
ok_message="OK: /storage/configuration/maps present; "
critical_message="CRITICAL: /storage/configuration/maps missing; "
arguments=load_arguments()

if path.exists("/storage/configuration/maps"):
   print(ok_message)
   exit(state_ok)

else:
   if arguments.nfs:
      if not path.exists("/storage/configuration"):
         critical_message = critical_message + "/storage/configuration missing; "
      if not is_mountpoint_in_fstab("/storage/configuration"):
         critical_message = critical_message + "/storage/configuration missing in fstab; "
      if not is_mountpoint_mounted("/storage/configuration"):
         critical_message = critical_message + "/storage/configuration not mounted; "
      print(critical_message)
      exit(state_critical)

   else:
      drbd_role=get_drbd_role()
      if "primary" in drbd_role:
         print(critical_message)
         exit(state_critical)
      elif "secondary" in drbd_role:
         print("OK: /storage/configuration/maps missing, but it's DRBD Secondary")
         exit(state_ok)
      else:
         critical_message = critical_message + "Unexpected role %s for host;" % drbd_role
         exit(state_critical)
