#!/bin/bash

set -e

PROGNAME=$(basename $0)

function log_info {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO]: $1"
}

function log_error {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR]: $1" 1>&2
}

function error_exit
{
    #   ----------------------------------------------------------------
    #   Function for exit due to fatal program error
    #       Accepts 1 argument:
    #           string containing descriptive error message
    #   ----------------------------------------------------------------
    log_error "${1:-"Unknown Error"}"
    exit 1
}

function echo_help
{
    echo "This script copies SSL certificates into the Application"
    echo "So they can be used to prove identity for integration partners."
    echo ""
    echo "Usage: ssl-deploy-hook -d example.com -p /etc/application/certs"
    echo ""
    echo "**Required Environment Variables:**"
    echo "This script is meant to run as a certbot hook and as such depends on the"
    echo "environment variables set by certbot."
    echo "More info: https://certbot.eff.org/docs/using.html#renewing-certificates"
    echo ""
    echo "RENEWED_DOMAINS       will contain a space-delimited list of renewed certificate"
    echo "                      domains (for example, example.com www.example.com)"
    echo "RENEWED_LINEAGE       will point to the config live subdirectory (for example,"
    echo "                      /etc/letsencrypt/live/example.com) containing the new"
    echo "                      certificates and keys"
    echo ""
    echo "Options:"
    echo "  -d | --domain       *Required*: Set the renewed domain for this server"
    echo "  -p | --path         *Required*: Set the path where certificates are copied to"
    echo "  -h | --help         Show this help"
    echo ""
}

# Default command line options
TARGET_DOMAIN=""
APP_PATH=""

# Parse command line options
POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -h|--help)
            echo_help
            exit 0
            ;;

        -p|--path)
            APP_PATH="$2"
            if [[ -z "$APP_PATH" ]]; then
                error_exit "Application path to copy certificates to (-p|--path) is a required option"
            fi
            log_info "Application path set to $APP_PATH"
            shift 2 # past argument & value
            ;;

        -d|--domain)
            TARGET_DOMAIN="$2"
            if [[ -z "$TARGET_DOMAIN" ]]; then
                error_exit "Target Domain (-d|--domain) is a required option"
            fi
            log_info "Target domain set to $TARGET_DOMAIN"
            shift 2 # past argument & value
            ;;

        *)    # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters

if [[ -z "$TARGET_DOMAIN" || -z "$APP_PATH" ]]; then
    error_exit "Both target domain (-d|--domain) and application path (-p|--path) are required options"
fi

# Main processing loop
for domain in $RENEWED_DOMAINS; do
    if [[ "$domain" == "$TARGET_DOMAIN" ]]; then
        application_cert_dir="$APP_PATH/$domain"
        log_info "Processing certificate for $domain"

        # make sure target application dir exists
        if mkdir -p "$application_cert_dir"; then
            log_info "Created directory $application_cert_dir"
        else
            error_exit "Failed to create directory $application_cert_dir"
        fi

        # Set strict file permissions
        umask 077

        # Copy certificate, certificate chain, and private key
        log_info "Copying certificates to $application_cert_dir"
        cp "$RENEWED_LINEAGE/cert.pem" "$application_cert_dir/cert.pem" || error_exit "Failed to copy cert.pem"
        cp "$RENEWED_LINEAGE/fullchain.pem" "$application_cert_dir/fullchain.pem" || error_exit "Failed to copy fullchain.pem"
        cp "$RENEWED_LINEAGE/privkey.pem" "$application_cert_dir/privkey.pem" || error_exit "Failed to copy privkey.pem"

        # Change ownership and set proper permissions
        log_info "Setting ownership and permissions for certificate files"
        chown root "$application_cert_dir/cert.pem" "$application_cert_dir/fullchain.pem" "$application_cert_dir/privkey.pem" || error_exit "Failed to change ownership"
        chmod 440 "$application_cert_dir/cert.pem" "$application_cert_dir/fullchain.pem" "$application_cert_dir/privkey.pem" || error_exit "Failed to set file permissions"

        log_info "Certificate deployment for $domain completed successfully"
    fi
done

log_info "Script completed successfully"
exit 0


