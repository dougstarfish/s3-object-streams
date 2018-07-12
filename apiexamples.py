#!/usr/bin/python
# Has some API examples
# Copyright Starfish Storage Corp, 2018 - Doug Hughes

import requests
import json
import urllib3

# get list of volumes
requests.request('GET','https://192.168.10.139:443/api/volume/', auth=('starfish',SECRET_KEY), verify=False).json()

# get list of scans
requests.request('GET','https://192.168.10.139:443/api/scan/', auth=('starfish',SECRET_KEY), verify=False).json()

# start a scan in a subdir of NFSExport2 volume
sess = requests.Session()
sess.auth=('starfish', SECRET_HERE)
payload = {
  "volume": "NFSExport2",
  "requested_by": "client",
  "type": "diff",
  "crawler_options": {
    "startpoint": "mydir/foo"
  }
}
r=sess.post('https://192.168.10.139:443/api/scan/', verify=False, json=payload)
print r.json()


# query
r=sess.get('https://192.168.10.139:443/api/query/Target:/?query=name%3Dtest&limit=10', verify=False)
print r.json()

r=sess.get('https://192.168.10.139:443/api/query/Target:/?query=name%3Dtest&limit=10', verify=False)
print r.json()[0]['full_path']
archivetarget/git/FlameGraph/test
print r.json()[1]['full_path']
Microsoft/SFU/unzip/BaseUtils/bin/test

r=sess.get('https://192.168.10.139:443/api/query/Target:archivetarget/?query=name%3Dtest&limit=10', verify=False)

r=sess.get('https://192.168.10.139:443/api/query/Target:/?query=ext%3Dpng&limit=10', verify=False)
for el in r.json():
  print el['full_path']

#  "incarnation": {
#    "cmd_line": [
#      "rsync_wrapper"
#    ],
#    "from_scratch": false,
#    "prescan_enabled": false
#  },
    "cmd_line": ["/opt/starfish/lib/sf-cli/_sfclient/_sfclient", "-v", "job", "start", "--no-prescan", "--from-scratch", "--job-name", "myrsynctest", "rsync_wrapper", "home:doug/git/FlameGraph", "Target:archivetarget/git2/FlameGraph"]
payload = {
  "incarnation": {
    "prescan_enabled": False, 
    "from_scratch": False, 
  },
  "job": {
    "volume": "home", 
    "name": "altrsynctest", 
    "root_path": "doug/git/FlameGraph", 
    "entry_verification": True, 
    "prescan_type": "mtime", 
    "requested_by": "client", 
    "command": ["rsync_wrapper"], 
    "query": [],  
    "options": {
      "dst_volume": "Target", 
      "dst_path": "archivetarget/git3/FlameGraph"
    }
  } 
}
r=sess.post('https://192.168.10.139:443/job/', verify=False, json=payload)
job_id =  r.json()['long_id']
