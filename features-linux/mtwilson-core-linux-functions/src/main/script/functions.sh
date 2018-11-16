#!/bin/bash
# WARNING:
# *** do NOT use TABS for indentation, use SPACES (tabs will cause errors in some linux distributions)
# *** do NOT use 'exit' to return from the functions in this file, use 'return' ONLY (exit will cause unit testing hassles)

# CONFIGURATION:

#setupconsole_dir=/opt/intel/cloudsecurity/setup-console
#conf_dir=/etc/intel/cloudsecurity
DEFAULT_MTWILSON_JAVA_DIR=/opt/mtwilson/java
DEFAULT_MTWILSON_CONF_DIR=/opt/mtwilson/configuration

# TERM_DISPLAY_MODE can be "plain" or "color"
TERM_DISPLAY_MODE=color
TERM_STATUS_COLUMN=60
TERM_COLOR_GREEN="\\033[1;32m"
TERM_COLOR_CYAN="\\033[1;36m"
TERM_COLOR_RED="\\033[1;31m"
TERM_COLOR_YELLOW="\\033[1;33m"
TERM_COLOR_NORMAL="\\033[0;39m"


#DEFAULT_MYSQL_HOSTNAME="127.0.0.1"
#DEFAULT_MYSQL_PORTNUM="3306"
#DEFAULT_MYSQL_USERNAME="root"
#DEFAULT_MYSQL_PASSWORD=""
#DEFAULT_MYSQL_DATABASE="mw_as"

#DEFAULT_POSTGRES_HOSTNAME="127.0.0.1"
#DEFAULT_POSTGRES_PORTNUM="5432"
#DEFAULT_POSTGRES_USERNAME="root"
#DEFAULT_POSTGRES_PASSWORD=""
#DEFAULT_POSTGRES_DATABASE="mw_as"

DEFAULT_JAVA_REQUIRED_VERSION="1.8"
DEFAULT_TOMCAT_REQUIRED_VERSION="7.0"
DEFAULT_MYSQL_REQUIRED_VERSION="5.0"
DEFAULT_POSTGRES_REQUIRED_VERSION="9.3"

DEFAULT_MTWILSON_API_BASEURL="http://127.0.0.1:"
DEFAULT_TOMCAT_API_PORT="8443"

export INSTALL_LOG_FILE=${INSTALL_LOG_FILE:-/tmp/mtwilson-install.log}

### FUNCTION LIBRARY: echo and export environment variables

# exports the values of the given variables
# example:
# export_vars VARNAME1 VARNAME2 VARNAME3
# there is no display output from this function
export_vars() {
  local names="$@"
  local name
  local value
  for name in $names
  do
    eval value="\$$name"
    if [ -n "$value" ]; then
      eval export $name=$value
    fi
  done
}

# prints the values of the given variables
# example:
# print_vars VARNAME1 VARNAME2 VARNAME3
# example output:
# VARNAME1=some_value1
# VARNAME2=some_value2
# VARNAME3=some_value3
print_vars() {
  local names="$@"
  local name
  local value
  for name in $names
  do
    eval value="\$$name"
    echo "$name=$value"
  done
}


### FUNCTION LIBRARY: generate random passwords

# generates a random password. default is 32 characters in length.
# you can pass a single parameter that is the desired length if
# you want something other than 32.
# usage examples:
# mypassword32=`generate_password`
# mypassword16=`generate_password 16`
# mypassword32=$(generate_password)
# mypassword16=$(generate_password 16)
generate_password() {
  < /dev/urandom tr -dc _A-Za-z0-9- | head -c${1:-32}
}

### FUNCTION LIBRARY: escape out input strings for passing to sed
# you pass it the string you are about to pass to sed that might
# contain the following characters ()&#%$+
# usage examples:
# new_string=$(sed_escape $string)
sed_escape() {
 echo $(echo $1 | sed -e 's/[()&#%$+]/\\&/g' -e 's/[/]/\\&/g')
}

# FUNCTION LIBRARY: This function returns either rhel fedora ubuntu suse
function getFlavour() {
  flavour=""
  grep -c -i ubuntu /etc/*-release > /dev/null
  if [ $? -eq 0 ] ; then
    echo "ubuntu"
    return 0
  fi
  grep -c -i "red hat" /etc/*-release > /dev/null
  if [ $? -eq 0 ] ; then
    echo "rhel"
    return 0
  fi
  grep -c -i fedora /etc/*-release > /dev/null
  if [ $? -eq 0 ] ; then
    echo "fedora"
    return 0
  fi
  grep -c -i suse /etc/*-release > /dev/null
  if [ $? -eq 0 ] ; then
    echo "suse"
    return 0
  fi
  echo "Unsupported linux flavor, Supported versions are ubuntu, rhel, fedora"
  return 1
}

function getUserProfileFile()
{
    flavor=$(getFlavour)
    case $flavor in
    "ubuntu" )
        file=~/.profile ;;
    "rhel" )
        file=~/.bash_profile ;;
    "fedora" )
        file=~/.bash_profile ;;
    "suse" )
        file=~/.bash_profile ;;
    esac
	#if [ ! -f $file ]; then
	#   touch $file
	#fi
	echo $file
}

#FUNCTION LIBRARY: appends data to a file
#requires two arguments first argument is data that needs to be appended and second argument is file path
function appendToUserProfileFile()
{
    if [ "$#" == 2 ]; then
	 file=$2
	else
	 file=$(getUserProfileFile)
	fi
    if [ ! -f $file ] || ! grep -q  "$1" $file; then
       echo "$1" >> $file
	else
	   echo "$1 Already there in user profile"
    fi
}

### FUNCTION LIBRARY: terminal display functions

# move to column 60:    term_cursor_movex $TERM_STATUS_COLUMN
# Environment:
# - TERM_DISPLAY_MODE
term_cursor_movex() {
  local x="$1"
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then
    echo -en "\\033[${x}G"
  fi
}

# Environment:
# - TERM_DISPLAY_MODE
# - TERM_DISPLAY_GREEN
# - TERM_DISPLAY_NORMAL
echo_success() {
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_GREEN}"; fi
  echo ${@:-"[  OK  ]"}
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_NORMAL}"; fi
  return 0
}

# Environment:
# - TERM_DISPLAY_MODE
# - TERM_DISPLAY_RED
# - TERM_DISPLAY_NORMAL
echo_failure() {
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_RED}"; fi
  echo ${@:-"[FAILED]"}
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_NORMAL}"; fi
  return 1
}

# Environment:
# - TERM_DISPLAY_MODE
# - TERM_DISPLAY_YELLOW
# - TERM_DISPLAY_NORMAL
echo_warning() {
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_YELLOW}"; fi
  echo ${@:-"[WARNING]"}
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_NORMAL}"; fi
  return 1
}


echo_info() {
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_CYAN}"; fi
  echo ${@:-"[INFO]"}
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_NORMAL}"; fi
  return 1
}

function validate_path_configuration() {
  local file_path="${1}"

  #if [[ "$file_path" == *..* ]]; then
  #  echo_warning "Path specified is not absolute: $file_path"
  #fi
  #file_path=`readlink -f "$file_path"` #make file path absolute

  if [ -z "$file_path" ]; then
    echo_failure "Path is missing"
    return 1
  fi
  file_path=`readlink -m "$file_path"` #make file path absolute

  if [[ "$file_path" != '/etc/'* && "$file_path" != '/opt/'* && "$file_path" != *'.env' ]]; then
    echo_failure "Configuration path validation failed. Verify path meets acceptable directory constraints: $file_path"
    return 1
  fi

  if [ -f "$file_path" ] || [ -d "$file_path" ]; then
    chmod 600 "${file_path}"
  fi
  return 0
}

function validate_path_data() {
  local file_path="${1}"

  #if [[ "$file_path" == *..* ]]; then
  #  echo_warning "Path specified is not absolute: $file_path"
  #fi
  #file_path=`readlink -f "$file_path"` #make file path absolute

  if [ -z "$file_path" ]; then
    echo_failure "Path is missing"
    return 1
  fi
  file_path=`readlink -m "$file_path"` #make file path absolute

  if [[ "$file_path" != '/var/'* && "$file_path" != '/opt/'* ]]; then
    echo_failure "Data path validation failed. Verify path meets acceptable directory constraints: $file_path"
    return 1
  fi

  if [ -f "$file_path" ] || [ -d "$file_path" ]; then
    chmod 600 "${file_path}"
  fi
  return 0
}

function validate_path_executable() {
  local file_path="${1}"

  #if [[ "$file_path" == *..* ]]; then
  #  echo_warning "Path specified is not absolute: $file_path"
  #fi
  #file_path=`readlink -f "$file_path"` #make file path absolute

  if [ -z "$file_path" ]; then
    echo_failure "Path is missing"
    return 1
  fi
  file_path=`readlink -m "$file_path"` #make file path absolute

  if [[ "$file_path" != '/usr/'* && "$file_path" != '/opt/'* ]]; then
    echo_failure "Executable path validation failed. Verify path meets acceptable directory constraints: $file_path"
    return 1
  fi

  if [ -f "$file_path" ] || [ -d "$file_path" ]; then
    chmod 755 "${file_path}"
  fi
  return 0
}

### SHELL FUNCTIONS

# parameters: space-separated list of files to include (shell functions or configuration)
# example:  shell_include_files /path/to/file1 /path/to/file2 /path/to/file3 ...
# if any file does not exist, it is skipped
shell_include_files() {
  for filename in "$@"
  do
    if [ -f "${filename}" ]; then
      . ${filename}
    fi
  done
}

# joins the items of an array with a delimiter value
# parameters: space-separated list of delimiter value and array to be joined
# example:  join_by : $array[@]
join_by() {
  local IFS="$1"
  shift
  echo "$*"
}

# finds all directories with name specified within a given directory
# parameters: space-separated list of directory to search within and name of directory to search for
# example:  find_subdirectories /opt/mtwilson bin
find_subdirectories() {
  local IFS=$'\n'
  find $1 \( -name $2 -type d \)
}


### FUNCTION LIBRARY: information functions

# Runs its argument and negates the error code:
# If the argument exits with success (0) then this function exits with error (1).
# If the argument exits with error (1) then this function exits with success (0).
# Note: only works with arguments that are executable; any additional parameters will be passed.
# Example:  if not using_java; then echo "Warning: skipping Java"; fi
no() { $* ; if [ $? -eq 0 ]; then return 1; else return 0; fi }
not() { $* ; if [ $? -eq 0 ]; then return 1; else return 0; fi }

# extracts the major version number (1) out of a string like 1.2.3_4
version_major() {
  echo "${1}" | awk -F . '{ print $1 }'
}
# extracts the minor version number (2) out of a string like 1.2.3_4
version_minor() {
  echo "${1}" | awk -F . '{ print $2 }'
}
# extracts the second minor version number (3) out of a string like 1.2.3_4
version_extract3() {
  local thirdpart=`echo "${1}" | awk -F . '{ print $3 }'`
  echo "${thirdpart}" | awk -F _ '{ print $1 }'
}
# extracts the fourth minor version number (4) out of a string like 1.2.3_4
version_extract4() {
  local thirdpart=`echo "${1}" | awk -F . '{ print $3 }'`
  echo "${thirdpart}" | awk -F _ '{ print $2 }'
}

# two arguments: actual version number (string), required version number (string)
# example:  `is_version_at_least 4.9 5.0` will return "no" because 4.9 < 5.0
is_version_at_least() {
  local testver="${1}"
  local reqver="${2}"
  local hasmajor=`version_major "${testver}"`
  local hasminor=`version_minor "${testver}"`
  local reqmajor=`version_major "${reqver}"`
  local reqminor=`version_minor "${reqver}"`
  if [[  -n "${reqmajor}" && "${hasmajor}" -gt "${reqmajor}" \
     || \
       -n "${reqmajor}" && "${hasmajor}" -eq "${reqmajor}" \
       && -z "${reqminor}" \
     || \
       -n "${reqmajor}" && "${hasmajor}" -eq "${reqmajor}" \
       && -n "${reqminor}" && "${hasminor}" -ge "${reqminor}" \
     ]]; then
    #echo "yes"
    return 0
  else
    #echo "no"
    return 1
  fi
}

# like is_version_at_least but works on entire java version string 1.7.0_51
# instead of just a major.minor number
# Parameters:
# - version to test (of installed software)
# - minimum required version
# Return code:  0 (no errors) if the java version given is greater than or equal to the minimum version
is_java_version_at_least() {
  local testver="${1}"
  local reqver="${2}"
  local hasmajor=`version_major "${testver}"`
  local hasminor=`version_minor "${testver}"`
  local hasminor3=`version_extract3 "${testver}"`
  local hasminor4=`version_extract4 "${testver}"`
  local reqmajor=`version_major "${reqver}"`
  local reqminor=`version_minor "${reqver}"`
  local reqminor3=`version_extract3 "${reqver}"`
  local reqminor4=`version_extract4 "${reqver}"`
  if [[  -n "${reqmajor}" && "${hasmajor}" -gt "${reqmajor}" \
     || \
       -n "${reqmajor}" && "${hasmajor}" -eq "${reqmajor}" \
       && -z "${reqminor}" \
     || \
       -n "${reqmajor}" && "${hasmajor}" -eq "${reqmajor}" \
       && -n "${reqminor}" && "${hasminor}" -gt "${reqminor}" \
     || \
       -n "${reqmajor}" && "${hasmajor}" -eq "${reqmajor}" \
       && -n "${reqminor}"  && "${hasminor}"  -eq "${reqminor}" \
       && -n "${reqminor3}" && "${hasminor3}" -gt "${reqminor3}" \
     || \
       -n "${reqmajor}" && "${hasmajor}" -eq "${reqmajor}" \
       && -n "${reqminor}"  && "${hasminor}"  -eq "${reqminor}" \
       && -z "${reqminor3}" \
     || \
       -n "${reqmajor}" && "${hasmajor}" -eq "${reqmajor}" \
       && -n "${reqminor}"  && "${hasminor}"  -eq "${reqminor}" \
       && -n "${reqminor3}" && "${hasminor3}" -eq "${reqminor3}" \
       && -z "${reqminor4}" \
     || \
       -n "${reqmajor}" && "${hasmajor}" -eq "${reqmajor}" \
       && -n "${reqminor}"  && "${hasminor}"  -eq "${reqminor}" \
       && -n "${reqminor3}" && "${hasminor3}" -eq "${reqminor3}" \
       && -n "${reqminor4}" && "${hasminor4}" -ge "${reqminor4}"  \
     ]]; then
#    echo "yes"
    return 0
  else
#    echo "no"
    return 1
  fi
}

# Parameters:
# - variable name to set with result
# - prompt (string)
# will accept y, Y, or nothing as yes, anything else as no
prompt_yes_no() {
  local resultvarname="${1}"
  local userprompt="${2}"
  # bug #512 add support for answer file
  if [ -n "${!resultvarname}" ]; then
    if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_CYAN}"; fi
    echo "$userprompt [Y/n] ${!resultvarname}"
    if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_NORMAL}"; fi
    return
  fi
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_CYAN}"; fi
  echo -n "$userprompt [Y/n] "
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_NORMAL}"; fi
  local userinput
  read -n 1 userinput
  echo
  if [[ $userinput == "Y" || $userinput == "y" || $userinput == "" ]]; then
    eval $resultvarname="yes"
  else
    eval $resultvarname="no"
  fi
}

# Parameters:
# - character like 'a' for which to echo the character code
# echos the character code of the specified character
# For example:   ord a     will echo 97
ord() { printf '%d' "'$1"; }

# Parameters:
# - variable name to set with result
# - prompt text (include any punctuation such as ? or : you want to display)
# - default setting (do not include any brackets or punctuation).
#   If the default setting is omitted, the current value of the output variable name will be used.
# Output:
# - result (input or default) is saved into the specified variable name
#
# Examples:
#   prompt_with_default USERNAME "What is your name?"
#   prompt_with_default USERCOLOR "What is your favorite color?" ${DEFAULT_COLOR}
prompt_with_default() {
  local resultvarname="${1}"
  local userprompt="${2}"
  local default_value
  # here $$
  eval current_value="\$$resultvarname"
  eval default_value="${3:-$current_value}"
  # bug #512 add support for answer file
  if [ -n "${!resultvarname}" ]; then
    if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_CYAN}"; fi
    echo "$userprompt [$default_value] ${!resultvarname:-$default_value}"
    if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_NORMAL}"; fi
    return
  fi
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_CYAN}"; fi
  echo -n "$userprompt [$default_value] "
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_NORMAL}"; fi
  local userinput
  read userinput
  eval $resultvarname=${userinput:-$default_value}
}

# Same as prompt_with_default, but the default value is hidden by *******,
# and if prompt text is not provided then the default prompt is "Password:"
prompt_with_default_password() {
  local resultvarname="${1}"
  local userprompt="${2:-Password:}"
  local default_value
  # here $$
  eval variable_name="$resultvarname"
  #echo_warning "variable name is $variable_name"
  eval current_value="\$$variable_name"
  #echo_warning "current value = $current_value"
  eval default_value="${3:-'$current_value'}"
  #echo_warning "default value = $default_value"
  local default_value_display="********"
  if [ -z "$default_value" ]; then default_value_display=""; fi;
  # bug #512 add support for answer file
  if [ -n "${!resultvarname}" ]; then
    if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_CYAN}"; fi
    echo "$userprompt [$default_value_display] ${default_value_display}"
    if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_NORMAL}"; fi
    return
  fi
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_CYAN}"; fi
  echo -n "$userprompt [$default_value_display] "
  if [ "$TERM_DISPLAY_MODE" = "color" ]; then echo -en "${TERM_COLOR_NORMAL}"; fi
  local userinput=""
  #IFS= read -r -s userinput
  #echo
  local input_counter=0
  local char
  while IFS= read -r -s -n 1 char
  do
    local code=`ord $char`
    if [[ $char == $'\0' ]]; then
      break
    elif [[ "$code" == "8" || "$code" == "127" ]]; then
      if (($input_counter > 0)); then
        echo -n $'\b \b';
        ((input_counter--))
        userinput="${userinput%?}"
      fi
    else
      echo -n '*'
      userinput+="$char";
      ((input_counter++))
    fi
  done
  echo
  if [ ! -z "$userinput" ]; then
   eval $resultvarname='$userinput'
  else
   eval $resultvarname='$default_value'
  fi
  #eval $resultvarname="${userinput:-'$default_value'}"
}

### FUNCTION LIBRARY: environment information functions

# Input: path to file that should exist
wait_until_file_exists() {
  markerfile=$1
  while [ ! -f "$markerfile" ]; do sleep 1; done
}


using_tomcat() {
  if [[ -n "$WEBSERVICE_VENDOR" ]]; then
    if [[ "${WEBSERVICE_VENDOR}" == "tomcat" ]]; then
      return 0
    else
      return 1
    fi
  else
    tomcat_detect 2>&1 > /dev/null
    if [ -n "$TOMCAT_HOME" ]; then
      return 0
    else
      return 1
    fi
  fi
}
# currently jetty is indicated either by WEBSERVER_VENDOR=jetty or by
# absence of tomcat . there's not an independent
# function for jetty_detect.
using_jetty() {
  if [[ -n "$WEBSERVER_VENDOR" ]]; then
    if [[ "${WEBSERVER_VENDOR}" == "jetty" ]]; then
      return 0
    else
      return 1
    fi
  else
    tomcat_detect 2>&1 > /dev/null
    if [ -z "$TOMCAT_HOME" ]; then
      return 0
    else
      return 1
    fi
  fi
}

using_mysql() { if [[ "${DATABASE_VENDOR}" == "mysql" ]]; then return 0; else return 1; fi }
using_postgres() { if [[ "${DATABASE_VENDOR}" == "postgres" ]]; then return 0; else return 1; fi }

### FUNCTION LIBARRY: conditional execution functions

# parameters: condition variable name, status line, code to run
# Will print "status line... " and then "OK" or "FAILED"
action_condition() {
  local condvar="${1}"
  local statusline="${2}"
  local condfn="${3}"
  local cond=$(eval "echo \$${condvar}")
  echo -n "$statusline"
  echo -n "... "
  if [ -n "$cond" ]; then
    echo_success "Skipped"
  else # if [ -z "$cond" ]; then
    eval "$condfn"
    cond=$(eval "echo \$${condvar}")
    if [ -n "$cond" ]; then
      echo_success "OK"
    else
      echo_failure "FAILED"
    fi
  fi
}
# similar to action_condition but reverses the logic: empty is OK, defined is FAILED
inaction_condition() {
  local condvar="${1}"
  local statusline="${2}"
  local condfn="${3}"
  local cond=$(eval "echo \$${condvar}")
  echo -n "$statusline"
  echo -n "... "
  if [ -z "$cond" ]; then
    echo_success "Skipped"
  else # if [ -z "$cond" ]; then
    eval "$condfn"
    cond=$(eval "echo \$${condvar}")
    if [ -z "$cond" ]; then
      echo_success "OK"
    else
      echo_failure "FAILED"
    fi
  fi
}

### FUNCTION LIBRARY: file management

# parameter: one or more paths to check for existence
# output: the first entry found to exist
# example:
# mybinary=`first_existing /usr/local/bin/ahctl /usr/bin/ahctl /opt/local/bin/ahctl /opt/bin/ahctl /opt/intel/cloudsecurity/attestation-service/bin/ahctl`
first_existing() {
    local search_locations="$@"
    local file
    for file in $search_locations
    do
      if [[ -e "$file" ]]; then
        echo "$file"
        return 0
      fi
    done
    return 1
}

# parameters: one or more files/directories to check for existence
# return value: returns 0 if all files are present, 1 if any are missing; displays report on screen
# example:
# report_files_exist /etc/file1 /etc/file2
report_files_exist() {
    local search_locations="$@"
    local report_summary=0
    local file
    for file in $search_locations
    do
      if [[ -e "$file" ]]; then
        echo_success "$file" exists
      else
        echo_failure "$file" missing
        report_summary=1
      fi
    done
    return $report_summary
}

# makes a date-stamped backup copy of a file
backup_file() {
  local filename="${1}"
  local datestr=`date +%Y-%m-%d.%H%M`
  local backup_filename="${filename}.${datestr}"
  if [[ -n "$filename" && -f "$filename" ]]; then
    cp ${filename} ${backup_filename}
    echo "${backup_filename}"
    return 0
  fi
  return 1
}

# read a property from a property file formatted like NAME=VALUE
# parameters: property name, filename
# example: read_property_from_file MYFLAG FILENAME
# Automatically strips Windows carriage returns from the file
read_property_from_file() {
  local property="${1}"
  local filename="${2}"
  if ! validate_path_configuration "$filename"; then exit -1; fi
  if [ -f "$filename" ]; then
    local found=`cat "$filename" | grep "^$property"`
    if [ -n "$found" ]; then
      #echo -n `cat "$filename" | tr -d '\r' | grep "^$property" | tr -d '\n' | awk -F '=' '{ print $2 }'`
      echo `cat "$filename" | tr -d '\r' | grep "^$property" | head -n 1 | awk -F '=' '{ print $2 }'`
    fi
  fi
}

# write a property into a property file, replacing the previous value
# parameters: property name, filename, new value
# example: update_property_in_file MYFLAG FILENAME true
update_property_in_file() {
  local property="${1}"
  local filename="${2}"
  local value="${3}"
  local encrypted="false"

  # disabling this check... this is a utility function, it is the
  # responsibility of all callers to ensure they are using it to
  # edit files in known locations and not pass in the wrong paths
  #if ! validate_path_configuration "$filename"; then exit -1; fi
  if [ -f "$filename" ]; then
    # Decrypt if needed
    if file_encrypted "$filename"; then
      encrypted="true"
      decrypt_file "$filename" "$MTWILSON_PASSWORD"
    fi

    local ispresent=`grep "^${property}" "$filename"`
    if [ -n "$ispresent" ]; then
      # first escape the pipes new value so we can use it with replacement command, which uses pipe | as the separator
      local escaped_value=`echo "${value}" | sed 's/|/\\|/g'`
      local sed_escaped_value=$(sed_escape "$escaped_value")
      # replace just that line in the file and save the file
      updatedcontent=`sed -re "s|^(${property})\s*=\s*(.*)|\1=${sed_escaped_value}|" "${filename}"`
      # protect against an error
      if [ -n "$updatedcontent" ]; then
        echo "$updatedcontent" > "${filename}"
      else
        echo_warning "Cannot write $property to $filename with value: $value"
        echo -n 'sed -re "s|^('
        echo -n "${property}"
        echo -n ')=(.*)|\1='
        echo -n "${escaped_value}"
        echo -n '|" "'
        echo -n "${filename}"
        echo -n '"'
        echo
      fi
    else
      # property is not already in file so add it. extra newline in case the last line in the file does not have a newline
      echo "" >> "${filename}"
      echo "${property}=${value}" >> "${filename}"
    fi

  # Return the file to encrypted state, if it was before
  if [ "$encrypted" == "true" ]; then
    encrypt_file "$filename" "$MTWILSON_PASSWORD"
  fi
  # test
  else
    # file does not exist so create it
    echo "${property}=${value}" > "${filename}"
  fi
}

configure_api_baseurl() {
  # setup mtwilson.api.baseurl
  local config_file="${1:-/etc/intel/cloudsecurity/management-service.properties}"

  local input_api_baseurl
  if [ -n "${MTWILSON_API_BASEURL}" ]; then
    mtwilson_api_baseurl="${MTWILSON_API_BASEURL}"
  elif [[ -n "${MTWILSON_SERVER}" && -n "${DEFAULT_API_PORT}" ]]; then
    mtwilson_api_baseurl="https://${MTWILSON_SERVER}:$DEFAULT_API_PORT"
  else
    local configured_api_baseurl="$CONFIGURED_API_BASEURL"   #`read_property_from_file mtwilson.api.baseurl "${config_file}"`
    if [ -z "${configured_api_baseurl}" ]; then
      prompt_with_default input_api_baseurl "Mt Wilson Server (https://[IP]:[PORT]):" "${configured_api_baseurl}"
    else
      input_api_baseurl="$configured_api_baseurl"
    fi

    if [[ "$input_api_baseurl" == http* ]]; then
      mtwilson_api_baseurl="$input_api_baseurl"
    else
      mtwilson_api_baseurl="https://${input_api_baseurl}"
    fi
  fi
  export MTWILSON_API_BASEURL=$mtwilson_api_baseurl
  update_property_in_file mtwilson.api.baseurl "${config_file}" "${mtwilson_api_baseurl}"
}

### FUNCTION LIBRARY: package management

# RedHat and CentOS may have yum and rpm

# Output:
# - variable "yum" contains path to yum or empty
yum_detect() {
  yum=`which yum 2>/dev/null`
  if [ -n "$yum" ]; then return 0; else return 1; fi
}
no_yum() {
  if yum_detect; then return 1; else return 0; fi
}

# Output:
# - variable "rpm" contains path to rpm or empty
rpm_detect() {
  rpm=`which rpm 2>/dev/null`
}

# Debian and Ubuntu may have apt-get and dpkg
# Output:
# - variable "aptget" contains path to apt-get or empty
# - variable "aptcache" contains path to apt-cache or empty
aptget_detect() {
  aptget=`which apt-get 2>/dev/null`
  aptcache=`which apt-cache 2>/dev/null`
}
# Output:
# - variable "dpkg" contains path to dpkg or empty
dpkg_detect() {
  dpkg=`which dpkg 2>/dev/null`
}

# SUSE has yast
# Output:
# - variable "yast" contains path to yast or empty
yast_detect() {
  yast=`which yast 2>/dev/null`
}

# SUSE has zypper
# Output:
# - variable "zypper" contains path to zypper or empty
zypper_detect() {
  zypper=`which zypper 2>/dev/null`
}


# Check if a package is already installed
is_package_installed() {
  local package_name="$1"
  if yum_detect; then
    yum list installed $package_name > /dev/null 2>&1
    result=$?
  elif aptget_detect; then
    dpkg-query --show $package_name > /dev/null 2>&1
    result=$?
  fi
  if [ $result -eq 0 ]; then return 0; else return 1; fi
}

# check if a command is already on path
is_command_available() {
  which $* > /dev/null 2>&1
  local result=$?
  if [ $result -eq 0 ]; then return 0; else return 1; fi
}

trousers_detect() {
  trousers=`which tcsd 2>/dev/null`
}

# Parameters:
# - absolute path to startup script to register
# - the name to use in registration (one word)
register_startup_script() {
  local absolute_filename="${1}"
  local startup_name="${2}"
  shift; shift;

  # try to install it as a startup script
  if [ -d /etc/init.d ]; then
    (
      cd /etc/init.d
      if [ -f "${startup_name}" ] || [ -L "${startup_name}" ]; then rm -f "${startup_name}"; fi
      ln -s "${absolute_filename}" "${startup_name}"
    )
  fi

  # RedHat and SUSE
  chkconfig=`which chkconfig 2>/dev/null`
  if [ -n "$chkconfig" ]; then
    $chkconfig --del "${startup_name}"  2>/dev/null
    $chkconfig --add "${startup_name}"  2>/dev/null
  fi

  # Ubuntu
  updatercd=`which update-rc.d 2>/dev/null`
  if [ -n "$updatercd" ]; then
    $updatercd -f "${startup_name}" remove 2>/dev/null
    $updatercd "${startup_name}" defaults $@ 2>/dev/null
  fi

  # systemd
  systemctlCommand=`which systemctl 2>/dev/null`
  if [ -d "/etc/systemd/system" ] && [ -n "$systemctlCommand" ]; then
    # root cannot requiretty; script "sudo -u" command will error out if a tty is required
    rootHasRequireTTY=$(cat /etc/sudoers.d/root 2>/dev/null | grep "requiretty")
    if [ -z "$rootHasRequireTTY" ]; then
      echo -e "Defaults:root "'!'"requiretty\n" >> "/etc/sudoers.d/root"
    fi

    if [ -f "/etc/systemd/system/${startup_name}.service" ]; then
      rm -f "/etc/systemd/system/${startup_name}.service"
    fi
    echo -e "[Unit]\nDescription=${startup_name}\n\n[Service]\nType=forking\nExecStart=${absolute_filename} start\nExecStop=${absolute_filename} stop\nTimeoutSec=300\n\n[Install]\nWantedBy=multi-user.target\n" > "/etc/systemd/system/${startup_name}.service"
    chmod 664 "/etc/systemd/system/${startup_name}.service"
    "$systemctlCommand" daemon-reload
    "$systemctlCommand" enable "${startup_name}.service"
    "$systemctlCommand" daemon-reload
  fi

}

# Parameters:
# - the name of the startup script (one word)
remove_startup_script() {
  local startup_name="${1}"
  shift;

  # RedHat and SUSE
  chkconfig=`which chkconfig 2>/dev/null`
  if [ -n "$chkconfig" ]; then
    $chkconfig --del "${startup_name}"  2>/dev/null
  fi

  # Ubuntu
  updatercd=`which update-rc.d 2>/dev/null`
  if [ -n "$updatercd" ]; then
    $updatercd -f "${startup_name}" remove 2>/dev/null
  fi

  # systemd
  systemctlCommand=`which systemctl 2>/dev/null`
  if [ -n "$systemctlCommand" ]; then
    "$systemctlCommand" disable "${startup_name}.service"
    "$systemctlCommand" daemon-reload
  fi
  if [ -f "/etc/systemd/system/${startup_name}.service" ]; then
    rm -f "/etc/systemd/system/${startup_name}.service"
  fi

  # try to remove startup script
  if [ -d "/etc/init.d" ]; then
    rm -f "/etc/init.d/${startup_name}" 2>/dev/null
  fi
}

function disable_tcp_timestamps() {
  local property="net.ipv4.tcp_timestamps"
  local filename="/etc/sysctl.conf"
  local value="0"

  if [ -f "$filename" ]; then
    local ispresent=$(grep "^${property}" "$filename")
    if [ -n "$ispresent" ]; then
      # first escape the pipes new value so we can use it with replacement command, which uses pipe | as the separator
      local escaped_value=$(echo "${value}" | sed 's/|/\\|/g')
      local sed_escaped_value=$(sed_escape "$escaped_value")
      # replace just that line in the file and save the file
      updatedcontent=`sed -re "s|^(${property})\s*=\s*(.*)|\1=${sed_escaped_value}|" "${filename}"`
      # protect against an error
      if [ -n "$updatedcontent" ]; then
        echo "$updatedcontent" > "${filename}"
      else
        echo_warning "Cannot write $property to $filename with value: $value"
        echo -n 'sed -re "s|^('
        echo -n "${property}"
        echo -n ')=(.*)|\1='
        echo -n "${escaped_value}"
        echo -n '|" "'
        echo -n "${filename}"
        echo -n '"'
        echo
      fi
    else
      # property is not already in file so add it. extra newline in case the last line in the file does not have a newline
      echo "" >> "${filename}"
      echo "${property}=${value}" >> "${filename}"
    fi
  else
    # file does not exist so create it
    echo "${property}=${value}" > "${filename}"
  fi

  echo 0 > /proc/sys/net/ipv4/tcp_timestamps
}

add_package_repository() {
  local repo_url=${1}
  local distro_release=${2}
  local repo_key_path=${3}

  #Repository URL must be specified
  if [ -z "${repo_url}" ]; then
    echo_failure "Add package repository failed. Repository URL not defined."
    return 1
  fi

  # detect available package management tools. start with the less likely ones to differentiate.
  yum_detect; yast_detect; zypper_detect; rpm_detect; aptget_detect; dpkg_detect;

  if [[ -n "$aptget" ]]; then
    local sources_list_file="/etc/apt/sources.list"
    if [ -z "${distro_release}" ]; then
      echo_failure "Add package repository failed. Distribution release not defined."
      return 1
    fi
    if [ -z "${repo_key_path}" ]; then
      echo_failure "Add package repository failed. Repository key path not defined."
      return 1
    fi
    local repo_not_already_added=$(cat ${sources_list_file} | grep ${repo_url})
    if [ -z "${repo_not_already_added}" ]; then
      echo "deb ${repo_url} ${distro_release} main" >> "${sources_list_file}"
    fi
    apt-key add "${repo_key_path}"
    if [ $? -ne 0 ]; then echo_failure "Failed to add postgresql repository public key to local package manager utility."; return 1; fi
    echo "Running apt-get update. This may take a while..."
    apt-get update > /dev/null
  #elif [[ -n "$yast" ]]; then
    # code goes here
  elif [[ -n "$yum" ]]; then
    yum -y localinstall "${repo_url}"
  #elif [[ -n "$zypper" ]]; then
    # code goes here
  else
    echo_failure "Package manager not supported."
    return 2
  fi
}

update_packages() {
  if yum_detect; then
    yum -y -x 'kernel*,redhat-release*' update
  elif aptget_detect; then
    apt-get -y update
  elif zypper_detect; then
    zypper -y update
  else
    echo "Unsupported operation: auto update only implemented for yum, apt, and zypper at this time"
  fi
}

# Ensure the package actually needs to be installed before calling this function.
# takes arguments: component name (string), package list prefix (string)
auto_install() {
  local component=${1}
  local cprefix=${2}
  local yum_packages=$(eval "echo \$${cprefix}_YUM_PACKAGES")
  local apt_packages=$(eval "echo \$${cprefix}_APT_PACKAGES")
  local yast_packages=$(eval "echo \$${cprefix}_YAST_PACKAGES")
  local zypper_packages=$(eval "echo \$${cprefix}_ZYPPER_PACKAGES")
  # detect available package management tools. start with the less likely ones to differentiate.
  yum_detect; yast_detect; zypper_detect; rpm_detect; aptget_detect; dpkg_detect;
  if [[ -n "$zypper" && -n "$zypper_packages" ]]; then
        zypper install $zypper_packages
  elif [[ -n "$yast" && -n "$yast_packages" ]]; then
        yast -i $yast_packages
  elif [[ -n "$yum" && -n "$yum_packages" ]]; then
        yum -y install $yum_packages
  elif [[ -n "$aptget" && -n "$apt_packages" ]]; then
        apt-get -y install $apt_packages
  fi
}

# echo the package names but don't do anything
auto_install_preview() {
  local component=${1}
  local cprefix=${2}
  local yum_packages=$(eval "echo \$${cprefix}_YUM_PACKAGES")
  local apt_packages=$(eval "echo \$${cprefix}_APT_PACKAGES")
  local yast_packages=$(eval "echo \$${cprefix}_YAST_PACKAGES")
  local zypper_packages=$(eval "echo \$${cprefix}_ZYPPER_PACKAGES")
  # detect available package management tools. start with the less likely ones to differentiate.
  yum_detect; yast_detect; zypper_detect; rpm_detect; aptget_detect; dpkg_detect;
  if [[ -n "$zypper" && -n "$zypper_packages" ]]; then
        echo zypper install $zypper_packages
  elif [[ -n "$yast" && -n "$yast_packages" ]]; then
        echo yast -i $yast_packages
  elif [[ -n "$yum" && -n "$yum_packages" ]]; then
        echo yum -y install $yum_packages
  elif [[ -n "$aptget" && -n "$apt_packages" ]]; then
        echo apt-get -y install $apt_packages
  fi
}

# automatically uninstall packages
# takes arguments: component name (string), package list prefix (string)
auto_uninstall() {
  local component=${1}
  local cprefix=${2}
  local yum_packages=$(eval "echo \$${cprefix}_YUM_PACKAGES")
  local apt_packages=$(eval "echo \$${cprefix}_APT_PACKAGES")
  local yast_packages=$(eval "echo \$${cprefix}_YAST_PACKAGES")
  local zypper_packages=$(eval "echo \$${cprefix}_ZYPPER_PACKAGES")
  # detect available package management tools. start with the less likely ones to differentiate.
  yum_detect; yast_detect; zypper_detect; rpm_detect; aptget_detect; dpkg_detect;
  if [[ -n "$zypper" && -n "$zypper_packages" ]]; then
        zypper remove $zypper_packages
  elif [[ -n "$yast" && -n "$yast_packages" ]]; then
        yast --remove $yast_packages
  elif [[ -n "$yum" && -n "$yum_packages" ]]; then
        yum -y erase $yum_packages
  elif [[ -n "$aptget" && -n "$apt_packages" ]]; then
        apt-get -y remove $apt_packages
  fi
}

# this was used in setup.sh when we installed complete rpm or deb packages via the self-extracting installer.
# not currently used, but will be used again when we return to rpm and deb package descriptors
# in conjunction with the self-extracting installer
my_service_install() {
  auto_install "Application requirements" "APPLICATION"
  if [ $? -ne 0 ]; then echo_failure "Failed to install prerequisites through package installer"; return 1; fi
  if [[ -n "$dpkg" && -n "$aptget" ]]; then
    is_installed=`$dpkg --get-selections | grep "${package_name_deb}" | awk '{ print $1 }'`
    if [ -n "$is_installed" ]; then
      echo "Looks like ${package_name} is already installed. Cleaning..."
      $dpkg -P ${is_installed}
    fi
    echo "Installing $DEB_PACKAGE"
    $dpkg -i $DEB_PACKAGE
    $aptget -f install
  elif [[ -n "$rpm" && -n "$yum" ]]; then
    is_installed=`$rpm -qa | grep "${package_name_rpm}"`
    if [ -n "$is_installed" ]; then
      echo "Looks like ${package_name} is already installed. Cleaning..."
      $rpm -e ${is_installed}
    fi
    echo "Installing $RPM_PACKAGE"
    $rpm -i $RPM_PACKAGE
  fi
  $package_setup_cmd
}

### FUNCTION LIBRARY: NETWORK INFORMATION

# Echo all the localhost's non-loopback IP addresses
# Parameters: None
# Output:
#   The output of "ifconfig" will be scanned for any non-loopback address and all results will be echoed
hostaddress_list() {
  # if you want to exclude certain categories, such as 192.168, add this after the 127.0.0.1 exclusion:  grep -v "^192.168."
  ifconfig=$(which ifconfig 2>/dev/null)
  ifconfig=${ifconfig:-"/sbin/ifconfig"}
  "$ifconfig" | grep "inet addr" | awk '{ print $2 }' | awk -F : '{ print $2 }' | grep -v "127.0.0.1"
}

# Echo all the localhost's addresses including loopback IP address
# Parameters: none
# output:  10.1.71.56,127.0.0.1
hostaddress_list_csv() {
  ifconfig=$(which ifconfig 2>/dev/null)
  ifconfig=${ifconfig:-"/sbin/ifconfig"}
  "$ifconfig" | grep -E "^\s*inet addr:" | awk '{ print $2 }' | awk -F : '{ print $2 }' | paste -d',' -s
}


# Echo localhost's non-loopback IP address
# Parameters: None
# Output:
#   If the environment variable HOSTADDRESS exists and has a value, its value will be used (careful to make sure it only has one address!).
#   Otherwise If the file /etc/ipaddress exists, the first line of its content will be echoed. This allows a system administrator to "override" the output of this function for the localhost.
#   Otherwise the output of "ifconfig" will be scanned for any non-loopback address and the first one will be used.
hostaddress() {
  if [ -n "$HOSTADDRESS" ]; then
    echo "$HOSTADDRESS"
  elif [ -s /etc/ipaddress ]; then
    cat /etc/ipaddress | head -n 1
  else
    # if you want to exclude certain categories, such as 192.168, add this after the 127.0.0.1 exclusion:  grep -v "^192.168."
    local HOSTADDRESS=`hostaddress_list | head -n 1`
    echo "$HOSTADDRESS"
  fi
}



### FUNCTION LIBRARY: SSH FUNCTIONS

# Displays the fingerprints of all ssh host keys on this server
ssh_fingerprints() {
  local has_ssh_keygen=`which ssh-keygen 2>/dev/null`
  if [ -z "$has_ssh_keygen" ]; then echo_warning "missing program: ssh-keygen"; return; fi
  local ssh_pubkeys=`find /etc -name ssh_host_*.pub 2>/dev/null`
  for file in $ssh_pubkeys
  do
    local keybits=`ssh-keygen -lf "$file" | awk '{ print $1 }'`
    local keyhash=`ssh-keygen -lf "$file" | awk '{ print $2 }'`
    local keytype=`ssh-keygen -lf "$file" | awk '{ print $4 }' | tr -d '()'`
    echo "$keyhash ($keytype-$keybits)"
  done
}


### FUNCTION LIBRARY: MYSQL FUNCTIONS


# parameters:
# 1. path to properties file
# 2. properties prefix (for mountwilson.as.db.user etc. the prefix is mountwilson.as.db)
# the default prefix is "mysql" for properties like "mysql.user", etc. The
# prefix must not have any spaces or special shell characters
# ONLY USE IF FILES ARE UNENCRYPTED!!!
mysql_read_connection_properties() {
    local config_file="$1"
    local prefix="${2:-mysql}"
    MYSQL_HOSTNAME=`read_property_from_file ${prefix}.host "${config_file}"`
    MYSQL_PORTNUM=`read_property_from_file ${prefix}.port "${config_file}"`
    MYSQL_USERNAME=`read_property_from_file ${prefix}.user "${config_file}"`
    MYSQL_PASSWORD=`read_property_from_file ${prefix}.password "${config_file}"`
    MYSQL_DATABASE=`read_property_from_file ${prefix}.schema "${config_file}"`
}

# ONLY USE IF FILES ARE UNENCRYPTED!!!
mysql_write_connection_properties() {
    local config_file="$1"
    local prefix="${2:-mysql}"
    local encrypted="false"

    # Decrypt if needed
    if file_encrypted "$config_file"; then
      encrypted="true"
      decrypt_file "$config_file" "$MTWILSON_PASSWORD"
    fi
    update_property_in_file ${prefix}.host "${config_file}" "${MYSQL_HOSTNAME}"
    update_property_in_file ${prefix}.port "${config_file}" "${MYSQL_PORTNUM}"
    update_property_in_file ${prefix}.user "${config_file}" "${MYSQL_USERNAME}"
    update_property_in_file ${prefix}.password "${config_file}" "${MYSQL_PASSWORD}"
    update_property_in_file ${prefix}.schema "${config_file}" "${MYSQL_DATABASE}"
    update_property_in_file ${prefix}.driver "${config_file}" "com.mysql.jdbc.Driver"
    # if you create a .url property then it takes precedence over the .host, .port, and .schema - so let user do that

    # Return the file to encrypted state, if it was before
    if [ encrypted == "true" ]; then
      encrypt_file "$config_file" "$MTWILSON_PASSWORD"
    fi
}

# parameters:
# - configuration filename (absolute path)
# - property prefix for settings in the configuration file (java format is assumed, dot will be automatically appended to prefix)
mysql_userinput_connection_properties() {
    echo "Configuring DB Connection..."
    prompt_with_default MYSQL_HOSTNAME "Hostname:" ${DEFAULT_MYSQL_HOSTNAME}
    prompt_with_default MYSQL_PORTNUM "Port Num:" ${DEFAULT_MYSQL_PORTNUM}
    prompt_with_default MYSQL_DATABASE "Database:" ${DEFAULT_MYSQL_DATABASE}
    prompt_with_default MYSQL_USERNAME "Username:" ${DEFAULT_MYSQL_USERNAME}
    prompt_with_default_password MYSQL_PASSWORD "Password:" ${DEFAULT_MYSQL_PASSWORD}
}

mysql_clear() {
  MYSQL_HOME=""
  mysql=""
}

# Environment:
# - MYSQL_REQUIRED_VERSION (or provide it as a parameter)
mysql_version() {
  local min_version="${1:-${MYSQL_REQUIRED_VERSION:-$DEFAULT_MYSQL_REQUIRED_VERSION}}"
  MYSQL_CLIENT_VERSION=""
  MYSQL_CLIENT_VERSION_OK=""
  if [ -n "$mysql" ]; then
    MYSQL_CLIENT_VERSION=`$mysql --version | sed -e 's/^.*Distrib \([0-9.]*\).*$/\1/g;'`
    if is_version_at_least "$MYSQL_CLIENT_VERSION" "${min_version}"; then
      MYSQL_CLIENT_VERSION_OK=yes
    else
      MYSQL_CLIENT_VERSION_OK=no
    fi
  fi
}

# Environment:
# - MYSQL_REQUIRED_VERSION
mysql_version_report() {
  mysql_version
  if [ "$MYSQL_CLIENT_VERSION_OK" == "yes" ]; then
    echo_success "Mysql client version $MYSQL_CLIENT_VERSION is ok"
  else
    echo_warning "Mysql client version $MYSQL_CLIENT_VERSION is not supported, minimum is ${MYSQL_REQUIRED_VERSION:-$DEFAULT_MYSQL_REQUIRED_VERSION}"
  fi
}

# Environment:
# - MYSQL_REQUIRED_VERSION
mysql_detect() {
  local min_version="${1:-${MYSQL_REQUIRED_VERSION:-$DEFAULT_MYSQL_REQUIRED_VERSION}}"
  if [[ -n "$MYSQL_HOME" && -n "$mysql" && -f "$mysql" ]]; then
    return
  fi
  mysql=`which mysql 2>/dev/null`
  if [ -e "$mysql" ]; then
    MYSQL_HOME=`dirname "$mysql"`
    echo "Found mysql client: $mysql"
    mysql_version ${min_version}
    if [ "$MYSQL_CLIENT_VERSION_OK" != "yes" ]; then
  MYSQL_HOME=''
  mysql=""
    fi
  fi
}


mysql_server_detect() {
  if [[ -n "$mysqld" && -f "$mysqld" ]]; then
    return 0
  fi
  mysql_installed=$(which mysql 2>/dev/null)
  if [ -n "$mysql_installed" ]; then
    mysqld="service mysql"
    echo "Found mysql server: $mysqld"
    return 0
  fi
  if [[ -f /usr/bin/mysqld_safe ]]; then
    mysqld="/usr/bin/mysqld_safe"
    echo "Found mysql server: $mysqld"
    return 0
  fi
  mysqld=`which mysqld_safe 2>/dev/null`
  if [[ -f "$mysqld" ]]; then
    echo "Found mysql server: $mysqld"
    return 0
  fi
  return 1
}


# must load from config file or call mysql_detect prior to calling this function
mysql_env_report() {
  echo "mysql=$mysql"
}

# Environment:
# - MYSQL_REQUIRED_VERSION
mysql_require() {
  local min_version="${1:-${MYSQL_REQUIRED_VERSION:-$DEFAULT_MYSQL_REQUIRED_VERSION}}"
  if [[ -z "$MYSQL_HOME" || -z "$mysql" || ! -f "$mysql" ]]; then
    mysql_detect ${min_version} > /dev/null
  fi
  if [[ -z "$MYSQL_HOME" || -z "$mysql" || ! -f "$mysql" ]]; then
    echo "Cannot find MySQL client version $min_version or later"
    exit 1
  fi
}



# Environment:
# - MYSQL_REQUIRED_VERSION
mysql_connection() {
  mysql_require
  mysql_connect="$mysql --batch --host=${MYSQL_HOSTNAME:-$DEFAULT_MYSQL_HOSTNAME} --port=${MYSQL_PORTNUM:-$DEFAULT_MYSQL_PORTNUM} --user=${MYSQL_USERNAME:-$DEFAULT_MYSQL_USERNAME} --password=${MYSQL_PASSWORD:-$DEFAULT_MYSQL_PASSWORD}"
}

# Environment:
# - MYSQL_REQUIRED_VERSION
# sets the is_mysql_available variable to "yes" or ""
# sets the is_MYSQL_DATABASE_created variable to "yes" or ""
mysql_test_connection() {
  mysql_connection
  is_mysql_available=""
  local mysql_test_result=`$mysql_connect -e "show databases" 2>/tmp/intel.mysql.err | grep "^${MYSQL_DATABASE}\$" | wc -l`
  if [ $mysql_test_result -gt 0 ]; then
    is_mysql_available="yes"
  fi
  mysql_connection_error=`cat /tmp/intel.mysql.err`
  rm -f /tmp/intel.mysql.err
}

# Environment:
# - MYSQL_REQUIRED_VERSION
mysql_test_connection_report() {
  echo -n "Testing database connection... "
  mysql_test_connection
  if [ -n "$is_mysql_available" ]; then
    echo "OK"
  else
    echo "FAILED"
    echo_failure "${mysql_connection_error}"
  fi
}


# Environment:
# - MYSQL_REQUIRED_VERSION
# installs mysql client programs (not the server)
# we need the mysql client to create or patch the database, but
# the server can be installed anywhere
mysql_install() {
  MYSQL_CLIENT_YUM_PACKAGES="mysql"
  MYSQL_CLIENT_APT_PACKAGES="mysql-client"
  mysql_detect > /dev/null
  if [[ -z "$MYSQL_HOME" || -z "$mysql" ]]; then
    auto_install "MySQL client" "MYSQL_CLIENT" >> $INSTALL_LOG_FILE
    if [ $? -ne 0 ]; then echo_failure "Failed to install mysql through package installer"; return 1; fi
    if [[ -z "$MYSQL_HOME" || -z "$mysql" ]]; then
      echo_failure "Unable to auto-install MySQL client" | tee -a $INSTALL_LOG_FILE
      echo "MySQL download URL:" >> $INSTALL_LOG_FILE
      echo "http://www.mysql.com/downloads/" >> $INSTALL_LOG_FILE
    fi
  else
    echo "MySQL client is already installed" >> $INSTALL_LOG_FILE
  fi
}

# Environment:
# - MYSQL_REQUIRED_VERSION
# installs mysql server
mysql_server_install() {
  MYSQL_SERVER_YUM_PACKAGES="mysql-server"
  MYSQL_SERVER_APT_PACKAGES="mysql-server"
  mysql_server_detect >> $INSTALL_LOG_FILE
  if [[ -n "$mysqld" ]]; then
    echo "MySQL server is already installed" >> $INSTALL_LOG_FILE
    return;
  fi
  if [[ -z "$mysqld" ]]; then
    auto_install "MySQL server" "MYSQL_SERVER"   >> $INSTALL_LOG_FILE
    if [ $? -ne 0 ]; then echo_failure "Failed to install mysql server through package installer"; return 1; fi
    mysql_server_detect
  fi
  if [[ -z "$mysqld" ]]; then
    MYSQL_SERVER_YUM_PACKAGES=""
    MYSQL_SERVER_APT_PACKAGES="mysql-server-5.5"
    auto_install "MySQL server" "MYSQL_SERVER"  >> $INSTALL_LOG_FILE
    if [ $? -ne 0 ]; then echo_failure "Failed to install mysql server through package installer"; return 1; fi
    mysql_server_detect
  fi
  if [[ -z "$mysqld" ]]; then
    MYSQL_SERVER_YUM_PACKAGES=""
    MYSQL_SERVER_APT_PACKAGES="mysql-server-5.1"
    auto_install "MySQL server" "MYSQL_SERVER"  >> $INSTALL_LOG_FILE
    if [ $? -ne 0 ]; then echo_failure "Failed to install mysql server through package installer"; return 1; fi
    mysql_server_detect
  fi
  if [[ -z "$mysqld" ]]; then
    echo_failure "Unable to auto-install MySQL server" | tee -a $INSTALL_LOG_FILE
    echo "MySQL download URL:"  >> $INSTALL_LOG_FILE
    echo "http://www.mysql.com/downloads/" >> $INSTALL_LOG_FILE
  fi
}

# responsible for ensuring that the connection properties in the config file
# Call this from the control script such as "asctl" before calling the other mysql_* functions
# Parameters:
# - absolute path to configuration file
# - prefix of mysql property file names (java style, dot is added automatically)
# Environment:
# - script_name such as 'asctl' or 'wlmctl'
# - intel_conf_dir (deprecated, just use absolute package_config_filename)
# - package_config_filename  (should be absolute)
mysql_configure_connection() {
    local config_file="${1:-/etc/intel/cloudsecurity/mysql.properties}"
    local prefix="${2:-mysql}"
    mysql_test_connection
    if [ -z "$is_mysql_available" ]; then
      #mysql_read_connection_properties "${config_file}" "${prefix}"
      mysql_test_connection
    fi
    while [ -n "$mysql_connection_error" ]
    do
      echo_warning "Cannot connect to MySQL: $mysql_connection_error"
      prompt_yes_no MYSQL_RETRY_CONFIGURE_AFTER_FAILURE "Do you want to configure it now?"
      if [[ "no" == "$MYSQL_RETRY_CONFIGURE_AFTER_FAILURE" ]]; then
        echo "MySQL settings are in ${package_config_filename}"
        echo "Run '${script_name} setup' after configuring to continue."
        return 1
      fi
      mysql_userinput_connection_properties
      mysql_test_connection
    done
      echo_success "Connected to database \`${MYSQL_DATABASE}\` on ${MYSQL_HOSTNAME}"
#      local should_save
#      prompt_yes_no should_save "Save in ${package_config_filename}?"
#      if [[ "yes" == "${should_save}" ]]; then
      mysql_write_connection_properties "${config_file}" "${prefix}"
#      fi
}

# before using this function, you must first set the connection variables mysql_*
# example:  mysql_run_script /path/to/statements.sql
mysql_run_script() {
  local scriptfile="${1}"
  local datestr=`date +%Y-%m-%d.%H%M`
  echo "##### [${datestr}] Script file: ${scriptfile}" >> ${mysql_setup_log}
  $mysql_connect --force ${MYSQL_DATABASE} < "${scriptfile}" 2>> ${mysql_setup_log}
}

# requires a mysql connection that can create tables and procedures inside an existing database.
# depends on mysql_* variables for the connection information.
# call mysql_configure_connection before calling this function.
# Parameters: a list of sql files to execute (absolute paths)
mysql_install_scripts() {
  local scriptlist="$@"
  mysql_test_connection
  if [ -n "$is_mysql_available" ]; then
    echo "Connected to ${MYSQL_HOSTNAME} as ${MYSQL_USERNAME}. Executing script..."
    for scriptname in $scriptlist
    do
        mysql_run_script $scriptname
    done
    return 0
  else
    echo_failure "Cannot connect to database."
    return 1
  fi
}



mysql_running() {
  MYSQL_SERVER_RUNNING=''
  if [ -n "$mysqld" ]; then
    local is_running=`$mysqld status | grep running`
    if [ -n "$is_running" ]; then
      MYSQL_SERVER_RUNNING=yes
    fi
  fi
}

mysql_running_report() {
  echo -n "Checking MySQL process... "
  mysql_running
  if [[ "$MYSQL_SERVER_RUNNING" == "yes" ]]; then
    echo_success "Running"
  else
    echo_failure "Not running"
  fi
}
mysql_start() {
  if [ -n "$mysqld" ]; then
      $mysqld start
  fi
}
mysql_stop() {
  if [ -n "$mysqld" ]; then
      $mysqld stop
  fi
}

mysql_configure_ca() {
  export mysql_ssl_ca_dir="${1:-/etc/intel/cloudsecurity/mysql-ca}"
  # derive CA settings
  export mysql_ssl_ca_key="${mysql_ssl_ca_dir}/ca.key.pem"
  export mysql_ssl_ca_cert="${mysql_ssl_ca_dir}/ca.cert.pem"
  export mysql_ssl_ca_index="${mysql_ssl_ca_dir}/index"
}

mysql_configure_ssl() {
  export mysql_ssl_dir="${1:-/etc/intel/cloudsecurity/mysql-ssl}"
}

# Parameters:
# - CA directory where private key, public key, and index is kept
mysql_create_ca() {
  mysql_configure_ca "${1:-$mysql_ssl_ca_dir}"
  # create CA
  if [ -f "${mysql_ssl_ca_key}" ]; then
    echo_warning "CA key already exists"
  else
    echo "Creating MySQL Certificate Authority..."
    mkdir -p "${mysql_ssl_ca_dir}"
    chmod 700 "${mysql_ssl_ca_dir}"
    touch "${mysql_ssl_ca_key}"
    chmod 600 "${mysql_ssl_ca_key}"
    openssl genrsa 2048 > "${mysql_ssl_ca_key}"
    openssl req -new -x509 -nodes -days 3650 -key "${mysql_ssl_ca_key}" -out "${mysql_ssl_ca_cert}" -subj "/CN=MySQL SSL CA/OU=Mt Wilson/O=Intel/C=US/"
    echo 0 > "${mysql_ssl_ca_index}"
  fi
}

# Parameters:
# - SSL request file (input)
# - SSL certificate file (output)
# - SSL CA dir
mysql_ca_sign() {
  local ssl_req="${1}"
  local ssl_cert="${2}"
  mysql_configure_ca "${3:-$mysql_ssl_ca_dir}"
  local prev_index next_index
  if [ -f "${mysql_ssl_ca_index}" ]; then
    prev_index=`cat "${mysql_ssl_ca_index}"`
    ((next_index=prev_index + 1))
  else
    echo_failure "Cannot find MySQL CA"
    return 1
  fi
  openssl x509 -req -in "${ssl_req}" -days 3650 -CA "${mysql_ssl_ca_cert}" -CAkey "${mysql_ssl_ca_key}"  -set_serial "${next_index}" -out "${ssl_cert}"
  echo "${next_index}" > "${mysql_ssl_ca_index}"
}

# Parameters:
# - SSL subject name (goes into the common name field in the certificate)
# - SSL directory where you keep server and client SSL keys and certificates
# - SSL CA directory
# Environment:
# you must have already created the CA key. the CA key information
# should be in the environment variables:
# MTWILSON_CA_KEY=/path/to/file
# MTWILSON_CA_CERT=/path/to/file
# MTWILSON_CA_PASSWORD=password
mysql_create_ssl() {
  local dname="${1}"
  mysql_configure_ssl "${2:-$mysql_ssl_dir}"
  mysql_configure_ca "${3:-$mysql_ssl_ca_dir}"
  echo "Creating MySQL SSL Certificate..."
  mkdir -p "${mysql_ssl_dir}"
  if [ -z "$dname" ]; then
    prompt_with_default MYSQL_SSL_CERT_CN "Common name (username):"
    dname=${MYSQL_SSL_CERT_CN}
  fi
  local filename=`echo "${dname}" | sed "s/[^a-zA-Z0-9-]/_/g"`
  local ssl_key="${mysql_ssl_dir}/${filename}.key.pem"
  local ssl_cert="${mysql_ssl_dir}/${filename}.cert.pem"
  openssl req -newkey rsa:1024 -days 3650 -nodes -keyout "${ssl_key}" -out "${ssl_cert}.req" -subj "/CN=${dname}/OU=Mt Wilson/O=Intel/C=US/"
  openssl rsa -in "${ssl_key}" -out "${ssl_key}"
  mysql_ca_sign "${ssl_cert}.req" "${ssl_cert}" "${mysql_ssl_ca_dir}"
  rm -rf "${ssl_cert}.req"
  # verify the certificate
  echo "Verifying SSL Certificate..."
  openssl verify -CAfile "${mysql_ssl_ca_cert}" "${ssl_cert}"
}

### FUNCTION LIBRARY: postgres


postgres_clear() {
  POSTGRES_HOME=""
  psql=""
  postgres_pghb_conf=""
  postgres_conf=""
  postgres_com=""
}

# Environment:
# - POSTGRES_REQUIRED_VERSION
postgres_version_report() {
  postgres_version
  if [ "$POSTGRES_CLIENT_VERSION_OK" == "yes" ]; then
    echo_success "Postgres client version $POSTGRES_CLIENT_VERSION is ok"
  else
    echo_warning "Postgres client version $POSTGRES_CLIENT_VERSION is not supported, minimum is ${POSTGRES_REQUIRED_VERSION:-$DEFAULT_POSTGRES_REQUIRED_VERSION}"
  fi
}

# Environment:
# - POSTGRES_REQUIRED_VERSION
# installs postgres client programs (not the server)
# we need the postgres client to create or patch the database, but
# the server can be installed anywhere
postgres_install() {
  POSTGRES_CLIENT_YUM_PACKAGES="postgresql93"
  #POSTGRES_CLIENT_APT_PACKAGES="postgresql-client-common"
  POSTGRES_CLIENT_APT_PACKAGES="postgresql-client-9.3"
  postgres_detect >> $INSTALL_LOG_FILE

  if [[ -z "$POSTGRES_HOME" || -z "$psql" ]]; then
    auto_install "Postgres client" "POSTGRES_CLIENT" >> $INSTALL_LOG_FILE
    if [ $? -ne 0 ]; then echo_failure "Failed to install postgresql client through package installer"; return 1; fi
    postgres_detect >> $INSTALL_LOG_FILE
    if [[ -z "$POSTGRES_HOME" || -z "$psql" ]]; then
      echo_failure "Unable to auto-install Postgres client" | tee -a $INSTALL_LOG_FILE
      echo "Postgres download URL:" >> $INSTALL_LOG_FILE
      echo "http://www.postgresql.org/download/" >> $INSTALL_LOG_FILE
    fi
  else
    echo "Postgres client is already installed" >> $INSTALL_LOG_FILE
    echo "Postgres client is already installed skipping..."
  fi
}

# Checks if postgresql packages need to be added to install application, and adds them
add_postgresql_install_packages() {
  local cprefix=${1}
  local yum_packages=$(eval "echo \$${cprefix}_YUM_PACKAGES")
  local apt_packages=$(eval "echo \$${cprefix}_APT_PACKAGES")
  local yast_packages=$(eval "echo \$${cprefix}_YAST_PACKAGES")
  local zypper_packages=$(eval "echo \$${cprefix}_ZYPPER_PACKAGES")

  local repo_url=
  local distro_release=
  local repo_key_path=

  # detect available package management tools. start with the less likely ones to differentiate.
  yum_detect; yast_detect; zypper_detect; rpm_detect; aptget_detect; dpkg_detect;

  echo "Checking to see if postgresql package is available for install..."
  if [[ -n "$aptget" && -n "$apt_packages" ]]; then
    pgAddPackRequired=`apt-cache search \`echo $apt_packages | cut -d' ' -f1\``
    repo_url="http://apt.postgresql.org/pub/repos/apt/"
    distro_release=`cat /etc/*-release | grep DISTRIB_CODENAME | sed 's/DISTRIB_CODENAME=//'`
    distro_release="${distro_release}-pgdg"
    repo_key_path="/etc/apt/trusted.gpg.d/ACCC4CF8.asc"
  #elif [[ -n "$yast" && -n "$yast_packages" ]]; then
    # code goes here
  elif [[ -n "$yum" && -n "$yum_packages" ]]; then
    pgAddPackRequired=$(yum list $yum_packages 2>/dev/null | grep -E 'Available Packages|Installed Packages')
    repo_url="https://download.postgresql.org/pub/repos/yum/9.3/redhat/rhel-7-x86_64/pgdg-redhat93-9.3-2.noarch.rpm"
    distro_release=
    repo_key_path=
  #elif [[ -n "$zypper" && -n "$zypper_packages" ]]; then
    # code goes here
  else
    echo_failure "Package manager not supported."
    return 2
  fi
  #if postgresql package already available, return with no error code; no need to add repo
  if [ -n "$pgAddPackRequired" ]; then
    return 0
  fi
  prompt_with_default ADD_POSTGRESQL_REPO "Add postgresql repository to local package manager? " "no"
  if [ "$ADD_POSTGRESQL_REPO" == "no" ]; then
    echo_failure "User declined to add postgresql repository to local package manager."
    return 1
  fi
  add_package_repository "${repo_url}" "${distro_release}" "${repo_key_path}"
}

# Environment:
# - POSTGRES_REQUIRED_VERSION
# installs postgres server
postgres_server_install(){
  POSTGRES_SERVER_YUM_PACKAGES="postgresql93-server pgadmin3_93 postgresql93-contrib"
  POSTGRES_SERVER_APT_PACKAGES="postgresql-9.3 pgadmin3 postgresql-contrib-9.3"

  postgres_clear; postgres_server_detect >> $INSTALL_LOG_FILE
  #echo "postgres_server_install postgres_com = $postgres_com"
  if [[ -n "$postgres_com" ]]; then
    echo "Postgres server is already installed" >> $INSTALL_LOG_FILE
    echo "Postgres server is already installed skipping..."
    return;
  fi
  if [[ -z "$postgres_com" ]]; then
    echo "Running postgresql auto install..."
    auto_install "Postgres server" "POSTGRES_SERVER"   >> $INSTALL_LOG_FILE
    if [ $? -ne 0 ]; then echo_failure "Failed to install postgresql server through package installer"; return 1; fi
    postgres_server_detect
  fi

  if [[ -z "$postgres_com" ]]; then
    echo_failure "Unable to auto-install postgresql server" | tee -a $INSTALL_LOG_FILE
    echo "Postgresql download URL:"  >> $INSTALL_LOG_FILE
    echo "http://www.postgresql.org/download/" >> $INSTALL_LOG_FILE
    return 1
  fi

  flavor=$(getFlavour)
  case $flavor in
    "rhel")
      short_version_number=$(echo $POSTGRES_SERVER_VERSION_SHORT | sed 's|\.||')
      postgresql_setup_binary=$(find / -name postgresql${short_version_number}-setup 2>/dev/null)
      $postgresql_setup_binary initdb
      systemctlCommand=`which systemctl 2>/dev/null`
      if [ -z "$systemctlCommand" ]; then
        echo_failure "Cannot find systemd binary to enable postgresql startup service"
        return 1
      fi
      "$systemctlCommand" enable "postgresql-${POSTGRES_SERVER_VERSION_SHORT}"
      "$systemctlCommand" start "postgresql-${POSTGRES_SERVER_VERSION_SHORT}"
      ;;
  esac
}

# Environment:
# - POSTGRES_REQUIRED_VERSION
postgres_detect(){
  local min_version="${1:-${POSTGRES_REQUIRED_VERSION:-$DEFAULT_POSTGRES_REQUIRED_VERSION}}"
  if [[ -n "$POSTGRES_HOME" && -n "$psql" && -f "$psql" ]]; then
    echo "postgres detected. returning..."
    return 0
  fi
  psql=`which psql 2>/dev/null`
  export psql
  echo "psql=$psql" >> $INSTALL_LOG_FILE

  if [ -e "$psql" ]; then
    POSTGRES_HOME=`dirname "$psql"`
    echo "Found postgres client: $psql" >> $INSTALL_LOG_FILE
    postgres_version ${min_version}
    if [ "$POSTGRES_CLIENT_VERSION_OK" != "yes" ]; then
      echo "postgres client version not ok. resetting psql=''"
      POSTGRES_HOME=''
      psql=""
    fi
  fi
echo "POSTGRES_CLIENT_VERSION_OK: $POSTGRES_CLIENT_VERSION_OK" >> $INSTALL_LOG_FILE
}

# instead of checking separately for pg_hba.conf, postgresql.conf, and /etc/init.d/postgresql
# this is now changed to looking for the postgres server binary and checking its version
# number. then based on its number we look for corresponding pg_hba.conf and postgresql.conf
# files as necessary.  the /etc/init.d/postgresql is always present for all versions.
postgres_server_detect() {
  local min_version="${1:-${POSTGRES_REQUIRED_VERSION:-${DEFAULT_POSTGRES_REQUIRED_VERSION}}}"
  local best_version=""
  local best_version_short=""
  local best_version_bin=""
  # best_version will have a complete version number like 9.1.9
  # best_version_short is the minor version name, for 9.1.9 it would be 9.1
  # best_version_bin is the complete path to the binary like /usr/lib/postgresql/9.1/bin/postgres

  # find candidates like /usr/lib/postgresql/9.1/bin/postgres
  postgres_candidates=$(find / -name postgres 2>/dev/null | grep bin)
  for c in $postgres_candidates
  do
    local version_name=$($c --version 2>/dev/null | head -n 1 | awk '{ print $3 }')
    local bin_dir=$(dirname $c)
    local version_dir=$(dirname $bin_dir)
    echo "postgres candidate version=$version_name" >> $INSTALL_LOG_FILE

    if is_version_at_least "$version_name" "$min_version"; then
      echo "Found postgres with version: $version_name" >> $INSTALL_LOG_FILE
      if [[ -z "$best_version" ]]; then
        echo "setting best version $best_version" >> $INSTALL_LOG_FILE
        best_version="$version_name"
        best_version_bin="$c"
        best_version_short=$(echo $version_name | sed 's/\.[0-9]*//2') #$(basename $version_dir)
      elif is_version_at_least "$version_name" "$best_version"; then
        echo "current best version $best_version" >> $INSTALL_LOG_FILE
        best_version="$version_name"
        best_version_bin="$c"
        best_version_short=$(echo $version_name | sed 's/\.[0-9]*//2') #$(basename $version_dir)
      fi
    fi
  done
  if [[ -z "$best_version" ]]; then
    echo_failure "Cannot find postgres version $min_version or later"
    postgres_clear
    return 1
  fi

  # now we have selected a postgres version so set variables accordingly
  echo "Best version of PostgreSQL: $best_version" >> $INSTALL_LOG_FILE
  POSTGRES_SERVER_VERSION="$best_version"
  POSTGRES_SERVER_BIN="$best_version_bin"
  POSTGRES_SERVER_VERSION_SHORT="$best_version_short"

  echo "server version $POSTGRES_SERVER_VERSION" >> $INSTALL_LOG_FILE
  postgresql_installed=$(which psql 2>/dev/null)
  if [ -n "$postgresql_installed" ]; then
    if yum_detect; then
      postgres_com="service postgresql-${POSTGRES_SERVER_VERSION_SHORT}"
    else
      postgres_com="service postgresql"
  fi

  local is_systemd=$($postgres_com status 2>/dev/null | grep -E 'Active:')
  if [ -n "$is_systemd" ]; then
    if service postgresql-${POSTGRES_SERVER_VERSION_SHORT} status >/dev/null 2>&1 -ne 3; then
      postgres_com="service postgresql-${POSTGRES_SERVER_VERSION_SHORT}"
	fi
  fi

  postgres_pghb_conf=$(find / -name pg_hba.conf 2>/dev/null | grep $best_version_short | head -n 1)
  postgres_conf=$(find / -name postgresql.conf 2>/dev/null | grep $best_version_short | head -n 1)
  if [ -z "$postgres_pghb_conf" ]; then postgres_pghb_conf=$(find / -name pg_hba.conf 2>/dev/null | head -n 1); fi
  if [ -z "$postgres_conf" ]; then postgres_conf=$(find / -name postgresql.conf 2>/dev/null | head -n 1); fi

  # if we run into a system where postgresql is organized differently we may need to check if these don't exist and try looking without the version number
  echo "postgres_pghb_conf=$postgres_pghb_conf" >> $INSTALL_LOG_FILE
  echo "postgres_conf=$postgres_conf" >> $INSTALL_LOG_FILE
  echo "postgres_com=$postgres_com" >> $INSTALL_LOG_FILE
  return 0
}
postgres_version(){
  local min_version="${1:-${POSTGRES_REQUIRED_VERSION:-$DEFAULT_POSTGRES_REQUIRED_VERSION}}"
  POSTGRES_CLIENT_VERSION=""
  POSTGRES_CLIENT_VERSION_OK=""

  if [ -n "$psql" ]; then
    POSTGRES_CLIENT_VERSION=`(cd /tmp && $psql --version |  head -n1 | awk '{print $3}')`
    echo "POSTGRES_CLIENT_VERSION: $POSTGRES_CLIENT_VERSION" >> $INSTALL_LOG_FILE
    if is_version_at_least "$POSTGRES_CLIENT_VERSION" "${min_version}"; then
      POSTGRES_CLIENT_VERSION_OK=yes
    else
      POSTGRES_CLIENT_VERSION_OK=no
    fi
  fi
  echo "POSTGRES_CLIENT_VERSION_OK: $POSTGRES_CLIENT_VERSION_OK" >> $INSTALL_LOG_FILE
}

# must load from config file or call postgres_detect prior to calling this function
postgres_env_report() {
  echo "psql=$psql" >> $INSTALL_LOG_FILE
}

# Environment:
# - POSTGRES_REQUIRED_VERSION
postgres_require() {
  local min_version="${1:-${POSTGRES_REQUIRED_VERSION:-$DEFAULT_POSTGRES_REQUIRED_VERSION}}"
  if [[ -z "$POSTGRES_HOME" || -z "$psql" || ! -f "$psql" ]]; then
    postgres_detect ${min_version} > /dev/null
  fi
  if [[ -z "$POSTGRES_HOME" || -z "$psql" || ! -f "$psql" ]]; then
    echo "Cannot find Postgres client version $min_version or later"
    #exit 1
  fi
}

# Environment:
# - POSTGRES_REQUIRED_VERSION\
# format like this -> psql -h 127.0.0.1 -p 5432 -d mw_as -U root -c "\l"
postgres_connection() {
  postgres_require
  postgres_connect="$psql -h ${POSTGRES_HOSTNAME:-$DEFAULT_POSTGRES_HOSTNAME} -p ${POSTGRES_PORTNUM:-$DEFAULT_POSTGRES_PORTNUM} -d ${POSTGRES_DATABASE:-$DEFAULT_POSTGRES_DATABASE} -U ${POSTGRES_USERNAME:-$DEFAULT_POSTGRES_USERNAME}"
  echo "postgres_connect=$postgres_connect" >> $INSTALL_LOG_FILE
}

# Environment:
# - POSTGRES_REQUIRED_VERSION
# sets the is_postgres_available variable to "yes" or ""
postgres_test_connection() {
  postgres_connection
  is_postgres_available=""

  #check if postgres is installed and we can connect with provided credencials
  POSTGRESS_LOG="/opt/mtwilson/logs/intel.postgres.err"
  if [ ! -f $POSTGRESS_LOG ]; then
     touch $POSTGRESS_LOG
  fi
  $psql -h ${POSTGRES_HOSTNAME:-$DEFAULT_POSTGRES_HOSTNAME} -p ${POSTGRES_PORTNUM:-$DEFAULT_POSTGRES_PORTNUM} -d ${POSTGRES_DATABASE:-$DEFAULT_POSTGRES_DATABASE} -U ${POSTGRES_USERNAME:-$DEFAULT_POSTGRES_USERNAME} -w -c "select 1" 2>$POSTGRESS_LOG >/dev/null
   if [ $? -eq 0 ]; then
    is_postgres_available="yes"
    return 0
  fi
  postgres_connection_error=`cat $POSTGRESS_LOG`

  #echo "postgres_connection_error: $postgres_connection_error"
  #rm -f /tmp/intel.postgres.err

  return 1
}

# Environment:
# - POSTGRES_REQUIRED_VERSION
postgres_test_connection_report() {
  echo -n "Testing database connection... "
  postgres_test_connection
  if [ -n "$is_postgres_available" ]; then
    echo "OK"
  else
    echo "FAILED"
    echo_failure "${postgres_connection_error}"
  fi
}

# responsible for ensuring that the connection properties in the config file
# Call this from the control script such as "asctl" before calling the other postgres_* functions
# Parameters:
# - absolute path to configuration file
# - prefix of psql property file names (java style, dot is added automatically)
# Environment:
# - script_name such as 'asctl' or 'wlmctl'
# - intel_conf_dir (deprecated, just use absolute package_config_filename)
# - package_config_filename  (should be absolute)
postgres_configure_connection() {
    local config_file="${1:-/etc/intel/cloudsecurity/postgres.properties}"
    local prefix="${2:-postgres}"
    postgres_test_connection
    if [ -z "$is_postgres_available" ]; then
      #postgres_read_connection_properties "${config_file}" "${prefix}"
      postgres_test_connection
    fi
    while [ -n "$postgres_connection_error" ]
    do
      echo_warning "Cannot connect to Postgres: $postgres_connection_error"
      prompt_yes_no POSTGRES_RETRY_CONFIGURE_AFTER_FAILURE "Do you want to configure it now?"
      if [[ "no" == "$POSTGRES_RETRY_CONFIGURE_AFTER_FAILURE" ]]; then
        echo "Postgres settings are in ${package_config_filename}"
        echo "Run '${script_name} setup' after configuring to continue."
        return 1
      fi
      postgres_userinput_connection_properties
      postgres_test_connection
    done
      echo_success "Connected to database [${POSTGRES_DATABASE}] on ${POSTGRES_HOSTNAME}" >> $INSTALL_LOG_FILE
#      local should_save
#      prompt_yes_no should_save "Save in ${package_config_filename}?"
#      if [[ "yes" == "${should_save}" ]]; then
      postgres_write_connection_properties "${config_file}" "${prefix}"
#      fi
}


# requires a postgres connection that can access the existing database, OR (if it doesn't exist)
# requires a postgres connection that can create databases and grant privileges
# call postgres_configure_connection before calling this function
postgres_create_database() {
if postgres_server_detect ; then
  #we first need to find if the user has specified a different port than the once currently configured for postgres
  if [ -n "$postgres_conf" ]; then
    current_port=`grep "port =" $postgres_conf | awk '{print $3}'`
    has_correct_port=`grep $POSTGRES_PORTNUM $postgres_conf`
    if [ -z "$has_correct_port" ]; then
      echo "Port needs to be reconfigured from $current_port to $POSTGRES_PORTNUM"
      sed -i s/$current_port/$POSTGRES_PORTNUM/g $postgres_conf
      echo "Restarting PostgreSQL for port change update to take effect."
      postgres_restart >> $INSTALL_LOG_FILE
      sleep 10
    fi
  else
    echo "warning: postgresql.conf not found" >> $INSTALL_LOG_FILE
  fi

  postgres_test_connection
  if [ -n "$is_postgres_available" ]; then
    echo_success "Database [${POSTGRES_DATABASE}] already exists"
    return 0
  else
    echo "Creating database..."
    local detect_superuser="select rolcreatedb from pg_authid where rolname = '$POSTGRES_USERNAME'"
    if [ "$(whoami)" == "root" ]; then
      user_is_superuser=$(sudo -u postgres psql postgres -c "$detect_superuser" 2>&1 | grep "(1 row)")
      if [ -z "$user_is_superuser" ]; then
        local create_user_sql="CREATE USER ${POSTGRES_USERNAME:-$DEFAULT_POSTGRES_USERNAME} WITH PASSWORD '${POSTGRES_PASSWORD:-$DEFAULT_POSTGRES_PASSWORD}';"
        sudo -u postgres psql postgres -c "${create_user_sql}" 1>/dev/null
        local superuser_sql="ALTER USER ${POSTGRES_USERNAME:-$DEFAULT_POSTGRES_USERNAME} WITH SUPERUSER;"
        sudo -u postgres psql postgres -c "${superuser_sql}" 1>/dev/null
      fi
      local create_sql="CREATE DATABASE ${POSTGRES_DATABASE:-$DEFAULT_POSTGRES_DATABASE};"
      sudo -u postgres psql postgres -c "${create_sql}" 2>/dev/null 1>/dev/null
      local grant_sql="GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DATABASE:-$DEFAULT_POSTGRES_DATABASE} TO ${POSTGRES_USERNAME:-$DEFAULT_POSTGRES_USERNAME};"
      sudo -u postgres psql postgres -c "${grant_sql}" 2>/dev/null 1>/dev/null
    else
      user_is_superuser=$(psql postgres -U "${POSTGRES_USERNAME:-$DEFAULT_POSTGRES_USERNAME}" -c "$detect_superuser" 2>&1 | grep "(1 row)")
      if [ -z "$user_is_superuser" ]; then
        echo_failure "You must make '$POSTGRES_USERNAME' postgres user a superuser as root"
        return 1
      fi
      # add additional checks here? is db created? does user have privilege for db?
    fi
  fi

  if [ "$(whoami)" == "root" ]; then
    #comment out ident line so our connection can be made
    sed -i 's|\(^host[ ]*all[ ]*all[ ]*127.0.0.1/32[ ]*ident\)|#\1|g' $postgres_pghb_conf

    postgres_pghb_conf_has_entry=$(cat $postgres_pghb_conf | grep '^host[ ]*all[ ]*all[ ]*127.0.0.1/32[ ]*password')
    if [ -z "$postgres_pghb_conf_has_entry" ]; then
      if [ -n "$postgres_pghb_conf" ]; then
        has_host=`grep "^host" $postgres_pghb_conf | grep "127.0.0.1" | grep -E "password|trust"`
        if [ -z "$has_host" ]; then
          echo host  all  all  127.0.0.1/32  password >> $postgres_pghb_conf
        fi
      else
        echo "warning: pg_hba.conf not found" >> $INSTALL_LOG_FILE
      fi
    fi
  else
    echo_warning "Following line must be in $postgres_pghb_conf: host  all  all  127.0.0.1/32  password"
  fi

  postgres_conf_has_entry=$(cat $postgres_conf | grep '^listen_addresses' | grep '127.0.0.1')
  if [ -z "$postgres_conf_has_entry" ]; then
    if [ "$(whoami)" == "root" ]; then
      if [ -n "$postgres_conf" ]; then
        has_listen_addresses=`grep "^listen_addresses" $postgres_conf`
        if [ -z "$has_listen_addresses" ]; then
          echo listen_addresses=\'127.0.0.1\' >> $postgres_conf
        fi
      else
        echo "warning: postgresql.conf not found" >> $INSTALL_LOG_FILE
      fi
    else
      echo_warning "Following line must be in $postgres_conf: listen_addresses='127.0.0.1'"
    fi
  fi

  postgres_restart >> $INSTALL_LOG_FILE
  sleep 10
  postgres_test_connection

  if [ -z "$is_postgres_available" ]; then
    echo_failure "Failed to create database."  | tee -a $INSTALL_LOG_FILE
    echo "Try to execute the following commands on the database:"  >> $INSTALL_LOG_FILE
    echo "${create_sql}" >> $INSTALL_LOG_FILE
    echo "${grant_sql}"  >> $INSTALL_LOG_FILE
    return 1
  fi
fi
}

# before using this function, you must first set the connection variables postgres_*
# example:  postgres_run_script /path/to/statements.sql
postgres_run_script() {
  local scriptfile="${1}"
  local datestr=`date +%Y-%m-%d.%H%M`
  echo "##### [${datestr}] Script file: ${scriptfile}" >> ${postgres_setup_log}
  $postgres_connect --force ${POSTGRES_DATABASE} < "${scriptfile}" 2>> ${postgres_setup_log}
}

# requires a postgres connection that can create tables and procedures inside an existing database.
# depends on postgres_* variables for the connection information.
# call postgres_configure_connection before calling this function.
# Parameters: a list of sql files to execute (absolute paths)
postgres_install_scripts() {
  local scriptlist="$@"
  postgresd_test_connection
  if [ -n "$is_postgres_available" ]; then
    echo "Connected to ${POSTGRES_HOSTNAME} as ${POSTGRES_USERNAME}. Executing script..."
    for scriptname in $scriptlist
    do
        postgres_run_script $scriptname
    done
    return 0
  else
    echo_failure "Cannot connect to database."
    return 1
  fi
}

postgres_running() {
  POSTGRES_SERVER_RUNNING=''
  if [ -n "$postgres_com" ]; then
    local is_running=`$postgres_com status | grep online`
    if [ -n "$is_running" ]; then
      POSTGRES_SERVER_RUNNING=yes
    fi
  fi
}

postgres_running_report() {
  echo -n "Checking Postgres process... "
  postgres_running
  if [[ "$POSTGRES_SERVER_RUNNING" == "yes" ]]; then
    echo_success "Running"
  else
    echo_failure "Not running"
  fi
}
postgres_restart() {
  if [ -n "$postgres_com" ]; then
      $postgres_com restart
  fi
}
postgres_start() {
  if [ -n "$postgres_com" ]; then
      $postgres_com start
  fi
}
postgres_stop() {
  if [ -n "$postgres_com" ]; then
      $postgres_com stop
  fi
}

postgres_configure_ca() {
  export postgres_ssl_ca_dir="${1:-/etc/intel/cloudsecurity/postgres-ca}"
  # derive CA settings
  export postgres_ssl_ca_key="${postgres_ssl_ca_dir}/ca.key.pem"
  export postgres_ssl_ca_cert="${postgres_ssl_ca_dir}/ca.cert.pem"
  export postgres_ssl_ca_index="${postgres_ssl_ca_dir}/index"
}

postgres_configure_ssl() {
  export postgres_ssl_dir="${1:-/etc/intel/cloudsecurity/postgres-ssl}"
}

# Parameters:
# - CA directory where private key, public key, and index is kept
postgres_create_ca() {
  postgres_configure_ca "${1:-$postgres_ssl_ca_dir}"
  # create CA
  if [ -f "${postgres_ssl_ca_key}" ]; then
    echo_warning "CA key already exists"
  else
    echo "Creating Postgres Certificate Authority..."
    mkdir -p "${postgres_ssl_ca_dir}"
    chmod 700 "${postgres_ssl_ca_dir}"
    touch "${postgres_ssl_ca_key}"
    chmod 600 "${postgres_ssl_ca_key}"
    openssl genrsa 2048 > "${postgres_ssl_ca_key}"
    openssl req -new -x509 -nodes -days 3650 -key "${postgres_ssl_ca_key}" -out "${postgres_ssl_ca_cert}" -subj "/CN=Posgres SSL CA/OU=Mt Wilson/O=Intel/C=US/"
    echo 0 > "${postgres_ssl_ca_index}"
  fi
}

# Parameters:
# - SSL request file (input)
# - SSL certificate file (output)
# - SSL CA dir
postgres_ca_sign() {
  local ssl_req="${1}"
  local ssl_cert="${2}"
  postgres_configure_ca "${3:-$postgres_ssl_ca_dir}"
  local prev_index next_index
  if [ -f "${postgres_ssl_ca_index}" ]; then
    prev_index=`cat "${postgres_ssl_ca_index}"`
    ((next_index=prev_index + 1))
  else
    echo_failure "Cannot find Postgres CA"
    return 1
  fi
  openssl x509 -req -in "${ssl_req}" -days 3650 -CA "${postgres_ssl_ca_cert}" -CAkey "${postgres_ssl_ca_key}"  -set_serial "${next_index}" -out "${ssl_cert}"
  echo "${next_index}" > "${postgres_ssl_ca_index}"
}

# Parameters:
# - SSL subject name (goes into the common name field in the certificate)
# - SSL directory where you keep server and client SSL keys and certificates
# - SSL CA directory
# Environment:
# you must have already created the CA key. the CA key information
# should be in the environment variables:
# MTWILSON_CA_KEY=/path/to/file
# MTWILSON_CA_CERT=/path/to/file
# MTWILSON_CA_PASSWORD=password
postgres_create_ssl() {
  local dname="${1}"
  postgres_configure_ssl "${2:-$postgres_ssl_dir}"
  postgres_configure_ca "${3:-$postgres_ssl_ca_dir}"
  echo "Creating Postgres SSL Certificate..."
  mkdir -p "${postgres_ssl_dir}"
  if [ -z "$dname" ]; then
    prompt_with_default POSTGRES_SSL_CERT_CN "Common name (username):"
    dname=${POSTGRES_SSL_CERT_CN}
  fi
  local filename=`echo "${dname}" | sed "s/[^a-zA-Z0-9-]/_/g"`
  local ssl_key="${postgres_ssl_dir}/${filename}.key.pem"
  local ssl_cert="${postgres_ssl_dir}/${filename}.cert.pem"
  openssl req -newkey rsa:1024 -days 3650 -nodes -keyout "${ssl_key}" -out "${ssl_cert}.req" -subj "/CN=${dname}/OU=Mt Wilson/O=Intel/C=US/"
  openssl rsa -in "${ssl_key}" -out "${ssl_key}"
  postgres_ca_sign "${ssl_cert}.req" "${ssl_cert}" "${postgres_ssl_ca_dir}"
  rm -rf "${ssl_cert}.req"
  # verify the certificate
  echo "Verifying SSL Certificate..."
  openssl verify -CAfile "${postgres_ssl_ca_cert}" "${ssl_cert}"
}


### FUNCTION LIBRARY: glassfish


function valid_ip() {
    local  ip=$1
    local  stat=1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}




### FUNCTION LIBRARY: tomcat

# tomcat

tomcat_clear() {
  TOMCAT_CONF=""
  TOMCAT_HOME=""
  tomcat_bin=""
  tomcat=""
}


tomcat_require() {
  local min_version="${1:-${tomcat_required_version:-$DEFAULT_TOMCAT_REQUIRED_VERSION}}"
  if not tomcat_ready; then
    tomcat_detect ${min_version} > /dev/null
  fi
  if not tomcat_ready; then
    echo_failure "Cannot find Tomcat server version $min_version or later"
    exit 1
  fi
}

tomcat_ready_report() {
  if [[ -z "$TOMCAT_HOME" ]]; then echo_warning "TOMCAT_HOME variable is not set"; return 1; fi
  if [[ -z "$tomcat_bin" ]]; then echo_warning "Tomcat binary path is not set"; return 1; fi
  if [[ ! -f "$tomcat_bin" ]]; then echo_warning "Cannot find Tomcat binary at $tomcat_bin"; return 1; fi
  if [[ -z "$tomcat" ]]; then echo_warning "Tomcat command is not set"; return 1; fi
  echo_success "Using Tomcat at $TOMCAT_HOME"
  return 0
}


tomcat_ready() {
  tomcat_ready_report > /dev/null
  return $?
}

# How to use;   TOMCAT_VERSION   =`tomcat_version`
# If you pass a parameter, it is the path to a tomcat "asadmin" binary
# If you do not pass a parameter, the "tomcat" variable is used as the path to the binary
tomcat_version() {
  # Either the JAVA_HOME or the JRE_HOME environment variable must be defined
  # At least one of these environment variable is needed to run this program
  if [ -z $JAVA_HOME ]; then java_detect; fi
  if [ -z $JAVA_HOME ]; then return 1; fi

  if [[ -n "$tomcat" ]]; then
    # extract the version number from a string like: tomcat version "3.0"
    local current_tomcat_version=`$tomcat version 2>&1 | grep -i "^Server version:" | grep -i version | awk -F / '{ print $2 }'`
    if [ -n "$current_tomcat_version" ]; then
      echo "current_tomcat_version: $current_tomcat_version" >> $INSTALL_LOG_FILE
      export TOMCAT_VERSION=$current_tomcat_version
      return 0
    fi
    return 2
  fi
  return 1
}

# sample output from "$tomcat version":
#Using CATALINA_BASE:   /usr/share/apache-tomcat-7.0.34
#Using CATALINA_HOME:   /usr/share/apache-tomcat-7.0.34
#Using CATALINA_TMPDIR: /usr/share/apache-tomcat-7.0.34/temp
#Using JRE_HOME:        /usr/share/jdk1.7.0_51
#Using CLASSPATH:       /usr/share/apache-tomcat-7.0.34/bin/bootstrap.jar
#Server version: Apache Tomcat/7.0.34
#Server built:   July 19 2010 1458
#Server number:  7.0.34
#OS Name:        Linux
#OS Version:     3.0.0-12-server
#Architecture:   amd64
#JVM Version:    1.7.0_51
#JVM Vendor:     Sun Microsystems Inc.


# Environment:
# - TOMCAT_REQUIRED_VERSION  (default is 7.0.34)
tomcat_version_report() {
  local min_version="${1:-${tomcat_required_version:-$DEFAULT_TOMCAT_REQUIRED_VERSION}}"
  #TOMCAT_VERSION=`tomcat_version`
  tomcat_version
  if is_version_at_least "$TOMCAT_VERSION" "${min_version}"; then
    echo_success "Tomcat version $TOMCAT_VERSION is ok"
    return 0
  else
    echo_warning "Tomcat version $TOMCAT_VERSION is not supported, minimum is ${min_version}"
    return 1
  fi
}

# detects possible tomcat installations
# does nothing if TOMCAT_HOME is already set; unset before calling to force detection
tomcat_detect() {
  local min_version="${1:-${tomcat_required_version:-${DEFAULT_TOMCAT_REQUIRED_VERSION}}}"
  java=$JAVA_CMD
  if [[ -z $JAVA_HOME || -z $java ]]; then java_detect; fi
  if [[ -z $JAVA_HOME || -z $java ]]; then return 1; fi
  if [[ -n "$java" ]]; then
    local java_bindir=`dirname "$java"`
  fi

  # start with TOMCAT_HOME if it is already configured
  if [ "$(whoami)" == "root" ]; then
    if [ -n "$TOMCAT_HOME" ] && [[ "$TOMCAT_HOME" == /opt/mtwilson* ]]; then
      tomcat_bin="$TOMCAT_HOME/bin/catalina.sh"
      if [ -z "$tomcat" ]; then
        if [ -n "$java" ]; then
          # the tomcat admin tool read timeout is in milliseconds, so 900,000 is 900 seconds
          tomcat="env PATH=$java_bindir:$PATH $tomcat_bin"
        else
          tomcat="$tomcat_bin"
        fi
      fi
      if [ -d "$TOMCAT_HOME/conf" ] && [ -f "$TOMCAT_HOME/conf/tomcat-users.xml" ] && [ -f "$TOMCAT_HOME/conf/server.xml" ]; then
        export TOMCAT_CONF="$TOMCAT_HOME/conf"
      else
        # we think we know TOMCAT_HOME but we can't find TOMCAT_CONF so
        # reset the "tomcat" variable to force a new detection below
        tomcat=""
      fi
      if [ -n "$tomcat" ]; then
        #TOMCAT_VERSION=`tomcat_version`
        tomcat_version
        if is_version_at_least "$TOMCAT_VERSION" "${min_version}"; then
          return 0
        fi
      fi
    fi
    searchdir=/
  else
    #TODO update it to $MTWILSON_HOME
    searchdir=/opt/mtwilson
  fi

  TOMCAT_CANDIDATES=`find /opt/mtwilson -name tomcat-users.xml 2>/dev/null`
  if [ -z "$TOMCAT_CANDIDATES" ]; then
    TOMCAT_CANDIDATES=`find $searchdir -name tomcat-users.xml 2>/dev/null`
  fi
  tomcat_clear
  for c in $TOMCAT_CANDIDATES; do
    if [ -z "$TOMCAT_HOME" ]; then
      local conf_dir=`dirname $c`
      local parent=`dirname $conf_dir`
      if [ -f "$parent/bin/catalina.sh" ]; then
        export TOMCAT_HOME="$parent"
        export TOMCAT_BASE="$parent"
        export TOMCAT_CONF="$conf_dir"
        tomcat_bin=$parent/bin/catalina.sh
        tomcat="env PATH=$java_bindir:$PATH JAVA_HOME=$JAVA_HOME CATALINA_HOME=$TOMCAT_HOME CATALINA_BASE=$TOMCAT_BASE CATALINA_CONF=$TOMCAT_CONF $tomcat_bin"
        echo "Found Tomcat: $TOMCAT_HOME" >> $INSTALL_LOG_FILE
        echo "tomcat=$tomcat" >> $INSTALL_LOG_FILE
        tomcat_version
        if is_version_at_least "$TOMCAT_VERSION" "${min_version}"; then
          return 0
        fi
      fi
    fi
  done
  #echo_failure "Cannot find Tomcat"
  tomcat_clear
  return 1
}



# Run this AFTER tomcat_install
# optional global variables:
#   tomcat_username (default value tomcat)
#   TOMCAT_HOME (default value /usr/share/tomcat)
# works on Debian, Ubuntu, CentOS, RedHat, SUSE
# Username should not contain any spaces or punctuation
# Optional arguments:  one or more directories for tomcat user to own
tomcat_permissions() {
  local chown_locations="$@"
  local username=${MTWILSON_USERNAME:-mtwilson}
  local user_exists=`cat /etc/passwd | grep "^${username}"`
  if [ -z "$user_exists" ]; then
	echo_failure "User [$username] does not exists"
	return 1
  fi
  local file
  for file in $(find "${chown_locations}" 2>/dev/null); do
    if [[ -n "$file" && -e "$file" ]]; then
      owner=`stat -c '%U' $file`
      if [ $owner != ${username} ]; then
        if [ -w "$file" ]; then
          chown -R "${username}:${username}" "$file"
        else
          echo_failure "Current user [$(whoami)] does not have permission to change file [$file]"
          return 1
        fi
      fi
    fi
  done
}

tomcat_running() {
  TOMCAT_RUNNING=''
  if [ -z "$TOMCAT_HOME" ]; then
    tomcat_detect 2>&1 > /dev/null
  fi
  if [ -n "$TOMCAT_HOME" ]; then
    TOMCAT_PID=$(ps gauwxx | grep java | grep "$TOMCAT_HOME" | awk '{ print $2 }')
    if [ -n "$TOMCAT_PID" ]; then
      TOMCAT_RUNNING=yes
      return 0
    fi
  fi
  return 1
}

tomcat_running_report() {
  echo -n "Checking Tomcat process... "
  if tomcat_running; then
    echo_success "Running (pid $TOMCAT_PID)"
  else
    echo_failure "Not running"
  fi
}
tomcat_start() {
  tomcat_require 2>&1 > /dev/null
  if tomcat_running; then
    echo_warning "Tomcat already running [PID: $TOMCAT_PID]"
  elif [ -n "$tomcat" ]; then
    echo -n "Waiting for Tomcat services to startup..."
    ($tomcat start &) 2>&1 > /dev/null
    while ! tomcat_running; do
      sleep 1
    done
    echo_success " Done"
  fi
}
tomcat_shutdown() {
  if tomcat_running; then
    if [ -n "$TOMCAT_PID" ]; then
      kill -9 $TOMCAT_PID 2>/dev/null
    fi
  fi
}
tomcat_stop() {
  tomcat_require 2>&1 > /dev/null
  if ! tomcat_running; then
    echo_warning "Tomcat already stopped"
  elif [ -n "$tomcat" ]; then
    echo -n "Waiting for Tomcat services to shutdown..."
    $tomcat stop 2>&1 > /dev/null
    while tomcat_running; do
      tomcat_shutdown 2>&1 > /dev/null
      sleep 3
    done
    echo_success " Done"
  fi
}
tomcat_async_stop() {
  tomcat_require 2>&1 > /dev/null
  if ! tomcat_running; then
    echo_warning "Tomcat already stopped"
  elif [ -n "$tomcat" ]; then
    echo -n "Shutting down Tomcat services in the background..."
    ($tomcat stop &) 2>&1 > /dev/null
    echo_success " Done"
  fi
}
tomcat_restart() {
  tomcat_stop
  tomcat_start
  tomcat_running_report
}
tomcat_start_report() {
  action_condition TOMCAT_RUNNING "Starting Tomcat" "tomcat_start > /dev/null; tomcat_running;"
}
tomcat_uninstall() {
  tomcat_require
  echo "Stopping Tomcat..."
  tomcat_shutdown
  # application files
  echo "Removing Tomcat in $TOMCAT_HOME..."
  rm -rf "$TOMCAT_HOME"
}

tomcat_create_ssl_cert_prompt() {
    ifconfig=$(which ifconfig 2>/dev/null)
    ifconfig=${ifconfig:-"/sbin/ifconfig"}
    prompt_yes_no TOMCAT_CREATE_SSL_CERT "Do you want to set up an SSL certificate for Tomcat?"
    echo
    if [ "${TOMCAT_CREATE_SSL_CERT}" == "yes" ]; then
      if no_java ${JAVA_REQUIRED_VERSION:-$DEFAULT_JAVA_REQUIRED_VERSION}; then echo "Cannot find Java ${JAVA_REQUIRED_VERSION:-$DEFAULT_JAVA_REQUIRED_VERSION} or later"; return 1; fi
      tomcat_require
      DEFAULT_TOMCAT_SSL_CERT_CN=`"$ifconfig" | grep "inet addr" | awk '{ print $2 }' | awk -F : '{ print $2 }' | sed -e ':a;N;$!ba;s/\n/,/g'`
      prompt_with_default TOMCAT_SSL_CERT_CN "Domain name[s] for SSL Certificate:" ${DEFAULT_TOMCAT_SSL_CERT_CN:-127.0.0.1}
      tomcat_create_ssl_cert "${TOMCAT_SSL_CERT_CN}"
    fi
}

# Parameters:
# - serverName (hostname in the URL, such as 127.0.0.1, 192.168.1.100, my.attestation.com, etc.)
tomcat_create_ssl_cert() {
  if no_java ${JAVA_REQUIRED_VERSION:-$DEFAULT_JAVA_REQUIRED_VERSION}; then echo "Cannot find Java ${JAVA_REQUIRED_VERSION:-$DEFAULT_JAVA_REQUIRED_VERSION} or later"; return 1; fi
  tomcat_require
  local serverName="${1}"
  serverName=$(echo $serverName | sed -e 's/ //g' | sed -e 's/,$//')

  local keystorePassword="$MTWILSON_TLS_KEYSTORE_PASS"   #changeit
  local keystore="${TOMCAT_HOME}/ssl/.keystore"
  local tomcatServerXml="${TOMCAT_HOME}/conf/server.xml"
  local configDir="/opt/mtwilson/configuration"
  local mtwilsonPropertiesFile="${configDir}/mtwilson.properties"
  local keytool="${JAVA_HOME}/bin/keytool"
  local mtwilson=$(which mtwilson 2>/dev/null)
  local tmpHost=$(echo "$serverName" | awk -F ',' '{ print $1 }' | sed -e 's/ //g')

  if [ -z "$MTWILSON_TLS_KEYSTORE_PASS" ] || [ "$MTWILSON_TLS_KEYSTORE_PASS" == "changeit" ]; then MTWILSON_TLS_KEYSTORE_PASS=$(generate_password 32); fi
  keystorePassword="$MTWILSON_TLS_KEYSTORE_PASS"   #changeit

  # decrypt file
  if file_encrypted "${mtwilsonPropertiesFile}"; then
    encrypted="true"
    decrypt_file "${mtwilsonPropertiesFile}" "$MTWILSON_PASSWORD"
  fi

  # read value
  keystorePasswordOld=$(read_property_from_file "mtwilson.tls.keystore.password" "${mtwilsonPropertiesFile}")

  # Return the file to encrypted state, if it was before
  if [ "$encrypted" == "true" ]; then
    encrypt_file "${mtwilsonPropertiesFile}" "$MTWILSON_PASSWORD"
  fi

  keystorePasswordOld=${keystorePasswordOld:-"changeit"}

  # Create an array of host ips and dns names from csv list passed into function
  OIFS="$IFS"
  IFS=','
  read -a hostArray <<< "${serverName}"
  IFS="$OIFS"

  # create common names and sans strings by parsing array
  local cert_cns=""
  local cert_sans=""
  for i in "${hostArray[@]}"; do
    cert_cns+="CN=$i,"
    tmpCN=""
    if valid_ip "$i"; then
      tmpCN="ip:$i"
    else
      tmpCN="dns:$i"
    fi
    cert_sans+="$tmpCN,"
  done
  cert_cns=$(echo $cert_cns | sed -e 's/,$//')
  cert_sans=$(echo $cert_sans | sed -e 's/,$//')

  mkdir -p ${TOMCAT_HOME}/ssl

  # fix for if old version of mtwilson was saving incorrect password; reverts current password to "changeit"
  has_incorrect_password=$($keytool -list -v -alias tomcat -keystore "$keystore" -storepass "$keystorePasswordOld" 2>&1 | grep "password was incorrect")
  if [ -n "$has_incorrect_password" ]; then
    keystorePasswordOld="changeit"
    has_incorrect_password=$($keytool -list -v -alias tomcat -keystore "$keystore" -storepass "$keystorePasswordOld" 2>&1 | grep "password was incorrect")
    if [ -n "$has_incorrect_password" ]; then
      echo_failure "Current SSL keystore password is incorrect"
      exit -1
    fi
  fi

  if [ "${TOMCAT_CREATE_SSL_CERT:-yes}" == "yes" ]; then
    if [ "$keystorePasswordOld" != "$keystorePassword" ]; then  # "OLD" != "NEW"
      echo "Changing keystore password and updating in Tomcat server.xml..."
      if [ -f "$keystore" ]; then
        $keytool -storepass "$keystorePasswordOld" -storepasswd -new "$keystorePassword" -keystore "$keystore"
      fi
      #sed -i.bak 's|sslProtocol=\"TLS\" />|sslEnabledProtocols=\"TLSv1,TLSv1.1,TLSv1.2\" keystoreFile=\"'"$keystore"'\" keystorePass=\"'"$keystorePassword"'\" />|g' "$tomcatServerXml"
      #sed -i 's/keystorePass=.*\b/keystorePass=\"'"$keystorePassword"'/g' "$tomcatServerXml"
      xmlstarlet ed --inplace --delete '/Server/Service/Connector[@SSLEnabled="true"][@protocol="HTTP/1.1"]/@sslProtocol' "$tomcatServerXml"
      xmlstarlet ed --inplace --insert '/Server/Service/Connector[@SSLEnabled="true"][@protocol="HTTP/1.1"][not(@sslEnabledProtocols)]' --type attr -n sslEnabledProtocols -v 'TLSv1.2' "$tomcatServerXml"
      xmlstarlet ed --inplace --insert '/Server/Service/Connector[@SSLEnabled="true"][@protocol="HTTP/1.1"][not(@keystoreFile)]' --type attr -n keystoreFile -v "$keystore" "$tomcatServerXml"
      xmlstarlet ed --inplace --insert '/Server/Service/Connector[@SSLEnabled="true"][@protocol="HTTP/1.1"][not(@keystorePass)]' --type attr -n keystorePass -v "$keystorePassword" "$tomcatServerXml"
      #update for upgrades; attribute already exists
      xmlstarlet ed --inplace --update '/Server/Service/Connector[@SSLEnabled="true"][@protocol="HTTP/1.1"]/@sslEnabledProtocols' -v 'TLSv1.2' "$tomcatServerXml"
      xmlstarlet ed --inplace --update '/Server/Service/Connector[@SSLEnabled="true"][@protocol="HTTP/1.1"]/@keystoreFile' -v "$keystore" "$tomcatServerXml"
      xmlstarlet ed --inplace --update '/Server/Service/Connector[@SSLEnabled="true"][@protocol="HTTP/1.1"]/@keystorePass' -v "$keystorePassword" "$tomcatServerXml"

      echo "Restarting Tomcat as a new Tomcat keystore password was set..."
      tomcat_restart >/dev/null
      update_property_in_file "mtwilson.tls.keystore.password" "${mtwilsonPropertiesFile}" "$keystorePassword"
    fi

    echo "Creating SSL Certificate for ${serverName}..."
    # Delete public insecure certs within keystore.jks and cacerts.jks
    $keytool -delete -alias tomcat -keystore "$keystore" -storepass "$keystorePassword" 2>&1 >/dev/null

    # Update keystore.jks
    $keytool -genkeypair -alias tomcat -dname "$cert_cns, OU=Mt Wilson, O=Trusted Data Center, C=US" -ext san="$cert_sans" -keyalg RSA -keysize 2048 -validity 3650 -keystore "$keystore" -keypass "$keystorePassword" -storepass "$keystorePassword"

    echo "Restarting Tomcat as a new SSL certificate was generated..."
    tomcat_restart >/dev/null
  fi

  has_cert=$($keytool -list -v -alias tomcat -keystore "$keystore" -storepass "$keystorePassword" | grep "^Owner:" | grep "$tmpHost")
  if [ -n "$has_cert" ]; then
    $keytool -export -alias tomcat -file "${TOMCAT_HOME}/ssl/ssl.${tmpHost}.crt" -keystore $keystore -storepass "$keystorePassword"
    openssl x509 -in "${TOMCAT_HOME}/ssl/ssl.${tmpHost}.crt" -inform der -out "$configDir/ssl.crt.pem" -outform pem
    cp "${TOMCAT_HOME}/ssl/ssl.${tmpHost}.crt" "$configDir/ssl.crt"
    cp "$keystore" "$configDir/mtwilson-tls.jks"
    mtwilson_tls_cert_sha1=`openssl sha1 -hex "$configDir/ssl.crt" | awk -F '=' '{ print $2 }' | tr -d ' '`
    update_property_in_file "mtwilson.api.tls.policy.certificate.sha1" "$configDir/mtwilson.properties" "$mtwilson_tls_cert_sha1"
    mtwilson_tls_cert_sha256=`openssl sha256 -hex "$configDir/ssl.crt" | awk -F '=' '{ print $2 }' | tr -d ' '`
    update_property_in_file "mtwilson.api.tls.policy.certificate.sha256" "$configDir/mtwilson.properties" "$mtwilson_tls_cert_sha256"
else
    echo_warning "No SSL certificate found in Tomcat keystore"
  fi
}
tomcat_env_report(){
  echo "TOMCAT_HOME=$TOMCAT_HOME"
  echo "tomcat_bin=$tomcat_bin"
  echo "tomcat=\"$tomcat\""
}

# Must call java_require before calling this.
# Parameters:
# - certificate alias to report on (default is tomcat, the tomcat default ssl cert alias)
tomcat_sslcert_report() {
  local alias="${1:-tomcat}"
  local keystorePassword="${MTWILSON_TLS_KEYSTORE_PASSWORD:-$MTW_TLS_KEYSTORE_PASS}"
  local keystore=${TOMCAT_HOME}/ssl/.keystore
  java_keystore_cert_report "$keystore" "$keystorePassword" "$alias"
}

tomcat_init_manager() {
  local config_file=/opt/mtwilson/configuration/mtwilson.properties
  TOMCAT_MANAGER_USER=""
  TOMCAT_MANAGER_PASS=""
  TOMCAT_MANAGER_PORT=""
  if [ -z "$WEBSERVICE_MANAGER_USERNAME" ]; then WEBSERVICE_MANAGER_USERNAME=admin; fi
  if [ -z "$TOMCAT_HOME" ]; then tomcat_detect; fi
  TOMCAT_MANAGER_USER=`read_property_from_file tomcat.admin.username "${config_file}"`
  TOMCAT_MANAGER_PASS=`read_property_from_file tomcat.admin.password "${config_file}"`
  if [[ -z "$TOMCAT_MANAGER_USER" ]]; then
    tomcat_manager_xml=`grep "username=\"$WEBSERVICE_MANAGER_USERNAME\"" $TOMCAT_HOME/conf/tomcat-users.xml | head -n 1`

    OIFS="$IFS"
    IFS=' '
    read -a managerArray <<< "${tomcat_manager_xml}"
    IFS="$OIFS"

    for i in "${managerArray[@]}"; do
      if [[ "$i" == *"username"* ]]; then
        TOMCAT_MANAGER_USER=`echo $i|awk -F'=' '{print $2}'|sed 's/^"\(.*\)"$/\1/'`
      fi

      if [[ "$i" == *"password"* ]]; then
        TOMCAT_MANAGER_PASS=`echo $i|awk -F'=' '{print $2}'|sed 's/^"\(.*\)"$/\1/'`
      fi
    done
  fi

  # get manager port
  tomcat_managerPort_xml=`cat $TOMCAT_HOME/conf/server.xml|
    awk 'in_comment&&/-->/{sub(/([^-]|-[^-])*--+>/,"");in_comment=0}
    in_comment{next}
    {gsub(/<\!--+([^-]|-[^-])*--+>/,"");
    in_comment=sub(/<\!--+.*/,"");
    print}'|
    grep "<Connector"|grep "port="|head -n1`

  OIFS="$IFS"
  IFS=' '
  read -a managerPortArray <<< "${tomcat_managerPort_xml}"
  IFS="$OIFS"

  for i in "${managerPortArray[@]}"; do
    if [[ "$i" == *"port"* ]]; then
      TOMCAT_MANAGER_PORT=`echo $i|awk -F'=' '{print $2}'|sed 's/^"\(.*\)"$/\1/'`
    fi
  done

  test=`wget http://$TOMCAT_MANAGER_USER:$TOMCAT_MANAGER_PASS@127.0.0.1:$TOMCAT_MANAGER_PORT/manager/text/list -O - -q --no-check-certificate --no-proxy|grep "OK"`

  if [ -n "$test" ]; then
    echo_success "Tomcat manger connection success."
  else
    echo_failure "Tomcat manager connection failed. Incorrect credentials."
  fi
}

tomcat_no_additional_webapps_exist() {
  if [ -z "$TOMCAT_HOME" ]; then tomcat_detect; fi
  if [ -z "$TOMCAT_HOME" ]; then return 1; fi
  TOMCAT_ADDITIONAL_APPLICATIONS_INSTALLED=$(ls "$TOMCAT_HOME/webapps" | sed '/^docs$\|^examples$\|^host-manager$\|^manager$\|^ROOT$\|^$/d')
  if [ -n "$TOMCAT_ADDITIONAL_APPLICATIONS_INSTALLED" ]; then
    return 1
  fi
  return 0
}

tomcat_no_additional_webapps_exist_wait() {
  tomcat_no_additional_webapps_exist
  if [[ "$TOMCAT_ADDITIONAL_APPLICATIONS_INSTALLED" == *".war"* ]]; then
    echo_warning "Additional tomcat webapps exist: $TOMCAT_ADDITIONAL_APPLICATIONS_INSTALLED"
    return 1
  fi
  echo -n "Checking if additional tomcat webapps exist..."
  for (( c=1; c<=10; c++ )); do
    if ! tomcat_no_additional_webapps_exist; then
      echo -n "."
      sleep 3
    fi
  done
  if [ -n "$TOMCAT_ADDITIONAL_APPLICATIONS_INSTALLED" ]; then
    echo
    echo_warning "Additional tomcat webapps exist: $TOMCAT_ADDITIONAL_APPLICATIONS_INSTALLED"
    return 1
  else
    echo
    return 0
  fi
}

### FUNCTION LIBRARY: jetty


jetty_running() {
  JETTY_RUNNING=''
  if [ -n "$MTWILSON_HOME" ]; then
    JETTY_PID=`ps gauwxx | grep java | grep -v grep | grep "$MTWILSON_HOME" | awk '{ print $2 }'`
    echo JETTY_PID: $JETTY_PID >> $INSTALL_LOG_FILE
    if [ -n "$JETTY_PID" ]; then
      JETTY_RUNNING=yes
      echo JETTY_RUNNING: $JETTY_RUNNING >> $INSTALL_LOG_FILE
      return 0
    fi
  fi
  return 1
}

jetty_running_report() {
  echo -n "Checking Mt Wilson process... "
  if jetty_running; then
    echo_success "Running (pid $JETTY_PID)"
  else
    echo_failure "Not running"
  fi
}
jetty_start() {
  jetty_require 2>&1 > /dev/null
  if jetty_running; then
    echo_warning "Jetty already running [PID: $JETTY_PID]"
  elif [ -n "$jetty" ]; then
    echo -n "Waiting for Mt Wilson services to startup..."
    # default is /opt/mtwilson/java
    local java_lib_dir=${MTWILSON_JAVA_DIR:-$DEFAULT_MTWILSON_JAVA_DIR}
    if no_java ${JAVA_REQUIRED_VERSION:-$DEFAULT_JAVA_REQUIRED_VERSION}; then echo "Cannot find Java ${JAVA_REQUIRED_VERSION:-$DEFAULT_JAVA_REQUIRED_VERSION} or later"; return 1; fi
    local mtwilson_jars=$(JARS=($java_lib_dir/*.jar); IFS=:; echo "${JARS[*]}")
    mainclass=com.intel.mtwilson.launcher.console.Main
    local jvm_memory=2048m
    { $java -Xmx${jvm_memory} -cp "$mtwilson_jars" -Dlogback.configurationFile=${conf_dir:-$DEFAULT_MTWILSON_CONF_DIR}/logback-stderr.xml $mainclass $@ | grep -vE "^\[EL Info\]|^\[EL Warning\]" ; } 2> /var/log/mtwilson.log
    return $?
  fi
}

jetty_shutdown() {
  if jetty_running; then
    if [ -n "$JETTY_PID" ]; then
      kill -9 $JETTY_PID
    fi
  fi
}
jetty_stop() {
  if ! jetty_running; then
    echo_warning "Mt Wilson already stopped"
  else
    echo -n "Waiting for Mt Wilson services to shutdown..."
    while jetty_running; do
      jetty_shutdown 2>&1 > /dev/null
      sleep 3
    done
    echo_success " Done"
  fi
}
jetty_restart() {
  jetty_stop
  jetty_start
  jetty_running_report
}
jetty_start_report() {
  action_condition TOMCAT_RUNNING "Starting Mt Wilson" "jetty_start > /dev/null; jetty_running;"
}

### FUNCTION LIBRARY: java

java_clear() {
  JAVA_HOME=""
  java=""
  JAVA_VERSION=""
}

# Returns success (0) if the JAVA_HOME and java variables are set and if the java binary exists.
# Returns error (1) otherwise and displays the issue as a warning.
# Quick and repeatable. No side effects.
# Example:   if not java_ready; then java_ready_report; fi
# Note: We do NOT check JAVA_VERSION here because if someone has configured a specific Java they want to use,
# we don't care what version it is as long as it is present.  In contrast, the java_detect function sets JAVA_VERSION
java_ready_report() {
  if [[ -z "$JAVA_HOME" ]]; then echo_warning "JAVA_HOME variable is not set"; return 1; fi
  if [[ -z "$java" ]]; then echo_warning "Java binary path is not set"; return 1; fi
  if [[ ! -f "$java" ]]; then echo_warning "Cannot find Java binary at $java"; return 1; fi
  echo_success "Using Java at $java"
  return 0
}

# Returns success (0) if the JAVA_HOME and java variables are set and if the java binary exists.
# Returns error (1) otherwise.
# Quick and repeatable. No side effects.
# Example:   if java_ready; then $java -jar start.jar; fi
java_ready() {
  java_ready_report > /dev/null
  return $?
}


# prints the current java version
# return codes:
# 0 - success
# 1 - java command not found
# 2 - cannot get version number using java command
# Environment:
# - java  (path to java binary) you can get it by calling java_detect
#    (or if you are calling this from java_detect you set it yourself)
java_version() {
  if [ -n "$java" ]; then
    # extract the version number from a string like: java version "1.7.0_51"
    local current_java_version=`java -version 2>&1 | head -n 1 | sed -e 's/"//g' | awk '{ print $3 }'`
    if [ -n "$current_java_version" ]; then
      echo $current_java_version
      return 0
    fi
    return 2
  fi
  return 1
}

# Environment:
# - JAVA_REQUIRED_VERSION
java_version_report() {
  local min_version="${1:-${JAVA_REQUIRED_VERSION:-${DEFAULT_JAVA_REQUIRED_VERSION}}}"
  local current_version=`java_version`
  if is_java_version_at_least "$current_version" "${min_version}"; then
    echo_success "Java version $current_version is ok"
    return 0
  else
    echo_warning "Java version $current_version is not supported, minimum is ${min_version}"
    return 1
  fi
}


# detects possible java installations
# does nothing if JAVA_HOME is already set; unset before calling to force detection
# uses the first installation found that meets the version requirement.
# prefers JDK over JRE installations, and prefers JRE over system-provided java
# This is not because JDK is better than JRE is better than system-provided java,
# but because if the system administrator has bothered to install the JDK or JRE
# it's clear he prefers to use that over the system-provided java.
# Environment:
# - JAVA_REQUIRED_VERSION should be set like 1.7 or 1.7.0_51 ; if not set then DEFAULT_JAVA_REQUIRED_VERSION is used
# Return code:  0 if java matching minimum version is found, 1 otherwise
# Postcondition:  on success, JAVA_HOME, java, and JAVA_VERSION are set;  on failure to find java they are cleared
java_detect() {
  local min_version="${1:-${JAVA_REQUIRED_VERSION:-${DEFAULT_JAVA_REQUIRED_VERSION}}}"
  local searchDirectory="${2:-/}"
  # start with JAVA_HOME if it is already configured
  if [[ -n "$JAVA_HOME" ]]; then
    if [[ -z "$java" ]]; then
      java=${JAVA_HOME}/bin/java
    fi
    JAVA_VERSION=`java_version`
    if is_java_version_at_least "$JAVA_VERSION" "${min_version}"; then
      return 0
    fi
  fi

    JAVA_JDK_CANDIDATES=`find "$searchDirectory" -name java 2>/dev/null | grep jdk | grep -v jre | grep bin/java`
    for c in $JAVA_JDK_CANDIDATES
    do
        local java_bindir=`dirname "$c"`
        if [ -f "$java_bindir/java" ]; then
          export JAVA_HOME=`dirname "$java_bindir"`
          java=$c
          JAVA_VERSION=`java_version`
          echo "Found Java: $JAVA_HOME" >> $INSTALL_LOG_FILE
          if is_java_version_at_least "$JAVA_VERSION" "${min_version}"; then
            return 0
          fi
        fi
    done

    echo "Cannot find JDK"

    JAVA_JRE_CANDIDATES=`find "$searchDirectory" -name java 2>/dev/null | grep jre | grep bin/java`
    for c in $JAVA_JRE_CANDIDATES
    do
        java_bindir=`dirname "$c"`
        if [ -f "$java_bindir/java" ]; then
          export JAVA_HOME=`dirname "$java_bindir"`
          java=$c
          JAVA_VERSION=`java_version`
          echo "Found Java: $JAVA_HOME" >> $INSTALL_LOG_FILE
          if is_java_version_at_least "$JAVA_VERSION" "${min_version}"; then
            return 0
          fi
        fi
    done


    echo "Cannot find JRE"

    JAVA_BIN_CANDIDATES=`find "$searchDirectory" -name java 2>/dev/null | grep bin/java`
    for c in $JAVA_BIN_CANDIDATES
    do
        java_bindir=`dirname "$c"`
        # in non-JDK and non-JRE folders the "java" command may be a symlink:
        if [ -f "$java_bindir/java" ]; then
          export JAVA_HOME=`dirname "$java_bindir"`
          java=$c
          JAVA_VERSION=`java_version`
          echo "Found Java: $c" >> $INSTALL_LOG_FILE
          if is_java_version_at_least "$JAVA_VERSION" "${min_version}"; then
            return 0
          fi
        elif [ -h "$java_bindir/java" ]; then
          local javatarget=`readlink $c`
          if [ -f "$javatarget" ]; then
            java_bindir=`dirname "$javatarget"`
            export JAVA_HOME=`dirname "$java_bindir"`
            java=$javatarget
            JAVA_VERSION=`java_version`
            echo "Found Java: $java" >> $INSTALL_LOG_FILE
            if is_java_version_at_least "$JAVA_VERSION" "${min_version}"; then
              return 0
            fi
          else
            echo_warning "Broken link $c -> $javatarget"
          fi
        fi
    done

    echo "Cannot find system Java"

  echo_failure "Cannot find Java"
  java_clear
  return 1
}

# must load from config file or call java_detect prior to calling this function
java_env_report() {
  echo "JAVA_HOME=$JAVA_HOME"
  echo "java_bindir=$java_bindir"
  echo "java=$java"
}


# if java home and java bin are already configured and meet the minimum version, does nothing
# if they are not configured it initiates java detect to find them
# if
# Environment:
# - JAVA_REQUIRED_VERSION in the format "1.7.0_51" (or pass it as a parameter)
java_require() {
  local min_version="${1:-${JAVA_REQUIRED_VERSION:-${DEFAULT_JAVA_REQUIRED_VERSION}}}"
  if [[ -z "$JAVA_HOME" || -z "$java" || ! -f "$java" ]]; then
    java_detect ${min_version} > /dev/null
  fi
  JAVA_VERSION=`java_version`
  if is_java_version_at_least "$JAVA_VERSION" "${min_version}"; then
    return 0
  fi
  echo_failure "Cannot find Java version $min_version or later"
  return 1
}

# usage:  if no_java 1.7; then echo_failure "Cannot find Java"; exit 1; fi
no_java() {
  java_require $1
  if [ $? -eq 0 ]; then return 1; else return 0; fi
}

# Environment:
# - JAVA_REQUIRED_VERSION in the format "1.7.0_51"
java_install_openjdk() {
echo "Installing Java from pacakage manager..." >> $INSTALL_LOG_FILE
if [ "$(whoami)" == "root" ]; then
  JAVA_YUM_PACKAGES="java-1.8.0-openjdk-devel"
  JAVA_APT_PACKAGES="openjdk-8-jdk"
  JAVA_YAST_PACKAGES=""
  JAVA_ZYPPER_PACKAGES="java-1.8.0-openjdk-headless.x86_64"
  aptget_detect
  if [[ -n "$aptget" && -n "$JAVA_APT_PACKAGES" ]]; then
    PROPERTIES_APT_PACKAGES="software-properties-common"
	auto_install "Software Properties Common" "PROPERTIES"
	# Note: We could also refactor function 'add_package_repository' to perform below steps
	add-apt-repository ppa:openjdk-r/ppa -y
	apt-get update
  fi
  auto_install "Installer requirements" "JAVA"
  if [ $? -ne 0 ]; then echo_failure "Failed to install prerequisites through package installer"; exit -1; fi
else
  echo_warning "You must be root to install Java through package manager"
fi
# Set Java related varibales
java=$(type -p java | xargs readlink -f)
JAVA_CMD=$java
java_bindir=$(dirname $JAVA_CMD)
}

java_install() {
  local JAVA_PACKAGE="${1-:jdk-7u51-linux-x64.tar.gz}"
#  JAVA_YUM_PACKAGES="java-1.7.0-openjdk java-1.7.0-openjdk-devel"
#  JAVA_APT_PACKAGES="openjdk-7-jre openjdk-7-jdk"
#  auto_install "Java" "JAVA"
  if [ -n "$FORCE_JAVA_HOME" ]; then
    JAVA_HOME=$FORCE_JAVA_HOME
    java_install_in_home $JAVA_PACKAGE
    return $?
  else
    java_clear; java_detect >> $INSTALL_LOG_FILE
  fi
  if no_java ${JAVA_REQUIRED_VERSION:-$DEFAULT_JAVA_REQUIRED_VERSION} >> $INSTALL_LOG_FILE; then
    if [[ -z "$JAVA_PACKAGE" || ! -f "$JAVA_PACKAGE" ]]; then
      echo_failure "Missing Java installer: $JAVA_PACKAGE" | tee -a
      return 1
    fi
    local javafile=$JAVA_PACKAGE
    echo "Installing $javafile"  >> $INSTALL_LOG_FILE
    is_targz=`echo $javafile | grep -E ".tar.gz$|.tgz$"`
    is_gzip=`echo $javafile | grep ".gz$"`
    is_bin=`echo $javafile | grep ".bin$"`
    javaname=`echo $javafile | awk -F . '{ print $1 }'`
    if [ -n "$is_targz" ]; then
      tar xzvf $javafile 2>&1 >> $INSTALL_LOG_FILE
    elif [ -n "$is_gzip" ]; then
      gunzip $javafile 2>&1 >/dev/null  >> $INSTALL_LOG_FILE
      chmod +x $javaname
      ./$javaname | grep -vE "inflating:|creating:|extracting:|linking:|^Creating"
    elif [ -n "$is_bin" ]; then
      chmod +x $javafile
      ./$javafile | grep -vE "inflating:|creating:|extracting:|linking:|^Creating"
    fi
    # java gets unpacked in current directory but they cleverly
    # named the folder differently than the archive, so search for it:
    local java_unpacked=`ls -1d jdk* jre* 2>/dev/null`
    for f in $java_unpacked
    do
      #echo "$f"
      if [ -d "$f" ]; then
        if [ -d "/usr/share/$f" ]; then
          echo "Java already installed at /usr/share/$f"
          export JAVA_HOME="/usr/share/$f"
        else
          mv "$f" /usr/share && export JAVA_HOME="/usr/share/$f"
        fi
      fi
    done
    java_detect  >> $INSTALL_LOG_FILE
    if [[ -z "$JAVA_HOME" || -z "$java" ]]; then
      echo_failure "Unable to auto-install Java" | tee -a $INSTALL_LOG_FILE
      echo "  Java download URL:"                >> $INSTALL_LOG_FILE
      echo "  http://www.java.com/en/download/"  >> $INSTALL_LOG_FILE
    fi
  else
    echo "Java is already installed"              >> $INSTALL_LOG_FILE
  fi
}

# the JAVA_HOME variable must be set as the destination to which we will
# install java;  if java is already there we skip installation - upgrade
# is not supported by this function
java_install_in_home() {
  local java_package=$1
  # validate inputs
  if [ -z "$java_package" ]; then
    echo_failure "Cannot install Java: missing package name"
    return 2
  elif [ ! -f "$java_package" ]; then
    echo_failure "Cannot install Java: missing file: $java_package"
    return 3
  elif [ -z "$JAVA_HOME" ]; then
    echo_failure "Cannot install Java: variable JAVA_HOME not set"
    return 4
  elif [ -d "$JAVA_HOME" ] && [ ! -w "$JAVA_HOME" ]; then
    echo_failure "Cannot install Java: directory $JAVA_HOME not writable"
    return 5
  elif [ -d "$JAVA_HOME" ] && [ $(ls -1 $JAVA_HOME | wc -l) -gt 0 ]; then
    echo_warning "Java already installed at $JAVA_HOME"
    java_bindir=$JAVA_HOME/bin
    java=$java_bindir/java
    JAVA_CMD=$java
    return 6
  fi

  mkdir -p $JAVA_HOME
  if [ $? -ne 0 ]; then
    echo_failure "Cannot install Java: parent directory $(dirname $JAVA_HOME) not writable"
    return 7
  fi
  rmdir $JAVA_HOME

  # unpack the java archive
    is_targz=`echo $java_package | grep "\.tar.gz$"`
    is_gzip=`echo $java_package | grep "\.gz$"`
    is_bin=`echo $java_package | grep "\.bin$"`
    javaname=`echo $java_package | awk -F . '{ print $1 }'`
    if [ -n "$is_targz" ]; then
      tar xzvf $java_package 2>&1 >> $INSTALL_LOG_FILE
    elif [ -n "$is_gzip" ]; then
      gunzip $java_package 2>&1 >/dev/null  >> $INSTALL_LOG_FILE
      chmod +x $javaname
      ./$javaname | grep -vE "inflating:|creating:|extracting:|linking:|^Creating"
    elif [ -n "$is_bin" ]; then
      chmod +x $java_package
      export FORCE_JAVA_HOME=$JAVA_HOME
      ./$java_package | grep -vE "inflating:|creating:|extracting:|linking:|^Creating"
      return
    fi
    # java gets unpacked in current directory but they cleverly
    # named the folder differently than the archive, so search for it:
    local java_unpacked=`ls -1d jdk* jre* 2>/dev/null`
    for f in $java_unpacked
    do
      if [ -d "$f" ]; then
        mv "$f" $(dirname $JAVA_HOME)
        echo "Installed Java in $JAVA_HOME"
        java_bindir=$JAVA_HOME/bin
        java=$java_bindir/java
        JAVA_CMD=$java
        return 0
      fi
    done
    echo_failure "Cannot install Java: error after unpacking"
    return 1
}

java_keystore_cert_report() {
  local keystore="${1:-keystore.jks}"
  local keystorePassword="${2:-changeit}"
  local alias="${3:-s1as}"
  local keytool=${JAVA_HOME}/bin/keytool
  local owner_expires=`$keytool -list -v -alias $alias -keystore $keystore -storepass $keystorePassword | grep -E "^Owner|^Valid"`
  echo "$owner_expires"
  local fingerprints=`$keytool -list -v -alias $alias -keystore $keystore -storepass $keystorePassword | grep -E "MD5:|SHA256:"`
  echo "$fingerprints"
}


### FUNCTION LIBARARY: prerequisites reporting


# environment dependencies report
print_env_summary_report() {
  echo "Requirements summary:"
  local error=0
  if [ -n "$JAVA_HOME" ]; then
    echo "Java: $JAVA_VERSION"
  else
    echo_failure "Java: not found"
    error=1
  fi
  if using_mysql; then
    if [ -n "$MYSQL_HOME" ]; then
      echo "Mysql: $MYSQL_CLIENT_VERSION"
    else
      echo_failure "Mysql: not found"
      error=1
    fi
  fi
  if using_postgres; then
    if [ -n "$POSTGRES_HOME" ]; then
      echo "Postgres: $POSTGRES_CLIENT_VERSION"
    else
      echo_failure "Postgres: not found"
      error=1
    fi
  fi

  if using_tomcat; then
    if [ -n "$TOMCAT_HOME" ]; then
      echo "Tomcat: $TOMCAT_CLIENT_VERSION"
    else
      echo_failure "Tomcat: not found"
      error=1
    fi
  fi
  return $error
}

mtwilson_running() {
  echo "Checking if mtwilson is running." >> $INSTALL_LOG_FILE
  MTWILSON_API_BASEURL=${MTWILSON_API_BASEURL:-"https://127.0.0.1:8443/mtwilson/v2"}
  MTWILSON_RUNNING=""

  MTWILSON_API_BASEURL_V2=`echo $MTWILSON_API_BASEURL | sed 's/\/mtwilson\/v1/\/mtwilson\/v2/'`
  MTWILSON_RUNNING=`wget $MTWILSON_API_BASEURL_V2/version -O - -q --no-check-certificate --no-proxy`
}

mtwilson_running_report() {
  echo -n "Checking if mtwilson is running... "
  mtwilson_running
  if [ -n "$MTWILSON_RUNNING" ]; then
    echo_success "Running"
  else
    echo_failure "Not running"
  fi
}

mtwilson_running_report_wait() {
  echo -n "Checking if mtwilson is running..."
  mtwilson_running
  for (( c=1; c<=120; c++ ))
  do
    if [ -z "$MTWILSON_RUNNING" ]; then
      echo -n "."
      sleep 5
      mtwilson_running
    fi
  done
  if [ -n "$MTWILSON_RUNNING" ]; then
    echo_success "Running"
  else
    echo_failure "Not running"
  fi
}

tagent_running() {
  TRUSTAGENT_API_BASEURL=${TRUSTAGENT_API_BASEURL:-"https://127.0.0.1:1443/v2"}
  TRUSTAGENT_RUNNING=""
  TRUSTAGENT_RUNNING=$(wget $TRUSTAGENT_API_BASEURL/version -O - -q --no-check-certificate --no-proxy)
}

tagent_running_report() {
  echo -n "Checking if trust agent is running... "
  tagent_running
  if [ -n "$TRUSTAGENT_RUNNING" ]; then
    echo_success "Running"
  else
    echo_failure "Not running"
  fi
}

tagent_running_report_wait() {
  echo -n "Checking if trust agent is running..."
  tagent_running
  for (( c=1; c<=120; c++ ))
  do
    if [ -z "$TRUSTAGENT_RUNNING" ]; then
      echo -n "."
      sleep 5
      tagent_running
    fi
  done
  if [ -n "$TRUSTAGENT_RUNNING" ]; then
    echo_success "Running"
  else
    echo_failure "Not running"
  fi
}

### FUNCTION LIBRARY: web service on top of web server

# parameters: webservice_application_name such as "AttestationService"
webservice_running() {
  local webservice_application_name="$1"

  echo "webservice_application_name: $webservice_application_name" >> $INSTALL_LOG_FILE
  MTWILSON_SERVER=${MTWILSON_SERVER:-127.0.0.1}
  WEBSERVICE_RUNNING=""
  WEBSERVICE_DEPLOYED=""


  if using_tomcat; then
    tomcat_running
    echo "TOMCAT_RUNNING: $TOMCAT_RUNNING" >> $INSTALL_LOG_FILE
    if [ -z "$TOMCAT_MANAGER_USER" ]; then tomcat_init_manager 2>&1 >/dev/null; fi
    if [ -n "$TOMCAT_RUNNING" ]; then
      WEBSERVICE_DEPLOYED=$(wget http://$TOMCAT_MANAGER_USER:$TOMCAT_MANAGER_PASS@$MTWILSON_SERVER:$TOMCAT_MANAGER_PORT/manager/text/list -O - -q --no-check-certificate --no-proxy | grep "${webservice_application_name}:" | sed -e 's/:/\n/g' | grep "^${webservice_application_name}$")
      if [ -n "$WEBSERVICE_DEPLOYED" ]; then
        WEBSERVICE_RUNNING=$(wget http://$TOMCAT_MANAGER_USER:$TOMCAT_MANAGER_PASS@$MTWILSON_SERVER:$TOMCAT_MANAGER_PORT/manager/text/list -O - -q --no-check-certificate --no-proxy | grep "${webservice_application_name}:" | sed -e 's/:/\n/g' | grep "running")
      fi
    else
      if [ -z "$TOMCAT_HOME" ]; then tomcat_detect; fi
      WEBSERVICE_DEPLOYED=$(ls "$TOMCAT_HOME/webapps" | grep "${webservice_application_name}.war")
    fi
  fi
}
webservice_running_report() {
  local webservice_application_name="$1"
  echo -n "Checking if ${webservice_application_name} is deployed on webserver... "
  webservice_running "${webservice_application_name}"
  if [ -n "$WEBSERVICE_RUNNING" ]; then
    echo_success "Deployed"
  else
    echo_failure "Not deployed"
  fi
}
webservice_running_report_wait() {
  local webservice_application_name="$1"
  echo -n "Checking if ${webservice_application_name} is deployed on webserver..."
  webservice_running "${webservice_application_name}"
  for (( c=1; c<=10; c++ ))
  do
    if [ -z "$WEBSERVICE_RUNNING" ]; then
      echo -n "."
      sleep 5
      webservice_running "${webservice_application_name}"
    fi
  done
  if [ -n "$WEBSERVICE_RUNNING" ]; then
    echo_success "Deployed"
  else
    echo_failure "Not deployed"
  fi
}

webservice_start() {
  local webservice_application_name="$1"
  webservice_running  "${webservice_application_name}"
  if [ -n "$WEBSERVICE_DEPLOYED" ]; then
    if using_tomcat; then
      if [ -z "$TOMCAT_MANAGER_USER" ]; then tomcat_init_manager 2>&1 >/dev/null; fi
      wget http://$TOMCAT_MANAGER_USER:$TOMCAT_MANAGER_PASS@$MTWILSON_SERVER:$TOMCAT_MANAGER_PORT/manager/text/start?path=/${webservice_application_name} -O - -q --no-check-certificate --no-proxy
      #$tomcat start
      #if [ -f $TOMCAT_HOME/${webservice_application_name}/WEB-INF/web.xml.stop ]; then
        #rename $TOMCAT_HOME/${webservice_application_name}/WEB-INF/web.xml.stop $TOMCAT_HOME/${webservice_application_name}/WEB-INF/web.xml
      #fi
      #wget -O - -q --no-check-certificate --no-proxy https://tomcat:tomcat@$MTWILSON_SERVER:$DEFAULT_API_PORT/manager/start?path=${WEBSERVICE_DEPLOYED}
    fi
  fi
}
webservice_stop() {
  local webservice_application_name="$1"
  webservice_running "${webservice_application_name}"
  if [ -n "$WEBSERVICE_DEPLOYED" ]; then
    if using_tomcat; then
      if [ -z "$TOMCAT_MANAGER_USER" ]; then tomcat_init_manager 2>&1 >/dev/null; fi
      wget http://$TOMCAT_MANAGER_USER:$TOMCAT_MANAGER_PASS@$MTWILSON_SERVER:$TOMCAT_MANAGER_PORT/manager/text/stop?path=/${webservice_application_name} -O - -q --no-check-certificate --no-proxy
      #$tomcat stop
      #if [ -f $TOMCAT_HOME/${webservice_application_name}/WEB-INF/web.xml ]; then
        #rename $TOMCAT_HOME/webapps/${webservice_application_name}/WEB-INF/web.xml $TOMCAT_HOME/${webservice_application_name}/WEB-INF/web.xml.stop
      #fi
      #wget -O - -q --no-check-certificate --no-proxy https://tomcat:tomcat@$MTWILSON_SERVER:$DEFAULT_API_PORT/manager/stop?path=${WEBSERVICE_DEPLOYED}
    fi
  fi
}

webservice_start_report() {
    local webservice_application_name="$1"
    webservice_require
    if using_tomcat; then
      tomcat_running
      if [ -z "$TOMCAT_RUNNING" ]; then
          tomcat_start_report
      fi
    fi

    webservice_running "${webservice_application_name}"
    if [ -z "$WEBSERVICE_RUNNING" ]; then
          action_condition WEBSERVICE_RUNNING "Starting ${webservice_application_name}" "webservice_start ${webservice_application_name} > /dev/null; webservice_running ${webservice_application_name};"
    fi
    if [ -n "$WEBSERVICE_RUNNING" ]; then
          echo_success "${webservice_application_name} is running"
    fi
}
webservice_stop_report() {
    local webservice_application_name="$1"
    webservice_require
    if using_tomcat; then
      tomcat_running
    fi
    webservice_running "${webservice_application_name}"
    if [ -n "$WEBSERVICE_RUNNING" ]; then
        inaction_condition WEBSERVICE_RUNNING "Stopping ${webservice_application_name}" "webservice_stop ${webservice_application_name} > /dev/null; webservice_running ${webservice_application_name};"
    fi

    if [ -z "$WEBSERVICE_RUNNING" ]; then
      echo_success "${webservice_application_name} is stopped"
    fi
}


# parameters:
# webservice_application_name such as "AttestationService"
# webservice_war_file such as "/path/to/AttestationService-0.5.1.war"
# Environment:

webservice_install() {
  local webservice_application_name="$1"
  local webservice_war_file="$2"
  #webservice_require

  webservice_running "${webservice_application_name}"

  local WAR_FILE="${webservice_war_file}"
  local WAR_NAME=${WAR_FILE##*/}

    if [ -n "$WEBSERVICE_DEPLOYED" ]; then
      if using_tomcat; then
        echo "Re-deploying ${WEBSERVICE_DEPLOYED} to Tomcat..."
        rm -rf $TOMCAT_HOME/webapps/$WAR_NAME
        cp $WAR_FILE $TOMCAT_HOME/webapps/
        #wget -O - -q --no-check-certificate --no-proxy https://tomcat:tomcat@$MTWILSON_SERVER:$DEFAULT_API_PORT/manager/reload?path=${WEBSERVICE_DEPLOYED}
      fi
    else
      if using_tomcat; then
        #if [ ! tomcat_running ]; then
        #  tomcat_start
        #fi
        echo "Deploying ${webservice_application_name} to Tomcat..."
        cp $WAR_FILE $TOMCAT_HOME/webapps/

        # 2014-02-16 rksavinx removed; unnecessary block of code
        #wget -O - -q --no-check-certificate --no-proxy https://tomcat:tomcat@$MTWILSON_SERVER:$DEFAULT_API_PORT/manager/deploy?path=${webservice_application_name}&war=file:${webservice_war_file}
        #wait here until the app finishes deploying
        ##webservice_running $webservice_application_name
        ##while [ -z "$WEBSERVICE_RUNNING" ]; do
        ##  webservice_running $webservice_application_name >> $INSTALL_LOG_FILE
        ##  echo -n "." >> $INSTALL_LOG_FILE
        ##  sleep 2
        ##done
      fi
    fi
}

webservice_uninstall() {
  local webservice_application_name="$1"
  webservice_running "${webservice_application_name}"
  webservice_require
  local WAR_NAME="${webservice_application_name}.war"
  if [ -n "$WEBSERVICE_DEPLOYED" ]; then
    if using_tomcat; then
      echo "Undeploying ${WEBSERVICE_DEPLOYED} from Tomcat..."
      #wget -O - -q --no-check-certificate --no-proxy https://tomcat:tomcat@$MTWILSON_SERVER:$DEFAULT_API_PORT/manager/undeploy?path=${WEBSERVICE_DEPLOYED}
      if [ -f "$TOMCAT_HOME/webapps/$WAR_NAME" ] && [ ! -w "$TOMCAT_HOME/webapps/$WAR_NAME" ]; then
        echo_failure "Current user does not have permission to remove ${WAR_NAME} from tomcat installation"
        return 1
      fi
      if [ -d "$TOMCAT_HOME/webapps/${webservice_application_name}" ] && [ ! -w "$TOMCAT_HOME/webapps/${webservice_application_name}" ]; then
        echo_failure "Current user does not have permission to remove ${webservice_application_name} from tomcat installation"
        return 1
      fi
      rm -rf "$TOMCAT_HOME/webapps/$WAR_NAME"
      rm -rf "$TOMCAT_HOME/webapps/${webservice_application_name}"
    fi
  else
    if using_tomcat; then
      echo "Application is not deployed on Tomcat; skipping undeploy"
    fi
  fi
}
webservice_require(){
  if using_tomcat; then
    tomcat_require
  fi
}

### FUNCTION LIBRARY: DATABASE FUNCTIONS

database_restart(){
  if using_tomcat; then
    tomcat_restart
  fi
}

database_shutdown(){
 if using_tomcat; then
    tomcat_shutdown
  fi
}
# determine database
which_dbms(){
  echo "Please identify the database which will be used for the Mt Wilson server.
The supported databases are m=MySQL | p=PostgreSQL"
  while true; do
    prompt_with_default DATABASE_CHOICE "Choose Database:" "p";

    if [ "$DATABASE_CHOICE" != 'm' ] && [ "$DATABASE_CHOICE" != 'p' ]; then
      echo "[m]ysql or [p]ostgresql: "
      DATABASE_CHOICE=
    else
      if [ "$DATABASE_CHOICE" = 'm' ]; then
        export DATABASE_VENDOR="mysql"
      else
        export DATABASE_VENDOR="postgres"
      fi
      break
    fi
  done
  echo "Database Choice: $DATABASE_VENDOR" >> $INSTALL_LOG_FILE
}

# determine web server
which_web_server(){
echo "Please identify the web server which will be used for the Mt Wilson server.
The supported server is t=Tomcat"
  while true; do
    prompt_with_default WEBSERVER_CHOICE "Choose Web Server:" "t";

    if [ "$WEBSERVER_CHOICE" != 't' ]; then
      echo "[t]omcat: "
      WEBSERVER_CHOICE=
    else
      if [ "$WEBSERVER_CHOICE" = 't' ]; then
        export WEBSERVICE_VENDOR="tomcat"
      fi
      break
    fi
  done
  echo "Web Server Choice: $WEBSERVICE_VENDOR" >> $INSTALL_LOG_FILE
}
# parameters:
# 1. path to properties file
# 2. properties prefix (for mountwilson.as.db.user etc. the prefix is mountwilson.as.db)
# the default prefix is "postgres" for properties like "postgres.user", etc. The
# prefix must not have any spaces or special shell characters
# ONLY USE IF FILES ARE UNENCRYPTED!!!
postgres_read_connection_properties() {
    local config_file="$1"
    local prefix="${2:-postgres}"
    POSTGRES_HOSTNAME=`read_property_from_file ${prefix}.host "${config_file}"`
    POSTGRES_PORTNUM=`read_property_from_file ${prefix}.port "${config_file}"`
    POSTGRES_USERNAME=`read_property_from_file ${prefix}.user "${config_file}"`
    POSTGRES_PASSWORD=`read_property_from_file ${prefix}.password "${config_file}"`
    POSTGRES_DATABASE=`read_property_from_file ${prefix}.schema "${config_file}"`
}

# ONLY USE IF FILES ARE UNENCRYPTED!!!
postgres_write_connection_properties() {
    local config_file="$1"
    local prefix="${2:-postgres}"
    local encrypted="false"

    # Decrypt if needed
    if file_encrypted "$config_file"; then
      encrypted="true"
      decrypt_file "$config_file" "$MTWILSON_PASSWORD"
    fi

    update_property_in_file ${prefix}.host "${config_file}" "${POSTGRES_HOSTNAME}"
    update_property_in_file ${prefix}.port "${config_file}" "${POSTGRES_PORTNUM}"
    update_property_in_file ${prefix}.user "${config_file}" "${POSTGRES_USERNAME}"
    update_property_in_file ${prefix}.password "${config_file}" "${POSTGRES_PASSWORD}"
    update_property_in_file ${prefix}.schema "${config_file}" "${POSTGRES_DATABASE}"
    update_property_in_file ${prefix}.driver "${config_file}" "org.postgresql.Driver"

    # Return the file to encrypted state, if it was before
    if [ encrypted == "true" ]; then
      encrypt_file "$config_file" "$MTWILSON_PASSWORD"
    fi
}

# parameters:
# - configuration filename (absolute path)
# - property prefix for settings in the configuration file (java format is assumed, dot will be automatically appended to prefix)
postgres_userinput_connection_properties() {
    echo "Configuring DB Connection..."
    prompt_with_default POSTGRES_HOSTNAME "Hostname:" ${DEFAULT_POSTGRES_HOSTNAME}
    prompt_with_default POSTGRES_PORTNUM "Port Num:" ${DEFAULT_POSTGRES_PORTNUM}
    prompt_with_default POSTGRES_DATABASE "Database:" ${DEFAULT_POSTGRES_DATABASE}
    prompt_with_default POSTGRES_USERNAME "Username:" ${DEFAULT_POSTGRES_USERNAME}
    prompt_with_default_password POSTGRES_PASSWORD "Password:" ${DEFAULT_POSTGRES_PASSWORD}
}

# Set config file db properties
set_config_db_properties() {
  local scriptname="$1"
  local packagename="$2"
  intel_conf_dir=/etc/intel/cloudsecurity
  package_dir=/opt/intel/cloudsecurity/${packagename}
  package_config_filename=${intel_conf_dir}/${packagename}.properties
  package_env_filename=${package_dir}/${packagename}.env
  package_install_filename=${package_dir}/${packagename}.install
}

# The EclipseLink persistence framework sends messages to stdout that start with the text [EL Info] or [EL Warning].
# We suppress those because they are not useful for the customer, only for debugging.
# Caller can set setupconsole_dir to the directory where jars are found; default provided by DEFAULT_MTWILSON_JAVA_DIR
# Caller can set conf_dir to the directory where logback-stderr.xml is found; default provided by DEFAULT_MTWILSON_CONF_DIR
call_setupcommand() {
  local java_lib_dir=${setupconsole_dir:-$DEFAULT_MTWILSON_JAVA_DIR}
  if no_java ${JAVA_REQUIRED_VERSION:-$DEFAULT_JAVA_REQUIRED_VERSION}; then echo "Cannot find Java ${JAVA_REQUIRED_VERSION:-$DEFAULT_JAVA_REQUIRED_VERSION} or later"; return 1; fi
  SETUP_CONSOLE_JARS=$(JARS=($java_lib_dir/*.jar); IFS=:; echo "${JARS[*]}")
  mainclass=com.intel.mtwilson.setup.TextConsole
  java -cp "$SETUP_CONSOLE_JARS" -Dlogback.configurationFile=${conf_dir:-$DEFAULT_MTWILSON_CONF_DIR}/logback-stderr.xml $mainclass $@ | grep -vE "^\[EL Info\]|^\[EL Warning\]" 2> /dev/null
  return $?
}

# Caller can set setupconsole_dir to the directory where jars are found; default provided by DEFAULT_MTWILSON_JAVA_DIR
call_tag_setupcommand() {
  local java_lib_dir=${setupconsole_dir:-$DEFAULT_MTWILSON_JAVA_DIR}
  if no_java ${JAVA_REQUIRED_VERSION:-$DEFAULT_JAVA_REQUIRED_VERSION}; then echo "Cannot find Java ${JAVA_REQUIRED_VERSION:-$DEFAULT_JAVA_REQUIRED_VERSION} or later"; return 1; fi
  SETUP_CONSOLE_JARS=$(JARS=($java_lib_dir/*.jar); IFS=:; echo "${JARS[*]}")
  mainclass=com.intel.mtwilson.launcher.console.Main
  local jvm_memory=2048m
  java -Xmx${jvm_memory} -cp "$SETUP_CONSOLE_JARS" -Dlogback.configurationFile=${conf_dir:-$DEFAULT_MTWILSON_CONF_DIR}/logback-stderr.xml $mainclass $@ --ext-java=$java_lib_dir | grep -vE "^\[EL Info\]|^\[EL Warning\]" 2> /dev/null
  return $?
}

file_encrypted() {
  local filename="${1}"
  if [ -n "$filename" ] && [ -f "$filename" ]; then
    if grep -q "ENCRYPTED DATA" "$filename"; then
      return 0 #"File encrypted: $filename"
    else
      return 1 #"File NOT encrypted: $filename"
    fi
  else
    return 2 # FILE NOT FOUND so cannot detect
  fi
}

decrypt_file() {
  local filename="${1}"
  export PASSWORD="${2}"
  if ! validate_path_configuration "$filename" 2>&1>/dev/null && ! validate_path_data "$filename" 2>&1>/dev/null; then
    echo_failure "Path validation failed. Verify path meets acceptable directory constraints: $filename"
    return 1
  fi
  if [ -f "$filename" ]; then
    call_tag_setupcommand export-config --in="$filename" --out="$filename" --env-password="PASSWORD"
    if file_encrypted "$filename"; then
      echo_failure "Incorrect encryption password. Please verify \"MTWILSON_PASSWORD\" variable is set correctly."
      return 2
    fi
  else
    echo_warning "File not found: $filename"
    return 3
  fi
}

encrypt_file() {
  local filename="${1}"
  export PASSWORD="${2}"
  if ! validate_path_configuration "$filename" 2>&1>/dev/null && ! validate_path_data "$filename" 2>&1>/dev/null; then
    echo_failure "Path validation failed. Verify path meets acceptable directory constraints: $filename"
    return 1
  fi
  if [ -f "$filename" ]; then
    call_tag_setupcommand import-config --in="$filename" --out="$filename" --env-password="PASSWORD"
    if ! file_encrypted "$filename"; then
      echo_failure "Incorrect encryption password. Please verify \"MTWILSON_PASSWORD\" variable is set correctly."
      return 2
    fi
  else
    echo_warning "File NOT found: $filename"
    return 3
  fi
}

load_conf() {
  local mtw_props_path="/etc/intel/cloudsecurity/mtwilson.properties"
  local as_props_path="/etc/intel/cloudsecurity/attestation-service.properties"
  #local pca_props_path="/etc/intel/cloudsecurity/PrivacyCA.properties"
  local ms_props_path="/etc/intel/cloudsecurity/management-service.properties"
  local mp_props_path="/etc/intel/cloudsecurity/mtwilson-portal.properties"
  local hp_props_path="/etc/intel/cloudsecurity/clientfiles/hisprovisioner.properties"
  local ta_props_path="/etc/intel/cloudsecurity/trustagent.properties"

  if [ -n "$DEFALT_ENV_LOADED" ]; then return; fi

  # mtwilson.properties file
  if [ -f "$mtw_props_path" ]; then
    echo -n "Reading properties from "
    if file_encrypted "$mtw_props_path"; then
      echo -n "encrypted file [$mtw_props_path]....."
      temp=$(call_tag_setupcommand export-config --in="$mtw_props_path" --stdout 2>&1)
      if [[ "$temp" == *"Incorrect password"* ]]; then
        echo_failure -e "Incorrect encryption password. Please verify \"MTWILSON_PASSWORD\" variable is set correctly."
        return 2
      fi
      export CONF_DATABASE_HOSTNAME=`echo $temp | awk -F'mtwilson.db.host=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_DATABASE_SCHEMA=`echo $temp | awk -F'mtwilson.db.schema=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_DATABASE_USERNAME=`echo $temp | awk -F'mtwilson.db.user=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_DATABASE_PASSWORD=`echo $temp | awk -F'mtwilson.db.password=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_DATABASE_PORTNUM=`echo $temp | awk -F'mtwilson.db.port=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_DATABASE_DRIVER=`echo $temp | awk -F'mtwilson.db.driver=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_MTWILSON_DEFAULT_TLS_POLICY_ID=`echo $temp | awk -F'mtwilson.default.tls.policy.id=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_MTWILSON_TLS_POLICY_ALLOW=`echo $temp | awk -F'mtwilson.tls.policy.allow=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_MTWILSON_TLS_KEYSTORE_PASSWORD=`echo $temp | awk -F'mtwilson.tls.keystore.password=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_MTWILSON_TAG_API_USERNAME=`echo $temp | awk -F'mtwilson.tag.api.username=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_MTWILSON_TAG_API_PASSWORD=`echo $temp | awk -F'mtwilson.tag.api.password=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_WEBSERVICE_VENDOR=$(echo $temp | awk -F'mtwilson.webserver.vendor=' '{print $2}' | awk -F' ' '{print $1}')
      if [ "CONF_WEBSERVICE_VENDOR == tomcat" ]; then
        export CONF_WEBSERVICE_MANAGER_USERNAME=$(echo $temp | awk -F'tomcat.admin.username=' '{print $2}' | awk -F' ' '{print $1}')
        export CONF_WEBSERVICE_MANAGER_PASSWORD=$(echo $temp | awk -F'tomcat.admin.password=' '{print $2}' | awk -F' ' '{print $1}')
      fi
    else
      echo -n "file [$mtw_props_path]....."
      export CONF_DATABASE_HOSTNAME=`read_property_from_file mtwilson.db.host "$mtw_props_path"`
      export CONF_DATABASE_SCHEMA=`read_property_from_file mtwilson.db.schema "$mtw_props_path"`
      export CONF_DATABASE_USERNAME=`read_property_from_file mtwilson.db.user "$mtw_props_path"`
      export CONF_DATABASE_PASSWORD=`read_property_from_file mtwilson.db.password "$mtw_props_path"`
      export CONF_DATABASE_PORTNUM=`read_property_from_file mtwilson.db.port "$mtw_props_path"`
      export CONF_DATABASE_DRIVER=`read_property_from_file mtwilson.db.driver "$mtw_props_path"`
      export CONF_MTWILSON_DEFAULT_TLS_POLICY_ID=`read_property_from_file mtwilson.default.tls.policy.id "$mtw_props_path"`
      export CONF_MTWILSON_TLS_POLICY_ALLOW=`read_property_from_file mtwilson.tls.policy.allow "$mtw_props_path"`
      export CONF_MTWILSON_TLS_KEYSTORE_PASSWORD=`read_property_from_file mtwilson.tls.keystore.password "$mtw_props_path"`
      export CONF_MTWILSON_TAG_API_USERNAME=`read_property_from_file mtwilson.tag.api.username "$mtw_props_path"`
      export CONF_MTWILSON_TAG_API_PASSWORD=`read_property_from_file mtwilson.tag.api.password "$mtw_props_path"`
      export CONF_WEBSERVICE_VENDOR=$(read_property_from_file mtwilson.webserver.vendor "$mtw_props_path")
      if [ "$CONF_WEBSERVICE_VENDOR" == "tomcat" ]; then
        export CONF_WEBSERVICE_MANAGER_USERNAME=$(read_property_from_file tomcat.admin.username "$mtw_props_path")
        export CONF_WEBSERVICE_MANAGER_PASSWORD=$(read_property_from_file tomcat.admin.password "$mtw_props_path")
      fi
    fi
    echo_success "Done"
  fi

  # attestation-service.properties
  if [ -f "$as_props_path" ]; then
    echo -n "Reading properties from "
    if file_encrypted "$as_props_path"; then
      echo -n "encrypted file [$as_props_path]....."
      temp=$(call_tag_setupcommand export-config --in="$as_props_path" --stdout 2>&1)
      if [[ "$temp" == *"Incorrect password"* ]]; then
        echo_failure -e "Incorrect encryption password. Please verify \"MTWILSON_PASSWORD\" variable is set correctly."
        return 2
      fi
      export CONF_SAML_KEYSTORE_FILE=`echo $temp | awk -F'saml.keystore.file=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_SAML_KEYSTORE_PASSWORD=`echo $temp | awk -F'saml.keystore.password=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_SAML_KEY_ALIAS=`echo $temp | awk -F'saml.key.alias=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_SAML_KEY_PASSWORD=`echo $temp | awk -F'saml.key.password=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_SAML_ISSUER=`echo $temp | awk -F'saml.issuer=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_PRIVACYCA_SERVER=`echo $temp | awk -F'privacyca.server=' '{print $2}' | awk -F' ' '{print $1}'`
    else
      echo -n "file [$as_props_path]....."
      export CONF_SAML_KEYSTORE_FILE=`read_property_from_file saml.keystore.file "$as_props_path"`
      export CONF_SAML_KEYSTORE_PASSWORD=`read_property_from_file saml.keystore.password "$as_props_path"`
      export CONF_SAML_KEY_ALIAS=`read_property_from_file saml.key.alias "$as_props_path"`
      export CONF_SAML_KEY_PASSWORD=`read_property_from_file saml.key.password "$as_props_path"`
      export CONF_SAML_ISSUER=`read_property_from_file saml.issuer "$as_props_path"`
      export CONF_PRIVACYCA_SERVER=`read_property_from_file privacyca.server "$as_props_path"`
    fi
    echo_success "Done"
  fi

  # management-service.properties
  if [ -f "$ms_props_path" ]; then
    echo -n "Reading properties from "
    if file_encrypted "$ms_props_path"; then
      echo -n "encrypted file [$ms_props_path]....."
      temp=$(call_tag_setupcommand export-config --in="$ms_props_path" --stdout 2>&1)
      if [[ "$temp" == *"Incorrect password"* ]]; then
        echo_failure -e "Incorrect encryption password. Please verify \"MTWILSON_PASSWORD\" variable is set correctly."
        return 2
      fi
      export CONF_MS_KEYSTORE_DIR=`echo $temp | awk -F'mtwilson.ms.keystore.dir=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_API_KEY_ALIAS=`echo $temp | awk -F'mtwilson.api.key.alias=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_API_KEY_PASS=`echo $temp | awk -F'mtwilson.api.key.password=' '{print $2}' | awk -F' ' '{print $1}'`
      export CONF_CONFIGURED_API_BASEURL=`echo $temp | awk -F'mtwilson.api.baseurl=' '{print $2}' | awk -F' ' '{print $1}'`
    else
      echo -n "file [$ms_props_path]....."
      export CONF_MS_KEYSTORE_DIR=`read_property_from_file mtwilson.ms.keystore.dir "$ms_props_path"`
      export CONF_API_KEY_ALIAS=`read_property_from_file mtwilson.api.key.alias "$ms_props_path"`
      export CONF_API_KEY_PASS=`read_property_from_file mtwilson.api.key.password "$ms_props_path"`
      export CONF_CONFIGURED_API_BASEURL=`read_property_from_file mtwilson.api.baseurl "$ms_props_path"`
    fi
    echo_success "Done"
  fi


  # mtwilson-portal.properties
  if [ -f "$mp_props_path" ]; then
    echo -n "Reading properties from "
    if file_encrypted "$mp_props_path"; then
      echo -n "encrypted file [$mp_props_path]....."
      temp=$(call_tag_setupcommand export-config --in="$mp_props_path" --stdout 2>&1)
      if [[ "$temp" == *"Incorrect password"* ]]; then
        echo_failure -e "Incorrect encryption password. Please verify \"MTWILSON_PASSWORD\" variable is set correctly."
        return 2
      fi
      export CONF_TDBP_KEYSTORE_DIR=`echo $temp | awk -F'mtwilson.tdbp.keystore.dir=' '{print $2}' | awk -F' ' '{print $1}'`
    else
      echo -n "file [$mp_props_path]....."
      export CONF_TDBP_KEYSTORE_DIR=`read_property_from_file mtwilson.tdbp.keystore.dir "$mp_props_path"`
    fi
    echo_success "Done"
  fi

  # hisprovisioner.properties
  if [ -f "$hp_props_path" ]; then
    echo -n "Reading properties from "
    if file_encrypted "$hp_props_path"; then
      echo -n "encrypted file [$hp_props_path]....."
      temp=$(call_tag_setupcommand export-config --in="$hp_props_path" --stdout 2>&1)
      if [[ "$temp" == *"Incorrect password"* ]]; then
        echo_failure -e "Incorrect encryption password. Please verify \"MTWILSON_PASSWORD\" variable is set correctly."
        return 2
      fi
      export CONF_ENDORSEMENT_P12_PASS=`echo $temp | awk -F'EndorsementP12Pass = ' '{print $2}' | awk -F' ' '{print $1}'`
    else
      echo -n "file [$hp_props_path]....."
      export CONF_ENDORSEMENT_P12_PASS=`read_property_from_file EndorsementP12Pass "$hp_props_path"`
    fi
    echo_success "Done"
  fi

  # trustagent.properties
  if [ -f "$ta_props_path" ]; then
    echo -n "Reading properties from "
    if file_encrypted "$ta_props_path"; then
      echo -n "encrypted file [$ta_props_path]....."
      temp=$(call_tag_setupcommand export-config --in="$ta_props_path" --stdout 2>&1)
      if [[ "$temp" == *"Incorrect password"* ]]; then
        echo_failure -e "Incorrect encryption password. Please verify \"MTWILSON_PASSWORD\" variable is set correctly."
        return 2
      fi
      export CONF_TRUSTAGENT_KEYSTORE_PASS=`echo $temp | awk -F'trustagent.keystore.password=' '{print $2}' | awk -F' ' '{print $1}'`
    else
      echo -n "file [$ta_props_path]....."
      export CONF_TRUSTAGENT_KEYSTORE_PASS=`read_property_from_file trustagent.keystore.password "$ta_props_path"`
    fi
    echo_success "Done"
  fi

  # Determine DATABASE_VENDOR
  if grep -q "postgres" <<< "$CONF_DATABASE_DRIVER"; then
    export CONF_DATABASE_VENDOR="postgres";
  elif grep -q "mysql" <<< "$CONF_DATABASE_DRIVER"; then
    export CONF_DATABASE_VENDOR="mysql";
  fi

  export DEFAULT_ENV_LOADED=true
  return 0
}

load_defaults() {
  export DEFAULT_MTWILSON_SERVER=""
  export DEFAULT_DATABASE_HOSTNAME=""
  export DEFAULT_DATABASE_SCHEMA=""
  export DEFAULT_DATABASE_USERNAME=""
  export DEFAULT_DATABASE_PASSWORD=""
  export DEFAULT_DATABASE_PORTNUM=""
  export DEFAULT_DATABASE_DRIVER=""
  export DEFAULT_WEBSERVICE_VENDOR=""
  export DEFAULT_WEBSERVICE_MANAGER_USERNAME="admin"
  export DEFAULT_WEBSERVICE_MANAGER_PASSWORD=$(generate_password 16)
  export DEFAULT_DATABASE_VENDOR=""
  export DEFAULT_PRIVACYCA_SERVER=""
  export DEFAULT_SAML_KEYSTORE_FILE="SAML.jks"
  export DEFAULT_SAML_KEYSTORE_PASSWORD=""
  export DEFAULT_SAML_KEY_ALIAS="samlkey1"
  export DEFAULT_SAML_KEY_PASSWORD=""
  export DEFAULT_SAML_ISSUER=""
  export DEFAULT_PRIVACYCA_SERVER=""
  export DEFAULT_MS_KEYSTORE_DIR="/var/opt/intel/management-service/users"
  export DEFAULT_API_KEY_ALIAS=""
  export DEFAULT_API_KEY_PASS=""
  export DEFAULT_CONFIGURED_API_BASEURL=""
  export DEFAULT_MTWILSON_DEFAULT_TLS_POLICY_ID=""
  export DEFAULT_MTWILSON_TLS_POLICY_ALLOW=""
  export DEFAULT_MTWILSON_TLS_KEYSTORE_PASSWORD=""
  export DEFAULT_TDBP_KEYSTORE_DIR=""
  export DEFAULT_ENDORSEMENT_P12_PASS=""
  export DEFAULT_TRUSTAGENT_KEYSTORE_PASS=""
  export DEFAULT_MTWILSON_TAG_API_USERNAME="tagservice"
  export DEFAULT_MTWILSON_TAG_API_PASSWORD=$(generate_password 16)

  export MTWILSON_SERVER=${MTWILSON_SERVER:-${CONF_MTWILSON_SERVER:-$DEFAULT_MTWILSON_SERVER}}
  export DATABASE_HOSTNAME=${DATABASE_HOSTNAME:-${CONF_DATABASE_HOSTNAME:-$DEFAULT_DATABASE_HOSTNAME}}
  export DATABASE_SCHEMA=${DATABASE_SCHEMA:-${CONF_DATABASE_SCHEMA:-$DEFAULT_DATABASE_SCHEMA}}
  export DATABASE_USERNAME=${DATABASE_USERNAME:-${CONF_DATABASE_USERNAME:-$DEFAULT_DATABASE_USERNAME}}
  export DATABASE_PASSWORD=${DATABASE_PASSWORD:-${CONF_DATABASE_PASSWORD:-$DEFAULT_DATABASE_PASSWORD}}
  export DATABASE_PORTNUM=${DATABASE_PORTNUM:-${CONF_DATABASE_PORTNUM:-$DEFAULT_DATABASE_PORTNUM}}
  export DATABASE_DRIVER=${DATABASE_DRIVER:-${CONF_DATABASE_DRIVER:-$DEFAULT_DATABASE_DRIVER}}
  export DATABASE_VENDOR=${DATABASE_VENDOR:-${CONF_DATABASE_VENDOR:-$DEFAULT_DATABASE_VENDOR}}
  export WEBSERVICE_VENDOR=${WEBSERVICE_VENDOR:-${WEBSERVER_VENDOR:-${CONF_WEBSERVICE_VENDOR:-$DEFAULT_WEBSERVICE_VENDOR}}}
  export WEBSERVICE_MANAGER_USERNAME=${WEBSERVICE_MANAGER_USERNAME:-${CONF_WEBSERVICE_MANAGER_USERNAME:-$DEFAULT_WEBSERVICE_MANAGER_USERNAME}}
  export WEBSERVICE_MANAGER_PASSWORD=${WEBSERVICE_MANAGER_PASSWORD:-${CONF_WEBSERVICE_MANAGER_PASSWORD:-$DEFAULT_WEBSERVICE_MANAGER_PASSWORD}}
  export PRIVACYCA_SERVER=${PRIVACYCA_SERVER:-${CONF_PRIVACYCA_SERVER:-$DEFAULT_PRIVACYCA_SERVER}}
  export SAML_KEYSTORE_FILE=${SAML_KEYSTORE_FILE:-${CONF_SAML_KEYSTORE_FILE:-$DEFAULT_SAML_KEYSTORE_FILE}}
  export SAML_KEYSTORE_PASSWORD=${SAML_KEYSTORE_PASSWORD:-${CONF_SAML_KEYSTORE_PASSWORD:-$DEFAULT_SAML_KEYSTORE_PASSWORD}}
  export SAML_KEY_ALIAS=${SAML_KEY_ALIAS:-${CONF_SAML_KEY_ALIAS:-$DEFAULT_SAML_KEY_ALIAS}}
  export SAML_KEY_PASSWORD=${SAML_KEY_PASSWORD:-${CONF_SAML_KEY_PASSWORD:-$DEFAULT_SAML_KEY_PASSWORD}}
  export SAML_ISSUER=${SAML_ISSUER:-${CONF_SAML_ISSUER:-$DEFAULT_SAML_ISSUER}}
  export PRIVACYCA_SERVER=${PRIVACYCA_SERVER:-${CONF_PRIVACYCA_SERVER:-$DEFAULT_PRIVACYCA_SERVER}}
  export MS_KEYSTORE_DIR=${MS_KEYSTORE_DIR:-${CONF_MS_KEYSTORE_DIR:-$DEFAULT_MS_KEYSTORE_DIR}}
  export API_KEY_ALIAS=${API_KEY_ALIAS:-${CONF_API_KEY_ALIAS:-$DEFAULT_API_KEY_ALIAS}}
  export API_KEY_PASS=${API_KEY_PASS:-${CONF_API_KEY_PASS:-$DEFAULT_API_KEY_PASS}}
  export CONFIGURED_API_BASEURL=${CONFIGURED_API_BASEURL:-${CONF_CONFIGURED_API_BASEURL:-$DEFAULT_CONFIGURED_API_BASEURL}}
  export MTWILSON_DEFAULT_TLS_POLICY_ID=${MTWILSON_DEFAULT_TLS_POLICY_ID:-${CONF_MTWILSON_DEFAULT_TLS_POLICY_ID:-$DEFAULT_MTWILSON_DEFAULT_TLS_POLICY_ID}}
  export MTWILSON_TLS_POLICY_ALLOW=${MTWILSON_TLS_POLICY_ALLOW:-${CONF_MTWILSON_TLS_POLICY_ALLOW:-$DEFAULT_MTWILSON_TLS_POLICY_ALLOW}}
  export MTWILSON_TLS_KEYSTORE_PASSWORD=${MTWILSON_TLS_KEYSTORE_PASSWORD:-${CONF_MTWILSON_TLS_KEYSTORE_PASSWORD:-$DEFAULT_MTWILSON_TLS_KEYSTORE_PASSWORD}}
  export TDBP_KEYSTORE_DIR=${TDBP_KEYSTORE_DIR:-${CONF_TDBP_KEYSTORE_DIR:-$DEFAULT_TDBP_KEYSTORE_DIR}}
  export ENDORSEMENT_P12_PASS=${ENDORSEMENT_P12_PASS:-${CONF_ENDORSEMENT_P12_PASS:-$DEFAULT_ENDORSEMENT_P12_PASS}}
  export MTWILSON_TAG_API_USERNAME=${MTWILSON_TAG_API_USERNAME:-${CONF_MTWILSON_TAG_API_USERNAME:-$DEFAULT_MTWILSON_TAG_API_USERNAME}}
  export MTWILSON_TAG_API_PASSWORD=${MTWILSON_TAG_API_PASSWORD:-${CONF_MTWILSON_TAG_API_PASSWORD:-$DEFAULT_MTWILSON_TAG_API_PASSWORD}}
  export TRUSTAGENT_KEYSTORE_PASS=${TRUSTAGENT_KEYSTORE_PASS:-${CONF_TRUSTAGENT_KEYSTORE_PASS:-$DEFAULT_TRUSTAGENT_KEYSTORE_PASS}}

  if using_mysql; then
    export MYSQL_HOSTNAME=${DATABASE_HOSTNAME}
    export MYSQL_PORTNUM=${MYSQL_PORTNUM:-${CONF_DATABASE_PORTNUM:-$DATABASE_PORTNUM}}
    export MYSQL_DATABASE=${DATABASE_SCHEMA}
    export MYSQL_USERNAME=${DATABASE_USERNAME}
    export MYSQL_PASSWORD=${DATABASE_PASSWORD}
  elif using_postgres; then
    export POSTGRES_HOSTNAME=${DATABASE_HOSTNAME}
    export POSTGRES_PORTNUM=${POSTGRES_PORTNUM:-${CONF_DATABASE_PORTNUM:-$DATABASE_PORTNUM}}
    export POSTGRES_DATABASE=${DATABASE_SCHEMA}
    export POSTGRES_USERNAME=${DATABASE_USERNAME}
    export POSTGRES_PASSWORD=${DATABASE_PASSWORD}
  fi
}

change_db_pass() {
  mysqladmin=`which mysqladmin 2>/dev/null`
  psql=`which psql 2>/dev/null`
  mtwilson=`which mtwilson 2>/dev/null`
  cryptopass="$MTWILSON_PASSWORD"

  #load_default_env 1>/dev/null

  # Do not allow a blank password to be specified
  prompt_with_default_password DATABASE_PASSWORD_NEW "New database password: " "$DATABASE_PASSWORD_NEW"
  new_db_pass="$DATABASE_PASSWORD_NEW"
  sed_escaped_value=$(sed_escape "$new_db_pass")

  # Check for encryption, add to array if encrypted
  encrypted_files=()
  count=0
  for i in `ls -1 /etc/intel/cloudsecurity/*.properties`; do
    if file_encrypted "$i"; then
      encrypted_files[count]="$i"
    fi
    let count++
  done

  local decryption_error=false
  for i in ${encrypted_files[@]}; do
    decrypt_file "$i" "$cryptopass"
    if [ $? -ne 0 ]; then
      decryption_error=true
    fi
  done
  if $decryption_error; then
    echo_error "Cannot decrypt configuration files; please set MTWILSON_PASSWORD"
    return 1
  fi

  load_conf
  load_defaults

  # Test DB connection and change password
  if using_mysql; then #MYSQL
    echo_success "using mysql"
    mysql_detect
    mysql_version
    mysql_test_connection_report
    if [ $? -ne 0 ]; then exit; fi
    $mysqladmin -h "$DATABASE_HOSTNAME" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" password "$new_db_pass"
    if [ $? -ne 0 ]; then echo_failure "Issue building mysql command."; exit; fi
  elif using_postgres; then #POSTGRES
    echo_success "using postgres"
    postgres_detect
    postgres_version
    postgres_test_connection_report
    if [ $? -ne 0 ]; then exit; fi
    temp=$(cd /tmp && "$psql" -h "$DATABASE_HOSTNAME" -d "$DATABASE_SCHEMA" -U "$DATABASE_USERNAME" -c "ALTER USER $DATABASE_USERNAME WITH PASSWORD '$new_db_pass';")
    if [ $? -ne 0 ]; then echo_failure -e "\nIssue building postgres or expect command."; exit; fi
    # Edit postgres password file if it exists
    if [ -f ~/.pgpass ]; then
      echo
      echo -n "Updating database password value in .pgpass file...."
      sed -i 's|\(.*:'"$DATABASE_SCHEMA"':'"$DATABASE_USERNAME"':\).*|\1'"$new_db_pass"'|' ~/.pgpass
      #temp=`cat ~/.pgpass | cut -f1,2,3,4 -d":"`
      #temp="$temp:$new_db_pass"
      #echo $temp > ~/.pgpass;
    fi
    postgres_restart
    echo_success "Done"
  fi

  # Edit .properties files
  for i in `ls -1 /etc/intel/cloudsecurity/*.properties`; do
    echo -n "Updating database password value in $i...."
    sed -i -e 's/db.password=[^\n]*/db.password='"$sed_escaped_value"'/g' "$i"
    echo_success "Done"
  done

  # 20140427 commented out the update to mtwilson.env because
  # running system should not depend on it or update it in any way;
  # the mtwilson.env is for install time only and is assumed to be
  # deleted after install.
  ## Update password in mtwilson.env file
  #if [ -f /root/mtwilson.env ]; then
  #  echo -n "Updating database password value in mtwilson.env file...."
  #  export sed_escaped_value=$(sed_escape "$new_db_pass")
  #  sed -i -e 's/DATABASE_PASSWORD=[^\n]*/DATABASE_PASSWORD='\'"$sed_escaped_value"\''/g' "/root/mtwilson.env"
  #  echo_success "Done"
  #fi

  # Restart
  if using_tomcat; then
    echo_success "using tomcat"
    echo "Restarting mtwilson......"
    $mtwilson tomcat-restart
  fi
  echo_success "RESTART COMPLETED"

  # Encrypt files
  for i in ${encrypted_files[@]}; do
    encrypt_file "$i" "$cryptopass"
  done

  echo_success "DB PASSWORD CHANGE FINISHED"
}

#echoerr() { echo_failure "$@" 1>&2; }

function erase_data() {
  mysql=`which mysql 2>/dev/null`
  psql=`which psql 2>/dev/null`

  #encrypted_files=()
  #count=0
  #for i in `ls -1 /etc/intel/cloudsecurity/*.properties`; do
  #  if file_encrypted "$i"; then
  #    encrypted_files[count]="$i"
  #  fi
  #  let count++
  #done
  #
  #for i in ${encrypted_files[@]}; do
  #  decrypt_file "$i" "$MTWILSON_PASSWORD"
  #done

  arr=(mw_measurement_xml mw_tag_certificate mw_tag_certificate_request mw_tag_selection_kvattribute mw_tag_selection mw_tag_kvattribute mw_host_tpm_password mw_asset_tag_certificate mw_audit_log_entry mw_module_manifest_log mw_ta_log mw_saml_assertion mw_host_specific_manifest mw_hosts mw_mle_source mw_module_manifest mw_pcr_manifest mw_mle mw_os mw_oem mw_tls_policy)

  # Test DB connection and change password
  if using_mysql; then #MYSQL
    echo_success "using mysql"
    mysql_detect
    mysql_version
    mysql_test_connection_report
    if [ $? -ne 0 ]; then return 1; fi
    for table in ${arr[*]}; do
      $mysql -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" -D"$DATABASE_SCHEMA" -e "DELETE from $table;"
    done
  elif using_postgres; then #POSTGRES
    echo_success "using postgres"
    postgres_detect
    postgres_version
    postgres_test_connection_report
    if [ $? -ne 0 ]; then return 1; fi
    postgres_password=${POSTGRES_PASSWORD:-$DEFAULT_POSTGRES_PASSWORD}
    for table in ${arr[*]}; do
      temp=`(cd /tmp && PGPASSWORD=$postgres_password "$psql" -d "$DATABASE_SCHEMA" -U "$DATABASE_USERNAME" -h "$DATABASE_HOSTNAME" -c "DELETE from $table;")`
    done
  fi
}

key_backup() {
  shift
  if ! options=$(getopt -a -n key-backup -l passwd: -o p: -- "$@"); then echo_failure "Usage: $0 key-backup [-p PASSWORD | --passwd PASSWORD]"; return 1; fi
  eval set -- "$options"
  while [ $# -gt 0 ]
  do
    case $1 in
      -p|--passwd) eval MTWILSON_PASSWORD="\$$2"; shift;;
      --) shift; args="$@"; shift;;
    esac
    shift
  done

  args=`echo $args | sed -e 's/^ *//' -e 's/ *$//'`
  if [ -n "$args" ]; then echo_failure "Usage: $0 key-backup [-p PASSWORD | --passwd PASSWORD]"; return 2; fi

  export MTWILSON_PASSWORD
  if [ -z "$MTWILSON_PASSWORD" ]; then echo_failure "Encryption password cannot be null."; return 3; fi

  configDir="/opt/mtwilson/configuration"
  if [ -w "/var/" ]; then
     keyBackupDir="/var/mtwilson/key-backup"
  else
     keyBackupDir="/opt/mtwilson/var/mtwilson/key-backup"
  fi
  datestr=`date +%Y-%m-%d.%H%M%S`
  keyBackupFile="$keyBackupDir/mtwilson-keys_$datestr.enc"
  mkdir -p "$keyBackupDir" 2>/dev/null
  filesToEncrypt="$configDir/*.*"
  if [ -f "$configDir/private/password.txt" ]; then filesToEncrypt="$filesToEncrypt $configDir/private/*.*"; fi
  /opt/mtwilson/bin/encrypt.sh -p MTWILSON_PASSWORD --nopbkdf2 "$keyBackupFile" "$filesToEncrypt" > /dev/null
  find "$configDir/" -name "*.sig" -type f -delete
  shred -uzn 3 "$keyBackupFile.zip"
  echo_success "Keys backed up to: $keyBackupFile"
}

key_restore() {
  shift
  if ! options=$(getopt -a -n key-restore -l passwd: -o p: -- "$@"); then echo_failure "Usage: $0 key-restore [-p PASSWORD | --passwd PASSWORD] file_name"; return 1; fi
  eval set -- "$options"
  while [ $# -gt 0 ]
  do
    case $1 in
      -p|--passwd) eval MTWILSON_PASSWORD="\$$2"; shift;;
      --) shift; args="$@"; shift;;
    esac
    shift
  done

  args=`echo $args | sed -e 's/^ *//' -e 's/ *$//'`
  if [[ "$args" == *" "* ]]; then echo_failure "Usage: $0 key-restore [-p PASSWORD | --passwd PASSWORD] file_name"; return 2; fi

  export MTWILSON_PASSWORD
  if [ -z "$MTWILSON_PASSWORD" ]; then echo_failure "Encryption password cannot be null."; return 3; fi

  keyBackupFile="$args"
  keyBackupDir="$keyBackupFile.d"
  configDir="/opt/mtwilson/configuration"
  if [ ! -f "$keyBackupFile" ]; then
    echo_failure "File does not exist"
    return 4
  fi
  /opt/mtwilson/bin/decrypt.sh -p MTWILSON_PASSWORD "$keyBackupFile" > /dev/null
  find "$keyBackupDir/" -name "*.sig" -type f -delete
  cp -R "$keyBackupDir"/* "$configDir"/
  # cd to make sure in readable directory to prevent find utility error on "sudo -u mtwilson ..."
  (cd "$keyBackupDir" && find "$keyBackupDir" -type f -exec shred -uzn 3 {} \;)
  rm -rf "$keyBackupDir"
  shred -uzn 3 "$keyBackupFile.zip"

  # password.txt file in private directory
  if [ -f "$configDir/password.txt" ]; then
    mkdir -p "$configDir/private" 2>/dev/null
    cp -R "$configDir/password.txt" "$configDir/private/password.txt"
    shred -uzn 3 "$configDir/password.txt"
  fi

  echo_success "Keys restored from: $keyBackupFile"
}

# called by installer to automatically configure the server for localhost integration
shiro_localhost_integration() {
  local shiroIniPath="${1}"
  local iplist;
  local finalIps;
  iplist="127.0.0.1"

  OIFS=$IFS
  IFS=',' read -ra newIps <<< "$iplist"
  IFS=$OIFS

  iniHostRealmPropertyExists=$(cat "${shiroIniPath}" | grep '^iniHostRealm=' 2>/dev/null)
  if [ -z "${iniHostRealmPropertyExists}" ]; then
    sed -i 's|\(^securityManager.realms*\)|iniHostRealm=\n\1|' "${shiroIniPath}"
  fi
  iniHostRealmAllowPropertyExists=$(cat "${shiroIniPath}" | grep '^iniHostRealm.allow=' 2>/dev/null)
  if [ -z "${iniHostRealmAllowPropertyExists}" ]; then
    sed -i 's|\(^securityManager.realms*\)|iniHostRealm.allow=\n\1|' "${shiroIniPath}"
  fi
  hostMatcherPropertyExists=$(cat "${shiroIniPath}" | grep '^hostMatcher=' 2>/dev/null)
  if [ -z "${hostMatcherPropertyExists}" ]; then
    sed -i 's|\(^securityManager.realms*\)|hostMatcher=\n\1|' "${shiroIniPath}"
  fi
  iniHostRealmCredentialsMatcherPropertyExists=$(cat "${shiroIniPath}" | grep '^iniHostRealm.credentialsMatcher=' 2>/dev/null)
  if [ -z "${iniHostRealmCredentialsMatcherPropertyExists}" ]; then
    sed -i 's|\(^securityManager.realms*\)|iniHostRealm.credentialsMatcher=\n\1|' "${shiroIniPath}"
  fi

  update_property_in_file "iniHostRealm" "${shiroIniPath}" 'com.intel.mtwilson.shiro.authc.host.IniHostRealm'
  update_property_in_file "hostMatcher" "${shiroIniPath}" 'com.intel.mtwilson.shiro.authc.host.HostCredentialsMatcher'
  update_property_in_file "iniHostRealm.credentialsMatcher" "${shiroIniPath}" '$hostMatcher'

  #iniHostRealm.allow
  hostAllow=$(read_property_from_file iniHostRealm.allow ${shiroIniPath})
  finalIps="$hostAllow"
  for i in "${newIps[@]}"; do
    OIFS=$IFS
    IFS=',' read -ra oldIps <<< "$finalIps"
    IFS=$OIFS
    if [[ "${oldIps[*]}" != *"$i"* ]]; then
      if [ -z "$finalIps" ]; then
        finalIps="$i"
      else
        finalIps+=",$i"
      fi
    fi
  done
  update_property_in_file "iniHostRealm.allow" "${shiroIniPath}" "$finalIps";

  #securityManager.realms
  securityManagerPropertyHasIniHostRealm=$(cat "${shiroIniPath}" | grep '^securityManager.realms' 2>/dev/null | grep '$iniHostRealm' 2>/dev/null)
  if [ -z "${securityManagerPropertyHasIniHostRealm}" ]; then
    sed -i 's|\(^securityManager.realms.*\)|\1, $iniHostRealm|' "${shiroIniPath}"
  fi
}
