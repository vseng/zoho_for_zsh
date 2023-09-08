
# Zoho API Functions by Victoria
# this is an oh-my-zsh plugin for interacting with zoho apis - under construction, new functions added as needed
# CURRENTLY ONLY SUPPORTS SELF CLIENT APP - create your self client app at https://api-console.zoho.com

# ---------- API AUTH FUNCTIONS ----------

function zoho_save_auth_to_keychain() {
    # This function must be run prior to querying any endpoings using this plugin - saves app id and secret to macOS keychain to avoid having to hardcode them in
    # if your self client is not new and you have an existing refresh token, use the optional third parameter to save it to keychain as well
    # if keychain items already exist, values will be updated
    #
    # @param $1: REQUIRED - the client id from your zoho self client app
    # @param $2: REQUIRED - the client secret from your zoho self client app
    # @param $3: OPTIONAL - the existing refresh token from your zoho self client app (required for initial use, use a dummy value to get the keychain item created)

    CLIENT=$1
    SECRET=$2
    RFRESH=$3
    # naming the input parameters

    security add-generic-password -U -s "ZOHO_API_CLIENT_ID" -U -a "Zoho" -U -w $CLIENT -T /usr/bin/security
    security add-generic-password -U -s "ZOHO_API_SECRET" -U -a "Zoho" -U -w $SECRET -T /usr/bin/security
    # adding/updating client id and secret keychain values - you may be prompted for your keychain password the first time

    if [ ! -z $RFRESH ];
        then security add-generic-password -U -s "ZOHO_API_REFRESH_TOKEN" -U -a "Zoho" -U -w $RFRESH -T /usr/bin/security
    fi
    # adding/updating refresh token keychain value if it is passed as a param
}

function zoho_oauth() {
    # This function handles token generation and refresh for the zoho_api plugin - app client info must already be saved to the keychain before use
    #
    # @param $1: OPTIONAL - grant code received from zoho api console to be used for new clients & if scopes are changed - refresh token will be saved to keychain
    #
    # @return: prints the token value and the duration in seconts until expiry - if new refresh token is generated, prints that as well

    CLIENT=$(security find-generic-password -w -s "ZOHO_API_CLIENT_ID" -a "Zoho")
    SECRET=$(security find-generic-password -w -s "ZOHO_API_SECRET" -a "Zoho")
    RFRESH=$(security find-generic-password -w -s "ZOHO_API_REFRESH_TOKEN" -a "Zoho")
    # gets client information from the keychain
    # my current scopes: ZohoCRM.settings.ALL, ZohoCRM.modules.READ, ZohoAnalytics.metadata.read, ZohoAnalytics.data.read (Updated on 09/08/2023)

    GRANT_CODE=$1
    # get this code from the zoho api console when creating your self client or when changing assigned scopes

    REFRESH=$(security find-generic-password -w -s "ZOHO_API_REFRESH_TOKEN" -a "Zoho")
    # gets
    # scopes: zoho.crm.settings.all, zoho.crm.modules.all, zoho.analytics.metadata.all, zoho.analytics.data.all (09/06/2023)

    if (! CLIENT=$(security find-generic-password -w -s "ZOHO_API_CLIENT_ID" -a "Zoho") || \
        ! SECRET=$(security find-generic-password -w -s "ZOHO_API_SECRET" -a "Zoho") || \
        ! RFRESH=$(security find-generic-password -w -s "ZOHO_API_REFRESH_TOKEN" -a "Zoho")); 
            then
                echo "can't fetch values from keychain, error $? - please make sure the specified keychain values exist and are not locked"
            return 1
    fi
    # if the keychain items cannot be fetched, stop execution because nothing else is gonna work

    if [ ! -z "$GRANT_CODE" ]; 
        then 
            AUTH=$(curl -X POST \
                        -d "client_id=$CLIENT&client_secret=$SECRET&redirect_uri=$REDIRECT&code=$GRANT_CODE&grant_type=authorization_code" \
                        "https://accounts.zoho.com/oauth/v2/token") 
            security add-generic-password -U -s "ZOHO_API_REFRESH_TOKEN" \
                                          -U -a "Zoho" \
                                          -U -w $(echo $AUTH | jq '.refresh_token' | tr -d '"')
        else 
            AUTH=$(curl -X POST \
                        -d "client_id=$CLIENT&client_secret=$SECRET&refresh_token=$RFRESH&grant_type=refresh_token" \
                        "https://accounts.zoho.com/oauth/v2/token")
    fi
    # the oauth2 http request - if a new grant code is not passed as an arg, saved refresh token is used - otherwise, new refresh token saved to keychain

    export ZOHO_TOKEN_EXPIRY=$(date -v+1H +%s)
    export ZOHO_TOKEN=$(echo $AUTH | jq '.access_token' | tr -d '"')
    # pushes the value of the access token to the environment variable $ZCRM_TOKEN, along with the datetime of its expiry (1 hour after generation)
    
    echo $AUTH | jq '.'
    # pretty print the response from Zoho
}

function zoho_ensure_oauth() {
    # This function checks the expiry datetime of the most recent zoho api token and runs zoho_ouath() if the current token is expired
    #
    # @return: The response from zoho_oauth() if it runs, otherwise prints the current active token and seconds till expiry
    NOW=$(date +%s)
    DIFF=$(($ZOHO_TOKEN_EXPIRY - $NOW))
   
    if [ $DIFF -lt 0 ];
        then
            zoho_oauth
        else
            echo "{\"Token\": \"$ZOHO_TOKEN\", \"Seconds until expiry\": \"$DIFF\"}" | jq .
    fi
}

# ---------- UTILITY FUNCTIONS ----------

function util_json_to_csv() {
    # This is a helper function for zoho api GET requests - parses json using specified jq syntax and outputs the result as a .csv file
    #
    # @param $1: REQUIRED - file path pointing to a .json or .txt file containing json to be parsed by jq
    # @param $2: REQUIRED - file path pointing to a .csv file where jq will save its output
    # @param $3: REQUIRED - file path pointing to a .txt file containing jq used to parse the json

    IN_FILE=$1
    OUT_FILE=$2
    JQ_FILE=$3
    # naming the input parameters

    if [ ! -r "$IN_FILE" ]; 
        then chmod 755 $IN_FILE
    fi
    # make sure we can read the input file 

    if [ ! -r "$JQ_FILE" ]; 
        then chmod 755 $JQ_FILE
    fi
    # make sure we can read the jq file 

    jq -r $($JQ_FILE) $IN_FILE > $OUT_FILE
    # parse the in-file using the contents of the jq-file, saving result to the out-file
}

function zoho_curl() {
    # this function handles http requests for the zoho_api plugin
    # BEFORE USING, UPDATE THE VALUE OF YOUR ZOHO CRM SAVE DIRECTORY $ZOHO_SAVE_DIR IN YOUR .ZSHRC
    #
    # @param $1: REQUIRED - Request Type - accepted values are POST, PUT, GET, etc.
    # @param $2: REQUIRED - The CRM Product being queried - determines base URL for http requests. Current supported values are CRM and ZA - also accepts base URLs (no trailing "/")
    # @param $3: REQUIRED - File path where http response will be saved - edit these in the functions below to support your local environment setup
    # @param $4: REQUIRED - API Endpoint targeted by the http request - exclude leading and trailing "/" characters
    # @param $5: OPTIONAL - URL parameters for the http request - should be URL-encoded
    #
    # @return: a file output, usually json-formatted

    TYPE=$1
    PRODUCT=$2
    SAVE_FILE=$3
    ENDPOINT=$4
    PARAMS=$5

    if [ ! -r "$SAVE_FILE" ]; 
        then chmod 755 $SAVE_FILE
    fi
    # if the owner does not have read/write/execute permissions to the $ZOHO_SAVE_DIR, grants them
    
    if [ $PRODUCT = "CRM" ]; 
        then BASE_URL=https://www.zohoapis.com/crm/v5
        elif [ $PRODUCT = "ZA" ]; 
            then BASE_URL=https://analyticsapi.zoho.com/api
        else BASE_URL=$PRODUCT
    fi
    # determines the base url to use for the request based on the product name or url specified in $2

    HEADER="Authorization: Zoho-oauthtoken $ZOHO_TOKEN"
    # header passed with the http request

    zoho_ensure_oauth

    if [ ! -z $PARAMS ];
        then
            RESP=$(curl \
                -o $SAVE_FILE \
                -X $TYPE \
                -H $HEADER \
                -d "$PARAMS" \
                "$BASE_URL/$ENDPOINT")
        else
            RESP=$(curl \
                -o $SAVE_FILE \
                -X $TYPE \
                -H $HEADER \
                "$BASE_URL/$ENDPOINT")
    fi
    # the http request - only passes url params with the request if they exist
}

# ---------- ZOHO ANALYTICS FUNCTIONS ----------

function zoho_analytics_get_view_metadata() {
    # This function reads the view metadata for a Zoho Analytics table
    #
    # @param $1: REQUIRED - the email address of your organization owner
    # @param $2: REQUIRED - the name of the targeted workspace, url-encoded
    # @param $3: REQUIRED - the name of the targeted workspace view, url-encoded

    TYPE=GET
    PRODUCT="ZA"
    FILENAME="ZA-View-Metadata-$2-$3"
    ENDPOINT="$1/$2/$3"
    PARAMS="ZOHO_ACTION=VIEWMETADATA&ZOHO_OUTPUT_FORMAT=JSON&ZOHO_API_VERSION=1.0&ZOHO_ERROR_FORMAT=JSON"
    # specify argument values for zoho_curl()
    
    JSON_FILE="$ZOHO_OUT/$FILENAME.txt"
    CSV_FILE="$ZOHO_OUT/$FILENAME.csv"
    # specifying the input and output file names for jq

    zoho_curl $TYPE $PRODUCT $JSON_FILE $ENDPOINT $PARAMS
    # perform the get request, saving the json response to the specified filename in $ZOHO_SAVE_DIR
    
    JQ_FILE="$ZOHO_IN/zoho_analytics_get_view_metadata_jq.txt"
    # specifying path to jq file, takes a parameter or a default value

    util_json_to_csv $JSON_FILE $CSV_FILE $JQ_FILE
    # parses file as raw json - first specifying col names, then iterating thru the modules array & selecting relevant keys, finally converting to csv
    return 0
}

# ---------- ZOHO CRM FUNCTIONS ----------

function zoho_crm_get_modules() {
    # This function gets all crm module metadata, saves it locally as a .txt file, then parses selected json to create a .csv file and saves it locally
    # uses the modules api: https://www.zoho.com/crm/developer/docs/api/v5/modules-api.html
    #
    # @param $1: OPTIONAL - file path pointing to a plain text file containing valid jq syntax to parse the json into a csv - default value can be hardcoded

    TYPE=GET
    PRODUCT="CRM"
    FILENAME=CRM-Module-Metadata
    ENDPOINT=settings/modules
    # specify argument values for zoho_curl()
    
    JSON_FILE="$ZOHO_OUT/$FILENAME.txt"
    CSV_FILE="$ZOHO_OUT/$FILENAME.csv"
    # specifying the input and output file names for jq

    zoho_curl $TYPE CRM $JSON_FILE $ENDPOINT
    # perform the get request, saving the json response to the specified filename in $ZOHO_SAVE_DIR
    
    JQ_FILE="$ZOHO_IN/zoho_crm_get_modules_jq.txt"
    # specifying path to jq file, takes a parameter or a default value

    util_json_to_csv $JSON_FILE $CSV_FILE $JQ_FILE
    # parses file as raw json - first specifying col names, then iterating thru the modules array & selecting relevant keys, finally converting to csv
    return 0
}

function zoho_crm_get_field_metadata() {
    # This function gets field metadata for specified modules, saves the responses locally as .txt files, and parses them to create .csv files
    # Make sure you have directories set up for the save paths before running this function
    #
    # @param $1: REQUIRED - a file path pointing to a .json file containing an array of crm module names inside a "modules" object
    # @param $2: OPTIONAL - a file path pointing to a plain text file containing valid jq syntax to parse the json into a csv - default value can be hardcoded

    TYPE="GET"
    PRODUCT="CRM"
    # general request variables

    INPUT_FILE="$ZOHO_IN/module_list.json"
    # the json file to be referenced for target modules

    JQ_FILE="$ZOHO_IN/zoho_crm_get_field_metadata_jq.txt"
    # the plain text file containing the jq to parse the input file to .csv format - default value can be hardcoded

    for i in $(jq -r '.modules[]' $INPUT_FILE |  tr -d '"');
        do 
            MODULE=$i
            JSON_FILE="$ZOHO_OUT/CRM-Raw-Field-Metadata-$MODULE.txt"
            CSV_FILE="$ZOHO_OUT/CRM-Formatted-Field-Metadata-$MODULE.csv"
            ENDPOINT="settings/fields?module=$i"
            # setting up module-specific request variables

            zoho_curl $TYPE $PRODUCT $JSON_FILE $ENDPOINT
            # the http request

            util_json_to_csv $JSON_FILE $CSV_FILE $JQ_FILE
            # parses file as raw json - first specifying col names, then iterating thru the modules array & selecting relevant keys, finally converting to csv
        done;
    return 0
}

function zoho_crm_get_record_timeline() {
    # This function pulls the history/timeline of a specified record - response saved as .txt file, then selected keys parsed to create .csv file
    #
    # @param $1: REQUIRED - api name of the module to which the queried record belongs
    # @param $2: REQUIRED - zoho record id of the module whose timeline is being pulled
    # @param $3: OPTIONAL - a file path pointing to a plain text file containing valid jq syntax to parse the json into a csv - default value can be hardcoded

    TYPE=GET
    PRODUCT="CRM"
    FILENAME="CRM-Timeline-$1-$2"
    ENDPOINT="$1/$2/__timeline"
    PARAMS="include_inner_details=field_history.data_type, field_history.field_label, field_history.pick_list_values"
    # specifying parameter values for zoho_curl()

    JSON_FILE="$ZOHO_OUT/$FILENAME.txt"
    CSV_FILE="$ZOHO_OUT/$FILENAME.csv"
    JQ_FILE="$ZOHO_IN/zoho_crm_get_record_timeline_jq.txt"
    # specifying input, output, and jq file names for parsing to csv

    zoho_curl $TYPE $PRODUCT $JSON_FILE $ENDPOINT $PARAMS
    # the http request
    
    util_json_to_csv $JSON_FILE $CSV_FILE $JQ_FILE
    # parses file as raw json - first specifying col names, then iterating thru the modules array & selecting relevant keys, finally converting to csv
    return 0
}