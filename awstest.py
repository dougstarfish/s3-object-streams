#!/usr/bin/python3.6

import boto3
#import uuid
import json
import sys
from pprint import pprint
import argparse


# Parse Arguments
parser = argparse.ArgumentParser()
#parser.add_argument("--csv", action="store_true")
#parser.add_argument("--html", action="store_true")
#parser.add_argument("--delimeter")
parser.add_argument("--profile", default="default")
parser.add_argument("--bucket", required=True)
parser.add_argument("--key", required=True)
parser.add_argument("--versionid")
parser.add_argument("--listversions", action="store_true")
parser.parse_args()

args = parser.parse_args()

if args.profile:
  session = boto3.Session(profile_name = args.profile)

#bucket = 'test-nci2'
#key = 'testp/testmd'

    

s3 = session.resource('s3')
client = session.client('s3')

#bucket_v = s3.BucketVersioning(args.bucket)
#bucket_v.load()
#print(bucket_v.status)

if args.listversions:
  ovs = client.list_object_versions(Bucket = args.bucket, Prefix=args.key)
  print ('Name: ' + ovs['Name'] )
  print ('Prefix: ' + ovs['Prefix'] )
  count = 1
  for item in ovs['Versions']:
    print (str(count))
    print (' ETag: ' + item['ETag'])
    print (' IsLatest: ' + str(item['IsLatest']))
    print (' VersionId: ' + str(item['VersionId']))
    print (' Date: ' + str(item['LastModified']))
    k = client.head_object(Bucket=args.bucket, Key=args.key)
    print('  ' + str(k['Metadata']))
    count += 1
  sys.exit(0)

#res = client.get_bucket_policy(Bucket='starfishs3-archive-target')
#res = client.list_buckets()

# test metadata size limits
#res = s3.Object('test-nci2','testp/testmd').put(Body='This is data',Metadata={'aa': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'ab' : 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'bcd': 'hi'})
#pprint (res)


pprint (client.get_object(Bucket=args.bucket, Key=args.key))

k = client.head_object(Bucket=args.bucket, Key=args.key)
md = k['Metadata']
md['aa'] = 'new metadata'
md['ab'] = 'foo bar'
client.copy_object(Bucket = args.bucket, Key = args.key, CopySource = args.bucket + '/' + args.key, Metadata = md, MetadataDirective='REPLACE')

pprint (client.get_object(Bucket = args.bucket, Key = args.key))
