
# Zoho API Functions by Victoria
# this is an oh-my-zsh plugin for interacting with zoho apis - under construction, new functions added as needed
# CURRENTLY ONLY SUPPORTS SELF CLIENT APP - create your self client app at https://api-console.zoho.com

# ---------- API AUTH FUNCTIONS ----------

function save_self_client() {
    # This function must be run prior to querying any endpoints using this plugin
    # saves app id and secret (and refresh if applicable) to macOS keychain
    #
    # if keychain items already exist, values will be updated
    #
    # INPUT (any order)
    # -i or --id:      REQUIRED - the client id from your zoho self client app
    # -s or --secret:  REQUIRED - the client secret from your zoho self client app
    # -r or --refresh: OPTIONAL - the existing refresh token from your zoho self client app (required for initial use, use a dummy value to get the keychain item created)
    # -v or --verbose: OPTIONAL - prints debug text

    while [[ "$#" -gt 0 ]] ; do 
        case "$1" in 
            -i | --id)      id="$2"
            shift ;;
            -s | --secret)  secret="$2"
            shift ;;
            -r | --refresh) refresh="$2"
            shift ;; 
            -v | --verbose) debug=true ;;
            *) echo "$0: Unrecognized input - $1. $?" ; return 1 ;; 
        esac 
        shift 
    done 
    # assigning function variables based on args

    echo "assigned values to function vars"

    security add-generic-password -U -s "ZOHO_API_CLIENT_ID" -U -a "Zoho" -U -w $id -T /usr/bin/security
    security add-generic-password -U -s "ZOHO_API_SECRET" -U -a "Zoho" -U -w $secret -T /usr/bin/security
    # adding/updating client id and secret keychain values - you may be prompted for your keychain password the first time

    echo "saving input to the keychain"

    if [ ! -z $refresh ]; then security add-generic-password -U -s "ZOHO_API_REFRESH_TOKEN" -U -a "Zoho" -U -w $ -T /usr/bin/security ; fi
    # adding/updating refresh token keychain value if it is passed
}

function get_access_token() {
    # This function handles token generation and refresh for the zoho_api plugin
    # app client info must already be saved to the keychain before use
    #
    # INPUT
    # -c or --code:    OPTIONAL - grant code received from zoho api console to be used for new clients & if scopes are changed - refresh token will be saved to keychain
    # -v or --verbose: OPTIONAL - asks for printed output

    while [[ "$#" -gt 0 ]] ; do 
        case "$1" in 
            -r | --refresh) gen_refresh=true uri="$2" code="$3"
            shift ;;
            -v | --verbose) debug=true ;;
            *) echo "$0: Unrecognized input $1. $?" ; return 1 ;; 
        esac 
        shift 
    done 
    # assigning function variables based on args

    base_url=https://accounts.zoho.com/oauth/v2/token
    # using north america url 

    echo "getting values from keychain"

    id=$(security find-generic-password -w -s "ZOHO_API_CLIENT_ID" -a "Zoho")
    secret=$(security find-generic-password -w -s "ZOHO_API_SECRET" -a "Zoho")
    
    # gets client information from the keychain
    # my current scopes: ZohoCRM.settings.ALL, ZohoCRM.modules.READ, ZohoAnalytics.metadata.read, ZohoAnalytics.data.read (Updated on 09/08/2023)

    # get this code from the zoho api console when creating your self client or when changing assigned scopes

    if (! id=$(security find-generic-password -w -s "ZOHO_API_CLIENT_ID" -a "Zoho") || \
        ! secret=$(security find-generic-password -w -s "ZOHO_API_SECRET" -a "Zoho"))
            then 
                echo "$0: can't fetch values from keychain"
                ${debug:-$(echo "Error: $?")}
                return 1
    fi
    # if the keychain items cannot be fetched, stop execution because nothing else is gonna work

    echo "requesting access token ${gen_refresh:+ and refresh token}"

    if [[ "$gen_refresh" = "true" ]]
        then 
            gen_refresh_params="&redirect_uri=$uri&code=$code&grant_type=authorization_code"
        else
            refresh=$(security find-generic-password -w -s "ZOHO_API_REFRESH_TOKEN" -a "Zoho")
            refresh_flow_params="&refresh_token=$refresh&grant_type=refresh_token"
    fi
    
    params="client_id=$id&client_secret=$secret${gen_refresh_params:-}${refresh_flow_params:-}" 

    echo $params

    response=$(curl -X POST -d $params "$base_url") 
    echo $response
    # the http request - if refresh token is not being generated & saved to keychain, saved refresh token is used
    
    if [[ "$gen_refresh" = "true" ]]
        then if [[ "$debug" = "true" ]]; then echo "saving new refresh token value to keychain"; fi
             security add-generic-password -U -s "ZOHO_API_REFRESH_TOKEN" \
                                           -U -a "Zoho" \
                                           -U -w $(echo $response | jq '.refresh_token' | tr -d '"')
    fi
    # saving new refresh token to keychain if one was generated

    export ZOHO_TOKEN_EXPIRY=$(date -v+1H +%s)
    export ZOHO_TOKEN=$(echo $response | jq '.access_token' | tr -d '"')
    # pushes the value of the access token to the environment variable $ZCRM_TOKEN, along with the datetime of its expiry (1 hour after generation)
    
    echo "{\"Refreshed\": \"TRUE\", \"Token\": \"$ZOHO_TOKEN\", \"Seconds until expiry\": \"$(echo $response | jq '.expires_in')\"}" | jq '.'
    # pretty print the response from Zoho if asked
}

function ensure_token() {
    # This function checks the expiry datetime of the most recent zoho api token and runs zoho_ouath() if the current token is expired
    #
    # INPUT
    # -v or --verbose: OPTIONAL - asks for printed output
    
    while [[ "$#" -gt 0 ]] ; do
        case "$1" in 
            -v | --verbose) debug=true ;; 
            *) echo "$0: Unrecognized input - $1. $?" ; exit 1 ;; 
        esac 
        shift 
    done 
    # assigning function variables based on args
    
    echo $debug

    if [ ! -z $ZOHO_TOKEN_EXPIRY ]
        then
            now=$(date +%s)
            diff=$(($ZOHO_TOKEN_EXPIRY - $now))
        else
            diff=0
            get_access_token ${debug:+-v}
    fi
   
    if [[ "$diff" -lt 0 ]]
        then get_access_token ${debug:+-v}
    else 
        ${debug:+$(echo "{\"Refreshed\": \"FALSE\", 
                          \"Token\": \"$ZOHO_TOKEN\", 
                          \"Seconds until expiry\": \"$diff\"}" | jq '.')}
    fi
}

function zoho_curl() {
    # this function handles http requests for the zoho_api plugin
    # BEFORE USING, UPDATE THE VALUE OF YOUR ZOHO CRM SAVE DIRECTORY $ZOHO_SAVE_DIR IN YOUR .ZSHRC
    #
    # @param $1: REQUIRED - Request Type - accepted values are POST, PUT, GET, etc.
    # @param $2: REQUIRED - File path where http response will be saved - edit these in the functions below to support your local environment setup
    # @param $3: REQUIRED - API Endpoint targeted by the http request - exclude leading and trailing "/" characters
    # @param $4: OPTIONAL - URL parameters for the http request - should be URL-encoded
    #
    # @return: a file output, usually json-formatted

    TYPE=$1
    SAVE_FILE=$2
    ENDPOINT=$3
    PARAMS=$4

    ensure_token
    # make sure we have an active token - if not, refresh it
    
    BASE_URL=https://www.zohoapis.com/crm/v5
    # determines the base url to use for the request based on the product name or url specified in $2

    HEADER="Authorization: Zoho-oauthtoken $ZOHO_TOKEN"
    # header passed with the http request

    RESP=$(curl -o $SAVE_FILE -X $TYPE -H $HEADER ${PARAMS:=-d $PARAMS} "$BASE_URL/$ENDPOINT")
    # the http request - only passes url params with the request if they exist
}
