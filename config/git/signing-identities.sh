#!/bin/bash

# Add one entry per signing identity:
#   full signing-subkey fingerprint|email
GPG_GIT_PRIMARY_FINGERPRINT=4F430EF8893AE3D330C5B8BE14FC48F9BBE08171
GPG_GIT_IDENTITIES=(
  'D98D08FE47805CB10E2CA7549E163909697C6FAA|heyitsusmon@gmail.com'
  '32F5ABAC7FFF28AB37915C68C7FA8C4F34356FD6|uabduraxmonov@sqb.uz'
)

gpg_git_config_error() {
  printf 'gpg-git identities: %s\n' "$1" >&2
  printf '  Configuration: %s\n' \
    "${GPG_GIT_IDENTITIES_PATH:-signing-identities.sh}" >&2
  printf '%s\n' \
    '  Fix: edit the configuration, keep one primary fingerprint, and use one subkey fingerprint|email record per identity.' >&2
}

gpg_git_load_identities() {
  local record_number=0
  local record email fingerprint extra existing

  if [[ ! "${GPG_GIT_PRIMARY_FINGERPRINT:-}" =~ ^[0-9A-F]{40}$ ]]; then
    gpg_git_config_error \
      'GPG_GIT_PRIMARY_FINGERPRINT must contain exactly 40 uppercase hexadecimal characters.'
    return 2
  fi

  if [[ "${#GPG_GIT_IDENTITIES[@]}" -eq 0 ]]; then
    gpg_git_config_error 'GPG_GIT_IDENTITIES must contain at least one identity.'
    return 2
  fi

  gpg_git_identity_emails=()
  gpg_git_identity_fingerprints=()

  for record in "${GPG_GIT_IDENTITIES[@]}"; do
    record_number=$((record_number + 1))
    IFS='|' read -r fingerprint email extra <<<"$record"

    if [[ -z "$email" || -z "$fingerprint" || -n "${extra:-}" ]]; then
      gpg_git_config_error \
        "Identity $record_number is malformed: '$record'. Expected FULL_SIGNING_SUBKEY_FINGERPRINT|email."
      return 2
    fi
    if [[ ! "$email" =~ ^[^@[:space:]]+@[^@[:space:]]+$ ]]; then
      gpg_git_config_error \
        "Identity $record_number has an invalid email: '$email'."
      return 2
    fi
    if [[ "$email" != "$(LC_ALL=C printf '%s' "$email" | tr '[:upper:]' '[:lower:]')" ]]; then
      gpg_git_config_error \
        "Identity $record_number email must be lowercase: '$email'."
      return 2
    fi
    if [[ ! "$fingerprint" =~ ^[0-9A-F]{40}$ ]]; then
      gpg_git_config_error \
        "Identity $record_number for '$email' needs a 40-character uppercase signing-subkey fingerprint."
      return 2
    fi
    if [[ "$fingerprint" == "$GPG_GIT_PRIMARY_FINGERPRINT" ]]; then
      gpg_git_config_error \
        "Identity $record_number for '$email' uses the primary fingerprint. Configure a signing subkey fingerprint instead."
      return 2
    fi
    for existing in "${gpg_git_identity_emails[@]-}"; do
      if [[ "$existing" == "$email" ]]; then
        gpg_git_config_error \
          "Identity $record_number repeats email '$email'. Each email must be unique."
        return 2
      fi
    done
    for existing in "${gpg_git_identity_fingerprints[@]-}"; do
      if [[ "$existing" == "$fingerprint" ]]; then
        gpg_git_config_error \
          "Identity $record_number repeats signing-subkey fingerprint '$fingerprint'. Each identity needs a distinct subkey."
        return 2
      fi
    done

    gpg_git_identity_emails+=("$email")
    gpg_git_identity_fingerprints+=("$fingerprint")
  done
}

gpg_git_find_identity() {
  local requested_email=$1
  local index

  gpg_git_identity_email=
  gpg_git_identity_fingerprint=

  for index in "${!gpg_git_identity_emails[@]}"; do
    if [[ "${gpg_git_identity_emails[$index]}" == "$requested_email" ]]; then
      gpg_git_identity_email=${gpg_git_identity_emails[$index]}
      gpg_git_identity_fingerprint=${gpg_git_identity_fingerprints[$index]}
      return 0
    fi
  done

  return 1
}

gpg_git_list_configured_emails() {
  local email

  for email in "${gpg_git_identity_emails[@]}"; do
    printf '  - %s\n' "$email"
  done
}
