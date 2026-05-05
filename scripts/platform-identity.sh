#!/usr/bin/env bash

IDP_PLATFORM_SLUG="${IDP_PLATFORM_SLUG:-internal-developer-platform}"
IDP_LEGACY_PLATFORM_SLUG="${IDP_LEGACY_PLATFORM_SLUG:-devops-easy-learning}"
IDP_STATE_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
IDP_STATE_DIR="${IDP_STATE_HOME}/${IDP_PLATFORM_SLUG}"
IDP_LEGACY_STATE_DIR="${IDP_STATE_HOME}/${IDP_LEGACY_PLATFORM_SLUG}"

idp_runtime_value() {
  local preferred_var="$1"
  local legacy_var="$2"
  local default_value="$3"
  printf '%s' "${!preferred_var:-${!legacy_var:-${default_value}}}"
}

idp_platform_slugs() {
  printf '%s\n' "${IDP_PLATFORM_SLUG}" "${IDP_LEGACY_PLATFORM_SLUG}" | awk '!seen[$0]++'
}

idp_ensure_state_dir() {
  mkdir -p "${IDP_STATE_DIR}"
  chmod 700 "${IDP_STATE_DIR}"
}

idp_migrate_legacy_state_dir_if_needed() {
  if [[ -d "${IDP_LEGACY_STATE_DIR}" && ! -d "${IDP_STATE_DIR}" ]]; then
    mkdir -p "${IDP_STATE_DIR}"
    cp -R "${IDP_LEGACY_STATE_DIR}/." "${IDP_STATE_DIR}/"
    chmod 700 "${IDP_STATE_DIR}"
  fi
}

idp_resolve_state_file() {
  local filename="$1"
  if [[ -f "${IDP_STATE_DIR}/${filename}" ]]; then
    printf '%s\n' "${IDP_STATE_DIR}/${filename}"
    return 0
  fi

  if [[ -f "${IDP_LEGACY_STATE_DIR}/${filename}" ]]; then
    printf '%s\n' "${IDP_LEGACY_STATE_DIR}/${filename}"
    return 0
  fi

  printf '%s\n' "${IDP_STATE_DIR}/${filename}"
}
