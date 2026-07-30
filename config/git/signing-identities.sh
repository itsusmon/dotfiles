#!/bin/bash

# Add one entry per signing identity:
#   email|full signing-subkey fingerprint|exact allowed push host
GPG_GIT_PRIMARY_FINGERPRINT=4F430EF8893AE3D330C5B8BE14FC48F9BBE08171
GPG_GIT_IDENTITIES=(
  'heyitsusmon@gmail.com|D98D08FE47805CB10E2CA7549E163909697C6FAA|github.com'
  'uabduraxmonov@sqb.uz|32F5ABAC7FFF28AB37915C68C7FA8C4F34356FD6|gitlab.sqb.uz'
)

gpg_git_config_error() {
  printf 'gpg-git identities: %s\n' "$1" >&2
  printf '  Configuration: %s\n' \
    "${GPG_GIT_IDENTITIES_PATH:-signing-identities.sh}" >&2
  printf '%s\n' \
    '  Fix: edit the configuration, keep one primary fingerprint, and use one email|subkey fingerprint|host record per identity.' >&2
}

gpg_git_load_identities() {
  local record_number=0
  local record email fingerprint host extra existing

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
  gpg_git_identity_hosts=()

  for record in "${GPG_GIT_IDENTITIES[@]}"; do
    record_number=$((record_number + 1))
    IFS='|' read -r email fingerprint host extra <<<"$record"

    if [[ -z "$email" || -z "$fingerprint" || -z "$host" || -n "${extra:-}" ]]; then
      gpg_git_config_error \
        "Identity $record_number is malformed: '$record'. Expected email|FULL_SIGNING_SUBKEY_FINGERPRINT|exact.git.host."
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
    if [[ ! "$host" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ || "$host" == *..* ]]; then
      gpg_git_config_error \
        "Identity $record_number for '$email' has an invalid lowercase ASCII push host: '$host'."
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
    gpg_git_identity_hosts+=("$host")
  done
}

gpg_git_find_identity() {
  local requested_email=$1
  local index

  gpg_git_identity_email=
  gpg_git_identity_fingerprint=
  gpg_git_identity_host=

  for index in "${!gpg_git_identity_emails[@]}"; do
    if [[ "${gpg_git_identity_emails[$index]}" == "$requested_email" ]]; then
      gpg_git_identity_email=${gpg_git_identity_emails[$index]}
      gpg_git_identity_fingerprint=${gpg_git_identity_fingerprints[$index]}
      gpg_git_identity_host=${gpg_git_identity_hosts[$index]}
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
