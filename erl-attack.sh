#!/usr/bin/env bash
trap ctrl_c INT
ctrl_c() { exit 1; }

exitOnError() { # $1=ErrorMessage $2=PrintUsageFlag
	local TMP="$(echo "$0" | sed -E 's#^.*/##')"
	local REQ_ARGS="$(grep -e "#REQUIRED[=]" $0)"
	local OPT_ARGS="$(grep -e "#OPTIONAL[=]" $0)"
	[ "$1" != "" ] && >&2 echo "ERROR: $1"
	[[ "$1" != "" && "$2" != "" ]] && >&2 echo ""
	[ "$2" != "" ] && {
		>&2 echo -e "USAGE: ${TMP} TARGET_URL$([[ "${REQ_ARGS}" != "" ]] && echo " [REQUIRED_ARGUMENTS]")$([[ "${OPT_ARGS}" != "" ]] && echo " [OPTIONAL_ARGUMENTS]")"
		[[ "${REQ_ARGS}" != "" ]] && {
			>&2 echo -e "\nREQUIRED ARGUMENTS:"
			>&2 echo -e "$(echo "${REQ_ARGS}" | sed -E -e 's/\|/ | /' -e 's/^[^-]*/  /g' -e 's/\)//' -e 's/#[^=]*=/: /')"
		}
		[[ "${OPT_ARGS}" != "" ]] && {
			>&2 echo -e "\nOPTIONAL ARGUMENTS:"
			>&2 echo -e "$(echo "${OPT_ARGS}" | sed -E -e 's/\|/ | /' -e 's/^[^-]*/  /g' -e 's/\)//' -e 's/#[^=]*=/: /')"
		}
	}
	exit 1
}

toolCheck() { # $1=TOOL_NAME
	[[ "$1" == "" ]] && exitOnError "Tool Name not specified"
	type -P "$1" >/dev/null 2>&1 || exitOnError "\"$1\" required and not found"
}

log() { # $1=msg
	echo "$1" >> "${LOG_FILE}"
	[[ "${DEBUG}" != "" ]] && >&2 echo "$1"
}

checkIntegerValue() { #$1=NAME, $2=VALUE, $3=MIN, $4=MAX 
	[[ "$2" != "0" && ! "$2" =~ ^[1-9]+[0-9]*$ ]] && exitOnError "$1 value must be an integer"
	[[ "$3" != "" ]] && {
		[[ $2 -lt $3 ]] && exitOnError "$1 value cannot be less than $3"
	}
	[[ "$4" != "" ]] && {
		[[ $2 -gt $4 ]] && exitOnError "$1 value cannot be greater than $4"
	}
}

dumpVars() { # $1=TITLE 
	local TITLE="$1"
	shift
	log "${TITLE}: $#"
	for NAME in "$@"
	do
		log "  ${NAME}: \"${!NAME}\""
	done
}

getArgs() {
	POSITIONAL=()
	VA_SCRIPT_REGEX='^[1-9][0-9]*:[1-9][0-9]*s(,[1-9][0-9]*:[1-9][0-9]*s)*$'
	# Set Defaults:
	DELAY_START="0"                                                                                                                                 
	DELAY_WINDOW=""
	GUI_URL=""
	LOG="1"
	OF_NAME=""
	POP_URL_TEMPLATE=""
	VA_DURATION="1s"
	VA_RATE="1"
	VA_REPORT_INTERVAL="1s"
	VA_SCRIPT=""
	VA_TARGET_METHOD="GET"
	VA_TARGET_POP=""
	VA_UA=""
	#
	while [[ $# -gt 0 ]]
	do
		key="$(echo "[$1]" | tr '[:upper:]' '[:lower:]' | sed -e 's/^\[//' -e 's/\]$//')"
		case "$key" in
			-a|--attack_script) #OPTIONAL=Vegeta Attack Script - RATE:DURATION[,RATE:DURATION...]
				[[ "${2}" =~ $VA_SCRIPT_REGEX ]] || exitOnError "Bad Vegeta Attack Script value"
				VA_SCRIPT="$2"
				shift; shift
				;;
			-r|--attack_rate) #OPTIONAL=Vegeta Attack Rate RPS
				checkIntegerValue "Vegeta Attack Rate" "$2"
				VA_RATE="$2"
				shift; shift
				;;
			-d|--attack_duration) #OPTIONAL=Vegeta Attack Duration seconds with "s" unit
				[[ "$2" =~ ^[1-9][0-9]*s$ ]] || exitOnError "Bad Vegeta Attack Duration value"
				VA_DURATION="$2"
				shift; shift
				;;
			-m|--attack_target_method) #OPTIONAL=Vegeta Attack Target Method
				VA_TARGET_METHOD="$2"
				shift; shift
				;;
			-p|--attack_target_pop) #OPTIONAL=Vegeta Attack Target POP
				[[ "$2" =~ ^[a-zA-Z]{3}$ ]] || exitOnError "POP expected to be 3 alpha characters"
				VA_TARGET_POP="$2"
				VA_TARGET_POP="$(echo "${VA_TARGET_POP}" | tr '[:lower:]' '[:upper:]')"
				shift; shift
				;;
			-g|--gui_url) #OPTIONAL=GUI URL
				GUI_URL="$2"
				shift; shift
				;;
			-t|--pop_url_template) #OPTIONAL=POP URL Template
				POP_URL_TEMPLATE="$2"
				shift; shift
				;;
			-i|--attack_report_interval) #OPTIONAL=Vegeta Attack Report Interval with "s" unit
				[[ "$2" =~ ^[1-9][0-9]*s$ ]] || exitOnError "Bad Vegeta Attack Report Interval value"
				VA_REPORT_INTERVAL="$2"
				shift; shift
				;;
			-h|--custom-header-name) #OPTIONAL=Vegeta Attack Header Name: Value
				[[ "$2" =~ ^[-a-zA-Z0-9_]+:[\ -~]+$ ]] || exitOnError "Bad Vegeta Attack Report Interval value"
				VA_CUSTOM_HEADER="$2"
				shift; shift
				;;
			-u|--user-agent) #OPTIONAL=Vegeta Attack User-Agent
				VA_UA_SET=1
				VA_UA="$2"
				shift; shift
				;;
			-f|--output_file_name) #OPTIONAL=Output File Name - Default=SCRIPT_NAME.out
				[[ "$2" == "" ]] && exitOnError "Output File Name cannot be an empty string"
				OF_NAME="$2"
				shift; shift
				;;
			-l|--log) #OPTIONAL=Log information to file
				checkIntegerValue "Log information to file" "$2" "0" "1"
				LOG="$2"
				shift; shift
				;;
			-w|--delay-window) #OPTIONAL=Delay Window (1/10/60)
				[[ "$2" =~ ^(1s|[16]0s)$ ]] || exitOnError "Unexpected Delay Window, i.e. not 1s/10s/60s"
				DELAY_WINDOW="$2"
				shift; shift
				;;
			-s|--delay-start) #OPTIONAL=Delay Start (0 <= DELAY_START < DELAY_WINDOW)
				checkIntegerValue "Delay Start" "$2" "0"
				DELAY_START="$2"
				shift; shift
				;;
			-x|--exit) #OPTIONAL=Process arguments and exit
				EXIT="1"
				shift
				;;
			--debug) #HIDDEN_OPTION
				{DEBUG}="1"
				shift
				;;
			*)
				[[ "$1" =~ ^- ]] && exitOnError "Unexpected argument - \"$1\"" "1"
				POSITIONAL+=("$1")
				shift
				;;
		esac
	done
	# Checks:VA_TARGET_URL
	[[ "${#POSITIONAL[@]}" -eq 0 ]] &&  exitOnError "TARGET_URL not specified" "1"
	[[ "${#POSITIONAL[@]}" -gt 1 ]] &&  exitOnError "One positional argument expected (TARGET_URL), ${#POSITIONAL[@]} found" "1"
	VA_TARGET_URL="${POSITIONAL[0]}"

	[[ "${DELAY_WINDOW}" != "" ]] && {
		DELAY_WINDOW_SECONDS="$(echo "${DELAY_WINDOW}" | sed -E 's/s$//')"
		[[ "${DELAY_START}" -ge "${DELAY_WINDOW_SECONDS}" ]] && exitOnError "Delay Start (${DELAY_START}) must be less than Delay Window (${DELAY_WINDOW})"
	}

	POS_ARGS=(VA_TARGET_URL)
	REQ_ARGS=()
	OPT_ARGS=(DELAY_START DELAY_WINDOW GUI_URL LOG OF_NAME POP_URL_TEMPLATE VA_DURATION VA_RATE VA_REPORT_INTERVAL VA_SCRIPT VA_TARGET_METHOD VA_TARGET_POP VA_UA)
	for NAME in "${REQ_ARGS[@]}"
	do
		[[ "${!NAME}" == "" ]] && exitOnError "Value for ${NAME} required" 1
	done

	[[ "${VA_UA}" == "" ]] && {
		getVegetaUserAgent
	}

	[[ "${LOG}" != "" || "${EXIT}" != "" ]] && {
		dumpVars "Positional Arguments" "${POS_ARGS[@]}"
		dumpVars "Required Arguments" "${REQ_ARGS[@]}"
		dumpVars "Optional Arguments" "${OPT_ARGS[@]}"
		[[ "${EXIT}" != "" ]] && {
			cat "${LOG_FILE}"
			exit 1
		}
	}
}

delayStart() { # $1=WIN_LEN, $2=WIN_SEC, $3=PREFIX
	local WIN_LEN="$1"; local WIN_SEC="$2"; local MSG_LBL="Time to start: "; local LAST_MSG; local NEW_MSG
	MSG_LBL="$3$MSG_LBL"
	[[ ! "$WIN_LEN" =~ ^[0-9]+$ ]] && exitOnError "WINDOW_LENGTH must be a positive integer"
	[[ ! "$WIN_SEC" =~ ^[0-9]+$ ]] && exitOnError "WINDOW_START must be a positive integer"
	[[ "$WIN_SEC" -ge $WIN_LEN ]] && exitOnError "WINDOW_START must be less than WINDOW_LENGTH"
	local NOW_MS="$(ruby -e 'printf("%.6f",Time.now.to_f)')"
	local NOW="$(echo $NOW_MS  | sed 's/\..*//')"
	local START="$((NOW/WIN_LEN*WIN_LEN + WIN_SEC))"
	[[ "$(echo "$START > $NOW_MS" | bc -l)" -eq 0 ]] && START="$(echo "$START + $WIN_LEN" | bc)"
	while [[ "$(echo "$START < $NOW_MS" | bc -l)" -eq 0 ]]; do
		local WAIT="$(( START - $(echo $NOW_MS  | sed 's/\..*//') ))"
		NEW_MSG="$(printf '%s%02d:%02d:%02d' "$MSG_LBL" "$((WAIT / 3600))" "$(((WAIT / 60) % 3600))" "$((WAIT % 60))")"
		[[ "$NEW_MSG" != "$LAST_MSG" ]] && {
			printf "$(echo "$LAST_MSG" | sed 's/./ /g')\r"
			echo -n "$NEW_MSG"
			LAST_MSG="$NEW_MSG"
		}
		sleep 0.05
		NOW_MS="$(ruby -e 'printf("%.6f",Time.now.to_f)')"
	done
	[[ "$LAST_MSG" != "" ]] && printf "\r$(echo "$LAST_MSG" | sed 's/./ /g')\r"
}

getVegetaUserAgent() {
	let TMP
	TMP="$(echo "GET https://ua.demotool.site" | vegeta attack  -rate=1 -duration=1s | vegeta encode)"
	VA_UA="$(echo "${TMP}" | grep -oE "\"X-User-Agent\":\[\".*?\"\]" | sed -E 's/^.*:\["(.*)"\]$/\1/')"
}

read -r -d '' GAWK_SCRIPT << EOM
function get_count(RESULTS,STATUS_CODE,OLD_COUNT,  RP, RR) {
	RP="\"" STATUS_CODE "\":([0-9]+)"
	return (match(RESULTS,RP,RR) ? RR[1] : 0) + OLD_COUNT
}
BEGIN{
	if(START=="") exit;
	#DEBUG=1
	#LOG=1
	HDRS=" -H \"content-type: application/json\" -H \"cookie: cid=erl\""
	OLD["0"]=get_count(RESULTS,"0")
	OLD["200"]=get_count(RESULTS,"200")
	OLD["429"]=get_count(RESULTS,"429")
	if(LOG==1){ print "OLD: " OLD["0"] ", " OLD["200"] ", " OLD["429"] > "gawk.log" }
}
{
	#if(DEBUG==1){ sub(/^[^{]*/,""); print }
	sub(/^.*"status_codes":{/,"")
	sub(/\},.*\$/,"")
	NEW["0"]=get_count(\$0,"0",OLD["0"])
	NEW["200"]=get_count(\$0,"200",OLD["200"])
	NEW["429"]=get_count(\$0,"429",OLD["429"])
	TMP="\"0\":" NEW["0"] ",\"200\":" NEW["200"] ",\"429\":" NEW["429"]
	POST_DATA="{\"index\":" systime()-START ",\"data\":{" TMP "},\"start\":" START "}"
	print POST_DATA > "gawk.tmp"
	if(LOG==1){ print POST_DATA > "gawk.log" }
	if(DEBUG==1){ print POST_DATA; next }
	printf POST_DATA "\n\t-> "
	system("curl -d '" POST_DATA "' " GUI_URL " " HDRS)
	print ""
}
END{
	if(START=="") print "START value missing";
}
EOM

runVegetaAttack() { # $1=VA_RATE $2=VA_DURATION
	VEGETA_ATTACK_ARGS=(-rate="$1" -duration="$2")
	[[ "${VA_UA_SET}" != "" ]] && VEGETA_ATTACK_ARGS+=(-header="user-agent: ${VA_UA}")
	[[ "${VA_TARGET_POP}" != "" ]] && VEGETA_ATTACK_ARGS+=(-insecure)
	let TMP
	[[ "${VA_CUSTOM_HEADER}" != "" ]] && TMP="\n${VA_CUSTOM_HEADER}"
	echo -e "${VA_TARGET_METHOD} ${VA_TARGET_URL}\nHost: ${VA_TARGET_HOSTNAME}${TMP}\n" | \
		vegeta attack "${VEGETA_ATTACK_ARGS[@]}" | \
		vegeta encode | \
		vegeta report -every "${VA_REPORT_INTERVAL}" -type json | \
		gawk -v START="${VA_START}" -v RESULTS="${VA_RESULTS}" -v GUI_URL="${GUI_URL}" "${GAWK_SCRIPT}"
}
#
#
#
toolCheck "curl"
toolCheck "vegeta"
toolCheck "gawk"

LOG_FILE="$(echo "$0" | sed -E 's/\.[^.]+$//').log"
rm -f $LOG_FILE

getArgs "$@"

[[ "${OF_NAME}" != "" ]] && OUT_FILE="${OF_NAME}.out" || OUT_FILE="$(echo "$0" | sed -E 's/\.[^.]+$//').out"
rm -f $OUT_FILE

IP="$(curl -s https://ip.demotool.site)"

VA_TARGET_HOSTNAME="$(echo "${VA_TARGET_URL}" | sed -E 's/^https?:\/\/([^\/]+).*$/\1/')"
[[ "${VA_TARGET_POP}" == "" ]] && {
	POP="$(curl -s https://node.demotool.site | \
		sed -E 's/^cache-(...).+$/\1/' | tr '[:lower:]' '[:upper:]')"
} || {
	[[ "${POP_URL_TEMPLATE}" == "" ]] && exitOnError "POP URL Template must be set if Target POP specified"
	VA_TARGET_URL="$(echo "${POP_URL_TEMPLATE}" | sed "s/\.---\./.${VA_TARGET_POP}./")"
	POP="$(curl -sk "${VA_TARGET_URL}" -H "host: node.demotool.site" | \
		sed -E 's/^cache-(...).+$/\1/' | tr '[:lower:]' '[:upper:]')"
	[[ "${POP}" == "" ]] && exitOnError "Unknown POP - ${VA_TARGET_POP}"
	[[ "${POP}" != "${VA_TARGET_POP}" ]] && exitOnError "POP validation failed - ${VA_TARGET_POP} expected, ${POP} found"
}

[[ "${DELAY_WINDOW}" != "" ]] && delayStart "${DELAY_WINDOW_SECONDS}" "${DELAY_START}"

echo "{\"client_ip\":\"${IP}\",\"client_ua\":\"${VA_UA}\",\"pop\":\"${POP}\"}"

VA_START="$(date +%s)"
VA_RESULTS=""

[[ "${GUI_URL}" == "" ]] && GAWK_SCRIPT='{sub(/^[^{]*/,""); print}'

[[ "${VA_SCRIPT}" == "" ]] && VA_SCRIPT="${VA_RATE}:${VA_DURATION}"
IFS=',' read -r -a KV_PAIRS <<< "${VA_SCRIPT}"
for KV_PAIR in "${KV_PAIRS[@]}"; do
   IFS=':' read -r -a TMP <<< "${KV_PAIR}"
   runVegetaAttack "${TMP[0]}" "${TMP[1]}"
   VA_RESULTS="$([[ -f gawk.tmp ]] && tail -1 gawk.tmp || echo "")"
done
