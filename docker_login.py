#!/usr/bin/python
import json
import sys
import argparse
import shutil
import os


# FUNCTION FOR PRETTY PRINTING OUT A JSON STRING
def PrintJSON(json_string):
    return json.dumps(json_string, indent=4, sort_keys=True)


# FUNCTION TO RETURN A JSON STRING FROM A UNICODE JSON
def Unicode_To_String(JSON_String):
    if isinstance(JSON_String, dict):
        return {Unicode_To_String(key): Unicode_To_String(value)
                for key, value in JSON_String.iteritems()}
    elif isinstance(JSON_String, list):
        return [Unicode_To_String(element) for element in JSON_String]
    elif isinstance(JSON_String, unicode):
        return JSON_String.encode('utf-8')
    else:
        return JSON_String


# PARSE THE DTR REPO NAME, USERNAME AND PASSWORD
parser = argparse.ArgumentParser(description='Parser for docker_login.py script')
parser.add_argument("dtr_repo", type=str, help='The URL for the old DTR or the Artifactory DTR Repo')
parser.add_argument("-u", "--user", type=str, help='The Intranet Email of the User wishing to login', required=True)
parser.add_argument("-p", "--password", type=str, help='The Intranet Password of the User wishing to login', required=True)
args = parser.parse_args()

# SET THE PARSED OPTIONS INTO VARIABLES
#sys.stdout.write('\nParsing given options')
ARTIFACTORY_REPO = str(args.dtr_repo)
AUTHENTICATION_TOKEN = str(args.password)
AUTHENTICATION_EMAIL = str(args.user)

# GET HOMEDIR
HOMEDIR=str(os.environ['HOME'])

# COPY OVER ORIGINAL DOCKER CONFIG.JSON FILE
#sys.stdout.write('\nCopying over original config.json file')
Original_Config_File = str(HOMEDIR+'/.docker/config.json')
Temp_config_file = '/tmp/config.json'
shutil.copy(Original_Config_File, Temp_config_file)

# GET DATA FROM THE CONFIG.JSON FILE AND UPDATE IT
#sys.stdout.write('\nGetting Data from File')
data = Unicode_To_String(json.load(open(Temp_config_file)))
AUTHENTICATION_URL = str("https://"+ARTIFACTORY_REPO)
data['auths'][AUTHENTICATION_URL] = dict([("auth", AUTHENTICATION_TOKEN), ("email", AUTHENTICATION_EMAIL)])

# CREATE FILE WITH UPDATED VALUES
#sys.stdout.write('\nCreating file with updated Authorization Credentials')
os.remove(Temp_config_file)
with open(Temp_config_file, 'wt') as outfile:
        outfile.write(PrintJSON(data))

# SET ORIGINAL FILE WITH THE NEW ONE
#sys.stdout.write('\nUpdating Authorization Credentials in Original File')
shutil.move(Temp_config_file, Original_Config_File)

sys.exit(0)
