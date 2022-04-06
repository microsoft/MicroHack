import urllib.request
import json
import os
import ssl

def allowSelfSignedHttps(allowed):
    # bypass the server certificate verification on client side
    if allowed and not os.environ.get('PYTHONHTTPSVERIFY', '') and getattr(ssl, '_create_unverified_context', None):
        ssl._create_default_https_context = ssl._create_unverified_context

allowSelfSignedHttps(True) # this line is needed if you use self-signed certificate in your scoring service.

data = {
    "data":
    [
         { 
            "CUSTOMERNAME": "Westend Cycles",
            "CUSTOMERGROUP": "Z1",
            "BILLINGCOMPANYCODE": 1710,
            "CUSTOMERACCOUNTGROUP": "KUNA",
            "CREDITCONTROLAREA": "A000",
            "DISTRIBUTIONCHANNEL": 10,
            "ORGANIZATIONDIVISION": 0,
            "SALESDISTRICT": "US0003",
            "SALESORGANIZATION": 1710,
            "SDDOCUMENTCATEGORY": "C",
            "CITYNAME": "RALEIGH",
            "POSTALCODE": "27603"
        },
        { 
            "CUSTOMERNAME": "Skymart Corp",
            "CUSTOMERGROUP": "Z2",
            "BILLINGCOMPANYCODE": 1710,
            "CUSTOMERACCOUNTGROUP": "KUNA",
            "CREDITCONTROLAREA": "A000",
            "DISTRIBUTIONCHANNEL": 10,
            "ORGANIZATIONDIVISION": 0,
            "SALESDISTRICT": "US0004",
            "SALESORGANIZATION": 1710,
            "SDDOCUMENTCATEGORY": "C",
            "CITYNAME": "New York",
            "POSTALCODE": "10007"
        }
    ],
}

body = str.encode(json.dumps(data))

#Replace with your own url
url = 'http://2fe78f13-726c-43d0-9182-7e0b084a295b.westeurope.azurecontainer.io/score'
api_key = '' # Replace this with the API key for the web service if needed
headers = {'Content-Type':'application/json', 'Authorization':('Bearer '+ api_key)}

req = urllib.request.Request(url, body, headers)

try:
    response = urllib.request.urlopen(req)

    result = response.read()
    print(result)
except urllib.error.HTTPError as error:
    print("The request failed with status code: " + str(error.code))

    # Print the headers - they include the requert ID and the timestamp, which are useful for debugging the failure
    print(error.info())
    print(json.loads(error.read().decode("utf8", 'ignore')))
