#!/bin/bash
# Based on: https://github.com/daniel3303/ClaudeCodeStatusLine
# Refactored for composition:
# - all derivation logic lives in functions
# - final line composition is inlined at the end
# - segment order is easy to change
# - splitting into multiple lines is straightforward

set -f

VERSION="1.2.0"
input=$(cat)

if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

# ============================================================
# Colors / formatting
# ============================================================

blue='\033[38;2;0;153;255m'
orange='\033[38;2;255;176;85m'
green='\033[38;2;0;160;0m'
cyan='\033[38;2;46;149;153m'
red='\033[38;2;255;85;85m'
yellow='\033[38;2;230;200;0m'
white='\033[38;2;220;220;220m'
dim='\033[2m'
reset='\033[0m'

SEP=" ${dim}|${reset} "

claude_config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings_path="${claude_config_dir}/settings.json"

# ============================================================
# Basic helpers
# ============================================================

json() {
    jq -r "$1 // empty" <<< "$input"
}

join_by() {
    local sep="$1"
    shift
    local out=""
    local first=true
    local item

    for item in "$@"; do
        [ -z "$item" ] && continue
        if $first; then
            out="$item"
            first=false
        else
            out+="$sep$item"
        fi
    done

    printf "%s" "$out"
}

format_tokens() {
    local num="${1:-0}"
    if [ "$num" -ge 1000000 ] 2>/dev/null; then
        awk "BEGIN {printf \"%.1fm\", $num / 1000000}"
    elif [ "$num" -ge 1000 ] 2>/dev/null; then
        awk "BEGIN {printf \"%.0fk\", $num / 1000}"
    else
        printf "%d" "$num"
    fi
}

format_commas() {
    printf "%'d" "${1:-0}"
}

usage_color() {
    local pct="${1:-0}"
    if [ "$pct" -ge 90 ] 2>/dev/null; then
        printf "%b" "$red"
    elif [ "$pct" -ge 70 ] 2>/dev/null; then
        printf "%b" "$orange"
    elif [ "$pct" -ge 50 ] 2>/dev/null; then
        printf "%b" "$yellow"
    else
        printf "%b" "$green"
    fi
}

version_gt() {
    local a="${1#v}" b="${2#v}"
    local IFS='.'
    read -r a1 a2 a3 <<< "$a"
    read -r b1 b2 b3 <<< "$b"
    a1=${a1:-0}; a2=${a2:-0}; a3=${a3:-0}
    b1=${b1:-0}; b2=${b2:-0}; b3=${b3:-0}

    [ "$a1" -gt "$b1" ] 2>/dev/null && return 0
    [ "$a1" -lt "$b1" ] 2>/dev/null && return 1
    [ "$a2" -gt "$b2" ] 2>/dev/null && return 0
    [ "$a2" -lt "$b2" ] 2>/dev/null && return 1
    [ "$a3" -gt "$b3" ] 2>/dev/null && return 0
    return 1
}

cache_mtime() {
    local file="$1"
    stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null
}

# ============================================================
# Time helpers
# ============================================================

iso_to_epoch() {
    local iso_str="$1"
    local epoch

    epoch=$(date -d "$iso_str" +%s 2>/dev/null)
    if [ -n "$epoch" ]; then
        printf "%s" "$epoch"
        return 0
    fi

    local stripped="${iso_str%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    stripped="${stripped%%-[0-9][0-9]:[0-9][0-9]}"

    if [[ "$iso_str" == *"Z"* ]] || [[ "$iso_str" == *"+00:00"* ]] || [[ "$iso_str" == *"-00:00"* ]]; then
        epoch=$(env TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    else
        epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    fi

    [ -n "$epoch" ] && printf "%s" "$epoch"
}

format_epoch_time() {
    local epoch="$1"
    local fmt="$2"
    date -d "@$epoch" +"$fmt" 2>/dev/null || date -j -r "$epoch" +"$fmt" 2>/dev/null
}

format_reset_time() {
    local iso_str="$1"
    local style="$2"

    { [ -z "$iso_str" ] || [ "$iso_str" = "null" ]; } && return

    local epoch
    epoch=$(iso_to_epoch "$iso_str")
    [ -z "$epoch" ] && return

    case "$style" in
        time)
            format_epoch_time "$epoch" "%H:%M"
            ;;
        datetime)
            format_epoch_time "$epoch" "%b %-d, %H:%M"
            ;;
        *)
            format_epoch_time "$epoch" "%b %-d"
            ;;
    esac
}

format_reset_epoch_builtin() {
    local epoch="$1"
    local style="$2"

    [ -z "$epoch" ] && return
    [ "$epoch" = "null" ] && return

    case "$style" in
        time)
            format_epoch_time "$epoch" "%H:%M"
            ;;
        datetime)
            format_epoch_time "$epoch" "%b %-d, %H:%M"
            ;;
        *)
            format_epoch_time "$epoch" "%b %-d"
            ;;
    esac
}

# ============================================================
# Data derivation functions
# ============================================================

get_model_name() {
    local value
    value=$(json '.model.display_name')
    printf "%s" "${value:-Claude}"
}

get_context_size() {
    local value
    value=$(json '.context_window.context_window_size')
    if [ -z "$value" ] || [ "$value" = "0" ]; then
        printf "200000"
    else
        printf "%s" "$value"
    fi
}

get_input_tokens() {
    local value
    value=$(json '.context_window.current_usage.input_tokens')
    printf "%s" "${value:-0}"
}

get_cache_create_tokens() {
    local value
    value=$(json '.context_window.current_usage.cache_creation_input_tokens')
    printf "%s" "${value:-0}"
}

get_cache_read_tokens() {
    local value
    value=$(json '.context_window.current_usage.cache_read_input_tokens')
    printf "%s" "${value:-0}"
}

get_total_used_tokens() {
    local input_tokens cache_create cache_read
    input_tokens=$(get_input_tokens)
    cache_create=$(get_cache_create_tokens)
    cache_read=$(get_cache_read_tokens)
    printf "%s" $(( input_tokens + cache_create + cache_read ))
}

get_pct_used() {
    local used size
    used=$(get_total_used_tokens)
    size=$(get_context_size)

    if [ "$size" -gt 0 ] 2>/dev/null; then
        printf "%s" $(( used * 100 / size ))
    else
        printf "0"
    fi
}

get_pct_remaining() {
    local pct_used
    pct_used=$(get_pct_used)
    printf "%s" $(( 100 - pct_used ))
}

get_effort_level() {
    if [ -n "$CLAUDE_CODE_EFFORT_LEVEL" ]; then
        printf "%s" "$CLAUDE_CODE_EFFORT_LEVEL"
        return
    fi

    if [ -f "$settings_path" ]; then
        local effort
        effort=$(jq -r '.effortLevel // empty' "$settings_path" 2>/dev/null)
        [ -n "$effort" ] && printf "%s" "$effort" && return
    fi

    printf "medium"
}

get_cwd() {
    json '.cwd'
}

get_display_dir() {
    local cwd
    cwd=$(get_cwd)
    [ -n "$cwd" ] && printf "%s" "${cwd##*/}"
}

get_git_branch() {
    local cwd
    cwd=$(get_cwd)
    [ -z "$cwd" ] && return

    git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null
}

get_git_diff_stat() {
    local cwd
    cwd=$(get_cwd)
    [ -z "$cwd" ] && return

    git -C "$cwd" diff --numstat 2>/dev/null | awk '
        {a+=$1; d+=$2}
        END {
            if (a+d > 0) printf "+%d -%d", a, d
        }
    '
}

render_usage_bar() {
    local pct="${1:-0}"
    local width="${2:-10}"

    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100

    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local color
    color=$(usage_color "$pct")

    local fill=""
    local rest=""
    local i

    for ((i = 0; i < filled; i++)); do
        fill+="█"
    done

    for ((i = 0; i < empty; i++)); do
        rest+="░"
    done

    printf "%b" "${color}${fill}${dim}${rest}${reset}"
}

# ============================================================
# OAuth / usage data
# ============================================================

get_oauth_token() {
    local token=""

    if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
        printf "%s" "$CLAUDE_CODE_OAUTH_TOKEN"
        return 0
    fi

    if command -v security >/dev/null 2>&1; then
        local keychain_svc="Claude Code-credentials"
        if [ -n "$CLAUDE_CONFIG_DIR" ]; then
            local dir_hash
            dir_hash=$(echo -n "$CLAUDE_CONFIG_DIR" | shasum -a 256 | cut -c1-8)
            keychain_svc="Claude Code-credentials-${dir_hash}"
        fi

        local blob
        blob=$(security find-generic-password -s "$keychain_svc" -w 2>/dev/null)
        if [ -n "$blob" ]; then
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                printf "%s" "$token"
                return 0
            fi
        fi
    fi

    local creds_file="${claude_config_dir}/.credentials.json"
    if [ -f "$creds_file" ]; then
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            printf "%s" "$token"
            return 0
        fi
    fi

    if command -v secret-tool >/dev/null 2>&1; then
        local blob
        blob=$(timeout 2 secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
        if [ -n "$blob" ]; then
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                printf "%s" "$token"
                return 0
            fi
        fi
    fi

    printf ""
}

get_builtin_five_hour_pct() {
    json '.rate_limits.five_hour.used_percentage'
}

get_builtin_five_hour_reset() {
    json '.rate_limits.five_hour.resets_at'
}

get_builtin_seven_day_pct() {
    json '.rate_limits.seven_day.used_percentage'
}

get_builtin_seven_day_reset() {
    json '.rate_limits.seven_day.resets_at'
}

has_builtin_rate_limits() {
    local five seven
    five=$(get_builtin_five_hour_pct)
    seven=$(get_builtin_seven_day_pct)
    [ -n "$five" ] || [ -n "$seven" ]
}

get_usage_cache_file() {
    local hash
    hash=$(echo -n "$claude_config_dir" | shasum -a 256 2>/dev/null || echo -n "$claude_config_dir" | sha256sum 2>/dev/null)
    hash=$(echo "$hash" | cut -c1-8)
    printf "/tmp/claude/statusline-usage-cache-%s.json" "$hash"
}

fetch_usage_data_from_api() {
    local token
    token=$(get_oauth_token)
    [ -z "$token" ] && return

    curl -s --max-time 10 \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "User-Agent: claude-code/2.1.34" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null
}

get_usage_data() {
    has_builtin_rate_limits && return

    local cache_file
    cache_file=$(get_usage_cache_file)
    local cache_max_age=60
    local usage_data=""
    local now cache_age mtime

    mkdir -p /tmp/claude

    if [ -f "$cache_file" ] && [ -s "$cache_file" ]; then
        mtime=$(cache_mtime "$cache_file")
        now=$(date +%s)
        cache_age=$(( now - mtime ))
        if [ "$cache_age" -lt "$cache_max_age" ]; then
            cat "$cache_file" 2>/dev/null
            return
        fi
        usage_data=$(cat "$cache_file" 2>/dev/null)
    fi

    touch "$cache_file"

    local response
    response=$(fetch_usage_data_from_api)
    if [ -n "$response" ] && echo "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
        echo "$response" > "$cache_file"
        printf "%s" "$response"
        return
    fi

    printf "%s" "$usage_data"
}

# ============================================================
# Segment builders
# ============================================================

segment_model() {
    printf "%b" "${blue}$(get_model_name)${reset}"
}

segment_project() {
    local display_dir git_branch git_stat
    display_dir=$(get_display_dir)
    git_branch=$(get_git_branch)
    git_stat=$(get_git_diff_stat)

    [ -z "$display_dir" ] && return

    local out="${cyan}${display_dir}${reset}"

    if [ -n "$git_branch" ]; then
        out+="${dim}@${reset}${green}${git_branch}${reset}"
    fi

    if [ -n "$git_stat" ]; then
        out+=" ${dim}(${reset}${green}${git_stat%% *}${reset} ${red}${git_stat##* }${reset}${dim})${reset}"
    fi

    printf "%b" "$out"
}

segment_context_usage() {
    local used total pct
    used=$(format_tokens "$(get_total_used_tokens)")
    total=$(format_tokens "$(get_context_size)")
    pct=$(get_pct_used)

    printf "%b" "${orange}${used}/${total}${reset} ${dim}(${reset}${green}${pct}%${reset}${dim})${reset}"
}

segment_effort() {
    local effort
    effort=$(get_effort_level)

    case "$effort" in
        low)
            printf "%b" "effort: ${dim}${effort}${reset}"
            ;;
        medium)
            printf "%b" "effort: ${orange}med${reset}"
            ;;
        max)
            printf "%b" "effort: ${red}${effort}${reset}"
            ;;
        *)
            printf "%b" "effort: ${green}${effort}${reset}"
            ;;
    esac
}

segment_five_hour_builtin() {
    local pct color formatted bar
    pct=$(get_builtin_five_hour_pct)
    [ -z "$pct" ] && return

    pct=$(printf "%.0f" "$pct")
    color=$(usage_color "$pct")
    formatted=$(format_reset_epoch_builtin "$(get_builtin_five_hour_reset)" "time")
    bar=$(render_usage_bar "$pct" 10)

    local out="${white}5h${reset} ${bar} ${color}${pct}%${reset}"
    [ -n "$formatted" ] && out+=" ${dim}@${formatted}${reset}"

    printf "%b" "$out"
}

segment_seven_day_builtin() {
    local pct color formatted
    pct=$(get_builtin_seven_day_pct)
    [ -z "$pct" ] && return

    pct=$(printf "%.0f" "$pct")
    color=$(usage_color "$pct")
    formatted=$(format_reset_epoch_builtin "$(get_builtin_seven_day_reset)" "datetime")

    local out="${white}7d${reset} ${color}${pct}%${reset}"
    [ -n "$formatted" ] && out+=" ${dim}@${formatted}${reset}"

    printf "%b" "$out"
}

segment_five_hour_api() {
    local usage_data="$1"
    [ -z "$usage_data" ] && return
    echo "$usage_data" | jq -e '.five_hour' >/dev/null 2>&1 || return

    local pct reset_iso reset_fmt color bar
    pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
    reset_iso=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')
    reset_fmt=$(format_reset_time "$reset_iso" "time")
    color=$(usage_color "$pct")
    bar=$(render_usage_bar "$pct" 10)

    local out="${white}5h${reset} ${bar} ${color}${pct}%${reset}"
    [ -n "$reset_fmt" ] && out+=" ${dim}@${reset_fmt}${reset}"

    printf "%b" "$out"
}

segment_seven_day_api() {
    local usage_data="$1"
    [ -z "$usage_data" ] && return
    echo "$usage_data" | jq -e '.seven_day' >/dev/null 2>&1 || return

    local pct reset_iso reset_fmt color
    pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
    reset_iso=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty')
    reset_fmt=$(format_reset_time "$reset_iso" "datetime")
    color=$(usage_color "$pct")

    local out="${white}7d${reset} ${color}${pct}%${reset}"
    [ -n "$reset_fmt" ] && out+=" ${dim}@${reset_fmt}${reset}"

    printf "%b" "$out"
}

segment_extra_usage_api() {
    local usage_data="$1"
    [ -z "$usage_data" ] && return

    local enabled
    enabled=$(echo "$usage_data" | jq -r '.extra_usage.is_enabled // false')
    [ "$enabled" = "true" ] || return

    local pct used limit color
    pct=$(echo "$usage_data" | jq -r '.extra_usage.utilization // 0' | awk '{printf "%.0f", $1}')
    used=$(echo "$usage_data" | jq -r '.extra_usage.used_credits // 0' | LC_NUMERIC=C awk '{printf "%.2f", $1/100}')
    limit=$(echo "$usage_data" | jq -r '.extra_usage.monthly_limit // 0' | LC_NUMERIC=C awk '{printf "%.2f", $1/100}')

    if [ -n "$used" ] && [ -n "$limit" ] && [[ "$used" != *'$'* ]] && [[ "$limit" != *'$'* ]]; then
        color=$(usage_color "$pct")
        printf "%b" "${white}extra${reset} ${color}\$${used}/\$${limit}${reset}"
    else
        printf "%b" "${white}extra${reset} ${green}enabled${reset}"
    fi
}

segment_usage_placeholders() {
    printf "%b" "${white}5h${reset} ${dim}-${reset}${SEP}${white}7d${reset} ${dim}-${reset}"
}

# ============================================================
# Final composition
# ============================================================

main() {
    local lines=()
    local usage_data=""

    if ! has_builtin_rate_limits; then
        usage_data=$(get_usage_data)
    fi

    # 1. Model + effort + context
    lines+=("$(join_by "$SEP" \
        "$(segment_model)" \
        "$(segment_effort)" \
        "$(segment_context_usage)")")

    # 2. Dir + git
    lines+=("$(join_by "$SEP" \
        "$(segment_project)")")

    # 3. Usage / limits (5h, 7d, extra) — hidden on API billing (no OAuth token)
    if has_builtin_rate_limits; then
        lines+=("$(join_by "$SEP" \
            "$(segment_five_hour_builtin)" \
            "$(segment_seven_day_builtin)")")
    elif [ -n "$usage_data" ] && echo "$usage_data" | jq -e '.five_hour' >/dev/null 2>&1; then
        lines+=("$(join_by "$SEP" \
            "$(segment_five_hour_api "$usage_data")" \
            "$(segment_seven_day_api "$usage_data")" \
            "$(segment_extra_usage_api "$usage_data")")")
    elif [ -n "$(get_oauth_token)" ]; then
        # Has OAuth token but API returned no data yet — show placeholders
        lines+=("$(segment_usage_placeholders)")
    fi
    # API billing users have no OAuth token: skip the usage line entirely

    printf "%b" "$(join_by "\n" "${lines[@]}")"
}

main
exit 0