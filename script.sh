#!/bin/bash

set -e

err() {
    RED='\033[0;31m'
    NC='\033[0m'
    printf "${RED}Err: $1${NC}\n"
}
warn() {
    YELLOW='\033[1;33m'
    NC='\033[0m'
    printf "${YELLOW}Warn: $1${NC}\n"
}
success() {
    GREEN='\033[0;32m'
    NC='\033[0m'
    printf "${GREEN}$1${NC}\n" 
}
die() { err "$*" 1>&2; exit 1; }


DIRECTORY=$1
MYSQL_HOST=$2
MYSQL_USER=$3
MYSQL_PWD=$4

check_params () {
    for arg in "$@"
    do  
        value="${!arg}"
        if [ -z "$value" ]; then
            die "Missing $arg"
        fi
    done
}

check_if_locked () {
    if [ -f "/tmp/lock" ]
    then
        die "Migration currently locked. Another process might be running the migration or previous one failed to unlock or complete."
    else
        echo "Starting migration."
        lock
    fi
}

lock () {
    echo "$BASHPID" > /tmp/lock
}

unlock () {
    rm /tmp/lock || true
}

get_current_version () {
    command="SELECT version FROM ecs.versionTable LIMIT 1"
    # -s, --silent
    # -N, --skip-column-names
    CURRENT_VERSION=$(MYSQL_PWD=$MYSQL_PWD mysql -sN -u "$MYSQL_USER" -h "$MYSQL_HOST" -e "$command")
    echo "Current version is $CURRENT_VERSION"
}

update_version () {
    echo "Updating current database version"
    command="UPDATE ecs.versionTable SET version = $1 WHERE version = $CURRENT_VERSION"
    MYSQL_PWD=$MYSQL_PWD mysql -sN -u "$MYSQL_USER" -h "$MYSQL_HOST" -e "$command"
    get_current_version
}

run_script () {
    echo "Running the script $1 marked by version $2"
    result=$(MYSQL_PWD=$MYSQL_PWD mysql -sN -u "$MYSQL_USER" -h "$MYSQL_HOST" < $1)
    if [ -z $result ]; then
        success "Migration $2 ran successfully."
        update_version $2

    fi
}

run_scripts () {
    # avoids splitting for loop by space
    declare -A scripts
    versions=()
    IFS=$(echo -en "\n\b")
    for file in $(ls $DIRECTORY/ | sort -n)
    do
        version=$(basename $file | sed -r 's/0*([0-9]+).*.sql/\1/')
        if [[ "$version" =~ ^[0-9]+$ ]]; then
            if [ "$version" -gt $CURRENT_VERSION ]; then
                run_script "$DIRECTORY/$file" $version
            else
                warn "Skipping script $file. Version lower than current database"
            fi
        else
            err "File $file has invalid name pattern"
        fi
    done
    success "Completed running all scripts. Final version is $CURRENT_VERSION"
}

check_if_locked
check_params DIRECTORY MYSQL_HOST MYSQL_USER MYSQL_PWD

echo "Reading current version from the database"
get_current_version

echo "Executing the scripts"
run_scripts

echo "Removing the lock"
unlock
echo "Finished"
exit 0