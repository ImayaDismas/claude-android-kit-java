#!/bin/bash

# Claude Environment Switcher

CLAUDE_DIR=".claude"
TARGET_FILE="$CLAUDE_DIR/settings.json"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
RESET="\033[0m"

CMD=$1

# -----------------------------
# Helpers
# -----------------------------
require_git() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${RED}Not inside a git repository${RESET}"
    exit 1
  fi
}

env_color() {
  case "$1" in
    dev)    echo -e "$BLUE" ;;
    review) echo -e "$MAGENTA" ;;
    ci)     echo -e "$RED" ;;
    *)      echo -e "$YELLOW" ;;
  esac
}

env_emoji() {
  case "$1" in
    dev)    echo "🟦" ;;
    review) echo "🟪" ;;
    ci)     echo "🟥" ;;
    *)      echo "⚠️" ;;
  esac
}

# -----------------------------
# help
# -----------------------------
cmd_help() {
  echo -e "${CYAN}Claude Environment Switcher${RESET}"
  echo ""
  echo -e "  ${GREEN}Usage:${RESET} ./scripts/claude-env.sh [command|env]"
  echo ""
  echo -e "  ${CYAN}Commands:${RESET}"
  echo -e "    ${GREEN}(none)${RESET}       Auto-detect env from current branch and switch"
  echo -e "    ${GREEN}dev${RESET}          Switch to dev environment"
  echo -e "    ${GREEN}review${RESET}       Switch to review environment"
  echo -e "    ${GREEN}ci${RESET}           Switch to CI environment"
  echo -e "    ${GREEN}status${RESET}       Show current active environment (no changes)"
  echo -e "    ${GREEN}list${RESET}         List all available environments and branch mappings"
  echo -e "    ${GREEN}help${RESET}         Show this help message"
  echo ""
  echo -e "  ${CYAN}Branch → Environment mapping:${RESET}"
  echo -e "    main, release/*, hotfix/*    → ${MAGENTA}review${RESET}"
  echo -e "    develop, feature/*, bugfix/* → ${BLUE}dev${RESET}"
  echo -e "    ci, ci/*                     → ${RED}ci${RESET}"
  echo -e "    (other)                      → ${BLUE}dev${RESET} (default)"
}

# -----------------------------
# list
# -----------------------------
cmd_list() {
  echo -e "${CYAN}Available environments:${RESET}"
  echo ""
  for env in dev review ci; do
    COLOR=$(env_color "$env")
    EMOJI=$(env_emoji "$env")
    FILE="$CLAUDE_DIR/settings.$env.json"
    if [ -f "$FILE" ]; then
      STATUS="${GREEN}✓ preset found${RESET}"
    else
      STATUS="${RED}✗ preset missing${RESET}"
    fi
    echo -e "  $EMOJI  ${COLOR}$env${RESET}  —  $STATUS"
  done
  echo ""
  echo -e "${CYAN}Branch → Environment mapping:${RESET}"
  echo -e "  main            → ${MAGENTA}review${RESET}"
  echo -e "  develop         → ${BLUE}dev${RESET}"
  echo -e "  feature/*       → ${BLUE}dev${RESET}"
  echo -e "  bugfix/*        → ${BLUE}dev${RESET}"
  echo -e "  release/*       → ${MAGENTA}review${RESET}"
  echo -e "  hotfix/*        → ${MAGENTA}review${RESET}"
  echo -e "  ci, ci/*        → ${RED}ci${RESET}"
  echo -e "  (other)         → ${BLUE}dev${RESET} (default)"
}

# -----------------------------
# status
# -----------------------------
cmd_status() {
  require_git

  if [ ! -f "$TARGET_FILE" ]; then
    echo -e "${RED}No active settings.json found at $TARGET_FILE${RESET}"
    exit 1
  fi

  ACTIVE_ENV="unknown"
  for env in dev review ci; do
    PRESET="$CLAUDE_DIR/settings.$env.json"
    if [ -f "$PRESET" ] && cmp -s "$TARGET_FILE" "$PRESET"; then
      ACTIVE_ENV=$env
      break
    fi
  done

  COLOR=$(env_color "$ACTIVE_ENV")
  EMOJI=$(env_emoji "$ACTIVE_ENV")

  echo ""
  echo -e "Active environment: ${COLOR}$ACTIVE_ENV mode${RESET}  $EMOJI"

  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  echo -e "Current branch:     ${CYAN}$BRANCH${RESET}"

  CLAUDE_PIDS=($(pgrep -u "$USER" -f "^claude" 2>/dev/null))
  SESSION_COUNT=${#CLAUDE_PIDS[@]}
  if [[ $SESSION_COUNT -gt 0 ]]; then
    echo -e "Claude sessions:    ${YELLOW}$SESSION_COUNT running${RESET}"
  else
    echo -e "Claude sessions:    ${YELLOW}none${RESET}"
  fi
  echo ""
}

# -----------------------------
# switch
# -----------------------------
cmd_switch() {
  local ENV=$1
  require_git

  # Auto-detect if no env given
  if [ -z "$ENV" ]; then
    branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$branch" == "main" ]]; then
      ENV="review"
    elif [[ "$branch" == "develop" ]]; then
      ENV="dev"
    elif [[ "$branch" == feature/* ]]; then
      ENV="dev"
    elif [[ "$branch" == bugfix/* ]]; then
      ENV="dev"
    elif [[ "$branch" == release/* ]]; then
      ENV="review"
    elif [[ "$branch" == hotfix/* ]]; then
      ENV="review"
    elif [[ "$branch" == "ci" || "$branch" == ci/* ]]; then
      ENV="ci"
    else
      echo -e "${YELLOW}Unknown branch: $branch${RESET}"
      echo -e "${YELLOW}Defaulting to dev environment${RESET}"
      ENV="dev"
    fi
    echo -e "${CYAN}Auto-detected: branch=$branch → ENV=$ENV${RESET}"
  fi

  SOURCE_FILE="$CLAUDE_DIR/settings.$ENV.json"

  if [[ "$ENV" != "dev" && "$ENV" != "review" && "$ENV" != "ci" ]]; then
    echo -e "${RED}Invalid environment: $ENV${RESET}"
    echo "Usage: ./scripts/claude-env.sh [dev|review|ci]"
    exit 1
  fi

  if [ ! -f "$SOURCE_FILE" ]; then
    echo -e "${RED}Missing config file: $SOURCE_FILE${RESET}"
    exit 1
  fi

  ENV_COLOR=$(env_color "$ENV")
  DESKTOP_EMOJI=$(env_emoji "$ENV")

  cp "$SOURCE_FILE" "$TARGET_FILE"
  echo -e "${GREEN}Switched to ${ENV_COLOR}$ENV${GREEN} mode${RESET}"

  # Validate JSON structure
  if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}jq not installed — skipping JSON validation${RESET}"
  else
    echo ""
    echo -e "${CYAN}Validating config structure...${RESET}"
    REQUIRED_KEYS=("permissions" "autoApply" "confirmBeforeEdit" "contextFiles")
    for key in "${REQUIRED_KEYS[@]}"; do
      if ! jq -e "has(\"$key\")" "$TARGET_FILE" > /dev/null; then
        echo -e "${RED}Missing required key: $key${RESET}"
        exit 1
      fi
    done
    echo -e "${GREEN}Config structure valid${RESET}"
  fi

  echo ""
  echo -e "Active environment: ${ENV_COLOR}$ENV ${RESET}mode"

  echo ""
  echo -e "${CYAN}Config summary:${RESET}"
  if command -v jq &> /dev/null; then
    jq '{ autoApply, confirmBeforeEdit, contextFilesCount: (.contextFiles | length) }' "$TARGET_FILE"
  else
    echo "autoApply / confirmBeforeEdit / contextFiles present"
  fi

  # Kill running sessions
  CLAUDE_PIDS=($(pgrep -u "$USER" -f "^claude" 2>/dev/null))
  SESSION_COUNT=${#CLAUDE_PIDS[@]}

  echo ""
  if [[ $SESSION_COUNT -gt 0 ]]; then
    kill "${CLAUDE_PIDS[@]}" 2>/dev/null
    SESSION_MSG="$SESSION_COUNT session(s) stopped — run \`claude\` to restart"
    echo -e "${GREEN}$SESSION_MSG${RESET}"
  else
    SESSION_MSG="No running sessions — run \`claude\` to start"
    echo -e "${YELLOW}$SESSION_MSG${RESET}"
  fi
  echo ""
  echo -e "${YELLOW}Note: Claude does NOT reload config mid-session.${RESET}"

  NOTIFY_MSG="Environment: $ENV mode\n$SESSION_MSG"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Claude Environment $DESKTOP_EMOJI" "$NOTIFY_MSG"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    osascript -e "display notification \"$NOTIFY_MSG\" with title \"Claude Environment $DESKTOP_EMOJI\""
  fi
}

# -----------------------------
# Route command
# -----------------------------
case "$CMD" in
  status)           cmd_status ;;
  list)             cmd_list ;;
  help|-h|--help)   cmd_help ;;
  dev|review|ci)    cmd_switch "$CMD" ;;
  "")               cmd_switch "" ;;
  *)
    echo -e "${RED}Unknown command: $CMD${RESET}"
    echo ""
    cmd_help
    exit 1
    ;;
esac
