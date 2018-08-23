#!/usr/bin/python

# Doug - 2018-08-22

#curl 'https://starfishstorage.zendesk.com/api/v2/search.json?query={Vazquez}'  -u dhughes@starfishstorage.com:$password" > /tmp/s
#ifile = open("/tmp/s" , 'r')
#bfjson = json.load(ifile)

import json
import requests
import sys
from argparse import ArgumentParser

parser = ArgumentParser(description='show zendesk tickets')
parser.add_argument('--zenuser', help='zendesk login', required=True)
parser.add_argument('--zenpass', help='zendesk password', required=True)
parser.add_argument('--search', help='a search query', required=True)
# status doesn't work yet
parser.add_argument('--status', help='open|closed|etc', required=False)
parser.add_argument('--csv', help='output as csv', required=False, action="store_true")
parser.add_argument('--body', help='how ticket body', required=False, action="store_true")

args = parser.parse_args()

delimeter = "\n"
if args.csv:
  delimeter = ","
if args.search:
  search = args.search

url = "https://starfishstorage.zendesk.com/api/v2/search.json?query={%s}"% args.search
ifile = requests.get(url,auth=(args.zenuser, args.zenpass ))


bfjson = ifile.json()

i = 0
while i < bfjson['count']:
  if args.csv:
    csvlist = []
    csvlist.append (str(bfjson['results'][i]['id']))
    csvlist.append (bfjson['results'][i]['created_at'])
    for item in ["name", "email", "subject"]:
      if item in bfjson['results'][i]:
	csvlist.append (bfjson['results'][i][item])
      else:
	csvlist.append ("")
    
    print ",".join(csvlist)
  else:
    print "id: " + str(bfjson['results'][i]['id'])
    print "created at: " + bfjson['results'][i]['created_at']
    for item in ["name", "email", "subject"]:
      if item in bfjson['results'][i]:
	print item + ": " + bfjson['results'][i][item]
    if args.body and "description" in bfjson['results'][i]:
      print "body: " + bfjson['results'][i]['description']
    print "-------------------------------------------"
  
  i += 1

